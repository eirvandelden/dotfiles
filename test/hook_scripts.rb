require "fileutils"
require "minitest"
require "tmpdir"

# Gives each test process one read-only copy of the tracked hook scripts, so a test repository
# never points core.hooksPath at the checkout and a hook cannot rewrite tracked files.
module HookScripts
  TRACKED = File.expand_path("../git/.config/git/hooks", __dir__) #: String

  # The directory a test repository points core.hooksPath at; the same path for the whole process.
  #: () -> String
  def self.directory
    @directory ||= read_only_copy
  end

  #: () -> String
  def self.read_only_copy
    parent = File.realpath(Dir.mktmpdir("hook-scripts"))
    copy = File.join(parent, "hooks")
    FileUtils.cp_r(TRACKED, copy, preserve: true)
    FileUtils.chmod_R("a-w", copy)
    Minitest.after_run { remove(parent) }
    copy
  end
  private_class_method :read_only_copy

  #: (String parent) -> void
  def self.remove(parent)
    FileUtils.chmod_R("u+w", parent)
    FileUtils.rm_rf(parent)
  end
  private_class_method :remove
end
