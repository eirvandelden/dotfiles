#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "git_gem_fixture"

# Git exports GIT_DIR to hooks, and lefthook passes it to every job. A gem installed from git can run
# git while Bundler loads its gemspec, so every job that loads the bundle must clear GIT_DIR first
# (see LefthookRubocopGitGemTest for the bug itself). The real tools (brakeman, erb_lint, rails, ...)
# are not installed in CI, so small probe executables stand in for them. Each probe loads the bundle
# through real Bundler, as the real tool does, and records that it got through. Git, the global hook
# shims, lefthook and Bundler are real.
class LefthookBundlerGitGemTest < Minitest::Test
  include GitGemFixture

  PROBES = %w[brakeman erb_lint bundler-audit rubocop rails bi].freeze
  BIN_PROBES = %w[rails rspec].freeze
  PROBE_SCRIPT = <<~'RUBY'.freeze
    #!/usr/bin/env ruby
    require "bundler/setup"
    File.write(ENV.fetch("PROBE_LOG"), "#{File.basename($PROGRAM_NAME)} #{ARGV.join(" ")}\n", mode: "a")
  RUBY
  LEFTHOOK_WRAPPER = "#!/bin/sh\nexec \"%s\" \"$@\"\n".freeze
  LOCKFILE_CHANGE = "\n".freeze
  MAIN_CHECKOUT_BRANCH = "main-checkout-feature".freeze
  MIGRATION = "db/migrate/20260101000000_add_things.rb".freeze
  MINITEST_FILES = { "app/models/thing.rb" => "class Thing; end\n", "test/models/thing_test.rb" => "# test\n" }.freeze
  RSPEC_FILES = { "app/models/thing.rb" => "class Thing; end\n", "spec/models/thing_spec.rb" => "# spec\n" }.freeze

  def setup
    setup_git_gem_fixture
    @probe_log = File.join(@tmpdir, "probe.log")
    write_probes
  end

  def teardown
    teardown_git_gem_fixture
  end

  def test_the_fixture_reproduces_the_bug_when_git_dir_leaks
    git_dir = git("rev-parse", "--absolute-git-dir").first.strip
    output, status = Open3.capture2e(hook_env("GIT_DIR" => git_dir), "brakeman", chdir: @worktree_dir)

    refute_predicate(status, :success?, "A probe passed with GIT_DIR set, the fixture no longer reproduces the bug")
    assert_match(/Could not find house-style/, output)
    assert_empty(probe_runs)
  end

  def test_brakeman_loads_the_bundle_when_pushing_from_a_linked_worktree
    commit_files({ "Gemfile" => "#{gemfile}# changed\n" })
    output, status = push

    assert_pushed(output, status)
    assert_probe_ran("brakeman")
    assert_probe_ran("bundler-audit")
  end

  def test_erb_lint_loads_the_bundle_when_committing_from_a_linked_worktree
    output, status = commit_files({ "app/views/show.html.erb" => "<p>hi</p>\n" }, hooks: true)

    assert_predicate(status, :success?, "Expected the commit to pass:\n#{output}")
    assert_probe_ran("erb_lint")
  end

  def test_erb_lint_loads_the_bundle_when_pushing_from_a_linked_worktree
    commit_files({ "app/views/show.html.erb" => "<p>hi</p>\n" })
    output, status = push

    assert_pushed(output, status)
    assert_probe_ran("erb_lint")
  end

  def test_minitest_loads_the_bundle_when_pushing_from_a_linked_worktree
    commit_files(MINITEST_FILES)
    output, status = push

    assert_pushed(output, status)
    assert_probe_ran("rails test test/models/thing_test.rb")
  end

  def test_rspec_loads_the_bundle_when_pushing_from_a_linked_worktree
    commit_files(RSPEC_FILES)
    output, status = push

    assert_pushed(output, status)
    assert_probe_ran("rspec spec/models/thing_spec.rb")
  end

  def test_a_pull_that_changes_the_lockfile_runs_bi_with_the_bundle_loaded
    push_from_another_clone("feature", "Gemfile.lock" => lockfile_with_change)
    pull

    assert_probe_ran("bi")
  end

  def test_a_pull_that_adds_a_migration_runs_rails_with_the_bundle_loaded
    push_from_another_clone("feature", MIGRATION => "# migration\n")
    pull

    assert_probe_ran("rails db:migrate")
  end

  def test_a_rebasing_pull_that_changes_the_lockfile_runs_bi_with_the_bundle_loaded
    commit_files({ "local.txt" => "local\n" })
    push_from_another_clone("feature", "Gemfile.lock" => lockfile_with_change)
    pull("--rebase")

    assert_probe_ran("bi")
  end

  def test_a_rebasing_pull_that_adds_a_migration_runs_rails_with_the_bundle_loaded
    commit_files({ "local.txt" => "local\n" })
    push_from_another_clone("feature", MIGRATION => "# migration\n")
    pull("--rebase")

    assert_probe_ran("rails db:migrate")
  end

  def test_erb_lint_loads_the_bundle_when_committing_from_the_main_checkout
    switch_main_checkout_to_its_own_branch
    output, status = commit_files({ "app/views/show.html.erb" => "<p>hi</p>\n" }, hooks: true, dir: @project_dir)

    assert_predicate(status, :success?, "Expected the commit to pass:\n#{output}")
    assert_probe_ran("erb_lint")
  end

  def test_the_pre_push_bundler_jobs_pass_in_the_main_checkout
    switch_main_checkout_to_its_own_branch
    commit_files({ "Gemfile" => "#{gemfile}# changed\n", "app/views/show.html.erb" => "<p>hi</p>\n" }.merge(MINITEST_FILES)
      .merge(RSPEC_FILES), dir: @project_dir)
    output, status = push(@project_dir, MAIN_CHECKOUT_BRANCH)

    assert_pushed(output, status, dir: @project_dir, branch: MAIN_CHECKOUT_BRANCH)
    [ "brakeman", "bundler-audit", "erb_lint", "rails test", "rspec" ].each { |run| assert_probe_ran(run) }
  end

  def test_a_pull_in_the_main_checkout_runs_bi_and_rails_with_the_bundle_loaded
    switch_main_checkout_to_its_own_branch
    push_from_another_clone(MAIN_CHECKOUT_BRANCH, "Gemfile.lock" => lockfile_with_change, MIGRATION => "# migration\n")
    pull(dir: @project_dir)

    assert_probe_ran("bi")
    assert_probe_ran("rails db:migrate")
  end

  def test_a_rebasing_pull_in_the_main_checkout_runs_bi_and_rails_with_the_bundle_loaded
    switch_main_checkout_to_its_own_branch
    commit_files({ "local.txt" => "local\n" }, dir: @project_dir)
    push_from_another_clone(MAIN_CHECKOUT_BRANCH, "Gemfile.lock" => lockfile_with_change, MIGRATION => "# migration\n")
    pull("--rebase", dir: @project_dir)

    assert_probe_ran("bi")
    assert_probe_ran("rails db:migrate")
  end

  private

  def project_files
    super.merge(
      "config/application.rb" => "# a Rails application\n",
      "bin/rails" => PROBE_SCRIPT,
      "bin/rspec" => PROBE_SCRIPT
    )
  end

  def write_probes
    @probe_dir = File.join(@tmpdir, "probes")
    PROBES.each { |name| write_files(@probe_dir, "bin/#{name}" => PROBE_SCRIPT) }
    write_files(@probe_dir, "bin/lefthook" => format(LEFTHOOK_WRAPPER, NATIVE_LEFTHOOK))
    @probe_dir = File.join(@probe_dir, "bin")
  end

  def hook_env(extra = {})
    path = [ @probe_dir, ENV.fetch("PATH") ].compact.join(File::PATH_SEPARATOR)
    super({ "PATH" => path, "PROBE_LOG" => @probe_log }.merge(extra))
  end

  def probe_runs
    File.exist?(@probe_log) ? File.readlines(@probe_log, chomp: true) : []
  end

  def assert_probe_ran(command)
    assert(probe_runs.any? { |run| run.start_with?(command) }, "No probe ran #{command.inspect}. Runs: #{probe_runs}")
  end

  def assert_pushed(output, status, dir: @worktree_dir, branch: "feature")
    assert_predicate(status, :success?, "Expected the push to pass:\n#{output}")
    refute_includes(output, "can no longer be found")
    assert_equal(head(dir), git("ls-remote", "origin", branch, chdir: dir).first.split.first)
  end

  def head(dir = @worktree_dir)
    git("rev-parse", "HEAD", chdir: dir).first.strip
  end

  def commit_files(files, dir: @worktree_dir, hooks: false)
    write_files(dir, files)
    git("add", ".", hooks: false, chdir: dir)
    git("commit", "--quiet", "-m", "Change", hooks: hooks, chdir: dir)
  end

  def push(dir = @worktree_dir, branch = "feature")
    git("push", "origin", branch, chdir: dir)
  end

  def pull(*args, dir: @worktree_dir)
    git("pull", "--quiet", *args, chdir: dir)
  end

  def switch_main_checkout_to_its_own_branch
    run!("git", "switch", "--quiet", "-c", MAIN_CHECKOUT_BRANCH, chdir: @project_dir)
    run!("git", "push", "--quiet", "--set-upstream", "origin", MAIN_CHECKOUT_BRANCH, chdir: @project_dir)
  end

  def push_from_another_clone(branch, files)
    other = File.join(@tmpdir, "other")
    run!("git", "clone", "--quiet", "--branch", branch, File.join(@tmpdir, "origin.git"), other)
    write_files(other, files)
    run!("git", "add", ".", chdir: other)
    run!("git", "commit", "--quiet", "-m", "Upstream change", chdir: other)
    run!("git", "push", "--quiet", "origin", branch, chdir: other)
  end

  def lockfile_with_change
    File.read(File.join(@worktree_dir, "Gemfile.lock")) + LOCKFILE_CHANGE
  end
end
