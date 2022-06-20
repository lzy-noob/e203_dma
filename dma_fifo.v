module dma_fifo(
    clk,
    rst_n,
    w_en,
    data_w,
    r_en,
    
    data_r, 
    empty,
    full,
    half_full,
    overflow

);

    input clk;
    input rst_n;
    input w_en;    
    input r_en;    
    input data_w;  
    
    output data_r;  
    output empty;  
    output full;   
    output half_full; 
    output overflow;  


    wire clk,rst_n,w_en,r_en; 
    wire [31:0] data_w; 
    reg  [31:0] data_r;
    reg empty, full, half_full, overflow;
    reg [31:0]memory [15:0];  //depth 16, width 32
    
    reg [4:0]counter;       //record the number of data in fifo
    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;




    //wr_ptr
    always@(posedge clk or negedge rst_n)
        if (!rst_n)
            wr_ptr<=4'b0000;
        else if (w_en==1'b1 & !full )
            wr_ptr<=wr_ptr+1;
        else 
            wr_ptr<=wr_ptr; //in other conditions, wr_ptr does not change 

    //rd_ptr
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            rd_ptr<=4'b0000;
        else if (r_en==1'b1 & !empty)
            rd_ptr<=rd_ptr+1;
        else 
            rd_ptr<=rd_ptr; //do-nothing operation


    //memory 
    always@(posedge clk or negedge rst_n)
        if (!rst_n) 
            memory[wr_ptr]<=memory[wr_ptr]; //do-nothing operation
        else if (w_en ==1'b1 & !full )
            memory[wr_ptr]<=data_w;	
        else
            memory[wr_ptr]<=memory[wr_ptr]; //do-nothing operation


    //counter
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            counter<=5'b00000;
        else if(w_en==1'b1 & !full )
            counter<=counter+1;
        else if(r_en==1'b1 & !empty)
            counter<=counter-1;
        else counter <= counter; //do-nothing operation


    //data_r 
    always@(posedge clk or negedge rst_n)
        if(!rst_n)
            data_r<=data_r; //do-nothing operation
        else if(r_en == 1'b1 & !empty )
            data_r<=memory[rd_ptr];
        else 
            data_r<=data_r; //do-nothing operation


//empty
always @(*)
begin 
if (counter==5'b00000)
empty=1'b1;
else empty=1'b0;
end 

//full
always @(*)
begin
if (counter==5'b10000)
full=1'b1;
else full=1'b0;
end  

//half_full
always @(*)
begin
if (counter == 5'b01000) 
half_full=1'b1;
else half_full=1'b0;
end 
//overflow
always@(posedge clk or negedge rst_n)
begin
if(!rst_n)
overflow<=1'b0; 
else if(full==1'b1 & w_en==1'b1)
overflow<=1'b1;
else overflow<=1'b0;
end
endmodule
