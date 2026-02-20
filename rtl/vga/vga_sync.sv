module vga_sync (
    input wire clk,         // 50MHz clock
    input wire rst,         // Reset button

    output wire clk_0,      // 25.175MHz divided clock

    output reg h_sync,      // Horizontal sync signal
    output reg v_sync,      // Vertical sync signal

    output reg [9:0] pixel_x,   // Horizontal pixel coordinate (from 0)
    output reg [9:0] pixel_y,   // Vertical pixel coordinate (from 0)

    output reg video_on     // Whether or not we are in the active video region
    );

    wire pll_locked;

    sys_pll pll_inst (
        .inclk0(clk),       // 50MHz input clock
        .rst(rst),          // Reset button
        .c0(clk_0),         // 25.175MHz output clock
        .locked(pll_locked)
    );

    // Horizontal timing values (in pixels):
    parameter h_video = 640;        // Active video
    parameter h_frontp = 24;        // Front porch
    parameter h_pulsewidth = 96;    // Sync pulse
    parameter h_backp = 40;         // Back porch

    // Vertical timing values (in lines):
    parameter v_video = 480;        // Active video
    parameter v_frontp = 7;        // Front porch
    parameter v_pulsewidth = 2;     // Sync pulse
    parameter v_backp = 35;         // Back porch

    reg [9:0] h_count = 0;          // Tracks horizontal pixel position
    reg [9:0] v_count = 0;          // Counts the number of hsync signals

    always @ (posedge clk_0) begin
        pixel_x <= h_count;         // Update horizontal pixel coordinates
        pixel_y <= v_count;         // Update vertical pixel coordinates
        video_on <= (h_count < h_video) && (v_count < v_video);

        if (!rst) begin             // If the reset button is pressed, reset all signals
            h_count <= 0;
            v_count <= 0;
            h_sync <= 1'b1;
            v_sync <= 1'b1;
        
        // If we haven't reached the front porch yet
        end else if (h_count < h_video) begin
            h_sync <= 1'b1;                         // Keep hsync inactive
            h_count <= h_count + 1;                 // Keep incrementing horizontal pixels
        
        // If we reach the front porch and haven't left yet
        end else if (h_count < h_video + h_frontp) begin
            h_sync <= 1'b1;                         // Keep hsync inactive
            h_count <= h_count + 1;                 // Keep incrementing horizontal pixels

        // If we reach the sync pulse region and haven't left yet
        end else if (h_count < h_video + h_frontp + h_pulsewidth) begin
                h_sync <= 1'b0;                     // Keep hsync active
                h_count <= h_count + 1;             // Keep incrementing horizontal pixels

        // If we reach the back porch region and haven't left yet
        end else if (h_count < h_video + h_frontp + h_pulsewidth + h_backp - 1) begin
            h_sync <= 1'b1;                         // Keep hsync inactive
            h_count <= h_count + 1;                 // Keep incrementing horizontal pixels

        end else begin                              // If we reach the end of the sync pulse
            h_sync <= 1'b1;                         // Keep hsync inactive
            h_count <= 0;                           // Reset horizontal count
            
            if (v_count < v_video + v_frontp) begin     // If we haven't reached the sync pulse yet
                v_sync <= 1'b1;                         // Keep vsync inactive
                v_count <= v_count + 1;                 // Keep incrementing horizontal pixels

            // If we reach the sync pulse region and haven't left yet
            end else if (v_count < v_video + v_frontp + v_pulsewidth) begin
                    v_sync <= 1'b0;                     // Keep vsync active
                    v_count <= v_count + 1;             // Keep incrementing vertical lines

            // If we reach the back porch region and haven't left yet
            end else if (v_count < v_video + v_frontp + v_pulsewidth + v_backp - 1) begin
                v_sync <= 1'b1;                         // Keep vsync inactive
                v_count <= v_count + 1;

            end else begin                              // If we reach the end of the sync pulse
                v_sync <= 1'b1;                         // Keep vsync inactive
                v_count <= 0;                           // Reset vertical count
            end
        end

    end

endmodule