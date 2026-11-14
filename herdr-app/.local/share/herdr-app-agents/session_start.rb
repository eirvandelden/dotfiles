require "json"
require "time"
require_relative "agent_record"
require_relative "core"
require_relative "process_table"

module HerdrAppAgents
  # One SessionStart hook call, turned into an agent record.
  class SessionStart
    #: (String kind, String payload, Hash[String, String] env, ?cores: singleton(Core)) -> void
    def initialize(kind, payload, env, cores: Core)
      @kind = kind
      @payload = payload
      @env = env
      @cores = cores
    end

    # nil outside herdr-app (no HC_TERMINAL_ID), for claude without CLAUDE_CODE_ENTRYPOINT=cli, and when the
    # terminal's foreground is not TerminalState#interactive?(kind) (a foreground `codex exec`).
    # Refusal when: the payload has no session_id or transcript_path; the hc answer names another address;
    # the hook lineage does not reach the terminal's foreground pid; HC_SESSION is set and differs from the
    # socket's core. cwd is the terminal's real foreground cwd; flags come from its foreground argv.
    #: (processes: ProcessTable, now: Time, ?pid: Integer) -> AgentRecord?
    def record(processes:, now:, pid: Process.pid)
      return unless applicable?

      payload = payload_fields
      core = checked_core
      state = core.terminal(terminal)
      refuse("hc answered another address than #{terminal}") unless state.address?(terminal)
      return unless state.interactive?(@kind)

      refuse("hook lineage does not reach the foreground of #{terminal}") unless lineage?(processes, pid, state)
      build(core, state, payload, now)
    end

    private

    #: -> String
    def terminal
      @env.fetch("HC_TERMINAL_ID")
    end

    #: -> bool
    def applicable?
      !@env.fetch("HC_TERMINAL_ID", "").empty? && (@kind != "claude" || @env["CLAUDE_CODE_ENTRYPOINT"] == "cli")
    end

    #: -> Hash[String, untyped]
    def payload_fields
      fields = JSON.parse(@payload)
      refuse("payload has no session_id or transcript_path") unless %w[session_id transcript_path].all? { |key| fields.is_a?(Hash) && fields[key].is_a?(String) }

      fields
    rescue JSON::ParserError
      refuse("payload is not JSON")
    end

    #: -> Core
    def checked_core
      core = @cores.of_socket(@env["HC_TERMINAL_SOCKET"])
      declared = @env.fetch("HC_SESSION", "")
      refuse("HC_SESSION #{declared} differs from the socket's core #{core.name}") unless declared.empty? || declared == core.name

      core
    end

    #: (ProcessTable processes, Integer pid, TerminalState state) -> bool
    def lineage?(processes, pid, state)
      agent_pid = state.foreground_pid
      !agent_pid.nil? && processes.spawned_by?(pid, agent_pid)
    end

    #: (Core core, TerminalState state, Hash[String, untyped] payload, Time now) -> AgentRecord
    def build(core, state, payload, now)
      AgentRecord.parse(JSON.generate(
        "core" => core.name, "terminal" => terminal, "kind" => @kind, "session_id" => payload["session_id"],
        "cwd" => state.cwd, "transcript_path" => payload["transcript_path"],
        "flags" => AgentRecord.flags_of(@kind, state.foreground_argv), "recorded_at" => now.utc.iso8601(3), "resumed_at" => nil
      ))
    end

    #: (String reason) -> bot
    def refuse(reason)
      raise Refusal, reason
    end
  end
end
