#!/usr/bin/env ruby

require_relative 'common'

module WorktreeTools
  # Cleans conflicting files before Stow creates symlinks
  #
  # Problem: If a file exists in both .worktree-local/package/ and the target
  # directory, Stow will fail with "file already exists" error.
  #
  # Solution: Before running Stow, delete any files in the target directory
  # that would conflict with files in the source packages.
  #
  # Safety: Only deletes files (not directories), and only if they match
  # files in the Stow packages. Won't touch unrelated files.
  class FileCleaner
    include Helpers

    def initialize(source_dir, target_dir, packages)
      @source_dir = File.expand_path(source_dir)
      @target_dir = File.expand_path(target_dir)
      @packages = Array(packages)
    end

    # Clean conflicting files from target directory
    #
    # @return [Array<String>] List of deleted file paths
    def clean!
      deleted_files = []

      @packages.each do |package|
        package_dir = File.join(@source_dir, package)
        next unless File.directory?(package_dir)

        files_to_delete = find_conflicting_files(package_dir)
        files_to_delete.each do |file_path|
          if delete_file(file_path)
            deleted_files << file_path
          end
        end
      end

      log_results(deleted_files)
      deleted_files
    end

    private

    # Find files in target that conflict with package files
    def find_conflicting_files(package_dir)
      conflicting = []

      Find.find(package_dir) do |source_path|
        # Skip directories
        next unless File.file?(source_path)

        # Get relative path from package root
        rel_path = source_path.sub("#{package_dir}/", '')

        # Check if this file exists in target
        target_path = File.join(@target_dir, rel_path)
        if File.exist?(target_path) && !File.symlink?(target_path)
          conflicting << target_path
        end
      end

      conflicting
    rescue Errno::ENOENT
      # Package directory doesn't exist, skip
      []
    end

    # Delete a single file
    def delete_file(file_path)
      return false unless File.exist?(file_path)
      return false if File.symlink?(file_path) # Don't delete existing symlinks
      return false if File.directory?(file_path) # Don't delete directories

      debug "Deleting conflicting file: #{file_path}"
      File.delete(file_path)
      true
    rescue => e
      warn "Failed to delete #{file_path}: #{e.message}"
      false
    end

    # Log cleaning results
    def log_results(deleted_files)
      if deleted_files.empty?
        debug "No conflicting files found"
      else
        log "Cleaned #{deleted_files.size} conflicting file(s)"
        deleted_files.each do |path|
          debug "  Deleted: #{path}"
        end
      end
    end
  end
end
