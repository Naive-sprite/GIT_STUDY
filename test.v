`timescale 1ns/1ns
module test(
	input wire clk,
	input wire rst,
	output wire test_en
);

reg [15:0] test_data [2:0];

always @(posedge clk or posedge rst) begin
	if(rst) begin
		test_data[0] <= 'd0;
		test_data[1] <= 'd0;
		test_data[2] <= 'd0;
	end
	else begin
		test_data[0] <= test_data[0] + 'd1;
		test_data[1] <= test_data[1] + 'd2;
		test_data[2] <= test_data[2] + 'd3;
	end
end
	

assign test_en = (test_data[0] == test_data[1]) & (test_data[1] == test_data[2]);

endmodule

module test_tb();

reg clk,rst;
wire test_en;

always #10 clk = ~clk;

test test(
	.clk		(clk),
	.rst		(rst),
	.test_en	(test_en)
);

initial begin
	clk = 0;
	rst = 1;
	#100
	rst = 0;
	#10000
	$stop;
end

//这样就没有问题了
//修改本地文件
endmodule