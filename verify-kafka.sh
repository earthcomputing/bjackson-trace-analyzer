#!/bin/csh -f
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

set advert_host = 'localhost'
set advert_host = '192.168.0.71'

if ( $#argv > 0 ) then
    set advert_host = $1:q
endif

kafka-topics.sh --zookeeper ${advert_host}:2181 --create --topic test --partitions 1 --replication-factor 1
seq 1 45 | kafka-console-producer.sh --broker-list ${advert_host}:9092 --topic test
kafka-console-consumer.sh --bootstrap-server ${advert_host}:9092 --topic test --from-beginning

