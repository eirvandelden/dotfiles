#!/usr/bin/env rv run ruby

require_relative 'common'
require_relative 'config'

module WorktreeTools
  class Symlinker
    include Helpers

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def setup!
      unless @config.stow_enabled?
        log "Stow is disabled, skipping symlink setup"
        return
      end

      validate_stow!
      validate_packages!

      log "Setting up symlinks via GNU Stow..."
      @config.stow_packages.each do |package|
        stow_package(package, :restow)
      end

      log "Symlinks setup complete"
    end

    def remove!
      unless @config.stow_enabled?
        return
      end

      validate_stow!

      log "Removing symlinks via GNU Stow..."
      @config.stow_packages.each do |package|
        stow_package(package, :delete)
      end

      log "Symlinks removed"
    end

    private

    def validate_stow!
      require_command(
        'stow',
        "GNU Stow is required but not installed. Install it with: brew install stow"
      )
    end

    def validate_packages!
      source_dir = Pathname.new(@config.stow_source_dir)

      unless source_dir.exist?
        raise StowError, "Stow source directory does not exist: #{source_dir}"
      end

      missing_packages = []
      @config.stow_packages.each do |package|
        package_dir = source_dir.join(package)
        unless package_dir.exist?
          missing_packages << package
        end
      end

      unless missing_packages.empty?
        raise StowError, "Missing stow packages in #{source_dir}: #{missing_packages.join(', ')}"
      end
    end

    def stow_package(package, operation)
      source_dir = @config.stow_source_dir
      target_dir = @config.stow_target

      action = operation == :delete ? '--delete' : '--restow'
      command = "stow #{action} --dir='#{source_dir}' --target='#{target_dir}' '#{package}'"

      log "  #{operation == :delete ? 'Removing' : 'Installing'} package: #{package}"

      output = `#{command} 2>&1`
      exit_code = $?.exitstatus

      if exit_code != 0
        raise StowError, "Failed to #{operation} package '#{package}': #{output}"
      end

      # Check for warnings (stow prints warnings even with exit code 0)
      if output.include?('WARNING')
        warn "Stow warning for package '#{package}': #{output}"
      end
    end
  end
end
