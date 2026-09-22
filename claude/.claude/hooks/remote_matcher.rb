# Shared remote matching for the consent guard (asks before pushing anywhere
# unlisted) and finish's change-scope (decides which of its two behaviours
# applies). One source, two callers: BUILTIN_REMOTES names Etienne's own
# GitHub account; ALLOWLIST_FILE is supplied by dotfiles-work, so the public
# repository names no employer.
module RemoteMatcher
  BUILTIN_REMOTES = [ %r{github\.com[:/]eirvandelden/} ].freeze

  ALLOWLIST_FILE = "~/.claude/consent-guard-allowed-remotes.txt".freeze

  module_function

  def personal?(url)
    BUILTIN_REMOTES.any? { |pattern| url.match?(pattern) }
  end

  def allowlisted?(url)
    listed_remotes.any? { |pattern| url.match?(pattern) }
  end

  def allowed_remotes
    BUILTIN_REMOTES + listed_remotes
  end

  def listed_remotes
    path = File.expand_path(ALLOWLIST_FILE)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).filter_map { |line| remote_pattern(line.strip) }
  end

  def remote_pattern(entry)
    return nil if entry.empty? || entry.start_with?("#")
    return %r{github\.com[:/]#{Regexp.escape(entry)}} if entry.end_with?("/")

    %r{github\.com[:/]#{Regexp.escape(entry)}(\.git)?\z}
  end
end
