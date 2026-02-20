module magnitude_calc (
    input logic board_clk,              // 50MHz FPGA onboard clock
    input logic resetn,                 // Active low reset button

    input logic signed [15:0] source_real,  // The real part of the frequency amplitude
    input logic signed [15:0] source_imag,  // The imaginary part of the frequency amplitude
    input logic source_valid,               // Flag to indicate the FFT has sent valid output
    input logic source_sop,                 // Start of packet (frequency bin 0)
    input logic source_eop,                 // End of packet (frequency bin 1023)

    output logic [15:0] magnitude,          // The calculated frequency amplitude
    output logic mag_valid,                 // Pulses high when 'magnitude' is ready
    output logic mag_sop,                   // Aligned with frequency bin 0
    output logic mag_eop                    // Aligned with frequency bin 1023
    );

    /* Use alpha max + beta min algorithm to approximate magnitude
    Magnitude is approx. alpha*max(|Re|, |Im|) + beta*min(|Re|, |Im|)
    Use alpha = 1, beta = 1/4 which means shifting min(|Re|, |Im|) to the right by 2 bits
    */

    typedef enum logic {
        IDLE,
        FINDING_MAX,
        FINDING_MIN,
        APPROXIMATING
    } calculation_state;

    calculation_state state;

    always_ff @ (posedge board_clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            magnitude <= 16'b0;
            mag_valid <= 1'b0;
            mag_sop <= 1'b0;
            mag_eop <= 1'b0;
        end else begin
            if (state == IDLE) begin
                // When in the idle state, check to see if we receive a valid output from FFT

            end
        end
    end



endmodule