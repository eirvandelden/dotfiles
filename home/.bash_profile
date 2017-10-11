export PATH="/usr/local/bin:$PATH"

if [ -f $(brew --prefix)/etc/bash_completion ]; then
  source $(brew --prefix)/etc/bash_completion
fi

###rbenv
# eval "$(rbenv init -)"

# chruby
if [[ -e /usr/local/opt/chruby/share/chruby ]]; then
  source /usr/local/opt/chruby/share/chruby/chruby.sh
  source /usr/local/opt/chruby/share/chruby/auto.sh
  chruby $(cat ~/.ruby-version)
fi

###git completion
if [ -f `brew --prefix`/etc/bash_completion ]; then
    . `brew --prefix`/etc/bash_completion
fi

###aliasses
  #git
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add'

  #others
alias be='bundle exec'

