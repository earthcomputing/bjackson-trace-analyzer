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
}

sub construct_key {
    my ($json, $lineno) = @_;
    my $thread_id = $json->{'trace_header'}{'thread_id'};
    my $event_id = $json->{'trace_header'}{'event_id'};
    my $key = join('::', $thread_id, $event_id, $lineno);
    return $key;
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

_eof_
