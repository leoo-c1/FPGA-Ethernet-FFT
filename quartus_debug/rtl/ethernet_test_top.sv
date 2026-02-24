module ethernet_test_top #(
    parameter FPGA_MAC = 48'h00_1A_2B_3C_4D_5E,
    parameter FPGA_IP = 32'hC0_00_02_92,
    parameter FPGA_PORT = 16'd5005
    )(
    input logic phy_clk,       // 50MHz LAN8720 clock
    input logic board_clk,     // 50MHz FPGA clock
    input logic resetn,        // Reset button

    // Ethernet pins
    input logic data_valid,
    input logic rx0,
    input logic rx1,
    output logic tx_en,

    // VGA pins
    output h_sync,
    output v_sync,
    output red,
    output green,
    output blue
    );

    // Ethernet signals
    logic [7:0] payload;
    logic payload_valid;
    logic payload_last;
    logic byte_valid;

    // Counts how many packets we have successfully received
    logic [9:0] packet_count;

    always_ff @(posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            packet_count <= 10'd0;
        end else begin
            // Increment every time a packet finishes
            if (payload_last) begin
                if (packet_count < 640) 
                    packet_count <= packet_count + 1'b1;
                else
                    packet_count <= 10'd0; // Reset after filling screen
            end
        end
    end

    ethernet_handler #(
        .FPGA_MAC(FPGA_MAC),
        .FPGA_IP(FPGA_IP),
        .FPGA_PORT(FPGA_PORT)
    ) u_test_handler (
        .phy_clk(phy_clk),
        .board_clk(board_clk),
        .resetn(resetn),
        .data_valid(data_valid),
        .rx0(rx0),
        .rx1(rx1),
        .tx_en(tx_en),
        .payload(payload),
        .payload_valid(payload_valid),
        .payload_last(payload_last),
        .byte_valid(byte_valid)
    );

    // 25MHz pixel clock
    logic vga_clk_reg;
    always_ff @(posedge board_clk) begin
        vga_clk_reg <= ~vga_clk_reg;
    end

    logic vga_clk;
    assign vga_clk = vga_clk_reg;

    // VGA driver
    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic video_on;

    vga_sync u_vga_sync (
        .board_clk(board_clk),
        .resetn(resetn),
        .pll_clk(vga_clk), 
        .h_sync(h_sync),
        .v_sync(v_sync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on)
    );

    // White bar that grows to the right
    assign red   = (video_on && (pixel_x < packet_count));
    assign green = (video_on && (pixel_x < packet_count));
    assign blue  = (video_on && (pixel_x < packet_count));

endmodule