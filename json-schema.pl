#!/usr/bin/perl -w
# json-schema.pl xx.json
# python -mjson.tool

use strict;

use lib '/Users/bjackson/perl5/lib/perl5';
use JSON qw(decode_json encode_json);
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Data::GUID;

my $endl = "\n";
my $dquot = '"';
my $blank = ' ';

if ( $#ARGV < 0 ) {
    giveup('usage: [-dump] [-NOT_ALAN] [-filter=C:2] analyze xx.json ...');
}

my $result_dir;
my $code_filter;
my %jschema;
my %keyset;

# --

foreach my $fname (@ARGV) {
    if ($fname =~ /-wdir=/) { my ($a, $b) = split('=', $fname); $result_dir = $b; $result_dir = '' unless $result_dir; next; }
    if ($fname =~ /-filter=/) { my ($a, $b) = split('=', $fname); $code_filter = $b; next; }
    print($endl, $fname, $endl);
    my $href = process_file($fname);
    do_analyze($href);
}

# --

my %dedup;
sub do_analyze {
    my ($href) = @_;

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};
        my @parts = @{$json->{'_SCHEMA'}};
        my $combined = join(' ;; ', @parts);
        $combined =~ s/ ;;  : / : /g; # yeah, hacky but effective
        $combined =~ s|//|/|g; # FIXME - change this in the code

        my $header = $json->{'header'};
        my $tag = methkey($header);
        my $entry = join(' = ', $tag, $combined);
        # print($entry, $endl) unless $dedup{$entry};
        $dedup{$entry}++;
    }

    dump_histo('SCHEMA:', \%dedup);
}

# by frequency, descending
sub dump_histo {
    my ($hdr, $href) = @_;
    ## print SCHEMA ($endl);
    ## print SCHEMA ($hdr, $endl);
    # foreach my $item (sort { $href->{$b} <=> $href->{$a} } keys %{$href}) {
    foreach my $item (sort order_dedup keys %{$href}) {
        print (join(' ', $href->{$item}, $item), $endl);
    }
}

sub order_dedup($$) {
    my ($left, $right) = @_;
    return $dedup{$right} <=> $dedup{$left} unless $dedup{$right} == $dedup{$left};
    return $left cmp $right;
}

# --

sub methkey {
    my ($header) = @_;
    my $repo = $header->{'repo'}; # software component
    my $module = $header->{'module'}; # source filename
    my $function = $header->{'function'}; # code method
    my $format = $header->{'format'}; # arbitrary tag (think line number/unique emitter)
    my $kind = $header->{'trace_type'}; # importance (simple trace, extra detail [debug])
    my $key = join('$$', $repo, $module, $function, $format, $kind);
    return $key;
}

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_keys($$) {
    my ($left, $right) = @_;
    return $left <=> $right;
}

sub process_file {
    my ($fname) = @_;
    my @records = inhale($fname);

    my $lineno = 0;
    my %data;
    foreach my $body (@records) {
        $lineno++;
        my $json = decode_json($body);
        my @parts = walk_structure('/', $json);
        my $key = construct_key($json, $lineno);
        $json->{'_SCHEMA'} = \@parts;
        $data{$key} = $json;
    }
    return \%data;
}

sub inhale {
    my ($path) = @_;
    my $gzip = $path =~ m/.gz$/;
    my $openspec = ($gzip) ?  'gzcat '.$path.'|' : '<'.$path;
    open(FD, $openspec) or die $path.': '.$!;
    my @body = <FD>;
    close(FD);
    return @body;
}

sub construct_key {
    my ($json, $lineno) = @_;
    my $key = $lineno;
    return $key;
}

# accumulate $jschema
# JSON::is_bool
sub walk_structure {
    my ($path, $json) = @_;
    my $rkind = ref($json);

    $jschema{$path}++ unless $rkind;
    return ($path, ' : SCALAR') unless $rkind;

    if ($rkind eq 'JSON::PP::Boolean') {
        $jschema{$path.' : BOOLEAN'}++;
        return ($path, ' : BOOLEAN');
    }

    if ($rkind eq 'HASH') {
        my $jtype = ' : OBJECT { '.join(' ', sort keys $json).' }';
        $jschema{$path.$jtype}++;

        my @fields;
        # canonicalize field order:
        foreach my $tag (sort keys $json) {
            $keyset{$tag}++;
            ##
            my $nested = $path.'/'.$tag;
            my @child_parts = walk_structure($nested, $json->{$tag});
            push @fields, @child_parts;
        }
        return ($path, $jtype, @fields);
    }

    if ($rkind eq 'ARRAY') {
        my @ary = @{$json};
        my $jtype = ' : ARRAY len='.($#ary+1);
        $jschema{$path.$jtype}++;

        my @union;
        foreach my $val (@ary) {
            my $nested = $path.'[]';
            my @child_parts = walk_structure($nested, $val);
            # FIXME : check for homogenius
            push @union, @child_parts;
last;
        }
        return ($path, ' : ARRAY', @union);
    }

    giveup(join(' ', 'unknown object type:', $rkind));
}

sub giveup {
    my ($msg) = @_;
    print STDERR ($msg, $endl);
    exit -1;
}

# --

my $notes = << '_eof_';

_eof_
