#!/bin/csh -fx
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------

set tag = "distributed-"
set epoch = 1533085651118541

set tag = "triangle-"
set epoch = 1530634503352636

set datafile = "multicell-trace-${tag}${epoch}.json.gz"

set wdir = "/tmp/${tag}${epoch}/"
set work = "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data"
set archive = "${work}/${tag}${epoch}"

mkdir -p ${wdir}

sha1sum.sh sample-data/${datafile} "${work}/${datafile}"
# cp sample-data/${datafile} "$work/${datafile}"

json-schema.pl sample-data/${datafile} > ${wdir}schema-use.txt
analyze.pl -wdir=${wdir} sample-data/${datafile} > ${wdir}raw-analysis.txt

set rc = $status
if ($rc != 0) then
    echo 'STATUS: ' ${status}
    exit ${status}
endif

cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

set files = ( \
    complex.gv \
    debug.txt \
    events.csv \
    forest.gv \
    guid-table.txt \
    gvm-table.txt \
    manifest-table.txt \
    msg-dump.txt \
    raw-analysis.txt \
    routing-table.txt \
    schema-data.txt \
    schema-use.txt \
    threaded-analysis.txt \
)

ls -latrh "${archive}"

foreach one ( ${files} )
    diff -N -w "${archive}/${one}" ${wdir}${one} | cdiff
    # cp ${wdir}${one} "${archive}/"
end

exit 0
