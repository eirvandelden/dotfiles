require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Shared setup for the delivery scripts' tests (deliver, ship, open-pr-dash.sh): a temporary git
# repository with a bare repository behind "origin", stubbed `gh` and `herdr` on PATH, and a HOME
# of its own so no real configuration is read.
#
# The stubs are one Ruby program installed under both names. Each call appends its arguments, one
# line per call, to <state>/gh.log or <state>/herdr.log. Its answer comes from <state>/scripts.json,
# written by `stub_response`. The key is "<tool> <subcommand words>", longest match first:
# "herdr pane get w1:pA", then "herdr pane get"; `gh pr checks` also answers to "gh pr checks watch"
# (when --watch is given) and "gh pr checks json" (otherwise). The last key tried is "<tool> *". A
# key with several responses plays them in order and repeats the last. A response is a hash with
# "stdout", "stderr", "exit", and "jq_stdout" (printed instead of stdout when -q or --jq is given).
# `--body-file` and `--title` values are copied to <state>/captured/<tool>-<a>-<b>.body and .title
# at call time, because the script under test may delete the file afterwards.
module DeliveryHarness
  REPO_ROOT = File.expand_path("..", __dir__)
  DELIVER = File.join(REPO_ROOT, "claude/.claude/skills/deliver/scripts/deliver")
  SHIP = File.join(REPO_ROOT, "claude/.claude/skills/finish/scripts/ship")
  HERDR_SCRIPTS = File.join(REPO_ROOT, "herdr/.config/herdr/scripts")
  OPEN_PR_DASH = File.join(HERDR_SCRIPTS, "open-pr-dash.sh")
  WORKTREE_TOOLS_DIR = File.join(REPO_ROOT, "git/.config/git/worktree-tools")

  PERSONAL_URL = "git@github.com:eirvandelden/dots.git".freeze
  PR_URL = "https://github.com/eirvandelden/dots/pull/7".freeze
  OWN_PANE = "w1:pOwn".freeze

  STUB_SOURCE = <<~'RUBY'.freeze
    #!/usr/bin/env ruby
    require "fileutils"
    require "json"

    state = ENV.fetch("STUB_STATE")
    name = File.basename($0)
    File.open(File.join(state, "#{name}.log"), "a") { |file| file.puts(ARGV.join(" ")) }

    captured = File.join(state, "captured")
    FileUtils.mkdir_p(captured)
    ARGV.each_with_index do |argument, index|
      stem = File.join(captured, "#{name}-#{ARGV[0]}-#{ARGV[1]}")
      FileUtils.cp(ARGV[index + 1], "#{stem}.body") if argument == "--body-file" && ARGV[index + 1]
      File.write("#{stem}.title", ARGV[index + 1]) if argument == "--title" && ARGV[index + 1]
    end

    scripts_path = File.join(state, "scripts.json")
    scripts = JSON.parse(File.read(scripts_path))
    keys = [ "#{name} #{ARGV[0..2].join(' ')}", "#{name} #{ARGV[0..1].join(' ')}" ]
    keys.unshift("gh pr checks #{ARGV.include?('--watch') ? 'watch' : 'json'}") if name == "gh" && ARGV[0..1] == %w[pr checks]
    keys << "#{name} *"

    key = keys.find { |candidate| scripts.key?(candidate) }
    responses = scripts.fetch(key)
    response = responses.first
    if responses.size > 1
      scripts[key] = responses.drop(1)
      File.write(scripts_path, JSON.generate(scripts))
    end

    jq = ARGV.include?("--jq") || ARGV.include?("-q")
    $stdout.print(jq && response.key?("jq_stdout") ? response["jq_stdout"] : response["stdout"].to_s)
    $stderr.print(response["stderr"].to_s)
    exit(response["exit"].to_i)
  RUBY

  def setup_harness
    @state = Dir.mktmpdir
    @stub_bin = Dir.mktmpdir
    @home = Dir.mktmpdir
    @origin = Dir.mktmpdir
    @repo = Dir.mktmpdir
    @scripts = {}
    install_stubs
    default_responses
  end

  def teardown_harness
    FileUtils.rm_rf([ @state, @stub_bin, @home, @origin, @repo ].compact)
  end

  # A repository on a feature branch whose origin pushes to a bare repository. The origin URL
  # reads as the user's own GitHub account so `change-scope` answers "personal"; only the push URL
  # points at the bare repository, because that is the only place a push may go.
  def build_repo(branch: "my-change", origin_url: PERSONAL_URL)
    @branch = branch
    system("git", "init", "--quiet", "--bare", "--initial-branch=main", @origin) || raise("git init --bare failed")
    system("git", "init", "--quiet", "--initial-branch=main", @repo) || raise("git init failed")
    configure_repo(origin_url)
    commit_file("README.md", "readme\n", "initial")
    git("push", "--quiet", "origin", "main")
    git("checkout", "--quiet", "-b", branch)
  end

  def configure_repo(origin_url)
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test")
    git("config", "commit.gpgsign", "false")
    git("config", "core.hooksPath", "/dev/null")
    git("remote", "add", "origin", origin_url)
    git("remote", "set-url", "--push", "origin", @origin)
  end

  def commit_file(path, content, message)
    full = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    git("add", path)
    git("commit", "--quiet", "-m", message)
  end

  def intent_text
    <<~MD
      # Intent: Ship the widget

      Author: Test. Status: accepted. Type: feature.

      ## Problem

      Widgets cannot ship today.

      ## Proposed outcome

      Widgets ship by themselves.
    MD
  end

  def plan_text
    <<~MD
      # Plan: Ship the widget

      ## Files that change

      - `lib/widget.rb` — new.

      ## Proof

      - Widgets ship → `test/widget_test.rb` `test_widgets_ship`
    MD
  end

  # intent.md and plan.md, a code commit, then a review.md round that covers it.
  def commit_change_work(slug: @branch, template: nil, findings: [ "- [ ] Nit: Naming — `lib/widget.rb:1` → fixed (Rename widget)" ])
    commit_file(".github/PULL_REQUEST_TEMPLATE.md", template, "Add template") if template
    commit_file("docs/changes/#{slug}/intent.md", intent_text, "Add intent")
    commit_file("docs/changes/#{slug}/plan.md", plan_text, "Add plan")
    commit_file("lib/widget.rb", "class Widget; end\n", "Add widget")
    commit_review(slug, findings) if findings
  end

  def commit_review(slug, findings)
    body = findings.empty? ? "No findings." : findings.join("\n")
    round = "## Round 1 — 2026-10-13T10:00:00Z — #{git('rev-parse', '--short', 'HEAD').strip}\n\n#{body}\n"
    commit_file("docs/changes/#{slug}/review.md", "# Review\n\n#{round}", "Review round 1")
  end

  def stub_response(key, *responses)
    @scripts[key] = responses
    File.write(File.join(@state, "scripts.json"), JSON.generate(@scripts))
  end

  def default_responses
    stub_response("gh *", { "stdout" => "" })
    stub_response("herdr *", { "stdout" => '{"result":{}}' })
    stub_response("gh pr list", { "stdout" => "[]" })
    stub_response("gh pr create", { "stdout" => "#{PR_URL}\n" })
    stub_response("gh repo view", { "stdout" => '{"nameWithOwner":"eirvandelden/dots"}', "jq_stdout" => "eirvandelden/dots\n" })
  end

  def existing_pr(draft: true)
    stub_response("gh pr list", { "stdout" => JSON.generate([ { number: 7, url: PR_URL, isDraft: draft } ]) })
  end

  def git(*arguments)
    stdout, stderr, status = Open3.capture3(
      { "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil }, "git", "-C", @repo, *arguments
    )
    raise("git #{arguments.join(' ')} failed: #{stderr}") unless status.success?

    stdout
  end

  def origin_branches
    Open3.capture2("git", "--git-dir", @origin, "for-each-ref", "--format=%(refname:short)", "refs/heads/").first.split
  end

  def common_dir
    git("rev-parse", "--path-format=absolute", "--git-common-dir").strip
  end

  def toplevel
    File.realpath(@repo)
  end

  def gh_calls
    log_lines("gh")
  end

  def herdr_calls
    log_lines("herdr")
  end

  def log_lines(name)
    path = File.join(@state, "#{name}.log")
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def captured(name)
    path = File.join(@state, "captured", name)
    File.exist?(path) ? File.read(path) : nil
  end

  def run_script(script, *arguments, herdr: false, env: {})
    Open3.capture3(script_environment(herdr).merge(env), script, *arguments, chdir: @repo)
  end

  def script_environment(herdr)
    {
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}", "HOME" => @home, "STUB_STATE" => @state,
      "WORKTREE_TOOLS_DIR" => WORKTREE_TOOLS_DIR, "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "LEFTHOOK_BIN" => nil,
      "HERDR_ENV" => herdr ? "1" : nil, "HERDR_WORKSPACE_ID" => herdr ? "w1" : nil,
      "HERDR_PANE_ID" => herdr ? OWN_PANE : nil
    }
  end

  private

  def install_stubs
    %w[gh herdr].each do |name|
      path = File.join(@stub_bin, name)
      File.write(path, STUB_SOURCE)
      FileUtils.chmod(0o755, path)
    end
  end
end
