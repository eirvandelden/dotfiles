require "fileutils"
require "json"
require "tmpdir"

# Stubs and fixtures for the tests of herdr-app as a pane backend. No test that uses this file reaches
# the real herdr-app or hc: stub `herdr-app`, `hc` and `herdr-app-pane` executables come first on PATH, and
# HERDR_APP_BIN, HC_BIN and HERDR_APP_PANE name them. HC_TERMINAL_ID is set only in the child
# environment herdr_app_env builds.
#
# One World holds the state of a herdr-app window: its spaces, the focused pane, the `hc get` answer of
# each terminal. The stub executables load it from <dir>/world.json, answer, and write it back; an in-process
# FakeCommandLine answers from the same World. Every call lands in <dir>/calls.log as a JSON array,
# the tool first: ["herdr-app", "do", "pane.split", "{...}"], ["hc", "get", "t10", "--json"].
#
# Every JSON shape the tests rely on lives in this file, copied from probe.md (herdr-app 0.1.15):
# - `herdr-app ls` → {"spaces":[{"id","name","machine","tabs":[{"id","terminals":[{"terminal","pane","name",
#   "status","app","sub_agents"}]}]}]}; status is idle, done, working, blocked or null; app claude-code, codex or null.
# - `herdr-app status` → {FOCUS_KEY => pane}.
# - `herdr-app do pane.split '{"pane","direction","argv"}'` → {"pane","terminal"}, and it moves focus to the new pane.
# - `herdr-app do pane.close '{"pane"}'` → {"ok":true}; `pane.focus '{"pane"}'` → {"ok":true}.
# - A refusal → {"error":"..."} on stdout, exit 1.
# - `hc get <t> --json` → {"address","cwd","state","exit_code","foreground":{"cwd","argv"},"status","labels"};
#   cwd is the spawn folder, foreground.cwd the real one; status is {"app","state"} or null; labels name
#   the herdr.space and herdr.tab ids. A claude that fails to start leaves a live shell with status null.
module HerdrAppHarness
  REPO_ROOT = File.realpath("..", __dir__)
  PANE_CLI = File.join(REPO_ROOT, "herdr-app/.local/bin/herdr-app-pane")
  PANE_LIBRARY = File.join(REPO_ROOT, "herdr-app/.local/share/herdr-app-pane")
  SCRIPTS = File.join(REPO_ROOT, "herdr-app/.config/herdr-app/scripts")
  # The variables a herdr-app terminal carries. Every test that runs a pipeline script clears them, so
  # a run inside herdr-app drives no pane of the real window.
  CLEARED_ENV = %w[HC_TERMINAL_ID HC_TERMINAL_SOCKET HC_SCOPE HERDR_APP_COORDINATOR HERDR_APP_HOME]
                .to_h { |name| [ name, nil ] }.freeze
  FOCUS_KEY = "focused_pane".freeze
  SPACE = "sp1".freeze
  TAB = "tb1".freeze
  COORDINATOR = "t10".freeze
  COORDINATOR_PANE = "p10".freeze
  FIRST_NEW_ID = 61

  # Builders for the JSON shapes above.
  module Fixtures
    module_function

    def terminal_row(terminal, pane, status: nil, app: nil)
      { "terminal" => terminal, "pane" => pane, "name" => app || "zsh", "status" => status, "app" => app,
        "sub_agents" => [] }
    end

    def agent_row(terminal, pane, status = "idle", app: "claude-code")
      terminal_row(terminal, pane, status: status, app: app)
    end

    def tab(id, *terminals)
      { "id" => id, "terminals" => terminals }
    end

    def space(id, *tabs, name: id, machine: nil)
      { "id" => id, "name" => name, "machine" => machine, "tabs" => tabs }
    end

    # One `hc get` answer. foreground_cwd defaults to cwd; pass nil for a terminal hc shows no foreground cwd for.
    def terminal(address, cwd:, foreground_cwd: cwd, status: nil, state: "live", space: SPACE, tab: TAB)
      { "address" => address, "cwd" => cwd, "state" => state, "exit_code" => nil,
        "foreground" => { "cwd" => foreground_cwd, "argv" => [ status ? status["app"] : "zsh" ] },
        "status" => status, "labels" => { "herdr.space" => space, "herdr.tab" => tab } }
    end

    def agent(state = "idle", app: "claude-code")
      { "app" => app, "state" => state }
    end

    # One personal space with the coordinator t10 (an idle claude, pane p10) and a shell t11 (pane p11), both
    # rooted in cwd. p11 has focus. A new terminal answers a working claude, as a started worker does.
    def default_world(cwd:)
      {
        "spaces" => [ space(SPACE, tab(TAB, agent_row(COORDINATOR, COORDINATOR_PANE), terminal_row("t11", "p11")),
                            name: "dotfiles") ],
        FOCUS_KEY => "p11",
        "terminals" => { COORDINATOR => [ terminal(COORDINATOR, cwd: cwd, status: agent) ],
                         "t11" => [ terminal("t11", cwd: cwd) ] },
        "new_terminal" => [ terminal("new", cwd: cwd, status: agent("working")) ],
        "split_takes_focus" => true, "refuse_split" => {}, "fail" => {}, "next_id" => FIRST_NEW_ID
      }
    end

    # Adds a terminal to the first tab of the space and gives hc an answer for it.
    def add_terminal(world, row, answer, space: SPACE)
      world["spaces"].find { |candidate| candidate["id"] == space }["tabs"].first["terminals"] << row
      world["terminals"][row["terminal"]] = [ answer ]
      world
    end
  end

  # The state of one herdr-app window and the answers it gives. A failure set under world["fail"]["herdr-app ls"]
  # (or "herdr-app do", "hc get", ...) makes that command print the message on stderr and exit 1. A pane listed
  # in world["refuse_split"] refuses a split with its message. A terminal's hc answers play in order; the last repeats.
  class World
    attr_reader :state

    def initialize(state)
      @state = state
    end

    # [stdout, stderr, exit status]
    def answer(tool, arguments)
      failure = state.fetch("fail", {}).values_at(*failure_keys(tool, arguments)).compact.first
      return [ "", "#{failure}\n", 1 ] if failure

      tool == "hc" ? hc(arguments) : herdr_app(arguments)
    end

    private

    def failure_keys(tool, arguments)
      [ "#{tool} #{arguments.first(2).join(' ')}", "#{tool} #{arguments.first}" ]
    end

    def hc(arguments)
      case arguments.first
      when "get" then terminal_answer(arguments[1])
      when "send" then [ "", "", 0 ]
      else [ "", "hc: unknown command #{arguments.first}\n", 2 ]
      end
    end

    def terminal_answer(address)
      answers = state["terminals"][address]
      return [ "", "hc: no terminal #{address}\n", 1 ] unless answers

      state["terminals"][address] = answers.drop(1) if answers.size > 1
      [ JSON.generate(answers.first), "", 0 ]
    end

    def herdr_app(arguments)
      case arguments.first
      when "ls" then ok("spaces" => state["spaces"])
      when "status" then ok(FOCUS_KEY => state[FOCUS_KEY])
      when "do" then action(arguments[1], JSON.parse(arguments[2].to_s))
      else error("unknown command #{arguments.first}")
      end
    rescue JSON::ParserError
      error("bad arguments for #{arguments[1]}")
    end

    def action(name, request)
      case name
      when "pane.split" then split(request)
      when "pane.close" then close(request["pane"])
      when "pane.focus" then focus(request["pane"])
      else error("unknown action #{name}")
      end
    end

    def split(request)
      anchor = request["pane"]
      refusal = state.fetch("refuse_split", {})[anchor]
      return error(refusal) if refusal

      space, tab = locate(anchor)
      return error("no pane \"#{anchor}\"") unless tab

      pane, terminal = take_ids
      tab["terminals"] << Fixtures.terminal_row(terminal, pane)
      state["terminals"][terminal] = state["new_terminal"].map do |answer|
        answer.merge("address" => terminal, "labels" => { "herdr.space" => space["id"], "herdr.tab" => tab["id"] })
      end
      state[FOCUS_KEY] = pane if state["split_takes_focus"]
      ok("pane" => pane, "terminal" => terminal)
    end

    def take_ids
      number = state["next_id"]
      state["next_id"] = number + 1
      [ "p#{number}", "t#{number}" ]
    end

    def close(pane)
      _space, tab = locate(pane)
      return error("no pane \"#{pane}\"") unless tab

      tab["terminals"].reject! { |row| row["pane"] == pane }
      ok("ok" => true)
    end

    def focus(pane)
      return error("no pane \"#{pane}\"") unless locate(pane).last

      state[FOCUS_KEY] = pane
      ok("ok" => true)
    end

    def locate(pane)
      state["spaces"].each do |space|
        space["tabs"].each { |tab| return [ space, tab ] if tab["terminals"].any? { |row| row["pane"] == pane } }
      end
      [ nil, nil ]
    end

    def ok(answer)
      [ JSON.generate(answer), "", 0 ]
    end

    def error(message)
      [ JSON.generate("error" => message), "", 1 ]
    end
  end

  # The entry point of the stub executables. `herdr-app` and `hc` answer from the World; `herdr-app-pane` only
  # logs and answers world["pane_cli"] ({"stdout","stderr","exit"}), by default the new terminal t61.
  module Stub
    def self.run(tool, arguments, directory)
      File.open(File.join(directory, "calls.log"), "a") { |log| log.puts(JSON.generate([ tool, *arguments ])) }
      stdout, stderr, status = File.open(File.join(directory, "world.json"), File::RDWR) do |file|
        file.flock(File::LOCK_EX)
        answer_and_save(file, tool, arguments)
      end
      $stdout.print(stdout)
      $stderr.print(stderr)
      exit(status)
    end

    def self.answer_and_save(file, tool, arguments)
      state = JSON.parse(file.read)
      return state.fetch("pane_cli", { "stdout" => "t#{FIRST_NEW_ID}\n" }).values_at("stdout", "stderr", "exit")
                  .then { |out, err, code| [ out.to_s, err.to_s, code.to_i ] } if tool == "herdr-app-pane"

      world = World.new(state)
      world.answer(tool, arguments).tap do
        file.rewind
        file.truncate(0)
        file.write(JSON.generate(world.state))
      end
    end
  end

  # Answers Panes' `json` calls in process, from a World, as HerdrAppPane::CommandLine would. Each call is
  # appended to calls, which several fakes of one test may share.
  class FakeCommandLine
    attr_reader :calls

    def initialize(state, calls = [])
      @world = World.new(state)
      @calls = calls
    end

    def json(*command)
      @calls << command
      stdout, stderr, status = @world.answer(command.first, command.drop(1))
      answer = parse(stdout)
      reason = answer["error"] if answer.is_a?(Hash)
      raise HerdrAppPane::Refusal, "#{command.join(' ')}: #{reason || stderr.strip}" if reason || !status.zero?

      answer
    end

    private

    def parse(stdout)
      JSON.parse(stdout)
    rescue JSON::ParserError
      nil
    end
  end

  STUB_SOURCE = <<~RUBY.freeze
    #!/usr/bin/env -S ruby --disable-gems
    require #{__FILE__.inspect}
    HerdrAppHarness::Stub.run(File.basename($0), ARGV, ENV.fetch("HERDR_APP_STUB_DIR"))
  RUBY

  def herdr_app_setup(world)
    @herdr_app_dir = Dir.mktmpdir("herdr-app-stub")
    @herdr_app_bin = File.join(@herdr_app_dir, "bin")
    FileUtils.mkdir_p(@herdr_app_bin)
    %w[herdr-app hc herdr-app-pane].each { |name| herdr_app_install(name, STUB_SOURCE) }
    herdr_app_world_write(world)
  end

  def herdr_app_teardown
    FileUtils.rm_rf(@herdr_app_dir) if @herdr_app_dir
  end

  # Writes an executable into the stub bin directory, first on PATH.
  def herdr_app_install(name, source)
    path = herdr_app_stub(name)
    File.write(path, source)
    FileUtils.chmod(0o755, path)
    path
  end

  def herdr_app_stub(name)
    File.join(@herdr_app_bin, name)
  end

  def herdr_app_world
    JSON.parse(File.read(File.join(@herdr_app_dir, "world.json")))
  end

  def herdr_app_world_write(world)
    File.write(File.join(@herdr_app_dir, "world.json"), JSON.generate(world))
  end

  def herdr_app_world_change
    herdr_app_world_write(herdr_app_world.tap { |world| yield(world) })
  end

  # The environment of a herdr-app terminal own, with every herdr-app executable a stub. pane_cli: the
  # herdr-app-pane to run, the stub by default; pass PANE_CLI to run the real one against the stubs.
  def herdr_app_env(own: COORDINATOR, pane_cli: herdr_app_stub("herdr-app-pane"))
    CLEARED_ENV.merge(
      "PATH" => "#{@herdr_app_bin}:#{ENV.fetch('PATH')}", "HERDR_APP_STUB_DIR" => @herdr_app_dir,
      "HERDR_APP_BIN" => herdr_app_stub("herdr-app"), "HC_BIN" => herdr_app_stub("hc"), "HERDR_APP_PANE" => pane_cli,
      "HERDR_APP_READY_POLL" => "0", "HERDR_APP_READY_TIMEOUT" => "2", "HC_TERMINAL_ID" => own,
      "HERDR_ENV" => nil, "HERDR_PANE_ID" => nil, "HERDR_WORKSPACE_ID" => nil, "REX_SESSION" => nil, "REX_BLOCK" => nil
    )
  end

  # Every logged call, as [tool, *arguments].
  def herdr_app_calls
    path = File.join(@herdr_app_dir, "calls.log")
    File.exist?(path) ? File.readlines(path, chomp: true).map { |line| JSON.parse(line) } : []
  end

  # The requests of the pane.split calls, in order.
  def herdr_app_splits
    herdr_app_actions("pane.split")
  end

  # The request of the one pane.split call; fails when there were none or several.
  def herdr_app_only_split
    splits = herdr_app_splits
    assert_equal(1, splits.size, splits.inspect)
    splits.first
  end

  def herdr_app_actions(name)
    herdr_app_calls.select { |call| call.first(3) == [ "herdr-app", "do", name ] }.map { |call| JSON.parse(call[3]) }
  end

  def herdr_app_pane_cli_calls
    herdr_app_calls.select { |call| call.first == "herdr-app-pane" }.map { |call| call.drop(1) }
  end

  def herdr_app_listed_panes
    herdr_app_world["spaces"].flat_map { |space| space["tabs"] }.flat_map { |tab| tab["terminals"] }.map { |row| row["pane"] }
  end
end
