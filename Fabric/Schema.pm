#!/usr/bin/perl -w

package Fabric::Schema v2018.10.13 {

my $endl = "\n";

use Exporter 'import';
our @EXPORT_OK = qw(
    dump_schema
    note_verb
    walk_structure
);

use Digest::SHA qw(sha1_hex);
use JSON;

# --

my %jschema; # map : $xpath.$jtype : ref-count - {$path}++ {$path.$jtype}++; {$path.' : BOOLEAN'}++;
my %keyset; # map : field : ref-count - foreach my $tag (keys $json) { $keyset{$tag}++; }

my %verb; # map : methkey : ref-count : $verb{join('$', $module, $function)}++; $verb{$methkey}++;

sub note_verb {
    my ($key) = @_;
    $verb{$key}++;
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

sub dump_schema {
    my ($path) = @_;
    open(SCHEMA, '>', $path) or die $path.': '.$!;
    dump_histo('VERBS:', \%verb);
    dump_histo('SCHEMA:', \%jschema);
    dump_histo('KEYSET:', \%keyset);
    close(SCHEMA);
}

# --

my $notes = << '_eof_';

_eof_

}

# for loading:
1;

