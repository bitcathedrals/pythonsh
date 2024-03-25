FROM alpine:3.19.1

LABEL docker-version = "2"
LABEL python-python = "3.11"
LABEL timestamp = "Sun"

RUN apk update && apk --no-cache add git gcc autoconf automake libtool openssl-dev bash build-base \
sqlite-dev pkgconf linux-headers ca-certificates bzip2-dev zlib-dev ncurses-dev readline-dev \
libffi-dev xz-dev shadow coreutils

ENV SHELL=/bin/bash

ENV USER=python
ENV HOME=/home

RUN adduser -D -h $HOME $USER && chmod 755 $HOME

USER $USER
WORKDIR /home

ENV TMPDIR=$HOME/tmp
RUN test -d $TMPDIR || mkdir -p $TMPDIR

ENV PYENV_ROOT="$HOME/.pyenv"
ENV PYENV_BIN="$PYENV_ROOT/bin"

ARG TOOLS=$HOME/tools

ENV TOOLS_LOCAL=$TOOLS/local
ENV TOOLS_BIN=$TOOLS_LOCAL/bin
RUN test -d $TOOLS_BIN || mkdir -p $TOOLS_BIN

ENV PIPENV_BIN="$TOOLS/pipenv/bin"

ENV PATH="$PYENV_BIN:$PIPENV_BIN:$TOOLS_BIN:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin::"

COPY py.sh python.sh Dockerfile .
RUN bash ./py.sh tools-unix

RUN bash ./py.sh global-virtual python
RUN pyenv global python

RUN rm *.sh rm -r $TMPDIR/*
