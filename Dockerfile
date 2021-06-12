#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------
FROM perl

ENV SCALA_VERSION 2.12
ENV KAFKA_VERSION 1.1.0

ENV SKBUILD "${SCALA_VERSION}"-"${KAFKA_VERSION}"
ENV KAFKA_HOME /opt/kafka_"${SKBUILD}"
ENV PATH="${PATH}:${KAFKA_HOME}/bin:."

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y openjdk-8-jre csh colordiff less vim && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get clean && \
    wget -q https://www.apache.org/dist/kafka/"${KAFKA_VERSION}"/kafka_"${SKBUILD}".tgz -O /tmp/kafka_"${SKBUILD}".tgz && \
    tar xfz /tmp/kafka_"${SKBUILD}".tgz -C /opt && \
    rm /tmp/kafka_"${SKBUILD}".tgz

RUN cpanm JSON Data::GUID Data::UUID Data::Dumper Digest::SHA
RUN cpanm --force Test::Block
RUN cpanm Kafka

## intermediate image : bjackson/perl-kafka
# FROM bjackson/perl-kafka

RUN mkdir -p sample-data

# git ls-files
## .gitignore
## Dockerfile
## README.md
## SCHEMA.md
## launch-kafka.sh

COPY Fabric /root/Fabric

COPY analyze-queue.pl /usr/local/bin/
COPY analyze.pl /usr/local/bin/
COPY from-queue.sh /usr/local/bin/
COPY json-schema.pl /usr/local/bin/
COPY pickle.sh /usr/local/bin/
COPY post-process.sh /usr/local/bin/
COPY pretty-json-lines.pl /usr/local/bin/
COPY quick.sh /usr/local/bin/
COPY sha1sum.sh /usr/local/bin/
COPY upload.pl /usr/local/bin/
COPY variance.sh /usr/local/bin/
COPY verify-kafka.sh /usr/local/bin/

# COPY sample-data/multicell-trace-triangle-1530634503352636.json.gz sample-data/

CMD /bin/sh
