/////////////////////////// INCLUDE /////////////////////////////
`include "../src/w5300_inc.v"

////////////////////////////////////////////////////////////////
//
//  Module  : w5300_datacomm.v 
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2017/9/17
//
////////////////////////////////////////////////////////////////
// 
//  Description: data communication of W5300
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////

`define  ST_SOCKET_IDLE          3'b000
`define  ST_SOCKET_OPEN          3'b001
`define  ST_SOCKET_LIS_CON       3'b010
`define  ST_SOCKET_ESTABLISHED   3'b011
`define  ST_SOCKET_RECV          3'b100
`define  ST_SOCKET_SEND          3'b101
`define  ST_SOCKET_DISCON        3'b110
`define  ST_SOCKET_CLOSE         3'b111

/////////////////////////// MODULE //////////////////////////////
module w5300_datacomm
(
   clk,
   reset,
   start,
   s_rx_dv,
   s_rx_data,
   s_rx_addr,
   s_rx_done,
   c_tx_en,
   c_tx_addr,
   c_tx_rd,
   c_tx_data,
   c_tx_error,
   c_tx_done,
   w_addr,
   w_wdata,
   w_wr,
   w_wr_en,
   w_rd,
   w_rdata,
   w_cs
);

   ///////////////// PARAMETER ////////////////
   parameter P_PROT       = `PROT_UDP;
   parameter TX_ADDR_NBIT = 14;
   parameter RX_ADDR_NBIT = 14;
   parameter P_CLK_PD     = 10;
   parameter P_SIG_VD     = 7;
   parameter P_TIMEOUT    = 32'h0026_25A0; // unit 100ns
   parameter P_SENDOK_CHK = 1'b0;
   parameter P_PROTIME    = 32'h0026_25A0; // protocol switch cycle, unit 100ns
   parameter P_MR_ALIGN   = `SOCK_MR_ALIGN;

   ////////////////// PORT ////////////////////
   input                      clk;       // clock input, 100MHz
   input                      reset;     // reset input
   input                      start;     // start input
   output                     s_rx_dv;   // rx data valid output, as server
   output [7:0]               s_rx_data; // rx data output, as server
   output [RX_ADDR_NBIT-1:0]  s_rx_addr; // rx address output, as server
   output                     s_rx_done; // rx done signal
   input                      c_tx_en;   // tx enable input, as client
   output                     c_tx_rd;   // tx read output
   output [TX_ADDR_NBIT-1:0]  c_tx_addr; // tx address output, as client
   input  [7:0]               c_tx_data; // tx data input, as client
   output                     c_tx_error;// tx process error, as client
   output                     c_tx_done; // tx process done, as client
   output [9:0]               w_addr;    // address output to w5300 
   output [7:0]               w_wdata;   // write data output to w5300
   output                     w_wr;      // write output to w5300
   output                     w_wr_en;   // write enable output 
   output                     w_rd;      // read output to w5300
   input  [7:0]               w_rdata;   // read data input from w5300
   output                     w_cs;      // chipselect output to w5300

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
   
   ////////////////// Data Communication FSM
   
   ////////////////// TCP
   // SERVER: CLOSED --> OPEN --> LISTEN --> ESTABLISHED --> SEND --> CLOSED
   //        |                          |                |          |
   //        <--       timeout       <--                 --> RECV -->
   //
   ////////////////// UDP
   // SERVER: CLOSED --> OPEN -->  UDP  --> SEND --> CLOSED
   //        |                         |           |
   //        <--       timeout     <--  --> RECV -->
   //
   //////////////////

   wire                    fsm_en = (clk_tick==P_CLK_PD-1);
   wire                    fsm_rd = (clk_tick==P_SIG_VD-1);
   reg  [2:0]              fsm_st;
   reg  [15:0]             fsm_cnt;
   reg  [15:0]             recv_size;
   reg  [15:0]             send_size;
   reg                     s_rx_dv;  
   reg  [7:0]              s_rx_data;
   reg  [RX_ADDR_NBIT-1:0] s_rx_addr;
   reg                     s_rx_done;
   reg                     c_tx_rd;
   reg  [TX_ADDR_NBIT-1:0] c_tx_addr;
   reg                     c_tx_error;
   reg                     c_tx_done;
   reg  [7:0]              send_data;
   reg                     isfirstsend;
   reg  [31:0]             watchdog;
   reg  [7:0]              fsm_rdata;
   
   always@(posedge clk) begin
      if(reset) begin
         fsm_st <= `ST_SOCKET_IDLE;
         fsm_cnt <= 0;
         s_rx_dv <= 1'b0;  
         s_rx_data <= 0;
         s_rx_addr <= 0;
         s_rx_done <= 1'b0;
         c_tx_addr <= 0;
         c_tx_error<= 1'b0;
         c_tx_done <= 1'b0;
         recv_size <= 16'hFFFF;
         send_size <= 16'hFFFF;
         isfirstsend <= 1'b1;
         watchdog  <= 0;
         c_tx_rd   <= 1'b0;
         fsm_rdata <= 0;
      end
      else begin
         s_rx_dv    <= 1'b0;
         c_tx_done  <= 1'b0;
         c_tx_error <= 1'b0;
         s_rx_done  <= 1'b0;
         c_tx_rd    <= 1'b0;
         fsm_rdata  <= fsm_rd ? w_rdata : fsm_rdata;
         if(fsm_en) begin
            case(fsm_st)
               `ST_SOCKET_IDLE: begin // SSR: TCP(closed) & UDP(closed)
                  fsm_cnt     <= 0;
                  s_rx_addr   <= {RX_ADDR_NBIT{1'b1}};
                  c_tx_addr   <= 0;
                  recv_size   <= 0;
                  send_size   <= 0;
                  isfirstsend <= 1'b1;
                  watchdog    <= 0;
                  if(start) // socket open detected
                     fsm_st   <= `ST_SOCKET_OPEN;
               end
               `ST_SOCKET_OPEN: begin // SSR: TCP(init) & UDP(udp)
                  /*              Open Socket                 */
                  // - CR(Command Reg) OPEN COMMAND   WR    0 (TCP&UDP)
                  // - SSR(Status Reg)                RD    1 (TCP&UDP)
                  // - IR(Interrupt Reg)              RD    2 (UDP)
                  /*                                          */
                  fsm_cnt <= fsm_cnt + 1'b1;
                  s_rx_addr <= {RX_ADDR_NBIT{1'b1}};
                  c_tx_addr <= 0;
                  if(P_PROT==`PROT_TCP) begin
                     if(fsm_cnt==1) begin
                        fsm_cnt <= 0;
                        if(fsm_rdata==`SOCK_SSR_INIT)
                           fsm_st <= `ST_SOCKET_LIS_CON;
                     end
                  end
                  else if(P_PROT==`PROT_UDP) begin
                     watchdog <= watchdog + 1'b1;
                     if(watchdog==P_PROTIME) begin // wait for RECV
                        watchdog <= 0;
                        fsm_cnt  <= 0;
                        fsm_st   <= `ST_SOCKET_CLOSE;
                     end
                     else if(fsm_cnt==1) begin
                        if(fsm_rdata==`SOCK_SSR_UDP)
                           fsm_cnt <= 2;
                        else
                           fsm_cnt <= 0;
                     end
                     else if(fsm_cnt==2) begin
                        fsm_cnt  <= 0;
                        if(c_tx_en)  // SERVER: send request
                           fsm_st <= `ST_SOCKET_SEND;
                        else if((fsm_rdata&`SOCK_IR_RECV)==`SOCK_IR_RECV) // SERVER: receive detected
                           fsm_st <= `ST_SOCKET_RECV;
                        else
                           fsm_cnt <= fsm_cnt;
                     end
                  end
               end
               `ST_SOCKET_LIS_CON: begin // SSR: TCP(connect)
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt!=0) begin
                     fsm_cnt <= fsm_cnt - 1'b1;
                     if(fsm_rdata==`SOCK_IR_TIMEOUT) begin // SERVER: connect timeout
                        fsm_cnt <= 0;
                        fsm_st <= `ST_SOCKET_CLOSE;
                     end
                     else if((fsm_rdata&`SOCK_IR_CON)==`SOCK_IR_CON) begin // server: connect detected
                        fsm_cnt <= 0;
                        fsm_st <= `ST_SOCKET_ESTABLISHED;
                     end
                  end
               end
               `ST_SOCKET_ESTABLISHED: begin // SSR: TCP(established)
                  fsm_cnt <= 0;
                  if((fsm_rdata&`SOCK_IR_DISCON)==`SOCK_IR_DISCON) // SERVER & CLIENT: Received FIN?
                     fsm_st <= `ST_SOCKET_DISCON;
                  else if((fsm_rdata&`SOCK_IR_TIMEOUT)==`SOCK_IR_TIMEOUT) // SERVER & CLIENT: Timeout
                     fsm_st <= `ST_SOCKET_CLOSE;
                  else if((fsm_rdata&`SOCK_IR_RECV)==`SOCK_IR_RECV) // SERVER: receive detected
                     fsm_st <= `ST_SOCKET_RECV;
                  else if(c_tx_en)  // SERVER: send request
                     fsm_st <= `ST_SOCKET_SEND;
               end
               `ST_SOCKET_RECV: begin // SSR: TCP(recv) & UDP(recv)
                  if(P_PROT==`PROT_TCP) begin
                     if(P_MR_ALIGN) begin // align
                        /*                  TCP Receiving Process                      */
                        // - RX_RSR(RX Received Size Reg)   RD 0 ~ size*2-1(4n+0 , 4n+1)
                        // - RX_FIFOR(RX FIFO Reg)          RD 0 ~ size*2-1(4n+2 , 4n+3)
                        // - IR(Interrupt Reg) CLEAR RECV   WR size*2
                        // - IR(Interrupt Reg) CHECK RECV   RD size*2+1
                        // - CR(Command Reg) RECV COMMAND   WR size*2+2
                        /*                                                             */
                        fsm_cnt <= fsm_cnt + 1'b1;
                        if(fsm_cnt==0)
                           recv_size[15:8] <= fsm_rdata;
                        else if(fsm_cnt==1) begin
                           recv_size[7:0]  <= fsm_rdata;
                           if(recv_size[15:8]==0 && fsm_rdata==0) // when RX_FIFO_SIZE=0, return to read size again
                              fsm_cnt <= 0;
                        end
                        else if(fsm_cnt==recv_size*2+1) begin
                           if((fsm_rdata&`SOCK_IR_RECV)==`SOCK_IR_RECV)
                              fsm_cnt <= fsm_cnt - 1'b1; // return to CLEAR RECV again
                        end
                        else if(fsm_cnt==recv_size*2+2) begin
                           fsm_cnt <= 0;
                           fsm_st <= `ST_SOCKET_ESTABLISHED;
                           s_rx_addr <= {RX_ADDR_NBIT{1'b1}};
                           s_rx_done <= 1'b1;
                        end
                        
                        if(fsm_cnt==0||fsm_cnt==1||(fsm_cnt<recv_size*2&&fsm_cnt[1])) begin
                           s_rx_dv <= 1'b1;
                           if(fsm_cnt==0||fsm_cnt==1)
                              s_rx_addr <= fsm_cnt;
                           else
                              s_rx_addr <= s_rx_addr + 1'b1;
                        end
                     end
                     else begin
                        /*                  TCP Receiving Process                      */
                        // - IR(Interrupt Reg) CLEAR RECV   WR 0
                        // - RX_FIFOR(RX FIFO Reg)          RD 1 ~ size+2
                        // - CR(Command Reg) RECV COMMAND   WR size+3
                        /*                                                             */
                        fsm_cnt <= fsm_cnt + 1'b1;
                        if(fsm_cnt==1)
                           recv_size[15:8] <= fsm_rdata;
                        else if(fsm_cnt==2) begin
                           recv_size[7:0]  <= fsm_rdata;
                        end
                        else if(fsm_cnt==recv_size+3) begin
                           fsm_cnt <= 0;
                           fsm_st <= `ST_SOCKET_ESTABLISHED;
                           s_rx_addr <= {RX_ADDR_NBIT{1'b1}};
                           s_rx_done <= 1'b1;
                        end
                        if(fsm_cnt>=1 && fsm_cnt<=recv_size+2) begin
                           s_rx_dv <= 1'b1;
                           s_rx_addr <= s_rx_addr + 1'b1;
                        end
                     end
                  end
                  else if(P_PROT==`PROT_UDP) begin
                     /*                  UDP Receiving Process                      */
                     // - IR(Interrupt Reg) CLEAR RECV   WR 0
                     // - RX_FIFOR(RX FIFO Reg)          RD 1 ~ size+8
                     // - CR(Command Reg) RECV COMMAND   WR size+9
                     /*                                                             */
                     
                     // PACKET: DEST_IP[0:3] DEST_PORT[4:5] SIZE[6:7] DATA[8:SIZE+7]
                     
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==7)
                        recv_size[15:8] <= fsm_rdata;
                     else if(fsm_cnt==8) begin
                        recv_size[7:0]  <= fsm_rdata;
                     end
                     else if(fsm_cnt==recv_size+9) begin
                        fsm_cnt   <= 16'd1;
                        fsm_st    <= `ST_SOCKET_OPEN;
                        s_rx_addr <= {RX_ADDR_NBIT{1'b1}};
                        s_rx_done <= 1'b1;
                     end
                     if(fsm_cnt>=7 && fsm_cnt<=recv_size+8) begin
                        s_rx_dv <= 1'b1;
                        s_rx_addr <= s_rx_addr + 1'b1;
                     end
                  end
                  s_rx_data <= fsm_rdata;
               end
               `ST_SOCKET_SEND: begin // SSR: TCP(send) & UDP(send_mac)
                  /*                         Sending Process                       */
                  // - TX_FSR(TX Free Size Reg)                  RD  0 ~ 2
                  // - TX_FIFOR(TX FIFO Reg)                     WR  3 ~ size+2
                  // - IR(Interrupt Reg)          CHECK SENDOK   RD  size+3
                  // - IR(Interrupt Reg)          CLEAR SENDOK   WR  size+4
                  // - TX_WRSR(TX Write Size Reg)                WR  size+5 ~ size+7
                  // - CR(Command Reg)            SEND Command   WR  size+8
                  /*                                                               */
                  
                  // TX Cache Interface
                  c_tx_addr <= c_tx_addr + 1'b1;
                  c_tx_rd   <= 1'b1;
                  if(fsm_cnt>3 && fsm_cnt>send_size+1) begin
                     c_tx_rd   <= 1'b0;
                     c_tx_addr <= 0;
                  end
                  
                  fsm_cnt <= fsm_cnt + 1'b1;
                  // send size
                  send_data <= c_tx_data;
                  if(fsm_cnt==0+1)
                     send_size <= {send_data,8'h00};
                  else if(fsm_cnt==1+1)
                     send_size <= send_size+(send_data[0] ? send_data+1'b1 : send_data);
                     
                  
                  // check socket status & send command
                  watchdog <= 0;
                  if(send_size!=0) begin
                     if(fsm_cnt==send_size+3) begin
                        fsm_cnt <= fsm_cnt;
                        watchdog <= watchdog + 1'b1;
                        if((fsm_rdata&`SOCK_IR_DISCON)==`SOCK_IR_DISCON || watchdog==P_TIMEOUT) begin // SERVER & CLIENT: disconnect ?
                           fsm_cnt <= 0;
                           fsm_st <= `ST_SOCKET_CLOSE;
                        end
                        else if(~P_SENDOK_CHK || isfirstsend || (fsm_rdata&`SOCK_IR_SENDOK)==`SOCK_IR_SENDOK) // SERVER & CLIENT: check previous send process
                           fsm_cnt <= fsm_cnt + 1'b1;
                     end
                     else if(fsm_cnt==send_size+8) begin
                        fsm_cnt <= P_PROT==`PROT_TCP ? 16'd0 : 16'd1;
                        fsm_st  <= P_PROT==`PROT_TCP ? `ST_SOCKET_ESTABLISHED : `ST_SOCKET_OPEN;
                        c_tx_done <= 1'b1;
                        c_tx_addr <= 0;
                        isfirstsend <= 1'b0;
                     end
                  end
               end
               `ST_SOCKET_DISCON: begin // SSR: TCP(discon)
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt==1) begin
                     fsm_cnt <= fsm_cnt - 1'b1;
                     if((fsm_rdata&`SOCK_IR_DISCON)==`SOCK_IR_DISCON) begin // SERVER: disconnect
                        fsm_cnt <= 0;
                        fsm_st <= `ST_SOCKET_CLOSE;
                     end
                  end
               end
               `ST_SOCKET_CLOSE: begin // SSR: TCP(close) & UDP(close)
                  fsm_cnt <= fsm_cnt + 1'b1;
                  if(fsm_cnt==1) begin
                     fsm_cnt <= 0;
                     fsm_st <= `ST_SOCKET_IDLE;
                  end
               end
               default: begin
                  fsm_st <= `ST_SOCKET_IDLE;
               end
            endcase
         end
      end
   end
   
   reg  [9:0]  w_addr; 
   reg  [7:0]  w_wdata;
   reg         w_wr;   
   reg         w_wr_en; 
   reg         w_rd;   
   reg         w_cs;   
   always@* begin
      case(fsm_st)
         `ST_SOCKET_IDLE: begin // SSR: TCP(closed) & UDP(closed)
            w_addr      <= `RGAD_S0_SSR;
            w_wdata     <= 0;
            w_wr        <= 1'b0;
            w_wr_en     <= 1'b0;
            w_rd        <= (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_OPEN: begin // SSR: TCP(init) & UDP(udp)
            /*              Open Socket                 */
            // - CR(Command Reg) OPEN COMMAND   WR    0 (TCP&UDP)
            // - SSR(Status Reg)                RD    1 (TCP&UDP)
            // - IR(Interrupt Reg)              RD    2 (UDP)
            /*                                          */
            w_addr      <= P_PROT==`PROT_TCP ? (fsm_cnt==0 ? `RGAD_S0_CR : `RGAD_S0_SSR) : (fsm_cnt==0 ? `RGAD_S1_CR : (fsm_cnt==1 ? `RGAD_S1_SSR : `RGAD_S1_IR_1));
            w_wdata     <= `SOCK_CR_OPEN;
            w_wr        <= fsm_cnt==0 ? (clk_tick<P_SIG_VD) : 1'b0;
            w_wr_en     <= fsm_cnt==0 ? 1'b1 : 1'b0;
            w_rd        <= fsm_cnt==0 ? 1'b0 : (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_LIS_CON: begin // SSR: TCP(connect)
            w_addr      <= fsm_cnt==0 ? `RGAD_S0_CR : `RGAD_S0_IR_1; 
            w_wdata     <= `SOCK_CR_CONNECT;
            w_wr        <= fsm_cnt==0 ? (clk_tick<P_SIG_VD) : 1'b0;
            w_wr_en     <= fsm_cnt[0]==0 ? 1'b1 : 1'b0;
            w_rd        <= fsm_cnt==0 ? 1'b0 : (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_ESTABLISHED: begin // SSR: TCP(established)
            w_addr      <= `RGAD_S0_IR_1; 
            w_wdata     <= 0;
            w_wr        <= 1'b0;
            w_wr_en     <= 1'b0;
            w_rd        <= (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_RECV: begin // SSR: TCP(recv) & UDP(recv)
            if(P_PROT==`PROT_TCP) begin
               if(P_MR_ALIGN) begin // align
                  /*               TCP Receiving Process                         */
                  // - RX_RSR(RX Received Size Reg)   RD 0 ~ size*2-1(4n+0 , 4n+1)
                  // - RX_FIFOR(RX FIFO Reg)          RD 0 ~ size*2-1(4n+2 , 4n+3)
                  // - IR(Interrupt Reg) CLEAR RECV   WR size*2
                  // - IR(Interrupt Reg) CHECK RECV   RD size*2+1
                  // - CR(Command Reg) RECV COMMAND   WR size*2+2
                  /*                                                             */
                  w_addr      <=((fsm_cnt==recv_size*2||fsm_cnt==recv_size*2+1)&&recv_size!=0)   ? `RGAD_S0_IR_1 :
                                ((fsm_cnt==recv_size*2+2&&recv_size!=0) ? `RGAD_S0_CR   :
                                ((fsm_cnt[1:0]==2 ? `RGAD_S0_RX_FIFOR_0 : 
                                 (fsm_cnt[1:0]==3 ? `RGAD_S0_RX_FIFOR_1 :
                                 (fsm_cnt[1:0]==0 ? `RGAD_S0_RX_RSR_2   : `RGAD_S0_RX_RSR_3))))); 
                  w_wdata     <= (fsm_cnt==recv_size*2&&recv_size!=0) ? `SOCK_IR_RECV : `SOCK_CR_RECV;
                  w_wr        <= ((fsm_cnt==recv_size*2||fsm_cnt==recv_size*2+2)&&recv_size!=0) ? (clk_tick<P_SIG_VD) : 1'b0;
                  w_wr_en     <= ((fsm_cnt==recv_size*2||fsm_cnt==recv_size*2+2)&&recv_size!=0) ? 1'b1 : 1'b0;
                  w_rd        <= ((fsm_cnt==recv_size*2||fsm_cnt==recv_size*2+2)&&recv_size!=0) ? 1'b0: (clk_tick<P_SIG_VD);
                  w_cs        <= (clk_tick<P_SIG_VD);
                  
               end
               else begin
                  /*               TCP Receiving Process                         */
                  // - IR(Interrupt Reg) CLEAR RECV   WR 0
                  // - RX_FIFOR(RX FIFO Reg)          RD 1 ~ size+2
                  // - CR(Command Reg) RECV COMMAND   WR size+3
                  /*                                                             */
                  w_addr      <= (fsm_cnt==0) ? `RGAD_S0_IR_1 :
                                ((fsm_cnt==recv_size+3&&recv_size!=0) ? `RGAD_S0_CR   :
                                 (fsm_cnt[0]==1 ? `RGAD_S0_RX_FIFOR_0 : `RGAD_S0_RX_FIFOR_1)); 
                  w_wdata     <= (fsm_cnt==0) ? `SOCK_IR_RECV : `SOCK_CR_RECV;
                  w_wr        <= ((fsm_cnt==0)||(fsm_cnt==recv_size+3&&recv_size!=0)) ? (clk_tick<P_SIG_VD) : 1'b0;
                  w_wr_en     <= ((fsm_cnt==0)||(fsm_cnt==recv_size+3&&recv_size!=0)) ? 1'b1 : 1'b0;
                  w_rd        <= ((fsm_cnt==0)||(fsm_cnt==recv_size+3&&recv_size!=0)) ? 1'b0 : (clk_tick<P_SIG_VD);
                  w_cs        <= (clk_tick<P_SIG_VD);
               end
            end
            else if(P_PROT==`PROT_UDP) begin
               /*                  UDP Receiving Process                      */
               // - IR(Interrupt Reg) CLEAR RECV   WR 0
               // - RX_FIFOR(RX FIFO Reg)          RD 1 ~ size+8
               // - CR(Command Reg) RECV COMMAND   WR size+9
               /*                                                             */
               
               // PACKET: DEST_IP[0:3] DEST_PORT[4:5] SIZE[6:7] DATA[8:SIZE+7]
               
               w_addr      <= (fsm_cnt==0) ? `RGAD_S1_IR_1 :
                             ((fsm_cnt==recv_size+9&&recv_size!=0) ? `RGAD_S1_CR   :
                              (fsm_cnt[0]==1 ? `RGAD_S1_RX_FIFOR_0 : `RGAD_S1_RX_FIFOR_1)); 
               w_wdata     <= (fsm_cnt==0) ? `SOCK_IR_RECV : `SOCK_CR_RECV;
               w_wr        <= ((fsm_cnt==0)||(fsm_cnt==recv_size+9&&recv_size!=0)) ? (clk_tick<P_SIG_VD) : 1'b0;
               w_wr_en     <= ((fsm_cnt==0)||(fsm_cnt==recv_size+9&&recv_size!=0)) ? 1'b1 : 1'b0;
               w_rd        <= ((fsm_cnt==0)||(fsm_cnt==recv_size+9&&recv_size!=0)) ? 1'b0 : (clk_tick<P_SIG_VD);
               w_cs        <= (clk_tick<P_SIG_VD);
            end
				else begin
					w_addr      <= 0; 
					w_wdata     <= 0;
					w_wr        <= 1'b0;
					w_wr_en     <= 1'b0;
					w_rd        <= 1'b0;
					w_cs        <= 1'b0;
				end
         end
         `ST_SOCKET_SEND: begin // SSR: TCP(send) & UDP(send)
            /*               TCP & UDP Sending Process                       */
            // - TX_FSR(TX Free Size Reg)                  RD  0 ~ 2
            // - TX_FIFOR(TX FIFO Reg)                     WR  3 ~ size+2
            // - IR(Interrupt Reg)          CHECK SENDOK   RD  size+3
            // - IR(Interrupt Reg)          CLEAR SENDOK   WR  size+4
            // - TX_WRSR(TX Write Size Reg)                WR  size+5 ~ size+7
            // - CR(Command Reg)            SEND Command   WR  size+8
            /*                                                               */
            if(P_PROT==`PROT_TCP) begin
               w_addr   <= (fsm_cnt==0) ? `RGAD_S0_TX_FSR_1 : 
                          ((fsm_cnt==1) ? `RGAD_S0_TX_FSR_2 : 
                          ((fsm_cnt==2) ? `RGAD_S0_TX_FSR_3 : 
                          ((fsm_cnt==send_size+3&&send_size!=0) ? `RGAD_S0_IR_1 : // read SENDOK from IR
                          ((fsm_cnt==send_size+4&&send_size!=0) ? `RGAD_S0_IR_1 : // write SENDOK to IR
                          ((fsm_cnt==send_size+5&&send_size!=0) ? `RGAD_S0_TX_WRSR_1 : 
                          ((fsm_cnt==send_size+6&&send_size!=0) ? `RGAD_S0_TX_WRSR_2 : 
                          ((fsm_cnt==send_size+7&&send_size!=0) ? `RGAD_S0_TX_WRSR_3 : 
                          ((fsm_cnt==send_size+8&&send_size!=0) ? `RGAD_S0_CR   : // write SEND to CR 
                           (fsm_cnt[0] ? `RGAD_S0_TX_FIFOR_0 :
                                         `RGAD_S0_TX_FIFOR_1))))))))); 
               w_wdata  <= (fsm_cnt==send_size+4&&send_size!=0) ? `SOCK_IR_SENDOK :
                          ((fsm_cnt==send_size+5&&send_size!=0) ? 8'h00 :
                          ((fsm_cnt==send_size+6&&send_size!=0) ? send_size[15:8] :
                          ((fsm_cnt==send_size+7&&send_size!=0) ? send_size[7:0]  :
                          ((fsm_cnt==send_size+8&&send_size!=0) ? `SOCK_CR_SEND : send_data))));
            end
            else if(P_PROT==`PROT_UDP) begin
               w_addr   <= (fsm_cnt==0) ? `RGAD_S1_TX_FSR_1 : 
                          ((fsm_cnt==1) ? `RGAD_S1_TX_FSR_2 : 
                          ((fsm_cnt==2) ? `RGAD_S1_TX_FSR_3 : 
                          ((fsm_cnt==send_size+3&&send_size!=0) ? `RGAD_S1_IR_1 : // read SENDOK from IR
                          ((fsm_cnt==send_size+4&&send_size!=0) ? `RGAD_S1_IR_1 : // write SENDOK to IR
                          ((fsm_cnt==send_size+5&&send_size!=0) ? `RGAD_S1_TX_WRSR_1 : 
                          ((fsm_cnt==send_size+6&&send_size!=0) ? `RGAD_S1_TX_WRSR_2 : 
                          ((fsm_cnt==send_size+7&&send_size!=0) ? `RGAD_S1_TX_WRSR_3 : 
                          ((fsm_cnt==send_size+8&&send_size!=0) ? `RGAD_S1_CR   : // write SEND to CR 
                           (fsm_cnt[0] ? `RGAD_S1_TX_FIFOR_0 :
                                         `RGAD_S1_TX_FIFOR_1))))))))); 
               w_wdata  <= (fsm_cnt==send_size+4&&send_size!=0) ? `SOCK_IR_SENDOK :
                          ((fsm_cnt==send_size+5&&send_size!=0) ? 8'h00 :
                          ((fsm_cnt==send_size+6&&send_size!=0) ? send_size[15:8] :
                          ((fsm_cnt==send_size+7&&send_size!=0) ? send_size[7:0]  :
                          ((fsm_cnt==send_size+8&&send_size!=0) ? `SOCK_CR_SENDMAC : send_data))));
            end
				else begin
					w_addr   <= 0; 
               w_wdata  <= 0;
            end
            w_wr        <= (fsm_cnt==0 || fsm_cnt==1 || fsm_cnt==2 || 
                           (fsm_cnt==send_size+3&&send_size!=0)) ? 1'b0 : (clk_tick<P_SIG_VD);
            w_wr_en     <= (fsm_cnt==0 || fsm_cnt==1 || fsm_cnt==2 || 
                           (fsm_cnt==send_size+3&&send_size!=0)) ? 1'b0 : 1'b1;
            w_rd        <= (fsm_cnt==0 || fsm_cnt==1 || fsm_cnt==2 || 
                           (fsm_cnt==send_size+3&&send_size!=0)) ? (clk_tick<P_SIG_VD) : 1'b0;
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_DISCON: begin // SSR: TCP(discon)
            if(P_PROT==`PROT_TCP)
               w_addr   <= fsm_cnt==0 ? `RGAD_S0_CR : `RGAD_S0_IR_1;
            else if(P_PROT==`PROT_UDP)
               w_addr   <= fsm_cnt==0 ? `RGAD_S1_CR : `RGAD_S1_IR_1;
				else
					w_addr   <= 0; 
					
            w_wdata     <= `SOCK_CR_DISCON;
            w_wr        <= fsm_cnt==0 ? (clk_tick<P_SIG_VD) : 1'b0;
            w_wr_en     <= fsm_cnt==0 ? 1'b1 : 1'b0;
            w_rd        <= fsm_cnt==0 ? 1'b0 : (clk_tick<P_SIG_VD);
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         `ST_SOCKET_CLOSE: begin // SSR: TCP(close) & UDP(close)
            if(P_PROT==`PROT_TCP)
               w_addr   <= fsm_cnt==0 ? `RGAD_S0_IR_1 : `RGAD_S0_CR;
            else if(P_PROT==`PROT_UDP)
               w_addr   <= fsm_cnt==0 ? `RGAD_S1_IR_1 : `RGAD_S1_CR;
				else
					w_addr   <= 0; 
					
            w_wdata     <= fsm_cnt==0 ? (`SOCK_IR_SENDOK|`SOCK_IR_TIMEOUT|`SOCK_IR_RECV|`SOCK_IR_DISCON|`SOCK_IR_CON) : 
                                        `SOCK_CR_CLOSE;
            w_wr        <= (clk_tick<P_SIG_VD);
            w_wr_en     <= 1'b1;
            w_rd        <= 1'b0;
            w_cs        <= (clk_tick<P_SIG_VD);
         end
         default: begin
            w_addr      <= 0; 
            w_wdata     <= 0;
            w_wr        <= 1'b0;
            w_wr_en     <= 1'b0;
            w_rd        <= 1'b0;
            w_cs        <= 1'b0;
         end
      endcase
   end
   
endmodule