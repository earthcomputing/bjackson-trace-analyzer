#!/bin/csh -fx

set tag = "triangle-"
set epoch = 1530634503352636

set wdir = "/tmp/${tag}${epoch}/"
set work = "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data"
set archive = "${work}/${tag}${epoch}"

mkdir -p ${wdir}

analyze-queue.pl -wdir=${wdir} -topic=CellAgent > ${wdir}raw-analysis.txt

set rc = $status
if ($rc != 0) then
    echo 'STATUS: ' ${status}
    exit ${status}
endif

cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

set files = ( \
    complex.gv \
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
