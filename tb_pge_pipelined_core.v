`timescale 1ns / 1ps

module tb_pge_pipelined_core;

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

    // Instantiate Pipelined RTL Core
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

    // 100MHz Reference Clock
    always #5 clk = ~clk;

    task step_clock;
        begin
            @(posedge clk);
            #1;
        end
    endtask

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
        clk               = 0;
        rst_n             = 0;
        piw_instruction   = 64'd0;
        piw_valid         = 0;
        trap_ack          = 0;
        cfg_trust_ceiling = 8'h01; // INFERRED
        stream_in_data    = 32'd0;
        stream_in_valid   = 0;

        #20;
        rst_n = 1;
        step_clock();

        $display("=== TEST 1: Simultaneous Write-Forwarding Bypass ===");
        // Assert stream ingestion and a simultaneous read from VEC_CURRENT
        // ring_mem is empty, head_ptr = 0. We ingest value 42 and execute TRANSVECT concurrently.
        stream_in_data    = 32'd42;
        stream_in_valid   = 1;
        piw_instruction   = encode_piw(8'h01, 8'h01, 8'h00, 8'h00, 16'h0, 16'd8); // TRANSVECT, Current, +8
        piw_valid         = 1;
        step_clock();

        // Deassert inputs; instruction is now transitioning from OF to EX
        stream_in_valid   = 0;
        piw_valid         = 0;
        step_clock(); // Cycle for EX stage execution

        // Commit the accumulator to verify bypass took place
        piw_instruction   = encode_piw(8'h05, 8'h02, 8'h00, 8'h00, 16'h0, 16'h0); // COMMIT
        piw_valid         = 1;
        step_clock();
        piw_valid         = 0;

        // Wait for COMMIT retirement through OF -> EX
        while (!pipeline_out_valid) step_clock();

        // Expected: operand (42 via forwarding) + payload (8) = 50
        if (pipeline_out_data !== 32'd50) begin
            $display("[FAIL] Forwarding mismatch. Expected 50, got: %d", pipeline_out_data);
            $stop;
        end else begin
            $display("[PASS] Write-forwarding bypass resolved 42 + 8 = 50 across pipeline split.");
        end

        $display("=== TEST 2: Back-to-Back Instruction Pacing (No Stalls) ===");
        // Seed stream with value 10
        stream_in_data  = 32'd10;
        stream_in_valid = 1;
        step_clock();
        stream_in_valid = 0;

        // Inst 1: TRANSVECT (CurrentPos: 10 + payload: 5) -> Acc = 15
        piw_instruction = encode_piw(8'h01, 8'h01, 8'h00, 8'h00, 16'h0, 16'd5);
        piw_valid = 1;
        step_clock();

        // Inst 2: FUSE Imperfective (Acc ^ 10 + payload: 2) -> (15 ^ 10) + 2 = 5 + 2 = 7
        piw_instruction = encode_piw(8'h02, 8'h01, 8'h00, 8'h00, 16'h0, 16'd2);
        piw_valid = 1;
        step_clock();

        // Inst 3: COMMIT
        piw_instruction = encode_piw(8'h05, 8'h02, 8'h00, 8'h00, 16'h0, 16'h0);
        piw_valid = 1;
        step_clock();
        piw_valid = 0;

        while (!pipeline_out_valid) step_clock();

        if (pipeline_out_data !== 32'd7) begin
            $display("[FAIL] Pipelined dependency mismatch. Expected 7, got: %d", pipeline_out_data);
            $stop;
        end else begin
            $display("[PASS] Back-to-back execution maintained RAW accumulator dependency (result = 7).");
        end

        $display("\n>> ALL PIPELINED SYNTHESIS CHECKS PASSED <<\n");
        $finish;
    end

endmodule
