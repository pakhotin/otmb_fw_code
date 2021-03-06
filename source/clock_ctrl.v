`timescale 1ns / 1ps
//`define DEBUG_CLOCK 1
//---------------------------------------------------------------------------------------------------------------------
//	Virtex6 Clock PLLs
//---------------------------------------------------------------------------------------------------------------------
//	02/13/2013	Initial Virtex-6
//	02/20/2013	Expand to 7 DCFEBs
//	02/28/2013	Remove buffer from dps feedback, source dps clock from main pll
//	05/02/2013	Add clock_2x and clock_lac for ALCT muonic posneg stages
//---------------------------------------------------------------------------------------------------------------------
	module clock_ctrl
	(
// Clock inputs
	tmb_clock0,
	tmb_clock0d,
	tmb_clock1,
	alct_rxclock,
	alct_rxclockd,
	mpc_clock,
	dcc_clock,
	rpc_sig,

// Main clock outputs
	clock,
	clock_2x,
	clock_lac,
	clock_vme,

// Phase delayed clocks
	clock_alct_rxd,
	clock_alct_txd,
	clock_cfeb0_rxd,
	clock_cfeb1_rxd,
	clock_cfeb2_rxd,
	clock_cfeb3_rxd,
	clock_cfeb4_rxd,
	clock_cfeb5_rxd,
	clock_cfeb6_rxd,

// Global reset
	mmcm_reset,
	global_reset_en,
	global_reset,
	clock_lock_lost_err,

// Clock DCM lock status
	lock_tmb_clock0,
	lock_tmb_clock0d,
	lock_alct_rxclockd,
	lock_mpc_clock,
	lock_dcc_clock,
	lock_rpc_rxalt1,
	lock_tmb_clock1,
	lock_alct_rxclock,

// Phaser VME control/status ports
	dps_fire,
	dps_reset,
	dps_busy,
	dps_lock,

	dps0_phase,
	dps1_phase,
	dps2_phase,
	dps3_phase,
	dps4_phase,
	dps5_phase,
	dps6_phase,
	dps7_phase,
	dps8_phase,

	dps0_sm_vec,
	dps1_sm_vec,
	dps2_sm_vec,
	dps3_sm_vec,
	dps4_sm_vec,
	dps5_sm_vec,
	dps6_sm_vec,
	dps7_sm_vec,
	dps8_sm_vec

// Debug
`ifdef DEBUG_CLOCK
	,psen_alct_rxd
	,psincdec_alct_rxd
	,psdone_alct_rxd
`endif
	);
//------------------------------------------------------------------------------------------------------------------
// Generic
//------------------------------------------------------------------------------------------------------------------
	parameter MXDPS=9;							// 2 ALCT + 7 DCFEB

//------------------------------------------------------------------------------------------------------------------
// Ports
//------------------------------------------------------------------------------------------------------------------
// Clock inputs
	input				tmb_clock0;				// 40MHz clock bypasses 3D3444 and loads Mez PROMs, chip bottom
	input				tmb_clock0d;			// 40MHz clock bypasses 3D3444 and loads Mez PROMs, chip top
	input				tmb_clock1;				// 40MHz clock with 3D3444 delay
	input				alct_rxclock;			// 40MHz ALCT receive data clock with 3D3444 delay, chip bottom
	input				alct_rxclockd;			// 40MHz ALCT receive data clock with 3D3444 delay, chip top
	input				mpc_clock;				// 40MHz MPC clock
	input				dcc_clock;				// 40MHz Duty cycle corrected clock with 3D3444 delay
	input				rpc_sig;				// 40MHz Unused

// Main clock outputs
	output				clock;					// 40MHz global TMB clock 1x
	output				clock_2x;				// 80MHz commutator clock
	output				clock_lac;				// 40MHz logic accessible clock
	output				clock_vme;				// 10MHz global VME clock 1/4x

// Phase delayed clocks
	output				clock_alct_rxd;			// 40MHz ALCT  receive  data clock 1x
	output				clock_alct_txd;			// 40MHz ALCT  transmit data clock 1x
	output				clock_cfeb0_rxd;		// 40MHz CFEB0 receive  data clock 1x
	output				clock_cfeb1_rxd;		// 40MHz CFEB1 receive  data clock 1x
	output				clock_cfeb2_rxd;		// 40MHz CFEB2 receive  data clock 1x
	output				clock_cfeb3_rxd;		// 40MHz CFEB3 receive  data clock 1x
	output				clock_cfeb4_rxd;		// 40MHz CFEB4 receive  data clock 1x
	output				clock_cfeb5_rxd;		// 40MHz CFEB5 receive  data clock 1x
	output				clock_cfeb6_rxd;		// 40MHz CFEB6 receive  data clock 1x

// Global reset
	input				mmcm_reset;				// PLL reset input for simulation
	input				global_reset_en;		// Enable global reset on lock_lost
	output				global_reset;			// Global reset, asserted until main DLL locks
	output				clock_lock_lost_err;	// 40MHz main clock lost lock FF

// Clock DCM lock status
	output				lock_tmb_clock0;		// DCM lock status
	output				lock_tmb_clock0d;		// DCM lock status
	output				lock_alct_rxclockd;		// DCM lock status
	output				lock_mpc_clock;			// DCM lock status
	output				lock_dcc_clock;			// DCM lock status
	output				lock_rpc_rxalt1;		// DCM lock status
	output				lock_tmb_clock1;		// DCM lock status
	output				lock_alct_rxclock;		// DCM lock status

// Phaser VME control/status ports
	input	[MXDPS-1:0]	dps_fire;				// Set new phase
	input	[MXDPS-1:0]	dps_reset;				// VME Reset current phase
	output	[MXDPS-1:0]	dps_busy;				// Phase shifter busy
	output	[MXDPS-1:0]	dps_lock;				// PLL lock status

	input	[7:0]		dps0_phase;				// Phase to set, 0-255
	input	[7:0]		dps1_phase;				// Phase to set, 0-255
	input	[7:0]		dps2_phase;				// Phase to set, 0-255
	input	[7:0]		dps3_phase;				// Phase to set, 0-255
	input	[7:0]		dps4_phase;				// Phase to set, 0-255
	input	[7:0]		dps5_phase;				// Phase to set, 0-255
	input	[7:0]		dps6_phase;				// Phase to set, 0-255
	input	[7:0]		dps7_phase;				// Phase to set, 0-255
	input	[7:0]		dps8_phase;				// Phase to set, 0-255

	output	[2:0]		dps0_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps1_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps2_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps3_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps4_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps5_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps6_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps7_sm_vec;			// Phase shifter machine state
	output	[2:0]		dps8_sm_vec;			// Phase shifter machine state

// Debug
`ifdef DEBUG_CLOCK
	output				psen_alct_rxd;			// Dps phase shift enable
	output				psincdec_alct_rxd;		// Dps phase increment/decrement
	output				psdone_alct_rxd;		// Dps done
`endif

//------------------------------------------------------------------------------------------------------------------
// Global clock buffers
//------------------------------------------------------------------------------------------------------------------
// PLL feedback and fanout buffers
	IBUFG uibufg_19p      (.I(tmb_clock0    ),.O(tmb_clock0_ibufg));
	BUFG  ubufg_pll_1x    (.I(clock_mmcm    ),.O(clock           ));
	BUFG  ubufg_pll_2x    (.I(clock_2x_mmcm ),.O(clock_2x        ));
	BUFG  ubufg_pll_vme   (.I(clock_vme_mmcm),.O(clock_vme       ));
	BUFG  ubufg_pll_dps   (.I(clock_dps_mmcm),.O(clock_dps       ));
	BUFG  ubufg_pll_lac   (.I(clock_90_mmcm ),.O(clock_90        ));

//------------------------------------------------------------------------------------------------------------------
// Main PLL generates clocks at 1x=40MHz, 2x=80MHz, 1/4x=10MHz
//------------------------------------------------------------------------------------------------------------------
	MMCM_ADV # (
	.CLKIN1_PERIOD			(25.0),				// Primary   input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
	.CLKIN2_PERIOD			(),					// Secondary input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
	.REF_JITTER1			(0.010),			// Primary   reference input jitter in UI (0.000-0.999)
	.REF_JITTER2			(),					// Secondary reference input jitter in UI (0.000-0.999)

	.CLKOUT4_CASCADE		(0),			// Cascade CLKOUT4 counter with CLKOUT6 (TRUE/FALSE)
	.CLOCK_HOLD				(0),			// Hold VCO Frequency (TRUE/FALSE)
	.COMPENSATION			("ZHOLD"),			// "ZHOLD", "INTERNAL", "EXTERNAL", "CASCADE" or "BUF_IN" 
	.STARTUP_WAIT			(0),			// Not supported. Must be set to FALSE

	.DIVCLK_DIVIDE			(1),				// Master division value (1-80)
	.CLKFBOUT_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKFBOUT_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.CLKOUT0_DUTY_CYCLE		(0.500),			// Duty cycle (0.01-0.99)
	.CLKOUT0_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00) -57.6 degrees = -4ns
	.CLKOUT0_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.CLKOUT1_DUTY_CYCLE		(0.500),			// Duty cycle (0.01-0.99)
	.CLKOUT1_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKOUT1_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.CLKOUT2_DUTY_CYCLE		(0.500),			// Duty cycle (0.01-0.99)
	.CLKOUT2_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKOUT2_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.CLKOUT3_DUTY_CYCLE		(0.500),			// Duty cycle (0.01-0.99)
	.CLKOUT3_PHASE			(90.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKOUT3_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.BANDWIDTH				("OPTIMIZED"),		// Jitter programming ("HIGH","LOW","OPTIMIZED")
	.CLKFBOUT_MULT_F		(25.000),			// Multiply all CLKOUT (5.0-64.0)		1x   40MHz clock
	.CLKOUT0_DIVIDE_F		(12.500),			// Divide amount (1.000-128.000) 		2x   80MHz clock
	.CLKOUT1_DIVIDE			(100),				// Divide amount (1.000-128.000) 		1/4x 10MHz clock
	.CLKOUT2_DIVIDE			(25),				// Divide amount (1.000-128.000) 		1x   40MHz clock
	.CLKOUT3_DIVIDE			(25)				// Divide amount (1.000-128.000) 		1x   40MHz clock

	) ummcm_main (

	.CLKIN1					(tmb_clock0_ibufg),	// In	1-bit Primary clock
 	.CLKIN2					(1'b0),				// In	1-bit Secondary clock
	.CLKINSEL				(1'b1),				// In	1-bit Clock select: 1=primary 0=secondary
        
	.RST					(mmcm_reset),		// In	1-bit Reset
	.PWRDWN					(1'b0),				// In	1-bit Power-down
	.LOCKED					(lock_tmb_clock0),	// Out	1-bit LOCK status
	.CLKFBSTOPPED			(),					// Out	1-bit Feedback clock stopped
	.CLKINSTOPPED			(),					// Out	1-bit Input    clock stopped

	.CLKFBIN				(clock),			// In	1-bit Feedback clock input
	.CLKFBOUT				(clock_mmcm),		// Out	1-bit Feedback clock output
	.CLKFBOUTB				(),					// Out	1-bit Inverted CLKFBOUT

	.CLKOUT0				(clock_2x_mmcm),	// Out	1-bit CLKOUT0
	.CLKOUT0B				(),					// Out	1-bit CLKOUT0 Inverted
	.CLKOUT1				(clock_vme_mmcm),	// Out	1-bit CLKOUT1
	.CLKOUT1B				(),					// Out	1-bit CLKOUT1 Inverted
	.CLKOUT2				(clock_dps_mmcm),	// Out	1-bit CLKOUT2
	.CLKOUT2B				(),					// Out	1-bit CLKOUT2 Inverted
	.CLKOUT3				(clock_90_mmcm),	// Out	1-bit CLKOUT3
	.CLKOUT3B				(),					// Out	1-bit CLKOUT3 Inverted
	.CLKOUT4				(),					// Out	1-bit CLKOUT4
	.CLKOUT5				(),					// Out	1-bit CLKOUT5
	.CLKOUT6				(),					// Out	1-bit CLKOUT6

	.DCLK					(1'b0),				// In	1-bit DRP clock Dynamic Reconfiguaration Port
	.DEN					(1'b0),				// In	1-bit DRP enable
	.DWE					(),					// In	1-bit DRP write enable
	.DADDR					(7'h0),				// In	7-bit DRP address
	.DI						(16'h0),			// In  16-bit DRP data
	.DO						(),					// Out 16-bit DRP data
	.DRDY					(),					// Out	1-bit DRP ready
 
	.PSCLK					(),					// In	1-bit Phase shift clock
	.PSEN					(),					// In	1-bit Phase shift enable
  	.PSINCDEC				(),					// In	1-bit Phase shift increment/decrement
	.PSDONE					()					// Out	1-bit Phase shift done
 	);

//------------------------------------------------------------------------------------------------------------------
// Logic Accessible Clock copy of 40MHz main clock, synchronized to clock_2x global net
//------------------------------------------------------------------------------------------------------------------
	FDRSE #(.INIT(1'b0)) ulac (
	.Q	(clock_lac),							// Out	Data
	.C	(clock_2x),								// In	Clock
	.CE	(lock_tmb_clock0),						// In	Clock enable
	.D	(!clock_90),							// In	Data
	.R	(1'b0),									// In	Synchronous reset
	.S	(1'b0));								// In	Synchronous set

//------------------------------------------------------------------------------------------------------------------
// Phase step ROMs translate 256 steps per cycle into 1400 steps per cycle
//------------------------------------------------------------------------------------------------------------------
	reg [10:0] rom [255:0];	
	
	integer iadr;

	always @* begin	
	for (iadr=0; iadr<=255; iadr=iadr+1) begin
	rom[iadr] = $rtoi((iadr*1400.0/256.0)+0.5);
	$display ("adr=%d  data=%d",iadr,rom[iadr]);
	end
	end

//------------------------------------------------------------------------------------------------------------------
// Generate Digital Phase Shifters
//------------------------------------------------------------------------------------------------------------------
// Map ports for generated instances
	wire [MXDPS-1:0]	dps_clock_fbi;
	wire [MXDPS-1:0]	dps_clock_fbo;
	wire [MXDPS-1:0]	dps_clock_out;
	wire [MXDPS-1:0]	dps_clock;

	wire [MXDPS-1:0]	dps_psen;
	wire [MXDPS-1:0]	dps_psincdec;
	wire [MXDPS-1:0]	dps_psdone;

	wire [10:0]			dps_phase  [MXDPS-1:0];
	wire [2:0]			dps_sm_vec [MXDPS-1:0];
	
	assign dps_phase[0][10:0] = rom[dps0_phase[7:0]];
	assign dps_phase[1][10:0] = rom[dps1_phase[7:0]];
	assign dps_phase[2][10:0] = rom[dps2_phase[7:0]];
	assign dps_phase[3][10:0] = rom[dps3_phase[7:0]];
	assign dps_phase[4][10:0] = rom[dps4_phase[7:0]];
	assign dps_phase[5][10:0] = rom[dps5_phase[7:0]];
	assign dps_phase[6][10:0] = rom[dps6_phase[7:0]];
	assign dps_phase[7][10:0] = rom[dps7_phase[7:0]];
	assign dps_phase[8][10:0] = rom[dps8_phase[7:0]];

	assign dps0_sm_vec[2:0]   = dps_sm_vec[0][2:0];
	assign dps1_sm_vec[2:0]   = dps_sm_vec[1][2:0];
	assign dps2_sm_vec[2:0]   = dps_sm_vec[2][2:0];
	assign dps3_sm_vec[2:0]   = dps_sm_vec[3][2:0];
	assign dps4_sm_vec[2:0]   = dps_sm_vec[4][2:0];
	assign dps5_sm_vec[2:0]   = dps_sm_vec[5][2:0];
	assign dps6_sm_vec[2:0]   = dps_sm_vec[6][2:0];
	assign dps7_sm_vec[2:0]   = dps_sm_vec[7][2:0];
	assign dps8_sm_vec[2:0]   = dps_sm_vec[8][2:0];

	assign clock_alct_rxd     = dps_clock[0];
	assign clock_alct_txd     = dps_clock[1];
	assign clock_cfeb0_rxd    = dps_clock[2];
	assign clock_cfeb1_rxd    = dps_clock[3];
	assign clock_cfeb2_rxd    = dps_clock[4];
	assign clock_cfeb3_rxd    = dps_clock[5];
	assign clock_cfeb4_rxd    = dps_clock[6];
	assign clock_cfeb5_rxd    = dps_clock[7];
	assign clock_cfeb6_rxd    = dps_clock[8];

// PLL phase shifters
	genvar i;
	generate
	for (i=0; i<=MXDPS-1; i=i+1) begin: dps

	assign dps_clock_fbi[i] = dps_clock_fbo[i];
	BUFG ubufg_out(.I(dps_clock_out[i]), .O(dps_clock[i]));

	MMCM_ADV # (
	.CLKIN1_PERIOD			(25.0),				// Primary   input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
	.CLKIN2_PERIOD			(),					// Secondary input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz)
	.REF_JITTER1			(0.010),			// Primary   reference input jitter in UI (0.000-0.999)
	.REF_JITTER2			(),					// Secondary reference input jitter in UI (0.000-0.999)

	.CLKOUT4_CASCADE		(0),			// Cascade CLKOUT4 counter with CLKOUT6 (TRUE/FALSE)
	.CLOCK_HOLD				(0),			// Hold VCO Frequency (TRUE/FALSE)
	.COMPENSATION			("ZHOLD"),			// "ZHOLD", "INTERNAL", "EXTERNAL", "CASCADE" or "BUF_IN" 
	.STARTUP_WAIT			(0),			// Not supported. Must be set to FALSE

	.DIVCLK_DIVIDE			(1),				// Master division value (1-80)
	.CLKFBOUT_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKFBOUT_USE_FINE_PS	(0),			// Fine phase shift enable (TRUE/FALSE)

	.CLKOUT0_DUTY_CYCLE		(0.500),			// Duty cycle (0.01-0.99)
	.CLKOUT0_PHASE			(0.000),			// Phase offset degrees of CLKFB (0.00-360.00)
	.CLKOUT0_USE_FINE_PS	(1),			// Fine phase shift enable (TRUE/FALSE)

	.BANDWIDTH				("OPTIMIZED"),		// Jitter programming ("HIGH","LOW","OPTIMIZED")
	.CLKFBOUT_MULT_F		(25.000),			// Multiply all CLKOUT (5.0-64.0)		1x   40MHz clock
	.CLKOUT0_DIVIDE_F		(25.000)			// Divide amount (1.000-128.000) 		1x   40MHz clock

	) ummcm_dps (

	.CLKIN1					(clock_dps),		// In	1-bit Primary clock
 	.CLKIN2					(1'b0),				// In	1-bit Secondary clock
	.CLKINSEL				(1'b1),				// In	1-bit Clock select: 1=primary 0=secondary
        
	.RST					(dps_reset[i]),		// In	1-bit Reset
	.PWRDWN					(1'b0),				// In	1-bit Power-down
	.LOCKED					(dps_lock[i]),		// Out	1-bit LOCK status
	.CLKFBSTOPPED			(),					// Out	1-bit Feedback clock stopped
	.CLKINSTOPPED			(),					// Out	1-bit Input    clock stopped

	.CLKFBIN				(dps_clock_fbi[i]),	// In	1-bit Feedback clock input
	.CLKFBOUT				(dps_clock_fbo[i]),	// Out	1-bit Feedback clock output	1x 40MHz
	.CLKFBOUTB				(),					// Out	1-bit Inverted CLKFBOUT

	.CLKOUT0				(dps_clock_out[i]),	// Out	1-bit CLKOUT0
	.CLKOUT0B				(),					// Out	1-bit CLKOUT0 Inverted
	.CLKOUT1				(),					// Out	1-bit CLKOUT1
	.CLKOUT1B				(),					// Out	1-bit CLKOUT1 Inverted
	.CLKOUT2				(),					// Out	1-bit CLKOUT2
	.CLKOUT2B				(),					// Out	1-bit CLKOUT2 Inverted
	.CLKOUT3				(),					// Out	1-bit CLKOUT3
	.CLKOUT3B				(),					// Out	1-bit CLKOUT3 Inverted
	.CLKOUT4				(),					// Out	1-bit CLKOUT4
	.CLKOUT5				(),					// Out	1-bit CLKOUT5
	.CLKOUT6				(),					// Out	1-bit CLKOUT6

	.DCLK					(1'b0),				// In	1-bit DRP clock Dynamic Reconfiguaration Port
	.DEN					(1'b0),				// In	1-bit DRP enable
	.DWE					(),					// In	1-bit DRP write enable
	.DADDR					(7'h0),				// In	7-bit DRP address
	.DI						(16'h0),			// In  16-bit DRP data
	.DO						(),					// Out 16-bit DRP data
	.DRDY					(),					// Out	1-bit DRP ready
 
	.PSCLK					(clock),			// In	1-bit Phase shift clock
	.PSEN					(dps_psen[i]),		// In	1-bit Phase shift enable
  	.PSINCDEC				(dps_psincdec[i]),	// In	1-bit Phase shift increment/decrement
	.PSDONE					(dps_psdone[i])		// Out	1-bit Phase shift done
 	);

// Digital phase shifter state machine
	phaser uphaser 
	(
	.clock			(clock),					// In	40MHz global TMB clock 1x
	.global_reset	(global_reset),				// In	Global reset, asserted until main DLL locks
	.lock_tmb		(lock_tmb_clock0),			// In	Lock state for TMB main clock DLL
	.lock_dcm		(dps_lock[i]),				// In	Lock state for this DCM
	.psen			(dps_psen[i]),				// Out	Dps phase shift enable
	.psincdec		(dps_psincdec[i]),			// Out	Dps phase increment/decrement
	.psdone			(dps_psdone[i]),			// In	Dps done
	.fire			(dps_fire[i]),				// In	VME Set new phase
	.reset			(dps_reset[i]),				// In	Reset current phase
	.phase			(dps_phase[i][10:0]),		// In	VME Phase to set, 0-1399
	.busy			(dps_busy[i]),				// Out	VME Phase shifter busy
	.dps_sm_vec		(dps_sm_vec[i][2:0])		// Out	VME Phase shifter machine state
	);
	end
	endgenerate

//------------------------------------------------------------------------------------------------------------------
// Global reset for fpga-wide state machines, asserted until main DLL locks
//------------------------------------------------------------------------------------------------------------------
	reg global_reset    = 1;
	reg startup_done	= 0;

	wire first_lock = (lock_tmb_clock0 || startup_done);

	always @(posedge clock) begin
	startup_done	<=	first_lock;												// Latches  on 1st dll lock
	global_reset	<= !first_lock || (!lock_tmb_clock0 && global_reset_en);	// Re-fires on lock lost
	end

	assign clock_lock_lost_err = (!global_reset && !lock_tmb_clock0);			// Latches  on lock lost in sync module

//------------------------------------------------------------------------------------------------------------------
// Pseudo-locked status for unused clock inputs, DDR FFs q0+q1 should add to 1 if clock is running
//------------------------------------------------------------------------------------------------------------------
	reg	[1:0]	tmb_clock0d_q	= 0;
	reg	[1:0]	alct_rxclockd_q	= 0;
	reg	[1:0]	mpc_clock_q		= 0;
	reg	[1:0]	dcc_clock_q		= 0;
	reg	[1:0]	rpc_rxalt1_q	= 0;
	reg [1:0]	tmb_clock1_q	= 0;
	reg [1:0]	alct_rxclock_q	= 0;

	always @(posedge clock)	begin
	tmb_clock0d_q[0]	<= tmb_clock0d && lock_tmb_clock0;	// Force ibuf insertion
	alct_rxclockd_q[0]	<= alct_rxclockd;
	mpc_clock_q[0]		<= mpc_clock;
	dcc_clock_q[0]		<= dcc_clock;
	rpc_rxalt1_q[0]		<= rpc_sig;
	tmb_clock1_q[0]		<= tmb_clock1;
	alct_rxclock_q[0]	<= alct_rxclock;
	end

	always @(negedge clock) begin
	tmb_clock0d_q[1]	<= tmb_clock0d && lock_tmb_clock0;	// Force ibuf insertion
	alct_rxclockd_q[1]	<= alct_rxclockd;
	mpc_clock_q[1]		<= mpc_clock;
	dcc_clock_q[1]		<= dcc_clock;
	rpc_rxalt1_q[1]		<= rpc_sig;
	tmb_clock1_q[1]		<= tmb_clock1;
	alct_rxclock_q[1]	<= alct_rxclock;
	end

	assign lock_tmb_clock0d		= ^ tmb_clock0d_q[1:0];
	assign lock_alct_rxclockd	= ^ alct_rxclockd_q[1:0];
	assign lock_mpc_clock		= ^ mpc_clock_q[1:0];
	assign lock_dcc_clock		= ^ dcc_clock_q[1:0];
	assign lock_rpc_rxalt1		= ^ rpc_rxalt1_q[1:0];
	assign lock_tmb_clock1		= ^ tmb_clock1_q[1:0];
	assign lock_alct_rxclock	= ^ alct_rxclock_q[1:0];

//------------------------------------------------------------------------------------------------------------------
	endmodule
//------------------------------------------------------------------------------------------------------------------
