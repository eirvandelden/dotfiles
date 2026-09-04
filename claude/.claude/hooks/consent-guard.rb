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

CONSENT_MARKER = "I_HAVE_USER_CONSENT=1 ".freeze

ALLOWED_REMOTES = [
  %r{github\.com[:/]eirvandelden/},
  %r{github\.com[:/]nedap/(caren3|ons-client)(\.git)?\z}
].freeze

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

  unnamed_remote = disallowed_remote(words, working_directory)
  return nil unless unnamed_remote

  "pushing to remote '#{unnamed_remote}' isn't on the unattended allowlist — " \
    "eirvandelden/*, nedap/caren3, nedap/ons-client (playbook rule 19)."
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

# The remote a push names, when it is one this repository may not be pushed to
# unattended. Only a configured remote can be resolved, so an unknown name is
# reported as-is rather than guessed at.
def disallowed_remote(words, working_directory)
  return nil unless words.include?("git") && words.include?("push")

  candidates = words.drop(words.index("push") + 1).reject { |word| word.start_with?("-") }
  candidates.find do |candidate|
    url = `git -C #{Shellwords.escape(working_directory)} remote get-url #{Shellwords.escape(candidate)} 2>/dev/null`.strip
    !url.empty? && ALLOWED_REMOTES.none? { |pattern| url.match?(pattern) }
  end
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
