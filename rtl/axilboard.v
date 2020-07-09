////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	axilboard
// {{{
// Project:	OpenZ7, an open source Zynq demo based on the Arty Z7-20
//
// Purpose:	Provide access to the boards basic user I/O, also as an early
//		demonstration of the ability to attach to and interact with
//	the ARM's AXI master port, as a simple slave that may be driven by it.
//
// I/O's controlled:
//	4 LEDs					0: 0x0000:00xf
//	Four buttons				0: 0x0000:ff00
//	Two switches				0: 0x0003:0000
//	HDMI Present/enable			0: 0x0030:0000
//	2x Color LEDs				4: 0x0fff:0fff
//
// Other I/O's not controlled here:
//	(Analog header?)
//	(SPI?)
//	(XADC?)
//	(I2C?)
//	(EDID)
//
// Registers:
//	0: 0x....:..xf	Bits 3:0 indicate and control the current LED outputs
//			Bits 7:4 control which LEDs are then changed
//	0: 0x....:ff..	Bits 15:12 indicate the current state of the buttons
//			Bits 11: 8 indicate if the button has been pressed
//				Setting this value to one will clear the button
//				press indicator.  It will be reset (again) on
//				any new button press.
//	0: 0x...3:....	Bits 17:16 indicate the current value of the switch
//	0: 0x...4:....	If set, turns on an LED chaser program overriding the
//			other LED outputs.
//	0: 0x..30:....	Bits 21:20 control the HDMI present bits
//			21	RX_HPD
//			20	TX_HPDN
//			Reads return the current value of the register.  Writes
//			(with corresponding bit 17 or 16) will also set the
//			register (if it caqn be set)
//	4: 0x....:.rgb	Sets the color of color LED #0
//	6: 0x.rgb:....	Sets the color of color LED #1
//			
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020, Gisselquist Technology, LLC
// {{{
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
// }}}
//
`default_nettype none
`include "builddate.v"
//
module	axilboard #(
		// {{{
		//
		// Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
		// is fixed at a width of 32-bits by Xilinx def'n, and 2) since
		// we only ever have 4 configuration words.
		parameter	C_AXI_ADDR_WIDTH = 5,
		localparam	C_AXI_DATA_WIDTH = 32,
		parameter [0:0]	OPT_SKIDBUFFER = 1'b1,
		parameter [0:0]	OPT_LOWPOWER = 0,
		localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3
		// }}}
	) (
		// {{{
		input	wire					S_AXI_ACLK,
		input	wire					S_AXI_ARESETN,
		//
		input	wire					S_AXI_AWVALID,
		output	wire					S_AXI_AWREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
		input	wire	[2:0]				S_AXI_AWPROT,
		//
		input	wire					S_AXI_WVALID,
		output	wire					S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire					S_AXI_BVALID,
		input	wire					S_AXI_BREADY,
		output	wire	[1:0]				S_AXI_BRESP,
		//
		input	wire					S_AXI_ARVALID,
		output	wire					S_AXI_ARREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
		input	wire	[2:0]				S_AXI_ARPROT,
		//
		output	wire					S_AXI_RVALID,
		input	wire					S_AXI_RREADY,
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
		output	wire	[1:0]				S_AXI_RRESP,
		//
		input	wire	[1:0]				i_sw,
		input	wire	[3:0]				i_btn,
		output	reg	[3:0]				o_led,
		output	reg	[1:0]				o_led_red,
		output	reg	[1:0]				o_led_grn,
		output	reg	[1:0]				o_led_blu
		// input	wire				i_hdmi_tx_hpd,
		// output	wire				o_hdmi_rx_hpd,
		// }}}
	);

	localparam		CLK_RATE_HZ = 100_000_000; // 100MHz
	localparam [31:0]	RTC_STEP = ((1<<30) / (CLK_RATE_HZ / 4));
	localparam [31:0]	PPS_STEP = 3 * RTC_STEP;

	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	wire				i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;

	reg		r_chaser;
	reg	[31:0]	r_spio, r_clrled;
	reg	[11:0]	clrled			[0:1];
	wire	[31:0]	w_spio, w_clrled, w_spio_reg;
	wire	[3:0]	w_btn;
	reg	[3:0]	r_pressed, r_led, last_btn;
	wire	[1:0]	w_sw;
	integer		ik;
	reg	[31:0]	r_pwrcount, r_rtccount;
	wire	[31:0]	w_rtccount;


	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Write signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_WRITE

		wire	awskd_valid, wskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilawskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
			.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(awskd_valid), .i_ready(axil_write_ready),
			.o_data(awskd_addr));

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
		axilwskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
			.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
			.o_valid(wskd_valid), .i_ready(axil_write_ready),
			.o_data({ wskd_data, wskd_strb }));

		assign	axil_write_ready = awskd_valid && wskd_valid
				&& (!S_AXI_BVALID || S_AXI_BREADY);

	end else begin : SIMPLE_WRITES

		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		assign	S_AXI_AWREADY = axil_awready;
		assign	S_AXI_WREADY  = axil_awready;

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		assign	axil_write_ready = axil_awready;

	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	assign	S_AXI_BVALID = axil_bvalid;
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_READ

		wire	arskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilarskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
			.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(arskd_valid), .i_ready(axil_read_ready),
			.o_data(arskd_addr));

		assign	axil_read_ready = arskd_valid
				&& (!axil_read_valid || S_AXI_RREADY);

	end else begin : SIMPLE_READS

		reg	axil_arready;

		always @(*)
			axil_arready = !S_AXI_RVALID;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	S_AXI_ARREADY = axil_arready;
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);

	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (axil_read_ready)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	assign	S_AXI_RVALID = axil_read_valid;
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Debounce the incoming buttons and switches
	//
`ifdef	FORMAL
	assign	w_btn = i_btn;
	assign	w_sw  = i_sw;
`else
	debouncer #(.NIN(4))
	btndebouncing(.i_clk(S_AXI_ACLK), .i_in(i_btn), .o_debounced(w_btn));

	debouncer #(.NIN(2))
	swdebouncing(.i_clk(S_AXI_ACLK), .i_in(i_sw), .o_debounced(w_sw));
`endif

	initial	last_btn = 0;
	always @(posedge S_AXI_ACLK)
		last_btn <= w_btn;

	always @(*)
	begin
		r_spio = 0;
		r_spio[ 3: 0] = o_led;
		// r_spio[11: 8] = r_pressed;
		r_spio[15:12] = w_btn;
		// r_spio[17:16] = w_sw;
		r_spio[18]    = r_chaser;

		r_clrled = 0;
		r_clrled[ 0 +: 12] = clrled[0];
		r_clrled[16 +: 12] = clrled[1];
	end

	assign	w_spio     = apply_wstrb(r_spio,     wskd_data, wskd_strb);
	assign	w_clrled   = apply_wstrb(r_clrled,   wskd_data, wskd_strb);
	assign	w_rtccount = apply_wstrb(r_rtccount, wskd_data, wskd_strb);

	assign	w_spio_reg = {
			8'h0,
			4'h3,			// o_RX_HPD, i_TX_HPD
			1'b0, r_chaser, w_sw,
			w_btn, r_pressed,
			4'h0, r_led
			};

	initial	r_pressed = 0;
	initial	r_led = 0;
	// Start color LEDs at red (error)--we're starting up
	initial	clrled[0] = 12'hf00;
	initial	clrled[1] = 12'hf00;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		r_pressed <= 0;
		r_led     <= 0;
		r_chaser  <= 1'b1;	// Control an LED chaser
		clrled[0] <= 12'hf00;
		clrled[0] <= 12'hf00;
		r_pwrcount <= 0;
		r_rtccount <= 0;
	end else begin

		r_pwrcount <= r_pwrcount + 1;
		if (r_pwrcount[31])
			r_pwrcount[31] <= r_pwrcount[31];

		r_rtccount <= r_rtccount + RTC_STEP;

		if (axil_write_ready)
		begin
			case(awskd_addr)
			3'b011:	r_rtccount <= w_rtccount;
			3'b100:	begin
				r_led <= (r_led & ~w_spio[7:4])
					| (w_spio[3:0] & w_spio[7:4]);
				r_pressed <= r_pressed & (~w_spio[11:8]);

				r_chaser <= w_spio[18];

				// r_rx_hdmi_hpd <= w_spio[21]
				end
			3'b101:	begin
				clrled[0] <= w_clrled[11: 0];
				clrled[1] <= w_clrled[27:16];
				end
			default: begin end
			endcase
		end

		for(ik=0; ik<4; ik=ik+1)
		if (!last_btn[ik] && w_btn[ik])
			r_pressed[ik] <= 1'b1;
	end

	initial	axil_read_data = 0;
	always @(posedge S_AXI_ACLK)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
		axil_read_data <= 0;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		case(arskd_addr)
		3'b000:	axil_read_data	<= `DATESTAMP;
		3'b001:	axil_read_data	<= `BUILDTIME;
		3'b010:	axil_read_data	<= r_pwrcount;
		3'b011:	axil_read_data	<= r_rtccount;
		3'b100:	axil_read_data	<= w_spio_reg;
		3'b101:	axil_read_data	<= r_clrled;
		default: axil_read_data <= 0;
		endcase

		if (OPT_LOWPOWER && !axil_read_ready)
			axil_read_data <= 0;
	end

	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction
	// }}}

	////////////////////////////////////////////////////////////////////////
	//
	// LED Chaser
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	// parameter	PPS_STEP = (1<<32) * 6 / CLK_RATE_HZ;

	reg		led_step;
	reg	[31:0]	led_counter;
	reg	[2:0]	led_state;
	reg	[3:0]	chased_leds;

	initial	{ led_step, led_counter } = 0;
	always @(posedge S_AXI_ACLK)
		{ led_step, led_counter } <= led_counter + PPS_STEP;

	always @(posedge S_AXI_ACLK)
	if (led_step)
	case(led_state)
	3'h0: led_state <= 3'h0;
	3'h1: led_state <= 3'h2;
	3'h2: led_state <= 3'h3;
	3'h3: led_state <= 3'h4;
	3'h4: led_state <= 3'h5;
	// 3'h5: led_state <= 3'h0; // Default
	default: led_state <= 3'b0;
	endcase

	always @(posedge S_AXI_ACLK)
	case(led_state)
	3'h0: chased_leds <= 4'h1;
	3'h1: chased_leds <= 4'h2;
	3'h2: chased_leds <= 4'h4;
	3'h3: chased_leds <= 4'h8;
	3'h4: chased_leds <= 4'h4;
	3'h5: chased_leds <= 4'h2;
	default: chased_leds <= 4'b1;
	endcase

	always @(*)
	begin
		if (r_chaser)
			o_led = chased_leds;
		else
			o_led = r_led;

		if (!S_AXI_ARESETN)
			o_led[3:1] = 3'h7;
	end
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Color LED logic
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	reg	[7:0]	raw_counter;

	always @(posedge S_AXI_ACLK)
		raw_counter <= raw_counter + 1;

	initial	o_led_red = 2'b11;
	initial	o_led_grn = 2'b11;
	initial	o_led_blu = 2'b00;
	always @(posedge S_AXI_ACLK)
	begin
		o_led_red[0] <= pwmfn(raw_counter, clrled[0][11:8]);
		o_led_grn[0] <= pwmfn(raw_counter, clrled[0][ 7:4]);
		o_led_blu[0] <= pwmfn(raw_counter, clrled[0][ 3:0]);

		o_led_red[1] <= pwmfn(raw_counter, clrled[1][11:8]);
		o_led_grn[1] <= pwmfn(raw_counter, clrled[1][ 7:4]);
		o_led_blu[1] <= pwmfn(raw_counter, clrled[1][ 3:0]);
	end

	function pwmfn;
		input	[7:0]		counter;
		input	[3:0]		brightness;

		case(brightness)
		4'h0: pwmfn = 1'b0;
		4'h1: pwmfn = (counter < 8'h01);
		4'h2: pwmfn = (counter < 8'h02);
		4'h3: pwmfn = (counter < 8'h04);
		4'h4: pwmfn = (counter < 8'h06);
		4'h5: pwmfn = (counter < 8'h08);
		4'h6: pwmfn = (counter < 8'h0c);
		4'h7: pwmfn = (counter < 8'h10);
		4'h8: pwmfn = (counter < 8'h18);
		4'h9: pwmfn = (counter < 8'h20);
		4'ha: pwmfn = (counter < 8'h33);
		4'hb: pwmfn = (counter < 8'h40);
		4'hc: pwmfn = (counter < 8'h66);
		4'hd: pwmfn = (counter < 8'h80);
		4'he: pwmfn = (counter < 8'hcc);
		4'hf: pwmfn = 1'b1;
		endcase

	endfunction
	// }}}


	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
			w_spio[31:19], w_spio[17:12],
			w_clrled[31:28], w_clrled[15:12],
			S_AXI_ARADDR[ADDRLSB-1:0],
			S_AXI_AWADDR[ADDRLSB-1:0] };
	// Verilator lint_on  UNUSED
	// }}}
`ifdef	FORMAL
	////////////////////////////////////////////////////////////////////////
	//
	// Formal properties used in verfiying this core
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge S_AXI_ACLK)
		f_past_valid <= 1;

	////////////////////////////////////////////////////////////////////////
	//
	// The AXI-lite control interface
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	localparam	F_AXIL_LGDEPTH = 4;
	wire	[F_AXIL_LGDEPTH-1:0]	faxil_rd_outstanding,
					faxil_wr_outstanding,
					faxil_awr_outstanding;

	faxil_slave #(
		// {{{
		.C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
		.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
		.F_LGDEPTH(F_AXIL_LGDEPTH),
		.F_AXI_MAXWAIT(2),
		.F_AXI_MAXDELAY(2),
		.F_AXI_MAXRSTALL(3),
		.F_OPT_COVER_BURST(4)
		// }}}
	) faxil(
		// {{{
		.i_clk(S_AXI_ACLK), .i_axi_reset_n(S_AXI_ARESETN),
		//
		.i_axi_awvalid(S_AXI_AWVALID),
		.i_axi_awready(S_AXI_AWREADY),
		.i_axi_awaddr( S_AXI_AWADDR),
		.i_axi_awcache(4'h0),
		.i_axi_awprot( S_AXI_AWPROT),
		//
		.i_axi_wvalid(S_AXI_WVALID),
		.i_axi_wready(S_AXI_WREADY),
		.i_axi_wdata( S_AXI_WDATA),
		.i_axi_wstrb( S_AXI_WSTRB),
		//
		.i_axi_bvalid(S_AXI_BVALID),
		.i_axi_bready(S_AXI_BREADY),
		.i_axi_bresp( S_AXI_BRESP),
		//
		.i_axi_arvalid(S_AXI_ARVALID),
		.i_axi_arready(S_AXI_ARREADY),
		.i_axi_araddr( S_AXI_ARADDR),
		.i_axi_arcache(4'h0),
		.i_axi_arprot( S_AXI_ARPROT),
		//
		.i_axi_rvalid(S_AXI_RVALID),
		.i_axi_rready(S_AXI_RREADY),
		.i_axi_rdata( S_AXI_RDATA),
		.i_axi_rresp( S_AXI_RRESP),
		//
		.f_axi_rd_outstanding(faxil_rd_outstanding),
		.f_axi_wr_outstanding(faxil_wr_outstanding),
		.f_axi_awr_outstanding(faxil_awr_outstanding)
		// }}}
		);

	always @(*)
	if (OPT_SKIDBUFFER)
	begin
		assert(faxil_awr_outstanding== (S_AXI_BVALID ? 1:0)
			+(S_AXI_AWREADY ? 0:1));
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0)
			+(S_AXI_WREADY ? 0:1));

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0)
			+(S_AXI_ARREADY ? 0:1));
	end else begin
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0));
		assert(faxil_awr_outstanding == faxil_wr_outstanding);

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0));
	end

	//
	// Check that our low-power only logic works by verifying that anytime
	// S_AXI_RVALID is inactive, then the outgoing data is also zero.
	//
	always @(*)
	if (OPT_LOWPOWER && !S_AXI_RVALID)
		assert(S_AXI_RDATA == 0);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Cover checks
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// While there are already cover properties in the formal property
	// set above, you'll probably still want to cover something
	// application specific here

	// }}}
	// }}}
`endif
endmodule
