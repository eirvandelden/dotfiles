#!/usr/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'common'
require 'detect'
require 'config'

module WorktreeTools
  class ConfigFindConfigFileTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    # Sets up a regular (non-bare) git repo with a linked worktree:
    #   repo/          <- main repo (has .git/)
    #   repo/mobile/   <- linked worktree
    def setup_regular_repo_with_worktree
      repo = File.join(@tmpdir, 'repo')
      FileUtils.mkdir_p(repo)
      system('git', '-C', repo, 'init', '-q')
      system('git', '-C', repo, 'commit', '--allow-empty', '-m', 'init', '-q')

      worktree = File.join(@tmpdir, 'mobile')
      system('git', '-C', repo, 'worktree', 'add', '-q', worktree, '-b', 'mobile')

      [ repo, worktree ]
    end

    # Sets up a bare-style repo (no main worktree checkout) with a linked worktree:
    #   caren/          <- bare repo (no .git subdir, is itself the git dir)
    #   caren/mobile/   <- linked worktree inside the bare repo dir
    def setup_bare_repo_with_worktree
      bare = File.join(@tmpdir, 'caren')
      FileUtils.mkdir_p(bare)
      system('git', '-C', bare, 'init', '--bare', '-q')

      # Seed the bare repo with a commit via a temp clone
      clone = File.join(@tmpdir, 'clone')
      system('git', 'clone', '-q', bare, clone)
      system('git', '-C', clone, 'commit', '--allow-empty', '-m', 'init', '-q')
      system('git', '-C', clone, 'push', '-q', 'origin', 'main')
      FileUtils.rm_rf(clone)

      worktree = File.join(bare, 'mobile')
      system('git', '-C', bare, 'worktree', 'add', '-q', worktree, 'main')

      [ bare, worktree ]
    end

    def rails_structure(path)
      FileUtils.mkdir_p(File.join(path, 'config'))
      FileUtils.touch(File.join(path, 'Gemfile'))
      FileUtils.touch(File.join(path, 'config', 'application.rb'))
      FileUtils.touch(File.join(path, 'config.ru'))
    end

    def worktree_yml(path, content)
      File.write(File.join(path, '.worktree.yml'), content)
    end

    def load_config(worktree_path)
      detector = ProjectDetector.new(worktree_path).detect!
      WorktreeConfig.new(worktree_path, detector).load!
    end

    # --- Regular repo: config in worktree root ---

    def test_finds_config_in_worktree_root_for_regular_repo
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(worktree, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      refute config.puma_dev_enabled?, 'puma-dev should be disabled'
    end

    # --- Regular repo: config in repo root (main worktree) ---

    def test_finds_config_in_repo_root_for_regular_repo
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(repo, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      refute config.puma_dev_enabled?, 'puma-dev should be disabled when config is in the git repo root'
    end

    # --- Bare repo: config in bare repo root ---

    def test_finds_config_in_bare_repo_root
      bare, worktree = setup_bare_repo_with_worktree
      rails_structure(worktree)
      worktree_yml(bare, "puma_dev:\n  enabled: false\n")

      config = load_config(worktree)

      refute config.puma_dev_enabled?, 'puma-dev should be disabled when config is in the bare repo root'
    end

    # --- No config file: falls back to defaults ---

    def test_defaults_to_puma_dev_enabled_for_rails_project_without_config
      repo, worktree = setup_regular_repo_with_worktree
      rails_structure(worktree)

      config = load_config(worktree)

      assert config.puma_dev_enabled?, 'puma-dev should be enabled by default for rails projects'
    end
  end
end
