#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"

require_relative "../statusline-command"

module Claude
  class StatuslineCommandTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
      @previous_tz = ENV["TZ"]
      ENV["TZ"] = "UTC"
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
      ENV["TZ"] = @previous_tz
    end

    def transcript(*lines)
      path = File.join(@tmpdir, "transcript.jsonl")
      File.write(path, lines.map { |line| JSON.generate(line) }.join("\n") + "\n")
      path
    end

    def test_shows_the_last_assistant_reply_time
      path = transcript(
        { type: "user", timestamp: "2026-01-15T08:00:00.000Z" },
        { type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" }
      )

      assert_equal "Last reply: 09:30", StatuslineCommand.render({ transcript_path: path }.to_json)
    end

    def test_picks_the_last_assistant_message_not_the_first
      path = transcript(
        { type: "assistant", timestamp: "2026-01-15T08:00:00.000Z" },
        { type: "user", timestamp: "2026-01-15T08:30:00.000Z" },
        { type: "assistant", timestamp: "2026-01-15T09:45:00.000Z" }
      )

      assert_equal "Last reply: 09:45", StatuslineCommand.render({ transcript_path: path }.to_json)
    end

    def test_includes_the_full_pr_url_alongside_the_reply_time
      path = transcript({ type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" })
      input = { transcript_path: path, pr: { number: 130, url: "https://github.com/eirvandelden/dotfiles/pull/130" } }

      assert_equal "Last reply: 09:30 | https://github.com/eirvandelden/dotfiles/pull/130", StatuslineCommand.render(input.to_json)
    end

    def test_shows_only_the_pr_url_when_there_is_no_reply_yet
      input = { transcript_path: "/does/not/exist.jsonl", pr: { url: "https://github.com/eirvandelden/dotfiles/pull/130" } }

      assert_equal "https://github.com/eirvandelden/dotfiles/pull/130", StatuslineCommand.render(input.to_json)
    end

    def test_is_blank_when_transcript_path_is_missing
      assert_equal "", StatuslineCommand.render({}.to_json)
    end

    def test_is_blank_when_the_transcript_file_does_not_exist
      assert_equal "", StatuslineCommand.render({ transcript_path: "/does/not/exist.jsonl" }.to_json)
    end

    def test_is_blank_when_the_transcript_has_no_assistant_messages
      path = transcript({ type: "user", timestamp: "2026-01-15T08:00:00.000Z" })

      assert_equal "", StatuslineCommand.render({ transcript_path: path }.to_json)
    end

    def test_is_blank_when_the_last_assistant_line_is_not_valid_json
      path = File.join(@tmpdir, "transcript.jsonl")
      File.write(path, %({"type":"assistant","timestamp"\n))

      assert_equal "", StatuslineCommand.render({ transcript_path: path }.to_json)
    end

    def test_is_blank_when_the_timestamp_is_not_a_parseable_date
      path = transcript({ type: "assistant", timestamp: "not-a-date" })

      assert_equal "", StatuslineCommand.render({ transcript_path: path }.to_json)
    end

    def test_is_blank_instead_of_raising_when_the_input_itself_is_not_valid_json
      assert_equal "", StatuslineCommand.render("not json")
    end
  end
end
