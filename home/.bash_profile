# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# from zshrc on 2019-11-04

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
alias rc='rails c'
alias rs='rails s'
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


# prepend .bin/ in path to use binstubs over bundle exec https://thoughtbot.com/blog/git-safe
export PATH=".git/safe/../../bin:$PATH"
