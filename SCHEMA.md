
# Log Messaging Substrate (LMS) - JSON Schema and Notes for Trace Records

    aka Stream Processing System
    Kafka Model (highly scalable)

hint: https://github.github.com/gfm/

## NAME_TYPE:

    /.../name : STRING
    /.../uuid/uuid[] : SEQ 2 OF NUMBER

## PORT_DESC:

    /.../ : OBJECT { v }
    /.../v : NUMBER

## SCHEMA:

    : OBJECT { header body }

## TRACE-METADATA:

    /header : OBJECT { repo module function trace_type format - thread_id event_id - epoch }

    /header/repo : STRING
    /header/module : STRING
    /header/function : STRING
    /header/trace_type : STRING # Trace, Debug
    /header/format : STRING
    /header/thread_id : NUMBER
    /header/event_id[] : SEQ OF NUMBER
    /header/epoch : NUMBER

For now, trace record parsing is done on a per unique "emitter" basis :

    my $methkey = join('$$', $module, $function, $kind, $format);
    SHOULD also include $repo

Each trace record SHOULD have a unique "key".  In order to be defensive against bugs, adding a stream sequence number disambiguates things.  The notion here is that a number of independent emitters may be publishing trace records thru the same channel HOWEVER sequential in the channel DOES NOT imply causal ordering.  Ordering by key is a causal guarantee (from the actual emitter).

    my $key = join('::', $thread_id, $event_id, $lineno);

## MAIN:

    https://github.com/earthcomputing/${repo}.git
    1529618416 (20180621-150016 PDT)

    "body": {
        "schema_version": "0.1",
        "build_info": "...."
    }

## BASE-FORMS:

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

## PAYLOAD-FORMS:

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


## Datacenter 'Complex' wiring diagram:

    # 'datacenter.rs$$initialize$$Trace$$connect_link'
    sub meth_connect_link {

    # 'cellagent.rs$$port_connected$$Trace$$ca_send_msg'
    sub meth_ca_send_msg {

            border_port($cell_id, $port_no) if $is_border;

## Spreadsheet Coding:

    For each sent message:
        show which link it goes out on as an entry in the sending cell's column, e.g., DiscoverD>link1.
    For each received message:
        show as an entry in the receiving cell's the link it came in on, e.g., link1<DiscoverD.

    Distinguish between packet engine (->) and cell agent (>)

    ensure a receive appears at least one row below the corresponding send.

    BONUS points : invent letter names for links and show highly compact/cryptic output (e.g. DD>a)

    Add : cell contest SHOULD include destination tree-id

    BONUS points : allow filtering to simply things, such as focus on C:2

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

Alan:
Aah.  I do see a difference. Discover, DiscoverD, and StackTree list the Connected tree.
It would be better to show the tree they are for, e.g., C:2 instead of C:2+Connected.
For stack tree it should show both the parent and new tree.
I didn’t show that in my spreadsheet because I knew I was only stacking on C:2.

Bill:
ok, that doesn’t have meaning for me “tree they are for” - there’s only 1 tree-id available in the trace data (I think).
As for parent/new - I could do that, however I’d like to now what tree we’re sending to (i.e. parent, right?) and I think perhaps ‘new’ really should be recorded in some other way.
Like perhaps message details (per message type) should be in another report ??

then we had a phone conversation

Result:
A generic tool should show all the message flow which would imply including the forwarding table index that's in the message meta-data (header).  Deep Packet Inspection (DPI) can pull out the "interesting tree" for display - perhaps among other things.

In general, it would be useful to provide a "message hash" in the per-trace info, and also dump out the complete message details in a separate table (report).

## Routing Table

     Index Tree UUID  In Use Send? Parent Mask             Indices
         0 "358d69e1"  Yes    Yes       0 0000000000000001 [0, 0, 0, 0, 0, 0, 0, 0]
         1 "b90ffb35"  Yes    Yes       0 0000000000000110 [0, 0, 0, 0, 0, 0, 0, 0]
         2 "5e3fd12d"  Yes    Yes       0 0000000000000111 [0, 4, 4, 0, 0, 0, 0, 0]
         3 "f42baa5c"  Yes    Yes       1 0000000000000101 [0, 2, 5, 0, 0, 0, 0, 0]
         4 "f9a0aead"  Yes    Yes       1 0000000000000101 [0, 3, 6, 0, 0, 0, 0, 0]
         5 "259238f9"  Yes    Yes       2 0000000000000001 [0, 7, 2, 0, 0, 0, 0, 0]
         6 "3cb12888"  Yes    Yes       2 0000000000000001 [0, 6, 3, 0, 0, 0, 0, 0]
         7 "3f93439f"  Yes    Yes       1 0000000000000101 [0, 5, 7, 0, 0, 0, 0, 0]
         8 "767f7086"  Yes    Yes       1 0000000000000101 [0, 8, 10, 0, 0, 0, 0, 0]
         9 "b1dc43ed"  Yes    Yes       2 0000000000000001 [0, 10, 8, 0, 0, 0, 0, 0]
        10 "5ecec45f"  Yes    Yes       1 0000000000000001 [0, 9, 9, 0, 0, 0, 0, 0]
        11 "7c5d07a6"  Yes    Yes       2 0000000000000001 [0, 11, 11, 0, 0, 0, 0, 0]
        12 "2c8b871d"  Yes    Yes       2 0000000000000001 [0, 0, 12, 0, 0, 0, 0, 0]
        13 "2c8b871d"  Yes    Yes       2 0000000000000100 [0, 0, 12, 0, 0, 0, 0, 0]
        14 "e9ef7cb9"  Yes    No        2 0000000000000001 [0, 0, 14, 0, 0, 0, 0, 0]
        15 "e9ef7cb9"  Yes    No        2 0000000000000100 [0, 0, 14, 0, 0, 0, 0, 0]
        16 "d548c82a"  Yes    Yes       2 0000000000000000 [0, 0, 16, 0, 0, 0, 0, 0]

## LINK-TABLE:

    C0 [label="p0, link#13"]
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

## VERBS:

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

## FIELDS:

    18775	uuid : OBJECT, ARRAY
    9530	name : XXX
    4054	header : OBJECT
    4039	v : NUMBER
    3210	body : OBJECT
    3144	module : STRING # source file name, e.g. "foo.fs"
    3144	trace_type : STRING # Trace, Debug
    3144	thread_id : NUMBER
    3144	format : STRING # random tag value
    3144	event_id : ARRAY
    3144	function : STRING # source code method name
    3111	cell_id : NAMETYPE
    2520	tree_id : NAMETYPE
    1532	msg_type : STRING # Application, Discover, DiscoverD, Manifest, StackTree, StackTreeD
    1028	port_no : PORT_DESC
    920	direction : STRING # Leafward, Rootward
    920	sender_id : NAMETYPE
    915	index : XXX
    910	tree_map : OBJECT
    910	payload : OBJECT
    910	msg_count : NUMBER
    910	msg : OBJECT
    878	port_nos : ARRAY
    875	xtnd_eqn : XXX
    875	send_eqn : XXX
    875	recv_eqn : XXX
    875	variables : ARRAY
    875	save_eqn : XXX
    761	base_tree_id : NAMETYPE
    757	hops : NUMBER
    757	port_number : OBJECT
    590	mask : OBJECT
    584	gvm_eqn : OBJECT
    466	path : OBJECT
    466	sending_cell_id : XXX
    295	inuse : BOOLEAN
    295	entry : OBJECT
    295	may_send : BOOLEAN
    295	tree_uuid : XXX
    295	parent : XXX
    295	other_indices : ARRAY
    291	other_index : NUMBER
    291	port_status : STRING # Parent, Child, Pruned
    291	gvm : OBJECT
    291	children : ARRAY
    270	new_tree_id : NAMETYPE
    189	my_index : XXX
    175	id : XXX
    148	stacked_tree_id : NAMETYPE
    118	var_name : XXX
    118	var_type : XXX
    118	value : XXX
    118	parent_tree_id : XXX
    105	allowed_trees : ARRAY
    70	image : XXX
    70	parent_list : ARRAY
    70	trees : ARRAY
    51	no_saved : NUMBER
    37	deploy_tree_id : NAMETYPE
    36	fwd_index : XXX
    35	NocAgentMaster : XXX
    35	cell_config : XXX
    35	deployment_tree : OBJECT
    35	NocMasterAgent : XXX
    35	containers : ARRAY
    35	required_config : XXX
    35	tree_name : OBJECT
    35	manifest : OBJECT
    35	params : ARRAY
    35	vms : ARRAY
    31	base_tree_map_keys : ARRAY
    31	base_tree_map_values : ARRAY
    27	is_border : BOOLEAN
    20	cell_number : NUMBER
    18	save : BOOLEAN
    18	no_saved_msgs : NUMBER
    13	rite_cell : NAMETYPE
    13	link_id : NAMETYPE
    13	rite_port : PORT_DESC
    13	left_cell : NAMETYPE
    13	left_port : PORT_DESC
    10	deployment_tree_id : NAMETYPE
    10	allowed_tree : OBJECT
    10	vm_id : NAMETYPE
    10	tree_vm_map_keys : ARRAY
    10	tcp_msg : STRING # "Hello From Master", "Reply from Container:VM:C:0+vm1+2"
    10	up_tree_name : XXX

---

    /body/tree_vm_map_keys[] : SEQ OF NAMETYPE

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

