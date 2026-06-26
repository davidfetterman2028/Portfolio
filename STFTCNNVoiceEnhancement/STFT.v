//----------------------------------------------------------------------
// STFT: 128-point streaming STFT with H=64 using two staggered FFTs
//----------------------------------------------------------------------
// This version is intended for the current one-sample-per-clock simulation.
// With H=64 and N=128, a new frame starts every 64 samples. One FFT cannot
// consume overlapping frames at the same input clock, so FFT A handles even
// frames and FFT B handles odd frames.
//
// NOTE: Outputs are intentionally separate. For H=64, FFT A and FFT B output
// windows overlap in time, so a single 8-bit complex output stream cannot carry
// all bins without either a faster output clock or an output FIFO/backpressure.
//----------------------------------------------------------------------

module STFT #(
    parameter WIDTH = 16,
    parameter N     = 128,
    parameter H     = 64
)(
    input                       clock,
    input                       reset,
    input                       di_en,
    input signed [WIDTH-1:0]    di_re,
    input signed [WIDTH-1:0]    di_im,

    output                      do_en_a,
    output signed [WIDTH-1:0]   do_re_a,
    output signed [WIDTH-1:0]   do_im_a,

    output                      do_en_b,
    output signed [WIDTH-1:0]   do_re_b,
    output signed [WIDTH-1:0]   do_im_b
);

// Hann window ROM, Q1.15 positive coefficients: 0..32767
localparam WINDOW_FRAC = 15;

function signed [15:0] hann_window;
    input [6:0] idx;
    begin
        case (idx)
        7'd0: hann_window = 16'sd0;
        7'd1: hann_window = 16'sd20;
        7'd2: hann_window = 16'sd80;
        7'd3: hann_window = 16'sd180;
        7'd4: hann_window = 16'sd320;
        7'd5: hann_window = 16'sd499;
        7'd6: hann_window = 16'sd717;
        7'd7: hann_window = 16'sd973;
        7'd8: hann_window = 16'sd1267;
        7'd9: hann_window = 16'sd1597;
        7'd10: hann_window = 16'sd1965;
        7'd11: hann_window = 16'sd2367;
        7'd12: hann_window = 16'sd2803;
        7'd13: hann_window = 16'sd3273;
        7'd14: hann_window = 16'sd3775;
        7'd15: hann_window = 16'sd4308;
        7'd16: hann_window = 16'sd4870;
        7'd17: hann_window = 16'sd5461;
        7'd18: hann_window = 16'sd6078;
        7'd19: hann_window = 16'sd6721;
        7'd20: hann_window = 16'sd7387;
        7'd21: hann_window = 16'sd8075;
        7'd22: hann_window = 16'sd8784;
        7'd23: hann_window = 16'sd9511;
        7'd24: hann_window = 16'sd10254;
        7'd25: hann_window = 16'sd11013;
        7'd26: hann_window = 16'sd11785;
        7'd27: hann_window = 16'sd12569;
        7'd28: hann_window = 16'sd13361;
        7'd29: hann_window = 16'sd14161;
        7'd30: hann_window = 16'sd14967;
        7'd31: hann_window = 16'sd15776;
        7'd32: hann_window = 16'sd16586;
        7'd33: hann_window = 16'sd17396;
        7'd34: hann_window = 16'sd18203;
        7'd35: hann_window = 16'sd19006;
        7'd36: hann_window = 16'sd19803;
        7'd37: hann_window = 16'sd20591;
        7'd38: hann_window = 16'sd21369;
        7'd39: hann_window = 16'sd22135;
        7'd40: hann_window = 16'sd22886;
        7'd41: hann_window = 16'sd23622;
        7'd42: hann_window = 16'sd24340;
        7'd43: hann_window = 16'sd25039;
        7'd44: hann_window = 16'sd25716;
        7'd45: hann_window = 16'sd26371;
        7'd46: hann_window = 16'sd27001;
        7'd47: hann_window = 16'sd27605;
        7'd48: hann_window = 16'sd28181;
        7'd49: hann_window = 16'sd28729;
        7'd50: hann_window = 16'sd29247;
        7'd51: hann_window = 16'sd29733;
        7'd52: hann_window = 16'sd30186;
        7'd53: hann_window = 16'sd30606;
        7'd54: hann_window = 16'sd30990;
        7'd55: hann_window = 16'sd31340;
        7'd56: hann_window = 16'sd31652;
        7'd57: hann_window = 16'sd31927;
        7'd58: hann_window = 16'sd32164;
        7'd59: hann_window = 16'sd32363;
        7'd60: hann_window = 16'sd32522;
        7'd61: hann_window = 16'sd32642;
        7'd62: hann_window = 16'sd32722;
        7'd63: hann_window = 16'sd32762;
        7'd64: hann_window = 16'sd32762;
        7'd65: hann_window = 16'sd32722;
        7'd66: hann_window = 16'sd32642;
        7'd67: hann_window = 16'sd32522;
        7'd68: hann_window = 16'sd32363;
        7'd69: hann_window = 16'sd32164;
        7'd70: hann_window = 16'sd31927;
        7'd71: hann_window = 16'sd31652;
        7'd72: hann_window = 16'sd31340;
        7'd73: hann_window = 16'sd30990;
        7'd74: hann_window = 16'sd30606;
        7'd75: hann_window = 16'sd30186;
        7'd76: hann_window = 16'sd29733;
        7'd77: hann_window = 16'sd29247;
        7'd78: hann_window = 16'sd28729;
        7'd79: hann_window = 16'sd28181;
        7'd80: hann_window = 16'sd27605;
        7'd81: hann_window = 16'sd27001;
        7'd82: hann_window = 16'sd26371;
        7'd83: hann_window = 16'sd25716;
        7'd84: hann_window = 16'sd25039;
        7'd85: hann_window = 16'sd24340;
        7'd86: hann_window = 16'sd23622;
        7'd87: hann_window = 16'sd22886;
        7'd88: hann_window = 16'sd22135;
        7'd89: hann_window = 16'sd21369;
        7'd90: hann_window = 16'sd20591;
        7'd91: hann_window = 16'sd19803;
        7'd92: hann_window = 16'sd19006;
        7'd93: hann_window = 16'sd18203;
        7'd94: hann_window = 16'sd17396;
        7'd95: hann_window = 16'sd16586;
        7'd96: hann_window = 16'sd15776;
        7'd97: hann_window = 16'sd14967;
        7'd98: hann_window = 16'sd14161;
        7'd99: hann_window = 16'sd13361;
        7'd100: hann_window = 16'sd12569;
        7'd101: hann_window = 16'sd11785;
        7'd102: hann_window = 16'sd11013;
        7'd103: hann_window = 16'sd10254;
        7'd104: hann_window = 16'sd9511;
        7'd105: hann_window = 16'sd8784;
        7'd106: hann_window = 16'sd8075;
        7'd107: hann_window = 16'sd7387;
        7'd108: hann_window = 16'sd6721;
        7'd109: hann_window = 16'sd6078;
        7'd110: hann_window = 16'sd5461;
        7'd111: hann_window = 16'sd4870;
        7'd112: hann_window = 16'sd4308;
        7'd113: hann_window = 16'sd3775;
        7'd114: hann_window = 16'sd3273;
        7'd115: hann_window = 16'sd2803;
        7'd116: hann_window = 16'sd2367;
        7'd117: hann_window = 16'sd1965;
        7'd118: hann_window = 16'sd1597;
        7'd119: hann_window = 16'sd1267;
        7'd120: hann_window = 16'sd973;
        7'd121: hann_window = 16'sd717;
        7'd122: hann_window = 16'sd499;
        7'd123: hann_window = 16'sd320;
        7'd124: hann_window = 16'sd180;
        7'd125: hann_window = 16'sd80;
        7'd126: hann_window = 16'sd20;
        7'd127: hann_window = 16'sd0;
            default: hann_window = 16'sd0;
        endcase
    end
endfunction

//----------------------------------------------------------------------
// Sample counter and staggered frame control
//----------------------------------------------------------------------
reg [6:0] sample_mod;
reg       a_active;
reg       b_active;
reg [6:0] a_cnt;
reg [6:0] b_cnt;

wire start_a = di_en && (sample_mod == 7'd0);
wire start_b = di_en && (sample_mod == 7'd64);

wire a_feed_en = di_en && (a_active || start_a);
wire b_feed_en = di_en && (b_active || start_b);

wire [6:0] a_win_idx = start_a ? 7'd0 : a_cnt;
wire [6:0] b_win_idx = start_b ? 7'd0 : b_cnt;

/*always @(posedge clock) begin
    if (!reset) begin
    //     if (a_feed_en) begin
    //         $display("A_FEED t=%0t idx=%0d re=%0d im=%0d",
    //             $time, a_win_idx, fft_a_di_re, fft_a_di_im);
    //     end

    //     if (b_feed_en) begin
    //         $display("B_FEED t=%0t idx=%0d re=%0d im=%0d",
    //             $time, b_win_idx, fft_b_di_re, fft_b_di_im);
    //     end
    end

end */

always @(posedge clock or posedge reset) begin
    if (reset) begin
        sample_mod <= 7'd0;
        a_active   <= 1'b0;
        b_active   <= 1'b0;
        a_cnt      <= 7'd0;
        b_cnt      <= 7'd0;
    end else begin
        if (di_en) begin
            sample_mod <= sample_mod + 7'd1;
        end

        if (a_feed_en) begin
            if (a_win_idx == 7'd127) begin
                a_active <= 1'b0;
                a_cnt    <= 7'd0;
            end else begin
                a_active <= 1'b1;
                a_cnt    <= a_win_idx + 7'd1;
            end
        end

        if (b_feed_en) begin
            if (b_win_idx == 7'd127) begin
                b_active <= 1'b0;
                b_cnt    <= 7'd0;
            end else begin
                b_active <= 1'b1;
                b_cnt    <= b_win_idx + 7'd1;
            end
        end
    end
end
// Windowing, Q1.15 multiply. signed WIDTH-bit sample * positive Q1.15 coeff.
wire signed [15:0] win_a = hann_window(a_win_idx);
wire signed [15:0] win_b = hann_window(b_win_idx);

wire signed [WIDTH+15:0] mult_a_re = $signed(di_re) * win_a;
wire signed [WIDTH+15:0] mult_a_im = $signed(di_im) * win_a;
wire signed [WIDTH+15:0] mult_b_re = $signed(di_re) * win_b;
wire signed [WIDTH+15:0] mult_b_im = $signed(di_im) * win_b;

wire signed [WIDTH-1:0] win_a_re = mult_a_re >>> WINDOW_FRAC;
wire signed [WIDTH-1:0] win_a_im = mult_a_im >>> WINDOW_FRAC;
wire signed [WIDTH-1:0] win_b_re = mult_b_re >>> WINDOW_FRAC;
wire signed [WIDTH-1:0] win_b_im = mult_b_im >>> WINDOW_FRAC;

wire signed [15:0] fft_a_di_re = {{(16-WIDTH){win_a_re[WIDTH-1]}}, win_a_re};
wire signed [15:0] fft_a_di_im = {{(16-WIDTH){win_a_im[WIDTH-1]}}, win_a_im};
wire signed [15:0] fft_b_di_re = {{(16-WIDTH){win_b_re[WIDTH-1]}}, win_b_re};
wire signed [15:0] fft_b_di_im = {{(16-WIDTH){win_b_im[WIDTH-1]}}, win_b_im};


FFT #(.WIDTH(16)) fft_a (
    .clock  (clock),
    .reset  (reset),
    .di_en  (a_feed_en),
    .di_re  (fft_a_di_re),
    .di_im  (fft_a_di_im),
    .do_en  (do_en_a),
    .do_re  (do_re_a),
    .do_im  (do_im_a)
);

FFT #(.WIDTH(16)) fft_b (
    .clock  (clock),
    .reset  (reset),
    .di_en  (b_feed_en),
    .di_re  (fft_b_di_re),
    .di_im  (fft_b_di_im),
    .do_en  (do_en_b),
    .do_re  (do_re_b),
    .do_im  (do_im_b)
);

endmodule
