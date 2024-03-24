FROM alpine:3.19.1

LABEL docker-version = "2"
LABEL python-python = "3.12"
LABEL timestamp = "Sun"

RUN apk update && apk --no-cache add git gcc autoconf automake libtool openssl-dev bash build-base sqlite-dev pkgconf linux-headers ca-certificates bzip2-dev

RUN test -d /home/tmp || mkdir -p /home/tmp
WORKDIR /home/

ENV PYENV_ROOT="/home/.pyenv/"
ENV TMPDIR=/home/tmp
ENV SHELL=/bin/bash
ENV HOME=/home/
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims/:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin::"

COPY py.sh python.sh install-module-tools.sh .
RUN bash ./py.sh tools-unix
RUN bash ./py.sh global-virtual python

RUN bash install-module-tools.sh

RUN rm *.sh rm -r /home/tmp/*
