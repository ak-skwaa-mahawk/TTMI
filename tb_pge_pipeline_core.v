`timescale 1ns / 1ps

module tb_pge_pipeline_core;

    reg         clk;
    reg         rst_n;
    reg  [63:0] piw_instruction;
    reg         piw_valid;
    wire        piw_ready;
    reg         trap_ack;
    reg  [7:0]  cfg_trust_ceiling;
    reg  [31:0] stream_in_data;
    reg         stream_in_valid;
    wire [31:0] pipeline_out_data;
    wire        pipeline_out_valid;
    wire        evidentiality_fault;

    // Instantiate Device Under Test (DUT)
    pge_pipeline_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .piw_instruction(piw_instruction),
        .piw_valid(piw_valid),
        .piw_ready(piw_ready),
        .trap_ack(trap_ack),
        .cfg_trust_ceiling(cfg_trust_ceiling),
        .stream_in_data(stream_in_data),
        .stream_in_valid(stream_in_valid),
        .pipeline_out_data(pipeline_out_data),
        .pipeline_out_valid(pipeline_out_valid),
        .evidentiality_fault(evidentiality_fault)
    );

    // Clock Generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    task step_clock;
        begin
            @(posedge clk);
            #1; // Hold-time margin
        end
    endtask

    // Instruction Encoder Helper
    function [63:0] encode_piw(
        input [7:0]  stem,
        input [7:0]  aspect,
        input [7:0]  evid,
        input [7:0]  vector,
        input [15:0] acc,
        input [15:0] payload
    );
        encode_piw = {stem, aspect, evid, vector, acc, payload};
    endfunction

    initial begin
        // Initialize Signals
        clk               = 0;
        rst_n             = 0;
        piw_instruction   = 64'd0;
        piw_valid         = 0;
        trap_ack          = 0;
        cfg_trust_ceiling = 8'h01; // Ceiling = INFERRED
        stream_in_data    = 32'd0;
        stream_in_valid   = 0;

        // Reset Sequence
        #20;
        rst_n = 1;
        step_clock();

        $display("=== TEST 1: Ring Buffer Saturation and Head Advancement ===");
        // Stream in 18 values to saturate 16-word buffer and trigger 2 head advances
        // Ingested: 1 to 18. Elements remaining: 3 through 18. CurrentPos should be 3.
        for (integer i = 1; i <= 18; i = i + 1) begin
            stream_in_data  = i;
            stream_in_valid = 1;
            step_clock();
        end
        stream_in_valid = 0;
        step_clock();

        // Validate head advancement: Read CURRENT_POS (must equal 3)
        // PIW: STEM_TRANSVECT, ASPECT_IMPERFECTIVE, EVID_DIRECT (0), VEC_CURRENT (0), Payload = 0
        piw_instruction = encode_piw(8'h01, 8'h01, 8'h00, 8'h00, 16'h0, 16'h0);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;
        step_clock();

        // Output check via commit: STEM_COMMIT, PERFECTIVE, DIRECT, CURRENT
        piw_instruction = encode_piw(8'h05, 8'h02, 8'h00, 8'h00, 16'h0, 16'h0);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;
        
        while (!pipeline_out_valid) step_clock();
        if (pipeline_out_data !== 32'd3) begin
            $display("[FAIL] Saturation mismatch. Expected head value 3, got: %d", pipeline_out_data);
            $stop;
        end else begin
            $display("[PASS] Buffer saturation correctly advanced head_ptr to 3.");
        end

        $display("=== TEST 2: Hardware Trap Assert and Recovery ===");
        // Inject EVID_REPORTED (0x02) against trust ceiling of INFERRED (0x01)
        piw_instruction = encode_piw(8'h01, 8'h01, 8'h02, 8'h00, 16'h0, 16'h000A);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;
        step_clock();

        if (evidentiality_fault !== 1'b1 || piw_ready !== 1'b0) begin
            $display("[FAIL] Security trap did not assert! fault=%b, ready=%b", evidentiality_fault, piw_ready);
            $stop;
        end else begin
            $display("[PASS] Evidential fault asserted; pipeline gate locked.");
        end

        // Assert trap_ack to resume pipeline
        trap_ack = 1;
        step_clock();
        trap_ack = 0;
        step_clock();

        if (evidentiality_fault !== 1'b0 || piw_ready !== 1'b1) begin
            $display("[FAIL] Recovery failed! fault=%b, ready=%b", evidentiality_fault, piw_ready);
            $stop;
        end else begin
            $display("[PASS] Pipeline unstalled via trap_ack.");
        end

        $display("=== TEST 3: STEM_TRANSFORM Endianness Byte Swap ===");
        // Preload accumulator using TRANSVECT with immediate:
        // Set accumulator to 0x12345678 via direct transvect
        // Current accumulator = 0. Stream head = 3. Payload = 0x12345678 - 3 = 0x12345675
        // Use 2 steps to inject wide immediate:
        // Step A: Load base via direct transform
        // Transform ITERATIVE: endian inversion of accumulator (0x12345678 -> 0x78563412)
        
        // Directly seed accumulator:
        dut.accumulator = 32'h12345678; // Backdoor injection for exact bit validation
        
        // Execute STEM_TRANSFORM with ASPECT_ITERATIVE (0x03) and payload = 0
        piw_instruction = encode_piw(8'h03, 8'h03, 8'h00, 8'h00, 16'h0, 16'h0000);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;
        step_clock();

        // Commit and verify
        piw_instruction = encode_piw(8'h05, 8'h02, 8'h00, 8'h00, 16'h0, 16'h0);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;

        while (!pipeline_out_valid) step_clock();
        if (pipeline_out_data !== 32'h78563412) begin
            $display("[FAIL] Endian inversion mismatch. Expected 0x78563412, got: 0x%h", pipeline_out_data);
            $stop;
        end else begin
            $display("[PASS] STEM_TRANSFORM byte swap accurately produced 0x78563412.");
        end

        $display("\n>> ALL HARDWARE AUDIT CHECKS PASSED <<\n");
        $finish;
    end

endmodule
