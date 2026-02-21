module ram_writer (
    input logic board_clk,                  // 50MHz FPGA onboard clock
    input logic resetn,                     // Active low reset button

    input logic [15:0] magnitude,           // The calculated frequency amplitude
    input logic mag_valid,                  // Pulses high when 'magnitude' is ready
    input logic mag_sop,                    // Aligned with frequency bin 0
    input logic mag_eop,                    // Aligned with frequency bin 1023

    output logic [15:0] data,               // Data to write to the ram
    output logic [9:0] wraddress,           // Memory address to write to in the RAM
    output logic wren                       // Enables writing to the RAM when high
    );

    logic [9:0] mag_counter;

    assign wr_address = mag_counter;

    always_ff @ (posedge clk or negedge resetn) begin
        if (!resetn) begin
            data <= 16'b0;
            wraddress <= 10'd0;
            wren <= 1'b0;
            mag_counter <= 10'b0;
        end else begin
            // Check if magnitude data is available
            if (mag_valid) begin
                wren <= 1'b1;
                // If this is the last magnitude we receive, restart our counter
                if (mag_eop)
                    mag_counter <= 1'b0;

                else 
                    mag_counter <= mag_counter + 10'd1;     // Increment our counter for every received magnitude
            end
        end
    end

endmodule