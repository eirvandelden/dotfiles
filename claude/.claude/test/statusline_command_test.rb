#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "json"

require_relative "../statusline-command"

module Claude
  class StatuslineCommandTest < Minitest::Test
    def setup
      @root = @tmpdir = Dir.mktmpdir
      @previous_tz = ENV["TZ"]
      ENV["TZ"] = "UTC"
    end

    def teardown
      FileUtils.rm_rf(@root)
      ENV["TZ"] = @previous_tz
    end

    def transcript(*lines)
      path = File.join(@tmpdir, "transcript.jsonl")
      File.write(path, lines.map { |line| JSON.generate(line) }.join("\n") + "\n")
      path
    end

    def reply_date
      Date.new(2026, 1, 15)
    end

    def change_folder(slug = "some-change", **files)
      folder = File.join(@tmpdir, "docs", "changes", slug)
      FileUtils.mkdir_p(folder)
      files.each { |name, content| File.write(File.join(folder, "#{name}.md"), content) }
      folder
    end

    def accepted_intent
      "Author: A. Status: accepted.\n"
    end

    def draft_intent
      "Author: A. Status: draft.\n"
    end

    def accepted_plan
      "From `intent.md` (2026-01-15). Status: accepted.\n"
    end

    def draft_plan
      "From `intent.md` (2026-01-15). Status: draft.\n"
    end

    def render_in_tmpdir(**extra)
      StatuslineCommand.render({ workspace: { current_dir: @tmpdir } }.merge(extra).to_json)
    end

    PR_URL = "https://github.com/eirvandelden/dotfiles/pull/130"

    def test_shows_the_last_assistant_reply_time
      path = transcript(
        { type: "user", timestamp: "2026-01-15T08:00:00.000Z" },
        { type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" }
      )

      assert_equal "Last reply: 09:30", StatuslineCommand.render({ transcript_path: path }.to_json, today: reply_date)
    end

    def test_shows_the_date_when_the_last_reply_was_not_today
      path = transcript({ type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" })

      assert_equal "Last reply: Jan 15 09:30",
        StatuslineCommand.render({ transcript_path: path }.to_json, today: reply_date.next_day)
    end

    def test_omits_the_date_for_a_reply_made_just_now
      path = transcript({ type: "assistant", timestamp: Time.now.utc.iso8601(3) })

      assert_match(/\ALast reply: \d\d:\d\d\z/, StatuslineCommand.render({ transcript_path: path }.to_json))
    end

    def test_picks_the_last_assistant_message_not_the_first
      path = transcript(
        { type: "assistant", timestamp: "2026-01-15T08:00:00.000Z" },
        { type: "user", timestamp: "2026-01-15T08:30:00.000Z" },
        { type: "assistant", timestamp: "2026-01-15T09:45:00.000Z" }
      )

      assert_equal "Last reply: 09:45", StatuslineCommand.render({ transcript_path: path }.to_json, today: reply_date)
    end

    def test_includes_the_full_pr_url_alongside_the_reply_time
      path = transcript({ type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" })
      input = { transcript_path: path, pr: { number: 130, url: "https://github.com/eirvandelden/dotfiles/pull/130" } }

      assert_equal "Last reply: 09:30 | https://github.com/eirvandelden/dotfiles/pull/130",
        StatuslineCommand.render(input.to_json, today: reply_date)
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

    def test_shows_interviewing_for_a_draft_intent
      change_folder(intent: draft_intent)

      assert_equal "🤔 interviewing", render_in_tmpdir
    end

    def test_shows_interviewing_when_the_folder_has_no_intent_yet
      change_folder

      assert_equal "🤔 interviewing", render_in_tmpdir
    end

    def test_shows_scheming_for_an_accepted_intent_with_a_draft_plan
      change_folder(intent: accepted_intent, plan: draft_plan)

      assert_equal "🧠 scheming", render_in_tmpdir
    end

    def test_shows_scheming_for_an_accepted_intent_without_a_plan
      change_folder(intent: accepted_intent)

      assert_equal "🧠 scheming", render_in_tmpdir
    end

    def test_shows_hammering_for_an_accepted_plan
      change_folder(intent: accepted_intent, plan: accepted_plan)

      assert_equal "🛠️ hammering", render_in_tmpdir
    end

    def test_shows_hammering_for_a_plan_accepted_with_a_date
      change_folder(intent: accepted_intent, plan: "From `intent.md`. Status: accepted (2026-10-20).\n")

      assert_equal "🛠️ hammering", render_in_tmpdir
    end

    def test_does_not_treat_accepted_draft_as_accepted
      change_folder(intent: "Author: A. Status: accepted-draft.\n")

      assert_equal "🤔 interviewing", render_in_tmpdir
    end

    def test_shows_sleuthing_for_a_review_with_open_findings
      change_folder(intent: accepted_intent, plan: accepted_plan, review: "## Round 1\n- [ ] open finding\n")

      assert_equal "🕵️ sleuthing", render_in_tmpdir
    end

    def test_shows_sleuthing_for_a_review_with_every_finding_closed
      change_folder(intent: accepted_intent, plan: accepted_plan, review: "## Round 1\n- [x] closed finding\n")

      assert_equal "🕵️ sleuthing", render_in_tmpdir
    end

    def test_shows_shipped_when_there_is_no_change_folder_but_a_pr_url
      assert_equal "🎉 shipped | #{PR_URL}", render_in_tmpdir(pr: { url: PR_URL })
    end

    def test_shows_no_label_when_there_is_no_change_folder_and_no_pr_url
      assert_equal "", render_in_tmpdir
    end

    def test_shows_no_label_when_docs_changes_is_empty
      FileUtils.mkdir_p(File.join(@tmpdir, "docs", "changes"))

      assert_equal "", render_in_tmpdir
    end

    def test_shows_no_label_without_a_current_dir
      assert_equal PR_URL, StatuslineCommand.render({ pr: { url: PR_URL } }.to_json)
    end

    def test_shows_no_label_when_current_dir_is_not_a_string
      change_folder(intent: accepted_intent)

      assert_equal "", StatuslineCommand.render({ workspace: { current_dir: 42 } }.to_json)
    end

    def test_shows_no_label_when_there_are_several_change_folders
      change_folder("one", intent: accepted_intent)
      change_folder("two", intent: accepted_intent)

      assert_equal "", render_in_tmpdir
    end

    def test_shows_no_label_but_keeps_the_pr_url_when_a_change_file_is_unreadable
      folder = change_folder
      FileUtils.mkdir_p(File.join(folder, "intent.md"))

      assert_equal PR_URL, render_in_tmpdir(pr: { url: PR_URL })
    end

    def test_shows_no_label_when_the_review_is_unreadable
      folder = change_folder(intent: accepted_intent, plan: accepted_plan)
      FileUtils.mkdir_p(File.join(folder, "review.md"))

      assert_equal "", render_in_tmpdir
    end

    def test_puts_the_label_before_the_last_reply_and_the_pr_url
      change_folder(intent: accepted_intent, plan: accepted_plan)
      path = transcript({ type: "assistant", timestamp: "2026-01-15T09:30:00.000Z" })
      input = { workspace: { current_dir: @tmpdir }, transcript_path: path, pr: { url: PR_URL } }

      assert_equal "🛠️ hammering | Last reply: 09:30 | #{PR_URL}",
        StatuslineCommand.render(input.to_json, today: reply_date)
    end

    def test_is_blank_instead_of_raising_when_the_input_is_a_json_array
      assert_equal "", StatuslineCommand.render("[]")
    end

    def test_is_blank_instead_of_raising_when_the_input_is_json_null_a_string_or_a_boolean
      %w[null "abc" true 42].each do |input|
        assert_equal "", StatuslineCommand.render(input), "input #{input}"
      end
    end

    def test_shows_the_label_when_current_dir_contains_glob_characters
      @tmpdir = File.join(@tmpdir, "proj[1]")
      change_folder(intent: accepted_intent)

      assert_equal "🧠 scheming", render_in_tmpdir
    end

    def test_shows_shipped_when_docs_changes_holds_only_plain_files
      FileUtils.mkdir_p(File.join(@tmpdir, "docs", "changes"))
      File.write(File.join(@tmpdir, "docs", "changes", "README.md"), "Notes\n")

      assert_equal "🎉 shipped | #{PR_URL}", render_in_tmpdir(pr: { url: PR_URL })
    end

    def test_is_blank_instead_of_raising_when_pr_or_workspace_is_not_an_object
      assert_equal "", StatuslineCommand.render({ pr: "x", workspace: 5 }.to_json)
    end
  end
end
