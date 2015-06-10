#
# Lines configured by zsh-newuser-install
#
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd notify
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/Users/etienne/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

export PATH="/usr/local/bin:$PATH"

#if [ -f $(brew --prefix)/etc/bash_completion ]; then
#  source $(brew --prefix)/etc/bash_completion
#fi

#eval "$(rbenv init -)"


###aliasses
  #git
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add'
alias gdf='git diff'

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
export PATH=/Users/etienne/Library/Android/sdk/tools:$PATH
export PATH=/Users/etienne/Library/Android/sdk/platform-tools:$PATH


#plugins
source /Users/etienne/Documents/zsh-notify/notify.plugin.zsh
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"


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
autoload -U compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true

setopt completealiases

### ASML
export DYLD_LIBRARY_PATH=/opt/oracle/instantclient_11_2:$DYLD_LIBRARY_PATH
export ORACLE_HOME=/opt/oracle/instantclient_11_2
export NSLANG="AMERICAN_AMERICA.UTF8"
export PATH=/opt/oracle/instantclient_11_2:$PATH
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export NLS_LANG=AMERICAN_AMERICA.UTF8

#support Visual Studio Code
code () {
    if [[ $# = 0 ]]
    then
        open -a "Visual Studio Code"
    else
        [[ $1 = /* ]] && F="$1" || F="$PWD/${1#./}"
        open -a "Visual Studio Code" --args "$F"
    fi
}


PERL_MB_OPT="--install_base \"/Users/etienne/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/Users/etienne/perl5"; export PERL_MM_OPT;
