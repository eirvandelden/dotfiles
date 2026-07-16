#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class EditorTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)

  def setup
    @tmpdir  = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log     = File.join(@tmpdir, "invocations.log")
    FileUtils.mkdir_p(@bin_dir)

    @editor      = File.join(REPO_ROOT, "editor/.local/bin/editor")
    @editor_wait = File.join(REPO_ROOT, "editor/.local/bin/editor-wait")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # 1. Interactive terminal selects nvim.
  # Open3.capture3 captures stdout via pipe, so [ -t 1 ] is always false in
  # tests — we cannot exercise the tty branch from a subprocess. Instead we
  # verify routing logic by inspecting the script directly: when stdin AND
  # stdout are connected to a tty, nvim must be invoked.
  # The non-tty path tests (2, 3) confirm the routing branches are correct.
  def test_script_routes_to_nvim_in_interactive_branch
    content = File.read(@editor)
    assert_match(/\[ -t 0 \] && \[ -t 1 \]/, content, "editor must check both stdin and stdout are ttys before routing to nvim")
    assert_match(/exec nvim "\$@"/, content, "editor must exec nvim in the interactive branch")
  end

  def test_editor_wait_routes_to_nvim_in_interactive_branch
    content = File.read(@editor_wait)
    assert_match(/\[ -t 0 \] && \[ -t 1 \]/, content, "editor-wait must check both stdin and stdout are ttys before routing to nvim")
    assert_match(/exec nvim "\$@"/, content, "editor-wait must exec nvim in the interactive branch")
  end

  # 2. Non-interactive macOS selects Neovide with --reuse-instance.
  def test_non_interactive_macos_selects_neovide_with_reuse_instance
    stub("nvim")
    stub("neovide")
    stub_uname("Darwin")

    result = run_script(@editor, "file.txt", env: base_env)

    assert_logged(/neovide --reuse-instance file\.txt/)
    assert_not_logged(/nvim/)
    assert result[:status].success?
  end

  # 3. Non-interactive Linux selects Neovide without --reuse-instance.
  def test_non_interactive_linux_selects_neovide_without_reuse_instance
    stub("nvim")
    stub("neovide")
    stub_uname("Linux")

    result = run_script(@editor, "file.txt", env: graphical_env)

    assert_logged(/neovide file\.txt/)
    assert_not_logged(/--reuse-instance/)
    assert result[:status].success?
  end

  def test_headless_linux_falls_back_to_nvim
    stub("nvim")
    stub("neovide")
    stub_uname("Linux")

    result = run_script(@editor, "file.txt", env: base_env)

    assert_logged(/nvim file\.txt/)
    assert_not_logged(/neovide/)
    assert result[:status].success?
  end

  def test_headless_linux_editor_wait_falls_back_to_nvim
    stub("nvim")
    stub("neovide")
    stub_uname("Linux")

    result = run_script(@editor_wait, "file.txt", env: base_env)

    assert_logged(/nvim file\.txt/)
    assert_not_logged(/neovide/)
    assert result[:status].success?
  end

  # 4. All arguments passed separately and unchanged.
  def test_arguments_remain_separate_and_unchanged
    stub("neovide")
    stub_uname("Linux")

    run_script(@editor, "a.txt", "b.txt", "c.txt", env: graphical_env)

    assert_logged(/neovide a\.txt b\.txt c\.txt/)
  end

  # 5. Paths containing spaces work.
  def test_paths_with_spaces_work
    stub("neovide")
    stub_uname("Linux")

    run_script(@editor, "my file.txt", env: graphical_env)

    assert_logged(/neovide my file\.txt/)
  end

  # 6. Missing executables produce a useful error and non-zero exit.
  def test_missing_editor_produces_clear_error
    stub_uname("Linux")
    # No nvim or neovide in PATH

    result = run_script(@editor, "file.txt", env: no_editor_env)

    assert_not result[:status].success?
    assert_match(/neither neovide nor nvim found/, result[:stderr])
  end

  def test_missing_editor_wait_produces_clear_error
    stub_uname("Linux")

    result = run_script(@editor_wait, "file.txt", env: no_editor_env)

    assert_not result[:status].success?
    assert_match(/neither neovide nor nvim found/, result[:stderr])
  end

  # 7. editor-wait sets NEOVIDE_FORK=0 (blocking) in non-interactive mode.
  def test_editor_wait_blocks_via_neovide_fork_0
    stub_env_capturing_neovide
    stub_uname("Linux")

    result = run_script(@editor_wait, "file.txt", env: graphical_env)

    assert_logged(/NEOVIDE_FORK=0/)
    assert result[:status].success?
  end

  # 8. .zshenv exports executable command names, not aliases.
  def test_zshenv_exports_editor_executables_not_aliases
    content = File.read(File.join(REPO_ROOT, "zsh/.config/zsh/.zshenv"))

    assert_match(/^export EDITOR='editor'/, content)
    assert_match(/^export VISUAL='editor'/, content)
    assert_no_match(/EDITOR='e'/, content)
    assert_no_match(/VISUAL='nano'/, content)
  end

  # 9. Git config uses the stowed editor-wait executable for core and rebase sequencing.
  def test_git_config_uses_editor_wait
    content = File.read(File.join(REPO_ROOT, "git/.config/git/config"))

    assert_match(/^\s*editor\s*=\s*~\/.local\/bin\/editor-wait/, content)
    assert_match(/\[sequence\]/, content)

    # [sequence] section must also set editor = editor-wait
    sequence_section = content[/\[sequence\].*?(?=\[|\z)/m]
    assert sequence_section, "[sequence] section not found"
    assert_match(/editor\s*=\s*~\/.local\/bin\/editor-wait/, sequence_section)
  end

  # 10. packages.conf includes the editor stow package and neovide.
  def test_packages_conf_includes_editor_and_neovide
    content = File.read(File.join(REPO_ROOT, "packages.conf"))

    assert_match(/^\s*editor\s*$/, content, "STOW must list 'editor'")
    assert_match(/neovide/, content, "packages.conf must include neovide")
  end

  def test_hosts_does_not_install_temp_file_after_failed_edit
    stub("sudo", <<~SH)
      #!/bin/sh
      printf 'sudo %s\n' "$*" >> "#{@log}"
    SH
    stub("nvim", "#!/bin/sh\nexit 1\n")
    stub("say")

    result = run_hosts

    assert_not result[:status].success?
    assert_equal 2, log_contents.lines.count
  end

  def test_hosts_stops_when_copying_hosts_file_fails
    stub("sudo", <<~SH)
      #!/bin/sh
      printf 'sudo %s\n' "$*" >> "#{@log}"
      exit 1
    SH
    stub("nvim")
    stub("say")

    result = run_hosts

    assert_not result[:status].success?
    assert_equal 1, log_contents.lines.count
  end

  def test_hosts_removes_temp_copy_after_editing
    stub("sudo")
    stub("nvim")
    stub("say")

    run_hosts

    temporary_copy = log_contents.lines.first.split.last
    assert_not File.exist?(temporary_copy)
  ensure
    FileUtils.rm_f(temporary_copy) if temporary_copy
  end

  private

  # Run script non-interactively: Open3.capture3 uses pipes for stdin/stdout,
  # so [ -t 0 ] and [ -t 1 ] both return false — the non-interactive path runs.
  def run_script(script, *args, env:)
    stdout, stderr, status = Open3.capture3(env, script, *args)
    { stdout: stdout, stderr: stderr, status: status }
  end

  def run_hosts
    command = "source #{File.join(REPO_ROOT, "zsh/.config/zsh/aliases.zsh")}; hosts"
    stdout, stderr, status = Open3.capture3(base_env, "zsh", "-f", "-c", command)
    { stdout: stdout, stderr: stderr, status: status }
  end

  def stub(name, body = nil)
    body ||= <<~SH
      #!/bin/sh
      printf '%s %s\n' "#{name}" "$*" >> "#{@log}"
    SH
    write_bin(name, body)
  end

  # Neovide stub that captures NEOVIDE_FORK from the environment.
  def stub_env_capturing_neovide
    body = <<~SH
      #!/bin/sh
      printf 'NEOVIDE_FORK=%s neovide %s\n' "${NEOVIDE_FORK:-unset}" "$*" >> "#{@log}"
    SH
    write_bin("neovide", body)
  end

  def stub_uname(os)
    write_bin("uname", <<~SH)
      #!/bin/sh
      if [ "$1" = "-s" ]; then
        printf '%s\n' "#{os}"
      else
        /usr/bin/uname "$@"
      fi
    SH
  end

  def write_bin(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
    path
  end

  # Shared env vars that isolate tests from the real Homebrew install and macOS
  # Neovide.app, while still giving the script a well-known PATH to search.
  ISOLATED_ENV = {
    "HOMEBREW_PREFIX" => "/nonexistent-homebrew",
    "NEOVIDE_APP_PATH" => "/nonexistent-neovide"
  }.freeze

  def base_env
    ISOLATED_ENV.merge(
      "HOME" => @tmpdir,
      "PATH" => "#{@bin_dir}:/usr/bin:/bin"
    )
  end

  def graphical_env
    base_env.merge("DISPLAY" => ":0")
  end

  # PATH with only system dirs — no nvim, no neovide.
  def no_editor_env
    ISOLATED_ENV.merge(
      "HOME" => @tmpdir,
      "PATH" => "/usr/bin:/bin"
    )
  end

  def log_contents
    File.exist?(@log) ? File.read(@log) : ""
  end

  def assert_logged(pattern)
    assert_match(pattern, log_contents,
      "Expected log to match #{pattern.inspect}. Log:\n#{log_contents}")
  end

  def assert_not_logged(pattern)
    assert_no_match(pattern, log_contents,
      "Expected log NOT to match #{pattern.inspect}. Log:\n#{log_contents}")
  end

  def assert_not(value, message = nil)
    assert_equal(false, !!value, message)
  end

  def assert_no_match(pattern, value, message = nil)
    assert_not(pattern.match?(value), message || "Expected #{value.inspect} not to match #{pattern.inspect}")
  end
end
