#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# Autonomous delivery must hand over proof that matches the code it ships.
# delivery-evidence records every check against a fingerprint of the files it
# depends on, so an edit makes the proof stale, a change-folder commit does
# not, and the handover reports only what actually ran.
class DeliveryEvidenceTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/finish/scripts/delivery-evidence", __dir__)
  SECRET = "ghp_abcdefghijklmnopqrstuvwxyz0123456789"

  def setup
    @root = Dir.mktmpdir
    @home = File.join(@root, "home")
    @repo = File.join(@root, "repo")
    FileUtils.mkdir_p([ @home, @repo ])
    git("init", "--quiet", "--initial-branch=main")
    write_and_commit("README.md", "readme\n", "initial")
    git("checkout", "--quiet", "-b", "fix-login")
    write_and_commit("docs/changes/fix-login/intent.md", "# Intent\n", "intent")
    write_and_commit("app/models/claim.rb", "class Claim; end\n", "add claim")
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_run_exits_with_the_commands_status_and_records_a_failure
    _, _, status = evidence("run", "--kind", "tests", "--name", "suite", "--", "sh", "-c", "exit 3")

    assert_equal(3, status.exitstatus)
    assert_match(/^failed\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_command_that_changes_its_inputs_is_recorded_as_failed
    _, stderr, = evidence("run", "--kind", "tests", "--name", "suite", "--",
                          "sh", "-c", "echo changed >> app/models/claim.rb")

    assert_match(/changed/, stderr)
    assert_match(/^failed\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_change_folder_commit_keeps_evidence_fresh
    record_suite
    write_and_commit("docs/changes/fix-login/review.md", "# Review\n", "review")

    assert_match(/^fresh\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_an_uncommitted_code_edit_makes_evidence_stale
    record_suite
    File.write(File.join(@repo, "app/models/claim.rb"), "class Claim; def x; end; end\n")

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_committed_code_edit_makes_evidence_stale
    record_suite
    write_and_commit("app/models/claim.rb", "class Claim; def x; end; end\n", "edit claim")

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_an_untracked_file_makes_evidence_stale
    record_suite
    File.write(File.join(@repo, "app/new.rb"), "class New; end\n")

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_commit_of_the_verified_dirty_content_stays_fresh
    File.write(File.join(@repo, "app/models/claim.rb"), "class Claim; def x; end; end\n")
    record_suite
    git("commit", "--quiet", "-am", "edit claim")

    assert_match(/^fresh\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_deleted_file_makes_evidence_stale
    record_suite
    File.delete(File.join(@repo, "app/models/claim.rb"))

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_mode_change_makes_evidence_stale
    record_suite
    FileUtils.chmod(0o755, File.join(@repo, "app/models/claim.rb"))

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_rename_makes_evidence_stale
    record_suite
    git("mv", "app/models/claim.rb", "app/models/renamed.rb")

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_a_submodule_commit_change_makes_evidence_stale
    sub_source = File.join(@root, "sub-source")
    FileUtils.mkdir_p(sub_source)
    git("init", "--quiet", "--initial-branch=main", dir: sub_source)
    git("commit", "--quiet", "--allow-empty", "-m", "first", dir: sub_source)
    git("-c", "protocol.file.allow=always", "submodule", "--quiet", "add", sub_source, "vendor/sub")
    git("commit", "--quiet", "-m", "add submodule")
    record_suite

    git("commit", "--quiet", "--allow-empty", "-m", "second", dir: File.join(@repo, "vendor/sub"))

    assert_match(/^stale\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_the_newest_entry_per_name_is_current
    evidence("run", "--kind", "tests", "--name", "suite", "--", "false")
    record_suite

    lines = evidence("status")
    assert_equal(1, lines.length)
    assert_match(/^fresh\s+tests\s+suite\b/, lines.first)
    assert_equal(0, evidence_status("check"))
  end

  def test_status_lists_fresh_stale_and_failed
    record_suite
    evidence("run", "--kind", "lint", "--name", "rubocop", "--paths", "app/models", "--", "true")
    evidence("run", "--kind", "tests", "--name", "broken", "--", "false")
    File.write(File.join(@repo, "app/models/claim.rb"), "class Claim; def x; end; end\n")
    evidence("run", "--kind", "tests", "--name", "later", "--paths", "README.md", "--", "true")

    out = evidence("status").join
    assert_match(/^stale\s+tests\s+suite\b/, out)
    assert_match(/^stale\s+lint\s+rubocop\b/, out)
    assert_match(/^failed\s+tests\s+broken\b/, out)
    assert_match(/^fresh\s+tests\s+later\b/, out)
  end

  def test_evidence_is_shared_between_worktrees_of_one_repository
    record_suite
    other = File.join(@root, "other")
    git("worktree", "add", "--quiet", "-b", "ai/fix-login", other, "fix-login")

    stdout, stderr, status = evidence_in(other, "status")

    assert(status.success?, stderr)
    assert_match(/^fresh\s+tests\s+suite\b/, stdout)
  end

  def test_handover_refuses_without_a_delivered_note
    record_suite

    _, stderr, status = evidence_in(@repo, "handover")

    refute(status.success?)
    assert_match(/delivered/i, stderr)
  end

  def test_handover_refuses_while_check_fails
    evidence("note", "--delivered", "Login works.")
    evidence("run", "--kind", "tests", "--name", "suite", "--", "false")

    _, stderr, status = evidence_in(@repo, "handover")

    refute(status.success?)
    assert_match(/suite/, stderr)
  end

  def test_command_output_is_never_persisted
    stdout, = evidence_in(@repo, "run", "--kind", "tests", "--name", "suite", "--",
                          "sh", "-c", "echo output-marker-42")

    assert_match(/output-marker-42/, stdout)
    refute_match(/output-marker-42/, store_text)
  end

  def test_secret_shaped_output_reaches_neither_evidence_nor_handover
    evidence("note", "--delivered", "Login works.")
    stdout, = evidence_in(@repo, "run", "--kind", "tests", "--name", "suite", "--summary", "1 run, 0 failures",
                          "--", "sh", "-c", "echo $LEAKED", env: { "LEAKED" => SECRET })
    assert_match(/#{SECRET}/, stdout)

    path, _, status = evidence_in(@repo, "handover")

    assert(status.success?)
    refute_match(/#{SECRET}/, store_text)
    refute_match(/#{SECRET}/, File.read(path.strip))
  end

  def test_check_names_a_missing_required_kind
    record_suite

    _, stderr, status = evidence_in(@repo, "check", "--require", "tests,lint")

    assert_equal(1, status.exitstatus)
    assert_match(/lint/, stderr)
    refute_match(/\btests\b.*(missing|no fresh)/i, stderr)
  end

  def test_check_names_a_failed_entry
    evidence("run", "--kind", "tests", "--name", "suite", "--", "false")

    _, stderr, status = evidence_in(@repo, "check")

    assert_equal(1, status.exitstatus)
    assert_match(/suite.*failed/i, stderr)
  end

  def test_check_names_a_stale_entry
    record_suite
    write_and_commit("app/models/claim.rb", "class Claim; def x; end; end\n", "edit claim")

    _, stderr, status = evidence_in(@repo, "check")

    assert_equal(1, status.exitstatus)
    assert_match(/suite.*stale/i, stderr)
  end

  def test_check_requires_a_migration_replay_when_the_branch_touches_migrations
    write_and_commit("db/migrate/20261013_add_x.rb", "class AddX; end\n", "add migration")
    record_suite

    _, stderr, status = evidence_in(@repo, "check")

    assert_equal(1, status.exitstatus)
    assert_match(/migration/, stderr)

    evidence("run", "--kind", "migration", "--name", "replay", "--", "true")
    assert_equal(0, evidence_status("check"))
  end

  def test_a_changed_migration_makes_the_replay_stale
    write_and_commit("db/migrate/20261013_add_x.rb", "class AddX; end\n", "add migration")
    evidence("run", "--kind", "migration", "--name", "replay", "--", "true")
    File.write(File.join(@repo, "db/migrate/20261013_add_x.rb"), "class AddX; def change; end; end\n")

    assert_match(/^stale\s+migration\s+replay\b/, evidence("status").first)
  end

  def test_check_requires_a_browser_check_when_the_branch_touches_ui_paths
    File.write(File.join(@repo, "app/new.html.erb"), "<p>hi</p>\n")
    record_suite

    _, stderr, status = evidence_in(@repo, "check")

    assert_equal(1, status.exitstatus)
    assert_match(/browser/, stderr)

    evidence("record", "--kind", "browser", "--name", "login-page", "--status", "pass",
             "--scenario", "Open /login", "--result", "Form renders")
    assert_equal(0, evidence_status("check"))
  end

  def test_a_changed_view_makes_the_browser_check_stale
    write_and_commit("app/views/login.html.erb", "<p>hi</p>\n", "add view")
    evidence("record", "--kind", "browser", "--name", "login-page", "--status", "pass",
             "--scenario", "Open /login", "--result", "Form renders", "--paths", "app/views")
    File.write(File.join(@repo, "app/views/login.html.erb"), "<p>changed</p>\n")

    assert_match(/^stale\s+browser\s+login-page\b/, evidence("status").first)
  end

  def test_handover_lists_recorded_checks_with_outcome_revision_and_limits
    evidence("note", "--delivered", "Users can log in again.")
    evidence("note", "--limitation", "No test on Windows.")
    File.write(File.join(@repo, "app/models/claim.rb"), "class Claim; def x; end; end\n")
    evidence("run", "--kind", "tests", "--name", "suite", "--summary", "312 runs, 0 failures",
             "--limits", "Safari untested", "--", "true")
    evidence("record", "--kind", "browser", "--name", "login-page", "--status", "pass",
             "--scenario", "Open /login and sign in", "--result", "Dashboard shown")

    body = File.read(handover_path)

    assert_match(/## Delivered behaviour\n\nUsers can log in again\./, body)
    verification = body[/## Verification\n(.*?)(?=\n## )/m, 1]
    assert_match(/tests.*suite.*true.*312 runs, 0 failures.*plus uncommitted changes/, verification)
    assert_match(/Safari untested/, verification)
    assert_match(/browser.*login-page.*Open \/login and sign in.*Dashboard shown/, verification)
    assert_match(/## Limitations\n.*No test on Windows\..*Safari untested/m, body)
  end

  def test_handover_without_review_or_limits_says_so
    evidence("note", "--delivered", "Users can log in again.")
    record_suite

    body = File.read(handover_path)

    assert_match(/## Review\n\nNo review\.md found\./, body)
    assert_match(/## Limitations\n\nNone recorded\./, body)
  end

  def test_handover_summarises_each_review_round_by_source_and_closure
    write_and_commit("docs/changes/fix-login/review.md", REVIEW, "review")
    evidence("note", "--delivered", "Users can log in again.")
    record_suite

    review = File.read(handover_path)[/## Review\n(.*?)(?=\n## |\z)/m, 1]

    assert_match(/Round 1.*claude.*94623717.*1 Important, 1 Nit/, review)
    assert_match(/fixed \(Guard nil input\)/, review)
    assert_match(/dismissed.*"same behaviour as before"/, review)
    assert_match(/Round 2.*codex.*809774d8.*no findings/i, review)
    assert_match(/Round 3.*claude.*1 Nit.*open/m, review)
  end

  def test_handover_and_evidence_survive_removing_the_change_folder
    evidence("note", "--delivered", "Users can log in again.")
    record_suite
    path = handover_path

    git("rm", "-rq", "docs/changes/fix-login")
    git("commit", "--quiet", "-m", "remove change artifacts")

    assert(File.exist?(path))
    assert_match(/Users can log in again\./, File.read(path))
    assert_match(/^fresh\s+tests\s+suite\b/, evidence("status").first)
  end

  def test_pr_check_rejects_a_head_mismatch
    handover_path_with_note

    _, stderr, status = pr_check(JSON.generate("headRefOid" => "0" * 40, "body" => verification_text))

    assert_equal(1, status.exitstatus)
    assert_match(/head/i, stderr)
  end

  def test_pr_check_rejects_a_body_without_the_verification
    handover_path_with_note

    _, stderr, status = pr_check(JSON.generate("headRefOid" => head, "body" => "## Summary\n\nNothing\n"))

    assert_equal(1, status.exitstatus)
    assert_match(/verification/i, stderr)
  end

  def test_pr_check_accepts_a_matching_pull_request
    handover_path_with_note

    body = "## Summary\n\nx\n\n## Verification\n\n#{verification_text}\n\n## Review\n"
    stdout, stderr, status = pr_check(JSON.generate("headRefOid" => head, "body" => body))

    assert(status.success?, stderr)
    assert_match(/ok/i, stdout)
  end

  REVIEW = <<~MARKDOWN
    # Review: fix-login

    ## Round 1 — 2026-10-07T19:29Z — 94623717

    Notes.

    - [ ] Important: Nil input crashes the login form. — `app/models/claim.rb:1` → fixed (Guard nil input)
    - [ ] Nit: Name is vague. — `app/models/claim.rb:2` → dismissed: same behaviour as before

    ### Compliance

    Fine.

    ## Round 2 — 2026-10-13T09:35:08Z — 809774d8 (codex)

    No findings.

    ## Round 3 — 2026-10-13T10:46:54Z — af00e776 (claude)

    - [ ] Nit: Comment is stale. — `app/models/claim.rb:3`
  MARKDOWN

  private

  def record_suite
    evidence("run", "--kind", "tests", "--name", "suite", "--", "true")
  end

  def head
    git("rev-parse", "HEAD").first.strip
  end

  def handover_path
    path, stderr, status = evidence_in(@repo, "handover")
    assert(status.success?, stderr)
    path.strip
  end

  def handover_path_with_note
    evidence("note", "--delivered", "Users can log in again.")
    record_suite
    @handover = handover_path
  end

  def verification_text
    File.read(@handover)[/## Verification\n\n?(.*?)(?=\n## )/m, 1].strip
  end

  def pr_check(json)
    bin = File.join(@root, "bin")
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, "gh"), "#!/bin/sh\ncat \"$GH_STUB_JSON\"\n")
    FileUtils.chmod(0o755, File.join(bin, "gh"))
    File.write(File.join(@root, "pr.json"), json)
    evidence_in(@repo, "pr-check", env: { "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
                                           "GH_STUB_JSON" => File.join(@root, "pr.json") })
  end

  def store_text
    Dir.glob(File.join(@repo, ".git/herdr/deliver-fix-login-evidence.json")).map { |file| File.read(file) }.join
  end

  # Returns stdout lines, for the common status case.
  def evidence(*args)
    stdout, stderr, = evidence_in(@repo, *args)
    args.first == "status" ? stdout.lines : [ stdout, stderr, last_status ]
  end

  def evidence_status(*args)
    _, _, status = evidence_in(@repo, *args)
    status.exitstatus
  end

  def evidence_in(dir, *args, env: {})
    stdout, stderr, status = Open3.capture3(isolated_env.merge(env), SCRIPT, *args, chdir: dir)
    @last_status = status
    [ stdout, stderr, status ]
  end

  attr_reader :last_status

  def isolated_env
    { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_NOSYSTEM" => "1", "HOME" => @home,
      "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil }
  end

  def git(*args, dir: @repo)
    stdout, status = Open3.capture2e(isolated_env, "git", "-c", "core.hooksPath=/dev/null",
                                     "-c", "commit.gpgsign=false", "-c", "user.name=Test",
                                     "-c", "user.email=test@example.com", *args, chdir: dir)
    raise "git #{args.join(' ')} failed: #{stdout}" unless status.success?

    [ stdout ]
  end

  def write_and_commit(path, content, message)
    full = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    git("add", "--", path)
    git("commit", "--quiet", "-m", message)
  end
end
