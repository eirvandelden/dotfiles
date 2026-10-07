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
# Installing gems is refused outright: bi is the one way to do it (playbook rule 11).
#
# What is left needs no understanding of the command, only whether a word is
# present. Every check errs towards asking: a false question costs a moment, a
# missed one costs the user's name on something they did not send.
#
# Only /finish opens a pull request, and it removes docs/changes/<slug>/ first.
# So `gh pr create` is refused while that folder exists in a checkout the command
# runs in, and `gh pr merge` is refused while the pull request's head commit still
# holds its own docs/changes/<slug>/, or when gh cannot tell. Neither is unlocked by the
# consent marker.
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
  Shellwords.split(command_lines_as_operators(command))
rescue ArgumentError
  without_redirects = command.gsub(/(?:(?<=\s|\A)\d+)?(?:&>>?|[<>]+&?)(?!\()\s*[^\s;|&<>]*/, " ")
  without_redirects.gsub(/\n|;|&&|\||(?<![<>])&/) { |operator| operator == "\n" ? " ; " : " #{operator} " }.split
end

# Outside quotes, a newline ends a command like `;` does, a backslash-newline joins
# the lines, and a comment is dropped. Quoted text is left as it is.
def command_lines_as_operators(command)
  characters = command.chars
  result = +""
  quote = nil
  quote = next_character(characters, result, quote) until characters.empty?
  result
end

# Moves one character from `characters` to `result`; returns the quote now open, or nil.
def next_character(characters, result, quote)
  character = characters.shift
  return copy_quoted(character, characters, result, quote) if quote

  case character
  when "\\" then copy_escape(characters, result)
  when "\n", ";", "|" then result << " #{character == "\n" ? ';' : character} "
  when "&" then result << ampersand(characters, result)
  when ">", "<" then characters.first == "(" ? result << " #{character} " : redirect(characters, result)
  when "#" then comment?(result) ? skip_comment(characters) : result << character
  else result << character
  end
  character if %w[' "].include?(character)
end

def ampersand(characters, result)
  return characters.shift && " && " if characters.first == "&"
  return redirect(characters, result, fd: false) if characters.first == ">"

  " & "
end

# A redirect is dropped whole: an optional file descriptor before it, the operator, and its
# target word. None of them is an argument of the command.
def redirect(characters, result, fd: true)
  result.sub!(/(?<=\A|\s)\d+\z/, "") if fd
  characters.shift while %w[> < & |].include?(characters.first)
  characters.shift while characters.first&.match?(/[ \t]/)
  skip_word(characters)
  ""
end

def skip_word(characters)
  quote = characters.shift if %w[' "].include?(characters.first)
  characters.shift until characters.empty? || (quote ? characters.first == quote : characters.first.match?(/[\s;|&<>]/))
  characters.shift if quote
end

def copy_escape(characters, result)
  escaped = characters.shift
  result << "\\#{escaped}" unless escaped == "\n"
end

def skip_comment(characters)
  characters.shift until characters.empty? || characters.first == "\n"
end

def comment?(result)
  result.empty? || result.end_with?(" ", "\t")
end

def copy_quoted(character, characters, result, quote)
  result << character
  result << characters.shift.to_s if character == "\\" && quote == '"'
  quote unless character == quote
end

GEM_INSTALL_REASON = "install gems with bi, not bundle install. " \
                     "bi resolves the lockfile with Bundler and installs with rv (playbook rule 11).".freeze
BUNDLER_INFO_FLAGS = %w[-v --version -h --help].freeze
COMMAND_SEPARATORS = /(?:&&|\|\||\||;)\z/
ENV_ASSIGNMENT = /\A\w+=/

# A bundle word in command position (first word, or after a separator, skipping
# VAR=value words) with no next word, an install word, or a flag that is not
# -v/--version/-h/--help. `bundle exec`, `bundle update` and the like run.
def installs_gems?(words)
  at_command = true
  words.each_with_index do |word, index|
    bare = word.sub(/\A\(+/, "")
    if at_command && File.basename(bare) == "bundle"
      return true if gem_install_argument?(words[index + 1])
    end
    at_command = starts_command?(word, bare, at_command)
  end
  false
end

def gem_install_argument?(argument)
  return true if argument.nil?

  argument = argument.sub(/[);]+\z/, "")
  %w[install i].include?(argument) || (argument.start_with?("-") && !BUNDLER_INFO_FLAGS.include?(argument))
end

def starts_command?(word, bare, at_command)
  return true if word.match?(COMMAND_SEPARATORS) || bare.empty?

  at_command && bare.match?(ENV_ASSIGNMENT)
end

# Rules 11 and 20 say never, so no consent marker unlocks these.
def never_allowed_reason(words, working_directory)
  return GEM_INSTALL_REASON if installs_gems?(words)
  return "plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20)." \
    if words.include?("--force") && !words.include?("--force-with-lease")

  pull_request_reason(pull_request_words(words), working_directory)
end

def pull_request_reason(words, working_directory)
  return unless gh_command?(words, "create") || gh_command?(words, "merge")

  create_reason(words, working_directory) || merge_reason(words, working_directory)
end

def create_reason(words, working_directory)
  return unless gh_command?(words, "create")

  directories = command_directories(words, working_directory)
  heads = pr_windows(words, "create").filter_map { |_, window| head_branch(window) }
  return unless directories.any? { |directory| change_folder?(directory) } ||
                heads.any? { |head| directories.any? { |directory| branch_carries_change_folder?(directory, head) } }

  "only /finish opens a pull request, once it removed docs/changes/<slug>/. Run /finish."
end

def merge_reason(words, working_directory)
  return unless gh_command?(words, "merge")

  pr_windows(words, "merge").filter_map do |index, window|
    merge_window_reason(words, index, window, working_directory)
  end.first
end

def merge_window_reason(words, index, window, working_directory)
  return if window.include?("--help") || window.include?("-h")

  state = merge_state(window, words, command_directories(words.take(index), working_directory).last)
  return if state == "absent"
  return "gh could not verify that the pull request's branch has removed docs/changes/<slug>/. " \
         "Fix gh (auth, network) and retry, or merge by hand." unless state

  "only /finish prepares a branch for merging: the pull request's branch still has its own docs/changes/<slug>/ " \
    "folder. Run /finish first."
end

# The branch named by --head or -H, without a leading <owner>: part.
def head_branch(words)
  index = words.index { |word| %w[--head -H].include?(word) }
  value = index ? words[index + 1] : words.filter_map { |word| head_value(word) }.first
  value&.split(":", 2)&.last
end

def head_value(word)
  return word.delete_prefix("--head=") if word.start_with?("--head=")

  word.delete_prefix("-H") if word.start_with?("-H") && word.length > 2
end

# Reads the branch's own folder, locally or on origin. A branch git cannot resolve means "cannot tell".
def branch_carries_change_folder?(directory, branch)
  toplevel = git_output(directory, "rev-parse", "--show-toplevel").strip
  folder = "docs/changes/#{change_slug(branch)}"
  [ branch, "origin/#{branch}" ].any? do |ref|
    !git_output(toplevel, "ls-tree", "--name-only", ref, "--", folder).strip.empty?
  end
end

# The folder name for a branch, as plan/scripts/change-folder derives it.
def change_slug(branch)
  branch.sub(%r{\A[^/]+/}, "")
end

# The words, plus the words inside the script of any `sh -c`, `bash -c` or `zsh -c`.
def pull_request_words(words)
  words + words.each_with_index.flat_map { |word, index| nested_shell_words(word, words.drop(index + 1)) }
end

def nested_shell_words(word, rest)
  return [] unless word.match?(%r{(?:\A|/)(?:ba|z)?sh\z})

  flag = rest.index { |argument| argument.match?(/\A-[A-Za-z]*c[A-Za-z]*\z/) }
  script = rest[flag + 1] if flag
  script ? words(script) : []
end

def gh_command?(words, action)
  words.any? { |word| word.match?(/(?:\A|[\/;&|({])gh\z/) } && words.each_cons(2).include?([ "pr", action ])
end

# Where the command runs: the hook's directory, then each `cd` target.
def command_directories(words, working_directory)
  targets = words.each_cons(2).filter_map { |word, target| target.split(SHELL_OPERATOR, 2).first if word.match?(/\A\(?(?:cd|pushd)\z/) }
  targets.reject(&:empty?).each_with_object([ working_directory ]) do |target, directories|
    directories << File.expand_path(target, directories.last)
  end
end

def change_folder?(directory)
  folder, _, status = Open3.capture3(CHANGE_FOLDER_SCRIPT, chdir: directory)
  return false unless status.success?

  toplevel = git_output(directory, "rev-parse", "--show-toplevel").strip
  folder = folder.strip
  [ [ "ls-files", "--", folder ], [ "ls-tree", "--name-only", "HEAD", "--", folder ] ].any? do |arguments|
    !git_output(toplevel, *arguments).strip.empty?
  end
rescue SystemCallError
  false
end

MERGE_VALUE_OPTIONS = %w[-A --author-email -b --body -F --body-file -t --subject --match-head-commit -R --repo].freeze

# Asks gh for the pull request's head commit, then whether that commit has its own
# docs/changes/<slug> tree. Returns "absent" or "Tree", or nil when gh cannot tell:
# the merge is then refused, since nothing shows the folder is gone.
def merge_state(window, words, directory)
  selector, repository = merge_arguments(window, words)
  owner, name, oid, branch = head_commit(selector, repository, directory)
  oid && gh_output(directory, "api", "graphql", *tree_query(owner, name, oid, branch))
rescue SystemCallError
  nil
end

def head_commit(selector, repository, directory)
  jq = "[.headRepositoryOwner.login, .headRepository.name, .headRefOid, .headRefName] | @tsv"
  fields = gh_output(directory, "pr", "view", *selector, *repository,
                     "--json", "headRefOid,headRefName,headRepository,headRepositoryOwner", "--jq", jq)
  fields&.split("\t")
end

def tree_query(owner, name, oid, branch)
  query = "query($owner:String!,$name:String!,$expression:String!){" \
          "repository(owner:$owner,name:$name){object(expression:$expression){__typename}}}"
  [ "-f", "query=#{query}", "-f", "owner=#{owner}", "-f", "name=#{name}", "-f", "expression=#{oid}:docs/changes/#{change_slug(branch)}",
    "--jq", '.data.repository.object.__typename // "absent"' ]
end

def gh_output(directory, *arguments)
  output, _, status = Open3.capture3("gh", *arguments, chdir: directory)
  output.strip if status.success?
end

# The first positional word after `pr merge` names the pull request; --repo is passed on.
# Only the words up to the next shell operator belong to the merge.
def merge_arguments(rest, words)
  selector = rest.each_with_index.find do |word, index|
    !word.start_with?("-") && !(index.positive? && MERGE_VALUE_OPTIONS.include?(rest[index - 1]))
  end&.first
  [ [ selector ].compact, repository_flag(rest, words) ]
end

# The words after `pr <action>`, up to the next shell operator.
def pr_window(words, action)
  pr_windows(words, action).first&.last || []
end

# Each `pr <action>` in the command, as [the index of `pr`, the words after the action].
def pr_windows(words, action)
  words.each_cons(2).each_with_index.filter_map do |pair, index|
    [ index, window(words.drop(index + 2)) ] if pair == [ "pr", action ]
  end
end

def repository_flag(rest, words)
  environment = words.find { |word| word.start_with?("GH_REPO=") }
  return [ "--repo", environment.delete_prefix("GH_REPO=") ] if environment

  equals = rest.find { |word| word.start_with?("--repo=") }
  return [ equals ] if equals

  glued = rest.find { |word| word.start_with?("-R") && word.length > 2 }
  return [ glued ] if glued

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
