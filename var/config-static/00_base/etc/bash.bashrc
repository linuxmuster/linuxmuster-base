# System-wide .bashrc file for interactive bash(1) shells.

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" -a -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color)
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# enable bash completion in interactive shells
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Vhata colour prompt
if [ `/usr/bin/whoami` = 'root' ]; then
  PS1='${debian_chroot:+($debian_chroot)}\A/$? \[\033[01;31m\]\h \[\033[01;34m\]\w \$ \[\033[00m\]'
else
  PS1='${debian_chroot:+($debian_chroot)}\A/$? \[\033[01;32m\][\u@\h] \[\033[01;34m\]\w \$ \[\033[00m\]'
fi

# aliases
alias dir='ls -l --color=auto'
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias la='ls -la --color=auto'
alias l='ls -alF --color=auto'
alias ls-l='ls -l --color=auto'
alias o='less'
alias ..='cd ..'
alias ...='cd ../..'
alias rd=rmdir
alias md='mkdir -p'
