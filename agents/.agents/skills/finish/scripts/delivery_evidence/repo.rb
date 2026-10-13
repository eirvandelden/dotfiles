require "open3"

# Thin, argument-array wrapper around the git calls the evidence script needs.
# Every call runs in the work tree root, so pathspecs mean the same wherever
# the script starts.
class Repo
  UI_PATHS = %r{\A(?:app/views/|app/components/|app/javascript/|app/assets/|app/frontend/)}
  MIGRATION_PATHS = %r{\A(?:db/migrate/|db/[^/]*schema\.rb\z|db/structure\.sql\z)}

  attr_reader :toplevel

  def initialize(dir = Dir.pwd)
    stdout, stderr, status = Open3.capture3("git", "rev-parse", "--show-toplevel", chdir: dir)
    raise "not a git repository: #{stderr.strip}" unless status.success?

    @toplevel = stdout.strip
  end

  def capture(*args, stdin: "")
    stdout, stderr, status = try(*args, stdin: stdin)
    raise "git #{args.join(' ')} failed: #{stderr.strip}" unless status.success?

    stdout
  end

  def try(*args, stdin: "")
    Open3.capture3("git", *args, stdin_data: stdin, chdir: toplevel)
  end

  def common_dir
    capture("rev-parse", "--path-format=absolute", "--git-common-dir").strip
  end

  def head
    capture("rev-parse", "HEAD").strip
  end

  # Same resolution as review-report-fresh: origin/HEAD if it resolves, else main, else master.
  def base_branch
    stdout, _stderr, status = try("symbolic-ref", "--short", "refs/remotes/origin/HEAD")
    candidate = stdout.strip if status.success?
    return candidate if candidate && ref?(candidate)

    %w[main master].find { |name| ref?("refs/heads/#{name}") }
  end

  def ref?(ref)
    try("rev-parse", "--verify", "--quiet", ref).last.success?
  end

  # Files the branch touches against its merge-base, working tree and untracked files included.
  def branch_paths
    base = base_branch
    return [] unless base

    fork_point, _stderr, status = try("merge-base", base, "HEAD")
    return [] unless status.success?

    tracked = capture("diff", "--name-only", "-z", fork_point.strip).split("\0")
    tracked | capture("ls-files", "-z", "--others", "--exclude-standard").split("\0")
  end

  def uncommitted?(pathspecs, folder)
    capture("status", "--porcelain", "--untracked-files=all", "--", *pathspecs).lines.any? do |line|
      !line[3..].delete_prefix('"').start_with?("#{folder}/")
    end
  end
end
