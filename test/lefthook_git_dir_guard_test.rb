#!/usr/bin/env ruby
require "minitest/autorun"
require "yaml"
require_relative "isolated_git"

# Git exports GIT_DIR to hooks, and a gem installed from git then runs git against the wrong repository
# while Bundler loads it (see LefthookBundlerGitGemTest). This guard fails closed: every lefthook job
# must clear GIT_DIR, unless it is listed here as a job that never loads the bundle. A new job fails
# the suite until someone does one or the other.
class LefthookGitDirGuardTest < Minitest::Test
  LEFTHOOK_YML = File.expand_path("../lefthook.yml", __dir__)

  # Written in two parts: a pre-commit job greps staged Ruby files for the whole job name.
  DEBUGGER_CHECKS = %w[ruby js].map { |language| "pre-commit/no-debug#{"ger"}-#{language}" }.freeze

  BUNDLE_FREE_COMMANDS = {
    "JavaScript and CSS tools run through yarn or npx" => %w[
      pre-commit/stylelint pre-commit/browserslist pre-commit/eslint
      pre-push/stylelint pre-push/browserslist pre-push/eslint migrations/client-dependencies
    ],
    "plain shell, ruby -c or grep checks" => %w[
      pre-commit/ruby-syntax pre-commit/shellcheck pre-commit/shellcheck-zsh pre-commit/yamllint
      pre-commit/no-hardwrap pre-commit/no-push-to-main pre-commit/no-fixme pre-commit/no-nocommit
      pre-commit/no-merge-conflicts commit-msg/no-push-to-main
      pre-push/shellcheck pre-push/shellcheck-zsh pre-push/yamllint pre-push/no-push-to-main
      pre-push/no-fixme pre-push/no-nocommit pre-push/review-report-fresh
    ],
    "starts a nested lefthook run or a detached sweep; the nested jobs clear it themselves" => %w[
      post-merge/migrations post-merge/sweep-worktrees post-rewrite/migrations post-rewrite/sweep-worktrees
    ]
  }.freeze

  def test_every_lefthook_job_clears_git_dir_or_is_listed_as_bundle_free
    unguarded = unguarded_commands(YAML.load_file(LEFTHOOK_YML))

    assert_empty(unguarded, "These lefthook jobs keep the hook's GIT_DIR. Add `unset GIT_DIR` to the job, or " \
                            "list it in BUNDLE_FREE_COMMANDS if it never loads the bundle: #{unguarded.join(", ")}")
  end

  def test_a_job_that_keeps_git_dir_fails_and_names_the_job
    config = YAML.safe_load(<<~YAML)
      pre-push:
        commands:
          audit-licences:
            run: licence_finder report
          yamllint:
            run: yamllint {push_files}
          brakeman:
            run: |
              unset GIT_DIR
              brakeman
    YAML

    assert_equal(%w[pre-push/audit-licences], unguarded_commands(config))
  end

  def test_a_job_that_clears_git_dir_through_env_passes
    config = YAML.safe_load("pre-push:\n  commands:\n    brakeman:\n      run: env -u GIT_DIR brakeman\n")

    assert_empty(unguarded_commands(config))
  end

  def test_a_comment_that_mentions_unset_does_not_count_as_clearing
    config = YAML.safe_load("pre-push:\n  commands:\n    brakeman:\n      run: |\n        # unset GIT_DIR\n        brakeman\n")

    assert_equal(%w[pre-push/brakeman], unguarded_commands(config))
  end

  def test_every_listed_bundle_free_job_still_exists
    existing = command_names(YAML.load_file(LEFTHOOK_YML))
    stale = bundle_free_names - existing

    assert_empty(stale, "BUNDLE_FREE_COMMANDS lists jobs that are not in lefthook.yml: #{stale.join(", ")}")
  end

  private

  def bundle_free_names
    BUNDLE_FREE_COMMANDS.values.flatten + DEBUGGER_CHECKS
  end

  def unguarded_commands(config)
    commands(config).reject { |name, run| bundle_free_names.include?(name) || clears_git_dir?(run) }.map(&:first)
  end

  def command_names(config)
    commands(config).map(&:first)
  end

  def commands(config)
    config.select { |_hook, body| body.is_a?(Hash) && body["commands"] }.flat_map do |hook, body|
      body["commands"].map { |job, settings| [ "#{hook}/#{job}", settings["run"].to_s ] }
    end
  end

  def clears_git_dir?(run)
    run.match?(/^\s*unset\b.*\bGIT_DIR\b/) || run.include?("env -u GIT_DIR")
  end
end
