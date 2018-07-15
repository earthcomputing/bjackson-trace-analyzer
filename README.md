# bjackson-trace-analyzer
example of trace output stream analysis

## How it works:

The heart of this tool is analyze.pl, which reads in a sequence of values in JSON text and holds them in an internal map (hashtable).
Keys of the map are constructing using trace header values augmented with a "stream position value" that is used to disambiguate when keys turn out to NOT be unique (technically an error, but tolerated).
The keys only create a "partial order" in that records may not be strictly sequential (causually related) as they are a consolidation of multiple, independent observers/emitters.

After reading in all that data, multiple passes of analysis are done over the date by a 'modeller' which attempts to re-build an independent, parallel imitation of the state(s) of the ECCF simulation based upon the changes impled by the event data.

Processing of the data is tolerant of excess "carried data" in the JSON objects and additional knowledge is synthesized utilizing a GEV of the emulated datacenter.

Ultimately, the processing completes with the generation of a number of 'report' output files.
Most are plain text.
Some are graphs in the DOT language that can be visualized using graphviz or other related tools (.gv).
There is also a spreadsheet (.csv) that can be loaded into Numbers or Excel.
A number of the reports include a 'nickname' which is the last few hex digits (5 or 8) of the SHA1 hash of the (canonicalized) value.

## What it produces :

At this time the reports are:

    complex.gv - the datacenter wiring diagram (blueprint) overlaid with edges indicating which "ground plane" spanning trees utilize edges, colored by "bias direction".

    forest.gv - the set of "ground plane" spanning trees (traph links) and stacked "application trees".

    events.csv - trace of message traffic through the network, compacted such that independent operations appear together.
    The packing heuristic models queues (mostly Forwarding Engine) associated with the wiring.
    Note that this model allows the pair of unidirectional channels of a edge in the network's graph to hold (contain) messages even while either end is pushing or popping a message onto transmit and receive queues.
    Uses "Alan Notation".

    routing-table.txt - a dump of the final state of each cell's routing table entries

    msg-dump.txt - a digest of all observed Message values
    guid-table.txt - a simple table of all GUID values
    gvm-table.txt - a simple table of all GVM equation values
    manifest-table.txt - a simple table of all Manifest values

    raw-analysis.txt - captured 'stdout' of the script ; densely organized into one line per emitter

    threaded-analysis.txt - post-processed output that rearranges (sorts) the raw output using a heuristic that groups emitters (by their first action) and expands each into a block of lines

    schema-use.txt - a machine-coded breakdown of the defacto-schema of the input JSON file meta-structure which may for the basis of automatic detection of incompatible format changes (ref: json-schema.pl)
    schema-data.txt - stats and info about JSON meta-structure (obsolete)


## How to build and start the Docker container image:

    docker build -t bjackson-analyzer .

    docker run --interactive --tty --rm --name analyzer bjackson-analyzer

Note: I picked the container (instance) name: 'analyzer' here at random.
Instructions below include this value - you can change it to your heart's content (you're on your own to know when the name is being used ;)

## Uploading Trace Data files:

    docker cp sample-data/multicell-trace-${tag}${epoch}.json.gz analyzer:/root/sample-data/

    docker cp "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data/multicell-trace-triangle-1530634503352636.json.gz" analyzer:/root/sample-data/

## Offloading results:

    docker cp analyzer:/tmp/${tag}${epoch}/events.csv /tmp/

## How to drive it:

Unlike conventional usage of Docker containers, this setup DOES NOT automatically run the application.
Instead the container provides a stable working playground which drops you into /bin/sh with everything set up for you to choose what you'd like to do.
You need to supply input data and configure a helper script to indicate which data to input and where to deposit result output(s).

In order to facilitate processing of different 'configurations' for and independent runs of the simulator along with changes to the simulator (i.e. data formats) or to analysis processing, there are a pair of "helper scripts" which have internal shell variables that can be modified (hand edited) to indicate the dataset to be processed.

    variance.sh - wraps the execution of analyze.pl so that all resultant report files are generated into independently named subdirectories of /tmp/.
    At the conclusion of processing the generated results are "regression tested" (i.e. diff'ed) against an archive direction (presumed to be the last good run), if any.

    pickle.sh - a duplicate copy of variance.sh which rather than comparing the results, archives them (does a fresh analysis to ensure stale results are NOT archived).

Note: everything lives in /usr/local/bin/ - alter the Dockerfile if you prefer something different.

## Managing Trace Data and Results

Input data uses a file naming pattern : sample-data/multicell-trace-${tag}${epoch}.json.gz.
The idea is that 'tag' reflects something useful to you - possibly the blueprint configuration and/or simulation run conditions.
The 'epoch' value really should be the value taken from the very first trace record (MAIN/schema).

Here's one example:

sample-data/multicell-trace-triangle-1530634503352636.json.gz

The helper (csh) script: variance.sh has two variables you can set (modify via text editor):

    set tag = "triangle-"
    set epoch = 1530634503352636

Configuring these should be sufficient for you to drive the whole process.

CAVEAT: I run on my laptop which has direct access to dropbox where I keep the archives.
When run in a Docker container, dropbox is not available (maybe we'll figure out that eventually).

This means at the end of processing you'll get dropped into a series of interactive colorized 'diff' runs which won't having any reference data (whole content will differ).
This is a handy way to inspect all the new output - rather than having difference from a reference run.

--

## Obsolete Notes, etc.

usage: analyze.pl sample-data/* | post-process.sh 

--

Here's a more sophisticated scenario - compare 2 runs :

analyze.pl tmp/multicell-trace.json | post-process.sh > /tmp/z1.txt
analyze.pl tmp/multicell-trace1.json | post-process.sh > /tmp/z2.txt
p4-merge.sh /tmp/z[12].txt

