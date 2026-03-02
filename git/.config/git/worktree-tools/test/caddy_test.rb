#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "common"
require "detect"
require "config"
require "caddy"

module WorktreeTools
  class CaddyDevTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
      @caddy_config_dir = File.join(@tmpdir, "caddy")
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    def setup_git_repo(name = "repo")
      path = File.join(@tmpdir, name)
      FileUtils.mkdir_p(path)
      system("git", "-C", path, "init", "-q")
      system("git", "-C", path, "commit", "--allow-empty", "-m", "init", "-q")
      rails_structure(path)
      path
    end

    def setup_repo_with_linked_worktree(repo_name: "repo", worktree_name: "mobile")
      repo = setup_git_repo(repo_name)
      worktree = File.join(@tmpdir, worktree_name)
      system("git", "-C", repo, "worktree", "add", "-q", worktree, "-b", worktree_name)
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

    def caddy_files
      Dir.glob(File.join(@caddy_config_dir, "*.caddy"))
    end

    def without_conductor
      saved = %w[CONDUCTOR_ROOT_PATH CONDUCTOR_PORT CONDUCTOR_WORKSPACE_NAME CONDUCTOR_WORKSPACE_PATH].map do |k|
        [ k, ENV.delete(k) ]
      end
      yield
    ensure
      saved.each { |k, v| ENV[k] = v if v }
    end

    # --- setup! ---

    def test_setup_writes_caddy_file
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      CaddyDev.new(config, repo).setup!

      assert_equal 1, caddy_files.size
    end

    def test_main_worktree_hostname_uses_project_only
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      without_conductor do
        config = load_config(repo)
        CaddyDev.new(config, repo).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, "myapp.localhost"
      assert_nil content.match(/myapp\.myapp\.localhost/)
    end

    def test_feature_worktree_hostname_uses_worktree_and_project
      repo, worktree = setup_repo_with_linked_worktree(repo_name: "myapp", worktree_name: "mobile")
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      without_conductor do
        config = load_config(worktree)
        CaddyDev.new(config, worktree).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, "mobile.myapp.localhost"
    end

    def test_main_named_worktree_can_use_project_hostname
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          name: main
          config_dir: #{@caddy_config_dir}
      YAML

      without_conductor do
        config = load_config(repo)
        CaddyDev.new(config, repo).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, "myapp.localhost"
      assert_nil content.match(/main\.myapp\.localhost/)
    end

    def test_tld_defaults_to_localhost
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      without_conductor do
        config = load_config(repo)
        CaddyDev.new(config, repo).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, ".localhost"
    end

    def test_tld_can_be_overridden
      repo = setup_git_repo("myapp")
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          tld: test
          config_dir: #{@caddy_config_dir}
      YAML

      without_conductor do
        config = load_config(repo)
        CaddyDev.new(config, repo).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, "myapp.test"
    end

    def test_setup_file_contains_port
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
        port:
          base: 4567
      YAML

      without_conductor do
        config = load_config(repo)
        CaddyDev.new(config, repo).setup!
      end

      content = File.read(caddy_files.first)
      assert_includes content, "4567"
    end

    def test_setup_uses_tls_internal_when_no_cert_configured
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      CaddyDev.new(config, repo).setup!

      content = File.read(caddy_files.first)
      assert_includes content, "tls internal"
    end

    def test_setup_uses_cert_files_when_configured
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          tls_cert: /path/to/cert.pem
          tls_key: /path/to/key.pem
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      CaddyDev.new(config, repo).setup!

      content = File.read(caddy_files.first)
      assert_includes content, "tls /path/to/cert.pem /path/to/key.pem"
    end

    def test_setup_skipped_when_disabled
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: false
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      CaddyDev.new(config, repo).setup!

      assert_empty caddy_files
    end

    # --- remove! ---

    def test_remove_deletes_caddy_file
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      caddy = CaddyDev.new(config, repo)
      caddy.setup!
      caddy.remove!

      assert_empty caddy_files
    end

    def test_remove_is_idempotent_when_no_file_exists
      repo = setup_git_repo
      worktree_yml(repo, <<~YAML)
        caddy:
          enabled: true
          config_dir: #{@caddy_config_dir}
      YAML

      config = load_config(repo)
      caddy = CaddyDev.new(config, repo)

      caddy.remove! # should not raise
    end
  end
end
