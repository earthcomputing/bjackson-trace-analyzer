#!/bin/csh -fx

set tag = ""
set epoch = 1529944245

# cmodel-1530320950
set tag = "cmodel-"
set epoch = 1530227070
set epoch = 1530320950

# filtered-1530400069
set tag = "filtered-"
set epoch = 1530400069

# onemsg-1530400069
set tag = "onemsg-"
set epoch = 1530400069

# triangle-1530400069
set tag = "triangle-"
set epoch = 1530400069

# cmodel-1530320950
set tag = "cmodel-"
set epoch = 1530227070
set epoch = 1530320950

set datafile = "multicell-trace-${tag}${epoch}.json"

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
