#!/usr/bin/env ruby
# Claude Code PostToolUse hook: after an Edit/Write/MultiEdit touches a Markdown file, runs the
# no-hardwrap markdownlint rule and, on findings, tells Claude the file, the wrapped lines, and
# how to fix them - so a wrapped paragraph gets caught right after it's written, the same habit
# `agents.md` rule 26 asks agents to avoid. Always exits 0: this hook only ever informs.
require "json"
require "open3"

CONFIG_DIR = File.expand_path("~/.config/markdownlint")
RULE_PATH = File.join(CONFIG_DIR, "no-hardwrap.cjs")
CHECK_CONFIG_PATH = File.join(CONFIG_DIR, "no-hardwrap.json")
FIX_COMMAND = "markdownlint -c ~/.config/markdownlint/unwrap.json -r ~/.config/markdownlint/no-hardwrap.cjs --fix"

def markdownlint_available?
  system("markdownlint", "--version", out: File::NULL, err: File::NULL)
end

def findings_for(file_path)
  _stdout, stderr, _status =
    Open3.capture3("markdownlint", "-j", "--config", CHECK_CONFIG_PATH, "--rules", RULE_PATH, file_path)
  JSON.parse(stderr)
rescue JSON::ParserError
  []
end

def tell_claude(file_path, findings)
  lines = findings.map { |finding| "line #{finding['lineNumber']}: #{finding['errorDetail']}" }.join("; ")
  context = "#{file_path} hardwraps markdown (#{lines}). Join each paragraph onto one line, " \
            "or run: #{FIX_COMMAND} #{file_path}"
  puts({ hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: context } }.to_json)
end

begin
  call = JSON.parse($stdin.read)
  file_path = call.dig("tool_input", "file_path") || ""

  if file_path.end_with?(".md") && File.exist?(file_path) && markdownlint_available?
    findings = findings_for(file_path)
    tell_claude(file_path, findings) unless findings.empty?
  end
rescue StandardError => error
  warn "markdown-hardwrap: #{error.message}"
end

exit 0
