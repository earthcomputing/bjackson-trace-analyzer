# bjackson-trace-analyzer
example of trace output stream analysis

## How it works:

The heart of this tool is analyze.pl, which reads in a sequence of values in JSON text and holds them in an internal map (hashtable).
Keys of the map are constructing using trace header values augmented with a "stream position value" that is used to disambiguate when keys turn out to NOT be unique (technically an error, but tolerated).
The keys only create a "partial order" in that records may not be strictly sequential (causually related) as they are a consolidation of multiple, independent observers/emitters.

After reading in all that data, multiple passes of analysis are done over the data by a 'modeller' which attempts to re-build an independent, parallel imitation of the state(s) of the ECCF simulation based upon the changes impled by the event data.

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


## How to build and start the Docker container image (macosx terminal):

    docker build -t bjackson-analyzer .

    docker run --interactive --tty --rm --name analyzer bjackson-analyzer

Note: I picked the container (instance) name: 'analyzer' here at random.
Instructions below include this value - you can change it to your heart's content (you're on your own to know when the name is being used ;)

## Uploading Trace Data files (macosx terminal):

    docker cp sample-data/multicell-trace-${tag}${epoch}.json.gz analyzer:/root/sample-data/

    docker cp "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data/multicell-trace-triangle-1530634503352636.json.gz" analyzer:/root/sample-data/

## Offloading results (macosx terminal):

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

## Managing Trace Data and Results:

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

## Server Naming(both macosx and analyzer container);:

The one niggly little detail that's needed is the ip-addr of the host:

    ifconfig -a | grep -w inet
    # your ip-addr here:
    export advert_host='192.168.0.71'

The value above can be used either in your normal laptop shell,
or within containers to access the 'outside' network/host.

CAVEAT: Be careful about moving among DHCP hosts or networks.  Docker doesn't intercept host address changes, so the whole environment may need to be torn down and built up again.  This may so be required even if the bindings "wink out" and are then restored to their previous value(s).  If it happens to work in that case, thank your lucky stars.

TL;DR : We can't use 'localhost' because within Docker containers name translation is done locally AND also the ipaddr 127.0.0.1 is intercepted to be the container itself.

## Integrating with Kafka (macosx terminal):

With thanks to David Francoeur, it's possible to use existing Docker images built by confluent to run a completely off-the-shelf version of Kafka.

    launch-kafka.sh ${advert_host}

Complete details on how configuration works (TL;DR):

    https://davidfrancoeur.com/post/kafka-on-docker-for-mac/
    https://www.ianlewis.org/en/almighty-pause-container
    https://www.ianlewis.org/en/what-are-kubernetes-pods-anyway
    https://kubernetes.io/docs/concepts/workloads/pods/pod/

## Confirming Kafka is Operational (analyzer container):

Here's a generic test that can be used to confirm everything is properly operating.
This uses utilities that are packaged with the Kafka distribution.
To use outside of a docker contain, download the distribution and put the 'bin' directory on the path.

Within the analyzer container, it's packaged up into the helper script : verify-kafka.sh,
which does this (passing ${advert_host} as a CLI parameter):

    kafka-topics.sh --zookeeper ${advert_host}:2181 --create --topic test --partitions 1 --replication-factor 1
    seq 1 45 | kafka-console-producer.sh --broker-list ${advert_host}:9092 --topic test
    kafka-console-consumer.sh --bootstrap-server ${advert_host}:9092 --topic test --from-beginning

Use ^C to exit the consumer.

## Interim perl tool (upload.pl):

The two parts (upload/analyze-queue) emulate what the Rust simulation and the Datacenter Control UI need to do.

Here's a work-in-progress utility that will upload a trace data file into a topic.
First upload some data into the analyzer container (macosx terminal):

    docker cp "${HOME}/Dropbox (Earth Computing)/Earth Computing Team Folder/Team/Bill/trace-data/multicell-trace-triangle-1530634503352636.json.gz" analyzer:/root/sample-data/

Then the real work (analyzer container);

    export advert_host='192.168.0.71'
    verify-kafka.sh ${advert_host}

And then this to process the data
(for now, TOPIC is hardwired to the 'repo' value from the first trace record, i.e. MAIN/schema):

    export TOPIC=CellAgent
    kafka-topics.sh --zookeeper ${advert_host}:2181 --create --topic ${TOPIC} --partitions 1 --replication-factor 1
    upload.pl sample-data/multicell-trace-triangle-1530634503352636.json.gz

---

When things goes sideways these flags may be useful:

    PERL_KAFKA_DEBUG=1
    PERL_KAFKA_DEBUG=IO:1
    PERL_KAFKA_DEBUG=Connection:1

## Process Stream Data (analyzer container):

NOTE: A fork of analyze.pl (analyze-queue.pl) supports reading trace data from Kafka.
The stream reader is operated via the from-queue.sh helper script.

    from-queue.sh ${advert_host}

As the fork of analyze.pl retains all the file processing logic it assumes that all data is uploaded,
and it's not really "live streaming".  The assumption is that the simulation has completed and what's modelled
is everything from start-of-time to current-end.

TBD: Eenhancing things to understand 'bookmark' records from a meta-topic would allow for "animated processing" in chunks.

## to inspect that uploaded data, use (analyzer container):

    kafka-console-consumer.sh --bootstrap-server ${advert_host}:9092 --topic ${TOPIC} --from-beginning

## Cleaning up stale data (analyzer container):

Ideally, there could/should be a meta-topic to hold 'bookmarks' for interesting 'offset' values which consumers would use to control processing of the data (queue).
In lieu of that there's two options : kill everything (i.e. restart Moby, etc.), or delete/create the topic:

    kafka-topics.sh --zookeeper ${advert_host}:2181 --delete --topic ${TOPIC}
    kafka-topics.sh --zookeeper ${advert_host}:2181 --create --topic ${TOPIC} --partitions 1 --replication-factor 1

CAVEAT: the ability to delete topics has to be configured (/etc/kafka/server.properties):

    delete.topic.enable=true

## Alan's Master Orchestrator:

The Master Orchestrator (TMO), which lives outside the ECCF (i.e. on the Internet) makes requests of the CellAgent whose "border port" is connected to the Internet (and which has properly authenticated and authorized the TMO).
In the "toy scenario" performed by the simulation, TMO requests the creation of 2 "stacked trees" using a pair of related GVM equations.
The effect is that one cell is selected to be the 'client', and all other cells in the datacenter are to be come "hello world servers" (or if you prefer owners of indpendent holders of parts of a sharded K/V store object space).

Once the "hello client" and "hello world servers" are 'launched', the client sends a message (request, leafward) to the set of servers, which then each send a message back (response, rootward) to the client.

The TMO's 'deploy' operation results in the creation of a GEV cluster of "service instances" - i.e. the cluster(s) table.
The table captures the set of clusters (i.e. class information), and for each cluster the set of running instances (i.e. instance information).

Once the 2 hello world clusters are 'ready', application traffic flows with the result being a set of "hello there (from instance x)" data being delivered and (printf) reported by the client.

Here's the snippets of the trace data that's involved which needs to be transformed into the cluster table content and the client's console output:

    grep AgentDeploy /tmp/triangle-1530634503352636/threaded-analysis.txt | grep StackTreeD | grep listen_cm_loop
    grep MasterDeploy /tmp/triangle-1530634503352636/threaded-analysis.txt | grep StackTreeD | grep listen_cm_loop
    grep Manifest /tmp/triangle-1530634503352636/threaded-analysis.txt | grep process_manifest_msg
    grep Application /tmp/triangle-1530634503352636/threaded-analysis.txt | grep tcp_application

    # grep AgentDeploy /tmp/triangle-1530634503352636/threaded-analysis.txt | grep StackTreeD | grep listen_cm_loop

        listen_cm_loop C:0 StackTreeD Tree:C:2+NocAgentDeploy ;
        listen_cm_loop C:1 StackTreeD Tree:C:2+NocAgentDeploy ;

    # grep MasterDeploy /tmp/triangle-1530634503352636/threaded-analysis.txt | grep StackTreeD | grep listen_cm_loop

    # grep Manifest /tmp/triangle-1530634503352636/threaded-analysis.txt | grep process_manifest_msg

        process_manifest_msg C:0 Tree:C:2+NocAgentDeploy v2 83060      Leafward        Manifest        Sender:C:2+BorderPort+2 gvm=    manifest=ccced ;
        process_manifest_msg C:1 Tree:C:2+NocAgentDeploy v2 83060      Leafward        Manifest        Sender:C:2+BorderPort+2 gvm=    manifest=ccced ;
        process_manifest_msg C:2 Tree:C:2+NocMasterDeploy v0 b1c99     Leafward        Manifest        Sender:C:2+BorderPort+2 gvm=    manifest=98ef3 ;

{
    "nick": "ccced",
    "id": "NocAgent",
    "deployment_tree": { "name": "NocAgentDeploy" },
    "cell_config": "Large",
    "trees": [ { "id": "NocAgent", "parent_list": [ 0 ] } ],
    "vms": [ {
        "id": "vm1",
        "image": "Ubuntu",
        "required_config": "Large",
        "allowed_trees": [ { "name": "NocMasterAgent" }, { "name": "NocAgentMaster" } ],
        "containers": [ {
            "id": "NocAgent",
            "image": "NocAgent",
            "params": []
        } ],
    } ]
}

{
    "nick": "98ef3",
    "id": "NocMaster",
    "deployment_tree": { "name": "NocMasterDeploy" },
    "cell_config": "Large",
    "trees": [ { "id": "NocMaster", "parent_list": [ 0 ] } ],
    "vms": [ {
        "id": "vm1",
        "image": "Ubuntu",
        "required_config": "Large",
        "allowed_trees": [ { "name": "NocMasterAgent" }, { "name": "NocAgentMaster" } ],
        "containers": [ {
            "id": "NocMaster",
            "image": "NocMaster",
            "params": []
        } ],
    } ]
}

# grep Application /tmp/triangle-1530634503352636/threaded-analysis.txt | grep tcp_application

    tcp_application C:0 Tree:C:2+NocAgentMaster 5d3f0      Rootward        Application     Sender:C:0+VM:C:0+vm1   gvm=    manifest= ;
    tcp_application C:1 Tree:C:2+NocAgentMaster b49af      Rootward        Application     Sender:C:1+VM:C:1+vm1   gvm=    manifest= ;
    tcp_application C:2 Tree:C:2+NocMasterAgent a83b1      Leafward        Application     Sender:C:2+VM:C:2+vm1   gvm=    manifest= ;

    a83b1 {"body":[72,101,108,108,111,32,70,114,111,109,32,77,97,115,116,101,114], ...}
        Hello From Master
    5d3f0 {"body":[82,101,112,108,121,32,102,114,111,109,32,67,111,110,116,97,105,110,101,114,58,86,77,58,67,58,48,43,118,109,49,43,50], ...}
        Reply from Container:VM:C:0+vm1+2
    b49af {"body":[82,101,112,108,121,32,102,114,111,109,32,67,111,110,116,97,105,110,101,114,58,86,77,58,67,58,49,43,118,109,49,43,50], ...}
        Reply from Container:VM:C:1+vm1+2

## Obsolete Notes, etc.

    setenv advert_host 192.168.0.71
    docker cp upload.pl analyzer:/root/

    usage: analyze.pl sample-data/* | post-process.sh 

    --

    Here's a more sophisticated scenario - compare 2 runs :

    analyze.pl tmp/multicell-trace.json | post-process.sh > /tmp/z1.txt
    analyze.pl tmp/multicell-trace1.json | post-process.sh > /tmp/z2.txt
    p4-merge.sh /tmp/z[12].txt

