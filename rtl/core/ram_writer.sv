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

    logic [8:0] displayed_bins;             // Tracks bins from 0 to 511
    logic [19:0] sum_acc;                   // 20-bit accumulator to prevent overflow

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            data <= 16'b0;
            wraddress <= 10'd0;
            wren <= 1'b0;
            displayed_bins <= 9'd0;
            sum_acc <= 20'd0;
        end else begin
            wren <= 1'b0;                   // Default to not writing

            if (amp_valid) begin
                if (amp_sop) begin
                    // On the first bin, start tracking and start the sum
                    displayed_bins <= 9'd1;
                    sum_acc <= amplitude;
                    wraddress <= 10'd0;
                    
                end else if (displayed_bins != 9'd0) begin 
                    if (displayed_bins == 9'd511) begin
                        displayed_bins <= 9'd0;         // Reached the center, stop tracking
                    end else begin
                        displayed_bins <= displayed_bins + 9'd1;
                    end

                    // Check if this is the last bin of our 16-bin chunk
                    if (displayed_bins[3:0] == 4'd15) begin
                        // Add final amplitude and divide by 16
                        data <= (sum_acc + amplitude) >> 4;
                        wren <= 1'b1;
                    end else if (displayed_bins[3:0] == 4'd0) begin
                        // If it's the start of a new chunk, start a new sum
                        sum_acc <= amplitude;
                    end else begin
                        sum_acc <= sum_acc + amplitude;
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