module amplitude_calc (
    input logic board_clk,                  // 50MHz FPGA onboard clock
    input logic resetn,                     // Active low reset button

    input logic signed [15:0] source_real,  // The real part of the frequency amplitude
    input logic signed [15:0] source_imag,  // The imaginary part of the frequency amplitude
    input logic source_valid,               // Flag to indicate the FFT has sent valid output
    input logic source_sop,                 // Start of packet (frequency bin 0)
    input logic source_eop,                 // End of packet (frequency bin 1023)

    output logic [15:0] amplitude,          // The calculated frequency amplitude
    output logic amp_valid,                 // Pulses high when 'amplitude' is ready
    output logic amp_sop,                   // Aligned with frequency bin 0
    output logic amp_eop                    // Aligned with frequency bin 1023
    );

    logic [15:0] abs_real;                  // Absolute value of the real part of the frequency amplitude
    logic [15:0] abs_imag;                  // Absolute value of the imaginary part of the frequency amplitude

    logic [15:0] max_val;                   // The maximum value between abs_real and abs_imag
    logic [15:0] min_val;                   // The minimum value between abs_real and abs_imag

    // Delay registers for source_valid signal
    logic valid_delay_1;
    logic valid_delay_2;

    // Delay registers for source_sop signal
    logic sop_delay_1;
    logic sop_delay_2;

    // Delay registers for source_eop signal
    logic eop_delay_1;
    logic eop_delay_2;

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            amplitude <= 16'b0;
            amp_valid <= 1'b0;
            amp_sop <= 1'b0;
            amp_eop <= 1'b0;
            valid_delay_1 <= 1'b0;
            valid_delay_2 <= 1'b0;
            sop_delay_1 <= 1'b0;
            sop_delay_2 <= 1'b0;
            eop_delay_1 <= 1'b0;
            eop_delay_2 <= 1'b0;
        end else begin
            // Shift register (3 clock cycles) for amp_valid signal
            valid_delay_1 <= source_valid;
            valid_delay_2 <= valid_delay_1;
            amp_valid <= valid_delay_2;

            // Shift register (3 clock cycles) for amp_sop signal
            sop_delay_1 <= source_sop;
            sop_delay_2 <= sop_delay_1;
            amp_sop <= sop_delay_2;

            // Shift register (3 clock cycles) for amp_eop signal
            eop_delay_1 <= source_eop;
            eop_delay_2 <= eop_delay_1;
            amp_eop <= eop_delay_2;

            // Check if real part of source is negative
            if (source_real[15])
                abs_real <= (~source_real) + 16'b1;
            else
                abs_real <= source_real;

            // Check if imaginary part of source is negative
            if (source_imag[15])
                abs_imag <= (~source_imag) + 16'b1;
            else
                abs_imag <= source_imag;

            // Find the maximum/minimum between abs_real and abs_imag
            if (abs_real > abs_imag) begin
                max_val <= abs_real;
                min_val <= abs_imag;
            end else begin
                max_val <= abs_imag;
                min_val <= abs_real;
            end

            /* Using alpha max + beta min algorithm to approximate amplitude
            Amplitude is approx. alpha*max(|Re|, |Im|) + beta*min(|Re|, |Im|)
            Using alpha = 1, beta = 1/4 which means shifting min(|Re|, |Im|) to the right by 2 bits
            */

            amplitude <= max_val + (min_val >> 2'd2);
        end
    end



endmodule