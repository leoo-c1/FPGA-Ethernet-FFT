/*
Handles reading from the FIFO buffer and connecting the read data to the FFT.
The onboard 50MHz clock is used for reading the FIFO buffer.
Ignores corrupt frames as indicated by the ethernet parser.
*/

module fft_controller (
    input logic board_clk,              // 50MHz FPGA onboard clock
    input logic resetn,                 // Active low reset button

    input logic [15:0] fifo_q,          // The data we extract from the FIFO
    input logic [11:0] rdusedw,         // How many words (1 word = 16 bits) are currently in the FIFO

    input logic sink_ready,             // Flag from the FFT telling us it is ready to read data
    input logic payload_flush,          // NEW: Flag from ethernet parser indicating sequence error

    output logic rdreq,                 // Requests a read operation when high

    output logic [15:0] sink_real,      // The real part of the audio we want to send to the FFT module
    output logic sink_valid,            // Requests the FFT to read our audio data
    output logic sink_sop,              // Pulses at the start of an audio packet
    output logic sink_eop               // Pulses at the end of an audio packet
    );

    typedef enum logic [1:0] {
        IDLE,                           // Not reading anything in this state
        READING,                        // In this state, we are in the process of reading 1024 bytes
        WAIT_SYNC                       // In this state we are using a delay to let the FIFO catch up
    } read_state;

    read_state state;

    logic [9:0] word_counter = 0;       // Counts how many words we have sent to the FFT module
    logic [3:0] wait_counter = 0;       // Counts how many clock cycles we have been waiting for the FIFO to catch up
    
    logic corrupt_frame_latch;          // Goes high when a sequence error occurs

    assign sink_real = fifo_q;
    
    // If the frame is corrupt, fft signals stay 0
    assign sink_valid = (state == READING) && !corrupt_frame_latch;
    assign sink_sop = (state == READING) && (word_counter == 10'd0) && !corrupt_frame_latch;
    assign sink_eop = (state == READING) && (word_counter == 10'd1023) && !corrupt_frame_latch;
    
    // Read from FIFO only if we are sending valid data and the FFT is ready to take it.
    assign rdreq = (state == READING) && sink_ready;
    
    // Handle the corrupt frame latch
    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            corrupt_frame_latch <= 1'b0;
        end else begin
            if (payload_flush) begin
                // Sequence error occurred, latch the error high
                corrupt_frame_latch <= 1'b1;
            end else if (state == READING && word_counter == 10'd1023 && sink_ready) begin
                // Clear the latch to get ready for the next frame
                corrupt_frame_latch <= 1'b0;
            end
        end
    end

    // State machine and FIFO read request
    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            word_counter <= 10'b0;
            wait_counter <= 4'd0;

        end else begin
            if (state == IDLE) begin
                word_counter <= 10'd0;

                // If the FIFO contains 1024 words, start reading
                if (rdusedw >= 12'd1024)
                    state <= READING;

            end else if (state == READING) begin
                // Only advance the FIFO if the FFT accepts the word
                if (sink_ready) begin
                    if (word_counter < 10'd1023) begin
                        word_counter <= word_counter + 10'd1;
                    end else begin
                        // Packet finished, go to wait state
                        state <= WAIT_SYNC;
                        wait_counter <= 4'd0;
                        word_counter <= 10'd0;
                    end
                end
            
            // Wait 10 clock cycles for the FIFO to catch up
            end else if (state == WAIT_SYNC) begin
                if (wait_counter < 4'd10)
                    wait_counter <= wait_counter + 4'd1;
                else
                    state <= IDLE;

            end else
                state <= IDLE;

        end
    end

endmodule