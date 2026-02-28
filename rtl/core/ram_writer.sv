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

    // Lookup table for highest FFT bin included in that bar
    logic [8:0] log_boundaries [0:31] = '{
        9'd1,   9'd2,   9'd3,   9'd4,   9'd5,   9'd6,   9'd8,   9'd10,
        9'd12,  9'd15,  9'd18,  9'd22,  9'd27,  9'd32,  9'd38,  9'd45,
        9'd53,  9'd63,  9'd75,  9'd89,  9'd106, 9'd126, 9'd150, 9'd178,
        9'd211, 9'd251, 9'd298, 9'd354, 9'd421, 9'd500, 9'd510, 9'd511
    };

    logic [8:0] displayed_bins;             // Tracks bins from 0 to 511
    logic [4:0] current_bar;                // Tracks which of the 32 bars we are currently filling
    logic [15:0] max_amp;                   // Stores the highest amplitude found in the current band

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            data <= 16'b0;
            wraddress <= 10'd0;
            wren <= 1'b0;
            displayed_bins <= 9'd0;
            current_bar <= 5'd0;
            max_amp <= 16'd0;
        end else begin
            wren <= 1'b0;                   // Default to not writing

            if (amp_valid) begin
                if (amp_sop) begin
                    // On the first bin, reset trackers and set the first max_amp
                    displayed_bins <= 9'd0;
                    current_bar <= 5'd0;
                    max_amp <= amplitude;
                    wraddress <= 10'd0;
                    
                end else if (displayed_bins < 9'd511) begin 
                    // Increment the bin counter
                    displayed_bins <= displayed_bins + 9'd1;

                    // Check if we just hit the boundary for the current bar
                    if ((displayed_bins + 9'd1) == log_boundaries[current_bar]) begin
                        // Compare the final bin of the boundary against the max
                        if (amplitude > max_amp) begin
                            data <= amplitude;
                        end else begin
                            data <= max_amp;
                        end
                        
                        wren <= 1'b1;                       // Write to the RAM
                        current_bar <= current_bar + 5'd1;  // Move to the next bar
                        max_amp <= 16'd0;                   // Reset max_amp for the next bar
                        
                    end else begin
                        // While still inside the current bar's frequency range, keep the highest peak
                        if (amplitude > max_amp) begin
                            max_amp <= amplitude;
                        end
                    end
                end
            end

            // Increment the ram address after we trigger a write
            if (wren) begin
                wraddress <= wraddress + 10'd1;
            end
        end
    end

endmodule