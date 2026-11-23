#!/usr/bin/env ruby
require "minitest/autorun"
require_relative "agent_git_support"
require_relative "isolated_git"

# The agent token comes from the login Keychain, one item per personal owner, and never from
# 1Password. `security` and `op` are PATH stubs that log their calls; `stub-token-*` are placeholders.
class AgentCredentialKeychainTest < Minitest::Test
  include AgentGitSupport

  HELPER = File.join(AGENT_DIRECTORY, "credential-keychain")

  def setup
    setup_agent_home
    write_security_stub
    write_executable(File.join(@bin, "op"), "#!/bin/sh\necho \"$*\" >> \"#{log('op')}\"\necho stub-1password-token\n")
  end

  def teardown
    teardown_agent_home
  end

  def test_get_prints_the_token_for_the_owner
    out, err, status = helper("eirvandelden", "get")

    assert status.success?, err
    assert_equal "username=x-access-token\npassword=stub-token-eirvandelden\n", out
    assert_includes calls("security"), "find-generic-password -s agent-git-github -a eirvandelden -w"
  end

  def test_get_without_an_owner_quits
    out, err, status = helper("get")

    assert status.success?
    assert_equal "quit=1\n", out
    assert_includes err, "agents push only to eirvandelden and eirvandelden-dev"
    assert_equal "", calls("security")
  end

  def test_a_missing_item_quits_and_names_the_token
    out, err, status = helper("nobody", "get")

    assert status.success?
    assert_equal "quit=1\n", out
    assert_includes err, "no agent token for nobody in the login Keychain (service agent-git-github)"
    refute_includes err + out, "stub-token"
  end

  def test_erase_names_the_rejected_token_and_keeps_the_item
    out, err, status = helper("eirvandelden-dev", "erase")

    assert status.success?
    assert_equal "", out
    assert_includes err, "GitHub rejected the agent token for eirvandelden-dev (service agent-git-github)"
    refute_includes calls("security"), "delete"
  end

  def test_store_does_nothing
    out, err, status = helper("eirvandelden", "store")

    assert status.success?
    assert_equal "", out + err
    assert_equal "", calls("security")
  end

  def test_each_owner_gets_its_own_agent_token_and_never_1password
    path = repository("git@github.com:eirvandelden/x.git")
    { "eirvandelden" => "eirvandelden", "eirvandelden-dev" => "eirvandelden-dev" }.each do |owner, account|
      out, err, status = git(path, "credential", "fill", stdin: "protocol=https\nhost=github.com\npath=#{owner}/x.git\n\n")

      assert status.success?, err
      assert_includes out, "password=stub-token-#{account}"
    end
    assert_equal "", calls("op")
  end

  def test_another_github_owner_stops_with_quit_and_never_1password
    path = repository("git@github.com:eirvandelden/x.git")
    out, err, status = git(path, "credential", "fill", stdin: "protocol=https\nhost=github.com\npath=someone/else.git\n\n")

    refute status.success?
    refute_includes out, "password="
    assert_includes err, "told us to quit"
    assert_equal "", calls("op")
  end

  def test_a_missing_agent_token_stops_git_and_names_it
    File.write(File.join(@home, "tokens-gone"), "")
    path = repository("git@github.com:eirvandelden-dev/x.git")
    out, err, status = git(path, "credential", "fill", stdin: "protocol=https\nhost=github.com\npath=eirvandelden-dev/x.git\n\n",
                                                       env: agent_env(claude_include, "STUB_NO_TOKENS" => "1"))

    refute status.success?
    refute_includes out, "password="
    assert_includes err, "no agent token for eirvandelden-dev"
    assert_equal "", calls("op")
  end

  def test_a_rejected_agent_token_is_named_on_erase
    path = repository("git@github.com:eirvandelden/x.git")
    _out, err, = git(path, "credential", "reject", stdin: "protocol=https\nhost=github.com\npath=eirvandelden/x.git\nusername=x-access-token\npassword=stub-token-eirvandelden\n\n")

    assert_includes err, "GitHub rejected the agent token for eirvandelden"
    assert_equal "", calls("op")
  end

  private

  def helper(*arguments)
    Open3.capture3(plain_env, HELPER, *arguments)
  end

  def write_security_stub
    write_executable(File.join(@bin, "security"), <<~SH)
      #!/bin/sh
      echo "$*" >> "#{log('security')}"
      [ -z "$STUB_NO_TOKENS" ] || exit 44
      account=$5
      [ "$account" = nobody ] && exit 44
      echo "stub-token-$account"
    SH
  end

  def log(name)
    File.join(@home, "#{name}.log")
  end

  def calls(name)
    File.exist?(log(name)) ? File.read(log(name)) : ""
  end
end
