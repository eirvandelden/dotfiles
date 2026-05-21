#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "common"
require "detect"
require "config"
require "portless"

module WorktreeTools
  class PortlessDevTest < Minitest::Test
    CONDUCTOR_ENV_KEYS = %w[CONDUCTOR_ROOT_PATH CONDUCTOR_PORT CONDUCTOR_WORKSPACE_NAME CONDUCTOR_WORKSPACE_PATH].freeze

    def setup
      @tmpdir = Dir.mktmpdir
      @saved_conductor_env = CONDUCTOR_ENV_KEYS.to_h { |key| [ key, ENV[key] ] }
      CONDUCTOR_ENV_KEYS.each { |key| ENV.delete(key) }
    end

    def teardown
      CONDUCTOR_ENV_KEYS.each { |key| ENV[key] = @saved_conductor_env[key] }
      FileUtils.rm_rf(@tmpdir)
    end

    def setup_git_repo(name = "repo")
      path = File.join(@tmpdir, name)
      FileUtils.mkdir_p(path)
      run_command("git", "-C", path, "init", "-q")
      run_command("git", "-C", path, "config", "user.name", "Test User")
      run_command("git", "-C", path, "config", "user.email", "test@example.com")
      run_command("git", "-C", path, "commit", "--allow-empty", "-m", "init", "-q")
      rails_structure(path)
      path
    end

    def setup_repo_with_linked_worktree(repo_name: "repo", worktree_name: "mobile")
      repo = setup_git_repo(repo_name)
      worktree = File.join(@tmpdir, worktree_name)
      run_command("git", "-C", repo, "worktree", "add", "-q", worktree, "-b", worktree_name)
      rails_structure(worktree)
      [ repo, worktree ]
    end

    def rails_structure(path)
      FileUtils.mkdir_p(File.join(path, "config"))
      FileUtils.touch(File.join(path, "Gemfile"))
      FileUtils.touch(File.join(path, "config", "application.rb"))
      FileUtils.touch(File.join(path, "config.ru"))
    end

    def worktree_yml(path, content)
      File.write(File.join(path, ".worktree.yml"), content)
    end

    def load_config(worktree_path)
      detector = ProjectDetector.new(worktree_path).detect!
      WorktreeConfig.new(worktree_path, detector).load!
    end

    # Returns a PortlessDev whose CLI invocations are recorded in @invocations
    # instead of shelling out. Also stubs availability checks so tests run on
    # machines without portless installed.
    def portless_instance(config, path, portless_installed: true)
      portless = PortlessDev.new(config, path)
      portless.instance_variable_set(:@invocations, [])
      portless.define_singleton_method(:register_alias) do |hostname, port|
        @invocations << [ :register, hostname, port ]
      end
      portless.define_singleton_method(:unregister_alias) do |hostname|
        @invocations << [ :unregister, hostname ]
        true
      end
      portless.define_singleton_method(:command_exists?) do |_command|
        portless_installed
      end
      portless.define_singleton_method(:require_command) do |_command, _message|
        nil unless portless_installed
        raise WorktreeTools::Error, "portless missing" unless portless_installed
      end
      portless
    end

    def run_command(*args)
      assert system(*args), "Command failed: #{args.join(' ')}"
    end

    # --- setup! ---

    def test_setup_registers_alias
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      invocations = portless.instance_variable_get(:@invocations)
      assert_equal 1, invocations.size
      assert_equal :register, invocations.first[0]
    end

    def test_main_worktree_hostname_uses_project_only
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, hostname, _ = portless.instance_variable_get(:@invocations).first
      assert_equal "myapp.localhost", hostname
    end

    def test_feature_worktree_hostname_uses_worktree_and_project
      _repo, worktree = setup_repo_with_linked_worktree(repo_name: "myapp", worktree_name: "mobile")
      worktree_yml(worktree, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(worktree)
      portless = portless_instance(config, worktree)
      portless.setup!

      _, hostname, _ = portless.instance_variable_get(:@invocations).first
      assert_equal "mobile.myapp.localhost", hostname
    end

    def test_main_named_worktree_collapses_to_project_hostname
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
          name: main
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, hostname, _ = portless.instance_variable_get(:@invocations).first
      assert_equal "myapp.localhost", hostname
      assert_nil hostname.match(/main\.myapp\.localhost/)
    end

    def test_tld_defaults_to_localhost
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, hostname, _ = portless.instance_variable_get(:@invocations).first
      assert hostname.end_with?(".localhost"), "hostname #{hostname.inspect} should end with .localhost"
    end

    def test_tld_can_be_overridden
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
          tld: test
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, hostname, _ = portless.instance_variable_get(:@invocations).first
      assert_equal "myapp.test", hostname
    end

    def test_setup_uses_base_port_for_main_worktree
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
        port:
          base: 4567
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, _, port = portless.instance_variable_get(:@invocations).first
      assert_equal 4567, port
    end

    def test_setup_uses_conductor_port_inside_conductor
      ENV["CONDUCTOR_ROOT_PATH"] = @tmpdir
      ENV["CONDUCTOR_PORT"] = "5123"
      ENV["CONDUCTOR_WORKSPACE_NAME"] = "bangalore"
      ENV["CONDUCTOR_WORKSPACE_PATH"] = @tmpdir

      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      _, _, port = portless.instance_variable_get(:@invocations).first
      assert_equal 5123, port
    end

    def test_setup_skipped_when_disabled
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: false
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!

      assert_empty portless.instance_variable_get(:@invocations)
    end

    def test_setup_raises_when_portless_not_installed
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo, portless_installed: false)

      assert_raises(WorktreeTools::Error) { portless.setup! }
    end

    # --- remove! ---

    def test_remove_unregisters_alias
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.setup!
      portless.remove!

      invocations = portless.instance_variable_get(:@invocations)
      assert_equal 2, invocations.size
      assert_equal [ :unregister, "myapp.localhost" ], invocations.last
    end

    def test_remove_is_silent_when_portless_not_installed
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: true
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo, portless_installed: false)

      portless.remove! # should not raise
      assert_empty portless.instance_variable_get(:@invocations)
    end

    def test_remove_runs_even_when_disabled
      # Mirrors caddy.rb behavior: remove! cleans up regardless of current
      # enabled flag, so toggling portless off still cleans up old aliases.
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        portless:
          enabled: false
      YAML

      config = load_config(repo)
      portless = portless_instance(config, repo)
      portless.remove!

      invocations = portless.instance_variable_get(:@invocations)
      assert_equal 1, invocations.size
      assert_equal :unregister, invocations.first[0]
    end
  end
end
