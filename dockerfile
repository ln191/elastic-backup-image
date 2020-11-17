FROM alpine

LABEL version="1.0" type="elastic-backup-retore"

RUN apk update
RUN apk upgrade
RUN apk add py3-pip
RUN apk add gnupg
RUN apk add jq
RUN apk add curl
RUN rm -rf /var/cache/apk/*
RUN pip install pip wheel setuptools
RUN pip install elasticsearch-curator

COPY backup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/backup.sh

RUN addgroup -S backup && adduser -S backup -G backup

USER backup

CMD backup.sh