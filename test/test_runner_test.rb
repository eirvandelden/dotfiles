#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "timeout"
require "tmpdir"
require_relative "isolated_git"

# bin/test runs every test file in its own process and process group, several at a time.
class TestRunnerTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  RUNNER = File.join(ROOT, "bin", "test")

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_failing_file_makes_the_runner_exit_non_zero_and_names_it
    passing = write_test("passing_test.rb", "def test_ok = assert(true)")
    failing = write_test("failing_test.rb", "def test_broken = flunk('on purpose')")

    output, status = run_runner(passing, failing)

    refute(status.success?, output)
    assert_includes(output, "FAILED: #{failing}")
    refute_includes(output, "FAILED: #{passing}")
  end

  def test_a_run_of_passing_files_exits_zero
    first = write_test("first_test.rb", "def test_ok = assert(true)")
    second = write_test("second_test.rb", "def test_ok = assert(true)")

    output, status = run_runner(first, second)

    assert(status.success?, output)
    assert_includes(output, "2 files")
    refute_includes(output, "FAILED")
  end

  def test_a_job_count_below_one_is_refused_without_running_any_file
    passing = write_test("passing_test.rb", record_script("passing"))

    %w[0 -1].each do |count|
      output, status = run_runner("-j", count, passing)

      refute(status.success?, output)
      assert_match(/at least 1/, output)
      refute(File.exist?(File.join(@dir, "passing.record")), "ran a file with -j #{count}")
    end
  end

  def test_an_interrupt_lets_each_running_file_clean_up_and_exits_130
    started = File.join(@dir, "started")
    cleaned = File.join(@dir, "cleaned")
    file = write_test("slow_test.rb", "def test_slow\n    File.write(#{started.inspect}, 'x')\n    sleep 30\n  " \
                                      "ensure\n    File.write(#{cleaned.inspect}, '')\n  end")

    status = interrupt_runner_once(started, file)

    assert_equal(130, status.exitstatus)
    assert_path_exists(cleaned, "the file's ensure block did not run")
  end

  def test_a_file_that_ignores_the_interrupt_is_killed_after_a_grace_period
    started = File.join(@dir, "started")
    file = write_test("stubborn_test.rb", "def test_stubborn\n    trap('INT') {}\n    " \
                                          "File.write(#{started.inspect}, Process.pid.to_s)\n    sleep 60\n  end")

    status = interrupt_runner_once(started, file)

    assert_equal(130, status.exitstatus)
    assert_raises(Errno::ESRCH) { Process.kill(0, Integer(File.read(started))) }
  end

  def test_a_closed_output_stops_the_running_files
    started = File.join(@dir, "started")
    closed = File.join(@dir, "closed")
    slow = write_test("slow_test.rb", "def test_slow\n    File.write(#{started.inspect}, Process.pid.to_s)\n" \
                                      "    sleep 60\n  end")
    # Ends only after the output is closed, so the runner's report of it hits the broken pipe.
    later = write_test("later_test.rb", "def test_later = sleep(0.05) until File.exist?(#{closed.inspect})")
    reader, writer = IO.pipe
    runner = Process.spawn(RbConfig.ruby, RUNNER, slow, later, chdir: ROOT, out: writer, err: File::NULL)
    writer.close
    Timeout.timeout(20) { sleep 0.05 until File.size?(started) }
    reader.close
    FileUtils.touch(closed)

    Timeout.timeout(20) { Process.wait(runner) }
    runner = nil
    assert_raises(Errno::ESRCH) { Process.kill(0, Integer(File.read(started))) }
  ensure
    reap(runner) if runner
  end

  def test_each_file_runs_in_its_own_process_group
    first = write_test("first_test.rb", record_script("first"))
    second = write_test("second_test.rb", record_script("second"))

    _, status = run_runner(first, second)

    assert(status.success?)
    groups = %w[first second].map { |name| File.read(File.join(@dir, "#{name}.record")).split[1] }
    assert_equal(2, groups.uniq.size)
    refute_includes(groups, Process.getpgrp.to_s)
  end

  def test_the_output_of_each_file_appears_as_one_block
    first = write_test("first_test.rb", "def test_ok = 3.times { puts 'first line'; sleep 0.1 }")
    second = write_test("second_test.rb", "def test_ok = 3.times { puts 'second line'; sleep 0.1 }")

    output, status = run_runner(first, second, "-j", "2")

    assert(status.success?, output)
    blocks = output.split(/^=== /).drop(1)
    assert_equal(2, blocks.size)
    blocks.each { |block| assert_equal(1, %w[first second].count { |name| block.include?("#{name} line") }) }
  end

  def test_jobs_option_limits_how_many_files_run_at_once
    files = 3.times.map { |index| write_test("slow#{index}_test.rb", span_script("slow#{index}")) }

    _, status = run_runner(*files, "-j", "1")

    assert(status.success?)
    assert_equal(1, max_overlap(files.size))
  end

  def test_without_arguments_it_runs_every_test_file_under_its_root
    root = File.join(@dir, "fixture")
    FileUtils.mkdir_p([ File.join(root, "bin"), File.join(root, "test") ])
    FileUtils.cp(RUNNER, File.join(root, "bin", "test"))
    %w[a b].each { |name| File.write(File.join(root, "test", "#{name}_test.rb"), standalone_test) }
    File.write(File.join(root, "test", "helper.rb"), "raise 'not a test file'")

    output, status = Open3.capture2e(RbConfig.ruby, File.join(root, "bin", "test"))

    assert(status.success?, output)
    assert_includes(output, "=== test/a_test.rb")
    assert_includes(output, "=== test/b_test.rb")
    refute_includes(output, "helper.rb")
  end

  def test_each_file_runs_with_the_standalone_command
    file = write_test("argv_test.rb", record_script("argv"))

    _, status = run_runner(file)

    assert(status.success?)
    _, _, script, load_path, directory = recorded_command("argv")
    assert_equal([ file, File.join(ROOT, "test"), ROOT ], [ script, load_path, directory ])
  end

  private

  def write_test(name, body)
    relative = File.join(File.basename(@dir), name)
    path = File.join(File.dirname(@dir), relative)
    File.write(path, standalone_test(body))
    path
  end

  def standalone_test(body = "def test_ok = assert(true)")
    <<~RUBY
      require "minitest/autorun"
      class FixtureTest < Minitest::Test
        #{body}
      end
    RUBY
  end

  def record_script(name)
    "def test_record = File.write(#{File.join(@dir, "#{name}.record").inspect}, " \
      "[Process.pid, Process.getpgrp, $0, $LOAD_PATH.grep(/test\\z/).first, Dir.pwd].join(\"\\n\"))"
  end

  def span_script(name)
    "def test_span\n    start = Time.now.to_f\n    sleep 0.3\n" \
      "    File.write(#{File.join(@dir, "#{name}.span").inspect}, \"\#{start} \#{Time.now.to_f}\")\n  end"
  end

  def max_overlap(count)
    spans = Dir.glob(File.join(@dir, "*.span")).map { |file| File.read(file).split.map(&:to_f) }
    assert_equal(count, spans.size)
    spans.map { |start, _| spans.count { |from, to| from <= start && start < to } }.max
  end

  def recorded_command(name)
    File.read(File.join(@dir, "#{name}.record")).split("\n")
  end

  # Starts the runner, waits until the file under test has started, sends INT, and returns the
  # runner's exit status. Fails when the runner does not end within 20 seconds.
  def interrupt_runner_once(started, *arguments)
    runner = Process.spawn(RbConfig.ruby, RUNNER, *arguments, chdir: ROOT, out: File::NULL, err: File::NULL)
    Timeout.timeout(20) { sleep 0.05 until File.size?(started) }
    Process.kill("INT", runner)
    status = Timeout.timeout(20) { Process.wait2(runner).last }
    runner = nil
    status
  ensure
    reap(runner) if runner
  end

  def reap(pid)
    Process.kill("KILL", pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def run_runner(*arguments)
    Open3.capture2e(RbConfig.ruby, RUNNER, *arguments, chdir: ROOT)
  end
end
