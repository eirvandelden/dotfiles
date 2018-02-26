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

export PATH="/usr/local/bin:$PATH"

###aliasses
alias lup='licommander project up'
alias ldo='licommander project down'

  #git
alias gst='echo "Use zprezto git plugin (gws / gwS)"'
alias gci='echo "Use zprezto git plugin (gc)"'
# alias gco='git checkout' #handle by zprezto git plugin with exact same command
alias gad='echo "Use zprezto git plugin (gia)"'
alias gdf='echo "Use zprezto git plugin (gwsd)"'
alias gpush='git push && afplay --volume 0.25 ~/.audioclips/push-it.wav'
alias gpull='git pull --rebase --autostash && afplay --volume 0.25 ~/.audioclips/come-here.mp3'
alias gclean='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

  #rails environment
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

  #rails
alias rc='echo "Use rails zprezto plugin (rorc)"'
alias rs='echo "Use rails zprezto plugin (rors)"'

  #others
alias be='echo "Use zprezto ruby plugin (rbbe)"'
alias bi='echo "Use zprezto git plugin (rbbi)"'
alias ls='ls -laG'

### Add PostgreSQL
export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

### Add Go Path
export GOPATH="$HOME/code/go"
export PATH="$GOPATH/bin:$PATH"

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
export PATH="/usr/local/opt/qt@5.5/bin:$PATH"
export PATH="/usr/local/opt/imagemagick@6/bin:$PATH"

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
export PATH="/usr/local/opt/libxslt/bin:$PATH"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
