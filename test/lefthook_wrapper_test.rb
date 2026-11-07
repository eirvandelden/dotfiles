#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"
require_relative "lefthook_binary"
require_relative "hook_scripts"
require_relative "isolated_git"
require_relative "personal_origin"
require_relative "../claude/.claude/hooks/remote_matcher"

# The hook wrapper (git/.config/git/hooks/lefthook-wrapper) runs one git hook through lefthook. In a
# personal repository it extends the shared config with the repo config; it never leaves GIT_DIR set.
class LefthookWrapperTest < Minitest::Test
  NATIVE_LEFTHOOK = LefthookBinary.locate
  HOOKS = %w[pre-commit pre-push commit-msg prepare-commit-msg post-merge post-rewrite post-checkout].freeze
  PERSONAL_URL = "https://github.com/eirvandelden/example.git".freeze
  OTHER_URL = "https://github.com/someone-else/example.git".freeze
  OWN_JOB = "pre-commit:\n  commands:\n    own-job:\n      run: echo own >> \"$HOME/own.log\"\n".freeze

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @home = File.realpath(Dir.mktmpdir)
    @bin_dir = File.join(@home, "bin")
    @tmp = File.join(@home, "tmp")
    @log = File.join(@home, "lefthook.log")
    FileUtils.mkdir_p([ @bin_dir, @tmp ])
    install_dotfiles
  end

  def teardown
    FileUtils.rm_rf(@home)
  end

  def test_a_personal_repo_with_its_own_config_runs_shared_and_own_jobs
    skip_without_native_lefthook
    repo = make_repo(origin: PERSONAL_URL, config: OWN_JOB)
    link_lefthook(NATIVE_LEFTHOOK)

    _out, err, status = commit_conflict_markers(repo)

    refute(status.success?, "the shared no-merge-conflicts job did not run:\n#{err}")
    assert_equal("own\n", File.read(File.join(@home, "own.log")), "the repo's own job did not run")
  end

  def test_a_personal_repo_without_a_config_runs_the_shared_jobs
    skip_without_native_lefthook
    repo = make_repo(origin: PERSONAL_URL)
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = commit_conflict_markers(repo)

    refute(status.success?, "the shared no-merge-conflicts job did not run:\n#{out}#{err}")
  end

  def test_an_own_job_overrides_the_shared_job_of_the_same_name
    skip_without_native_lefthook
    override = "pre-commit:\n  commands:\n    no-merge-conflicts:\n      run: \"true\"\n"
    repo = make_repo(origin: PERSONAL_URL, config: override)
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = commit_conflict_markers(repo)

    assert(status.success?, "the shared job won over the repo's job:\n#{out}#{err}")
  end

  def test_a_pre_push_job_in_a_linked_worktree_does_not_see_git_dir
    skip_without_native_lefthook
    worktree = personal_worktree_with_a_commit
    File.write(File.join(worktree, "lefthook.yml"), "pre-push:\n  commands:\n    bundle-env:\n      run: bundle exec true\n")
    write_executable("bundle", "#!/bin/sh\necho \"GIT_DIR=${GIT_DIR-unset}\" >> \"#{@log}\"\n")
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = git(worktree, "push", "origin", "HEAD")

    assert(status.success?, "push failed:\n#{out}#{err}")
    assert_equal("GIT_DIR=unset\n", File.read(@log))
  end

  def test_every_hook_script_passes_its_own_name_and_no_auto_install
    repo = make_repo(origin: PERSONAL_URL)
    write_logging_lefthook

    HOOKS.each do |name|
      _out, err, status = Open3.capture3(hook_env, File.join(HookScripts.directory, name), "arg1", chdir: repo)

      assert(status.success?, "#{name} failed: #{err}")
    end

    assert_equal(HOOKS.map { |name| "run #{name} --no-auto-install arg1" }, logged("args"))
  end

  def test_a_repo_with_another_origin_runs_only_its_own_config
    skip_without_native_lefthook
    repo = make_repo(origin: OTHER_URL, config: OWN_JOB)
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = commit_conflict_markers(repo)

    assert(status.success?, "the shared config reached a repo that is not personal:\n#{out}#{err}")
    assert_equal("own\n", File.read(File.join(@home, "own.log")))
  end

  def test_a_repo_without_origin_runs_only_its_own_config
    skip_without_native_lefthook
    repo = make_repo(origin: nil, config: OWN_JOB)
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = commit_conflict_markers(repo)

    assert(status.success?, "the shared config reached a repo without origin:\n#{out}#{err}")
    assert_equal("own\n", File.read(File.join(@home, "own.log")))
  end

  def test_the_personal_rule_agrees_with_remote_matcher
    write_logging_lefthook
    urls = %w[
      git@github.com:eirvandelden/dotfiles.git https://github.com/eirvandelden/dotfiles ssh://git@github.com/eirvandelden/x.git
      git@github.com:someone/dotfiles.git https://github.com/eirvandelden-fork/dotfiles https://github.com/eirvandelden
      https://gitlab.com/eirvandelden/dotfiles.git
    ]

    urls.each do |url|
      File.write(@log, "")
      run_wrapper("pre-commit", repo: make_repo(origin: url))

      assert_equal(RemoteMatcher.personal?(url), logged("config").none?("unset"), "the rule differs for #{url}")
    end
  end

  def test_no_runtime_config_is_left_after_a_hook_run
    write_logging_lefthook
    repo = make_repo(origin: PERSONAL_URL)

    _out, _err, status = run_wrapper("pre-commit", repo: repo)
    failing = run_wrapper("pre-commit", repo: repo, env: { "STUB_EXIT" => "1" })

    assert(status.success?)
    refute(failing.last.success?)
    assert(logged("config").all? { |path| path.start_with?(@tmp) }, "the runtime config is outside TMPDIR")
    assert_empty(Dir.children(@tmp), "a runtime config is left behind")
  end

  def test_a_partial_commit_checks_the_temporary_index
    repo = make_repo(origin: PERSONAL_URL)
    write_logging_lefthook
    File.write(File.join(repo, "README.md"), "changed\n")
    File.write(File.join(repo, "staged.txt"), "staged\n")
    git!(repo, "add", "staged.txt")

    out, err, status = git(repo, "commit", "-m", "partial", "README.md")

    assert(status.success?, "commit failed:\n#{out}#{err}")
    assert_match(%r{/next-index-}, logged("index").first)
  end

  def test_an_inherited_lefthook_config_is_dropped_in_another_repo
    write_logging_lefthook
    repo = make_repo(origin: OTHER_URL)

    run_wrapper("pre-commit", repo: repo, env: { "LEFTHOOK_CONFIG" => "/inherited/lefthook.yml" })

    assert_equal([ "unset" ], logged("config"))
  end

  def test_a_dotfiles_worktree_runs_only_its_own_lefthook_yml
    skip_without_native_lefthook
    dotfiles = File.join(@home, "Developer", "dotfiles")
    make_repo(origin: PERSONAL_URL, path: dotfiles, commit_files: [ "lefthook.yml" ])
    worktree = File.join(dotfiles, ".worktrees", "feature")
    git!(dotfiles, "worktree", "add", "--quiet", "-b", "feature", worktree)
    File.write(File.join(worktree, "lefthook.yml"), OWN_JOB)
    link_lefthook(NATIVE_LEFTHOOK)

    out, err, status = commit_conflict_markers(worktree)

    assert(status.success?, "the dotfiles worktree also ran the main checkout's shared jobs:\n#{out}#{err}")
    assert_equal("own\n", File.read(File.join(@home, "own.log")))
  end

  def test_a_hook_without_its_wrapper_warns_to_restow_and_continues
    lonely = File.join(@home, "lonely-hooks")
    FileUtils.mkdir_p(lonely)
    FileUtils.cp(File.join(HookScripts.directory, "pre-commit"), lonely)

    out, err, status = Open3.capture3(hook_env, File.join(lonely, "pre-commit"))

    assert(status.success?, "#{out}#{err}")
    assert_match(/hooks skipped, restow the git package/, err)
  end

  def test_the_wrapper_exits_0_without_running_lefthook_when_lefthook_is_0
    write_logging_lefthook
    repo = make_repo(origin: PERSONAL_URL)

    _out, _err, status = run_wrapper("pre-commit", repo: repo, env: { "LEFTHOOK" => "0" })

    assert(status.success?)
    refute_path_exists(@log)
  end

  def test_the_wrapper_passes_stdin_through_to_lefthook
    write_logging_lefthook
    repo = make_repo(origin: PERSONAL_URL)
    stdin_log = File.join(@home, "stdin.log")

    run_wrapper("pre-push", "origin", "url", repo: repo, stdin: "refs/heads/a sha refs/heads/a sha\n",
                            env: { "STUB_STDIN" => stdin_log })

    assert_equal("refs/heads/a sha refs/heads/a sha\n", File.read(stdin_log))
  end

  def test_the_wrapper_returns_the_exit_status_of_lefthook
    write_logging_lefthook
    repo = make_repo(origin: PERSONAL_URL)

    _out, _err, status = run_wrapper("pre-commit", repo: repo, env: { "STUB_EXIT" => "7" })

    assert_equal(7, status.exitstatus)
  end

  def test_the_runtime_config_names_the_repo_config_only_when_one_exists
    write_logging_lefthook
    shared = File.join(@home, "Developer", "dotfiles", "lefthook.yml")
    with_config = make_repo(origin: PERSONAL_URL, config: OWN_JOB)
    without_config = make_repo(origin: PERSONAL_URL)

    run_wrapper("pre-commit", repo: with_config)
    with_entries = runtime_extends
    File.write(@log, "")
    run_wrapper("pre-commit", repo: without_config)

    assert_equal([ shared, File.join(with_config, "lefthook.yml") ], with_entries)
    assert_equal([ shared ], runtime_extends)
  end

  def test_the_runtime_config_leaves_out_the_shared_config_when_the_repo_config_already_extends_it
    write_logging_lefthook
    shared = File.join(@home, "Developer", "dotfiles", "lefthook.yml")
    repo = make_repo(origin: PERSONAL_URL, config: "extends:\n  - #{shared}\n")

    run_wrapper("pre-commit", repo: repo)

    assert_equal([ File.join(repo, "lefthook.yml") ], runtime_extends)
  end

  def test_the_runtime_config_quotes_a_path_holding_a_space_and_a_single_quote
    write_logging_lefthook
    repo = make_repo(origin: PERSONAL_URL, path: File.join(@home, "it's a repo"), config: OWN_JOB)

    run_wrapper("pre-commit", repo: repo)

    assert_equal(File.join(repo, "lefthook.yml"), runtime_extends.last)
  end

  private

  def skip_without_native_lefthook
    skip(LefthookBinary::MISSING_MESSAGE) unless NATIVE_LEFTHOOK
  end

  # HOME holds the shared config, the review-report stub and the PATH stubs; TMPDIR is the test's own.
  def install_dotfiles
    dotfiles = File.join(@home, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), dotfiles)
    stub = File.join(@home, ".config", "git", "worktree-tools", "review-report-fresh")
    FileUtils.mkdir_p(File.dirname(stub))
    File.write(stub, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", stub)
  end

  def hook_env(extra = {})
    { "HOME" => @home, "PATH" => "#{@bin_dir}:/usr/bin:/bin", "TMPDIR" => @tmp, "LEFTHOOK" => nil,
      "LEFTHOOK_CONFIG" => nil, "LEFTHOOK_VERBOSE" => nil, "LEFTHOOK_BIN" => nil, "GIT_DIR" => nil,
      "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com" }.merge(extra)
  end

  # A repository whose core.hooksPath is the hooks copy. `config` becomes its lefthook.yml.
  def make_repo(origin:, path: next_repo_path, config: nil, commit_files: [])
    FileUtils.mkdir_p(path)
    git!(path, "init", "--quiet", "--initial-branch=trunk")
    git!(path, "config", "core.hooksPath", HookScripts.directory)
    git!(path, "remote", "add", "origin", origin) if origin
    File.write(File.join(path, "lefthook.yml"), config) if config
    File.write(File.join(path, "README.md"), "init\n")
    git!(path, "add", "README.md", *commit_files)
    git!(path, "commit", "--quiet", "-m", "init", env: { "LEFTHOOK" => "0" })
    path
  end

  def next_repo_path
    @repo_count = @repo_count.to_i + 1
    File.join(@home, "repo#{@repo_count}")
  end

  def personal_worktree_with_a_commit
    origin = File.join(@home, PersonalOrigin::PATH)
    FileUtils.mkdir_p(origin)
    git!(origin, "init", "--bare", "--quiet")
    repo = make_repo(origin: origin)
    worktree = File.join(@home, "worktree")
    git!(repo, "worktree", "add", "--quiet", "-b", "feature", worktree)
    File.write(File.join(worktree, "feature.txt"), "feature\n")
    git!(worktree, "add", "feature.txt")
    git!(worktree, "commit", "--quiet", "-m", "feature", env: { "LEFTHOOK" => "0" })
    worktree
  end

  def commit_conflict_markers(repo)
    File.write(File.join(repo, "conflict.txt"), "<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch\n")
    git!(repo, "add", "conflict.txt")
    git(repo, "commit", "-m", "conflict")
  end

  def git(dir, *args, env: {})
    Open3.capture3(hook_env(env), "git", *args, chdir: dir)
  end

  def git!(dir, *args, env: {})
    out, err, status = git(dir, *args, env: env)
    flunk("git #{args.join(' ')} failed in #{dir}: #{out}#{err}") unless status.success?
  end

  def run_wrapper(*args, repo:, env: {}, stdin: "")
    wrapper = File.join(HookScripts.directory, "lefthook-wrapper")
    Open3.capture3(hook_env(env), wrapper, *args, chdir: repo, stdin_data: stdin)
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def link_lefthook(binary)
    write_executable("lefthook", "#!/bin/sh\nexec \"#{binary}\" \"$@\"\n")
  end

  # Logs what the wrapper hands lefthook: arguments, config, GIT_DIR, GIT_INDEX_FILE and the runtime config.
  def write_logging_lefthook
    write_executable("lefthook", <<~SH)
      #!/bin/sh
      if [ "$1" = "-h" ]; then exit 0; fi
      {
        echo "args: $*"
        echo "config: ${LEFTHOOK_CONFIG-unset}"
        echo "git_dir: ${GIT_DIR-unset}"
        echo "index: ${GIT_INDEX_FILE-unset}"
        if [ -n "$LEFTHOOK_CONFIG" ] && [ -f "$LEFTHOOK_CONFIG" ]; then sed 's/^/runtime: /' "$LEFTHOOK_CONFIG"; fi
      } >> "#{@log}"
      if [ -n "$STUB_STDIN" ]; then cat > "$STUB_STDIN"; fi
      exit "${STUB_EXIT:-0}"
    SH
  end

  def logged(key)
    File.readlines(@log, chomp: true).filter_map { |line| line.delete_prefix("#{key}: ") if line.start_with?("#{key}: ") }
  end

  def runtime_extends
    YAML.safe_load(logged("runtime").join("\n")).fetch("extends")
  end
end
