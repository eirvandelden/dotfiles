require_relative "command_line"
require_relative "agent_session"
require_relative "workspace"

module HerdrAppMigration
  # Reads one herdr TUI session. It sends only `list`, `get` and `layout` requests.
  class TuiSession
    KINDS = %w[claude codex].freeze

    #: (String session, ?command_line: CommandLine) -> void
    def initialize(session, command_line: CommandLine.new)
      @session = session
      @command_line = command_line
    end

    #: -> Array[Workspace]
    def workspaces
      rows = read("workspace", "list").fetch("workspaces")
      refuse_duplicates(rows)
      rows.map { |workspace| build(workspace) }
    end

    #: -> Hash[String, AgentSession]
    def running_agents
      agents = read("agent", "list").fetch("agents").select { |agent| KINDS.include?(agent["agent"]) }
      agents.filter_map { |agent| session_of(agent) }.to_h
    end

    private

    def read(*words)
      @command_line.json("herdr", "--session", @session, *words).fetch("result")
    end

    def refuse_duplicates(rows)
      label = rows.map { |workspace| workspace["label"] }.tally.find { |_label, count| count > 1 }&.first
      raise Refusal, "two workspaces are named #{label}; rename one in the TUI session first" if label
    end

    def build(workspace)
      panes = read("pane", "list", "--workspace", workspace["workspace_id"]).fetch("panes")
      tabs = read("tab", "list", "--workspace", workspace["workspace_id"]).fetch("tabs").map { |tab| tab_of(tab, panes) }
      raise Refusal, "workspace #{workspace['label']} has no tab" if tabs.empty?

      Workspace.new(workspace["label"], tabs.first.folder, tabs)
    end

    def tab_of(tab, all_panes)
      panes = all_panes.filter_map { |pane| Pane.new(pane["pane_id"], pane["cwd"]) if pane["tab_id"] == tab["tab_id"] }
      raise Refusal, "tab #{tab['label']} has no pane" if panes.empty?

      Tab.new(tab["label"], panes.first.cwd, panes, layout_of(tab, panes))
    end

    def layout_of(tab, panes)
      layout = read("pane", "layout", "--pane", panes.first.id).fetch("layout")
      rects = layout.fetch("panes").to_h { |pane| [ pane["pane_id"], pane["rect"] ] }
      Layout.new(panes.map { |pane| [ pane.id, rects[pane.id] ] }, label: tab["label"])
    end

    def session_of(agent)
      session = agent["agent_session"]
      return unless session && session["kind"] == "id"

      [ agent["pane_id"], AgentSession.new(agent["agent"], session["value"], agent["cwd"]) ]
    end
  end
end
