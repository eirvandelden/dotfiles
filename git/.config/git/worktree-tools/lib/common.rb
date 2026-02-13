#!/usr/bin/env rv run ruby

require 'fileutils'
require 'pathname'

module WorktreeTools
  # Exit codes
  EXIT_SUCCESS = 0
  EXIT_ERROR = 1
  EXIT_CONFIG_ERROR = 2
  EXIT_STOW_ERROR = 3
  EXIT_DETECTION_ERROR = 4

  # Custom exception hierarchy
  class Error < StandardError; end
  class ConfigError < Error; end
  class StowError < Error; end
  class DetectionError < Error; end
  class PumaDevError < Error; end

  module Helpers
    # Logging methods
    def log(message)
      puts message
    end

    def warn(message)
      $stderr.puts "warning: #{message}"
    end

    def error(message)
      $stderr.puts "error: #{message}"
    end

    def die(message, exit_code = EXIT_ERROR)
      error(message)
      exit(exit_code)
    end

    # Git helpers
    def git_root(path = '.')
      result = `git -C "#{path}" rev-parse --show-toplevel 2>/dev/null`.strip
      return nil if $?.exitstatus != 0 || result.empty?
      Pathname.new(result)
    end

    def worktree_name(path = '.')
      repo_root = git_root(path)
      return nil unless repo_root

      current_path = Pathname.new(File.expand_path(path))
      current_path.basename.to_s
    end

    def main_worktree?(path = '.')
      repo_root = git_root(path)
      return false unless repo_root

      current_path = Pathname.new(File.expand_path(path))
      current_path.realpath == repo_root.realpath
    end

    # Conductor detection
    def in_conductor?
      !ENV['CONDUCTOR_ROOT_PATH'].nil? && !ENV['CONDUCTOR_ROOT_PATH'].empty?
    end

    def conductor_root
      return nil unless in_conductor?
      Pathname.new(ENV['CONDUCTOR_ROOT_PATH'])
    end

    def conductor_workspace_path
      return nil unless in_conductor?
      path = ENV['CONDUCTOR_WORKSPACE_PATH']
      path ? Pathname.new(path) : nil
    end

    def conductor_port
      return nil unless in_conductor?
      port = ENV['CONDUCTOR_PORT']
      port ? port.to_i : nil
    end

    def conductor_workspace_name
      return nil unless in_conductor?
      ENV['CONDUCTOR_WORKSPACE_NAME']
    end

    # Command detection
    def command_exists?(command)
      system("command -v #{command} > /dev/null 2>&1")
    end

    def require_command(command, error_message = nil)
      return true if command_exists?(command)

      error_message ||= "#{command} is required but not found in PATH"
      die(error_message, EXIT_ERROR)
    end

    # Path helpers
    def expand_path(path, base_dir = Dir.pwd)
      return nil if path.nil?

      path_str = path.to_s
      if path_str.start_with?('~')
        File.expand_path(path_str)
      elsif Pathname.new(path_str).absolute?
        path_str
      else
        File.expand_path(path_str, base_dir)
      end
    end

    def ensure_directory(path)
      FileUtils.mkdir_p(path) unless Dir.exist?(path)
    end
  end
end
