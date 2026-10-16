#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "isolated_git"

# Proves which node a zsh resolves first, with a fake Homebrew node, a faithful
# chnode 0.4.3 stub, and a stand-in for macOS path_helper.
class NodePathOrderTest < Minitest::Test
  CHNODE_STUB = <<~'SH'
    CHNODE_VERSION=0.4.3
    : "${CHNODE_NODES_DIR=$HOME/.nodes}"

    chnode_replace_path() {
        local last_root=$1 new_root=${2:-}
        local new_path=:$PATH:
        local replacement_new_root
        if [[ -n $new_root ]]; then
            replacement_new_root=:$new_root/bin:
        else
            replacement_new_root=:
        fi
        new_path=${new_path//:$last_root\/bin:/"$replacement_new_root"}
        new_path=${new_path#:}
        new_path=${new_path%:}
        PATH=$new_path
    }

    chnode_reload() {
        local last_root=${CHNODE_ROOT:-}
        [[ -n $last_root ]] && chnode_reset
        CHNODE_NODES=()
        [[ ! (-d $CHNODE_NODES_DIR && -n "$(command ls "$CHNODE_NODES_DIR")") ]] && return
        CHNODE_NODES+=("$CHNODE_NODES_DIR"/*)
        [[ -z $last_root ]] && return
        local dir
        for dir in "${CHNODE_NODES[@]}"; do
            if [[ $dir == "$last_root" ]]; then
                if chnode_use "$dir"; then
                    return
                else
                    return 1
                fi
            fi
        done
    }

    chnode_reset() {
        local last_root=${CHNODE_ROOT:-}
        unset CHNODE_ROOT
        [[ -z $last_root ]] && return
        chnode_replace_path "$last_root"
        hash -r
    }

    chnode_use() {
        local new_root=$1
        if [[ ! -x "$new_root/bin/node" ]]; then
            echo "chnode: $new_root/bin/node not executable" >&2
            return 1
        fi
        if [[ -n ${CHNODE_ROOT:-} ]]; then
            chnode_replace_path "$CHNODE_ROOT" "$new_root"
        else
            PATH=$new_root/bin:$PATH
        fi
        export CHNODE_ROOT=$new_root
        export PATH
        hash -r
    }

    chnode_match() {
        local dir node given=$1
        for dir in "${CHNODE_NODES[@]}"; do
            dir="${dir%%/}"
            node="${dir##*/}"
            case $node in
                "$given")
                    match_output=$dir
                    break
                    ;;
                *"$given"*)
                    match_output=$dir
                    ;;
            esac
        done
    }

    chnode() {
        case ${1:-} in
            -r | --reset)
                chnode_reset
                ;;
            "")
                ;;
            *)
                local match_output
                chnode_match "$1"
                if [[ -z $match_output ]]; then
                    echo "chnode: unknown Node.js: $1" >&2
                    return 1
                fi
                chnode_use "$match_output"
                ;;
        esac
    }

    chnode_reload
  SH

  NODE_VERSIONS = %w[24.14.0 22.21.1 22.17.0 20.11.1].freeze

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @tmpdir = Dir.mktmpdir
    @home = File.join(@tmpdir, "home")
    @brew = File.join(@tmpdir, "homebrew")
    @rubies = File.join(@tmpdir, "rubies", "bin")
    build_fixtures
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_a_login_shell_puts_chnodes_node_ahead_of_homebrews_after_path_helper
    assert_first_node(node_bin("24.14.0"), "command -v node", login: true)
  end

  def test_an_inherited_chnode_root_beats_the_home_node_version_in_login_and_non_login_shells
    [ true, false ].each do |login|
      assert_first_node(node_bin("22.21.1"), "command -v node", login:, env: inherited_root("22.21.1"))
    end
  end

  def test_a_non_login_shell_puts_chnodes_node_first
    assert_first_node(node_bin("24.14.0"), "command -v node")
  end

  def test_interactive_login_and_non_login_shells_keep_chnodes_node_first_after_the_prompt_hook
    [ true, false ].each do |login|
      script = "apply_default_node_version; command -v node"

      assert_first_node(node_bin("24.14.0"), script, login:, interactive: true)
    end
  end

  def test_leaving_a_project_returns_to_the_inherited_node
    script = "cd #{@home}/project; command -v node; cd ../plain; command -v node"
    result = run_zsh(script, login: true, env: inherited_root("22.21.1"))

    assert_equal("", result[:stderr])
    assert_equal([ node_bin("20.11.1"), node_bin("22.21.1") ], result[:stdout].lines.map(&:strip))
  end

  def test_without_an_inherited_root_the_home_node_version_applies
    [ true, false ].each do |login|
      assert_first_node(node_bin("24.14.0"), "command -v node", login:)
    end
  end

  def test_npm_and_npx_come_from_chnodes_node_in_a_login_shell
    root = File.join(@home, ".nodes", "node-24.14.0")
    result = run_zsh("command -v npx; npm root -g", login: true)

    assert_equal("", result[:stderr])
    assert_equal([ File.join(root, "bin", "npx"), File.join(root, "lib", "node_modules") ], result[:stdout].lines.map(&:strip))
  end

  def test_a_project_node_version_wins_in_a_login_shell
    assert_first_node(node_bin("20.11.1"), "command -v node", login: true, chdir: File.join(@home, "project"))
  end

  def test_the_prompt_hook_keeps_the_shells_reply_variables
    script = "REPLY=kept; reply=(also kept); apply_default_node_version; print -r -- \"$REPLY ${reply[*]}\""
    result = run_zsh(script, chdir: File.join(@home, "project"))

    assert_equal("", result[:stderr])
    assert_equal("kept also kept", result[:stdout].strip)
  end

  def test_a_project_node_version_with_crlf_line_endings_applies
    project = mkdir(File.join(@home, "windows-project"))
    File.write(File.join(project, ".node-version"), "20.11.1\r\n")

    assert_first_node(node_bin("20.11.1"), "command -v node", chdir: project)
  end

  def test_an_empty_project_node_version_is_skipped
    project = mkdir(File.join(@home, "empty-project"))
    File.write(File.join(project, ".node-version"), " \n")

    assert_first_node(node_bin("22.21.1"), "command -v node", chdir: project, env: inherited_root("22.21.1"))
    assert_first_node(node_bin("24.14.0"), "command -v node", chdir: project)
  end

  def test_leaving_a_project_without_a_home_node_version_resets_the_node
    File.delete(File.join(@home, ".node-version"))
    result = run_zsh("cd #{@home}/project; command -v node; cd ../plain; command -v node")

    assert_equal("", result[:stderr])
    assert_equal([ node_bin("20.11.1"), File.join(@brew, "bin", "node") ], result[:stdout].lines.map(&:strip))
  end

  def test_rvs_ruby_stays_ahead_of_homebrews_ruby_in_a_login_shell
    assert_first_node(File.join(@rubies, "ruby"), "command -v ruby", login: true)
  end

  def test_the_unlocked_codex_shim_stays_first_in_a_login_shell
    shim_dir = File.join(@tmpdir, "unlocked-bin")
    write_exe(File.join(shim_dir, "codex"), "#!/bin/sh\nexit 0\n")

    assert_first_node(File.join(shim_dir, "codex"), "command -v codex", login: true, env: { "UNLOCKED_BIN" => shim_dir })
  end

  def test_zprofile_leaves_path_alone_without_chnode_root
    FileUtils.rm_f(File.join(@brew, "opt", "chnode", "share", "chnode", "chnode.sh"))

    assert_first_node(File.join(@brew, "bin", "node"), "command -v node", login: true)
  end

  def test_the_home_node_version_reached_through_a_symlinked_path_is_not_a_project_file
    link = File.join(@tmpdir, "home-link")
    File.symlink(@home, link)
    root = File.join(link, ".nodes", "node-22.21.1")
    env = { "HOME" => link, "CHNODE_ROOT" => root, "PATH" => "#{@brew}/bin:#{root}/bin:/usr/bin:/bin" }

    assert_first_node(File.join(root, "bin", "node"), "command -v node", login: true, env:)
  end

  def test_a_project_node_version_above_home_counts
    outside = mkdir(File.join(@tmpdir, "outside"))
    File.write(File.join(outside, ".node-version"), "20.11.1\n")

    assert_first_node(node_bin("20.11.1"), "command -v node", login: true, chdir: mkdir(File.join(outside, "deep")),
      env: inherited_root("22.21.1"))
  end

  def test_an_inherited_root_outside_the_nodes_dir_falls_back_to_the_home_node_version
    elsewhere = File.join(@tmpdir, "elsewhere", "node-22.21.1")
    write_node_root(elsewhere)
    env = { "CHNODE_ROOT" => elsewhere, "PATH" => "#{@brew}/bin:#{elsewhere}/bin:/usr/bin:/bin" }

    assert_first_node(node_bin("24.14.0"), "command -v node", login: true, env:)
  end

  def test_a_manual_chnode_choice_survives_the_next_prompt_hook
    script = "chnode 20.11.1; apply_default_node_version; command -v node"

    assert_first_node(node_bin("20.11.1"), script, interactive: true)
  end

  def test_inherited_root_is_selected_by_exact_directory_name
    assert_first_node(node_bin("22.17.0"), "command -v node", login: true, env: inherited_root("22.17.0"))
  end

  private

  def assert_first_node(expected, script, **options)
    result = run_zsh(script, **options)

    assert_equal("", result[:stderr])
    assert_equal(expected, result[:stdout].lines.last.to_s.strip)
  end

  def build_fixtures
    File.write(File.join(mkdir(@home), ".node-version"), "24.14.0\n")
    mkdir(File.join(@home, "plain"))
    mkdir(File.join(@home, "project"))
    File.write(File.join(@home, "project", ".node-version"), "20.11.1\n")
    NODE_VERSIONS.each { |version| write_node_root(File.join(@home, ".nodes", "node-#{version}")) }
    write_homebrew
  end

  def write_node_root(root)
    %w[node npx].each { |name| write_exe(File.join(root, "bin", name), "#!/bin/sh\nexit 0\n") }
    write_exe(File.join(root, "bin", "npm"), "#!/bin/sh\n[ \"$1 $2\" = 'root -g' ] && echo '#{root}/lib/node_modules'\n")
  end

  def write_homebrew
    %w[node npm npx ruby].each { |name| write_exe(File.join(@brew, "bin", name), "#!/bin/sh\nexit 0\n") }
    write_exe(File.join(@rubies, "ruby"), "#!/bin/sh\nexit 0\n")
    write_exe(File.join(@brew, "bin", "rv"), rv_stub)
    chnode_dir = mkdir(File.join(@brew, "opt", "chnode", "share", "chnode"))
    File.write(File.join(chnode_dir, "chnode.sh"), CHNODE_STUB)
  end

  def rv_stub
    <<~SH
      #!/bin/sh
      case "$2" in
        init) printf '%s\\n' 'function _rv_autoload_hook() { :; }' "path=(#{@rubies} \\"\\${path[@]}\\")" ;;
        env) printf '%s\\n' "export PATH='#{@rubies}:'\\"\\$PATH\\"" ;;
      esac
    SH
  end

  def mkdir(path)
    FileUtils.mkdir_p(path)
    path
  end

  def write_exe(path, body)
    mkdir(File.dirname(path))
    File.write(path, body)
    FileUtils.chmod("+x", path)
  end

  def inherited_root(version, dir: "node-#{version}")
    root = File.join(@home, ".nodes", dir)
    { "CHNODE_ROOT" => root, "PATH" => "#{@brew}/bin:#{root}/bin:/usr/bin:/bin" }
  end

  def node_bin(version)
    File.join(@home, ".nodes", "node-#{version}", "bin", "node")
  end

  # Runs `script` in a clean zsh. A login shell sources .zprofile after a
  # stand-in for macOS path_helper, which moves Homebrew's bin to the front.
  def run_zsh(script, login: false, interactive: false, chdir: File.join(@home, "plain"), env: {})
    zsh = [ "zsh", "-f", *("-i" if interactive), "-c", shell_script(script, login:) ]
    stdout, stderr, status = Open3.capture3(shell_env.merge(env), *zsh, chdir:, unsetenv_others: true)
    { stdout:, stderr:, status: }
  end

  def shell_script(script, login:)
    <<~SH
      typeset -gU path
      source "#{File.join(@repo_root, "zsh/.config/zsh/paths.zsh")}"
      #{login ? path_helper_and_zprofile : ""}
      #{script}
    SH
  end

  def path_helper_and_zprofile
    <<~SH
      path=("$HOMEBREW_PREFIX/bin" "${path[@]}")
      source "#{File.join(@repo_root, "zsh/.config/zsh/.zprofile")}"
    SH
  end

  def shell_env
    { "HOME" => @home, "HOMEBREW_PREFIX" => @brew, "PATH" => "#{@brew}/bin:/usr/bin:/bin", "TERM" => "dumb" }
  end
end
