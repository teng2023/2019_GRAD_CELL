module  CONV(
	input		clk,
	input		reset,
	output		busy,	
	input		ready,	
			
	output [11:0] iaddr,
	input [19:0] idata,	
	
	output	 	cwr,
	output [11:0] caddr_wr,
	output [19:0] cdata_wr,
	
	output	 	crd,
	output [11:0] caddr_rd,
	input [19:0] cdata_rd,
	
	output [2:0] csel
	);

// define state
`define IDLE 2'b0
`define EXECUTE 2'b01
`define DONE 2'b10 

// parameters of kernel 0
parameter KERNEL_01 = 20'h0A89E;
parameter KERNEL_02 = 20'h092D5;
parameter KERNEL_03 = 20'h06D43;
parameter KERNEL_04 = 20'h01004;
parameter KERNEL_05 = 20'hF8F71;
parameter KERNEL_06 = 20'hF6E54;
parameter KERNEL_07 = 20'hFA6D7;
parameter KERNEL_08 = 20'hFC834;
parameter KERNEL_09 = 20'hFAC19;

parameter BIAS_0 = 20'h01310;

// parameters of kernel 1
parameter KERNEL_11 = 20'hFDB55;
parameter KERNEL_12 = 20'h02992;
parameter KERNEL_13 = 20'hFC994;
parameter KERNEL_14 = 20'h050FD;
parameter KERNEL_15 = 20'h02F20;
parameter KERNEL_16 = 20'h0202D;
parameter KERNEL_17 = 20'h03BD7;
parameter KERNEL_18 = 20'hFD369;
parameter KERNEL_19 = 20'h05E68;

parameter BIAS_1 = 20'hF7295;

///////////////////////////// variables /////////////////////////////
// convolution
reg signed [19:0] conv_element;
reg signed [39:0] conv_sum;
reg layer_switch;	// 0 represents kernel0, 1 represents kernel1
reg signed [19:0] kernel_number;

wire signed [19:0] bias_number;
wire signed [39:0] multiplication;
wire [40:0] conv_relu;
wire signed [40:0] conv_bias;
wire [40:0] relu_round;

// maxpooling
reg [19:0] maxpool_compare0;
reg [19:0] maxpool_compare1;
reg [1:0] maxpool_count;

wire [19:0] substract_result0;
wire [19:0] substract_result1;

// flatten
wire add_1;

// memory
reg cwr_r;
reg [11:0] caddr_wr_r;
reg [19:0] cdata_wr_r;
reg [2:0] csel_r;

// coordinate
reg [5:0] center_x;
reg [5:0] center_y;
reg [5:0] addr_x;
reg [5:0] addr_y;

wire [4:0] maxpool_x;
wire [4:0] maxpool_y;

// system
reg conv_execute;
reg maxpool_execute;
reg flatten_execute;
reg busy_r;
reg [3:0] counter;
reg [1:0] current_state;
reg [1:0] next_state;

///////////////////////////// convolution /////////////////////////////
// bias_number
assign bias_number = (layer_switch) ? BIAS_1 : BIAS_0;

// multiplication, conv_bias, conv_relu, relu_round
assign multiplication = kernel_number * conv_element;
assign conv_bias = conv_sum + (bias_number << 16);
assign conv_relu = (conv_bias[40]) ? 40'b0 : conv_bias;
assign relu_round = (conv_relu[15] && |conv_relu[14:0]) ? (conv_relu + {1'b1, 16'b0}) : conv_relu;

// conv_element
always @(posedge clk or posedge reset) begin
	if (reset) begin
		conv_element <= 20'b0;
	end
	else if (current_state == `EXECUTE && counter < 9) begin
		if (center_y == 0 && counter < 3 || center_y == 63 && counter > 5 || center_x == 0 && counter % 3 == 0 || center_x == 63 && counter % 3 == 2) begin
			conv_element <= 20'b0;
		end
		else begin
			conv_element <= idata;
		end
	end
	else begin
		conv_element <= 20'b0;
	end
end

// conv_sum
always @(posedge clk or posedge reset) begin
	if (reset) begin
		conv_sum <= 20'b0;
	end
	else if (current_state == `EXECUTE && counter < 11) begin
		conv_sum <= conv_sum + multiplication;
	end
	else begin
		conv_sum <= 20'b0;
	end
end

// kernel_number
always @(*) begin
	if (current_state == `EXECUTE && ~&layer_switch) begin
		case(counter)
			1: kernel_number = KERNEL_01;
			2: kernel_number = KERNEL_02;
			3: kernel_number = KERNEL_03;
			4: kernel_number = KERNEL_04;
			5: kernel_number = KERNEL_05;
			6: kernel_number = KERNEL_06;
			7: kernel_number = KERNEL_07;
			8: kernel_number = KERNEL_08;
			9: kernel_number = KERNEL_09;
			default: kernel_number = 20'b0;
		endcase
	end
	else if (current_state == `EXECUTE && layer_switch) begin
		case(counter)
			1: kernel_number = KERNEL_11;
			2: kernel_number = KERNEL_12;
			3: kernel_number = KERNEL_13;
			4: kernel_number = KERNEL_14;
			5: kernel_number = KERNEL_15;
			6: kernel_number = KERNEL_16;
			7: kernel_number = KERNEL_17;
			8: kernel_number = KERNEL_18;
			9: kernel_number = KERNEL_19;
			default: kernel_number = 20'b0;
		endcase
	end
end

// layer_switch
always @(posedge clk or posedge reset) begin
	if (reset) begin
		layer_switch <= 1'b0;
	end
	else if (current_state == `EXECUTE && counter == 10) begin
		layer_switch <= ~layer_switch;
	end
end

// conv_execute
always @(posedge clk or posedge reset) begin
	if (reset) begin
		conv_execute <= 1'b0;
	end
	else if (ready) begin
		conv_execute <= 1'b1;
	end
	else if (center_x == 63 && center_y == 63 && ~layer_switch && counter == 11) begin
		conv_execute <= 1'b0;
	end
end

// center_x
always @(posedge clk or posedge reset) begin
	if (reset) begin
		center_x <= 6'b0;
	end
	else if (current_state == `EXECUTE && counter == 11 && ~layer_switch && center_y[0]) begin
		if (&center_x) begin
			center_x <= 6'b0;
		end
		else begin
			center_x <= center_x + 1'b1;
		end
	end
end

// center_y
always @(posedge clk or posedge reset) begin
	if (reset) begin
		center_y <= 6'b0;
	end
	else if (current_state == `EXECUTE && counter == 11 && ~layer_switch) begin
		if (center_y[0] && &center_x) begin
			center_y <= center_y + 1'b1;
		end
		else begin
			center_y <= {center_y[5:1], ~center_y[0]};
		end
		
	end
end

// addr_x
always @(*) begin
	case(counter)
		0, 3, 6: addr_x = (center_x) ? (center_x - 1'b1) : 6'b0;
		1, 4, 7: addr_x = center_x;
		2, 5, 8: addr_x = (&center_x) ? 6'b0 : (center_x + 1'b1);
		default: addr_x = 6'bx;
	endcase
end

// addr_y
always @(*) begin
	case(counter)
		0, 1, 2: addr_y = (center_y) ? (center_y - 1'b1) : 6'b0;
		3, 4, 5: addr_y = center_y;
		6, 7, 8: addr_y = (&center_y) ? 6'b0 : (center_y + 1'b1);
		default: addr_y = 6'bx;
	endcase
end

///////////////////////////// maxpooling /////////////////////////////
assign substract_result0 = maxpool_compare0 - relu_round[35:16];
assign substract_result1 = maxpool_compare1 - relu_round[35:16];

// maxpool_execute
always @(posedge clk or posedge reset) begin
	if (reset) begin
		maxpool_execute <= 1'b0;
	end
	else if (conv_execute && counter == 9 && &maxpool_count) begin
		maxpool_execute <= 1'b1;
	end
	else if (counter == 0) begin
		maxpool_execute <= 1'b0;
	end
end

// maxpool_count
always @(posedge clk or posedge reset) begin
	if (reset) begin
		maxpool_count <= 2'b0;
	end
	else if (current_state == `EXECUTE && counter == 11 && ~layer_switch) begin
		if (&maxpool_count) begin
			maxpool_count <= 2'b0;
		end
		else begin
			maxpool_count <= maxpool_count + 1'b1;
		end
	end
end

// maxpool_compare0
always @(posedge clk or posedge reset) begin
	if (reset) begin
		maxpool_compare0 <= 20'b0;
	end
	else if (current_state == `EXECUTE && counter == 10 && ~layer_switch) begin
		if (substract_result0[19]) begin
			maxpool_compare0 <= relu_round[35:16];
		end
	end
	else if (current_state == `EXECUTE && counter == 11 && &maxpool_count && layer_switch) begin
		maxpool_compare0 <= 20'b0;
	end
end

// maxpool_compare1
always @(posedge clk or posedge reset) begin
	if (reset) begin
		maxpool_compare1 <= 20'b0;
	end
	else if (current_state == `EXECUTE && counter == 10 && layer_switch) begin
		if (substract_result1[19]) begin
			maxpool_compare1 <= relu_round[35:16];
		end
	end
	else if (current_state == `EXECUTE && counter == 11 && &maxpool_count && ~layer_switch) begin
		maxpool_compare1 <= 20'b0;
	end
end

///////////////////////////// Flatten /////////////////////////////
// flatten_execute
always @(posedge clk or posedge reset) begin
	if (reset) begin
		flatten_execute <= 1'b0;
	end
	else if (current_state == `EXECUTE && counter == 0 && maxpool_execute) begin
		flatten_execute <= 1'b1;
	end
	else begin
		flatten_execute <= 1'b0;
	end
end

///////////////////////////// memory /////////////////////////////
assign iaddr = addr_x + (addr_y * 64);
assign maxpool_x = ((center_x - 1) < 0) ? 5'b0 : (center_x - 1)/2;
assign maxpool_y = ((center_y - 1) < 0) ? 5'b0 : (center_y - 1)/2;
assign add_1 = ~layer_switch;

assign cwr = cwr_r;
assign caddr_wr = caddr_wr_r;
assign cdata_wr = cdata_wr_r;
assign csel = csel_r;

// cwr_r
always @(posedge clk or posedge reset) begin
	if (reset) begin
		cwr_r <= 1'b0;
	end
	else if (current_state == `EXECUTE && counter == 10) begin
		cwr_r <= 1'b1;
	end
	else if (current_state == `EXECUTE && counter == 11 && &maxpool_count) begin
		cwr_r <= 1'b1;
	end
	else if (maxpool_execute && counter == 0) begin
		cwr_r <= 1'b1;
	end
	else begin	
		cwr_r <= 1'b0;
	end
end

// caddr_wr_r
always @(posedge clk or posedge reset) begin
	if (reset) begin
		caddr_wr_r <= 12'b0;
	end
	else if (current_state == `EXECUTE && counter == 10) begin
		caddr_wr_r <= center_x + center_y * 64;
	end
	else if (current_state == `EXECUTE && counter == 11) begin
		caddr_wr_r <= maxpool_x + maxpool_y * 32;
	end
	else if (current_state == `EXECUTE && counter == 0 && maxpool_execute) begin
		caddr_wr_r <= 2 * caddr_wr_r + add_1;
	end
	else begin
		caddr_wr_r <= 12'bx;
	end
end

// cdata_wr_r
always @(posedge clk or posedge reset) begin
	if (reset) begin
		cdata_wr_r <= 20'b0;
	end
	else if (current_state == `EXECUTE && counter == 10) begin
		cdata_wr_r <= relu_round[35:16];
	end
	else if (current_state == `EXECUTE && counter == 11 && &maxpool_count) begin
		if (layer_switch) begin
			cdata_wr_r <= maxpool_compare0;
		end
		else begin
			cdata_wr_r <= maxpool_compare1;
		end
	end
end

// csel_r
always @(posedge clk or posedge reset) begin
	if (reset) begin
		csel_r <= 3'b0;
	end
	else if (current_state == `EXECUTE && counter == 10) begin
		if (layer_switch) begin
			csel_r <= 3'b010;
		end
		else begin
			csel_r <= 3'b001;
		end
	end
	else if (current_state == `EXECUTE && counter == 11 && &maxpool_count) begin
		if (layer_switch) begin
			csel_r <= 3'b011;
		end
		else begin
			csel_r <= 3'b100;
		end
	end
	else if (current_state == `EXECUTE && counter == 0 && maxpool_execute) begin
		csel_r <= 3'b101;
	end
	else begin
		csel_r <= 3'bx;
	end
end

///////////////////////////// system output /////////////////////////////
assign busy = busy_r;

// busy_r
always @(posedge clk or posedge reset) begin
	if (reset) begin
		busy_r <= 1'b0;
	end
	else if (ready) begin
		busy_r <= 1'b1;
	end
	else if (current_state == `DONE) begin
		busy_r <= 1'b0;
	end
end

// counter
always @(posedge clk or posedge reset) begin
	if (reset) begin
		counter <= 4'b0;
	end
	else if (current_state == `EXECUTE) begin
		if (counter == 11) begin
			counter <= 4'b0;
		end
		else begin
			counter <= counter + 1'b1;
		end
	end
end

// current_state
always @(posedge clk or posedge reset) begin
	if (reset) begin
		current_state <= 2'b0;
	end
	else begin
		current_state <= next_state;
	end
end

// finite state machine
always @(*) begin
	case(current_state)
		`IDLE:begin
			next_state = (~reset) ? `EXECUTE : `IDLE;
		end
		`EXECUTE:begin
			next_state = (~conv_execute && ~maxpool_execute && ~flatten_execute) ? `DONE : `EXECUTE;
		end
		default:begin
			next_state = `IDLE;
		end
	endcase
end

endmodule
