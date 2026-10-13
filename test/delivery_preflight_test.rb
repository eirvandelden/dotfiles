#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# delivery-preflight answers one question before autonomous delivery starts: can this machine
# finish the job unattended? Every external tool is a stub. PATH holds only the stub directory,
# so a real claude, codex, gh, node or browser is never found unless a test installs one.
class DeliveryPreflightTest < Minitest::Test
  SCRIPT = File.expand_path("../claude/.claude/skills/intent/scripts/delivery-preflight", __dir__)
  REMOTE = "git@github.com:someone/repo.git"
  EMAIL = "someone@example.invalid"
  CHECKS = %w[claude codex github origin signing runtime database browser].freeze

  def setup
    @tmp = Dir.mktmpdir
    @stub_bin = File.join(@tmp, "bin")
    @logs = File.join(@tmp, "logs")
    @home = File.join(@tmp, "home")
    @repo = File.join(@tmp, "repo")
    @origin = File.join(@tmp, "origin.git")
    @env = {}
    [ @stub_bin, @logs, @home, @repo ].each { |dir| FileUtils.mkdir_p(dir) }
    install_wrapper("git", Open3.capture2("sh", "-c", "command -v git").first.strip)
    install_wrapper("ruby", RbConfig.ruby)
    install_healthy_tools
    init_repo
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  def test_a_healthy_machine_has_no_blockers
    stdout, stderr, status = run_script

    assert_equal(0, status.exitstatus, stderr)
    assert_equal(CHECKS, check_names(stdout))
    assert_includes(stdout, "No blockers.")
    assert_match(/^pass     claude: /, stdout)
  end

  def test_reports_every_check_together_and_summarises_blockers
    install_stub("claude", %(echo '{"loggedIn":false,"email":"#{EMAIL}"}'))
    enable_signing

    stdout, _, status = run_script

    assert_equal(1, status.exitstatus)
    assert_equal(CHECKS, check_names(stdout))
    assert_match(/^missing  claude: not logged in$/, stdout)
    assert_match(/^pass     signing: /, stdout)
    assert_match(/^Blockers: claude$/, stdout)
  end

  def test_database_and_browser_are_not_applicable_without_needs
    stdout, = run_script

    assert_includes(stdout, "n/a      database: the agreed proof needs no database\n")
    assert_includes(stdout, "n/a      browser: the agreed proof needs no browser\n")
  end

  def test_a_needed_browser_that_is_absent_is_missing
    @env["DELIVERY_PREFLIGHT_APPLICATIONS"] = File.join(@tmp, "no-applications")

    stdout, _, status = run_script("--needs", "browser")

    assert_equal(1, status.exitstatus)
    assert_match(/^missing  browser: /, stdout)
    assert_match(/^Blockers: browser$/, stdout)
  end

  def test_a_browser_app_bundle_passes
    applications = File.join(@tmp, "Applications")
    FileUtils.mkdir_p(File.join(applications, "Google Chrome.app"))
    @env["DELIVERY_PREFLIGHT_APPLICATIONS"] = applications

    stdout, = run_script("--needs", "browser")

    assert_match(/^pass     browser: /, stdout)
  end

  def test_a_browser_on_path_passes
    install_stub("chromium", "exit 0")

    stdout, = run_script("--needs", "browser")

    assert_match(/^pass     browser: /, stdout)
  end

  def test_an_unknown_need_is_a_usage_error
    stdout, stderr, status = run_script("--needs", "database,printer")

    assert_equal(2, status.exitstatus)
    assert_match(/usage|unknown/i, stderr)
    assert_empty(stdout)
  end

  def test_never_prints_a_token_email_or_key
    install_stub("claude", %(echo '{"loggedIn":true,"email":"#{EMAIL}","token":"sk-ant-secret"}'))
    install_stub("gh", %(echo "$GH_TOKEN" > /dev/null; echo WRITE))
    @env["GH_TOKEN"] = "ghp_secrettoken123"
    key = enable_signing
    File.write(key, "SECRETKEYMATERIAL\n")
    git("config", "user.email", "dev@example.invalid")

    stdout, stderr, = run_script("--needs", "database,browser")

    [ EMAIL, "sk-ant-secret", "ghp_secrettoken123", "SECRETKEYMATERIAL", "dev@example.invalid", key ].each do |secret|
      refute_includes(stdout + stderr, secret)
    end
  end

  def test_leaves_the_repository_untouched
    File.write(File.join(@repo, ".ruby-version"), "#{RUBY_VERSION}\n")
    enable_signing
    before = snapshot

    run_script("--needs", "database,browser")

    assert_equal(before, snapshot)
    assert_empty(git("status", "--porcelain").first)
  end

  def test_a_hung_command_times_out_as_missing
    install_stub("claude", "/bin/sleep 30")
    @env["DELIVERY_PREFLIGHT_TIMEOUT"] = "1"

    started = Time.now
    stdout, _, status = run_script

    assert_operator(Time.now - started, :<, 15)
    assert_equal(1, status.exitstatus)
    assert_match(/^missing  claude: timed out after 1s$/, stdout)
  end

  def test_a_timed_out_command_and_its_child_are_killed
    pid_file = File.join(@tmp, "child.pid")
    install_stub("claude", "/bin/sleep 60 &\necho $! > #{pid_file}\n/bin/sleep 60")
    @env["DELIVERY_PREFLIGHT_TIMEOUT"] = "1"

    run_script

    assert(gone_soon?(Integer(File.read(pid_file).strip)), "the background child is still running")
  end

  def test_claude_that_is_not_installed_is_missing
    FileUtils.rm(File.join(@stub_bin, "claude"))

    stdout, = run_script

    assert_match(/^missing  claude: /, stdout)
  end

  def test_codex_that_is_not_logged_in_is_missing
    install_stub("codex", "exit 1")

    stdout, = run_script

    assert_match(/^missing  codex: /, stdout)
  end

  def test_github_without_write_permission_is_missing
    install_stub("gh", "echo READ")

    stdout, = run_script

    assert_match(/^missing  github: /, stdout)
  end

  def test_github_is_queried_for_the_origin_repository
    run_script

    assert_match(/repo view someone\/repo --json viewerPermission/, log("gh"))
  end

  def test_an_origin_that_is_not_on_github_is_missing
    point_origin_at(@origin, remote: @origin)

    stdout, = run_script

    assert_match(/^missing  github: /, stdout)
    assert_match(/^pass     origin: /, stdout)
  end

  def test_origin_that_cannot_be_read_is_missing
    point_origin_at(File.join(@tmp, "nowhere.git"))

    stdout, = run_script

    assert_match(/^missing  origin: /, stdout)
  end

  def test_signing_is_not_applicable_when_commits_are_unsigned
    stdout, = run_script

    assert_match(/^n\/a      signing: /, stdout)
  end

  def test_signing_that_fails_is_missing
    enable_signing(program: "exit 1")

    stdout, _, status = run_script

    assert_equal(1, status.exitstatus)
    assert_match(/^missing  signing: /, stdout)
  end

  def test_a_ruby_version_mismatch_is_missing
    File.write(File.join(@repo, ".ruby-version"), "1.8.7\n")

    stdout, = run_script

    assert_match(/^missing  runtime: .*1\.8\.7/, stdout)
  end

  def test_a_matching_ruby_version_passes
    File.write(File.join(@repo, ".ruby-version"), "#{RUBY_VERSION}\n")

    stdout, = run_script

    assert_match(/^pass     runtime: /, stdout)
  end

  def test_unsatisfied_bundle_is_missing
    File.write(File.join(@repo, "Gemfile"), "source \"https://rubygems.org\"\n")
    install_stub("bundle", %(echo "$BUNDLE_FROZEN" >> #{File.join(@logs, 'bundle.env')}\nexit 7))

    stdout, = run_script

    assert_match(/^missing  runtime: .*bundle/i, stdout)
    assert_equal("true\n", File.read(File.join(@logs, "bundle.env")))
  end

  def test_a_node_version_mismatch_is_missing
    File.write(File.join(@repo, ".node-version"), "99.0.0\n")
    install_stub("node", "echo v22.1.0")

    stdout, = run_script

    assert_match(/^missing  runtime: .*99\.0\.0/, stdout)
  end

  def test_declared_node_dependency_missing_from_node_modules_is_missing
    write_package(dependencies: { "left-pad" => "^1.0.0" })

    stdout, = run_script

    assert_match(/^missing  runtime: .*left-pad/, stdout)
  end

  def test_node_dependency_older_than_the_lockfile_is_missing
    write_package(dependencies: { "left-pad" => "^1.0.0" })
    write_lockfile("left-pad" => "1.3.0")
    install_node_module("left-pad", "1.1.0")

    stdout, = run_script

    assert_match(/^missing  runtime: .*left-pad/, stdout)
  end

  def test_node_dependencies_that_match_the_lockfile_pass
    write_package(dependencies: { "left-pad" => "^1.0.0" }, devDependencies: { "@scope/tool" => "^2.0.0" })
    write_lockfile("left-pad" => "1.3.0", "@scope/tool" => "2.0.1")
    install_node_module("left-pad", "1.3.0")
    install_node_module("@scope/tool", "2.0.1")

    stdout, = run_script

    assert_match(/^pass     runtime: /, stdout)
  end

  def test_without_a_lockfile_node_versions_are_not_compared
    write_package(dependencies: { "left-pad" => "^1.0.0" })
    install_node_module("left-pad", "1.1.0")

    stdout, = run_script

    assert_match(/^pass     runtime: .*not compared/, stdout)
  end

  def test_runtime_is_not_applicable_without_runtime_files
    stdout, = run_script

    assert_match(/^n\/a      runtime: /, stdout)
  end

  def test_an_unknown_database_adapter_is_missing
    rails_fixture("adapter: oracle_enhanced")

    stdout, = run_script("--needs", "database")

    assert_match(/^missing  database: .*oracle_enhanced/, stdout)
  end

  def test_a_database_needs_its_config_and_bin_rails
    stdout, = run_script("--needs", "database")

    assert_match(/^missing  database: /, stdout)
  end

  def test_sqlite_needs_the_sqlite3_cli
    rails_fixture("adapter: sqlite3")

    stdout, = run_script("--needs", "database")
    assert_match(/^missing  database: .*sqlite3/, stdout)

    install_stub("sqlite3", "exit 0")
    stdout, = run_script("--needs", "database")
    assert_match(/^pass     database: .*not checked/, stdout)
  end

  def test_database_checks_never_contact_a_server_from_the_environment
    rails_fixture("adapter: postgresql", "adapter: mysql2")
    %w[psql pg_isready mysql].each { |tool| install_stub(tool, "echo called >> #{File.join(@logs, "#{tool}.log")}") }
    @env.merge!("PGHOST" => "db.production.invalid", "PGSERVICE" => "prod", "MYSQL_HOST" => "db.production.invalid")

    stdout, = run_script("--needs", "database")

    assert_match(/^pass     database: .*not checked/, stdout)
    %w[psql pg_isready mysql].each { |tool| refute(File.exist?(File.join(@logs, "#{tool}.log")), "#{tool} ran") }
  end

  private

  def run_script(*args)
    env = { "PATH" => @stub_bin, "HOME" => @home, "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_NOSYSTEM" => "1" }
    Open3.capture3(env.merge(@env), SCRIPT, *args, chdir: @repo, unsetenv_others: true)
  end

  def check_names(stdout)
    stdout.lines.grep(/\A(?:pass|missing|n\/a) /).map { |line| line.split[1].delete_suffix(":") }
  end

  def git(*args, dir: @repo)
    env = { "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_NOSYSTEM" => "1", "HOME" => @home }
    stdout, stderr, status = Open3.capture3(env, "git", "-C", dir, *args)
    raise "git #{args.join(' ')} failed: #{stderr}" unless status.success?

    [ stdout, stderr ]
  end

  def init_repo
    git("init", "--quiet", "--initial-branch=main")
    git("init", "--quiet", "--bare", "--initial-branch=main", @origin, dir: @tmp)
    %w[user.name user.email].each { |key| git("config", key, "Preflight Test") }
    git("config", "commit.gpgsign", "false")
    File.write(File.join(@repo, "README.md"), "x\n")
    git("add", "README.md")
    git("commit", "--quiet", "-m", "initial")
    git("remote", "add", "origin", REMOTE)
    point_origin_at(@origin)
    git("push", "--quiet", "origin", "main")
  end

  # The remote URL stays a GitHub URL so the github check can parse it; git is told where it
  # really lives. Pass remote: to change the URL itself.
  def point_origin_at(path, remote: REMOTE)
    git("config", "remote.origin.url", remote)
    git("config", "--remove-section", "url.#{@rewrite}") if @rewrite
    @rewrite = nil
    return if remote == path

    git("config", "url.#{path}.insteadOf", remote)
    @rewrite = path
  end

  def install_wrapper(name, target)
    install_stub(name, %(exec "#{target}" "$@"))
  end

  def install_stub(name, body)
    path = File.join(@stub_bin, name)
    File.write(path, "#!/bin/sh\necho \"$@\" >> #{File.join(@logs, "#{name}.log")}\n#{body}\n")
    File.chmod(0o755, path)
  end

  def log(name)
    path = File.join(@logs, "#{name}.log")
    File.exist?(path) ? File.read(path) : ""
  end

  def install_healthy_tools
    install_stub("claude", %(echo '{"loggedIn":true,"email":"#{EMAIL}"}'))
    install_stub("codex", "exit 0")
    install_stub("gh", "echo WRITE")
  end

  # A stub ssh-keygen: git hands the buffer file last and reads "<buffer>.sig" back.
  def enable_signing(program: nil)
    key = File.join(@tmp, "key.pub")
    File.write(key, "ssh-ed25519 AAAAFAKE preflight\n")
    signer = File.join(@tmp, "signer")
    body = program || %(for last in "$@"; do :; done\necho "-----BEGIN SSH SIGNATURE-----" > "$last.sig")
    File.write(signer, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, signer)
    { "commit.gpgsign" => "true", "gpg.format" => "ssh", "user.signingkey" => key, "gpg.ssh.program" => signer }
      .each { |name, value| git("config", name, value) }
    key
  end

  def rails_fixture(*adapters)
    FileUtils.mkdir_p(File.join(@repo, "config"))
    FileUtils.mkdir_p(File.join(@repo, "bin"))
    yaml = adapters.each_with_index.map { |line, index| "env#{index}:\n  #{line}\n" }.join
    File.write(File.join(@repo, "config", "database.yml"), yaml)
    File.write(File.join(@repo, "bin", "rails"), "#!/bin/sh\n")
    File.chmod(0o755, File.join(@repo, "bin", "rails"))
  end

  def write_package(dependencies: {}, devDependencies: {})
    File.write(File.join(@repo, "package.json"),
               JSON.generate("dependencies" => dependencies, "devDependencies" => devDependencies))
  end

  def write_lockfile(versions)
    packages = versions.to_h { |name, version| [ "node_modules/#{name}", { "version" => version } ] }
    File.write(File.join(@repo, "package-lock.json"), JSON.generate("lockfileVersion" => 3, "packages" => packages))
  end

  def install_node_module(name, version)
    dir = File.join(@repo, "node_modules", name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "package.json"), JSON.generate("name" => name, "version" => version))
  end

  def snapshot
    Dir.glob(File.join(@repo, "**", "*"), File::FNM_DOTMATCH).sort.filter_map do |path|
      next if File.directory?(path)

      [ path, File.mtime(path).to_f, File.read(path) ]
    end
  end

  def gone_soon?(pid)
    20.times do
      Process.kill(0, pid)
      sleep 0.1
    rescue Errno::ESRCH
      return true
    end
    false
  end
end
