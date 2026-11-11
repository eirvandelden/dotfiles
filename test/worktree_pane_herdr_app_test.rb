#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "git_fixture"
require_relative "herdr_app_harness"
require_relative "isolated_git"

# In a herdr-app terminal (HC_TERMINAL_ID set, HERDR_ENV not 1) worktree-pane hands its work to
# herdr-app-pane: open runs `herdr-app-pane open <path> --worktree`, close runs `herdr-app-pane close-at <path>`,
# and label does nothing. Most tests use the logging herdr-app-pane stub; the worktree-create test runs the real
# CLI against stub herdr-app and hc. HC_TERMINAL_ID is set in the child environment only.
class WorktreePaneHerdrAppTest < Minitest::Test
  include HerdrAppHarness
  include HerdrAppHarness::Fixtures

  TOOLS = File.join(REPO_ROOT, "git/.config/git/worktree-tools")
  PANE = File.join(TOOLS, "worktree-pane")
  CREATE = File.join(TOOLS, "worktree-create")

  # <root>/dotfiles with one empty commit and a linked worktree on feature at <root>/worktree; <root>/origin.git,
  # a bare origin of <root>/clone, whose .worktrees is excluded.
  REPOSITORIES = GitFixture.new do |root|
    git = ->(*arguments) { system("git", "-c", "core.hooksPath=/dev/null", "-c", "user.email=test@example.com",
                                  "-c", "user.name=Test", *arguments, exception: true) }
    repo = File.join(root, "dotfiles")
    git.call("init", "--quiet", "--initial-branch=main", repo)
    git.call("-C", repo, "commit", "--quiet", "--allow-empty", "-m", "initial")
    git.call("-C", repo, "worktree", "add", "--quiet", "-b", "feature", File.join(root, "worktree"))
    git.call("init", "--quiet", "--bare", "--initial-branch=main", File.join(root, "origin.git"))
    git.call("-C", repo, "push", "--quiet", File.join(root, "origin.git"), "main")
    git.call("clone", "--quiet", File.join(root, "origin.git"), File.join(root, "clone"))
    File.write(File.join(root, "clone", ".git", "info", "exclude"), ".worktrees\n")
  end

  def setup
    @root = REPOSITORIES.copy
    @worktree = File.realpath(File.join(@root, "worktree"))
    herdr_app_setup(default_world(cwd: File.realpath(@root)))
    herdr_app_install("gh", "#!/bin/sh\nexit 1\n")
  end

  def teardown
    herdr_app_teardown
    FileUtils.rm_rf(@root)
  end

  def test_worktree_create_opens_a_pane_rooted_in_the_new_worktree
    clone = File.realpath(File.join(@root, "clone"))
    shell_log = File.join(@root, "shell.log")
    env = herdr_app_env(pane_cli: PANE_CLI).merge("SHELL" => login_shell(shell_log), "HOME" => @root,
                                                  "XDG_STATE_HOME" => File.join(@root, "state"))

    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, CREATE, "feature", chdir: clone)

    assert(status.success?, stderr)
    worktree = File.join(clone, ".worktrees", "feature")
    assert_equal(worktree, stdout.strip)
    split = herdr_app_only_split
    assert_equal(%w[p10 down], split.values_at("pane", "direction"))
    Open3.capture2e({ "SHELL" => env.fetch("SHELL") }, *split["argv"])
    assert_equal([ "-l", worktree ], File.readlines(shell_log, chomp: true))
  end

  def test_herdr_env_keeps_the_herdr_path
    herdr_log = File.join(@root, "herdr.log")
    herdr_app_install("herdr", <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> #{herdr_log.inspect}
      case "$1 $2" in
        "pane list") echo '{"result":{"panes":[]}}' ;;
        "pane split") echo '{"result":{"pane":{"pane_id":"w1:pV"}}}' ;;
        *) echo '{"result":{}}' ;;
      esac
    SH

    _, stderr, status = worktree_pane("open", @worktree, env: { "HERDR_ENV" => "1", "HERDR_WORKSPACE_ID" => "w1" })

    assert(status.success?, stderr)
    assert_includes(File.readlines(herdr_log, chomp: true),
                    "pane split --current --direction down --cwd #{@worktree} --no-focus")
    assert_empty(herdr_app_pane_cli_calls)
  end

  def test_open_runs_herdr_app_pane_open_worktree
    _, stderr, status = worktree_pane("open", @worktree)

    assert(status.success?, stderr)
    assert_equal([ [ "open", @worktree, "--worktree" ] ], herdr_app_pane_cli_calls)
  end

  def test_close_runs_close_at
    _, stderr, status = worktree_pane("close", @worktree)

    assert(status.success?, stderr)
    assert_equal([ [ "close-at", @worktree ] ], herdr_app_pane_cli_calls)
  end

  def test_label_does_nothing
    _, stderr, status = worktree_pane("label", @worktree, "t61")

    assert(status.success?, stderr)
    assert_empty(herdr_app_calls)
  end

  private

  def worktree_pane(*arguments, env: {})
    Open3.capture3(herdr_app_env.merge(env), RbConfig.ruby, PANE, *arguments)
  end

  # A login shell that records its arguments and the folder it started in.
  def login_shell(log)
    path = File.join(@root, "login-shell")
    File.write(path, "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{log.inspect}\npwd -P >> #{log.inspect}\n")
    FileUtils.chmod(0o755, path)
    path
  end
end

# The two Helpers methods behind the herdr-app branch, each read in a child ruby that gets only the environment
# the case names.
class WorktreeToolsHerdrAppHelpersTest < Minitest::Test
  LIBRARY = File.join(HerdrAppHarness::REPO_ROOT, "git/.config/git/worktree-tools/lib")

  def test_herdr_app_env_needs_hc_terminal_id_and_no_herdr_env_1
    {
      { "HC_TERMINAL_ID" => "t10" } => "true",
      { "HC_TERMINAL_ID" => "t10", "HERDR_ENV" => "0", "REX_SESSION" => "S1" } => "true",
      { "HC_TERMINAL_ID" => nil } => "false",
      { "HC_TERMINAL_ID" => "" } => "false",
      { "HC_TERMINAL_ID" => "t10", "HERDR_ENV" => "1" } => "false"
    }.each do |env, answer|
      assert_equal(answer, helper("herdr_app_env?", env), env.inspect)
    end
  end

  def test_herdr_app_pane_bin_honours_herdr_app_pane
    assert_equal("/stubs/herdr-app-pane", helper("herdr_app_pane_bin", "HERDR_APP_PANE" => "/stubs/herdr-app-pane"))
    assert_equal("herdr-app-pane", helper("herdr_app_pane_bin", "HERDR_APP_PANE" => nil))
    assert_equal("herdr-app-pane", helper("herdr_app_pane_bin", "HERDR_APP_PANE" => ""))
  end

  private

  def helper(name, env)
    environment = HerdrAppHarness::CLEARED_ENV.merge("HERDR_ENV" => nil, "REX_SESSION" => nil).merge(env)
    script = "require 'common'; include WorktreeTools::Helpers; print #{name}"
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-I", LIBRARY, "-e", script)
    assert(status.success?, stderr)
    stdout
  end
end
