#!/bin/csh -f
# https://davidfrancoeur.com/post/kafka-on-docker-for-mac/
# https://www.apache.org/dist/kafka/1.1.0/kafka_2.12-1.1.0.tgz

set advert_host = 'localhost'
set advert_host = '192.168.0.71'

if ( $#argv > 0 ) then
    set advert_host = $1:q
else
    echo "usage: $0 : "'${advert_host}'
    exit 1
endif

docker run -d --name pause \
    -p 9092:9092 \
    -p 2181:2181 \
    gcr.io/google_containers/pause-amd64:3.0

docker run -d --name cp-zk \
    --net=container:pause \
    --ipc=container:pause \
    --pid=container:pause \
    -e "ZOOKEEPER_CLIENT_PORT=2181" \
    confluentinc/cp-zookeeper:4.1.1

docker run -d --name cp-kafka \
    --net=container:pause \
    --ipc=container:pause \
    --pid=container:pause \
    -e "KAFKA_ZOOKEEPER_CONNECT=localhost:2181" \
    -e "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://${advert_host}:9092" \
    -e "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1" \
    confluentinc/cp-kafka:4.1.1

