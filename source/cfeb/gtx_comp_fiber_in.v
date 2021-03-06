`timescale 1ns / 1ps
//-------------------------------------------------------------------------------------------------------------------
//
// Virtex6: Instantiates GTX
//
//-------------------------------------------------------------------------------------------------------------------
//	08/30/2012	Port from TAMU comp_fiber_in.v
//	09/05/2012	Add sump
//	09/05/2012	Remove CMP_SIGDET, CMP_RX_VIO_CNTRL, CMP_RX_LA_CNTRL inputs
//	09/12/2012	Conform module names
//	12/05/2012	Add cmp_rx signals to sump
//-------------------------------------------------------------------------------------------------------------------
	module gtx_comp_fiber_in
	(
	RST,
	CMP_RX_N,
	CMP_RX_P,
//	CMP_TDIS,
//	CMP_TX_N,
//	CMP_TX_P,
	CMP_RX_REFCLK,
	RX_POLARITY_SWAP,
//	CMP_SD,
	CMP_RX_CLK160,
	STRT_MTCH,
	VALID,
	MATCH,
	RCV_DATA,
	NONZERO_WORD,
	CEW0,
	CEW1,
	CEW2,
	CEW3,
	LTNCY_TRIG,
	RX_SYNC_DONE,
	sump
    );
//-------------------------------------------------------------------------------------------------------------------
// Generic
//-------------------------------------------------------------------------------------------------------------------
	parameter USE_CHIPSCOPE	= 0;
	parameter SIM_SPEEDUP	= 0;

//-------------------------------------------------------------------------------------------------------------------
// Ports
//-------------------------------------------------------------------------------------------------------------------
	input			RST;
	input			CMP_RX_N;
	input			CMP_RX_P;
//	output			CMP_TDIS;
//	output			CMP_TX_N;
//	output			CMP_TX_P;
	input			CMP_RX_REFCLK;
	input			RX_POLARITY_SWAP;
//	output			CMP_SD;
	output			CMP_RX_CLK160;
	output			STRT_MTCH;
	output			VALID;
	output			MATCH;
	output	[47:0]	RCV_DATA;
	output	[3:1]	NONZERO_WORD;
	output			CEW0;
	output			CEW1;
	output			CEW2;
	output			CEW3;
	output			LTNCY_TRIG;
	output			RX_SYNC_DONE;
	output			sump;

//-------------------------------------------------------------------------------------------------------------------
// Output Registers
//-------------------------------------------------------------------------------------------------------------------
	reg		[47:0]	RCV_DATA;
	reg		[3:1]	NONZERO_WORD;
	reg				CEW0;
	reg				CEW1;
	reg				CEW2;
	reg				CEW3;
	reg				LTNCY_TRIG;

//-------------------------------------------------------------------------------------------------------------------
// Local
//-------------------------------------------------------------------------------------------------------------------
//!	wire cmp_tx_dis;

// Inputs to TRG GTX receiver
	reg  cmp_rx_calign_m	= 1'b1;
	reg  cmp_rx_calign_p	= 1'b1;
	reg	 cmp_rxresetdone_r	= 0;
	reg  cmp_rxresetdone_r2	= 0;

	wire rx_enpmaphasealign;
	wire rx_pmasetphase;
	wire rx_dlyaligndisable;
	wire rx_dlyalignreset;
	wire rx_sync_rst;
	wire cmp_gtxrxreset;
	wire rx_dly_align_mon_ena;

	wire [7:0]	rx_dly_align_mon;

// Outputs from TRG GTX receiver
	wire [1:0]	cmp_rx_isc;
	wire [1:0]	cmp_rx_isk;
	wire [1:0]	cmp_rx_disperr;
	wire [1:0]	cmp_rx_notintable;
	wire [15:0]	cmp_rx_data;
	wire [1:0]	cmp_rx_lossofsync;

	wire cmp_rx_byte_is_aligned;
	wire cmp_rx_commadet;
	wire cmp_rx_resetdone;

// TRG GTX receiver clocking signals
	wire cmp_rx_recclk;
	wire cmp_rx_pll_lock;
	wire cmp_rx_clk80;
	wire cmp_rx_clk40;
	wire cmp_rx_rec_lock;

// Don't know
	wire sync_match;
	wire lt_trg;

	reg			lt_trg_reg 	= 0;
	reg [15:0]	w1_reg 		= 0;
	reg [15:0]	w2_reg 		= 0;

//!	assign cmp_tx_dis =1 'b1;
  
//! IBUF IBUF_CMP_SIGDET (.I(CMP_SIGDET),.O(CMP_SD));
//!	assign CMP_SD=0;	// JK
//!	OBUF  #(.DRIVE(12),.IOSTANDARD("DEFAULT"),.SLEW("SLOW")) OBUF_CMP_TDIS (.O(CMP_TDIS),.I(cmp_tx_dis));

//-------------------------------------------------------------------------------------------------------------------
// GTX instance
//-------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------
// Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
// Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
//----------------------------------------------------------------------------
// CLK_OUT1   160.000      0.000      50.0      108.430     95.076
// CLK_OUT2    80.000      0.000      50.0      124.157     95.076
// CLK_OUT3    40.000      0.000      50.0      143.129     95.076
//
//----------------------------------------------------------------------------
// Input Clock   Input Freq (MHz)   Input Jitter (UI)
//----------------------------------------------------------------------------
// primary         160.000            0.010
//-------------------------------------------------------------------------------------------------------------------
	BUFG rxrecclk_bufg (.I(cmp_rx_recclk), .O(CMP_RX_CLK160));

// GTX0  (X0Y12)
	GTX_RX_BUF_BYPASS # 
	(.WRAPPER_SIM_GTXRESET_SPEEDUP	(0)	// Set this to 1 for simulation

	) ugtx_rx_buf_bypass (
// Receive Ports - 8b10b Decoder
	.GTX0_RXCHARISCOMMA_OUT         (cmp_rx_isc),
	.GTX0_RXCHARISK_OUT             (cmp_rx_isk),
	.GTX0_RXDISPERR_OUT             (cmp_rx_disperr),
	.GTX0_RXNOTINTABLE_OUT          (cmp_rx_notintable),

// Receive Ports - Comma Detection and Alignment
	.GTX0_RXBYTEISALIGNED_OUT       (cmp_rx_byte_is_aligned),
	.GTX0_RXCOMMADET_OUT            (cmp_rx_commadet),
	.GTX0_RXENMCOMMAALIGN_IN        (cmp_rx_calign_m),
	.GTX0_RXENPCOMMAALIGN_IN        (cmp_rx_calign_p),

// Receive Ports - RX Data Path interface
	.GTX0_RXDATA_OUT                (cmp_rx_data),
	.GTX0_RXRECCLK_OUT              (cmp_rx_recclk),
	.GTX0_RXUSRCLK2_IN              (CMP_RX_CLK160),

// Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR
	.GTX0_RXN_IN                    (CMP_RX_N),
	.GTX0_RXP_IN                    (CMP_RX_P),

// Receive Ports - RX Elastic Buffer and Phase Alignment Ports
	.GTX0_RXDLYALIGNDISABLE_IN      (rx_dlyaligndisable),
	.GTX0_RXDLYALIGNMONENB_IN       (rx_dly_align_mon_ena),
	.GTX0_RXDLYALIGNMONITOR_OUT     (rx_dly_align_mon),
	.GTX0_RXDLYALIGNOVERRIDE_IN     (1'b0),
	.GTX0_RXDLYALIGNRESET_IN        (rx_dlyalignreset),
	.GTX0_RXENPMAPHASEALIGN_IN      (rx_enpmaphasealign),
	.GTX0_RXPMASETPHASE_IN          (rx_pmasetphase),

// Receive Ports - RX Loss-of-sync State Machine
	.GTX0_RXLOSSOFSYNC_OUT          (cmp_rx_lossofsync),

//  Receive Ports - RX PLL Ports
	.GTX0_GTXRXRESET_IN             (cmp_gtxrxreset),
	.GTX0_MGTREFCLKRX_IN            (CMP_RX_REFCLK),
	.GTX0_PLLRXRESET_IN             (1'b0),
	.RX_POLARITY_IN                 (RX_POLARITY_SWAP),
	.GTX0_RXPLLLKDET_OUT            (cmp_rx_pll_lock),
	.GTX0_RXRESETDONE_OUT           (cmp_rx_resetdone),

// Transmit Ports - TX Driver and OOB signaling
	.GTX0_TXN_OUT                   (CMP_TX_N),
	.GTX0_TXP_OUT                   (CMP_TX_P),
	.sump							(sump_crbp)
	);

//-------------------------------------------------------------------------------------------------------------------
// RXSYNC modules
//-------------------------------------------------------------------------------------------------------------------
// The RXSYNC module performs phase synchronization for all the active RX datapaths. It
// waits for the user clocks to be stable, then drives the RX phase align signals on each
// GTX. When phase synchronization is complete, it asserts SYNC_DONE
//
// Include one RX_SYNC module per Buffer bypassed RX datapath in your own design. RX_SYNC modules
// can also be shared, but when sharing, make sure to hold the module in reset until all lanes have 
// a stable clock
//-------------------------------------------------------------------------------------------------------------------

	GTX_RX_SYNC  ugtx_rx_sync
	(
	.RXENPMAPHASEALIGN	(rx_enpmaphasealign),	// Out
	.RXPMASETPHASE		(rx_pmasetphase),		// Out
	.RXDLYALIGNDISABLE	(rx_dlyaligndisable),	// Out
    .RXDLYALIGNOVERRIDE	(rx_dlyalignoverride),	// Out	JK: signalt not used
	.RXDLYALIGNRESET	(rx_dlyalignreset),		// Out
	.SYNC_DONE			(RX_SYNC_DONE),			// Out
	.USER_CLK			(CMP_RX_CLK160),		// In
	.RESET				(rx_sync_rst)			// In
	);

	assign rx_sync_rst = !cmp_rxresetdone_r2;

	always @(posedge CMP_RX_CLK160 or negedge cmp_rx_resetdone) begin
	if(!cmp_rx_resetdone) begin
	cmp_rxresetdone_r	<= 1'b0;
	cmp_rxresetdone_r2	<= 1'b0;
	end
	else begin
	cmp_rxresetdone_r	<= cmp_rx_resetdone;
	cmp_rxresetdone_r2	<= cmp_rxresetdone_r;
	end
	end

	always @(posedge CMP_RX_CLK160) begin
	if(cmp_rx_byte_is_aligned) begin
	cmp_rx_calign_m	<= 1'b0;
	cmp_rx_calign_p	<= 1'b0;
	end
	else begin
	cmp_rx_calign_m	<= 1'b1;
	cmp_rx_calign_p	<= 1'b1;
	end
	end

//-------------------------------------------------------------------------------------------------------------------
// Receive data
//-------------------------------------------------------------------------------------------------------------------
	assign sync_match = (cmp_rx_isk==2'b01);
	assign lt_trg     = (cmp_rx_isk==2'b01) && (cmp_rx_data[7:0] == 8'hFC);

	always @(posedge CMP_RX_CLK160) begin
	CEW1	<= sync_match;
	CEW2	<= CEW1;
	CEW3	<= CEW2;
	CEW0	<= CEW3;
	end

	always @(posedge CMP_RX_CLK160) begin
	if(CEW0)	begin
				lt_trg_reg <= lt_trg;
				end
	if(CEW1)	begin
				w1_reg			<=  cmp_rx_data;
				NONZERO_WORD[1]	<= |cmp_rx_data;
				end
	if(CEW2) begin
				w2_reg			<=  cmp_rx_data;
				NONZERO_WORD[2]	<= |cmp_rx_data;
				end
	if(CEW3) begin
				RCV_DATA		<= {cmp_rx_data,w2_reg,w1_reg};
				LTNCY_TRIG		<=  lt_trg_reg;
				NONZERO_WORD[3]	<= |cmp_rx_data;
				end
	end

//-------------------------------------------------------------------------------------------------------------------
// Pseudo-random bit signaling
//-------------------------------------------------------------------------------------------------------------------
	gtx_prbs_rx_c160 #(.start_pattern(48'hFFFFFF000000)) ugtx_prbs_rx1_c160
	(
	.REC_CLK	(CMP_RX_CLK160),	// In
	.CE1		(CEW1),				// In
	.CE3		(CEW3),				// In
	.RST		(RST),				// In
	.RCV_DATA	(RCV_DATA),			// In
	.STRT_MTCH	(STRT_MTCH),		// Out
	.VALID		(VALID),			// Out
	.MATCH		(MATCH)				// Out
	);

//-------------------------------------------------------------------------------------------------------------------
// Chipscope
//-------------------------------------------------------------------------------------------------------------------
	generate

	if (USE_CHIPSCOPE==1) begin : chipscope

	wire [15:0]		cmp_rx_async_in;
	wire [7:0]		cmp_rx_async_out;
	wire [143:0]	cmp_rx_la_data;
	wire [24:0]		cmp_rx_la_trig;
	wire [7:0]		dummy_sigs;
	wire cmp_gtxrxreset_csp;

/*JK
	cmp_rx_vio cmp_rx_vio1
	(
	.CONTROL	(CMP_RX_VIO_CNTRL),		// INOUT BUS [35:0]
	.ASYNC_IN	(cmp_rx_async_in),		// IN BUS [15:0]
	.ASYNC_OUT	(cmp_rx_async_out)		// OUT BUS [7:0]
	);
*/

// ASYNC_IN [15:0]
	assign cmp_rx_async_in[0]     = cmp_rx_byte_is_aligned;
	assign cmp_rx_async_in[1]     = cmp_rx_resetdone;
	assign cmp_rx_async_in[2]     = cmp_rx_pll_lock;
	assign cmp_rx_async_in[3]     = RST;
	assign cmp_rx_async_in[4]     = MATCH;
	assign cmp_rx_async_in[5]     = VALID;
	assign cmp_rx_async_in[6]     = cmp_gtxrxreset;
	assign cmp_rx_async_in[7]     = cmp_rx_rec_lock;
	assign cmp_rx_async_in[8]     = RX_SYNC_DONE;
	assign cmp_rx_async_in[9]     = 0;	// CMP_SD;
	assign cmp_rx_async_in[10]    = 1'b0;
	assign cmp_rx_async_in[11]    = 1'b0;
	assign cmp_rx_async_in[12]    = 1'b0;
	assign cmp_rx_async_in[13]    = 1'b0;
	assign cmp_rx_async_in[14]    = 1'b0;
	assign cmp_rx_async_in[15]    = 1'b0;

// ASYNC_OUT [7:0]
	assign rx_dly_align_mon_ena = cmp_rx_async_out[0];
	assign cmp_gtxrxreset_csp   = cmp_rx_async_out[1];
	assign dummy_sigs[7:2]      = cmp_rx_async_out[7:2];

/*JK		 
	cmp_rx_la cmp_rx_la_i
	(
	.CONTROL(CMP_RX_LA_CNTRL),
	.CLK	(CMP_RX_CLK160),
	.DATA	(cmp_rx_la_data),	// IN BUS [143:0]
	.TRIG0	(cmp_rx_la_trig)	// IN BUS [23:0]
	);
*/
// LA Data [143:0]
	assign cmp_rx_la_data[0]		= RST;
	assign cmp_rx_la_data[1]		= cmp_gtxrxreset;
	assign cmp_rx_la_data[2]		= cmp_rx_resetdone;
	assign cmp_rx_la_data[3]		= cmp_rx_pll_lock;
	assign cmp_rx_la_data[4]		= cmp_rx_rec_lock;
	assign cmp_rx_la_data[20:5]		= cmp_rx_data;
	assign cmp_rx_la_data[22:21]	= cmp_rx_isc;
	assign cmp_rx_la_data[24:23]	= cmp_rx_isk;
	assign cmp_rx_la_data[26:25]	= cmp_rx_disperr;
	assign cmp_rx_la_data[28:27]	= cmp_rx_notintable;
	assign cmp_rx_la_data[29]		= CEW0;
	assign cmp_rx_la_data[30]		= CEW1;
	assign cmp_rx_la_data[31]		= CEW2;
	assign cmp_rx_la_data[32]		= CEW3;
	assign cmp_rx_la_data[48:33]	= w1_reg;
	assign cmp_rx_la_data[64:49]	= w2_reg;
	assign cmp_rx_la_data[112:65]	= RCV_DATA;
	assign cmp_rx_la_data[113]		= sync_match;
	assign cmp_rx_la_data[114]		= STRT_MTCH;
	assign cmp_rx_la_data[115]		= VALID;
	assign cmp_rx_la_data[116]		= MATCH;

	assign cmp_rx_la_data[117]		= cmp_rx_commadet;
	assign cmp_rx_la_data[118]		= cmp_rx_calign_m;
	assign cmp_rx_la_data[119]		= cmp_rx_calign_p;
	assign cmp_rx_la_data[121:120]	= cmp_rx_lossofsync;
	assign cmp_rx_la_data[122]		= rx_enpmaphasealign;
	assign cmp_rx_la_data[123]		= rx_pmasetphase;
	assign cmp_rx_la_data[124]		= rx_dlyaligndisable;
	assign cmp_rx_la_data[125]		= rx_dlyalignreset;
	assign cmp_rx_la_data[126]		= rx_sync_rst;
	assign cmp_rx_la_data[127]		= RX_SYNC_DONE;
	assign cmp_rx_la_data[128]		= rx_dly_align_mon_ena;
	assign cmp_rx_la_data[136:129]	= rx_dly_align_mon;
	assign cmp_rx_la_data[137]		= cmp_rx_byte_is_aligned;
	assign cmp_rx_la_data[138]		= 1'b0;
	assign cmp_rx_la_data[139]		= 1'b0;
	assign cmp_rx_la_data[140]		= 1'b0;
	assign cmp_rx_la_data[141]		= 1'b0;
	assign cmp_rx_la_data[142]		= 1'b0;
	assign cmp_rx_la_data[143]		= 1'b0;

// LA Trigger [23:0]
	assign cmp_rx_la_trig[0]		= RST;
	assign cmp_rx_la_trig[1]		= cmp_gtxrxreset;
	assign cmp_rx_la_trig[2]		= cmp_rx_rec_lock;
	assign cmp_rx_la_trig[3]		= cmp_rx_pll_lock;
	assign cmp_rx_la_trig[4]		= cmp_rx_resetdone;
	assign cmp_rx_la_trig[5]		= cmp_rx_byte_is_aligned;
	assign cmp_rx_la_trig[6]		= rx_sync_rst;
	assign cmp_rx_la_trig[7]		= RX_SYNC_DONE;
	assign cmp_rx_la_trig[8]		= cmp_rx_commadet;
	assign cmp_rx_la_trig[9]		= cmp_rx_calign_m;
	assign cmp_rx_la_trig[10]		= cmp_rx_calign_p;
	assign cmp_rx_la_trig[12:11]	= cmp_rx_lossofsync;
	assign cmp_rx_la_trig[13]		= cmp_rx_commadet;
	assign cmp_rx_la_trig[14]		= cmp_rx_calign_m;
	assign cmp_rx_la_trig[15]		= cmp_rx_calign_p;
	assign cmp_rx_la_trig[16]		= sync_match;
	assign cmp_rx_la_trig[17]		= VALID;
	assign cmp_rx_la_trig[18]		= MATCH;
	assign cmp_rx_la_trig[19]		= STRT_MTCH;
	assign cmp_rx_la_trig[20]		= 1'b0;
	assign cmp_rx_la_trig[21]		= 1'b0;
	assign cmp_rx_la_trig[22]	 	= 1'b0;
	assign cmp_rx_la_trig[23] 		= 1'b0;
	assign cmp_gtxrxreset			= cmp_gtxrxreset_csp;
	end

	else begin : no_chipscope
	assign rx_dly_align_mon_ena	= 1'b0;
	assign cmp_gtxrxreset_csp	= 1'b0;
	assign cmp_gtxrxreset		= 1'b0;
	end
	endgenerate

//-------------------------------------------------------------------------------------------------------------------
// Unused signals
//-------------------------------------------------------------------------------------------------------------------
	assign sump = 
	rx_dlyalignoverride 		| 
	sump_crbp					|
	CMP_TX_N					|
	CMP_TX_P					|
	(|cmp_rx_isc[1:0])			|
	(|cmp_rx_disperr[1:0])		|
	(|cmp_rx_notintable[1:0])	|
	(|rx_dly_align_mon[7:0])	|
	(|cmp_rx_lossofsync[1:0])	|
	cmp_rx_commadet				|
	cmp_rx_pll_lock;

	endmodule
