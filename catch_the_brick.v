module catch_the_brick
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]

		PS2_CLK,
	   PS2_DAT
	);

	input			CLOCK_50;				//	50 MHz
	input   [3:0]   KEY;
	inout PS2_CLK,
	inout PS2_DAT,

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	wire resetn;
	assign resetn = KEY[0];

	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [6:0] x;
	wire [6:0] y;
	wire writeEn;

	wire [6:0] in_x, in_y;
	wire [2:0] in_colour, colour_draw;
	wire left, right;

	// Create an Instance of a VGA controller - there can be only on
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";

	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.


	 keyboard_inout keyboard ( .clock(CLOCK_50),.resetn(resetn), .PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT), .start(start), .left(left), .right(right));
   draw_cube draw_cube ( .clock(CLOCK_50), .resetn(resetn), .in_x(in_x), .in_y(in_y),
													.colour(in_colour), // the colour should be random
													.go(go_for_cube), // whenever the previous cube is stay at the place
													.out_x(x), .out_y(y), .out_colour(colour), .plot(writeEn));


endmodule

module draw_cube (clock, resetn, in_x, in_y, colour, go, out_x, out_y, out_colour, plot);
	input clock, resetn, go;
	input [6:0] in_x;
	input [6:0] in_y;
	input [2:0] colour;
	output [6:0] out_x;
	output [6:0] out_y;
	output [2:0] out_colour;
	output plot;

	wire ld_x_y, finish, draw;

	// Instansiate datapath
	datapath d0(
		.resetn(resetn),
		.clock(clock),
		.in_x(in_x),
		.in_y(in_y),
		.colour(colour),

		.ld_x_y(ld_x_y),
		.draw(draw),

		.out_x(out_x),
		.out_y(out_y),
		.finish(finish),
		.out_colour(out_colour)
	);

    // Instansiate FSM control
   control c0(
		.clock(clock),
		.resetn(resetn),
		.go(go),
		.finish(finish),

		.ld_x_y(ld_x_y),
		.draw(draw),
		.plot(plot)
		);

endmodule

module datapath(in_x, in_y, colour, resetn, clock, ld_x_y, draw, out_x, out_y, out_colour, finish);
	input [6:0] in_x;
	input [6:0] in_y;
	input [2:0] colour;
	input resetn, clock;
	input ld_x_y, draw;

	output  [6:0] out_x;
	output  [6:0] out_y;
	output reg [2:0] out_colour;
	output finish;

	reg [6:0] x;
	reg [6:0] y;
	reg [3:0] q_x, q_y;
	reg [1:0] times;
	wire signal_y;

	always @(posedge clock)
	begin: load
		if (!resetn) begin
			x <= 0;
			y <= 0;
			out_colour = 3'b111;
			end
		else
			begin
				if (ld_x_y) begin
					x <= in_x;
					y <= 4'b0000;
					out_colour = colour;
					end
			end
	end

	always @(posedge clock)
	begin: x_counter
		if (! resetn) begin
			q_x <= 4'b0000;
			end
		else if (draw)
			begin
				if (q_x == 4'b1001) begin
					q_x <= 0;
					end
				else
					q_x <= q_x + 1'b1;
			end
	end

	assign signal_y = (q_x == 4'b1001) ? 1: 0;

	always @(posedge clock)
	begin: y_counter
		if (! resetn) begin
			q_y <= 4'b0000;
			times <= 2'b00;
			end
		else if (signal_y)
			begin
				if (q_y == 4'b1001) begin
					q_y <= 4'b1001;
					times <= times + 1'b1;
					end
				else
					q_y <= q_y + 1'b1;
			end
	end

	assign finish = (q_y == 4'b1001 & times == 2'b10) ? 1 : 0;

	assign out_x = x + q_x;
	assign out_y = y + q_y;

endmodule

module control(clock, resetn, go, finish, ld_x_y, draw, plot);
	input resetn, clock, go, finish;
	output reg ld_x_y, draw, plot;

	reg [1:0] current_state, next_state;

	localparam Start = 2'd0,
					Load_x_y = 2'd1,
					Draw = 2'd2;

	always @(*)
	begin: state_table
		case (current_state)
			Start: next_state = go ? Load_x_y : Start;
			Load_x_y: next_state = Draw;
			Draw: next_state = finish ? Start : Draw;
			default: next_state = Start;
		endcase
	end

	always @(*)
	begin: signals
		ld_x_y = 1'b0;
		draw = 1'b0;
		plot = 1'b0;

		case (current_state)
		Load_x_y: begin
			ld_x_y = 1'b1;
			end
		Draw: begin
			draw = 1'b1;
			plot = 1'b1;
			end
		endcase
	end

always@(posedge clock)
    begin: state_FFs
        if(!resetn)
            current_state <= Start;
        else
            current_state <= next_state;
    end // state_FFS
endmodule
