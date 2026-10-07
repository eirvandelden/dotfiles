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
# Runs on whichever Ruby is on PATH, which is rv's. A hook that cannot run does
# not block anything, so keep Ruby on PATH.
require "json"
require "shellwords"
require_relative "remote_matcher"

CONSENT_MARKER = "I_HAVE_USER_CONSENT=1 ".freeze

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
def never_allowed_reason(words)
  return nil unless words.include?("--force") && !words.include?("--force-with-lease")

  "plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20)."
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

# The first word after `push` that names somewhere this repository may not be
# pushed to unattended: a URL, or a remote configured here or in a `-C`
# directory, outside the allowlist. Like the other checks it reads words, not
# shell syntax, so a push behind `;`, `env`, a newline or a second push is still
# seen; `git stash push` and other words after `push` that are neither a URL nor
# a remote pass. A word that is neither is a local path to git.
def disallowed_remote(words, working_directory)
  return nil unless words.any? { |word| word.match?(/(?:\A|[\/;&|({])git\z/) } && words.include?("push")

  directories = [ working_directory ] + option_values(words, "-C", working_directory)
  words.drop(words.index("push") + 1).find { |word| disallowed_target?(word, directories) }
end

def option_values(words, option, working_directory)
  words.each_cons(2).filter_map { |flag, value| File.expand_path(value, working_directory) if flag == option }
end

def disallowed_target?(word, directories)
  return !allowed_url?(word) if url_like?(word)

  directories.map { |directory| remote_url(word, directory) }.reject(&:empty?).any? { |url| !allowed_url?(url) }
end

# A URL is one word with no spaces, so prose quoted after `push` is not one.
def url_like?(word)
  return false if word.match?(/\s/)

  word.include?("://") || word.match?(/\A[^\/]+@[^:]+:/) || word.start_with?("/", "./", "../")
end

# Matches the allowlist against the path on github.com only, from its start, so
# a URL on another host that merely contains an allowed path does not pass.
def allowed_url?(url)
  path = url[GITHUB_URL, :path]
  return false unless path

  canonical = "github.com/#{path}"
  RemoteMatcher.allowed_remotes.any? { |pattern| pattern.match(canonical)&.begin(0)&.zero? }
end

def remote_url(name, working_directory)
  `git -C #{Shellwords.escape(working_directory)} remote get-url #{Shellwords.escape(name)} 2>/dev/null`.strip
end

call = JSON.parse($stdin.read)
command = call.fetch("tool_input", {}).fetch("command", "")
working_directory = call.fetch("cwd", "")

command_words = words(command)

refused = never_allowed_reason(command_words)
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
