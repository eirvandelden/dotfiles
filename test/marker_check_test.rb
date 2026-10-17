#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"
require_relative "isolated_git"

# marker-check <word> <file>...: exits 1 and prints path:line:text for each file that holds the word,
# and skips vendored files. The marker word is built by concatenation, so this file passes the marker checks.
class MarkerCheckTest < Minitest::Test
  SCRIPT = File.expand_path("../git/.config/git/worktree-tools/marker-check", __dir__)
  WORD = "FIX" + "ME"
  OTHER_WORD = "NO" + "COMMIT"
  REPO_ROOT = File.expand_path("..", __dir__)

  def setup
    @repo = Dir.mktmpdir
    init_repository
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_reports_a_marker_with_path_and_line_and_exits_1
    write("notes.txt", "fine\n# #{WORD} later\n")

    output, status = check("notes.txt")

    assert_equal(1, status.exitstatus)
    assert_equal("notes.txt:2:# #{WORD} later\n", output)
  end

  def test_exits_0_when_no_file_holds_the_marker
    write("notes.txt", "fine\n")

    output, status = check("notes.txt")

    assert_equal(0, status.exitstatus)
    assert_equal("", output)
  end

  def test_exits_0_with_no_files
    _, status = check

    assert_equal(0, status.exitstatus)
  end

  def test_skips_a_path_marked_linguist_vendored
    write(".gitattributes", "skills/** linguist-vendored\n")
    write("skills/upstream.md", "upstream says #{WORD} in prose\n")

    _, status = check("skills/upstream.md")

    assert_equal(0, status.exitstatus)
  end

  def test_skips_a_path_under_a_vendor_directory
    write("vendor/lib/code.rb", "# #{WORD}\n")
    write("app/vendor/code.rb", "# #{WORD}\n")

    _, status = check("vendor/lib/code.rb", "app/vendor/code.rb")

    assert_equal(0, status.exitstatus)
  end

  def test_checks_a_vendor_path_marked_not_vendored
    write(".gitattributes", "vendor/own.rb -linguist-vendored\n")
    write("vendor/own.rb", "# #{WORD}\n")

    output, status = check("vendor/own.rb")

    assert_equal(1, status.exitstatus)
    assert_match(%r{\Avendor/own\.rb:1:}, output)
  end

  def test_skips_lefthook_yml_and_sorbet_paths
    write("lefthook.yml", "# #{WORD}\n")
    write("sorbet/rbi/gem.rbi", "# #{WORD}\n")

    _, status = check("lefthook.yml", "sorbet/rbi/gem.rbi")

    assert_equal(0, status.exitstatus)
  end

  def test_skips_lefthook_local_yml
    write("lefthook-local.yml", "# #{WORD}\n")

    _, status = check("lefthook-local.yml")

    assert_equal(0, status.exitstatus)
  end

  def test_the_local_config_calls_the_repository_copy_for_all_four_checks
    config = YAML.load_file(File.join(REPO_ROOT, "lefthook-local.yml"))
    expected = { "pre-commit" => "{staged_files}", "pre-push" => "{files}" }

    expected.each do |hook, files|
      { "no-fixme" => WORD, "no-nocommit" => OTHER_WORD }.each do |name, word|
        run = config.dig(hook, "commands", name, "run")
        assert_equal("git/.config/git/worktree-tools/marker-check #{word} #{files}", run, "#{hook} #{name}")
      end
    end
  end

  def test_skips_a_path_inside_the_git_directory
    write(".git/HEAD", "ref: refs/heads/#{WORD}-branch\n")

    _, status = check(".git/HEAD", "#{@repo}/.git/worktrees/x/HEAD")

    assert_equal(0, status.exitstatus)
  end

  def test_handles_a_file_name_with_spaces
    write("my notes.txt", "# #{WORD}\n")

    output, status = check("my notes.txt")

    assert_equal(1, status.exitstatus)
    assert_match(/\Amy notes\.txt:1:/, output)
  end

  private

  # The run line of every marker-check command in a lefthook config, with the word in place.
  def marker_commands(path)
    YAML.load_file(path).values.grep(Hash).flat_map { |hook| hook.fetch("commands", {}).values }
        .filter_map { |command| command["run"] if command["run"].to_s.include?("marker-check") }
  end

  def write(relative_path, content)
    path = File.join(@repo, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def check(*files)
    output, status = Open3.capture2e(RbConfig.ruby, SCRIPT, WORD, *files, chdir: @repo)
    [ output, status ]
  end

  def init_repository
    _, status = Open3.capture2e("git", "init", "--quiet", chdir: @repo)
    flunk("git init failed") unless status.success?
  end
end
