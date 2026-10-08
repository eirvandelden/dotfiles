#!/usr/bin/env ruby
require "minitest/autorun"

# Only /finish opens a pull request, and it removes docs/changes/<slug>/ first. The consent guard
# enforces that mechanically (test/consent_guard_test.rb); these tests pin the skill, playbook and
# hook text that carries the same rule, and the pushes that keep the remote branch current. They
# prove the words exist, not that an agent obeys them.
class PullRequestFlowTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  FINISH = File.join(SKILLS, "finish/SKILL.md")
  PUSH = "git push -u origin HEAD".freeze

  def test_only_the_finish_skill_runs_gh_pr_create
    offenders = scanned_files.reject { |path| path == FINISH }.select { |path| File.read(path).include?("gh pr create") }

    assert_empty(offenders.map { |path| path.delete_prefix("#{REPO_ROOT}/") })
  end

  def test_the_playbook_lets_only_finish_open_a_pull_request
    playbook = File.read(File.join(REPO_ROOT, "agents.md"))

    assert_match(/only `?finish`? opens/i, rule(playbook, 5))
    assert_includes(rule(playbook, 25), "/finish")
    assert_match(/finish/, playbook[/^## 7a\..*?(?=^## 8\.)/m])
  end

  def test_lefthook_messages_send_pull_requests_through_finish
    messages = File.readlines(File.join(REPO_ROOT, "lefthook.yml")).grep(/is not allowed\./)

    assert_equal(2, messages.size)
    messages.each do |message|
      assert_includes(message, "/finish")
      refute_match(/open a PR/, message)
    end
  end

  def test_finish_checks_freshness_without_the_skip
    line = File.readlines(FINISH).find { |entry| entry.include?("review-report-fresh") }

    refute_includes(line, "--skip-without-pr")
  end

  def test_finish_removes_the_change_folder_before_it_creates_the_pull_request
    finish = File.read(FINISH)

    assert_operator(finish.index("git rm -r docs/changes/<slug>"), :<, finish.index("`gh pr create --title"))
    assert_match(/consent guard refuses `gh pr create`/, finish)
  end

  def test_implement_pushes_the_branch_when_done
    implement = File.read(File.join(SKILLS, "implement/SKILL.md"))

    assert_includes(implement, PUSH)
    assert_match(/never `--no-verify`/, implement)
  end

  def test_the_reviewer_agent_pushes_its_round
    reviewer = File.read(File.join(REPO_ROOT, "claude/.claude/agents/reviewer.md"))

    assert_includes(reviewer, PUSH)
    assert_match(/`git add`\/`git commit` of the review file, `#{Regexp.escape(PUSH)}`/, reviewer)
  end

  def test_the_coordinator_pushes_the_codex_round
    intent = File.read(File.join(SKILLS, "intent/SKILL.md"))
    review = File.read(File.join(SKILLS, "review/SKILL.md"))

    assert_match(/commit it alone, then push/, intent[/^5\. Review\..*$/])
    assert_match(/Commit that file alone, then push/, review[/^2\. The Codex CLI.*$/])
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
