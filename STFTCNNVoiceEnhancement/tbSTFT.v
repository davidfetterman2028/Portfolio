//----------------------------------------------------------------------
// TB: STFT H=64 two-FFT testbench
//----------------------------------------------------------------------
`timescale 1ns/1ns
module tbSTFT #(
    parameter N = 128,
    parameter H = 64,
    parameter numFrames = 128,
    parameter WIDTH = 16
);

localparam totalSamples = N + (numFrames - 1) * H; // 8256 for 128 frames

reg clock;
reg reset;
reg di_en;
reg signed [15:0] di_re;
reg signed [15:0] di_im;

wire do_en_a;
wire signed [WIDTH-1:0] do_re_a;
wire signed [WIDTH-1:0] do_im_a;
wire do_en_b;
wire signed [WIDTH-1:0] do_re_b;
wire signed [WIDTH-1:0] do_im_b;

reg signed [15:0] imem [0:2*totalSamples-1];
reg signed [15:0] omem_a [0:(numFrames/2)-1][0:2*N-1];
reg signed [15:0] omem_b [0:(numFrames/2)-1][0:2*N-1];

wire signed [15:0] di_re_ext;
wire signed [15:0] di_im_ext;

assign di_re_ext = di_re;
assign di_im_ext = di_im;

//assign di_re_ext = $signed(di_re) <<< 8;
//assign di_im_ext = $signed(di_im) <<< 8;

always begin
    clock = 0; #10;
    clock = 1; #10;
end

initial begin
    reset = 0; #20;
    reset = 1; #100;
    reset = 0;
end

initial begin
    wait (reset == 1);
    di_en = 0;
    di_re = 0;
    di_im = 0;
end

integer frame_a;
integer frame_b;
integer bin_a;
integer bin_b;

initial begin
    $dumpfile("stft.vcd");
    $dumpvars(0, tbSTFT);
end

initial begin : OCAP_A
    frame_a = 0;
    bin_a = 0;
    forever begin
        @(negedge clock);
        if (do_en_a) begin
            omem_a[frame_a][2*bin_a]   = do_re_a;
            omem_a[frame_a][2*bin_a+1] = do_im_a;
            bin_a = bin_a + 1;
            if (bin_a == N) begin
                bin_a = 0;
                frame_a = frame_a + 1;
            end
        end
    end
end

initial begin : OCAP_B
    frame_b = 0;
    bin_b = 0;
    forever begin
        @(negedge clock);
        if (do_en_b) begin
            omem_b[frame_b][2*bin_b]   = do_re_b;
            omem_b[frame_b][2*bin_b+1] = do_im_b;
            bin_b = bin_b + 1;
            if (bin_b == N) begin
                bin_b = 0;
                frame_b = frame_b + 1;
            end
        end
    end
end

task LoadInputData;
    input [80*8:1] filename;
begin
    $readmemh(filename, imem);
end
endtask

task GenerateInputWave;
    integer n;
begin
    di_en = 0;
    di_re = 0;
    di_im = 0;
    @(negedge clock);

    for (n = 0; n < totalSamples; n = n + 1) begin
        di_re = imem[2*n];
        di_im = imem[2*n+1];
        di_en = 1;
        @(negedge clock);
    end

    di_en = 0;
    di_re = 0;
    di_im = 0;
end
endtask

task SaveOutputData;
    input [80*8:1] filename;
    integer fp, f, k;
begin
    fp = $fopen(filename);
    // Interleave A/B frames back into natural STFT frame order:
    // frame 0 = A0, frame 1 = B0, frame 2 = A1, frame 3 = B1, ...
    for (f = 0; f < numFrames; f = f + 1) begin
        for (k = 0; k < N; k = k + 1) begin
            if (f[0] == 1'b0) begin
                $fdisplay(fp, "%0d %0d %0d %0d", f, k,
                    omem_a[f>>1][2*k], omem_a[f>>1][2*k+1]);
            end else begin
                $fdisplay(fp, "%0d %0d %0d %0d", f, k,
                    omem_b[f>>1][2*k], omem_b[f>>1][2*k+1]);
            end
        end
    end
    
    $fclose(fp);
end
endtask

STFT #(.WIDTH(16), .N(N), .H(H)) STFT (
    .clock   (clock),
    .reset   (reset),
    .di_en   (di_en),
    .di_re   (di_re_ext),
    .di_im   (di_im_ext),
    .do_en_a (do_en_a),
    .do_re_a (do_re_a),
    .do_im_a (do_im_a),
    .do_en_b (do_en_b),
    .do_re_b (do_re_b),
    .do_im_b (do_im_b)
);

`include "stim.vh"

endmodule
