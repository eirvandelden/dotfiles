# dotfiles

========

My personal configuration for applications using dotfiles. Managed using [homesick](https://github.com/technicalpickles/homesick)!

## 🤖Installation

    mkdir -p ~/Developer
    cd ~/Developer
    git clone git@github.com:eirvandelden/dotfiles.git
    cd dotfiles
    ./install.sh

## 🔁Syncing brew packages

To dump your currently installed brew packages to a Brewfile:

    brew bundle dump --file ~/Developer/dotfiles/brew/Brewfile --force

To install packages from the Brewfile:

    ./install.sh

Or manually run:

    brew bundle install --file ~/Developer/dotfiles/brew/Brewfile

## 😔Manual installation

- [zsh-notify](https://github.com/eirvandelden/zsh-notify)
  - Running `git clone https://github.com/eirvandelden/zsh-notify ~/.zsh-notify/`
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-autosuggestions)
  - Running `git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh-autosuggestions/`
- [solarized](http://ethanschoonover.com/solarized)
- **terminal notifier** `brew install terminal-notifier`

### puma-dev

Configure puma-dev with:

```
sudo puma-dev -setup
puma-dev -install -d test:localhost:WORK.test:WORK.localhost -install-port 9280 -install-https-port 928
```

### Sensible OS X defaults

When setting up a new Mac, you may want to set some sensible OS X defaults:

    ./.macos
