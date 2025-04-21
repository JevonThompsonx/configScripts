#!/bin/bash

echo "Starting system config cloning"

echo "Let's log into github"

gh auth login

echo "Let's start cloning!"

gh repo clone nvim ~/config
gh repo clone alacritty ~/config 
gh repo clone fish ~/config
gh repo clone foot ~/config
gh repo clone WPs ~/Pictures
gh repo clone variety ~/config
gh repo clone fastfetch ~/config
