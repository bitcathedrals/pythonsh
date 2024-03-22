FROM alpine:3.19.1

LABEL docker-version = "1"
LABEL python-python = "3.12"

RUN apk update && apk add git python3 gcc autoconf automake libtool openssl openssl-dev bash build-base

RUN test -d /home || mkdir /home
WORKDIR /home/

ENV SHELL=/bin/bash
ENV HOME=/home/
ENV PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/home/.pyenv/bin::"
ENV PYENV_ROOT="/home/.pyenv/"

COPY py.sh python.sh .
RUN chmod u+x ./py.sh && ./py.sh tools-unix

RUN pyenv init - >exec.sh && echo "./py.sh global-virtual python" >>exec.sh bash exec.sh
