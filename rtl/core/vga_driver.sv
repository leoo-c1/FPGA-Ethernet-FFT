module vga_driver (
    input logic pll_clk,                // 25.175MHz PLL clock
    input logic resetn,                 // Active low reset button

    input logic [9:0] pixel_x,          // Horizontal pixel coordinate (from 0)
    input logic [9:0] pixel_y,          // Vertical pixel coordinate (from 0)
    input logic video_on,               // Whether or not we are in the active video region

    input logic [15:0] q_amplitude,     // The stored amplitude value in ram      

    output logic [9:0] rdaddress,       // The address in RAM that we want to read from

    output logic red,                   // Pixel red value (single bit, 0v or 0.7v)
    output logic green,                 // Pixel green value (single bit, 0v or 0.7v)
    output logic blue                   // Pixel blue value (single bit, 0v or 0.7v)
    );

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin

        end
    end

endmodule