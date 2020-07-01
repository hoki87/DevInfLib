/////////////////////////// INCLUDE /////////////////////////////
`include "../src/w5300_inc.v"

////////////////////////////////////////////////////////////////
//
//  Module  : w5300_init.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2017/9/16
//
////////////////////////////////////////////////////////////////
// 
//  Description: initial register in W5300
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////

`define ST_INIT_RESET  2'b00
`define ST_INIT_WRITE  2'b01
`define ST_INIT_CHECK  2'b10
`define ST_INIT_IDLE   2'b11

/////////////////////////// MODULE //////////////////////////////
module w5300_init
(
   clk,
   reset,
   w_init_done,
   w_rst,
   w_addr,
   w_wdata,
   w_wr,
   w_wr_en,
   w_rd,
   w_rdata,
   w_cs
);

   ///////////////// PARAMETER ////////////////
   parameter P_REG_NUM = 56;
   parameter P_CHK_NUM = 4;
   parameter P_CLK_PD  = 10;
   parameter P_SIG_VD  = 7;

   ////////////////// PORT ////////////////////
   input          clk;         // clock input, 100MHz
   input          reset;       // reset input
   output         w_init_done; // initial done
   output         w_rst;       // reset output to w5300
   output [9:0]   w_addr;      // address output to w5300 
   output [7:0]   w_wdata;     // write data output to w5300
   output         w_wr;        // write output to w5300
   output         w_wr_en;     // write enable output 
   output         w_rd;        // read output to w5300
   input  [7:0]   w_rdata;     // read data input from w5300
   output         w_cs;        // chipselect output to w5300

   ////////////////// ARCH ////////////////////
   
   ////////////////// Clock tick @ 10ns
   
   reg  [3:0]  clk_tick; 
   always@(posedge clk) begin
      if(reset) begin
         clk_tick <= 0;
      end
      else begin
         clk_tick <= clk_tick + 1'b1;
         if(clk_tick==P_CLK_PD-1)
            clk_tick <= 0;
      end
   end
   
   ////////////////// Initial FSM
   
   wire        fsm_en = (clk_tick==P_CLK_PD-1);
   reg  [1:0]  fsm_st;
   reg         fsm_start=1'b1;
   reg  [9:0]  fsm_cnt;
   
   always@(posedge clk) begin
      if(reset) begin
         fsm_st <= `ST_INIT_IDLE;
         fsm_start <= 1'b1;
         fsm_cnt <= 0;
      end
      else begin
         if(fsm_en) begin
            case(fsm_st)
               `ST_INIT_IDLE: begin
                  fsm_cnt <= 0;
                  if(fsm_start) begin
                     fsm_start <= 1'b0;
                     fsm_st <= `ST_INIT_RESET;
                  end
               end
               `ST_INIT_RESET: begin
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt==(55000/(P_CLK_PD*10))) begin // (5us + 50us)/(PD*10ns)
                     fsm_cnt <= 0;
                     fsm_st <= `ST_INIT_WRITE;
                  end
               end
               `ST_INIT_WRITE: begin
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt==P_REG_NUM-1) begin
                     fsm_cnt <= 0;
                     fsm_st <= `ST_INIT_CHECK;
                  end
               end
               `ST_INIT_CHECK: begin
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt==P_CHK_NUM-1) begin
                     fsm_cnt <= 0;
                     fsm_st <= `ST_INIT_IDLE;
                  end
               end
               default:
                  fsm_st <= `ST_INIT_IDLE;
            endcase
         end
      end
   end
   
   reg         w_init_done;
   reg         w_rst;  
   reg  [9:0]  w_addr; 
   reg  [7:0]  w_wdata;
   reg         w_wr;  
   reg         w_wr_en; 
   reg         w_rd;   
   reg         w_cs;   
	wire [9:0]	regmem_addr = regmem[fsm_cnt][17:8];
	wire [7:0]	regmem_data = regmem[fsm_cnt][7:0];
   
	always@* begin
      case(fsm_st)
         `ST_INIT_IDLE: begin
            w_rst       <= 1'b0;  
            w_addr      <= 0; 
            w_wdata     <= 0;
            w_wr        <= 1'b0;   
            w_wr_en     <= 1'b0;
            w_rd        <= 1'b0;   
            w_cs        <= 1'b0;
            w_init_done <= 1'b0;
         end
         `ST_INIT_RESET: begin
            w_rst       <= fsm_cnt<(5000/(P_CLK_PD*10));
            w_addr      <= 0; 
            w_wdata     <= 0;
            w_wr        <= 1'b0;   
            w_wr_en     <= 1'b0;
            w_rd        <= 1'b0;   
            w_cs        <= 1'b0;   
            w_init_done <= 1'b0;
         end
         `ST_INIT_WRITE: begin
            w_rst       <= 1'b0;  
            w_addr      <= regmem_addr; 
            w_wdata     <= regmem_data;
            w_wr        <= (clk_tick<P_SIG_VD); 
            w_wr_en     <= 1'b1;
            w_rd        <= 1'b0;   
            w_cs        <= (clk_tick<P_SIG_VD);
            w_init_done <= 1'b0;
         end
         `ST_INIT_CHECK: begin
            w_rst       <= 1'b0;  
            w_addr      <= chkmem[fsm_cnt][17:8]; 
            w_wdata     <= 0;
            w_wr        <= 1'b0;
            w_wr_en     <= 1'b0;
            w_rd        <= (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
            w_init_done <= fsm_en&(fsm_cnt==P_CHK_NUM-1);
         end
         default: begin
            w_rst       <= 1'b0;
            w_addr      <= 0;
            w_wdata     <= 0;
            w_wr        <= 1'b0;
            w_wr_en     <= 1'b0;
            w_rd        <= 1'b0;
            w_cs        <= 1'b0;
            w_init_done <= 1'b0;
         end
      endcase 
   end
        
   ////////////////// Initial Registers
   
   reg  [17:0]    regmem[0:P_REG_NUM-1];
   reg  [17:0]    chkmem[0:P_CHK_NUM-1];
   initial begin
      regmem[0]  = {`RGAD_MR_0,       8'h38};          // Mode register
      regmem[1]  = {`RGAD_MR_1,       8'h80};           
      regmem[2]  = {`RGAD_IMR_0,      8'h00};          // Interrup mask register
      regmem[3]  = {`RGAD_IMR_1,      8'hFF};          
                                                       
      regmem[4]  = {`RGAD_SHAR_0,     8'h00};          // Source hardware address register
      regmem[5]  = {`RGAD_SHAR_1,     8'h01};          
      regmem[6]  = {`RGAD_SHAR_2,     8'h02};          
      regmem[7]  = {`RGAD_SHAR_3,     8'h03};          
      regmem[8]  = {`RGAD_SHAR_4,     8'h04};          
      regmem[9]  = {`RGAD_SHAR_5,     8'h05};          
                                                       
      regmem[10] = {`RGAD_GAR_0,      8'd192};         // Gateway address register
      regmem[11] = {`RGAD_GAR_1,      8'd168};         
      regmem[12] = {`RGAD_GAR_2,      8'd199};         
      regmem[13] = {`RGAD_GAR_3,      8'd1};           
                                                       
      regmem[14] = {`RGAD_SUBR_0,     8'd255};         // Subnet mask register
      regmem[15] = {`RGAD_SUBR_1,     8'd255};         
      regmem[16] = {`RGAD_SUBR_2,     8'd255};         
      regmem[17] = {`RGAD_SUBR_3,     8'd0};           
                                                       
      regmem[18] = {`RGAD_SIPR_0,     8'd192};         // Source ip address register
      regmem[19] = {`RGAD_SIPR_1,     8'd168};         
      regmem[20] = {`RGAD_SIPR_2,     8'd199};         
      regmem[21] = {`RGAD_SIPR_3,     8'd110};         
                                                       
      regmem[22] = {`RGAD_TMSR_0,     8'h08};          // TX memory size register of SOCKET0: 8Kbytes
      regmem[23] = {`RGAD_RMSR_0,     8'h08};          // RX memory size register of SOCKET0: 8Kbytes
      regmem[24] = {`RGAD_TMSR_1,     8'h08};          // TX memory size register of SOCKET1: 8Kbytes
      regmem[25] = {`RGAD_RMSR_1,     8'h08};          // RX memory size register of SOCKET1: 8Kbytes
                                                       
      regmem[26] = {`RGAD_MTYPER_0,   8'h00};          // Memory type of TX(1) & RX(0)
      regmem[27] = {`RGAD_MTYPER_1,   8'hFF};
      
      regmem[28] = {`RGAD_S0_MR_0,    `SOCK_MR_ALIGN}; // Socket 0 - mode register: TCP
      regmem[29] = {`RGAD_S0_MR_1,    `SOCK_MR_TCP|`SOCK_MR_ND};
      regmem[30] = {`RGAD_S0_PORTR_0, 8'h13};          // Socket 0 - SERVER source port regsiter
      regmem[31] = {`RGAD_S0_PORTR_1, 8'h14};      
      regmem[32] = {`RGAD_S0_DPORTR_0,8'h13};          // Socket 0 - CLIENT destination port register
      regmem[33] = {`RGAD_S0_DPORTR_1,8'h14};          //            (as TCP client, set the listen port number of TCP server)
      regmem[34] = {`RGAD_S0_DIPR_0,  8'd192};         // Socket 0 - CLIENT Destination IP Address Register
      regmem[35] = {`RGAD_S0_DIPR_1,  8'd168};         //            (as TCP client, set IP adderss of TCP server)
      regmem[36] = {`RGAD_S0_DIPR_2,  8'd199};      
      regmem[37] = {`RGAD_S0_DIPR_3,  8'd196};      
      regmem[38] = {`RGAD_S0_IMR_0,   8'h00};          // Socket 0 - interrupt mask register
      regmem[39] = {`RGAD_S0_IMR_1,   8'h1F};        
      regmem[40] = {`RGAD_S0_MSSR_0,  8'h05};          // Socket 0 - Maximum Segment Size Register
      regmem[41] = {`RGAD_S0_MSSR_1,  8'hB4};       
                                                  
      regmem[42] = {`RGAD_S1_MR_0,    8'h00};          // Socket 1 - mode register: UDP & Unicast
      regmem[43] = {`RGAD_S1_MR_1,    `SOCK_MR_UDP};  
      regmem[44] = {`RGAD_S1_IMR_0,   8'h00};          // Socket 1 - interrupt mask register
      regmem[45] = {`RGAD_S1_IMR_1,   8'h1F};        
      regmem[46] = {`RGAD_S1_PORTR_0, 8'h13};          // Socket 1 - SERVER source port regsiter
      regmem[47] = {`RGAD_S1_PORTR_1, 8'h14};      
      regmem[48] = {`RGAD_S1_DPORTR_0,8'h13};          // Socket 1 - CLIENT destination port register
      regmem[49] = {`RGAD_S1_DPORTR_1,8'h14};          //            (as UDP client, set the listen port number of UDP server)
      regmem[50] = {`RGAD_S1_DIPR_0,  8'd192};         // Socket 1 - CLIENT Destination IP Address Register
      regmem[51] = {`RGAD_S1_DIPR_1,  8'd168};         //            (as UDP client, set IP adderss of UDP server)
      regmem[52] = {`RGAD_S1_DIPR_2,  8'd199};      
      regmem[53] = {`RGAD_S1_DIPR_3,  8'd196};      
      regmem[54] = {`RGAD_S1_MSSR_0,  8'h05};          // Socket 1 - Maximum Segment Size Register
      regmem[55] = {`RGAD_S1_MSSR_1,  8'hB4};
            
      chkmem[0]  = {`RGAD_IDR_0,      8'h53};
      chkmem[1]  = {`RGAD_IDR_1,      8'h00};
      chkmem[2]  = {`RGAD_MR_0,       8'h38};
      chkmem[3]  = {`RGAD_MR_1,       8'h00};
   end

endmodule