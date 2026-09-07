`timescale 1ns / 1ps

module pge_axi_wrapper # (
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)(
    input  wire                                 aclk,
    input  wire                                 aresetn,

    // -------------------------------------------------------------------------
    // AXI4-Stream Slave: Instruction Channel (64-bit)
    // -------------------------------------------------------------------------
    input  wire [63:0]                          s_axis_instr_tdata,
    input  wire                                 s_axis_instr_tvalid,
    output wire                                 s_axis_instr_tready,

    // -------------------------------------------------------------------------
    // AXI4-Stream Slave: Riverine Data Ingestion Channel (32-bit)
    // -------------------------------------------------------------------------
    input  wire [31:0]                          s_axis_data_tdata,
    input  wire                                 s_axis_data_tvalid,
    output wire                                 s_axis_data_tready,

    // -------------------------------------------------------------------------
    // AXI4-Stream Master: Retirement / Commit Channel (32-bit)
    // -------------------------------------------------------------------------
    output reg  [31:0]                          m_axis_commit_tdata,
    output reg                                  m_axis_commit_tvalid,
    input  wire                                 m_axis_commit_tready,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave: Trust Control & Status Registers
    // -------------------------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire                                 s_axi_awvalid,
    output reg                                  s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire [3:0]                           s_axi_wstrb,
    input  wire                                 s_axi_wvalid,
    output reg                                  s_axi_wready,
    output reg  [1:0]                           s_axi_bresp,
    output reg                                  s_axi_bvalid,
    input  wire                                 s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire                                 s_axi_arvalid,
    output reg                                  s_axi_arready,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output reg  [1:0]                           s_axi_rresp,
    output reg                                  s_axi_rvalid,
    input  wire                                 s_axi_rready
);

    // Register Mapping:
    // 0x0: Control / Trap Ack (Bit 0: trap_ack)
    // 0x4: Trust Configuration (Bits [7:0]: cfg_trust_ceiling)
    // 0x8: Status Register (Bit 0: evidentiality_fault, Bit 1: piw_ready, Bit 2: commit_stalled)
    reg [7:0]  cfg_trust_ceiling;
    reg        trap_ack_reg;
    wire       evidentiality_fault_wire;
    wire       piw_ready_wire;

    wire [31:0] core_commit_tdata;
    wire        core_commit_tvalid;

    // Buffer output stall condition
    wire commit_stall = m_axis_commit_tvalid && !m_axis_commit_tready;

    // Gate instruction ingestion if core faulted OR commit channel is backpressured
    assign s_axis_data_tready  = 1'b1;
    assign s_axis_instr_tready = piw_ready_wire && !evidentiality_fault_wire && !commit_stall;

    // -------------------------------------------------------------------------
    // Core Instantiation
    // -------------------------------------------------------------------------
    pge_pipeline_core pge_core_inst (
        .clk                 (aclk),
        .rst_n               (aresetn),
        .piw_instruction     (s_axis_instr_tdata),
        .piw_valid           (s_axis_instr_tvalid && s_axis_instr_tready),
        .piw_ready           (piw_ready_wire),
        .trap_ack            (trap_ack_reg),
        .cfg_trust_ceiling   (cfg_trust_ceiling),
        .stream_in_data      (s_axis_data_tdata),
        .stream_in_valid     (s_axis_data_tvalid),
        .pipeline_out_data   (core_commit_tdata),
        .pipeline_out_valid  (core_commit_tvalid),
        .evidentiality_fault (evidentiality_fault_wire)
    );

    // -------------------------------------------------------------------------
    // Master Stream Commit Holding / Skid Buffer
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axis_commit_tdata  <= 32'd0;
            m_axis_commit_tvalid <= 1'b0;
        end else begin
            if (m_axis_commit_tvalid && m_axis_commit_tready) begin
                if (core_commit_tvalid) begin
                    m_axis_commit_tdata  <= core_commit_tdata;
                    m_axis_commit_tvalid <= 1'b1;
                end else begin
                    m_axis_commit_tvalid <= 1'b0;
                end
            end else if (!m_axis_commit_tvalid && core_commit_tvalid) begin
                m_axis_commit_tdata  <= core_commit_tdata;
                m_axis_commit_tvalid <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Decoupled AXI-Lite Control Bus Logic
    // -------------------------------------------------------------------------
    reg aw_en;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_latched;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_wdata_latched;
    reg aw_received;
    reg w_received;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready      <= 1'b0;
            s_axi_wready       <= 1'b0;
            s_axi_bvalid       <= 1'b0;
            s_axi_bresp        <= 2'b00;
            aw_en              <= 1'b1;
            aw_received        <= 1'b0;
            w_received         <= 1'b0;
            axi_awaddr_latched <= 0;
            axi_wdata_latched  <= 0;
            cfg_trust_ceiling  <= 8'h01; // Default: INFERRED
            trap_ack_reg       <= 1'b0;
        end else begin
            if (trap_ack_reg) trap_ack_reg <= 1'b0;

            // Address write latching
            if (~s_axi_awready && s_axi_awvalid && aw_en && !aw_received) begin
                s_axi_awready      <= 1'b1;
                axi_awaddr_latched <= s_axi_awaddr;
                aw_received        <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end

            // Data write latching
            if (~s_axi_wready && s_axi_wvalid && aw_en && !w_received) begin
                s_axi_wready      <= 1'b1;
                axi_wdata_latched <= s_axi_wdata;
                w_received        <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end

            // Execution of write once both phases are captured
            if (aw_received && w_received && ~s_axi_bvalid) begin
                aw_en       <= 1'b0;
                aw_received <= 1'b0;
                w_received  <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY

                case (axi_awaddr_latched[3:0])
                    4'h0: if (axi_wdata_latched[0]) trap_ack_reg <= 1'b1;
                    4'h4: cfg_trust_ceiling <= axi_wdata_latched[7:0];
                    default: ;
                endcase
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_en        <= 1'b1;
            end

            // Read Address Channel
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                case (s_axi_araddr[3:0])
                    4'h0: s_axi_rdata <= {31'd0, trap_ack_reg};
                    4'h4: s_axi_rdata <= {24'd0, cfg_trust_ceiling};
                    4'h8: s_axi_rdata <= {29'd0, commit_stall, piw_ready_wire, evidentiality_fault_wire};
                    default: s_axi_rdata <= 32'd0;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            // Read Data Channel
            if (s_axi_arready && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
