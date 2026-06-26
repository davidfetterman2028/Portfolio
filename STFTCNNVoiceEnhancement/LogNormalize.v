module LogNormalize #(
    parameter MAG_WIDTH = 16,
    parameter [MAG_WIDTH-1:0] MAG_FLOOR = 16'd22937
)(
    input                       clock,
    input                       reset,
    input                       in_en,
    input      [MAG_WIDTH-1:0]  in_mag,

    output reg                  out_en,
    output reg signed [7:0]     logMag_out
);

localparam [15:0] FLOOR_LOG2_Q11 = 16'd29655;
localparam [15:0] MAX_LOG2_Q3   = 16'd127;
localparam [15:0] RANGE_LOG2_Q3 = MAX_LOG2_Q3 - FLOOR_LOG2_Q11;

// (255 / RANGE_LOG2_Q3) * 64 ≈ 1484 when RANGE=11
localparam [15:0] NORM_SCALE_Q6 = 16'd1484;

reg [MAG_WIDTH-1:0] x;
reg [15:0] log2_q3;
reg [15:0] norm_tmp;
reg signed [15:0] signed_tmp;

function [15:0] approx_log2_q3;
    input [MAG_WIDTH-1:0] val;
    integer j;
    reg [4:0] ip;   // 5 integer bits (max 31 log2 should end at 16 but don't want clipping)
    reg [10:0] fp;  // 11 frac bits (leftover bits for precision (unsigned currently))
    reg f;
    begin
        ip = 0;
        fp = 0;
        f  = 0;

        for (j = MAG_WIDTH-1; j >= 0; j = j - 1) begin
            if (!f && val[j]) begin
                ip = j[4:0];
                if (j >= 11)
                    fp = val[j-1 -: 11];
                else if (j == 10)
                    fp = {val[9:0], 1'b0};
                else if (j == 9)
                    fp = {val[8:0], 2'b00};
                else if (j == 8)
                    fp = {val[7:0], 3'b000};
                else if (j == 7)
                    fp = {val[6:0], 4'b0000};
                else if (j == 6)
                    fp = {val[5:0], 5'b00000};
                else if (j == 5)
                    fp = {val[4:0], 6'b000000};
                else if (j == 4)
                    fp = {val[3:0], 7'b0000000};
                else if (j == 3)
                    fp = {val[2:0], 8'b00000000};
                else if (j == 2)
                    fp = {val[1:0], 9'b000000000};
                else if (j == 1)
                    fp = {val[0], 10'b0000000000};
                else
                    fp = 11'd0;
                f = 1;
            end
        end

        approx_log2_q3 = {ip, fp};
    end
endfunction

always @(*) begin
    x = (in_mag < MAG_FLOOR) ? MAG_FLOOR : in_mag;

    log2_q3 = approx_log2_q3(x);

    if (log2_q3 <= FLOOR_LOG2_Q11)
        norm_tmp = 16'd0;
    else
        norm_tmp = ((log2_q3 - FLOOR_LOG2_Q11) * NORM_SCALE_Q6) >> 6;

    if (norm_tmp > 16'd255)
        signed_tmp = 16'sd127;
    else
        signed_tmp = $signed({1'b0, norm_tmp}) - 16'sd128;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        out_en     <= 1'b0;
        logMag_out <= 8'sd0;
    end
    else begin
        out_en <= in_en;

        if (in_en) begin
            if (signed_tmp > 16'sd127)
                logMag_out <= 8'sd127;
            else if (signed_tmp < -16'sd128)
                logMag_out <= -8'sd128;
            else
                logMag_out <= signed_tmp[7:0];
        end
    end
end

endmodule