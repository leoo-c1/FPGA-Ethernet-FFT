import eth_types_pkg::*;

module ethernet_handler #(
    parameter FPGA_MAC = 48'h00_1A_2B_3C_4D_5E,
    parameter FPGA_IP = 32'hC0_00_02_92,
    parameter FPGA_PORT = 16'd5005
    )(
    input logic phy_clk,                    // 50MHz LAN8720 clock
    input logic resetn,                 // Active low reset button

    input logic data_valid,             // Flag to indicate we are receiving valid data

    input logic rx0,                    // The data on the first receiving pin
    input logic rx1,                    // The data on the second receiving pin

    output logic tx_en,                 // TX enable pin, drive to low to prevent FPGA transmission

    output logic [7:0] payload,         // The payload data
    output logic payload_valid,         // Whether we are currently receiving payload data
    output logic payload_last           // Pulses on the last byte of our payload data
    );

    // Delay buffers for sync time
    logic dv_sync1;
    logic dv_sync2;
    logic rx0_sync1;
    logic rx0_sync2;
    logic rx1_sync1;
    logic rx1_sync2;

    always_ff @(posedge phy_clk or negedge resetn) begin
        if (!resetn) begin
            dv_sync1 <= 1'b0;
            dv_sync2  <= 1'b0;
            rx0_sync1 <= 1'b0;
            rx0_sync2 <= 1'b0;
            rx1_sync1 <= 1'b0;
            rx1_sync2 <= 1'b0;
        end else begin
            dv_sync1 <= data_valid;
            dv_sync2 <= dv_sync1;
            
            rx0_sync1 <= rx0;
            rx0_sync2 <= rx0_sync1;
            
            rx1_sync1 <= rx1;
            rx1_sync2 <= rx1_sync1;
        end
    end

    logic [7:0] received_byte;          // The 8-bit data made by combining both data pins' inputs
    logic byte_valid;                   // Pulses for one clock cycle on valid byte

    assign tx_en = 1'b0;

    rmii_handler byte_receiver (
        .phy_clk(phy_clk),
        .resetn(resetn),
        .data_valid(dv_sync2),
        .rx0(rx0_sync2),
        .rx1(rx1_sync2),
        .received_byte(received_byte),
        .byte_valid(byte_valid)
    );

    eth_parser #(
        .FPGA_MAC(FPGA_MAC),
        .FPGA_IP(FPGA_IP),
        .FPGA_PORT(FPGA_PORT)
    ) ethernet_parser (
        .phy_clk(phy_clk),
        .resetn(resetn),
        .data_valid(dv_sync2),
        .received_byte(received_byte),
        .byte_valid(byte_valid),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last)
    );

endmodule