require "open3"
require_relative "../../../../../claude/.claude/hooks/remote_matcher"

# The change scope of a repository, from its "origin" remote alone: "personal" for a personal
# owner, "work" for an entry of RemoteMatcher's allowlist. The one mapping that
# `change-scope` and the scripts that treat work repositories differently share. It is not the
# glossary's Scope, which names the secrets `unlock` loads.
module ChangeScope
  # "personal", "work", or nil for an origin RemoteMatcher does not know.
  #: (?String? url) -> String?
  def self.current(url = origin_url)
    return nil if url.nil? || url.empty?
    return "personal" if RemoteMatcher.personal?(url)

    "work" if RemoteMatcher.allowlisted?(url)
  end

  # True only when the change scope is exactly "work"; an unknown origin is not work.
  #: -> bool
  def self.work?
    current == "work"
  end

  # True when git shows the change folder as untracked or changed: on a work repository that means
  # `docs/changes` is not ignored, and a `git add .` would stage the artefacts.
  #: (String folder) -> bool
  def self.folder_visible?(folder)
    stdout, = Open3.capture2("git", "status", "--porcelain", "--untracked-files=all", "--", folder)
    !stdout.strip.empty?
  end

  #: -> String?
  def self.origin_url
    stdout, status = Open3.capture2("git", "remote", "get-url", "origin", err: File::NULL)
    status.success? ? stdout.strip : nil
  end
  private_class_method :origin_url
end
