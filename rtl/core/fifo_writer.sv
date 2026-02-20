/*
This module collects 2 chunks of 8-bit payload transmissions and joins them into a 16-bit chunk.
It then notifies the fifo that the fifo is ready to read these 16 bits.
*/

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

    logic [7:0] data_storage;           // Temporarily hold payload data
    logic chunk_count;                  // Counts how many 8-bit payload chunks we have received

    always_ff @ (posedge phy_clk or negedge resetn) begin
        // On startup or if the reset button is pressed
        if (!resetn) begin
            data_storage <= 16'b0;
            chunk_count <= 1'b0;
            wrreq <= 1'b0;
            fifo_data <= 16'b0;
            
        end else if (payload_valid) begin
            if (payload_last) begin
                case (chunk_count)
                    0: begin
                        data_storage <= payload;
                        chunk_count <= 1'b1;
                    end
                    1: begin
                        fifo_data <= {payload, data_storage};
                        chunk_count <= 1'b0;
                    end
                endcase
            end
            

        end else begin

        end

    end




endmodule