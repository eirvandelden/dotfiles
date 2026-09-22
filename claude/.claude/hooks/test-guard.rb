#!/usr/bin/env ruby
# Claude Code PreToolUse hook (same stdin/exit contract as consent-guard.rb): while a bugfix's
# reproduction test is committed — this branch's plan.md carries "Reproduction: committed" —
# an edit to a test path is refused. The playbook's "fix the code, not the tests" for a
# bugfix, enforced rather than advised (spec.md §1.4).
#
# `--always` skips the plan.md lookup and refuses every write to a test path unconditionally:
# used as a per-agent hook on the `implementer` agent, whose whole job is production code, so
# it never has a reason to touch one.
require "json"
require "open3"
require "pathname"

REPRODUCTION_LINE = "Reproduction: committed".freeze

CHANGE_FOLDER_SCRIPT = File.expand_path("../../.claude/skills/plan/scripts/change-folder", __dir__)

def test_path?(relative_path)
  return true if relative_path.start_with?("test/", "spec/", "__tests__/")

  relative_path.match?(/(_test|_spec)\.rb\z/) || relative_path.match?(/\.test\.[^.\/]+\z/)
end

def relative_to_repo(file_path, cwd)
  return file_path unless file_path.start_with?("/")

  toplevel, status = Open3.capture2("git", "-C", cwd, "rev-parse", "--show-toplevel")
  return file_path unless status.success?

  Pathname.new(file_path).relative_path_from(Pathname.new(toplevel.strip)).to_s
rescue ArgumentError
  file_path
end

def change_folder(cwd)
  stdout, status = Open3.capture2(CHANGE_FOLDER_SCRIPT, chdir: cwd)
  return nil unless status.success?

  stdout.strip
end

def reproduction_in_progress?(cwd)
  folder = change_folder(cwd)
  return false unless folder

  plan_path = File.join(cwd, folder, "plan.md")
  return false unless File.exist?(plan_path)

  File.read(plan_path).include?(REPRODUCTION_LINE)
end

def block(message)
  warn "Blocked: #{message}"
  exit 2
end

call = JSON.parse($stdin.read)
file_path = call.dig("tool_input", "file_path") || ""
cwd = call["cwd"] || Dir.pwd

exit 0 if file_path.empty?

relative_path = relative_to_repo(file_path, cwd)
exit 0 unless test_path?(relative_path)

if ARGV.include?("--always")
  block("this agent writes production code only; test paths are denied unconditionally.")
end

exit 0 unless reproduction_in_progress?(cwd)

block("bugfix in progress: the reproduction test is committed; fix the code, not the tests. " \
      "Remove `#{REPRODUCTION_LINE}` from plan.md to override on purpose.")
