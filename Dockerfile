FROM perl

RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y csh colordiff less vim && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get clean

RUN cpanm JSON Data::GUID Data::UUID Data::Dumper Digest::SHA

## .gitignore
## README.md
## SCHEMA.md
COPY analyze.pl /usr/local/bin/
COPY json-schema.pl /usr/local/bin/
COPY pickle.sh /usr/local/bin/
COPY post-process.sh /usr/local/bin/
COPY pretty-json-lines.pl /usr/local/bin/
COPY variance.sh /usr/local/bin/
COPY sha1sum.sh /usr/local/bin/
# COPY sample-data/multicell-trace-triangle-1530634503352636.json.gz sample-data/

CMD /bin/sh
