#!/usr/bin/env rv run ruby

require 'yaml'
require_relative 'common'
require_relative 'detect'

module WorktreeTools
  class WorktreeConfig
    include Helpers

    attr_reader :path, :detector, :config

    def initialize(path = '.', detector = nil)
      @path = Pathname.new(File.expand_path(path))
      @detector = detector || ProjectDetector.new(@path).detect!
      @config = {}
    end

    def load!
      config_file = find_config_file
      file_config = config_file ? load_yaml(config_file) : {}

      @config = merge_with_defaults(file_config)
      expand_paths!
      validate!
      self
    end

    def [](key)
      @config[key]
    end

    def project_name
      @config.dig('project', 'name') || @detector.project_info[:name] || 'unknown'
    end

    def project_type
      @config.dig('project', 'type')&.to_sym || @detector.project_type
    end

    def stow_enabled?
      @config.dig('stow', 'enabled') == true
    end

    def stow_packages
      @config.dig('stow', 'packages') || []
    end

    def stow_source_dir
      @config.dig('stow', 'source_dir')
    end

    def stow_target
      @config.dig('stow', 'target')
    end

    def puma_dev_enabled?
      @config.dig('puma_dev', 'enabled') == true
    end

    def puma_dev_name
      @config.dig('puma_dev', 'name')
    end

    def puma_dev_domain
      @config.dig('puma_dev', 'domain') || 'test'
    end

    def puma_dev_dir
      @config.dig('puma_dev', 'dir')
    end

    def base_port
      @config.dig('port', 'base') || 3000
    end

    private

    def find_config_file
      # Look for .worktree.yml in repo root
      repo_root = @detector.project_info[:root]
      return nil unless repo_root

      config_path = repo_root.join('.worktree.yml')
      config_path.exist? ? config_path : nil
    end

    def load_yaml(file_path)
      YAML.safe_load_file(file_path)
    rescue => e
      warn "Failed to load config file #{file_path}: #{e.message}"
      {}
    end

    def merge_with_defaults(file_config)
      defaults = build_defaults
      deep_merge(defaults, file_config)
    end

    def build_defaults
      repo_root = @detector.project_info[:root]

      # Default source dir based on environment
      default_source_dir = if in_conductor?
        conductor_root.join('.worktree-local').to_s
      elsif repo_root
        repo_root.join('.worktree-local').to_s
      else
        '~/.worktree-local'
      end

      {
        'project' => {
          'name' => @detector.project_info[:name],
          'type' => @detector.project_type.to_s
        },
        'stow' => {
          'enabled' => false,
          'packages' => [],
          'target' => @path.to_s,
          'source_dir' => default_source_dir
        },
        'puma_dev' => {
          'enabled' => @detector.rails? && @detector.puma_dev_compatible?,
          'name' => build_puma_dev_name,
          'domain' => 'test',
          'dir' => File.expand_path('~/.puma-dev')
        },
        'port' => {
          'base' => 3000
        }
      }
    end

    def build_puma_dev_name
      # Main worktree: <project>
      # Feature worktree: <worktree-name>.<project>
      # Conductor workspace: <workspace-name>.<project>

      # Get the actual project name from the git root
      repo_root = @detector.project_info[:root]
      project_name = repo_root ? repo_root.basename.to_s : @detector.project_info[:name]

      if in_conductor?
        workspace_name = conductor_workspace_name
        return workspace_name ? "#{workspace_name}.#{project_name}" : project_name
      end

      if @detector.project_info[:is_main_worktree]
        project_name
      else
        # Use the worktree directory name
        worktree_name = @detector.project_info[:name]
        "#{worktree_name}.#{project_name}"
      end
    end

    def expand_paths!
      # Expand stow source_dir
      if @config.dig('stow', 'source_dir')
        @config['stow']['source_dir'] = expand_path(@config['stow']['source_dir'], @path)
      end

      # Expand stow target
      if @config.dig('stow', 'target')
        @config['stow']['target'] = expand_path(@config['stow']['target'], @path)
      end

      # Expand puma_dev dir
      if @config.dig('puma_dev', 'dir')
        @config['puma_dev']['dir'] = expand_path(@config['puma_dev']['dir'])
      end
    end

    def validate!
      # Validate project name
      if project_name.nil? || project_name.empty?
        raise ConfigError, "Project name is required"
      end

      # Validate stow configuration
      if stow_enabled?
        unless Dir.exist?(stow_source_dir)
          raise ConfigError, "Stow source directory does not exist: #{stow_source_dir}"
        end

        if stow_packages.empty?
          raise ConfigError, "Stow is enabled but no packages are specified"
        end
      end

      # Validate puma_dev configuration
      if puma_dev_enabled?
        unless @detector.puma_dev_compatible?
          raise ConfigError, "Puma-dev is enabled but project is not compatible (missing config.ru or config/application.rb)"
        end

        # Validate puma_dev name (no spaces, valid DNS characters)
        unless puma_dev_name.match?(/^[a-z0-9.-]+$/)
          raise ConfigError, "Invalid puma-dev name: #{puma_dev_name} (must contain only lowercase letters, numbers, dots, and hyphens)"
        end
      end
    end

    def deep_merge(hash1, hash2)
      result = hash1.dup
      hash2.each do |key, value|
        result[key] = if result[key].is_a?(Hash) && value.is_a?(Hash)
          deep_merge(result[key], value)
        else
          value
        end
      end
      result
    end
  end
end
