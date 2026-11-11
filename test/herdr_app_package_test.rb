#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require_relative "isolated_git"

# The herdr-app package carries the files Etienne edits: keys.json, settings.json and the cores clones
# of the spaces mod and the main layout. herdr-app writes other files into its config folder (view.json,
# window.json, caches, each mod's .d.ts), so the folder must stay a real folder with file links;
# packages.conf lists the package in STOW_SHARED for that.
class HerdrAppPackageTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PACKAGE = File.join(REPO_ROOT, "herdr-app/.config/herdr-app")

  def test_both_files_parse_as_json
    %w[keys.json settings.json].each do |name|
      assert_kind_of(Hash, JSON.parse(File.read(File.join(PACKAGE, name))), name)
    end
  end

  def test_the_package_holds_only_etiennes_files
    assert_equal(
      %w[
        keys.json layouts/cores.json
        mods/golden-ratio/controller.js mods/golden-ratio/main.js mods/golden-ratio/mod.json
        mods/golden-ratio/planner.js
        mods/spaces-cores/main.js mods/spaces-cores/mod.json settings.json
      ],
      tracked_package_files.sort
    )
  end

  def test_the_cores_layout_shows_the_cloned_spaces_mod
    assert_equal(%w[spaces-cores], layout_mods("cores").grep(/\Aspaces/))
  end

  def test_the_cloned_spaces_mod_names_the_local_group_personal
    source = File.read(File.join(PACKAGE, "mods/spaces-cores/main.js"))

    refute_match(/"this computer"/i, source)
    refute_match(/\?\? "this computer"/i, source)
    assert_equal(3, source.scan(/\?\? "personal"|: "personal"/).size)
    assert_includes(source, "once one isn't this computer.")
  end

  def test_the_cloned_spaces_mod_loads_as_its_own_mod
    mod = JSON.parse(File.read(File.join(PACKAGE, "mods/spaces-cores/mod.json")))

    assert_equal("spaces", mod.dig("cloned_from", "name"))
  end

  def test_the_generated_mod_files_are_ignored
    %w[mods/spaces-cores/jsconfig.json mods/spaces-cores/herdr.d.ts].each do |path|
      _stdout, _stderr, status = Open3.capture3(
        IsolatedGit::ENVIRONMENT, "git", "check-ignore", "-q", "herdr-app/.config/herdr-app/#{path}", chdir: REPO_ROOT
      )

      assert_predicate(status, :success?, path)
    end
  end

  def test_settings_keep_monolisa
    assert_equal("MonoLisa", settings.fetch("font"))
  end

  def test_settings_hold_no_absolute_paths
    paths = sound_paths

    refute_empty(paths)
    paths.each { |path| refute(Pathname.new(path).absolute?, path) }
  end

  def test_sound_paths_resolve_under_home
    home = Pathname.new("/home/someone")
    config_folder = home.join(".config/herdr-app")

    sound_paths.each do |path|
      resolved = config_folder.join(path).cleanpath

      assert(resolved.to_s.start_with?("#{home}/Documents/Tones/herdr/"), "#{path} resolves to #{resolved}")
    end
  end

  def test_brew_macos_lists_the_herdr_app_cask
    assert_includes(bash_array("BREW_MACOS"), "herdr-app")
  end

  def test_stow_lists_herdr_app
    assert_includes(bash_array("STOW"), "herdr-app")
  end

  def test_stow_shared_lists_herdr_app
    assert_includes(bash_array("STOW_SHARED"), "herdr-app")
  end

  def test_the_stow_task_links_herdr_app_file_by_file
    calls = Dir.mktmpdir("herdr-app-stow") { |directory| stow_calls(directory) }
    call = calls.find { |line| line.split.last == "herdr-app" }

    refute_nil(call, "no stow call for herdr-app in #{calls}")
    assert_includes(call.split, "--no-folding")
  end

  def test_atomic_write_leftovers_are_ignored
    _stdout, _stderr, status = Open3.capture3(
      IsolatedGit::ENVIRONMENT, "git", "check-ignore", "-q", "herdr-app/.config/herdr-app/settings.json.tmp.1.0",
      chdir: REPO_ROOT
    )

    assert_predicate(status, :success?)
  end

  private

  def layout_mods(name)
    nodes = [ JSON.parse(File.read(File.join(PACKAGE, "layouts/#{name}.json"))) ]
    nodes.flat_map { |node| collect_mods(node) }
  end

  def collect_mods(node)
    case node
    when Hash then [ node["mod"] ].grep(String) + node.each_value.flat_map { |child| collect_mods(child) }
    when Array then node.flat_map { |child| collect_mods(child) }
    else []
    end
  end

  def settings
    JSON.parse(File.read(File.join(PACKAGE, "settings.json")))
  end

  def sound_paths
    settings.fetch("sounds").values_at("done", "blocked")
  end

  def bash_array(name)
    stdout, stderr, status = Open3.capture3(
      "bash", "-c", %(source "$0"; printf "%s\\n" "${#{name}[@]}"), File.join(REPO_ROOT, "packages.conf")
    )
    raise stderr unless status.success?

    stdout.split("\n")
  end

  # Runs the real stow task from a scratch copy of the installer, with a folder for each package that
  # git tracks here, a stub `stow` that logs its arguments, and a HOME that has no dotfiles-work. A STOW
  # entry without a tracked folder makes the task fail, as it would on a fresh clone. Returns one logged
  # line per call.
  def stow_calls(directory)
    root = File.join(directory, "repo")
    bin = File.join(directory, "bin")
    log = File.join(directory, "stow.log")
    FileUtils.mkdir_p([ root, bin, File.join(directory, "home") ])
    FileUtils.cp_r([ "install", "packages.conf" ].map { |name| File.join(REPO_ROOT, name) }, root)
    tracked_package_folders.each { |package| FileUtils.mkdir_p(File.join(root, package)) }
    stub = File.join(bin, "stow")
    File.write(stub, %(#!/bin/sh\necho "$@" >> "#{log}"\n))
    FileUtils.chmod(0o755, stub)

    env = { "HOME" => File.join(directory, "home"), "PATH" => "#{bin}:#{ENV.fetch('PATH')}" }
    _stdout, stderr, status = Open3.capture3(env, File.join(root, "install/tasks/50_stow_all.sh"))
    raise stderr unless status.success?

    File.readlines(log, chomp: true)
  end

  # Herdr writes untracked, ignored files into the package folder, so only tracked files count.
  def tracked_package_files
    stdout, stderr, status = Open3.capture3(
      IsolatedGit::ENVIRONMENT, "git", "-C", REPO_ROOT, "ls-files", "-z", "--", PACKAGE
    )
    raise stderr unless status.success?

    stdout.split("\0").map { |path| Pathname.new(File.join(REPO_ROOT, path)).relative_path_from(PACKAGE).to_s }
  end

  def tracked_package_folders
    stdout, stderr, status = Open3.capture3("git", "-C", REPO_ROOT, "ls-files", "-z")
    raise stderr unless status.success?

    stdout.split("\0").filter_map { |path| path.split("/", 2).first if path.include?("/") }.uniq
  end
end
