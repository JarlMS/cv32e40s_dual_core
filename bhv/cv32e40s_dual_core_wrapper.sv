module cv32e40s_dual_core_wrapper
  import cv32e40s_pkg::*;
#(
  parameter              LIB                          = 0,
  parameter rv32_e       RV32                         = RV32I,
  parameter b_ext_e      B_EXT                        = B_NONE,
  parameter m_ext_e      M_EXT                        = M,
  parameter int unsigned PMP_GRANULARITY              = 0,
  parameter int          PMP_NUM_REGIONS              = 0,
  parameter pmpncfg_t    PMP_PMPNCFG_RV[PMP_NUM_REGIONS-1:0] = '{default:PMPNCFG_DEFAULT},
  parameter [31:0]       PMP_PMPADDR_RV[PMP_NUM_REGIONS-1:0] = '{default:32'h0},
  parameter mseccfg_t    PMP_MSECCFG_RV                      = MSECCFG_DEFAULT,
  parameter bit          CLIC                         = 0,
  parameter int unsigned CLIC_ID_WIDTH                = 5,
  parameter int          DBG_NUM_TRIGGERS             = 1,
  parameter int          PMA_NUM_REGIONS              = 0,
  parameter pma_cfg_t    PMA_CFG[PMA_NUM_REGIONS-1:0] = '{default:PMA_R_DEFAULT},
  parameter lfsr_cfg_t   LFSR0_CFG                    = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
  parameter lfsr_cfg_t   LFSR1_CFG                    = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
  parameter lfsr_cfg_t   LFSR2_CFG                    = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
  parameter bit          CORE_LOG_ENABLE              = 1,
  parameter bit          DEBUG                        = 1,
  parameter logic [31:0] DM_REGION_START              = 32'hF0000000,
  parameter logic [31:0] DM_REGION_END                = 32'hF0003FFF
)
(
  // Clock and Reset
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        scan_cg_en_i,                     // Enable all clock gates for testing

  // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
  input  logic [31:0] boot_addr_i,
  input  logic [31:0] mtvec_addr_i,
  input  logic [31:0] dm_halt_addr_i,
  input  logic [31:0] mhartid_i,
  input  logic  [3:0] mimpid_patch_i,
  input  logic [31:0] dm_exception_addr_i,

  // Instruction memory interface
  output logic        instr_req_o,
  output logic        instr_reqpar_o,
  input  logic        instr_gnt_i,
  input  logic        instr_gntpar_i,
  input  logic        instr_rvalid_i,
  input  logic        instr_rvalidpar_i,
  output logic [31:0] instr_addr_o,
  output logic [12:0] instr_achk_o,
  output logic [1:0]  instr_memtype_o,
  output logic [2:0]  instr_prot_o,
  output logic        instr_dbg_o,
  input  logic [31:0] instr_rdata_i,
  input  logic [4:0]  instr_rchk_i,
  input  logic        instr_err_i,

  // Data memory interface
  output logic        data_req_o,
  output logic        data_reqpar_o,
  input  logic        data_gnt_i,
  input  logic        data_gntpar_i,
  input  logic        data_rvalid_i,
  input  logic        data_rvalidpar_i,
  output logic        data_we_o,
  output logic [3:0]  data_be_o,
  output logic [31:0] data_addr_o,
  output logic [12:0] data_achk_o,
  output logic [1:0]  data_memtype_o,
  output logic [2:0]  data_prot_o,
  output logic        data_dbg_o,
  output logic [31:0] data_wdata_o,
  input  logic [31:0] data_rdata_i,
  input  logic [4:0]  data_rchk_i,
  input  logic        data_err_i,

  // Cycle Count
  output logic [63:0] mcycle_o,

  // Interrupt inputs
  input  logic [31:0] irq_i,                    // CLINT interrupts + CLINT extension interrupts

  // WFE input
  input  logic        wu_wfe_i,

  // CLIC Interface
  input  logic                       clic_irq_i,
  input  logic [CLIC_ID_WIDTH-1:0]   clic_irq_id_i,
  input  logic [ 7:0]                clic_irq_level_i,
  input  logic [ 1:0]                clic_irq_priv_i,
  input  logic                       clic_irq_shv_i,

  // Fencei flush handshake
  output logic        fencei_flush_req_o,
  input  logic        fencei_flush_ack_i,

  // Security Alerts
  output logic        alert_minor_o,
  output logic        alert_major_o,
  output logic [2:0]  alert_compare_o,

  // Debug Interface
  input  logic        debug_req_i,
  output logic        debug_havereset_o,
  output logic        debug_running_o,
  output logic        debug_halted_o,
  output logic        debug_pc_valid_o,
  output logic [31:0] debug_pc_o,

  // CPU Control Signals
  input  logic        fetch_enable_i,
  output logic        core_sleep_o
);

// instantiate the main core
    cv32e40s_core
        #(
          .LIB                   ( LIB                   ),
          .RV32                  ( RV32                  ),
          .B_EXT                 ( B_EXT                 ),
          .M_EXT                 ( M_EXT                 ),
          .PMP_GRANULARITY       ( PMP_GRANULARITY       ),
          .PMP_NUM_REGIONS       ( PMP_NUM_REGIONS       ),
          .PMP_PMPNCFG_RV        ( PMP_PMPNCFG_RV        ),
          .PMP_PMPADDR_RV        ( PMP_PMPADDR_RV        ),
          .PMP_MSECCFG_RV        ( PMP_MSECCFG_RV        ),
          .CLIC                  ( CLIC                  ),
          .CLIC_ID_WIDTH         ( CLIC_ID_WIDTH         ),
          .DEBUG                 ( DEBUG                 ),
          .DM_REGION_START       ( DM_REGION_START       ),
          .DM_REGION_END         ( DM_REGION_END         ),
          .DBG_NUM_TRIGGERS      ( DBG_NUM_TRIGGERS      ),
          .PMA_NUM_REGIONS       ( PMA_NUM_REGIONS       ),
          .PMA_CFG               ( PMA_CFG               ),
          .LFSR0_CFG             ( LFSR0_CFG             ),
          .LFSR1_CFG             ( LFSR1_CFG             ),
          .LFSR2_CFG             ( LFSR2_CFG             ))
    core_i (.*);

// generate if (ENABLE_DUAL_CORES == 1) begin
//     cv32e40s_core
//         #(
//           .LIB                   ( LIB                   ),
//           .RV32                  ( RV32                  ),
//           .B_EXT                 ( B_EXT                 ),
//           .M_EXT                 ( M_EXT                 ),
//           .PMP_GRANULARITY       ( PMP_GRANULARITY       ),
//           .PMP_NUM_REGIONS       ( PMP_NUM_REGIONS       ),
//           .PMP_PMPNCFG_RV        ( PMP_PMPNCFG_RV        ),
//           .PMP_PMPADDR_RV        ( PMP_PMPADDR_RV        ),
//           .PMP_MSECCFG_RV        ( PMP_MSECCFG_RV        ),
//           .CLIC                  ( CLIC                  ),
//           .CLIC_ID_WIDTH         ( CLIC_ID_WIDTH         ),
//           .DEBUG                 ( DEBUG                 ),
//           .DM_REGION_START       ( DM_REGION_START       ),
//           .DM_REGION_END         ( DM_REGION_END         ),
//           .DBG_NUM_TRIGGERS      ( DBG_NUM_TRIGGERS      ),
//           .PMA_NUM_REGIONS       ( PMA_NUM_REGIONS       ),
//           .PMA_CFG               ( PMA_CFG               ),
//           .LFSR0_CFG             ( LFSR0_CFG             ),
//           .LFSR1_CFG             ( LFSR1_CFG             ),
//           .LFSR2_CFG             ( LFSR2_CFG             ))
//     core_i_compare (.*);

//     cv32e40s_compare 
//         #(
//           .N ($bits(if_id_compare_o))
//         )
//     if_id_stage_compare (
//       .core_master (core_i.if_id_compare_o),
//       .core_checker (core_i_compare.if_id_compare_o),
//       .error (alert_compare_o[0])
//     );

//     cv32e40s_compare 
//         #(
//           .N ($bits(id_ex_compare_o))
//         )
//     id_ex_stage_compare (
//       .core_master (core_i.id_ex_compare_o),
//       .core_checker (core_i_compare.id_ex_compare_o),
//       .error (alert_compare_o[1])
//     );

//     cv32e40s_compare 
//         #(
//           .N ($bits(ex_wb_compare_o))
//         )
//     ex_wb_stage_compare (
//       .core_master (core_i.ex_wb_compare_o),
//       .core_checker (core_i_compare.ex_wb_compare_o),
//       .error (alert_compare_o[2])
//     );

//     // This induces a detectable error in comparison 
//     // assign core_i.id_stage_i.if_id_pipe_i.pc = 0;
// end
// endgenerate

endmodule