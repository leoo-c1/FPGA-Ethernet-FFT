module vga_driver (
    input clk,              // 50MHz clock
    input rst,              // Reset button

    output h_sync,          // Horizontal sync pulse
    output v_sync,          // Vertical sync pulse

    output red,             // Pixel red value (single bit, 0v or 0.7v)
    output green,           // Pixel green value (single bit, 0v or 0.7v)
    output blue             // Pixel blue value (single bit, 0v or 0.7v)
    );

    wire clk_0;             // Intermediate wire to connect 25.175MHz clock between modules

    wire [9:0] pixel_x;     // Horizontal pixel coordinate (from 0)
    wire [9:0] pixel_y;     // Vertical pixel coordinate (from 0)

    wire video_on;          // Whether or not we are in the active video region

    vga_sync vga_sync_logic (
        .clk(clk),
        .rst(rst),
        .clk_0(clk_0),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

    bouncing_ball_2d scene (
        .clk_0(clk_0),
        .rst(rst),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on),
        .red(red),
        .green(green),
        .blue(blue)
    );

endmodule