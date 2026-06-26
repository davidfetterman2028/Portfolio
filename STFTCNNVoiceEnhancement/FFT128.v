//  FFT: 128-Point FFT Using Radix-2^2 Single-Path Delay Feedback

module FFT #(
    parameter   WIDTH = 16
)(
    input               clock,
    input               reset,
    input               di_en,
    input signed  [WIDTH-1:0] di_re,
    input signed  [WIDTH-1:0] di_im,
    output                    do_en,
    output signed [WIDTH-1:0] do_re,
    output signed [WIDTH-1:0] do_im
);

/*function signed [7:0] sat8(input signed [15:0] x);
    reg signed [15:0] scaled;
begin
    // The SDF FFT is already internally scaled by the butterfly shifts.
    // Keep the 16-bit result and saturate to the 8-bit output port.
    scaled = x;
    $display("su1_do_re=%0d su1_do_re=%0d", su1_do_re, su1_do_im);
    //$display("do_re_ext=%0d do_im_ext=%0d", fft_re_ext, fft_im_ext);
    //$display("do_re_ext=%0d do_im_ext=%0d", fft_re_ext, fft_im_ext);

    if (scaled > 16'sd127)
        sat8 = 8'sd127;
    else if (scaled < -16'sd128)
        sat8 = -8'sd128;
    else
        sat8 = scaled[7:0];
end
endfunction */

//  Data must be input consecutively in natural order.
//  The result is scaled to 1/N and output in bit-reversed order.
//  The output latency is 137 clock cycles.

wire signed [WIDTH-1:0] fft_re_ext;
wire signed [WIDTH-1:0] fft_im_ext;

wire              su1_do_en;
wire [WIDTH-1:0] su1_do_re;
wire [WIDTH-1:0] su1_do_im;
wire              su2_do_en;
wire [WIDTH-1:0] su2_do_re;
wire [WIDTH-1:0] su2_do_im;
wire              su3_do_en;
wire [WIDTH-1:0] su3_do_re;
wire [WIDTH-1:0] su3_do_im;

assign do_re = fft_re_ext;
assign do_im = fft_im_ext;

//assign do_re = sat8(fft_re_ext<<<5);
//assign do_im = sat8(fft_im_ext<<<5);

SdfUnit #(.N(128),.M(128),.WIDTH(WIDTH)) SU1 (
    .clock  (clock),
    .reset  (reset),
    .di_en  (di_en),
    .di_re  (di_re),
    .di_im  (di_im),
    .do_en  (su1_do_en),
    .do_re  (su1_do_re),
    .do_im  (su1_do_im)
);

SdfUnit #(.N(128),.M(32),.WIDTH(WIDTH)) SU2 (
    .clock  (clock),
    .reset  (reset),
    .di_en  (su1_do_en),
    .di_re  (su1_do_re),
    .di_im  (su1_do_im),
    .do_en  (su2_do_en),
    .do_re  (su2_do_re),
    .do_im  (su2_do_im)
);

SdfUnit #(.N(128),.M(8),.WIDTH(WIDTH)) SU3 (
    .clock  (clock),
    .reset  (reset),
    .di_en  (su2_do_en),
    .di_re  (su2_do_re),
    .di_im  (su2_do_im),
    .do_en  (su3_do_en),
    .do_re  (su3_do_re),
    .do_im  (su3_do_im)
);

SdfUnit2 #(.WIDTH(WIDTH)) SU4 (
    .clock  (clock),
    .reset  (reset),
    .di_en  (su3_do_en),
    .di_re  (su3_do_re),
    .di_im  (su3_do_im),
    .do_en  (do_en),
    .do_re  (fft_re_ext),
    .do_im  (fft_im_ext)
);

endmodule
