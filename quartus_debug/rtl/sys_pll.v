module sys_pll (
	inclk0,
	rst,
	c0,
	locked);

	input	  inclk0;
	input	  rst;
	output	  c0;
	output	  locked;

	wire [4:0] sub_wire0;
	wire [0:0] sub_wire4 = 1'h0;
	wire [0:0] sub_wire1 = sub_wire0[0:0];
	wire  c0 = sub_wire1;
	wire  sub_wire2;
	wire  locked = sub_wire2;
	wire [1:0] sub_wire3 = {sub_wire4, inclk0};

	altpll	altpll_component (
				.areset (!rst),
				.inclk (sub_wire3),
				.clk (sub_wire0),
				.locked (sub_wire2),
				.activeclock (),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b0),
				.enable0 (),
				.enable1 (),
				.extclk (),
				.fbin (1'b1),
				.fbmimicbidir (),
				.fbout (),
				.pfdena (1'b1),
				.phasecounterselect ({4{1'b1}}),
				.phasedone (),
				.phasestep (1'b1),
				.phaseupdown (1'b1),
				.pllena (1'b1),
				.scanaclr (1'b0),
				.scanclk (1'b0),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.bandwidth_type = "AUTO",
		altpll_component.clk0_divide_by = 284,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 143,
		altpll_component.clk0_phase_shift = "0",
		altpll_component.compensate_clock = "CLK0",
		altpll_component.inclk0_input_frequency = 20000,
		altpll_component.intended_device_family = "Cyclone IV E",
		altpll_component.lpm_type = "altpll",
		altpll_component.operation_mode = "NORMAL",
		altpll_component.pll_type = "AUTO",
		altpll_component.self_reset_on_loss_lock = "OFF",
		altpll_component.width_clock = 5;

endmodule