#!/usr/bin/env ruby
# PreToolUse hook for Claude Code and Codex: blocks a hand-typed `git worktree add` whose
# target is not <main checkout>/.worktrees/<name>. Exit 2 blocks the call and feeds stderr back
# to the agent; exit 0 lets it run. `worktree-create` runs git as its own subprocess, so this
# hook never sees it.
#
# It tokenises the command; it is not a shell. Variables, subshells and eval are not expanded,
# so such a target is taken literally and usually blocks. Everything else errs towards allowing:
# a false block stops legitimate work, and the written rule covers the rest.
#
# Runs on whichever Ruby is on PATH, which is rv's. A hook that cannot run does not block
# anything, so keep Ruby on PATH.
require "json"
require "open3"
require "shellwords"

SEGMENT_SEPARATOR = /&&|\|\||[;|\n]/
GLOBAL_OPTIONS_WITH_VALUE = %w[-c --git-dir --work-tree --namespace].freeze
ADD_OPTIONS_WITH_VALUE = %w[-b -B --reason].freeze
BLOCK_MESSAGE = <<~MESSAGE.freeze
  Blocked: this `git worktree add` does not target <main checkout>/.worktrees/<name>.
  Never type `git worktree add` yourself; use `worktree-create` (see the `worktree-first` skill).
MESSAGE

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

  rest = segment_words.drop(start + 1)
  directory = apply_global_options(rest, directory)
  return nil unless rest.first(2) == %w[worktree add]

  target = add_target(rest.drop(2))
  target && [ directory, target ]
end

# Consumes the global options from the front of rest and returns the directory they select.
def apply_global_options(rest, directory)
  while rest.first&.start_with?("-")
    option = rest.shift
    if option == "-C"
      directory = File.expand_path(rest.shift.to_s, directory)
    elsif GLOBAL_OPTIONS_WITH_VALUE.include?(option)
      rest.shift
    end
  end
  directory
end

def add_target(arguments)
  until arguments.empty?
    argument = arguments.shift
    return arguments.first if argument == "--"
    return argument unless argument.start_with?("-")

    arguments.shift if ADD_OPTIONS_WITH_VALUE.include?(argument)
  end
  nil
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

def blocked?(command, directory)
  command.split(SEGMENT_SEPARATOR).any? do |segment|
    segment_words = words(segment)
    if segment_words.first == "cd" && segment_words[1]
      directory = File.expand_path(segment_words[1], directory)
      next false
    end

    found_directory, target = worktree_add(segment_words, directory)
    target && File.directory?(found_directory) && misplaced_worktree?(found_directory, target)
  end
end

payload = JSON.parse($stdin.read)
tool_input = payload["tool_input"]
command = tool_input.is_a?(Hash) ? tool_input["command"].to_s : ""
if blocked?(command, payload["cwd"] || Dir.pwd)
  warn(BLOCK_MESSAGE)
  exit 2
end
