/*
Handles reading from the FIFO buffer and connecting the read data to the FFT.
The onboard 50MHz clock is used for reading the FIFO buffer
*/

module fft_controller {
    input logic board_clk,              // 50MHz FPGA onboard clock
    input logic resetn,                 // Active low reset button

    input logic [15:0] fifo_q,          // The data we extract from the FIFO
    input logic [11:0] rdusedw,         // How many words (1 word = 16 bits) are currently in the FIFO
    input logic rdempty,                // Flag to indicate the FIFO is empty

    input logic sink_ready,             // Flag from the FFT telling us it is ready to read data

    output logic rdreq,                 // Requests a read operation when high

    output logic [15:0] sink_real,      // The real part of the audio we want to send to the FFT module
    output logic sink_valid,            // Requests the FFT to read our audio data
    output logic sink_sop,              // Pulses at the start of an audio packet
    output logic sink_eop               // Pulses at the end of an audio packet
    };



endmodule