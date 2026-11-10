#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# GNU Stow maps a package's top-level entries onto $HOME: `zsh/.zshrc` becomes `~/.zshrc`, which
# is the point. The mapping does not care whether a file was meant to go there, and `README.md`
# is not in .stow-global-ignore — so a README written at a package root silently becomes
# `~/README.md`. Nothing complains: stow succeeds, and the stray file is found months later.
#
# Every package root in this repository holds only dot-prefixed entries. This is the guard for
# that, over exactly the packages packages.conf declares.
class StowPackageRootsTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)

  # Non-dot directories that a named package may hold at its root because they are real $HOME
  # directories. macOS keeps glow's config in ~/Library, so `glow/Library` is intended.
  # `rex/Library` holds a LaunchAgent plist for ~/Library/LaunchAgents.
  HOME_DIRECTORIES = { "glow" => [ "Library" ], "rex" => [ "Library" ] }.freeze

  def test_a_package_of_only_dotfiles_is_accepted
    root = fixture_repository("tidy" => [ ".config", ".gitignore" ])

    assert_empty(strays_in(root))
  end

  def test_a_readme_at_a_package_root_is_rejected
    root = fixture_repository("untidy" => [ ".config", "README.md" ])

    assert_equal([ "untidy/README.md" ], strays_in(root))
  end

  def test_the_rejection_names_the_file_and_where_it_would_land
    root = fixture_repository("untidy" => [ "README.md" ])

    report = stray_report(strays_in(root))

    assert_includes(report, "untidy/README.md")
    assert_includes(report, "~/README.md")
  end

  def test_the_checked_packages_come_from_packages_conf
    root = fixture_repository("declared" => [ "README.md" ])
    FileUtils.mkdir_p(File.join(root, "undeclared"))
    FileUtils.touch(File.join(root, "undeclared", "README.md"))

    assert_equal([ "declared/README.md" ], strays_in(root))
  end

  def test_an_allowed_home_directory_at_its_package_root_is_accepted
    root = fixture_repository("glow" => [ ".config", "Library" ])

    assert_empty(strays_in(root))
  end

  def test_an_allowed_home_directory_at_another_package_root_is_rejected
    root = fixture_repository("other" => [ "Library" ])

    assert_equal([ "other/Library" ], strays_in(root))
  end

  def test_every_stowed_package_root_holds_only_dotfiles
    strays = strays_in(REPO_ROOT)

    assert_empty(strays, stray_report(strays))
  end

  # A file in git's index under a declared package's folder makes it a tracked package folder.
  #: () -> void
  def test_a_declared_package_with_a_tracked_file_is_accepted
    root = fixture_repository("tidy" => [ ".gitignore" ])

    assert_empty(untracked_in(root))
  end

  # The fresh-clone failure: packages.conf declares a package that has no folder.
  #: () -> void
  def test_a_declared_package_without_a_folder_is_rejected
    root = fixture_repository("present" => [ ".gitignore" ])
    File.write(File.join(root, "packages.conf"), "STOW=(\n  present\n  missing\n)\n\nSTOW_SHARED=()\n")

    assert_equal([ "missing" ], untracked_in(root))
  end

  # The main-checkout case: the folder exists locally, but git tracks nothing in it.
  # A File.directory? check passes here, where a fresh clone fails.
  #: () -> void
  def test_a_declared_package_with_only_untracked_files_is_rejected
    root = fixture_repository("tracked" => [ ".gitignore" ])
    FileUtils.mkdir_p(File.join(root, "local"))
    FileUtils.touch(File.join(root, "local", ".bundle"))
    File.write(File.join(root, "packages.conf"), "STOW=(\n  tracked\n  local\n)\n\nSTOW_SHARED=()\n")

    assert_equal([ "local" ], untracked_in(root))
  end

  # A tracked file at the root with the package's name is not a folder; stow_configure refuses it.
  #: () -> void
  def test_a_declared_package_that_is_a_tracked_file_is_rejected
    root = fixture_repository("tracked" => [ ".gitignore" ])
    FileUtils.touch(File.join(root, "plain"))
    File.write(File.join(root, "packages.conf"), "STOW=(\n  tracked\n  plain\n)\n\nSTOW_SHARED=()\n")
    system("git", "-C", root, "add", "--all", exception: true)

    assert_equal([ "plain" ], untracked_in(root))
  end

  # The regression test: red on main (bundler), green after the fix.
  #: () -> void
  def test_every_stowed_package_has_a_tracked_folder
    missing = untracked_in(REPO_ROOT)

    assert_empty(missing, "packages.conf declares packages with no tracked folder: #{missing.join(", ")}")
  end

  private

  # Names each stray and the path in $HOME it would become, so a failure says what goes wrong
  # rather than only which file is unexpected.
  def stray_report(strays)
    "Stow links a package's top-level entries into $HOME. These would land there: " +
      strays.map { |stray| "#{stray} -> ~/#{File.basename(stray)}" }.join(", ")
  end

  # Every declared package with no path in git's index under its folder. It reads the index only,
  # never a file's contents, so a local untracked folder counts as missing.
  #: (String root) -> Array[String]
  def untracked_in(root)
    packages = stow_packages(root)
    stdout, stderr, status = Open3.capture3("git", "-C", root, "ls-files", "-z", "--", *packages)
    raise stderr unless status.success?

    packages - stdout.split("\0").filter_map { |path| path.split("/", 2).first if path.include?("/") }
  end

  # Every entry at a declared package's root that is not dot-prefixed, as "<package>/<entry>".
  def strays_in(root)
    stow_packages(root).flat_map { |package|
      directory = File.join(root, package)
      # A declared package with no directory is packages.conf's bug, not a stray file, and stow
      # itself fails on it at install time. Nothing for this guard to say about it.
      next [] unless File.directory?(directory)

      Dir.children(directory)
        .reject { |entry| entry.start_with?(".") || HOME_DIRECTORIES.fetch(package, []).include?(entry) }
        .map { |entry| "#{package}/#{entry}" }
    }.sort
  end

  # Both stow lists, read by sourcing packages.conf rather than matching it: the block carries
  # comment lines that a regex would take for package names. STOW_SHARED is a subset of STOW
  # today, and the union keeps this correct if that stops being true.
  def stow_packages(root)
    (bash_array(root, "STOW") | bash_array(root, "STOW_SHARED")).sort
  end

  def bash_array(root, name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), File.join(root, "packages.conf")
    )
    raise stderr unless status.success?

    stdout.split("\n").reject(&:empty?)
  end

  # A repository root holding a packages.conf that declares the given packages, each created with
  # the entries listed for it.
  #: (Hash[String, Array[String]] packages) -> String
  def fixture_repository(packages)
    root = Dir.mktmpdir
    @fixtures = (@fixtures || []) << root

    packages.each do |package, entries|
      FileUtils.mkdir_p(File.join(root, package))
      entries.each { |entry| FileUtils.touch(File.join(root, package, entry)) }
    end

    declarations = packages.keys.map { |package| "  #{package}" }.join("\n")
    File.write(File.join(root, "packages.conf"),
               "STOW=(\n#{declarations}\n)\n\nSTOW_SHARED=()\n")
    system("git", "init", "--quiet", root, exception: true)
    system("git", "-C", root, "add", "--all", exception: true)
    root
  end

  def teardown
    FileUtils.rm_rf(@fixtures) if @fixtures
  end
end
