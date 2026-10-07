#!/usr/bin/env ruby
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

class CodexConfigTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../codex/.codex/config.toml", __dir__)
  TREK_URL = "https://trips.vandelden.family/mcp"
  APPROVAL_TOOLS = %w[
    delete_trip
    bulk_delete_places
    delete_journey
    delete_collection
    dissolve_vacay_plan
    remove_trip_member
    remove_collection_member
    remove_journey_contributor
    delete_trip_invite_link
    delete_vacay_year
  ].freeze

  def test_trek_points_at_the_trek_url_with_no_bearer_token
    server = trek_server

    assert_equal(TREK_URL, server[/^url\s*=\s*"([^"]+)"/, 1])
    refute_match(/^(bearer_token|bearer_token_env_var|http_headers|env_http_headers)\s*=/, server)
  end

  def test_trek_sets_no_scopes
    refute_match(/^scopes/, trek_server)
  end

  def test_codex_accepts_the_config_and_shows_the_trek_url
    skip("codex is not installed") unless codex_installed?

    assert_equal(TREK_URL, codex_trek_config.dig("transport", "url"))
  end

  def test_codex_sends_no_credentials_to_trek
    skip("codex is not installed") unless codex_installed?

    transport = codex_trek_config.fetch("transport")

    %w[bearer_token_env_var http_headers env_http_headers http_headers_helper].each do |setting|
      assert_nil(transport[setting], "#{setting} must not be set; TREK logs in through OAuth")
    end
  end

  def test_trek_tools_run_without_asking_by_default
    assert_equal("approve", trek_server[/^default_tools_approval_mode\s*=\s*"([^"]+)"/, 1])
  end

  def test_every_listed_trek_tool_asks_for_approval
    APPROVAL_TOOLS.each do |tool|
      assert_equal("prompt", approval_mode(tool), "#{tool} must ask for approval")
    end
  end

  def test_no_other_trek_tool_asks_for_approval
    assert_empty(approving_trek_tools - APPROVAL_TOOLS)
  end

  private

  def trek_server
    config[/^\[mcp_servers\.trek\][^\n]*\n(.*?)(?=^\[|\z)/m, 1] || flunk("config.toml has no [mcp_servers.trek] section")
  end

  def approval_mode(tool)
    table = config[/^\[mcp_servers\.trek\.tools\.#{Regexp.escape(tool)}\][^\n]*\n(.*?)(?=^\[|\z)/m, 1]
    table && table[/^approval_mode\s*=\s*"([^"]+)"/, 1]
  end

  def approving_trek_tools
    trek_tool_names.select { |tool| approval_mode(tool) && approval_mode(tool) != "approve" }
  end

  def trek_tool_names
    config.scan(/^\[mcp_servers\.trek\.tools\.([^\].]+)\]/).flatten
  end

  def config
    File.read(CONFIG_PATH)
  end

  def codex_trek_config
    Dir.mktmpdir do |home|
      FileUtils.cp(CONFIG_PATH, File.join(home, "config.toml"))
      output, status = Open3.capture2e({ "CODEX_HOME" => home }, "codex", "mcp", "get", "trek", "--json")

      assert(status.success?, output)
      JSON.parse(output)
    end
  end

  def codex_installed?
    system("command -v codex >/dev/null 2>&1")
  end
end
