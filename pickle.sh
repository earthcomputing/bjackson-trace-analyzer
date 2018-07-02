#!/bin/csh -fx

# git commit -a
# git push

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

set datafile = "multicell-trace-${tag}${epoch}.json"

set wdir = "/tmp/${tag}${epoch}/"
set work = "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data"

mkdir -p ${wdir}

sha1sum.sh sample-data/${datafile} "${work}/${datafile}"
# cp sample-data/${datafile} "$work/${datafile}"

analyze.pl -ALAN -wdir=${wdir} sample-data/${datafile} > ${wdir}raw-analysis.txt
cat ${wdir}raw-analysis.txt | post-process.sh > ${wdir}threaded-analysis.txt

set files = ( \
    raw-analysis.txt \
    threaded-analysis.txt \
    complex.dot \
    routing-table.txt \
    msg-dump.txt \
    events.csv \
    schema-data.txt \
    guid-table.txt \
    forest.txt \
)

ls -latrh "${work}/${tag}${epoch}"

mkdir -p "${work}/${tag}${epoch}"
foreach one ( ${files} )
    # diff -N -w "${work}/${tag}${epoch}/${one}" ${wdir}${one} | cdiff
    cp ${wdir}${one} "${work}/${tag}${epoch}/"
end

ls -latrh "${work}"

exit 0
