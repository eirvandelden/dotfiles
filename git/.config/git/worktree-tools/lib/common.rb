#!/usr/bin/env rv run ruby

require "fileutils"
require "pathname"
require "open3"

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
    #: (String message) -> void
    def log(message)
      puts message
    end

    #: (String message) -> void
    def debug(message)
      return unless ENV["DEBUG"]
      $stderr.puts "debug: #{message}"
    end

    #: (String message) -> void
    def warn(message)
      $stderr.puts "warning: #{message}"
    end

    #: (String message) -> void
    def error(message)
      $stderr.puts "error: #{message}"
    end

    #: (String message, ?Integer exit_code) -> bot
    def die(message, exit_code = EXIT_ERROR)
      error(message)
      exit(exit_code)
    end

    # Runs a command and returns its output and status. Without a time limit the command shares
    # the caller's process group, so Ctrl-C and terminal prompts reach it. With one (the
    # background sweep, which has no terminal and holds the repository's lock) it runs in its own
    # process group, which is killed, ssh included, once the limit passes.
    #: (*String command, ?time_limit: Numeric?) -> [String, Process::Status]
    def capture_output(*command, time_limit: nil)
      return Open3.capture2(*command, err: File::NULL) unless time_limit

      Open3.popen2(*command, err: File::NULL, pgroup: true) do |stdin, stdout, waiter|
        stdin.close
        reader = Thread.new { stdout.read }
        reader.report_on_exception = false
        return [ reader.value, waiter.value ] if waiter.join(time_limit)

        kill_group(waiter.pid)
        [ "", waiter.value ]
      end
    end

    # The group can end between the time-out and the kill.
    #: (Integer pid) -> nil
    def kill_group(pid)
      Process.kill("KILL", -pid)
      nil
    rescue Errno::ESRCH
      nil
    end

    # Git helpers
    #: (?(String | Pathname) path) -> Pathname?
    def git_root(path = ".")
      # Use array form to avoid shell injection
      output, status = Open3.capture2("git", "-C", path.to_s, "rev-parse", "--show-toplevel", err: "/dev/null")
      return nil if status.exitstatus != 0 || output.strip.empty?
      Pathname.new(output.strip)
    end

    #: (?(String | Pathname) path) -> String?
    def worktree_name(path = ".")
      repo_root = git_root(path)
      return nil unless repo_root

      current_path = Pathname.new(File.expand_path(path))
      current_path.basename.to_s
    end

    #: (?(String | Pathname) path) -> bool
    def main_worktree?(path = ".")
      git_dir = git_absolute_dir(path)
      common_dir = git_common_dir(path)
      return false unless git_dir && common_dir

      git_dir.realpath == common_dir.realpath
    end

    #: (?(String | Pathname) path) -> Pathname?
    def git_absolute_dir(path = ".")
      output, status = Open3.capture2("git", "-C", path.to_s, "rev-parse", "--absolute-git-dir", err: "/dev/null")
      return nil if status.exitstatus != 0 || output.strip.empty?

      Pathname.new(output.strip)
    end

    #: (?(String | Pathname) path) -> Pathname?
    def git_common_dir(path = ".")
      output, status = Open3.capture2("git", "-C", path.to_s, "rev-parse", "--git-common-dir", err: "/dev/null")
      return nil if status.exitstatus != 0 || output.strip.empty?

      common_dir = Pathname.new(output.strip)
      return common_dir.realpath if common_dir.absolute?

      base_path = Pathname.new(File.expand_path(path))
      base_path.join(common_dir).realpath
    rescue StandardError
      nil
    end

    # Conductor detection
    #: -> bool
    def in_conductor?
      !ENV["CONDUCTOR_ROOT_PATH"].nil? && !ENV["CONDUCTOR_ROOT_PATH"].empty?
    end

    #: -> Pathname?
    def conductor_root
      return nil unless in_conductor?
      Pathname.new(ENV["CONDUCTOR_ROOT_PATH"])
    end

    #: -> Pathname?
    def conductor_workspace_path
      return nil unless in_conductor?
      path = ENV["CONDUCTOR_WORKSPACE_PATH"]
      path ? Pathname.new(path) : nil
    end

    #: -> Integer?
    def conductor_port
      return nil unless in_conductor?
      raw_port = ENV["CONDUCTOR_PORT"]
      return nil if raw_port.nil? || raw_port.empty?

      port = Integer(raw_port, exception: false)
      return nil unless port && port.positive? && port <= 65_535

      port
    end

    #: -> String?
    def conductor_workspace_name
      return nil unless in_conductor?
      ENV["CONDUCTOR_WORKSPACE_NAME"]
    end

    # Command detection
    #: (String | Symbol command) -> bool
    def command_exists?(command)
      # Use array form to avoid shell injection
      _output, status = Open3.capture2("which", command.to_s, err: "/dev/null", out: "/dev/null")
      status.success?
    end

    # The herdr plugin scripts prefer HERDR_BIN_PATH over PATH; worktree-create and worktree-viewer match them.
    #: -> String
    def herdr_bin
      ENV["HERDR_BIN_PATH"].to_s.empty? ? "herdr" : ENV["HERDR_BIN_PATH"]
    end

    #: (String command, ?String? error_message) -> true
    def require_command(command, error_message = nil)
      return true if command_exists?(command)

      error_message ||= "#{command} is required but not found in PATH"
      die(error_message, EXIT_ERROR)
    end

    # Path helpers
    #: ((String | Pathname)? path, ?String base_dir) -> String?
    def expand_path(path, base_dir = Dir.pwd)
      return nil if path.nil?

      path_str = path.to_s
      if path_str.start_with?("~")
        File.expand_path(path_str)
      elsif Pathname.new(path_str).absolute?
        path_str
      else
        File.expand_path(path_str, base_dir)
      end
    end

    #: ((String | Pathname) path) -> void
    def ensure_directory(path)
      FileUtils.mkdir_p(path) unless Dir.exist?(path)
    end
  end
end
