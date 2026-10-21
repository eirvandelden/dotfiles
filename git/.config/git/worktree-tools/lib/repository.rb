require "common"
require "open3"

module WorktreeTools
  # Where a repository's main working tree is, what its default branch is, and the lock that
  # keeps one sweep or create at a time per repository.
  class Repository
    include Helpers

    #: (String program, ?time_limit: Numeric?) -> void
    def initialize(program, time_limit: nil)
      @program = program
      @time_limit = time_limit
    end

    # git worktree list's first "worktree <path>" line is the main working tree, except inside
    # a submodule, where git prints the submodule's git directory there instead (reproduced with
    # git 2.54.0) — from the submodule's own checkout and from any linked worktree of it alike.
    # That git directory's core.worktree points back at the submodule checkout, resolved
    # relative to the git directory itself, so it works from both.
    #: -> String
    def root
      output, status = git("worktree", "list", "--porcelain")
      die("#{@program}: not inside a git repository") unless status.success?

      first_line = output.lines.find { |line| line.start_with?("worktree ") }
      die("#{@program}: not inside a git repository") unless first_line

      candidate = first_line.delete_prefix("worktree ").strip
      return candidate if working_tree?(candidate)

      submodule_checkout(candidate) || toplevel
    end

    #: -> String
    def default_branch
      branch = symbolic_ref_default_branch || remote_show_default_branch
      die("#{@program}: cannot determine default branch") if branch.to_s.empty? || branch == "(unknown)"
      branch
    end

    #: -> String
    def common_dir
      output, status = git("rev-parse", "--path-format=absolute", "--git-common-dir")
      die("#{@program}: not inside a git repository") unless status.success?

      output.strip
    end

    # A pull in the main checkout reads FETCH_HEAD between its own fetch and its merge, so a
    # sweep running beside it must not rewrite that file.
    #: (String branch) -> [String, Process::Status]
    def fetch_default_branch(branch)
      capture_output("git", "fetch", "--no-write-fetch-head", "origin", branch, time_limit: @time_limit)
    end

    # Creates the lock file, so its presence shows that a sweep started.
    #: -> void
    def touch_lock
      File.open(lock_path, File::RDWR | File::CREAT) { nil }
    end

    # One sweep or create at a time per repository: another caller waits here, and says so
    # first when it has a waiting message.
    #: (?waiting_message: String?) { () -> untyped } -> untyped
    def exclusively(waiting_message: nil)
      File.open(lock_path, File::RDWR | File::CREAT) do |lock|
        wait_for(lock, waiting_message) unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        yield
      end
    end

    private

    def wait_for(lock, message)
      $stderr.puts(message) if message
      lock.flock(File::LOCK_EX)
    end

    def lock_path
      File.join(common_dir, "worktree-sweep.lock")
    end

    def working_tree?(path)
      output, status = git("-C", path, "rev-parse", "--is-inside-work-tree")
      status.success? && output.strip == "true"
    end

    def submodule_checkout(git_dir)
      output, status = git("-C", git_dir, "config", "--get", "core.worktree")
      return nil unless status.success?

      worktree = output.strip
      return nil if worktree.empty?

      File.expand_path(worktree, git_dir)
    end

    def toplevel
      toplevel, status = git("rev-parse", "--show-toplevel")
      die("#{@program}: not inside a git repository") unless status.success?

      toplevel.strip
    end

    def symbolic_ref_default_branch
      output, status = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD")
      output.strip.delete_prefix("origin/") if status.success?
    end

    def remote_show_default_branch
      output, = git("remote", "show", "origin")
      output.lines.find { |line| line.include?("HEAD branch:") }&.split(":")&.last&.strip
    end

    def git(*arguments)
      Open3.capture2("git", *arguments, err: File::NULL)
    end
  end
end
