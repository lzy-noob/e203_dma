`include "e203_defines.v"
module e203_dma (

    //数据ICB
    output                          dma_icb_cmd_valid,  
    input                           dma_icb_cmd_ready,
    output  [`E203_ADDR_SIZE-1:0]   dma_icb_cmd_addr,
    output                          dma_icb_cmd_read,
    output  [`E203_XLEN-1:0]        dma_icb_cmd_wdata,
    output  [`E203_XLEN/8-1:0]        dma_icb_cmd_wmask,
    //
    input                         dma_icb_rsp_valid,
    output                        dma_icb_rsp_ready,
    input                         dma_icb_rsp_err,
    input [`E203_XLEN-1:0]        dma_icb_rsp_rdata,
    output                        dma_irq,
    
    //配置ICB
    input                          dma_cfg_icb_cmd_valid,
    output                         dma_cfg_icb_cmd_ready,
    input  [`E203_ADDR_SIZE-1:0]   dma_cfg_icb_cmd_addr,
    input                          dma_cfg_icb_cmd_read,
    input  [`E203_XLEN-1:0]        dma_cfg_icb_cmd_wdata,
    input  [`E203_XLEN/8-1:0]      dma_cfg_icb_cmd_wmask,
    //
    output                         dma_cfg_icb_rsp_valid,
    input                          dma_cfg_icb_rsp_ready,
    output                         dma_cfg_icb_rsp_err,
    output [`E203_XLEN-1:0]        dma_cfg_icb_rsp_rdata,
   
    input 			  clk,
    input             rst_n
); 
    wire [31:0] sour_addr;
    wire [31:0] dest_addr;
    wire [31:0] line_size;
    wire [31:0] row_size;
    wire [31:0] trans_matr;
    wire [2:0] dma_ctr;
    wire cfg_vld;

dma_cfg u_dma_cfg (
    .dma_cfg_icb_cmd_valid   ( dma_cfg_icb_cmd_valid   ),
    .dma_cfg_icb_cmd_addr    ( dma_cfg_icb_cmd_addr    ),
    .dma_cfg_icb_cmd_read    ( dma_cfg_icb_cmd_read    ),
    .dma_cfg_icb_cmd_wdata   ( dma_cfg_icb_cmd_wdata   ),
    .dma_cfg_icb_cmd_wmask   ( dma_cfg_icb_cmd_wmask   ),
    .dma_cfg_icb_rsp_ready   ( dma_cfg_icb_rsp_ready   ),
    .clk                     ( clk                     ),
    .rst_n                   ( rst_n                   ),
    .dma_ctr                 ( dma_ctr                 ),

    .dma_cfg_icb_cmd_ready   ( dma_cfg_icb_cmd_ready   ),
    .dma_cfg_icb_rsp_valid   ( dma_cfg_icb_rsp_valid   ),
    .dma_cfg_icb_rsp_err     ( dma_cfg_icb_rsp_err     ),
    .dma_cfg_icb_rsp_rdata   ( dma_cfg_icb_rsp_rdata   ),
    .sour_addr               ( sour_addr               ),
    .dest_addr               ( dest_addr               ),
    .line_size               ( line_size               ),
    .row_size                ( row_size                ),
    .cfg_vld                 ( cfg_vld                 ),
    .trans_matr              ( trans_matr              )
);

dma_core u_dma_core (
    .dma_icb_cmd_ready       ( dma_icb_cmd_ready   ),
    .dma_icb_rsp_valid       ( dma_icb_rsp_valid   ),
    .dma_icb_rsp_err         ( dma_icb_rsp_err     ),
    .dma_icb_rsp_rdata       ( dma_icb_rsp_rdata   ),
    .clk                     ( clk                 ),
    .rst_n                   ( rst_n               ),
    .sour_addr               ( sour_addr           ),
    .dest_addr               ( dest_addr           ),
    .line_size               ( line_size           ),
    .row_size                ( row_size            ),
    .cfg_vld                 ( cfg_vld             ),
    .trans_matr              ( trans_matr          ),

    .dma_icb_cmd_valid       ( dma_icb_cmd_valid   ),
    .dma_icb_cmd_addr        ( dma_icb_cmd_addr    ),
    .dma_icb_cmd_read        ( dma_icb_cmd_read    ),
    .dma_icb_cmd_wdata       ( dma_icb_cmd_wdata   ),
    .dma_icb_cmd_wmask       ( dma_icb_cmd_wmask   ),
    .dma_icb_rsp_ready       ( dma_icb_rsp_ready   ),
    .dma_irq                 ( dma_irq             ),
    .dma_ctr                 ( dma_ctr             )
);
endmodule
