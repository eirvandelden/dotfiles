#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# The worktree guard is a PreToolUse hook for Claude Code and Codex. It reads the tool call as
# JSON on stdin and exits 2 (block, reason on stderr) when a hand-typed `git worktree add`
# does not target <main checkout>/.worktrees/<name>, 0 for everything else. worktree-create
# runs git as its own subprocess, so the hook never sees it.
class WorktreeGuardTest < Minitest::Test
  GUARD = File.expand_path("../claude/.claude/hooks/worktree-guard.rb", __dir__)
  WITHOUT_GLOBAL_GIT_CONFIG = { "GIT_CONFIG_GLOBAL" => "/dev/null" }.freeze

  def setup
    @enclosing = Dir.mktmpdir
    @repo = File.join(@enclosing, "repo")
    FileUtils.mkdir_p(@repo)
    git(@repo, "init", "--quiet", "--initial-branch=main")
    commit(@repo, "initial")
    File.write(File.join(@repo, ".git", "info", "exclude"), ".worktrees\n")
    git(@repo, "worktree", "add", "--quiet", File.join(".worktrees", "foo"), "-b", "foo")
    @foo = File.join(@repo, ".worktrees", "foo")
  end

  def teardown
    FileUtils.rm_rf(@enclosing)
  end

  def test_a_worktree_beside_the_main_checkout_is_blocked_naming_worktree_first
    _, stderr, status = run_guard("git worktree add ../elsewhere -b x")

    assert_equal(2, status.exitstatus)
    assert_match(/worktree-first/, stderr)
  end

  def test_the_block_message_names_worktree_create
    _, stderr, status = run_guard("git worktree add ../elsewhere -b x")

    assert_equal(2, status.exitstatus)
    assert_match(/worktree-create/, stderr)
  end

  def test_a_worktree_under_dot_claude_is_blocked
    _, _, status = run_guard("git worktree add .claude/worktrees/x -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_git_dash_c_with_an_absolute_target_outside_is_blocked
    _, _, status = run_guard("git -C #{@repo} worktree add /tmp/x -b x", cwd: @enclosing)

    assert_equal(2, status.exitstatus)
  end

  def test_a_relative_target_from_a_linked_worktree_that_leaves_the_main_checkout_is_blocked
    _, _, status = run_guard("git worktree add ../../x -b x", cwd: @foo)

    assert_equal(2, status.exitstatus)
  end

  def test_a_relative_target_from_a_linked_worktree_into_dot_worktrees_is_allowed
    _, stderr, status = run_guard("git worktree add ../bar -b bar", cwd: @foo)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_target_inside_dot_worktrees_is_allowed
    _, stderr, status = run_guard("git worktree add .worktrees/baz -b baz")

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_worktree_nested_inside_a_linked_worktree_is_blocked
    _, _, status = run_guard("git worktree add .claude/worktrees/x -b x", cwd: @foo)

    assert_equal(2, status.exitstatus)
  end

  def test_a_target_deeper_than_one_level_under_dot_worktrees_is_blocked
    _, _, status = run_guard("git worktree add .worktrees/a/b -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_other_git_commands_are_allowed
    [ "git worktree list", "git status", "ls -la" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_outside_a_git_repository_it_allows_everything
    _, stderr, status = run_guard("git worktree add /tmp/x -b x", cwd: Dir.mktmpdir)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_worktree_add_after_a_literal_cd_resolves_against_that_directory
    _, _, status = run_guard("cd #{@foo} && git worktree add ../../x -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_a_worktree_add_later_in_a_chain_is_still_checked
    _, _, status = run_guard("git status && echo hi; git worktree add ../elsewhere -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_a_quoted_commit_message_that_mentions_worktree_add_is_allowed
    _, stderr, status = run_guard('git commit -m "Refuse it; git worktree add /tmp/x is blocked"')

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_heredoc_body_that_mentions_worktree_add_is_allowed
    command = "git commit -F - <<'EOF'\nGuard\n\n- git worktree add /tmp/x -b x is refused\nEOF"
    _, stderr, status = run_guard(command)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_pr_body_built_from_a_heredoc_that_mentions_worktree_add_is_allowed
    command = "gh pr create --title t --body \"$(cat <<'EOF'\nBlocks git worktree add .claude/worktrees/x\nEOF\n)\""
    _, stderr, status = run_guard(command)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_a_worktree_add_after_a_heredoc_is_still_checked
    _, _, status = run_guard("cat <<'EOF'\nhello\nEOF\ngit worktree add ../elsewhere -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_a_worktree_add_handed_to_another_shell_or_eval_is_still_checked
    [ 'bash -c "git worktree add ../x -b x"', "sh -c 'git worktree add ../x -b x'",
     'eval "git worktree add ../x -b x"' ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_only_the_command_word_hands_a_command_on_and_the_segment_is_still_checked
    [ "git worktree add ../x -b eval", "git worktree add ../eval -b x",
     'git worktree add ../x -b x # bash -c "echo"', 'sudo bash -c "git worktree add ../x -b x"',
     'FOO=1 env eval "git worktree add ../x -b x"' ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_shell_with_combined_or_earlier_flags_before_dash_c_is_still_checked
    [ 'bash -lc "git worktree add ../x -b x"', 'bash -e -c "git worktree add ../x -b x"',
     "zsh -i -c 'git worktree add ../x -b x'" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_worktree_add_handed_to_another_shell_inside_dot_worktrees_is_allowed
    _, stderr, status = run_guard('bash -c "git worktree add .worktrees/ok -b ok"')

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_global_options_that_take_a_separate_value_are_skipped
    [ "git --config-env a.b=HOME worktree add ../x -b x",
     "git --attr-source HEAD worktree add ../x -b x" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_command_wrapped_with_backslash_newline_reads_as_one_line
    _, stderr, inside = run_guard("git worktree add \\\n  .worktrees/ok -b ok")
    _, _, outside = run_guard("git \\\n  worktree add ../x -b x")

    assert_equal(0, inside.exitstatus, stderr)
    assert_equal(2, outside.exitstatus)
  end

  def test_a_comment_that_mentions_worktree_add_is_allowed
    [ "# do not run: git worktree add ../x\necho hi",
     "# don't\ngit commit -m \"a; git worktree add ../x\"" ].each do |command|
      _, stderr, status = run_guard(command)

      assert_equal(0, status.exitstatus, "#{command}: #{stderr}")
    end
  end

  def test_a_comment_ends_at_the_newline_and_a_hash_inside_a_word_is_no_comment
    [ "git status # note\ngit worktree add ../x -b x", "echo a#b; git worktree add ../x -b x" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_heredoc_marker_inside_quotes_starts_no_heredoc
    _, _, status = run_guard("git commit -m \"notes <<EOF\"\ngit worktree add ../y -b y")

    assert_equal(2, status.exitstatus)
  end

  def test_a_heredoc_end_word_with_a_dash_or_dot_closes_the_heredoc
    [ "cat <<END-OF\nhi\nEND-OF\ngit worktree add ../y -b y",
     "cat <<'my.end'\nhi\nmy.end\ngit worktree add ../y -b y" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_the_path_after_dash_b_is_the_target_not_the_branch_name
    _, stderr, status = run_guard("git worktree add -b .worktrees/inside .worktrees/inside")

    assert_equal(0, status.exitstatus, stderr)
    _, _, outside = run_guard("git worktree add -b .worktrees/inside ../outside")
    assert_equal(2, outside.exitstatus)
  end

  def test_flags_and_double_dash_before_the_target_are_skipped
    _, _, flagged = run_guard("git worktree add --detach --force ../elsewhere HEAD")
    _, _, separated = run_guard("git worktree add -- ../elsewhere HEAD")
    _, stderr, inside = run_guard("git worktree add --detach .worktrees/ok HEAD")

    assert_equal(2, flagged.exitstatus)
    assert_equal(2, separated.exitstatus)
    assert_equal(0, inside.exitstatus, stderr)
  end

  def test_a_git_behind_command_env_or_an_assignment_is_still_checked
    [ "command git worktree add ../x -b x", "env git worktree add ../x -b x",
     "FOO=1 git worktree add ../x -b x", "sudo git worktree add ../x -b x" ].each do |command|
      _, _, status = run_guard(command)

      assert_equal(2, status.exitstatus, command)
    end
  end

  def test_a_sibling_directory_whose_name_starts_with_dot_worktrees_is_blocked
    _, _, status = run_guard("git worktree add .worktrees-escape/x -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_dot_worktrees_itself_as_the_target_is_blocked
    _, _, status = run_guard("git worktree add .worktrees -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_a_target_through_a_symlinked_tmp_directory_is_compared_by_real_path
    link = File.join(@enclosing, "link")
    File.symlink(@repo, link)

    _, stderr, inside = run_guard("git worktree add #{link}/.worktrees/through-link -b x")
    _, _, outside = run_guard("git worktree add #{link}/../elsewhere -b y")

    assert_equal(0, inside.exitstatus, stderr)
    assert_equal(2, outside.exitstatus)
  end

  def test_inside_a_submodule_dot_worktrees_under_the_submodule_checkout_is_allowed
    submodule = add_submodule("child")

    _, stderr, status = run_guard("git worktree add .worktrees/x -b x", cwd: submodule)

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_from_a_linked_worktree_of_a_submodule_a_target_outside_is_blocked
    submodule = add_submodule("child")
    git(submodule, "worktree", "add", "--quiet", File.join(".worktrees", "one"), "-b", "one")
    linked = File.join(submodule, ".worktrees", "one")

    _, _, status = run_guard("git worktree add ../../../elsewhere -b x", cwd: linked)

    assert_equal(2, status.exitstatus)
  end

  def test_a_command_that_cannot_be_tokenised_still_gets_checked
    _, _, status = run_guard("echo 'unterminated && git worktree add ../elsewhere -b x")

    assert_equal(2, status.exitstatus)
  end

  def test_a_codex_payload_is_refused_with_the_same_message_as_a_claude_payload
    _, claude_stderr, claude_status = run_guard("git worktree add ../elsewhere -b x")
    _, codex_stderr, codex_status = run_codex_guard("git worktree add ../elsewhere -b x")

    assert_equal(2, codex_status.exitstatus)
    assert_equal(claude_status.exitstatus, codex_status.exitstatus)
    assert_equal(claude_stderr, codex_stderr)
  end

  def test_a_null_tool_input_is_allowed
    payload = JSON.generate({ tool_name: "Bash", tool_input: nil, cwd: @repo })
    _, stderr, status = Open3.capture3(GUARD, stdin_data: payload)

    assert_equal(0, status.exitstatus, stderr)
  end

  private

  def run_guard(command, cwd: @repo)
    payload = JSON.generate({ tool_name: "Bash", tool_input: { command: command }, cwd: cwd })
    Open3.capture3(GUARD, stdin_data: payload)
  end

  def run_codex_guard(command)
    payload = JSON.generate({ session_id: "s", turn_id: "t", hook_event_name: "PreToolUse", model: "gpt",
                              permission_mode: "default", tool_name: "Bash", tool_input: { command: command },
                              tool_use_id: "exec-1", cwd: @repo })
    Open3.capture3(GUARD, stdin_data: payload)
  end

  def git(dir, *arguments)
    output, status = Open3.capture2(WITHOUT_GLOBAL_GIT_CONFIG, "git", "-C", dir, "-c", "core.hooksPath=/dev/null",
                                    "-c", "user.email=test@example.com", "-c", "user.name=Test",
                                    "-c", "protocol.file.allow=always", *arguments)
    raise("git #{arguments.join(' ')} failed: #{output}") unless status.success?

    output
  end

  def commit(dir, message)
    File.write(File.join(dir, "file-#{message.tr(' ', '-')}.txt"), message)
    git(dir, "add", "-A")
    git(dir, "commit", "--quiet", "-m", message)
  end

  def add_submodule(name)
    child_origin = File.join(@enclosing, "#{name}.git")
    FileUtils.mkdir_p(child_origin)
    git(child_origin, "init", "--quiet", "--bare", "--initial-branch=main")

    child_seed = File.join(@enclosing, "#{name}-seed")
    git(@enclosing, "clone", "--quiet", child_origin, child_seed)
    commit(child_seed, "#{name} initial")
    git(child_seed, "push", "--quiet", "origin", "main")

    git(@repo, "submodule", "add", "--quiet", child_origin, name)
    commit(@repo, "add #{name} submodule")

    submodule = File.join(@repo, name)
    File.write(File.join(git(submodule, "rev-parse", "--absolute-git-dir").strip, "info", "exclude"), ".worktrees\n")
    submodule
  end
end
