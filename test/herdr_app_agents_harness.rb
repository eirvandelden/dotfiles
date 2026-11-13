require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "socket"
require "time"
require "tmpdir"

# Stubs and fixtures for the tests of herdr-app-agents. No test that uses this file reaches a real core:
# stub `hc` and `ps` executables come first on PATH, and HC_BIN and PS_BIN name them.
#
# The stubs answer from <dir>/world.json and log every call to <dir>/calls.log as a JSON array:
# ["hc", "default", "get", "t5", "--json"] (the second word is HC_SESSION, "default" when unset) and
# ["ps", "-A", "-ww", "-o", "pid=,ppid=,args="].
#
# world.json: {"cores" => {name => {"uptime_ms", "terminals" => {id => `hc get` answer}, "refuse_send" => [ids]}},
# "ps" => [lines]}. In a ps line, $RECORDER stands for the pid of the process that called ps: the recorder.
module HerdrAppAgentsHarness
  REPO_ROOT = File.realpath("..", __dir__)
  AGENTS_CLI = File.join(REPO_ROOT, "herdr-app/.local/bin/herdr-app-agents")
  LIBRARY = File.join(REPO_ROOT, "herdr-app/.local/share/herdr-app-agents")
  CLEARED_ENV = %w[HC_TERMINAL_ID HC_TERMINAL_SOCKET HC_SESSION HC_SCOPE CLAUDECODE CODEX_THREAD_ID
                   CLAUDE_CODE_ENTRYPOINT XDG_STATE_HOME].to_h { |name| [ name, nil ] }.freeze
  CLAUDE_ID = "11111111-2222-4333-8444-555555555555".freeze
  CODEX_ID = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee".freeze
  AGENT_PID = 5001
  HOOK_PID = 5002

  # One `hc get` answer, as probed live: top-level pid, foreground.{pid,argv,cwd}, status.
  module Fixtures
    module_function

    def shell(address, cwd: "/tmp", pid: 4000 + address.delete("^0-9").to_i)
      { "address" => address, "cwd" => cwd, "state" => "live", "pid" => pid, "status" => nil,
        "foreground" => { "pid" => pid, "argv" => [ "-zsh" ], "cwd" => cwd } }
    end

    def agent(address, argv, cwd: "/tmp", app: "claude-code", pid: AGENT_PID)
      { "address" => address, "cwd" => cwd, "state" => "live", "pid" => pid,
        "status" => { "app" => app, "state" => "idle" },
        "foreground" => { "pid" => pid, "argv" => argv, "cwd" => cwd } }
    end

    def core(terminals = [], uptime_ms: 60_000)
      { "uptime_ms" => uptime_ms, "terminals" => terminals.group_by { |terminal| terminal["address"] }.transform_values(&:first) }
    end

    # The hook chain of the plan: recorder → sh → the pane's agent.
    def hook_chain(agent_command = "claude")
      [ "$RECORDER #{HOOK_PID} ruby herdr-app-agents record claude",
        "#{HOOK_PID} #{AGENT_PID} /bin/sh -c herdr-app-agents record claude || true",
        "#{AGENT_PID} 1 #{agent_command}" ]
    end
  end

  STUB_SOURCE = <<~'RUBY'.freeze
    #!/usr/bin/env -S ruby --disable-gems
    require "json"
    directory = ENV.fetch("AGENTS_STUB_DIR")
    world = JSON.parse(File.read(File.join(directory, "world.json")))
    tool = File.basename($0)
    core = ENV.fetch("HC_SESSION", "default")
    File.open(File.join(directory, "calls.log"), "a") do |log|
      log.puts(JSON.generate(tool == "hc" ? [ tool, core, *ARGV ] : [ tool, *ARGV ]))
    end
    if tool == "ps"
      puts(world.fetch("ps", []).map { |line| line.gsub("$RECORDER", Process.ppid.to_s) })
      exit
    end
    state = world.dig("cores", core) or abort("hc: no core #{core}")
    case ARGV.first(2)
    in [ "server", "status" ] then puts(JSON.generate("uptime_ms" => state["uptime_ms"]))
    in [ "get", address ]
      answer = state["terminals"][address] or abort("hc: no terminal #{address}")
      puts(JSON.generate(answer))
    in [ "send", address ] then exit(state.fetch("refuse_send", []).include?(address) ? 1 : 0)
    else abort("hc: unknown command #{ARGV.first}")
    end
  RUBY

  def agents_setup(world = { "cores" => { "default" => Fixtures.core } })
    @agents_dir = Dir.mktmpdir("agents-stub", "/tmp") # short: a unix socket path holds about 100 characters
    @agents_listeners = {}
    @agents_bin = File.join(@agents_dir, "bin")
    @agents_state = File.join(@agents_dir, "state")
    FileUtils.mkdir_p([ @agents_bin, @agents_state ])
    %w[hc ps].each { |name| agents_install(name) }
    agents_world_write(world)
    agents_core_listen("default")
  end

  # A running core is a socket something listens on, at <state>/herdr-core/<core>/<core>.sock.
  def agents_core_listen(core)
    @agents_listeners[core] ||= begin
      FileUtils.mkdir_p(File.join(@agents_state, "herdr-core", core))
      UNIXServer.new(File.join(@agents_state, "herdr-core", core, "#{core}.sock"))
    end
  end

  def agents_teardown
    @agents_listeners&.each_value(&:close)
    FileUtils.rm_rf(@agents_dir) if @agents_dir
  end

  def agents_install(name)
    path = File.join(@agents_bin, name)
    File.write(path, STUB_SOURCE)
    FileUtils.chmod(0o755, path)
  end

  def agents_world_write(world)
    File.write(File.join(@agents_dir, "world.json"), JSON.generate(world))
  end

  # The environment of a herdr-app terminal, with hc and ps as stubs and the state folder in the tmpdir.
  def agents_env(extra = {})
    CLEARED_ENV.merge(
      "PATH" => "#{@agents_bin}:#{ENV.fetch('PATH')}", "AGENTS_STUB_DIR" => @agents_dir,
      "HC_BIN" => File.join(@agents_bin, "hc"), "PS_BIN" => File.join(@agents_bin, "ps"),
      "XDG_STATE_HOME" => @agents_state
    ).merge(extra)
  end

  # [stdout, stderr, status]
  def agents_cli(*arguments, stdin: "", env: {})
    Open3.capture3(agents_env(env), RbConfig.ruby, AGENTS_CLI, *arguments, stdin_data: stdin)
  end

  def agents_calls
    path = File.join(@agents_dir, "calls.log")
    File.exist?(path) ? File.readlines(path, chomp: true).map { |line| JSON.parse(line) } : []
  end

  # Every `hc send`, as [core, terminal, text].
  def agents_sends
    agents_calls.select { |call| call[0] == "hc" && call[2] == "send" }.map { |call| call.values_at(1, 3, 4) }
  end

  def agents_store
    File.join(@agents_state, "herdr-app/agents")
  end

  def agents_record_path(core, terminal)
    File.join(agents_store, core, "#{terminal}.json")
  end

  # Writes a record file as the recorder would, and a transcript whose mtime is transcript_age seconds ago.
  # Pass transcript_age: nil for a record with no transcript on disk.
  def agents_write_record(terminal:, session_id:, core: "default", kind: "claude", cwd: "/tmp/project",
                          transcript_age: 120, recorded_age: 3600, core_running: true, **overrides)
    agents_core_listen(core) if core_running
    transcript = File.join(@agents_dir, "#{session_id}.jsonl")
    agents_touch(transcript, transcript_age) if transcript_age
    record = { "core" => core, "terminal" => terminal, "kind" => kind, "session_id" => session_id, "cwd" => cwd,
               "transcript_path" => transcript, "flags" => [], "recorded_at" => (Time.now - recorded_age).utc.iso8601(3),
               "resumed_at" => nil }.merge(overrides.transform_keys(&:to_s))
    FileUtils.mkdir_p(File.dirname(agents_record_path(core, terminal)))
    File.write(agents_record_path(core, terminal), JSON.generate(record))
    record
  end

  def agents_touch(path, age)
    File.write(path, "{}\n")
    File.utime(Time.now - age, Time.now - age, path)
  end

  def agents_session_payload(session_id, transcript_path = File.join(@agents_dir, "transcript.jsonl"))
    JSON.generate("session_id" => session_id, "transcript_path" => transcript_path, "cwd" => "/tmp",
                  "hook_event_name" => "SessionStart", "source" => "startup")
  end
end
