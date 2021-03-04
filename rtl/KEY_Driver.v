//------------------------------------------------------------------------
// ENTITY/MODULE NAME:		KEY_Driver
// DESCRIPTIONS:			input detection. generate pulse signal once the 
// 							touch keys are pressed down
//
// FREQUENCY:				@25MHz
// 
// 
//
// INPUT:					KEY_clk:		    clock signal.
// 							KEY_up:				move up key input		    
// 							KEY_down:			move down key input
// 							KEY_left:			move left key input
// 							KEY_right:			move right key input
// 		
// OUTPUT:					KEY_up_action:		pulse signal for move up, 
//												issued to CORE_Gm->CORE_Gm_dir_up
//							KEY_down_action:	pulse signal for move down
//												issued to CORE_Gm->CORE_Gm_dir_down
//							KEY_down_action:	pulse signal for move left
//												issued to CORE_Gm->CORE_Gm_dir_left
//							KEY_down_action:	pulse signal for move right
//												issued to CORE_Gm->CORE_Gm_dir_right
// 
// 
// REFERENCE: 				AlienTek FPGA
// AUTHOR:					ZeningLin
// VERSION:					1.0
// DATE CREATED:			2021-02-11
// DATE MODIFIED:			2021-02-18
//------------------------------------------------------------------------
module KEY_Driver (
    input               KEY_clk,
    input               KEY_up,
    input               KEY_down,
    input               KEY_right,
    input               KEY_left,
    
    output  			KEY_up_action,
	output  			KEY_down_action,
	output  			KEY_left_action,
	output  			KEY_right_action
);


/*---------------------------------------------------------------------------
* parameter definiton start
---------------------------------------------------------------------------*/
reg KEY_up_reg0;
reg KEY_up_reg1;
reg KEY_down_reg0;
reg KEY_down_reg1;
reg KEY_left_reg0;
reg KEY_left_reg1;
reg KEY_right_reg0;
reg KEY_right_reg1;

/*---------------------------------------------------------------------------
* end of parameter definiton
---------------------------------------------------------------------------*/




/*
* 上升沿检测，按下按键时仅仅产生一个正脉冲信号
*/
always@(posedge KEY_clk) begin
	KEY_up_reg0 <= KEY_up;
	KEY_up_reg1 <= KEY_up_reg0;
	KEY_down_reg0 <= KEY_down;
	KEY_down_reg1 <= KEY_down_reg0;
	KEY_left_reg0 <= KEY_left;
	KEY_left_reg1 <= KEY_left_reg0;
	KEY_right_reg0 <= KEY_right;
	KEY_right_reg1 <= KEY_right_reg0;
end


assign KEY_up_action = (!KEY_up_reg1) & KEY_up_reg0;
assign KEY_down_action =(!KEY_down_reg1) & KEY_down_reg0;
assign KEY_left_action =(!KEY_left_reg1) & KEY_left_reg0;
assign KEY_right_action =(!KEY_right_reg1) & KEY_right_reg0;


endmodule