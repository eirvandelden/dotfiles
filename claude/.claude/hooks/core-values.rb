#!/usr/bin/env ruby
# Reinjects the core behavioral rules as a system reminder on every session start and prompt,
# so they stay salient across a long session and survive context compaction — unlike CLAUDE.md,
# which loads once and can get summarized away.
#
# A hook whose only job is to guarantee those rules are present must never go quiet about
# failing to do so: every path that produces no rules also warns on stderr. It still exits 0 —
# a hook that cannot run should not block the session, only say so.
require "yaml"

CONFIG_PATH = File.expand_path("~/.claude/core-values.yml").freeze

def load_config
  YAML.safe_load_file(CONFIG_PATH, permitted_classes: [], aliases: false)
rescue StandardError => error
  warn "core-values: could not read #{CONFIG_PATH}: #{error.message}"
  :unreadable
end

def print_motto(motto)
  puts "Core value: #{motto}" if motto
end

def print_full(config)
  puts "CORE VALUES ACTIVE — #{config["motto"]}"

  sections = config["sections"]
  unless sections.nil? || sections.is_a?(Hash)
    warn "core-values: \"sections\" should be a mapping, got #{sections.inspect}"
    return
  end

  sections.to_h.each do |name, rules|
    puts
    puts "#{name}:"
    Array(rules).each { |rule| puts "  - #{rule}" }
  end
end

config = load_config

unless config.is_a?(Hash)
  warn "core-values: #{CONFIG_PATH} did not parse to a mapping, got #{config.inspect}" unless config == :unreadable
  exit 0
end

case ARGV.first
when "motto" then print_motto(config["motto"])
when "full" then print_full(config)
else warn "core-values: unknown mode #{ARGV.first.inspect}, expected \"motto\" or \"full\""
end
