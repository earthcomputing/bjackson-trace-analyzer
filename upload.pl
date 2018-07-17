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
 
my $server = '192.168.0.71'; # localhost:9092
my $partition = 0;
my $topic = 'mytopic';

my @msg_set = [
    'The first message',
    'The second message',
    'The third message',
];

my $connection;
my $producer;
my $consumer;

use Data::Dumper;

try {
    $connection = Kafka::Connection->new(host => $server);
    # print Dumper $connection;

    $producer = Kafka::Producer->new(Connection => $connection);
    $producer->send($topic, $partition, 'Single message');
    $producer->send($topic, $partition, @msg_set);
 
    $consumer = Kafka::Consumer->new(Connection => $connection);
    dump_offsets($consumer, $topic, $partition);
 
    my $offset = 0;
    my $messages = $consumer->fetch($topic, $partition, $offset, $DEFAULT_MAX_BYTES);
    dump_msgs($messages) if $messages;
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
