
//=============Synchronizer============\\

module dff_sync  #(parameter WIDTH = 4)(
					input clk,
					input resetb,
					input logic   [WIDTH- 1 :0]   d,
					output logic [WIDTH- 1 :0]    q
					);
							
logic [WIDTH- 1:0]  q1;
logic [WIDTH- 1:0]  q2;

always_ff @ (posedge clk or negedge resetb)
		begin
		if(~resetb)
			begin
				q1 <= {WIDTH{1'b0}};
				q2 <= {WIDTH{1'b0}};
			end
		else
			begin
				q1 <= d;
				q2 <= q1;
			end
		end
		
assign q = q2;
							
endmodule

//============BIN 2 GRAY ================\\


module binary2grey #(parameter WIDTH = 4)
			(
			input logic 	[WIDTH-1:0] binary,
			output logic 	[WIDTH-1:0] grey
			);

assign  grey    =  {1'b0,binary[WIDTH-1:1]}^binary;

endmodule

//============GRAY 2 BIN ================\\

module grey2binary #(parameter WIDTH = 4)
			(
			input logic 		[WIDTH-1:0] grey,
			output logic 	[WIDTH-1:0] binary
			);

generate
genvar  i;
    for(i=0; i<WIDTH-1; i=i+1)
        assign  binary[i]  =   grey[i]^binary[i+1];
endgenerate


assign  binary[WIDTH-1]   =   grey[WIDTH-1];

endmodule

//=============FIFO===================\\

module async_FIFO (
		input logic [7:0] din,
		output  logic [7:0] dout,
		input logic wr,
		input logic rd,
		output logic full,
		output logic empty,
		input logic clk_rd,
		input logic clk_wr,
		input logic resetb_rd,
		input logic resetb_wr
		);
							
logic [7:0] mem [15:0]; 	//memory allocution


//=======WRITE LOGIC======	

logic [3:0] wr_ptr_bin ;
logic [3:0] wr_ptr_grey ;
logic [3:0] wr_next_ptr;

grey2binary #(.WIDTH(4)) G2B_wr_ptr (.grey(wr_ptr_grey)   ,.binary(wr_ptr_bin) );
binary2grey #(.WIDTH(4)) B2G_wr_ptr_p1 ( .binary(wr_ptr_bin+4'b0001) , .grey(wr_next_ptr)  );

always_ff @(posedge clk_wr or negedge resetb_wr) // wr ptr
		if (~resetb_wr)
			wr_ptr_grey <= 4'b0000;
		else if (wr & ~full)
			begin
			mem[wr_ptr_bin] <= din;
			wr_ptr_grey <= wr_next_ptr;
			end
	
//=====READ LOGIC=========
			
logic [3:0] rd_ptr_bin ;	
logic [3:0] rd_ptr_grey ;				
logic [3:0] rd_next_ptr;

grey2binary  #(.WIDTH(4)) G2B_rd_ptr (.grey(rd_ptr_grey)   ,.binary(rd_ptr_bin) );
binary2grey #(.WIDTH(4)) B2G_rd_ptr_p1 ( .binary(rd_ptr_bin+4'b0001) , .grey(rd_next_ptr)  );

always_ff @(posedge clk_rd or negedge resetb_rd) // rd ptr
		if (~resetb_rd)
			rd_ptr_grey <= 4'b1000;
		else if (rd & ~empty)
			begin
				dout = mem[rd_ptr_bin];
				rd_ptr_grey <= rd_next_ptr;
			end

//=======READ / WRITE CD  Managment=======

logic [3:0] sync_RD_to_WR_out;
logic [3:0] out_G2B_RD_to_WR;

dff_sync       #(.WIDTH(4)) RD_to_WR_Sync (.clk(clk_wr),.resetb(resetb_wr),.d(rd_ptr_grey),.q(sync_RD_to_WR_out));
grey2binary  #(.WIDTH(4)) G2B_RD_to_WR_SYNC (.grey(sync_RD_to_WR_out)   ,.binary(out_G2B_RD_to_WR) );

//======WRITE / READ CDC Managment ========

logic [3:0] sync_WR_to_RD_out;
logic [3:0] out_G2B_WR_to_RD;

dff_sync       #(.WIDTH(4)) WR_to_RD_Sync (.clk(clk_rd),.resetb(resetb_rd),.d(wr_ptr_grey),.q(sync_WR_to_RD_out));
grey2binary  #(.WIDTH(4)) G2B_WR_to_RD_SYNC (.grey(sync_WR_to_RD_out)  ,.binary(out_G2B_WR_to_RD) );	
	
//========== MEMORY Managment== =========

assign full  = (out_G2B_RD_to_WR   ==      wr_ptr_bin +4'b0001 );
assign empty = (out_G2B_WR_to_RD  ==    rd_ptr_bin  +4'b0001 );


endmodule
				
//=================================================\\
//==================MAIN MODULE====================\\
//=================================================\\


module sync_bridge (
			input logic clka, 
			input logic clkb, 
			input logic resetb_clkb,			
			input logic  [7:0] din_clka,
			output logic [7:0] dout_clkb,
			input logic data_req_clkb,
			output logic data_req_clka, 	
			input logic data_valid_clka,
			output logic data_valid_clkb								
			);			
logic full;
logic ack;
logic out_from_extend;
logic out_from_sync_A2B;	
logic empty_sig_connector;
logic resetb_wr_connector;


//============Extend + Synchronizer ========

logic data_req_clka_temp;	
logic [4:0]counter_reg_clka;
dff_sync 	#(.WIDTH(1)) B2A_SYNC (.d(data_req_clkb),	.q(data_req_clka_temp),	.clk(clka),	.resetb(resetb_clka) );			
			

always_ff@(posedge clka or negedge resetb_wr_connector)
		if(~resetb_wr_connector)
			counter_reg_clka <= 5'b0;
		else if(counter_reg_clka == 5'b10111)  
			counter_reg_clka <= 5'b0;
		else if(data_req_clka | (counter_reg_clka == 5'b0 & data_req_clka_temp))	
			counter_reg_clka <= counter_reg_clka + 5'b1;
			
assign data_req_clka = counter_reg_clka != 5'b0;

//============FF EMPTY
always_ff @(posedge clkb or negedge resetb_clkb)
	begin
	if (~resetb_clkb)
		data_valid_clkb <= 1'b0;
	else
		data_valid_clkb <= ~empty_sig_connector ;
	end			
			
			
//====resetb synchronizer=========
								
dff_sync  	#(.WIDTH(1)) RESET_SYNC ( .d(1'b1),	.q(resetb_wr_connector), .clk(clkb), .resetb(resetb_clkb)  );


//============FIFO==========																						
									
async_FIFO 	FIFO (
			 .din(din_clka),
			 .dout(dout_clkb),
			 .wr(data_valid_clka),
			 .rd(1'b1),
			 .full(full),
			 .empty(empty_sig_connector),
			 .clk_rd(clkb),
			 .clk_wr(clka),
			 .resetb_rd(resetb_clkb),
			 .resetb_wr(resetb_wr_connector)
			);				

endmodule








