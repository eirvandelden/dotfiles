# Requiring this file keeps tests that commit in temporary repositories away from the machine's
# global git setup (hooks, signing). Git reads neither the global nor the system config, in this
# process and in every child process, so a local run matches CI. A test that needs its own git config
# passes GIT_CONFIG_GLOBAL to the child it starts, or sets a repository-local core.hooksPath; both win.
module IsolatedGit
  ENVIRONMENT = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null" }.freeze
end

ENV.update(IsolatedGit::ENVIRONMENT)
