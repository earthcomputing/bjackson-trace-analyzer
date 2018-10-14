#!/usr/bin/perl -w

package Fabric::Model v2018.10.13 {

our $endl = "\n";

use Exporter 'import';
our @EXPORT_OK = qw(
    get_link_no
    order_edges
    find_edge
    edge_table_entry
    activate_edge
    write_border
    write_edge
    dump_edges
    write_link
    order_forest
    add_tree_link
    add_overlay
    dump_forest
    dump_complex
    cell_table_entry
    get_cellagent_port
    border_port
    get_routing_entry
    update_routing_table
    dump_routing_tables
    letters
    add_msgcode
    ec_fromkey
    add_msgcode2
    pe_api

    do_treelink
    do_application
    do_manifest
);

use JSON qw(encode_json);

use Fabric::TraceData qw(nametype xlate_uuid hint4uuid port_index bytes2dense dump_packet grab_name);
use Fabric::Util qw(note_value giveup get_epoch epoch_marker);

# --

my %link_table; # map : 'Cx:py' -> $link_no

# graphviz format (note :pX is magic)
sub get_link_no {
    my ($c, $p) = @_;
    my $k = 'C'.$c.':p'.$p;
    return $link_table{$k};
}

# --

my $max_edge = 1; # avoid 0
my %edges; # map : "Cx:pX->Cy:pY" -> { 'left_cell' 'left_port' 'right_cell' 'right_port' 'edge_no' }; # plus 'Internet'

sub order_edges($$) {
    my ($left, $right) = @_;
    my $l = $edges{$left}{'edge_no'};
    my $r = $edges{$right}{'edge_no'};
    return $l <=> $r;
}

# accelerate with an inverted map
sub find_edge {
    my ($edge_no) = @_;
    foreach my $k (keys %edges) {
        my $o = $edges{$k};
        return $o if $o->{'edge_no'} == $edge_no;
    }
    giveup('find_edge: not found? '.$edge_no);
}

# indicate EAST/WEST direction (a, a')
# do that with even/odd numbers
# ISSUE : knows direction, so key really matters (don't allow both!)
# could canonicalize by sorting cell numbers (uuid)
sub edge_table_entry {
    my ($lc, $lp, $rc, $rp) = @_;
    my $k1 = 'C'.$lc.':p'.$lp; $k1 = 'Internet' if $lc == -1;
    my $k2 = 'C'.$rc.':p'.$rp;
    my $edge_key = $k1.'->'.$k2;
    my $edge = {
        'left_cell' => $lc,
        'left_port' => $lp,
        'right_cell' => $rc,
        'right_port' => $rp,
        'edge_no' => 0 # illegal value
    };
    # not threadsafe: conditionally stores object, then updates it.
    $edges{$edge_key} = $edge unless defined $edges{$edge_key};
    my $o = $edges{$edge_key};
    if ($o->{'edge_no'} == 0) {
        my $edge_no = $max_edge ; $max_edge++; # allocate
        $o->{'edge_no'} = $edge_no;
        # this could be done with edge_no, and then checking the edge object for which end the cell/port is
        my $link_no = $edge_no * 2;
        $link_table{$k1} = $link_no;
        $link_table{$k2} = $link_no + 1;
    }
    return $o->{'edge_no'};
}

sub activate_edge {
    my ($lc, $lp, $rc, $rp) = @_;
    my $edge_no = edge_table_entry($lc, $lp, $rc, $rp);
    my $c1_up = cell_table_entry($lc);
    my $c2_up = cell_table_entry($rc);
    # write_edge($lc, $lp, $rc, $rp, $edge_no);
}

# --

# info from border_port / meth_ca_send_msg_port_connected
sub write_border {
    my ($c, $p, $edge_no) = @_;
    if ($NOT_ALAN) {
        my $link_name = 'link#'.$edge_no;
        printf DOT ("Internet -> C%d:p%d [label=\"p%d,\\n%s\"]\n", $c, $p, $p, $link_name);
    }
    else {
        my $link_no = $edge_no * 2;
        my $link_name = letters($link_no);
        printf DOT ("Internet -> C%d:p%d [label=\"%s\"]\n", $c, $p, $link_name);
    }
}

# info from activate_edge / meth_connect_link
sub write_edge {
    my ($lc, $lp, $rc, $rp, $edge_no) = @_;
    if ($NOT_ALAN) {
        my $link_name = 'link#'.$edge_no;
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"p%d:p%d,\\n%s\"]\n", $lc, $lp, $rc, $rp, $lp, $rp, $link_name);
    }
    else {
        my $link_no = $edge_no * 2;
        my $link_name = letters($link_no);
        printf DOT ("C%d:p%d -> C%d:p%d [label=\"%s\"]\n", $lc, $lp, $rc, $rp, $link_name);
    }
}

sub dump_edges {
    foreach my $k (sort order_edges keys %edges) {
        my $o = $edges{$k};
        my $left_cell = $o->{'left_cell'};
        my $left_port = $o->{'left_port'};
        my $right_cell = $o->{'right_cell'};
        my $right_port = $o->{'right_port'};
        my $edge_no = $o->{'edge_no'};

        if ($left_cell == -1) { # eq 'Internet') {
            write_border($right_cell, $right_port, $edge_no);
        }
        else {
            write_edge($left_cell, $left_port, $right_cell, $right_port, $edge_no);
        }
    }
}

# --

sub write_link {
    my ($link_no, $label) = @_;
    my $edge_no = int($link_no / 2);
    my $compass = $link_no % 2;

    my $o = find_edge($edge_no);

    my $lc = $o->{'left_cell'};
    my $lp = $o->{'left_port'};
    my $rc = $o->{'right_cell'};
    my $rp = $o->{'right_port'};

    giveup('bad link') if ($lc == -1); # 'Internet'

    if ($compass) {
        my $attrs = '[label="'.$label.'" color=red]';
        printf DOT ("C%d:p%d -> C%d:p%d %s\n", $lc, $lp, $rc, $rp, $attrs); # [label=\"p%d:p%d,\\n%s\"]
    }
    else {
        my $attrs = '[label="'.$label.'" color=blue]';
        printf DOT ("C%d:p%d -> C%d:p%d %s\n", $rc, $rp, $lc, $lp, $attrs); # [label=\"p%d:p%d,\\n%s\"]
    }
}

# --

my $max_forest = 1;
my %forest; # map : int -> { span_tree parent p child }

sub order_forest($$) {
    my ($left, $right) = @_;
    my $l_tree = $forest{$left}{'span_tree'};
    my $r_tree = $forest{$right}{'span_tree'};
    return $l_tree cmp $r_tree unless $l_tree eq $r_tree;

    my $l = $forest{$left}{'child'};
    my $r = $forest{$right}{'child'};
    # return $l <=> $r;
    return $l cmp $r;
}

sub add_tree_link {
    my ($tree_id, $c, $p, $child) = @_;

    my $link_no = get_link_no($c, $p);
    my $root;
    {
        my ($x, $y, $c) = split(':', $tree_id);
        $root = $c;
        $root = $y unless defined $root;
        print STDERR (join(' ', 'WARNING: parse error', $tree_id, $link_no), $endl) unless defined $root;
    }
    $tree_id =~ s/C:/C/;

    my $o = {
        'span_tree' => $tree_id,
        'parent' => 'C'.$c,
        'p' => $p,
        'child' => 'C'.$child,
        'root' => $root,
        'link_no' => $link_no
    };
    my $k = $max_forest++;
    $forest{$k} = $o;
}

sub add_overlay {
    my %target;
    foreach my $k (sort order_forest keys %forest) {
        my $o = $forest{$k};
        my $root = $o->{'root'};
        my $link_no = $o->{'link_no'};
        next unless defined $root; # defensive against parse errors

        $target{$link_no} = [] unless $target{$link_no}; # ensure defined
        push(@{$target{$link_no}}, $root);

    }
    foreach my $l (sort keys %target) {
        my @cells = @{$target{$l}};
        my $label = '( C'.join(' C', sort @cells).' )'; # list of roots
        write_link($l, $label);
    }
}

my $gamut = {
    'C0' => 'red',
    'C1' => 'green',
    'C2' => 'blue',
    'C3' => 'cyan',
    'C4' => 'magenta',
    'C5' => 'purple', # 'yellow' - bad visual choices
    'C6' => 'navy',
    'C7' => 'green',
    'C8' => 'maroon',
    'C9' => 'turquoise4', # teal, 'olive'

    'C2+NocAgentDeploy' => 'cyan',
    'C2+NocMasterDeploy' => 'magenta',
    'C2+NocAgentMaster' => 'navy',
    'C2+NocMasterAgent' => 'maroon',
    'C2+Noc' => 'maroon',

    'C0+Connected' => 'black',
    'C1+Connected' => 'black',
    'C2+Connected' => 'black',
    'C0+Control' => 'black',
    'C1+Control' => 'black',
    'C2+Control' => 'black'
};

sub pick_color {
    my ($span_tree) = @_;
    $span_tree =~ s/Tree://;
    my $color = $gamut->{$span_tree};
    return 'black' unless $color;
    return $color;
}

# C1 -> C0:p1 [label="Tree:C0" color=red]
sub dump_forest {
    my ($path) = @_;
    open(FOREST, '>'.$path) or die $path.': '.$!;
    print FOREST ('digraph G {', $endl);
    print FOREST ('rankdir=LR', $endl);
    # print FOREST (join(' ', 'span-tree', 'parent', 'link', 'child'), $endl);
    foreach my $k (sort order_forest keys %forest) {
        my $o = $forest{$k};
        my $parent = $o->{'parent'};
        my $child = $o->{'child'};
        my $span_tree = $o->{'span_tree'};
        my $port = $o->{'p'};
        my $link_no = $o->{'link_no'};

{
        # child is other side of link!
        my $compass = $link_no % 2;
        my $edge_no = int($link_no / 2);
        my $e = find_edge($edge_no);
        my $lc = $e->{'left_cell'};
        my $lp = $e->{'left_port'};
        my $rc = $e->{'right_cell'};
        my $rp = $e->{'right_port'};
        giveup('bad link') if ($lc == -1); # 'Internet'
        my $left = 'C'.$lc.':p'.$lp;
        my $right = 'C'.$rc.':p'.$rp;
        $child = ($compass) ? $left : $right;
}
        my $dst_link = $parent.':p'.$port;
        my $src_link = $child;

        my $left = $src_link;
        my $right = $dst_link;
        my $label = $span_tree;
        my $color = pick_color($span_tree);

        my $attrs = '[label="'.$label.'" color='.$color.']';
        print FOREST (join(' ', $left, '->', $right, $attrs), $endl);
    }
    print FOREST ('}', $endl);
    close(FOREST);
}

# --

sub dump_complex {
    my ($path) = @_;
    open(DOT, '>'.$path) or die $path.': '.$!;
    print DOT ('digraph G {', $endl);
    print DOT ('rankdir=LR', $endl);
    dump_edges();
    foreach my $c (sort keys %cell_table) {
        my $c_up = $cell_table{$c}; # edge_no
        next if ($c == -1); # Internet
        my $link_no = ($c_up * 2) + 1;
        my $cell_lname = ($NOT_ALAN) ? 'link#'.$link_no : letters($link_no);
        printf DOT ("C%d [label=\"C%d  (%s)\"]\n", $c, $c, $cell_lname);
    }
    add_overlay();
    print DOT ('}', $endl);
    close(DOT);
}

# --

my $max_cell = -1;
my %cell_table; # $c => $edge_no

sub cell_table_entry {
    my ($c) = @_;
    $max_cell = $c if $c > $max_cell;
    return $cell_table{$c} if $cell_table{$c};

    my $edge_no = edge_table_entry($c, 0, $c, 0); # virtual port #0
    my $k = 'C'.$c.':p0';
    $cell_table{$c} = $edge_no;
    return $edge_no;
}

# unused ?
sub get_cellagent_port {
    my ($c) = @_;
    my $edge_no = $cell_table{$c};
    return $edge_no;
}

# Internet+C:1+P:2
sub border_port {
    my ($cell_id, $port_no) = @_;
    my ($tag, $c) = split(':', $cell_id);
    my $port_index = $port_no; $port_index =~ s/[^\d]//g;
    my $edge_no = edge_table_entry(-1, 0, $c, $port_index);
    my $c_up = cell_table_entry($c);
    # write_border($c, $port_index, $edge_no);
}

# --

my %routing_table; # map : {$cell_id}{$entry->{'tree_uuid'}} => $entry

sub get_routing_entry {
    my ($cell_id, $key) = @_;
    return $routing_table{$cell_id}->{$key};
}

sub update_routing_table {
    my ($cell_id, $entry) = @_;
    my $key = $entry->{'tree_uuid'}; # $entry->{'index'};
    $routing_table{$cell_id} = { } unless defined $routing_table{$cell_id};
    my $table = $routing_table{$cell_id};
    $table->{$key} = $entry;
    # FIXME : should we indicate updates ??
}

sub dump_routing_tables {
    my ($path) = @_;
    open(FD, '>'.$path) or die $path.': '.$!;
    foreach my $cell_id (sort keys %routing_table) {
        print FD ($endl);
        print FD (join(' ', $cell_id, 'Routing Table'), $endl);

        my $routes = $routing_table{$cell_id};

        my $order_routes = sub ($$) {
            my ($left, $right) = @_;
            my $l = $routes->{$left};
            my $r = $routes->{$right};
            return $l cmp $r unless $l eq $r;
            return $left cmp $right;
        };

        foreach my $key (sort { $order_routes->($a, $b) } keys %{$routes}) {
            my $entry = $routes->{$key};
            # my $index = $entry->{'index'};
            my $hint = hint4uuid($entry->{'tree_uuid'});
            my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
            my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
            my $parent = port_index($entry->{'parent'});
            my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
            # my $other_indices = '['.join(', ', @{$entry->{'other_indices'}}).']';
            my $guid_name = grab_name($entry->{'tree_uuid'});
            print FD (join("\t", $hint, $inuse, $may_send, $parent, $mask, $guid_name), $endl); # $index, $other_indices
        }
    }
    close(FD);
}

# --

my $arrow_code = {
    'cell-rcv' => '<',
    'cell-snd' => '>',
    'pe-rcv' => '<-',
    'pe-snd' => '->'
};

my $op_table = {
    'Application' => 'A',
    'Discover' => 'D',
    'DiscoverD' => 'DD',
    'Hello' => 'H',
    'Manifest' => 'M',
    'StackTree' => 'S',
    'StackTreeD' => 'SD'
};

sub letters {
    my ($link_no) = @_;
    my $edge_no = int($link_no / 2);
    my $compass = $link_no % 2;
    my $star = ($compass == 0) ? '' : "'";

    my $little = $edge_no % 26;
    my $more = int($edge_no / 26);

    my $ch0 = chr($little + ord('a') - 1);
    my $ch1= chr($more + ord('a') - 1);
    my $name = $ch0; $name = $ch1.$ch0 if $more > 0; # 676 edges (vs. 17,576 or 456,976 edges)
    return $name.$star;
}

# link#
# $dir : cell-rcv, cell-snd, pe-rcv, pe-snd
sub add_msgcode {
    my ($c, $p, $msg_type, $event_code, $dir, $tree_id) = @_;
    # swimming against the flow, or not ??
    # relate to the wiring diagram, trees segments can be upside-down!
    my $link_no = get_link_no($c, $p);
    return unless $link_no; # ugh, issue with 0

    my $arrow = $arrow_code->{$dir};
    my $crypt = $op_table->{$msg_type}; # FIXME - missing msg_type's here ...
    my $link_code = ($NOT_ALAN) ?  'link#'.$link_no : letters($link_no);
    my $code = $crypt.$arrow.$link_code.' '.'('.$tree_id.')'; # $blank
    my $o = {
        'event_code' => $event_code,
        'tree_id' => $tree_id,
        'cell_no' => $c,
        'link_no' => $link_no,
        'arrow' => $arrow,
        'code' => $code
    };

    print main::DBGOUT (join(' ', 'msgcode',
        $msg_type,
        $o->{'event_code'},
        $o->{'tree_id'},
        'C'.$o->{'cell_no'}.'p'.$p,
        $o->{'link_no'},
        $o->{'arrow'},
        $o->{'code'}
        ), $endl);
    push(@msgqueue, $o);
}

sub ec_fromkey {
    my ($key) = @_;
    my ($l1, $l2, $l3) = split('::', $key);
    die('ec '.$key) unless defined $l3; # bulletproofing
    return $l3; # aka lineno
}

## Spreadsheet Coding:
sub add_msgcode2 {
    my ($tag, $tree_id, $port, $body, $key) = @_;
    my $event_code = ec_fromkey($key); # aka lineno

    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $header = $msg->{'header'};
    my $payload = $msg->{'payload'};
    my $msg_type = $header->{'msg_type'};

    my $c = $cell_id; $c =~ s/C://;
    add_msgcode($c, $port, $msg_type, $event_code, $tag, $tree_id);
}

# --
# Routing Table

sub dump_entry {
    my ($entry) = @_;
    my $hint = hint4uuid($entry->{'tree_uuid'});
    my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
    my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
    my $parent = port_index($entry->{'parent'});
    my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
    return join(' ', $hint, $inuse, $may_send, $parent, $mask);
}

# --
# ait byte coding

my $ait_code = {
    '00' => 'TICK',
    '01' => 'TOCK',
    '02' => 'TACK',
    '03' => 'TECK',
    '04' => 'AIT',
    '40' => 'NORMAL',
    # '00' => 'FORWARD',
    '80' => 'REVERSE'
};

# seq : 'AIT ' => 'TECK' => 'TACK' => 'TOCK' => 'TICK' => 'TOCK'
my $ait_forward = {
    'TICK' => 'TOCK',
    'TOCK' => 'TICK',
    'TACK' => 'TOCK',
    'TECK' => 'TACK',
    'AIT ' => 'TECK',
    'NORMAL' => 'NORMAL'
};

# seq : 'TICK' => 'TOCK' => 'TACK' => 'TECK' => 'AIT'
my $ait_backward = {
    'TICK' => 'TOCK',
    'TOCK' => 'TACK',
    'TACK' => 'TECK',
    'TECK' => 'AIT',
    'NORMAL' => 'NORMAL'
};

# binary (octet) to name (string)
sub ait_name {
    my ($octet) = @_;
    my $ait_dense = sprintf("%02x", $octet);
    my $name = $ait_code->{$ait_dense};
    print main::DBGOUT (join(' ', 'bad ait code:"'.$ait_dense.'"'), $endl) unless $name;
    return $name;
}

# name to ait_dense/hex (string)
sub ait_unname {
    my ($name) = @_;
    return undef unless $name;
    foreach my $key (keys %{$ait_code}) {
        my $value = $ait_code->{$key};
        return $value if $name eq $value;
    }
    print main::DBGOUT (join(' ', 'bad ait name:"'.$name.'"'), $endl) unless $name;
    return undef;
}

# ait_dense/hex (string) to struct
sub ait_decode {
    my ($ait_dense) = @_;
    my $octet = hex('0x'.$ait_dense);
    my $dir = ($octet & 0x80) ? 'REVERSE' : 'FORWARD'; # ait_name - FORWARD/TICK ??
    my $flavor = ait_name($octet & 0x44);
    my $state = ait_name($octet & 0x03);
    return ($dir, $flavor, $state);
}

# --
# ait state sequence:

# cycle AIT state machine - ait_dense/hex (string) to name (string)
sub ait_next {
    my ($ait_dense) = @_;
    my ($dir, $flavor, $state) = ait_decode($ait_dense);
    return $ait_forward->{$state} if $dir eq 'FORWARD';
    return $ait_backward->{$state} if $dir eq 'REVERSE';
    return undef;
}

# --
# PE model

my $maxport = 7;
my $cm_bitmask = 1 << 0;

my %pe_workers; # map : cell_id => object

# phy - ports/links
sub get_worker {
    my ($cell_id) = @_;
    my $w = $pe_workers{$cell_id};
    return $w if $w;

    my $o = {
        'pe_id' => $cell_id, # debug
        'block' => undef,
        'table' => {},
        'phy' => [],
    };
    $pe_workers{$cell_id} = $o;
    return $o;
}

# --

# phy enqueue C:1 2 TOCK 0x400074367c704351baf6176ffc4e1b6a msg_id=9060533230310021231 7b226d7367... ;
sub phy_enqueue {
    my ($pe_id, $outbound, $ait_code, $tree, $msg_id, $frame) = @_;
    print(join(' ', '   ', 'phy enqueue', $pe_id, $outbound, $ait_code, $tree, 'msg_id='.$msg_id, substr($frame, 0, 10).'...', ';'));
    my $o = {
        'pe_id' => $pe_id,
        'outbound' => $outbound,
        'ait_code' => $ait_code,
        'tree' => $tree,
        'msg_id' => $msg_id,
        'frame' => $frame,
    };
    my $meta = JSON->new->canonical->encode($o);
    print main::FRAMEOUT ($meta, $endl);
}

sub xmit_tcp_frame {
    my ($pe_worker, $port_no, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $ait_code = 'NORMAL';
    my $tree = $TraceData::null_uuid;
    my $msg_id = 0;
    phy_enqueue($pe_id, $port_no, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
    # 'ROOTWARD'
}
# special processing
sub eccf_ait {
    my ($pe_worker, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    # post event to PE at other end of edge
    my $route = JSON->new->canonical->encode($entry);
    my $meta = JSON->new->canonical->encode($o);
    print main::DBGOUT (join(' ', 'multicast', $pe_id, $bitmask, $tree, $route), $endl);
    print main::DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};

    my $ait_dense = $o->{'ait_dense'};
    my $ait_state = ait_next($ait_dense);
    my $ait_code = ait_unname($ait_state);

    print main::DBGOUT (join(' ', 'bad ait?', $ait_dense, $ait_state), $endl) unless $ait_code;

    my $route_mask = $entry->{'mask'}{'mask'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)
    my $port_mask = ($limit_mask & $route_mask);
# FIXME : going up ??
    for my $i (0..$maxport) {
        my $bit = 1 << $i;
        next unless $port_mask & $bit;
        phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
    }
}

# forward
sub eccf_normal {
    my ($pe_worker, $port_no, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)

    # post event to PE at other end of edge
    my $route = JSON->new->canonical->encode($entry);
    my $meta = JSON->new->canonical->encode($o);
    print main::DBGOUT (join(' ', 'multicast', $pe_id, $port_no, $tree, $route), $endl);
    print main::DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};

    my $parent = $entry->{'parent'};
    my $route_mask = $entry->{'mask'}{'mask'};
    my $port_mask = ($limit_mask & $route_mask);

    # Leafward
    if ($port_no == $parent) {
# FIXME : going up ??
        for my $i (0..$maxport) {
            my $bit = 1 << $i;
            next unless $port_mask & $bit;
            my $ait_code = 'NORMAL';
            phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
    # RootWard
    else {
        if ($parent) {
# FIXME : is 'ports' all ports or just phy-ports?
# FIXME : going up ??
            for my $i (0..$maxport) {
                my $bit = 1 << $i;
                next unless $port_mask & $bit;
                my $ait_code = 'NORMAL';
                phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
            }
        }
        # fallsthru
        my $going_up = ($port_mask == $cm_bitmask);
        if (!$parent || $going_up) {
# FIXME : going up ??
            # ca.enqueue()
            my $i = 0;
            my $ait_code = 'NORMAL';
            phy_enqueue($pe_id, $i, $ait_code, $tree, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
}

sub xmit_eccf_frame {
    my ($pe_worker, $real_uuid, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $table = $pe_worker->{'table'};
    my $entry = $table->{$real_uuid};
    print main::DBGOUT (join(' ', 'table miss?', $pe_id, $real_uuid, Dumper $table), $endl) unless $entry;

    my $ait_dense = $o->{'ait_dense'};

    # AIT(04)
    if ($ait_dense eq '04') {
        eccf_ait($pe_worker, $real_uuid, $entry, $bitmask, $o, $frame);
    }

    # NORMAL(40)
    if ($ait_dense eq '40') {
        my $port_no = 0;
        eccf_normal($pe_worker, $port_no, $real_uuid, $entry, $bitmask, $o, $frame);
    }
}

# ugh. special case handling of rust 'match' complicates things:
# reverse-engineer arg-list (0, 1, n)

## CmToPePacket::Unblock => {
## CmToPePacket::Entry(entry) => {
## CmToPePacket::Packet((user_mask, mut packet)) => {
## CmToPePacket::Tcp((port_number, msg)) => {

## listen_cm_loop C:1 raw-api Unblock ;
## listen_cm_loop C:2 raw-api Entry ref=HASH ;
## listen_cm_loop C:2 raw-api Packet HASH(0x7fde9b268610) HASH(0x7fde9b268628) ;
## listen_cm_loop C:2 raw-api Tcp HASH(0x7fde9a00bf38) ARRAY(0x7fde9a00bf50) ;
sub pe_api {
    my ($cell_id, $tag, @args) = @_;
    print(join(' ', $cell_id, 'pe-raw-api', $tag, @args, ';'));

    my $e = get_epoch();
    print main::DBGOUT (join(' ', 'PE-API', $cell_id, $e, $tag, ''));

    my $pe_worker = get_worker($cell_id);

    if ($tag eq 'Unblock') {
        my $was = $pe_worker->{'block'};
        $pe_worker->{'block'} = undef;
        print main::DBGOUT ('was='.($was ? 'true' : 'false'), $endl);
        return;
    }

    if ($tag eq 'Entry') {
        my ($entry) = @args;
        my $uuid = $entry->{'tree_uuid'};
        my $hex_guid = lc(xlate_uuid($uuid));
        my $table = $pe_worker->{'table'};
        my $current_entry = $table->{$hex_guid};
        $table->{$hex_guid} = $entry;
        print main::DBGOUT (join(' ', ($current_entry) ? '[update]' : '[create]', $hex_guid, dump_entry($entry)), $endl);
        return;
    }

    if ($tag eq 'Packet') {
        my ($user_mask, $packet) = @args;
        my ($hint, $real_uuid, $bitmask, $o, $frame) = dump_packet($user_mask, $packet);
        my $meta = JSON->new->canonical->encode($o);
        my $some = substr($frame, -40).'...';
        print main::DBGOUT (join(' ', $hint, $real_uuid, $bitmask, $meta, 'octets='.$some), $endl);
        xmit_eccf_frame($pe_worker, $real_uuid, $bitmask, $o, $frame);
        return;
    }

    # pub type TCP = (ISAIT, AllowedTree, TcpMsgType, MsgDirection, ByteArray);
    if ($tag eq 'Tcp') {
        my ($port_number, $msg) = @args;
        my $port_no = $port_number->{'port_no'};
        my @tcpargs = @{$msg}; # $#tcpargs is 4
        my $isAit = $tcpargs[0]; # 'JSON::PP::Boolean'
        my $allowed_tree = $tcpargs[1]; # object
        my $tcp_msg_type = $tcpargs[2]; # String : Application, DeleteTree, Manifest, Query, StackTree, TreeName
        my $dir = $tcpargs[3]; # String : Rootward/Leafward
        my $octets = $tcpargs[4]; # u8[]

        my $body_dense = bytes2dense($octets);
print main::DBGOUT (join(' ', 'Tcp', $isAit ? 'AIT' : 'NORMAL', $allowed_tree->{'name'}, $tcp_msg_type, $dir), $endl);
# FIXME:
        my $str = JSON->new->canonical->encode($msg);
        my $frame = unpack("H*",  $str); # ascii_to_hex
        my $some = substr($frame, -40).'...';
        print main::DBGOUT (join(' ', $port_no, $some), $endl);
        xmit_tcp_frame($pe_worker, $port_no, $frame);
        return;
    }

    print main::DBGOUT ('unknown tag?', $endl);
}

# --
# CellAgent behaviors

my $note2 = << '_eor_';

APPLICATION: C0p2 Tree:C:2+NocMasterAgent Sender:C:2+VM:C:2+vm1
APPLICATION: C1p2 Tree:C:2+NocMasterAgent Sender:C:2+VM:C:2+vm1
APPLICATION: C2p1 Tree:C:2+NocAgentMaster Sender:C:0+VM:C:0+vm1
APPLICATION: C2p3 Tree:C:2+NocAgentMaster Sender:C:1+VM:C:1+vm1

    do_treelink 2 1 Tree:C:2+NocAgentDeploy Sender:C:2+BorderPort+2
    do_treelink 2 3 Tree:C:2+NocAgentDeploy Sender:C:2+BorderPort+2
    do_treelink 2 1 Tree:C:2+NocMasterAgent Sender:C:2+BorderPort+2
    do_treelink 2 3 Tree:C:2+NocMasterAgent Sender:C:2+BorderPort+2

_eor_

## Forest / DiscoverD
sub do_treelink {
    my ($c, $p, $tree_id, $sender_id) = @_;
    my ($xtag, $cc, $child, $remain) = split(/[\+:]/, $sender_id); # need child from sender_id
epoch_marker();
    add_tree_link($tree_id, $c, $p, $child);
}

sub do_application {
    my ($c, $p, $tree_id, $sender_id) = @_;
    my $direction;
    print main::DBGOUT (join(' ', 'APPLICATION:', 'C'.$c.'p'.$p, $tree_id, $sender_id), $endl);
}

sub do_manifest {
    my ($c, $p, $tree_id, $sender_id) = @_;
    my $direction;
    print main::DBGOUT (join(' ', 'MANIFEST:', 'C'.$c.'p'.$p, $tree_id, $sender_id), $endl);
}


# --

my $notes = << '_eof_';

_eof_

}

# for loading:
1;