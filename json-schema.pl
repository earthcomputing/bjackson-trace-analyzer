#!/usr/local/bin/perl -w
#!/usr/bin/perl -w
#---------------------------------------------------------------------------------------------
 #  Copyright © 2016-present Earth Computing Corporation. All rights reserved.
 #  Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#---------------------------------------------------------------------------------------------
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
my $squot = "'";
my $comma = ',';
my $blank = ' ';
my $nest = $blank x 4;

my $codes = {
    'BOOLEAN' => 'Z',
    'SCALAR' => '$',
    'OBJECT' => '%',
    'ARRAY' => '@'
};

if ( $#ARGV < 0 ) {
    giveup('usage: json-schema.pl [-terse] [-filter=C:2] multicell-trace-${tag}${epoch}.json[.gz] ...');
}

my $code_filter;
my %jschema;
my %keyset;

my $terse = 0;

# --

my %methods;

foreach my $fname (@ARGV) {
    if ($fname =~ /-terse/) { $terse = 1; next; }
    if ($fname =~ /-filter=/) { my ($a, $b) = split('=', $fname); $code_filter = $b; next; }
    print($endl, $fname, $endl);
    my $href = process_file($fname);
    do_analyze($href);
    dump_methods();
}

# --

sub mline {
    my ($mname) = @_;
    print METH (join($endl.$nest,
        "sub $mname {",
        'my ($body, $key) = @_;',
        'my @body_attr = keys %{$body};',
        'my $alist = join(", ", @body_attr);',
        'print($aslist, " ;");'),
        $endl, '}', $endl, $endl # 2nd endl separates methods
    );
}

sub dump_methods {
    my $mpath = '/tmp/methods.pl';
    open(METH, '>', $mpath) or die $mpath.': '.$!;

    my %mcount;
    print METH ('#!/usr/bin/perl -w', $endl);
    print METH ($endl);
    foreach my $key (sort keys %methods) {
        my $mname = $methods{$key};
        mline($mname) unless $mcount{$mname};
        $mcount{$mname}++;
    }

    print METH ($endl);
    print METH ('my $dispatch = {', $endl);
    foreach my $key (sort keys %methods) {
        my $mname = $methods{$key};
        print METH ('    ', $squot, $key, $squot, ' => \\&', $mname, $comma, $endl);
    }
    print METH ('};', $endl);

    close(METH);
}

my %dedup;
my %bodies;
sub do_analyze {
    my ($href) = @_;

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};
        my @parts = @{$json->{'_SCHEMA'}};
        my $combined = join(' ;; ', @parts);
        $combined =~ s/ ;;  : / : /g; # yeah, hacky but effective
        $combined =~ s|//|/|g; # FIXME - change this in the code
        $combined =~ s|SEQ OF ;;  : |SEQ OF |g;

        my $hc = sha1_hex($combined);
        my $hash = substr($hc, -5);

        $bodies{$hash.' '.$combined}++;

        my $header = $json->{'header'};
        my $tag = methkey($header);
        my $entry = join(' = ', $tag, $hash);

        my $format = $header->{'format'}; # arbitrary tag (think unique emitter)
        my $mname = join('', 'meth_', $format, '_', $hash);
        $methods{$tag} = $mname unless defined $dedup{$entry};

        # print($entry, $endl) unless $dedup{$entry};
        $dedup{$entry}++;
    }

    dump_histo('SCHEMA:', \%dedup);
    dump_histo('BODY:', \%bodies);
}

my $context;

# by frequency, descending
sub dump_histo {
    my ($hdr, $href) = @_;
    print ($endl);
    ## print SCHEMA ($hdr, $endl);
    # foreach my $item (sort { $href->{$b} <=> $href->{$a} } keys %{$href}) {
    ## UGH, global context - bad, very bad!!
    $context = $href;
    foreach my $item (sort order_dedup keys %{$href}) {
        print (join(' ', $href->{$item}, $item), $endl);
    }
}

sub order_dedup($$) {
    my ($left, $right) = @_;
    my $href = $context;
    return $href->{$right} <=> $href->{$left} unless $href->{$right} == $href->{$left};
    return $left cmp $right;
}

# --

## "header": {
##    "repo": "CellAgent",
##    "module": "src/main.rs",
##    "line_no": 39,
##    "function": "MAIN",
##    "format": "trace_schema",
##    "trace_type": "Trace",
##
# emitter instance data:
##    "thread_id": 0,
##    "event_id": [ 2 ],
##    "epoch": 1539168999907516
sub methkey {
    my ($header) = @_;
    my $repo = $header->{'repo'}; # software component
    my $module = $header->{'module'}; # source filename
    my $function = $header->{'function'}; # code method
    my $format = $header->{'format'}; # arbitrary tag (think unique emitter)
    my $line_no = $header->{'line_no'}; # source line_no
    my $kind = $header->{'trace_type'}; # importance (simple trace, extra detail [debug])

    my $key = join('$$', $repo, $module, $function, $format, $line_no, $kind);
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
        my @parts = $terse ? walk_structure('/body', $json->{'body'}) : walk_structure('/', $json);
        my $key = construct_key($json, $lineno);
        $json->{'_SCHEMA'} = \@parts;
        $data{$key} = $json;
    }
    return \%data;
}

# FIXME : allow '-' for STDIN processing ??
sub inhale {
    my ($path) = @_;
    my $gzip = $path =~ m/.gz$/;
    my $openspec = ($gzip) ?  'gunzip -c '.$path.'|' : '<'.$path;
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
    return ($path, ' : '.$codes->{SCALAR}) unless $rkind;

    if ($rkind eq 'JSON::PP::Boolean') {
        my $jtype = ' : '.$codes->{BOOLEAN};
        $jschema{$path.$jtype}++;
        return ($path, $jtype);
    }

    if ($rkind eq 'HASH') {
        # canonicalize field order:
        my @attrs = sort keys %{$json};
        my $jtype = ' : '.$codes->{OBJECT}.' { '.join(' ', @attrs).' }';
        $jschema{$path.$jtype}++;

        my @fields;
        foreach my $tag (@attrs) {
            $keyset{$tag}++;
            my $nested = $path.'/'.$tag;
            my @child_parts = walk_structure($terse ? $tag : $nested, $json->{$tag});
            push @fields, @child_parts;
        }

## identify sub-structures here:
        return ($path, $jtype, @fields);
    }

    if ($rkind eq 'ARRAY') {
        my @ary = @{$json};
        my $jtype = ' : '.$codes->{ARRAY}.' len='.($#ary+1);
        $jschema{$path.$jtype}++;

        my @union;
        my %subtypes;
        foreach my $val (@ary) {
            my $nested = $path.'[]';
            next unless defined $val; # ignore null references
            my @child_parts = walk_structure($terse ? '' : $nested, $val);
            my $combined = join(' ;; ', @child_parts);
            ## $combined =~ s/ ;;  : / : /g; # yeah, hacky but effective
            ## $combined =~ s|//|/|g; # FIXME - change this in the code
            $subtypes{$combined}++;
        }

        my @keys = keys %subtypes;
        foreach my $item (sort @keys) {
            push @union, $item;
        }

        return ($path, ' : SEQ OF', @union) unless $#keys > 0;

        # FIXME : check for homogenius
        print STDERR (join(' ', 'WARNING: hetergeneous array:', $path), $endl);
        return ($path, ' : UNION <', @union, '>'); # violates pair structure
    }

    giveup(join(' ', 'unknown object type:', $rkind));
}

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

sub giveup {
    my ($msg) = @_;
    print STDERR ($msg, $endl);
    exit -1;
}

# --

my $notes = << '_eof_';

    /body/base_tree_map_keys : ARRAY ;;
    /body/base_tree_map_values : ARRAY ;;
    /body/children : ARRAY ;;
    /body/tree_vm_map_keys : ARRAY ;;
    /body/msg : ARRAY ;;

    "body": {
        "schema_version": "0.1",
        "ncells": 3
    }

_eof_
