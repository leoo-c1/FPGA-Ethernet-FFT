module ram_writer (
    input logic board_clk,                  // 50MHz FPGA onboard clock
    input logic resetn,                     // Active low reset button

    input logic [15:0] amplitude,           // The calculated frequency amplitude
    input logic amp_valid,                  // Pulses high when 'amplitude' is ready
    input logic amp_sop,                    // Aligned with frequency bin 0
    input logic amp_eop,                    // Aligned with frequency bin 1023

    output logic [15:0] data,               // Data to write to the ram
    output logic [9:0] wraddress,           // Memory address to write to in the RAM
    output logic wren                       // Enables writing to the RAM when high
    );

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            data <= 16'b0;
            wraddress <= 10'd0;
            wren <= 1'b0;
        end else begin
            // Default to write enable being low
            wren <= 1'b0;
            // Check if amplitude data is available
            if (amp_valid) begin
                wren <= 1'b1;
                data <= amplitude;
                // If this is the first amplitude we receive, go back to the first address in RAM
                if (amp_sop)
                    wraddress <= 10'b0;

                else 
                    wraddress <= wraddress + 10'd1;     // Increment our write address for every received amplitude
            end
        end
    end

endmodule