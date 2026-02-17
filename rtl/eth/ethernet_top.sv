import eth_types_pkg::*;

module ethernet_top (
    input logic clk,                    // 50MHz LAN8720 clock
    input logic resetn,                 // Active low reset button

    input logic data_valid,             // Flag to indicate we are receiving valid data

    input logic rx0,                    // The data on the first receiving pin
    input logic rx1,                    // The data on the second receiving pin

    output logic tx_en,                  // TX enable pin, drive to low to prevent FPGA transmission

    output logic [7:0] payload,         // The payload data
    output logic payload_valid,         // Whether we are currently receiving payload data
    output logic payload_last           // Pulses on the last byte of our payload data
    );

    logic [7:0] received_byte;          // The 8-bit data made by combining both data pins' inputs
    logic byte_valid;                   // Pulses for one clock cycle on valid byte

    assign tx_en = 1'b0;

    rmii_handler byte_receiver (
        .clk(clk),
        .resetn(resetn),
        .data_valid(data_valid),
        .rx0(rx0),
        .rx1(rx1),
        .received_byte(received_byte),
        .byte_valid(byte_valid)
    );

    eth_parser #(
        .FPGA_MAC(48'h00_1A_2B_3C_4D_5E),
        .FPGA_IP(32'hC0_00_02_92),
        .FPGA_PORT(16'd5005)
    ) ethernet_parser (
        .clk(clk),
        .resetn(resetn),
        .received_byte(received_byte),
        .byte_valid(byte_valid),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last)
    );

endmodule