# Every way, visible in a command's words, to skip or disarm the git hooks that
# keep commits and pushes off main. Used by the consent guard. Like the guard it
# reads which words are present, not what a shell will do, and errs towards
# asking.
module HookBypass
  COMMIT_WORDS = %w[commit ci].freeze
  NO_VERIFY = "--no-verify".freeze
  SHORT_OPTIONS_WITH_N = /\A-[A-Za-z]*n[A-Za-z]*\z/
  LEFTHOOK_SWITCH = /\ALEFTHOOK(?:_EXCLUDE|_BIN|_CONFIG)?=/
  # Swallows escapes and whole quoted strings, so only an unquoted assignment with a quoted value matches.
  QUOTED_SWITCH = /\\.|'[^']*'|"(?:\\.|[^"\\])*"|(?<![^\s;&|(])(LEFTHOOK(?:_EXCLUDE|_BIN|_CONFIG)?=["'])|./m
  HOOKS_PATH = "core.hookspath".freeze
  READS = %w[--get --get-all --get-regexp get].freeze
  SECTION_OPERATIONS = %w[--remove-section remove-section --rename-section rename-section].freeze

  module_function

  def reason(words, command)
    words = words.map { |word| bare(word) }
    routes(words, command).find { |skips, _| skips }&.last
  end

  def routes(words, command)
    [
      [ no_verify?(words), "#{NO_VERIFY} skips the git hooks, which are what keep commits off main (playbook rule 19)." ],
      [ commit_n?(words), "git commit -n is #{NO_VERIFY}: it skips the git hooks (playbook rule 19)." ],
      [ lefthook_switch?(words, command), "a LEFTHOOK switch turns off, replaces or narrows the git hooks (playbook rule 19)." ],
      [ hooks_path?(words), "changing core.hooksPath moves the git hooks out of the way (playbook rule 19)." ],
      [ plumbing?(words), "git commit-tree and update-ref write history without running any git hook (playbook rule 19)." ],
      [ lefthook_install?(words), "lefthook install and uninstall replace or remove the global git hooks (playbook rule 19)." ]
    ]
  end

  # Substitution and subshell punctuation stays glued to a word. A word with whitespace came from quotes: prose.
  def bare(word)
    word.match?(/\s/) ? word : word.gsub(/\A[$({`]+|[)}`]+\z/, "")
  end

  def no_verify?(words)
    words.any? { |word| word.length >= 6 && NO_VERIFY.start_with?(word) }
  end

  def commit_n?(words)
    git?(words) && commit?(words) && words.any? { |word| word.match?(SHORT_OPTIONS_WITH_N) }
  end

  def commit?(words)
    words.any? { |word| COMMIT_WORDS.include?(word) }
  end

  def lefthook_switch?(words, command)
    words.any? { |word| word.match?(LEFTHOOK_SWITCH) && !word.match?(/\s/) } || quoted_switch?(command)
  end

  def quoted_switch?(command)
    command.scan(QUOTED_SWITCH).any? { |(switch)| switch }
  end

  def hooks_path?(words)
    environment_hooks_path?(words) ||
      (git?(words) && (git_option_hooks_path?(words) || config_hooks_path?(words)))
  end

  def environment_hooks_path?(words)
    words.any? do |word|
      word.match?(/\AGIT_CONFIG_KEY_\d+=core\.hookspath\z/i) ||
        (word.start_with?("GIT_CONFIG_PARAMETERS=") && word.downcase.include?(HOOKS_PATH))
    end
  end

  def git_option_hooks_path?(words)
    words.any? { |word| word.downcase.start_with?("#{HOOKS_PATH}=", "--config-env=#{HOOKS_PATH}=") }
  end

  def config_hooks_path?(words)
    words.include?("config") && (hooks_path_written?(words) || core_section_changed?(words))
  end

  def hooks_path_written?(words)
    words.each_with_index.any? do |word, index|
      word.casecmp?(HOOKS_PATH) && !(index.positive? && READS.include?(words[index - 1]))
    end
  end

  def core_section_changed?(words)
    words.any? { |word| word.casecmp?("core") } && words.any? { |word| SECTION_OPERATIONS.include?(word) }
  end

  def plumbing?(words)
    git?(words) && (words.include?("commit-tree") || words.include?("update-ref"))
  end

  def lefthook_install?(words)
    start = words.index { |word| File.basename(word) == "lefthook" }
    !start.nil? && words.drop(start + 1).any? { |word| %w[install uninstall].include?(word) }
  end

  def git?(words)
    words.any? { |word| File.basename(word) == "git" }
  end
end
