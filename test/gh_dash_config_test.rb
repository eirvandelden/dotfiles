#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"
require_relative "../claude/.claude/hooks/remote_matcher"
require_relative "isolated_git"

class GhDashConfigTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../github/.config/gh-dash/config.yml", __dir__)

  def test_config_is_valid_yaml_inside_the_github_stow_package
    assert_kind_of(Hash, config)
  end

  def test_pr_sections_put_what_needs_action_first
    expected = [ "Work reviews", "Personal PRs", "My work drafts", "My work: needs reply",
                "My work: changes requested", "My Pull Requests", "Involved" ]

    assert_equal(expected, titles("prSections"))
  end

  def test_work_reviews_section_takes_team_requests_i_have_not_reviewed_and_skips_drafts
    expected = %w[is:open org:nedap review-requested:@me -reviewed-by:@me draft:false sort:updated-asc]

    assert_equal(expected.sort, filter_tokens("prSections", "Work reviews"))
  end

  def test_personal_section_takes_every_ready_pr_in_my_repositories
    expected = %w[is:open user:eirvandelden user:eirvandelden-dev draft:false]

    assert_equal(expected.sort, filter_tokens("prSections", "Personal PRs"))
  end

  def test_personal_section_names_every_personal_owner
    owners = filter_tokens("prSections", "Personal PRs").grep(/\Auser:/).map { |token| token.delete_prefix("user:") }

    assert_equal(RemoteMatcher::PERSONAL_OWNERS.sort, owners.sort)
  end

  def test_drafts_section_takes_my_open_work_drafts
    expected = %w[is:open org:nedap author:@me draft:true]

    assert_equal(expected.sort, filter_tokens("prSections", "My work drafts"))
  end

  def test_needs_reply_section_takes_my_ready_work_prs_with_comments_except_approved
    expected = %w[is:open org:nedap author:@me draft:false comments:>0 -review:approved]

    assert_equal(expected.sort, filter_tokens("prSections", "My work: needs reply"))
  end

  def test_changes_requested_section_takes_my_ready_work_prs_with_changes_requested
    expected = %w[is:open org:nedap author:@me draft:false review:changes_requested]

    assert_equal(expected.sort, filter_tokens("prSections", "My work: changes requested"))
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

  def test_the_deep_review_key_dispatches_between_herdr_and_rex
    herdr_only = run_deep_review("HERDR_ENV" => "1")
    assert_equal([ "pane split --current --direction down --focus",
                   "pane run w1:pNew nvim -c 'silent Octo pr edit 7 o/r'" ], herdr_only.fetch(:herdr))
    assert_empty(herdr_only.fetch(:rex))

    rex_only = run_deep_review("REX_SESSION" => "S1")
    assert_empty(rex_only.fetch(:herdr))
    assert_match(/\Asplit\b.*--split[= ]below\b.* -- nvim -c silent Octo pr edit 7 o\/r\z/, rex_only.fetch(:rex).first)
  end

  def test_herdr_wins_over_rex_for_the_deep_review_key
    calls = run_deep_review("HERDR_ENV" => "1", "REX_SESSION" => "S1")

    refute_empty(calls.fetch(:herdr))
    assert_empty(calls.fetch(:rex))
  end

  def test_diff_pager_is_delta_side_by_side
    assert_equal("delta --paging always --side-by-side", config.dig("pager", "diff"))
  end

  private

  # Runs the C key's command under sh with stub herdr and rex binaries on PATH and the template
  # variables filled in. Answers what each stub logged, as { herdr: [calls], rex: [calls] }.
  def run_deep_review(environment)
    Dir.mktmpdir do |dir|
      %w[herdr rex].each { |name| install_stub(dir, name) }
      command = keybinding_command.sub("{{.PrNumber}}", "7").sub("{{.RepoName}}", "o/r")
      env = { "PATH" => "#{dir}:#{ENV.fetch('PATH')}", "STUB_DIR" => dir, "HERDR_ENV" => nil, "REX_SESSION" => nil }
      Open3.capture3(env.merge(environment), "sh", "-c", command)
      %w[herdr rex].to_h { |name| [ name.to_sym, logged_calls(dir, name) ] }
    end
  end

  def keybinding_command
    keybinding = config.fetch("keybindings").fetch("prs").find { |binding| binding["key"] == "C" }
    refute_nil(keybinding, "no C keybinding in keybindings.prs")
    keybinding["command"].strip
  end

  def install_stub(dir, name)
    path = File.join(dir, name)
    File.write(path, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> "$STUB_DIR/#{name}.log"
      echo '{"result":{"pane":{"pane_id":"w1:pNew"}},"block_ids":["blkNew"]}'
    SH
    FileUtils.chmod(0o755, path)
  end

  def logged_calls(dir, name)
    log = File.join(dir, "#{name}.log")
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end

  def config
    @config ||= YAML.safe_load_file(CONFIG_PATH)
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
