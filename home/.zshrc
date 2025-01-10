#
# Executes commands when in an interactive session.
#

#
# Lines configured by zsh-newuser-install
#
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=2000
SAVEHIST=$HISTSIZE

# Write history file after each command so 2 shells share the same history
setopt SHARE_HISTORY HIST_IGNORE_DUPS

# setopt autocd notify
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

### zsh-plugins
##zsh-notify
#zsh notify for terminal thingies
source $HOME/.zsh-notify/notify.plugin.zsh
zstyle ':notify:*' notifier /opt/homebrew/bin/terminal-notifier
zstyle ':notify:*' error-title "failed"
zstyle ':notify:*' error-sound "default"
zstyle ':notify:*' success-sound "wc3-work-complete"
# export NOTIFY_COMMAND_COMPLETE_TIMEOUT=2

#MANUAL: brew completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

# Load zsh-autosuggestions.
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Enable autosuggestions automatically.
zle -N zle-line-init

#zsh
autoload run-help
HELPDIR=/usr/local/share/zsh/help

# fish like autocompletion from zsh-syntax-highlighting (Needed at end of zshrc)
# source $HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# RUBY
## Ruby install configuration
## Always install with yjit and jemalloc
## Don't forget to run `brew install jemalloc` and `brew install rust`
export RUBY_CONFIGURE_OPTS="--enable-yjit --with-jemalloc --disable-install-doc"
export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/jemalloc/include"
export LDFLAGS="-L$HOMEBREW_PREFIX/opt/jemalloc/lib"
# Always make ruby scripts debugable
# export RUBY_DEBUG_OPEN=true

#
# chruby
#

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh
chruby $(cat ~/.ruby-version)

# source: https://dance.computer.dance/posts/2015/02/making-chruby-and-binstubs-play-nice.html
# Remove the need for bundle exec ... or ./bin/...
# by adding ./bin to path if the current project is trusted
function set_local_bin_path() {
  # Replace any existing local bin paths with our new one
  export PATH="${1:-""}`echo "$PATH"|sed -e 's,[^:]*\.git/[^:]*bin:,,g'`"
}

function add_trusted_local_bin_to_path() {
  if [[ -d "$PWD/.git/safe" ]]; then
    # We're in a trusted project directory so update our local bin path
    set_local_bin_path "$PWD/.git/safe/../../bin:"
  fi
}
# Make sure add_trusted_local_bin_to_path runs after chruby so we
# prepend the default chruby gem paths
if [[ -n "$ZSH_VERSION" ]]; then
  if [[ ! "$preexec_functions" == *add_trusted_local_bin_to_path* ]]; then
    preexec_functions+=("add_trusted_local_bin_to_path")
  fi
fi

# https://reinteractive.com/posts/266-no-more-bundle-exec-using-the-new-rubygems_gemdeps-environment-variable
# export RUBYGEMS_GEMDEPS=-

# Terminal notifier
# Tell the terminal about the working directory whenever it changes.
if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]] && [[ -z "$INSIDE_EMACS" ]]; then
  update_terminal_cwd() {
    # Identify the directory using a "file:" scheme URL, including
    # the host name to disambiguate local vs. remote paths.

    # Percent-encode the pathname.
    local URL_PATH=''
    {
      # Use LANG=C to process text byte-by-byte.
      local i ch hexch LANG=C
      for ((i = 1; i <= ${#PWD}; ++i)); do
        ch="$PWD[i]"
        if [[ "$ch" =~ [/._~A-Za-z0-9-] ]]; then
          URL_PATH+="$ch"
        else
          hexch=$(printf "%02X" "'$ch")
          URL_PATH+="%$hexch"
        fi
      done
    }

    local PWD_URL="file://$HOST$URL_PATH"
    #echo "$PWD_URL"        # testing
    printf '\e]7;%s\a' "$PWD_URL"
  }

  # Register the function so it is called whenever the working
  # directory changes.
  autoload add-zsh-hook
  add-zsh-hook chpwd update_terminal_cwd

  # Tell the terminal about the initial directory.
  update_terminal_cwd
fi

# iterm2 auto profile switching based on macos Dark Mode
if [[ "$(uname -s)" == "Darwin" ]]; then
    sith() {
        val=$(defaults read -g AppleInterfaceStyle 2>/dev/null)
        if [[ $val == "Dark" ]]; then
            i
        fi
    }

    i() {
        if [[ $ITERM_PROFILE == "Light" ]]; then
            echo -ne "\033]50;SetProfile=Dark\a"
            export ITERM_PROFILE="Dark"
        else
            echo -ne "\033]50;SetProfile=Light\a"
            export ITERM_PROFILE="Light"
        fi
    }

    sith
fi

# open github links via terminal
 function gh {
   open "https://github.com/eet-nu/${(j:/:)@}"
 }

###aliasses
  #git
alias g='git'
alias gs='git stash'
alias gsp='git stash pop'
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add -p .'
alias gadd='git add'
alias gdf='git diff -w' # Don't show whitespace changes, those are always good
alias gbr='git branch'
alias gbra='git branch -a'
alias gps='git push && afplay --volume 0.10 ~/.audioclips/push-it.wav'
alias gpl='git pull --rebase --autostash && afplay --volume 0.10 ~/.audioclips/come-here.mp3'
alias gcp='git cherry-pick'
alias grb='git rebase'
alias grbc='git rebase --continue'
alias grbs='git rebase --skip'
alias grba='git rebase --abort'
alias gclean='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d | git remote prune origin'
# alias s='gpg_cache' # s for sign

  #rails environment
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

  #rails
alias rc='rails console'
alias rs='rails server'
alias rrs='puma-dev -stop'
alias rdbm='rails db:migrate'
alias rdbr='rails db:rollback'
alias rsg='rails g'

# alias standard commands to bundle exec
# alias cap='bundle exec cap'
alias erd='rake erd && open erd.pdf'
# alias rails='bundle exec rails'
# alias rake='bundle exec rake'
# alias guard='bundle exec guard'

  #others
# alias os='overmind s'
# alias oc='overmind connect'
# alias ow='overmind connect web'
alias be="echo Use a .git/safe directory instead for binstubs"
alias bi='MAKE="make --jobs $(sysctl -n hw.ncpu)" bundle install && bin/rails app:update:bin; solargraph'
alias ls='ls -laG'
alias rm="echo Use 'rmtrash', or the full path i.e. '/bin/rm'"
alias clr="clear && printf '\e[3J'"
# alias clear="echo Use "
alias ag="Echo Use 'rg', which is ripgrep"
alias audit="bundle audit update; bundle audit check"
alias hosts="sudo vim /etc/hosts; sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder; say 'DNS Cache is geleegd'"
alias pumalog="tail -f ~/Library/Logs/puma-dev.log"
alias myip="curl http://ipecho.net/plain; echo"
alias history="history 1"
alias celastic="docker run --rm --name elasticsearch -p 9200:9200 -p 9300:9300 -e 'discovery.type=single-node' -e 'xpack.security.enabled=false' elasticsearch:7.17.6"

alias dlog="tail -f log/development.log | tspin" # pass dev log to tailspin

# add `code` alias to open VS Code from the terminal while I'm one foot in VSCode world
# export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"


### Add PostgreSQL
# export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

### Add Go Path
# export GOPATH="$HOME/code/go"
# export PATH="$GOPATH/bin:$PATH"


function docker_mysql {
  containers=($(docker ps --format '{{.Names}}'))
  select container in $containers; do
    docker exec -it $container sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
    break
  done
}
function docker_bash {
  containers=($(docker ps --format '{{.Names}}'))
  select container in $containers; do
    docker exec -it $container bash
    break
  done
}


# My git sign key uses a passphrase. We can use 1password cli to get the password and preset it as the default passphrase for my key.
#function gpg_cache() {
#  gpg-connect-agent /bye &> /dev/null # Make sure gpg is setup
#  eval $(op signin --account vandelden.1password.com) # Sign in to 1password
  # yzimv5fpj2fckwxu3kcsffxf2e is the id for the "GPG passphrase item"
  # 4C8E003F23514693C30B18DB7E0194E652E6FF5D is the Keygrip for my GPG Key
#  op item get yzimv5fpj2fckwxu3kcsffxf2e --fields password | /opt/homebrew/opt/gpg2/libexec/gpg-preset-passphrase --preset 4C8E003F23514693C30B18DB7E0194E652E6FF5D
#}
# gpg_cache # Actually call cache function

# Sign commits with GPG
# export GPG_TTY=$(tty)
# gpgconf --launch gpg-agent

# homebrew github token
# export HOMEBREW_GITHUB_API_TOKEN=dd03b4d0025f18c4763db84e29fc3e4010cca475



# export PATH="/usr/local/bin:/usr/bin:$PATH"
# prepend .bin/ in path to use binstubs over bundle exec https://thoughtbot.com/blog/git-safe
# export PATH=".git/safe/../../bin:$PATH"

# https://gist.github.com/zanetagebka/3b9b42c92ce5926fd5aada6b3a9535a5
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export DISABLE_SPRING=true

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/etienne.vandelden/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
