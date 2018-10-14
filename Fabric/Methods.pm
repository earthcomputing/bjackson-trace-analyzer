#!/usr/bin/perl -w

package Fabric::Methods v2018.10.13 {

my $endl = "\n";
my $dquot = '"';

use Exporter 'import';
our @EXPORT_OK = qw( register_methods );

use Fabric::Util qw(note_value epoch_marker);
use Fabric::DispatchTable qw(extend_table);
use Fabric::TraceData qw(
    nametype
    port_index
    portdesc
    summarize_msg
    build_port_list
    decode_octets
);
use Fabric::Model qw(
    activate_edge
    update_routing_table
    add_msgcode2
    pe_api
    ec_fromkey
    add_msgcode
    add_msgcode2
    border_port
    do_treelink
    do_application
    do_manifest
);


sub register_methods {
    my $updates = {
        'cellagent.rs$$add_saved_discover$$Debug$$ca_save_discover_msg' => \&meth_ca_save_discover_msg,
        'cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg' => \&meth_ca_add_saved_msg,
        'cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg' => \&meth_ca_save_stack_tree_msg,
        'cellagent.rs$$deploy$$Debug$$ca_deploy' => \&meth_ca_deploy,
        'cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg' => \&meth_ca_forward_saved_msg,
        'cellagent.rs$$forward_saved_application$$Debug$$ca_forward_saved_msg' => \&meth_ca_forward_saved_msg_application,
        'cellagent.rs$$forward_saved_manifest$$Debug$$ca_forward_saved_msg' => \&meth_ca_forward_saved_msg_manifest,
        'cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg' => \&meth_ca_forward_stack_tree_msg,
        'cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id' => \&meth_ca_get_base_tree_id,
        'cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs' => \&meth_ca_get_saved_msgs,
        'cellagent.rs$$listen_cm$$Debug$$ca_listen_cm' => \&meth_ca_listen_cm,
        'cellagent.rs$$listen_cm$$Debug$$ca_listen_pe' => \&meth_ca_listen_pe_cmodel,
        'cellagent.rs$$listen_cm_loop$$Debug$$ca_got_msg' => \&meth_ca_got_msg_cmodel,
        'cellagent.rs$$listen_pe$$Debug$$ca_listen_pe' => \&meth_ca_listen_pe,
        'cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg' => \&meth_ca_got_msg,
        'cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm' => \&meth_ca_listen_vm,
        'cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree' => \&meth_ca_got_from_uptree,
        'cellagent.rs$$port_connected$$Trace$$ca_send_msg' => \&meth_ca_send_msg_port_connected,
        'cellagent.rs$$process_application_msg$$Debug$$ca_process_application_msg' => \&meth_ca_process_stack_tree_d_msg,
        'cellagent.rs$$process_discover_msg$$Debug$$ca_process_discover_msg' => \&meth_ca_process_discover_msg,
        'cellagent.rs$$process_discoverd_msg$$Debug$$ca_process_discover_d_msg' => \&meth_ca_process_discover_d_msg,
        'cellagent.rs$$process_hello_msg$$Debug$$ca_process_hello_msg' => \&meth_hello,
        'cellagent.rs$$process_manifest_msg$$Debug$$ca_process_manifest_msg' => \&meth_ca_process_manifest_msg,
        'cellagent.rs$$process_stack_tree_msg$$Debug$$ca_process_stack_tree_msg' => \&meth_ca_process_stack_tree_msg,
        'cellagent.rs$$process_stack_treed_msg$$Debug$$ca_process_stack_tree_d_msg' => \&meth_ca_process_stack_tree_d_msg,
        'cellagent.rs$$send_msg$$Debug$$ca_send_msg' => \&meth_ca_send_msg_generic,
        'cellagent.rs$$stack_tree$$Debug$$ca_stack_tree' => \&meth_ca_stack_tree,
        'cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg' => \&meth_ca_got_tcp_application_msg,
        'cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg' => \&meth_ca_got_manifest_tcp_msg,
        'cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg' => \&meth_ca_got_stack_tree_tcp_msg,
        'cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map' => \&meth_ca_update_base_tree_map,
        'cellagent.rs$$update_traph$$Debug$$ca_update_traph' => \&meth_ca_update_traph,
        'cellagent.rs$$update_traph$$Debug$$ca_updated_traph_entry' => \&meth_ca_updated_traph_entry,
        'cmodel.rs$$listen_ca_loop$$Debug$$cm_bytes_from_ca' => \&meth_cm_bytes_from_ca,
        'cmodel.rs$$process_packet$$Debug$$cm_bytes_to_ca' => \&meth_cm_bytes_to_ca,
        'datacenter.rs$$initialize$$Trace$$border_cell_start' => \&meth_border_cell_start,
        'datacenter.rs$$initialize$$Trace$$connect_link' => \&meth_connect_link,
        'datacenter.rs$$initialize$$Trace$$interior_cell_start' => \&meth_interior_cell_start,
        'main.rs$$MAIN$$Trace$$trace_schema' => \&meth_START,
        'main.rs$$listen_port_loop$$Trace$$noc_from_ca' => \&meth_noc_from_ca,
        'main.rs$$main$$Trace$$trace_schema' => \&meth_START,
        'nalcell.rs$$new$$Trace$$nalcell_port_setup' => \&meth_nalcell_port_setup,
        'nalcell.rs$$start_cell$$Trace$$nalcell_start_ca' => \&meth_nalcell_start_ca,
        'nalcell.rs$$start_packet_engine$$Trace$$nalcell_start_pe' => \&meth_nalcell_start_pe,
        'noc.rs$$initialize$$Trace$$edge_list' => \&meth_edge_list,
        'packet_engine.rs$$forward$$Debug$$pe_forward_leafward' => \&meth_pe_forward_leafward,
        'packet_engine.rs$$forward$$Debug$$pe_forward_rootward' => \&meth_pe_forward_rootward,
        'packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca' => \&meth_pe_listen_ca,
        'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca' => \&meth_pe_packet_from_ca,
        'packet_engine.rs$$listen_cm_loop$$Debug$$pe_forward_leafward' => \&meth_yyy,
        'packet_engine.rs$$listen_cm_loop$$Debug$$pe_packet_from_cm' => \&meth_pe_packet_from_cm,
        'packet_engine.rs$$listen_cm_loop$$Trace$$recv' => \&meth_recv,
        'packet_engine.rs$$listen_port$$Debug$$pe_listen_ports' => \&meth_pe_listen_ports,
        'packet_engine.rs$$listen_port_loop$$Trace$$pl_recv' => \&meth_pl_recv,
        'packet_engine.rs$$process_packet$$Debug$$pe_process_packet' => \&meth_pe_process_packet,
    };

    extend_table($updates);
}

# /body : OBJECT { schema_version [ncells] }
sub meth_START {
    my ($body, $key, $header) = @_;
    my $repo = $header->{'repo'};
    my $epoch = $header->{'epoch'};
    my $schema_version = $body->{'schema_version'};
    my $ncells = $body->{'ncells'}; # new
    print(join(' ', $repo, 'schema_version='.$schema_version, $epoch, ';'));
}

# /body : OBJECT { cell_number }
sub meth_border_cell_start {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { cell_number }
sub meth_interior_cell_start {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { edge_list }
# 'edge_list' => [ [ 0, 1 ], [ 1, 2 ], [ 1, 6 ], [ 3, 4 ], [ 5, 6 ], [ 6, 7 ], [ 7, 8 ], [ 8, 9 ], [ 0, 5 ], [ 2, 3 ], [ 2, 7 ], [ 3, 8 ], [ 4, 9 ] ]
sub meth_edge_list {
    my ($body) = @_;
    my $edge_list = $body->{'edge_list'};
    my @wires = wirelist($edge_list);
    my $nedge = @wires;
    print(join(' ', 'nedge='.$nedge, ';'));
}

## IMPORTANT : link activation
# /body : OBJECT { link_id left_cell left_port rite_cell rite_port }
sub meth_connect_link {
    my ($body) = @_;
    my $link_id = $body->{'link_id'}{'name'};
    my $left_cell = nametype($body->{'left_cell'});
    my $left_port = portdesc($body->{'left_port'});
    my $rite_cell = nametype($body->{'rite_cell'});
    my $rite_port = portdesc($body->{'rite_port'});

    ## FIXME : GOV magic, should happen thru Discovery!
    ## Complex Entry:
    if (defined $link_id) {
        my ($c1, $lc, $p1, $lp, $c2, $rc, $p2, $rp) = split(/:|\+/, $link_id); # C:0+P:1+C:1+P:1
epoch_marker();
        activate_edge($lc, $lp, $rc, $rp);
    }
    print(join(' ', $link_id, ';'));
}

# /body : OBJECT { cell_number }
sub meth_nalcell_port_setup {
    my ($body) = @_;
    my $cell_number = $body->{'cell_number'};
    print(join(' ', 'cell='.$cell_number, ';'));
}

# /body : OBJECT { cell_id }
sub meth_nalcell_start_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
sub meth_nalcell_start_pe {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
sub meth_pe_listen_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
sub meth_pe_listen_ports {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id }
sub meth_ca_listen_pe {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# single-ended port (link LOV) activation:

## IMPORTANT : Complex Entry
# /body : OBJECT { cell_id port_no is_border }
sub meth_ca_send_msg_port_connected {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $is_border = $body->{'is_border'}; # cell port=of-entry

    ## Complex Entry:
    my $port_id = '';
    if (defined $port_no) {
        $port_id = (($is_border) ? 'FX:' : '').$port_no;
epoch_marker();
        border_port($cell_id, $port_no) if $is_border;
    }
    print(join(' ', $cell_id, $port_id, ';'));
}

# point of origin for all messages!

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg port_nos tree_id }
# /body/msg : OBJECT { header payload }
# /.../payload : OBJECT { tree_id body }
sub meth_ca_send_msg_generic {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_nos = $body->{'port_nos'};
    my $port_list = build_port_list($port_nos);
    my $summary = summarize_msg($body->{'msg'});

    print(join(' ', $cell_id, $tree_id, $port_list, $summary, ';'));

    # my $msg_hdr = $body->{'msg'}{'header'};
    # my $msg_type = $msg_hdr->{'msg_type'};
    # my $direction = $msg_hdr->{'direction'};
    # my $msg_count = $msg_hdr->{'msg_count'};
    # my $sender_id = nametype($msg_hdr->{'sender_id'});
    # my $tree_map = $msg_hdr->{'tree_map'};

    my $msg_payload = $body->{'msg'}{'payload'};
    my $pay_tree_id = nametype($msg_payload->{'tree_id'}); # "C:2+NocAgentMaster"

    #FIXME -bj
    # confirm that a later record captures forwarding,
    # then switch this to indicate port #0
    # this really just adds a msg to the CA=>PE queue
    my $tag = 'cell-snd';
    foreach my $item (@{$port_nos}) {
        my $p = port_index($item);
        add_msgcode2($tag, $tree_id, $p, $body, $key);
    }
}

# virtual recieve from Cell Agent
# eventually this will be CA => C-Model => PE

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type tree_id }
sub meth_pe_packet_from_ca {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $tree_id, ';'));

    # Discover - "C:0"
    # DiscoverD - "C:0"
    # StackTree - "C:2+NocAgentDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    # StackTreeD - "C:2+NocAgentDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    # Manifest - "C:2+NocMasterDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = 0;
    ## add_msgcode2($tag, $tree_id, $p, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# /body : OBJECT { cell_id msg_type port_nos tree_id - ait_state }
# ait_state : SCALAR ;;
sub meth_yyy {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_list = build_port_list($body->{'port_nos'});
    my $msg_type = $body->{'msg_type'};
    my $ait_state = $body->{'ait_state'};
    print(join(' ', $cell_id, $msg_type, $port_list, 'tree='.$tree_id, $ait_state, ';'));
}

# guts of the Packet Engine (forwarding)

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type port_nos tree_id }
sub meth_pe_forward_leafward {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_list = build_port_list($body->{'port_nos'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $port_list, 'tree='.$tree_id, ';'));

    ## Spreadsheet Coding:
    my $port_nos = $body->{'port_nos'};
    my $c = $cell_id; $c =~ s/C://;
    my $event_code = ec_fromkey($key);
    foreach my $item (@{$port_nos}) {
        my $p = port_index($item);
        # add_msgcode2($tag, $tree_id, $port, $body, $key);
        add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
    }
}

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg_type parent_port tree_id }
sub meth_pe_forward_rootward {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'parent_port'});
    my $msg_type = $body->{'msg_type'};
    print(join(' ', $cell_id, $msg_type, $port_no, 'tree='.$tree_id, ';'));

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = port_index($body->{'parent_port'});
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
}

# Packet Engine Control Plane - msg processing (ie. worker)

## IMPORTANT : Routing, Spreadsheet
# /body : OBJECT { cell_id entry msg_type port_no tree_id }
sub meth_pe_process_packet {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});

    # why is this "meta data" ?
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};

    my $entry = $body->{'entry'};
    # my $index = $entry->{'index'};
    my $parent = portdesc($entry->{'parent'});
    print(join(' ', $cell_id, $port_no, $tree_id, $msg_type, 'parent='.$parent, ';')); # 'index='.$index

    ## Routing Table:
    update_routing_table($cell_id, $entry);

    # FIXME - maybe this isn't a msgcode per-se (redundant/excess) ??
    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $c = $cell_id; $c =~ s/C://;
    my $p = port_index($body->{'port_no'});
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# --
# traph ops:

# /body : OBJECT { cell_id base_tree_id children gvm hops other_index port_number port_status }
sub meth_ca_update_traph {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'}); # "C:2"
    my $port_no = portdesc($body->{'port_number'}{'port_no'});
    my $port_status = $body->{'port_status'}; # STRING # Parent, Child, Pruned
    my $base_tree_id = nametype($body->{'base_tree_id'}); # "C:2", "C:2+Control", "C:2+Connected", "C:2+Noc"
    my $hops = $body->{'hops'}; # NUMBER
    # my $other_index = $body->{'other_index'}; # NUMBER
    # 'children' => [],
    # "gvm": { "recv_eqn": "true", "save_eqn": "false", "send_eqn": "true", "variables": [], "xtnd_eqn": "true" },
    my $gvm = $body->{'gvm'};
    my $gvm_hash = note_value(\%gvm_table, $gvm);
    print(join(' ', $cell_id, $port_no, 'status='.$port_status, 'base='.$base_tree_id, 'hops='.$hops, 'gvm='.substr($gvm_hash, -5), ';')); # $other_index
}

## IMPORTANT : Routing
# /body : OBJECT { cell_id base_tree_id entry }
sub meth_ca_updated_traph_entry {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'}); # "C:2"
    my $base_tree_id = nametype($body->{'base_tree_id'}); # "C:2", "C:2+Control", "C:2+Connected", "C:2+Noc"
    my $entry = $body->{'entry'};

    ## Routing Table:
    update_routing_table($cell_id, $entry);

    # FIXME
    my $parent = portdesc($entry->{'parent'});
    print(join(' ', $cell_id, 'base='.$base_tree_id, 'entry.parent='.$parent, ';'));
}

# --
## ca_process_*

sub meth_ca_process_discover_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $new_tree_id, $port_no, $summary, ';'));
}

sub meth_ca_process_discover_d_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $summary, ';'));
}

sub meth_ca_process_stack_tree_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $new_tree_id, $port_no, $summary, ';'));
}

sub meth_ca_process_stack_tree_d_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

sub meth_ca_process_manifest_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $summary, ';'));

    my $msg = $body->{'msg'};
    my $payload = $msg->{'payload'};
    my $manifest = $payload->{'manifest'};
    my $app_name = $manifest->{'id'};
    my $man_hash = note_value(\%manifest_table, $manifest);
    my $opt_manifest = defined($man_hash) ? substr($man_hash, -5) : '';
epoch_marker();
    print main::DBGOUT (join(' ', 'Launch Application:', $tree_id, $cell_id, $app_name, 'manifest='.$opt_manifest), $endl);
}

sub meth_ca_process_application_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $save = $body->{'save'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $port_no, $save, $summary, ';'));
}

# --
# general info:

# /body : OBJECT { cell_id tree_id }
sub meth_ca_get_base_tree_id {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'}); # "C:0+Connected", "C:1", "C:2+NocMasterDeploy", "C:2+NocAgentDeploy", "C:2+NocMasterAgent", "C:2+NocAgentMaster"
    print(join(' ', $cell_id, $tree_id, ';'));
}

# /body : OBJECT { cell_id msg tree_id }
sub meth_ca_save_discover_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $summary, ';'));
}

# --

## IMPORTANT : Stacking (base_tree_map) ??
# /body : OBJECT { cell_id base_tree_id stacked_tree_id }
sub meth_ca_update_base_tree_map {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $base_tree_id = nametype($body->{'base_tree_id'});
    my $stacked_tree_id = nametype($body->{'stacked_tree_id'});
    print(join(' ', $cell_id, $base_tree_id, $stacked_tree_id, ';'));

epoch_marker();
    print main::DBGOUT (join(' ', 'Layer Tree:', $base_tree_id, $stacked_tree_id), $endl);
}

## IMPORTANT : Stacking
# /body : OBJECT { cell_id base_tree_id base_tree_map_keys base_tree_map_values new_tree_id }
sub meth_ca_stack_tree {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $base_tree_id = nametype($body->{'base_tree_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    # base_tree_map_keys
    # base_tree_map_values
    # FIXME
    print(join(' ', $cell_id, $base_tree_id, $new_tree_id, ';'));
}

# IMPORTANT : Stacking, Routing
# /body : OBJECT { cell_id msg entry new_tree_id }
sub meth_ca_got_stack_tree_tcp_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $new_tree_id = nametype($body->{'new_tree_id'});
    my $summary = summarize_msg($body->{'msg'});

    my $entry = $body->{'entry'};

    ## Routing Table:
    # update_routing_table($cell_id, $entry);

    # FIXME
    print(join(' ', $cell_id, $new_tree_id, $summary, ';'));

    my $msg = $body->{'msg'};
    my $payload = $msg->{'payload'};
    my $gvm_eqn = $payload->{'gvm_eqn'};
    my $gvm_hash = note_value(\%gvm_table, $gvm_eqn);
    my $opt_gvm = defined($gvm_hash) ? substr($gvm_hash, -5) : '';
epoch_marker();
    print main::DBGOUT (join(' ', 'Application Tree:', $new_tree_id, 'gvm='.$opt_gvm), $endl);

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $new_tree_id, $virt_p, $body, $key);
}

# IMPORTANT : Stacking
# /body : OBJECT { cell_id msg no_saved tree_id }
sub meth_ca_save_stack_tree_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg no_saved tree_id }
sub meth_ca_add_saved_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved = $body->{'no_saved'};
    my $summary = 'BUG'; # summarize_msg($body->{'msg'}); ## msg became an array, with [0] = null ??
    print(join(' ', $cell_id, $tree_id, $no_saved, $summary, ';'));
}
# bj

# best guess - launch of VM (Cell Agent Control Plane work action)

# IMPORTANT : up_tree
# /body : OBJECT { cell_id deployment_tree_id tree_vm_map_keys up_tree_name }
sub meth_ca_deploy {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deployment_tree_id = nametype($body->{'deployment_tree_id'});
    my $up_tree_name = $body->{'up_tree_name'}; # STRING # "vm1"
    # my $tree_vm_map_keys = $body->{'tree_vm_map_keys'};
    print(join(' ', $cell_id, $deployment_tree_id, $up_tree_name, ';'));

epoch_marker();
    print main::DBGOUT (join(' ', 'Deploy:', $cell_id, $up_tree_name, $deployment_tree_id), $endl);
}

# /body : OBJECT { cell_id sender_id vm_id }
sub meth_ca_listen_vm {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $sender_id = nametype($body->{'sender_id'});
    my $vm_id = nametype($body->{'vm_id'});
    print(join(' ', $cell_id, $sender_id, $vm_id, ';'));
}

#  listen_uptree_loop C:0 Rootward Application Reply from Container:VM:C:0+vm1+2 NocAgentMaster ;

# /body : OBJECT { cell_id msg_type allowed_tree direction tcp_msg }
sub meth_ca_got_from_uptree {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $direction = $body->{'direction'};
    my $tcp_msg = $body->{'tcp_msg'};
    my $allowed_tree = nametype($body->{'allowed_tree'});
    print(join(' ', $cell_id, $msg_type, $direction, $tcp_msg, $allowed_tree, ';'));
}

# /body : OBJECT { cell_id msg deploy_tree_id }
sub meth_ca_got_manifest_tcp_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $deploy_tree_id = nametype($body->{'deploy_tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $deploy_tree_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $deploy_tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg tree_id }
sub meth_ca_got_tcp_application_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $tree_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);

    my $str = decode_octets($body->{'msg'});
epoch_marker();
    print main::DBGOUT (join(' ', 'TCP_APP:', $cell_id, $dquot.$str.$dquot), $endl);
}

## IMPORTANT : stacking
# /body : OBJECT { cell_id msg_type port_nos tree_id }
sub meth_ca_forward_stack_tree_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $tree_id, $msg_type, $port_list, ';'));
}

# /body : OBJECT { cell_id no_saved_msgs tree_id }
sub meth_ca_get_saved_msgs {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $tree_id = nametype($body->{'tree_id'});
    my $no_saved_msgs = $body->{'no_saved_msgs'};
    print(join(' ', $cell_id, $tree_id, $no_saved_msgs, ';'));
}

# /body : OBJECT { cell_id msg_type port_nos }
sub meth_ca_forward_saved_msg {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'}; # Manifest Application
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# { 'cell_id',  'msg' { 'Status' [ 1, boolean, 'Connected' ] } }
sub meth_pl_recv {
    my ($body) = @_;
}

# { cell_id, recv_port_no, msg { header payload } }
## 'header' { 'sender_id' 'msg_count' 'tree_map' 'direction' 'is_ait' 'msg_type' },
## 'payload'=> { 'cell_id' 'port_no' }
sub meth_hello {
    my ($body) = @_;
}

# /body : OBJECT { cell_id msg }
sub meth_recv {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $rkind = ref($msg);

    # no args
    if ($rkind eq '') {
        my $tag = $msg;
        # print(join(' ', $cell_id, 'raw-api', $tag, ';'));
        pe_api($cell_id, $tag);
        return;
    }

    if ($rkind eq 'HASH') {
        my @kind = keys %{$msg};

        # huh?
        if ($#kind != 0) {
            print(join(' ', $cell_id, 'raw-api obj', 'keyset=', @kind, ';'));
            return;
        }

        my $tag = pop @kind;
        my $args = $msg->{$tag};
        my $akind = ref($args);
        # 1 arg
        if ($akind eq 'HASH') {
            # print(join(' ', $cell_id, 'raw-api', $tag, $args, ';'));
            pe_api($cell_id, $tag, $args);
            return;
        }
        # multi args
        if ($akind eq 'ARRAY') {
            # print(join(' ', $cell_id, 'raw-api', $tag, @{$args}, ';'));
            pe_api($cell_id, $tag, @{$args});
            return;
        }

        # huh?
        print(join(' ', $cell_id, 'raw-api obj', 'akind='.$akind, $msg, ';'));
        return;
    }

    # huh?
    print(join(' ', $cell_id, 'raw-api', 'rkind='.$rkind, $msg, ';'));
}

# /body : OBJECT { msg_type tree_name }
# { 'tree_name' => 'Base', 'msg_type' => 'TreeName' };
sub meth_noc_from_ca {
    my ($body) = @_;
    my $msg_type = $body->{'msg_type'};
    my $tree_name = $body->{'tree_name'};
    print(join(' ', $msg_type, $tree_name, ';'));
}

# --

## IMPORTANT : why ?
# /body : OBJECT { ... }
# ''
sub meth_xx {
    my ($body) = @_;
    my $xx = 0;
    print(join(' ', $xx, ';'));
}

# --
# NEW

# /body : OBJECT { cell_id }
sub meth_ca_listen_cm {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# --

# /body : OBJECT { cell_id }
sub meth_ca_listen_pe_cmodel {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    print(join(' ', $cell_id, ';'));
}

# /body : OBJECT { cell_id msg  }
sub meth_cm_bytes_from_ca {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $summary, ';'));

    # FIXME
    my $tree_id = nametype($body->{'missing'});
    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-snd';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

# /body : OBJECT { cell_id msg  }
sub meth_cm_bytes_to_ca {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $summary = summarize_msg($body->{'msg'});
    print(join(' ', $cell_id, $summary, ';'));
}

# /body : OBJECT { cell_id msg_type tree_id }
sub meth_pe_packet_from_cm {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $tree_id = nametype($body->{'tree_id'});
    print(join(' ', $cell_id, $msg_type, $tree_id, ';'));

    ## Spreadsheet Coding:
    my $event_code = ec_fromkey($key);
    my $msg = $body->{'msg'};
    my $header = $msg->{'header'};
    my $payload = $msg->{'payload'};
    #my $msg_type = $header->{'msg_type'};

    my $c = $cell_id; $c =~ s/C://;
    my $virt_p = 0;
    # add_msgcode2($tag, $tree_id, $port, $body, $key);
    add_msgcode($c, $virt_p, $msg_type, $event_code, 'pe-rcv', $tree_id);
}

# Cell Agent Control Plane - msg processing (ie. worker)
# Leafward => micro service request (set)
# Rootward => response to application/client (singleton)

## IMPORTANT : Spreadsheet
# /body : OBJECT { cell_id msg }
sub meth_ca_got_msg {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg = $body->{'msg'};
    my $summary = summarize_msg($msg);
    print(join(' ', $cell_id, $summary, ';'));

    ## Spreadsheet Coding:
    my $payload = $msg->{'payload'};
    my $tree_id = nametype($payload->{'tree_id'});
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $virt_p, $body, $key);
}

## IMPORTANT : Forest/DiscoverD
# /body : OBJECT { cell_id port_no msg  }
#
# parent :    /body/cell_id: NAME_TYPE                # "C:0"
# link :      /body/port_no : PORT_DESC               # - relative to this node, aka parent
# msg_type :  /body/msg/header/msg_type : String      # "DiscoverD"
# child :     /body/msg/header/sender_id : NAME_TYPE  # "Sender:C:1+CellAgent"
# span-tree : /body/msg/payload/tree_id : NAME_TYPE   # "Tree:C:0"
sub meth_ca_got_msg_cmodel {
    my ($body, $key) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $port_no = portdesc($body->{'port_no'});
    my $msg = $body->{'msg'};
    my $summary = summarize_msg($msg);
    print(join(' ', $cell_id, $port_no, $summary, ';'));

    my $p = port_index($body->{'port_no'});
    my $payload = $msg->{'payload'};
    my $tree_id = nametype($payload->{'tree_id'});

    ## Spreadsheet Coding:
    my $virt_p = 0;
    my $tag = 'cell-rcv';
    add_msgcode2($tag, $tree_id, $p, $body, $key);

    my $c = $cell_id; $c =~ s/C://;
    my $header = $msg->{'header'};
    my $msg_type = $header->{'msg_type'};
    my $sender_id = nametype($header->{'sender_id'});
    do_treelink($c, $p, $tree_id, $sender_id) if $msg_type eq 'DiscoverD';
    do_treelink($c, $p, $tree_id, $sender_id) if $msg_type eq 'StackTreeD';
    do_application($c, $p, $tree_id, $sender_id) if $msg_type eq 'Application';
    do_manifest($c, $p, $tree_id, $sender_id) if $msg_type eq 'Manifest';
}

# /body : OBJECT { cell_id msg_type port_nos }
sub meth_ca_forward_saved_msg_manifest {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# /body : OBJECT { cell_id msg_type port_nos }
sub meth_ca_forward_saved_msg_application {
    my ($body) = @_;
    my $cell_id = nametype($body->{'cell_id'});
    my $msg_type = $body->{'msg_type'};
    my $port_list = build_port_list($body->{'port_nos'});
    print(join(' ', $cell_id, $msg_type, $port_list, ';'));
}

# --

my $notes = << '_eof_';

- refactor add_msgcode2, event_code
sub meth_ca_send_msg_generic
sub meth_pe_packet_from_ca
sub meth_pe_forward_leafward
sub meth_pe_forward_rootward
sub meth_pe_process_packet
sub meth_ca_save_stack_tree_msg
sub meth_ca_got_manifest_tcp_msg
sub meth_ca_got_tcp_application_msg
sub meth_cm_bytes_from_ca
sub meth_pe_packet_from_cm
sub meth_ca_got_msg
sub meth_ca_got_msg_cmodel
sub meth_ca_got_stack_tree_tcp_msg

_eof_

}

# for loading:
1;
