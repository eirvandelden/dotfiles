#
# Lines configured by zsh-newuser-install
#
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
#setopt autocd notify
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
  #git
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add'
alias gdf='git diff'
alias gclean='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

  #rails environment
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

  #rails
alias rc='rails console'
alias rs='rails server'

  #others
alias be='bundle exec'

###fix maven with correct Java Home
export JAVA_HOME=$(/usr/libexec/java_home)

### add Android SDK
export PATH=$HOME/Library/Android/sdk/tools:$PATH
export PATH=$HOME/Library/Android/sdk/platform-tools:$PATH


## plugins
#zsh notify for terminal thingies
source /Users/Shared/zsh-notify/notify.plugin.zsh


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


# autocompletion
# autoload -U compinit
# compinit

#zstyle ':completion:*' menu select
#zstyle ':completion:*' special-dirs true

#setopt completealiases

# fish like autocompletion from plugin
# Load zsh-syntax-highlighting.
source ~/Documents/dotfiles/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Load zsh-autosuggestions.
source ~/Documents/dotfiles/zsh/zsh-autosuggestions/autosuggestions.zsh

# Enable autosuggestions automatically.
zle-line-init() {
    zle autosuggest-start
}
zle -N zle-line-init

#support Visual Studio Code
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* }

#zsh
unalias run-help
autoload run-help
HELPDIR=/usr/local/share/zsh/help

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"