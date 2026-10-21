#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require_relative "isolated_git"

class GhDashMergeTest < Minitest::Test
  SCRIPT = File.expand_path("../github/.config/gh-dash/scripts/merge-pr.sh", __dir__)
  STUB_GH = <<~RUBY
    #!/usr/bin/env ruby
    File.write(File.join(ENV.fetch("STUB_DIR"), "gh.log"), ARGV.join(" ") + "\\n", mode: "a")
    exit Integer(ENV.fetch("STUB_GH_EXIT", "0"))
  RUBY

  def setup
    @dir = Dir.mktmpdir("gh-dash-merge")
    @git_config = File.join(@dir, "gitconfig")
    FileUtils.touch(@git_config)
    File.write(File.join(@dir, "gh"), STUB_GH)
    File.chmod(0o755, File.join(@dir, "gh"))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_merges_with_a_merge_commit_and_deletes_the_branch_without_a_setting
    _, _, status = run_script("\n")

    assert_predicate(status, :success?)
    assert_equal([ "pr merge 7 -R eirvandelden/dotfiles --merge --delete-branch" ], gh_calls)
  end

  def test_squashes_when_the_owner_says_squash
    set("pr-merge.eirvandelden.method", "squash")

    run_script("\n")

    assert_equal([ "pr merge 7 -R eirvandelden/dotfiles --squash --delete-branch" ], gh_calls)
  end

  def test_rebases_when_the_repository_says_rebase
    set("pr-merge.eirvandelden/dotfiles.method", "rebase")

    run_script("\n")

    assert_equal([ "pr merge 7 -R eirvandelden/dotfiles --rebase --delete-branch" ], gh_calls)
  end

  def test_repository_setting_wins_over_the_owner_setting
    set("pr-merge.eirvandelden.method", "squash")
    set("pr-merge.eirvandelden/dotfiles.method", "merge")

    run_script("\n")

    assert_equal([ "pr merge 7 -R eirvandelden/dotfiles --merge --delete-branch" ], gh_calls)
  end

  def test_settings_match_owner_and_repository_case_insensitively
    set("pr-merge.EirVanDelden.method", "squash")
    set("pr-merge.EirVanDelden/DotFiles.method", "rebase")

    run_script("\n")

    assert_equal([ "pr merge 7 -R eirvandelden/dotfiles --rebase --delete-branch" ], gh_calls)
  end

  def test_any_answer_other_than_enter_cancels_without_error
    stdout, _, status = run_script("n\n")

    assert_predicate(status, :success?)
    assert_includes(stdout, "Cancelled.")
    assert_empty(gh_calls)
  end

  def test_end_of_input_cancels_without_error
    stdout, _, status = run_script("")

    assert_predicate(status, :success?)
    assert_includes(stdout, "Cancelled.")
    assert_empty(gh_calls)
  end

  def test_unknown_method_fails_without_merging
    set("pr-merge.eirvandelden.method", "fastforward")

    _, stderr, status = run_script("\n")

    assert_equal(2, status.exitstatus)
    assert_includes(stderr, "merge-pr: unknown merge method 'fastforward' in pr-merge.eirvandelden.method; " \
                            "use merge, squash or rebase")
    assert_empty(gh_calls)
  end

  def test_method_without_a_value_names_its_setting_in_the_error
    File.write(@git_config, "[pr-merge \"eirvandelden\"]\n\tmethod\n")

    _, stderr, status = run_script("\n")

    assert_equal(2, status.exitstatus)
    assert_includes(stderr, "merge-pr: unknown merge method '' in pr-merge.eirvandelden.method")
    assert_empty(gh_calls)
  end

  def test_unreadable_git_config_fails_without_merging
    File.write(@git_config, "[pr-merge \"eirvandelden\"]\n\tmethod = squash\n[broken\n")

    stdout, stderr, status = run_script("\n")

    assert_equal(2, status.exitstatus)
    assert_includes(stderr, "merge-pr: cannot read the merge method from git config")
    refute_includes(stdout, "Merge ")
    assert_empty(gh_calls)
  end

  def test_prompt_names_the_pull_request_and_the_method
    set("pr-merge.eirvandelden.method", "squash")

    stdout, = run_script("n\n")

    assert_includes(stdout, "Merge eirvandelden/dotfiles#7 with squash and delete its branch? " \
                            "Enter merges, anything else cancels: ")
  end

  def test_gh_failure_is_the_script_exit_status
    _, _, status = run_script("\n", "STUB_GH_EXIT" => "4")

    assert_equal(4, status.exitstatus)
  end

  def test_passes_the_repository_with_r_so_no_local_branch_is_deleted
    run_script("\n")

    assert_includes(gh_calls.first.split, "-R")
  end

  private

  def set(key, value)
    system("git", "config", "--file", @git_config, key, value, exception: true)
  end

  def run_script(input, extra_env = {})
    env = { "PATH" => "#{@dir}:#{ENV.fetch('PATH')}", "STUB_DIR" => @dir, "GIT_CONFIG_GLOBAL" => @git_config }
    Open3.capture3(env.merge(extra_env), SCRIPT, "eirvandelden/dotfiles", "7", stdin_data: input)
  end

  def gh_calls
    log = File.join(@dir, "gh.log")
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end
end
