require "json"
require_relative "command_line"

module HerdrAppMigration
  # The ids a create command answers. herdr-app answers `pane` only to a split; `Machine` finds the
  # first pane of a new space or tab in the listing.
  Created = Data.define(
    :space,    #: String?
    :tab,      #: String?
    :pane,     #: String
    :terminal  #: String?
  )

  # One machine as herdr-app shows it, and the only sender of create commands. It has no close method.
  class Machine
    #: (String name, ?command_line: CommandLine) -> void
    def initialize(name, command_line: CommandLine.new)
      @name = name
      @command_line = command_line
      @built = []
    end

    #: (String name) -> bool
    def space?(name)
      names.include?(name) || @built.include?(name)
    end

    #: (name: String, folder: String, tab: String, argv: Array[String]) -> Created
    def new_space(name:, folder:, tab:, argv:)
      @built << name
      answer = do_command("space.new", name: name, folder: folder, tab: tab, argv: argv, machine: @name)
      incomplete(name, answer["space"]) { created(answer) }
    end

    #: (space: String, name: String, folder: String, argv: Array[String]) -> Created
    def new_tab(space:, name:, folder:, argv:)
      created(do_command("tab.new", space: space, name: name, folder: folder, argv: argv))
    end

    #: (pane: String, direction: String, argv: Array[String]) -> Created
    def split(pane:, direction:, argv:)
      answer = do_command("pane.split", pane: pane, direction: direction, argv: argv)
      Created.new(space: nil, tab: nil, pane: answer.fetch("pane"), terminal: answer["terminal"])
    rescue KeyError
      raise Refusal, "pane.split answered no pane id"
    end

    private

    def names
      @names ||= spaces.filter_map { |space| space["name"] if space["machine"] == (@name.empty? ? nil : @name) }
    end

    def spaces
      @command_line.json("herdr-app", "ls").fetch("spaces")
    end

    def do_command(command, **arguments)
      @command_line.json("herdr-app", "do", command, JSON.generate(arguments))
    end

    def incomplete(name, space)
      yield
    rescue Refusal => error
      raise Refusal, "space #{name} (#{space}) is incomplete: #{error.message}"
    end

    def created(answer)
      pane = pane_of(answer["tab"], answer["terminal"])
      Created.new(space: answer["space"], tab: answer["tab"], pane: pane, terminal: answer["terminal"])
    end

    def pane_of(tab, terminal)
      terminals = spaces.flat_map { |space| space["tabs"] }.find { |candidate| candidate["id"] == tab }&.fetch("terminals")
      pane = terminals&.find { |candidate| candidate["terminal"] == terminal }&.fetch("pane")
      pane || raise(Refusal, "herdr-app lists no pane for terminal #{terminal} of tab #{tab}")
    end
  end
end
