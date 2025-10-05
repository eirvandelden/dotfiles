dotfiles
========

My personal configuration for applications using dotfiles. Managed using [homesick](https://github.com/technicalpickles/homesick)!

## Configurations

This dotfile repository contains dotfile configuration for the following tools:

* vim
* bash
* Git: Global gitignore

## Installation

    ln -s <source> ~/.<target>

## Install yourself

* [zprezto](https://github.com/sorin-ionescu/prezto)
  * Running `git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"` should suffice
* [zsh-notify](https://github.com/eirvandelden/zsh-notify)
  * Running `git clone https://github.com/eirvandelden/zsh-notify ~/.zsh-notify/`
* [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-autosuggestions)
  * Running `git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh-autosuggestions/`
* [solarized](http://ethanschoonover.com/solarized)
* **terminal notifier** `brew install terminal-notifier`

## Brew install

* `brew install the_silver_searcher`

## chnode

    brew tap tkareine/chnode
    brew install tkareine/chnode/chnode

## node-build

    brew install node-build

## puma-dev

Configure puma-dev with:

```
sudo puma-dev -setup
puma-dev -install -d test:localhost:WORK.test:WORK.localhost -install-port 9280 -install-https-port 928
```

## Sensible OS X defaults

When setting up a new Mac, you may want to set some sensible OS X defaults:

    ./.macos
