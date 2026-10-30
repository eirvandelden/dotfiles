#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"
require_relative "git_fixture"
require_relative "isolated_git"

# The agent voice hook gives a personal session one playful persona on SessionStart. Work
# repositories and repositories without origin get nothing: fail closed. A directory outside git
# counts as personal. Claude and Codex run the same script.
class AgentVoiceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  HOOK = File.join(ROOT, "claude/.claude/hooks/agent-voice.rb")
  PERSONAS = [
    "WarCraft Orc Peon", "WarCraft Peasant", "WarCraft Thrall", "StarCraft SCV", "StarCraft Marine",
    "StarCraft Protoss Executor", "Diablo Deckard Cain", "Deekin Scalesinger", "Overlord minion", "Yoda"
  ].freeze
  SOURCES = "startup|resume|clear|compact|fork".freeze

  # One fixture per origin URL: an empty repository whose origin remote is that URL.
  REPOSITORIES = Hash.new do |fixtures, origin|
    fixtures[origin] = GitFixture.new do |repo|
      system("git", "init", "-q", repo, exception: true)
      system("git", "-C", repo, "remote", "add", "origin", origin, exception: true)
    end
  end
  private_constant :REPOSITORIES

  def setup
    @dir = Dir.mktmpdir
    @copies = []
  end

  def teardown
    FileUtils.rm_rf([ @dir, *@copies ])
  end

  def test_a_personal_repository_session_gets_a_persona_with_a_greeting
    stdout, stderr, status = run_hook(cwd: repository("git@github.com:eirvandelden/example.git"))

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Persona:")
    assert_match(/greeting/i, stdout)
    assert_equal(1, PERSONAS.count { |name| stdout.include?(name) })
  end

  def test_different_sessions_can_get_different_personas
    cwd = repository("git@github.com:eirvandelden/example.git")
    picks = (1..30).map { |n| persona_in(run_hook(cwd: cwd, session_id: "session-#{n}").first) }

    assert_operator(picks.uniq.size, :>, 1)
  end

  def test_the_same_session_keeps_its_persona
    cwd = repository("git@github.com:eirvandelden/example.git")
    picks = 3.times.map { persona_in(run_hook(cwd: cwd, session_id: "abc").first) }

    assert_equal(1, picks.uniq.size)
  end

  def test_resume_and_compact_keep_the_persona_without_a_greeting
    cwd = repository("git@github.com:eirvandelden/example.git")
    start = persona_in(run_hook(cwd: cwd, session_id: "abc").first)

    %w[resume compact fork].each do |source|
      stdout, = run_hook(cwd: cwd, session_id: "abc", source: source)

      assert_equal(start, persona_in(stdout), source) unless source == "fork"
      assert_match(/do not greet/i, stdout, source)
    end
  end

  def test_a_work_repository_session_prints_nothing
    stdout, stderr, status = run_hook(cwd: repository("git@github.com:someone-else/example.git"))

    assert_equal([ 0, "", "" ], [ status.exitstatus, stdout, stderr ])
  end

  def test_a_repository_without_origin_prints_nothing
    cwd = File.join(@dir, "bare")
    FileUtils.mkdir_p(cwd)
    system("git", "init", "-q", cwd, exception: true)

    stdout, = run_hook(cwd: cwd)

    assert_equal("", stdout)
  end

  def test_a_session_outside_git_gets_a_persona
    cwd = File.join(@dir, "plain")
    FileUtils.mkdir_p(cwd)

    stdout, = run_hook(cwd: cwd)

    assert_includes(stdout, "Persona:")
  end

  def test_a_directory_that_does_not_exist_prints_nothing
    stdout, stderr, status = run_hook(cwd: File.join(@dir, "missing"))

    assert_equal([ 0, "" ], [ status.exitstatus, stdout ], stderr)
  end

  def test_a_session_with_a_number_as_id_still_gets_a_persona
    stdout, stderr, status = run_hook(cwd: repository("git@github.com:eirvandelden/e.git"), session_id: 5)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Persona:")
  end

  def test_a_session_without_an_id_still_gets_a_persona
    stdout, stderr, status = run_hook(cwd: repository("git@github.com:eirvandelden/e.git"), session_id: nil)

    assert_equal(0, status.exitstatus, stderr)
    assert_includes(stdout, "Persona:")
  end

  def test_all_ten_personas_have_a_tone_and_catchphrases
    data = YAML.safe_load_file(File.join(ROOT, "claude/.claude/agent-voice.yml"), permitted_classes: [])
    personas = data.fetch("personas")

    assert_equal(PERSONAS.sort, personas.map { |persona| persona["name"] }.sort)
    personas.each do |persona|
      assert_operator(persona["tone"].to_s.size, :>, 10, persona["name"])
      assert_includes(1..8, persona["catchphrases"].size, persona["name"])
      refute_empty(persona["emoji"].to_s, persona["name"])
    end
  end

  def test_the_orc_peon_has_more_catchphrases_and_thrall_has_no_line_from_another_character
    personas = YAML.safe_load_file(File.join(ROOT, "claude/.claude/agent-voice.yml"), permitted_classes: []).fetch("personas")
    peon = personas.find { |persona| persona["name"] == "WarCraft Orc Peon" }
    thrall = personas.find { |persona| persona["name"] == "WarCraft Thrall" }

    assert_includes(peon["catchphrases"], "Dabu?")
    assert_operator(peon["catchphrases"].size, :>, 4)
    refute_includes(thrall["catchphrases"], "What is thy bidding?")
  end

  def test_deekin_has_his_two_extra_catchphrases
    personas = YAML.safe_load_file(File.join(ROOT, "claude/.claude/agent-voice.yml"), permitted_classes: []).fetch("personas")
    deekin = personas.find { |persona| persona["name"] == "Deekin Scalesinger" }

    assert_includes(deekin["catchphrases"], "Deekin?!")
    assert_includes(deekin["catchphrases"], "Doom doom doom...")
  end

  def test_the_overlord_minion_uses_the_chosen_catchphrases
    personas = YAML.safe_load_file(File.join(ROOT, "claude/.claude/agent-voice.yml"), permitted_classes: []).fetch("personas")
    minion = personas.find { |persona| persona["name"] == "Overlord minion" }

    assert_equal([ "For the Master!", "For you!", "For the Overlord!", "For me?", "Pillage? Pillage!" ], minion["catchphrases"])
  end

  def test_the_rules_ask_for_a_done_line_after_the_plain_summary
    assert_match(/done line.*after the plain summary/i, rules_text)
  end

  def test_the_rules_cap_flavour_at_two_lines_and_keep_most_replies_plain
    assert_match(/at most 2 flavour lines/i, rules_text)
    assert_match(/most replies have none/i, rules_text)
  end

  def test_the_rules_keep_code_commands_errors_commits_and_pr_text_plain
    assert_match(/code, commands, error text, commit messages and PR text/i, rules_text)
  end

  def test_the_rules_allow_emoji_in_ordinary_replies
    assert_match(/emoji.*ordinary replies/i, rules_text)
  end

  def test_the_rules_keep_security_warnings_and_destructive_confirmations_plain
    assert_match(/security warnings and confirmations of destructive actions/i, rules_text)
  end

  def test_a_missing_data_file_warns_instead_of_going_quiet
    stdout, stderr, status = run_hook(cwd: @dir, data: File.join(@dir, "missing.yml"))

    assert_equal([ 0, "" ], [ status.exitstatus, stdout ])
    assert_match(/agent-voice: could not read/, stderr)
  end

  def test_malformed_data_warns_instead_of_going_quiet
    data = File.join(@dir, "bad.yml")
    File.write(data, "personas: nope\n")

    stdout, stderr, status = run_hook(cwd: @dir, data: data)

    assert_equal([ 0, "" ], [ status.exitstatus, stdout ])
    assert_match(/agent-voice:/, stderr)
  end

  def test_data_without_personas_or_catchphrases_warns_instead_of_crashing
    [
      "personas: []\nrules: [x]\n",
      "personas:\n  - {name: A, emoji: x, tone: t}\nrules: [x]\n"
    ].each do |yaml|
      data = File.join(@dir, "partial.yml")
      File.write(data, yaml)

      stdout, stderr, status = run_hook(cwd: @dir, data: data)

      assert_equal([ 0, "" ], [ status.exitstatus, stdout ], yaml)
      assert_match(/agent-voice:/, stderr)
    end
  end

  def test_unparseable_stdin_warns_and_prints_nothing
    stdout, stderr, status = Open3.capture3(HOOK, stdin_data: "not json")

    assert_equal([ 0, "" ], [ status.exitstatus, stdout ])
    assert_match(/agent-voice:/, stderr)
  end

  def test_input_that_is_not_a_json_object_or_has_a_bad_cwd_prints_nothing_and_exits_zero
    [ "[]", "5", '{"cwd":5}' ].each do |input|
      stdout, _stderr, status = Open3.capture3(HOOK, stdin_data: input)

      assert_equal([ 0, "" ], [ status.exitstatus, stdout ], input)
    end
  end

  def test_claude_runs_the_hook_on_session_start
    entry = hook_entry(JSON.parse(File.read(File.join(ROOT, "claude/.claude/settings.json"))), "SessionStart")

    assert_equal("^(#{SOURCES})$", entry["matcher"])
    assert_equal('"$HOME/.claude/hooks/agent-voice.rb"', entry["hooks"].first["command"])
  end

  def test_codex_runs_the_same_hook_on_session_start
    config = File.read(File.join(ROOT, "codex/.codex/config.toml"))
    block = config[/\[\[hooks\.SessionStart\]\]\n(.*?)(?=\n\n\[(?!\[hooks\.SessionStart))/m, 1]

    assert_includes(block.to_s, %(matcher = "^(#{SOURCES})$"))
    assert_includes(block.to_s, %(command = '"$HOME/.claude/hooks/agent-voice.rb"'))
  end

  def test_claude_and_codex_match_the_same_sources
    settings = JSON.parse(File.read(File.join(ROOT, "claude/.claude/settings.json")))
    toml = File.read(File.join(ROOT, "codex/.codex/config.toml"))

    claude = hook_entry(settings, "SessionStart")["matcher"].delete_prefix("^(").delete_suffix(")$")
    codex = toml[/\[\[hooks\.SessionStart\]\]\nmatcher = "\^\((.*?)\)\$"/, 1]

    assert_equal(claude.split("|").sort, codex.to_s.split("|").sort)
  end

  def test_the_hook_reads_its_data_beside_itself_through_a_link
    hooks = File.join(@dir, "linked/hooks")
    FileUtils.mkdir_p(hooks)
    File.symlink(HOOK, File.join(hooks, "agent-voice.rb"))
    File.symlink(File.join(ROOT, "claude/.claude/agent-voice.yml"), File.join(@dir, "linked/agent-voice.yml"))
    cwd = File.join(@dir, "plain")
    FileUtils.mkdir_p(cwd)

    stdout, stderr, = run_hook(cwd: cwd, hook: File.join(hooks, "agent-voice.rb"), data: nil)

    assert_includes(stdout, "Persona:", stderr)
  end

  def test_the_playbook_exempts_flavour_lines_only_when_a_persona_was_given
    playbook = File.read(File.join(ROOT, "agents.md"))

    assert_match(/flavour lines.*exempt.*only when the `agent-voice` hook gave the session a persona/i, playbook)
  end

  private

  def repository(origin)
    REPOSITORIES[origin].copy.tap { |copy| @copies << copy }
  end

  def run_hook(cwd:, session_id: "s-1", source: "startup", data: :default, hook: HOOK)
    payload = { "cwd" => cwd, "source" => source }
    payload["session_id"] = session_id if session_id
    env = {}
    env["AGENT_VOICE_DATA"] = data unless data == :default || data.nil?
    Open3.capture3(env, hook, stdin_data: JSON.generate(payload))
  end

  def persona_in(stdout)
    PERSONAS.find { |name| stdout.include?("Persona: #{name}") }
  end

  def rules_text
    run_hook(cwd: @dir).first
  end

  def hook_entry(settings, event)
    settings.dig("hooks", event).find do |entry|
      entry["hooks"].any? { |hook| hook["command"].include?("agent-voice.rb") }
    end
  end
end
