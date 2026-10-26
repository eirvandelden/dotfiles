# Finds the banned words in an AskUserQuestion call's question texts and option labels, so
# every question names its actor (Claude or Etienne) instead of saying "I" or "you".
# Used by question-wording-guard.rb.
module QuestionWording
  BANNED = Set[
    "i", "i'll", "i'm", "i've", "i'd", "me", "my",
    "you", "you'll", "you're", "you'd", "you've", "your", "yours"
  ].freeze

  # A run of N backticks up to the next run of exactly N. A backtick after a backslash opens no span.
  CODE_SPAN = /(?<![`\\])(`+)(?!`).*?(?<!`)\1(?!`)/m
  WORD = /[\p{L}\p{N}_]+(?:['’][\p{L}\p{N}_]+)*/
  private_constant :BANNED, :CODE_SPAN, :WORD

  module_function

  # The denial that lists every finding, or nil when every checked text names its actor.
  # Raises KeyError or TypeError when tool_input does not have the AskUserQuestion shape.
  #: (Hash[String, untyped] tool_input) -> String?
  def denial(tool_input)
    findings = checked_texts(tool_input).flat_map do |place, text|
      banned_words_in(text).map { |word| "- \"#{word}\" in #{place}" }
    end
    message(findings) if findings.any?
  end

  # [place, text] pairs: each question text and each option label.
  #: (Hash[String, untyped] tool_input) -> Array[[String, untyped]]
  def checked_texts(tool_input)
    questions = tool_input.fetch("questions")
    raise TypeError, "questions is not an array" unless questions.is_a?(Array)

    questions.each_with_index.flat_map { |question, index| question_texts(question, index + 1) }
  end

  #: (untyped question, Integer number) -> Array[[String, untyped]]
  def question_texts(question, number)
    raise TypeError, "question is not a hash" unless question.is_a?(Hash)

    place = "question #{number} [#{question["header"]}]"
    options = question.fetch("options")
    raise TypeError, "options is not an array" unless options.is_a?(Array)

    [ [ "#{place} text", question.fetch("question") ] ] + options.each_with_index.map do |option, index|
      [ "#{place}, option #{index + 1} label", option.fetch("label") ]
    end
  end

  #: (untyped text) -> Array[String]
  def banned_words_in(text)
    raise TypeError, "checked text is not a string" unless text.is_a?(String)

    text.gsub(CODE_SPAN, " ").scan(WORD).select { |word| BANNED.include?(word.downcase.tr("’", "'")) }
  end

  #: (Array[String] findings) -> String
  def message(findings)
    <<~TEXT.chomp
      AskUserQuestion names no actor. Fix every finding in one new call:
      #{findings.join("\n")}
      Banned in question texts and option labels: I, I'll, I'm, I've, I'd, me, my, you, you'll, you're, you'd, you've, your, yours.
      Name the actor (Claude or Etienne). Write each option label as an order to Claude, such as "Rebase onto main".
      Text inside backticks is not checked. Option descriptions are not checked, so "You do:" lines stay.
    TEXT
  end

  private_class_method :checked_texts, :question_texts, :banned_words_in, :message
end
