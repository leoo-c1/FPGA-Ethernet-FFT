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

    logic [9:0] word_counter = 0;       // Counts how many words we have sent to the FFT module

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            rdreq <= 1'b0;
            sink_real <= 16'b0;
            sink_valid <= 1'b0;
            sink_sop <= 1'b0;
            sink_eop <= 1'b0;
            word_counter <= 1'b0;

        // If the fifo isn't empty
        end else (!rdempty) begin
            // Default to having sink pulses as low
            sink_sop <= 1'b0;
            sink_eop <= 1'b0;

            // Check if we have enough words (1024) to send to the FFT
            if (rdusedw >= 12'd1024) begin
                rdreq <= 1'b1;          // Request a read operation

                // If the FFT is ready to read our data
                if (sink_ready) begin
                    sink_valid <= 1'b1;     // Indicate sink is valid
                    sink_real <= fifo_q;    // Send fifo output to FFT
                end

                // Indicate start of packet if this is the first word we are sending
                if (word_counter == 10'b0;)
                    sink_sop <= 1'b1;

                // Indicate end of packet if this is the last word we are sending  
                else if (word_counter == 10'd1023)
                    sink_eop <= 1'b1;

                if (word_counter < 1023)
                    word_counter <= word_counter + 10'd1;
                else
                    word_counter <= 10'b0;
            end


        // If the fifo is empty
        end else begin
            // Don't read from it
            rdreq <= 1'b0;
        end
    end


endmodule