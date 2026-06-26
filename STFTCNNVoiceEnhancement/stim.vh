//----------------------------------------------------------------------
// Test Stimuli
//----------------------------------------------------------------------
initial begin : STIM
    wait (reset == 1);
    wait (reset == 0);

    repeat (10) @(posedge clock);

    LoadInputData("voiceTest.txt");
    GenerateInputWave;

    repeat (1000) @(posedge clock);
end

initial begin : TIMEOUT
    wait ((frame_a == numFrames/2) && (frame_b == numFrames/2));

    repeat (200) @(posedge clock);

    $display("All Frames Reached");
    SaveOutputData("output4.txt");
    $finish;
end

initial begin
    repeat (200000) @(posedge clock);
    $display("TIMEOUT");
    $finish;
end