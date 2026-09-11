#!/usr/bin/env rv run ruby

require "json"
require "time"

def last_assistant_timestamp(transcript_path)
  return nil unless transcript_path && File.exist?(transcript_path)

  line = File.foreach(transcript_path).select { |entry| entry.include?('"type":"assistant"') }.last
  line && JSON.parse(line)["timestamp"]
rescue JSON::ParserError
  nil
end

def format_local_time(timestamp)
  return nil unless timestamp

  Time.parse(timestamp).localtime.strftime("%H:%M")
rescue ArgumentError
  nil
end

data = JSON.parse($stdin.read)
reply_time = format_local_time(last_assistant_timestamp(data["transcript_path"]))
pr_url = data.dig("pr", "url")

segments = [ ("Last reply: #{reply_time}" if reply_time), pr_url ].compact
puts segments.join(" | ") unless segments.empty?
