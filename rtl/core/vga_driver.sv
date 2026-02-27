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

    logic [9:0] scaled_amplitude;
    
    // If amplitude exceeds 479 (the screen height), hold it at 479
    assign scaled_amplitude = (q_amplitude > 16'd479) ? 10'd479 : q_amplitude[9:0];

    // Delay registers for pixel_x value
    logic [9:0] pixel_x_delay_1;
    logic [9:0] pixel_x_delay_2;
    logic [9:0] pixel_x_delay_3;

    // Delay registers for pixel_y value
    logic [9:0] pixel_y_delay_1;
    logic [9:0] pixel_y_delay_2;
    logic [9:0] pixel_y_delay_3;

    // Delay registers for video_on signal
    logic vid_delay_1;
    logic vid_delay_2;
    logic vid_delay_3;

    always_ff @ (posedge pll_clk or negedge resetn) begin
        if (!resetn) begin
            rdaddress <= 10'b0;
            pixel_x_delay_1 <= 10'b0;
            pixel_x_delay_2 <= 10'b0;
            pixel_x_delay_3 <= 10'b0;
            pixel_y_delay_1 <= 10'b0;
            pixel_y_delay_2 <= 10'b0;
            pixel_y_delay_3 <= 10'b0;
            vid_delay_1 <= 1'b0;
            vid_delay_2 <= 1'b0;
            vid_delay_3 <= 1'b0;
            red <= 1'b0;
            green <= 1'b0;
            blue <= 1'b0;
        end else begin
            // Shift register (3 clock cycles) for pixel_x value
            pixel_x_delay_1 <= pixel_x;
            pixel_x_delay_2 <= pixel_x_delay_1;
            pixel_x_delay_3 <= pixel_x_delay_2;

            // Shift register (3 clock cycles) for pixel_y value
            pixel_y_delay_1 <= pixel_y;
            pixel_y_delay_2 <= pixel_y_delay_1;
            pixel_y_delay_3 <= pixel_y_delay_2;

            // Shift register (3 clock cycles) for video_on signal
            vid_delay_1 <= video_on;
            vid_delay_2 <= vid_delay_1;
            vid_delay_3 <= vid_delay_2;

            if (pixel_x >= 10'd64 && pixel_x < 10'd576) begin
                // Divide by 16 to stretch each RAM address across 16 pixels
                rdaddress <= (pixel_x - 10'd64) >> 4;
            end else begin
                rdaddress <= 10'b0;
            end

            if (vid_delay_3) begin
                // Check if we are inside the active 512-pixel EQ window
                if (pixel_x_delay_3 >= 10'd64 && pixel_x_delay_3 < 10'd576) begin
                    // Create a 2-pixel gap between bars (draw if remainder < 14)
                    if (((pixel_x_delay_3 - 10'd64) & 10'd15) < 10'd14) begin
                        // Measure from the bottom of the screen, use delayed pixel_y coordinate
                        if (10'd479 - pixel_y_delay_3 < scaled_amplitude) begin
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
                        // Gap between bars
                        red <= 1'b0;
                        green <= 1'b0;
                        blue <= 1'b0;
                    end
                end else begin
                    // Margins outside the EQ window
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