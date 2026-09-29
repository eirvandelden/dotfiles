#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"

class HerdrConfigTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../herdr/.config/herdr/config.toml", __dir__)

  def test_notifications_go_through_the_terminal_so_no_notifier_program_can_block_the_client
    assert_equal("terminal", toast_delivery)
  end

  def test_herdr_accepts_the_config
    skip("herdr is not installed") unless herdr_installed?

    output, status = Open3.capture2e({ "HERDR_CONFIG_PATH" => CONFIG_PATH }, "herdr", "config", "check")

    assert(status.success?, output)
  end

  private

  def toast_delivery
    toast_section = File.read(CONFIG_PATH)[/^\[ui\.toast\][^\n]*\n(.*?)(?=^\[|\z)/m, 1]
    flunk("config.toml has no [ui.toast] section") unless toast_section

    toast_section[/^delivery\s*=\s*"([^"]+)"/, 1] || flunk("[ui.toast] has no delivery setting")
  end

  def herdr_installed?
    system("command -v herdr >/dev/null 2>&1")
  end
end
