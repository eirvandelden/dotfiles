require "find"
require "fileutils"
require "minitest"
require "tmpdir"
require_relative "isolated_git"

# Builds the git repositories of a test file once, then gives each test its own copy of them.
# The build block fills an empty directory, the original; no test gets its path. A copy is a plain
# recursive copy, so it starts no git process, and a test can change anything inside it (hooks, config,
# stash, reflog, worktrees) without touching another test. A git path in a copy that named the
# original is rewritten to name the copy. Submodules are refused, because .gitmodules holds an
# absolute URL that the rewrite does not reach.
class GitFixture
  REWRITTEN = %w[config gitdir .git].freeze #: Array[String]

  # Stores the build block; nothing builds yet. The block gets an empty real-path directory and makes
  # the repositories inside it, for example <root>/origin and <root>/repo, or one repository at <root>.
  #: () { (String root) -> void } -> void
  def initialize(&build)
    @build = build
    Minitest.after_run { remove }
  end

  # A new real-path directory that holds a copy of the original. The first call builds the original.
  # In every git `config`, `gitdir` and `.git` file of the copy, the original's path becomes the copy's
  # path. The copy is removed with the original when the test process ends.
  #: () -> String
  def copy
    original
    copy = File.realpath(Dir.mktmpdir("copy", @directory))
    FileUtils.cp_r("#{@original}/.", copy, preserve: true)
    repoint(copy)
    copy
  end

  private

  # Memoized only after the block and the submodule guard pass; a failure removes the partial directory.
  def original
    return @original if @original

    @directory = File.realpath(Dir.mktmpdir("git-fixture"))
    @original = File.join(@directory, "original")
    FileUtils.mkdir(@original)
    @build.call(@original)
    refuse_submodules
    @original
  rescue StandardError
    remove
    @original = nil
    raise
  end

  def refuse_submodules
    pattern = File.join(@original, "**", "{.gitmodules,.git/modules}")
    return if Dir.glob(pattern, File::FNM_DOTMATCH).empty?

    raise("a git fixture cannot hold a submodule: .gitmodules names an absolute URL that a copy keeps")
  end

  def repoint(copy)
    path = /#{Regexp.escape(@original)}(?=\/|$)/
    Find.find(copy) do |entry|
      next unless File.file?(entry) && REWRITTEN.include?(File.basename(entry))

      text = File.binread(entry)
      moved = text.gsub(path) { copy }
      File.binwrite(entry, moved) unless moved == text
    end
  end

  def remove
    return unless @directory && File.exist?(@directory)

    FileUtils.chmod_R("u+w", @directory)
    FileUtils.rm_rf(@directory)
  end
end
