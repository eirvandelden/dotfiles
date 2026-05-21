#!/usr/bin/env rv run ruby
require_relative "common"
require_relative "config"

module WorktreeTools
  class PortlessDev
    include Helpers

    def initialize(config, path = ".")
      @config = config
      @path = Pathname.new(File.expand_path(path))
    end

    def setup!
      return unless @config.portless_enabled?

      unless command_exists?("portless")
        raise Error, "portless is required when portless is enabled. Install with: npm install -g portless"
      end

      hostname = build_hostname
      port = @config.calculated_port(@path)

      log "Setting up Portless..."
      log "  URL: https://#{hostname}"
      log "  Port: #{port}"

      register_alias(hostname, port)
      log "Portless setup complete"
    end

    def remove!
      return unless command_exists?("portless")

      hostname = build_hostname
      log "Portless route removed: #{hostname}" if unregister_alias(hostname)
    end

    private

    def build_hostname
      if main_hostname?
        "#{@config.portless_project_name}.#{@config.portless_tld}"
      else
        "#{@config.portless_name}.#{@config.portless_project_name}.#{@config.portless_tld}"
      end
    end

    def main_hostname?
      @config.portless_name == @config.portless_project_name ||
        @config.portless_name == "main"
    end

    def register_alias(hostname, port)
      _output, status = Open3.capture2("portless", "alias", hostname, port.to_s, "--force")
      raise Error, "Failed to register Portless alias for #{hostname}" unless status.success?
    end

    def unregister_alias(hostname)
      _output, status = Open3.capture2("portless", "alias", "--remove", hostname)
      status.success?
    end
  end
end
