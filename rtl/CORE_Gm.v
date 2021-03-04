/*--------------------------------------------------------------------------
-- ENTITY/MODULE NAME:		CORE_Gaming
-- DESCRIPTIONS:			game logic control
-- 
-- FREQUENCY:				@25MHz
--
--
--
-- INPUT:					CORE_Gm_clk:			clock signal. 
-- 							CORE_Gm_rst:			global reset signal. active 0
-- 							CORE_Gm_cur_rst:		local reset signal. active 0
-- 							CORE_Gm_dir_up:			move up signal. active 1
-- 							CORE_Gm_dir_down:		move down signal. active 1
-- 							CORE_Gm_dir_left:		move left signal. active 1
-- 							CORE_Gm_dir_right:		move right signal. active 1
-- 							CORE_CurCoorX[9:0]:		coordinateX of the current output pixel
-- 													from VGA_Driver->VGA_CurCoorX[9:0]
--							CORE_CurCoorY[9:0]: 	coordinateY of the current output pixel
-- 													from VGA_Driver->VGA_CurCoorY[9:0]
--
-- 
-- OUTPUT:					CORE_PixelSignal[15:0]:	RGB signal for the current coordinate
-- 													issued to VGA_Driver->VGA_PixelSignal
--
-- 
--
-- AUTHOR:					ZeningLin
-- VERSION:					1.0
-- DATE CREATED:			2021-02-08
-- DATE MODIFIED:			2021-02-23
--------------------------------------------------------------------------*/

module CORE_Gm(
    input             	CORE_Gm_clk,                // 时钟信号@25MHz
    input             	CORE_Gm_rst,               	// 总复位信号
	input				CORE_Gm_cur_rst,			// 当前关卡复位信号

	input 				CORE_Gm_dir_up,				// 向上移动信号
	input 				CORE_Gm_dir_down,			// 向下移动信号
	input 				CORE_Gm_dir_left,			// 向左移动信号
	input 				CORE_Gm_dir_right,			// 向右移动信号

    input      [ 9:0] 	CORE_CurCoorX,              // 当前输出像素点横坐标
    input      [ 9:0] 	CORE_CurCoorY,              // 当前输出像素点纵坐标


    output reg [15:0] 	CORE_PixelSignal            // 像素点数据
);    


/*---------------------------------------------------------------------------
* parameter definiton start
---------------------------------------------------------------------------*/
	// 尺寸
	parameter  H_DISP  = 10'd640;                   	//行分辨率
	parameter  V_DISP  = 10'd480;                  		//列分辨率

	parameter  BOARDER_UP   = 10'd80;					// 游戏区域上边界坐标
	parameter  BOARDER_DOWN = 10'd400;					// 游戏区域下边界坐标
	parameter  BOARDER_LEFT = 10'd160;					// 游戏区域左边界坐标
	parameter  BOARDER_RIGHT = 10'd480;					// 游戏区域右边界坐标

	localparam BLOCK_SIZE = 10'd40;                    	//方块宽度

	// 显示方块颜色定义
	localparam VIOLET       = 16'b01111_000000_01111;	// 紫色，表示人踏在终点上
	localparam BLACK        = 16'b00000_000000_00000;	// 黑色，表示墙体
	localparam WHITE        = 16'b11111_111111_11111;	// 白色，表示可移动区域
	localparam NAVY         = 16'b00000_000000_01111;	// 蓝色，表示箱子
	localparam MAROON       = 16'b01111_000000_00000;	// 红色，表示人
	localparam OLIVE        = 16'b01111_011111_00000;	// 橄榄色，表示终点
	localparam YELLOW       = 16'b11111_111111_00000;	// 黄色，表示箱子到达终点

	// 游戏区域
	reg [2:0] GameArea [7:0][7:0]; 

	// 人的当前坐标
	reg [2:0] ManPosX;
	reg [2:0] ManPosY;

	// 前行方向格子定义
	reg [2:0] NeighBlo1X;
	reg [2:0] NeighBlo1Y;
	reg [2:0] NeighBlo2X;
	reg [2:0] NeighBlo2Y;

	// 移动使能
	reg movEn;

	// 步数计数
	reg [7:0] step;
	reg [7:0] stepUnits;
	reg [7:0] stepTens;

	// 关卡
	reg [2:0] level;
	reg nextLevel;

	// 胜利计数
	reg [7:0] TotalDestination;
	reg [7:0] ReachDestination;

	// 胜利标志，1为胜利
	reg Win;

	// 通关界面使能
	reg missionClear;


	// -------------------------------- 字符坐标尺寸参数 --------------------------
	// ---------------------------------------------------------------------------

	// 字符"level"
	parameter levelStrStartX = 10'd480;
	parameter levelStrStartY = 10'd80;
	parameter levelStrEndX = 10'd520;
	parameter levelStrEndY = 10'd96;
	parameter levelNumStartX = 10'd528;
	parameter levelNumStartY = 10'd80;
	parameter levelNumEndX = 10'd536;
	parameter levelNumEndY = 10'd96;
	parameter levelStrWidth = 10'd40;
	parameter levelNumWidth = 10'd8;
	parameter levelHeight = 10'd16;

	reg [39:0] levelStr [15:0];
	reg [7:0] levelNum [15:0];

	// 字符"steps:"
	parameter stepStrStartX = 10'd480;
	parameter stepStrStartY = 10'd96;
	parameter stepStrEndX = 10'd528;
	parameter stepStrEndY = 10'd112;
	parameter stepNum1StartX = 10'd528;
	parameter stepNum1StartY = 10'd96;
	parameter stepNum1EndX = 10'd536;
	parameter stepNum1EndY = 10'd96;
	parameter stepNum2StartX = 10'd536;
	parameter stepNum2StartY = 10'd96;
	parameter stepNum2EndX = 10'd544;
	parameter stepNum2EndY = 10'd96;
	parameter stepStrWidth = 10'd48;
	parameter stepNumWidth = 10'd8;
	parameter stepHeight = 10'd16;

	reg [47:0] stepStr [15:0];
	reg [7:0] stepNum1 [15:0];
	reg [7:0] stepNum2 [15:0];

	// 字符"MISSION CLEAR"
	parameter missionclearStrStartX = 10'd164;
	parameter missionclearStrStartY = 10'd220;
	parameter missionclearStrWidth = 10'd312;
	parameter missionclearStrHeight = 10'd40;

	reg [311:0] missionclearStr [39:0];

/*---------------------------------------------------------------------------
* end of parameter definiton
---------------------------------------------------------------------------*/

/*
* 字模数据存储
*/
always @(posedge CORE_Gm_clk) begin
	// levelStr
	levelStr[ 0] <= 40'h0000000000;
	levelStr[ 1] <= 40'h0000000000;
	levelStr[ 2] <= 40'h0000000000;
	levelStr[ 3] <= 40'h0000000000;
	levelStr[ 4] <= 40'h7000000070;
	levelStr[ 5] <= 40'h1000000010;
	levelStr[ 6] <= 40'h1000000010;
	levelStr[ 7] <= 40'h103CEE3C10;
	levelStr[ 8] <= 40'h1042444210;
	levelStr[ 9] <= 40'h1042444210;
	levelStr[10] <= 40'h107E287E10;
	levelStr[11] <= 40'h1040284010;
	levelStr[12] <= 40'h1042104210;
	levelStr[13] <= 40'h7C3C103C7C;
	levelStr[14] <= 40'h0000000000;
	levelStr[15] <= 40'h0000000000;
	// levelNum
	case (level)
		8'd0:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'hE7;
			levelNum[ 6] <= 8'hE7;
			levelNum[ 7] <= 8'hE7;
			levelNum[ 8] <= 8'hE7;
			levelNum[ 9] <= 8'hE7;
			levelNum[10] <= 8'hE7;
			levelNum[11] <= 8'h7E;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end
		8'd1:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h1C;
			levelNum[ 5] <= 8'h7C;
			levelNum[ 6] <= 8'h1C;
			levelNum[ 7] <= 8'h1C;
			levelNum[ 8] <= 8'h1C;
			levelNum[ 9] <= 8'h1C;
			levelNum[10] <= 8'h1C;
			levelNum[11] <= 8'h1C;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end
			 	
		8'd2:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'hE7;
			levelNum[ 6] <= 8'h07;
			levelNum[ 7] <= 8'h0E;
			levelNum[ 8] <= 8'h1C;
			levelNum[ 9] <= 8'h70;
			levelNum[10] <= 8'hE0;
			levelNum[11] <= 8'hFF;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd3:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'h6E;
			levelNum[ 6] <= 8'h0E;
			levelNum[ 7] <= 8'h7C;
			levelNum[ 8] <= 8'h0E;
			levelNum[ 9] <= 8'h07;
			levelNum[10] <= 8'hEE;
			levelNum[11] <= 8'h7C;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd4:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h0E;
			levelNum[ 5] <= 8'h1E;
			levelNum[ 6] <= 8'h3E;
			levelNum[ 7] <= 8'h7E;
			levelNum[ 8] <= 8'hEE;
			levelNum[ 9] <= 8'hFF;
			levelNum[10] <= 8'h0E;
			levelNum[11] <= 8'h0E;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd5:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'h70;
			levelNum[ 6] <= 8'h60;
			levelNum[ 7] <= 8'h7E;
			levelNum[ 8] <= 8'h0F;
			levelNum[ 9] <= 8'h07;
			levelNum[10] <= 8'h0F;
			levelNum[11] <= 8'h7C;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd6:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h3E;
			levelNum[ 5] <= 8'h70;
			levelNum[ 6] <= 8'hE0;
			levelNum[ 7] <= 8'hFE;
			levelNum[ 8] <= 8'hE7;
			levelNum[ 9] <= 8'hE7;
			levelNum[10] <= 8'hE7;
			levelNum[11] <= 8'h7E;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd7:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'hFF;
			levelNum[ 5] <= 8'h06;
			levelNum[ 6] <= 8'h0E;
			levelNum[ 7] <= 8'h1C;
			levelNum[ 8] <= 8'h1C;
			levelNum[ 9] <= 8'h38;
			levelNum[10] <= 8'h38;
			levelNum[11] <= 8'h70;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd8:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'hE7;
			levelNum[ 6] <= 8'hE7;
			levelNum[ 7] <= 8'h7E;
			levelNum[ 8] <= 8'hE7;
			levelNum[ 9] <= 8'hE7;
			levelNum[10] <= 8'hE7;
			levelNum[11] <= 8'h7E;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		8'd9:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'hE7;
			levelNum[ 6] <= 8'hE7;
			levelNum[ 7] <= 8'hE7;
			levelNum[ 8] <= 8'h7F;
			levelNum[ 9] <= 8'h07;
			levelNum[10] <= 8'h0E;
			levelNum[11] <= 8'hFC;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end 	
		default:begin
			levelNum[ 0] <= 8'h00;
			levelNum[ 1] <= 8'h00;
			levelNum[ 2] <= 8'h00;
			levelNum[ 3] <= 8'h00;
			levelNum[ 4] <= 8'h7E;
			levelNum[ 5] <= 8'hE7;
			levelNum[ 6] <= 8'hE7;
			levelNum[ 7] <= 8'hE7;
			levelNum[ 8] <= 8'hE7;
			levelNum[ 9] <= 8'hE7;
			levelNum[10] <= 8'hE7;
			levelNum[11] <= 8'h7E;
			levelNum[12] <= 8'h00;
			levelNum[13] <= 8'h00;
			levelNum[14] <= 8'h00;
			levelNum[15] <= 8'h00;
		end
	endcase

	// stepStr
	stepStr[ 0] <= 48'h000000000000;
	stepStr[ 1] <= 48'h000000000000;
	stepStr[ 2] <= 48'h000000000000;
	stepStr[ 3] <= 48'h000000000000;
	stepStr[ 4] <= 48'h000000000000;
	stepStr[ 5] <= 48'h001000000000;
	stepStr[ 6] <= 48'h001000000018;
	stepStr[ 7] <= 48'h3E7C3CD83E18;
	stepStr[ 8] <= 48'h421042644200;
	stepStr[ 9] <= 48'h401042424000;
	stepStr[10] <= 48'h3C107E423C00;
	stepStr[11] <= 48'h021040420200;
	stepStr[12] <= 48'h421242644218;
	stepStr[13] <= 48'h7C0C3C587C18;
	stepStr[14] <= 48'h000000000000;
	stepStr[15] <= 48'h000000000000;

	// stepNum
	stepUnits = step % 10;
	stepTens = step / 10;
	// stepTens
	case (stepTens)
		8'd0:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'hE7;
			stepNum1[ 6] <= 8'hE7;
			stepNum1[ 7] <= 8'hE7;
			stepNum1[ 8] <= 8'hE7;
			stepNum1[ 9] <= 8'hE7;
			stepNum1[10] <= 8'hE7;
			stepNum1[11] <= 8'h7E;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end
		8'd1:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h1C;
			stepNum1[ 5] <= 8'h7C;
			stepNum1[ 6] <= 8'h1C;
			stepNum1[ 7] <= 8'h1C;
			stepNum1[ 8] <= 8'h1C;
			stepNum1[ 9] <= 8'h1C;
			stepNum1[10] <= 8'h1C;
			stepNum1[11] <= 8'h1C;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end
			 	
		8'd2:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'hE7;
			stepNum1[ 6] <= 8'h07;
			stepNum1[ 7] <= 8'h0E;
			stepNum1[ 8] <= 8'h1C;
			stepNum1[ 9] <= 8'h70;
			stepNum1[10] <= 8'hE0;
			stepNum1[11] <= 8'hFF;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd3:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'h6E;
			stepNum1[ 6] <= 8'h0E;
			stepNum1[ 7] <= 8'h7C;
			stepNum1[ 8] <= 8'h0E;
			stepNum1[ 9] <= 8'h07;
			stepNum1[10] <= 8'hEE;
			stepNum1[11] <= 8'h7C;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd4:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h0E;
			stepNum1[ 5] <= 8'h1E;
			stepNum1[ 6] <= 8'h3E;
			stepNum1[ 7] <= 8'h7E;
			stepNum1[ 8] <= 8'hEE;
			stepNum1[ 9] <= 8'hFF;
			stepNum1[10] <= 8'h0E;
			stepNum1[11] <= 8'h0E;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd5:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'h70;
			stepNum1[ 6] <= 8'h60;
			stepNum1[ 7] <= 8'h7E;
			stepNum1[ 8] <= 8'h0F;
			stepNum1[ 9] <= 8'h07;
			stepNum1[10] <= 8'h0F;
			stepNum1[11] <= 8'h7C;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd6:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h3E;
			stepNum1[ 5] <= 8'h70;
			stepNum1[ 6] <= 8'hE0;
			stepNum1[ 7] <= 8'hFE;
			stepNum1[ 8] <= 8'hE7;
			stepNum1[ 9] <= 8'hE7;
			stepNum1[10] <= 8'hE7;
			stepNum1[11] <= 8'h7E;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd7:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'hFF;
			stepNum1[ 5] <= 8'h06;
			stepNum1[ 6] <= 8'h0E;
			stepNum1[ 7] <= 8'h1C;
			stepNum1[ 8] <= 8'h1C;
			stepNum1[ 9] <= 8'h38;
			stepNum1[10] <= 8'h38;
			stepNum1[11] <= 8'h70;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd8:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'hE7;
			stepNum1[ 6] <= 8'hE7;
			stepNum1[ 7] <= 8'h7E;
			stepNum1[ 8] <= 8'hE7;
			stepNum1[ 9] <= 8'hE7;
			stepNum1[10] <= 8'hE7;
			stepNum1[11] <= 8'h7E;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		8'd9:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'hE7;
			stepNum1[ 6] <= 8'hE7;
			stepNum1[ 7] <= 8'hE7;
			stepNum1[ 8] <= 8'h7F;
			stepNum1[ 9] <= 8'h07;
			stepNum1[10] <= 8'h0E;
			stepNum1[11] <= 8'hFC;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end 	
		default:begin
			stepNum1[ 0] <= 8'h00;
			stepNum1[ 1] <= 8'h00;
			stepNum1[ 2] <= 8'h00;
			stepNum1[ 3] <= 8'h00;
			stepNum1[ 4] <= 8'h7E;
			stepNum1[ 5] <= 8'hE7;
			stepNum1[ 6] <= 8'hE7;
			stepNum1[ 7] <= 8'hE7;
			stepNum1[ 8] <= 8'hE7;
			stepNum1[ 9] <= 8'hE7;
			stepNum1[10] <= 8'hE7;
			stepNum1[11] <= 8'h7E;
			stepNum1[12] <= 8'h00;
			stepNum1[13] <= 8'h00;
			stepNum1[14] <= 8'h00;
			stepNum1[15] <= 8'h00;
		end
	endcase

	// stepUnits
	case (stepUnits)
		8'd0:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'hE7;
			stepNum2[ 6] <= 8'hE7;
			stepNum2[ 7] <= 8'hE7;
			stepNum2[ 8] <= 8'hE7;
			stepNum2[ 9] <= 8'hE7;
			stepNum2[10] <= 8'hE7;
			stepNum2[11] <= 8'h7E;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end
		8'd1:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h1C;
			stepNum2[ 5] <= 8'h7C;
			stepNum2[ 6] <= 8'h1C;
			stepNum2[ 7] <= 8'h1C;
			stepNum2[ 8] <= 8'h1C;
			stepNum2[ 9] <= 8'h1C;
			stepNum2[10] <= 8'h1C;
			stepNum2[11] <= 8'h1C;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end
			 	
		8'd2:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'hE7;
			stepNum2[ 6] <= 8'h07;
			stepNum2[ 7] <= 8'h0E;
			stepNum2[ 8] <= 8'h1C;
			stepNum2[ 9] <= 8'h70;
			stepNum2[10] <= 8'hE0;
			stepNum2[11] <= 8'hFF;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd3:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'h6E;
			stepNum2[ 6] <= 8'h0E;
			stepNum2[ 7] <= 8'h7C;
			stepNum2[ 8] <= 8'h0E;
			stepNum2[ 9] <= 8'h07;
			stepNum2[10] <= 8'hEE;
			stepNum2[11] <= 8'h7C;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd4:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h0E;
			stepNum2[ 5] <= 8'h1E;
			stepNum2[ 6] <= 8'h3E;
			stepNum2[ 7] <= 8'h7E;
			stepNum2[ 8] <= 8'hEE;
			stepNum2[ 9] <= 8'hFF;
			stepNum2[10] <= 8'h0E;
			stepNum2[11] <= 8'h0E;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd5:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'h70;
			stepNum2[ 6] <= 8'h60;
			stepNum2[ 7] <= 8'h7E;
			stepNum2[ 8] <= 8'h0F;
			stepNum2[ 9] <= 8'h07;
			stepNum2[10] <= 8'h0F;
			stepNum2[11] <= 8'h7C;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd6:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h3E;
			stepNum2[ 5] <= 8'h70;
			stepNum2[ 6] <= 8'hE0;
			stepNum2[ 7] <= 8'hFE;
			stepNum2[ 8] <= 8'hE7;
			stepNum2[ 9] <= 8'hE7;
			stepNum2[10] <= 8'hE7;
			stepNum2[11] <= 8'h7E;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd7:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'hFF;
			stepNum2[ 5] <= 8'h06;
			stepNum2[ 6] <= 8'h0E;
			stepNum2[ 7] <= 8'h1C;
			stepNum2[ 8] <= 8'h1C;
			stepNum2[ 9] <= 8'h38;
			stepNum2[10] <= 8'h38;
			stepNum2[11] <= 8'h70;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd8:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'hE7;
			stepNum2[ 6] <= 8'hE7;
			stepNum2[ 7] <= 8'h7E;
			stepNum2[ 8] <= 8'hE7;
			stepNum2[ 9] <= 8'hE7;
			stepNum2[10] <= 8'hE7;
			stepNum2[11] <= 8'h7E;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		8'd9:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'hE7;
			stepNum2[ 6] <= 8'hE7;
			stepNum2[ 7] <= 8'hE7;
			stepNum2[ 8] <= 8'h7F;
			stepNum2[ 9] <= 8'h07;
			stepNum2[10] <= 8'h0E;
			stepNum2[11] <= 8'hFC;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end 	
		default:begin
			stepNum2[ 0] <= 8'h00;
			stepNum2[ 1] <= 8'h00;
			stepNum2[ 2] <= 8'h00;
			stepNum2[ 3] <= 8'h00;
			stepNum2[ 4] <= 8'h7E;
			stepNum2[ 5] <= 8'hE7;
			stepNum2[ 6] <= 8'hE7;
			stepNum2[ 7] <= 8'hE7;
			stepNum2[ 8] <= 8'hE7;
			stepNum2[ 9] <= 8'hE7;
			stepNum2[10] <= 8'hE7;
			stepNum2[11] <= 8'h7E;
			stepNum2[12] <= 8'h00;
			stepNum2[13] <= 8'h00;
			stepNum2[14] <= 8'h00;
			stepNum2[15] <= 8'h00;
		end
	endcase

	// missionclearStr
	missionclearStr[ 0] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 1] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 2] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 3] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 4] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 5] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 6] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[ 7] <= 312'h000000000000007C00007C00000000003C00000000000000000F08000000000000001800000000;
	missionclearStr[ 8] <= 312'hFC007E0FFFF003CFE003CFE00FFFF000E7807E00FF00000000F3F83FE0007FFFF0003C007FFF80;
	missionclearStr[ 9] <= 312'h1C0078003C000601F00601F0003C000380C00E001000000001C0780F00000E0078003C000E01E0;
	missionclearStr[10] <= 312'h1E0078003C000C00700C0070003C000700600F00100000000700180F00000E0018007C000E0070;
	missionclearStr[11] <= 312'h1E00F8003C00180030180030003C000E00700F801000000007000C0F00000E0008006C000E0078;
	missionclearStr[12] <= 312'h1E00B8003C00180030180030003C000E00380B80100000000E000C0F00000E000C004E000E0038;
	missionclearStr[13] <= 312'h1600B8003C00380010380010003C001C003809C0100000001C00040F00000E0000004E000E0038;
	missionclearStr[14] <= 312'h1700B8003C00380000380000003C001C003C09C0100000001C00000F00000E000000CE000E0038;
	missionclearStr[15] <= 312'h1701B8003C00180000180000003C003C001C08E0100000003C00000F00000E008000C7000E0038;
	missionclearStr[16] <= 312'h170138003C001C00001C0000003C003C001C08F0100000003C00000F00000E00800087000E0038;
	missionclearStr[17] <= 312'h130138003C000F00000F0000003C0038001C0870100000003800000F00000E00800187000E0070;
	missionclearStr[18] <= 312'h138338003C0007C00007C000003C0038001E0838100000003800000F00000E00800183000E00E0;
	missionclearStr[19] <= 312'h138238003C0003F80003F800003C0038001E083C100000003800000F00000E07800103800E03C0;
	missionclearStr[20] <= 312'h138238003C00007F00007F00003C0038001E081C100000003800000F00000FFF800303800FFF00;
	missionclearStr[21] <= 312'h118238003C00001F80001F80003C0038001E081E100000003800000F00000E01800303800E0E00;
	missionclearStr[22] <= 312'h11C638003C000003E00003E0003C0038001E080E100000003800000F00000E00800201C00E0E00;
	missionclearStr[23] <= 312'h11C438003C000001F00001F0003C0038001E0807100000003800000F00000E008003FFC00E0700;
	missionclearStr[24] <= 312'h10C438003C00000070000070003C0038001C0807900000003800000F00000E00800601C00E0700;
	missionclearStr[25] <= 312'h10CC38003C00000038000038003C003C001C0803900000003800000F00000E00000401C00E0380;
	missionclearStr[26] <= 312'h10E838003C00000038000038003C003C001C0803D00000003C00000F00000E00000400E00E0380;
	missionclearStr[27] <= 312'h10E838003C00200018200018003C001C001C0801F00000003C00040F00000E00000C00E00E01C0;
	missionclearStr[28] <= 312'h106838003C00300018300018003C001C00380800F00000001C00040F00040E00040C00E00E01C0;
	missionclearStr[29] <= 312'h107838003C00100038100038003C000E00380800F00000001E00080F00040E00040800700E00E0;
	missionclearStr[30] <= 312'h107038003C00180030180030003C000E00700800700000000E00180F000C0E000C1800700E00E0;
	missionclearStr[31] <= 312'h107038003C001C00701C0070003C000700600800300000000700300F001C0E00181800700E00F0;
	missionclearStr[32] <= 312'h103038003C001F00E01F00E0003C000380C00800300000000380600F00380E00381800780E0070;
	missionclearStr[33] <= 312'h7C21FE0FFFF01FE3801FE3800FFFF000E380FF001000000001FFC07FFFF87FFFF8FE01FE7FC07E;
	missionclearStr[34] <= 312'h000000000000003C00003C00000000003C00000000000000001E00000000000000000000000000;
	missionclearStr[35] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[36] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[37] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[38] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;
	missionclearStr[39] <= 312'h000000000000000000000000000000000000000000000000000000000000000000000000000000;

end

/*
* 方向控制与使能
*/
always @(posedge CORE_Gm_clk or negedge CORE_Gm_rst) begin
	if(!CORE_Gm_rst)begin
		NeighBlo1X <= ManPosX;
		NeighBlo1Y <= ManPosY;
		NeighBlo2X <= ManPosX;
		NeighBlo2Y <= ManPosY;
		movEn <= 1'b0;
	end
	else begin
		if(CORE_Gm_dir_up) begin
			NeighBlo1X = ManPosX-3'd1;
			NeighBlo1Y = ManPosY;
			NeighBlo2X = ManPosX-3'd2;
			NeighBlo2Y = ManPosY;
			movEn <= 1'b1;
		end
		else if (CORE_Gm_dir_down) begin
			NeighBlo1X = ManPosX+3'd1;
			NeighBlo1Y = ManPosY;
			NeighBlo2X = ManPosX+3'd2;
			NeighBlo2Y = ManPosY;
			movEn <= 1'b1;
		end
		else if (CORE_Gm_dir_left) begin
			NeighBlo1X = ManPosX;
			NeighBlo1Y = ManPosY-3'd1;
			NeighBlo2X = ManPosX;
			NeighBlo2Y = ManPosY-3'd2;
			movEn <= 1'b1;
		end
		else if (CORE_Gm_dir_right) begin
			NeighBlo1X = ManPosX;
			NeighBlo1Y = ManPosY+3'd1;
			NeighBlo2X = ManPosX;
			NeighBlo2Y = ManPosY+3'd2;
			movEn <= 1'b1;
		end
		else begin
			movEn <= 1'b0;
		end
	end
end    


/*
* 前进判断与坐标修改 等级切换
*/
always @(posedge CORE_Gm_clk or negedge CORE_Gm_rst or negedge CORE_Gm_cur_rst) begin
	if (!CORE_Gm_rst || !CORE_Gm_cur_rst) begin
		// 初始化
		nextLevel = 1'b1; // 进入下一等级标志位为1，使得其初始化为等级1或者重置为当前等级
		step = 8'd0; // 步数计数器清零
		ReachDestination = 3'd0; // 箱子到位个数清零
		Win = 1'b0; // 胜利标志位清零
		missionClear = 1'b0;
		if (!CORE_Gm_rst) begin
			level = 3'd1; // !!!如果是全局初始化，则初始等级设为1
		end
	end
	else begin
		if (nextLevel == 1'b1 )begin
			// 当前关卡复位或者进入下一等级操作
			// 刷新或重置地图
			nextLevel = 1'b0;
			step = 8'd0;
			ReachDestination <= 3'd0;
			if (level == 3'd1) begin
				// 第一关地图初始化
				GameArea[0][0] = 3'd3;
				GameArea[0][1] = 3'd3;
				GameArea[0][2] = 3'd3;
				GameArea[0][3] = 3'd3;
				GameArea[0][4] = 3'd3;
				GameArea[0][5] = 3'd3;
				GameArea[0][6] = 3'd3;
				GameArea[0][7] = 3'd3;
				GameArea[1][0] = 3'd3;
				GameArea[1][1] = 3'd3;
				GameArea[1][2] = 3'd3;
				GameArea[1][3] = 3'd4;
				GameArea[1][4] = 3'd3;
				GameArea[1][5] = 3'd3;
				GameArea[1][6] = 3'd3;
				GameArea[1][7] = 3'd3;
				GameArea[2][0] = 3'd3;
				GameArea[2][1] = 3'd3;
				GameArea[2][2] = 3'd3;
				GameArea[2][3] = 3'd0;
				GameArea[2][4] = 3'd3;
				GameArea[2][5] = 3'd3;
				GameArea[2][6] = 3'd3;
				GameArea[2][7] = 3'd3;
				GameArea[3][0] = 3'd3;
				GameArea[3][1] = 3'd3;
				GameArea[3][2] = 3'd3;
				GameArea[3][3] = 3'd2;
				GameArea[3][4] = 3'd0;
				GameArea[3][5] = 3'd2;
				GameArea[3][6] = 3'd4;
				GameArea[3][7] = 3'd3;
				GameArea[4][0] = 3'd3;
				GameArea[4][1] = 3'd4;
				GameArea[4][2] = 3'd0;
				GameArea[4][3] = 3'd2;
				GameArea[4][4] = 3'd1;
				GameArea[4][5] = 3'd3;
				GameArea[4][6] = 3'd3;
				GameArea[4][7] = 3'd3;
				GameArea[5][0] = 3'd3;
				GameArea[5][1] = 3'd3;
				GameArea[5][2] = 3'd3;
				GameArea[5][3] = 3'd3;
				GameArea[5][4] = 3'd2;
				GameArea[5][5] = 3'd3;
				GameArea[5][6] = 3'd3;
				GameArea[5][7] = 3'd3;
				GameArea[6][0] = 3'd3;
				GameArea[6][1] = 3'd3;
				GameArea[6][2] = 3'd3;
				GameArea[6][3] = 3'd3;
				GameArea[6][4] = 3'd4;
				GameArea[6][5] = 3'd3;
				GameArea[6][6] = 3'd3;
				GameArea[6][7] = 3'd3;
				GameArea[7][0] = 3'd3;
				GameArea[7][1] = 3'd3;
				GameArea[7][2] = 3'd3;
				GameArea[7][3] = 3'd3;
				GameArea[7][4] = 3'd3;
				GameArea[7][5] = 3'd3;
				GameArea[7][6] = 3'd3;
				GameArea[7][7] = 3'd3;

				ManPosX = 3'd4;
				ManPosY = 3'd4;
				TotalDestination = 4;
			end
			else if (level == 3'd2) begin
				// 第二关地图初始化
				GameArea[0][0] = 3'd3;
				GameArea[0][1] = 3'd3;
				GameArea[0][2] = 3'd3;
				GameArea[0][3] = 3'd3;
				GameArea[0][4] = 3'd3;
				GameArea[0][5] = 3'd3;
				GameArea[0][6] = 3'd3;
				GameArea[0][7] = 3'd3;
				GameArea[1][0] = 3'd3;
				GameArea[1][1] = 3'd3;
				GameArea[1][2] = 3'd4;
				GameArea[1][3] = 3'd0;
				GameArea[1][4] = 3'd1;
				GameArea[1][5] = 3'd0;
				GameArea[1][6] = 3'd4;
				GameArea[1][7] = 3'd3;
				GameArea[2][0] = 3'd3;
				GameArea[2][1] = 3'd3;
				GameArea[2][2] = 3'd0;
				GameArea[2][3] = 3'd2;
				GameArea[2][4] = 3'd0;
				GameArea[2][5] = 3'd2;
				GameArea[2][6] = 3'd0;
				GameArea[2][7] = 3'd3;
				GameArea[3][0] = 3'd3;
				GameArea[3][1] = 3'd3;
				GameArea[3][2] = 3'd0;
				GameArea[3][3] = 3'd3;
				GameArea[3][4] = 3'd3;
				GameArea[3][5] = 3'd3;
				GameArea[3][6] = 3'd0;
				GameArea[3][7] = 3'd3;
				GameArea[4][0] = 3'd3;
				GameArea[4][1] = 3'd3;
				GameArea[4][2] = 3'd0;
				GameArea[4][3] = 3'd2;
				GameArea[4][4] = 3'd0;
				GameArea[4][5] = 3'd2;
				GameArea[4][6] = 3'd0;
				GameArea[4][7] = 3'd3;
				GameArea[5][0] = 3'd3;
				GameArea[5][1] = 3'd3;
				GameArea[5][2] = 3'd4;
				GameArea[5][3] = 3'd0;
				GameArea[5][4] = 3'd0;
				GameArea[5][5] = 3'd0;
				GameArea[5][6] = 3'd4;
				GameArea[5][7] = 3'd3;
				GameArea[6][0] = 3'd3;
				GameArea[6][1] = 3'd3;
				GameArea[6][2] = 3'd3;
				GameArea[6][3] = 3'd3;
				GameArea[6][4] = 3'd3;
				GameArea[6][5] = 3'd3;
				GameArea[6][6] = 3'd3;
				GameArea[6][7] = 3'd3;
				GameArea[7][0] = 3'd3;
				GameArea[7][1] = 3'd3;
				GameArea[7][2] = 3'd3;
				GameArea[7][3] = 3'd3;
				GameArea[7][4] = 3'd3;
				GameArea[7][5] = 3'd3;
				GameArea[7][6] = 3'd3;
				GameArea[7][7] = 3'd3;

				ManPosX = 3'd1;
				ManPosY = 3'd4;
				TotalDestination = 4;
			end
			else if (level == 3'd3) begin
				// 第三关地图初始化
				GameArea[0][0] = 3'd3;
				GameArea[0][1] = 3'd3;
				GameArea[0][2] = 3'd3;
				GameArea[0][3] = 3'd3;
				GameArea[0][4] = 3'd3;
				GameArea[0][5] = 3'd3;
				GameArea[0][6] = 3'd3;
				GameArea[0][7] = 3'd3;
				GameArea[1][0] = 3'd3;
				GameArea[1][1] = 3'd3;
				GameArea[1][2] = 3'd0;
				GameArea[1][3] = 3'd3;
				GameArea[1][4] = 3'd3;
				GameArea[1][5] = 3'd3;
				GameArea[1][6] = 3'd0;
				GameArea[1][7] = 3'd3;
				GameArea[2][0] = 3'd3;
				GameArea[2][1] = 3'd3;
				GameArea[2][2] = 3'd0;
				GameArea[2][3] = 3'd4;
				GameArea[2][4] = 3'd2;
				GameArea[2][5] = 3'd0;
				GameArea[2][6] = 3'd0;
				GameArea[2][7] = 3'd3;
				GameArea[3][0] = 3'd3;
				GameArea[3][1] = 3'd3;
				GameArea[3][2] = 3'd1;
				GameArea[3][3] = 3'd2;
				GameArea[3][4] = 3'd4;
				GameArea[3][5] = 3'd0;
				GameArea[3][6] = 3'd0;
				GameArea[3][7] = 3'd3;
				GameArea[4][0] = 3'd3;
				GameArea[4][1] = 3'd3;
				GameArea[4][2] = 3'd0;
				GameArea[4][3] = 3'd0;
				GameArea[4][4] = 3'd4;
				GameArea[4][5] = 3'd2;
				GameArea[4][6] = 3'd0;
				GameArea[4][7] = 3'd3;
				GameArea[5][0] = 3'd3;
				GameArea[5][1] = 3'd3;
				GameArea[5][2] = 3'd0;
				GameArea[5][3] = 3'd3;
				GameArea[5][4] = 3'd3;
				GameArea[5][5] = 3'd3;
				GameArea[5][6] = 3'd0;
				GameArea[5][7] = 3'd3;
				GameArea[6][0] = 3'd3;
				GameArea[6][1] = 3'd3;
				GameArea[6][2] = 3'd3;
				GameArea[6][3] = 3'd3;
				GameArea[6][4] = 3'd3;
				GameArea[6][5] = 3'd3;
				GameArea[6][6] = 3'd3;
				GameArea[6][7] = 3'd3;
				GameArea[7][0] = 3'd3;
				GameArea[7][1] = 3'd3;
				GameArea[7][2] = 3'd3;
				GameArea[7][3] = 3'd3;
				GameArea[7][4] = 3'd3;
				GameArea[7][5] = 3'd3;
				GameArea[7][6] = 3'd3;
				GameArea[7][7] = 3'd3;

				ManPosX = 3'd3;
				ManPosY = 3'd2;
				TotalDestination = 3;
			end
			else if (level == 3'd4) begin
				GameArea[0][0] = 3'd3;
				GameArea[0][1] = 3'd3;
				GameArea[0][2] = 3'd3;
				GameArea[0][3] = 3'd3;
				GameArea[0][4] = 3'd3;
				GameArea[0][5] = 3'd3;
				GameArea[0][6] = 3'd3;
				GameArea[0][7] = 3'd3;
				GameArea[1][0] = 3'd3;
				GameArea[1][1] = 3'd1;
				GameArea[1][2] = 3'd0;
				GameArea[1][3] = 3'd4;
				GameArea[1][4] = 3'd4;
				GameArea[1][5] = 3'd0;
				GameArea[1][6] = 3'd0;
				GameArea[1][7] = 3'd3;
				GameArea[2][0] = 3'd3;
				GameArea[2][1] = 3'd0;
				GameArea[2][2] = 3'd0;
				GameArea[2][3] = 3'd2;
				GameArea[2][4] = 3'd2;
				GameArea[2][5] = 3'd0;
				GameArea[2][6] = 3'd0;
				GameArea[2][7] = 3'd3;
				GameArea[3][0] = 3'd3;
				GameArea[3][1] = 3'd0;
				GameArea[3][2] = 3'd2;
				GameArea[3][3] = 3'd4;
				GameArea[3][4] = 3'd4;
				GameArea[3][5] = 3'd2;
				GameArea[3][6] = 3'd0;
				GameArea[3][7] = 3'd3;
				GameArea[4][0] = 3'd3;
				GameArea[4][1] = 3'd0;
				GameArea[4][2] = 3'd2;
				GameArea[4][3] = 3'd4;
				GameArea[4][4] = 3'd4;
				GameArea[4][5] = 3'd2;
				GameArea[4][6] = 3'd0;
				GameArea[4][7] = 3'd3;
				GameArea[5][0] = 3'd3;
				GameArea[5][1] = 3'd0;
				GameArea[5][2] = 3'd0;
				GameArea[5][3] = 3'd2;
				GameArea[5][4] = 3'd2;
				GameArea[5][5] = 3'd0;
				GameArea[5][6] = 3'd0;
				GameArea[5][7] = 3'd3;
				GameArea[6][0] = 3'd3;
				GameArea[6][1] = 3'd0;
				GameArea[6][2] = 3'd0;
				GameArea[6][3] = 3'd4;
				GameArea[6][4] = 3'd4;
				GameArea[6][5] = 3'd0;
				GameArea[6][6] = 3'd0;
				GameArea[6][7] = 3'd3;
				GameArea[7][0] = 3'd3;
				GameArea[7][1] = 3'd3;
				GameArea[7][2] = 3'd3;
				GameArea[7][3] = 3'd3;
				GameArea[7][4] = 3'd3;
				GameArea[7][5] = 3'd3;
				GameArea[7][6] = 3'd3;
				GameArea[7][7] = 3'd3;

				ManPosX = 1;
				ManPosY = 1;
				TotalDestination = 8;
			end
			else if (level == 3'd5) begin
				missionClear = 1'b1;
			end
		end
		else if (ReachDestination == TotalDestination) begin
			Win = 1'b1;
			level = level + 3'd1;
			nextLevel = 1'b1;
		end
		else begin
			if (movEn == 1'b1)begin
				if (GameArea[ManPosX][ManPosY] == 3'd1) 
				begin
				//------------------ man on empty ---------------------
					if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd2) begin
					//----------------- box neighbouring --------------
						if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd2;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd1;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd2;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd5;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							ReachDestination <= ReachDestination + 3'b1;
							
						end
					end
					else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd5) begin
					//----------- box on destination neighbouring--------
						if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd2;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							ReachDestination <= ReachDestination - 3'b1;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd1;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd5;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd5;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
					end

					else begin
					//------------- not box neighbouring ----------------
						if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
						else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd1;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
							
						end
						else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd0;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
					end
				end
				else begin
				//--------------------- man on destination -----------------
					if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd2) begin
						//---------------- box neighbouring --------------
						if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd2;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd6;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd2;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd5;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							ReachDestination <= ReachDestination + 3'b1;
							
						end
					end
					else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd5) begin
						//---------- box on destination neighbouring--------
						if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd2;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							ReachDestination <= ReachDestination - 3'b1;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd6;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd5;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
							
						end
						else if (GameArea[NeighBlo2X][NeighBlo2Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;
							GameArea[NeighBlo2X][NeighBlo2Y] <= 3'd5;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
							
						end
					end

					else begin
						//------------ not box neighbouring ----------------
						if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd0) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd1;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
						end
						else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd3) begin
							GameArea[ManPosX][ManPosY] <= 3'd6;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd3;

							ManPosX <= ManPosX;
							ManPosY <= ManPosY;
						end
						else if (GameArea[NeighBlo1X][NeighBlo1Y] == 3'd4) begin
							GameArea[ManPosX][ManPosY] <= 3'd4;
							GameArea[NeighBlo1X][NeighBlo1Y] <= 3'd6;

							ManPosX <= NeighBlo1X;
							ManPosY <= NeighBlo1Y;
							step <= step + 1'b1;
						end
					end
				end
			end
		end
		
		
	end
end



/*
* 显示信号输出
*/
always @(posedge CORE_Gm_clk) begin
	// ---------------------- 游戏结束界面输出 ------------------------
	if(missionClear == 1'b1) begin
		if((CORE_CurCoorX >= missionclearStrStartX) && (CORE_CurCoorX < missionclearStrStartX + missionclearStrWidth)
		&& (CORE_CurCoorY >= missionclearStrStartY) && (CORE_CurCoorY < missionclearStrStartY + missionclearStrHeight)) 
		begin
			if(missionclearStr[CORE_CurCoorY - missionclearStrStartY][10'd311 - CORE_CurCoorX + missionclearStrStartX])begin
				CORE_PixelSignal <= WHITE;             
			end
			else begin
				CORE_PixelSignal <= BLACK;                 
			end
		end
	end
	else begin

		// ------------------------------------------------------------
		//----------------------- 游戏信息输出控制 ---------------------
		// ------------ levelStr输出 ---------------------
		if((CORE_CurCoorX >= levelStrStartX) && (CORE_CurCoorX < levelStrStartX + levelStrWidth)
		&& (CORE_CurCoorY >= levelStrStartY) && (CORE_CurCoorY < levelStrStartY + levelHeight)) 
		begin
				if(levelStr[CORE_CurCoorY - levelStrStartY][10'd39 - CORE_CurCoorX + levelStrStartX])begin
					CORE_PixelSignal <= WHITE;             
				end
				else begin
					CORE_PixelSignal <= BLACK;                 
				end
		end
		// ------------ levelNum输出 ---------------------
		else if((CORE_CurCoorX >= levelNumStartX) && (CORE_CurCoorX < levelNumStartX + levelNumWidth)
		&& (CORE_CurCoorY >= levelNumStartY) && (CORE_CurCoorY < levelNumStartY + levelHeight)) 
		begin
				if(levelNum[CORE_CurCoorY - levelNumStartY][10'd7 - CORE_CurCoorX + levelNumStartX])begin
					CORE_PixelSignal <= WHITE;
				end
				else begin
					CORE_PixelSignal <= BLACK;      
				end
		end
		
		// --------------- stepStr输出 ---------------------
		else if((CORE_CurCoorX >= stepStrStartX) && (CORE_CurCoorX < stepStrStartX + stepStrWidth)
		&& (CORE_CurCoorY >= stepStrStartY) && (CORE_CurCoorY < stepStrStartY + stepHeight)) 
		begin
				if(stepStr[CORE_CurCoorY - stepStrStartY][10'd47 - CORE_CurCoorX + stepStrStartX])begin
					CORE_PixelSignal <= WHITE;             
				end
				else begin
					CORE_PixelSignal <= BLACK;                 
				end
		end
		// ------------ stepNum1输出 ---------------------
		else if((CORE_CurCoorX >= stepNum1StartX) && (CORE_CurCoorX < stepNum1StartX + stepNumWidth)
		&& (CORE_CurCoorY >= stepNum1StartY) && (CORE_CurCoorY < stepNum1StartY + stepHeight)) 
		begin
				if(stepNum1[CORE_CurCoorY - stepNum1StartY][10'd7 - CORE_CurCoorX + stepNum1StartX])begin
					CORE_PixelSignal <= WHITE;
				end
				else begin
					CORE_PixelSignal <= BLACK;      
				end
		end
		// ------------ stepNum2输出 ---------------------
		else if((CORE_CurCoorX >= stepNum2StartX) && (CORE_CurCoorX < stepNum2StartX + stepNumWidth)
		&& (CORE_CurCoorY >= stepNum2StartY) && (CORE_CurCoorY < stepNum2StartY + stepHeight)) 
		begin
				if(stepNum2[CORE_CurCoorY - stepNum2StartY][10'd7 - CORE_CurCoorX + stepNum2StartX])begin
					CORE_PixelSignal <= WHITE;
				end
				else begin
					CORE_PixelSignal <= BLACK;      
				end
		end


		// ------------------------------------------------------------
		//----------------------- 游戏区域输出控制 ---------------------
		// 判断当前坐标落在哪一个方格里，一共判断8*8=64次！
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 1 * BLOCK_SIZE))) 
		begin
			case (GameArea[0][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 2 * BLOCK_SIZE))) 
		begin
			case (GameArea[1][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 3 * BLOCK_SIZE))) 
		begin
			case (GameArea[2][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 4 * BLOCK_SIZE))) 
		begin
			case (GameArea[3][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 5 * BLOCK_SIZE))) 
		begin
			case (GameArea[4][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 6 * BLOCK_SIZE))) 
		begin
			case (GameArea[5][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 7 * BLOCK_SIZE))) 
		begin
			case (GameArea[6][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 0 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][0])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 1 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][1])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 2 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][2])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 3 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][3])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 4 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][4])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 5 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][5])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 6 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][6])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else if ((CORE_CurCoorX > (BOARDER_LEFT + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorX < (BOARDER_LEFT + 8 * BLOCK_SIZE))
		&& (CORE_CurCoorY > (BOARDER_UP + 7 * BLOCK_SIZE))
		&& (CORE_CurCoorY < (BOARDER_UP + 8 * BLOCK_SIZE))) 
		begin
			case (GameArea[7][7])
				3'd0: CORE_PixelSignal <= WHITE; 
				3'd1: CORE_PixelSignal <= MAROON;
				3'd2: CORE_PixelSignal <= NAVY;
				3'd3: CORE_PixelSignal <= BLACK;
				3'd4: CORE_PixelSignal <= OLIVE;
				3'd5: CORE_PixelSignal <= YELLOW;
				3'd6: CORE_PixelSignal <= VIOLET;
				default: CORE_PixelSignal <= BLACK;
			endcase
		end
		else begin
			CORE_PixelSignal <= BLACK;
		end
	end
end


endmodule