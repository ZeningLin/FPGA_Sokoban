//------------------------------------------------------------------------
// ENTITY/MODULE NAME:		VGA_Driver
// DESCRIPTIONS:			accept RGB signal of the current pixel, then
// 							generate corresponding VGA signal and issue it
// 							to the VGA port; simultaneously generate the 
// 							coordinate of the current processing pixel,
// 							which will be issued to the module CORE_Gm for 
//                          the next iteration
//
// FREQUENCY:				@25MHz
// 
// 
//
// INPUT:					VGA_clk:			    clock signal.
// 							VGA_rst:			    reset signal. active 0
// 							VGA_PixelSignal[15:0]:	RGB signal for the current
// 			                                        pixel, processed by the 
// 													module CORE_Gm
// 		
// OUTPUT:					VGA_CurCoorX[9:0]:	    current processing coordinate x
// 							VGA_CurCoorY[9:0]:	    current processing coordinate y
// 							VGA_HS:				    horizontal synchronous signal
// 							VGA_VS:				    vertical synchronous signal
// 							VGA_PortSignal[15:0]:	RGB signal for the current
// 											        pixel, issued to the VGA port
// 
// 
// REFERENCE: 				AlienTek FPGA
// AUTHOR:					ZeningLin
// VERSION:					1.0
// DATE CREATED:			2021-02-09
// DATE MODIFIED:			2021-02-09
//------------------------------------------------------------------------
module VGA_Driver(
    input           VGA_clk,
    input           VGA_rst,
    input   [15:0]  VGA_PixelSignal,     


    output          VGA_HS, 
    output          VGA_VS,
    output  [15:0]  VGA_PortSignal,
    output  [ 9:0]  VGA_CurCoorX,
    output  [ 9:0]  VGA_CurCoorY  
);                             
                                                        
//parameter define  
parameter  VGA_HSync   =  10'd96;    //行同步
parameter  VGA_HBack   =  10'd48;    //行显示后沿
parameter  VGA_HDisp   =  10'd640;   //行有效数据
parameter  VGA_HFront  =  10'd16;    //行显示前沿
parameter  VGA_HTotal  =  10'd800;   //行扫描周期

parameter  VGA_VSync   =  10'd2;     //场同步
parameter  VGA_VBack   =  10'd33;    //场显示后沿
parameter  VGA_VDisp   =  10'd480;   //场有效数据
parameter  VGA_VFront  =  10'd10;    //场显示前沿
parameter  VGA_VTotal  =  10'd525;   //场扫描周期
          
//reg define                                     
reg  [9:0] VGA_CntH;
reg  [9:0] VGA_CntV;

//wire define
wire       VGA_En;
wire       VGA_DataReq; 

//VGA行场同步信号
assign VGA_HS  = (VGA_CntH <= VGA_HSync - 1'b1) ? 1'b0 : 1'b1;
assign VGA_VS  = (VGA_CntV <= VGA_VSync - 1'b1) ? 1'b0 : 1'b1;

//使能RGB565数据输出
assign VGA_En  = (((VGA_CntH >= VGA_HSync+VGA_HBack) && (VGA_CntH < VGA_HSync+VGA_HBack+VGA_HDisp))
                 &&((VGA_CntV >= VGA_VSync+VGA_VBack) && (VGA_CntV < VGA_VSync+VGA_VBack+VGA_VDisp)))
                 ?  1'b1 : 1'b0;
                 
//RGB565数据输出                 
assign VGA_PortSignal = VGA_En ? VGA_PixelSignal : 16'd0;

//请求像素点颜色数据输入                
assign VGA_DataReq = (((VGA_CntH >= VGA_HSync+VGA_HBack-1'b1) && (VGA_CntH < VGA_HSync+VGA_HBack+VGA_HDisp-1'b1))
                  && ((VGA_CntV >= VGA_VSync+VGA_VBack) && (VGA_CntV < VGA_VSync+VGA_VBack+VGA_VDisp)))
                  ?  1'b1 : 1'b0;

//像素点坐标                
assign VGA_CurCoorX = VGA_DataReq ? (VGA_CntH - (VGA_HSync + VGA_HBack - 1'b1)) : 10'd0;
assign VGA_CurCoorY = VGA_DataReq ? (VGA_CntV - (VGA_VSync + VGA_VBack - 1'b1)) : 10'd0;

//行计数器对像素时钟计数
always @(posedge VGA_clk or negedge VGA_rst) begin         
    if (!VGA_rst)
        VGA_CntH <= 10'd0;                                  
    else begin
        if(VGA_CntH < VGA_HTotal - 1'b1)                                               
            VGA_CntH <= VGA_CntH + 1'b1;                               
        else 
            VGA_CntH <= 10'd0;  
    end
end

//场计数器对行计数
always @(posedge VGA_clk or negedge VGA_rst) begin         
    if (!VGA_rst)
        VGA_CntV <= 10'd0;                                  
    else if(VGA_CntH == VGA_HTotal - 1'b1) begin
        if(VGA_CntV < VGA_VTotal - 1'b1)                                               
            VGA_CntV <= VGA_CntV + 1'b1;                               
        else 
            VGA_CntV <= 10'd0;  
    end
end

endmodule 