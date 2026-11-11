require_relative "command_line"

module HerdrAppMigration
  # The live spaces of one machine that Etienne may approve for closing.
  class StaleSpaces
    #: (String machine, ?command_line: CommandLine) -> void
    def initialize(machine, command_line: CommandLine.new)
      @machine = machine
      @command_line = command_line
    end

    #: -> Array[String]
    def listing
      lines = spaces.map { |space| line(space) }
      lines.empty? ? [ "no spaces" ] : lines
    end

    #: (Array[String] ids) -> void
    def close(ids)
      unknown = ids - spaces.map { |space| space["id"] }
      raise Refusal, "no live space has the id #{unknown.join(', ')}; nothing closed" if unknown.any?

      ids.each { |id| @command_line.json("herdr-app", "do", "space.close", JSON.generate(id: id, confirmed: true)) }
    end

    private

    def spaces
      @command_line.json("herdr-app", "ls").fetch("spaces").select { |space| space["machine"] == (@machine.empty? ? nil : @machine) }
    end

    def line(space)
      terminals = space["tabs"].flat_map { |tab| tab["terminals"] }
      [ space["id"], space["name"], space["folder"], space["tabs"].size, terminals.size,
        terminals.filter_map { |terminal| terminal["status"] }.join(",") ].join("\t")
    end
  end
end
