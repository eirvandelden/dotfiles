# ~/.config/zsh/aliases.zsh

# Git
alias g='git'
alias gs='git stash'
alias gsp='git stash pop'
alias gst='git status'
alias gci='git commit'
alias gco='git checkout'
alias gad='git add -p .'
alias gadd='git add'
alias gdf='git diff -w'
alias gbr='git branch'
alias gbra='git branch -a'
alias gps='git push && afplay --volume 0.10 ~/.audioclips/push-it.wav'
alias gpl='git pull --rebase --autostash && afplay --volume 0.10 ~/.audioclips/come-here.mp3'
alias gcp='git cherry-pick'
alias grb='git rebase'
alias grbc='git rebase --continue'
alias grbs='git rebase --skip'
alias grba='git rebase --abort'
alias gclean='git branch --merged | grep -v "*" | xargs -n 1 git branch -d | git remote prune origin'
alias gitforce='git push --force-with-lease'

# Rails
## Environments
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

## aliases
alias rc='rails console'
alias rs='rails server'
alias rrs='puma-dev -stop'
alias rdbm='rails db:migrate'
alias rdbr='rails db:rollback'
alias rsg='rails g'
alias erd='rake erd && open erd.pdf'
alias dlog="tail -f log/development.log | tspin"

# Ruby
## TODO: replace this with ~/.default-gems and an install script
alias defaultgems="gem install bundler; bundle install --gemfile=~/.config/chruby/Gemfile.default"

## Bundler
alias bi='MAKE="make --jobs $(sysctl -n hw.ncpu)" bundle install && bin/rails app:update:bin; solargraph'
alias be="echo Use a .git/safe directory instead for binstubs"
alias audit="bundle audit update; bundle audit check"

alias ls='ls -laG'
alias rm="echo Use 'rmtrash', or the full path i.e. '/bin/rm'"
alias clr="clear && printf '\e[3J'"
alias ag="Echo Use 'rg', which is ripgrep"
alias hosts="sudo vim /etc/hosts; sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder; say 'DNS Cache is geleegd'"
alias pumalog="tail -f ~/Library/Logs/puma-dev.log"
alias myip="curl http://ipecho.net/plain; echo"
alias history="history 1"

# Caddy
alias caddyedit="nova -w $(brew --prefix)/etc/Caddyfile"
alias caddyfmt="caddy fmt --overwrite $(brew --prefix)/etc/Caddyfile"
alias caddylog="tail -f $(brew --prefix)/var/log/caddy.log"
alias caddyrestart="brew services restart caddy"
alias caddyconf="caddyedit; caddyfmt; caddyrestart; caddylog"
alias caddyvalidate="caddy validate --config $(brew --prefix)/etc/Caddyfile"

# Editors
#alias e="NVIM_LISTEN_ADDRESS=$HOME/.cache/nvim.sock nvim"
alias e="nvim"
