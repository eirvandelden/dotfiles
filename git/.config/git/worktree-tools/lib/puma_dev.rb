#!/usr/bin/env rv run ruby

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
      @config.calculated_port(@path)
    end

    def create_port_symlink(symlink_path, port)
      # Remove existing entry if it exists
      FileUtils.rm_f(symlink_path) if symlink_path.exist? || symlink_path.symlink?

      # Puma-dev proxies to an existing server when ~/.puma-dev/<name> is a plain
      # text file containing just the port number.
      File.write(symlink_path, port.to_s)
    end
  end
end
