module binary2grey #(parameter WIDTH = 8) (input logic 	[WIDTH-1:0] binary, output logic 	[WIDTH-1:0] grey);
assign  grey    =       {1'b0,binary[WIDTH-1:1]}^binary;
endmodule

//=====================================

module grey2binary #(parameter WIDTH = 8) (input logic 	[WIDTH-1:0] grey, output logic 	[WIDTH-1:0] binary);
generate
genvar  i;
    for(i=0; i<WIDTH-1; i=i+1)
        assign  binary[i]     =       grey[i]^binary[i+1];
endgenerate
assign  binary[WIDTH-1]     =       grey[WIDTH-1];
endmodule

//======================================

module dff_sync  #(parameter WIDTH = 4) (input clk, input reset, input logic   [WIDTH- 1 :0]   din, output logic [WIDTH- 1 :0] dout);
							
logic [WIDTH- 1:0]  q1;
logic [WIDTH- 1:0]  q2;

always_ff @ (posedge clk or negedge reset)
		begin
		if(~reset)
			begin
				q1 <= {WIDTH{1'b0}};
				q2 <= {WIDTH{1'b0}};
			end
		else
			begin
				q1 <= din;
				q2 <= q1;
			end
		end
		
assign dout = q2;
							
endmodule

//=====================================


module ASyncFIFO #(parameter N = 4, parameter WIDTH = 8) 
(
input logic [WIDTH-1:0] din,
output logic [WIDTH-1:0] dout,
input logic wr_en,
input logic rd_en,
input logic clk_rd,
input logic clk_wr,
input logic rst,
output logic full,
output logic empty
);


/*Grey Code
Change only one bit at a time : Good for Avoiding Metastability
We can begin/end with 001 and 101 for example

000
001
011
010
----
110
111
101
100
*/


	
parameter M = $clog2(N); // # of bits required to express adress
parameter wr_rst_dec = ((2**M) - N)/2;
parameter rd_rst_dec = ((2**M) + N)/2;
parameter first_index = wr_rst_dec ^ (wr_rst_dec >> 1);
parameter last_index = rd_rst_dec ^ (rd_rst_dec >> 1);
parameter Depth_grey = ((N-1)>>1)^(N-2);

logic [WIDTH-1:0] mem [N-1:0];
logic [M-1:0] wr_adr_grey;
logic [M-1:0] wr_adr_bin;
logic [M-1:0] rd_adr_grey;
logic [M-1:0] rd_adr_bin;
logic [M-1:0] next_wr_adr;
logic [M-1:0] next_rd_adr;


//=====================================

binary2grey #(.WIDTH(M)) B2G_wr  (.grey(next_wr_adr), .binary(wr_adr_bin + {{(M-1){1'b0}}, 1'b1}));
grey2binary #(.WIDTH(M)) G2B_wr  (.grey(wr_adr_grey), .binary(wr_adr_bin));

always_ff @(posedge clk_wr or negedge rst)
	if (~rst)
		wr_adr_grey <= first_index;
	else if (wr_en & ~full)
				begin
				mem[wr_adr_bin] <= din;	
				if (wr_adr_grey == last_index)
					wr_adr_grey <= first_index;
				else
					wr_adr_grey <= next_wr_adr;
				end
				
//=====================================

binary2grey #(.WIDTH(M)) B2G_rd  (.grey(next_rd_adr), .binary(rd_adr_bin + {{(M-1){1'b0}}, 1'b1}));
grey2binary #(.WIDTH(M)) G2B_rd  (.grey(rd_adr_grey), .binary(rd_adr_bin));

always_ff @(posedge clk_rd or negedge rst)
	if (~rst)
		rd_adr_grey <= last_index;
	else if (rd_en & ~empty)
				if (rd_adr_grey == last_index)
					rd_adr_grey <= first_index;
				else
					rd_adr_grey <= next_rd_adr;
					
//=====================================			

logic [M-1:0] OutSyncFromRD;
dff_sync #(.WIDTH(M)) FromRD (.din(rd_adr_grey), .dout(OutSyncFromRD), .clk(clk_wr), .reset(rst));

logic [M-1:0] OutSyncFromWR;
dff_sync #(.WIDTH(M)) FromWR (.din(wr_adr_grey), .dout(OutSyncFromWR), .clk(clk_rd), .reset(rst));

//=====================================	

logic [M-1:0] binary_wr_sync;
grey2binary #(.WIDTH(M)) COMPARATOR  (.grey(OutSyncFromWR), .binary(binary_wr_sync));

//=====================================	

assign empty =   (binary_wr_sync + (N-1) ) == rd_adr_bin;
assign full = (wr_adr_grey == OutSyncFromRD);

assign dout = mem[rd_adr_bin];

endmodule