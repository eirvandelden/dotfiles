require_relative "panes"

module HerdrAppPane
  # Opens a herdr-app tab in the own space, whatever space has focus.
  class Tabs
    #: (?own: String, ?window: Window) -> void
    def initialize(own: ENV.fetch("HC_TERMINAL_ID"), window: Window.new)
      @own = own
      @window = window
    end

    # Opens a tab in the own space, rooted in cwd, named name when given, running command (herdr-app's default
    # shell when empty), with focus false; answers the hc address of its terminal, or nil when herdr-app names
    # none. Raises Refusal when the own space is not listed exactly once.
    #: (String cwd, ?name: String?, ?command: Array[String]) -> String?
    def open(cwd, name: nil, command: [])
      request = { "folder" => cwd, "name" => name, "argv" => command, "focus" => false }
      @window.new_tab(@window.space_address(@own), request.reject { |_key, value| value.nil? || value == [] })["terminal"]
    end
  end
end
