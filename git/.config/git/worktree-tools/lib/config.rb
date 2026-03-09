#!/usr/bin/env rv run ruby

require "digest"
require "yaml"
require_relative "common"
require_relative "detect"

module WorktreeTools
  class WorktreeConfig
    include Helpers

    attr_reader :path, :detector, :config, :config_file

    def initialize(path = ".", detector = nil)
      @path = Pathname.new(File.expand_path(path))
      @detector = detector || ProjectDetector.new(@path).detect!
      @config = {}
      @config_file = nil
    end

    def load!
      @config_file = find_config_file
      file_config = @config_file ? load_yaml(@config_file) : {}

      @config = merge_with_defaults(file_config)
      expand_paths!
      validate!
      self
    end

    def [](key)
      @config[key]
    end

    def project_name
      @config.dig("project", "name") || @detector.project_info[:name] || "unknown"
    end

    def project_type
      @config.dig("project", "type")&.to_sym || @detector.project_type
    end

    def stow_enabled?
      @config.dig("stow", "enabled") == true
    end

    def stow_packages
      @config.dig("stow", "packages") || []
    end

    def stow_source_dir
      @config.dig("stow", "source_dir")
    end

    def stow_target
      @config.dig("stow", "target")
    end

    def puma_dev_enabled?
      @config.dig("puma_dev", "enabled") == true
    end

    def puma_dev_name
      @config.dig("puma_dev", "name")
    end

    def puma_dev_domain
      @config.dig("puma_dev", "domain") || "test"
    end

    def puma_dev_dir
      @config.dig("puma_dev", "dir")
    end

    def base_port
      @config.dig("port", "base") || 3000
    end

    def manual_port
      @config.dig("port", "manual")
    end

    def calculated_port(path)
      path = Pathname.new(File.expand_path(path))

      return manual_port if manual_port && same_path?(path, @path)
      return conductor_port if in_conductor? && conductor_port
      return base_port if main_worktree?(path)

      worktree_name_str = worktree_name(path) || "default"
      hash_value = Digest::SHA256.hexdigest(worktree_name_str).to_i(16)
      base_port + (hash_value % 1000)
    end

    def caddy_enabled?
      @config.dig("caddy", "enabled") == true
    end

    def caddy_name
      @config.dig("caddy", "name")
    end

    def caddy_tld
      @config.dig("caddy", "tld") || "localhost"
    end

    def caddy_project_name
      root = find_git_repo_root
      root ? root.basename.to_s : project_name
    end

    def caddy_tls_cert
      @config.dig("caddy", "tls_cert")
    end

    def caddy_tls_key
      @config.dig("caddy", "tls_key")
    end

    def caddy_config_dir
      @config.dig("caddy", "config_dir")
    end

    private

    def find_config_file
      # Look for .worktree.yml in the worktree root first
      repo_root = @detector.project_info[:root]
      if repo_root
        config_path = repo_root.join(".worktree.yml")
        return config_path if config_path.exist?
      end

      # For bare-repo worktree setups, the config lives in the git repository
      # root (the common dir parent), not inside the worktree directory itself
      git_repo_root = find_git_repo_root
      if git_repo_root && git_repo_root != repo_root
        config_path = git_repo_root.join(".worktree.yml")
        return config_path if config_path.exist?
      end

      nil
    end

    def find_git_repo_root
      common_dir = git_common_dir(@path)
      return nil unless common_dir

      # Regular repos: common dir ends with .git, its parent is the repo root
      # Bare repos: common dir is the repo root itself
      common_dir.basename.to_s == ".git" ? common_dir.dirname : common_dir
    rescue StandardError
      nil
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
      repo_root = find_git_repo_root || @detector.project_info[:root]

      # Default source dir based on environment
      default_source_dir = if in_conductor?
        conductor_root.join(".worktree-local").to_s
      elsif repo_root
        repo_root.join(".worktree-local").to_s
      else
        "~/.worktree-local"
      end

      {
        "project" => {
          "name" => @detector.project_info[:name],
          "type" => @detector.project_type.to_s
        },
        "stow" => {
          "enabled" => false,
          "packages" => [],
          "target" => @path.to_s,
          "source_dir" => default_source_dir
        },
        "puma_dev" => {
          "enabled" => @detector.rails? && @detector.puma_dev_compatible?,
          "name" => build_puma_dev_name,
          "domain" => "test",
          "dir" => File.expand_path("~/.puma-dev")
        },
        "caddy" => {
          "enabled" => false,
          "name" => build_caddy_name,
          "tld" => "localhost",
          "tls_cert" => nil,
          "tls_key" => nil,
          "config_dir" => File.expand_path("~/.config/caddy")
        },
        "port" => {
          "base" => 3000,
          "manual" => nil
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

    def build_caddy_name
      if in_conductor?
        conductor_workspace_name || @detector.project_info[:name]
      else
        @detector.project_info[:name]
      end
    end

    def expand_paths!
      base_dir = @config_file ? @config_file.dirname : @path

      # Expand stow source_dir
      if @config.dig("stow", "source_dir")
        @config["stow"]["source_dir"] = expand_path(@config["stow"]["source_dir"], base_dir)
      end

      # Expand stow target
      if @config.dig("stow", "target")
        @config["stow"]["target"] = expand_path(@config["stow"]["target"], base_dir)
      end

      # Expand puma_dev dir
      if @config.dig("puma_dev", "dir")
        @config["puma_dev"]["dir"] = expand_path(@config["puma_dev"]["dir"], base_dir)
      end

      # Expand caddy paths
      %w[config_dir tls_cert tls_key].each do |key|
        next unless @config.dig("caddy", key)
        @config["caddy"][key] = expand_path(@config["caddy"][key], base_dir)
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

      validate_port!
      validate_caddy!
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

    def validate_caddy!
      return unless caddy_enabled?

      validate_hostname_value!(caddy_name, "caddy name")
      validate_hostname_value!(caddy_project_name, "caddy project name")
      validate_hostname_value!(caddy_tld, "caddy tld")
      validate_caddy_tls_pair!
      validate_caddy_config_dir!
    end

    def validate_hostname_value!(value, label)
      return if valid_hostname_value?(value)

      raise ConfigError, "Invalid #{label}: #{value.inspect} (must contain DNS-safe labels separated by dots)"
    end

    def valid_hostname_value?(value)
      return false unless value.is_a?(String)
      return false if value.empty?

      labels = value.split(".")
      return false if labels.empty? || labels.any?(&:empty?)

      labels.all? { |label| label.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/) }
    end

    def validate_caddy_tls_pair!
      cert_present = caddy_tls_cert.is_a?(String) && !caddy_tls_cert.empty?
      key_present = caddy_tls_key.is_a?(String) && !caddy_tls_key.empty?
      return if cert_present == key_present

      raise ConfigError, "Caddy tls_cert and tls_key must both be set when caddy is enabled"
    end

    def validate_caddy_config_dir!
      return if caddy_config_dir.is_a?(String) && !caddy_config_dir.empty?

      raise ConfigError, "Caddy config directory is required when caddy is enabled"
    end

    def validate_port!
      validate_base_port!
      validate_manual_port!
    end

    def validate_base_port!
      normalized_base_port = Integer(base_port, exception: false)
      return if valid_port_value?(normalized_base_port)

      raise ConfigError, "Invalid base port: #{base_port.inspect} (must be an integer between 1 and 65535)"
    ensure
      @config["port"]["base"] = normalized_base_port if normalized_base_port
    end

    def validate_manual_port!
      return if @config.dig("port", "manual").nil?

      unless config_from_worktree_root?
        raise ConfigError, "Manual port is only allowed in .worktree.yml inside the current worktree root"
      end

      normalized_manual_port = Integer(@config.dig("port", "manual"), exception: false)
      if valid_port_value?(normalized_manual_port)
        @config["port"]["manual"] = normalized_manual_port
        return
      end

      raise ConfigError, "Invalid manual port: #{@config.dig('port', 'manual').inspect} (must be an integer between 1 and 65535)"
    end

    def valid_port_value?(port)
      port.is_a?(Integer) && port.positive? && port <= 65_535
    end

    def config_from_worktree_root?
      return false unless @config_file

      same_path?(@config_file, @path.join(".worktree.yml"))
    end

    def same_path?(left, right)
      left_path = Pathname.new(left).expand_path
      right_path = Pathname.new(right).expand_path
      return left_path.realpath == right_path.realpath if left_path.exist? && right_path.exist?

      left_path == right_path
    rescue StandardError
      false
    end
  end
end
