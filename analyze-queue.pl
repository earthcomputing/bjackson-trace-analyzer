#!/usr/local/bin/perl -w
#!/usr/bin/perl -w
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------
# analyze xx.json
## A microservice is not a 'subroutine' !!
# python -mjson.tool

use 5.010;
use strict;
use warnings;

use lib '/Users/bjackson/perl5/lib/perl5';
use JSON qw(decode_json encode_json);
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Data::GUID;

use Scalar::Util qw(blessed);
use Try::Tiny;
use Kafka qw($KAFKA_SERVER_PORT $REQUEST_TIMEOUT $RECEIVE_EARLIEST_OFFSET $DEFAULT_MAX_NUMBER_OF_OFFSETS $DEFAULT_MAX_BYTES);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;

# --

my $endl = "\n";
my $dquot = '"';
my $blank = ' ';

my $maxport = 7;
my $cm_bitmask = 1 << 0;
my $null_uuid = '0x00000000000000000000000000000000';

# --
# ait byte coding
my $ait_code = {
    '00' => 'TICK',
    '01' => 'TOCK',
    '02' => 'TACK',
    '03' => 'TECK',
    '04' => 'AIT',
    '40' => 'NORMAL',
    # '00' => 'FORWARD',
    '80' => 'REVERSE'
};

# --
# ait state sequence:

# seq : 'AIT ' => 'TECK' => 'TACK' => 'TOCK' => 'TICK' => 'TOCK'
my $ait_forward = {
    'TICK' => 'TOCK',
    'TOCK' => 'TICK',
    'TACK' => 'TOCK',
    'TECK' => 'TACK',
    'AIT ' => 'TECK',
    'NORMAL' => 'NORMAL'
};

# seq : 'TICK' => 'TOCK' => 'TACK' => 'TECK' => 'AIT'
my $ait_backward = {
    'TICK' => 'TOCK',
    'TOCK' => 'TACK',
    'TACK' => 'TECK',
    'TECK' => 'AIT',
    'NORMAL' => 'NORMAL'
};

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
my $gvmfile = 'gvm-table.txt'; my %gvm_table;
my $manifestfile = 'manifest-table.txt'; my %manifest_table;

# tables of json_text for various objects
sub note_value {
    my ($href, $value) = @_;
    return undef unless $value;

    my $json_text = JSON->new->canonical->encode($value);
    giveup('encode error') unless $json_text;
    my $hc = sha1_hex($json_text);
    giveup('hash error') unless $hc;
    $href->{$json_text} = $hc;
    return $hc;
}

my $op_table = {
    'Application' => 'A',
    'Discover' => 'D',
    'DiscoverD' => 'DD',
    'Hello' => 'H',
    'Manifest' => 'M',
    'StackTree' => 'S',
    'StackTreeD' => 'SD'
};

my $arrow_code = {
    'cell-rcv' => '<',
    'cell-snd' => '>',
    'pe-rcv' => '<-',
    'pe-snd' => '->'
};

my $gamut = {
    'C0' => 'red',
    'C1' => 'green',
    'C2' => 'blue',
    'C3' => 'cyan',
    'C4' => 'magenta',
    'C5' => 'purple', # 'yellow' - bad visual choices
    'C6' => 'navy',
    'C7' => 'green',
    'C8' => 'maroon',
    'C9' => 'turquoise4', # teal, 'olive'

    'C2+NocAgentDeploy' => 'cyan',
    'C2+NocMasterDeploy' => 'magenta',
    'C2+NocAgentMaster' => 'navy',
    'C2+NocMasterAgent' => 'maroon',
    'C2+Noc' => 'maroon',

    'C0+Connected' => 'black',
    'C1+Connected' => 'black',
    'C2+Connected' => 'black',
    'C0+Control' => 'black',
    'C1+Control' => 'black',
    'C2+Control' => 'black'
};

sub pick_color {
    my ($span_tree) = @_;
    $span_tree =~ s/Tree://;
    my $color = $gamut->{$span_tree};
    return 'black' unless $color;
    return $color;
}

# --

my $debug;
my $NOT_ALAN;
my $code_filter;
my $last_epoch;
my $epoch_global;
my $result_dir = '/tmp/'; # can be blank!?

my $max_cell = -1;
my %cell_table; # $c => $edge_no

my $max_edge = 1; # avoid 0
my %edges; # map : "Cx:pX->Cy:pY" -> { 'left_cell' 'left_port' 'right_cell' 'right_port' 'edge_no' }; # plus 'Internet'
my %link_table; # map : 'Cx:py' -> $link_no
my @wires; # array {from, to}

my $max_forest = 1;
my %forest; # map : int -> { span_tree parent p child }

my %jschema; # map : {$path}++ {$path.$jtype}++; {$path.' : BOOLEAN'}++;
my %keyset; # map : foreach my $tag (keys $json) { $keyset{$tag}++; }
my %msg_table; # map : {$payload_text} = $payload_hash
my %routing_table; # map : {$cell_id}{$entry->{'tree_uuid'}} => $entry
my %verb; # map : $verb{join('$', $module, $function)}++; $verb{$methkey}++;
my %guid_table; # map : guid -> name

my @msgqueue; # list : { 'event_code' 'tree_id' 'cell_no' 'link_no' 'code' };

# --

foreach my $fname (@ARGV) {
    if ($fname eq '-NOT_ALAN') { $NOT_ALAN = 1; next; }
    if ($fname =~ /-wdir=/) { my ($a, $b) = split('=', $fname); $result_dir = $b; $result_dir = '' unless $result_dir; next; }
    if ($fname =~ /-filter=/) { my ($a, $b) = split('=', $fname); $code_filter = $b; next; }
    if ($fname =~ /-server=/) { my ($a, $b) = split('=', $fname); $server = $b; next; }
    if ($fname =~ /-epoch=/) { my ($a, $b) = split('=', $fname); $last_epoch = $b; next; }
    print($endl, $fname, $endl);
    open(DBGOUT, '>'.$result_dir.$dbg_file) or die $result_dir.$dbg_file.': '.$!;
    open(FRAMEOUT, '>'.$result_dir.$frames_file) or die $result_dir.$frames_file.': '.$!;
    my $href = process_file($fname);
    do_analyze($href);
}

# ISSUE : one file/report for entire list of inputs
dump_complex();
dump_routing_tables();
dump_msgs($msgfile, \%msg_table);
dump_msgs($gvmfile, \%gvm_table);
dump_msgs($manifestfile, \%manifest_table);
dump_schema();
dump_guids();
dump_forest();
msg_sheet();

close(FRAMEOUT);
close(DBGOUT);
exit 0;

# --

sub epoch_marker {
    print DBGOUT (join(' ', 'epoch_marker:', $epoch_global), $endl);
}

sub dump_guids {
    my $fname = $guidfile;
    my $hdr = 'GUIDS:';
    my $href = \%guid_table;

    my $path = $result_dir.$fname;
    open(GUIDS, '>'.$path) or die $path.': '.$!;
    print GUIDS ($endl);
    print GUIDS ($hdr, $endl);

    # sort by value
    foreach my $item (sort { $href->{$a} cmp $href->{$b} } keys %{$href}) {
        my $hint =  lc(substr($item, 0, 8)); # -8
        print GUIDS (join(' ', $hint, $item, $href->{$item}), $endl);
    }

    close(GUIDS);
}

# accelerate with an inverted map
sub find_edge {
    my ($edge_no) = @_;
    foreach my $k (keys %edges) {
        my $o = $edges{$k};
        return $o if $o->{'edge_no'} == $edge_no;
    }
    giveup('find_edge: not found? '.$edge_no);
}

sub write_link {
    my ($link_no, $label) = @_;
    my $edge_no = int($link_no / 2);
    my $compass = $link_no % 2;

    my $o = find_edge($edge_no);

    my $lc = $o->{'left_cell'};
    my $lp = $o->{'left_port'};
    my $rc = $o->{'right_cell'};
    my $rp = $o->{'right_port'};

    giveup('bad link') if ($lc == -1); # 'Internet'

    if ($compass) {
        my $attrs = '[label="'.$label.'" color=red]';
        printf DOT ("C%d:p%d -> C%d:p%d %s\n", $lc, $lp, $rc, $rp, $attrs); # [label=\"p%d:p%d,\\n%s\"]
    }
    else {
        my $attrs = '[label="'.$label.'" color=blue]';
        printf DOT ("C%d:p%d -> C%d:p%d %s\n", $rc, $rp, $lc, $lp, $attrs); # [label=\"p%d:p%d,\\n%s\"]
    }
}

# info from activate_edge / meth_connect_link
sub write_edge {
    my ($lc, $lp, $rc, $rp, $edge_no) = @_;
    if ($NOT_ALAN) {
        my $link_name = 'link#'.$edge_no;
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"p%d:p%d,\\n%s\"]\n", $lc, $lp, $rc, $rp, $lp, $rp, $link_name);
    }
    else {
        my $link_no = $edge_no * 2;
        my $link_name = letters($link_no);
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"%s\"]\n", $lc, $lp, $rc, $rp, $link_name);
    }
}

# info from border_port / meth_ca_send_msg_port_connected
sub write_border {
    my ($c, $p, $edge_no) = @_;
    if ($NOT_ALAN) {
        my $link_name = 'link#'.$edge_no;
        printf DOT ("Internet -> C%d:p%d [label=\"p%d,\\n%s\"]\n", $c, $p, $p, $link_name);
    }
    else {
        my $link_no = $edge_no * 2;
        my $link_name = letters($link_no);
        printf DOT ("Internet -> C%d:p%d [label=\"%s\"]\n", $c, $p, $link_name);
    }
}

sub dump_edges {
    foreach my $k (sort order_edges keys %edges) {
        my $o = $edges{$k};
        my $left_cell = $o->{'left_cell'};
        my $left_port = $o->{'left_port'};
        my $right_cell = $o->{'right_cell'};
        my $right_port = $o->{'right_port'};
        my $edge_no = $o->{'edge_no'};

        if ($left_cell == -1) { # eq 'Internet') {
            write_border($right_cell, $right_port, $edge_no);
        }
        else {
            write_edge($left_cell, $left_port, $right_cell, $right_port, $edge_no);
        }
    }
}

sub order_edges($$) {
    my ($left, $right) = @_;
    my $l = $edges{$left}{'edge_no'};
    my $r = $edges{$right}{'edge_no'};
    return $l <=> $r;
}

sub dump_complex {
    my $path = $result_dir.$dotfile;
    open(DOT, '>'.$path) or die $path.': '.$!;
    print DOT ('digraph G {', $endl);
    print DOT ('rankdir=LR', $endl);
    dump_edges();
    foreach my $c (sort keys %cell_table) {
        my $c_up = $cell_table{$c}; # edge_no
        next if ($c == -1); # Internet
        my $link_no = ($c_up * 2) + 1;
        my $cell_lname = ($NOT_ALAN) ? 'link#'.$link_no : letters($link_no);
        printf DOT ("C%d [label=\"C%d  (%s)\"]\n", $c, $c, $cell_lname);
    }
    add_overlay();
    print DOT ('}', $endl);
    close(DOT);
}

sub add_overlay {
    my %target;
    foreach my $k (sort order_forest keys %forest) {
        my $o = $forest{$k};
        my $root = $o->{'root'};
        my $link_no = $o->{'link_no'};
        next unless defined $root; # defensive against parse errors

        $target{$link_no} = [] unless $target{$link_no}; # ensure defined
        push(@{$target{$link_no}}, $root);

    }
    foreach my $l (sort keys %target) {
        my @cells = @{$target{$l}};
        my $label = '( C'.join(' C', sort @cells).' )'; # list of roots
        write_link($l, $label);
    }
}

sub dump_schema {
    my $path = $result_dir.$schemafile;
    open(SCHEMA, '>'.$path) or die $path.': '.$!;
    dump_histo('VERBS:', \%verb);
    dump_histo('SCHEMA:', \%jschema);
    dump_histo('KEYSET:', \%keyset);
    close(SCHEMA);
}

sub update_routing_table {
    my ($cell_id, $entry) = @_;
    # my $key = $entry->{'index'};
    my $key = $entry->{'tree_uuid'};
    $routing_table{$cell_id} = { } unless defined $routing_table{$cell_id};
    my $table = $routing_table{$cell_id};
    $table->{$key} = $entry;
    # FIXME : should we indicate updates ??
}

sub get_routing_entry {
    my ($cell_id, $key) = @_;
    return $routing_table{$cell_id}->{$key};
}

# costly, but validates
sub hint4uuid {
    my ($ref) = @_;
    my $hex_guid = xlate_uuid($ref);
    return lc(substr($hex_guid, 0, 8)); # -8 from right
}

sub dump_routing_tables {
    my $path = $result_dir.$routingfile;
    open(FD, '>'.$path) or die $path.': '.$!;
    foreach my $cell_id (sort keys %routing_table) {
        print FD ($endl);
        print FD (join(' ', $cell_id, 'Routing Table'), $endl);

        my $routes = $routing_table{$cell_id};
        foreach my $key (sort { $a cmp $b } keys %{$routes}) {
            my $entry = $routes->{$key};
            # my $index = $entry->{'index'};
            my $hint = hint4uuid($entry->{'tree_uuid'});
            my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
            my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
            my $parent = port_index($entry->{'parent'});
            my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
            # my $other_indices = '['.join(', ', @{$entry->{'other_indices'}}).']';
            my $guid_name = grab_name($entry->{'tree_uuid'});
            print FD (join("\t", $hint, $inuse, $may_send, $parent, $mask, $guid_name), $endl); # $index, $other_indices
        }
    }
    close(FD);
}

sub dump_msgs {
    my ($file, $href) = @_;
    my $path = $result_dir.$file;
    open(FD, '>'.$path) or die $path.': '.$!;

    foreach my $key (sort keys %{$href}) {
        my $hint = substr($href->{$key}, -5);
        print FD (join(' ', $hint, $key), $endl);
    }

    close(FD);
}

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_mtable($$) {
    my ($left, $right) = @_;
    my $href = \%msg_table;

    my $left_hint = substr($href->{$left}, -5);
    my $right_hint = substr($href->{$right}, -5);
    return $left_hint cmp $right_hint unless $left_hint eq $right_hint;
    return $href->{$left} cmp $href->{$right};
}

## Spreadsheet Coding:
sub add_msgcode2 {
    my ($tag, $tree_id, $port, $body, $key) = @_;
    my $event_code = ec_fromkey($key); # aka lineno

    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $header = $msg->{'header'};
    my $payload = $msg->{'payload'};
    my $msg_type = $header->{'msg_type'};

    my $c = $cell_id; $c =~ s/C://;
    add_msgcode($c, $port, $msg_type, $event_code, $tag, $tree_id);
}

# link#
# $dir : cell-rcv, cell-snd, pe-rcv, pe-snd
sub add_msgcode {
    my ($c, $p, $msg_type, $event_code, $dir, $tree_id) = @_;
    # swimming against the flow, or not ??
    # relate to the wiring diagram, trees segments can be upside-down!
    my $link_no = get_link_no($c, $p);
    return unless $link_no; # ugh, issue with 0
    my $arrow = $arrow_code->{$dir};
    my $crypt = $op_table->{$msg_type}; # FIXME - missing msg_type's here ...
    my $link_code = ($NOT_ALAN) ?  'link#'.$link_no : letters($link_no);
    my $code = $crypt.$arrow.$link_code.' '.'('.$tree_id.')'; # $blank
    my $o = {
        'event_code' => $event_code,
        'tree_id' => $tree_id,
        'cell_no' => $c,
        'link_no' => $link_no,
        'arrow' => $arrow,
        'code' => $code
    };

    print DBGOUT (join(' ', 'msgcode', 
        $msg_type,
        $o->{'event_code'},
        $o->{'tree_id'},
        'C'.$o->{'cell_no'}.'p'.$p,
        $o->{'link_no'},
        $o->{'arrow'},
        $o->{'code'}
        ), $endl);
    push(@msgqueue, $o);
}

sub letters {
    my ($link_no) = @_;
    my $edge_no = int($link_no / 2);
    my $compass = $link_no % 2;
    my $star = ($compass == 0) ? '' : "'";

    my $little = $edge_no % 26;
    my $more = int($edge_no / 26);

    my $ch0 = chr($little + ord('a') - 1);
    my $ch1= chr($more + ord('a') - 1);
    my $name = $ch0; $name = $ch1.$ch0 if $more > 0; # 676 edges (vs. 17,576 or 456,976 edges)
    return $name.$star;
}

# uses the notion that an 'edge' can have 4 pending operations on it simultanously: (left, right) x (xmit rcv).
# There's a possible argument that left-xmit conflicts (must have happens-before) with right-rcv.
# instead, allow for the notion that "the wire" can hold two msgs so that each end can be simultaneously active.
# allows the spreadsheet to be really dense - provided folks reading it understand the game rules

# breaking condition is contention for a queue endpoint
# could construct data into a 2 dimensional data structure (fix number of cells, variable length history)
sub msg_sheet {
    my $path = $result_dir.$csvfile;
    open(CSV, '>'.$path) or die $path.': '.$!;
    print CSV (join(',', 'event/cell', 0..9), $endl);
    my @row = ();

    my %queue_table;

    foreach my $item (sort order_msgs @msgqueue) {
        my $code = $item->{'code'};
        if (defined $code_filter) { next unless $code =~ $code_filter; }

        my $c = $item->{'cell_no'};
        my $l = $item->{'link_no'};
        my $arrow = $item->{'arrow'};

        my $chan = $l.$arrow;
        my $interlock = $queue_table{$chan};
        $queue_table{$chan}++;

        # causal relationship - cell-agent queue and link queues are sequential
        # check if the queue is busy:
        if (defined $interlock) {
            foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
            print CSV (join(',', $item->{'event_code'}, map { $dquot.$_.$dquot } @row), $endl);
            @row = ();
            %queue_table = ();
        }

        my $prev = $row[$c];
        $code .= $endl.$prev if $prev;
        $row[$c] = $code;
    }

    # dangling data:
    foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
    print CSV (join(',', 'last', map { $dquot.$_.$dquot } @row), $endl);
    close(CSV);
}

sub giveup {
    my ($msg) = @_;
    print STDERR ($msg, $endl);
    exit -1;
}

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_msgs($$) {
    my ($left, $right) = @_;
    my $l1 = $left->{'event_code'};
    my $r1 = $right->{'event_code'};
    return $l1 - $r1 unless $l1 == $r1;

    my $l2 = $left->{'link_no'};
    my $r2 = $right->{'link_no'};
    return $l2 - $r2 unless $l2 == $r2;

    giveup(join(' ', 'WARNING: duplicate event/link?', $l1, $l2));
}

# --

sub process_file {
    my ($fname) = @_;

    my $topic;
    if ($fname =~ /-topic=/) { my ($a, $b) = split('=', $fname); $topic = $b; }
    my @records = ($topic) ? kafka_inhale($topic) : inhale($fname);

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
$epoch_global = $epoch;

        ## my $methkey = join('$$', $module, $function, $kind, $format);
        $verb{join('$', $module, $function)}++;

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

# 00112233-4455-6677-8899-aabbccddeeff
# {time_low}-{time_mid}-{time_hi_and_version}-{clk_seq_hi_res/clk_seq_low}-{node}
# octet 8 variant
# octet 6 version
# variant - most significant 3 bits of clock_seq (clk_seq_hi_res)
# version - most significant 4 bits of timestamp (time_hi_and_version)
# 1-3 bit "variant" followed by 13-15 bit clock sequence
# clk_seq_hi_res=88
# time_hi_and_version=6677
sub xlate_uuid {
    my ($ref) = @_;
    return $null_uuid unless ref($ref) eq 'HASH';
    my $words = $ref->{'uuid'};

    my $rkind = ref($words);
    if ($rkind eq 'ARRAY') {
        return $null_uuid unless $#$words == 1;

        my $w0 = $words->[0];
        my $w1 = $words->[1];

        unless (defined $w0) {
            print STDERR (Dumper $ref, $endl);
            exit 0;
        }

        my $str = sprintf("0x%016x%016x", $w1, $w0);
        my $guid = Data::GUID->from_hex($str);
        my $hex_guid = $guid->as_hex;
        return $hex_guid;
    }
    # Can't use string ("400d426d-8eee-4230-92b4-5557cdbd"...) as an ARRAY ref while "strict refs" in use at analyze.pl line 597.
    else {
        return $null_uuid unless $words;
        my $guid = Data::GUID->from_string($words);
        my $hex_guid = $guid->as_hex;
        return $hex_guid;
    }
}

# hex_guid
sub uuid_magic {
    my ($coded_uuid) = @_;
    my $b0 = substr($coded_uuid, 2, 2);
    my $b1 = substr($coded_uuid, 4, 2);
    # make_normal(uuid)
    substr($coded_uuid, 2, 4, '4000'); # ugh, side-effect : OFFSET,LENGTH,REPLACEMENT
    my $real_uuid = lc($coded_uuid);
    return ($b0, $b1, $real_uuid);
}

sub nametype {
    my ($nameref) = @_;
    my $name = $nameref->{'name'}; $name = '' unless defined $name;
    my $uuid = $nameref->{'uuid'};
    my $guid = xlate_uuid($uuid);
    $guid_table{$guid} = $name;
    return $name;
}

sub grab_name {
    my ($ref) = @_;
    my $guid = xlate_uuid($ref);
    my $guid_name = $guid_table{$guid};
}

sub port_index {
    my ($portref) = @_;

    my $rkind = ref($portref);
    if ($rkind eq 'HASH') {
        my $id = $portref->{'v'};
        return $id;
    }
    # Can't use string ("1") as a HASH ref while "strict refs" in use at analyze.pl line 640.
    else {
        return $portref;
    }
}

sub portdesc {
    my ($portref) = @_;
    my $id = port_index($portref);
    return 'v'.$id;
}

# --
## data record parsing routines:

# /body : OBJECT { schema_version [ncells] }
# 'noc.rs$$initialize$$Trace$$trace_schema'
sub meth_START {
    my ($body, $header) = @_;
    my $repo = $header->{'repo'};
    my $epoch = $header->{'epoch'};
    my $schema_version = $body->{'schema_version'};
    my $ncells = $body->{'ncells'}; # new
    print(join(' ', $repo, 'schema_version='.$schema_version, $epoch, ';'));
}

# /body : OBJECT { cell_number }
# 'initialize datacenter.rs$$initialize$$Trace$$border_cell_start'
sub meth_border_cell_start {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { cell_number }
# 'datacenter.rs$$initialize$$Trace$$interior_cell_start'
sub meth_interior_cell_start {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { edge_list }
# 'noc.rs$$initialize$$Trace$$edge_list'
# 'edge_list' => [ [ 0, 1 ], [ 1, 2 ], [ 1, 6 ], [ 3, 4 ], [ 5, 6 ], [ 6, 7 ], [ 7, 8 ], [ 8, 9 ], [ 0, 5 ], [ 2, 3 ], [ 2, 7 ], [ 3, 8 ], [ 4, 9 ] ]
sub meth_edge_list {
    my ($body) = @_;
    my $edge_list = $body->{'edge_list'};
    my @ary = @{$edge_list};
    foreach my $edge (@ary) {
        my ($left, $right) = (@{$edge});
        my $o = {
            'left' => $left,
            'right' => $right,
        };
        push (@wires, $o);
    }
    my $nedge = @wires;
    print(join(' ', 'nedge='.$nedge, ';'));
}

## IMPORTANT : link activation
# /body : OBJECT { link_id left_cell left_port rite_cell rite_port }
# 'datacenter.rs$$initialize$$Trace$$connect_link'
sub meth_connect_link {
    my ($body) = @_;
    my $link_id = $body->{'link_id'}{'name'};
    my $left_cell = nametype($body->{'left_cell'});
    my $left_port = portdesc($body->{'left_port'});
    my $rite_cell = nametype($body->{'rite_cell'});
    my $rite_port = portdesc($body->{'rite_port'});

    ## FIXME : GOV magic, should happen thru Discovery!
    ## Complex Entry:
    if (defined $link_id) {
        my ($c1, $lc, $p1, $lp, $c2, $rc, $p2, $rp) = split(/:|\+/, $link_id); # C:0+P:1+C:1+P:1
epoch_marker();
        activate_edge($lc, $lp, $rc, $rp);
    }
    print(join(' ', $link_id, ';'));
}

# /body : OBJECT { cell_number }
# 'nalcell.rs$$new$$Trace$$nalcell_port_setup'
sub meth_nalcell_port_setup {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { cell_id }
# 'nalcell.rs$$start_cell$$Trace$$nalcell_start_ca'
sub meth_nalcell_start_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
# 'nalcell.rs$$start_packet_engine$$Trace$$nalcell_start_pe'
sub meth_nalcell_start_pe {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
# 'packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca'
sub meth_pe_listen_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
# 'packet_engine.rs$$listen_port$$Debug$$pe_listen_ports'
sub meth_pe_listen_ports {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
# 'cellagent.rs$$listen_pe$$Debug$$ca_listen_pe'
sub meth_ca_listen_pe {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# single-ended port (link LOV) activation:

## IMPORTANT : Complex Entry
# /body : OBJECT { cell_id port_no is_border }
# 'cellagent.rs$$port_connected$$Trace$$ca_send_msg'
sub meth_ca_send_msg_port_connected {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $is_border = $body->{'is_border'}; # cell port=of-entry

    ## Complex Entry:
    my $port_id = '';
    if (defined $port_no) {
        $port_id = (($is_border) ? 'FX:' : '').$port_no;
epoch_marker();
        border_port($cell_id, $port_no) if $is_border;
    }
    print(join(' ', $cell_id, $port_id, ';'));
}

# point of origin for all messages!

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg port_nos tree_id }
# /body/msg : OBJECT { header payload }
# /.../payload : OBJECT { tree_id body }
# 'cellagent.rs$$send_msg$$Debug$$ca_send_msg'
sub meth_ca_send_msg_generic {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_nos = $body->{'port_nos'};
    my $port_list = build_port_list($port_nos);
    my $summary = summarize_msg($body->{'msg'});

    print(join(' ', $cell_id, $tree_id, $port_list, $summary, ';'));

    # my $msg_hdr = $body->{'msg'}{'header'};
    # my $msg_type = $msg_hdr->{'msg_type'};
    # my $direction = $msg_hdr->{'direction'};
    # my $msg_count = $msg_hdr->{'msg_count'};
    # my $sender_id = nametype($msg_hdr->{'sender_id'});
    # my $tree_map = $msg_hdr->{'tree_map'};

    my $msg_payload = $body->{'msg'}{'payload'};
    my $pay_tree_id = nametype($msg_payload->{'tree_id'}); # "C:2+NocAgentMaster"

    #FIXME -bj
    # confirm that a later record captures forwarding,
    # then switch this to indicate port #0
    # this really just adds a msg to the CA=>PE queue
    my $tag = 'cell-snd';
    foreach my $item (@{$port_nos}) {
        my $p = port_index($item);
        add_msgcode2($tag, $tree_id, $p, $body, $key);
    }
}

# virtual recieve from Cell Agent
# eventually this will be CA => C-Model => PE

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type tree_id }
# 'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca'
sub meth_pe_packet_from_ca {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $tree_id, ';'));

    # Discover - "C:0"
    # DiscoverD - "C:0"
    # StackTree - "C:2+NocAgentDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    # StackTreeD - "C:2+NocAgentDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    # Manifest - "C:2+NocMasterDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = 0;
    ## add_msgcode2($tag, $tree_id, $p, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# /body : OBJECT { cell_id msg_type port_nos tree_id - ait_state }
# ait_state : SCALAR ;;
# 'packet_engine.rs$$listen_cm_loop$$Debug$$pe_forward_leafward'
sub meth_yyy {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_list = build_port_list($body->{'port_nos'});
    my $msg_type = $body->{'msg_type'};
    my $ait_state = $body->{'ait_state'};
    print(join(' ', $cell_id, $msg_type, $port_list, 'tree='.$tree_id, $ait_state, ';'));
}

# guts of the Packet Engine (forwarding)

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type port_nos tree_id }
# 'packet_engine.rs$$forward$$Debug$$pe_forward_leafward'
sub meth_pe_forward_leafward {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_list = build_port_list($body->{'port_nos'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $port_list, 'tree='.$tree_id, ';'));

    ## Spreadsheet Coding:
    my $port_nos = $body->{'port_nos'};
    my $c = $cell_id; $c =~ s/C://;
    my $event_code = ec_fromkey($key);
    foreach my $item (@{$port_nos}) {
        my $p = port_index($item);
        # add_msgcode2($tag, $tree_id, $port, $body, $key);
        add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
    }
}

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type parent_port tree_id }
# 'packet_engine.rs$$forward$$Debug$$pe_forward_rootward'
sub meth_pe_forward_rootward {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'parent_port'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $port_no, 'tree='.$tree_id, ';'));

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = port_index($body->{'parent_port'});
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
}

# Packet Engine Control Plane - msg processing (ie. worker)

## IMPORTANT : Routing, Spreadsheet
# /body : OBJECT { cell_id entry msg_type port_no tree_id }
# 'packet_engine.rs$$process_packet$$Debug$$pe_process_packet'
sub meth_pe_process_packet {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});

    # why is this "meta data" ?
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};

    my $entry = $body->{'entry'};
    # my $index = $entry->{'index'};
    my $parent = portdesc($entry->{'parent'});
    print(join(' ', $cell_id, $port_no, $tree_id, $msg_type, 'parent='.$parent, ';')); # 'index='.$index

    ## Routing Table:
    update_routing_table($cell_id, $entry);

    # FIXME - maybe this isn't a msgcode per-se (redundant/excess) ??
    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = port_index($body->{'port_no'});
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# --
# traph ops:

# /body : OBJECT { cell_id base_tree_id children gvm hops other_index port_number port_status }
# 'cellagent.rs$$update_traph$$Debug$$ca_update_traph'
sub meth_ca_update_traph {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'}); # "C:2"
    my $port_no = portdesc($body->{'port_number'}{'port_no'});
    my $port_status = $body->{'port_status'}; # STRING # Parent, Child, Pruned
    my $base_tree_id = nametype($body->{'base_tree_id'}); # "C:2", "C:2+Control", "C:2+Connected", "C:2+Noc"
    my $hops = $body->{'hops'}; # NUMBER
    # my $other_index = $body->{'other_index'}; # NUMBER
    # 'children' => [],
    # "gvm": { "recv_eqn": "true", "save_eqn": "false", "send_eqn": "true", "variables": [], "xtnd_eqn": "true" },
    my $gvm = $body->{'gvm'};
    my $gvm_hash = note_value(\%gvm_table, $gvm);
    print(join(' ', $cell_id, $port_no, 'status='.$port_status, 'base='.$base_tree_id, 'hops='.$hops, 'gvm='.substr($gvm_hash, -5), ';')); # $other_index
}

## IMPORTANT : Routing
# /body : OBJECT { cell_id base_tree_id entry }
# 'cellagent.rs$$update_traph$$Debug$$ca_updated_traph_entry'
sub meth_ca_updated_traph_entry {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'}); # "C:2"
    my $base_tree_id = nametype($body->{'base_tree_id'}); # "C:2", "C:2+Control", "C:2+Connected", "C:2+Noc"
    my $entry = $body->{'entry'};

    ## Routing Table:
    update_routing_table($cell_id, $entry);

    # FIXME
    my $parent = portdesc($entry->{'parent'});
    print(join(' ', $cell_id, 'base='.$base_tree_id, 'entry.parent='.$parent, ';'));
}

# --
## ca_process_*

# 'cellagent.rs$$process_discover_msg$$Debug$$ca_process_discover_msg'
sub meth_ca_process_discover_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $new_tree_id, $port_no, $summary, ';'));
}

# 'cellagent.rs$$process_discoverd_msg$$Debug$$ca_process_discover_d_msg'
sub meth_ca_process_discover_d_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $summary, ';'));
}

# 'cellagent.rs$$process_stack_tree_msg$$Debug$$ca_process_stack_tree_msg'
sub meth_ca_process_stack_tree_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $new_tree_id, $port_no, $summary, ';'));
}

# 'cellagent.rs$$process_stack_treed_msg$$Debug$$ca_process_stack_tree_d_msg'
sub meth_ca_process_stack_tree_d_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# 'cellagent.rs$$process_manifest_msg$$Debug$$ca_process_manifest_msg'
sub meth_ca_process_manifest_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $summary, ';'));

    my $msg = $body->{'msg'};
    my $payload = $msg->{'payload'};
    my $manifest = $payload->{'manifest'};
    my $app_name = $manifest->{'id'};
    my $man_hash = note_value(\%manifest_table, $manifest);
    my $opt_manifest = defined($man_hash) ? substr($man_hash, -5) : '';
epoch_marker();
    print DBGOUT (join(' ', 'Launch Application:', $tree_id, $cell_id, $app_name, 'manifest='.$opt_manifest), $endl);
}

# 'cellagent.rs$$process_application_msg$$Debug$$ca_process_application_msg'
sub meth_ca_process_application_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $save = $body->{'save'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $save, $summary, ';'));
}

# --
# general info:

# /body : OBJECT { cell_id tree_id }
# 'cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id'
sub meth_ca_get_base_tree_id {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'}); # "C:0+Connected", "C:1", "C:2+NocMasterDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    print(join(' ', $cell_id, $tree_id, ';'));
}

# /body : OBJECT { cell_id msg tree_id }
# 'cellagent.rs$$add_saved_discover$$Debug$$ca_save_discover_msg'
sub meth_ca_save_discover_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $summary, ';'));
}

# --

## IMPORTANT : Stacking (base_tree_map) ??
# /body : OBJECT { cell_id base_tree_id stacked_tree_id }
# 'cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map'
sub meth_ca_update_base_tree_map {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $base_tree_id = nametype($body->{'base_tree_id'});
    my $stacked_tree_id = nametype($body->{'stacked_tree_id'});
    print(join(' ', $cell_id, $base_tree_id, $stacked_tree_id, ';'));

epoch_marker();
    print DBGOUT (join(' ', 'Layer Tree:', $base_tree_id, $stacked_tree_id), $endl);
}

## IMPORTANT : Stacking
# /body : OBJECT { cell_id base_tree_id base_tree_map_keys base_tree_map_values new_tree_id }
# 'cellagent.rs$$stack_tree$$Debug$$ca_stack_tree'
sub meth_ca_stack_tree {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $base_tree_id = nametype($body->{'base_tree_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    # base_tree_map_keys
    # base_tree_map_values
    # FIXME
    print(join(' ', $cell_id, $base_tree_id, $new_tree_id, ';'));
}

# IMPORTANT : Stacking, Routing
# /body : OBJECT { cell_id msg entry new_tree_id }
# 'cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg'
sub meth_ca_got_stack_tree_tcp_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $summary = summarize_msg($body->{'msg'});

    my $entry = $body->{'entry'};

    ## Routing Table:
    # update_routing_table($cell_id, $entry);

    # FIXME
    print(join(' ', $cell_id, $new_tree_id, $summary, ';'));

    my $msg = $body->{'msg'};
    my $payload = $msg->{'payload'};
    my $gvm_eqn = $payload->{'gvm_eqn'};
    my $gvm_hash = note_value(\%gvm_table, $gvm_eqn);
    my $opt_gvm = defined($gvm_hash) ? substr($gvm_hash, -5) : '';
epoch_marker();
    print DBGOUT (join(' ', 'Application Tree:', $new_tree_id, 'gvm='.$opt_gvm), $endl);

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $new_tree_id, $virt_p, $body, $key);
}

# IMPORTANT : Stacking
# /body : OBJECT { cell_id msg no_saved tree_id }
# 'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg'
sub meth_ca_save_stack_tree_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg no_saved tree_id }
# 'cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg'
sub meth_ca_add_saved_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = 'BUG'; # summarize_msg($body->{'msg'}); ## msg became an array, with [0] = null ??
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));
}
# bj

# best guess - launch of VM (Cell Agent Control Plane work action)

# IMPORTANT : up_tree
# /body : OBJECT { cell_id deployment_tree_id tree_vm_map_keys up_tree_name }
# 'cellagent.rs$$deploy$$Debug$$ca_deploy'
sub meth_ca_deploy {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deployment_tree_id = nametype($body->{'deployment_tree_id'});
    my $up_tree_name = $body->{'up_tree_name'}; # STRING # "vm1"
    # my $tree_vm_map_keys = $body->{'tree_vm_map_keys'};
    print(join(' ', $cell_id, $deployment_tree_id, $up_tree_name, ';'));

epoch_marker();
    print DBGOUT (join(' ', 'Deploy:', $cell_id, $up_tree_name, $deployment_tree_id), $endl);
}

# /body : OBJECT { cell_id sender_id vm_id }
# 'cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm'
sub meth_ca_listen_vm {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $sender_id = nametype($body->{'sender_id'});
    my $vm_id = nametype($body->{'vm_id'});
    print(join(' ', $cell_id, $sender_id, $vm_id, ';'));
}

#  listen_uptree_loop C:0 Rootward Application Reply from Container:VM:C:0+vm1+2 NocAgentMaster ;

# /body : OBJECT { cell_id msg_type allowed_tree direction tcp_msg }
# 'cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree'
sub meth_ca_got_from_uptree {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $direction = $body->{'direction'};
    my $tcp_msg = $body->{'tcp_msg'};
    my $allowed_tree = nametype($body->{'allowed_tree'});
    print(join(' ', $cell_id, $msg_type, $direction, $tcp_msg, $allowed_tree, ';'));
}

# /body : OBJECT { cell_id msg deploy_tree_id }
# 'cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg'
sub meth_ca_got_manifest_tcp_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deploy_tree_id = nametype($body->{'deploy_tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $deploy_tree_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $deploy_tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg tree_id }
# 'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg'
sub meth_ca_got_tcp_application_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);

    my $str = decode_octets($body->{'msg'});
epoch_marker();
    print DBGOUT (join(' ', 'TCP_APP:', $cell_id, $dquot.$str.$dquot), $endl);
}

sub decode_octets {
    my ($msg) = @_;
    my $payload = $msg->{'payload'};
    my $octets = $payload->{'body'};
    my $content = convert_string($octets);
}

sub convert_string {
    my ($ref) = @_;
    my $str = '';
    foreach my $i (@{$ref}) {
        my $c = chr($i);
        $str .= $c;
    }
    return $str;
}

## IMPORTANT : stacking
# /body : OBJECT { cell_id msg_type port_nos tree_id }
# 'cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg'
sub meth_ca_forward_stack_tree_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $tree_id, $msg_type, $port_list, ';'));
}

# /body : OBJECT { cell_id no_saved_msgs tree_id }
# 'cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs'
sub meth_ca_get_saved_msgs {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved_msgs = $body->{'no_saved_msgs'};
    print(join(' ', $cell_id, $tree_id, $no_saved_msgs, ';'));
}

# /body : OBJECT { cell_id msg_type port_nos }
# 'cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg'
sub meth_ca_forward_saved_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'}; # Manifest Application
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# --

sub dispatch {
    my ($key, $module, $function, $kind, $format, $json) = @_;
    my $methkey = join('$$', $module, $function, $kind, $format);

    $verb{$methkey}++;

    my $body = $json->{'body'};
    my $header = $json->{'header'};

    # This indicates subsystem startup - i.e. break in seq of messages
    if ($methkey eq 'main.rs$$main$$Trace$$trace_schema') { meth_START($body, $header); return; }
    if ($methkey eq 'main.rs$$MAIN$$Trace$$trace_schema') { meth_START($body, $header); return; }
    ## if ($methkey eq 'noc.rs$$MAIN$$Trace$$trace_schema') { meth_START($body, $header); return; }
    ## if ($methkey eq 'noc.rs$$initialize$$Trace$$trace_schema') { meth_START($body, $header); return; }

    if ($methkey eq 'datacenter.rs$$initialize$$Trace$$border_cell_start') { meth_border_cell_start($body); return; }
    if ($methkey eq 'datacenter.rs$$initialize$$Trace$$interior_cell_start') { meth_interior_cell_start($body); return; }
    if ($methkey eq 'datacenter.rs$$initialize$$Trace$$connect_link') { meth_connect_link($body); return; }

    if ($methkey eq 'nalcell.rs$$new$$Trace$$nalcell_port_setup') { meth_nalcell_port_setup($body); return; }
    if ($methkey eq 'nalcell.rs$$start_cell$$Trace$$nalcell_start_ca') { meth_nalcell_start_ca($body); return; } ## nal_cellstart_ca
    if ($methkey eq 'nalcell.rs$$start_packet_engine$$Trace$$nalcell_start_pe') { meth_nalcell_start_pe($body); return; }
    ## if ($methkey eq 'nalcell.rs$$start_cell$$Trace$$nal_cellstart_ca') { meth_nalcell_start_ca($body); return; }

# --

    if ($methkey eq 'cellagent.rs$$update_traph$$Debug$$ca_update_traph') { meth_ca_update_traph($body); return; }
    if ($methkey eq 'cellagent.rs$$update_traph$$Debug$$ca_updated_traph_entry') { meth_ca_updated_traph_entry($body); return; }

# --

    if ($methkey eq 'cellagent.rs$$process_application_msg$$Debug$$ca_process_application_msg') { meth_ca_process_stack_tree_d_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$process_discover_msg$$Debug$$ca_process_discover_msg') { meth_ca_process_discover_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$process_discoverd_msg$$Debug$$ca_process_discover_d_msg') { meth_ca_process_discover_d_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$process_manifest_msg$$Debug$$ca_process_manifest_msg') { meth_ca_process_manifest_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$process_stack_tree_msg$$Debug$$ca_process_stack_tree_msg') { meth_ca_process_stack_tree_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$process_stack_treed_msg$$Debug$$ca_process_stack_tree_d_msg') { meth_ca_process_stack_tree_d_msg($body); return; }

# --

    if ($methkey eq 'cellagent.rs$$add_saved_discover$$Debug$$ca_save_discover_msg') { meth_ca_save_discover_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg') { meth_ca_add_saved_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg') { meth_ca_save_stack_tree_msg($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$deploy$$Debug$$ca_deploy') { meth_ca_deploy($body); return; }
    if ($methkey eq 'cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg') { meth_ca_forward_saved_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg') { meth_ca_forward_stack_tree_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id') { meth_ca_get_base_tree_id($body); return; }
    if ($methkey eq 'cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs') { meth_ca_get_saved_msgs($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_pe$$Debug$$ca_listen_pe') { meth_ca_listen_pe($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg') { meth_ca_got_msg($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm') { meth_ca_listen_vm($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree') { meth_ca_got_from_uptree($body); return; }
    if ($methkey eq 'cellagent.rs$$port_connected$$Trace$$ca_send_msg') { meth_ca_send_msg_port_connected($body); return; }
    if ($methkey eq 'cellagent.rs$$send_msg$$Debug$$ca_send_msg') { meth_ca_send_msg_generic($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$stack_tree$$Debug$$ca_stack_tree') { meth_ca_stack_tree($body); return; }
    if ($methkey eq 'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg') { meth_ca_got_tcp_application_msg($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg') { meth_ca_got_manifest_tcp_msg($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg') { meth_ca_got_stack_tree_tcp_msg($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map') { meth_ca_update_base_tree_map($body); return; }

    if ($methkey eq 'packet_engine.rs$$forward$$Debug$$pe_forward_leafward') { meth_pe_forward_leafward($body, $key); return; }
    if ($methkey eq 'packet_engine.rs$$forward$$Debug$$pe_forward_rootward') { meth_pe_forward_rootward($body, $key); return; }
    ## if ($methkey eq 'packet_engine.rs$$listen_ca$$Debug$$listen_ca') { meth_pe_listen_ca($body); return; }
    if ($methkey eq 'packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca') { meth_pe_listen_ca($body); return; } ## listen_ca
    if ($methkey eq 'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca') { meth_pe_packet_from_ca($body, $key); return; }
    if ($methkey eq 'packet_engine.rs$$listen_port$$Debug$$pe_listen_ports') { meth_pe_listen_ports($body); return; } ##  pe_msg_from_ca
    ## if ($methkey eq 'packet_engine.rs$$listen_port$$Debug$$pe_msg_from_ca') { meth_pe_listen_ports($body); return; }
    if ($methkey eq 'packet_engine.rs$$process_packet$$Debug$$pe_process_packet') { meth_pe_process_packet($body, $key); return; }

    if ($methkey eq 'cellagent.rs$$listen_cm$$Debug$$ca_listen_pe') { meth_ca_listen_pe_cmodel($body); return; }
    if ($methkey eq 'cmodel.rs$$listen_ca_loop$$Debug$$cm_bytes_from_ca') { meth_cm_bytes_from_ca($body, $key); return; }
    if ($methkey eq 'cmodel.rs$$process_packet$$Debug$$cm_bytes_to_ca') { meth_cm_bytes_to_ca($body); return; }
    if ($methkey eq 'packet_engine.rs$$listen_cm_loop$$Debug$$pe_packet_from_cm') { meth_pe_packet_from_cm($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$listen_cm_loop$$Debug$$ca_got_msg') { meth_ca_got_msg_cmodel($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$forward_saved_manifest$$Debug$$ca_forward_saved_msg') { meth_ca_forward_saved_msg_manifest($body); return; }
    if ($methkey eq 'cellagent.rs$$forward_saved_application$$Debug$$ca_forward_saved_msg') { meth_ca_forward_saved_msg_application($body); return; }

    if ($methkey eq 'cellagent.rs$$listen_cm$$Debug$$ca_listen_cm') { meth_ca_listen_cm($body); return; }
    if ($methkey eq 'packet_engine.rs$$listen_cm_loop$$Debug$$pe_forward_leafward') { meth_yyy($body, $key); return; }

    if ($methkey eq 'noc.rs$$initialize$$Trace$$edge_list') { meth_edge_list($body, $key); return; }
    if ($methkey eq 'main.rs$$listen_port_loop$$Trace$$noc_from_ca') { meth_noc_from_ca($body, $key); return; }
    if ($methkey eq 'packet_engine.rs$$listen_cm_loop$$Trace$$recv') { meth_recv($body, $key); return; }
# NEW:
    if ($methkey eq 'packet_engine.rs$$listen_port_loop$$Trace$$pl_recv') { meth_pl_recv($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$process_hello_msg$$Debug$$ca_process_hello_msg') { meth_hello($body, $key); return; }

    print($endl);

    print STDERR (join(' ', $methkey), $endl);
    print STDERR Dumper $body;
    print STDERR ($endl);
    giveup('incompatible schema');
}

# packet_engine.rs$$listen_port_loop$$Trace$$pl_recv
# { 'cell_id',  'msg' { 'Status' [ 1, boolean, 'Connected' ] } }
sub meth_pl_recv {
    my ($body, $key) = @_;
}

# cellagent.rs$$process_hello_msg$$Debug$$ca_process_hello_msg
# { cell_id, recv_port_no, msg { header payload } }
## 'header' { 'sender_id' 'msg_count' 'tree_map' 'direction' 'is_ait' 'msg_type' },
## 'payload'=> { 'cell_id' 'port_no' }
sub meth_hello {
    my ($body, $key) = @_;
}

sub dump_entry {
    my ($entry) = @_;
    my $hint = hint4uuid($entry->{'tree_uuid'});
    my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
    my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
    my $parent = port_index($entry->{'parent'});
    my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
    return join(' ', $hint, $inuse, $may_send, $parent, $mask);
}

sub dump_packet {
    my ($user_mask, $packet) = @_;
    my $mask = $user_mask->{'mask'};
    my $bitmask = sprintf('%016b', $mask);
    my $header = $packet->{'header'};
        my $coded_uuid = $header->{'uuid'};
        my $hex_guid = xlate_uuid($coded_uuid);
        my ($b0, $b1, $real_uuid) = uuid_magic($hex_guid);
        my $hint = hint4uuid($coded_uuid); # not sure which (coded/real) to use here ??
    my $payload = $packet->{'payload'};
        my $is_last = $payload->{'is_last'};
        my $size = $payload->{'size'};
        my $is_blocking = $payload->{'is_blocking'};
        my $msg_id = $payload->{'msg_id'};
        my $bytes = $payload->{'bytes'};
# FIXME : do we always have a $header{'msg_type'} ??
# FIXME : OOB or protocol layer data?
    my $o = {
        'is_blocking' => $is_blocking,
        'is_last' => $is_last,
        'msg_id' => $msg_id,
        'size' => $size,
        'ait_dense' => $b0, # NORMAL(40), AIT(04)
        'port_byte' => $b1,
    };
    return ($hint, $real_uuid, $bitmask, $o, $bytes);
}

# --
# ait byte coding

# binary (octet) to name (string)
sub ait_name {
    my ($octet) = @_;
    my $ait_dense = sprintf("%02x", $octet);
    my $name = $ait_code->{$ait_dense};
    print DBGOUT (join(' ', 'bad ait code:"'.$ait_dense.'"'), $endl) unless $name;
    return $name;
}

# name to ait_dense/hex (string)
sub ait_unname {
    my ($name) = @_;
    return undef unless $name;
    foreach my $key (keys %{$ait_code}) {
        my $value = $ait_code->{$key};
        return $value if $name eq $value;
    }
    print DBGOUT (join(' ', 'bad ait name:"'.$name.'"'), $endl) unless $name;
    return undef;
}

# ait_dense/hex (string) to struct
sub ait_decode {
    my ($ait_dense) = @_;
    my $octet = hex('0x'.$ait_dense);
    my $dir = ($octet & 0x80) ? 'REVERSE' : 'FORWARD'; # ait_name - FORWARD/TICK ??
    my $flavor = ait_name($octet & 0x44);
    my $state = ait_name($octet & 0x03);
    return ($dir, $flavor, $state);
}

# --
# ait state sequence:

# cycle AIT state machine - ait_dense/hex (string) to name (string)
sub ait_next {
    my ($ait_dense) = @_;
    my ($dir, $flavor, $state) = ait_decode($ait_dense);
    return $ait_forward->{$state} if $dir eq 'FORWARD';
    return $ait_backward->{$state} if $dir eq 'REVERSE';
    return undef;
}

# --
# PE model

my %pe_workers; # map : cell_id => object

# phy - ports/links
sub get_worker {
    my ($cell_id) = @_;
    my $w = $pe_workers{$cell_id};
    return $w if $w;

    my $o = {
        'pe_id' => $cell_id, # debug
        'block' => undef,
        'table' => {},
        'phy' => [],
    };
    $pe_workers{$cell_id} = $o;
    return $o;
}

# phy enqueue C:1 2 TOCK 0x400074367c704351baf6176ffc4e1b6a msg_id=9060533230310021231 7b226d7367... ;
sub phy_enqueue {
    my ($pe_id, $outbound, $ait_code, $tree, $msg_id, $frame) = @_;
    print(join(' ', '   ', 'phy enqueue', $pe_id, $outbound, $ait_code, $tree, 'msg_id='.$msg_id, substr($frame, 0, 10).'...', ';'));
    my $o = {
        'pe_id' => $pe_id,
        'outbound' => $outbound,
        'ait_code' => $ait_code,
        'tree' => $tree,
        'msg_id' => $msg_id,
        'frame' => $frame,
    };
    my $meta = encode_json($o);
    print FRAMEOUT ($meta, $endl);
}

## PE-API C:2 1536648431721208 Entry [update] 0x400071e6f02749b68332b65273f36051 73f36051 Yes Yes 0 0000000000000010
## PE -API C:2 1536648431721890 Packet 73f36051 0x400071e6f02749b68332b65273f36051 0000000000000010 {"is_last":true,"size":649,"ait_dense":"04","is_blocking":false,"msg_id":2198900630282842901,"port_byte":"00"} octets=227661726961626c65735c223a5b5d7d7d7d227d...

# special processing
sub eccf_ait {
    my ($pe_worker, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    # post event to PE at other end of edge
    my $route = encode_json($entry);
    my $meta = encode_json($o);
    print DBGOUT (join(' ', 'multicast', $pe_id, $bitmask, $tree, $route), $endl);
    print DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};

    my $ait_dense = $o->{'ait_dense'};
    my $ait_state = ait_next($ait_dense);
    my $ait_code = ait_unname($ait_state);

    print DBGOUT (join(' ', 'bad ait?', $ait_dense, $ait_state), $endl) unless $ait_code;

    my $route_mask = $entry->{'mask'}{'mask'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)
    my $port_mask = ($limit_mask & $route_mask);
# FIXME : going up ??
    for my $i (0..$maxport) {
        my $bit = 1 << $i;
        next unless $port_mask & $bit;
        phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
    }
}

# forward
sub eccf_normal {
    my ($pe_worker, $port_no, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)

    # post event to PE at other end of edge
    my $route = encode_json($entry);
    my $meta = encode_json($o);
    print DBGOUT (join(' ', 'multicast', $pe_id, $port_no, $tree, $route), $endl);
    print DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};

    my $parent = $entry->{'parent'};
    my $route_mask = $entry->{'mask'}{'mask'};
    my $port_mask = ($limit_mask & $route_mask);

    # Leafward
    if ($port_no == $parent) {
# FIXME : going up ??
        for my $i (0..$maxport) {
            my $bit = 1 << $i;
            next unless $port_mask & $bit;
            my $ait_code = 'NORMAL';
            phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
    # RootWard
    else {
        if ($parent) {
# FIXME : is 'ports' all ports or just phy-ports?
# FIXME : going up ??
            for my $i (0..$maxport) {
                my $bit = 1 << $i;
                next unless $port_mask & $bit;
                my $ait_code = 'NORMAL';
                phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
            }
        }
        # fallsthru
        my $going_up = ($port_mask == $cm_bitmask);
        if (!$parent || $going_up) {
# FIXME : going up ??
            # ca.enqueue()
            my $i = 0;
            my $ait_code = 'NORMAL';
            phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
}

sub xmit_eccf_frame {
    my ($pe_worker, $real_uuid, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $table = $pe_worker->{'table'};
    my $entry = $table->{$real_uuid};
    print DBGOUT (join(' ', 'table miss?', $pe_id, $real_uuid, Dumper $table), $endl) unless $entry;

    my $ait_dense = $o->{'ait_dense'};

    # AIT(04)
    if ($ait_dense eq '04') {
        eccf_ait($pe_worker, $real_uuid, $entry, $bitmask, $o, $frame);
    }

    # NORMAL(40)
    if ($ait_dense eq '40') {
        my $port_no = 0;
        eccf_normal($pe_worker, $port_no, $real_uuid, $entry, $bitmask, $o, $frame);
    }
}

sub xmit_tcp_frame {
    my ($pe_worker, $port_no, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $ait_code = 'NORMAL';
    my $tree = $null_uuid;
    my $msg_id = 0;
    phy_enqueue($pe_id, $port_no, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
    # 'ROOTWARD'
}

# ugh. special case handling of rust 'match' complicates things:
# reverse-engineer arg-list (0, 1, n)

## CmToPePacket::Unblock => {
## CmToPePacket::Entry(entry) => {
## CmToPePacket::Packet((user_mask, mut packet)) => {
## CmToPePacket::Tcp((port_number, msg)) => {

## listen_cm_loop C:1 raw-api Unblock ;
## listen_cm_loop C:2 raw-api Entry ref=HASH ;
## listen_cm_loop C:2 raw-api Packet HASH(0x7fde9b268610) HASH(0x7fde9b268628) ;
## listen_cm_loop C:2 raw-api Tcp HASH(0x7fde9a00bf38) ARRAY(0x7fde9a00bf50) ;
sub pe_api {
    my ($cell_id, $tag, @args) = @_;
    print(join(' ', $cell_id, 'pe-raw-api', $tag, @args, ';'));

    print DBGOUT (join(' ', 'PE-API', $cell_id, $epoch_global, $tag, ''));

    my $pe_worker = get_worker($cell_id);

    if ($tag eq 'Unblock') {
        my $was = $pe_worker->{'block'};
        $pe_worker->{'block'} = undef;
        print DBGOUT ('was='.($was ? 'true' : 'false'), $endl);
        return;
    }

    if ($tag eq 'Entry') {
        my ($entry) = @args;
        my $uuid = $entry->{'tree_uuid'};
        my $hex_guid = lc(xlate_uuid($uuid));
        my $table = $pe_worker->{'table'};
        my $current_entry = $table->{$hex_guid};
        $table->{$hex_guid} = $entry;
        print DBGOUT (join(' ', ($current_entry) ? '[update]' : '[create]', $hex_guid, dump_entry($entry)), $endl);
        return;
    }

    if ($tag eq 'Packet') {
        my ($user_mask, $packet) = @args;
        my ($hint, $real_uuid, $bitmask, $o, $frame) = dump_packet($user_mask, $packet);
        my $meta = encode_json($o);
        my $some = substr($frame, -40).'...';
        print DBGOUT (join(' ', $hint, $real_uuid, $bitmask, $meta, 'octets='.$some), $endl);
        xmit_eccf_frame($pe_worker, $real_uuid, $bitmask, $o, $frame);
        return;
    }

# pub type TCP = (ISAIT, AllowedTree, TcpMsgType, MsgDirection, ByteArray);
    if ($tag eq 'Tcp') {
        my ($port_number, $msg) = @args;
        my $port_no = $port_number->{'port_no'};
        my @tcpargs = @{$msg}; # $#tcpargs is 4
        my $isAit = $tcpargs[0]; # 'JSON::PP::Boolean'
        my $allowed_tree = $tcpargs[1]; # object
        my $tcp_msg_type = $tcpargs[2]; # String : Application, DeleteTree, Manifest, Query, StackTree, TreeName
        my $dir = $tcpargs[3]; # String : Rootward/Leafward
        my $octets = $tcpargs[4]; # u8[]

        my $body_dense = bytes2dense($octets);
print DBGOUT (join(' ', 'Tcp', $isAit ? 'AIT' : 'NORMAL', $allowed_tree->{'name'}, $tcp_msg_type, $dir), $endl);
# FIXME:
        my $str = encode_json($msg);
        my $frame = unpack("H*",  $str); # ascii_to_hex
        my $some = substr($frame, -40).'...';
        print DBGOUT (join(' ', $port_no, $some), $endl);
        xmit_tcp_frame($pe_worker, $port_no, $frame);
        return;
    }

    print DBGOUT ('unknown tag?', $endl);
}

# /body : OBJECT { cell_id msg }
# 'packet_engine.rs$$listen_cm_loop$$Trace$$recv'
sub meth_recv {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $rkind = ref($msg);

    # no args
    if ($rkind eq '') {
        my $tag = $msg;
        # print(join(' ', $cell_id, 'raw-api', $tag, ';'));
        pe_api($cell_id, $tag);
        return;
    }

    if ($rkind eq 'HASH') {
        my @kind = keys %{$msg};

        # huh?
        if ($#kind != 0) {
            print(join(' ', $cell_id, 'raw-api obj', 'keyset=', @kind, ';'));
            return;
        }

        my $tag = pop @kind;
        my $args = $msg->{$tag};
        my $akind = ref($args);
        # 1 arg
        if ($akind eq 'HASH') {
            # print(join(' ', $cell_id, 'raw-api', $tag, $args, ';'));
            pe_api($cell_id, $tag, $args);
            return;
        }
        # multi args
        if ($akind eq 'ARRAY') {
            # print(join(' ', $cell_id, 'raw-api', $tag, @{$args}, ';'));
            pe_api($cell_id, $tag, @{$args});
            return;
        }

        # huh?
        print(join(' ', $cell_id, 'raw-api obj', 'akind='.$akind, $msg, ';'));
        return;
    }

    # huh?
    print(join(' ', $cell_id, 'raw-api', 'rkind='.$rkind, $msg, ';'));
}

# /body : OBJECT { msg_type tree_name }
# 'main.rs$$listen_port_loop$$Trace$$noc_from_ca'
# { 'tree_name' => 'Base', 'msg_type' => 'TreeName' };
sub meth_noc_from_ca {
    my ($body) = @_;
    my $msg_type = $body->{'msg_type'};
    my $tree_name = $body->{'tree_name'};
    print(join(' ', $msg_type, $tree_name, ';'));
}

# --

## IMPORTANT : why ?
# /body : OBJECT { ... }
# ''
sub meth_xx {
    my ($body) = @_;
    my $xx = 0;
    print(join(' ', $xx, ';'));
}

# --
# NEW

# /body : OBJECT { cell_id }
# 'cellagent.rs$$listen_cm$$Debug$$ca_listen_cm'
sub meth_ca_listen_cm {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# --

# /body : OBJECT { cell_id }
# 'cellagent.rs$$listen_cm$$Debug$$ca_listen_pe'
sub meth_ca_listen_pe_cmodel {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id msg  }
# 'cmodel.rs$$listen_ca_loop$$Debug$$cm_bytes_from_ca'
sub meth_cm_bytes_from_ca {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $summary, ';'));

    # FIXME
    my $tree_id = nametype($body->{'missing'});
    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-snd';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg  }
# 'cmodel.rs$$process_packet$$Debug$$cm_bytes_to_ca'
sub meth_cm_bytes_to_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $summary, ';'));
}

# /body : OBJECT { cell_id msg_type tree_id }
# 'packet_engine.rs$$listen_cm_loop$$Debug$$pe_packet_from_cm'
sub meth_pe_packet_from_cm {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $tree_id = nametype($body->{'tree_id'});
    print(join(' ', $cell_id, $msg_type, $tree_id, ';'));

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $msg = $body->{'msg'};
    my $header = $msg->{'header'};
    my $payload = $msg->{'payload'};
    #my $msg_type = $header->{'msg_type'};

    my $c = $cell_id; $c =~ s/C://;
    my $virt_p = 0;
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $virt_p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# Cell Agent Control Plane - msg processing (ie. worker)
# Leafward => micro service request (set)
# Rootward => response to application/client (singleton)

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg }
# 'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg'
sub meth_ca_got_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $summary = summarize_msg($msg);
    print(join(' ', $cell_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $payload = $msg->{'payload'};
    my $tree_id = nametype($payload->{'tree_id'});
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

## IMPORTANT : Forest/DiscoverD
# /body : OBJECT { cell_id port_no msg  }
# 'cellagent.rs$$listen_cm_loop$$Debug$$ca_got_msg'
#
# parent :    /body/cell_id: NAME_TYPE                # "C:0"
# link :      /body/port_no : PORT_DESC               # - relative to this node, aka parent
# msg_type :  /body/msg/header/msg_type : String      # "DiscoverD"
# child :     /body/msg/header/sender_id : NAME_TYPE  # "Sender:C:1+CellAgent"
# span-tree : /body/msg/payload/tree_id : NAME_TYPE   # "Tree:C:0"
sub meth_ca_got_msg_cmodel {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $msg = $body->{'msg'};
    my $summary = summarize_msg($msg);
    print(join(' ', $cell_id, $port_no, $summary, ';'));

    my $p = port_index($body->{'port_no'});
    my $payload = $msg->{'payload'};
    my $tree_id = nametype($payload->{'tree_id'});

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $p, $body, $key);

    my $c = $cell_id; $c =~ s/C://;
    my $header = $msg->{'header'};
    my $msg_type = $header->{'msg_type'};
    my $sender_id = nametype($header->{'sender_id'});
    do_treelink($c, $p, $tree_id, $sender_id) if $msg_type eq 'DiscoverD';
    do_treelink($c, $p, $tree_id, $sender_id) if $msg_type eq 'StackTreeD';
    do_application($c, $p, $tree_id, $sender_id) if $msg_type eq 'Application';
    do_manifest($c, $p, $tree_id, $sender_id) if $msg_type eq 'Manifest';
}

sub do_manifest {
    my ($c, $p, $tree_id, $sender_id) = @_;
    my $direction;
    print DBGOUT (join(' ', 'MANIFEST:', 'C'.$c.'p'.$p, $tree_id, $sender_id), $endl);
}

my $note1 = << '_eor_';

MANIFEST: C0p2  Sender:C:2+BorderPort+2
MANIFEST: C1p2  Sender:C:2+BorderPort+2
MANIFEST: C2p0  Sender:C:2+BorderPort+2


    "direction": "Leafward",
    "tree_map": {
        "NocAgentMaster": { "name": "Tree:C:2+NocAgentMaster", "uuid": { "uuid": [ 9408345567043698430, 0 ] } },
        "NocMasterAgent": { "name": "Tree:C:2+NocMasterAgent", "uuid": { "uuid": [ 46690252040399963, 0 ] } }
    }

    "tree_name": { "name": "NocAgentDeploy" }
    "deploy_tree_id": { "name": "Tree:C:2+NocAgentDeploy", "uuid": { "uuid": [ 2354389112903126494, 0 ] } },
    "manifest": {
        "id": "NocAgent",
        "cell_config": "Large",
        "trees": [ { "id": "NocAgent", "parent_list": [ 0 ] } ],
        "deployment_tree": { "name": "NocAgentDeploy" },
        "allowed_trees": [ { "name": "NocMasterAgent" }, { "name": "NocAgentMaster" } ],
        "vms": [ {
                "id": "vm1",
                "required_config": "Large",
                "image": "Ubuntu",
                "trees": [ { "id": "NocAgent", "parent_list": [ 0 ] } ]
                "allowed_trees": [ { "name": "NocMasterAgent" }, { "name": "NocAgentMaster" } ],
                "containers": [ {
                        "id": "NocAgent", "image": "NocAgent", "params": []
                        "allowed_trees": [ { "name": "NocMasterAgent" }, { "name": "NocAgentMaster" } ],
                } ],
        } ]
    },

_eor_

sub do_application {
    my ($c, $p, $tree_id, $sender_id) = @_;
    my $direction;
    print DBGOUT (join(' ', 'APPLICATION:', 'C'.$c.'p'.$p, $tree_id, $sender_id), $endl);
}

my $note2 = << '_eor_';

APPLICATION: C0p2 Tree:C:2+NocMasterAgent Sender:C:2+VM:C:2+vm1
APPLICATION: C1p2 Tree:C:2+NocMasterAgent Sender:C:2+VM:C:2+vm1
APPLICATION: C2p1 Tree:C:2+NocAgentMaster Sender:C:0+VM:C:0+vm1
APPLICATION: C2p3 Tree:C:2+NocAgentMaster Sender:C:1+VM:C:1+vm1

    do_treelink 2 1 Tree:C:2+NocAgentDeploy Sender:C:2+BorderPort+2
    do_treelink 2 3 Tree:C:2+NocAgentDeploy Sender:C:2+BorderPort+2
    do_treelink 2 1 Tree:C:2+NocMasterAgent Sender:C:2+BorderPort+2
    do_treelink 2 3 Tree:C:2+NocMasterAgent Sender:C:2+BorderPort+2

_eor_

sub do_treelink {
    my ($c, $p, $tree_id, $sender_id) = @_;
    # print STDERR (join(' ', 'do_treelink', $c, $p, $tree_id, $sender_id), $endl);

    ## Forest / DiscoverD
    my ($xtag, $cc, $child, $remain) = split(/[\+:]/, $sender_id);
epoch_marker();
    add_tree_link($tree_id, $c, $p, $child);
}

sub add_tree_link {
    my ($tree_id, $c, $p, $child) = @_;

    my $link_no = get_link_no($c, $p);
    my $root;
    {
        my ($x, $y, $c) = split(':', $tree_id);
        $root = $c;
        $root = $y unless defined $root;
        print STDERR (join(' ', 'WARNING: parse error', $tree_id, $link_no), $endl) unless defined $root;
    }
    $tree_id =~ s/C:/C/;

    my $o = {
        'span_tree' => $tree_id,
        'parent' => 'C'.$c,
        'p' => $p,
        'child' => 'C'.$child,
        'root' => $root,
        'link_no' => $link_no
    };
    my $k = $max_forest++;
    $forest{$k} = $o;
}

# C1 -> C0:p1 [label="Tree:C0" color=red]
sub dump_forest {
    my $path = $result_dir.$forestfile;
    open(FOREST, '>'.$path) or die $path.': '.$!;
    print FOREST ('digraph G {', $endl);
    print FOREST ('rankdir=LR', $endl);
    # print FOREST (join(' ', 'span-tree', 'parent', 'link', 'child'), $endl);
    foreach my $k (sort order_forest keys %forest) {
        my $o = $forest{$k};
        my $parent = $o->{'parent'};
        my $child = $o->{'child'};
        my $span_tree = $o->{'span_tree'};
        my $port = $o->{'p'};
        my $link_no = $o->{'link_no'};

{
        # child is other side of link!
        my $compass = $link_no % 2;
        my $edge_no = int($link_no / 2);
        my $e = find_edge($edge_no);
        my $lc = $e->{'left_cell'};
        my $lp = $e->{'left_port'};
        my $rc = $e->{'right_cell'};
        my $rp = $e->{'right_port'};
        giveup('bad link') if ($lc == -1); # 'Internet'
        my $left = 'C'.$lc.':p'.$lp;
        my $right = 'C'.$rc.':p'.$rp;
        $child = ($compass) ? $left : $right;
}
        my $dst_link = $parent.':p'.$port;
        my $src_link = $child;

        my $left = $src_link;
        my $right = $dst_link;
        my $label = $span_tree;
        my $color = pick_color($span_tree);

        my $attrs = '[label="'.$label.'" color='.$color.']';
        print FOREST (join(' ', $left, '->', $right, $attrs), $endl);
    }
    print FOREST ('}', $endl);
    close(FOREST);
}

sub order_forest($$) {
    my ($left, $right) = @_;
    my $l_tree = $forest{$left}{'span_tree'};
    my $r_tree = $forest{$right}{'span_tree'};
    return $l_tree cmp $r_tree unless $l_tree eq $r_tree;

    my $l = $forest{$left}{'child'};
    my $r = $forest{$right}{'child'};
    # return $l <=> $r;
    return $l cmp $r;
}

# /body : OBJECT { cell_id msg_type port_nos }
# 'cellagent.rs$$forward_saved_manifest$$Debug$$ca_forward_saved_msg'
sub meth_ca_forward_saved_msg_manifest {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# /body : OBJECT { cell_id msg_type port_nos }
# 'cellagent.rs$$forward_saved_application$$Debug$$ca_forward_saved_msg'

sub meth_ca_forward_saved_msg_application {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# --

sub get_cellagent_port {
    my ($c) = @_;
    my $edge_no = $cell_table{$c};
    return $edge_no;
}

# graphviz format (note :pX is magic)
sub get_link_no {
    my ($c, $p) = @_;
    my $k = 'C'.$c.':p'.$p;
    return $link_table{$k};
}

# indicate EAST/WEST direction (a, a')
# do that with even/odd numbers
# ISSUE : knows direction, so key really matters (don't allow both!)
# could canonicalize by sorting cell numbers (uuid)
sub edge_table_entry {
    my ($lc, $lp, $rc, $rp) = @_;
    my $k1 = 'C'.$lc.':p'.$lp; $k1 = 'Internet' if $lc == -1;
    my $k2 = 'C'.$rc.':p'.$rp;
    my $edge_key = $k1.'->'.$k2;
    my $edge = {
        'left_cell' => $lc,
        'left_port' => $lp,
        'right_cell' => $rc,
        'right_port' => $rp,
        'edge_no' => 0 # illegal value
    };
    # not threadsafe: conditionally stores object, then updates it.
    $edges{$edge_key} = $edge unless defined $edges{$edge_key};
    my $o = $edges{$edge_key};
    if ($o->{'edge_no'} == 0) {
        my $edge_no = $max_edge ; $max_edge++; # allocate
        $o->{'edge_no'} = $edge_no;
        # this could be done with edge_no, and then checking the edge object for which end the cell/port is
        my $link_no = $edge_no * 2;
        $link_table{$k1} = $link_no;
        $link_table{$k2} = $link_no + 1;
    }
    return $o->{'edge_no'};
}

sub cell_table_entry {
    my ($c) = @_;
    $max_cell = $c if $c > $max_cell;
    return $cell_table{$c} if $cell_table{$c};

    my $edge_no = edge_table_entry($c, 0, $c, 0); # virtual port #0
    my $k = 'C'.$c.':p0';
    $cell_table{$c} = $edge_no;
    return $edge_no;
}

sub activate_edge {
    my ($lc, $lp, $rc, $rp) = @_;
    my $edge_no = edge_table_entry($lc, $lp, $rc, $rp);
    my $c1_up = cell_table_entry($lc);
    my $c2_up = cell_table_entry($rc);
    # write_edge($lc, $lp, $rc, $rp, $edge_no);
}

# Internet+C:1+P:2
sub border_port {
    my ($cell_id, $port_no) = @_;
    my ($tag, $c) = split(':', $cell_id);
    my $port_index = $port_no; $port_index =~ s/[^\d]//g;
    my $edge_no = edge_table_entry(-1, 0, $c, $port_index);
    my $c_up = cell_table_entry($c);
    # write_border($c, $port_index, $edge_no);
}

# SEQ OF OBJECT { v }
sub build_port_list {
    my ($port_nos) = @_;
    return '' unless defined $port_nos;
    return '['.join(',', map { portdesc($_) } @{$port_nos}).']';
}

# /msg/header/direction
# /msg/header/msg_type
# /msg/header/sender_id
# /msg/payload/gvm_eqn
# /msg/payload/manifest
sub summarize_msg {
    my ($msg) = @_;
    return '' unless defined $msg;

    my $header = $msg->{'header'};
    my $direction = $header->{'direction'};
    my $msg_type = $header->{'msg_type'};
    my $sender_id = $header->{'sender_id'}{'name'};

    my $payload = $msg->{'payload'};
    my $gvm_eqn = $payload->{'gvm_eqn'};
    my $manifest = $payload->{'manifest'};

    my $payload_hash = note_value(\%msg_table, $payload);
    my $gvm_hash = note_value(\%gvm_table, $gvm_eqn);
    my $man_hash = note_value(\%manifest_table, $manifest);

    my $hint = substr($payload_hash, -5);
    my $opt_gvm = defined($gvm_hash) ? substr($gvm_hash, -5) : '';
    my $opt_manifest = defined($man_hash) ? substr($man_hash, -5) : '';
    return join('%%', $hint, $direction, $msg_type, $sender_id, 'gvm='.$opt_gvm, 'manifest='.$opt_manifest);
}

sub construct_key {
    my ($hdr, $lineno) = @_;
    my $thread_id = $hdr->{'thread_id'};
    my $event_id = $hdr->{'event_id'};
    my $line_tag = $hdr->{'_lineno'}; $lineno = $line_tag if $line_tag;
    $event_id = e_massage($event_id);
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
}

sub ec_fromkey {
    my ($key) = @_;
    my ($l1, $l2, $l3) = split('::', $key);
    return $l3; # aka lineno
}

# incompatible interface change!!
sub e_massage {
    my ($event_id) = @_;
    return $event_id unless ref($event_id); # old : scalar / number

    my $xxx = join('.', 'v', @{$event_id}); # new : seq of number (array)
    return $xxx;
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

# accumulate $jschema
# JSON::is_bool
sub walk_structure {
    my ($path, $json) = @_;
    my $rkind = ref($json);
    $jschema{$path}++ unless $rkind;
    return unless $rkind;
    if ($rkind eq 'HASH') {
        # special case: include type
        my $jtype = ' : OBJECT { '.join(' ', sort keys %{$json}).' }';
        $jschema{$path.$jtype}++;
        foreach my $tag (keys %{$json}) {
            $keyset{$tag}++;
            my $nested = $path.'/'.$tag;
            ## $jschema{$nested}++;
            walk_structure($nested, $json->{$tag});
        }
        return;
    }
    if ($rkind eq 'ARRAY') {
        my @ary = @{$json};
        # special case: include type
        my $jtype = ' : ARRAY len='.($#ary+1);
        $jschema{$path.$jtype}++;
        foreach my $val (@ary) {
            my $nested = $path.'[]';
            ## $jschema{$nested}++;
            walk_structure($nested, $val);
        }
        return;
    }
    if ($rkind eq 'JSON::PP::Boolean') {
        # special case: include type
        $jschema{$path.' : BOOLEAN'}++;
        return;
    }

    giveup(join(' ', 'unknown object type:', $rkind));
}

# by frequency, descending
sub dump_histo {
    my ($hdr, $href) = @_;
    print SCHEMA ($endl);
    print SCHEMA ($hdr, $endl);
    foreach my $item (sort { $href->{$b} <=> $href->{$a} } keys %{$href}) {
        print SCHEMA (join(' ', $href->{$item}, $item), $endl);
    }
}

# --

my @mformats = qw(
    DEAD:
    'noc.rs$$MAIN$$Trace$$trace_schema'
    'noc.rs$$initialize$$Trace$$trace_schema'
    'nalcell.rs$$start_cell$$Trace$$nal_cellstart_ca'
    'packet_engine.rs$$listen_ca$$Debug$$listen_ca'
    'packet_engine.rs$$listen_port$$Debug$$pe_msg_from_ca'

    OCCUR:
    'main.rs$$MAIN$$Trace$$trace_schema'

    'datacenter.rs$$initialize$$Trace$$border_cell_start'
    'datacenter.rs$$initialize$$Trace$$connect_link'
    'datacenter.rs$$initialize$$Trace$$interior_cell_start'

    'cellagent.rs$$port_connected$$Trace$$ca_send_msg'

    'cellagent.rs$$add_saved_discover$$Debug$$ca_save_discover_msg'
    'cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg'
    'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg'
    'cellagent.rs$$deploy$$Debug$$ca_deploy'
    'cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg'
    'cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg'
    'cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id'
    'cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs'
    'cellagent.rs$$listen_pe$$Debug$$ca_listen_pe'
    'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg'
    'cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm'
    'cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree'
    'cellagent.rs$$process_application_msg$$Debug$$ca_process_application_msg'
    'cellagent.rs$$process_discover_msg$$Debug$$ca_process_discover_msg'
    'cellagent.rs$$process_discoverd_msg$$Debug$$ca_process_discover_d_msg'
    'cellagent.rs$$process_manifest_msg$$Debug$$ca_process_manifest_msg'
    'cellagent.rs$$process_stack_tree_msg$$Debug$$ca_process_stack_tree_msg'
    'cellagent.rs$$process_stack_treed_msg$$Debug$$ca_process_stack_tree_d_msg'
    'cellagent.rs$$send_msg$$Debug$$ca_send_msg'
    'cellagent.rs$$stack_tree$$Debug$$ca_stack_tree'
    'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg'
    'cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg'
    'cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg'
    'cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map'
    'cellagent.rs$$update_traph$$Debug$$ca_update_traph'
    'cellagent.rs$$update_traph$$Debug$$ca_updated_traph_entry'
    'nalcell.rs$$new$$Trace$$nalcell_port_setup'
    'nalcell.rs$$start_cell$$Trace$$nalcell_start_ca'
    'nalcell.rs$$start_packet_engine$$Trace$$nalcell_start_pe'
    'packet_engine.rs$$forward$$Debug$$pe_forward_leafward'
    'packet_engine.rs$$forward$$Debug$$pe_forward_rootward'
    'packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca'
    'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca'
    'packet_engine.rs$$listen_port$$Debug$$pe_listen_ports'
    'packet_engine.rs$$process_packet$$Debug$$pe_process_packet'

    NEW:
    'cellagent.rs$$forward_saved_application$$Debug$$ca_forward_saved_msg'
    'cellagent.rs$$forward_saved_manifest$$Debug$$ca_forward_saved_msg'
    'cellagent.rs$$listen_cm$$Debug$$ca_listen_pe'
    'cellagent.rs$$listen_cm_loop$$Debug$$ca_got_msg'
    'cmodel.rs$$listen_ca_loop$$Debug$$cm_bytes_from_ca'
    'cmodel.rs$$process_packet$$Debug$$cm_bytes_to_ca'
    'packet_engine.rs$$listen_cm_loop$$Debug$$pe_packet_from_cm'

    'packet_engine.rs$$listen_cm_loop$$Debug$$pe_forward_leafward'
);

sub bytes2dense {
    my ($u8) = @_;
    return undef unless $u8;
    my $dense = '';
    foreach my $ch (@{$u8}) {
        my $doublet = sprintf('%02x', $ch);
        $dense = $dense.$doublet;
    }
    print($dense, $endl);
    return $dense;
}

sub frame2obj {
    my ($frame) = @_;
    my $json_text = pack('H*', $frame); # hex_to_ascii
    my $o = decode_json($json_text);
    print($json_text, $endl);
    return $o;
}

my $notes = << '_eof_';

# name patterns:

"C:[0-9]*"
"VM:C:[0-9]*+vm[0-9]*"
"Sender:C:[0-9]*+VM:C:[0-9]*+vm[0-9]*"

# --

# use JSON::MaybeXS;
# $json = $json->ascii([$enable])
# $json = $json->latin1([$enable])
# $json = $json->utf8([$enable])
# $json = $json->relaxed([$enable])
# $json = $json->canonical([$enable])

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

"#ffffff", "#ff0000", "#00ff00", "#0000ff", // white(#ffffff), red(#ff0000), green(#00ff00), blue(#0000ff)
"#000000", "#00ffff", "#ff00ff", "#ffff00", // black(#000000), cyan(#00ffff), magenta(#ff00ff) yellow(#ffff00)
"#c0c0c0",  // silver(#c0c0c0)
"#000080", "#008000", "#800000", // navy, green (old), maroon
"#808000", "#800080", "#008080", // olive, purple, teal
"#808080", // gray
// lime=green
// aqua=cyan
// fuchsia=magenta

# --

sample-data/multicell-trace-distributed-1533085651118541.json.gz
sample-data/multicell-trace-triangle-1530634503352636.json.gz

CellAgent$$cellagent.rs$$forward_stack_tree$$ca_forward_stack_tree_msg$$Debug

/ : OBJECT { body header } ;;

/header : OBJECT { epoch event_id format function module repo thread_id trace_type } ;;
    /header/epoch : SCALAR ;;
    /header/event_id : SEQ OF ;;
    /header/event_id[] : SCALAR ;;
    /header/format : SCALAR ;;
    /header/function : SCALAR ;;
    /header/module : SCALAR ;;
    /header/repo : SCALAR ;;
    /header/thread_id : SCALAR ;;
    /header/trace_type : SCALAR

/body : OBJECT { cell_number } ;; /body/cell_number : SCALAR ;;
/body : OBJECT { schema_version } ;; /body/schema_version : SCALAR ;;

--

/body : OBJECT { left_cell left_port link_id rite_cell rite_port }

cell_id:

/body : OBJECT { ait_state entry msg_type port_no tree_id }
/body : OBJECT { ait_state msg_type port_nos tree_id }
/body : OBJECT { ait_state msg_type tree_id }
/body : OBJECT { allowed_tree direction msg_type tcp_msg }
/body : OBJECT { base_tree_id base_tree_map_keys base_tree_map_values new_tree_id }
/body : OBJECT { base_tree_id children gvm hops other_index port_number port_status }
/body : OBJECT { base_tree_id children gvm hops port_number port_status }
/body : OBJECT { base_tree_id entry }
/body : OBJECT { base_tree_id stacked_tree_id }
/body : OBJECT { deploy_tree_id msg }
/body : OBJECT { deployment_tree_id tree_vm_map_keys up_tree_name }
/body : OBJECT { entry msg new_tree_id }
/body : OBJECT { entry msg_type port_no tree_id }
/body : OBJECT { is_border port_no }
/body : OBJECT { msg new_tree_id port_no }
/body : OBJECT { msg no_saved tree_id }
/body : OBJECT { msg port_no save tree_id }
/body : OBJECT { msg port_no tree_id }
/body : OBJECT { msg port_no }
/body : OBJECT { msg port_nos tree_id }
/body : OBJECT { msg tree_id }
/body : OBJECT { msg }
/body : OBJECT { msg_type port_nos tree_id }
/body : OBJECT { msg_type port_nos }
/body : OBJECT { msg_type tree_id }
/body : OBJECT { no_saved_msgs tree_id }
/body : OBJECT { sender_id vm_id }
/body : OBJECT { tree_id }
/body : OBJECT { }

# my $s = 'Hello World';
# my $x1 = unpack("H*",  $s); # ascii_to_hex
# my $s = pack('H*', $x1); # hex_to_ascii

_eof_
