#!/usr/bin/perl -w

package TraceData v2018.10.13 {

my $endl = "\n";

use Exporter 'import';
our @EXPORT_OK = qw(
    bytes2dense
    frame2obj
    dump_guids
    grab_name
    hint4uuid
    nametype
    port_index
    portdesc
    build_port_list
    uuid_magic
    xlate_uuid
    summarize_msg
    convert_string
    decode_octets
    dump_packet
);

use Data::Dumper;
use Data::GUID;
use JSON qw(decode_json);

use Util qw(note_value);

# --

sub bytes2dense {
    my ($u8) = @_;
    return undef unless $u8;
    my $dense = '';
    foreach my $ch (@{$u8}) {
        my $doublet = sprintf('%02x', $ch);
        $dense = $dense.$doublet;
    }
    print($dense, $endl);
    return $dense;
}

sub frame2obj {
    my ($frame) = @_;
    my $json_text = pack('H*', $frame); # hex_to_ascii
    my $o = decode_json($json_text);
    print($json_text, $endl);
    return $o;
}

# --

my $null_uuid = '0x00000000000000000000000000000000';

my %guid_table; # map : guid -> name

sub dump_guids {
    my ($path) = @_;
    my $hdr = 'GUIDS:';
    my $href = \%guid_table;

    open(GUIDS, '>'.$path) or die $path.': '.$!;
    print GUIDS ($endl);
    print GUIDS ($hdr, $endl);

    # sort by value
    foreach my $item (sort { $href->{$a} cmp $href->{$b} } keys %{$href}) {
        my $hint =  lc(substr($item, 0, 8)); # -8
        print GUIDS (join(' ', $hint, $item, $href->{$item}), $endl);
    }

    close(GUIDS);
}

# hex_guid
sub uuid_magic {
    my ($coded_uuid) = @_;
    my $b0 = substr($coded_uuid, 2, 2);
    my $b1 = substr($coded_uuid, 4, 2);
    # make_normal(uuid)
    substr($coded_uuid, 2, 4, '4000'); # ugh, side-effect : OFFSET,LENGTH,REPLACEMENT
    my $real_uuid = lc($coded_uuid);
    return ($b0, $b1, $real_uuid);
}

# 00112233-4455-6677-8899-aabbccddeeff
# {time_low}-{time_mid}-{time_hi_and_version}-{clk_seq_hi_res/clk_seq_low}-{node}
# octet 8 variant
# octet 6 version
# variant - most significant 3 bits of clock_seq (clk_seq_hi_res)
# version - most significant 4 bits of timestamp (time_hi_and_version)
# 1-3 bit "variant" followed by 13-15 bit clock sequence
# clk_seq_hi_res=88
# time_hi_and_version=6677
sub xlate_uuid {
    my ($ref) = @_;
    return $null_uuid unless ref($ref) eq 'HASH';
    my $words = $ref->{'uuid'};

    my $rkind = ref($words);
    if ($rkind eq 'ARRAY') {
        return $null_uuid unless $#$words == 1;

        my $w0 = $words->[0];
        my $w1 = $words->[1];

        unless (defined $w0) {
            print STDERR (Dumper $ref, $endl);
            exit 0;
        }

        my $str = sprintf("0x%016x%016x", $w1, $w0);
        my $guid = Data::GUID->from_hex($str);
        my $hex_guid = $guid->as_hex;
        return $hex_guid;
    }
    # Can't use string ("400d426d-8eee-4230-92b4-5557cdbd"...) as an ARRAY ref while "strict refs" in use at analyze.pl line 597.
    else {
        return $null_uuid unless $words;
        my $guid = Data::GUID->from_string($words);
        my $hex_guid = $guid->as_hex;
        return $hex_guid;
    }
}

# costly, but validates
sub hint4uuid {
    my ($ref) = @_;
    my $hex_guid = xlate_uuid($ref);
    return lc(substr($hex_guid, 0, 8)); # -8 from right
}

sub grab_name {
    my ($ref) = @_;
    my $guid = xlate_uuid($ref);
    my $guid_name = $guid_table{$guid};
}

# --

sub nametype {
    my ($nameref) = @_;
    my $name = $nameref->{'name'}; $name = '' unless defined $name;
    my $uuid = $nameref->{'uuid'};
    my $guid = xlate_uuid($uuid);
    $guid_table{$guid} = $name;
    return $name;
}


# --

sub port_index {
    my ($portref) = @_;

    my $rkind = ref($portref);
    if ($rkind eq 'HASH') {
        my $id = $portref->{'v'};
        return $id;
    }
    # Can't use string ("1") as a HASH ref while "strict refs" in use at analyze.pl line 640.
    else {
        return $portref;
    }
}

sub portdesc {
    my ($portref) = @_;
    my $id = port_index($portref);
    return 'v'.$id;
}

# SEQ OF OBJECT { v }
sub build_port_list {
    my ($port_nos) = @_;
    return '' unless defined $port_nos;
    return '['.join(',', map { portdesc($_) } @{$port_nos}).']';
}

# --

# header { direction msg_type sender_id }
# payload { gvm_eqn manifest }
sub summarize_msg {
    my ($msg) = @_;
    return '' unless defined $msg;

    my $header = $msg->{'header'};
    my $direction = $header->{'direction'};
    my $msg_type = $header->{'msg_type'};
    my $sender_id = $header->{'sender_id'}{'name'};

    my $payload = $msg->{'payload'};
    my $gvm_eqn = $payload->{'gvm_eqn'};
    my $manifest = $payload->{'manifest'};

    my $payload_hash = note_value(\%msg_table, $payload);
    my $gvm_hash = note_value(\%gvm_table, $gvm_eqn);
    my $man_hash = note_value(\%manifest_table, $manifest);

    my $hint = substr($payload_hash, -5);
    my $opt_gvm = defined($gvm_hash) ? substr($gvm_hash, -5) : '';
    my $opt_manifest = defined($man_hash) ? substr($man_hash, -5) : '';
    return join('%%', $hint, $direction, $msg_type, $sender_id, 'gvm='.$opt_gvm, 'manifest='.$opt_manifest);
}

# Rust [u8] to string
sub convert_string {
    my ($ref) = @_;
    my $str = '';
    foreach my $i (@{$ref}) {
        my $c = chr($i);
        $str .= $c;
    }
    return $str;
}

sub decode_octets {
    my ($msg) = @_;
    my $payload = $msg->{'payload'};
    my $octets = $payload->{'body'};
    my $content = convert_string($octets);
}

# --

sub dump_packet {
    my ($user_mask, $packet) = @_;
    my $mask = $user_mask->{'mask'};
    my $bitmask = sprintf('%016b', $mask);
    my $header = $packet->{'header'};
        my $coded_uuid = $header->{'uuid'};
        my $hex_guid = xlate_uuid($coded_uuid);
        my ($b0, $b1, $real_uuid) = uuid_magic($hex_guid);
        my $hint = hint4uuid($coded_uuid); # not sure which (coded/real) to use here ??
    my $payload = $packet->{'payload'};
        my $is_last = $payload->{'is_last'};
        my $size = $payload->{'size'};
        my $is_blocking = $payload->{'is_blocking'};
        my $msg_id = $payload->{'msg_id'};
        my $bytes = $payload->{'bytes'};
# FIXME : do we always have a $header{'msg_type'} ??
# FIXME : OOB or protocol layer data?
    my $o = {
        'is_blocking' => $is_blocking,
        'is_last' => $is_last,
        'msg_id' => $msg_id,
        'size' => $size,
        'ait_dense' => $b0, # NORMAL(40), AIT(04)
        'port_byte' => $b1,
    };
    return ($hint, $real_uuid, $bitmask, $o, $bytes);
}

# --

my $notes = << '_eof_';

_eof_

}

# for loading:
1;
