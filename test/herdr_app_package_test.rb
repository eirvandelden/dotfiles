#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"
require_relative "isolated_git"

# The herdr-app package carries the files Etienne edits: keys.json, settings.json, the cores clones
# of the spaces mod and the main layout, and the pipeline's stage scripts. herdr-app writes other files
# into its config folder (view.json, window.json, caches, each mod's .d.ts), so the folder must stay a
# real folder with file links; packages.conf lists the package in STOW_SHARED for that.
class HerdrAppPackageTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  PACKAGE = File.join(REPO_ROOT, "herdr-app/.config/herdr-app")
  PATH_IMPORT = /(?:\bfrom|\bimport)\s*\(?\s*["'](\.{0,2}\/[^"']*)["']/
  AGENT_LISTS = { "agents-done" => "done", "agents-blocked" => "blocked" }.freeze

  def test_both_files_parse_as_json
    %w[keys.json settings.json].each do |name|
      assert_kind_of(Hash, JSON.parse(File.read(File.join(PACKAGE, name))), name)
    end
  end

  def test_the_package_holds_only_etiennes_files
    assert_equal(
      %w[
        keys.json layouts/cores.json
        mods/agents-blocked/main.js mods/agents-blocked/mod.json mods/agents-done/main.js mods/agents-done/mod.json
        mods/core-look/main.js mods/core-look/mod.json
        mods/golden-ratio/main.js mods/golden-ratio/mod.json
        mods/spaces-cores/main.js mods/spaces-cores/mod.json
        mods/tabs-cores/main.js mods/tabs-cores/mod.json mods/tabs-cores/win-close.svg mods/tabs-cores/win-max.svg
        mods/tabs-cores/win-min.svg mods/tabs-cores/win-restore.svg
        scripts/hand-off-plan.sh scripts/open-pr-dash.sh scripts/start-review.sh
        settings.json
        themes/solunized-dark-blue.json themes/solunized-dark-orange.json
        themes/solunized-light-blue.json themes/solunized-light-orange.json
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
    mods = %w[spaces-cores agents-done agents-blocked core-look tabs-cores]
    generated = mods.product(%w[jsconfig.json herdr.d.ts gpui-kit.d.ts])
    generated.map { |mod, name| "mods/#{mod}/#{name}" }.each do |path|
      _stdout, _stderr, status = Open3.capture3(
        IsolatedGit::ENVIRONMENT, "git", "check-ignore", "-q", "herdr-app/.config/herdr-app/#{path}", chdir: REPO_ROOT
      )

      assert_predicate(status, :success?, path)
    end
  end

  def test_the_blocked_list_shares_the_done_list_code
    path = File.join(PACKAGE, "mods/agents-blocked/main.js")

    assert(File.symlink?(path), "#{path} is not a symlink")
    assert_equal("../agents-done/main.js", File.readlink(path))
  end

  def test_each_agent_list_names_its_status
    AGENT_LISTS.each do |mod, status|
      overlay = mod_json(mod).fetch("overlay", {})

      assert_equal([ "popup", status ], [ overlay["kind"], overlay.dig("props", "status") ], mod)
    end
  end

  # herdr-app's loader refuses a path import whose real path leaves the mod folder, and every file in a
  # stowed mod resolves into this repository. The scan runs everywhere, CI included.
  def test_no_mod_holds_a_path_import
    found = path_imports(File.join(PACKAGE, "mods"))

    assert_empty(found, found.map { |mod, hits| "mod #{mod}: #{hits.join(', ')}" }.join("\n"))
  end

  def test_the_import_guard_names_a_mod_with_a_path_import
    Dir.mktmpdir("herdr-app-mods") do |root|
      FileUtils.mkdir_p(File.join(root, "helper-user"))
      File.write(File.join(root, "helper-user/main.js"), %(import { x } from "./helper.js";\n))

      assert_equal({ "helper-user" => [ "main.js imports ./helper.js" ] }, path_imports(root))
    end
  end

  def test_the_agent_list_names_no_other_agent_list
    path = File.join(PACKAGE, "mods/agents-done/main.js")
    assert_path_exists(path)

    refute_includes(File.read(path), "mods/agents-")
  end

  # The real loader, through links as stow makes them. Needs herdr-app, so CI skips it.
  def test_herdr_app_loads_every_mod_through_links
    skip("herdr-app is not installed") unless system("command -v herdr-app >/dev/null 2>&1")

    failures = Dir.mktmpdir("hal", "/tmp") do |home|
      mod_names.filter_map { |mod| linked_mod_failure(home, mod) }
    end

    assert_empty(failures, failures.join("\n"))
  end

  def test_the_agent_lists_are_clones_of_a_shipped_mod
    AGENT_LISTS.each_key do |mod|
      assert_equal("picker", mod_json(mod).dig("cloned_from", "name"), mod)
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

  def mod_names
    Dir.children(File.join(PACKAGE, "mods")).sort
  end

  # Builds a folder of one link per tracked file of the mod, the way stow links it, and checks it.
  # Returns a line that names the mod and the first line of the output, or nil when herdr-app accepts it.
  def linked_mod_failure(home, mod)
    folder = File.join(home, "mods", mod)
    FileUtils.rm_rf(folder)
    tracked_package_files.grep(%r{\Amods/#{mod}/}).each do |path|
      target = File.join(folder, path.delete_prefix("mods/#{mod}/"))
      FileUtils.mkdir_p(File.dirname(target))
      File.symlink(File.join(PACKAGE, path), target)
    end
    output, status = Open3.capture2e({ "HERDR_APP_HOME" => home }, "herdr-app", "check", folder)
    "mod #{mod}: #{output.lines.first&.strip}" unless status.success?
  end

  # { mod => ["<file> imports <specifier>"] } for each mod with a path import.
  #: (String) -> Hash[String, Array[String]]
  def path_imports(mods_root)
    Dir.children(mods_root).sort.to_h { |mod| [ mod, mod_path_imports(mods_root, mod) ] }.reject { |_, hits| hits.empty? }
  end

  def mod_path_imports(mods_root, mod)
    folder = File.join(mods_root, mod)
    Dir.glob("**/*.js", base: folder).sort.flat_map do |file|
      File.read(File.join(folder, file)).scan(PATH_IMPORT).flatten.map { |specifier| "#{file} imports #{specifier}" }
    end
  end

  #: (String) -> Hash[String, untyped]
  def mod_json(mod)
    path = File.join(PACKAGE, "mods/#{mod}/mod.json")
    assert_path_exists(path)

    JSON.parse(File.read(path))
  end

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
