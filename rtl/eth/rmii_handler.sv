module rmii_handler (
    input logic clk,                    // 50MHz LAN8720 clock
    input logic resetn,                 // Reset button (active low)

    input logic data_valid,             // Flag to indicate we are receiving valid data

    input logic rx0,                    // The data on the first receiving pin
    input logic rx1,                    // The data on the second receiving pin

    output logic [7:0] received_byte,   // The 8-bit data made by combining both data pins' inputs
    output logic byte_valid             // Pulses for one clock cycle on valid byte
    );

    parameter max_bit_count = 8;        // We want to count a total of 8 bits
    logic [3:0] bit_counter = 0;        // Counts how many bits we have received

    logic [7:0] bit_storage;            // Holds onto each received bit until full byte is received

    always_ff @ (posedge clk or negedge resetn) begin
        if (!resetn) begin              // On reset/startup, reset our collected byte
            received_byte <= 8'b0;
            byte_valid <= 1'b0;
            bit_counter <= 4'b0;
            bit_storage <= 8'b0;
        end else begin
            if (data_valid) begin       // If we are receiving valid data
                if (bit_counter < max_bit_count - 2) begin
                    bit_storage[bit_counter +: 2] <= {rx1, rx0};
                    bit_counter <= bit_counter + 2'd2;
                    byte_valid <= 1'b0;
                end else begin
                    received_byte <= {rx1, rx0, bit_storage[5:0]};
                    byte_valid <= 1'b1;
                    bit_counter <= 0;
                end

            end else begin              // If we aren't receiving valid data
                bit_counter <= 0;
                byte_valid <= 1'b0;
            end
        end
    end

endmodule