#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "lefthook_binary"

class LefthookLocalHooksTest < Minitest::Test
  NATIVE_LEFTHOOK = LefthookBinary.locate
  MISSING_LEFTHOOK_MESSAGE = LefthookBinary::MISSING_MESSAGE

  def self.locate_markdownlint_dir
    found = `which markdownlint 2>/dev/null`.strip
    File.dirname(found) unless found.empty?
  end

  MARKDOWNLINT_DIR = locate_markdownlint_dir

  def setup
    skip(MISSING_LEFTHOOK_MESSAGE) unless NATIVE_LEFTHOOK

    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @log_file = File.join(@tmpdir, "commands.log")
    @repo_dir = File.join(@tmpdir, "repo")
    @hooks_dir = File.join(@tmpdir, "hooks")
    @origin_dir = File.join(@tmpdir, "origin.git")
    FileUtils.mkdir_p(@bin_dir)
    setup_dotfiles_home
    setup_lint_bin_dirs
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_pre_commit_uses_global_fallback_and_rejects_conflict_markers
    setup_repo("trunk")
    stub_real_lefthook
    stage_file("conflict.txt", conflict_markers)
    _out, _err, status = git("commit", "-m", "conflict")
    refute(status.success?, "Expected a commit with conflict markers to be rejected by the global fallback")
  end

  def test_pre_commit_calls_lefthook_with_no_auto_install
    setup_repo("trunk")
    stub_logging_lefthook
    stage_file("clean.txt", "hello\n")
    git("commit", "-m", "clean")
    assert_match(/--no-auto-install/, hook_invocation("pre-commit"))
  end

  def test_pre_push_uses_global_fallback_and_rejects_a_pushed_fixme
    setup_repo("trunk")
    stub_real_lefthook
    commit_file("todo.txt", "FIX" + "ME: something\n")
    _out, _err, status = push
    refute(status.success?, "Expected a pushed fixme marker to be rejected by the global fallback")
  end

  def test_pre_push_calls_lefthook_with_no_auto_install
    setup_repo("trunk")
    stub_logging_lefthook
    push
    assert_match(/--no-auto-install/, hook_invocation("pre-push"))
  end

  def test_pre_commit_uses_global_fallback_and_commits_an_unknown_word
    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.txt", "zzqxklmnop is not a real word\n")
    _out, _err, status = git("commit", "-m", "notes")
    assert(status.success?, "Expected an unknown word to be committed through the global fallback")
  end

  def test_pre_commit_still_commits_a_binary_only_change
    setup_repo("trunk")
    stub_real_lefthook
    stage_binary_file("icon.png", "\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR".b)
    _out, _err, status = git("commit", "-m", "add icon")
    assert(status.success?, "Expected a binary-only commit to succeed")
  end

  def test_pre_commit_warns_about_a_wrapped_paragraph_and_still_commits
    skip("markdownlint not found on PATH") unless MARKDOWNLINT_DIR

    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.md", "This is line one\nand line two.\n")
    out, err, status = git("commit", "-m", "notes")
    assert(status.success?, "Expected a wrapped paragraph to warn, not block, the commit")
    assert_match(/error no-hardwrap/, out + err)
  end

  def test_pre_commit_warns_about_a_wrapped_paragraph_in_a_markdown_extension_file
    skip("markdownlint not found on PATH") unless MARKDOWNLINT_DIR

    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.markdown", "This is line one\nand line two.\n")
    out, err, status = git("commit", "-m", "notes")
    assert(status.success?, "Expected a wrapped paragraph to warn, not block, the commit")
    assert_match(/error no-hardwrap/, out + err)
  end

  def test_pre_commit_prints_no_hardwrap_warning_for_one_line_paragraphs
    skip("markdownlint not found on PATH") unless MARKDOWNLINT_DIR

    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.md", "One line paragraph.\n")
    out, err, status = git("commit", "-m", "notes")
    assert(status.success?, "Expected a clean commit to succeed")
    refute_match(/error no-hardwrap/, out + err)
  end

  def test_pre_commit_skips_the_hardwrap_check_without_markdownlint
    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.md", "This is line one\nand line two.\n")
    out, err, status = git("commit", "-m", "notes", markdownlint: false)
    assert(status.success?, "Expected the commit to succeed when markdownlint is missing")
    assert_match(/no-hardwrap: markdownlint not found on PATH, skipping/, out + err)
  end

  def test_pre_commit_skips_the_hardwrap_check_when_the_markdownlint_package_is_not_stowed
    skip("markdownlint not found on PATH") unless MARKDOWNLINT_DIR

    File.unlink(File.join(@tmpdir, ".config", "markdownlint"))
    setup_repo("trunk")
    stub_real_lefthook
    stage_file("notes.md", "This is line one\nand line two.\n")
    out, err, status = git("commit", "-m", "notes")
    assert(status.success?, "Expected the commit to succeed when the package is not stowed")
    assert_match(/no-hardwrap: .*no-hardwrap\.cjs not found, skipping/, out + err)
    refute_match(/Cannot load custom rule/, out + err)
  end

  private

  def hook_invocation(hook_name)
    invocation = File.readlines(@log_file, chomp: true).find { |line| line.start_with?("run #{hook_name}") }
    refute(invocation.nil?, "Expected #{hook_name} to invoke lefthook. Log:\n#{File.read(@log_file)}")
    invocation
  end

  def setup_dotfiles_home
    dotfiles_dir = File.join(@tmpdir, "Developer", "dotfiles")
    FileUtils.mkdir_p(dotfiles_dir)
    FileUtils.cp(File.join(@repo_root, "lefthook.yml"), File.join(dotfiles_dir, "lefthook.yml"))
    FileUtils.mkdir_p(File.join(@tmpdir, ".config"))
    File.symlink(
      File.join(@repo_root, "markdownlint/.config/markdownlint"),
      File.join(@tmpdir, ".config", "markdownlint")
    )
  end

  # markdownlint lives in an npm bin directory with other binaries and needs node on PATH via its
  # `#!/usr/bin/env node` shebang, so excluding markdownlint from PATH means symlinking markdownlint
  # and node into their own directory rather than including the shared one wholesale.
  def setup_lint_bin_dirs
    return unless MARKDOWNLINT_DIR

    @markdownlint_only_dir = File.join(@tmpdir, "markdownlint-bin")
    FileUtils.mkdir_p(@markdownlint_only_dir)
    File.symlink(File.join(MARKDOWNLINT_DIR, "markdownlint"), File.join(@markdownlint_only_dir, "markdownlint"))
    File.symlink(`which node`.strip, File.join(@markdownlint_only_dir, "node"))
  end

  def setup_repo(branch)
    FileUtils.cp_r(File.join(@repo_root, "git/.config/git/hooks"), @hooks_dir)
    run_git("init", "--bare", "--quiet", @origin_dir)
    run_git("init", "--quiet", "--initial-branch=#{branch}", @repo_dir)
    run_git("-C", @repo_dir, "config", "core.hooksPath", @hooks_dir)
    run_git("-C", @repo_dir, "config", "user.name", "Test")
    run_git("-C", @repo_dir, "config", "user.email", "test@example.com")
    run_git("-C", @repo_dir, "remote", "add", "origin", @origin_dir)
    File.write(File.join(@repo_dir, "README.md"), "init\n")
    run_git("-C", @repo_dir, "add", ".")
    run_git("-C", @repo_dir, "commit", "-q", "-m", "init", env: { "LEFTHOOK" => "0" })
  end

  def conflict_markers
    "<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch\n"
  end

  def stage_file(name, content)
    File.write(File.join(@repo_dir, name), content)
    run_git("-C", @repo_dir, "add", ".")
  end

  def stage_binary_file(name, bytes)
    File.binwrite(File.join(@repo_dir, name), bytes)
    run_git("-C", @repo_dir, "add", ".")
  end

  def commit_file(name, content)
    stage_file(name, content)
    run_git("-C", @repo_dir, "commit", "-q", "-m", "add #{name}", env: { "LEFTHOOK" => "0" })
  end

  def stub_real_lefthook
    write_executable("lefthook", "#!/bin/sh\nexec \"#{NATIVE_LEFTHOOK}\" \"$@\"\n")
  end

  def stub_logging_lefthook
    write_executable("lefthook", "#!/bin/sh\necho \"$*\" >> \"#{@log_file}\"\n")
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
    path
  end

  def repo_env(markdownlint: true)
    path_dirs = [ @bin_dir ]
    path_dirs << @markdownlint_only_dir if markdownlint && @markdownlint_only_dir
    {
      "HOME" => @tmpdir,
      "PATH" => "#{path_dirs.join(':')}:/usr/bin:/bin",
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_SYSTEM" => "/dev/null",
      "GIT_AUTHOR_NAME" => "Test",
      "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "Test",
      "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end

  def git(*args, markdownlint: true)
    Open3.capture3(repo_env(markdownlint: markdownlint), "git", *args, chdir: @repo_dir)
  end

  def push
    git("push", "origin", "HEAD")
  end

  def run_git(*args, env: {})
    full_env = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null" }.merge(env)
    stdout, stderr, status = Open3.capture3(full_env, "git", *args, chdir: @tmpdir)
    return if status.success?

    flunk "git #{args.join(" ")} failed (exit #{status.exitstatus}):\n#{stdout}\n#{stderr}"
  end
end
