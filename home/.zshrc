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

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi
export PATH="/bin:/usr/local/bin:/usr/bin:$PATH"

# fixes ruby processes crashing due to using fork() on macos
# stolen from: https://blog.phusion.nl/2017/10/13/why-ruby-app-servers-break-on-macos-high-sierra-and-what-can-be-done-about-it/
# export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

###aliasses
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
alias grbc='git rebase --continue'
alias grbs='git rebase --skip'
alias grba='git rebase --abort'
alias gclean='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

  #rails environment
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

  #rails
alias rc='rails c'
alias rs='rails s'
alias rrs='puma-dev -stop'
alias rdbm='rake db:migrate'
alias rdbr='rake db:rollback'
alias rsg='rails g'

# alias standard commands to bundle exec
# alias cap='bundle exec cap'
alias erd='rake erd && open erd.pdf'
# alias rails='bundle exec rails'
# alias rake='bundle exec rake'
# alias guard='bundle exec guard'

  #others
alias os='overmind s'
alias oc='overmind connect'
alias ow='overmind connect web'
alias be="echo Use a .git/safe directory instead for binstubs"
alias bi='bundle install'
alias ls='ls -laG'
alias rm="echo Use 'rmtrash', or the full path i.e. '/bin/rm'"
alias clr="clear && printf '\e[3J'"
# alias clear="echo Use "
alias ag="Echo Use 'rg', which is ripgrep"
alias audit="bundle audit update; bundle audit check"
alias hosts="sudo vim /etc/hosts; sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder; say 'DNS Cache is geleegd'"
alias pumalog="tail -f ~/Library/Logs/puma-dev.log"

# VS Code
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# open github links via terminal
 function gh {
   open "https://github.com/eet-nu/${(j:/:)@}"
 }

### Add PostgreSQL
# export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

### Add Go Path
# export GOPATH="$HOME/code/go"
# export PATH="$GOPATH/bin:$PATH"

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

# fish like autocompletion from zsh-syntax-highlighting (Needed at end of zshrc)
# source $HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# NVM_DIR
export NVM_DIR="$HOME/.nvm"
  [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

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

# chruby
if [[ -e /usr/local/opt/chruby/share/chruby ]]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
  chruby $(cat ~/.ruby-version)

  #enable chruby-default-gems
  DEFAULT_GEMFILE='~/.default-ruby-gems'
  source /usr/local/share/chruby-default-gems.sh
fi

# homebrew github token
# export HOMEBREW_GITHUB_API_TOKEN=dd03b4d0025f18c4763db84e29fc3e4010cca475

# prepend .bin/ in path to use binstubs over bundle exec https://thoughtbot.com/blog/git-safe
export PATH=".git/safe/../../bin:$PATH"

# heroku autocomplete setup
HEROKU_AC_ZSH_SETUP_PATH=/Users/eirvandelden/Library/Caches/heroku/autocomplete/zsh_setup && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH;