#!/usr/bin/env ruby
require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "common"

module WorktreeTools
  class CaptureOutputTest < Minitest::Test
    include Helpers

    def test_returns_the_output_and_status_of_the_command
      output, status = capture_output("printf", "done", time_limit: 5)

      assert_equal("done", output)
      assert(status.success?)
    end

    def test_fails_a_command_that_runs_past_the_time_limit
      output, status = capture_output("sleep", "5", time_limit: 0.2)

      assert_equal("", output)
      refute(status.success?)
    end

    # The command's process group can end between the time-out and the kill.
    def test_killing_a_process_group_that_already_ended_is_no_error
      pid = Process.spawn("true", pgroup: true)
      Process.wait(pid)

      assert_nil(kill_group(pid))
    end

    def test_without_a_time_limit_it_waits_for_the_command
      output, status = capture_output("sh", "-c", "sleep 0.3; printf late")

      assert_equal("late", output)
      assert(status.success?)
    end
  end
end
