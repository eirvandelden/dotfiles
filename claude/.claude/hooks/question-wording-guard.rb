#!/usr/bin/env ruby
# PreToolUse hook for Claude Code (same stdin/exit contract as consent-guard.rb): denies an
# AskUserQuestion call whose question text or option label says "I" or "you", so each question
# names its actor. Exit 2 with stderr blocks the call; any error in the hook itself allows it,
# because a broken hook must never block Etienne.
require "json"

begin
  require_relative "question_wording"

  input = JSON.parse($stdin.read)
  exit 0 unless input["tool_name"] == "AskUserQuestion"

  denial = QuestionWording.denial(input["tool_input"])
  if denial
    warn "Blocked: #{denial}"
    exit 2
  end
rescue StandardError, ScriptError => error
  warn "question-wording-guard: #{error.message}"
end
