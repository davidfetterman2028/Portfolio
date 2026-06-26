//----------------------------------------------------------------------
// iSTFT: 128-point inverse STFT with H=64 using two staggered IFFT lanes
//----------------------------------------------------------------------
// Assumptions:
//   1. di_*_a and di_*_b are already reconstructed complex STFT bins.
//   2. di_im_a / di_im_b have already been conjugated before this module
//      if using the forward FFT core as an IFFT.
//   3. The FFT core is internally scaled, so no extra divide-by-128 is used.
//   4. Since the forward STFT already applied a Hann analysis window,
//      this module overlap-adds the real IFFT frame outputs directly.
//----------------------------------------------------------------------

module iSTFT #(
    parameter WIDTH = 16,
    parameter N = 128,
    parameter H = 64
)(
    input clock,
    input reset,

    input di_en_a,
    input signed [WIDTH-1:0] di_re_a,
    input signed [WIDTH-1:0] di_im_a,

    input di_en_b,
    input signed [WIDTH-1:0] di_re_b,
    input signed [WIDTH-1:0] di_im_b,

    output reg do_en,
    output reg signed [WIDTH-1:0] do_re
);

function signed [WIDTH-1:0] sat_width;
    input signed [WIDTH:0] x;
    begin
        if (x > $signed({1'b0, {(WIDTH-1){1'b1}}}))
            sat_width = {1'b0, {(WIDTH-1){1'b1}}};
        else if (x < $signed({1'b1, {(WIDTH-1){1'b0}}}))
            sat_width = {1'b1, {(WIDTH-1){1'b0}}};
        else
            sat_width = x[WIDTH-1:0];
    end
endfunction


wire signed [15:0] fft_a_di_re = {{(16-WIDTH){di_re_a[WIDTH-1]}}, di_re_a};
wire signed [15:0] fft_a_di_im = {{(16-WIDTH){di_im_a[WIDTH-1]}}, di_im_a};
wire signed [15:0] fft_b_di_re = {{(16-WIDTH){di_re_b[WIDTH-1]}}, di_re_b};
wire signed [15:0] fft_b_di_im = {{(16-WIDTH){di_im_b[WIDTH-1]}}, di_im_b};

wire ifft_do_en_a;
wire signed [15:0] ifft_do_re_a;
wire signed [15:0] ifft_do_im_a;

wire ifft_do_en_b;
wire signed [15:0] ifft_do_re_b;
wire signed [15:0] ifft_do_im_b;

FFT #(.WIDTH(16)) ifft_a (
    .clock  (clock),
    .reset  (reset),
    .di_en  (di_en_a),
    .di_re  (fft_a_di_re),
    .di_im  (fft_a_di_im),
    .do_en  (ifft_do_en_a),
    .do_re  (ifft_do_re_a),
    .do_im  (ifft_do_im_a)
);

FFT #(.WIDTH(16)) ifft_b (
    .clock  (clock),
    .reset  (reset),
    .di_en  (di_en_b),
    .di_re  (fft_b_di_re),
    .di_im  (fft_b_di_im),
    .do_en  (ifft_do_en_b),
    .do_re  (ifft_do_re_b),
    .do_im  (ifft_do_im_b)
);


reg [6:0] a_out_idx;
reg [6:0] b_out_idx;

wire a_first_half  = (a_out_idx < H);
wire a_second_half = (a_out_idx >= H);
wire b_first_half  = (b_out_idx < H);
wire b_second_half = (b_out_idx >= H);

wire [5:0] a_ola_idx = a_out_idx[5:0];
wire [5:0] b_ola_idx = b_out_idx[5:0];

wire signed [WIDTH-1:0] a_sample = ifft_do_re_a[WIDTH-1:0];
wire signed [WIDTH-1:0] b_sample = ifft_do_re_b[WIDTH-1:0];

// Stores the second half of a frame when the following frame's first half
// is not valid on the same clock.
reg signed [WIDTH-1:0] overlap_mem [0:H-1];

integer i;

// Overlap-add:
//   first half of current frame  + saved previous second half -> output
//   second half of current frame -> saved for next frame
//
// When one lane is producing second-half samples while the other lane is
// producing first-half samples on the same clock, bypass the memory and add
// them directly.

wire signed [WIDTH:0] a_ola_sum;
wire signed [WIDTH:0] b_ola_sum;
wire signed [WIDTH:0] ab_direct_sum;
assign a_ola_sum = $signed({a_sample[WIDTH-1], a_sample}) + $signed({overlap_mem[a_ola_idx][WIDTH-1], overlap_mem[a_ola_idx]});
assign b_ola_sum = $signed({b_sample[WIDTH-1], b_sample}) + $signed({overlap_mem[b_ola_idx][WIDTH-1], overlap_mem[b_ola_idx]});
assign ab_direct_sum = $signed({a_sample[WIDTH-1], a_sample}) + $signed({b_sample[WIDTH-1], b_sample});

always @(posedge clock or posedge reset) begin
    if (reset) begin
        do_en     <= 1'b0;
        do_re     <= {WIDTH{1'b0}};
        a_out_idx <= 7'd0;
        b_out_idx <= 7'd0;

        for (i = 0; i < H; i = i + 1)
            overlap_mem[i] <= {WIDTH{1'b0}};
    end else begin
        do_en <= 1'b0;

        // Direct overlap case: A second half overlaps B first half
        if (ifft_do_en_a && ifft_do_en_b &&
            a_second_half && b_first_half &&
            (a_ola_idx == b_ola_idx)) begin

            do_re <= sat_width(ab_direct_sum);
            do_en <= 1'b1;
        end

        // Direct overlap case: B second half overlaps A first half
        else if (ifft_do_en_a && ifft_do_en_b &&
                 b_second_half && a_first_half &&
                 (a_ola_idx == b_ola_idx)) begin

            do_re <= sat_width(ab_direct_sum);
            do_en <= 1'b1;
        end

        else begin
            // Lane A alone, or non-overlap-aligned lane A
            if (ifft_do_en_a) begin
                if (a_first_half) begin

                    do_re <= sat_width(a_ola_sum);
                    do_en <= 1'b1;
                    overlap_mem[a_ola_idx] <= {WIDTH{1'b0}};
                end else begin
                    overlap_mem[a_ola_idx] <= a_sample;
                end
            end

            // Lane B alone, or non-overlap-aligned lane B
            if (ifft_do_en_b) begin
                if (b_first_half) begin

                    do_re <= sat_width(b_ola_sum);
                    do_en <= 1'b1;
                    overlap_mem[b_ola_idx] <= {WIDTH{1'b0}};
                end else begin
                    overlap_mem[b_ola_idx] <= b_sample;
                end
            end
        end

        if (ifft_do_en_a) begin
            if (a_out_idx == 7'd127)
                a_out_idx <= 7'd0;
            else
                a_out_idx <= a_out_idx + 7'd1;
        end

        if (ifft_do_en_b) begin
            if (b_out_idx == 7'd127)
                b_out_idx <= 7'd0;
            else
                b_out_idx <= b_out_idx + 7'd1;
        end
    end
end

endmodule
