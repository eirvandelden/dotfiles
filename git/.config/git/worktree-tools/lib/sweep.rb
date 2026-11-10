require "common"
require "open3"
require "rbconfig"
require "tempfile"

module WorktreeTools
  # Removes the worktrees under .worktrees/ whose work has merged. Run it from the repository root.
  # Untracked files under docs/changes/ count as clean: they are local change artefacts. Git keeps
  # the final say, since the status and the removal both run with that exclusion and no --force.
  class Sweep
    include Helpers

    PANE = File.expand_path("../worktree-pane", __dir__)
    REMOVE = File.expand_path("../worktree-remove", __dir__)

    #: (String program, ?time_limit: Numeric?) -> void
    def initialize(program, time_limit: nil)
      @program = program
      @time_limit = time_limit
    end

    #: (default_branch: String, ?keep: Array[String]) -> void
    def run(default_branch:, keep: [])
      kept = keep.map { |path| File.realpath(path) }
      Dir.glob(".worktrees/*/").each do |dir|
        trimmed = dir.chomp("/")
        sweep_one(trimmed, default_branch) unless kept.include?(File.realpath(trimmed))
      end
    end

    private

    def sweep_one(dir, default_branch)
      return unless clean?(dir)

      branch = worktree_branch(dir)
      return warn("#{@program}: #{dir}: detached HEAD, left alone") if branch == "HEAD"

      state = pr_state(branch)
      return if fresh?(dir, branch, state, default_branch)

      remove_worktree(dir, branch, state) if removable?(dir, branch, state, default_branch)
    end

    def removable?(dir, branch, state, default_branch)
      return true if state == "MERGED"

      pushed_under_own_name?(dir, branch) && ancestor?(dir, branch, default_branch)
    end

    # A branch that was never pushed under its own name has no merge to wait for: origin moving
    # past it says nothing about its work.
    def pushed_under_own_name?(dir, branch)
      output, = git("-C", dir, "config", "--get", "branch.#{branch}.merge")
      output.strip == "refs/heads/#{branch}"
    end

    def clean?(dir)
      output, = git(*artefact_exclusion, "-C", dir, "status", "--porcelain")
      output.strip.empty?
    end

    def worktree_branch(dir)
      output, = git("-C", dir, "rev-parse", "--abbrev-ref", "HEAD")
      output.strip
    end

    def pr_state(branch)
      output, status = capture_output("gh", "pr", "view", branch, "--json", "state", "-q", ".state",
                                      time_limit: @time_limit)
      output.strip if status.success?
    rescue Errno::ENOENT
      nil
    end

    def fresh?(dir, branch, state, default_branch)
      return false unless state.to_s.empty?

      branch_sha(dir, branch) == branch_sha(dir, "origin/#{default_branch}")
    end

    def branch_sha(dir, ref)
      output, = git("-C", dir, "rev-parse", ref)
      output.strip
    end

    def ancestor?(dir, branch, default_branch)
      _, status = git("-C", dir, "merge-base", "--is-ancestor", branch, "origin/#{default_branch}")
      status.success?
    end

    def remove_worktree(dir, branch, state)
      close_pane(dir)
      run_worktree_remove(dir)
      git_showing_errors(*artefact_exclusion, "worktree", "remove", dir)
      git_showing_errors("branch", state == "MERGED" ? "-D" : "-d", branch)
    end

    # ["-c", "core.excludesFile=<excludes_file>"], put before every status and worktree remove call.
    def artefact_exclusion
      [ "-c", "core.excludesFile=#{excludes_file}" ]
    end

    # A temporary excludes file: the current global excludes (core.excludesFile, else
    # $XDG_CONFIG_HOME/git/ignore or ~/.config/git/ignore), then "docs/changes/". Written once per run.
    def excludes_file
      @excludes_file ||= Tempfile.new("sweep-excludes").tap do |file|
        file.puts(global_excludes)
        file.puts("docs/changes/")
        file.flush
      end
      @excludes_file.path
    end

    def global_excludes
      path = global_excludes_path
      File.exist?(path) ? File.read(path) : ""
    end

    def global_excludes_path
      configured, = git("config", "--get", "core.excludesFile")
      return File.expand_path(configured.strip) unless configured.strip.empty?

      config_home = ENV["XDG_CONFIG_HOME"].to_s.empty? ? File.join(Dir.home, ".config") : ENV["XDG_CONFIG_HOME"]
      File.join(config_home, "git", "ignore")
    end

    def git_showing_errors(*arguments)
      _output, error, status = Open3.capture3("git", *arguments)
      $stderr.print(error) unless status.success?
    end

    def close_pane(dir)
      _, stderr, = Open3.capture3(RbConfig.ruby, PANE, "close", dir)
      $stderr.print(stderr) unless stderr.empty?
    end

    def run_worktree_remove(dir)
      return unless File.executable?(REMOVE)

      Open3.capture2(RbConfig.ruby, REMOVE, dir)
    end

    def git(*arguments)
      Open3.capture2("git", *arguments, err: File::NULL)
    end
  end
end
