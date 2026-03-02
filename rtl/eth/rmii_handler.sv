module rmii_handler (
    input logic clk,                    // 50MHz LAN8720 clock
    input logic resetn,                 // Reset button (active low)

    input logic data_valid,             // Flag to indicate we are receiving valid data

    input logic rx0,                    // The data on the first receiving pin
    input logic rx1,                    // The data on the second receiving pin

    output logic [7:0] received_byte,   // The 8-bit data made by combining both data pins' inputs
    output logic byte_valid             // Pulses for one clock cycle on valid byte
    );

    logic [7:0] rx_shift;               // Continuous sliding window
    logic [1:0] dibit_counter;          // Counts 0 to 3 (4 dibits = 1 byte)
    logic locked;                       // Flags when we have found the byte boundary

    always_ff @ (posedge clk or negedge resetn) begin
        if (!resetn) begin
            received_byte <= 8'b0;
            byte_valid <= 1'b0;
            rx_shift <= 8'b0;
            dibit_counter <= 2'b0;
            locked <= 1'b0;
        end else begin
            if (data_valid) begin
                // Continuously shift the new dibit in (RMII sends LSB first, so shift right)
                rx_shift <= {rx1, rx0, rx_shift[7:2]};

                if (!locked) begin
                    byte_valid <= 1'b0;
                    
                    // Look for the exact SFD alignment (0xD5)
                    if ({rx1, rx0, rx_shift[7:2]} == 8'hD5) begin
                        locked <= 1'b1;           // Boundary locked!
                        received_byte <= 8'hD5;   // Output the SFD
                        byte_valid <= 1'b1;       // Tell parser we have a valid byte
                        dibit_counter <= 2'b0;    // Reset the 4-clock counter
                    end
                end else begin
                    // We are locked. Safely count 4 clock cycles per byte.
                    dibit_counter <= dibit_counter + 2'd1;
                    if (dibit_counter == 2'd3) begin
                        received_byte <= {rx1, rx0, rx_shift[7:2]};
                        byte_valid <= 1'b1;
                    end else begin
                        byte_valid <= 1'b0;
                    end
                end
            end else begin
                // The physical packet ended. Drop the lock and reset.
                locked <= 1'b0;
                byte_valid <= 1'b0;
                dibit_counter <= 2'b0;
            end
        end
    end

endmodule