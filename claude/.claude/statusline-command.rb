#!/usr/bin/env rv run ruby

require "json"
require "time"
require "date"

class ChangeFolder
  ACCEPTED = /Status: accepted(?: \(\d{4}-\d{2}-\d{2}\))?(?=\.|\s|\z)/

  #: (String current_dir) -> Array[String]
  def self.folders_in(current_dir)
    Dir.glob("docs/changes/*/", base: current_dir).map { |folder| File.join(current_dir, folder) }
  end

  #: (String current_dir) -> bool
  def self.shipped?(current_dir)
    changes = File.join(current_dir, "docs", "changes")
    Dir.children(changes).none? { |entry| !entry.start_with?(".") && File.directory?(File.join(changes, entry)) }
  rescue Errno::ENOENT
    true
  end

  #: (String current_dir) -> ChangeFolder?
  def self.in(current_dir)
    folders = folders_in(current_dir)
    new(folders.first) if folders.one?
  end

  #: (String path) -> void
  def initialize(path)
    @path = path
  end

  #: -> String
  def stage_label
    return "🕵️ sleuthing" if read("review.md")
    return "🛠️ hammering" if accepted?("plan.md")

    accepted?("intent.md") ? "🧠 scheming" : "🤔 interviewing"
  end

  private

  def accepted?(name)
    status_line = read(name)&.lines&.find { |line| line.include?("Status:") }
    ACCEPTED.match?(status_line.to_s)
  end

  def read(name)
    File.read(File.join(@path, name), encoding: Encoding::UTF_8).scrub
  rescue Errno::ENOENT
    nil
  end
end

module StatuslineCommand
  module_function

  #: (String? transcript_path) -> String?
  def last_assistant_timestamp(transcript_path)
    return nil unless transcript_path && File.exist?(transcript_path)

    line = File.foreach(transcript_path).select { |entry| entry.include?('"type":"assistant"') }.last
    line && JSON.parse(line)["timestamp"]
  rescue JSON::ParserError
    nil
  end

  #: (String? timestamp, today: Date) -> String?
  def format_local_time(timestamp, today:)
    return nil unless timestamp

    reply_time = Time.parse(timestamp).localtime
    reply_time.strftime(reply_time.to_date == today ? "%H:%M" : "%b %-d %H:%M")
  rescue ArgumentError
    nil
  end

  #: (String? current_dir, String? pr_url) -> String?
  def stage_label(current_dir, pr_url)
    return unless current_dir.is_a?(String) && !current_dir.empty?

    folder = ChangeFolder.in(current_dir)
    return folder.stage_label if folder

    "🎉 shipped" if pr_url && ChangeFolder.shipped?(current_dir)
  rescue SystemCallError, ArgumentError
    nil
  end

  #: (String json_input, ?today: Date) -> String
  def render(json_input, today: Time.now.getlocal.to_date)
    data = JSON.parse(json_input)
    return "" unless data.is_a?(Hash)

    reply_time = format_local_time(last_assistant_timestamp(data["transcript_path"]), today: today)
    pr_url = data.dig("pr", "url")
    label = stage_label(data.dig("workspace", "current_dir"), pr_url)

    [ label, ("Last reply: #{reply_time}" if reply_time), pr_url ].compact.join(" | ")
  rescue JSON::ParserError, TypeError
    ""
  end
end

if $PROGRAM_NAME == __FILE__
  output = StatuslineCommand.render($stdin.read)
  puts output unless output.empty?
end
