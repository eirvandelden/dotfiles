#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require_relative "isolated_git"

load File.expand_path("../bin/protect-main", __dir__)

# MainProtection reports and applies the "protect main" ruleset. The runner is a lambda that plays
# `gh`: it answers by the joined arguments and records every call.
class ProtectMainTest < Minitest::Test
  FULL_RULES = [ { "type" => "deletion" }, { "type" => "non_fast_forward" }, { "type" => "pull_request" } ].freeze

  def setup
    @answers = {}
    @calls = []
    @bodies = []
  end

  def test_report_marks_a_repository_without_the_ruleset_as_missing
    repositories("eirvandelden" => [ "x" ])
    rulesets("eirvandelden/x" => [])

    assert_equal [ "eirvandelden/x: missing" ], report("eirvandelden")
  end

  def test_report_marks_a_protected_repository
    protected_repository("eirvandelden", "x")

    assert_equal [ "eirvandelden/x: protected" ], report("eirvandelden")
  end

  def test_report_marks_a_ruleset_with_bypass_actors_as_bypassable
    protected_repository("eirvandelden", "x", bypass: [ { "actor_id" => 5 } ])

    assert_equal [ "eirvandelden/x: bypassable" ], report("eirvandelden")
  end

  def test_report_marks_hidden_bypass_actors_as_unverified
    protected_repository("eirvandelden", "x", bypass: nil)

    assert_equal [ "eirvandelden/x: unverified" ], report("eirvandelden")
  end

  def test_report_marks_an_inactive_or_non_main_ruleset_as_missing
    repositories("eirvandelden" => [ "x", "y" ])
    rulesets("eirvandelden/x" => [ { "id" => 1, "enforcement" => "disabled", "target" => "branch" } ],
             "eirvandelden/y" => [ { "id" => 2, "enforcement" => "active", "target" => "branch" } ])
    detail("eirvandelden/x", 1, include: [ "~DEFAULT_BRANCH" ])
    detail("eirvandelden/y", 2, include: [ "refs/heads/release" ])

    assert_equal [ "eirvandelden/x: missing", "eirvandelden/y: missing" ], report("eirvandelden")
  end

  def test_report_marks_a_403_upgrade_answer_as_unavailable
    repositories("eirvandelden" => [ "x" ])
    @answers["api repos/eirvandelden/x/rulesets"] = [ "gh: Upgrade to GitHub Pro (HTTP 403)", false ]

    assert_equal [ "eirvandelden/x: unavailable" ], report("eirvandelden")
  end

  def test_report_skips_archived_repositories
    @answers["repo list eirvandelden --limit 200 --no-archived --json nameWithOwner --jq .[].nameWithOwner"] = [ "eirvandelden/live\n", true ]
    rulesets("eirvandelden/live" => [])

    assert_equal [ "eirvandelden/live: missing" ], report("eirvandelden")
  end

  def test_apply_creates_a_ruleset_with_no_bypass_actors
    protection = MainProtection.new([ "eirvandelden" ], runner: runner)
    message = protection.apply("eirvandelden/x")

    body = @bodies.fetch(0)
    assert_equal "eirvandelden/x: ruleset created", message
    assert_equal "api --method POST repos/eirvandelden/x/rulesets --input", @calls.fetch(0).take(5).join(" ")
    assert_equal "active", body["enforcement"]
    assert_equal [ "~DEFAULT_BRANCH" ], body.dig("conditions", "ref_name", "include")
    assert_equal [], body["bypass_actors"]
    assert_equal %w[deletion non_fast_forward pull_request], body["rules"].map { |rule| rule["type"] }.sort
    assert_equal 0, body["rules"].find { |rule| rule["type"] == "pull_request" }.dig("parameters", "required_approving_review_count")
  end

  private

  def report(*owners)
    MainProtection.new(owners, runner: runner).report
  end

  def runner
    lambda do |*arguments|
      @calls << arguments
      if (position = arguments.index("--input"))
        @bodies << JSON.parse(File.read(arguments[position + 1]))
        return [ "{}", true ]
      end
      answer = @answers.fetch(arguments.join(" ")) { raise "unexpected gh call: #{arguments.join(' ')}" }
      [ answer.first, answer.last ]
    end
  end

  def repositories(by_owner)
    by_owner.each do |owner, names|
      @answers["repo list #{owner} --limit 200 --no-archived --json nameWithOwner --jq .[].nameWithOwner"] =
        [ names.map { |name| "#{owner}/#{name}\n" }.join, true ]
    end
  end

  def rulesets(by_repository)
    by_repository.each { |repository, list| @answers["api repos/#{repository}/rulesets"] = [ JSON.generate(list), true ] }
  end

  def detail(repository, id, include:, rules: FULL_RULES, bypass: [])
    body = { "id" => id, "enforcement" => "active", "conditions" => { "ref_name" => { "include" => include } }, "rules" => rules }
    body["bypass_actors"] = bypass unless bypass.nil?
    @answers["api repos/#{repository}/rulesets/#{id}"] = [ JSON.generate(body), true ]
  end

  def protected_repository(owner, name, bypass: [])
    repositories(owner => [ name ])
    rulesets("#{owner}/#{name}" => [ { "id" => 7, "enforcement" => "active", "target" => "branch" } ])
    detail("#{owner}/#{name}", 7, include: [ "~DEFAULT_BRANCH" ], bypass: bypass)
  end
end
