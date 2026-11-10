#!/usr/bin/env ruby
require "minitest/autorun"
require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# install/tasks/26_install_herdr_app.sh installs herdr-app on SteamOS from the verified Linux
# tarball. These tests run the real script with a PATH that holds only stubs and a few real tools,
# a scratch HOME, XDG_DATA_HOME and TMPDIR, and an os-release file for the distro under test. A
# `curl` stub serves a fixture tarball and manifest, so no test reaches the network.
class HerdrAppInstallTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  TASK = File.join(REPO_ROOT, "install/tasks/26_install_herdr_app.sh")
  REAL_TOOLS = %w[bash env dirname basename jq tar gzip mktemp mkdir mv cp rm cat chmod ln sed grep tr head
                  cut readlink id].freeze
  RELEASES = "https://releases.herdr.dev/app/9.9.9"

  def setup
    @directory = Dir.mktmpdir("herdr-app-install")
    @bin = File.join(@directory, "bin")
    @home = File.join(@directory, "home")
    @data = File.join(@directory, "data")
    @tmp = File.join(@directory, "tmp")
    @fixtures = File.join(@directory, "fixtures")
    FileUtils.mkdir_p([ @bin, @home, @tmp, @fixtures ])
    link_real_tools
    write_stub("sha256sum", sha256sum_stub)
    @executable = "#!/bin/sh\ntouch \"#{marker}\"\nexit 1\n"
    @arch = "x86_64"
    @curl_status = 0
    @release = {}
  end

  def teardown
    FileUtils.chmod_R(0o755, @directory)
    FileUtils.rm_rf(@directory)
  end

  def test_the_task_is_executable
    assert_predicate(File.stat(TASK), :executable?)
  end

  def test_install_runs_the_task_after_the_brew_packages
    lines = File.readlines(File.join(REPO_ROOT, "install.sh"))
    brew = lines.index { |line| line.include?(%(run_task "20_install_brew_packages.sh")) }
    task = lines.index { |line| line.include?(%(run_task "26_install_herdr_app.sh" "$root")) }

    refute_nil(task)
    assert_operator(task, :>, brew)
  end

  def test_the_task_skips_on_macos
    _stdout, _stderr, status = run_task(kernel: "Darwin")

    assert_predicate(status, :success?)
    assert_empty(curl_calls)
    refute_path_exists(launcher)
  end

  def test_the_task_skips_on_debian
    stdout, _stderr, status = run_task(distro: "ubuntu")

    assert_predicate(status, :success?)
    assert_match(/skipping/, stdout)
    assert_empty(curl_calls)
  end

  def test_the_task_installs_on_arch
    _stdout, _stderr, status = run_task(distro: "arch")

    assert_predicate(status, :success?)
    assert_path_exists(launcher)
  end

  def test_a_fresh_install_places_the_app_and_the_launcher_link
    _stdout, stderr, status = run_task

    assert_predicate(status, :success?, stderr)
    assert_equal(File.join(app_home, "herdr-app"), File.readlink(launcher))
    assert_path_exists(File.join(app_home, "LICENSE"))
    assert_path_exists(File.join(@data, "icons/hicolor/scalable/apps/herdr-app.svg"))
    assert_match(/^Exec="#{Regexp.escape(File.join(app_home, 'herdr-app'))}"$/, File.read(desktop_entry))
  end

  def test_a_fresh_install_writes_only_the_app_files
    run_task

    written = Dir.glob("**/*", File::FNM_DOTMATCH, base: @directory).reject { |path| path.end_with?("/.", "/..") }
    outside = written.grep_v(%r{\A(bin|fixtures|home|data|tmp|os-release|curl\.log)(/|\z)|\A\.\z})

    assert_empty(outside)
    assert_empty(Dir.children(@tmp), "staging left behind")
    assert_empty(Dir.glob("home/**/*", base: @directory).grep_v(%r{\Ahome/\.local(/|\z)}))
  end

  def test_xdg_data_home_moves_the_app_home
    run_task(xdg: File.join(@directory, "elsewhere"))

    assert_path_exists(File.join(@directory, "elsewhere/herdr-app/herdr-app"))
    refute_path_exists(File.join(@home, ".local/share/herdr-app"))
  end

  def test_the_desktop_entry_quotes_an_exec_path_with_reserved_characters
    data = File.join(@directory, "my data $HOME")
    run_task(xdg: data)

    exec_line = File.read(File.join(data, "applications/herdr-app.desktop"))[/^Exec=.*$/]
    assert_equal("Exec=\"#{File.join(@directory, 'my data \\\\$HOME/herdr-app/herdr-app')}\"", exec_line)
  end

  def test_a_second_run_downloads_nothing
    run_task
    File.delete(curl_log)

    _stdout, _stderr, status = run_task

    assert_predicate(status, :success?)
    assert_empty(curl_calls)
  end

  def test_a_missing_launcher_link_reinstalls
    run_task
    File.delete(launcher)
    File.delete(curl_log)

    run_task

    assert_equal(2, curl_calls.size)
    assert_path_exists(launcher)
  end

  def test_aarch64_fetches_the_aarch64_tarball
    @arch = "aarch64"

    run_task

    assert_includes(curl_calls.join("\n"), "herdr-app-linux-aarch64.tar.gz")
  end

  def test_an_unknown_arch_fails_before_any_request
    @arch = "riscv64"

    _stdout, stderr, status = run_task

    refute_predicate(status, :success?)
    assert_match(/riscv64/, stderr)
    assert_empty(curl_calls)
  end

  def test_a_failed_download_installs_nothing
    @curl_status = 22

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    refute_path_exists(launcher)
    refute_path_exists(app_home)
  end

  def test_a_missing_target_fails
    @release = { drop_target: true }

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    refute_path_exists(launcher)
  end

  def test_a_malformed_sha256_fails
    @release = { sha256: "not-a-digest" }

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    assert_equal(1, curl_calls.size, "only the manifest is fetched")
  end

  def test_a_wrong_sha256_installs_nothing
    @release = { sha256: "0" * 64 }

    _stdout, stderr, status = run_task

    refute_predicate(status, :success?)
    assert_match(/sha256|digest/i, stderr)
    refute_path_exists(launcher)
    refute_path_exists(app_home)
  end

  def test_a_foreign_tarball_url_fails_before_download
    @release = { url: "https://example.com/herdr-app.tar.gz" }

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    assert_equal(1, curl_calls.size, "only the manifest is fetched")
  end

  def test_every_request_is_https_only
    run_task

    refute_empty(curl_calls)
    curl_calls.each do |call|
      assert_includes(call, "--proto =https", call)
      assert_includes(call, "--proto-redir =https", call)
    end
  end

  def test_the_task_runs_no_fetched_content
    run_task

    refute_path_exists(marker, "the fetched executable ran")
    script = File.readlines(TASK).grep_v(/\A\s*#/).join

    refute_match(/\|\s*(ba|z)?sh\b/, script)
    refute_match(/\beval\b/, script)
    refute_match(/\bsudo\b/, script)
  end

  def test_a_tarball_without_the_executable_installs_nothing
    @executable = nil

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    refute_path_exists(launcher)
    refute_path_exists(app_home)
  end

  def test_a_tarball_with_a_symlinked_executable_installs_nothing
    @executable = :symlink

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    refute_path_exists(launcher)
  end

  def test_a_rerun_after_a_partial_install_replaces_it
    FileUtils.mkdir_p([ app_home, "#{app_home}.new" ])
    File.write(File.join(app_home, "stale"), "old")
    File.write(File.join("#{app_home}.new", "stale"), "old")

    _stdout, stderr, status = run_task

    assert_predicate(status, :success?, stderr)
    refute_path_exists(File.join(app_home, "stale"))
    refute_path_exists(File.join(app_home, "herdr-app", "herdr-app"), "nested folder")
    refute_path_exists("#{app_home}.new")
    assert_path_exists(launcher)
  end

  def test_a_failed_desktop_entry_leaves_no_launcher_link
    FileUtils.mkdir_p(File.join(@data, "applications"))
    FileUtils.chmod(0o555, File.join(@data, "applications"))

    _stdout, _stderr, status = run_task

    refute_predicate(status, :success?)
    refute_path_exists(launcher)
  end

  def test_staging_is_removed_after_success_and_failure
    run_task
    assert_empty(Dir.children(@tmp))

    @release = { sha256: "0" * 64 }
    FileUtils.rm_rf([ launcher, app_home ])
    run_task

    assert_empty(Dir.children(@tmp))
  end

  private

  def app_home = File.join(@data, "herdr-app")
  def launcher = File.join(@home, ".local/bin/herdr-app")
  def desktop_entry = File.join(@data, "applications/herdr-app.desktop")
  def marker = File.join(@directory, "marker")
  def curl_log = File.join(@directory, "curl.log")

  def curl_calls
    File.exist?(curl_log) ? File.readlines(curl_log, chomp: true) : []
  end

  def run_task(kernel: "Linux", distro: "steamos", xdg: nil)
    @data = xdg if xdg
    build_fixtures
    write_stub("uname", uname_stub(kernel))
    write_stub("curl", curl_stub)
    os_release = File.join(@directory, "os-release")
    File.write(os_release, "ID=#{distro}\nPRETTY_NAME=\"#{distro}\"\n")
    env = { "HOME" => @home, "XDG_DATA_HOME" => @data, "TMPDIR" => @tmp, "PATH" => @bin,
            "OS_RELEASE_FILE" => os_release }
    Open3.capture3(env, "bash", TASK, unsetenv_others: true)
  end

  def link_real_tools
    REAL_TOOLS.each do |tool|
      path = executable_on_path(tool)
      FileUtils.ln_s(path, File.join(@bin, tool)) if path
    end
  end

  def write_stub(name, body)
    path = File.join(@bin, name)
    FileUtils.rm_f(path)
    File.write(path, body)
    FileUtils.chmod(0o755, path)
  end

  def uname_stub(kernel)
    <<~SH
      #!/bin/sh
      case "$1" in
        -s) echo #{kernel} ;;
        -m) echo #{@arch} ;;
        *) echo #{kernel} ;;
      esac
    SH
  end

  def sha256sum_stub
    host = executable_on_path("sha256sum") || executable_on_path("shasum")
    host.end_with?("shasum") ? "#!/bin/sh\nexec #{host} -a 256 \"$@\"\n" : "#!/bin/sh\nexec #{host} \"$@\"\n"
  end

  # `command -v` is a shell builtin; Ruby's backticks run it without a shell on Linux, so look the
  # tool up on PATH here instead.
  def executable_on_path(tool)
    ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, tool) }
       .find { |path| File.file?(path) && File.executable?(path) }
  end

  # Serves a fixture for the URL asked for and logs every call. The last two arguments are `-o <out>
  # <url>` in the order the task passes them; the stub finds both by flag.
  def curl_stub
    <<~SH
      #!/bin/sh
      echo "$*" >> "#{curl_log}"
      [ "#{@curl_status}" -eq 0 ] || exit #{@curl_status}
      while [ $# -gt 0 ]; do
        case "$1" in -o) out="$2"; shift ;; *) url="$1" ;; esac
        shift
      done
      case "$url" in
        */latest.json) cp "#{File.join(@fixtures, 'latest.json')}" "$out" ;;
        *) cp "#{File.join(@fixtures, 'herdr-app.tar.gz')}" "$out" ;;
      esac
    SH
  end

  def build_fixtures
    tarball = File.join(@fixtures, "herdr-app.tar.gz")
    build_tarball(tarball)
    digest = @release.fetch(:sha256) { Digest::SHA256.file(tarball).hexdigest }
    url = @release.fetch(:url, "#{RELEASES}/herdr-app-linux-#{@arch}.tar.gz")
    targets = { "linux-#{@arch}" => { "url" => url, "sha256" => digest } }
    targets.clear if @release[:drop_target]
    File.write(File.join(@fixtures, "latest.json"), JSON.generate("version" => "9.9.9", "targets" => targets))
  end

  def build_tarball(path)
    source = File.join(@fixtures, "source")
    FileUtils.rm_rf(source)
    FileUtils.mkdir_p(File.join(source, "herdr-app"))
    File.write(File.join(source, "herdr-app/herdr-app.svg"), "<svg/>")
    File.write(File.join(source, "herdr-app/LICENSE"), "license")
    write_fixture_executable(File.join(source, "herdr-app/herdr-app"))
    system("tar", "-czf", path, "-C", source, "herdr-app", exception: true)
  end

  def write_fixture_executable(path)
    case @executable
    when nil then nil
    when :symlink then File.symlink("/bin/sh", path)
    else
      File.write(path, @executable)
      FileUtils.chmod(0o755, path)
    end
  end
end
