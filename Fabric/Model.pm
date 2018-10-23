#!/usr/bin/perl -w

package Fabric::Model v2018.10.13 {

my $endl = "\n";
my $dquot = '"';

use Exporter 'import';
our @EXPORT_OK = qw(
    get_link_no
    wirelist
    order_edges
    find_edge
    activate_edge
    write_border
    write_edge
    dump_edges
    write_link
    order_forest
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
msg_sheet
dump_frames

    $NOT_ALAN
);

use Data::Dumper;
use JSON qw(decode_json encode_json);

use Fabric::TraceData qw(nametype xlate_uuid hint4uuid port_index bytes2dense dump_packet grab_name null_uuid);
use Fabric::Util qw(note_value giveup epoch_marker);

# --

# think unidirectional channel (pair)
# symmetry broken by neighbor agreement, even is dominant
my %link_table; # map : 'Cx:py' -> $link_no

# graphviz format (note :pX is magic)
sub get_link_no {
    my ($c, $p) = @_;
    my $k = 'C'.$c.':p'.$p;
    return $link_table{$k};
}

my @wires; # array {from, to}

sub wirelist {
    my @ary = @{$edge_list};
    foreach my $edge (@ary) {
        my ($left, $right) = (@{$edge});
        my $o = {
            'left' => $left,
            'right' => $right,
        };
        push (@wires, $o);
    }
    return @wires;
}

# --

my $max_edge = 1; # avoid 0
my %edges; # map : 'Cx:pX->Cy:pY' -> { edge_no - left_cell left_port right_cell right_port }; # plus 'Internet'

sub order_edges($$) {
    my ($left, $right) = @_;
    my $l = $edges{$left}{'edge_no'};
    my $r = $edges{$right}{'edge_no'};
    return $l <=> $r;
}

# accelerate with an inverted map
sub find_edge {
    my ($edge_no) = @_;
    # while (my ($k, $o) = each %edges) { # doesn't work??
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
    # FIXME: maybe: //= ??
    $edges{$edge_key} = $edge unless defined $edges{$edge_key};
    my $o = $edges{$edge_key};

    # poor man's lock:
    if ($o->{'edge_no'} == 0) {
        my $edge_no = $max_edge ; $max_edge++; # allocate
        $o->{'edge_no'} = $edge_no;
        # this could be done with edge_no, and then checking the edge object for which end the cell/port is
        my $link_no = $edge_no * 2;
        $link_table{$k1} = $link_no;
        $link_table{$k2} = $link_no + 1;
epoch_marker(); # new edge
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
my %forest; # map : forext_index -> { span_tree child - parent p root link_no}

# FIXME - not completely correct ??
sub order_forest($$) {
    my ($left, $right) = @_;
    my $l_tree = $forest{$left}{'span_tree'};
    my $r_tree = $forest{$right}{'span_tree'};
    return $l_tree cmp $r_tree unless $l_tree eq $r_tree;

    my $l = $forest{$left}{'child'};
    my $r = $forest{$right}{'child'};
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
        'child' => 'C'.$child,
        'parent' => 'C'.$c,
        'p' => $p,
        'root' => $root,
        'link_no' => $link_no
    };
    my $k = $max_forest++;
    $forest{$k} = $o;
epoch_marker(); # new spanning tree edge
    return $k; # really: void
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
    open(FOREST, '>', $path) or die $path.': '.$!;
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

my $NOT_ALAN;

my $max_cell = -1;
my %cell_table; # map : "Cx:p0" => $edge_no

sub cell_table_entry {
    my ($c) = @_;
    return $cell_table{$c} if $cell_table{$c};

    my $k = 'C'.$c.':p0';
    my $edge_no = edge_table_entry($c, 0, $c, 0); # virtual port #0
    $max_cell = $c if $c > $max_cell;
    $cell_table{$c} = $edge_no;
    return $edge_no;
}

# unused ?
sub get_cellagent_port {
    my ($c) = @_;
    my $k = 'C'.$c.':p0';
    my $edge_no = $cell_table{$k};
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

sub dump_complex {
    my ($path) = @_;
    open(DOT, '>', $path) or die $path.': '.$!;
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

# or trick : $entry->{'index'};
my %routing_table; # map : $cell_id -> map $entry{tree_uuid} -> { tree_uuid - inuse may_send parent mask [other_indices] }

sub get_routing_entry {
    my ($cell_id, $key) = @_;
    return $routing_table{$cell_id}->{$key};
}

# FIXME : should we indicate updates ??
sub update_routing_table {
    my ($cell_id, $entry) = @_;
    my $key = $entry->{'tree_uuid'};
    $routing_table{$cell_id}->{$key} = $entry; # autovivication
}

sub dump_routing_tables {
    my ($path) = @_;
    open(FD, '>', $path) or die $path.': '.$!;
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
            my $inuse = $entry->{'inuse'} ? 'Yes' : 'No';
            my $may_send = $entry->{'may_send'} ? 'Yes' : 'No';
            my $parent = port_index($entry->{'parent'});
            my $mask = sprintf('%016b', $entry->{'mask'}{'mask'});
            # my $other_indices = '['.join(', ', @{$entry->{'other_indices'}}).']';

            my $hint = hint4uuid($entry->{'tree_uuid'});
            my $guid_name = grab_name($entry->{'tree_uuid'});
            print FD (join("\t", $hint, $inuse, $may_send, $parent, $mask, $guid_name), $endl); # $index, $other_indices
        }
    }
    close(FD);
}

# --

my @msgqueue; # list : { event_code link_no - tree_id cell_no code };

# ref: "<=>" and "cmp" operators
# return $left cmp $right; # lexically
# return $left <=> $right; # numerically
sub order_msgs($$) {
    my ($left, $right) = @_;
    my $l1 = $left->{'event_code'};
    my $r1 = $right->{'event_code'};
    return $l1 - $r1 unless $l1 == $r1;

    my $l2 = $left->{'link_no'};
    my $r2 = $right->{'link_no'};
    return $l2 - $r2 unless $l2 == $r2;

    giveup(join(' ', 'WARNING: duplicate event/link?', $l1, $l2));
}

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
    'Failover' => 'F',
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
    print STDERR (join(' ', 'missing msg_type:', $msg_type), $endl) unless defined $crypt;

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
    giveup('ec '.$key) unless defined $l3; # bulletproofing
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

# uses the notion that an 'edge' can have 4 pending operations on it simultanously: (left, right) x (xmit rcv).
# There's a possible argument that left-xmit conflicts (must have happens-before) with right-rcv.
# instead, allow for the notion that "the wire" can hold two msgs so that each end can be simultaneously active.
# allows the spreadsheet to be really dense - provided folks reading it understand the game rules

# breaking condition is contention for a queue endpoint
# could construct data into a 2 dimensional data structure (fix number of cells, variable length history)
sub msg_sheet {
    my ($path) = @_;
    open(CSV, '>', $path) or die $path.': '.$!;
    print CSV (join(',', 'event/cell', 0..9), $endl);
    my @row = ();

    my %queue_table;

    foreach my $item (sort order_msgs @msgqueue) {
        my $code = $item->{'code'};
        if (defined $code_filter) { next unless $code =~ $code_filter; }

        my $c = $item->{'cell_no'};
        my $l = $item->{'link_no'};
        my $arrow = $item->{'arrow'};

        my $chan = $l.$arrow;
        my $interlock = $queue_table{$chan};
        $queue_table{$chan}++;

        # causal relationship - cell-agent queue and link queues are sequential
        # check if the queue is busy:
        if (defined $interlock) {
            foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
            print CSV (join(',', $item->{'event_code'}, map { $dquot.$_.$dquot } @row), $endl);
            @row = ();
            %queue_table = ();
        }

        my $prev = $row[$c];
        $code .= $endl.$prev if $prev;
        $row[$c] = $code;
    }

    # dangling data:
    foreach my $i (0..$#row) { $row[$i] = '' unless $row[$i]; } # avoid uninitialized warnings
    print CSV (join(',', 'last', map { $dquot.$_.$dquot } @row), $endl);
    close(CSV);
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
    # FIXME - while?
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

my @frame_seq; # list : { epoch pe_id outbound - ait_code tree msg_id msg_type frame }

sub order_frames($$) {
    my ($left, $right) = @_;
    return $left->{epoch} <=> $right->{epoch} unless $left->{epoch} == $right->{epoch};
    return $left->{pe_id} cmp $right->{pe_id} unless $left->{pe_id} eq $right->{pe_id};
    return $left->{outbound} <=> $right->{outbound};
}

sub parse_portcode {
    my ($portcode) = @_;
    $portcode =~ m/^C(\d+)p(\d+)$/;
    return ($1, $2);
}

# FIXME : hardwired blueprint of triangle-demo
# connectors numbered starting at 1
# formula: 'C<N> p<x+1> : C<X> p<n+1>'
# C2:C-1
my $blueprint_codex = << '_eor_';
{
    "C0p2":"C1p1",
    "C0p3":"C2p1",
    "C0p4":"C3p1",

    "C1p1":"C0p2",
    "C1p3":"C2p2",
    "C1p4":"C3p2",

    "C2p1":"C0p3",
    "C2p2":"C1p3",
    "C2p4":"C3p3",

    "C3p1":"C0p4",
    "C3p2":"C1p4",
    "C3p3":"C2p4"
}
_eor_


sub chan_remap {
    my ($blueprint_graph) = @_;
    my %m;
    while (my ($key, $value) = each %{$blueprint_graph}) {
        my ($left_cell, $left_port) = parse_portcode($key);
        my ($right_cell, $right_port) = parse_portcode($value);
        my $cell_pair = 'C'.$left_cell.':C'.$right_cell;
        $m{$cell_pair} = $left_port; # outbound
    }
    return \%m;
}

sub target_cell {
    my ($c, $p) = @_;
    my $link_no = get_link_no($c, $p);
    my $edge_no = int($link_no / 2);
    my $compass = $link_no % 2;
    my $e = find_edge($edge_no);
    my $lc = $e->{'left_cell'};
    my $lp = $e->{'left_port'};
    my $rc = $e->{'right_cell'};
    my $rp = $e->{'right_port'};
    my $t = ($compass) ? $lc : $rc;
    return ($t, $compass);
}

sub dump_frames {
    my ($path) = @_;
    my $blueprint_graph = decode_json($blueprint_codex);
    my $channel_remap = chan_remap($blueprint_graph);
    open(FRAMEOUT, '>', $path) or die $path.': '.$!;
    foreach my $o (sort order_frames @frame_seq) {
        my $c = $o->{pe_id}; $c =~ s/C://;
        my $p = $o->{outbound};
        my ($t, $bias) = target_cell($c, $p);
        giveup('missing target - cell: '.$o->{pe_id}.' port: '.$p) unless defined $t;

        next if $t < 0; # write to Internet ??
        next if $c == $t; # PE to CellAgent ?

        my $cell_pair = 'C'.$c.':C'.$t;
        my $device_index = $channel_remap->{$cell_pair};
        giveup('no wiring: '.$cell_pair) unless defined $device_index;

        $o->{outbound} = $device_index; # patch in place:
        my $meta = JSON->new->canonical->encode($o);
        print FRAMEOUT ($meta, $endl);
    }
    close(FRAMEOUT);
}

# phy enqueue C:1 2 TOCK 0x400074367c704351baf6176ffc4e1b6a msg_id=9060533230310021231 7b226d7367... ;
sub phy_enqueue {
    my ($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame) = @_;
    print(join(' ', '   ', 'phy enqueue', $epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, 'msg_id='.$msg_id, substr($frame, 0, 10).'...', ';'));
    my $o = {
        'epoch' => $epoch,
        'pe_id' => $pe_id,
        'outbound' => $outbound,
        'ait_code' => $ait_code,
        'tree' => $tree,
        'msg_id' => $msg_id,
        'msg_type' => $msg_type,
        'frame' => $frame,
    };
    push(@frame_seq, $o);
}

sub xmit_tcp_frame {
    my ($epoch, $pe_worker, $outbound, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $ait_code = 'NORMAL';
    my $tree = null_uuid();
    my $msg_id = 0;
    my $msg_type = 'TCP';
    phy_enqueue($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame); # if $port_mask & $bit;
    # 'ROOTWARD'
}

# special processing
sub eccf_ait {
    my ($epoch, $pe_worker, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    # post event to PE at other end of edge
    my $route = JSON->new->canonical->encode($entry);
    my $meta = JSON->new->canonical->encode($o);
    print main::DBGOUT (join(' ', 'multicast', $pe_id, $bitmask, $tree, $route), $endl);
    print main::DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};
    my $msg_type = $o->{'msg_type'};

    my $ait_dense = $o->{'ait_dense'};
    my $ait_state = ait_next($ait_dense);
    my $ait_code = ait_unname($ait_state);

    print main::DBGOUT (join(' ', 'bad ait?', $ait_dense, $ait_state), $endl) unless $ait_code;

    my $route_mask = $entry->{'mask'}{'mask'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)
    my $port_mask = ($limit_mask & $route_mask);
# FIXME : going up ??
    for my $outbound (0..$maxport) {
        my $bit = 1 << $outbound;
        next unless $port_mask & $bit;
        phy_enqueue($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame); # if $port_mask & $bit;
    }
}

# forward
sub eccf_normal {
    my ($epoch, $pe_worker, $port_no, $tree, $entry, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};
    my $limit_mask = unpack('B*', $bitmask); # ascii_to_binary(numeric)

    # post event to PE at other end of edge
    my $route = JSON->new->canonical->encode($entry);
    my $meta = JSON->new->canonical->encode($o);
    print main::DBGOUT (join(' ', 'multicast', $pe_id, $port_no, $tree, $route), $endl);
    print main::DBGOUT (join(' ', 'phy-set', $pe_id, $meta, $endl, '   ', $frame), $endl);

    my $msg_id = $o->{'msg_id'};
    my $msg_type = $o->{'msg_type'};

    my $parent = $entry->{'parent'};
    my $route_mask = $entry->{'mask'}{'mask'};
    my $port_mask = ($limit_mask & $route_mask);

    # Leafward
    if ($port_no == $parent) {
# FIXME : going up ??
        for my $outbound (0..$maxport) {
            my $bit = 1 << $outbound;
            next unless $port_mask & $bit;
            my $ait_code = 'NORMAL';
            phy_enqueue($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
    # RootWard
    else {
        if ($parent) {
# FIXME : is 'ports' all ports or just phy-ports?
# FIXME : going up ??
            for my $outbound (0..$maxport) {
                my $bit = 1 << $outbound;
                next unless $port_mask & $bit;
                my $ait_code = 'NORMAL';
                phy_enqueue($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame); # if $port_mask & $bit;
            }
        }
        # fallsthru
        my $going_up = ($port_mask == $cm_bitmask);
        if (!$parent || $going_up) {
# FIXME : going up ??
            # ca.enqueue()
            my $outbound = 0;
            my $ait_code = 'NORMAL';
            phy_enqueue($epoch, $pe_id, $outbound, $ait_code, $tree, $msg_type, $msg_id, $frame); # if $port_mask & $bit;
        }
    }
}

sub xmit_eccf_frame {
    my ($epoch, $pe_worker, $real_uuid, $bitmask, $o, $frame) = @_;
    my $pe_id = $pe_worker->{'pe_id'};

    my $table = $pe_worker->{'table'};
    my $entry = $table->{$real_uuid};
    print main::DBGOUT (join(' ', 'table miss?', $pe_id, $real_uuid, Dumper $table), $endl) unless $entry;

    my $ait_dense = $o->{'ait_dense'};

    # AIT(04)
    if ($ait_dense eq '04') {
        eccf_ait($epoch, $pe_worker, $real_uuid, $entry, $bitmask, $o, $frame);
    }

    # NORMAL(40)
    if ($ait_dense eq '40') {
        my $port_no = 0;
        eccf_normal($epoch, $pe_worker, $port_no, $real_uuid, $entry, $bitmask, $o, $frame);
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
    my ($epoch, $cell_id, $tag, @args) = @_;
    print(join(' ', $cell_id, 'pe-raw-api', $tag, @args, ';'));

    print main::DBGOUT (join(' ', 'PE-API', $cell_id, $epoch, $tag, ''));

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
        xmit_eccf_frame($epoch, $pe_worker, $real_uuid, $bitmask, $o, $frame);
        return;
    }

    # pub type TCP = (ISAIT, AllowedTree, TcpMsgType, MsgDirection, ByteArray);
    if ($tag eq 'Tcp') {
        my ($port_number, $msg) = @args;
        my $outbound = $port_number->{'port_no'};
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
        print main::DBGOUT (join(' ', $outbound, $some), $endl);
        xmit_tcp_frame($epoch, $pe_worker, $outbound, $frame);
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
