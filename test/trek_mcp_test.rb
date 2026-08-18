#!/usr/bin/env ruby
require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class TrekMcpTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  FUNCTION = File.join(REPO_ROOT, "zsh/.config/zsh/functions/trek.zsh")

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @request_file = File.join(@tmpdir, "request.txt")
    FileUtils.mkdir_p(@bin_dir)
    write_curl_stub
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_missing_client_credentials_is_a_no_op
    result = run_helper(
      env: {
        "TREK_MCP_CLIENT_ID" => nil,
        "TREK_MCP_CLIENT_SECRET" => nil,
        "TREK_MCP_TOKEN_URL" => "https://example.test/oauth/token"
      }
    )

    assert result[:status].success?, result[:stderr]
    assert_equal "unset\n", result[:stdout]
  end

  def test_client_credentials_are_exchanged_and_access_token_is_exported
    result = run_helper(
      env: {
        "TREK_MCP_CLIENT_ID" => "client-id",
        "TREK_MCP_CLIENT_SECRET" => "client-secret",
        "TREK_MCP_TOKEN_URL" => "https://example.test/oauth/token"
      }
    )

    assert result[:status].success?, result[:stderr]
    assert_equal "set\n", result[:stdout]

    request = File.read(@request_file)
    assert_includes request, "grant_type=client_credentials"
    assert_includes request, "client_id=client-id"
    assert_includes request, "client_secret=client-secret"
    scope_separator = "%3" + "A"
    scope_names = %w[trips reservations places geo]
    scope_permissions = %w[write write write read]
    expected_scope = scope_names.zip(scope_permissions)
      .map { |name, permission| "#{name}#{scope_separator}#{permission}" }
      .join("%20")
    assert_includes request, "scope=#{expected_scope}"
    assert_equal false, (result[:stdout] + result[:stderr]).include?("client-secret")
  end

  def test_token_request_failure_is_generic_and_does_not_echo_response
    write_executable("curl", <<~SH)
      #!/bin/sh
      printf '%s\n' 'oauth failure containing client-secret' >&2
      exit 22
    SH

    result = run_helper(
      env: {
        "TREK_MCP_CLIENT_ID" => "client-id",
        "TREK_MCP_CLIENT_SECRET" => "client-secret"
      }
    )

    assert_equal false, result[:status].success?
    assert_includes result[:stderr], "OAuth token request failed"
    assert_equal false, result[:stderr].include?("client-secret")
  end

  def test_failed_token_refresh_clears_a_previously_exported_token
    write_executable("curl", <<~SH)
      #!/bin/sh
      exit 22
    SH

    result = run_helper(
      env: {
        "TREK_MCP_CLIENT_ID" => "client-id",
        "TREK_MCP_CLIENT_SECRET" => "client-secret",
        "TREK_MCP_ACCESS_TOKEN" => "stale-token"
      }
    )

    assert_equal false, result[:status].success?
    assert_equal "unset\n", result[:stdout]
  end

  def test_unlock_does_not_exchange_tokens_when_secrets_fails
    marker_file = File.join(@tmpdir, "trek-called")
    command = <<~'ZSH'
      secrets() {
        set -e
        false
        print 'export TREK_MCP_CLIENT_ID=client'
      }

      trek_mcp_token() {
        : > "$TREK_TEST_MARKER_FILE"
      }

      source "$TREK_TEST_ALIASES"
      eval unlock
    ZSH
    env = {
      "PATH" => "#{@bin_dir}:/opt/homebrew/bin:/usr/bin:/bin",
      "TREK_TEST_ALIASES" => File.join(REPO_ROOT, "zsh/.config/zsh/aliases.zsh"),
      "TREK_TEST_MARKER_FILE" => marker_file
    }

    _stdout, _stderr, status = Open3.capture3(env, "zsh", "-f", "-o", "aliases", "-c", command)

    assert_equal false, status.success?
    assert_equal false, File.exist?(marker_file)
  end

  def test_dotfiles_reference_the_trek_credentials_and_bearer_token
    mappings = File.read(File.join(REPO_ROOT, "secrets/.config/secrets/1password.env"))
    aliases = File.read(File.join(REPO_ROOT, "zsh/.config/zsh/aliases.zsh"))
    config = File.read(File.join(REPO_ROOT, "codex/.codex/config.toml"))
    packages = File.read(File.join(REPO_ROOT, "packages.conf"))

    assert_match(%r{^TREK_MCP_CLIENT_ID=op://[^/]+/TrekMCP/CLIENT_ID$}, mappings)
    assert_match(%r{^TREK_MCP_CLIENT_SECRET=op://[^/]+/TrekMCP/CLIENT_SECRET$}, mappings)
    assert_includes aliases, "unlock()"
    assert_match(/^  jq$/, packages)
    assert_match(/\[mcp_servers\.trek\]/, config)
    assert_match(/url = \"https:\/\/trips\.vandelden\.family\/mcp\"/, config)
    assert_match(/bearer_token_env_var = \"TREK_MCP_ACCESS_TOKEN\"/, config)
  end

  private

  def run_helper(env: {})
    command = <<~'ZSH'
      source "$TREK_TEST_FUNCTION"
      trek_mcp_token
      exit_code=$?
      if [[ -n "${TREK_MCP_ACCESS_TOKEN:-}" ]]; then
        print set
      else
        print unset
      fi
      exit "$exit_code"
    ZSH

    base_env = {
      "PATH" => "#{@bin_dir}:/opt/homebrew/bin:/usr/bin:/bin",
      "TREK_TEST_FUNCTION" => FUNCTION,
      "TREK_TEST_REQUEST_FILE" => @request_file,
      "TREK_MCP_CLIENT_ID" => nil,
      "TREK_MCP_CLIENT_SECRET" => nil,
      "TREK_MCP_ACCESS_TOKEN" => nil
    }
    stdout, stderr, status = Open3.capture3(base_env.merge(env), "zsh", "-f", "-c", command)
    { stdout: stdout, stderr: stderr, status: status }
  end

  def write_curl_stub
    write_executable("curl", <<~SH)
      #!/bin/sh
      cat > "$TREK_TEST_REQUEST_FILE"
      printf '%s\n' '{"access_token":"test-access-token"}'
    SH
  end

  def write_executable(name, body)
    path = File.join(@bin_dir, name)
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end
end
