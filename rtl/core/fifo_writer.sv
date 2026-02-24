/*
This module collects 2 chunks of 8-bit payload transmissions and joins them into a 16-bit chunk.
It then notifies the fifo that the fifo is ready to read these 16 bits.
*/

module fifo_writer (
    input logic board_clk,              // 50MHz FPGA onboard clock
    input logic resetn,                 // Active low reset button

    input logic [7:0] payload,          // The payload data
    input logic payload_valid,          // Whether we are currently receiving payload data
    input logic payload_last,           // Pulses on the last byte of our payload data

    input logic wr_full,                // Indicates the fifo is currently full

    output logic wrreq,                 // Requests a write operation when high
    output logic [15:0] fifo_data       // The data we write to the fifo
    );

    logic [7:0] data_storage;           // Temporarily hold payload data
    logic chunk_count;                  // Counts how many 8-bit payload chunks we have received

    always_ff @ (posedge phy_clk or negedge resetn) begin
        // On startup or if the reset button is pressed
        if (!resetn) begin
            data_storage <= 8'b0;
            chunk_count <= 1'b0;
            wrreq <= 1'b0;
            fifo_data <= 16'b0;

        end else begin
            // If we are receiving payload data
            if (payload_valid) begin
                wrreq <= 1'b0;

                // Check if this is the first 8 bits of the 16-bit group
                if (chunk_count == 1'b0) begin
                    data_storage <= payload;    // Store the data
                    chunk_count <= 1'b1;
                // If this is the second chunk we have come across
                end else begin
                    fifo_data <= {data_storage, payload};   // Combine the stored data with the data we received
                    chunk_count <= 1'b0;
                    // Check if the fifo isn't full
                    if (!wr_full)
                        wrreq <= 1'b1;
                    // If it is full, don't write to it
                    else
                        wrreq <= 1'b0;
                end

            // If we aren't receiving payload data
            end else
                wrreq <= 1'b0;

            // On the last 8-bit payload chunk, reset the chunk counter
            if (payload_last)
                chunk_count <= 1'b0;
        end
    end

endmodule