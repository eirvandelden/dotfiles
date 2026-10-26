#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "../claude/.claude/hooks/question_wording"
require_relative "isolated_git"

class QuestionWordingTest < Minitest::Test
  def test_clean_wording_has_no_denial
    assert_nil(QuestionWording.denial(ask))
  end

  def test_a_banned_word_in_a_question_text_is_denied
    %w[I I'll I'm I've me my you you'll your yours].each do |word|
      denial = QuestionWording.denial(ask(question: "Should #{word} go?"))

      assert_includes(denial.to_s, "\"#{word}\" in question 1 [Rebase] text", word)
    end
  end

  def test_a_banned_word_in_an_option_label_is_denied
    denial = QuestionWording.denial(ask(options: [ option("Rebase"), option("Let me decide") ]))

    assert_includes(denial, "\"me\" in question 1 [Rebase], option 2 label")
  end

  def test_matching_ignores_case
    denial = QuestionWording.denial(ask(question: "YOU or My?"))

    assert_includes(denial, "\"YOU\"")
    assert_includes(denial, "\"My\"")
  end

  def test_a_curly_apostrophe_counts_as_straight
    assert_includes(QuestionWording.denial(ask(question: "I’ll go?")), "\"I’ll\"")
  end

  def test_contractions_with_i_and_you_are_denied
    [ "I'd", "you're", "you'd", "you've" ].each do |word|
      assert_includes(QuestionWording.denial(ask(question: "#{word} go?")).to_s, "\"#{word}\"", word)
    end
  end

  def test_headers_and_previews_are_not_checked
    input = { "questions" => [ { "question" => "Rebase?", "header" => "You choose",
      "options" => [ { "label" => "Rebase", "description" => "You do: nothing", "preview" => "[You] I push" } ] } ] }

    assert_nil(QuestionWording.denial(input))
  end

  def test_single_backtick_spans_hide_their_text
    assert_nil(QuestionWording.denial(ask(question: "Run `git push me` now?")))
  end

  def test_triple_backtick_spans_hide_their_text
    assert_nil(QuestionWording.denial(ask(question: "Run ```I and you``` now?")))
  end

  def test_an_unclosed_backtick_hides_nothing
    assert_includes(QuestionWording.denial(ask(question: "Run `git and I")), "\"I\"")
  end

  def test_an_escaped_backtick_opens_no_span
    assert_includes(QuestionWording.denial(ask(question: "Run \\`git and I now?")), "\"I\"")
  end

  def test_words_that_only_contain_a_banned_word_are_allowed
    assert_nil(QuestionWording.denial(ask(question: "Change the UI, my_var and MySQL?")))
  end

  def test_a_slash_dot_or_hyphen_ends_a_word
    [ "you/Claude", "me-first", "I/O", "i.e." ].each do |text|
      refute_nil(QuestionWording.denial(ask(question: "Use #{text} here?")), text)
    end
  end

  def test_the_denial_lists_every_finding_with_its_place
    input = ask(question: "Should I go?", options: [ option("Rebase"), option("I'll push") ])
    input["questions"] << { "question" => "Your call?", "header" => "Second",
                            "options" => [ option("Wait"), option("Stop") ] }

    denial = QuestionWording.denial(input)

    assert_includes(denial, "\"I\" in question 1 [Rebase] text")
    assert_includes(denial, "\"I'll\" in question 1 [Rebase], option 2 label")
    assert_includes(denial, "\"Your\" in question 2 [Second] text")
    assert_includes(denial, "Claude or Etienne")
    assert_includes(denial, "backticks")
  end

  def test_a_tool_input_without_questions_raises
    assert_raises(KeyError) { QuestionWording.denial({}) }
  end

  def test_denial_is_the_only_public_surface
    assert_equal([ :denial ], QuestionWording.singleton_methods)
    assert_empty(QuestionWording.constants)
  end

  private

  def option(label)
    { "label" => label, "description" => "Claude does: x. You do: y. Result: z." }
  end

  def ask(question: "Rebase the branch?", options: [ option("Rebase onto main"), option("Wait") ])
    { "questions" => [ { "question" => question, "header" => "Rebase", "options" => options } ] }
  end
end
