require_relative "agent_session"
require_relative "layout"
require_relative "machine"

module HerdrAppMigration
  # One herdr TUI pane next to the herdr-app pane built for it. View only, one output line.
  class Pairing < Data.define(
    :space,     #: String?
    :tab,       #: String
    :tui_pane,  #: String
    :app_pane,  #: String
    :agent      #: AgentSession?
  )
    #: -> String
    def to_s
      [ space, tab, tui_pane, app_pane, agent ? "#{agent.kind} #{agent.id} started" : "shell" ].join("\t")
    end
  end

  # One herdr TUI pane and the start command of the pane that replaces it.
  class Pane < Data.define(
    :id,  #: String
    :cwd  #: String
  )
    SHELL_IN = 'cd "$1" || exit 1; exec "${SHELL:-/bin/sh}" -l'.freeze

    # pane.split takes no folder, so a plain pane gets its login shell in its folder through sh -c.
    #: (Hash[String, AgentSession] agents) -> Array[String]
    def argv(agents)
      agents[id]&.resume_argv || [ "sh", "-c", SHELL_IN, "sh", cwd ]
    end
  end

  # One herdr TUI tab, filled into a new herdr-app tab.
  class Tab < Data.define(
    :name,    #: String
    :folder,  #: String
    :panes,   #: Array[Pane]
    :layout   #: Layout
  )
    #: (Hash[String, AgentSession] agents) -> Array[String]
    def first_argv(agents)
      pane(layout.anchor).argv(agents)
    end

    #: (Machine machine, String first_pane, Hash[String, AgentSession] agents) -> Array[Pairing]
    def fill(machine, first_pane, agents)
      apps = { layout.anchor => first_pane }
      layout.steps.each do |step|
        argv = pane(step.to).argv(agents)
        apps[step.to] = machine.split(pane: apps.fetch(step.from), direction: step.direction, argv: argv).pane
      end
      panes.map { |pane| Pairing.new(nil, name, pane.id, apps.fetch(pane.id), agents[pane.id]) }
    end

    #: (Hash[String, AgentSession] agents) -> String
    def preview(agents)
      lines = layout.steps.map { |step| "  split #{label(step.from)} #{step.direction} -> #{label(step.to)}" }
      [ "tab #{name}", *lines, *panes.map { |pane| "  #{label(pane.id)}: #{start(pane, agents)}" } ].join("\n")
    end

    private

    def pane(id)
      panes.find { |candidate| candidate.id == id }
    end

    def label(id)
      "pane #{panes.index { |candidate| candidate.id == id } + 1}"
    end

    def start(pane, agents)
      agent = agents[pane.id]
      agent ? "#{agent.kind} session #{agent.id} in #{agent.cwd}" : "login shell in #{pane.cwd}"
    end
  end

  # One herdr TUI workspace, built as a space.
  class Workspace < Data.define(
    :name,    #: String
    :folder,  #: String
    :tabs     #: Array[Tab]
  )
    #: (Machine machine, Hash[String, AgentSession] agents) -> Array[Pairing]
    def migrate_to(machine, agents)
      return [] if machine.space?(name)

      created = machine.new_space(name: name, folder: folder, tab: tabs.first.name, argv: tabs.first.first_argv(agents))
      build(machine, created, agents)
    end

    # The declarative plan for --dry-run: no ids, so it can be printed before anything exists.
    #: (Hash[String, AgentSession] agents) -> String
    def preview(agents)
      [ "space #{name} (#{folder})", *tabs.map { |tab| tab.preview(agents) } ].join("\n")
    end

    private

    def build(machine, created, agents)
      first, *rest = tabs
      pairings = first.fill(machine, created.pane, agents)
      rest.each { |tab| pairings += further(machine, created.space, tab, agents) }
      pairings.map { |pairing| pairing.with(space: name) }
    rescue Refusal => error
      raise Refusal, "space #{name} (#{created.space}) is incomplete: #{error.message}"
    end

    def further(machine, space, tab, agents)
      created = machine.new_tab(space: space, name: tab.name, folder: tab.folder, argv: tab.first_argv(agents))
      tab.fill(machine, created.pane, agents)
    end
  end
end
