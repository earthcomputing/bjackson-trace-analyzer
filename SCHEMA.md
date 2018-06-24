
https://github.github.com/gfm/

VERBS: 33
=========

    685	cellagent.rs$get_base_tree_id
    582	cellagent.rs$update_traph
    333	cellagent.rs$listen_pe_loop
    266	cellagent.rs$send_msg
    148	cellagent.rs$update_base_tree_map
    90	cellagent.rs$process_discover_msg
    90	cellagent.rs$add_saved_discover
    31	cellagent.rs$stack_tree
    30	cellagent.rs$add_saved_stack_tree
    27	cellagent.rs$process_stack_tree_msg
    27	cellagent.rs$port_connected
    21	cellagent.rs$add_saved_msg
    18	cellagent.rs$process_stack_treed_msg
    18	cellagent.rs$process_application_msg
    18	cellagent.rs$get_saved_msgs
    10	cellagent.rs$tcp_application
    10	cellagent.rs$process_manifest_msg
    10	cellagent.rs$listen_uptree_loop
    10	cellagent.rs$listen_uptree
    10	cellagent.rs$listen_pe
    10	cellagent.rs$deploy
    9	cellagent.rs$process_discoverd_msg
    6	cellagent.rs$forward_saved
    4	cellagent.rs$tcp_stack_tree
    3	cellagent.rs$forward_stack_tree
    2	cellagent.rs$tcp_manifest
    23	datacenter.rs$initialize
    10	nalcell.rs$new
    10	nalcell.rs$start_cell
    10	nalcell.rs$start_packet_engine
    603	packet_engine.rs$forward
    10	packet_engine.rs$listen_ca
    10	packet_engine.rs$listen_port

NAME_TYPE:
==========

    /.../name : STRING
    /.../uuid/uuid[] : SEQ 2 OF NUMBER

PORT_DESC:
==========

    /.../ : OBJECT { v }
    /.../v : NUMBER

SCHEMA:
=======

    : OBJECT { header body }

TRACE-METADATA:
===============

    /header : OBJECT { repo module function trace_type format - thread_id event_id - epoch }

    /header/repo : STRING
    /header/module : STRING
    /header/function : STRING
    /header/trace_type : STRING # Trace, Debug
    /header/format : STRING
    /header/thread_id : NUMBER
    /header/event_id[] : SEQ OF NUMBER
    /header/epoch : NUMBER

BASE-FORMS:
===========

    685	/body : OBJECT { cell_id tree_id }
    606	/body : OBJECT { cell_id msg_type port_nos tree_id }
    333	/body : OBJECT { cell_id msg }
    291	/body : OBJECT { cell_id base_tree_id entry }
    291	/body : OBJECT { cell_id base_tree_id children gvm hops other_index port_number port_status }
    266	/body : OBJECT { cell_id msg port_nos tree_id }
    148	/body : OBJECT { cell_id base_tree_id stacked_tree_id }
    117	/body : OBJECT { cell_id msg new_tree_id port_no }
    100	/body : OBJECT { cell_id msg tree_id }
    68	/body : OBJECT { cell_id }
    51	/body : OBJECT { cell_id msg no_saved tree_id }
    31	/body : OBJECT { cell_id base_tree_id base_tree_map_keys base_tree_map_values new_tree_id }
    27	/body : OBJECT { cell_id is_border port_no }
    19	/body : OBJECT { cell_id msg port_no tree_id }
    18	/body : OBJECT { cell_id no_saved_msgs tree_id }
    18	/body : OBJECT { cell_id msg port_no save tree_id }
    10	/body : OBJECT { cell_id sender_id vm_id }
    10	/body : OBJECT { cell_id deployment_tree_id tree_vm_map_keys up_tree_name }
    10	/body : OBJECT { cell_id allowed_tree direction msg_type tcp_msg }
    6	/body : OBJECT { cell_id msg_type port_nos }
    4	/body : OBJECT { cell_id entry msg new_tree_id }
    2	/body : OBJECT { cell_id deploy_tree_id msg }
    20	/body : OBJECT { cell_number }
    13	/body : OBJECT { left_cell left_port link_id rite_cell rite_port }

---

    /body/cell_id : NAMETYPE
    /body/base_tree_id : NAMETYPE
    /body/deploy_tree_id : NAMETYPE
    /body/deployment_tree_id : NAMETYPE
    /body/left_cell : NAMETYPE
    /body/link_id : NAMETYPE
    /body/new_tree_id : NAMETYPE
    /body/rite_cell : NAMETYPE
    /body/sender_id : NAMETYPE
    /body/stacked_tree_id : NAMETYPE
    /body/tree_id : NAMETYPE
    /body/vm_id : NAMETYPE

    /body/tree_vm_map_keys[] : SEQ OF NAMETYPE

    /body/direction : STRING # Leafward, Rootward
    /body/msg_type : STRING # Application, DiscoverD, Manifest, StackTree, StackTreeD
    /body/port_status : STRING # Parent, Child, Pruned
    /body/tcp_msg : STRING # "Hello From Master", "Reply from Container:VM:C:0+vm1+2"

    /body/is_border : BOOLEAN
    /body/save : BOOLEAN

    /body/cell_number : NUMBER
    /body/hops : NUMBER
    /body/no_saved : NUMBER
    /body/no_saved_msgs : NUMBER
    /body/other_index : NUMBER

    /body/port_no : PORT_DESC
    /body/left_port : PORT_DESC
    /body/rite_port : PORT_DESC

    /body/port_nos[] : SEQ OF PORT_DESC

    10	/body/up_tree_name

    90	/body/children[] : SEQ OF OBJECT { port_no }
    90	/body/children[]/port_no : PORT_DESC

    291	/body/port_number : OBJECT { port_no }
    291	/body/port_number/port_no : PORT_DESC

    10	/body/allowed_tree : OBJECT { name }
    10	/body/allowed_tree/name

    370	/body/base_tree_map_keys[] : NAMETYPE
    740	/body/base_tree_map_values[]/uuid/uuid[] : SEQ 2 OF NUMBER

---

    /body/entry : OBJECT { index inuse mask may_send other_indices parent tree_uuid }

    /.../entry/index
    /.../entry/inuse : BOOLEAN
    /.../entry/mask : OBJECT { mask }
    /.../entry/mask/mask
    /.../entry/may_send : BOOLEAN
    /.../entry/other_indices : ARRAY len=8
    /.../entry/other_indices[]
    /.../entry/parent : PORT_DESC
    /.../entry/tree_uuid/uuid[] : SEQ 2 OF NUMBER

---

    /body/gvm : OBJECT { recv_eqn save_eqn send_eqn variables xtnd_eqn }

    /.../gvm/recv_eqn
    /.../gvm/save_eqn
    /.../gvm/send_eqn
    /.../gvm/variables : ARRAY len=0
    /.../gvm/xtnd_eqn

---

    /body/msg : OBJECT { header payload }

    /body/msg/header : OBJECT { direction msg_count msg_type sender_id tree_map }

    /.../header/direction
    /.../header/msg_count
    /.../header/msg_type
    /.../header/sender_id : NAMETYPE
    /.../header/tree_map : OBJECT {  }
    /.../header/tree_map : OBJECT { NocAgentMaster NocMasterAgent }
    /.../header/tree_map/NocAgentMaster : NAMETYPE
    /.../header/tree_map/NocMasterAgent : NAMETYPE

PAYLOAD-FORMS:
==============

    /.../payload : OBJECT { body tree_id }
    /.../payload : OBJECT { deploy_tree_id manifest tree_name }
    /.../payload : OBJECT { fwd_index index tree_id }
    /.../payload : OBJECT { gvm_eqn hops index path sending_cell_id tree_id }
    /.../payload : OBJECT { gvm_eqn index new_tree_id parent_tree_id }
    /.../payload : OBJECT { my_index tree_id }

---

    /.../payload/deploy_tree_id : NAMETYPE
    /.../payload/new_tree_id : NAMETYPE
    /.../payload/parent_tree_id : NAMETYPE
    /.../payload/sending_cell_id : NAMETYPE
    /.../payload/tree_id : NAMETYPE
    /.../payload/tree_name : OBJECT { name }
    /.../payload/tree_name/name

    /.../payload/body
    /.../payload/fwd_index
    /.../payload/hops
    /.../payload/index
    /.../payload/my_index

    /.../payload/path : OBJECT { port_number }
    /.../payload/path/port_number : OBJECT { port_no }
    /.../payload/path/port_number/port_no : PORT_DESC

---

    /.../payload/gvm_eqn : OBJECT { recv_eqn save_eqn send_eqn variables xtnd_eqn }

    /.../gvm_eqn/recv_eqn
    /.../gvm_eqn/save_eqn
    /.../gvm_eqn/send_eqn
    /.../gvm_eqn/variables[] : SEQ OF OBJECT { value var_name var_type }
    /.../gvm_eqn/variables[]/value
    /.../gvm_eqn/variables[]/var_name
    /.../gvm_eqn/variables[]/var_type
    /.../gvm_eqn/xtnd_eqn

---

    /payload/manifest : OBJECT { allowed_trees cell_config deployment_tree id trees vms }

    /.../manifest/allowed_trees[] : SEQ OF OBJECT { name }
    /.../manifest/allowed_trees[]/name
    /.../manifest/cell_config
    /.../manifest/deployment_tree : OBJECT { name }
    /.../manifest/deployment_tree/name
    /.../manifest/id
    /.../manifest/trees[] : SEQ OF OBJECT { id parent_list }
    /.../manifest/trees[]/id
    /.../manifest/trees[]/parent_list : ARRAY len=1
    /.../manifest/trees[]/parent_list[]
    /.../manifest/vms[] : SEQ OF OBJECT { allowed_trees containers id image required_config trees }
    /.../manifest/vms[]/allowed_trees[] : SEQ OF OBJECT { name }
    /.../manifest/vms[]/allowed_trees[]/name
    /.../manifest/vms[]/containers[] : SEQ OF OBJECT { allowed_trees id image params }
    /.../manifest/vms[]/containers[]/allowed_trees[] : SEQ OF OBJECT { name }
    /.../manifest/vms[]/containers[]/allowed_trees[]/name
    /.../manifest/vms[]/containers[]/id
    /.../manifest/vms[]/containers[]/image
    /.../manifest/vms[]/containers[]/params : ARRAY len=0
    /.../manifest/vms[]/id
    /.../manifest/vms[]/image
    /.../manifest/vms[]/required_config
    /.../manifest/vms[]/trees[] : SEQ OF OBJECT { id parent_list }
    /.../manifest/vms[]/trees[]/id
    /.../manifest/vms[]/trees[]/parent_list : ARRAY len=1
    /.../manifest/vms[]/trees[]/parent_list[]

KEYSET:
=======

    18775	uuid
    9530	name
    4054	header
    4039	v
    3210	body
    3144	module
    3144	trace_type
    3144	thread_id
    3144	format
    3144	event_id
    3144	function
    3111	cell_id
    2520	tree_id
    1532	msg_type
    1028	port_no
    920	direction
    920	sender_id
    915	index
    910	tree_map
    910	payload
    910	msg_count
    910	msg
    878	port_nos
    875	xtnd_eqn
    875	send_eqn
    875	recv_eqn
    875	variables
    875	save_eqn
    761	base_tree_id
    757	hops
    757	port_number
    590	mask
    584	gvm_eqn
    466	path
    466	sending_cell_id
    295	inuse
    295	entry
    295	may_send
    295	tree_uuid
    295	parent
    295	other_indices
    291	other_index
    291	port_status
    291	gvm
    291	children
    270	new_tree_id
    189	my_index
    175	id
    148	stacked_tree_id
    118	var_name
    118	var_type
    118	value
    118	parent_tree_id
    105	allowed_trees
    70	image
    70	parent_list
    70	trees
    51	no_saved
    37	deploy_tree_id
    36	fwd_index
    35	NocAgentMaster
    35	cell_config
    35	deployment_tree
    35	NocMasterAgent
    35	containers
    35	required_config
    35	tree_name
    35	manifest
    35	params
    35	vms
    31	base_tree_map_keys
    31	base_tree_map_values
    27	is_border
    20	cell_number
    18	save
    18	no_saved_msgs
    13	rite_cell
    13	link_id
    13	rite_port
    13	left_cell
    13	left_port
    10	deployment_tree_id
    10	allowed_tree
    10	vm_id
    10	tree_vm_map_keys
    10	tcp_msg
    10	up_tree_name

Datacenter 'Complex' wiring diagram:
====================================

    # 'datacenter.rs$$initialize$$Trace$$connect_link'
    sub meth_connect_link {

    # 'cellagent.rs$$port_connected$$Trace$$ca_send_msg'
    sub meth_ca_send_msg {

            border_port($cell_id, $port_no) if $is_border;

    Spreadsheet Coding:
    ===================

    For each sent message:
        show which link it goes out on as an entry in the sending cell's column, e.g., DiscoverD>link1.
    For each received message:
        show as an entry in the receiving cell's the link it came in on, e.g., link1<DiscoverD.

    Distinguish between packet engine (->) and cell agent (>)

    ensure a receive appears at least one row below the corresponding send.

---

        send_msg C:0 C:0+Connected [v0,v1,v2,v3,v4,v5,v6,v7] Discover%%Sender:C:0+CellAgent%%Leafward%%gvm%% ;

    Discover>link#0       # table(C0:p1)
    Discover>link#8       # table(C0:p2)
    Discover>       # table(C0:p0)
    Discover>       # table(C0:p3)
    Discover>       # table(C0:p4)
    Discover>       # table(C0:p5)
    Discover>       # table(C0:p6)
    Discover>       # table(C0:p7)

     forward C:2 Discover [v1] tree=C:2 ;
     forward C:2 DiscoverD [v1] tree=C:1 ;
     forward C:2 Discover [] tree=C:1 ;
     forward C:2 DiscoverD [v1] tree=C:0 ;
     forward C:2 Discover [] tree=C:0 ;
     forward C:2 DiscoverD [v1] tree=C:6 ;

    C:2 Discover<-link#1    # table(C2:p1)
    C:2 DiscoverD<-link#1   # table(C2:p1)
    C:2 DiscoverD<-link#1   # table(C2:p1)
    C:2 DiscoverD<-link#1   # table(C2:p1)


LINK-TABLE:
===========

    C0:p1 -> C1:p1 [label="p1:p1, link#0"]
    C1:p2 -> C2:p1 [label="p2:p1, link#1"]
    C1:p3 -> C6:p1 [label="p3:p1, link#2"]
    C3:p1 -> C4:p1 [label="p1:p1, link#3"]
    C5:p1 -> C6:p2 [label="p1:p2, link#4"]
    C6:p3 -> C7:p1 [label="p3:p1, link#5"]
    C7:p3 -> C8:p1 [label="p3:p1, link#6"]
    C8:p2 -> C9:p1 [label="p2:p1, link#7"]
    C0:p2 -> C5:p2 [label="p2:p2, link#8"]
    C2:p3 -> C3:p2 [label="p3:p2, link#9"]
    C2:p4 -> C7:p4 [label="p4:p4, link#10"]
    C3:p3 -> C8:p3 [label="p3:p3, link#11"]
    C4:p2 -> C9:p2 [label="p2:p2, link#12"]
    Internet -> C2:p2 [label="p2, link#13"]

---

    Change to header format :

    https://github.com/earthcomputing/${repo}.git
    1529618416 (20180621-150016 PDT)

    "body": {
        "schema_version": "0.1",
        "build_info": "...."
    }
