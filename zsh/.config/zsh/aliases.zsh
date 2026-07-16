# ~/.config/zsh/aliases.zsh

# Git
alias g='lazygit'
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
alias gps='git push && afplay --volume 0.10 ~/.config/audioclips/push-it.wav'
alias gpl='git pull --rebase --autostash && afplay --volume 0.10 ~/.config/audioclips/come-here.mp3'
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

## Bundler
bi() {
  # disabled gem installation via rv ci until it supports bundler configs
  # local make_jobs
  # make_jobs="make --jobs $(sysctl -n hw.ncpu)"

  # if [ -f "Gemfile.lock" ]; then
  #   MAKE="$make_jobs" rv ci
  # else
  #   MAKE="$make_jobs" bundle install
  # fi && bin/rails app:update:bin

  bundle install
  bin/rails app:update:bin
  solargraph
}
alias be="echo Use a .git/safe directory instead for binstubs"
alias audit="bundle audit update; bundle audit check"

alias ls='ls -laG'
alias rm="echo Use 'rmtrash', or the full path i.e. '/bin/rm'"
alias clr="clear && printf '\e[3J'"
alias ag="Echo Use 'rg', which is ripgrep"
# Edit /etc/hosts safely: copy to a user-owned temp file, edit with nvim
# (terminal-only — no GUI process as root), then install back with sudo.
hosts() (
  local tmp
  tmp="$(mktemp)"
  trap '/bin/rm -f "$tmp"' EXIT
  sudo cp /etc/hosts "$tmp" || return
  sudo chmod 644 "$tmp" || return
  nvim "$tmp" || return
  sudo install -m 644 "$tmp" /etc/hosts
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  say 'DNS Cache is geleegd'
)
alias pumalog="tail -f ~/Library/Logs/puma-dev.log"
alias myip="curl http://ipecho.net/plain; echo"
alias history="history 1"

# Caddy
alias caddyedit='editor-wait "$HOMEBREW_PREFIX/etc/Caddyfile"'
alias caddyfmt='caddy fmt --overwrite "$HOMEBREW_PREFIX/etc/Caddyfile"'
alias caddylog='tail -f "$HOMEBREW_PREFIX/var/log/caddy.log"'
alias caddyrestart="brew services restart caddy"
alias caddyconf="caddyedit; caddyfmt; caddyrestart; caddylog"
alias caddyvalidate='caddy validate --config "$HOMEBREW_PREFIX/etc/Caddyfile"'

# Portless (proxy lives behind Caddy on :1355)
alias portless-start='portless proxy start -p 1355 --no-tls'
alias portless-stop='portless proxy stop'
alias portless-log='tail -f /tmp/portless-proxy.log'

# Secrets
alias unlock='eval "$(secrets)"'

# Editors
# e: opens terminal Neovim when in a terminal, Neovide otherwise.
# Aliases expand to the command + any arguments, so no "$@" is needed here.
alias e='editor'
