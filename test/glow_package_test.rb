#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require_relative "isolated_git"

# The glow package carries only the committed copy of the generated Solunized style. Glow's own
# config stays a plain file, because the style path in it must be absolute and the repository is
# public. The install step (install/tasks/51_configure_glow_style.sh) writes that path.
class GlowPackageTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  GLOW_DIRECTORY = File.join(REPO_ROOT, "glow/Library/Preferences/glow")

  def test_the_package_holds_a_valid_glamour_style
    style = JSON.parse(File.read(File.join(GLOW_DIRECTORY, "solunized.json")))

    assert_kind_of(Hash, style)
    assert_includes(style, "document")
  end

  def test_the_package_holds_no_glow_yml
    refute_path_exists(File.join(GLOW_DIRECTORY, "glow.yml"))
  end

  def test_packages_conf_stows_glow
    assert_includes(bash_array("STOW"), "glow")
  end

  def test_packages_conf_links_glow_file_by_file
    assert_includes(bash_array("STOW_SHARED"), "glow")
  end

  private

  def bash_array(name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), File.join(REPO_ROOT, "packages.conf")
    )
    raise stderr unless status.success?

    stdout.split("\n")
  end
end
