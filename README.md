# dotfiles

========

My personal configuration for applications using dotfiles. Managed using [homesick](https://github.com/technicalpickles/homesick)!

## Configurations

This dotfile repository contains dotfile configuration for the following tools:

* neovim
* zsh
* Git: Global gitignore

## Installation

To install these dotfiles using [homesick](https://github.com/technicalpickles/homesick):

    gem install homesick
    homesick clone <your-github-username>/dotfiles
    homesick symlink dotfiles

## Install yourself

* [zsh-notify](https://github.com/eirvandelden/zsh-notify)
  * Running `git clone https://github.com/eirvandelden/zsh-notify ~/.zsh-notify/`
* [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-autosuggestions)
  * Running `git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh-autosuggestions/`
* **terminal notifier** `brew install terminal-notifier`

## Brew install

* `brew install the_silver_searcher`

## chnode

    brew tap tkareine/chnode
    brew install tkareine/chnode/chnode

## node-build

    brew install node-build

## Sensible OS X defaults

When setting up a new Mac, you may want to set some sensible OS X defaults:

    ./.macos
