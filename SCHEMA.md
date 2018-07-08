
# Log Messaging Substrate (LMS) - JSON Schema and notes for Trace Records

    aka Stream Processing System
    Kafka Model (highly scalable)

GitHub Flavored Markdown: https://github.github.com/gfm/

## NAME_TYPE:

    /.../name : STRING
    /.../uuid/uuid[] : SEQ 2 OF NUMBER

## PORT_DESC:

    /.../ : OBJECT { v }
    /.../v : NUMBER

## SCHEMA:

    : OBJECT { header body }

## Trace Metadata:

    /header : OBJECT { repo module function trace_type format - thread_id event_id - epoch }

    /header/repo : STRING
    /header/module : STRING
    /header/function : STRING
    /header/trace_type : STRING # Trace, Debug
    /header/format : STRING
    /header/thread_id : NUMBER
    /header/event_id[] : SEQ OF NUMBER
    /header/epoch : NUMBER

Trace record parsing is done on a per unique "emitter key" basis :

    my $emitter_key = join('$$', $repo, $module, $function, $kind, $format);

Each record SHOULD have a unique "trace key".  In order to be defensive against bugs, adding a stream sequence number (or lineno) disambiguates things.  The notion here is that a number of independent emitters may be publishing trace records thru the same channel HOWEVER sequential in the channel DOES NOT necessarily imply causal ordering.  Ordering by key is a causal guarantee (from the actual emitter).

    my $trace_key = join('::', $thread_id, $event_id, $lineno);

## MAIN:

    "body": {
        "schema_version": "0.1",
        "build_info": "...."
    }

    https://github.com/earthcomputing/${repo}.git
    1530634503352636 (20180703-161503.352636 PDT)

## Datacenter 'Complex' wiring diagram:

    ## IMPORTANT : link activation
    # /body : OBJECT { link_id left_cell left_port rite_cell rite_port }
    # 'datacenter.rs$$initialize$$Trace$$connect_link'
    sub meth_connect_link {
        my ($body) = @_;
        my $link_id = $body->{'link_id'}{'name'};
        my $left_cell = nametype($body->{'left_cell'});
        my $left_port = portdesc($body->{'left_port'});
        my $rite_cell = nametype($body->{'rite_cell'});
        my $rite_port = portdesc($body->{'rite_port'});

        ## FIXME : GEV magic, should happen thru Discovery!
        ## Complex Entry:
        if (defined $link_id) {
            my ($c1, $lc, $p1, $lp, $c2, $rc, $p2, $rp) = split(/:|\+/, $link_id); # C:0+P:1+C:1+P:1
**            activate_edge($lc, $lp, $rc, $rp); **
        }
        print(join(' ', $link_id, ';'));
    }

---
Border Port:

    ## IMPORTANT : Complex Entry
    # /body : OBJECT { cell_id port_no is_border }
    # 'cellagent.rs$$port_connected$$Trace$$ca_send_msg'
    sub meth_ca_send_msg_port_connected {
        my ($body) = @_;
        my $cell_id = nametype($body->{'cell_id'});
        my $port_no = portdesc($body->{'port_no'});
        my $is_border = $body->{'is_border'}; # cell port=of-entry

        ## Complex Entry:
        my $port_id = '';
        if (defined $port_no) {
            $port_id = (($is_border) ? 'FX:' : '').$port_no;
**            border_port($cell_id, $port_no) if $is_border; **
        }
        print(join(' ', $cell_id, $port_id, ';'));
    }

## Spanning Tree Link Identification (Discovery):

    ## IMPORTANT : Forest/DiscoverD
    # /body : OBJECT { cell_id port_no msg  }
    # 'cellagent.rs$$listen_cm_loop$$Debug$$ca_got_msg'
    #
    # parent :    /body/cell_id: NAME_TYPE                # "C:0"
    # link :      /body/port_no : PORT_DESC               # - relative to this node, aka parent
    # msg_type :  /body/msg/header/msg_type : String      # "DiscoverD"
    # child :     /body/msg/header/sender_id : NAME_TYPE  # "Sender:C:1+CellAgent"
    # span-tree : /body/msg/payload/tree_id : NAME_TYPE   # "Tree:C:0"
    sub meth_ca_got_msg_cmodel {
        my ($body) = @_;
        my $cell_id = nametype($body->{'cell_id'});
        my $port_no = portdesc($body->{'port_no'});
        my $summary = summarize_msg($body->{'msg'});

        print(join(' ', $cell_id, $port_no, $summary, ';'));

        # /.../msg/header/msg_type
        # /.../msg/header/sender_id
        my $msg = $body->{'msg'};
        my $header = $msg->{'header'};
        my $payload = $msg->{'payload'};

        my $msg_type = $header->{'msg_type'};

        return unless $msg_type eq 'DiscoverD';

        ## sort out link/edge/bias:

        # FIXME
        my $p = $body->{'port_no'}{'v'};
        # my $link = ($parent, $p);
        # my ($edge, $bias) = ($link);

        ## Forest / DiscoverD
        my $sender_id = nametype($header->{'sender_id'});
        my $tree_id = nametype($payload->{'tree_id'});

        # FIXME : parse names
        my $parent = $cell_id;
        my $child = $sender_id;
        my $span_tree = $tree_id;

        add_tree_link($span_tree, $parent, $p, $child);
    }

## GUIDS (example)

    a6c47326 0x0000000000000000007C5D07A6C47326 C:0
    ed92353c 0x00000000000000005ECEC45FED92353C C:1
    64706081 0x0000000000000000B1DC43ED64706081 C:2
    00000000 0x00000000000000000000000000000000 NocAgentMaster
    ae2efa9b 0x0000000000000000AF943EABAE2EFA9B Sender:C:0+CellAgent
    5b0877ee 0x00000000000000004BBCCFCB5B0877EE Sender:C:0+VM:C:0+vm1
    34dad883 0x000000000000000042F6C5CE34DAD883 Sender:C:1+CellAgent
    eda6a9b1 0x000000000000000089436F38EDA6A9B1 Sender:C:1+VM:C:1+vm1
    f064c137 0x0000000000000000B06112BDF064C137 Sender:C:2+BorderPort+2
    dcce50a2 0x0000000000000000A70CAA9BDCCE50A2 Sender:C:2+CellAgent
    08e000dc 0x0000000000000000A8FBFC6708E000DC Sender:C:2+VM:C:2+vm1
    68afc0f8 0x0000000000000000E16C0E0568AFC0F8 Tree:C:0
    45fc3d70 0x0000000000000000E43193C745FC3D70 Tree:C:0+Connected
    372ecfca 0x00000000000000004850A27A372ECFCA Tree:C:0+Control
    abc44384 0x0000000000000000A4899807ABC44384 Tree:C:1
    11bb0267 0x000000000000000036EBB3A611BB0267 Tree:C:1+Connected
    1f67615c 0x00000000000000000F3DB7991F67615C Tree:C:1+Control
    29ef2d77 0x0000000000000000C89609D229EF2D77 Tree:C:2
    6e5791fe 0x0000000000000000F137DD9A6E5791FE Tree:C:2+Connected
    2b21a0d2 0x0000000000000000F18C70282B21A0D2 Tree:C:2+Control
    cac7473d 0x00000000000000007E92A542CAC7473D Tree:C:2+Noc
    91a34dde 0x000000000000000020AC786C91A34DDE Tree:C:2+NocAgentDeploy
    17c2befe 0x00000000000000008291287217C2BEFE Tree:C:2+NocAgentMaster
    6f576c5b 0x000000000000000000A5E0896F576C5B Tree:C:2+NocMasterAgent
    8efbb9a0 0x000000000000000011C028F38EFBB9A0 Tree:C:2+NocMasterDeploy
    45df39b7 0x00000000000000003636ECCE45DF39B7 VM:C:0+vm1
    155c1e00 0x000000000000000065BEBDB6155C1E00 VM:C:1+vm1
    3415de02 0x0000000000000000BD6F4E0F3415DE02 VM:C:2+vm1

## Sender Names (typical)

    Discover - "Sender:C:0+CellAgent"
    DiscoverD - "Sender:C:0+CellAgent"
    StackTree - "Sender:C:2+BorderPort+2"
    StackTreeD - "Sender:C:2+BorderPort+2"
    Manifest - "Sender:C:2+BorderPort+2"
    Application - "Sender:C:9+VM:C:9+vm1"

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

    BONUS points : show unidirectional channel info (a, a')

    Note : happens-before is problematic here so rely upon stream order

---

Ideally, this is an observation point for traffic that's going between the Cell Agent and the Packet Engine (in the 'cell-snd' direction).  At this time it's considered a serialization point - so this is introduces a "happens-before" causal relationship.

Alan and I are currently trying to untangle this a bit.  Alan was thinking that he's debugging what the Cell Agent is doing, and he leverages his simulator's GEV which makes names for things easier.  In a real world production systems (and looking at a "time window" of the telementry stream), we'd need to keep a running translation map for things (think uuid's) to make things more understandable for human beings.  The trick that GIT uses is to just use a few hex digits from the uuid (4 or 5, prefix or suffix), however I suspect being able to associate string tags (e.g. Alice, Bob) might be immensely helpful.

Another idea being kicked around is to hash the msg body here and use that as a "msg ref" value.  A separate report/dump could be consulted if msg details are needed.  It's really not worth it to start doing deep packet inspection all over the place in order to show some useful values - that's really a code/debugging notion that really isn't useful in the streaming world.  Think Wireshark rather than program printf's.

---

    # 'cellagent.rs$$send_msg$$Debug$$ca_send_msg'
    sub meth_ca_send_msg2 {

        my $cell_id = nametype($body->{'cell_id'});
        my $tree_id = nametype($body->{'tree_id'});
        my $port_list = build_port_list($body->{'port_nos'});
        my $summary = summarize_msg($body->{'msg'});

        ## Spreadsheet Coding:
        my $msg_type = $body->{'msg'}{'header'}{'msg_type'};
        my $port_nos = $body->{'port_nos'};
        my $c = $cell_id; $c =~ s/C://;
        my $event_code = ec_fromkey($key);

        # FIXME : don't break out individual ports here - that should happen in PE
        foreach my $item (@{$port_nos}) {
            my $p = $item->{'v'};
            add_msgcode($c, $p, $msg_type, $event_code, 'cell-snd', $tree_id); # $tree_id.' '.$port_list);
        }
    }

If I understand things correctly, this observation point is for the "port #0" channel recieve of msgs coming 'down' to the PE from the Cell Agent.

    # 'packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca'
    sub meth_pe_packet_from_ca {

        my $cell_id = nametype($body->{'cell_id'});
        my $tree_id = nametype($body->{'tree_id'});
        my $msg_type = $body->{'msg_type'};

        ## Spreadsheet Coding:
        my $event_code = ec_fromkey($key);
        my $c = $cell_id; $c =~ s/C://;
        my $p = 9999;
        add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
    }

I'm guessing this is the observation point for the PE taking msgs off of a link and then passing them along based upon the 'traph' data for the 'index' (forwarding table entry) for the "destination tree".

    # 'packet_engine.rs$$forward$$Debug$$pe_forward_leafward'
    sub meth_pe_forward_leafward {

        my $cell_id = nametype($body->{'cell_id'});
        my $tree_id = nametype($body->{'tree_id'});
        my $port_list = build_port_list($body->{'port_nos'});
        my $msg_type = $body->{'msg_type'};

        ## Spreadsheet Coding:
        my $port_nos = $body->{'port_nos'};
        my $c = $cell_id; $c =~ s/C://;
        my $event_code = ec_fromkey($key);
        foreach my $item (@{$port_nos}) {
            my $p = $item->{'v'};
            add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
        }
    }

It's unclear that we really need forward leafward/rootward as completely different records/methods?  Could this be simplified by passing a 'direction' value? There is the difference between a single port and a port-set to be considered, but as I understand things, these are referred by index/direction and so it seems like Alan is 'helping' here ??

    # 'packet_engine.rs$$forward$$Debug$$pe_forward_rootward'
    sub meth_pe_forward_rootward {

        my $cell_id = nametype($body->{'cell_id'});
        my $tree_id = nametype($body->{'tree_id'});
        my $msg_type = $body->{'msg_type'};
        my $port_no = portdesc($body->{'parent_port'});

        ## Spreadsheet Coding:
        my $event_code = ec_fromkey($key);
        my $c = $cell_id; $c =~ s/C://;
        my $p = $body->{'parent_port'}{'v'};
        add_msgcode($c, $p, $msg_type, $event_code, 'pe-snd', $tree_id);
    }

Kinda confused here - I think this is the internals of the PE when it's interpreting a message from the Cell Agent telling the PE to update the forwarding table ??

    # 'packet_engine.rs$$process_packet$$Debug$$pe_process_packet'
    sub meth_pe_process_packet {

        my $cell_id = nametype($body->{'cell_id'});
        my $tree_id = nametype($body->{'tree_id'});
        my $msg_type = $body->{'msg_type'};
        my $port_no = portdesc($body->{'port_no'});
    #    'entry' => {
    #        'parent' => { 'v' => 0 },
    #        'inuse' : BOOLEAN
    #        'may_send' => $VAR1->{'entry'}{'inuse'},
    #        'mask' => { 'mask' => 1 },
    #        'index' => 0,
    #        'other_indices' => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
    #        'tree_uuid'
    #    },
        my $entry = $body->{'entry'};
        my $parent = portdesc($entry->{'parent'});

        ## Spreadsheet Coding:
        my $event_code = ec_fromkey($key);
        my $c = $cell_id; $c =~ s/C://;
        my $p = $body->{'port_no'}{'v'};
        add_msgcode($c, $p, $msg_type, $event_code, 'pe-rcv', $tree_id);
    }

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

## Body Forms:

    1	/body : OBJECT { schema_version }
    20	/body : OBJECT { cell_number }
    13	/body : OBJECT { link_id left_cell left_port rite_cell rite_port }
    68	/body : OBJECT { cell_id }

    685	/body : OBJECT { cell_id tree_id }
    291	/body : OBJECT { cell_id base_tree_id entry }
    291	/body : OBJECT { cell_id base_tree_id children gvm hops other_index port_number port_status }
    148	/body : OBJECT { cell_id base_tree_id stacked_tree_id }
    31	/body : OBJECT { cell_id base_tree_id base_tree_map_keys base_tree_map_values new_tree_id }
    27	/body : OBJECT { cell_id port_no is_border }
    18	/body : OBJECT { cell_id no_saved_msgs tree_id }
    10	/body : OBJECT { cell_id sender_id vm_id }
    10	/body : OBJECT { cell_id deployment_tree_id tree_vm_map_keys up_tree_name }

    614	/body : OBJECT { cell_id msg_type port_nos tree_id }
    340	/body : OBJECT { cell_id msg_type entry port_no tree_id }
    297	/body : OBJECT { cell_id msg_type tree_id }
    17	/body : OBJECT { cell_id msg_type parent_port tree_id }
    10	/body : OBJECT { cell_id msg_type allowed_tree direction tcp_msg }
    6	/body : OBJECT { cell_id msg_type port_nos }

    333	/body : OBJECT { cell_id msg }
    266	/body : OBJECT { cell_id msg port_nos tree_id }
    117	/body : OBJECT { cell_id msg new_tree_id port_no }
    100	/body : OBJECT { cell_id msg tree_id }
    51	/body : OBJECT { cell_id msg no_saved tree_id }
    19	/body : OBJECT { cell_id msg port_no tree_id }
    18	/body : OBJECT { cell_id msg port_no save tree_id }
    4	/body : OBJECT { cell_id msg entry new_tree_id }
    2	/body : OBJECT { cell_id msg deploy_tree_id }

## Message Header:

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

## Message Payload Forms:

    /.../payload : OBJECT { tree_id body }
    /.../payload : OBJECT { tree_id fwd_index index }
    /.../payload : OBJECT { tree_id gvm_eqn hops index path sending_cell_id }
    /.../payload : OBJECT { tree_id my_index }
    /.../payload : OBJECT { parent_tree_id gvm_eqn index new_tree_id }
    /.../payload : OBJECT { deploy_tree_id manifest tree_name }

## Message Payload Notes:

    /.../payload/tree_id : NAMETYPE
    /.../payload/parent_tree_id : NAMETYPE
    /.../payload/deploy_tree_id : NAMETYPE
    /.../payload/new_tree_id : NAMETYPE
    /.../payload/sending_cell_id : NAMETYPE
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

## Forwarding Table Entries:

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

## Graph Virtual Machine (GVM) Equations

    /body/gvm : OBJECT { recv_eqn save_eqn send_eqn variables xtnd_eqn }

    /.../gvm/recv_eqn
    /.../gvm/save_eqn
    /.../gvm/send_eqn
    /.../gvm/variables : ARRAY len=0
    /.../gvm/xtnd_eqn

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

## Software Bootstrap Manifest:

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

## Routing Table (example)

    entry/index : NUMBER
    entry/tree_uuid/uuid : UUID (SEQ 2 of NUMBER)
    entry/inuse : BOOLEAN
    entry/may_send : BOOLEAN
    entry/parent/v : NUMBER
    entry/mask/mask : NUMBER
    entry/other_indices : SEQ OF NUMBER

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

## Blueprint AND Spanning Trees (dot language):

    digraph G {
        rankdir=LR
        C0:p1 -> C1:p1 [label="a"]
        C0:p0 -> C0:p0 [label="b"]
        C1:p0 -> C1:p0 [label="c"]
        C0:p2 -> C2:p1 [label="d"]
        C2:p0 -> C2:p0 [label="e"]
        C1:p2 -> C2:p3 [label="f"]
        Internet -> C2:p2 [label="g"]
        C0 [label="C0  (b')"]
        C1 [label="C1  (c')"]
        C2 [label="C2  (e')"]

        C2:p3 -> C1:p2 [label="( C1 )" color=blue]
        C1:p2 -> C2:p3 [label="( C2 )" color=red]
        C1:p1 -> C0:p1 [label="( C0 )" color=blue]
        C0:p1 -> C1:p1 [label="( C1 )" color=red]
        C2:p1 -> C0:p2 [label="( C0 )" color=blue]
        C0:p2 -> C2:p1 [label="( C2 )" color=red]
    }

## VERBS:

    1	main.rs$MAIN

    685	cellagent.rs$get_base_tree_id
    582	cellagent.rs$update_traph
    333	cellagent.rs$listen_pe_loop
    266	cellagent.rs$send_msg
    148	cellagent.rs$update_base_tree_map
    90	cellagent.rs$add_saved_discover
    90	cellagent.rs$process_discover_msg
    31	cellagent.rs$stack_tree
    30	cellagent.rs$add_saved_stack_tree
    27	cellagent.rs$process_stack_tree_msg
    27	cellagent.rs$port_connected
    21	cellagent.rs$add_saved_msg
    18	cellagent.rs$get_saved_msgs
    18	cellagent.rs$process_stack_treed_msg
    18	cellagent.rs$process_application_msg
    10	cellagent.rs$listen_pe
    10	cellagent.rs$tcp_application
    10	cellagent.rs$listen_uptree
    10	cellagent.rs$process_manifest_msg
    10	cellagent.rs$deploy
    10	cellagent.rs$listen_uptree_loop
    9	cellagent.rs$process_discoverd_msg
    6	cellagent.rs$forward_saved
    4	cellagent.rs$tcp_stack_tree
    3	cellagent.rs$forward_stack_tree
    2	cellagent.rs$tcp_manifest
    23	datacenter.rs$initialize
    10	nalcell.rs$new
    10	nalcell.rs$start_cell
    10	nalcell.rs$start_packet_engine
    628	packet_engine.rs$forward
    340	packet_engine.rs$process_packet
    297	packet_engine.rs$listen_ca_loop
    10	packet_engine.rs$listen_port
    10	packet_engine.rs$listen_ca

---

    1	main.rs$$MAIN$$Trace$$trace_schema

    27	cellagent.rs$$port_connected$$Trace$$ca_send_msg
    13	datacenter.rs$$initialize$$Trace$$connect_link
    8	datacenter.rs$$initialize$$Trace$$interior_cell_start
    2	datacenter.rs$$initialize$$Trace$$border_cell_start
    10	nalcell.rs$$new$$Trace$$nalcell_port_setup
    10	nalcell.rs$$start_cell$$Trace$$nalcell_start_ca
    10	nalcell.rs$$start_packet_engine$$Trace$$nalcell_start_pe

    291	cellagent.rs$$update_traph$$Debug$$ca_updated_traph_entry
    291	cellagent.rs$$update_traph$$Debug$$ca_update_traph

    90	cellagent.rs$$process_discover_msg$$Debug$$ca_process_discover_msg
    27	cellagent.rs$$process_stack_tree_msg$$Debug$$ca_process_stack_tree_msg
    18	cellagent.rs$$process_stack_treed_msg$$Debug$$ca_process_stack_tree_d_msg
    18	cellagent.rs$$process_application_msg$$Debug$$ca_process_application_msg
    10	cellagent.rs$$process_manifest_msg$$Debug$$ca_process_manifest_msg
    9	cellagent.rs$$process_discoverd_msg$$Debug$$ca_process_discover_d_msg

    685	cellagent.rs$$get_base_tree_id$$Debug$$ca_get_base_tree_id
    333	cellagent.rs$$listen_pe_loop$$Debug$$ca_got_msg
    266	cellagent.rs$$send_msg$$Debug$$ca_send_msg
    148	cellagent.rs$$update_base_tree_map$$Debug$$ca_update_base_tree_map
    90	cellagent.rs$$add_saved_discover$$Debug$$ca_save_discover_msg
    31	cellagent.rs$$stack_tree$$Debug$$ca_stack_tree
    30	cellagent.rs$$add_saved_stack_tree$$Debug$$ca_save_stack_tree_msg
    21	cellagent.rs$$add_saved_msg$$Debug$$ca_add_saved_msg
    18	cellagent.rs$$get_saved_msgs$$Debug$$ca_get_saved_msgs
    10	cellagent.rs$$tcp_application$$Debug$$ca_got_tcp_application_msg
    10	cellagent.rs$$listen_uptree_loop$$Debug$$ca_got_from_uptree
    10	cellagent.rs$$listen_uptree$$Debug$$ca_listen_vm
    10	cellagent.rs$$listen_pe$$Debug$$ca_listen_pe
    10	cellagent.rs$$deploy$$Debug$$ca_deploy
    6	cellagent.rs$$forward_saved$$Debug$$ca_forward_saved_msg
    4	cellagent.rs$$tcp_stack_tree$$Debug$$ca_got_stack_tree_tcp_msg
    3	cellagent.rs$$forward_stack_tree$$Debug$$ca_forward_stack_tree_msg
    2	cellagent.rs$$tcp_manifest$$Debug$$ca_got_manifest_tcp_msg

    611	packet_engine.rs$$forward$$Debug$$pe_forward_leafward
    340	packet_engine.rs$$process_packet$$Debug$$pe_process_packet
    297	packet_engine.rs$$listen_ca_loop$$Debug$$pe_packet_from_ca
    17	packet_engine.rs$$forward$$Debug$$pe_forward_rootward
    10	packet_engine.rs$$listen_port$$Debug$$pe_listen_ports
    10	packet_engine.rs$$listen_ca$$Debug$$pe_listen_ca

## FIELDS:

    21779	uuid : OBJECT, ARRAY
    10862	name : XXX
    4736	v : NUMBER
    4717	header : OBJECT
    3873	body : OBJECT
    3807	trace_type : STRING # Trace, Debug
    3807	thread_id : NUMBER
    3807	repo
    3807	module : STRING # source file name, e.g. "foo.fs"
    3807	function : STRING # source code method name
    3807	format : STRING # random tag value
    3807	event_id : ARRAY
    3807	epoch
    3773	cell_id : NAMETYPE # "C:2"
    3182	tree_id : NAMETYPE
    2194	msg_type : STRING # Application, Discover, DiscoverD, Manifest, StackTree, StackTreeD
    1368	port_no : PORT_DESC
    1270	mask : OBJECT
    1255	index : XXX
    920	sender_id : NAMETYPE # "Sender:C:9+VM:C:9+vm1"
    920	direction : STRING # Leafward, Rootward
    910	tree_map : OBJECT
    910	payload : OBJECT
    910	msg_count : NUMBER
    910	msg : OBJECT
    886	port_nos : ARRAY
    875	xtnd_eqn : XXX
    875	variables : ARRAY
    875	send_eqn : XXX
    875	save_eqn : XXX
    875	recv_eqn : XXX
    761	base_tree_id : NAMETYPE
    757	port_number : OBJECT
    757	hops : NUMBER
    635	tree_uuid : XXX
    635	parent : XXX
    635	other_indices : ARRAY
    635	may_send : BOOLEAN
    635	inuse : BOOLEAN
    635	entry : OBJECT
    584	gvm_eqn : OBJECT
    466	sending_cell_id : XXX
    466	path : OBJECT
    291	port_status : STRING # Parent, Child, Pruned
    291	other_index : NUMBER
    291	gvm : OBJECT
    291	children : ARRAY
    270	new_tree_id : NAMETYPE
    189	my_index : XXX
    175	id : XXX
    148	stacked_tree_id : NAMETYPE
    118	var_type : XXX
    118	var_name : XXX
    118	value : XXX
    118	parent_tree_id : XXX
    105	allowed_trees : ARRAY
    70	trees : ARRAY
    70	parent_list : ARRAY
    70	image : XXX
    51	no_saved : NUMBER
    37	deploy_tree_id : NAMETYPE
    36	fwd_index : XXX
    35	vms : ARRAY
    35	tree_name : OBJECT
    35	required_config : XXX
    35	params : ARRAY
    35	manifest : OBJECT
    35	deployment_tree : OBJECT
    35	containers : ARRAY
    35	cell_config : XXX
    35	NocMasterAgent : XXX
    35	NocAgentMaster : XXX
    31	base_tree_map_values : ARRAY
    31	base_tree_map_keys : ARRAY
    27	is_border : BOOLEAN
    20	cell_number : NUMBER
    18	save : BOOLEAN
    18	no_saved_msgs : NUMBER
    17	parent_port
    13	rite_port : PORT_DESC
    13	rite_cell : NAMETYPE
    13	link_id : NAMETYPE
    13	left_port : PORT_DESC
    13	left_cell : NAMETYPE
    10	vm_id : NAMETYPE
    10	up_tree_name : XXX
    10	tree_vm_map_keys : ARRAY
    10	tcp_msg : STRING # "Hello From Master", "Reply from Container:VM:C:0+vm1+2"
    10	deployment_tree_id : NAMETYPE
    10	allowed_tree : OBJECT
    1	schema_version

## misc notes:

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

