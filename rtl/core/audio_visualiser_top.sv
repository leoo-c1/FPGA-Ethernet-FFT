module audio_visualiser_top #(
    parameter FPGA_MAC = 48'h00_1A_2B_3C_4D_5E, // FPGA's MAC address
    parameter FPGA_IP = 32'hC0_00_02_92,        // FPGA's IP address of 192.0.2.146 (theoretical)
    parameter FPGA_PORT = 16'd5005              // FPGA's UDP port
    )(
    input logic phy_clk,                // 50MHz LAN8720 clock
    input logic board_clk,              // 50MHz FPGA onboard clock
    input logic resetn,                 // Active low reset button

    input logic data_valid,             // Flag to indicate we are receiving valid data

    input logic rx0,                    // The data on the first receiving pin
    input logic rx1,                    // The data on the second receiving pin

    output logic tx_en,                 // TX enable pin, drive to low to prevent FPGA transmission

    output h_sync,                      // Horizontal sync pulse
    output v_sync,                      // Vertical sync pulse

    output red,                         // Pixel red value (single bit, 0v or 0.7v)
    output green,                       // Pixel green value (single bit, 0v or 0.7v)
    output blue                         // Pixel blue value (single bit, 0v or 0.7v)
    );

    // u_ethernet_handler <--> u_fifo_writer
    logic [7:0] payload;                // The ethernet payload data
    logic payload_valid;                // Whether we are currently receiving payload data
    logic payload_last;                 // Pulses on the last byte of our payload data

    // u_fifo_writer <--> u_audio_fifo
    logic wr_full;                      // Indicates the fifo is currently full
    logic [15:0] fifo_data;             // The data we write to the fifo
    logic wrreq;                        // Requests a write operation to the FIFO when high

    // u_audio_fifo <--> u_fft_controller
    logic rdreq;                        // Requests a read operation from the FIFO when high
    logic [15:0] fifo_q;                // The data we extract from the FIFO
    logic [11:0] rdusedw;               // How many words (1 word = 16 bits) are currently in the FIFO

    // u_fft_controller <--> u_audio_fft
    logic sink_ready;                   // Flag from the FFT telling us it is ready to read data
    logic [15:0] sink_real;             // The real part of the audio we want to send to the FFT module
    logic sink_valid;                   // Requests the FFT to read our audio data
    logic sink_sop;                     // Pulses at the start of an audio packet
    logic sink_eop;                     // Pulses at the end of an audio packet

    ethernet_handler #(
        .FPGA_MAC(FPGA_MAC),
        .FPGA_IP(FPGA_IP),
        .FPGA_PORT(FPGA_PORT)
    ) u_ethernet_handler (
        .phy_clk(phy_clk),
        .resetn(resetn),
        .data_valid(data_valid),
        .rx0(rx0),
        .rx1(rx1),
        .tx_en(tx_en),
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
        .rdclk(board_clk),
        .rdreq(rdreq),
        .wrclk(phy_clk),
        .wrreq(wrreq),
        .q(fifo_q),
        .rdusedw(rdusedw),
        .wrfull(wr_full)
	);

    fft_controller u_fft_controller (
        .board_clk(board_clk),
        .resetn(resetn),
        .fifo_q(fifo_q),
        .rdusedw(rdusedw),
        .sink_ready(sink_ready),
        .rdreq(rdreq),
        .sink_real(sink_real),
        .sink_valid(sink_valid),
        .sink_sop(sink_sop),
        .sink_eop(sink_eop)
    );

endmodule