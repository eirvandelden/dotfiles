require_relative "command_line"

module HerdrAppPane
  # The own core's machine as herdr-app shows it, and the one owner of the address rule: herdr-app addresses
  # (`work/t25`) carry a `<machine>/` prefix outside the default core; hc addresses (`t25`) never do.
  class Machine
    DEFAULT_CORE = "default".freeze

    # The machine of HC_SESSION; an empty or unset HC_SESSION, or "default", is this computer.
    #: (?Hash[String, String] env) -> Machine
    def self.own(env = ENV)
      session = env.fetch("HC_SESSION", "")
      new(session.empty? || session == DEFAULT_CORE ? nil : session)
    end

    # name: nil for this computer (the default core), else the core's name.
    #: (String? name) -> void
    def initialize(name)
      @name = name
    end

    # The name herdr-app lists as a space's "machine": nil for this computer.
    #: -> String?
    def name
      @name
    end

    # The one listed space on this machine whose hc address is label. Refuses when none, or more than one,
    # matches; a space of another machine never matches.
    #: (Array[Hash[String, untyped]] spaces, String? label) -> Hash[String, untyped]
    def space(spaces, label)
      found = spaces.select { |candidate| candidate["machine"] == @name && hc_address(candidate["id"]) == label }
      raise Refusal, "herdr-app lists no space #{label.inspect} on #{machine_name}" if found.empty?
      raise Refusal, "herdr-app lists space #{label} #{found.size} times on #{machine_name}: no single space" if found.size > 1

      found.first
    end

    # The part of a herdr-app address after its last "/"; an hc address answers itself.
    #: (String id) -> String
    def hc_address(id)
      id.split("/").last.to_s
    end

    private

    #: -> String
    def machine_name
      @name || "this computer"
    end
  end
end
