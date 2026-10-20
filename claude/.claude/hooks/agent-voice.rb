#!/usr/bin/env ruby
# Gives a personal session one playful persona on SessionStart. Claude and Codex both add this
# stdout to the model context. Work repositories and repositories without origin print nothing:
# fail closed. A directory outside git counts as personal.
#
# The persona is a hash of session_id, so it stays stable across resume and compaction without a
# state file. Like core-values.rb, a failure warns on stderr and still exits 0.
require "json"
require "open3"
require "yaml"
require "zlib"
require_relative "remote_matcher"

DATA_PATH = ENV.fetch("AGENT_VOICE_DATA") { File.expand_path("../agent-voice.yml", __dir__) }.freeze
GREETING_SOURCES = %w[startup clear].freeze

def load_data
  data = YAML.safe_load_file(DATA_PATH, permitted_classes: [], aliases: false)
  raise "expected \"personas\" and \"rules\" lists" unless data.is_a?(Hash) && data["personas"].is_a?(Array) &&
                                                          data["rules"].is_a?(Array)

  data
rescue StandardError => error
  warn "agent-voice: could not read #{DATA_PATH}: #{error.message}"
  nil
end

def read_event
  JSON.parse($stdin.read)
rescue JSON::ParserError => error
  warn "agent-voice: could not parse hook input: #{error.message}"
  nil
end

def origin_url(cwd)
  stdout, _stderr, status = Open3.capture3("git", "-C", cwd, "remote", "get-url", "origin")
  status.success? ? stdout.strip : nil
end

def inside_git?(cwd)
  _stdout, _stderr, status = Open3.capture3("git", "-C", cwd, "rev-parse", "--git-dir")
  status.success?
end

def personal?(cwd)
  return !inside_git?(cwd) unless (url = origin_url(cwd))

  RemoteMatcher.personal?(url)
end

def pick(personas, session_id)
  index = session_id ? Zlib.crc32(session_id) : Random.rand(personas.size)
  personas[index % personas.size]
end

def print_voice(data, persona, source)
  puts "Persona: #{persona["name"]} #{persona["emoji"]}"
  puts "Tone: #{persona["tone"]}"
  puts "Catchphrases: #{persona["catchphrases"].join(" | ")}"
  puts GREETING_SOURCES.include?(source) ? "Open your first reply with a greeting in character." : "Do not greet again."
  puts "Voice rules:"
  data["rules"].each { |rule| puts "  - #{rule}" }
end

event = read_event
data = event && load_data
exit 0 unless data

cwd = event["cwd"] || Dir.pwd
exit 0 unless personal?(cwd)

print_voice(data, pick(data["personas"], event["session_id"]), event["source"])
