#!/usr/local/bin/perl -w
#!/usr/bin/perl -w
# analyze xx.json
## A microservice is not a 'subroutine' !!
# python -mjson.tool

use 5.010;
use strict;
use warnings;

use lib '/Users/bjackson/perl5/lib/perl5';
use lib '.';

use JSON qw(decode_json encode_json);
use Data::Dumper;
use Data::GUID;

use Fabric::Util qw(giveup set_epoch);
use Fabric::DispatchTable qw(meth_lookup extend_table);
use Fabric::Methods qw(register_methods);
use Fabric::TraceData qw(dump_guids grab_name hint4uuid nametype port_index portdesc xlate_uuid silly %msg_table %gvm_table %manifest_table);
use Fabric::Model qw(dump_complex dump_routing_tables dump_forest msg_sheet dump_frames);
use Fabric::Schema qw(walk_structure dump_schema note_verb);

# --

my $endl = "\n";
my $dquot = '"';
my $blank = ' ';

# --

if ( $#ARGV < 0 ) {
    print('usage: analyze [-NOT_ALAN] [-filter=C:2] [-wdir=/tmp/] [-server=${advert_host}] [-epoch=end-ts] xx.json ...', $endl);
    exit -1
}

my $server = $ENV{'advert_host'}; # '192.168.0.71'; # localhost:9092

# --

my $frames_file = 'frames.json';
my $dbg_file = 'debug.txt';
my $dotfile = 'complex.gv';
my $schemafile = 'schema-data.txt';
my $routingfile = 'routing-table.txt';
my $msgfile = 'msg-dump.txt';
my $csvfile = 'events.csv';
my $guidfile = 'guid-table.txt';
my $forestfile = 'forest.gv';
my $gvmfile = 'gvm-table.txt';
my $manifestfile = 'manifest-table.txt';

# --

my $debug;
my $code_filter;
my $last_epoch;
my $result_dir = '/tmp/'; # can be blank!?


# --

foreach my $fname (@ARGV) {
    if ($fname eq '-NOT_ALAN') { $Fabric::Model::NOT_ALAN = 1; next; }
    if ($fname =~ /-wdir=/) { my ($a, $b) = split('=', $fname); $result_dir = $b; $result_dir = '' unless $result_dir; next; }
    if ($fname =~ /-filter=/) { my ($a, $b) = split('=', $fname); $code_filter = $b; next; }
    if ($fname =~ /-server=/) { my ($a, $b) = split('=', $fname); $server = $b; next; }
    if ($fname =~ /-epoch=/) { my ($a, $b) = split('=', $fname); $last_epoch = $b; next; }
    print($endl, $fname, $endl);
    # FIXME : re-open ?
    open(DBGOUT, '>'.$result_dir.$dbg_file) or die $result_dir.$dbg_file.': '.$!;
    my $href = process_file($fname);
    do_analyze($href);
}

# ISSUE : one file/report for entire list of inputs

dump_schema($result_dir.$schemafile);
dump_trace_tables();
dump_model_data();

close(DBGOUT);
exit 0;

# --

sub dump_model_data {
    dump_complex($result_dir.$dotfile);
    dump_routing_tables($result_dir.$routingfile);
    dump_forest($result_dir.$forestfile);
    dump_frames($result_dir.$frames_file);
    msg_sheet($result_dir.$csvfile);
}

# --

sub dump_msgs {
    my ($path, $href) = @_;
    open(FD, '>'.$path) or die $path.': '.$!;
    foreach my $key (sort keys %{$href}) {
        my $hint = substr($href->{$key}, -5);
        print FD (join(' ', $hint, $key), $endl);
    }

    close(FD);
}

sub dump_trace_tables {
    dump_msgs($result_dir.$msgfile, silly());
    dump_msgs($result_dir.$gvmfile, \%gvm_table);
    dump_msgs($result_dir.$manifestfile, \%manifest_table);
    dump_guids($result_dir.$guidfile);
}

# --

sub process_file {
    my ($fname) = @_;

    my $topic;
    if ($fname =~ /-topic=/) { my ($a, $b) = split('=', $fname); $topic = $b; }
    # my @records = ($topic) ? kafka_inhale($topic) : inhale($fname);
    my @records = inhale($fname);

    my $lineno = 0;
    my %data;
    foreach my $body (@records) {
        $lineno++;
        my $json = decode_json($body);
        walk_structure('', $json);
        my $key = construct_key($json->{'header'}, $lineno);
        $data{$key} = $json;
    }
    return \%data;
}

#    "header": {
#        "repo": "CellAgent",
#        "module": "main.rs",
#        "function": "MAIN",
#        "format": "trace_schema",
#        "trace_type": "Trace"
#        "thread_id": 0,
#        "event_id": [ 1 ],
#        "epoch": 1529944245,
#    }
#    "body": { "schema_version": "0.1" },

sub do_analyze {
    my ($href) = @_;

    register_methods();

    my $last_thread = '-1';

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};
        my $header = $json->{'header'};
        my $body = $json->{'body'};

        # REQUIRED/SHOULD:
        my $repo = $header->{'repo'}; # software component
        my $module = $header->{'module'}; # source filename
            $module =~ s|src/||; # change to file macro
        my $function = $header->{'function'}; # code method
        my $format = $header->{'format'}; # arbitrary tag (think line number/unique emitter)
        my $kind = $header->{'trace_type'}; # importance (simple trace, extra detail [debug])
        my $epoch = $header->{'epoch'}; # human domain indicator uses for managing streaming data (think lifetime of data)
        # key contains "basic causal ordering" - thread_id/event_id (and stream position for ties)

        # animation filter
        if ($last_epoch) {
            next if $epoch > $last_epoch;
        }
        set_epoch($epoch);

        ## my $methkey = join('$$', $module, $function, $kind, $format);
        my $zz = join('$', $module, $function);
        note_verb($zz);

        ## combine all records into one line per thread
        # re-hack key for output
        my $xkey = $key;
        # $xkey =~ s/::[0-9]*$//; # remove just lineno
        $xkey =~ s/::.*$/::/; # only retain thread_id
        if ($xkey eq $last_thread) {
            $xkey = '';
        }
        else {
            print($endl);
            $last_thread = $xkey;
        }
        print(join(' ', $xkey, $function, ''));
        dispatch($key, $module, $function, $kind, $format, $json);
    }

    # dangling data:
    print($endl);
}

# --

sub dispatch {
    my ($key, $module, $function, $kind, $format, $json) = @_;
    my $methkey = join('$$', $module, $function, $kind, $format);
    # my $event_code = ec_fromkey($key);

    note_verb($methkey);

    my $body = $json->{'body'};
    my $header = $json->{'header'};

    my $m = meth_lookup($methkey); # $dispatch_table->{$methkey};
    unless (defined($m)) {
        print($endl);
        print STDERR (join(' ', $methkey), $endl);
        print STDERR Dumper $body;
        print STDERR ($endl);
        giveup('incompatible schema');
    }

    $m->($body, $key, $header);
}

# --

sub construct_key {
    my ($hdr, $lineno) = @_;
    my $thread_id = $hdr->{'thread_id'};
    my $event_id = $hdr->{'event_id'};
    my $line_tag = $hdr->{'_lineno'}; $lineno = $line_tag if $line_tag;
    $event_id = e_massage($event_id);
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
}

# incompatible interface change!!
sub e_massage {
    my ($event_id) = @_;
    return $event_id unless ref($event_id); # old : scalar / number

    my $vector = join('.', 'v', @{$event_id}); # new : seq of number (array)
    return $vector;
}

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_keys($$) {
    my ($left, $right) = @_;
    my ($l1, $l2, $l3) = split('::', $left);
    my ($r1, $r2, $r3) = split('::', $right);

    return $l1 - $r1 unless $l1 == $r1;
    if ($l2 =~ m/\./) {
        my $xx = order_numseq_basic($l2, $r2);
        return $xx unless $xx == 0;
    }
    else {
        return $l2 - $r2 unless $l2 == $r2;
    }

    # only need 3rd when duplicate:
    my $basic_key = join('::', $l1, $l2);
    print STDERR (join(' ', 'WARNING: duplicate key', $basic_key), $endl);

    return $l3 - $r3;
}

sub order_numseq_basic($$) {
    my ($left, $right) = @_;
    my @l = split('\.', $left);
    my @r = split('\.', $right);
    my $l_len = $#l;
    my $r_len = $#r;
    my $len_cmp = $l_len <=> $r_len;
    my $scan = ($len_cmp < 0) ? $l_len : $r_len; # pick shorter one
    # skip 'v' prefix
    for my $i ( 1 .. $scan ) {
        my $val_cmp = $l[$i] <=> $r[$i];
        return $val_cmp unless $val_cmp == 0;
    }
    return $len_cmp;
}

# --

my $kafka_notes = << '_eor_';

sub inhale_all_msgs {
    my ($consumer, $topic, $partition) = @_;
    my $offset = 0;
    my $messages = $consumer->fetch($topic, $partition, $offset, $DEFAULT_MAX_BYTES);
    return undef unless  $messages;

    my @bodies;
    foreach my $m (@$messages) {
        unless ($m->valid) {
            print STDERR (join(' ', 'ERROR:', $m->error), $endl);
            next;
        }

        ## $m->key; $m->offset; $m->next_offset;
        push(@bodies, $m->payload);
    }
    return @bodies;
}

sub kafka_inhale {
    my ($topic) = @_;
    my $partition = 0;

    my $connection;
    my $producer;
    my $consumer;

    my @bodies;
    try {
        $connection = Kafka::Connection->new(host => $server);
        $producer = Kafka::Producer->new(Connection => $connection);
        $consumer = Kafka::Consumer->new(Connection => $connection);

        @bodies = inhale_all_msgs($consumer, $topic, $partition);
    }
    catch {
        my $error = $_;
        if (blessed($error) && $error->isa('Kafka::Exception')) {
            warn 'Error: (', $error->code, ') ',  $error->message, "\n";
            exit;
        }
        else {
            die $error;
        }
    };

    undef $consumer;
    undef $producer;
    $connection->close;
    undef $connection;

    return @bodies;
}

_eor_

sub inhale {
    my ($path) = @_;
    my $gzip = $path =~ m/.gz$/;
    my $openspec = ($gzip) ?  'gunzip -c '.$path.'|' : '<'.$path;
    open(FD, $openspec) or die $path.': '.$!;
    my @body = <FD>;
    close(FD);
    return @body;
}

# --

my $notes = << '_eof_';

# --

dotest('1.1', '1.1');
dotest('1.1.1', '1.1.2');
dotest('1.1.2', '1.1.1');
dotest('1.1', '1.1.1');
dotest('1.1.1', '1.1');
exit 0;

sub dotest {
    my ($v1, $v2) = @_;
    my $xcmd = order_numseq_basic($v1, $v2);
    print(join(' ', $xcmd, $v1, $v2), $endl);
}

no if $] >= 5.018, warnings => "experimental::smartmatch";

sub order_numseq_smartmatch($$) {
    my ($left, $right) = @_;
    return $left ~~ $right;
}

# --

# this function allows for multi-line json entries
# UNUSED
sub snarf {
    my ($path) = @_;
    open FD, '<'.$path or die $path.': '.$!;
    my $body = '';
    while (<FD>) {
        chomp;
        ## next if /^#/;
        ## s|#.*||; # remove trailing comment
        s|^[ 	]*||; # space, tab
        s|[ 	]*$||;
        next if /^$/;
        my $line = $_;
        $body .= $line;
    }

    my @records = split('}{', $body);
    return @records;
}

http://www.graphviz.org/doc/info/colors.html
https://en.wikipedia.org/wiki/Web_colors

# --

my $s = 'Hello World';
my $x1 = unpack("H*",  $s); # ascii_to_hex
my $s = pack('H*', $x1); # hex_to_ascii

_eof_
