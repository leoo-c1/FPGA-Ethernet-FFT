module fifo_writer (
    input logic phy_clk,                // 50MHz LAN8720 clock
    input logic resetn,                 // Active low reset button

    input logic [7:0] payload,          // The payload data
    input logic payload_valid,          // Whether we are currently receiving payload data
    input logic payload_last,           // Pulses on the last byte of our payload data

    input logic wr_full,                // Indicates the fifo is currently full

    output logic wrreq,                 // Requests a write operation when high
    output logic [15:0] fifo_data,      // The data we write to the fifo

    );



endmodule