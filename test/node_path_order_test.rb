#!/usr/bin/env ruby
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

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
    mkdir(File.join(root, "lib", "node_modules", "beautiful-mermaid"))
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
