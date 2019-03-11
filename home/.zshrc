#
# Lines configured by zsh-newuser-install
#
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
# setopt autocd notify
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "${ZDOTDIR:-$HOME}/.zshrc"

#MANUAL: brew completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
export PATH="/bin:/usr/local/bin:/usr/bin:$PATH"
# export PATH="/usr/local/bin:$PATH"

###aliasses
alias lup='licommander project up'
alias ldo='licommander project down'

  #git
alias g='git'
alias gs='git stash'
alias gsp='git stash pop'
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add'
alias gdf='git diff -w' # Don't show whitespace changes, those are always good
alias gbr='git branch'
alias gbra='git branch -a'
alias gps='git push && afplay --volume 0.25 ~/.audioclips/push-it.wav'
alias gpl='git pull --rebase --autostash && afplay --volume 0.25 ~/.audioclips/come-here.mp3'
alias gcp='git cherry-pick'
alias grb='git rebase'
alias gclean='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

  #rails environment
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

  #rails
alias rc='bundle exec rails c'
alias rs='bundle exec rails s'
alias rdbm='bundle exec rake db:migrate'
alias rdbr='bundle exec rake db:rollback'
alias rsg='bundle exec rails g'

# alias standard commands to bundle exec
alias cap='bundle exec cap'
alias erd='bundle exec rake erd && open erd.pdf'
alias rails='bundle exec rails'
alias rake='bundle exec rake'

  #others
alias os='overmind s'
alias oc='overmind connect'
alias ow='overmind connect web'
alias be='bundle exec'
alias bi='bundle install'
alias ls='ls -laG'
alias rm="echo Use 'rmtrash', or the full path i.e. '/bin/rm'"
alias clr="clear && printf '\e[3J'"
# alias clear="echo Use "
alias ag="Echo Use 'rg', which is ripgrep"

# VS Code
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

### Add PostgreSQL
# export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

### Add Go Path
# export GOPATH="$HOME/code/go"
# export PATH="$GOPATH/bin:$PATH"

### Prompt
# Setup spaceship-Prompt
# https://denysdovhan.com/spaceship-prompt/docs/Options.html#exit-code-exit_code
SPACESHIP_CHAR_SYMBOL = 🚀
SPACESHIP_CHAR_SYMBOL_SECONDARY = ➜
SPACESHIP_BATTERY_THRESHOLD = 40
SPACESHIP_BATTERY_PREFIX = 🔋

### zsh-plugins
##zsh-notify
#zsh notify for terminal thingies
source $HOME/.zsh-notify/notify.plugin.zsh
zstyle ':notify:*' notifier /usr/local/bin/terminal-notifier
zstyle ':notify:*' error-title "failed"
zstyle ':notify:*' error-sound "default"
zstyle ':notify:*' success-sound "wc3-work-complete"
# export NOTIFY_COMMAND_COMPLETE_TIMEOUT=2

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

# Load zsh-autosuggestions.
source $HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh

# Enable autosuggestions automatically.
zle -N zle-line-init

#zsh
autoload run-help
HELPDIR=/usr/local/share/zsh/help


# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm

# fish like autocompletion from zsh-syntax-highlighting (Needed at end of zshrc)
# source $HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# brew QT & imagemagick6
# export PATH="/usr/local/opt/qt@5.5/bin:$PATH"
# export PATH="/usr/local/opt/imagemagick@6/bin:$PATH"

# chruby
# if [[ -e /usr/local/opt/chruby/share/chruby ]]; then
  # source /usr/local/opt/chruby/share/chruby/chruby.sh
  # source /usr/local/opt/chruby/share/chruby/auto.sh
  # RUBIES+=( /usr/local/Cellar/ruby@1.9/*)
  # chruby $(cat ~/.ruby-version)
# fi
# Allows installation of default rubies
# from https://github.com/jpickwell/chruby-default-gems
# source /usr/local/share/chruby-default-gems.sh

# Don't show RVM_PROJECT_PATH in terminal
unsetopt AUTO_NAME_DIRS

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# export PATH="/usr/local/opt/libxslt/bin:$PATH"

# Add remote tools
# export PATH="$PATH:/Users/eirvandelden/code/rconsole/bin"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
# export PATH="$PATH:$HOME/.rvm/bin"

# tty support for gpg
export GPG_TTY=$(tty)

# Setup GPG pin-entry with user-agent
if test -f ~/.gnupg/.gpg-agent-info -a -n "$(pgrep gpg-agent)"; then
  source ~/.gnupg/.gpg-agent-info
  export GPG_AGENT_INFO
  GPG_TTY=$(tty)
  export GPG_TTY
else
  eval $(gpg-agent --daemon --write-env-file ~/.gnupg/.gpg-agent-info)
fi

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

## LICO

# open gitlab links via terminal
function gitlab {
  open "https://gitlab.lico.nl/${(j:/:)@}"
}

# ISMS
export PATH="$PATH:/Users/eirvandelden/code/isms-notify"

#remote tools
export PATH="$PATH:/Users/eirvandelden/code/remote-console-tools/bin"

source /usr/local/opt/chruby/share/chruby/chruby.sh
source /usr/local/opt/chruby/share/chruby/auto.sh

#chruby using rvm folders
RUBIES+=(~/.rvm/rubies/*)

chruby ruby-2.6.0
export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"

