import Types::*;

module IDStage(
    input [31:0] ir,
    input [31:0] pc,
    output [4:0] adr1,
    output [4:0] adr2,
    input [31:0] rs1,
    input [31:0] rs2,
    
    BranchPredictor.ID predictor,
    IBranchControlUnit.ID bcu,
    
    output IDEX_t result
);
    
    opcode_t opcode;
    assign opcode = opcode_t'(ir[6:0]);
    func3_t func3;
    assign func3 = func3_t'(ir[14:12]);
    alusrcA_t srcA;
    alusrcB_t srcB;
    CU_DCDR cu_dcdr(
        .ir(ir),
        
        .int_taken(int_taken),
        .br_eq(br_eq),
        .br_lt(br_lt),
        .br_ltu(br_ltu),
        .alu_srcA(srcA),
        .alu_srcB(srcB),
        .alu_fun(result.alu_fun),
        
        .rf_wr_sel(result.wb.rf_wr_sel),
        .rf_wr_en(result.wb.rf_wr_en),
        
        .mem_read(result.mem.read),
        .mem_write(result.mem.write)
    );

    logic [31:0] j_imm, b_imm, i_imm, u_imm, s_imm;
    ImmedGen imm_gen(
        .ir(ir[31:7]),
        .j_type_imm(j_imm),
        .i_type_imm(i_imm),
        .b_type_imm(b_imm),
        .u_type_imm(u_imm),
        .s_type_imm(s_imm)
    );
    
    logic is_branch;
    assign is_branch = opcode == BRANCH;
    assign is_jump = opcode == JAL;
    
    assign predictor.id_is_branch = is_branch;
    assign predictor.id_branch_type = func3;  
    assign predictor.id_pc = pc;
    
    br_predict_t prediction;
    always_comb case (opcode)
        JAL: begin
            prediction = predict_jump;
        end
        BRANCH: begin
            prediction = predictor.should_branch ? predict_br : predict_nobr;
        end
        default: begin
            prediction = predict_none;
        end
    endcase 
    assign bcu.id_status = prediction;
    
    logic [31:0] jump_target;
    BranchAddrGen bag(
        .pc(pc),
        .rs1(rs1),
        .opcode(opcode),
        .b_type_imm(b_imm),
        .i_type_imm(i_imm),
        .j_type_imm(j_imm),
        .target(jump_target)
    );
    assign predictor.id_target = jump_target;
    assign bcu.id_target = jump_target;
    
    assign adr1 = ir[19:15];
    assign adr2 = ir[24:20];
    
    always_comb case(srcA) 
        alusrc_a_RS1: result.alu_a = rs1;
        alusrc_a_UIMM: result.alu_a = u_imm;
    endcase
    assign result.alu_a_adr = (srcA == alusrc_a_RS1) ? adr1 : 0;
        
    always_comb case(srcB)
        alusrc_b_RS2: result.alu_b = rs2;
        alusrc_b_IIMM: result.alu_b = i_imm;
        alusrc_b_SIMM: result.alu_b = s_imm;
        alusrc_b_PC: result.alu_b = pc;
    endcase
    assign result.alu_b_adr = (srcB == alusrc_b_RS2) ? adr2 : 0;
    
    assign result.pc = pc;
    
    assign result.mem.size = ir[13:12];
    assign result.mem.sign = ir[14];
    assign result.mem.rs2 = rs2; 
    assign result.mem.rs2_adr = adr2; 
    
    assign result.branch_status = prediction;
    assign result.i_imm = i_imm;
    assign result.jump_target = jump_target;
    assign result.func3 = func3;
    assign result.opcode = opcode;
    assign result.wb.wa = ir[11:7];
endmodule
