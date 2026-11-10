#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "../claude/.claude/hooks/remote_matcher"

# ghp opens a personal project on GitHub. It asks gh whether the eirvandelden-dev
# organisation has the repository and falls back to the eirvandelden user, so a
# failed lookup still opens a page. Stub gh and open sit first on PATH; the real
# ones never run.
class GhpTest < Minitest::Test
  FUNCTION = File.expand_path("../zsh/.config/zsh/functions/gh.zsh", __dir__)

  def setup
    @bin = Dir.mktmpdir
    install_stub("open", "exit 0")
  end

  def teardown
    FileUtils.rm_rf(@bin)
  end

  def test_opens_the_personal_org_when_it_has_the_repository
    install_stub("gh", "exit 0")

    assert_equal([ "https://github.com/eirvandelden-dev/clocky/issues" ], ghp("clocky", "issues"))
  end

  def test_opens_the_user_account_when_the_org_lacks_the_repository
    install_stub("gh", "exit 1")

    assert_equal([ "https://github.com/eirvandelden/homelab-iac" ], ghp("homelab-iac"))
  end

  def test_bare_ghp_opens_the_profile_without_a_lookup
    install_stub("gh", "exit 0")

    assert_equal([ "https://github.com/eirvandelden/" ], ghp)
    assert_empty(logged("gh"))
  end

  def test_a_failed_lookup_opens_the_user_account
    install_stub("gh", "echo 'gh: not signed in' >&2; exit 1")

    assert_equal([ "https://github.com/eirvandelden/clocky/issues" ], ghp("clocky", "issues"))
  end

  def test_passes_the_path_segments_through
    install_stub("gh", "exit 0")

    assert_equal([ "https://github.com/eirvandelden-dev/clocky/pull/7/files" ], ghp("clocky", "pull", "7", "files"))
  end

  def test_ghp_uses_exactly_the_personal_owners
    install_stub("gh", "exit 1")
    ghp("clocky")
    asked = logged("gh").map { |call| call[%r{repos/([^/]+)/}, 1] }
    fallback = File.readlines(File.join(@bin, "open.log"), chomp: true).map { |url| url[%r{github\.com/([^/]+)/}, 1] }

    assert_equal(RemoteMatcher::PERSONAL_OWNERS.sort, (asked + fallback).uniq.sort)
  end

  private

  def ghp(*arguments)
    script = "source #{FUNCTION}; ghp #{arguments.join(' ')}"
    env = { "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "STUB_DIR" => @bin }
    _, stderr, status = Open3.capture3(env, "zsh", "-f", "-c", script)
    assert(status.success?, stderr)
    File.exist?(File.join(@bin, "open.log")) ? File.readlines(File.join(@bin, "open.log"), chomp: true) : []
  end

  def install_stub(name, body)
    path = File.join(@bin, name)
    File.write(path, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$STUB_DIR/#{name}.log\"\n#{body}\n")
    FileUtils.chmod(0o755, path)
  end

  def logged(name)
    log = File.join(@bin, "#{name}.log")
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end
end
