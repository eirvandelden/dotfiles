#!/usr/bin/env ruby
# Claude Code PreToolUse hook: asks for the user's consent before a handful of
# commands that cannot be undone from the outside (playbook agents.md section 7).
# Exit 2 blocks the call and feeds stderr back to the agent; exit 0 lets it run.
#
# Deliberately small. It used to work out which branch a write would land on, in
# which checkout, through which refspec — and got that wrong repeatedly, because
# deciding what a shell command will do requires being a shell. Committing and
# pushing to main are enforced where they cannot be argued with instead: by
# lefthook locally, and by the "protect main" ruleset on GitHub.
#
# What is left needs no understanding of the command, only whether a word is
# present. Every check errs towards asking: a false question costs a moment, a
# missed one costs the user's name on something they did not send.
#
# Only /finish opens a pull request, and it removes docs/changes/<slug>/ first.
# So `gh pr create` is refused while that folder exists in a checkout the command
# runs in, and `gh pr merge` is refused while the pull request's head commit still
# holds docs/changes. Neither is unlocked by the consent marker.
#
# Runs on whichever Ruby is on PATH, which is rv's. A hook that cannot run does
# not block anything, so keep Ruby on PATH.
require "json"
require "open3"
require "shellwords"
require_relative "remote_matcher"

CONSENT_MARKER = "I_HAVE_USER_CONSENT=1 ".freeze
CHANGE_FOLDER_SCRIPT = File.expand_path("../skills/plan/scripts/change-folder", __dir__)

# The command as words. Quoted text arrives as one word, so prose that mentions
# a flag is not mistaken for the flag itself. A command that cannot be
# tokenised, such as one holding an unmatched quote, falls back to splitting on
# whitespace: cruder, and more likely to ask when it need not, which is the
# direction to fail in.
def words(command)
  Shellwords.split(command)
rescue ArgumentError
  command.split
end

# Rule 20 says never, so no consent marker unlocks this one.
def never_allowed_reason(words, working_directory)
  return "plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20)." \
    if words.include?("--force") && !words.include?("--force-with-lease")

  pull_request_reason(pull_request_words(words), working_directory)
end

def pull_request_reason(words, working_directory)
  directories = command_directories(words, working_directory)
  return "only /finish opens a pull request, once it removed docs/changes/<slug>/. Run /finish." \
    if gh_command?(words, "create") && directories.any? { |directory| change_folder?(directory) }

  "only /finish prepares a branch for merging: docs/changes still exists in the pull request's branch. " \
    "Run /finish first." if gh_command?(words, "merge") && merge_carries_change_folder?(words, directories.last)
end

# The words, plus the words inside the script of any `sh -c`, `bash -c` or `zsh -c`.
def pull_request_words(words)
  words + words.each_with_index.flat_map { |word, index| nested_shell_words(word, words.drop(index + 1)) }
end

def nested_shell_words(word, rest)
  return [] unless word.match?(%r{(?:\A|/)(?:ba|z)?sh\z}) && rest.include?("-c")

  script = rest[rest.index("-c") + 1]
  script ? words(script) : []
end

def gh_command?(words, action)
  words.any? { |word| word.match?(/(?:\A|[\/;&|({])gh\z/) } && words.each_cons(2).include?([ "pr", action ])
end

# Where the command runs: the hook's directory, then each `cd` target.
def command_directories(words, working_directory)
  targets = words.each_cons(2).filter_map { |word, target| target.split(SHELL_OPERATOR, 2).first if word == "cd" }
  [ working_directory ] + targets.reject(&:empty?).map { |target| File.expand_path(target, working_directory) }
end

def change_folder?(directory)
  folder, _, status = Open3.capture3(CHANGE_FOLDER_SCRIPT, chdir: directory)
  return false unless status.success?

  toplevel = git_output(directory, "rev-parse", "--show-toplevel").strip
  File.directory?(File.join(toplevel, folder.strip))
rescue SystemCallError
  false
end

MERGE_VALUE_OPTIONS = %w[-A --author-email -b --body -F --body-file -t --subject --match-head-commit -R --repo].freeze

# Asks gh for the pull request's head commit, then whether that commit has a
# docs/changes tree. A gh that fails or is missing means "cannot tell": not carried.
def merge_carries_change_folder?(words, directory)
  selector, repository = merge_arguments(words)
  owner, name, oid = head_commit(selector, repository, directory)
  oid && gh_output(directory, "api", "graphql", *tree_query(owner, name, oid)) == "Tree"
rescue SystemCallError
  false
end

def head_commit(selector, repository, directory)
  jq = "[.headRepositoryOwner.login, .headRepository.name, .headRefOid] | @tsv"
  fields = gh_output(directory, "pr", "view", *selector, *repository,
                     "--json", "headRefOid,headRepository,headRepositoryOwner", "--jq", jq)
  fields&.split("\t")
end

def tree_query(owner, name, oid)
  query = "query($owner:String!,$name:String!,$expression:String!){" \
          "repository(owner:$owner,name:$name){object(expression:$expression){__typename}}}"
  [ "-f", "query=#{query}", "-f", "owner=#{owner}", "-f", "name=#{name}", "-f", "expression=#{oid}:docs/changes",
    "--jq", '.data.repository.object.__typename // "absent"' ]
end

def gh_output(directory, *arguments)
  output, _, status = Open3.capture3("gh", *arguments, chdir: directory)
  output.strip if status.success?
end

# The first positional word after `merge` names the pull request; --repo is passed on.
def merge_arguments(words)
  rest = words.drop(words.index("merge") + 1)
  selector = rest.each_with_index.find do |word, index|
    !word.start_with?("-") && !MERGE_VALUE_OPTIONS.include?(rest[index - 1])
  end&.first
  [ [ selector ].compact, repository_flag(rest) ]
end

def repository_flag(rest)
  equals = rest.find { |word| word.start_with?("--repo=") }
  return [ equals ] if equals

  index = rest.index { |word| %w[-R --repo].include?(word) }
  index ? rest[index, 2] : []
end

def consentable_reason(words, working_directory)
  return "--no-verify skips the git hooks, which are what keep commits off main (playbook rule 19)." \
    if words.include?("--no-verify")

  return "posting on GitHub as the user needs approval for that exact message (playbook rule 6). " \
         "Draft the text in chat instead." if posts_to_github?(words)

  return "deploy commands need the user's explicit approval (playbook rule 13)." if deploys?(words)

  return "destructive database commands need the user's explicit approval (playbook rule 9)." \
    if destroys_database?(words)

  unnamed_remote = disallowed_remote(words, working_directory)
  return nil unless unnamed_remote

  "pushing to remote '#{unnamed_remote}' isn't on the unattended allowlist — " \
    "eirvandelden/*, plus whatever #{RemoteMatcher::ALLOWLIST_FILE} lists (playbook rule 19)."
end

def posts_to_github?(words)
  return false unless words.include?("gh")

  (words.include?("comment") && (words.include?("pr") || words.include?("issue"))) ||
    (words.include?("review") && words.include?("pr"))
end

def deploys?(words)
  return true if words.include?("kamal") && (words.include?("deploy") || words.include?("exec"))

  words.include?("cap") && words.include?("deploy")
end

def destroys_database?(words)
  words.any? { |word| word.match?(/\Adb:(drop|reset|schema:load)(:\w+)?\z/) }
end

GITHUB_URL = %r{\A(?:(?:https|ssh|git)://(?:[^@/]+@)?|[^@/\s]+@)?github\.com[:/](?<path>.+)\z}

VALUE_OPTIONS = %w[-o --push-option --receive-pack --exec --repo].freeze

SHELL_OPERATOR = /(;|&&|\|\||\||(?<![<>])&(?!>))/

# The first word, in any `push`, that names somewhere this repository may not be
# pushed to unattended. Like the other checks it reads words, not shell syntax:
# each `push` owns the words up to the next shell operator, glued to a word or
# not, so a second push behind `;`, `env` or `sudo` is seen and a URL in a later
# command is not mistaken for a target.
def disallowed_remote(words, working_directory)
  return nil unless words.any? { |word| word.match?(/(?:\A|[\/;&|({])git\z/) } && words.include?("push")

  directories = [ working_directory ] + option_values(words, "-C", working_directory)
  push_windows(words).filter_map { |window| disallowed_in(window, directories) }.first
end

def option_values(words, option, working_directory)
  words.each_cons(2).filter_map { |flag, value| File.expand_path(value, working_directory) if flag == option }
end

# One window per `git push`; `git stash push` takes a message and paths, not a remote.
def push_windows(words)
  words.each_index.filter_map do |index|
    window(words.drop(index + 1)) if words[index] == "push" && (index.zero? || words[index - 1] != "stash")
  end
end

# The words up to the first shell operator, keeping the part of a word before a glued one.
def window(words)
  words.each_with_object([]) do |word, kept|
    head, operator = word.split(SHELL_OPERATOR, 2)
    kept << head unless head.to_s.empty?
    break kept if operator
  end
end

# Git reads the first argument, or else `--repo`, as the repository, so both are
# checked: a remote, an alias, or a location, where a colon before any slash
# means an ssh host. Later arguments are refspecs, so only what git resolves to a
# remote, or a `://` URL, counts there.
def disallowed_in(window, directories)
  arguments = positional(window)
  repositories = [ repo_option(window), arguments.first ].compact.uniq
  foreign = repositories.find { |word| remote_location?(word) && !allowed_url?(word) }
  return foreign if foreign

  (repositories + arguments).uniq.find do |word|
    (url_with_scheme?(word) && !allowed_url?(word)) || foreign_push_url?(word, directories)
  end
end

# The arguments that are not flags, nor the value of a flag that takes one.
def positional(window)
  window.each_with_index.filter_map do |word, index|
    word unless word.start_with?("-") || (index.positive? && VALUE_OPTIONS.include?(window[index - 1]))
  end
end

def repo_option(window)
  equals = window.find { |word| word.start_with?("--repo=") }
  return equals.delete_prefix("--repo=") if equals

  window.each_cons(2).find { |flag, _| flag == "--repo" }&.last
end

def remote_location?(word)
  return false if word.start_with?("file://")

  url_with_scheme?(word) || word.match?(/\A[^\/\s:]+:/)
end

def url_with_scheme?(word)
  word.include?("://") && !word.start_with?("file://")
end

def foreign_push_url?(word, directories)
  directories.flat_map { |directory| push_urls(word, directory) }.any? { |url| !allowed_url?(url) }
end

# Where git would push for this word: a remote's push URLs (`pushurl` and
# `pushInsteadOf` included), else an `insteadOf` alias expanded. Nothing when the
# word is neither.
def push_urls(word, directory)
  urls = git_output(directory, "remote", "get-url", "--push", "--all", word).lines.map(&:strip)
  return urls unless urls.empty?

  alias_url = git_output(directory, "ls-remote", "--get-url", word).strip
  alias_url.empty? || alias_url == word ? [] : [ alias_url ]
end

def git_output(directory, *arguments)
  `git -C #{Shellwords.escape(directory)} #{arguments.map { |argument| Shellwords.escape(argument) }.join(" ")} 2>/dev/null`
end

# Matches the allowlist against the path on github.com only, from its start, so
# a URL on another host that merely contains an allowed path does not pass.
def allowed_url?(url)
  path = url[GITHUB_URL, :path]
  return false unless path

  canonical = "github.com/#{path}"
  RemoteMatcher.allowed_remotes.any? { |pattern| pattern.match(canonical)&.begin(0)&.zero? }
end

call = JSON.parse($stdin.read)
command = call.fetch("tool_input", {}).fetch("command", "")
working_directory = call.fetch("cwd", "")

command_words = words(command)

refused = never_allowed_reason(command_words, working_directory)
if refused
  warn "Blocked: #{refused}"
  exit 2
end

reason = consentable_reason(command_words, working_directory)
exit 0 if reason.nil?
exit 0 if command.start_with?(CONSENT_MARKER)

warn "Blocked: #{reason} Ask the user first; once they explicitly agree, re-run the command " \
     "prefixed with I_HAVE_USER_CONSENT=1."
exit 2
