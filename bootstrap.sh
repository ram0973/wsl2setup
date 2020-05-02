#!/bin/bash
echo Installation of pyenv
sudo apt-get update
echo Install pyenv dependencies
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python-openssl git
echo Install pyenv
curl https://pyenv.run | bash
