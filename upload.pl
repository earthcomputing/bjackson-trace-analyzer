#!/usr/local/bin/perl -w

use 5.010;
use strict;
use warnings;

use Scalar::Util qw(
    blessed
);
use Try::Tiny;
 
use Kafka qw(
    $KAFKA_SERVER_PORT
    $REQUEST_TIMEOUT
    $RECEIVE_EARLIEST_OFFSET
    $DEFAULT_MAX_NUMBER_OF_OFFSETS
    $DEFAULT_MAX_BYTES
);
use Kafka::Connection;
use Kafka::Producer;
use Kafka::Consumer;

# --

use JSON qw(decode_json encode_json);
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Data::GUID;

# --

my $endl = "\n";
my $dquot = '"';
my $blank = ' ';

my $code_filter;

# --
 
my $server = $ENV{'advert_host'}; # '192.168.0.71'; # localhost:9092

giveup('must specify ${advert_host}') unless $server;

my $connection;
my $producer;
my $consumer;

try {
    $connection = Kafka::Connection->new(host => $server);
    $producer = Kafka::Producer->new(Connection => $connection);
    $consumer = Kafka::Consumer->new(Connection => $connection);

    # dump_offsets($consumer, $topic, $partition);
    # dump_all_msgs($consumer, $topic, $partition);

    upload_tool($producer);
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

exit 0;

# --

sub upload_tool {
    my ($producer) = @_;
    foreach my $fname (@ARGV) {
        if ($fname =~ /-filter=/) { my ($a, $b) = split('=', $fname); $code_filter = $b; next; }
        print($endl, $fname, $endl);
        my $href = process_file($fname);
        do_upload($href);
    }
}

# kafka-topics.sh --zookeeper 192.168.0.71:2181 --create --topic CellAgent --partitions 1 --replication-factor 1
sub do_upload {
    my ($href) = @_;

    foreach my $key (sort order_keys keys %{$href}) {
        my $json = $href->{$key};
        my $header = $json->{'header'};
        # my $body = $json->{'body'};

        my $topic = $header->{'repo'}; # software component
        my $partition = 0;
        my $json_text = encode_json($json);
        $producer->send($topic, $partition, $json_text, $key);
    }
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

sub process_file {
    my ($fname) = @_;
    my @records = inhale($fname);

    my $lineno = 0;
    my %data;
    foreach my $body (@records) {
        $lineno++;
        my $json = decode_json($body);
        my $header = $json->{'header'};
        my $key = construct_key($header, $lineno);
        $header->{'_lineno'} = $lineno; # augment data
        $data{$key} = $json;
    }
    return \%data;
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

sub dump_offsets {
    my ($consumer, $topic, $partition) = @_;
    # Get a list of valid offsets before the given time
    my $offsets = $consumer->offsets($topic, $partition, $RECEIVE_EARLIEST_OFFSET, $DEFAULT_MAX_NUMBER_OF_OFFSETS);
    if (@$offsets) {
        say "Received offset: $_" foreach @$offsets;
    }
    else {
        warn "Error: Offsets are not received\n";
    }
}

sub dump_all_msgs {
    my ($consumer, $topic, $partition) = @_;
    my $offset = 0;
    my $messages = $consumer->fetch($topic, $partition, $offset, $DEFAULT_MAX_BYTES);
    dump_msgs($messages) if $messages;
}

sub dump_msgs {
    my ($messages) = @_;
    foreach my $message (@$messages) {
        if ($message->valid) {
            say 'payload    : ', $message->payload;
            say 'key        : ', $message->key;
            say 'offset     : ', $message->offset;
            say 'next_offset: ', $message->next_offset;
        }
        else {
            say 'error      : ', $message->error;
        }
    }
}

# --

my $notes = << '_eof_';

_eof_
