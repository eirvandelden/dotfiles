#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# In autonomous delivery a recorded critique replaces Etienne's word "accepted"
# on spec.md and plan.md. auto-accept is the one mechanical gate: it flips the
# status line only on a personal origin and only when every critique finding
# is closed.
class AutoAcceptTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/plan/scripts/auto-accept", __dir__)

  CLOSED_CRITIQUE = <<~MD
    ## Critique

    ### Round 1 (codex)

    - The plan skips the rollback path → fixed (added step 4)
    - Naming is vague → dismissed: the name matches the existing module
  MD

  def setup
    @repo = Dir.mktmpdir
    system("git", "-C", @repo, "init", "--quiet", "--initial-branch=main")
    @home = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@home, ".claude"))
    @artifact = File.join(@repo, "spec.md")
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@home)
  end

  def test_accepts_a_personal_artifact_with_a_closed_critique
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: CLOSED_CRITIQUE)

    _stdout, stderr, status = run_script

    assert(status.success?, stderr)
    assert_match(/Status: accepted$/, File.read(@artifact))
  end

  def test_changes_only_the_status_line
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: CLOSED_CRITIQUE)
    before = File.read(@artifact)

    run_script

    assert_equal(before.sub("Status: draft", "Status: accepted"), File.read(@artifact))
  end

  def test_refuses_on_a_work_origin
    allow_remotes("employer/their-app")
    add_remote("git@github.com:employer/their-app.git")
    write_artifact(critique: CLOSED_CRITIQUE)

    assert_refused(/personal/i)
  end

  def test_refuses_without_an_origin
    write_artifact(critique: CLOSED_CRITIQUE)

    assert_refused(/personal/i)
  end

  def test_refuses_without_a_critique_section
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "")

    assert_refused(/critique/i)
  end

  def test_refuses_a_critique_section_without_a_round
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "## Critique\n\nLooks fine.\n")

    assert_refused(/round/i)
  end

  def test_refuses_while_a_critique_finding_is_open
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "## Critique\n\n### Round 1 (codex)\n\n- Missing a test →\n")

    assert_refused(/open/i)
  end

  def test_refuses_an_artifact_that_is_not_draft
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: CLOSED_CRITIQUE, status: "accepted")

    assert_refused(/draft/i)
  end

  def test_refuses_a_finding_without_a_closure_slot
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "## Critique\n\n### Round 1 (codex)\n\n- Missing a test\n")

    assert_refused(/open/i)
  end

  def test_refuses_a_dismissal_without_a_reason
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "## Critique\n\n### Round 1 (codex)\n\n- Naming is vague → dismissed:\n")

    assert_refused(/open/i)
  end

  def test_refuses_a_fix_without_a_subject
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: "## Critique\n\n### Round 1 (codex)\n\n- Missing a test → fixed ()\n")

    assert_refused(/open/i)
  end

  def test_refuses_an_accepted_artifact_whose_body_quotes_a_draft_status
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: CLOSED_CRITIQUE, status: "accepted", body: "The old line read Status: draft.")

    assert_refused(/draft/i)
  end

  def test_leaves_a_quoted_draft_status_in_the_body_alone
    add_remote("git@github.com:eirvandelden/dotfiles.git")
    write_artifact(critique: CLOSED_CRITIQUE, body: "The old line read Status: draft.")

    run_script

    assert_includes(File.read(@artifact), "Status: accepted\n")
    assert_includes(File.read(@artifact), "The old line read Status: draft.")
  end

  private

  def assert_refused(pattern)
    before = File.read(@artifact)
    _stdout, stderr, status = run_script

    refute(status.success?)
    assert_match(pattern, stderr)
    assert_equal(before, File.read(@artifact))
  end

  def write_artifact(critique:, status: "draft", body: "Body text.")
    File.write(@artifact, "# Spec: x\n\nFrom intent.md. Status: #{status}\n\n#{body}\n\n#{critique}")
  end

  def allow_remotes(*entries)
    File.write(File.join(@home, ".claude", "consent-guard-allowed-remotes.txt"), entries.join("\n"))
  end

  def add_remote(url)
    system("git", "-C", @repo, "remote", "add", "origin", url)
  end

  def run_script
    Open3.capture3({ "HOME" => @home }, SCRIPT, @artifact, chdir: @repo)
  end
end
