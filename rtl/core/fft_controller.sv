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

    typedef enum logic {
        IDLE,                           // Not reading anything in this state
        READING                         // In this state, we are in the process of reading 1024 bytes
    } read_state;

    logic [9:0] word_counter = 0;       // Counts how many words we have sent to the FFT module
    logic read_active;                  // Flag for when we are actively reading data

    // State machine and FIFO read request
    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            rdreq <= 1'b0;
            word_counter <= 1'b0;
            read_active  <= 1'b0;

        end else begin
            // Default to not requesting data
            rdreq <= 1'b0;
            read_active  <= 1'b0;

            if (state == IDLE) begin
                word_counter <= 10'd0;

                // If the FIFO contains 1024 words, start reading
                if (rdusedw >= 12'd1024)
                    state <= READING;


            end else if (state == READING) begin
                // Only read if the FFT is ready to accept data
                if (sink_ready) begin
                    rdreq <= 1'b1;
                    read_active <= 1'b1;

                    if (word_counter < 10'd1023)
                        word_counter <= word_counter + 10'd1;
                    else
                        state <= IDLE;
                end
            end

        end
    end

    // FFT sending
    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            sink_valid <= 1'b0;
            sink_sop <= 1'b0;
            sink_eop <= 1'b0;
            sink_real <= 16'd0;

        end else begin
            sink_real <= fifo_q;
            sink_valid <= read_active;

            if (read_active && (word_counter == 10'd0))
                sink_sop <= 1'b1;
            
            if (read_active && (word_counter == 10'd1023))
                sink_eop <= 1'b1;
        end
    end

endmodule