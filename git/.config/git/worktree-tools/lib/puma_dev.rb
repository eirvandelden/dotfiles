#!/usr/bin/env rv run ruby

require 'digest'
require_relative 'common'
require_relative 'config'

module WorktreeTools
  class PumaDev
    include Helpers

    attr_reader :config, :path

    def initialize(config, path = '.')
      @config = config
      @path = Pathname.new(File.expand_path(path))
    end

    def setup!
      unless @config.puma_dev_enabled?
        log "Puma-dev is disabled, skipping setup"
        return
      end

      validate_rack_app!

      puma_dev_dir = Pathname.new(@config.puma_dev_dir)
      ensure_directory(puma_dev_dir)

      symlink_name = @config.puma_dev_name
      symlink_path = puma_dev_dir.join(symlink_name)
      port = calculate_port

      log "Setting up puma-dev..."
      log "  URL: https://#{symlink_name}.#{@config.puma_dev_domain}"
      log "  Port: #{port}"

      # Create port file (tells puma-dev which port to proxy to)
      create_port_symlink(symlink_path, port)

      log "Puma-dev setup complete"
    end

    def remove!
      unless @config.puma_dev_enabled?
        return
      end

      puma_dev_dir = Pathname.new(@config.puma_dev_dir)
      symlink_name = @config.puma_dev_name
      symlink_path = puma_dev_dir.join(symlink_name)

      if symlink_path.exist? || symlink_path.symlink?
        log "Removing puma-dev symlink: #{symlink_name}"
        FileUtils.rm_f(symlink_path)
        log "Puma-dev symlink removed"
      else
        log "No puma-dev symlink to remove"
      end
    end

    private

    def validate_rack_app!
      # Check for config.ru or config/application.rb
      has_config_ru = @path.join('config.ru').exist?
      has_rails_app = @path.join('config', 'application.rb').exist?

      unless has_config_ru || has_rails_app
        raise PumaDevError, "Not a valid Rack/Rails application (missing config.ru or config/application.rb)"
      end
    end

    def calculate_port
      # Conductor takes precedence
      return conductor_port if in_conductor? && conductor_port

      # Main worktree uses base_port
      if main_worktree?(@path)
        return @config.base_port
      end

      # Feature worktrees use hash-based stable port offset
      worktree_name_str = worktree_name(@path) || 'default'
      hash_value = Digest::SHA256.hexdigest(worktree_name_str).to_i(16)
      offset = hash_value % 1000

      @config.base_port + offset
    end

    def create_port_symlink(symlink_path, port)
      # Remove existing symlink if it exists
      FileUtils.rm_f(symlink_path) if symlink_path.exist? || symlink_path.symlink?

      # Puma-dev expects either:
      # 1. A symlink to the project directory (it will auto-detect port via Procfile or use default)
      # 2. A file containing just the port number

      # For Conductor compatibility and explicit port control, we create a file with the port number
      # But we need to write it through a temp file approach since puma-dev prefers directories

      # Actually, per puma-dev docs, we should create a symlink to the directory
      # and let puma-dev handle port via PORT env var or .pumadev file

      # Let's create a .pumadev file in the worktree root with the port
      pumadev_file = @path.join('.pumadev')
      File.write(pumadev_file, port.to_s)

      # Create symlink to the worktree directory
      FileUtils.ln_sf(@path, symlink_path)
    end
  end
end
