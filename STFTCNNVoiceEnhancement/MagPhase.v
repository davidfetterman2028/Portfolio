module MagPhase #(
    parameter WIDTH       = 16,
    parameter MAG_WIDTH   = 16,
    parameter PHASE_WIDTH = 16,
    parameter ITER        = 16
)(
    input                           clock,
    input                           reset,

    input                           in_en,
    input signed [WIDTH-1:0]        in_re,
    input signed [WIDTH-1:0]        in_im,

    output reg                      out_en,
    output reg [MAG_WIDTH-1:0]      mag_out,
    output reg signed [PHASE_WIDTH-1:0] phase_out
);

localparam CORDIC_WIDTH = WIDTH + 4;

function signed [PHASE_WIDTH-1:0] atan_lut;
    input integer i;
    begin
        case (i)
            0:  atan_lut = 16'sd8192;  // atan(1)
            1:  atan_lut = 16'sd4836;
            2:  atan_lut = 16'sd2555;
            3:  atan_lut = 16'sd1297;
            4:  atan_lut = 16'sd651;
            5:  atan_lut = 16'sd326;
            6:  atan_lut = 16'sd163;
            7:  atan_lut = 16'sd81;
            8:  atan_lut = 16'sd41;
            9:  atan_lut = 16'sd20;
            10: atan_lut = 16'sd10;
            11: atan_lut = 16'sd5;
            12: atan_lut = 16'sd3;
            13: atan_lut = 16'sd1;
            14: atan_lut = 16'sd1;
            15: atan_lut = 16'sd0;
            default: atan_lut = 16'sd0;
        endcase
    end
endfunction

integer k;

reg signed [CORDIC_WIDTH-1:0] x [0:ITER];
reg signed [CORDIC_WIDTH-1:0] y [0:ITER];
reg signed [PHASE_WIDTH-1:0]  z [0:ITER];
reg                           valid [0:ITER];

// CORDIC gain correction approximately 1 / 1.64676 = 0.607253
// Q15 scale: 0.607253 * 32768 ≈ 19899
wire signed [31:0] mag_corrected;
assign mag_corrected = (x[ITER] * 16'sd19899) >>> 15;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (k = 0; k <= ITER; k = k + 1) begin
            x[k] <= 0;
            y[k] <= 0;
            z[k] <= 0;
            valid[k] <= 0;
        end

        out_en    <= 0;
        mag_out   <= 0;
        phase_out <= 0;
    end
    else begin
        valid[0] <= in_en;

        // Pre-rotate into right half-plane for atan2 behavior
        if (in_en) begin
            if (in_re < 0) begin
                if (in_im >= 0) begin
                    x[0] <= -{{4{in_re[WIDTH-1]}}, in_re};
                    y[0] <= -{{4{in_im[WIDTH-1]}}, in_im};
                    z[0] <= 16'sd32767;
                end
                else begin
                    x[0] <= -{{4{in_re[WIDTH-1]}}, in_re};
                    y[0] <= -{{4{in_im[WIDTH-1]}}, in_im};
                    z[0] <= -16'sd32768;
                end
            end
            else begin
                x[0] <= {{4{in_re[WIDTH-1]}}, in_re};
                y[0] <= {{4{in_im[WIDTH-1]}}, in_im};
                z[0] <= 0;
            end
        end

        for (k = 0; k < ITER; k = k + 1) begin
            valid[k+1] <= valid[k];

            if (y[k] >= 0) begin
                x[k+1] <= x[k] + (y[k] >>> k);
                y[k+1] <= y[k] - (x[k] >>> k);
                z[k+1] <= z[k] + atan_lut(k);
            end
            else begin
                x[k+1] <= x[k] - (y[k] >>> k);
                y[k+1] <= y[k] + (x[k] >>> k);
                z[k+1] <= z[k] - atan_lut(k);
            end
        end

        out_en    <= valid[ITER];
        phase_out <= z[ITER];

        if (mag_corrected > 65535)
            mag_out <= 16'hFFFF;
        else if (mag_corrected < 0)
            mag_out <= 16'd0;
        else
            mag_out <= mag_corrected[15:0];
    end
end

endmodule