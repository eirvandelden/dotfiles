#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "common"
require "file_cleaner"

module WorktreeTools
  class FileCleanerTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
      @source_dir = File.join(@tmpdir, "packages")
      @target_dir = File.join(@tmpdir, "project")
      FileUtils.mkdir_p(File.join(@source_dir, "app"))
      FileUtils.mkdir_p(@target_dir)
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    def test_removes_a_project_file_the_package_will_replace
      write_package_file(".env", "SHARED=1")
      write_project_file(".env", "STALE=1")

      clean!

      refute project_file_exists?(".env"),
        "the package provides .env, so the project's copy must make way for the symlink"
    end

    def test_keeps_a_project_file_the_package_ignores
      write_package_file("README.md", "docs about this package")
      write_package_ignore("^README\\.md$")
      write_project_file("README.md", "the project's own readme")

      clean!

      assert_equal "the project's own readme", project_file("README.md"),
        "stow never links an ignored file, so deleting the project's copy would just lose it"
    end

    def test_keeps_a_project_file_matched_by_a_bare_name_in_the_ignore_list
      write_package_file("Procfile.dev", "package version")
      write_package_ignore("Procfile.dev")
      write_project_file("Procfile.dev", "project version")

      clean!

      assert_equal "project version", project_file("Procfile.dev")
    end

    def test_ignores_blank_lines_and_comments_in_the_ignore_list
      write_package_file(".env", "SHARED=1")
      write_package_ignore("# a comment\n\n^README\\.md$\n")
      write_project_file(".env", "STALE=1")

      clean!

      refute project_file_exists?(".env"),
        "only the listed patterns are ignored; everything else still gets cleaned"
    end

    def test_never_links_the_ignore_list_itself
      write_package_file(".env", "SHARED=1")
      write_package_ignore("^README\\.md$")
      write_project_file(".stow-local-ignore", "the project's own")

      clean!

      assert_equal "the project's own", project_file(".stow-local-ignore"),
        "stow treats its ignore list as metadata, not as a file to link"
    end

    def test_matches_a_nested_path_pattern
      write_package_file("app/secret.key", "package version")
      write_package_ignore("app/secret\\.key")
      write_project_file("app/secret.key", "project version")

      clean!

      assert_equal "project version", project_file("app/secret.key")
    end

    private

    def clean!
      FileCleaner.new(@source_dir, @target_dir, [ "app" ]).clean!
    end

    def write_package_file(rel_path, contents)
      path = File.join(@source_dir, "app", rel_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end

    def write_package_ignore(contents)
      File.write(File.join(@source_dir, "app", ".stow-local-ignore"), contents)
    end

    def write_project_file(rel_path, contents)
      path = File.join(@target_dir, rel_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end

    def project_file(rel_path)
      File.read(File.join(@target_dir, rel_path))
    end

    def project_file_exists?(rel_path)
      File.exist?(File.join(@target_dir, rel_path))
    end
  end
end
