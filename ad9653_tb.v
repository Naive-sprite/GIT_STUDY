//**************************************************************
// Testbench for ad9653_inf (修正版，解决 fatal error)
//**************************************************************
`timescale 1ns / 1ps

module tb_ad9653_inf();

// ------------------------------------------------------------------
// Parameters
// ------------------------------------------------------------------
localparam DCO_PERIOD  = 5.0;         // 200 MHz
localparam REFCLK_FREQ = 200_000_000; // 200 MHz

// ------------------------------------------------------------------
// Signals
// ------------------------------------------------------------------
reg         rstn;
reg         dco_clk;
reg         fco_clk;

wire        dcop, dcom;
wire        fcop, fcom;
wire [1:0]  dap, dam;
wire [1:0]  dbp, dbm;
wire [1:0]  dcp, dcm;
wire [1:0]  ddp, ddm;

wire [7:0]  align_patten;
wire        fclk;
wire        clk4x;
wire [15:0] da, db, dc, dd;

reg         idelay_refclk;
wire        idelay_rdy;

reg [15:0]  test_data_a, test_data_b, test_data_c, test_data_d;

// ------------------------------------------------------------------
// Data lines (positive reg, negative wire)
// ------------------------------------------------------------------
reg         dap0, dap1;
reg         dbp0, dbp1;
reg         dcp0, dcp1;
reg         ddp0, ddp1;

wire        dam0, dam1;
wire        dbm0, dbm1;
wire        dcm0, dcm1;
wire        ddm0, ddm1;

assign dam0 = ~dap0; assign dam1 = ~dap1;
assign dbm0 = ~dbp0; assign dbm1 = ~dbp1;
assign dcm0 = ~dcp0; assign dcm1 = ~dcp1;
assign ddm0 = ~ddp0; assign ddm1 = ~ddp1;

assign dap[0] = dap0; assign dam[0] = dam0;
assign dap[1] = dap1; assign dam[1] = dam1;
assign dbp[0] = dbp0; assign dbm[0] = dbm0;
assign dbp[1] = dbp1; assign dbm[1] = dbm1;
assign dcp[0] = dcp0; assign dcm[0] = dcm0;
assign dcp[1] = dcp1; assign dcm[1] = dcm1;
assign ddp[0] = ddp0; assign ddm[0] = ddm0;
assign ddp[1] = ddp1; assign ddm[1] = ddm1;

// ------------------------------------------------------------------
// DUT instantiation
// ------------------------------------------------------------------
ad9653_inf u_dut (
    .rstn         (rstn),
    .refclk_200m  (idelay_refclk),   // 新增连接
    .dcop         (dcop),
    .dcom         (dcom),
    .fcop        (fcop),
    .fcom        (fcom),
    .dap         (dap),
    .dam         (dam),
    .dbp         (dbp),
    .dbm         (dbm),
    .dcp         (dcp),
    .dcm         (dcm),
    .ddp         (ddp),
    .ddm         (ddm),
    .dly_ctrl    (5'd0),
    .align_patten(align_patten),
    .fclk        (fclk),
    .clk4x       (clk4x),
    .da          (da),
    .db          (db),
    .dc          (dc),
    .dd          (dd)
);

// ------------------------------------------------------------------
// IDELAYCTRL
// ------------------------------------------------------------------
idly_ctrl u_idly_ctrl (
    .rstn (rstn),
    .clk  (idelay_refclk),
    .rdy  (idelay_rdy)
);

glbl glbl_inst ();

initial begin
    rstn = 0;
    // 等待参考时钟稳定（至少 100 ns）
    repeat (100) @(posedge idelay_refclk);
    // 再等待 IDELAYCTRL 就绪
    wait (idelay_rdy == 1'b1);
    #100;
    rstn = 1;
end

// ------------------------------------------------------------------
// Differential clocks
// ------------------------------------------------------------------
assign dcop = dco_clk;
assign dcom = ~dco_clk;
assign fcop = fco_clk;
assign fcom = ~fco_clk;

// ------------------------------------------------------------------
// Clock generation
// ------------------------------------------------------------------
initial begin
    dco_clk = 0;
    forever #(DCO_PERIOD/2) dco_clk = ~dco_clk;
end

initial begin
    idelay_refclk = 0;
    forever #(500.0/REFCLK_FREQ) idelay_refclk = ~idelay_refclk;
end

// ------------------------------------------------------------------
// Reset generation: wait for IDELAYCTRL ready
// ------------------------------------------------------------------
initial begin
    rstn = 0;
    // Wait for IDELAYCTRL to become ready (max ~1us)
    wait (idelay_rdy == 1'b1);
    #100;   // extra delay
    rstn = 1;
end

// ------------------------------------------------------------------
// Test data update
// ------------------------------------------------------------------
initial begin
    test_data_a = 16'h0000;
    test_data_b = 16'h0000;
    test_data_c = 16'h0000;
    test_data_d = 16'h0000;
    @(posedge rstn);
    forever begin
        repeat (16) @(posedge dco_clk or negedge dco_clk);
        test_data_a <= test_data_a + 1'b1;
        test_data_b <= test_data_b + 1'b1;
        test_data_c <= test_data_c + 1'b1;
        test_data_d <= test_data_d + 1'b1;
    end
end

// ------------------------------------------------------------------
// FCO pattern generation (0xF0, MSB first, DDR)
// ------------------------------------------------------------------
reg [7:0] fco_pattern = 8'b11110000;
reg [3:0] fco_bit_idx;
initial begin
    fco_bit_idx = 0;
    forever begin
        @(posedge dco_clk) begin
            fco_clk <= fco_pattern[7 - fco_bit_idx];
            fco_bit_idx <= fco_bit_idx + 1;
        end
        @(negedge dco_clk) begin
            fco_clk <= fco_pattern[7 - fco_bit_idx];
            fco_bit_idx <= fco_bit_idx + 1;
        end
    end
end

// ------------------------------------------------------------------
// Serial data generation (D0 lane even bits, D1 lane odd bits)
// ------------------------------------------------------------------
reg [15:0] sample_a, sample_b, sample_c, sample_d;
reg [3:0] pos_cnt, neg_cnt;

always @(posedge dco_clk or negedge rstn) begin
    if (!rstn) begin
        pos_cnt <= 0;
        dap0 <= 0; dbp0 <= 0; dcp0 <= 0; ddp0 <= 0;
        sample_a <= 0; sample_b <= 0; sample_c <= 0; sample_d <= 0;
    end else begin
        if (pos_cnt == 0 && neg_cnt == 0) begin
            sample_a <= test_data_a;
            sample_b <= test_data_b;
            sample_c <= test_data_c;
            sample_d <= test_data_d;
        end
        dap0 <= sample_a[14 - 2*pos_cnt];
        dbp0 <= sample_b[14 - 2*pos_cnt];
        dcp0 <= sample_c[14 - 2*pos_cnt];
        ddp0 <= sample_d[14 - 2*pos_cnt];
        pos_cnt <= (pos_cnt == 7) ? 0 : pos_cnt + 1;
    end
end

always @(negedge dco_clk or negedge rstn) begin
    if (!rstn) begin
        neg_cnt <= 0;
        dap1 <= 0; dbp1 <= 0; dcp1 <= 0; ddp1 <= 0;
    end else begin
        dap1 <= sample_a[15 - 2*neg_cnt];
        dbp1 <= sample_b[15 - 2*neg_cnt];
        dcp1 <= sample_c[15 - 2*neg_cnt];
        ddp1 <= sample_d[15 - 2*neg_cnt];
        neg_cnt <= (neg_cnt == 7) ? 0 : neg_cnt + 1;
    end
end

// ------------------------------------------------------------------
// Output checking with pipeline delay
// ------------------------------------------------------------------
integer errors = 0;
reg [15:0] exp_a_dly [0:5];
reg [15:0] exp_b_dly [0:5];
reg [15:0] exp_c_dly [0:5];
reg [15:0] exp_d_dly [0:5];
integer i;

always @(posedge fclk) begin
    if (rstn) begin
        for (i = 5; i > 0; i = i - 1) begin
            exp_a_dly[i] <= exp_a_dly[i-1];
            exp_b_dly[i] <= exp_b_dly[i-1];
            exp_c_dly[i] <= exp_c_dly[i-1];
            exp_d_dly[i] <= exp_d_dly[i-1];
        end
        exp_a_dly[0] <= test_data_a;
        exp_b_dly[0] <= test_data_b;
        exp_c_dly[0] <= test_data_c;
        exp_d_dly[0] <= test_data_d;

        if (exp_a_dly[5] !== da) begin
            $display("ERROR at %t: Channel A expected %h, got %h", $time, exp_a_dly[5], da);
            errors = errors + 1;
        end
        if (exp_b_dly[5] !== db) begin
            $display("ERROR at %t: Channel B expected %h, got %h", $time, exp_b_dly[5], db);
            errors = errors + 1;
        end
        if (exp_c_dly[5] !== dc) begin
            $display("ERROR at %t: Channel C expected %h, got %h", $time, exp_c_dly[5], dc);
            errors = errors + 1;
        end
        if (exp_d_dly[5] !== dd) begin
            $display("ERROR at %t: Channel D expected %h, got %h", $time, exp_d_dly[5], dd);
            errors = errors + 1;
        end
    end
end

// ------------------------------------------------------------------
// Simulation duration
// ------------------------------------------------------------------
initial begin
    #500000;   // 500 us to ensure enough time for alignment
    $display("Simulation finished. Errors: %0d", errors);
    $finish;
end

initial begin
    $dumpfile("tb_ad9653_inf.vcd");
    $dumpvars(0, tb_ad9653_inf);
end

endmodule