require "socket"
require_relative "command_line"

module HerdrAppAgents
  # One `hc get --json` answer, read strictly: a missing field answers the safe side.
  class TerminalState
    SHELLS = %w[zsh bash sh fish dash].freeze

    #: (untyped answer) -> void
    def initialize(answer)
      @answer = answer.is_a?(Hash) ? answer : {}
    end

    #: (String terminal) -> bool
    def address?(terminal)
      @answer["address"] == terminal
    end

    #: -> Integer?
    def foreground_pid
      pid = foreground["pid"]
      pid if pid.is_a?(Integer)
    end

    #: -> Array[String]
    def foreground_argv
      argv = foreground["argv"]
      argv.is_a?(Array) && argv.all?(String) ? argv : []
    end

    # The real path of foreground.cwd, else cwd; nil when absent or unresolvable.
    #: -> String?
    def cwd
      path = foreground["cwd"] || @answer["cwd"]
      File.realpath(path) if path.is_a?(String)
    rescue SystemCallError
      nil
    end

    # Live, no agent status, foreground.pid == pid, argv[0] (basename, leading - stripped) in SHELLS.
    #: -> bool
    def bare_shell?
      @answer["state"] == "live" && @answer["status"].nil? && !foreground_pid.nil? &&
        foreground_pid == @answer["pid"] && SHELLS.include?(program(foreground_argv.first))
    end

    # True when the foreground argv runs kind interactively: a program named kind among the first two words,
    # and for codex no later word is exec or e (flag values never are).
    #: (String kind) -> bool
    def interactive?(kind)
      argv = foreground_argv
      index = argv.first(2).index { |word| program(word) == kind }
      return false unless index
      return true unless kind == "codex"

      (argv.drop(index + 1) & %w[exec e]).empty?
    end

    private

    #: -> Hash[String, untyped]
    def foreground
      value = @answer["foreground"]
      value.is_a?(Hash) ? value : {}
    end

    #: (String? word) -> String?
    def program(word)
      File.basename(word.to_s).delete_prefix("-")
    end
  end

  # One herdr-core session, reached through hc with HC_SESSION set to its name.
  class Core
    NAME = /\A[a-z0-9][a-z0-9_-]{0,31}\z/

    # The name from <dir>/<core>/<core>.sock; Refusal for any other shape.
    #: (String? socket_path) -> Core
    def self.of_socket(socket_path)
      name = File.basename(socket_path.to_s, ".sock")
      unless File.basename(socket_path.to_s) == "#{name}.sock" && File.basename(File.dirname(socket_path.to_s)) == name &&
             NAME.match?(name)
        raise Refusal, "no core named by socket #{socket_path.inspect}"
      end

      new(name)
    end

    attr_reader :name #: String

    # Whether something listens on <state>/herdr-core/<name>/<name>.sock. Asks the socket, never hc: hc starts a stopped core.
    #: -> bool
    def running?
      state = ENV.fetch("XDG_STATE_HOME", "")
      UNIXSocket.open(File.join(state.empty? ? File.expand_path("~/.local/state") : state, "herdr-core", @name, "#{@name}.sock")).close
      true
    rescue SystemCallError, ArgumentError
      false
    end

    #: (String name, ?command_line: CommandLine) -> void
    def initialize(name, command_line: CommandLine.new(core: name))
      @name = name
      @command_line = command_line
    end

    # now - uptime_ms of `hc server status --json`; Refusal without uptime_ms.
    #: (Time now) -> Time
    def started_at(now)
      uptime = @command_line.json("hc", "server", "status", "--json")["uptime_ms"]
      raise Refusal, "hc server status: no uptime_ms" unless uptime.is_a?(Numeric)

      now - (uptime / 1000.0)
    end

    # An unreadable answer gives a TerminalState that is never a bare shell.
    #: (String terminal) -> TerminalState
    def terminal(terminal)
      TerminalState.new(@command_line.json("hc", "get", terminal, "--json"))
    rescue Refusal
      TerminalState.new(nil)
    end

    # Types record's resume line into its terminal when that terminal is a bare shell, then writes resumed_at.
    # A refused send writes nothing, so a later run may retry. Answers :typed, :closed (hc get refuses),
    # :not_a_bare_shell or :send_refused.
    #: (AgentRecord record, store: RecordStore, now: Time) -> Symbol
    def resume(record, store:, now:)
      state = TerminalState.new(@command_line.json("hc", "get", record.terminal, "--json"))
      return :not_a_bare_shell unless state.address?(record.terminal) && state.bare_shell?

      type(record, store, now)
    rescue Refusal
      :closed
    end

    private

    #: (AgentRecord record, RecordStore store, Time now) -> Symbol
    def type(record, store, now)
      @command_line.text("hc", "send", record.terminal, record.resume_line)
      store.write(record.resumed(now))
      :typed
    rescue Refusal
      :send_refused
    end
  end
end
