#!/usr/bin/env ruby
require "minitest/autorun"
require "open3"
require_relative "isolated_git"

class HerdrConfigTest < Minitest::Test
  CONFIG_PATH = File.expand_path("../herdr/.config/herdr/config.toml", __dir__)
  QUIETER_COPIES = "/Users/etienne.vandelden/Documents/Tones/herdr".freeze

  def test_notifications_go_through_the_terminal_so_no_notifier_program_can_block_the_client
    assert_equal("terminal", toast_delivery)
  end

  def test_herdr_accepts_the_config
    skip("herdr is not installed") unless herdr_installed?

    output, status = Open3.capture2e({ "HERDR_CONFIG_PATH" => CONFIG_PATH }, "herdr", "config", "check")

    assert(status.success?, output)
  end

  def test_each_sound_points_at_its_quieter_copy
    { "path" => "ready-to-serve", "request_path" => "milord", "done_path" => "jobs-done" }.each do |key, tone|
      sound_path = sound_setting(key)

      assert(sound_path.start_with?("/"), "#{key} must be absolute: #{sound_path}")
      assert_equal(File.join(QUIETER_COPIES, "#{tone}.mp3"), sound_path, key)
    end
  end

  def test_the_commented_alternative_also_points_at_a_quieter_copy
    alternative = File.read(CONFIG_PATH)[/^#\s*done_path\s*=\s*"([^"]+)"/, 1]

    assert_equal(File.join(QUIETER_COPIES, "ForTheMaster02.mp3"), alternative)
  end

  def test_no_herdr_tone_is_tracked
    listing, status = Open3.capture2("git", "ls-files", "-z", chdir: File.expand_path("..", __dir__))
    assert(status.success?, "git ls-files failed")
    tracked = listing.split("\0")
    herdr_audio = tracked.grep(%r{\Aherdr/.*\.(mp3|wav|aiff|m4a|ogg|flac)\z}i)
    tones = %w[ready-to-serve milord jobs-done ForTheMaster02]

    assert_empty(herdr_audio)
    assert_empty(tracked.select { |file| tones.any? { |tone| File.basename(file, ".*") == tone } })
  end

  private

  def sound_setting(key)
    sound_section = File.read(CONFIG_PATH)[/^\[ui\.sound\][^\n]*\n(.*?)(?=^\[|\z)/m, 1]
    flunk("config.toml has no [ui.sound] section") unless sound_section

    sound_section[/^#{key}\s*=\s*"([^"]+)"/, 1] || flunk("[ui.sound] has no #{key}")
  end

  def toast_delivery
    toast_section = File.read(CONFIG_PATH)[/^\[ui\.toast\][^\n]*\n(.*?)(?=^\[|\z)/m, 1]
    flunk("config.toml has no [ui.toast] section") unless toast_section

    toast_section[/^delivery\s*=\s*"([^"]+)"/, 1] || flunk("[ui.toast] has no delivery setting")
  end

  def herdr_installed?
    system("command -v herdr >/dev/null 2>&1")
  end
end
