require "common"
require "fileutils"
require "json"

module WorktreeTools
  # Remembers, per herdr pane, the worktree its agent created or reused last.
  class AgentWorktree
    include Helpers

    def record(pane_id, terminal_id, path)
      file = record_file(pane_id)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, JSON.generate("terminal_id" => terminal_id, "path" => path))
    end

    def usable_for(pane_id, terminal_id, beside:)
      stored = read(pane_id)
      return unless stored && stored["terminal_id"] == terminal_id

      path = stored["path"]
      path if File.directory?(path) && same_repository?(path, beside)
    end

    private

    def read(pane_id)
      stored = JSON.parse(File.read(record_file(pane_id)))
      stored if stored.is_a?(Hash) && stored["path"].is_a?(String)
    rescue SystemCallError, JSON::ParserError
      nil
    end

    def same_repository?(path, other)
      common_dir = git_common_dir(path)
      !common_dir.nil? && common_dir == git_common_dir(other)
    end

    def record_file(pane_id)
      File.join(directory, pane_id.to_s.gsub(/[^A-Za-z0-9_-]/, "_"))
    end

    def directory
      state_home = ENV["XDG_STATE_HOME"].to_s
      state_home = File.join(Dir.home, ".local", "state") if state_home.empty?
      File.join(state_home, "worktree-tools", "agent-worktrees")
    end
  end
end
