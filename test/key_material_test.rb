#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../claude/.claude/hooks/key_material"
require_relative "isolated_git"

# KeyMaterial finds private keys that a staging command would add. Private key headers are built at
# run time, so no file of this repository holds one.
class KeyMaterialTest < Minitest::Test
  def setup
    @directory = File.realpath(Dir.mktmpdir("key-material"))
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_an_openssh_private_key_is_key_material
    assert KeyMaterial.key_material?(write("id", "#{header('OPENSSH PRIVATE KEY')}\nabc\n"))
  end

  def test_a_pem_private_key_is_key_material
    assert KeyMaterial.key_material?(write("pem", "#{header('RSA PRIVATE KEY')}\nabc\n"))
  end

  def test_a_master_key_is_key_material
    assert KeyMaterial.key_material?(write("config/master.key", "0123456789abcdef\n"))
  end

  def test_a_public_key_is_not_key_material
    refute KeyMaterial.key_material?(write("id.pub", "ssh-ed25519 AAAAC3Nza comment\n"))
  end

  def test_a_file_over_the_size_limit_is_not_key_material
    big = "#{header('OPENSSH PRIVATE KEY')}\n#{'a' * KeyMaterial::MAX_BYTES}\n"

    refute KeyMaterial.key_material?(write("big", big))
  end

  def test_stageable_in_lists_an_unignored_untracked_key
    repository
    write("deploy_key", "#{header('OPENSSH PRIVATE KEY')}\nabc\n")
    write("notes.txt", "hello\n")

    assert_equal [ "deploy_key" ], KeyMaterial.stageable_in(@directory)
  end

  def test_stageable_in_skips_an_ignored_master_key
    repository
    write(".gitignore", "config/master.key\n")
    write("config/master.key", "0123456789abcdef\n")

    assert_equal [], KeyMaterial.stageable_in(@directory)
  end

  def test_stageable_in_lists_an_already_staged_key
    repository
    write("deploy_key", "#{header('OPENSSH PRIVATE KEY')}\nabc\n")
    system("git", "-C", @directory, "add", "deploy_key", exception: true)

    assert_equal [ "deploy_key" ], KeyMaterial.stageable_in(@directory)
  end

  def test_stageable_in_is_empty_outside_a_repository
    write("deploy_key", "#{header('OPENSSH PRIVATE KEY')}\nabc\n")

    assert_equal [], KeyMaterial.stageable_in(@directory)
  end

  def test_stageable_in_skips_a_global_exemption
    repository
    write("config/master.key", "0123456789abcdef\n")
    write("other/master.key", "0123456789abcdef\n")

    with_git_config("GIT_CONFIG_GLOBAL" => global_config("config/master.key")) do
      assert_equal [ "other/master.key" ], KeyMaterial.stageable_in(@directory)
    end
  end

  def test_stageable_in_ignores_a_local_or_command_exemption
    repository
    write("config/master.key", "0123456789abcdef\n")
    system("git", "-C", @directory, "config", "--local", "agent.keyMaterialExempt", "config/master.key", exception: true)
    command = { "GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "agent.keyMaterialExempt",
                "GIT_CONFIG_VALUE_0" => "config/master.key", "GIT_CONFIG_GLOBAL" => File::NULL }

    with_git_config(command) do
      assert_equal [ "config/master.key" ], KeyMaterial.stageable_in(@directory)
    end
  end

  def test_stageable_in_still_lists_a_non_exempt_key
    repository
    write("config/master.key", "0123456789abcdef\n")
    write("deploy_key", "#{header('OPENSSH PRIVATE KEY')}\nabc\n")

    with_git_config("GIT_CONFIG_GLOBAL" => global_config("config/master.key")) do
      assert_equal [ "deploy_key" ], KeyMaterial.stageable_in(@directory)
    end
  end

  private

  def global_config(*paths)
    file = File.join(@directory, "..", "global-#{File.basename(@directory)}.config")
    File.write(file, "[agent]\n#{paths.map { |path| "  keyMaterialExempt = #{path}\n" }.join}")
    file
  end

  def with_git_config(values)
    saved = values.keys.to_h { |name| [ name, ENV.fetch(name, nil) ] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  def header(kind)
    "-----BEGIN #{kind}-----"
  end

  def repository
    system("git", "init", "-q", "-b", "main", @directory, exception: true)
  end

  def write(relative, content)
    path = File.join(@directory, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end
end
