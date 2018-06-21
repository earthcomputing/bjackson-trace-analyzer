# bjackson-trace-analyzer
simplistic example of trace output stream analysis

usage: analyze.pl sample-data/* | post-process.sh 

--

Here's a more sophisticated scenario - compare 2 runs :

analyze.pl tmp/multicell-trace.json | post-process.sh > /tmp/z1.txt
analyze.pl tmp/multicell-trace1.json | post-process.sh > /tmp/z2.txt
p4-merge.sh /tmp/z[12].txt

