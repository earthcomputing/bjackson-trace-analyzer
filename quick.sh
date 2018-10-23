#!/bin/csh -fx

# multicell-trace-triangle-1536648431697765.json.gz
set tag = "triangle-"
set epoch = 1539644788248291

set datafile = "multicell-trace-${tag}${epoch}.json.gz"

set wdir = "/tmp/${tag}${epoch}/"

mkdir -p ${wdir}

# json-schema.pl sample-data/${datafile} > ${wdir}schema-use.txt
analyze.pl -wdir=${wdir} sample-data/${datafile} > ${wdir}raw-analysis.txt

set rc = $status
if ($rc != 0) then
    echo 'STATUS: ' ${status}
    exit ${status}
endif

cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

exit 0
