#!/usr/bin/env ruby

require 'find'
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
  # files in the Stow packages. Won't touch unrelated files. Files the
  # package's .stow-local-ignore excludes are left alone too -- Stow will
  # never link those, so deleting the target's copy would simply lose it.
  class FileCleaner
    include Helpers

    STOW_IGNORE_FILE = '.stow-local-ignore'

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
      ignores = ignore_patterns(package_dir)
      conflicting = []

      Find.find(package_dir) do |source_path|
        # Skip directories
        next unless File.file?(source_path)

        # Get relative path from package root
        rel_path = source_path.sub("#{package_dir}/", '')
        next if stow_skips?(rel_path, ignores)

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

    # Files Stow will not link, so the target's own copy must survive
    def stow_skips?(rel_path, ignores)
      return true if File.basename(rel_path) == STOW_IGNORE_FILE

      ignores.any? { |pattern, matches_full_path| pattern.match?(matches_full_path ? rel_path : File.basename(rel_path)) }
    end

    # Parse the package's .stow-local-ignore into [regexp, matches_full_path] pairs.
    # Stow matches a pattern containing a slash against the path relative to the
    # package root, and any other pattern against the basename alone.
    def ignore_patterns(package_dir)
      ignore_file = File.join(package_dir, STOW_IGNORE_FILE)
      return [] unless File.file?(ignore_file)

      File.readlines(ignore_file, chomp: true).filter_map do |line|
        pattern = line.strip
        next if pattern.empty? || pattern.start_with?('#')

        compiled = compile_ignore_pattern(pattern)
        [ compiled, pattern.include?('/') ] if compiled
      end
    end

    # Stow anchors each pattern, so an unanchored name never matches a substring
    def compile_ignore_pattern(pattern)
      Regexp.new("\\A#{pattern.delete_prefix('^').sub(/(?<!\\)\$\z/, '')}\\z")
    rescue RegexpError => e
      warn "Skipping invalid #{STOW_IGNORE_FILE} pattern #{pattern.inspect}: #{e.message}"
      nil
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
