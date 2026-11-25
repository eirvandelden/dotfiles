#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "agent_git_support"
require_relative "isolated_git"

# The three agent hooks run as config-based git hooks behind the personal gate: the origin check,
# the private key check and the co-author trailer. Private key headers are built at run time.
class AgentHooksTest < Minitest::Test
  include AgentGitSupport

  def setup
    setup_agent_home
    make_signing_key
  end

  def teardown
    teardown_agent_home
  end

  def test_a_personal_origin_passes
    path = repository("https://github.com/eirvandelden-dev/x.git")

    assert hook("origin-check", path).last.success?
  end

  def test_a_foreign_origin_refuses
    path = repository("git@github.com:someone/else.git")
    _out, err, status = hook("origin-check", path)

    refute status.success?
    assert_includes err, "origin is not a personal repository (git@github.com:someone/else.git)"
  end

  def test_no_origin_refuses
    _out, err, status = hook("origin-check", repository(nil))

    refute status.success?
    assert_includes err, "origin is not a personal repository (none)"
  end

  def test_a_personal_fork_remote_on_a_foreign_origin_refuses_the_commit
    path = foreign_origin_with_fork
    _out, err, status = commit(path)

    refute status.success?
    assert_includes err, "origin is not a personal repository"
    assert_equal "", git(path, "log", "--format=%s").first.strip
  end

  def test_a_personal_fork_remote_on_a_foreign_origin_refuses_the_push
    path = foreign_origin_with_fork
    git(path, "-c", "user.name=First", "-c", "user.email=first@example.com", "commit", "-q", "--allow-empty", "-m", "first", env: plain_env)
    _out, err, status = git(path, "push", "origin", "HEAD")

    refute status.success?
    assert_includes err, "origin is not a personal repository"
  end

  def test_a_staged_private_key_is_refused_at_commit
    refused_path = refuses_commit_of("deploy_key", "#{key_header}\nabc\n")

    assert_equal "deploy_key", refused_path
  end

  def test_a_staged_master_key_is_refused_at_commit
    FileUtils.mkdir_p(File.join(@home, "repo/config"))

    assert_equal "config/master.key", refuses_commit_of("config/master.key", "0123456789abcdef\n")
  end

  def test_a_staged_credentials_key_is_refused_at_commit
    FileUtils.mkdir_p(File.join(@home, "repo/config/credentials"))

    assert_equal "config/credentials/production.key", refuses_commit_of("config/credentials/production.key", "abc\n")
  end

  def test_a_key_that_is_already_tracked_does_not_block_a_commit_that_stages_something_else
    path = repository
    File.write(File.join(path, "fixture.pem"), "#{key_header}\nabc\n")
    git(path, "add", "fixture.pem", env: plain_env)
    git(path, "-c", "user.name=First", "-c", "user.email=first@example.com", "commit", "-q", "-m", "first", env: plain_env)
    _out, err, status = commit(path)

    assert status.success?, err
  end

  def test_a_staged_private_key_with_a_crlf_header_is_refused_at_commit
    assert_equal "deploy_key", refuses_commit_of("deploy_key", "#{key_header}\r\nabc\r\n")
  end

  def test_a_staged_nested_credentials_key_is_refused_at_commit
    FileUtils.mkdir_p(File.join(@home, "repo/app/config/credentials"))

    assert_equal "app/config/credentials/production.key", refuses_commit_of("app/config/credentials/production.key", "abc\n")
  end

  def test_a_staged_credentials_key_with_a_space_in_its_name_is_refused_at_commit
    FileUtils.mkdir_p(File.join(@home, "repo/config/credentials"))

    assert_equal "config/credentials/prod env.key", refuses_commit_of("config/credentials/prod env.key", "abc\n")
  end

  def test_a_globally_exempt_path_passes
    path = repository
    FileUtils.mkdir_p(File.join(path, "config"))
    File.write(File.join(path, "config/master.key"), "0123456789abcdef\n")
    git(path, "add", "config/master.key", env: plain_env)

    _out, err, status = key_hook(path, "config/master.key")

    assert status.success?, err
  end

  def test_a_locally_exempt_path_still_refuses
    path = repository
    FileUtils.mkdir_p(File.join(path, "config"))
    File.write(File.join(path, "config/master.key"), "0123456789abcdef\n")
    git(path, "add", "config/master.key", env: plain_env)
    git(path, "config", "agent.keyMaterialExempt", "config/master.key", env: plain_env)

    _out, err, status = key_hook(path, nil)

    refute status.success?
    assert_includes err, "refusing to commit config/master.key"
  end

  def test_a_non_exempt_key_still_refuses
    path = repository
    FileUtils.mkdir_p(File.join(path, "other"))
    File.write(File.join(path, "other/master.key"), "0123456789abcdef\n")
    git(path, "add", "other/master.key", env: plain_env)

    _out, err, status = key_hook(path, "config/master.key")

    refute status.success?
    assert_includes err, "refusing to commit other/master.key"
  end

  def test_an_ordinary_commit_passes
    _out, err, status = commit(repository)

    assert status.success?, err
  end

  def test_an_agent_commit_without_lefthook_gets_one_co_authored_by_trailer
    path = repository
    commit(path, "change")

    assert_equal [ "Co-Authored-By: Claude <noreply@anthropic.com>" ], trailers(path)
  end

  def test_an_existing_same_email_trailer_is_not_repeated
    path = repository
    commit(path, "change\n\nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>")

    assert_equal [ "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>" ], trailers(path)
  end

  def test_a_codex_commit_gets_the_codex_trailer
    path = repository
    commit(path, "change", env: agent_env(codex_include))

    assert_equal [ "Co-Authored-By: Codex <codex@openai.com>" ], trailers(path)
  end

  def test_the_trailer_hook_adds_one_trailer
    message = File.join(@home, "message")
    File.write(message, "subject\n")
    status = run_trailer_hook(message, "Tool <tool@example.com>")

    assert status.success?
    assert_includes File.read(message), "Co-Authored-By: Tool <tool@example.com>"
  end

  def test_the_trailer_hook_keeps_an_existing_same_email_trailer
    message = File.join(@home, "message")
    File.write(message, "subject\n\nco-authored-by: Other Name <tool@example.com>\n")
    run_trailer_hook(message, "Tool <tool@example.com>")

    assert_equal 1, File.read(message).scan(/co-authored-by/i).size
  end

  def test_the_trailer_hook_does_nothing_without_the_setting
    message = File.join(@home, "message")
    File.write(message, "subject\n")
    status = run_trailer_hook(message, nil)

    assert status.success?
    assert_equal "subject\n", File.read(message)
  end

  private

  def key_header
    "-----BEGIN #{%w[OPENSSH PRIVATE KEY].join(' ')}-----"
  end

  def hook(name, directory)
    Open3.capture3(plain_env, "sh", File.join(AGENT_DIRECTORY, name), chdir: directory)
  end

  def key_hook(path, exempt)
    global = File.join(@home, "exempt.config")
    File.write(global, exempt ? "[agent]\n  keyMaterialExempt = #{exempt}\n" : "")
    Open3.capture3(plain_env("GIT_CONFIG_GLOBAL" => global), "sh", File.join(AGENT_DIRECTORY, "no-private-keys"), chdir: path)
  end

  def foreign_origin_with_fork
    bare = File.join(@home, "origin.git")
    system("git", "init", "-q", "--bare", bare, exception: true)
    path = repository(bare)
    git(path, "remote", "add", "fork", "git@github.com:eirvandelden/x.git", env: plain_env)
    path
  end

  def refuses_commit_of(relative, content)
    path = repository
    File.write(File.join(path, relative), content)
    git(path, "add", relative, env: plain_env)
    _out, err, status = git(path, "commit", "-q", "-m", "key")

    refute status.success?
    err[/refusing to commit (.+?): /, 1]
  end

  def trailers(path)
    out, = git(path, "log", "-1", "--format=%(trailers:key=Co-Authored-By)")
    out.lines.map(&:strip).reject(&:empty?)
  end

  def run_trailer_hook(message, value)
    path = repository
    git(path, "config", "agent.coAuthoredBy", value, env: plain_env) if value
    _out, _err, status = Open3.capture3(plain_env, "sh", File.join(AGENT_DIRECTORY, "co-authored-by"), message, chdir: path)
    status
  end
end
