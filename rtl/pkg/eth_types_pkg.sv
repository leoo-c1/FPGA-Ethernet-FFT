package eth_types_pkg;

    // Ethernet frame header components
    typedef struct {
        byte unsigned dest_mac [6];
        byte unsigned src_mac [6];
        byte unsigned ethertype [2];
    } frame_header;

    // IP packet header components
    typedef struct {
        bit [3:0] version;
        bit [3:0] header_len;
        bit [5:0] dscp;
        bit [1:0] ecn;
        byte unsigned total_len [2];
        byte unsigned identification [2];
        bit [2:0] flags;
        bit [12:0] frag_offset;
        byte unsigned ttl [1];
        byte unsigned protocol [1];
        byte unsigned header_csum [2];
        byte unsigned src_ip [4];
        byte unsigned dest_ip [4];
    } ip_header;

    // UDP datagram header components
    typedef struct {
        byte unsigned src_port [2];
        byte unsigned dest_port [2];
        byte unsigned udp_len [2];
        byte unsigned udp_csum [2];
    } udp_header;

    typedef enum {
        IDLE,           // Haven't received the SFD yet
        ETH_HEADER,     // Reading MACs and EtherType
        IP_HEADER,      // Reading IP header
        UDP_HEADER,     // Reading UDP header
        PAYLOAD,        // Reading the payload data
        FCS             // Checking the CRC
    } eth_states;

endpackage