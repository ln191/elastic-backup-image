FROM docker.elastic.co/elasticsearch/elasticsearch:7.9.2
COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
RUN mkdir /nfs
RUN chmod -R 777 /nfs