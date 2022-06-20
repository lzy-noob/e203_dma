`include "e203_defines.v"
module dma_cfg (
    //配置ICB总线
    input                          dma_cfg_icb_cmd_valid,
    output reg                     dma_cfg_icb_cmd_ready,
    input  [`E203_ADDR_SIZE-1:0]   dma_cfg_icb_cmd_addr,
    input                          dma_cfg_icb_cmd_read,
    input  [`E203_XLEN-1:0]        dma_cfg_icb_cmd_wdata,
    input  [`E203_XLEN/8-1:0]      dma_cfg_icb_cmd_wmask,
    //
    output reg                      dma_cfg_icb_rsp_valid,
    input                           dma_cfg_icb_rsp_ready,
    output wire                     dma_cfg_icb_rsp_err,
    output wire [`E203_XLEN-1:0]    dma_cfg_icb_rsp_rdata,
    //时钟和复位
    input 			  clk,
    input             rst_n,

    //寄存器配置
    output reg  [31:0]              sour_addr,
    output reg  [31:0]              dest_addr,
    output reg  [31:0]              line_size,
    output reg  [31:0]              row_size,
    output reg                      cfg_vld,
    output reg  [31:0]              trans_matr,

    input  wire [2:0]               dma_ctr

);
    //地址分配
    parameter SOURCE_ADDR       = 32'h1000_0000;        //源地址
    parameter DESTINATION_ADDR  = 32'h1000_0004;        //目的地址
    parameter line_size_ADDR    = 32'h1000_0008;        //行大小
    parameter row_size_ADDR     = 32'h1000_000c;        //列大小
    parameter trans_matr_ADDR   = 32'h1000_0010;        //变换矩阵 [31:24] [23:16] [15:8] [7:0] 分别代表1,1 1,0 0,1 0,0 到后面矩阵的映射
    parameter cfg_vld_ADDR      = 32'h1000_0014;        //使能信号
    parameter dma_ctr_ADDR      = 32'h1000_0018;        //dma状态

    assign dma_cfg_icb_rsp_err = 0;

    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dma_cfg_icb_cmd_ready <= 1'b0;
        else if(dma_ctr[2] && !dma_cfg_icb_cmd_read)
            dma_cfg_icb_cmd_ready <= 1'b0;
        else if(dma_cfg_icb_cmd_valid)
            dma_cfg_icb_cmd_ready <= 1'b1;
        else 
            dma_cfg_icb_cmd_ready <= 1'b0;
    
    // dma_cfg_icb_rsp_valid
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dma_cfg_icb_rsp_valid <= 1'b0;
        else if(dma_cfg_icb_cmd_valid)
            dma_cfg_icb_rsp_valid <= 1'b1;
        else  
            dma_cfg_icb_rsp_valid <= 1'b0;



    //--------------------------------寄存器配置---------------------------------
    //sour_addr
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            sour_addr <= 'b0;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==SOURCE_ADDR && !dma_cfg_icb_cmd_read)
            sour_addr <= dma_cfg_icb_cmd_wdata;
        else begin
        end
    //dest_addr
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dest_addr <= 'b0;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==DESTINATION_ADDR && !dma_cfg_icb_cmd_read)
            dest_addr <= dma_cfg_icb_cmd_wdata;
        else begin
        end
    //cfg_vld    
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            cfg_vld <= 'b0;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==cfg_vld_ADDR && cfg_vld==0 && !dma_cfg_icb_cmd_read)
            cfg_vld <= dma_cfg_icb_cmd_wdata[0];
        else begin
            cfg_vld <= 'b0;
        end
    //line_size
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            line_size <= 32'd1;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==line_size_ADDR && !dma_cfg_icb_cmd_read)
            line_size <= dma_cfg_icb_cmd_wdata;
        else begin
        end
    //row_size
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            row_size <= 32'd1;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==row_size_ADDR && !dma_cfg_icb_cmd_read)
            row_size <= dma_cfg_icb_cmd_wdata;
        else begin
        end
    //trans_matr
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            trans_matr <= 'b0;
        else if(dma_cfg_icb_cmd_valid && ! dma_ctr[2] && dma_cfg_icb_cmd_addr==trans_matr_ADDR && !dma_cfg_icb_cmd_read)
            trans_matr <= dma_cfg_icb_cmd_wdata;
        else begin
        end
    
        //------------------------------读控制------------------------------------
    reg [31:0] r_data;
    
    always @(*)
     case(dma_cfg_icb_cmd_addr)
        SOURCE_ADDR:
            r_data <= sour_addr;
        DESTINATION_ADDR:
            r_data <= dest_addr;
        line_size_ADDR:
            r_data <= line_size;
        row_size_ADDR:
            r_data <= row_size;
        trans_matr_ADDR:
            r_data <= trans_matr;
        dma_ctr_ADDR:
            r_data <= {29'd0,dma_ctr[2:0]};
        default:
            r_data <= 32'hzzzz_zzzz;
     endcase

	assign dma_cfg_icb_rsp_rdata = r_data;

endmodule
