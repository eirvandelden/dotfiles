#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"
require_relative "isolated_git"

# The no-fixme hooks skip vendored skill reference docs, whose upstream prose names the marker,
# and still refuse every other file that holds it.
class LefthookNoFixmeTest < Minitest::Test
  LEFTHOOK = LefthookBinary.locate
  MARKER = "FIX" + "ME"
  REFERENCE_DOC = "agents/.agents/skills/rails-guides/references/command_line.md"
  OTHER_FILE = "zsh/.config/zsh/paths.zsh"

  def setup
    skip(LefthookBinary::MISSING_MESSAGE) unless LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @repo_dir = File.join(@tmpdir, "repo")
    setup_repo_with_origin
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pre_push_no_fixme_skips_a_skill_reference_doc
    assert_passes("pre-push", REFERENCE_DOC)
  end

  def test_pre_commit_no_fixme_skips_a_skill_reference_doc
    assert_passes("pre-commit", REFERENCE_DOC)
  end

  def test_pre_push_no_fixme_still_refuses_another_file
    assert_refuses("pre-push", OTHER_FILE)
  end

  def test_pre_commit_no_fixme_still_refuses_another_file
    assert_refuses("pre-commit", OTHER_FILE)
  end

  private

  def assert_passes(hook, path)
    out, status = run_no_fixme(hook, path)
    assert(status.success?, "Expected #{hook} no-fixme to skip #{path}:\n#{out}")
  end

  def assert_refuses(hook, path)
    out, status = run_no_fixme(hook, path)
    refute(status.success?, "Expected #{hook} no-fixme to refuse #{path}:\n#{out}")
    assert_includes(out, path)
  end

  # lefthook's --file flag bypasses exclude filters, so the file goes through the real staged or
  # pushed file list: staged for pre-commit, committed but not pushed for pre-push.
  def run_no_fixme(hook, path)
    write_marked_file(path)
    run_git("add", path)
    run_git("commit", "--quiet", "-m", "Add #{path}") if hook == "pre-push"
    command = [ LEFTHOOK, "run", hook, "--tag", "fixme", "--no-auto-install", "--no-tty" ]
    Open3.capture2e(lefthook_env, *command, chdir: @repo_dir)
  end

  def setup_repo_with_origin
    origin_dir = File.join(@tmpdir, "origin.git")
    run_git("init", "--bare", "--quiet", origin_dir)
    run_git("init", "--quiet", "--initial-branch=feature", @repo_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(@repo_dir, "lefthook.yml"))
    run_git("add", "lefthook.yml")
    run_git("commit", "--quiet", "-m", "Add lefthook.yml")
    run_git("remote", "add", "origin", origin_dir)
    run_git("push", "--quiet", "-u", "origin", "feature")
  end

  def write_marked_file(path)
    full_path = File.join(@repo_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, "#{MARKER} upstream prose\n")
  end

  def lefthook_env
    { "LEFTHOOK_CONFIG" => nil, "LEFTHOOK" => nil, "LEFTHOOK_BIN" => nil }
  end

  def run_git(*args)
    identity = { "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                 "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com" }
    _out, err, status = Open3.capture3(identity, "git", *args, chdir: File.exist?(@repo_dir) ? @repo_dir : @tmpdir)
    raise "git #{args.join(" ")} failed: #{err}" unless status.success?
  end
end
