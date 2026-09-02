#!/usr/bin/env ruby
# Claude Code PreToolUse hook: blocks Bash commands that need the user's
# explicit consent (playbook agents.md section 7). Exit 2 blocks the call and
# feeds stderr back to the agent; exit 0 lets it run.
#
# Runs on whichever Ruby is on PATH, which is rv's. The Ruby macOS ships at
# /usr/bin/ruby cannot stand in: GEM_PATH points at rv's gems, so requiring json
# there loads a gem built for a newer Ruby and the hook dies before it reads
# anything. A hook that cannot run does not block, so keep Ruby on PATH.
require "json"
require "shellwords"

# One command the shell would run: its program, flags and arguments. Anything
# quoted arrives as a single token, so a message that mentions a command is an
# argument here rather than a command of its own.
class ShellCommand
  WRAPPERS = %w[time nice nohup sudo env command xargs].freeze
  GIT_FLAGS_TAKING_A_VALUE = %w[-C -c --git-dir --work-tree --namespace --super-prefix].freeze

  def initialize(tokens)
    @tokens = tokens
  end

  def directory_change
    return nil unless words.first == "cd"

    words[1]
  end

  def runs?(program, *subcommands)
    return false unless words.first == program

    subcommands.empty? || subcommands == words.drop(1).reject { |word| flag?(word) }.first(subcommands.length)
  end

  # The tokens with leading environment assignments and wrappers stepped over,
  # because `sudo git commit` is still a commit.
  def words
    @words ||= @tokens.drop_while { |token| token.include?("=") || WRAPPERS.include?(token) }
  end

  def git?
    words.first == "git"
  end

  def posts_to_github?
    runs?("gh", "pr", "comment") || runs?("gh", "issue", "comment") || runs?("gh", "pr", "review")
  end

  # Capistrano takes an optional stage before the task, as in `cap production deploy`.
  def deploys?
    runs?("kamal", "deploy") || runs?("kamal", "app", "exec") ||
      (words.first == "cap" && words.include?("deploy"))
  end

  def subcommand
    after_gits_own_flags.first
  end

  # The path `git -C <path>` names, read from the tokens so a path written in a
  # commit message cannot be mistaken for one.
  def checkout_path
    return nil unless git?

    index = words.index("-C")
    index && words[index + 1]
  end

  def flags
    after_gits_own_flags.drop(1).select { |token| flag?(token) }
  end

  def arguments
    after_gits_own_flags.drop(1).reject { |token| flag?(token) }
  end

  private

  def flag?(token)
    token.start_with?("-")
  end

  # The tokens from the subcommand onwards. Git's own flags sit before it, and
  # some of them take a value, so both have to be dropped for `git -C <path>
  # commit` to read as a commit.
  def after_gits_own_flags
    return @after_gits_own_flags if defined?(@after_gits_own_flags)
    return @after_gits_own_flags = [] unless git?

    remaining = words.drop(1)
    remaining = remaining.drop(GIT_FLAGS_TAKING_A_VALUE.include?(remaining.first) ? 2 : 1) while flag?(remaining.first.to_s)
    @after_gits_own_flags = remaining
  end
end

# The whole Bash command, read as the sequence of commands the shell would run.
# Splitting on operators only after tokenising means an operator inside a quoted
# argument stays part of that argument.
class BashCommand
  OPERATORS = [ "&&", "||", "|", ";", "&" ].freeze

  class Unparseable < StandardError; end

  def initialize(text)
    @text = text
  end

  def commands
    @commands ||= @text.split("\n").flat_map { |line| commands_in(line) }
  end

  private

  def commands_in(line)
    split_on_operators(tokenise(line)).reject(&:empty?).map { |tokens| ShellCommand.new(tokens) }
  end

  def tokenise(line)
    Shellwords.split(line).map { |token| without_grouping_punctuation(token) }.reject(&:empty?)
  rescue ArgumentError => error
    raise Unparseable, error.message
  end

  # Shellwords leaves a grouping parenthesis stuck to the word beside it, so
  # `(cd x` would not read as a directory change. Only bare words are trimmed:
  # a token holding spaces came from quotes and is an argument, not syntax.
  def without_grouping_punctuation(token)
    return token if token.include?(" ")

    token.gsub(/\A[(){}]+/, "").gsub(/[(){}]+\z/, "")
  end

  def split_on_operators(tokens)
    tokens.each_with_object([ [] ]) do |token, groups|
      if OPERATORS.include?(token) || token.match?(/[<>]/)
        groups << []
      else
        groups.last << token
      end
    end
  end
end

# A git checkout on disk, and what the guard needs to know about it.
class Checkout
  DEFAULT_BRANCHES = %w[main master].freeze
  ALLOWED_REMOTES = [
    %r{github\.com[:/]eirvandelden/},
    %r{github\.com[:/]nedap/(caren3|ons-client)(\.git)?\z}
  ].freeze

  def initialize(path)
    @path = path
  end

  def branch
    @branch ||= `git -C #{Shellwords.escape(@path)} branch --show-current 2>/dev/null`.strip
  end

  def on_default_branch?
    DEFAULT_BRANCHES.include?(branch)
  end

  def allows_pushing_to?(remote)
    url = `git -C #{Shellwords.escape(@path)} remote get-url #{Shellwords.escape(remote)} 2>/dev/null`.strip
    return false if url.empty?

    ALLOWED_REMOTES.any? { |pattern| url.match?(pattern) }
  end
end

# Where a write runs. A git command can act on another checkout through
# `git -C <path>`, or behind a `cd <path> &&`. Each `cd` moves where every later
# command runs, so they apply in order up to the write; a `cd` after it is not
# where git ran. A path that does not resolve falls back to the agent's own
# directory, so an unreadable command is judged by where the agent stands rather
# than waved through.
class WriteLocation
  def initialize(commands, working_directory)
    @commands = commands
    @working_directory = working_directory
  end

  def checkout
    Checkout.new(named_checkout || directory_reached_by_the_write)
  end

  private

  def named_checkout
    @commands.each do |command|
      resolved = resolve(command.checkout_path)
      return resolved if resolved
    end
    nil
  end

  def directory_reached_by_the_write
    directory = @working_directory
    @commands.each do |command|
      break if writes?(command)

      reached = resolve(command.directory_change)
      directory = reached if reached
    end
    directory
  end

  def writes?(command)
    command.git? && GitWrite::SUBCOMMANDS.include?(command.subcommand)
  end

  def resolve(path)
    return nil if path.nil?

    expanded = path.start_with?("~") ? File.expand_path(path) : path
    File.directory?(expanded) ? expanded : nil
  end
end

# A commit or a push, and what it would write.
class GitWrite
  SUBCOMMANDS = %w[commit push].freeze
  EVERY_BRANCH_FLAGS = %w[--all --mirror].freeze

  def initialize(command)
    @command = command
  end

  def push?
    @command.subcommand == "push"
  end

  def sends_every_branch?
    EVERY_BRANCH_FLAGS.any? { |flag| @command.flags.include?(flag) }
  end

  def remote
    @command.arguments.first || "origin"
  end

  def refspecs
    @command.arguments.drop(1)
  end

  # What a refspec writes: "source:destination" writes the destination, a bare
  # name writes itself, and HEAD writes whichever branch is checked out.
  def writes_default_branch?(checked_out_branch)
    refspecs.any? do |refspec|
      destination = refspec.split(":").last.to_s.delete_prefix("+").delete_prefix("refs/heads/")
      destination = checked_out_branch if destination == "HEAD"
      Checkout::DEFAULT_BRANCHES.include?(destination)
    end
  end

  def forces_without_lease?
    @command.flags.include?("--force") && !@command.flags.include?("--force-with-lease")
  end

  def skips_hooks?
    @command.flags.include?("--no-verify")
  end
end

# A reason to stop, and whether the user's consent marker can override it.
class Refusal
  CONSENT_ADVICE = "Ask the user first; once they explicitly agree, re-run the command " \
                   "prefixed with I_HAVE_USER_CONSENT=1."

  def self.never_allowed(reason)
    new(reason, consentable: false)
  end

  def self.needs_consent(reason)
    new(reason, consentable: true)
  end

  attr_reader :reason

  def initialize(reason, consentable:)
    @reason = reason
    @consentable = consentable
  end

  def overridden_by_consent?
    @consentable
  end
end

# One write measured against the checkout it runs in. Rule 7 is never commit to
# main and never push main, so what matters is what the write sends there — not
# merely which branch the checkout happens to sit on.
class WriteAgainstBranch
  def initialize(write, checkout)
    @write = write
    @checkout = checkout
  end

  def refusal
    return commit_refusal unless @write.push?

    push_refusal
  end

  private

  def commit_refusal
    return nil unless @checkout.on_default_branch?

    Refusal.never_allowed(
      "Blocked: committing on #{@checkout.branch} is never allowed (playbook rule 7). " \
      "Create a feature branch and open a PR.",
    )
  end

  def push_refusal
    return every_branch_refusal if @write.sends_every_branch?
    return checked_out_branch_refusal if @write.refspecs.empty?
    return nil unless @write.writes_default_branch?(@checkout.branch)

    Refusal.never_allowed(
      "Blocked: pushing to main/master is never allowed (playbook rule 7). " \
      "Push the feature branch and open a PR.",
    )
  end

  def every_branch_refusal
    Refusal.never_allowed(
      "Blocked: pushing every branch at once sends main with them (playbook rule 7). Name the branch to push.",
    )
  end

  # With no refspec the push sends whatever is checked out, so the branch decides.
  def checked_out_branch_refusal
    return nil unless @checkout.on_default_branch?

    Refusal.never_allowed(
      "Blocked: pushing #{@checkout.branch} is never allowed (playbook rule 7). " \
      "Push a feature branch and open a PR.",
    )
  end
end

# Reads the command and says why it may not run, or nothing when it may.
class ConsentGuard
  def initialize(command_text, working_directory)
    @command_text = command_text
    @working_directory = working_directory
  end

  def refusal
    never_allowed_refusal || consentable_refusal
  end

  private

  def never_allowed_refusal
    return @never_allowed_refusal if defined?(@never_allowed_refusal)

    @never_allowed_refusal = first_write_refusal
  end

  def first_write_refusal
    writes.each do |write|
      refusal = WriteAgainstBranch.new(write, checkout).refusal
      return refusal if refusal
    end
    nil
  end

  def consentable_refusal
    hooks_refusal || remote_refusal || github_refusal || deploy_refusal
  end

  def hooks_refusal
    return nil unless writes.any?(&:forces_without_lease?) || writes.any?(&:skips_hooks?)

    if writes.any?(&:forces_without_lease?)
      return Refusal.never_allowed(
        "Blocked: plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20).",
      )
    end

    Refusal.needs_consent(
      "Blocked: --no-verify skips the git hooks and needs the user's explicit approval (playbook rule 19).",
    )
  end

  def remote_refusal
    pushes = writes.select(&:push?)
    refused = pushes.find { |push| !checkout.allows_pushing_to?(push.remote) }
    return nil unless refused

    Refusal.needs_consent(
      "Blocked: pushing to remote '#{refused.remote}' isn't on the unattended allowlist — " \
      "eirvandelden/*, nedap/caren3, nedap/ons-client (playbook rule 19).",
    )
  end

  def github_refusal
    return nil unless commands.any?(&:posts_to_github?)

    Refusal.needs_consent(
      "Blocked: posting comments or reviews on GitHub as the user needs explicit approval for that " \
      "exact message (playbook rule 6). Draft the text in chat instead.",
    )
  end

  def deploy_refusal
    return nil unless commands.any?(&:deploys?)

    Refusal.needs_consent("Blocked: deploy commands need the user's explicit approval (playbook rule 13).")
  end

  def writes
    @writes ||= commands.each_with_object([]) do |command, found|
      found << GitWrite.new(command) if command.git? && GitWrite::SUBCOMMANDS.include?(command.subcommand)
    end
  end

  def checkout
    @checkout ||= WriteLocation.new(commands, @working_directory).checkout
  end

  def commands
    @commands ||= BashCommand.new(@command_text).commands
  end
end

# What to do with a command that cannot be tokenised, such as one holding an
# unmatched quote. It is read as text, the way the whole guard used to read
# every command: imprecisely, and prone to finding these words in prose. That is
# the point — an unreadable command is judged no more loosely than before rather
# than waved through. The checkout is not resolved here, so the branch is always
# the agent's own, which is the conservative direction.
class RawTextGuard
  def initialize(command_text, working_directory)
    @command_text = command_text
    @working_directory = working_directory
  end

  def refusal
    return nil unless writes?

    never_allowed_refusal || consentable_refusal
  end

  private

  def writes?
    @command_text.match?(/git\s+(commit|push)(\s|\z)/)
  end

  def never_allowed_refusal
    checkout = Checkout.new(@working_directory)
    if checkout.on_default_branch?
      return Refusal.never_allowed(
        "Blocked: committing or pushing on #{checkout.branch} is never allowed (playbook rule 7). " \
        "Create a feature branch and open a PR.",
      )
    end
    return nil unless @command_text.match?(/\s(origin\s+)?(main|master)(\s|\z)/) ||
                      @command_text.match?(/:(main|master)(\s|\z)/)

    Refusal.never_allowed(
      "Blocked: pushing to main/master is never allowed (playbook rule 7). " \
      "Push the feature branch and open a PR.",
    )
  end

  def consentable_refusal
    if @command_text.include?("--force") && !@command_text.include?("--force-with-lease")
      return Refusal.never_allowed(
        "Blocked: plain --force overwrites remote history. Use --force-with-lease instead (playbook rule 20).",
      )
    end
    return nil unless @command_text.include?("--no-verify")

    Refusal.needs_consent(
      "Blocked: --no-verify skips the git hooks and needs the user's explicit approval (playbook rule 19).",
    )
  end
end

call = JSON.parse($stdin.read)
command_text = call.fetch("tool_input", {}).fetch("command", "")
working_directory = call.fetch("cwd", "")

refusal = begin
  ConsentGuard.new(command_text, working_directory).refusal
rescue BashCommand::Unparseable
  RawTextGuard.new(command_text, working_directory).refusal
end

exit 0 if refusal.nil?
exit 0 if refusal.overridden_by_consent? && command_text.start_with?("I_HAVE_USER_CONSENT=1 ")

advice = refusal.overridden_by_consent? ? " #{Refusal::CONSENT_ADVICE}" : ""
warn "#{refusal.reason}#{advice}"
exit 2
