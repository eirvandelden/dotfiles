#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "isolated_git"

# Only deliver opens a pull request, and it removes docs/changes/<slug>/ first. The consent guard
# enforces that mechanically (test/consent_guard_test.rb); these tests pin the skill, playbook and
# hook text that carries the same rule, and the pushes that keep the remote branch current. They
# prove the words exist, not that an agent obeys them.
class PullRequestFlowTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "agents/.agents/skills")
  FINISH = File.join(SKILLS, "finish/SKILL.md")
  DELIVER_DIR = File.join(SKILLS, "deliver")
  DELIVER_SCRIPT = File.join(DELIVER_DIR, "scripts/deliver")
  PUSH = "git push -u origin HEAD".freeze

  def test_only_the_deliver_skill_runs_gh_pr_create
    offenders = scanned_files.reject { |path| path.start_with?("#{DELIVER_DIR}/") }
                             .select { |path| File.read(path).include?("gh pr create") }

    assert_empty(offenders.map { |path| path.delete_prefix("#{REPO_ROOT}/") })
  end

  def test_the_playbook_lets_only_deliver_open_a_pull_request
    playbook = File.read(File.join(REPO_ROOT, "agents.md"))

    assert_match(/only `?deliver`? opens/i, rule(playbook, 5))
    assert_includes(rule(playbook, 25), "deliver")
    assert_match(/deliver/, playbook[/^## 7a\..*?(?=^## 8\.)/m])
  end

  def test_deliver_is_named_as_the_freshness_check_before_the_pull_request
    playbook = File.read(File.join(REPO_ROOT, "agents.md"))
    header = File.read(File.join(REPO_ROOT, "git/.config/git/worktree-tools/review-report-fresh"))[/\A(?:#.*\n)+/]

    assert_match(/`deliver` checks it before it opens one/, rule(playbook, 16))
    refute_match(/finish\b[^.]*\bopens/, rule(playbook, 16))
    assert_match(/deliver runs it that way before it opens the PR/, header)
    refute_match(/finish runs it/, header)
    refute_match(/finish opens/, File.read(File.join(SKILLS, "finish/scripts/fill-pr-template")))
  end

  def test_lefthook_messages_send_pull_requests_through_deliver
    messages = File.readlines(File.join(REPO_ROOT, "lefthook.yml")).grep(/is not allowed\./)

    assert_equal(4, messages.size)
    messages.each do |message|
      assert_includes(message, "deliver opens the PR")
      refute_match(/open a PR/, message)
    end
  end

  def test_deliver_checks_freshness_without_the_skip
    line = File.readlines(DELIVER_SCRIPT).find { |entry| entry.include?("review-report-fresh") }

    refute_includes(line, "--skip-without-pr")
  end

  def test_deliver_removes_the_change_folder_before_it_creates_the_pull_request
    script = File.read(DELIVER_SCRIPT)

    assert_operator(script.index('capture("git", "rm", "-r"'), :<, script.index('capture("gh", "pr", "create"'))
  end

  def test_finish_names_the_consent_guard_and_creates_no_pull_request
    finish = File.read(FINISH)

    assert_match(/consent guard refuses to create or merge a pull request/, finish)
    refute_includes(finish, "gh pr create")
  end

  def test_implement_pushes_the_branch_when_done
    implement = File.read(File.join(SKILLS, "implement/SKILL.md"))

    assert_includes(implement, PUSH)
    assert_match(/never `--no-verify`/, implement)
  end

  def test_the_reviewer_agent_pushes_its_round
    reviewer = File.read(File.join(REPO_ROOT, "claude/.claude/agents/reviewer.md"))

    assert_includes(reviewer, PUSH)
    assert_match(/`commit-review`, `#{Regexp.escape(PUSH)}`/, reviewer)
  end

  def test_the_reviewer_agent_commits_only_through_commit_review
    reviewer = File.read(File.join(REPO_ROOT, "claude/.claude/agents/reviewer.md"))

    assert_includes(reviewer, "~/.claude/skills/review/scripts/commit-review")
    assert_match(/leave `review\.md` uncommitted/i, reviewer)
    refute_match(/commit `<folder>\/review\.md` alone/, reviewer)
  end

  def test_the_coordinator_commits_rounds_through_commit_review
    intent = File.read(File.join(SKILLS, "intent/SKILL.md"))
    review = File.read(File.join(SKILLS, "review/SKILL.md"))

    assert_match(/transcribing each round and running `commit-review`, then pushing the branch when it exits 0/, intent[/^5\. Review\..*$/])
    assert_match(/Run `commit-review`; push the branch/, review[/^2\. The Codex CLI.*$/])
    assert_match(/Run `commit-review`; push the branch/, review[/transcribes the output into `review.md`.*$/])
  end

  def test_auto_review_runs_the_codex_round_before_the_claude_round
    intent = File.read(File.join(SKILLS, "intent/SKILL.md"))
    review = File.read(File.join(SKILLS, "review/SKILL.md"))

    assert_match(/Codex round first, then the Claude round/, intent[/^5\. Review\..*$/])
    assert_match(/Codex round before the Claude round/, review[/^## Auto mode.*?(?=^## )/m])
    assert_match(/Codex round before the Claude round/, review[/^### Read-only Claude CLI backend.*?(?=^## )/m])
  end

  def test_intent_accept_leaves_intent_md_uncommitted
    intent = File.read(File.join(SKILLS, "intent/SKILL.md"))

    assert_match(/leave `intent\.md` uncommitted/, intent[/^Otherwise, on the words "accepted".*$/])
    refute_match(/commit `intent\.md` alone/, intent)
    refute_match(/commits it alone/, intent)
  end

  def test_plan_commits_through_commit_plan
    plan = File.read(File.join(SKILLS, "plan/SKILL.md"))

    assert_match(/plan\/scripts\/commit-plan/, plan[/^7\. `Status: accepted`.*$/])
    assert_match(/commit-plan/, plan[/^5\. Run `[^`]*commit-plan`.*$/])
    refute_match(/commits? `?plan\.md`? alone/, plan)
  end

  def test_code_review_never_commits_review_md
    code_review = File.read(File.join(SKILLS, "code-review/SKILL.md"))

    assert_match(/never commit `review\.md`/i, code_review)
    assert_match(/stage fix paths by name/, code_review)
  end

  def test_deliver_documents_restore_with_force_with_lease
    deliver = File.read(File.join(SKILLS, "deliver/SKILL.md"))
    section = deliver[/^## Change requests after delivery.*?(?=^## |\z)/m]

    assert_includes(section, "scripts/restore")
    assert_includes(section, "git push --force-with-lease -u origin HEAD")
  end

  def test_the_playbook_names_restore_in_rule_5
    assert_match(/`restore`/, rule(File.read(File.join(REPO_ROOT, "agents.md")), 5))
  end

  private

  def scanned_files
    skills = Dir.glob(File.join(SKILLS, "**/*")).select { |path| File.file?(path) }
    agents = Dir.glob(File.join(REPO_ROOT, "claude/.claude/agents/*"))
    scripts = Dir.glob(File.join(REPO_ROOT, "herdr/.config/herdr/scripts/*")).select { |path| File.file?(path) }
    skills + agents + scripts + [ File.join(REPO_ROOT, "lefthook.yml"), File.join(REPO_ROOT, "agents.md") ]
  end

  def rule(playbook, number)
    playbook[/^#{number}\. .*?(?=^#{number + 1}\. |^## )/m]
  end
end
