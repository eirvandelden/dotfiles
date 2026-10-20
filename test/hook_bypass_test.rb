#!/usr/bin/env ruby
require "minitest/autorun"
require "shellwords"
require_relative "isolated_git"
require_relative "../claude/.claude/hooks/hook_bypass"

# HookBypass.reason names the way a command skips the git hooks, or is nil.
class HookBypassTest < Minitest::Test
  GIT_CONFIG = File.expand_path("../git/.config/git/config", __dir__)

  def test_an_ordinary_commit_has_no_reason
    assert_nil(reason("git commit -m x"))
  end

  def test_no_verify_still_has_a_reason
    assert_match(/--no-verify/, reason("git push --no-verify origin x"))
  end

  def test_every_unambiguous_abbreviation_of_no_verify_has_a_reason
    [ "--no-veri", "--no-verif" ].each { |flag| assert_match(/--no-verify/, reason("git commit #{flag} -m x"), flag) }
  end

  def test_a_short_prefix_that_is_not_no_verify_has_no_reason
    [ "--no-edit", "--no" ].each { |flag| assert_nil(reason("git commit #{flag} -m x"), flag) }
  end

  def test_an_n_inside_a_short_option_cluster_has_a_reason
    [ "git commit -nm x", "git commit -an" ].each { |command| refute_nil(reason(command), command) }
  end

  def test_the_ci_alias_with_n_has_a_reason
    refute_nil(reason("git ci -n -m x"))
  end

  def test_every_commit_alias_in_the_git_config_is_a_commit_word
    aliases = File.read(GIT_CONFIG)[/^\[alias\]\n(.*?)(?=^\[|\z)/m, 1].to_s.lines
                  .filter_map { |line| line.match(/\A\s*(\w+)\s*=\s*commit\b/)&.captures&.first }

    assert_empty(aliases - HookBypass::COMMIT_WORDS)
  end

  def test_quoted_prose_that_starts_with_a_switch_has_no_reason
    [ 'git commit -m "LEFTHOOK=0 is refused"', 'git commit -m "LEFTHOOK_BIN=true is refused"' ]
      .each { |command| assert_nil(reason(command), command) }
  end

  def test_substitution_punctuation_does_not_hide_a_word
    [ "$(git commit -n)", "`git commit -n`", "(git commit -n)" ].each { |command| refute_nil(reason(command), command) }
  end

  def test_git_and_lefthook_match_by_basename
    [ "/usr/bin/git commit -n", "bin/lefthook install" ].each { |command| refute_nil(reason(command), command) }
  end

  def test_core_hooks_path_matches_in_any_case
    refute_nil(reason("git -c CORE.HOOKSPATH=/dev/null commit"))
  end

  def test_config_env_has_a_reason
    [ "git --config-env core.hooksPath=NOPE commit", "git --config-env=core.hooksPath=NOPE commit" ]
      .each { |command| refute_nil(reason(command), command) }
  end

  def test_git_config_set_and_unset_subcommands_have_a_reason
    [ "git config set core.hooksPath x", "git config unset core.hooksPath", "git config --local --unset core.hooksPath" ]
      .each { |command| refute_nil(reason(command), command) }
  end

  def test_git_config_reads_have_no_reason
    [ "git config --get-all core.hooksPath", "git config get core.hooksPath" ]
      .each { |command| assert_nil(reason(command), command) }
  end

  def test_a_read_does_not_hide_a_later_write
    refute_nil(reason("git config --get core.hooksPath; git config core.hooksPath x"))
  end

  def test_a_bare_key_without_a_read_flag_has_a_reason
    refute_nil(reason("git config core.hooksPath"))
  end

  def test_searching_for_the_key_has_no_reason
    assert_nil(reason("rg core.hooksPath"))
  end

  def test_installing_lefthook_itself_has_no_reason
    assert_nil(reason("brew install lefthook"))
  end

  def test_an_exported_switch_has_a_reason
    [ "export LEFTHOOK_EXCLUDE=x", "export LEFTHOOK_CONFIG=x" ].each { |command| refute_nil(reason(command), command) }
  end

  def test_a_quoted_switch_value_with_a_space_has_a_reason
    [ 'LEFTHOOK_CONFIG="/tmp/hook dir/x.yml" git commit -m x', "LEFTHOOK_EXCLUDE='a, b' git commit -m x" ]
      .each { |command| refute_nil(reason(command), command) }
  end

  def test_a_quoted_switch_assignment_inside_a_quoted_sentence_has_no_reason
    [ %q(git commit -m 'LEFTHOOK_CONFIG="/tmp/hook dir/x.yml" is refused'),
      %q(git commit -m "see LEFTHOOK_CONFIG='/a b' here") ].each { |command| assert_nil(reason(command), command) }
  end

  def test_renaming_the_core_section_has_a_reason
    refute_nil(reason("git config --rename-section core core2"))
  end

  private

  def reason(command)
    HookBypass.reason(Shellwords.split(command), command)
  end
end
