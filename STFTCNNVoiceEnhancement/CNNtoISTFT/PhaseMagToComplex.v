module PhaseMagToComplex #(
    parameter WIDTH       = 16,
    parameter MAG_WIDTH   = 16,
    parameter PHASE_WIDTH = 16,
    parameter ITER        = 16
)(
    input                                    clock,
    input                                    reset,

    input                                    in_en,
    input        [MAG_WIDTH-1:0]            in_mag,
    input signed [PHASE_WIDTH-1:0]        in_phase,

    output reg                              out_en,
    output reg signed [WIDTH-1:0]           out_re,
    output reg signed [WIDTH-1:0]           out_im // this is complex conjugate of retained phase
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
reg                       valid [0:ITER];
reg                      negate [0:ITER];
wire signed [CORDIC_WIDTH-1:0]   re_full;
wire signed [CORDIC_WIDTH-1:0]   im_full;

assign re_full = negate[ITER] ? -x[ITER] : x[ITER];
// conjugate
assign im_full = negate[ITER] ? y[ITER] : -y[ITER];

// CORDIC gain correction approximately 1 / 1.64676 = 0.607253
// Q15 scale: 0.607253 * 32768 ≈ 19899
always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (k = 0; k <= ITER; k = k + 1) begin
            x[k] <= 0;
            y[k] <= 0;
            z[k] <= 0;
            valid[k] <= 0;
            negate[k] <= 0;
        end

        out_en    <= 0;
        out_re   <= 0;
        out_im <= 0;
    end
    else begin
        valid[0] <= in_en;
        if (in_en) begin
            x[0] <= ($signed({1'b0,in_mag}) * 16'sd19899) >>> 15; // mag_scaled = mag_in * 0.607253 (Dealing with CORDIC gain)
            y[0] <= 0;
            if (in_phase > 16'sd16384) begin
                z[0] <= in_phase - 16'sd32767;
                negate[0] <= 1'b1;
            end
            else if (in_phase < -16'sd16384) begin
                z[0] <= in_phase + 16'sd32767;
                negate[0] <= 1'b1;
            end
            else begin
                z[0] <= in_phase;
                negate[0] <= 1'b0;
            end
        end
        for (k = 0; k < ITER; k = k + 1) begin
            valid[k+1] <= valid[k];
            negate[k+1] <= negate[k];

            if (z[k] >= 0) begin
                x[k+1] <= x[k] - (y[k] >>> k);
                y[k+1] <= y[k] + (x[k] >>> k);
                z[k+1] <= z[k] - atan_lut(k);
            end
            else begin
                x[k+1] <= x[k] + (y[k] >>> k);
                y[k+1] <= y[k] - (x[k] >>> k);
                z[k+1] <= z[k] + atan_lut(k);
            end
        end

        out_en    <= valid[ITER];

        out_re <= re_full[WIDTH-1:0];
        out_im <= im_full[WIDTH-1:0];
    end
end

endmodule