#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"

class GhDashConfigTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../github/.config/gh-dash/config.yml", __dir__)

  DEEP_REVIEW_COMMAND =
    "pane=$(herdr pane split --current --direction down --focus | jq -r '.result.pane.pane_id') " \
    "&& [ -n \"$pane\" ] && herdr pane run \"$pane\" " \
    "\"nvim -c 'silent Octo pr edit {{.PrNumber}} {{.RepoName}}'\""

  def test_config_is_valid_yaml_inside_the_github_stow_package
    assert_kind_of(Hash, config)
  end

  def test_pr_sections_put_what_needs_action_first
    expected = [ "Work reviews", "Personal PRs", "My work drafts", "My work: needs reply",
                "My Pull Requests", "Involved" ]

    assert_equal(expected, titles("prSections"))
  end

  def test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts
    expected = %w[is:open org:nedap review-requested:@me -reviewed-by:@me draft:false]

    assert_equal(expected.sort, filter_tokens("prSections", "Work reviews"))
  end

  def test_personal_section_takes_every_ready_pr_in_my_repositories
    expected = %w[is:open user:eirvandelden draft:false]

    assert_equal(expected.sort, filter_tokens("prSections", "Personal PRs"))
  end

  def test_drafts_section_takes_my_open_work_drafts
    expected = %w[is:open org:nedap author:@me draft:true]

    assert_equal(expected.sort, filter_tokens("prSections", "My work drafts"))
  end

  def test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved
    expected = %w[is:open org:nedap author:@me draft:false comments:>0 -review:approved]

    assert_equal(expected.sort, filter_tokens("prSections", "My work: needs reply"))
  end

  def test_default_pr_sections_follow_with_their_gh_dash_filters
    assert_equal(%w[author:@me is:open], filter_tokens("prSections", "My Pull Requests"))
    assert_equal(%w[-author:@me involves:@me is:open], filter_tokens("prSections", "Involved"))
  end

  def test_issue_sections_open_on_issues_assigned_to_me
    assert_equal([ "Assigned to me", "My Issues", "Involved" ], titles("issuesSections"))
    assert_equal(%w[assignee:@me is:open], filter_tokens("issuesSections", "Assigned to me"))
    assert_equal(%w[author:@me is:open], filter_tokens("issuesSections", "My Issues"))
    assert_equal(%w[-author:@me involves:@me is:open], filter_tokens("issuesSections", "Involved"))
  end

  def test_no_filter_uses_or
    filters = %w[prSections issuesSections].flat_map { |view| config.fetch(view).map { |section| section["filters"] } }

    refute_empty(filters)
    filters.each { |filter| refute_includes(filter.split, "OR", filter) }
  end

  def test_deep_review_keybinding_opens_octo_in_a_herdr_pane
    keybinding = config.dig("keybindings", "prs").find { |binding| binding["key"] == "C" }

    refute_nil(keybinding, "no C keybinding in keybindings.prs")
    assert_equal(DEEP_REVIEW_COMMAND, keybinding["command"].strip)
  end

  def test_diff_pager_stays_delta
    assert_equal("delta", config.dig("pager", "diff"))
  end

  private

  def config
    YAML.safe_load_file(CONFIG_PATH)
  end

  def titles(view)
    config.fetch(view).map { |section| section["title"] }
  end

  def filter_tokens(view, title)
    section = config.fetch(view).find { |candidate| candidate["title"] == title }
    flunk("#{view} has no section titled #{title.inspect}") unless section

    section.fetch("filters").split.sort
  end
end
