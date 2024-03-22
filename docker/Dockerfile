FROM alpine:latest

LABEL version = "0.1.0"
LABEL python = "3.12"

RUN apk update && apk add git python3 apk add gcc autoconf automake libtool libssl1.1 libssl1.1-dev

RUN test -d /home || mkdir /home
WORKDIR /home
ENV HOME=/home/

COPY py.sh python.sh
RUN chmod u+x ./py.sh && ./py.sh tools-unix && ./py.sh global-virtual "python"
