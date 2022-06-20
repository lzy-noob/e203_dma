`include "e203_defines.v"
module dma_core(
        //数据ICB总线
    output                            dma_icb_cmd_valid,  
    input                             dma_icb_cmd_ready,
    output  reg  [`E203_ADDR_SIZE-1:0]   dma_icb_cmd_addr,
    output                            dma_icb_cmd_read,
    output  reg   [`E203_XLEN-1:0]        dma_icb_cmd_wdata,
    output    [`E203_XLEN/8-1:0]      dma_icb_cmd_wmask,
    //
    input                             dma_icb_rsp_valid,
    output                            dma_icb_rsp_ready,
    input                             dma_icb_rsp_err,
    input [`E203_XLEN-1:0]            dma_icb_rsp_rdata,
    output                            dma_irq,
    
    input                                   clk,
    input                                   rst_n,

	//寄存器配置信息
    input   wire [31:0]                    sour_addr,
    input   wire [31:0]                    dest_addr,
    input   wire [31:0]                    line_size,
    input   wire [31:0]                    row_size,
    input   wire                           cfg_vld,
    input   wire [31:0]                    trans_matr,

    output  reg [2:0]                      dma_ctr //read only [0] 使能 [1]结束 [2] busy 高电平有效
);
    //----------------FSM----------------
    parameter IDLE = 2'b00;  
    parameter WRITE = 2'b01;
    parameter READ = 2'b11;
    
    reg [2:0] cur_state;
    reg [2:0] next_state; 
    
    //-------------dma write&read----------------
    reg [31:0] write_addr;
    wire [31:0] write_data;

    reg [31:0] read_addr;
    wire [31:0] read_data;
    
    reg [15:0] counter_line;
    reg [15:0] counter_row;

    //------------------dma handshake-------------------
    wire cmd_suc = dma_icb_cmd_valid && dma_icb_cmd_ready;
    wire write_suc = cmd_suc && ~dma_icb_cmd_read;
    wire read_suc = cmd_suc && dma_icb_cmd_read;
    wire rsp_suc = dma_icb_rsp_valid && dma_icb_rsp_ready;


    //------------------读写数据计数--------------------
    parameter read_size = 4;
    parameter write_size =4;
    
    reg [3:0] counter_read;
    reg [3:0] counter_cmd_read;
    wire read_finish;
    reg [3:0] counter_write;
    reg [3:0] counter_cmd_write;
    wire write_finish;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_cmd_read <= 0;
        else if(cur_state == WRITE || cur_state == IDLE) 
            counter_cmd_read <= 0;
        else if(cur_state == READ && counter_cmd_read < read_size && read_suc)
            counter_cmd_read <= counter_cmd_read+1;
        else 
            counter_cmd_read <= counter_cmd_read;

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_read <= 0;
        else if(cur_state == WRITE || cur_state == IDLE || counter_read == read_size) 
            counter_read <= 0;
        else if(cur_state == READ && counter_read < read_size && rsp_suc)
            counter_read <= counter_read+1;
        else 
            counter_read <= counter_read;
    assign read_finish = (counter_read == read_size);


    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_cmd_write <= 0;
        else if(cur_state == READ || cur_state == IDLE)
            counter_cmd_write <= 0;
        else if(cur_state == WRITE && counter_cmd_write < write_size && write_suc)
            counter_cmd_write <= counter_cmd_write+1;
        else 
            counter_cmd_write <= counter_cmd_write;
    
    
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_write <= 0;
        else if(cur_state == READ || cur_state == IDLE || counter_write == write_size)
            counter_write <= 0;
        else if(cur_state == WRITE && counter_write < write_size && rsp_suc)
            counter_write <= counter_write+1;
        else 
            counter_write <= counter_write;
    
    assign write_finish = (counter_write == write_size);
    //--------------读逻辑-----------------
    //读是顺序的读，因此地地址可以顺序的增加
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            read_addr <= 'b0;
        else if(dma_ctr[0])
            read_addr <= sour_addr;
        else if(read_suc)
            read_addr <= read_addr + 4;
        else begin
        end
    
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_line <= 'b0;
        else if(dma_ctr[0])
            counter_line <= 'b0;
        else if(read_suc && counter_line < line_size) 
            counter_line <= counter_line + 4;
        else if(read_suc && counter_line >= line_size)
            counter_line <= 4;
        else 
            counter_line <= counter_line;

    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            counter_row <= 'b0;
        else if(dma_ctr[0])
            counter_row <= 'b0;
        else if(read_suc && counter_line >= line_size)
            counter_row <= counter_row + 1;
        else 
            counter_row <= counter_row;
    

    assign read_data = ( cur_state ==READ && rsp_suc) ? dma_icb_rsp_rdata : 'b0;
    
    wire [15:0] counter_row_start = (counter_line < 12)? counter_row-1 : counter_row;
    wire [15:0] counter_row_end =  counter_row;

    reg [3:0] row_shift_signal;

    always @(*)
        case(counter_line)
           16'd4:
           begin
            row_shift_signal <= 4'b1000;
           end 
           16'd8:
           begin
            row_shift_signal <= 4'b1100;
           end
           16'd12:
           begin 
            row_shift_signal <= 4'b1110;
           end
           default:
           begin
            row_shift_signal <= 4'b0000;
           end
        endcase


    //------------------写逻辑-------------------
    wire [31:0] diff_odd = dest_addr - sour_addr - (line_size + line_size[1:0]); 
    wire [31:0] diff_oven = dest_addr - sour_addr + line_size + line_size[1:0];
    //写会跳地址，因此地址要跳变，跳变时需要依据转移矩阵和当前的读地址
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            write_addr <= 'b0;
        else if(dma_ctr[0])
            write_addr <= diff_odd;
        else if(cur_state==WRITE && counter_cmd_write == 0 && !counter_row_start[0])
            write_addr <= (read_addr - 8'd16) + diff_oven; 
        else if(cur_state==WRITE && counter_cmd_write == 0 && counter_row_start[0])
            write_addr <= (read_addr - 8'd16) + diff_odd;
        else if(cur_state==WRITE && counter_cmd_write == 1 && !row_shift_signal[1])
            write_addr <= (read_addr - 8'd12) + (diff_oven&{32{!counter_row_start[0]}}) + (diff_odd&{32{counter_row_start[0]}}); 
        else if(cur_state==WRITE && counter_cmd_write == 1 &&  row_shift_signal[1])
            write_addr <= (read_addr - 8'd12) + (diff_oven&{32{!counter_row_end[0]}}) + (diff_odd&{32{counter_row_end[0]}});
        else if(cur_state==WRITE && counter_cmd_write == 2 && !row_shift_signal[2])
            write_addr <= (read_addr - 8'd8 ) + (diff_oven&{32{!counter_row_start[0]}}) + (diff_odd&{32{counter_row_start[0]}}); 
        else if(cur_state==WRITE && counter_cmd_write == 2 && row_shift_signal[2])
            write_addr <= (read_addr - 8'd8 ) + (diff_oven&{32{!counter_row_end[0]}}) + (diff_odd&{32{counter_row_end[0]}});
        else if(cur_state==WRITE && counter_cmd_write == 3 && !row_shift_signal[3])
            write_addr <= (read_addr - 8'd4 ) + (diff_oven&{32{!counter_row_start[0]}}) + (diff_odd&{32{counter_row_start[0]}}); 
        else if(cur_state==WRITE && counter_cmd_write == 3 && row_shift_signal[3])
            write_addr <= (read_addr - 8'd4 ) + (diff_oven&{32{!counter_row_end[0]}}) + (diff_odd&{32{counter_row_end[0]}});
        else begin
        end
    //-----------------fifo--------------------
    wire w_en = (cur_state == READ && rsp_suc);   
    wire r_en = (read_finish) || (cur_state==WRITE && write_suc && !(counter_cmd_write == 3));


    dma_fifo  u_dma_fifo (
    .clk                     ( clk         ),
    .rst_n                   ( rst_n       ),
    .w_en                    ( w_en        ),
    .r_en                    ( r_en        ),
    .data_w                  ( read_data  ),

    .data_r                  ( write_data )
    );
        
    reg [31:0] data_trans;
    
    always @(*)
    begin
        case(counter_cmd_write)
            0:
            begin
                if(counter_row_start[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else 
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
            end
            1:
            begin
                if(!row_shift_signal[1] && counter_row_start[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(!row_shift_signal[1] && !counter_row_start[0])
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(row_shift_signal[1] && counter_row_end[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else 
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
            end
            2:
            begin
                if(!row_shift_signal[2] && counter_row_start[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(!row_shift_signal[2] && !counter_row_start[0])
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(row_shift_signal[2] && counter_row_end[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else 
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
            end
            3:
            begin
                if(!row_shift_signal[3] && counter_row_start[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(!row_shift_signal[3] && !counter_row_start[0])
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else if(row_shift_signal[3] && !counter_row_end[0])
                    data_trans <= (trans_matr[16])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
                else 
                    data_trans <= (trans_matr[0])? {write_data[23:16],write_data[31:24],write_data[7:0],write_data[15:8]} : write_data;
            end
            default:
                data_trans <= write_data;
        endcase
    end

    //-----------------状态信息更新--------------------
    //start end busy
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dma_ctr[0] <= 1'b0;
        else if (cfg_vld)
            dma_ctr[0] <= 1'b1;
        else 
            dma_ctr[0] <= 1'b0;

    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dma_ctr[1] <= 1'b0;
        else if (cfg_vld)
            dma_ctr[1] <= 1'b0;
        else if ((counter_row >= row_size && row_shift_signal[3]==0) || (counter_row >= row_size && row_shift_signal[3]==1 && write_finish) )
            dma_ctr[1] <= 1'b1;
        else begin
        end

    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            dma_ctr[2] <= 1'b0;
        else if (cfg_vld)
            dma_ctr[2] <= 1'b1;
        else if ((counter_row >= row_size && row_shift_signal[3]==0) || (counter_row >= row_size && row_shift_signal[3]==1 && write_finish) )
            dma_ctr[2] <= 1'b0;
        else begin
        end


    //-------------------------DMA作为主设备--------------------------
    //dma_irq
    assign dma_irq = dma_ctr[1];  
    assign dma_icb_cmd_valid = ((cur_state==READ) || (cur_state==WRITE)) && dma_icb_cmd_ready && !(counter_cmd_read==read_size) && !(counter_cmd_write == write_size);
    assign dma_icb_cmd_read = (cur_state == READ) && (cmd_suc);
    assign dma_icb_cmd_wmask = 4'b1111;
    
    assign dma_icb_rsp_ready = dma_icb_rsp_valid;

    //dma_icb_cmd_addr dma_icb_cmd_wdata
    always@(*)
        if(cur_state == WRITE) begin
            dma_icb_cmd_addr <= write_addr;
            dma_icb_cmd_wdata <= data_trans;
        end
        else if(cur_state == READ) begin
            dma_icb_cmd_addr <= read_addr;
            dma_icb_cmd_wdata <= 'b0;
        end
        else begin
            dma_icb_cmd_addr <= 'b0;
            dma_icb_cmd_wdata <= 'b0;
        end
        
    //----------------dma FSM--------------------

    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            cur_state <= IDLE;
        else 
            cur_state <= next_state;
    
    always @(*) begin
        case(cur_state)
            IDLE: 
            begin
                if(dma_ctr[0] == 0)
                    next_state <= IDLE;
                else if(dma_ctr[0] == 1)
                    next_state <= READ;
                else 
                    next_state <= IDLE;
            end
            WRITE:
            begin
                if(dma_ctr[1] == 1)
                    next_state <= IDLE;
                else if (dma_ctr[2]==1 && dma_ctr[1]==0 && !write_finish )
                    next_state <= WRITE;
                else if(write_finish && rsp_suc)
                    next_state <= READ;
                else begin
                end
            end
            
            READ:
            begin
                if(dma_ctr[1] == 1)
                    next_state <= IDLE;
                else if (dma_ctr[2]==1 && dma_ctr[1]==0 && !read_finish )
                    next_state <= READ;
                else if (read_finish && rsp_suc)
                    next_state <= WRITE;
                else begin
                end
            end
        default : next_state <= IDLE;
        endcase
    end


    
endmodule