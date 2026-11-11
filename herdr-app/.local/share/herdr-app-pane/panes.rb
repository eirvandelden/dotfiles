require "json"
require_relative "command_line"
require_relative "row_record"

module HerdrAppPane
  # One `hc get` answer; an unreadable one runs no agent and shows no folder. hc's top-level cwd is the folder the
  # terminal was spawned in; foreground.cwd is where its program runs.
  class Terminal
    AGENTS = %w[claude-code codex].freeze

    #: (String? path) -> String?
    def self.real(path)
      path && File.realpath(path)
    rescue SystemCallError
      nil
    end

    #: (untyped answer) -> void
    def initialize(answer)
      @answer = answer.is_a?(Hash) ? answer : {}
    end

    #: -> bool
    def agent?
      status = @answer["status"]
      status.is_a?(Hash) && AGENTS.include?(status["app"])
    end

    # True when the terminal's real folder is target, a real path.
    #: (String? target) -> bool
    def at?(target)
      !target.nil? && Terminal.real(@answer.dig("foreground", "cwd") || @answer["cwd"]) == target
    end
  end

  # The herdr-app window and its core, as Panes sees them: the only pipeline code that sends `herdr-app ls` or
  # `herdr-app do`. Addresses repeat across cores, so a space is found by the space id `hc get` labels a
  # terminal with, and `herdr-app ls` is narrowed to that space before any address is matched.
  class Window
    FOCUS_KEY = "focused_pane".freeze

    #: (CommandLine command_line) -> void
    def initialize(command_line)
      @command_line = command_line
    end

    # The terminals listed in the space of terminal, across its tabs: {"terminal","pane","status","app",...}.
    #: (String terminal) -> Array[Hash[String, untyped]]
    def space_of(terminal)
      id = @command_line.json("hc", "get", terminal, "--json").dig("labels", "herdr.space")
      space = @command_line.json("herdr-app", "ls").fetch("spaces", []).find { |candidate| candidate["id"] == id }
      raise Refusal, "herdr-app lists no space for #{terminal}" unless space

      space.fetch("tabs", []).flat_map { |tab| tab.fetch("terminals", []) }
    end

    #: (String address) -> Terminal
    def terminal(address)
      Terminal.new(@command_line.json("hc", "get", address, "--json"))
    rescue Refusal
      Terminal.new(nil)
    end

    # Polls hc every HERDR_APP_READY_POLL seconds until the terminal runs an agent; false after seconds.
    #: (String address, Float seconds) -> bool
    def await_agent(address, seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      until terminal(address).agent?
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep(Float(ENV.fetch("HERDR_APP_READY_POLL", "1")))
      end
      true
    end

    #: -> String?
    def focused
      @command_line.json("herdr-app", "status")[FOCUS_KEY]
    end

    # Answers {"pane","terminal"} of the new pane.
    #: (String anchor, String direction, Array[String] argv) -> Hash[String, String]
    def split(anchor, direction, argv)
      act("pane.split", "pane" => anchor, "direction" => direction, "argv" => argv)
    end

    #: (String pane) -> void
    def focus(pane)
      act("pane.focus", "pane" => pane)
    end

    #: (String pane) -> void
    def close(pane)
      act("pane.close", "pane" => pane)
    end

    private

    #: (String name, Hash[String, untyped] request) -> untyped
    def act(name, request)
      @command_line.json("herdr-app", "do", name, JSON.generate(request))
    end
  end

  # Places and closes herdr-app panes beside the coordinator, in the coordinator's space.
  class Panes
    PLACEMENTS = %i[column new_row unlisted worktree].freeze
    STAGES = %i[column new_row].freeze
    CLOSABLE = %w[idle done].freeze
    # Starts the command in its folder, or not at all.
    ROOTED = 'cd "$1" || exit 1; shift; exec "$@"'.freeze

    #: (?own: String, ?coordinator: String?, ?common_dir: String?, ?command_line: CommandLine) -> void
    def initialize(own: ENV.fetch("HC_TERMINAL_ID"), coordinator: ENV.fetch("HERDR_APP_COORDINATOR", nil),
                   common_dir: nil, command_line: CommandLine.new)
      @own = own
      @coordinator = coordinator.to_s.empty? ? own : coordinator
      @common_dir = common_dir
      @window = Window.new(command_line)
    end

    # Opens a pane rooted in cwd that runs command, or a login shell when command is empty, and answers its
    # terminal address. column: right of the row's last live pane, else right of the coordinator; new_row: below
    # the coordinator; unlisted: placed like column, never recorded; worktree: below the coordinator, nil when a
    # pane of the space already shows cwd. Focus goes back where it was. A column or new_row pane is recorded and
    # waits until hc shows an agent; with none by HERDR_APP_READY_TIMEOUT seconds it closes and raises Refusal.
    #: (String cwd, ?command: Array[String], ?row: String?, ?placement: Symbol) -> String?
    def open(cwd, command: [], row: nil, placement: :column)
      raise ArgumentError, "unknown placement #{placement}" unless PLACEMENTS.include?(placement)

      panes = @window.space_of(@coordinator)
      return if placement == :worktree && shown?(panes, cwd)

      opened = split(anchors(panes, row, placement), direction(placement), rooted(cwd, command))
      settle(opened, row && record(row)) if STAGES.include?(placement)
      opened.fetch("terminal")
    end

    # Closes the pane that shows terminal (default: the own terminal), whatever runs in it.
    #: (?String terminal) -> void
    def close(terminal = @own)
      @window.close(pane_of(@window.space_of(terminal), terminal))
    end

    # Closes the row's recorded panes whose agent is idle or done; keeps the own, coordinator and intent
    # terminals; then deletes the record. Best effort: warns, never raises. Answers the number closed.
    #: (String row) -> Integer
    def close_idle(row)
      row_record = record(row)
      return 0 unless row_record.exist?

      closed = idle_panes(row_record).count { |pane| close_pane(pane) }
      row_record.delete
      closed
    rescue Refusal => error
      warn("herdr-app-pane: the stage panes stay open: #{error.message}")
      0
    end

    # Closes each pane of the coordinator's space whose real cwd (foreground.cwd, else cwd) is the real cwd given,
    # and that runs no agent. Never the own or coordinator terminal. Answers the number closed.
    #: (String cwd) -> Integer
    def close_at(cwd)
      target = Terminal.real(cwd)
      @window.space_of(@coordinator).count { |entry| shell_at?(entry, target) && close_pane(entry["pane"]) }
    end

    private

    #: (String row) -> RowRecord
    def record(row)
      RowRecord.new(@common_dir ||= RowRecord.common_dir, row)
    end

    #: (Array[Hash[String, untyped]] panes, String cwd) -> bool
    def shown?(panes, cwd)
      target = Terminal.real(cwd)
      panes.any? { |entry| @window.terminal(entry["terminal"]).at?(target) }
    end

    #: (Array[Hash[String, untyped]] panes, String? row, Symbol placement) -> Array[String]
    def anchors(panes, row, placement)
      coordinator = pane_of(panes, @coordinator)
      return [ coordinator ] unless row && %i[column unlisted].include?(placement)

      listed = panes.to_h { |entry| [ entry["terminal"], entry["pane"] ] }
      row_end = record(row).terminals.reverse.filter_map { |terminal| listed[terminal] }.first
      [ row_end, coordinator ].compact.uniq
    end

    #: (Symbol placement) -> String
    def direction(placement)
      %i[new_row worktree].include?(placement) ? "down" : "right"
    end

    #: (String cwd, Array[String] command) -> Array[String]
    def rooted(cwd, command)
      shell = ENV.fetch("SHELL", "").empty? ? "/bin/sh" : ENV.fetch("SHELL")
      [ "sh", "-c", ROOTED, "sh", cwd, *(command.empty? ? [ shell, "-l" ] : command) ]
    end

    # Splits the first anchor that takes it, raising only the last anchor's refusal, then gives focus back.
    #: (Array[String] anchors, String direction, Array[String] argv) -> Hash[String, String]
    def split(anchors, direction, argv)
      focused = @window.focused
      opened = split_first(anchors, direction, argv)
      @window.focus(focused) unless focused.nil? || @window.focused == focused
      opened
    end

    #: (Array[String] anchors, String direction, Array[String] argv) -> Hash[String, String]
    def split_first(anchors, direction, argv)
      anchor, *rest = anchors
      @window.split(anchor, direction, argv)
    rescue Refusal
      raise if rest.empty?

      split_first(rest, direction, argv)
    end

    # Records a stage pane, then waits for its agent. hc keeps terminals, so a claude that fails to start leaves
    # a shell: that pane closes again, and its line leaves the record.
    #: (Hash[String, String] opened, RowRecord? row_record) -> void
    def settle(opened, row_record)
      terminal = opened.fetch("terminal")
      row_record&.append(terminal)
      return if @window.await_agent(terminal, ready_timeout)

      close_pane(opened.fetch("pane"))
      row_record&.drop(terminal)
      raise Refusal, "no agent started in #{terminal} within #{ready_timeout} s; closed its pane"
    end

    #: -> Float
    def ready_timeout
      Float(ENV.fetch("HERDR_APP_READY_TIMEOUT", "30"))
    end

    #: (RowRecord row_record) -> Array[String]
    def idle_panes(row_record)
      stale = row_record.terminals - [ @own, @coordinator, row_record.intent ]
      idle = @window.space_of(@coordinator).select { |entry| stale.include?(entry["terminal"]) && idle_agent?(entry) }
      idle.map { |entry| entry["pane"] }
    end

    #: (Hash[String, untyped] entry) -> bool
    def idle_agent?(entry)
      Terminal::AGENTS.include?(entry["app"]) && CLOSABLE.include?(entry["status"])
    end

    #: (Hash[String, untyped] entry, String? target) -> bool
    def shell_at?(entry, target)
      return false if [ @own, @coordinator ].include?(entry["terminal"]) || Terminal::AGENTS.include?(entry["app"])

      terminal = @window.terminal(entry["terminal"])
      !terminal.agent? && terminal.at?(target)
    end

    #: (Array[Hash[String, untyped]] panes, String terminal) -> String
    def pane_of(panes, terminal)
      panes.find { |entry| entry["terminal"] == terminal }&.fetch("pane") ||
        raise(Refusal, "herdr-app lists no pane for #{terminal} in its space")
    end

    # Best effort: a refusal warns and answers false.
    #: (String pane) -> bool
    def close_pane(pane)
      @window.close(pane)
      true
    rescue Refusal => error
      warn("herdr-app-pane: #{error.message}")
      false
    end
  end
end
