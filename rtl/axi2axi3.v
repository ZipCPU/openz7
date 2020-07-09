////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	axi2axi3.v
//
// Project:	OpenZ7, an open source Zynq demo based on the Arty Z7-20
//
// Purpose:	Bridge from an AXI4 slave to an AXI3 master
//
//	The goal in this implementation is just to get something working
//	into the design quickly.  I intend to come back later and add
//	something more optimized, for now the goal is just to get something
//	working.  As such, we'll just convert everything to AXI-lite and go
//	from there.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2020, Gisselquist Technology, LLC
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
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype none
//
//
module	axi2axi3 #(
		parameter	C_AXI_ID_WIDTH = 1,
		parameter	C_AXI_ADDR_WIDTH = 32,
		parameter	C_AXI_DATA_WIDTH = 32,
		//
		localparam	ADDRLSB= $clog2(C_AXI_DATA_WIDTH)-3
	) (
		input	wire				S_AXI_ACLK,
		input	wire				S_AXI_ARESETN,
		//
		// The AXI4 incoming/slave interface
		input	wire				S_AXI_AWVALID,
		output	wire				S_AXI_AWREADY,
		input	wire	[C_AXI_ID_WIDTH-1:0]	S_AXI_AWID,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]	S_AXI_AWADDR,
		input	wire	[7:0]			S_AXI_AWLEN,
		input	wire	[2:0]			S_AXI_AWSIZE,
		input	wire	[1:0]			S_AXI_AWBURST,
		input	wire				S_AXI_AWLOCK,
		input	wire	[3:0]			S_AXI_AWCACHE,
		input	wire	[2:0]			S_AXI_AWPROT,
		input	wire	[3:0]			S_AXI_AWQOS,
		//
		//
		input	wire				S_AXI_WVALID,
		output	wire				S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]	S_AXI_WDATA,
		input	wire [C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		input	wire				S_AXI_WLAST,
		//
		//
		output	wire				S_AXI_BVALID,
		input	wire				S_AXI_BREADY,
		output	wire	[C_AXI_ID_WIDTH-1:0]	S_AXI_BID,
		output	wire	[1:0]			S_AXI_BRESP,
		//
		//
		input	wire				S_AXI_ARVALID,
		output	wire				S_AXI_ARREADY,
		input	wire	[C_AXI_ID_WIDTH-1:0]	S_AXI_ARID,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]	S_AXI_ARADDR,
		input	wire	[7:0]			S_AXI_ARLEN,
		input	wire	[2:0]			S_AXI_ARSIZE,
		input	wire	[1:0]			S_AXI_ARBURST,
		input	wire				S_AXI_ARLOCK,
		input	wire	[3:0]			S_AXI_ARCACHE,
		input	wire	[2:0]			S_AXI_ARPROT,
		input	wire	[3:0]			S_AXI_ARQOS,
		//
		output	wire				S_AXI_RVALID,
		input	wire				S_AXI_RREADY,
		output	wire	[C_AXI_ID_WIDTH-1:0]	S_AXI_RID,
		output	wire	[C_AXI_DATA_WIDTH-1:0]	S_AXI_RDATA,
		output	wire				S_AXI_RLAST,
		output	wire	[1:0]			S_AXI_RRESP,
		//
		//
		// The AXI3 Master (outgoing) interface
		output	wire				M_AXI_AWVALID,
		input	wire				M_AXI_AWREADY,
		output	wire	[C_AXI_ID_WIDTH-1:0]	M_AXI_AWID,
		output	wire	[C_AXI_ADDR_WIDTH-1:0]	M_AXI_AWADDR,
		output	wire	[3:0]			M_AXI_AWLEN,
		output	wire	[2:0]			M_AXI_AWSIZE,
		output	wire	[1:0]			M_AXI_AWBURST,
		output	wire	[1:0]			M_AXI_AWLOCK,
		output	wire	[3:0]			M_AXI_AWCACHE,
		output	wire	[2:0]			M_AXI_AWPROT,
		output	wire	[3:0]			M_AXI_AWQOS,
		//
		//
		output	wire				M_AXI_WVALID,
		input	wire				M_AXI_WREADY,
		output	wire	[C_AXI_ID_WIDTH-1:0]	M_AXI_WID,
		output	wire	[C_AXI_DATA_WIDTH-1:0]	M_AXI_WDATA,
		output	wire [C_AXI_DATA_WIDTH/8-1:0]	M_AXI_WSTRB,
		output	wire				M_AXI_WLAST,
		//
		//
		input	wire				M_AXI_BVALID,
		output	wire				M_AXI_BREADY,
		input	wire	[C_AXI_ID_WIDTH-1:0]	M_AXI_BID,
		input	wire	[1:0]			M_AXI_BRESP,
		//
		//
		output	wire				M_AXI_ARVALID,
		input	wire				M_AXI_ARREADY,
		output	wire	[C_AXI_ID_WIDTH-1:0]	M_AXI_ARID,
		output	wire	[C_AXI_ADDR_WIDTH-1:0]	M_AXI_ARADDR,
		output	wire	[3:0]			M_AXI_ARLEN,
		output	wire	[2:0]			M_AXI_ARSIZE,
		output	wire	[1:0]			M_AXI_ARBURST,
		output	wire	[1:0]			M_AXI_ARLOCK,
		output	wire	[3:0]			M_AXI_ARCACHE,
		output	wire	[2:0]			M_AXI_ARPROT,
		output	wire	[3:0]			M_AXI_ARQOS,
		//
		input	wire				M_AXI_RVALID,
		output	wire				M_AXI_RREADY,
		input	wire	[C_AXI_ID_WIDTH-1:0]	M_AXI_RID,
		input	wire	[C_AXI_DATA_WIDTH-1:0]	M_AXI_RDATA,
		input	wire				M_AXI_RLAST,
		input	wire	[1:0]			M_AXI_RRESP
	);

	localparam	[0:0]	OPT_LOWPOWER = 1'b0;
	localparam		LGWFIFO = 4;
	localparam		NID = (1<<C_AXI_ID_WIDTH);
	parameter		LGFIFO = 8;


	axi2axilite #(
		.C_AXI_ID_WIDTH(C_AXI_ID_WIDTH),
		.C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
		.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
	) jump2litespeed (
		.S_AXI_ACLK(S_AXI_ACLK),
		.S_AXI_ARESETN(S_AXI_ARESETN),
		//
		.S_AXI_AWVALID(S_AXI_AWVALID),
		.S_AXI_AWREADY(S_AXI_AWREADY),
		.S_AXI_AWID(   S_AXI_AWID),
		.S_AXI_AWADDR( S_AXI_AWADDR),
		.S_AXI_AWLEN(  S_AXI_AWLEN),
		.S_AXI_AWSIZE( S_AXI_AWSIZE),
		.S_AXI_AWBURST(S_AXI_AWBURST),
		.S_AXI_AWLOCK( S_AXI_AWLOCK),
		.S_AXI_AWCACHE(S_AXI_AWCACHE),
		.S_AXI_AWPROT( S_AXI_AWPROT),
		.S_AXI_AWQOS(  S_AXI_AWQOS),
		//
		.S_AXI_WVALID(S_AXI_WVALID),
		.S_AXI_WREADY(S_AXI_WREADY),
		.S_AXI_WDATA( S_AXI_WDATA),
		.S_AXI_WSTRB( S_AXI_WSTRB),
		.S_AXI_WLAST( S_AXI_WLAST),
		//
		.S_AXI_BVALID(S_AXI_BVALID),
		.S_AXI_BREADY(S_AXI_BREADY),
		.S_AXI_BID(   S_AXI_BID),
		.S_AXI_BRESP( S_AXI_BRESP),
		//
		.S_AXI_ARVALID(S_AXI_ARVALID),
		.S_AXI_ARREADY(S_AXI_ARREADY),
		.S_AXI_ARID(   S_AXI_ARID),
		.S_AXI_ARADDR( S_AXI_ARADDR),
		.S_AXI_ARLEN(  S_AXI_ARLEN),
		.S_AXI_ARSIZE( S_AXI_ARSIZE),
		.S_AXI_ARBURST(S_AXI_ARBURST),
		.S_AXI_ARLOCK( S_AXI_ARLOCK),
		.S_AXI_ARCACHE(S_AXI_ARCACHE),
		.S_AXI_ARPROT( S_AXI_ARPROT),
		.S_AXI_ARQOS(  S_AXI_ARQOS),
		//
		.S_AXI_RVALID(S_AXI_RVALID),
		.S_AXI_RREADY(S_AXI_RREADY),
		.S_AXI_RID(   S_AXI_RID),
		.S_AXI_RDATA( S_AXI_RDATA),
		.S_AXI_RLAST( S_AXI_RLAST),
		.S_AXI_RRESP( S_AXI_RRESP),
		//
		//
		.M_AXI_AWVALID(M_AXI_AWVALID),
		.M_AXI_AWREADY(M_AXI_AWREADY),
		.M_AXI_AWADDR( M_AXI_AWADDR),
		.M_AXI_AWPROT( M_AXI_AWPROT),
		//
		.M_AXI_WVALID(M_AXI_WVALID),
		.M_AXI_WREADY(M_AXI_WREADY),
		.M_AXI_WDATA( M_AXI_WDATA),
		.M_AXI_WSTRB( M_AXI_WSTRB),
		//
		.M_AXI_BVALID(M_AXI_BVALID),
		.M_AXI_BREADY(M_AXI_BREADY),
		.M_AXI_BRESP( M_AXI_BRESP),
		//
		.M_AXI_ARVALID(M_AXI_ARVALID),
		.M_AXI_ARREADY(M_AXI_ARREADY),
		.M_AXI_ARADDR( M_AXI_ARADDR),
		.M_AXI_ARPROT( M_AXI_ARPROT),
		//
		.M_AXI_RVALID(M_AXI_RVALID),
		.M_AXI_RREADY(M_AXI_RREADY),
		.M_AXI_RDATA( M_AXI_RDATA),
		.M_AXI_RRESP( M_AXI_RRESP)
		//
	);

	assign	M_AXI_AWLEN   = 4'h0;
	assign	M_AXI_AWSIZE  = ADDRLSB[2:0];
	assign	M_AXI_AWID    = 0;
	assign	M_AXI_AWBURST = 2'b01;
	assign	M_AXI_AWLOCK  = 2'b00;
	assign	M_AXI_AWCACHE = 4'h3;
	assign	M_AXI_AWQOS   = 4'h0;

	assign	M_AXI_WID   = 0;
	assign	M_AXI_WLAST = 1;

	assign	M_AXI_ARLEN   = 4'h0;
	assign	M_AXI_ARSIZE  = ADDRLSB[2:0];
	assign	M_AXI_ARID    = 0;
	assign	M_AXI_ARBURST = 2'b01;
	assign	M_AXI_ARLOCK  = 2'b00;
	assign	M_AXI_ARCACHE = 4'h3;
	assign	M_AXI_ARQOS   = 4'h0;

	// Make Verilator happy
	// {{{
	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, M_AXI_BID, M_AXI_RID, M_AXI_RLAST };
	// Verilator lint_on UNUSED
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal property section
//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
//
// This design has not been formally verified.
//
`endif
endmodule
