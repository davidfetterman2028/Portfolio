module UnlogNormalize #(
    parameter MAG_WIDTH = 16,
    parameter [MAG_WIDTH-1:0] MAG_FLOOR = 16'd22937
)(
    input                       clock,
    input                       reset,
    input                       in_en,
    input signed [7:0]          in_logMag,

    output reg                  out_en,
    output reg [MAG_WIDTH-1:0]  out_mag
);

localparam [15:0] FLOOR_LOG2_Q3 = 16'd29655;
localparam [15:0] NORM_SCALE_Q6 = 16'd1484;

reg [15:0] norm_tmp;
reg [15:0] log2_q3;
reg [4:0]  ip;
reg [10:0] fp;
reg [MAG_WIDTH-1:0] mag_tmp;

always @(*) begin
    // Reverse: signed output was norm_tmp - 128
    norm_tmp = $signed(in_logMag) + 16'sd128;

    // Reverse: norm_tmp = ((log2_q3 - FLOOR_LOG2_Q3) * NORM_SCALE_Q6) >> 6
    log2_q3 = FLOOR_LOG2_Q3 + ((norm_tmp << 6) / NORM_SCALE_Q6);

    // Split fixed-point log representation
    ip = log2_q3[15:11];
    fp = log2_q3[10:0];

    // Reverse approx_log2_q3:
    // original form was approximately {leading_bit_position, next 11 bits}
    if (ip >= 11)
        mag_tmp = ({1'b1, fp} << (ip - 11));
    else
        mag_tmp = ({1'b1, fp} >> (11 - ip));

    if (mag_tmp < MAG_FLOOR)
        mag_tmp = MAG_FLOOR;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        out_en  <= 1'b0;
        out_mag <= {MAG_WIDTH{1'b0}};
    end
    else begin
        out_en <= in_en;

        if (in_en)
            out_mag <= mag_tmp;
    end
end

endmodule