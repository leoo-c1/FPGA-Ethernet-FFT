module amplitude_calc (
    input logic board_clk,                  // 50MHz FPGA onboard clock
    input logic resetn,                     // Active low reset button

    input logic signed [15:0] source_real,  // The real part of the frequency amplitude
    input logic signed [15:0] source_imag,  // The imaginary part of the frequency amplitude
    input logic source_valid,               // Flag to indicate the FFT has sent valid output
    input logic source_sop,                 // Start of packet (frequency bin 0)
    input logic source_eop,                 // End of packet (frequency bin 1023)
    input logic [5:0] source_exp,           // The exponent of the block-floating-point representation of source

    output logic [15:0] amplitude,          // Frequency amplitude (after exponent and logarithmic scaling)
    output logic amp_valid,                 // Pulses high when 'amplitude' is ready
    output logic amp_sop,                   // Aligned with frequency bin 0
    output logic amp_eop                    // Aligned with frequency bin 1023
    );

    logic [15:0] abs_real;                  // Absolute value of the real part of the frequency amplitude
    logic [15:0] abs_imag;                  // Absolute value of the imaginary part of the frequency amplitude

    logic [15:0] max_val;                   // The maximum value between abs_real and abs_imag
    logic [15:0] min_val;                   // The minimum value between abs_real and abs_imag

    logic [30:0] base_amplitude;            // The amplitude before exponent scaling is applied
    logic [39:0] raw_amplitude;             // The exponent-scaled amplitude before logarithmic scaling

    logic [5:0] delayed_exp;                // The delayed exponent of the block-floating-point representation of source

    // Delay registers for source_valid signal
    logic valid_delay_1;
    logic valid_delay_2;
    logic valid_delay_3;
    logic valid_delay_4;

    // Delay registers for source_sop signal
    logic sop_delay_1;
    logic sop_delay_2;
    logic sop_delay_3;
    logic sop_delay_4;

    // Delay registers for source_eop signal
    logic eop_delay_1;
    logic eop_delay_2;
    logic eop_delay_3;
    logic eop_delay_4;

    // Delay registers for source_exp value
    logic [5:0] exp_delay_1;
    logic [5:0] exp_delay_2;
    logic [5:0] exp_delay_3;

    logic [63:0] val_64;
    logic [31:0] val_32;
    logic [15:0] val_16;
    logic [7:0] val_8;
    logic [3:0] val_4;
    logic [1:0] val_2;

    logic [5:0] log_index;

    logic [63:0] normalized_val;
    logic [3:0] frac_bits;

    always_comb begin
        val_64 = {24'b0, raw_amplitude};    // Pad to 64

        // Find the 32s place
        if (| val_64[63:32]) begin
            log_index[5] = 1'b1;
            val_32 = val_64[63:32];
        end else begin
            log_index[5] = 1'b0;
            val_32 = val_64[31:0];
        end

        // Find the 16s place
        if (| val_32[31:16]) begin
            log_index[4] = 1'b1;
            val_16 = val_32[31:16]; 
        end else begin
            log_index[4] = 1'b0;
            val_16 = val_32[15:0];  
        end

        // Find the 8s place
        if (| val_16[15:8]) begin
            log_index[3] = 1'b1;
            val_8 = val_16[15:8];
        end else begin
            log_index[3] = 1'b0;
            val_8 = val_16[7:0];
        end

        // Find the 4s place
        if (| val_8[7:4]) begin
            log_index[2] = 1'b1;
            val_4 = val_8[7:4];
        end else begin
            log_index[2] = 1'b0;
            val_4 = val_8[3:0];
        end

        // Find the 2s place
        if (| val_4[3:2]) begin
            log_index[1] = 1'b1;
            val_2 = val_4[3:2];
        end else begin
            log_index[1] = 1'b0;
            val_2 = val_4[1:0];
        end

        // Find the 1s place
        if (val_2[1])
            log_index[0] = 1'b1;
        else
            log_index[0] = 1'b0;

        // Extract the 4 fractional bits
        normalized_val = val_64 << (6'd63 - log_index);
        frac_bits = normalized_val[62:59];
    end

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            amplitude <= 16'b0;
            base_amplitude <= 31'b0;
            delayed_exp <= 6'b0;
            amp_valid <= 1'b0;
            amp_sop <= 1'b0;
            amp_eop <= 1'b0;
            valid_delay_1 <= 1'b0;
            valid_delay_2 <= 1'b0;
            valid_delay_3 <= 1'b0;
            valid_delay_4 <= 1'b0;
            sop_delay_1 <= 1'b0;
            sop_delay_2 <= 1'b0;
            sop_delay_3 <= 1'b0;
            sop_delay_4 <= 1'b0;
            eop_delay_1 <= 1'b0;
            eop_delay_2 <= 1'b0;
            eop_delay_3 <= 1'b0;
            eop_delay_4 <= 1'b0; 
            exp_delay_1 <= 1'b0;
            exp_delay_2 <= 1'b0;
            exp_delay_3 <= 1'b0;
        end else begin
            // Shift register (6 clock cycles) for amp_valid signal
            valid_delay_1 <= source_valid;
            valid_delay_2 <= valid_delay_1;
            valid_delay_3 <= valid_delay_2;
            valid_delay_4 <= valid_delay_3;
            amp_valid <= valid_delay_4;

            // Shift register (6 clock cycles) for amp_sop signal
            sop_delay_1 <= source_sop;
            sop_delay_2 <= sop_delay_1;
            sop_delay_3 <= sop_delay_2;
            sop_delay_4 <= sop_delay_3;
            amp_sop <= sop_delay_4;

            // Shift register (6 clock cycles) for amp_eop signal
            eop_delay_1 <= source_eop;
            eop_delay_2 <= eop_delay_1;
            eop_delay_3 <= eop_delay_2;
            eop_delay_4 <= eop_delay_3;
            amp_eop <= eop_delay_4;

            // Shift register (4 clock cycles) for delayed_exp signal
            exp_delay_1 <= source_exp;
            exp_delay_2 <= exp_delay_1;
            exp_delay_3 <= exp_delay_2;
            delayed_exp <= exp_delay_3;

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

            base_amplitude <= max_val + (min_val >> 2'd2);

            // Decide the direction of bit shift based on sign of the exponent
            if (delayed_exp[5]) 
                raw_amplitude <= base_amplitude << (~delayed_exp + 1'b1);
            else
                raw_amplitude <= base_amplitude >> delayed_exp;

            // Combine integer and fractional parts
            amplitude <= {6'b0, log_index, frac_bits};
        end
    end

endmodule