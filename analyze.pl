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

my $endl = "\n";

if ( $#ARGV < 1 ) {
    print("usage: analyze xx.json ...", $endl);
    exit -1
}

foreach my $file (@ARGV) {
    print($file, $endl);
    my $href = process_file($file);
    do_analyze($href);
}

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
        my $key = construct_key($json, $lineno);
        if (defined $data{$key}) {
            print(join(' ', 'duplicate key', $key), $endl);
        }
        $data{$key} = $json;
    }
    return \%data;
}

sub do_analyze {
    my ($href) = @_;
    my %verb;

    my $last_thread = '-1';;

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};

        # REQUIRED:
        my $module = $json->{'module'}; # elide this - redundant
        my $function = $json->{'function'};

        $verb{$function}++;

        # OPTIONAL:
        # complex name structures:
        my $cell_id = $json->{'cell_id'}{'name'};
        $cell_id = '' unless defined $cell_id;

        my $vm_id = $json->{'vm_id'}{'name'};
        $vm_id = '' unless defined $vm_id;

        my $sender_id = $json->{'sender_id'}{'name'};
        $sender_id = '' unless defined $sender_id;

        # junk
        my $comment = $json->{'comment'};
        $comment = '' unless defined $comment;

        # suggest changing this ??
        my $port_no = $json->{'port_no'}{'v'};
        my $is_border = $json->{'is_border'};
        my $port_id = '';
        if (defined $port_no) {
            # is_bool($is_border)
            my $fx = $is_border eq 'true';
            $port_id = (($fx) ? 'FX:' : 'v').$port_no;
        }

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
        print(join(' ', $xkey, $function, $cell_id, $vm_id, $sender_id, $port_id, $comment, ';'));
    }

    print($endl);
    # dump histogram of verbs
    foreach my $item (sort { $verb{$a} <=> $verb{$b} } keys %verb) {
        print(join(' ', $verb{$item}, $item), $endl);
    }
}

sub construct_key {
    my ($json, $lineno) = @_;
    my $thread_id = $json->{'trace_header'}{'thread_id'};
    my $event_id = $json->{'trace_header'}{'event_id'};
    $event_id = e_massage($event_id);
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
}

# incompatible interface change!!
sub e_massage {
    my ($event_id) = @_;
    return $event_id unless ref($event_id); # old : scalar / number

    my $xxx = join('.', @{$event_id}); # new : seq of number (array)
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
    for my $i ( 0 .. $scan ) {
        my $val_cmp = $l[$i] <=> $r[$i];
        return $val_cmp unless $val_cmp == 0;
    }
    return $len_cmp;
}

sub inhale {
    my ($file) = @_;
    open(FD, "<".$file) or die $!;
    my @body = <FD>;
    close(FD);
    return @body;
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

_eof_
