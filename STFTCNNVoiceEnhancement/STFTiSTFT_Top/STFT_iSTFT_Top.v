//----------------------------------------------------------------------
// Top: STFT -> optional Mag/Phase + Log features -> iSTFT
//
// The iSTFT module in this project accepts the two staggered STFT lanes
// directly and produces one overlap-added reconstructed audio stream.
//
// For IFFT-by-forward-FFT, the imaginary FFT bins are conjugated here before
// being sent into iSTFT. The real part is not negated.
//----------------------------------------------------------------------

module STFT_iSTFT_Top #(
    parameter WIDTH       = 16,
    parameter N           = 128,
    parameter H           = 64,
    parameter MAG_WIDTH   = 16,
    parameter PHASE_WIDTH = 16,
    parameter ITER        = 16,
    parameter [MAG_WIDTH-1:0] MAG_FLOOR = 16'd22937
)(
    input                       clock,
    input                       reset,
    input                       di_en,
    input signed [WIDTH-1:0]    di_re,
    input signed [WIDTH-1:0]    di_im,

    // STFT complex outputs, useful for debugging/reference capture
    output                      stft_en_a,
    output signed [WIDTH-1:0]   stft_re_a,
    output signed [WIDTH-1:0]   stft_im_a,
    output                      stft_en_b,
    output signed [WIDTH-1:0]   stft_re_b,
    output signed [WIDTH-1:0]   stft_im_b,

    // Log-magnitude streams, useful as CNN input pixels/features
    output                      log_en_a,
    output signed [7:0]         log_mag_a,
    output signed [PHASE_WIDTH-1:0] phase_a,
    output                      log_en_b,
    output signed [7:0]         log_mag_b,
    output signed [PHASE_WIDTH-1:0] phase_b,

    // Complex frequency-domain streams sent into iSTFT.
    // These are the conjugated STFT bins for IFFT-by-FFT.
    output                      recon_en_a,
    output signed [WIDTH-1:0]   recon_re_a,
    output signed [WIDTH-1:0]   recon_im_a,
    output                      recon_en_b,
    output signed [WIDTH-1:0]   recon_re_b,
    output signed [WIDTH-1:0]   recon_im_b,

    // Final overlap-added reconstructed audio stream
    output                      istft_en,
    output signed [WIDTH-1:0]   istft_re,

    // Legacy/debug ports kept so your existing tbSTFT_iSTFT_Top.v still compiles.
    // Since iSTFT now performs overlap-add internally, only lane A carries the
    // final reconstructed stream. Lane B is held at zero.
    output                      istft_en_a,
    output signed [WIDTH-1:0]   istft_re_a,
    output signed [WIDTH-1:0]   istft_im_a,
    output                      istft_en_b,
    output signed [WIDTH-1:0]   istft_re_b,
    output signed [WIDTH-1:0]   istft_im_b
);

//----------------------------------------------------------------------
// Signed negation with saturation for the most-negative value.
//----------------------------------------------------------------------
function signed [WIDTH-1:0] neg_sat;
    input signed [WIDTH-1:0] x;
    begin
        if (x == {1'b1, {(WIDTH-1){1'b0}}})
            neg_sat = {1'b0, {(WIDTH-1){1'b1}}};
        else
            neg_sat = -x;
    end
endfunction

//----------------------------------------------------------------------
// STFT front end
//----------------------------------------------------------------------
STFT #(
    .WIDTH(WIDTH),
    .N(N),
    .H(H)
) u_stft (
    .clock   (clock),
    .reset   (reset),
    .di_en   (di_en),
    .di_re   (di_re),
    .di_im   (di_im),
    .do_en_a (stft_en_a),
    .do_re_a (stft_re_a),
    .do_im_a (stft_im_a),
    .do_en_b (stft_en_b),
    .do_re_b (stft_re_b),
    .do_im_b (stft_im_b)
);

//----------------------------------------------------------------------
// Lane A: complex STFT -> mag/phase -> log magnitude
//----------------------------------------------------------------------
wire [MAG_WIDTH-1:0] mag_a;
wire                 magphase_en_a;

MagPhase #(
    .WIDTH(WIDTH),
    .MAG_WIDTH(MAG_WIDTH),
    .PHASE_WIDTH(PHASE_WIDTH),
    .ITER(ITER)
) u_magphase_a (
    .clock     (clock),
    .reset     (reset),
    .in_en     (stft_en_a),
    .in_re     (stft_re_a),
    .in_im     (stft_im_a),
    .out_en    (magphase_en_a),
    .mag_out   (mag_a),
    .phase_out (phase_a)
);

LogNormalize #(
    .MAG_WIDTH(MAG_WIDTH),
    .MAG_FLOOR(MAG_FLOOR)
) u_log_a (
    .clock      (clock),
    .reset      (reset),
    .in_en      (magphase_en_a),
    .in_mag     (mag_a),
    .out_en     (log_en_a),
    .logMag_out (log_mag_a)
);

//----------------------------------------------------------------------
// Lane B: complex STFT -> mag/phase -> log magnitude
//----------------------------------------------------------------------
wire [MAG_WIDTH-1:0] mag_b;
wire                 magphase_en_b;

MagPhase #(
    .WIDTH(WIDTH),
    .MAG_WIDTH(MAG_WIDTH),
    .PHASE_WIDTH(PHASE_WIDTH),
    .ITER(ITER)
) u_magphase_b (
    .clock     (clock),
    .reset     (reset),
    .in_en     (stft_en_b),
    .in_re     (stft_re_b),
    .in_im     (stft_im_b),
    .out_en    (magphase_en_b),
    .mag_out   (mag_b),
    .phase_out (phase_b)
);

LogNormalize #(
    .MAG_WIDTH(MAG_WIDTH),
    .MAG_FLOOR(MAG_FLOOR)
) u_log_b (
    .clock      (clock),
    .reset      (reset),
    .in_en      (magphase_en_b),
    .in_mag     (mag_b),
    .out_en     (log_en_b),
    .logMag_out (log_mag_b)
);

//----------------------------------------------------------------------
// iSTFT input path
//----------------------------------------------------------------------
// Right now this is a direct STFT -> iSTFT reconstruction path. The log stream
// is still exposed for the CNN, but it is not converted back to complex because
// UnlogNormalize / PhaseMagToComplex modules were not included in the current
// uploaded source set.
//
// For IFFT using the forward FFT core:
//   X_ifft_input = conjugate(X_stft) = real unchanged, imag negated.
//----------------------------------------------------------------------
assign recon_en_a = stft_en_a;
assign recon_re_a = stft_re_a;
assign recon_im_a = neg_sat(stft_im_a);

assign recon_en_b = stft_en_b;
assign recon_re_b = stft_re_b;
assign recon_im_b = neg_sat(stft_im_b);

//----------------------------------------------------------------------
// iSTFT back end: consumes both staggered FFT lanes and performs overlap-add.
//----------------------------------------------------------------------
iSTFT #(
    .WIDTH(WIDTH),
    .N(N),
    .H(H)
) u_istft (
    .clock   (clock),
    .reset   (reset),
    .di_en_a (recon_en_a),
    .di_re_a (recon_re_a),
    .di_im_a (recon_im_a),
    .di_en_b (recon_en_b),
    .di_re_b (recon_re_b),
    .di_im_b (recon_im_b),
    .do_en   (istft_en),
    .do_re   (istft_re)
);

assign istft_en_a = istft_en;
assign istft_re_a = istft_re;
assign istft_im_a = {WIDTH{1'b0}};

assign istft_en_b = 1'b0;
assign istft_re_b = {WIDTH{1'b0}};
assign istft_im_b = {WIDTH{1'b0}};

endmodule
