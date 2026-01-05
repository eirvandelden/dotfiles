# ~/.config/zsh/functions/gh.zsh

# Open github for my personal projects
ghp() {
  open "https://github.com/eirvandelden/${(j:/:)@}"
}
