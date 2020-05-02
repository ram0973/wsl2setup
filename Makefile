SHELL := /bin/bash

help:
	make -h

pyenv:
	echo Install pyenv dependencies
	sudo apt-get update
	sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
	libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
	xz-utils tk-dev libffi-dev liblzma-dev python-openssl git
	echo Install pyenv
	curl https://pyenv.run | bash
	echo Restart shell
	echo Make sure .basrc have this:
	echo export PATH="$HOME/.pyenv/bin:$PATH"
	echo eval "$(pyenv init -)"
	echo eval "$(pyenv virtualenv-init -)"

poetry:
	pip install --upgrade pip
	pip install poetry=
	echo run source $HOME/.poetry/env
