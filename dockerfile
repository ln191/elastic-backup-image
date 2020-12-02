FROM alpine

LABEL version="2.0" type="elastic-backup-retore"

# change to single line
RUN apk update && apk upgrade
RUN apk add py3-pip gnupg jq curl bash && rm -rf /var/cache/apk/*
RUN pip3 install pip wheel setuptools && pip3 install boto3==1.15.12 botocore==1.18.12 && pip3 install elasticsearch-curator==5.8.1 

COPY backup.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/backup.sh

RUN addgroup -S backup && adduser -S backup -G backup

USER backup

CMD backup.sh