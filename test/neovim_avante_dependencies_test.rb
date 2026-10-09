#!/usr/bin/env ruby
require "minitest/autorun"
require "json"

class NeovimAvanteDependenciesTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  NVIM_ROOT = File.join(REPO_ROOT, "neovim/.config/nvim")

  # avante.nvim requires mega.cmdparse at load time; without it plugin/avante.lua
  # fails on startup and :Avante is never defined.
  def test_avante_spec_declares_mega_cmdparse_with_mega_logging
    spec = File.read(File.join(NVIM_ROOT, "lua/plugins/ai.lua"))

    assert_match(
      /\{\s*"ColinKennedy\/mega\.cmdparse",\s*dependencies\s*=\s*\{\s*"ColinKennedy\/mega\.logging"\s*\}\s*\}/,
      spec
    )
  end

  def test_lockfile_pins_mega_cmdparse_and_mega_logging
    lockfile = JSON.parse(File.read(File.join(NVIM_ROOT, "lazy-lock.json")))

    %w[mega.cmdparse mega.logging].each do |plugin|
      refute_empty lockfile.dig(plugin, "commit").to_s, "#{plugin} missing from lazy-lock.json"
    end
  end
end
