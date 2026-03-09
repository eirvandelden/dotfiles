#!/usr/bin/env ruby
require "minitest/autorun"
require "digest"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "common"
require "detect"
require "config"

module WorktreeTools
  class ConfigFindConfigFileTest < Minitest::Test
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

    # Sets up a regular (non-bare) git repo with a linked worktree:
    #   repo/          <- main repo (has .git/)
    #   repo/mobile/   <- linked worktree
    def setup_regular_repo_with_worktree
      repo = File.join(@tmpdir, "repo")
      FileUtils.mkdir_p(repo)
      run_command("git", "-C", repo, "init", "-q")
      run_command("git", "-C", repo, "config", "user.name", "Test User")
      run_command("git", "-C", repo, "config", "user.email", "test@example.com")
      run_command("git", "-C", repo, "commit", "--allow-empty", "-m", "init", "-q")

      worktree = File.join(@tmpdir, "mobile")
      run_command("git", "-C", repo, "worktree", "add", "-q", worktree, "-b", "mobile")

      [ repo, worktree ]
    end

    # Sets up a bare-style repo (no main worktree checkout) with a linked worktree:
    #   caren/          <- bare repo (no .git subdir, is itself the git dir)
    #   caren/mobile/   <- linked worktree inside the bare repo dir
    def setup_bare_repo_with_worktree
      bare = File.join(@tmpdir, "caren")
      FileUtils.mkdir_p(bare)
      run_command("git", "-C", bare, "init", "--bare", "-q")

      # Seed the bare repo with a commit via a temp clone
      clone = File.join(@tmpdir, "clone")
      run_command("git", "clone", "-q", bare, clone)
      run_command("git", "-C", clone, "config", "user.name", "Test User")
      run_command("git", "-C", clone, "config", "user.email", "test@example.com")
      run_command("git", "-C", clone, "commit", "--allow-empty", "-m", "init", "-q")
      run_command("git", "-C", clone, "push", "-q", "origin", "main")
      FileUtils.rm_rf(clone)

      worktree = File.join(bare, "mobile")
      run_command("git", "-C", bare, "worktree", "add", "-q", worktree, "main")

      [ bare, worktree ]
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

    def with_conductor_env(overrides)
      original = overrides.keys.to_h { |key| [ key, ENV[key] ] }
      overrides.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end

    def assert_not(value, message = nil)
      assert_equal(false, !!value, message)
    end

    def run_command(*args)
      assert system(*args), "Command failed: #{args.join(' ')}"
    end

    # --- Regular repo: config in worktree root ---

    def test_finds_config_in_worktree_root_for_regular_repo
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      assert_not config.puma_dev_enabled?, "puma-dev should be disabled"
    end

    # --- Regular repo: config in repo root (main worktree) ---

    def test_finds_config_in_repo_root_for_regular_repo
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(repo, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      assert_not config.puma_dev_enabled?, "puma-dev should be disabled when config is in the git repo root"
    end

    # --- Bare repo: config in bare repo root ---

    def test_finds_config_in_bare_repo_root
      bare, worktree = setup_bare_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(bare, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      assert_not config.puma_dev_enabled?, "puma-dev should be disabled when config is in the bare repo root"
    end

    # --- No config file: falls back to defaults ---

    def test_defaults_to_puma_dev_enabled_for_rails_project_without_config
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      config = load_config(worktree)

      assert config.puma_dev_enabled?, "puma-dev should be enabled by default for rails projects"
    end

    def test_default_stow_source_dir_uses_git_repo_root_for_linked_worktree
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      config = load_config(worktree)

      assert_equal File.realpath(repo).then { |path| File.join(path, ".worktree-local") }, config.stow_source_dir
    end

    def test_repo_root_source_dir_override_is_resolved_from_repo_root
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(repo, <<~YAML)
        stow:
          source_dir: .worktree-local
      YAML

      config = load_config(worktree)

      assert_equal File.realpath(repo).then { |path| File.join(path, ".worktree-local") }, config.stow_source_dir
    end

    def test_worktree_source_dir_override_is_resolved_from_worktree_root
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, <<~YAML)
        stow:
          source_dir: .worktree-local
      YAML

      config = load_config(worktree)

      assert_equal File.realpath(worktree).then { |path| File.join(path, ".worktree-local") }, config.stow_source_dir
    end

    def test_linked_worktree_uses_hashed_port
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      config = load_config(worktree)
      expected_port = 3000 + (Digest::SHA256.hexdigest("mobile").to_i(16) % 1000)

      assert_equal 3000, config.calculated_port(repo)
      assert_equal expected_port, config.calculated_port(worktree)
    end

    def test_caddy_enabled_rejects_invalid_name
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, <<~YAML)
        caddy:
          enabled: true
          name: "invalid name"
      YAML

      assert_raises(ConfigError) { load_config(worktree) }
    end

    def test_caddy_enabled_requires_tls_cert_and_key_together
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, <<~YAML)
        caddy:
          enabled: true
          tls_cert: /tmp/cert.pem
      YAML

      assert_raises(ConfigError) { load_config(worktree) }
    end

    def test_invalid_conductor_port_falls_back_to_base_port
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      with_conductor_env(
        "CONDUCTOR_ROOT_PATH" => @tmpdir,
        "CONDUCTOR_PORT" => "not-a-number",
        "CONDUCTOR_WORKSPACE_NAME" => "madrid",
        "CONDUCTOR_WORKSPACE_PATH" => worktree
      ) do
        config = load_config(repo)
        assert_equal 3000, config.calculated_port(repo)
      end
    end

    def test_manual_port_from_worktree_config_overrides_conductor_port
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, <<~YAML)
        port:
          manual: 4123
      YAML

      with_conductor_env(
        "CONDUCTOR_ROOT_PATH" => @tmpdir,
        "CONDUCTOR_PORT" => "5678",
        "CONDUCTOR_WORKSPACE_NAME" => "madrid",
        "CONDUCTOR_WORKSPACE_PATH" => worktree
      ) do
        config = load_config(worktree)
        assert_equal 4123, config.calculated_port(worktree)
      end
    end

    def test_manual_port_from_worktree_config_overrides_hashing
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, <<~YAML)
        port:
          manual: 4123
      YAML

      config = load_config(worktree)

      assert_equal 4123, config.calculated_port(worktree)
      assert_equal 3000, config.calculated_port(repo)
    end

    def test_manual_port_is_rejected_in_shared_repo_config
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(repo, <<~YAML)
        port:
          manual: 4123
      YAML

      assert_raises(ConfigError) { load_config(worktree) }
    end
  end
end
