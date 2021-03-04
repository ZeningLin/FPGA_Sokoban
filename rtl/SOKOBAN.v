/*--------------------------------------------------------------------------
-- ENTITY/MODULE NAME:		SOKOBAN
-- DESCRIPTIONS:			top level entity
-- FREQUENCY:				@25MHz
--
--
--
-- INPUT:					SYS_clk:			clock signal. 
-- 							SYS_rst:			global reset signal. active 0
-- 							SYS_cur_rst:		local reset signal. active 0
-- 							SYS_DirUp:          move up signal connected to touch key
-- 							SYS_DirDown:        move down signal connected to touch key
-- 							SYS_DirLeft:        move left signal connected to touch key
-- 							SYS_DirRight:       move right signal connected to touch key
--
-- 
-- OUTPUT:					SYS_VGA_PortSignal[15:0]:	RGB signal for the current coordinate
-- 								
--
-- 
--
-- AUTHOR:					ZeningLin
-- VERSION:					1.0
-- DATE CREATED:			2021-02-08
-- DATE MODIFIED:			2021-02-23
--------------------------------------------------------------------------*/
module SOKOBAN(
    input           SYS_clk,        
    input           SYS_rst,      
    input           SYS_cur_rst,  
    input           SYS_DirUp,
    input           SYS_DirDown,
    input           SYS_DirLeft,
    input           SYS_DirRight,


    output          SYS_VGA_HS,         
    output          SYS_VGA_VS,         
    output  [15:0]  SYS_VGA_PortSignal   
); 


wire         SYS_clk_w;             
wire         SYS_PLL_locked_w;              
wire         SYS_rst_w;               
wire [15:0]  PixelSignal_w;          
wire [ 9:0]  PixelXPos_w;          
wire [ 9:0]  PixelYPos_w;          
wire         DirUp_w;
wire         DirDown_ww;
wire         DirLeft_w;
wire         DirRight_w;

assign SYS_rst_w = SYS_rst && SYS_PLL_locked_w;
   
SYS_PLL	u_SYS_PLL(
	.inclk0         (SYS_clk),    
	.areset         (~SYS_rst),
    
	.c0             (SYS_clk_w),
	.locked         (SYS_PLL_locked_w)
	); 

VGA_Driver u_VGA_Driver(
    .VGA_clk        (SYS_clk_w),    
    .VGA_rst        (SYS_rst_w),    

    .VGA_HS         (SYS_VGA_HS),       
    .VGA_VS         (SYS_VGA_VS),       
    .VGA_PortSignal (SYS_VGA_PortSignal),      
    
    .VGA_PixelSignal  (PixelSignal_w), 
    .VGA_CurCoorX     (PixelXPos_w), 
    .VGA_CurCoorY     (PixelYPos_w)
    ); 
    
CORE_Gm u_CORE_Gm(
    .CORE_Gm_clk        (SYS_clk_w),
    .CORE_Gm_rst        (SYS_rst_w),
    .CORE_Gm_cur_rst    (SYS_cur_rst),
    .CORE_Gm_dir_up     (DirUp_w),
    .CORE_Gm_dir_down   (DirDown_ww),
    .CORE_Gm_dir_left   (DirLeft_w),
    .CORE_Gm_dir_right  (DirRight_w),
    
    .CORE_CurCoorX      (PixelXPos_w),
    .CORE_CurCoorY      (PixelYPos_w),
    .CORE_PixelSignal   (PixelSignal_w)
    );   

KEY_Driver u_KEY_Driver(
    .KEY_clk        (SYS_clk_w),
    .KEY_up         (SYS_DirUp),
    .KEY_down       (SYS_DirDown),
    .KEY_left       (SYS_DirLeft),
    .KEY_right      (SYS_DirRight),

    .KEY_up_action        (DirUp_w),
    .KEY_down_action        (DirDown_ww),
    .KEY_left_action        (DirLeft_w),
    .KEY_right_action        (DirRight_w)
);

    
endmodule 