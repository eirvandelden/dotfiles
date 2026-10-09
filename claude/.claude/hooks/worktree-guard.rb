#!/usr/bin/env ruby
# PreToolUse hook for Claude Code and Codex: blocks a hand-typed `git worktree add` whose
# target is not <main checkout>/.worktrees/<name>. Exit 2 blocks the call and feeds stderr back
# to the agent; exit 0 lets it run. `worktree-create` runs git as its own subprocess, so this
# hook never sees it.
#
# It tokenises the command; it is not a shell. Quoted text, comments and heredoc bodies are
# text, so a commit message or PR body that mentions `git worktree add` passes. A `<<` inside
# quoted text, a comment or `$(( … ))` starts no heredoc. When the command word is `eval`, or
# `sh`, `bash` or `zsh` with `-c` among its flags, that command text is checked too.
# Variables are not expanded, so such a target is taken literally and usually blocks. Commands
# inside `( … )` or `$( … )` are not checked. Everything else errs towards allowing: a false
# block stops legitimate work, and the written rule covers the rest.
#
# Runs on whichever Ruby is on PATH, which is rv's. A hook that cannot run does not block
# anything, so keep Ruby on PATH.
require "json"
require "open3"
require "shellwords"
require "strscan"

# A single `&` also ends a command, except in a redirection such as `2>&1` or `&>file`.
SEGMENT_SEPARATOR = /&&|\|\||[;|\n]|(?<![<>])&(?!>)/
LINE_CONTINUATION = /\\\n/
TOKEN = /
  (?<separator>#{SEGMENT_SEPARATOR})
  | (?<space>[ \t]+)
  | '(?<single>[^']*)'
  | "(?<double>(?:\\.|[^"\\])*)"
  | \\(?<escaped>.)
  | (?<comment>\#[^\n]*)
  | (?<plain>[^\s;&|'"\\\#][^\s;&|'"\\]*|&)
/mx
HEREDOC_START = /(?<!<)<<(?!<)-?[ \t]*(['"]?)([^\s'"<>;&|()]+)\1/
# Quoted text and arithmetic on one line, where a `<<` starts no heredoc. A double-quoted string
# with `$(` in it may hold `$(cat <<'EOF'`, a real heredoc, so it does not count here.
NO_HEREDOC_ON_LINE = /'[^'\n]*'|"(?:\\.|\$(?!\()|[^"\\$\n])*"|\$\(\(.*?\)\)/
COMMENT_START = /(?:\A|(?<=[\s;&|]))\#/
GLOBAL_OPTIONS_WITH_VALUE = %w[-c --git-dir --work-tree --namespace --config-env --attr-source].freeze
ADD_OPTIONS_WITH_VALUE = %w[-b -B --reason].freeze
SHELLS = %w[sh bash zsh].freeze
WRAPPERS = %w[command env sudo exec nohup].freeze
WRAPPER_OPTIONS_WITH_VALUE = %w[-u -g -U -C -D -h -p -r -t].freeze
ASSIGNMENT = /\A[A-Za-z_]\w*=/
BLOCK_MESSAGE = <<~MESSAGE.freeze
  Blocked: this `git worktree add` does not target <main checkout>/.worktrees/<name>.
  Never type `git worktree add` yourself; use `worktree-create` (see the `worktree-first` skill).
MESSAGE

# The words of each simple command. Separators inside quotes and heredoc bodies are text, not
# commands. A quote left open falls back to splitting on every separator.
def segments(command)
  text = without_heredoc_bodies(command).gsub(LINE_CONTINUATION, "")
  pieces = tokens(text)
  return text.split(SEGMENT_SEPARATOR).map { |segment| words(segment) } unless pieces

  pieces.slice_when { |before, after| [ before, after ].include?(:separator) }
        .reject { |chunk| chunk == [ :separator ] }
        .map { |chunk| join_words(chunk) }
end

def without_heredoc_bodies(command)
  delimiters = []
  command.lines.each_with_object(+"") do |line, kept|
    if delimiters.empty?
      kept << line
      delimiters.concat(heredoc_delimiters(line))
    elsif line.strip == delimiters.first
      delimiters.shift
    end
  end
end

def heredoc_delimiters(line)
  no_heredoc = match_spans(line, NO_HEREDOC_ON_LINE)
  comment_at = comment_start(line, no_heredoc)
  match_spans(line, HEREDOC_START).filter_map do |match|
    match[2] unless match.begin(0) >= comment_at || inside?(match.begin(0), no_heredoc)
  end
end

# Where an unquoted `#` starts a comment, or the line's length when it has none.
def comment_start(line, quoted)
  starts = match_spans(line, COMMENT_START).map { |match| match.begin(0) }
  starts.find { |at| !inside?(at, quoted) } || line.length
end

def inside?(at, spans)
  spans.any? { |span| at.between?(span.begin(0) + 1, span.end(0) - 1) }
end

def match_spans(line, pattern)
  line.to_enum(:scan, pattern).map { Regexp.last_match }
end

# Quoted text, escapes and plain text as strings; :space and :separator between them. Nil when
# a quote is left open.
def tokens(text)
  scanner = StringScanner.new(text)
  pieces = []
  until scanner.eos?
    return nil unless scanner.scan(TOKEN)

    pieces << piece(scanner)
  end
  pieces
end

def piece(scanner)
  return :separator if scanner[:separator]
  return :space if scanner[:space] || scanner[:comment]

  scanner[:single] || scanner[:double] || scanner[:escaped] || scanner[:plain]
end

def join_words(pieces)
  pieces.chunk { |piece| piece != :space }.filter_map { |is_word, parts| parts.join if is_word }
end

def words(segment)
  Shellwords.split(segment)
rescue ArgumentError
  segment.split
end

def git(directory, *arguments)
  Open3.capture2("git", "-C", directory, *arguments, err: File::NULL)
rescue SystemCallError
  [ "", Struct.new(:success?).new(false) ]
end

# Where git was pointed and what `worktree add` was given, or nil when the segment is not one.
def worktree_add(segment_words, directory)
  start = segment_words.index { |word| word == "git" || word.end_with?("/git") }
  return nil unless start

  directory, rest = after_global_options(segment_words.drop(start + 1), directory)
  return nil unless rest.first(2) == %w[worktree add]

  target = add_target(rest.drop(2))
  target && [ directory, target ]
end

# The directory git's global options select, and the words after those options.
def after_global_options(words, directory)
  option, *rest = words
  return [ directory, words ] unless option&.start_with?("-")
  return after_global_options(rest.drop(1), File.expand_path(rest.first.to_s, directory)) if option == "-C"

  after_global_options(GLOBAL_OPTIONS_WITH_VALUE.include?(option) ? rest.drop(1) : rest, directory)
end

def add_target(arguments)
  argument, *rest = arguments
  return nil unless argument
  return rest.first if argument == "--"
  return argument unless argument.start_with?("-")

  add_target(ADD_OPTIONS_WITH_VALUE.include?(argument) ? rest.drop(1) : rest)
end

# Ported from worktree-create's repo_root!. The first `worktree` line is the main working tree,
# except inside a submodule, where it is the submodule's git directory; core.worktree resolves it.
def main_checkout(directory)
  output, status = git(directory, "worktree", "list", "--porcelain")
  first = status.success? && output.lines.find { |line| line.start_with?("worktree ") }
  return nil unless first

  candidate = first.delete_prefix("worktree ").strip
  working_tree?(candidate) ? candidate : submodule_checkout(candidate)
end

def working_tree?(path)
  output, status = git(path, "rev-parse", "--is-inside-work-tree")
  status.success? && output.strip == "true"
end

def submodule_checkout(git_dir)
  output, status = git(git_dir, "config", "--get", "core.worktree")
  return nil unless status.success? && !output.strip.empty?

  File.expand_path(output.strip, git_dir)
end

# The real path of a target that may not exist yet: symlinks are resolved component by component
# for the part that exists, the rest is appended as written.
def real_target(target, directory)
  start = target.start_with?("/") ? "/" : File.realpath(directory)
  target.split("/").reject(&:empty?).reduce(start) do |current, part|
    next current if part == "."
    next File.dirname(current) if part == ".."

    candidate = File.join(current, part)
    File.exist?(candidate) ? File.realpath(candidate) : candidate
  end
end

def misplaced_worktree?(directory, target)
  root = main_checkout(directory)
  return false unless root

  File.dirname(real_target(target, directory)) != "#{File.realpath(root)}/.worktrees"
end

# The command text a segment hands to another shell (`bash -c "<command>"`) or to `eval`.
def handed_on_command(segment_words)
  command_at = command_word_index(segment_words)
  return nil unless command_at

  name = File.basename(segment_words[command_at])
  arguments = segment_words.drop(command_at + 1)
  return arguments.join(" ") if name == "eval"

  shell_command_text(arguments) if SHELLS.include?(name)
end

# Where the command word is: past variable assignments, and past wrappers with their options.
def command_word_index(words, index = 0)
  word = words[index]
  return nil unless word
  return command_word_index(words, index + 1) if word.match?(ASSIGNMENT)
  return index unless WRAPPERS.include?(word)

  command_word_index(words, past_options(words, index + 1))
end

def past_options(words, index)
  return index unless words[index]&.start_with?("-")

  past_options(words, index + (WRAPPER_OPTIONS_WITH_VALUE.include?(words[index]) ? 2 : 1))
end

# `-c` may share a cluster with other short flags (`-lc`) or follow them (`-e -c`); the command
# text is the first word after the flags.
def shell_command_text(arguments)
  flags = arguments.take_while { |word| word.start_with?("-") }
  arguments[flags.length] if flags.any? { |flag| flag.match?(/\A-[A-Za-z]*c[A-Za-z]*\z/) }
end

def blocked?(command, directory)
  segments(command).any? do |segment_words|
    if segment_words.first == "cd" && segment_words[1]
      directory = after_cd(segment_words[1], directory)
      next false
    end
    handed_on = handed_on_command(segment_words)
    (handed_on && blocked?(handed_on, directory)) || misplaced_add?(segment_words, directory)
  end
end

# A failed `cd` leaves the shell where it was.
def after_cd(destination, directory)
  path = File.expand_path(destination, directory)
  File.directory?(path) ? path : directory
end

def misplaced_add?(segment_words, directory)
  found_directory, target = worktree_add(segment_words, directory)
  target && File.directory?(found_directory) && misplaced_worktree?(found_directory, target)
end

payload = JSON.parse($stdin.read)
tool_input = payload["tool_input"]
command = tool_input.is_a?(Hash) ? tool_input["command"].to_s : ""
if blocked?(command, payload["cwd"] || Dir.pwd)
  warn(BLOCK_MESSAGE)
  exit 2
end
