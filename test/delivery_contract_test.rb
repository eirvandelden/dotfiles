#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

# Delivery is mostly script behaviour (deliver_test, ship_test, open_pr_dash_test), but who runs
# which script, and when, is skill and playbook text. These contract tests pin the text that carries
# each hand-over, so a later edit cannot drop one silently. They prove the words exist, not that an
# agent obeys them.
class DeliveryContractTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  SKILLS = File.join(REPO_ROOT, "claude/.claude/skills")
  PLAYBOOK = File.read(File.join(REPO_ROOT, "agents.md"))
  CORE_VALUES = File.read(File.join(REPO_ROOT, "claude/.claude/core-values.yml"))

  def test_review_runs_delivery_when_no_finding_is_open
    section = section_of(skill("review"), "## After either backend")

    assert_match(/deliver/i, line_with(section, "Review clean:"))
    assert_includes(section, "~/.claude/skills/deliver/SKILL.md")
    assert_includes(section, "deliver --check")
    assert_match(/without asking/i, section)
  end

  def test_review_on_review_ready_only_summarises
    line = line_with(section_of(skill("review"), "## After either backend"), "Review ready:")

    assert_match(/summaris/i, line)
    assert_match(/stop/i, line)
  end

  def test_review_descriptions_no_longer_promise_report_only_for_the_whole_skill
    frontmatter_description = frontmatter(File.join(SKILLS, "review/SKILL.md")).fetch("description")
    short_description = YAML.load_file(File.join(SKILLS, "review/agents/openai.yaml")).dig("interface", "short_description")

    [ frontmatter_description, short_description ].each do |description|
      assert_match(/deliver/i, description)
      refute_match(/\AReport-only review of this branch/, description)
    end
  end

  def test_the_reviewer_rules_allow_the_deliver_check_its_output_asks_for
    reviewer = File.read(File.join(REPO_ROOT, "claude/.claude/agents/reviewer.md"))
    bash_rule = line_with(section_of(reviewer, "## Rules"), "`Bash` is for")

    assert_includes(section_of(reviewer, "## Output"), "~/.claude/skills/deliver/scripts/deliver --check")
    assert_includes(bash_rule, "`~/.claude/skills/deliver/scripts/deliver --check`")
  end

  def test_intent_records_its_pane_on_accept
    section = section_of(skill("intent"), "## 4. Accept")

    assert_includes(section, "herdr pane current")
    assert_includes(section, "terminal_id")
    assert_includes(section, "intent-pane-<slug>")
  end

  def test_the_coordinator_delivers_then_ships_without_merging
    section = section_of(skill("intent"), "## Autonomous delivery")

    assert_includes(section, "~/.claude/skills/deliver/SKILL.md")
    assert_includes(section, "finish/scripts/ship --no-merge")
    assert_operator(section.index("deliver/SKILL.md"), :<, section.index("ship --no-merge"))
    assert_match(/never merge/i, section)
  end

  def test_work_finish_runs_after_push_then_requests_reviewers
    text = skill("finish")

    assert_includes(text, "gh pr list")
    assert_includes(text, "review-board")
    assert_includes(text, "Needs Review")
    assert_operator(text.index("gh pr list"), :<, text.index("after-push"))
    assert_operator(text.index("after-push"), :<, text.index("--add-reviewer"))
  end

  def test_work_finish_refuses_without_a_pr
    assert_includes(skill("finish"), "the delivery step has not run")
  end

  def test_deliver_and_finish_name_their_codex_invocation
    assert_includes(section_of(skill("deliver"), "## Codex"), "$deliver")
    assert_includes(section_of(skill("finish"), "## Codex"), "$finish")
  end

  def test_finish_no_longer_removes_the_change_folder
    text = skill("finish")

    refute_includes(text, "git rm -r docs/changes")
    refute_includes(text, "mktemp")
    refute_includes(text, "gh pr create")
  end

  def test_finish_personal_runs_ship
    assert_includes(skill("finish"), "~/.claude/skills/finish/scripts/ship")
  end

  def test_finish_auto_mode_runs_ship_no_merge
    section = section_of(skill("finish"), "## Auto mode")

    assert_includes(section, "ship --no-merge")
    assert_match(/never merge/i, section)
  end

  def test_implement_hands_the_branch_to_review_and_the_delivery_step
    text = skill("implement")

    assert_includes(text, "`/review` and the delivery step send the branch onward")
    refute_includes(text, "`/review` and `/finish` send the branch onward")
  end

  def test_playbook_rule_5_names_the_delivery_step
    rule = PLAYBOOK[/^5\. Pull request workflow:.*?(?=^6\. )/m]

    assert_match(/delivery step/i, rule)
    refute_includes(rule, "removed by the `finish` skill")
  end

  def test_core_values_name_finish_as_the_merge_approval
    line = CORE_VALUES.lines.find { |entry| entry.match?(/never merge/i) } || flunk("no never-merge line")

    assert_includes(line, "/finish")
    assert_match(/merge approval/i, line)
  end

  private

  def line_with(text, fragment)
    text.lines.find { |entry| entry.include?(fragment) } || flunk("no line mentions #{fragment}")
  end

  def skill(name)
    File.read(File.join(SKILLS, name, "SKILL.md"))
  end

  def frontmatter(path)
    YAML.safe_load(File.read(path)[/\A---\n(.*?)\n---/m, 1])
  end

  # The text from a heading to the next heading of the same or higher level. A missing heading
  # fails the test, so a dropped section is a red test, not a vacuous pass.
  def section_of(text, heading)
    level = heading[/\A#+/].length
    lines = text.lines
    start = lines.index { |line| line.start_with?(heading) }
    flunk("missing section #{heading}") unless start

    stop = lines[(start + 1)..].index { |line| line.match?(/\A#{'#'}{1,#{level}} /) }
    stop ? lines[start, stop + 1].join : lines[start..].join
  end
end
