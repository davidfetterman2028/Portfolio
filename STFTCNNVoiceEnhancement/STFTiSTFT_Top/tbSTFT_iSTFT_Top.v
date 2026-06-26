//----------------------------------------------------------------------
// TB: STFT_iSTFT_Top verification testbench
// Uses stim.vh-style tasks:
//   LoadInputData("voiceTest.txt");
//   GenerateInputWave;
//   SaveOutputData("top_verify.csv");
//
// Expected input file format:
//   Hex values read by $readmemh into imem[]
//   imem[2*n]   = real sample
//   imem[2*n+1] = imaginary sample
//----------------------------------------------------------------------
`timescale 1ns/1ns

module tbSTFT_iSTFT_Top #(
    parameter N = 128,
    parameter H = 64,
    parameter numFrames = 128,
    parameter WIDTH = 16,
    parameter MAG_WIDTH = 16,
    parameter PHASE_WIDTH = 16,
    parameter ITER = 16
);

localparam totalSamples = N + (numFrames - 1) * H;
localparam TOTAL_BINS   = numFrames * N;

reg clock;
reg reset;
reg di_en;
reg signed [WIDTH-1:0] di_re;
reg signed [WIDTH-1:0] di_im;

reg signed [WIDTH-1:0] imem [0:2*totalSamples-1];

wire stft_en_a;
wire signed [WIDTH-1:0] stft_re_a;
wire signed [WIDTH-1:0] stft_im_a;
wire stft_en_b;
wire signed [WIDTH-1:0] stft_re_b;
wire signed [WIDTH-1:0] stft_im_b;

wire log_en_a;
wire signed [7:0] log_mag_a;
wire signed [PHASE_WIDTH-1:0] phase_a;
wire log_en_b;
wire signed [7:0] log_mag_b;
wire signed [PHASE_WIDTH-1:0] phase_b;

wire recon_en_a;
wire signed [WIDTH-1:0] recon_re_a;
wire signed [WIDTH-1:0] recon_im_a;
wire recon_en_b;
wire signed [WIDTH-1:0] recon_re_b;
wire signed [WIDTH-1:0] recon_im_b;

wire istft_en_a;
wire signed [WIDTH-1:0] istft_re_a;
wire signed [WIDTH-1:0] istft_im_a;
wire istft_en_b;
wire signed [WIDTH-1:0] istft_re_b;
wire signed [WIDTH-1:0] istft_im_b;

integer stft_count_a;
integer stft_count_b;
integer log_count_a;
integer log_count_b;
integer recon_count_a;
integer recon_count_b;
integer istft_count_a;
integer istft_count_b;

integer stft_fp;
integer log_fp;
integer recon_fp;
integer istft_fp;
integer sample_fp;

// Clock/reset

always begin
    clock = 1'b0; #10;
    clock = 1'b1; #10;
end

initial begin
    reset = 1'b0; #20;
    reset = 1'b1; #100;
    reset = 1'b0;
end

initial begin
    wait (reset == 1'b1);
    di_en = 1'b0;
    di_re = {WIDTH{1'b0}};
    di_im = {WIDTH{1'b0}};
end

// DUT

STFT_iSTFT_Top #(
    .WIDTH(WIDTH),
    .N(N),
    .H(H),
    .MAG_WIDTH(MAG_WIDTH),
    .PHASE_WIDTH(PHASE_WIDTH),
    .ITER(ITER)
) DUT (
    .clock      (clock),
    .reset      (reset),
    .di_en      (di_en),
    .di_re      (di_re),
    .di_im      (di_im),

    .stft_en_a  (stft_en_a),
    .stft_re_a  (stft_re_a),
    .stft_im_a  (stft_im_a),
    .stft_en_b  (stft_en_b),
    .stft_re_b  (stft_re_b),
    .stft_im_b  (stft_im_b),

    .log_en_a   (log_en_a),
    .log_mag_a  (log_mag_a),
    .phase_a    (phase_a),
    .log_en_b   (log_en_b),
    .log_mag_b  (log_mag_b),
    .phase_b    (phase_b),

    .recon_en_a (recon_en_a),
    .recon_re_a (recon_re_a),
    .recon_im_a (recon_im_a),
    .recon_en_b (recon_en_b),
    .recon_re_b (recon_re_b),
    .recon_im_b (recon_im_b),

    .istft_en_a (istft_en_a),
    .istft_re_a (istft_re_a),
    .istft_im_a (istft_im_a),
    .istft_en_b (istft_en_b),
    .istft_re_b (istft_re_b),
    .istft_im_b (istft_im_b)
);

// Input stimulus tasks, compatible with stim.vh pattern

task LoadInputData;
    input [80*8:1] filename;
begin
    $readmemh(filename, imem);
end
endtask

task GenerateInputWave;
    integer n;
begin
    di_en = 1'b0;
    di_re = {WIDTH{1'b0}};
    di_im = {WIDTH{1'b0}};
    @(negedge clock);

    sample_fp = $fopen("input_samples.csv", "w");
    $fdisplay(sample_fp, "sample,re,im");

    for (n = 0; n < totalSamples; n = n + 1) begin
        di_re = imem[2*n];
        di_im = imem[2*n+1];
        di_en = 1'b1;
        $fdisplay(sample_fp, "%0d,%0d,%0d", n, di_re, di_im);
        @(negedge clock);
    end

    $fclose(sample_fp);

    di_en = 1'b0;
    di_re = {WIDTH{1'b0}};
    di_im = {WIDTH{1'b0}};
end
endtask

// Opens all CSV output files.
task OpenOutputFiles;
begin
    stft_fp  = $fopen("stft_complex.csv", "w");
    log_fp   = $fopen("log_features.csv", "w");
    recon_fp = $fopen("reconstructed_complex.csv", "w");
    istft_fp = $fopen("istft_output.csv", "w");

    $fdisplay(stft_fp,  "lane,index,frame,bin,re,im");
    $fdisplay(log_fp,   "lane,index,frame,bin,log_mag,phase");
    $fdisplay(recon_fp, "lane,index,frame,bin,re,im");
    $fdisplay(istft_fp, "lane,index,frame,bin,re,im");
end
endtask

task CloseOutputFiles;
begin
    $fclose(stft_fp);
    $fclose(log_fp);
    $fclose(recon_fp);
    $fclose(istft_fp);
end
endtask

// Kept so the existing stim.vh call to SaveOutputData(...) still works.
// The filename argument is unused because this TB writes separate CSVs live.
task SaveOutputData;
    input [80*8:1] filename;
begin
    CloseOutputFiles;
    $display("Wrote input_samples.csv");
    $display("Wrote stft_complex.csv");
    $display("Wrote log_features.csv");
    $display("Wrote reconstructed_complex.csv");
    $display("Wrote istft_output.csv");
end
endtask

// Live capture. Frame/bin are derived from count.
// For H=64 two-lane STFT:
//   A lane corresponds to even frames:  frame = 2*(index/N)
//   B lane corresponds to odd frames:   frame = 2*(index/N)+1

initial begin
    stft_count_a  = 0;
    stft_count_b  = 0;
    log_count_a   = 0;
    log_count_b   = 0;
    recon_count_a = 0;
    recon_count_b = 0;
    istft_count_a = 0;
    istft_count_b = 0;

    wait (reset == 1'b1);
    wait (reset == 1'b0);
    OpenOutputFiles;
end

always @(negedge clock) begin
    if (stft_en_a) begin
        $fdisplay(stft_fp, "A,%0d,%0d,%0d,%0d,%0d",
            stft_count_a, 2*(stft_count_a/N), stft_count_a%N, stft_re_a, stft_im_a);
        stft_count_a = stft_count_a + 1;
    end

    if (stft_en_b) begin
        $fdisplay(stft_fp, "B,%0d,%0d,%0d,%0d,%0d",
            stft_count_b, 2*(stft_count_b/N)+1, stft_count_b%N, stft_re_b, stft_im_b);
        stft_count_b = stft_count_b + 1;
    end

    if (log_en_a) begin
        $fdisplay(log_fp, "A,%0d,%0d,%0d,%0d,%0d",
            log_count_a, 2*(log_count_a/N), log_count_a%N, log_mag_a, phase_a);
        log_count_a = log_count_a + 1;
    end

    if (log_en_b) begin
        $fdisplay(log_fp, "B,%0d,%0d,%0d,%0d,%0d",
            log_count_b, 2*(log_count_b/N)+1, log_count_b%N, log_mag_b, phase_b);
        log_count_b = log_count_b + 1;
    end

    if (recon_en_a) begin
        $fdisplay(recon_fp, "A,%0d,%0d,%0d,%0d,%0d",
            recon_count_a, 2*(recon_count_a/N), recon_count_a%N, recon_re_a, recon_im_a);
        recon_count_a = recon_count_a + 1;
    end

    if (recon_en_b) begin
        $fdisplay(recon_fp, "B,%0d,%0d,%0d,%0d,%0d",
            recon_count_b, 2*(recon_count_b/N)+1, recon_count_b%N, recon_re_b, recon_im_b);
        recon_count_b = recon_count_b + 1;
    end

    if (istft_en_a) begin
        $fdisplay(istft_fp, "A,%0d,%0d,%0d,%0d,%0d",
            istft_count_a, 2*(istft_count_a/N), istft_count_a%N, istft_re_a, istft_im_a);
        istft_count_a = istft_count_a + 1;
    end

    if (istft_en_b) begin
        $fdisplay(istft_fp, "B,%0d,%0d,%0d,%0d,%0d",
            istft_count_b, 2*(istft_count_b/N)+1, istft_count_b%N, istft_re_b, istft_im_b);
        istft_count_b = istft_count_b + 1;
    end
end

// stim.vh can be reused directly because this TB provides the same tasks
// and frame_a/frame_b aliases used by the old timeout block.

wire [31:0] frame_a = stft_count_a / N;
wire [31:0] frame_b = stft_count_b / N;

`include "stim.vh"

endmodule
