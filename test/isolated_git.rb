# Requiring this file keeps tests that commit in temporary repositories away from the machine's
# global git setup (hooks, signing). Git reads neither the global nor the system config, in this
# process and in every child process, so a local run matches CI. A test that needs its own git config
# passes GIT_CONFIG_GLOBAL to the child it starts, or sets a repository-local core.hooksPath; both win.
#
# It also makes git quieter and faster. Two settings, maintenance.auto=false and gc.auto=0, reach every
# git process at command scope, so a commit starts no background maintenance. GIT_TEMPLATE_DIR points
# every `git init` and `git clone` at an empty template (an empty info/ and hooks/), so git copies no
# sample hooks. Both ride in the environment, which a child that sets its own GIT_CONFIG_GLOBAL keeps.
require "fileutils"
require "tmpdir"

module IsolatedGit
  ENVIRONMENT = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null" }.freeze
  QUIET_SETTINGS = { "maintenance.auto" => "false", "gc.auto" => "0" }.freeze #: Hash[String, String]

  # ENVIRONMENT, GIT_TEMPLATE_DIR => template, and both quiet settings appended after any
  # GIT_CONFIG_COUNT entries already in base. Git uses the last value of a key, so an inherited
  # maintenance.auto=true loses to the appended false.
  #: (Hash[String, String] base, String template) -> Hash[String, String]
  def self.environment(base, template)
    first = base.fetch("GIT_CONFIG_COUNT", "0").to_i
    entries = QUIET_SETTINGS.each_with_index.flat_map do |(key, value), offset|
      [ [ "GIT_CONFIG_KEY_#{first + offset}", key ], [ "GIT_CONFIG_VALUE_#{first + offset}", value ] ]
    end
    ENVIRONMENT.merge("GIT_TEMPLATE_DIR" => template, "GIT_CONFIG_COUNT" => (first + QUIET_SETTINGS.size).to_s)
               .merge(entries.to_h)
  end

  # A fresh Dir.mktmpdir holding empty info/ and hooks/. Removed by the process that made it: through
  # Minitest.after_run when Minitest is loaded (an at_exit here would run before the tests, since
  # minitest/autorun registers its at_exit first), else through at_exit.
  #: () -> String
  def self.template
    directory = Dir.mktmpdir("git-template")
    FileUtils.mkdir_p(%w[info hooks].map { |name| File.join(directory, name) })
    cleanup = -> { FileUtils.rm_rf(directory) }
    defined?(Minitest) ? Minitest.after_run(&cleanup) : at_exit(&cleanup)
    directory
  end
end

ENV.update(IsolatedGit.environment(ENV.to_h, IsolatedGit.template))
