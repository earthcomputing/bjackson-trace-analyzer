#!/usr/bin/perl -w

package Fabric::DispatchTable v2018.10.13 {

use Exporter 'import';
our @EXPORT_OK = qw( meth_lookup extend_table );

sub extend_table {
    my ($table) = @_;
    my $key = 'main.rs$$MAIN$$Trace$$trace_schema';
    @{$dispatch_table}{ keys %{$table} } = values %{$table};
    # foreach my $key (%{$table}) { $dispatch_table->{$key} = $table->{$key}; }
}

sub meth_lookup {
    my ($methkey) = @_;
    return $dispatch_table->{$methkey};
}

my $dispatch_table = {
};

my $all_dispatch_table = {
    'CellAgent$$src/cellagent.rs$$add_saved_discover$$ca_save_discover_msg$$279$$Debug' => \&meth_ca_save_discover_msg_ff6df,
    'CellAgent$$src/cellagent.rs$$add_saved_msg$$ca_add_saved_msg$$248$$Debug' => \&meth_ca_add_saved_msg_8d6a2,
    'CellAgent$$src/cellagent.rs$$add_saved_stack_tree$$ca_save_stack_tree_msg$$268$$Debug' => \&meth_ca_save_stack_tree_msg_295f4,
    'CellAgent$$src/cellagent.rs$$deploy$$ca_deploy$$514$$Debug' => \&meth_ca_deploy_11933,
    'CellAgent$$src/cellagent.rs$$forward_saved_application$$ca_forward_saved_msg$$1347$$Debug' => \&meth_ca_forward_saved_msg_a634b,
    'CellAgent$$src/cellagent.rs$$forward_saved_manifest$$ca_forward_saved_msg$$1362$$Debug' => \&meth_ca_forward_saved_msg_a634b,
    'CellAgent$$src/cellagent.rs$$forward_stack_tree$$ca_forward_stack_tree_msg$$1315$$Debug' => \&meth_ca_forward_stack_tree_msg_6a0ee,
    'CellAgent$$src/cellagent.rs$$get_base_tree_id$$ca_get_base_tree_id$$320$$Debug' => \&meth_ca_get_base_tree_id_4aea5,
    'CellAgent$$src/cellagent.rs$$get_saved_msgs$$ca_get_saved_msgs$$220$$Debug' => \&meth_ca_get_saved_msgs_72ab4,
    'CellAgent$$src/cellagent.rs$$listen_cm$$ca_listen_cm$$665$$Debug' => \&meth_ca_listen_cm_e750c,
    'CellAgent$$src/cellagent.rs$$listen_cm_loop$$ca_got_msg$$699$$Debug' => \&meth_ca_got_msg_5fb6e,
    'CellAgent$$src/cellagent.rs$$listen_uptree$$ca_listen_vm$$548$$Debug' => \&meth_ca_listen_vm_28653,
    'CellAgent$$src/cellagent.rs$$listen_uptree_loop$$ca_got_from_uptree$$572$$Debug' => \&meth_ca_got_from_uptree_6f6c1,
    'CellAgent$$src/cellagent.rs$$port_connected$$ca_send_msg$$1191$$Trace' => \&meth_ca_send_msg_79767,
    'CellAgent$$src/cellagent.rs$$process_application_msg$$ca_process_application_msg$$755$$Debug' => \&meth_ca_process_application_msg_84c94,
    'CellAgent$$src/cellagent.rs$$process_discover_msg$$ca_process_discover_msg$$785$$Debug' => \&meth_ca_process_discover_msg_11ab2,
    'CellAgent$$src/cellagent.rs$$process_discoverd_msg$$ca_process_discover_d_msg$$828$$Debug' => \&meth_ca_process_discover_d_msg_2ca26,
    'CellAgent$$src/cellagent.rs$$process_hello_msg$$ca_process_hello_msg$$921$$Debug' => \&meth_ca_process_hello_msg_2fc97,
    'CellAgent$$src/cellagent.rs$$process_manifest_msg$$ca_process_manifest_msg$$950$$Debug' => \&meth_ca_process_manifest_msg_e0ffb,
    'CellAgent$$src/cellagent.rs$$process_stack_tree_msg$$ca_process_stack_tree_msg$$988$$Debug' => \&meth_ca_process_stack_tree_msg_27e4c,
    'CellAgent$$src/cellagent.rs$$process_stack_treed_msg$$ca_process_stack_tree_d_msg$$1022$$Debug' => \&meth_ca_process_stack_tree_d_msg_e750c,
    'CellAgent$$src/cellagent.rs$$send_msg$$ca_send_msg$$1381$$Debug' => \&meth_ca_send_msg_f900d,
    'CellAgent$$src/cellagent.rs$$stack_tree$$ca_stack_tree$$644$$Debug' => \&meth_ca_stack_tree_95500,
    'CellAgent$$src/cellagent.rs$$tcp_application$$ca_got_tcp_application_msg$$1044$$Debug' => \&meth_ca_got_tcp_application_msg_23fec,
    'CellAgent$$src/cellagent.rs$$tcp_manifest$$ca_got_manifest_tcp_msg$$1081$$Debug' => \&meth_ca_got_manifest_tcp_msg_febf5,
    'CellAgent$$src/cellagent.rs$$tcp_stack_tree$$ca_got_stack_tree_tcp_msg$$1119$$Debug' => \&meth_ca_got_stack_tree_tcp_msg_80b52,
    'CellAgent$$src/cellagent.rs$$update_base_tree_map$$ca_update_base_tree_map$$309$$Debug' => \&meth_ca_update_base_tree_map_d8651,
    'CellAgent$$src/cellagent.rs$$update_traph$$ca_update_traph$$373$$Debug' => \&meth_ca_update_traph_ac047,
    'CellAgent$$src/cellagent.rs$$update_traph$$ca_updated_traph_entry$$414$$Debug' => \&meth_ca_updated_traph_entry_308cb,
    'CellAgent$$src/cmodel.rs$$listen_ca_loop$$cm_bytes_from_ca$$60$$Debug' => \&meth_cm_bytes_from_ca_45ce9,
    'CellAgent$$src/cmodel.rs$$process_packet$$cm_bytes_to_ca$$111$$Debug' => \&meth_cm_bytes_to_ca_45ce9,
    'CellAgent$$src/datacenter.rs$$initialize$$border_cell_start$$35$$Trace' => \&meth_border_cell_start_127ed,
    'CellAgent$$src/datacenter.rs$$initialize$$connect_link$$93$$Trace' => \&meth_connect_link_c34d2,
    'CellAgent$$src/datacenter.rs$$initialize$$interior_cell_start$$50$$Trace' => \&meth_interior_cell_start_127ed,
    'CellAgent$$src/main.rs$$MAIN$$trace_schema$$39$$Trace' => \&meth_trace_schema_6a402,
    'CellAgent$$src/main.rs$$listen_port_loop$$noc_from_ca$$88$$Trace' => \&meth_noc_from_ca_0ad94,
    'CellAgent$$src/nalcell.rs$$new$$nalcell_port_setup$$61$$Trace' => \&meth_nalcell_port_setup_e62bc,
    'CellAgent$$src/nalcell.rs$$start_cell$$nalcell_start_ca$$97$$Trace' => \&meth_nalcell_start_ca_e750c,
    'CellAgent$$src/nalcell.rs$$start_packet_engine$$nalcell_start_pe$$124$$Trace' => \&meth_nalcell_start_pe_e750c,
    'CellAgent$$src/packet_engine.rs$$forward$$pe_forward_leafward$$342$$Debug' => \&meth_pe_forward_leafward_a7b8e,
    'CellAgent$$src/packet_engine.rs$$listen_cm_loop$$pe_forward_leafward$$104$$Debug' => \&meth_pe_forward_leafward_f9d21,
    'CellAgent$$src/packet_engine.rs$$listen_cm_loop$$pe_packet_from_cm$$143$$Debug' => \&meth_pe_packet_from_cm_5cae7,
    'CellAgent$$src/packet_engine.rs$$listen_cm_loop$$recv$$82$$Trace' => \&meth_recv_11937,
    'CellAgent$$src/packet_engine.rs$$listen_port$$pe_listen_ports$$63$$Debug' => \&meth_pe_listen_ports_e750c,
    'CellAgent$$src/packet_engine.rs$$listen_port_loop$$pl_recv$$181$$Trace' => \&meth_pl_recv_768dc,
    'CellAgent$$src/packet_engine.rs$$process_packet$$pe_process_packet$$245$$Debug' => \&meth_pe_process_packet_39d58,
};

# --

sub meth_border_cell_start_127ed { }
sub meth_ca_add_saved_msg_8d6a2 { }
sub meth_ca_deploy_11933 { }
sub meth_ca_forward_saved_msg_a634b { }
sub meth_ca_forward_stack_tree_msg_6a0ee { }
sub meth_ca_get_base_tree_id_4aea5 { }
sub meth_ca_get_saved_msgs_72ab4 { }
sub meth_ca_got_from_uptree_6f6c1 { }
sub meth_ca_got_manifest_tcp_msg_febf5 { }
sub meth_ca_got_msg_5fb6e { }
sub meth_ca_got_stack_tree_tcp_msg_80b52 { }
sub meth_ca_got_tcp_application_msg_23fec { }
sub meth_ca_listen_cm_e750c { }
sub meth_ca_listen_vm_28653 { }
sub meth_ca_process_application_msg_84c94 { }
sub meth_ca_process_discover_d_msg_2ca26 { }
sub meth_ca_process_discover_msg_11ab2 { }
sub meth_ca_process_hello_msg_2fc97 { }
sub meth_ca_process_manifest_msg_e0ffb { }
sub meth_ca_process_stack_tree_d_msg_e750c { }
sub meth_ca_process_stack_tree_msg_27e4c { }
sub meth_ca_save_discover_msg_ff6df { }
sub meth_ca_save_stack_tree_msg_295f4 { }
sub meth_ca_send_msg_79767 { }
sub meth_ca_send_msg_f900d { }
sub meth_ca_stack_tree_95500 { }
sub meth_ca_update_base_tree_map_d8651 { }
sub meth_ca_update_traph_ac047 { }
sub meth_ca_updated_traph_entry_308cb { }
sub meth_cm_bytes_from_ca_45ce9 { }
sub meth_cm_bytes_to_ca_45ce9 { }
sub meth_connect_link_c34d2 { }
sub meth_interior_cell_start_127ed { }
sub meth_nalcell_port_setup_e62bc { }
sub meth_nalcell_start_ca_e750c { }
sub meth_nalcell_start_pe_e750c { }
sub meth_noc_from_ca_0ad94 { }
sub meth_pe_forward_leafward_a7b8e { }
sub meth_pe_forward_leafward_f9d21 { }
sub meth_pe_listen_ports_e750c { }
sub meth_pe_packet_from_cm_5cae7 { }
sub meth_pe_process_packet_39d58 { }
sub meth_pl_recv_768dc { }
sub meth_recv_11937 { }
sub meth_trace_schema_6a402 { }

# --

my $notes = << '_eof_';

_eof_

}

# for loading:
1;
