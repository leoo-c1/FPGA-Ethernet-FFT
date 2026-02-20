package eth_types_pkg;

    // Ethernet frame header components
    typedef struct packed {
        logic [5:0][7:0] dest_mac;
        logic [5:0][7:0] src_mac;
        logic [1:0][7:0] ethertype;
    } frame_header;

    // IP packet header components
    typedef struct packed {
        logic [3:0] version;
        logic [3:0] header_len;
        logic [5:0] dscp;
        logic [1:0] ecn;
        logic [1:0][7:0] total_len;
        logic [1:0][7:0] identification;
        logic [2:0] flags;
        logic [12:0] frag_offset;
        logic [7:0] ttl;
        logic [7:0] protocol;
        logic [1:0][7:0] header_csum;
        logic [3:0][7:0] src_ip;
        logic [3:0][7:0] dest_ip;
    } ip_header;

    // UDP datagram header components
    typedef struct packed {
        logic [1:0][7:0] src_port;
        logic [1:0][7:0] dest_port;
        logic [1:0][7:0] udp_len;
        logic [1:0][7:0] udp_csum;
    } udp_header;

    typedef enum [2:0] {
        IDLE,           // Haven't received the SFD yet
        ETH_HEADER,     // Reading MACs and EtherType
        IP_HEADER,      // Reading IP header
        UDP_HEADER,     // Reading UDP header
        PAYLOAD,        // Reading the payload data
        FCS             // Checking the CRC
    } eth_states;

endpackage