# ~/.config/zsh/functions/gh.zsh

# Open github for my personal projects: the eirvandelden-dev organisation when it
# has the repository, else the eirvandelden user (also when the lookup fails).
ghp() {
  local owner=eirvandelden
  if (( $# )) && gh api "repos/eirvandelden-dev/$1" --silent >/dev/null 2>&1; then
    owner=eirvandelden-dev
  fi
  local IFS=/
  open "https://github.com/$owner/$*"
}
