#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Claude Code PreToolUse hook (same stdin/exit contract as consent-guard.rb): while a bugfix's
# reproduction test is committed (plan.md carries "Reproduction: committed"), an edit to a test
# path is refused — "fix the code, not the tests", enforced rather than advised (docs/changes/ai-native-workflow/spec.md §1.4).
# With --always, every write to a test path is refused unconditionally, regardless of plan.md —
# the implementer agent's whole job is production code, so it never has a reason to touch one.
class TestGuardTest < Minitest::Test
  GUARD = File.expand_path("../claude/.claude/hooks/test-guard.rb", __dir__)

  def setup
    @repo = Dir.mktmpdir
    git("init", "--quiet", "--initial-branch=main")
    git("commit", "--quiet", "--allow-empty", "-m", "initial")
    git("checkout", "--quiet", "-b", "claims-status")
  end

  def teardown
    FileUtils.rm_rf(@repo)
  end

  def test_no_change_folder_allows_a_test_edit
    _, stderr, status = run_guard("test/foo_test.rb")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_change_folder_without_the_reproduction_line_allows_a_test_edit
    write_plan("# Plan\n\nStatus: accepted.\n")

    _, stderr, status = run_guard("test/foo_test.rb")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_the_reproduction_line_blocks_a_test_edit
    write_plan("# Plan\n\nReproduction: committed\n")

    _, stderr, status = run_guard("test/foo_test.rb")

    assert_equal(2, status.exitstatus)
    assert_match(/reproduction/i, stderr)
    assert_match(/Reproduction: committed/, stderr)
  end

  def test_the_reproduction_line_allows_a_non_test_edit
    write_plan("# Plan\n\nReproduction: committed\n")

    _, stderr, status = run_guard("app/foo.rb")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_always_mode_blocks_a_test_edit_with_no_plan_at_all
    _, stderr, status = run_guard("spec/foo_spec.rb", always: true)

    assert_equal(2, status.exitstatus)
    assert_match(/test/i, stderr)
  end

  def test_always_mode_allows_a_non_test_edit
    _, stderr, status = run_guard("app/foo.rb", always: true)

    assert_equal(0, status.exitstatus, stderr)
  end

  # Codex edits files through apply_patch (probed 2026-10-01, codex-cli 0.159.3): tool_name "apply_patch", no
  # file_path, and the patch text in tool_input.command naming each file on an "*** Add/Update/Delete File:" line.
  def test_a_codex_patch_adding_a_test_file_is_blocked_in_always_mode
    _, stderr, status = run_codex_guard(patch("Add File", File.join(@repo, "test/foo_test.rb")), always: true)

    assert_equal(2, status.exitstatus)
    assert_match(/test/i, stderr)
  end

  def test_a_codex_patch_updating_a_test_file_is_blocked_during_a_reproduction
    write_plan("# Plan\n\nReproduction: committed\n")

    _, stderr, status = run_codex_guard(patch("Update File", "spec/foo_spec.rb"))

    assert_equal(2, status.exitstatus)
    assert_match(/Reproduction: committed/, stderr)
  end

  def test_a_codex_patch_touching_only_production_code_is_allowed
    _, stderr, status = run_codex_guard(patch("Update File", File.join(@repo, "app/foo.rb")), always: true)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_codex_patch_is_blocked_when_any_of_its_files_is_a_test
    multi_file_patch = "#{patch('Update File', 'app/foo.rb')}\n#{patch('Delete File', 'test/foo_test.rb')}"

    _, _, status = run_codex_guard(multi_file_patch, always: true)

    assert_equal(2, status.exitstatus)
  end

  def test_a_codex_patch_moving_a_file_into_the_test_folder_is_blocked
    moving_patch = "*** Begin Patch\n*** Update File: app/foo.rb\n*** Move to: test/foo_test.rb\n*** End Patch"

    _, _, status = run_codex_guard(moving_patch, always: true)

    assert_equal(2, status.exitstatus)
  end

  private

  def write_plan(content)
    path = File.join(@repo, "docs/changes/claims-status/plan.md")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    git("add", "docs/changes/claims-status/plan.md")
    git("commit", "--quiet", "-m", "add plan")
  end

  def git(*arguments)
    system("git", "-C", @repo, "-c", "commit.gpgsign=false", "-c", "user.email=test@example.com",
           "-c", "user.name=Test", *arguments) || raise("git #{arguments.join(' ')} failed")
  end

  def run_guard(relative_file_path, always: false)
    payload = {
      "tool_input" => { "file_path" => File.join(@repo, relative_file_path) },
      "cwd" => @repo
    }
    Open3.capture3(GUARD, *(always ? [ "--always" ] : []), stdin_data: JSON.generate(payload))
  end

  def patch(action, path)
    "*** Begin Patch\n*** #{action}: #{path}\n+hi\n*** End Patch"
  end

  def run_codex_guard(patch_text, always: false)
    payload = { "tool_name" => "apply_patch", "tool_input" => { "command" => patch_text }, "cwd" => @repo }
    Open3.capture3(GUARD, *(always ? [ "--always" ] : []), stdin_data: JSON.generate(payload))
  end
end
