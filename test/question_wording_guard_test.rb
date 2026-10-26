#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require_relative "isolated_git"

# The question wording guard is a PreToolUse hook: exit 2 with stderr blocks the call, exit 0
# allows it. A broken hook must never block Etienne, so every unexpected input exits 0.
class QuestionWordingGuardTest < Minitest::Test
  HOOK = File.expand_path("../claude/.claude/hooks/question-wording-guard.rb", __dir__)
  SETTINGS = File.expand_path("../claude/.claude/settings.json", __dir__)

  def test_a_question_with_i_is_denied_and_the_message_names_the_word
    _, stderr, status = run_guard(ask(question: "Should I rebase the branch?"))

    assert_equal(2, status.exitstatus, stderr)
    assert_match(/\ABlocked: /, stderr)
    assert_includes(stderr, "\"I\"")
  end

  def test_a_label_with_i_will_is_denied
    _, stderr, status = run_guard(ask(options: [ option("I'll push first"), option("Wait") ]))

    assert_equal(2, status.exitstatus, stderr)
    assert_includes(stderr, "\"I'll\"")
  end

  def test_a_label_that_names_no_pronoun_with_a_full_description_is_allowed
    description = "Claude does: rebases. You do: nothing. Result: linear history."

    stdout, stderr, status = run_guard(ask(options: [ option("Rebase onto main", description), option("Wait") ]))

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
    assert_empty(stderr)
  end

  def test_a_description_with_you_do_is_allowed
    _, stderr, status = run_guard(ask(options: [ option("Wait", "You do: nothing"), option("Rebase") ]))

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_banned_words_inside_backticks_are_allowed
    options = [ option("Run `git rebase`"), option("Keep the `I` flag") ]

    _, stderr, status = run_guard(ask(question: "Which `I`?", options: options))

    assert_equal(0, status.exitstatus, stderr)
  end

  def test_malformed_input_is_allowed
    [
      "not json",
      "",
      JSON.generate("tool_name" => "AskUserQuestion", "tool_input" => "text"),
      JSON.generate("tool_name" => "AskUserQuestion", "tool_input" => { "questions" => "text" }),
      JSON.generate("tool_name" => "AskUserQuestion", "tool_input" => { "questions" => [ { "question" => "Q?",
        "options" => [ { "label" => nil } ] } ] })
    ].each do |input|
      _, stderr, status = Open3.capture3(HOOK, stdin_data: input)

      assert_equal(0, status.exitstatus, "#{input.inspect}: #{stderr}")
    end
  end

  def test_another_tool_is_untouched
    payload = JSON.generate("tool_name" => "Bash", "tool_input" => { "command" => "echo I you me" })

    stdout, stderr, status = Open3.capture3(HOOK, stdin_data: payload)

    assert_equal(0, status.exitstatus, stderr)
    assert_empty(stdout)
    assert_empty(stderr)
  end

  def test_settings_run_the_guard_on_ask_user_question
    entry = JSON.parse(File.read(SETTINGS)).dig("hooks", "PreToolUse").find { |hook| hook["matcher"] == "AskUserQuestion" }

    refute_nil(entry)
    assert_equal([ "\"$HOME/.claude/hooks/question-wording-guard.rb\"" ], entry["hooks"].map { |hook| hook["command"] })
  end

  private

  def option(label, description = "Claude does: x. You do: y. Result: z.")
    { "label" => label, "description" => description }
  end

  def ask(question: "Rebase the branch?", options: [ option("Rebase onto main"), option("Wait") ])
    { "questions" => [ { "question" => question, "header" => "Rebase", "multiSelect" => false,
                         "options" => options } ] }
  end

  def run_guard(tool_input)
    payload = JSON.generate("tool_name" => "AskUserQuestion", "tool_input" => tool_input)
    Open3.capture3(HOOK, stdin_data: payload)
  end
end
