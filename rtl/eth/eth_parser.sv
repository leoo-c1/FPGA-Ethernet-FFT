import eth_types_pkg::*;

module eth_parser #(
    parameter FPGA_MAC = 48'h00_1A_2B_3C_4D_5E, // FPGA's MAC address (theoretical)
    parameter FPGA_IP = 32'hC0_00_02_92,        // FPGA's IP address of 192.0.2.146 (theoretical)
    parameter FPGA_PORT = 16'd5005              // FPGA's UDP port (theoretical)
    ) (
    input logic clk,                    // 50MHz LAN8720 clock
    input logic resetn,                 // Reset button (active low)

    input logic [7:0] received_byte,    // The byte of data we have received from the LAN8720
    input logic byte_valid,             // Pulses for one clock cycle on valid byte

    output logic [7:0] payload,         // The payload data
    output logic payload_valid,         // Whether we are currently receiving payload data
    output logic payload_last           // Pulses on the last byte of our payload data
    );

    frame_header frame_header_content;  // Each component of the ethernet frame header
    ip_header ip_header_content;        // Each component of the IP packet header
    udp_header udp_header_content;      // Each component of the UDP datagram header

    eth_states state;                   // The current ethernet state we are in

    logic [47:0] dest_mac_flat;
    logic [15:0] ethertype_flat;
    logic [31:0] dest_ip_flat;
    logic [15:0] dest_port_flat;
    logic [15:0] udp_len_flat;

    // Destination MAC
    assign dest_mac_flat = {frame_header_content.dest_mac[0], frame_header_content.dest_mac[1],
                            frame_header_content.dest_mac[2], frame_header_content.dest_mac[3],
                            frame_header_content.dest_mac[4], frame_header_content.dest_mac[5]};

    // Ethertype, low byte is the current received byte at the time of checking this
    assign ethertype_flat = {frame_header_content.ethertype[0], received_byte};

    // Destination IP address
    assign dest_ip_flat = {ip_header_content.dest_ip[0], ip_header_content.dest_ip[1],
                           ip_header_content.dest_ip[2], ip_header_content.dest_ip[3]};

    // Destination UDP port
    assign dest_port_flat = {udp_header_content.dest_port[0], udp_header_content.dest_port[1]};

    // UDP length
    assign udp_len_flat = {udp_header_content.udp_len[0], udp_header_content.udp_len[1]};

    logic [16:0] ip_checksum_calc;      // The calculated checksum of the IP header
    logic [31:0] ip_checksum_acc;       // 32 bits to handle overflow carries
    logic [15:0] current_word;          // Temporary holder for the 16-bit word

    always_comb begin
        // Add any carry-over to the bottom 4 hex digits of the sum
        ip_checksum_calc = ip_checksum_acc[31:16] + ip_checksum_acc[15:0];
        // Check if there is still 1 bit of carry-over left over
        if (ip_checksum_calc[16])
            ip_checksum_calc = ip_checksum_calc[15:0] + 1'b1;
        
        ip_checksum_calc = {1'b0, ~ip_checksum_calc[15:0]};
    end

    logic [15:0] byte_counter = 0;      // Counts the number of bytes we have received

    always_ff @ (posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            payload <= 8'b0;
            payload_valid <= 1'b0;
            payload_last <= 1'b0;
            byte_counter <= 0;
            ip_checksum_acc <= 0;
        end else begin
            if (state == IDLE) begin
                payload_valid <= 1'b0;
                payload_last <= 1'b0;
                byte_counter <= 0;
                if (byte_valid) begin
                    // If we just received the SFD
                    if (received_byte == 8'hD5)
                        state <= ETH_HEADER;        // Get ready to start reading the frame header
                    else
                        state <= IDLE;
                end else
                    state <= IDLE;
            end else if (state == ETH_HEADER) begin
                // Assign bytes based on the current byte counter
                if (byte_valid) begin
                    if (byte_counter < 6)
                        frame_header_content.dest_mac[byte_counter] <= received_byte;
                    else if (byte_counter < 12)
                        frame_header_content.src_mac[byte_counter-6] <= received_byte;
                    else if (byte_counter < 14)
                        frame_header_content.ethertype[byte_counter-12] <= received_byte;

                    if (byte_counter < 13)
                        byte_counter <= byte_counter + 1'b1;
                    else begin
                        byte_counter <= 0;
                        ip_checksum_acc <= 0;
                        // Make sure the destination mac is ours and ethertype is 0x0800 (IPv4)
                        if ((dest_mac_flat == FPGA_MAC) & (ethertype_flat == 16'h0800))
                            state <= IP_HEADER;
                        else
                            state <= IDLE;
                    end
                end

            end else if (state == IP_HEADER) begin
                if (byte_valid) begin
                    // Assign bytes based on the current byte counter
                    case (byte_counter)
                        0: begin
                            ip_header_content.version <= received_byte[7:4];
                            ip_header_content.header_len <= received_byte[3:0];
                        end

                        1: begin
                            ip_header_content.dscp <= received_byte[7:2];
                            ip_header_content.ecn <= received_byte[1:0];
                        end

                        2: ip_header_content.total_len[0] <= received_byte;
                        3: ip_header_content.total_len[1] <= received_byte;

                        4: ip_header_content.identification[0] <= received_byte;
                        5: ip_header_content.identification[1] <= received_byte;

                        6: begin
                            ip_header_content.flags <= received_byte[7:5];
                            ip_header_content.frag_offset[12:8] <= received_byte[4:0];
                        end
                        7: ip_header_content.frag_offset[7:0] <= received_byte;

                        8: ip_header_content.ttl[0] <= received_byte;

                        9: ip_header_content.protocol[0] <= received_byte;

                        10: ip_header_content.header_csum[0] <= received_byte;
                        11: ip_header_content.header_csum[1] <= received_byte;

                        12: ip_header_content.src_ip[0] <= received_byte;
                        13: ip_header_content.src_ip[1] <= received_byte;
                        14: ip_header_content.src_ip[2] <= received_byte;
                        15: ip_header_content.src_ip[3] <= received_byte;

                        16: ip_header_content.dest_ip[0] <= received_byte;
                        17: ip_header_content.dest_ip[1] <= received_byte;
                        18: ip_header_content.dest_ip[2] <= received_byte;
                        19: ip_header_content.dest_ip[3] <= received_byte;
                    endcase

                    if (byte_counter[0] == 1'b0) begin
                        // If the current byte is even, it is the MSByte of the 16-bit word
                        current_word[15:8] <= received_byte;
                    end 
                    else begin
                        // The current byte is odd, so it is the LSByte of the 16-bit word
                        current_word[7:0] <= received_byte;     // Complete the word
                        ip_checksum_acc <= ip_checksum_acc + {current_word[15:8], received_byte};
                    end

                    if (byte_counter < 19)
                        byte_counter <= byte_counter + 1'b1;
                    else begin
                        byte_counter <= 0;
                        current_word <= 16'b0;

                        // Go to the UDP header state
                        state <= UDP_HEADER;
                    end
                end

            end else if (state == UDP_HEADER) begin
                if (byte_valid) begin
                    if (byte_counter == 0) begin
                        // Check if checksum is the valid 0x0000 and dest_ip matches the FPGA's IP
                        if (~(ip_checksum_calc == 16'h0000) | ~(dest_ip_flat == FPGA_IP))
                            state <= IDLE;
                    end

                    // Assign bytes based on the current byte counter
                    case (byte_counter)
                        0: udp_header_content.src_port[0] <= received_byte;
                        1: udp_header_content.src_port[1] <= received_byte;

                        2: udp_header_content.dest_port[0] <= received_byte;
                        3: udp_header_content.dest_port[1] <= received_byte;

                        4: udp_header_content.udp_len[0] <= received_byte;
                        5: udp_header_content.udp_len[1] <= received_byte;

                        6: udp_header_content.udp_csum[0] <= received_byte;
                        7: udp_header_content.udp_csum[1] <= received_byte;
                    endcase

                    if (byte_counter < 7)
                        byte_counter <= byte_counter + 1'b1;
                    else begin
                        byte_counter <= 0;
                        current_word <= 16'b0;

                        // Check if dest_port matches the FPGA's port
                        if (dest_port_flat == FPGA_PORT)
                            state <= PAYLOAD;
                        else
                            state <= IDLE;
                    end
                end

            end else if (state == PAYLOAD) begin
                if (byte_valid) begin
                    payload_valid <= 1'b1;
                    payload <= received_byte;

                    if (byte_counter < udp_len_flat - 16'd9) begin
                        byte_counter <= byte_counter + 1'b1;
                        payload_last <= 1'b0;
                    end
                    else if (byte_counter == udp_len_flat - 16'd9) begin
                        byte_counter <= 0;
                        payload_last <= 1'b1;
                        state <= FCS;
                    end
                end else
                    payload_valid <= 1'b0;

            end else if (state == FCS) begin
                if (byte_valid) begin
                    payload_last <= 1'b0;
                    payload_valid <= 1'b0;

                    if (byte_counter < 4)
                        byte_counter <= byte_counter + 1'b1;
                    else
                        state <= IDLE;
                end

            end else begin
                state <= IDLE;
            end
        end
    end

endmodule