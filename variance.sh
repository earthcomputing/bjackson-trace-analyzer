#!/bin/csh -fx

# sample-data/multicell-trace-triangle-1530634503352636.json.gz
# sample-data/multicell-trace-square-1530635880772557.json.gz
# sample-data/multicell-trace-cmodel-1530635964794727.json.gz

set tag = "cmodel-"
set epoch = 1530635964794727

set tag = "distributed-"
set epoch = 1530937085270224

set datafile = "multicell-trace-${tag}${epoch}.json.gz"

set wdir = "/tmp/${tag}${epoch}/"
set work = "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data"
set archive = "${work}/${tag}${epoch}"

mkdir -p ${wdir}

sha1sum.sh sample-data/${datafile} "${work}/${datafile}"
# cp sample-data/${datafile} "$work/${datafile}"

analyze.pl -wdir=${wdir} sample-data/${datafile} > ${wdir}raw-analysis.txt

set rc = $status
if ($rc != 0) then
    echo 'STATUS: ' ${status}
    exit ${status}
endif

cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

set files = ( \
    raw-analysis.txt \
    threaded-analysis.txt \
    complex.gv \
    routing-table.txt \
    msg-dump.txt \
    events.csv \
    schema-data.txt \
    guid-table.txt \
    forest.gv \
)

ls -latrh "${archive}"

foreach one ( ${files} )
    diff -N -w "${archive}/${one}" ${wdir}${one} | cdiff
    # cp ${wdir}${one} "${archive}/"
end

exit 0
