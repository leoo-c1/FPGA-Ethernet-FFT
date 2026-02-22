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

    always_ff @ (posedge pll_clk or negedge resetn) begin
        if (!resetn) begin
            rdaddress <= 10'b0;
            red <= 1'b0;
            green <= 1'b0;
            blue <= 1'b0;
        end else begin
            // Reading from the RAM takes one clock cycle, so read for upcoming pixel_x
            if (pixel_x < 639) begin
                // Approximate multiplication by 1.6 (approx. 205/128)
                rdaddress <= (205*(pixel_x + 1'b1)) >> 3'd7;
            end else if (pixel_x == 10'd799) begin
                // On the very last pixel, schedule a read from the first memory address
                rdaddress <= 10'b0;
            end

            if (video_on) begin
                if (pixel_y < q_amplitude) begin
                    // Colour the bar white
                    red <= 1'b1;
                    green <= 1'b1;
                    blue <= 1'b1;
                end else begin
                    // If we're above the bar, colour it black
                    red <= 1'b0;
                    green <= 1'b0;
                    blue <= 1'b0;
                end
            end else begin
                red <= 1'b0;
                green <= 1'b0;
                blue <= 1'b0;
            end

        end
    end

endmodule