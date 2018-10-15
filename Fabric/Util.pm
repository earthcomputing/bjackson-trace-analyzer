#!/usr/bin/perl -w

package Fabric::Util v2018.10.13 {

my $endl = "\n";

use Exporter 'import';
our @EXPORT_OK = qw(
    note_value
    giveup
    get_epoch
    set_epoch
    epoch_marker
);

use Digest::SHA qw(sha1_hex);
use JSON;

# --

my $epoch_global = 0;

# unused
sub get_epoch { return $epoch_global; }
sub set_epoch { my ($e) = @_; $epoch_global = $e; }

sub epoch_marker {
    print main::DBGOUT (join(' ', 'epoch_marker:', $epoch_global), $endl);
}

# --

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

_eof_

}

# for loading:
1;

