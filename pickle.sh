#!/bin/csh -fx

# sample-data/multicell-trace-triangle-1530634503352636.json.gz
# sample-data/multicell-trace-square-1530635880772557.json.gz
# sample-data/multicell-trace-cmodel-1530635964794727.json.gz
# sample-data/multicell-trace-distributed-1530937085270224.json.gz
## sample-data/multicell-trace-decentralized-1530858754526305.json.gz

set tag = "cmodel-"
set epoch = 1530635964794727

set tag = "distributed-"
set epoch = 1530937085270224

set tag = "triangle-"
set epoch = 1530634503352636

# git commit -a
# git push

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
    threaded-analysis.txt \
)

ls -latrh "${archive}"

mkdir -p "${archive}"
foreach one ( ${files} )
    # diff -N -w "${archive}/${one}" ${wdir}${one} | cdiff
    cp ${wdir}${one} "${archive}/"
end

ls -latrh "${archive}"

exit 0
