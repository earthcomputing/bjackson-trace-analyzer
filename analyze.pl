#!/usr/bin/perl -w
# analyze xx.json
## A microservice is not a 'subroutine' !!

# TODO :
# JSON::MaybeXS
# python -mjson.tool

use strict;

use lib '/Users/bjackson/perl5/lib/perl5';
use JSON qw(decode_json encode_json); # From CPAN
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Data::GUID;

my $ALAN;
my $code_filter;
my $debug;
my $dump_tables; # = 1;

my $endl = "\n";
my $dquot = '"';
my $blank = ' ';

my $op_table = {
    'Application' => 'A',
    'Discover' => 'D',
    'DiscoverD' => 'DD',
    'Manifest' => 'M',
    'StackTree' => 'S',
    'StackTreeD' => 'SD'
};

my $arrow_code = {
    'cell-snd' => '>',
    'pe-rcv' => '<-',
    'pe-snd' => '->'
};

my $max_cell = -1;
my %cell_table;

# link name map : 'Cx:py' -> 'link#z';
my $max_link = 1; # avoid 0 ## 2
my %link_table;

my %routing_table;
my %msg_table;

my @msgqueue;

my %verb;
my %jschema;
my %keyset;

if ( $#ARGV < 0 ) {
    print('usage: [-dump] [-ALAN] [-filter=C:2] analyze xx.json ...', $endl);
    exit -1
}

# FIXME : one dot file for list of inputs
my $dotfile = '/tmp/complex.dot';
open(DOT, '>'.$dotfile) or die $!;
print DOT ('digraph G {', $endl);
print DOT ('rankdir=LR', $endl);

my $schemafile = '/tmp/schema-data.txt';
open(SCHEMA, '>'.$schemafile) or die $!;
foreach my $file (@ARGV) {
    if ($file eq '-dump') { $dump_tables = 1; next; }
    if ($file eq '-ALAN') { $ALAN = 1; next; }
    if ($file =~ /-filter=/) { my ($a, $b) = split('=', $file); $code_filter = $b; next; }
    print($endl, $file, $endl);
    my $href = process_file($file);
    do_analyze($href);
    dump_histo('VERBS:', \%verb);
}

# FIXME - localize 'DOT'
# dump_link_table();
dump_cell_table();
print DOT ('}', $endl);
close(DOT);

dump_routing_tables();
dump_msgs();
msg_sheet();

dump_histo('SCHEMA:', \%jschema);
dump_histo('KEYSET:', \%keyset);
close(SCHEMA);
exit 0;

# --

sub update_routing_table {
    my ($cell_id, $entry) = @_;
    my $key = $entry->{'index'};
    # my $key = $entry->{'tree_uuid'};
    $routing_table{$cell_id} = { '0' => 0 } unless defined $routing_table{$cell_id};
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
    my $word0 = $ref->{'uuid'}[0];
    my $word1 = $ref->{'uuid'}[1];
    my $str = sprintf("0x%016x%016x", $word1, $word0);
    my $guid = Data::GUID->from_hex($str);
    my $hex_guid = $guid->as_hex;
    return lc(substr($hex_guid, -8));
}

sub dump_routing_tables {
    my $file = '/tmp/routing-table.txt';
    open(FD, '>'.$file) or die $!;
    foreach my $cell_id (sort keys %routing_table) {
        print FD ($endl);
        print FD (join(' ', $cell_id, 'Routing Table'), $endl);

        my $routes = $routing_table{$cell_id};
        foreach my $key (sort { $a cmp $b } keys %{$routes}) {
            my $entry = $routes->{$key};
            my $index = $entry->{'index'};
            my $hint = hint4uuid($entry->{'tree_uuid'});
            my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
            my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
            my $parent = $entry->{'parent'}{'v'};
            my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
            my $other_indices = '['.join(', ', @{$entry->{'other_indices'}}).']';
            print FD (join("\t", $index, $hint, $inuse, $may_send, $parent, $mask, $other_indices), $endl);
        }
    }
    close(FD);
}

sub dump_cell_table {
    foreach my $c (sort keys %cell_table) {
        my $c_up = $cell_table{$c};
        next if ($c == -1);
        my $cell_lname = ($ALAN) ? letter($c_up) : 'link#'.$c_up;
        printf DOT ("C%d [label=\"C%d  (%s)\"]\n", $c, $c, $cell_lname);
    }
}

sub write_edge {
    my ($lc, $lp, $rc, $rp, $link_no) = @_;
    if ($ALAN) {
        my $link_name = letter($link_no);
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"%s\"]\n", $lc, $lp, $rc, $rp, $link_name);
    }
    else {
        my $link_name = 'link#'.$link_no;
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"p%d:p%d,\\n%s\"]\n", $lc, $lp, $rc, $rp, $lp, $rp, $link_name);
    }
}

sub write_border {
    my ($c, $p, $link_no) = @_;
    if ($ALAN) {
        my $link_name = letter($link_no);
        printf DOT ("Internet -> C%d:p%d [label=\"%s\"]\n", $c, $p, $link_name);
    }
    else {
        my $link_name = 'link#'.$link_no;
        printf DOT ("Internet -> C%d:p%d [label=\"p%d,\\n%s\"]\n", $c, $p, $p, $link_name);
    }
}

sub dump_msgs {
    my $file = '/tmp/msg-dump.txt';
    open(FD, '>'.$file) or die $!;

    foreach my $key (sort order_mtable keys %msg_table) {
        my $hint = substr($msg_table{$key}, -5);
        print FD (join(' ', $hint, $key), $endl);
    }

    close(FD);
}

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_mtable($$) {
    my ($left, $right) = @_;
    my $left_hint = substr($msg_table{$left}, -5);
    my $right_hint = substr($msg_table{$right}, -5);
    return $left_hint cmp $right_hint unless $left_hint eq $right_hint;
    return $msg_table{$left} cmp $msg_table{$right};
}

# link#
# $dir : cell-snd, pe-rcv, pe-snd
sub add_msgcode {
    my ($c, $p, $msg_type, $event_code, $dir, $tree_id) = @_;
    my $link_no = get_link_no($c, $p);
    return unless $link_no; # ugh, issue with 0
    my $arrow = $arrow_code->{$dir};
    my $crypt = $op_table->{$msg_type};
    my $link_code = ($ALAN) ? letter($link_no) : 'link#'.$link_no;
    my $code = $crypt.$arrow.$link_code.$endl.'('.$tree_id.')'; # $blank
    my $o = {
        'event_code' => $event_code,
        'tree_id' => $tree_id,
        'cell_no' => $c,
        'link_no' => $link_no,
        'code' => $code
    };

    push(@msgqueue, $o);
}

sub letter {
    my ($link_no) = @_;
    my $chan = $link_no / 2;
    my $compass = $link_no % 1;
    return chr($link_no + ord('a') - 1); # $chan ...) + (($compass) ? '' : "'");
}

# breaking condition is contention for a queue endpoint
# could construct data into a 2 dimensional data structure (fix number of cells, variable length history)
# combine operations by ((in x out) x ports)
# use a row-busy bitvector - can keep it in cell table ?
# FIXME
# only supports 60 cells or links
sub msg_sheet {
    my $csvfile = '/tmp/events.csv';
    open(CSV, '>'.$csvfile) or die $!;
    print CSV (join(',', 'event/cell', 0..9), $endl);
    my @row = ();
    my $c_overwrite = 0;
    my $l_overwrite = 0;
    foreach my $item (sort order_msgs @msgqueue) {
my $code = $item->{'code'};
if (defined $code_filter) { next unless $code =~ $code_filter; }
        my $c = $item->{'cell_no'};
        my $l = $item->{'link_no'};
        giveup('more than 60 cells?') if $c > 60;
        giveup('more than 60 links?') if $l > 60;
        my $cindex = 1 << $c;
        my $lindex = 1 << $l;
        # causal relationship - cell-agent queue and link queues are sequential
        # check if the queue is busy:
        my $has_c = $c_overwrite & $cindex;
        my $has_l = $l_overwrite & $lindex;
        if ($has_c or $has_l) {
            $c_overwrite = 0;
            $l_overwrite = 0;
            foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
            print CSV (join(',', $item->{'event_code'}, @row), $endl);
            @row = ();
        }

        $c_overwrite |= $cindex;
        $l_overwrite |= $lindex;
        $row[$c] = $dquot.$code.$dquot;
    }

    # dangling data:
    foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
    print CSV (join(',', 'last', @row), $endl);
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
    my ($file) = @_;
    my @records = inhale($file);

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
        my $function = $header->{'function'}; # code method
        my $format = $header->{'format'}; # arbitrary tag (think line number/unique emitter)
        my $kind = $header->{'trace_type'}; # importance (simple trace, extra detail [debug])
        my $epoch = $header->{'epoch'}; # human domain indicator uses for managing streaming data (think lifetime of data)
        # key contains "basic causal ordering" - thread_id/event_id (and stream position for ties)

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

sub nametype {
    my ($nameref) = @_;
    my $id = $nameref->{'name'}; $id = '' unless defined $id;
    return $id;
}

sub portdesc {
    my ($portref) = @_;
    my $id = $portref->{'v'};
    return 'v'.$id;
}

# --
## data record parsing routines:

# /body : OBJECT { schema_version }
# 'noc.rs$$initialize$$Trace$$trace_schema'
sub meth_START {
    my ($body, $header) = @_;
    my $repo = $header->{'repo'};
    my $epoch = $header->{'epoch'};
    my $schema_version = $body->{'schema_version'};
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

    ## Complex Entry:
    add_edge($link_id);
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
sub ca_send_msg_generic {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_list = build_port_list($body->{'port_nos'});
    my $summary = summarize_msg($body->{'msg'});

    print(join(' ', $cell_id, $tree_id, $port_list, $summary, ';'));

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $port_nos = $body->{'port_nos'};

    my $msg_hdr = $body->{'msg'}{'header'};
    my $msg_type = $msg_hdr->{'msg_type'}; # STRING # Application, Discover, DiscoverD, Manifest, StackTree, StackTreeD
    my $direction = $msg_hdr->{'direction'}; # STRING # Leafward, Rootward
    my $msg_count = $msg_hdr->{'msg_count'}; # NUMBER
    my $sender_id = nametype($msg_hdr->{'sender_id'}); # "Sender:..."
    my $tree_map = $msg_hdr->{'tree_map'};

    my $msg_payload = $body->{'msg'}{'payload'};
    my $pay_tree_id = nametype($msg_payload->{'tree_id'}); # "C:2+NocAgentMaster"
    my $pay_body = $msg_payload->{'body'}; # STRING # "Reply from Container:VM:C:9+vm1+2"

    #FIXME -bj
    # this really just adds a msg to the CA=>PE queue
    foreach my $item (@{$port_nos}) {
        my $p = $item->{'v'};
        add_msgcode($c, $p, $msg_type, $event_code, 'cell-snd', $tree_id); # $tree_id.' '.$port_list);
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
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# guts of the Packet Engine (forwarding)

## IMPORTANT : Spreadsheet
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
        my $p = $item->{'v'};
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
    my $p = $body->{'parent_port'}{'v'};
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
    my $index = $entry->{'index'};
    my $parent = portdesc($entry->{'parent'});
    print(join(' ', $cell_id, $port_no, 'index='.$index, $tree_id, $msg_type, 'parent='.$parent, ';'));

    ## Routing Table:
    update_routing_table($cell_id, $entry);

# FIXME - maybe this isn't a msgcode per-se (redundant/excess) ??
    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = $body->{'port_no'}{'v'};
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# Cell Agent Control Plane - msg processing (ie. worker)
# Leafward => micro service request (set)
# Rootward => response to application/client (singleton)

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg }
# 'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg'
sub meth_ca_got_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $summary = summarize_msg($body->{'msg'});
# FIXME
    print(join(' ', $cell_id, $summary, ';'));
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
    my $other_index = $body->{'other_index'}; # NUMBER
    # 'children' => [],
    # "gvm": { "recv_eqn": "true", "save_eqn": "false", "send_eqn": "true", "variables": [], "xtnd_eqn": "true" },
    # FIXME
    print(join(' ', $cell_id, $port_no, 'status='.$port_status, 'base='.$base_tree_id, 'hops='.$hops, $other_index, ';'));
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
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $summary = summarize_msg($body->{'msg'});

    my $entry = $body->{'entry'};

    ## Routing Table:
    # update_routing_table($cell_id, $entry);

    # FIXME
    print(join(' ', $cell_id, $new_tree_id, $summary, ';'));
}

# IMPORTANT : Stacking
# /body : OBJECT { cell_id msg no_saved tree_id }
# 'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg'
sub meth_ca_save_stack_tree_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));
}

# /body : OBJECT { cell_id msg no_saved tree_id }
# 'cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg'
sub meth_ca_add_saved_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));
}

# best guess - launch of VM (Cell Agent Control Plane work action)

# IMPORTANT : up_tree
# /body : OBJECT { cell_id deployment_tree_id tree_vm_map_keys up_tree_name }
# 'cellagent.rs$$deploy$$Debug$$ca_deploy'
sub meth_ca_deploy {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deployment_tree_id = nametype($body->{'deployment_tree_id'});
    my $up_tree_name = $body->{'up_tree_name'}; # STRING # "vm1"
    my $tree_vm_map_keys = $body->{'tree_vm_map_keys'};
    # FIXME
    print(join(' ', $cell_id, $deployment_tree_id, $up_tree_name, ';'));
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
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deploy_tree_id = nametype($body->{'deploy_tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $deploy_tree_id, $summary, ';'));
}

# /body : OBJECT { cell_id msg tree_id }
# 'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg'
sub meth_ca_got_tcp_application_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $summary, ';'));
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

# ''
sub meth_xx {
    my ($body) = @_;
    my $xx = 0;
    print(join(' ', $xx, ';'));
}

sub dispatch {
    my ($key, $module, $function, $kind, $format, $json) = @_;
    my $methkey = join('$$', $module, $function, $kind, $format);

    $verb{$methkey}++;

    my $body = $json->{'body'};
    my $header = $json->{'header'};

    # This indicates subsystem startup - i.e. break in seq of messages
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
    if ($methkey eq 'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg') { meth_ca_save_stack_tree_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$deploy$$Debug$$ca_deploy') { meth_ca_deploy($body); return; }
    if ($methkey eq 'cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg') { meth_ca_forward_saved_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg') { meth_ca_forward_stack_tree_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id') { meth_ca_get_base_tree_id($body); return; }
    if ($methkey eq 'cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs') { meth_ca_get_saved_msgs($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_pe$$Debug$$ca_listen_pe') { meth_ca_listen_pe($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg') { meth_ca_got_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm') { meth_ca_listen_vm($body); return; }
    if ($methkey eq 'cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree') { meth_ca_got_from_uptree($body); return; }
    if ($methkey eq 'cellagent.rs$$port_connected$$Trace$$ca_send_msg') { meth_ca_send_msg_port_connected($body); return; }
    if ($methkey eq 'cellagent.rs$$send_msg$$Debug$$ca_send_msg') { ca_send_msg_generic($body, $key); return; }
    if ($methkey eq 'cellagent.rs$$stack_tree$$Debug$$ca_stack_tree') { meth_ca_stack_tree($body); return; }
    if ($methkey eq 'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg') { meth_ca_got_tcp_application_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg') { meth_ca_got_manifest_tcp_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg') { meth_ca_got_stack_tree_tcp_msg($body); return; }
    if ($methkey eq 'cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map') { meth_ca_update_base_tree_map($body); return; }

    if ($methkey eq 'packet_engine.rs$$forward$$Debug$$pe_forward_leafward') { meth_pe_forward_leafward($body, $key); return; }
    if ($methkey eq 'packet_engine.rs$$forward$$Debug$$pe_forward_rootward') { meth_pe_forward_rootward($body, $key); return; }
    ## if ($methkey eq 'packet_engine.rs$$listen_ca$$Debug$$listen_ca') { meth_pe_listen_ca($body); return; }
    if ($methkey eq 'packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca') { meth_pe_listen_ca($body); return; } ## listen_ca
    if ($methkey eq 'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca') { meth_pe_packet_from_ca($body, $key); return; }
    if ($methkey eq 'packet_engine.rs$$listen_port$$Debug$$pe_listen_ports') { meth_pe_listen_ports($body); return; } ##  pe_msg_from_ca
    ## if ($methkey eq 'packet_engine.rs$$listen_port$$Debug$$pe_msg_from_ca') { meth_pe_listen_ports($body); return; }
    if ($methkey eq 'packet_engine.rs$$process_packet$$Debug$$pe_process_packet') { meth_pe_process_packet($body, $key); return; }

    print($endl);
    print(join(' ', $methkey), $endl);
    print Dumper $body;
    print($endl);
    giveup('incompatible schema');
}

# DANGER: shares link allocation responsibility
sub cell_table_entry {
    my ($c) = @_;
    $max_cell = $c if $c > $max_cell;
    my $p = 0;
    my $k = 'C'.$c.':p'.$p;
    return $cell_table{$c} if $cell_table{$c};
    ## fill in entry
    my $link_no = $max_link; $max_link++; # += 2
    $link_table{$k} = $link_no;
    $cell_table{$c} = $link_no;
    return $link_no;
}

sub get_cellagent_port {
    my ($c) = @_;
    my $link_no = $cell_table{$c};
    return $link_no;
}

# FIXME
# should indicate EAST/WEST direction (a, a')
# could do that with even/odd numbers
sub link_table_entry {
    my ($lc, $lp, $rc, $rp) = @_;
    my $k1 = 'C'.$lc.':p'.$lp; $k1 = 'Internet' if $lc == -1;
    my $k2 = 'C'.$rc.':p'.$rp;

    my $link_no = $max_link; $max_link++; # += 2
    $link_table{$k1} = $link_no;
    $link_table{$k2} = $link_no; # +1
}

# FIXME
sub dump_link_table {
    foreach my $cp (sort keys %link_table) {
        my $link_no = $link_table{$cp};
        if ($cp eq 'Internet') {
            write_border();
        }
        else {
            write_edge();
        }
    }
}

sub get_link_no {
    my ($c, $p) = @_;
    my $k = 'C'.$c.':p'.$p;
    return $link_table{$k};
}

# C:0+P:1+C:1+P:1
sub add_edge {
    my ($link_id) = @_;
    return unless $link_id;
    my ($c1, $lc, $p1, $lp, $c2, $rc, $p2, $rp) = split(/:|\+/, $link_id);
    my $link_no = link_table_entry($lc, $lp, $rc, $rp);
    my $c1_up = cell_table_entry($lc);
    my $c2_up = cell_table_entry($rc);
    write_edge($lc, $lp, $rc, $rp, $link_no);
}

# Internet+C:1+P:2
sub border_port {
    my ($cell_id, $port_no) = @_;
    my ($tag, $c) = split(':', $cell_id);
    my $port_index = $port_no; $port_index =~ s/[^\d]//g;
    my $link_no = link_table_entry(-1, 0, $c, $port_index);
    my $c_up = cell_table_entry($c);
    write_border($c, $port_index, $link_no);
}

# SEQ OF OBJECT { v }
sub build_port_list {
    my ($port_nos) = @_;
    return '' unless defined $port_nos;
    return '['.join(',', map { 'v'.$_->{'v'} } @{$port_nos}).']';
}

sub summarize_msg {
    my ($msg) = @_;
    return '' unless defined $msg;

    my $header = $msg->{'header'};
    my $payload = $msg->{'payload'};

    my $payload_text = JSON->new->canonical->encode($payload);# encode_json
giveup('encode error') unless $payload_text;
    my $payload_hash = sha1_hex($payload_text);
giveup('hash error') unless $payload_hash;
    $msg_table{$payload_text} = $payload_hash;

    # /msg/header/direction
    # /msg/header/msg_type
    # /msg/header/sender_id
    my $direction = $header->{'direction'};
    my $msg_type = $header->{'msg_type'};
    my $sender_id = $header->{'sender_id'}{'name'};

    # /msg/payload/gvm_eqn
    # /msg/payload/manifest
    my $has_gvm = defined($payload->{'gvm_eqn'}) ? 'gvm' : '';
    my $has_manifest = defined($payload->{'manifest'}) ? 'manifest' : '';

    my $hint = substr($payload_hash, -5);
    return join('%%', $msg_type, $sender_id, $direction, $hint, $has_gvm, $has_manifest);
}

sub construct_key {
    my ($hdr, $lineno) = @_;
    my $thread_id = $hdr->{'thread_id'};
    my $event_id = $hdr->{'event_id'};
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

sub inhale {
    my ($file) = @_;
    open(FD, '<'.$file) or die $!;
    my @body = <FD>;
    close(FD);
    return @body;
}

# accumulate $jschema
# JSON::is_bool
sub walk_structure {
    my ($path, $json) = @_;
    my $rkind = ref($json);
    $jschema{$path}++ unless $rkind;
    return unless $rkind;
    if ($rkind eq 'HASH') {
        # special case: include type
        my $jtype = ' : OBJECT { '.join(' ', sort keys $json).' }';
        $jschema{$path.$jtype}++;
        foreach my $tag (keys $json) {
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
    return unless $dump_tables; # 

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
);

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
    my ($fname) = @_;
    open FD, '<'.$fname or die $!;
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

_eof_
