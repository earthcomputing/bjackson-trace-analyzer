#!/usr/bin/perl -w
# analyze xx.json

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
    process_file($file);
}

## print Dumper $json;

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
        ## print(join(' ', 'insert:', $key), $endl);
        if (defined $data{$key}) {
            print(join(' ', 'duplicate key', $key), $endl);
            ## print Dumper $json;
            ## print Dumper $data{$key};
            # exit 1;
        }
        $data{$key} = $json;
    }

    # analysis

    # foreach my $key (sort { $data{$a} <=> $data{$b} } keys %data) {
    # foreach my $key (sort keys %data) {
    foreach my $key (sort order_keys keys %data) {
        my $json = $data{$key};

        # REQUIRED:
        my $module = $json->{'module'}; # elide this - redundant
        my $function = $json->{'function'};

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
            my $fx = $is_border eq 'true';
            $port_id = (($fx) ? 'FX:' : 'v').$port_no;
        }

        # re-hack key
        my $xkey = $key;
        $xkey =~ s/::[0-9]*$//;
        print(join(' ', $xkey, $function, $cell_id, $vm_id, $sender_id, $port_id, $comment), $endl);
    }
}

sub construct_key {
    my ($json, $lineno) = @_;
    my $thread_id = $json->{'trace_header'}{'thread_id'};
    my $event_id = $json->{'trace_header'}{'event_id'};
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
}

# ref: "<=>" and "cmp" operators
sub order_keys($$) {
    my ($left, $right) = @_;
    my ($l1, $l2, $l3) = split('::', $left);
    my ($r1, $r2, $r3) = split('::', $right);

    return $l1 - $r1 unless $l1 == $r1;
    return $l2 - $r2 unless $l2 == $r2;
    return $l3 - $r3;

    # return $left cmp $right; # lexically
    # return $left <=> $right; # numerically
}

sub inhale {
    my ($file) = @_;
    open(FD, "<".$file) or die $!;
    my @body = <FD>;
    close(FD);
    return @body;
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

my $notes = << '_eof_';

{
    'function' => 'start_cell',
    'module' => 'nalcell.rs',
    'comment' => 'starting cell agent',
    'cell_id' => {
        'name' => 'C:2',
        'uuid' => { 'uuid' => [ '12816193326460985473', 0 ] }
    },
    'trace_header' => { 'trace_type' => 'Trace', 'event_id' => 1, 'thread_id' => 0 }
}

THDR - "trace_header":{"thread_id":[0-9]*,"event_id":[0-9]*,"trace_type":"Trace"},
FCN - "module":"[^"]*","function":"[^"]*",
COMMENT - "comment":"[^"]*"

CELLID - "cell_id":{"name":"C:[0-9]*","uuid":{"uuid":\[[0-9]*,0\]}},
VMID - "vm_id":{"name":"VM:C:[0-9]*+vm[0-9]*","uuid":{"uuid":[[0-9]*,0]}},
SENDER - "sender_id":{"name":"Sender:C:[0-9]*+VM:C:[0-9]*+vm[0-9]*","uuid":{"uuid":[[0-9]*,0]}},

PORT - "port_no":{"v":[0-9]*},"is_border":[a-z]*

{THDR,FCN,COMMENT}
{THDR,FCN,CELLID,PORT}
{THDR,FCN,CELLID,COMMENT}
{THDR,FCN,CELLID,VMID,SENDER,COMMENT}

# name patterns:

"C:[0-9]*"
"VM:C:[0-9]*+vm[0-9]*"
"Sender:C:[0-9]*+VM:C:[0-9]*+vm[0-9]*"

_eof_
