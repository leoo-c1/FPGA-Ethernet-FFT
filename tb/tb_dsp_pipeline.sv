`timescale 1ns/100ps

module tb_dsp_pipeline;

    logic clk;
    logic resetn;

    // FFT inputs
    logic sink_valid;
    logic sink_sop;
    logic sink_eop;
    logic [15:0] sink_real;
    logic sink_ready;

    // FFT -> amplitude_calc
    logic source_valid;
    logic source_sop;
    logic source_eop;
    logic signed [15:0] source_real;
    logic signed [15:0] source_imag;
    logic [5:0] source_exp;

    // amplitude_calc -> RAM writer
    logic [15:0] amplitude;
    logic amp_valid;
    logic amp_sop;
    logic amp_eop;

    // RAM writer outputs
    logic [15:0] data;
    logic [9:0] wraddress;
    logic wren;

    audio_fft u_audio_fft (
        .clk(clk),
        .reset_n(resetn),
        .sink_valid(sink_valid),
        .sink_ready(sink_ready),
        .sink_error(2'b0),
        .sink_sop(sink_sop),
        .sink_eop(sink_eop),
        .sink_real(sink_real),
        .sink_imag(16'b0),
        .inverse(1'b0),
        .source_valid(source_valid),
        .source_ready(1'b1),
        .source_sop(source_sop),
        .source_eop(source_eop),
        .source_real(source_real),
        .source_imag(source_imag),
        .source_exp(source_exp)
    );

    amplitude_calc u_amplitude_calc (
        .board_clk(clk),
        .resetn(resetn),
        .source_real(source_real),
        .source_imag(source_imag),
        .source_valid(source_valid),
        .source_sop(source_sop),
        .source_eop(source_eop),
        .source_exp(source_exp),
        .amplitude(amplitude),
        .amp_valid(amp_valid),
        .amp_sop(amp_sop),
        .amp_eop(amp_eop)
    );

    ram_writer u_ram_writer (
        .board_clk(clk),
        .resetn(resetn),
        .amplitude(amplitude),
        .amp_valid(amp_valid),
        .amp_sop(amp_sop),
        .amp_eop(amp_eop),
        .data(data),
        .wraddress(wraddress),
        .wren(wren)
    );

    // 50MHz Clock
    always #10 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        resetn = 0;
        sink_valid = 0;
        sink_sop = 0;
        sink_eop = 0;
        sink_real = 0;

        #200 resetn = 1;
        #200;

        // Wait for FFT to initialise
        wait(sink_ready == 1'b1);
        #20;

        // Send frame 1
        for (i = 0; i < 1024; ) begin
            @ (posedge clk);
            if (sink_ready) begin
                sink_valid = 1'b1;
                sink_real  = i[15:0];
                sink_sop   = (i == 0);
                sink_eop   = (i == 1023);
                i++;
            end else begin
                // If sink_ready goes low, hold the state
                sink_valid = 1'b1;
                sink_real  = i[15:0];
                sink_sop   = (i == 0);
                sink_eop   = (i == 1023);
            end
        end

        @ (posedge clk);
        sink_valid = 1'b0;
        sink_sop = 1'b0;
        sink_eop = 1'b0;

        // Wait a bit
        #10000;

        // Send frame 2
        wait(sink_ready == 1'b1);
        for (i = 0; i < 1024; ) begin
            @ (posedge clk);
            if (sink_ready) begin
                sink_valid = 1'b1;
                sink_real  = (i[15:0] + 16'd1000);
                sink_sop   = (i == 0);
                sink_eop   = (i == 1023);
                i++;
            end else begin
                sink_valid = 1'b1;
                sink_real  = (i[15:0] + 16'd1000);
                sink_sop   = (i == 0);
                sink_eop   = (i == 1023);
            end
        end

        @ (posedge clk);
        sink_valid = 1'b0;
        sink_sop = 1'b0;
        sink_eop = 1'b0;

        // Wait a bit
        #20000;
        $stop(2);
    end

endmodule