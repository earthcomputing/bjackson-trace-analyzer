#!/usr/bin/perl -w
# analyze xx.json

# TODO :
# duplicate key
# is_bool
# JSON::MaybeXS

use strict;

use lib '/Users/bjackson/perl5/lib/perl5';
use JSON qw( decode_json ); # From CPAN
use Data::Dumper;

my $debug;
my $dump_tables; # = 1;

my %jschema;
my %keyset;

my $endl = "\n";

if ( $#ARGV < 0 ) {
    print('usage: analyze xx.json ...', $endl);
    exit -1
}

# FIXME
my $dotfile = '/tmp/complex.dot';
open(DOT, '>'.$dotfile) or die $!;
print DOT ('digraph G {', $endl);
print DOT ('rankdir=LR', $endl);

foreach my $file (@ARGV) {
    if ($file eq '-dump') { $dump_tables = 1; next; }
    print($endl, $file, $endl);
    my $href = process_file($file);
    do_analyze($href);
}

print DOT ('}', $endl);
close(DOT);
dump_schema();
exit 0;

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
        # my $key = construct_key($json->{'trace_header'}, $lineno);
        my $key = construct_key($json->{'header'}, $lineno);
        $data{$key} = $json;
    }
    return \%data;
}

sub do_analyze {
    my ($href) = @_;
    my %verb;

    my $last_thread = '-1';

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};
        my $body_type = $json->{'body_type'};
        my $body = $json->{'body'};

        # REQUIRED/SHOULD:
        # my $trace_header = $json->{'trace_header'}
        my $module = $body->{'module'}; # elide this - redundant
        my $function = $body->{'function'};
        # complex name structures:
        my $cell_id = $body->{'cell_id'}{'name'};
        $cell_id = '' unless defined $cell_id;

        $verb{join('$', $module, $function)}++;

# --

        # OPTIONAL:
        my $comment = $body->{'comment'};
        $comment = '' unless defined $comment;

        # complex name structures:
        my $vm_id = $body->{'vm_id'}{'name'};
        $vm_id = '' unless defined $vm_id;

        my $sender_id = $body->{'sender_id'}{'name'};
        $sender_id = '' unless defined $sender_id;

## port_connected
        my $is_border = $body->{'is_border'}; # cell has port=of-entry ??

        # suggest changing this ??
        my $port_no = $body->{'port_no'}{'v'};
        my $port_id = '';
        if (defined $port_no) {
            my $fx = $is_border; #  eq 'true';
            $port_id = (($fx) ? 'FX:' : 'v').$port_no;
            border_port($cell_id, $port_no) if $fx;
        }

## listen_pe_loop, send_msg
        my $tree_id = $body->{'tree_id'}{'name'};
        $tree_id = '' unless defined $tree_id;

        my $port_nos = $body->{'port_nos'}; ## array of port names (vXX)
        my $port_list = build_port_list($port_nos);
        ## FIXME

## forward
        my $msg_type = $body->{'msg_type'};
        $msg_type = '' unless defined $msg_type;

## listen_pe_loop
        my $msg = $body->{'msg'};
        my $summary = summarize_msg($msg);
        ## FIXME

## initialize
        my $link_id = $body->{'link_id'}{'name'};
        $link_id = '' unless defined $link_id;
        add_edge($link_id);

## output
        # re-hack key for output
        my $xkey = $key;
        # $xkey =~ s/::[0-9]*$//;
        $xkey =~ s/::.*$/::/;
        if ($xkey eq $last_thread) {
            $xkey = '';
        }
        else {
            print($endl);
            $last_thread = $xkey;
        }
        print(join(' ', $xkey, $function, $cell_id, $vm_id, $sender_id, $msg_type, 'tree='.$tree_id, $port_id, $port_list, 'msg='.$summary, $comment, $link_id, ';'));
    }
    print($endl); # terminate last entry

    dump_histo('VERBS:', \%verb);
}

# C:0+P:1+C:1+P:1
sub add_edge {
    my ($link_id) = @_;
    return unless $link_id;
    my ($c1, $lc, $p1, $lp, $c2, $rc, $p2, $rp) = split(/:|\+/, $link_id);
    printf DOT ("C%d:p%d -> C%d:p%d [label=\"p%d:p%d\"]\n", $lc, $lp, $rc, $rp, $lp, $rp);
}

sub border_port {
    my ($cell_id, $port_no) = @_;
    my ($tag, $c) = split(':', $cell_id);
    printf DOT ("Internet -> C%d:p%d [label=\"p%d\"]\n", $c, $port_no, $port_no);

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

    return join('%%', $msg_type, $sender_id, $direction, $has_gvm, $has_manifest);
}

sub construct_key {
    my ($hdr, $lineno) = @_;
    my $thread_id = $hdr->{'thread_id'};
    my $event_id = $hdr->{'event_id'};
    $event_id = e_massage($event_id);
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
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

    print(join(' ', 'unknown object type:', $rkind), $endl);
    exit 0;
}

# by frequency, descending
sub dump_histo {
    my ($hdr, $href) = @_;
    return unless $dump_tables; # 

    print($endl);
    print($hdr, $endl);
    foreach my $item (sort { $href->{$b} <=> $href->{$a} } keys %{$href}) {
        print(join(' ', $href->{$item}, $item), $endl);
    }
}

sub dump_schema {
    dump_histo('SCHEMA:', \%jschema);
    dump_histo('KEYSET:', \%keyset);
}

# --

my $notes = << '_eof_';

{
    'trace_header' => { 'trace_type' => 'Trace', 'event_id' => 1, 'thread_id' => 0 },
    'module' => 'nalcell.rs',
    'function' => 'start_cell',

    'comment' => 'starting cell agent',
    'cell_id' => { 'uuid' => { 'uuid' => [ '12816193326460985473', 0 ] }, 'name' => 'C:2' }
}

# --

THDR - "trace_header":{"thread_id":[0-9]*,"event_id":[0-9]*,"trace_type":"Trace"},
FCN - "module":"[^"]*","function":"[^"]*",
COMMENT - "comment":"[^"]*"

UUID - {"name":"[^"]*","uuid":{"uuid":\[[0-9]*,0\]}},

CELLID - "cell_id":UUID,
VMID - "vm_id":UUID,
SENDER - "sender_id":UUID,

PORT - "port_no":{"v":[0-9]*},"is_border":[a-z]*

{THDR,FCN,COMMENT}
{THDR,FCN,CELLID,PORT}
{THDR,FCN,CELLID,COMMENT}
{THDR,FCN,CELLID,VMID,SENDER,COMMENT}

# name patterns:

"C:[0-9]*"
"VM:C:[0-9]*+vm[0-9]*"
"Sender:C:[0-9]*+VM:C:[0-9]*+vm[0-9]*"

# --

90 process_discoverd_msg
27 process_stack_treed_msg
27 port_connected
10 start_packet_engine
10 start_cell
10 listen_port
10 listen_pe
10 listen_ca

10 listen_uptree
5 listen_uptree

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

# --

3888 uuid
2128 name
1254 v
746 function
746 thread_id
746 trace_header
746 event_id
746 trace_type
746 cell_id
746 module
572 msg_type
570 tree_id
414 port_nos
312 sender_id
293 direction
293 msg_count
293 tree_map
293 msg
293 payload
293 header
186 index
120 comment
115 id
114 new_tree_id
114 var_name
114 send_eqn
114 value
114 recv_eqn
114 save_eqn
114 xtnd_eqn
114 parent_tree_id
114 gvm_eqn
114 var_type
114 variables
72 fwd_index
69 allowed_trees
54 is_border
54 port_no
48 body
46 image
46 trees
46 parent_list
36 my_index
23 containers
23 vms
23 NocMasterAgent
23 NocAgentMaster
23 tree_name
23 required_config
23 deploy_tree_id
23 params
23 cell_config
23 manifest
23 deployment_tree
19 vm_id

# --

{
    "trace_body": {
        "cell_number": 2,
        "function": "initialize",
        "module": "datacenter.rs"
    },
    "trace_body_type": "border_cell_start",
    "trace_header": {
        "event_id": [ 1 ],
        "thread_id": 0,
        "trace_type": "Trace"
    }
}

{
    "trace_header": {
        "thread_id": 0,
        "event_id": [ 1 ],
        "module": "datacenter.rs"
        "function": "initialize",
        "kind": "Trace",
        "format": "border_cell_start",
    },
    "body": {
        "cell_number": 2,
    },
}

_eof_
