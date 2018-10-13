#!/bin/csh -fx

set advert_host = 'localhost'
set advert_host = '192.168.0.71'

if ( $#argv > 0 ) then
    set advert_host = $1:q
endif

# multicell-trace-triangle-1536648431697765.json.gz
set tag = "triangle-"
set epoch = 1539405234737631

set datafile = "multicell-trace-${tag}${epoch}.json.gz"

set wdir = "/tmp/${tag}${epoch}/"

mkdir -p ${wdir}

# json-schema.pl sample-data/${datafile} > ${wdir}schema-use.txt
analyze-queue.pl -wdir=${wdir} -server=${advert_host} -topic=CellAgent > ${wdir}raw-analysis.txt

set rc = $status
if ($rc != 0) then
    echo 'STATUS: ' ${status}
    exit ${status}
endif

cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

exit 0
