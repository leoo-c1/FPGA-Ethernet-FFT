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
    logic byte_valid;                   // Pulses for one clock cycle on valid byte

    // u_fifo_writer <--> u_audio_fifo
    logic wr_full;                      // Indicates the fifo is currently full
    logic [15:0] fifo_data;             // The data we write to the fifo
    logic wrreq;                        // Requests a write operation to the FIFO when high

    // u_audio_fifo <--> u_fft_controller
    logic rdreq;                        // Requests a read operation from the FIFO when high
    logic [15:0] fifo_q;                // The data we extract from the FIFO
    logic [11:0] rdusedw;               // How many words (1 word = 16 bits) are currently in the FIFO

    // u_fft_controller <--> u_audio_fft
    logic sink_valid;                   // Requests the FFT to read our audio data
    logic sink_ready;                   // Flag from the FFT telling us it is ready to read data
    logic sink_sop;                     // Pulses at the start of an audio packet
    logic sink_eop;                     // Pulses at the end of an audio packet
    logic [15:0] sink_real;             // The real part of the audio we want to send to the FFT module

    // u_audio_fft <--> u_amplitude_calc
    logic source_valid;                 // Flag to indicate the FFT has sent valid output
    logic source_sop;                   // Start of packet (frequency bin 0)
    logic source_eop;                   // End of packet (frequency bin 1023)
    logic signed [15:0] source_real;    // The real part of the frequency amplitude
    logic signed [15:0] source_imag;    // The imaginary part of the frequency amplitude
    logic [5:0] source_exp;             // The exponent of the block-floating-point representation of source

    // u_amplitude_calc <--> u_ram_writer
    logic [15:0] amplitude;             // Frequency amplitude (after exponent and logarithmic scaling)
    logic amp_valid;                    // Pulses high when 'amplitude' is ready
    logic amp_sop;                      // Aligned with frequency bin 0
    logic amp_eop;                      // Aligned with frequency bin 1023

    // u_ram_writer <--> u_amplitude_ram
    logic [15:0] data;                  // Data to write to the ram
    logic [9:0] wraddress;              // Memory address to write to in the RAM
    logic wren;                         // Enables writing to the RAM when high

    // u_amplitude_ram <--> u_vga_driver
    logic [15:0] q_amplitude;           // The stored amplitude value in ram      
    logic [9:0] rdaddress;              // The address in RAM that we want to read from

    // u_vga_sync <--> u_vga_driver
    logic pll_clk;                      // 25.175MHz PLL clock
    logic [9:0] pixel_x;                // Horizontal pixel coordinate (from 0)
    logic [9:0] pixel_y;                // Vertical pixel coordinate (from 0)
    logic video_on;                     // Whether or not we are in the active video region

    ethernet_handler #(
        .FPGA_MAC(FPGA_MAC),
        .FPGA_IP(FPGA_IP),
        .FPGA_PORT(FPGA_PORT)
    ) u_ethernet_handler (
        .phy_clk(phy_clk),
        .board_clk(board_clk),
        .resetn(resetn),
        .data_valid(data_valid),
        .rx0(rx0),
        .rx1(rx1),
        .tx_en(tx_en),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last),
        .byte_valid(byte_valid)
    );

    fifo_writer u_fifo_writer (
        .board_clk(board_clk),
        .resetn(resetn),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last),
        .byte_valid(byte_valid),
        .wr_full(wr_full),
        .wrreq(wrreq),
        .fifo_data(fifo_data)
    );

    audio_fifo u_audio_fifo (
        .data(fifo_data),
        .rdclk(board_clk),
        .rdreq(rdreq),
        .wrclk(board_clk),
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

    audio_fft u_audio_fft (
		.clk(board_clk),
		.reset_n(resetn),
		.sink_valid(sink_valid),
		.sink_ready(sink_ready),
		.sink_error(2'b0),
		.sink_sop(sink_sop),
		.sink_eop(sink_eop),
		.sink_real(sink_real),
		.sink_imag(16'b0),
		.inverse(1'b0),
		.source_valid(source_valid),
		.source_ready(1'b1),
		.source_sop(source_sop),
		.source_eop(source_eop),
		.source_real(source_real),
		.source_imag(source_imag),
		.source_exp(source_exp)
	);

    amplitude_calc u_amplitude_calc (
        .board_clk(board_clk),
        .resetn(resetn),
        .source_real(source_real),
        .source_imag(source_imag),
        .source_valid(source_valid),
        .source_sop(source_sop),
        .source_eop(source_eop),
        .source_exp(source_exp),
        .amplitude(amplitude),
        .amp_valid(amp_valid),
        .amp_sop(amp_sop),
        .amp_eop(amp_eop)
    );

    ram_writer u_ram_writer (
        .board_clk(board_clk),
        .resetn(resetn),
        .amplitude(amplitude),
        .amp_valid(amp_valid),
        .amp_sop(amp_sop),
        .amp_eop(amp_eop),
        .data(data),
        .wraddress(wraddress),
        .wren(wren)
    );

    amplitude_ram u_amplitude_ram (
        .data(data),
        .rdaddress(rdaddress),
        .rdclock(pll_clk),
        .wraddress(wraddress),
        .wrclock(board_clk),
        .wren(wren),
        .q(q_amplitude)
    );

    vga_driver u_vga_driver (
        .pll_clk(pll_clk),
        .resetn(resetn),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on),
        .q_amplitude(q_amplitude),
        .rdaddress(rdaddress),
        .red(red),
        .green(green),
        .blue(blue)
    );

    vga_sync u_vga_sync (
        .board_clk(board_clk),
        .resetn(resetn),
        .pll_clk(pll_clk),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

endmodule