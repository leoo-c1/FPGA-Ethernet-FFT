`timescale 1ns/100ps

module tb_eth_parser;

    logic clk;                  // 50MHz LAN8720 clock
    logic resetn;               // Reset button (active low)

    logic [7:0] received_byte;  // The byte of data we have received from the LAN8720
    logic byte_valid;           // Pulses for one clock cycle on valid byte

    logic [7:0] payload;        // The payload data
    logic payload_valid;        // Whether we are currently receiving payload data
    logic payload_last;         // Pulses on the last byte of our payload data

    eth_parser #(
        .FPGA_MAC(48'h00_1A_2B_3C_4D_5E),
        .FPGA_IP(32'hC0_00_02_92),
        .FPGA_PORT(16'd5005)
    ) eth_parser_test (
        .clk(clk),
        .resetn(resetn),
        .received_byte(received_byte),
        .byte_valid(byte_valid),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last)
    );

    task send_byte;
        input [7:0] byte_to_send;
        begin
            @ (posedge clk);
            received_byte <= byte_to_send;
            byte_valid <= 1'b1;

            @ (posedge clk);
            byte_valid <= 1'b0;
        end
    endtask

    task send_frame;
        input [47:0] task_dest_mac;
        input [15:0] task_ethertype;
        input [15:0] task_header_csum;
        input [31:0] task_dest_ip;
        input [15:0] task_dest_port;
        input [31:0] task_payload;

        begin
            send_byte(8'h55);       // Start preamble
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'h55);
            send_byte(8'hD5);      // Send SFD

            // Send 6 bytes for destination MAC
            send_byte(task_dest_mac[47:40]);
            send_byte(task_dest_mac[39:32]);
            send_byte(task_dest_mac[31:24]);
            send_byte(task_dest_mac[23:16]);
            send_byte(task_dest_mac[15:8]);
            send_byte(task_dest_mac[7:0]);

            // Send 6 placeholder bytes for source MAC
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);

            // Send 2 bytes for ethertype
            send_byte(task_ethertype[15:8]);
            send_byte(task_ethertype[7:0]);

            // Send 10 placeholders bytes for everything from version up to protocol
            send_byte(8'h8E);   // Version/IHL
            send_byte(8'h8E);   // DSCP/ECN
            send_byte(8'h00);   // Top of total length, where total length = 16'h0020
            send_byte(8'h20);   // Bottom of total length, where total length = 16'h0020
            send_byte(8'h8E);   // Top of identification
            send_byte(8'h8E);   // Bottom of identification
            send_byte(8'h8E);   // Flags + part of fragment offset
            send_byte(8'h8E);   // Rest of fragment offset
            send_byte(8'h8E);   // Time to live
            send_byte(8'h8E);   // Protocol

            // Send 2 bytes for the IP header checksum
            send_byte(task_header_csum[15:8]);
            send_byte(task_header_csum[7:0]);

            // Send 4 placeholder bytes for source IP
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);

            // Send 4 bytes for destination IP
            send_byte(task_dest_ip[31:24]);
            send_byte(task_dest_ip[23:16]);
            send_byte(task_dest_ip[15:8]);
            send_byte(task_dest_ip[7:0]);

            // Send 2 placeholder bytes for source port
            send_byte(8'h8E);
            send_byte(8'h8E);

            // Send 2 bytes for destination port
            send_byte(task_dest_port[15:8]);
            send_byte(task_dest_port[7:0]);

            // Force payload to be 4 bytes, so make UDP length 12 bytes
            send_byte(8'h00);
            send_byte(8'd12);

            // Send 2 placeholder bytes for UDP checksum
            send_byte(8'h8E);
            send_byte(8'h8E);

            // Send 4 bytes for payload
            send_byte(task_payload[31:24]);
            send_byte(task_payload[23:16]);
            send_byte(task_payload[15:8]);
            send_byte(task_payload[7:0]);

            // Send 4 placeholder bytes for FCS
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
        end
    endtask

    initial begin
        clk = 0;
    end

    always begin
        #10 clk = ~clk;         // Generate 50MHz clock signal
    end

    initial begin
        clk = 0;            // Initially, clock is low
        resetn = 0;         // Reset is active

        #200 resetn = 1;    // After 200ns, turn off the reset signal
        #200;               // Wait another 200ns doing nothing

        // Send a completely valid frame
        // Header checksum should be 16'hE5F5 based on these values
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send a frame that has the incorrect destination mac
        send_frame (
            .task_dest_mac(48'h10_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send a frame that has the incorrect ethertype
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h86DD),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send a frame that has the incorrect checksum
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F6),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send a frame that has the incorrect destination IP
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_AA_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send a frame that has the incorrect destination port
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd8001),
            .task_payload(32'hDEADBEEF)
        );

        // Wait a bit
        #80;

        // Send 2 valid frames back-to-back
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );
        #20;
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .task_payload(32'hDEADBEEF)
        );

        #10_000     // Wait a bit
        $stop(2);   // Finish the simulation
    end

endmodule