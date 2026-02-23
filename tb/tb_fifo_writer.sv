`timescale 1ns/100ps

module tb_fifo_writer;

    logic phy_clk;              // 50MHz LAN8720 clock
    logic resetn;               // Reset button (active low)

    // eth_parser inputs
    logic data_valid;
    logic [7:0] received_byte;  // The byte of data we have received from the LAN8720
    logic byte_valid;           // Pulses for one clock cycle on valid byte

    // eth_parser outputs
    logic [7:0] payload;        // The payload data
    logic payload_valid;        // Whether we are currently receiving payload data
    logic payload_last;         // Pulses on the last byte of our payload data

    // fifo_writer outputs
    logic wrreq;                 // Requests a write operation when high
    logic [15:0] fifo_data;      // The data we write to the fifo

    // audio_fifo output
    logic wr_full;              // Indicates the fifo is currently full
    logic [11:0] rdusedw;       // Tells us how many 16-bit words are in the FIFO
    logic [15:0] fifo_q;        // The data output of the FIFO
    logic rdreq = 1'b0;         // Keep the read request tied low so we don't accidentally empty it

    eth_parser #(
        .FPGA_MAC(48'h00_1A_2B_3C_4D_5E),
        .FPGA_IP(32'hC0_00_02_92),
        .FPGA_PORT(16'd5005)
    ) eth_parser_test (
        .phy_clk(phy_clk),
        .resetn(resetn),
        .data_valid(data_valid),
        .received_byte(received_byte),
        .byte_valid(byte_valid),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last)
    );

    fifo_writer u_fifo_writer (
        .phy_clk(phy_clk),
        .resetn(resetn),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last),
        .wr_full(wr_full),
        .wrreq(wrreq),
        .fifo_data(fifo_data)
    );

    audio_fifo u_audio_fifo (
        .data(fifo_data),
        .rdclk(phy_clk),
        .rdreq(rdreq),
        .wrclk(phy_clk),
        .wrreq(wrreq),
        .q(fifo_q),
        .rdusedw(rdusedw),
        .wrfull(wr_full)
    );

    task send_byte;
        input [7:0] byte_to_send;
        begin
            @ (posedge phy_clk);
            received_byte <= byte_to_send;
            byte_valid <= 1'b1;

            @ (posedge phy_clk);
            byte_valid <= 1'b0;
        end
    endtask

    task send_frame;
        input [47:0] task_dest_mac;
        input [15:0] task_ethertype;
        input [15:0] task_header_csum;
        input [31:0] task_dest_ip;
        input [15:0] task_dest_port;
        input integer payload_bytes;

        integer i;                  // Loop variable
        logic [15:0] udp_len;
        begin
            data_valid = 1'b1;      // Make data_valid go high
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

            // UDP length is dynamic as it depends on payload_bytes
            udp_len = payload_bytes + 16'd8;
            send_byte(udp_len[15:8]);
            send_byte(udp_len[7:0]);

            // Send 2 placeholder bytes for UDP checksum
            send_byte(8'h8E);
            send_byte(8'h8E);

            // Loop to send 'payload_bytes' bytes of data
            for (i = 0; i < payload_bytes; i = i + 1) begin
                send_byte(i[7:0]);
            end

            // Send 4 placeholder bytes for FCS
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);
            send_byte(8'h8E);

            @ (posedge phy_clk);
            data_valid = 1'b0;      // Make data_valid low after the frame
        end
    endtask

    always begin
        #10 phy_clk = ~phy_clk;     // Generate 50MHz clock signal
    end

    initial begin
        phy_clk = 0;            // Initially, clock is low
        resetn = 0;         // Reset is active
        data_valid = 0;

        #200 resetn = 1;    // After 200ns, turn off the reset signal
        #200;               // Wait another 200ns doing nothing

        // Send first 1472 byte packet (736 audio samples)
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .payload_bytes(1472)
        );

        // Small delay between packets
        #500;

        // Send second 1472 byte packet (FIFO should now hit 1472 words)
        send_frame (
            .task_dest_mac(48'h00_1A_2B_3C_4D_5E),
            .task_ethertype(16'h0800),
            .task_header_csum(16'hE5F5),
            .task_dest_ip(32'hC0_00_02_92),
            .task_dest_port(16'd5005),
            .payload_bytes(1472)
        );

        #10_000     // Wait a bit
        $stop(2);   // Finish the simulation
    end

endmodule