/////////////////////////// INCLUDE /////////////////////////////

////////////////////////////////////////////////////////////////
//
//  Module  : ds2745_controller.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2017/8/22 9:22:23
//
////////////////////////////////////////////////////////////////
// 
//  Description: DS2745 Low-Cost I2C Battery Monitor
//  - Write one register;
//  - Read some register, number is set by P_DS2745_RDATA_NUM
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////

`define I2C_SPD_400K  (P_CLK_FREQ/400000)
`define I2C_SPD_200K  (P_CLK_FREQ/200000)
`define I2C_SPD_100K  (P_CLK_FREQ/100000)

`define ST_IDLE  2'b00
`define ST_READ  2'b01
`define ST_WRITE 2'b10
`define ST_DONE  2'b11

/////////////////////////// MODULE //////////////////////////////

module ds2745_controller
(
   clk,
   arst_n,
   start,
   ready,
   raddr,
   rdata,
   SCL,
   SDA
);

   ///////////////// PARAMETER ////////////////
   
   parameter P_CLK_FREQ          = 50_000000;   // main clock frequency @ Hz
   parameter P_DS2745_SADDR      = 7'b100_1000; // slave address
   parameter P_DS2745_WADDR      = 8'h01;       // memory address for writing
   parameter P_DS2745_WDATA      = 8'b1110_0000;// data for writing
   parameter P_DS2745_RADDR_BASE = 8'h00;       // base memory address for reading
   parameter P_DS2745_RDATA_NUM  = 8'd18;       // number of registers for reading, address from P_DS2745_RADDR_BASE to P_DS2745_RADDR_BASE+P_DS2745_RDATA_NUM-1
   
   ////////////////// PORT ////////////////////

   input          clk;    // main clock
   input          arst_n; // asynchronous reset, active low
   input          start;  // start signal
   output         ready;  // cache data ready signal 
   input  [7:0]   raddr;  // read address of register data cache 
   output [7:0]   rdata;  // register data, one cycle delay
   output         SCL;    // I2C serial clock
   inout          SDA;    // I2C serial data
   
   ////////////////// ARCH ////////////////////
   
   ////////////////// DS2745 Read/Write Control
   
   reg        i2c_start;
   reg  [6:0] i2c_saddr;
   reg        i2c_rw;   
   reg  [7:0] i2c_maddr;
   reg  [7:0] i2c_wdata;
   reg  [7:0] i2c_num;  
   wire [7:0] i2c_rdata;  // read data byte
   wire       i2c_rdv;    // read data valid
   wire       i2c_busy;   // busy status
   wire       i2c_done;   // done
   reg  [7:0] cache_waddr;
   reg        ready;
   
   reg  [1:0] fsm_st;
   
   always@(posedge clk or negedge arst_n) begin
      if(~arst_n) begin
         i2c_start <= 1'b0;
         i2c_rw    <= 1'b0;
         i2c_saddr <= 0;
         i2c_maddr <= 0;
         i2c_wdata <= 0;
         i2c_num   <= 0;
         ready     <= 1'b0;
         fsm_st    <= `ST_IDLE;
      end
      else begin
         case(fsm_st)
            `ST_IDLE: begin
               i2c_start <= 1'b0;
               i2c_rw    <= 1'b0;
               i2c_saddr <= 0;
               i2c_maddr <= 0;
               i2c_wdata <= 0;
               i2c_num   <= 0;
               if(start) begin
                  fsm_st <= `ST_WRITE;
                  ready  <= 1'b0;
               end
               cache_waddr <= 0;
            end
            `ST_WRITE: begin
               i2c_start <= 1'b1;
               i2c_rw    <= 1'b0;
               i2c_saddr <= P_DS2745_SADDR;
               i2c_maddr <= P_DS2745_WADDR;
               i2c_wdata <= P_DS2745_WDATA;
               i2c_num   <= 0;
               if(i2c_busy)
                  i2c_start <= 1'b0;
               if(i2c_done)
                  fsm_st <= `ST_READ;
            end
            `ST_READ: begin
               i2c_start <= 1'b1;
               i2c_rw    <= 1'b1;
               i2c_saddr <= P_DS2745_SADDR;
               i2c_maddr <= P_DS2745_RADDR_BASE;
               i2c_wdata <= 0;
               i2c_num   <= P_DS2745_RDATA_NUM;
               if(i2c_busy)
                  i2c_start <= 1'b0;
               if(i2c_done)
                  fsm_st <= `ST_DONE;
               if(i2c_rdv)
                  cache_waddr <= cache_waddr + 1'b1;
            end
            `ST_DONE: begin
               ready <= 1'b1;
               fsm_st <= `ST_IDLE;
            end
            default: begin
               fsm_st <= `ST_IDLE;
            end
         endcase
      end
   end
   
   ////////////////// I2C Master
   
   i2c_master #(`I2C_SPD_400K)
   ds2745_i2c(
      .clk   (clk      ),
      .arst_n(arst_n   ),
      .start (i2c_start),
      .saddr (i2c_saddr),
      .rw    (i2c_rw   ),
		.maddr (i2c_maddr),
      .wdata (i2c_wdata),
      .num   (i2c_num  ),
      .rdata (i2c_rdata),
      .rdv   (i2c_rdv  ),
      .busy  (i2c_busy ),
      .done  (i2c_done ),
      .scl   (SCL      ),
      .sda   (SDA      )
   );
   
   ////////////////// Data Cache
   
   reg   [7:0]    cache[0:2**8-1];
   wire           cache_wr    = i2c_rdv;
   wire  [7:0]    cache_wdata = i2c_rdata;
   reg   [7:0]    rdata;
   
   always@(posedge clk) begin
      if(cache_wr)
         cache[cache_waddr] <= cache_wdata;
      rdata <= cache[raddr];
   end

endmodule

////////////////////////////////////////////////////////////////
//
//  Module  : i2c_master.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2017/8/22
//
////////////////////////////////////////////////////////////////
// 
//  Description: I2C master controller
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////

`define I2C_IDLE  3'b000
`define ST_START  3'b001
`define ST_SADDR  3'b010
`define ST_MADDR  3'b011
`define ST_DATA   3'b100
`define ST_STOP   3'b101
`define I2C_DONE  3'b110

`define KEY_WRITE 1'b0
`define KEY_READ  1'b1

/////////////////////////// MODULE //////////////////////////////

module i2c_master
(
   clk,
   arst_n,
   start,
   saddr,
   rw,
   maddr,
   wdata,
   num,
   rdata,
   rdv,
   busy,
   done,
   scl,
   sda
);
   ///////////////// PARAMETER ////////////////
   
   parameter P_CLK_DIV = 50000000/400000;

   ////////////////// PORT ////////////////////
   
   input        clk;    // main clock
   input        arst_n; // asynchronous reset, active low
   input        start;  // start
   input  [6:0] saddr;  // salve address
   input        rw;     // read/wrtie bit: 0 - write, 1 - read
   input  [7:0] maddr;  // memory address
   input  [7:0] wdata;  // data byte
   input  [7:0] num;    // number of read data
   output [7:0] rdata;  // read data byte
   output       rdv;    // read data valid
   output       busy;   // busy status
   output       done;   // done
   output       scl;    // serial clock
   inout        sda;    // serial data
   
   ////////////////// ARCH ////////////////////

   ////////////////// clock generate
   
   reg [15:0]  div_cnt;
   always@(posedge clk or negedge arst_n) begin
      if(~arst_n) begin
         div_cnt <= 0;
      end
      else begin
         div_cnt <= div_cnt + 1'b1;
         if(div_cnt==P_CLK_DIV-1)
            div_cnt <= 0;
      end
   end
   
   wire sclk_en = (div_cnt>=P_CLK_DIV/2);
   
   ////////////////// sda In Acquisition
   
   wire sda_acq = (div_cnt==P_CLK_DIV/2);
   reg  sda_in;
   
   always@(posedge clk or negedge arst_n) begin
      if(~arst_n) begin
         sda_in <= 1'b0;
      end
      else begin
         if(sda_acq)
            sda_in <= sda;
      end
   end
   
   ////////////////// Transaction
   // WRITE: START -> SADDR(W) -> MADDR -> DATA -> STOP
   // READ : START -> SADDR(W) -> MADDR -> START(R) -> SADDR(R) -> DATA0 -> ... -> DATAN -> STOP

   wire         fsm_en = (div_cnt==P_CLK_DIV-1);
   reg  [2:0]   fsm_st;
   reg  [3:0]   trans_bitcnt;
   reg  [7:0]   trans_bytecnt;
   reg  [7:0]   trans_shiftdata;
   
   always@(posedge clk or negedge arst_n) begin
      if(~arst_n) begin
         fsm_st          <= `I2C_IDLE;
         trans_bitcnt    <= 0;
         trans_bytecnt   <= 0;
         trans_shiftdata <= 0;
      end
      else begin
         if(fsm_en) begin
            case(fsm_st)
               `I2C_IDLE: begin
                  trans_bitcnt    <= 0;
                  trans_bytecnt   <= 0;
                  trans_shiftdata <= 0;
                  if(start) begin
                     trans_bitcnt <= 4'd1; // 1bit start
                     fsm_st       <= `ST_START;
                  end
               end
               `ST_START: begin
                  trans_bitcnt <= trans_bitcnt - 1'b1;
                  if(trans_bitcnt==0) begin
                     trans_bitcnt    <= 4'd9-1'b1; // 7bit salve address + 1bit rw + 1bit ack
                     trans_shiftdata <= {saddr,trans_bytecnt ? `KEY_READ : `KEY_WRITE};
                     fsm_st          <= `ST_SADDR;
                  end
               end
               `ST_SADDR: begin
                  trans_bitcnt    <= trans_bitcnt - 1'b1;
                  trans_shiftdata <= {trans_shiftdata[6:0],1'b0};
                  if(trans_bitcnt==0) begin
                     trans_bitcnt    <= 4'd9-1'b1; // 8bit memory address + 1bit ack
                     trans_shiftdata <= maddr;
                     if(trans_bytecnt) begin
                        trans_bytecnt <= trans_bytecnt - 1'b1;
                        fsm_st        <= `ST_DATA;
                     end
                     else
                        fsm_st <= `ST_MADDR;
                  end
               end
               `ST_MADDR: begin
                  trans_bitcnt    <= trans_bitcnt - 1'b1;
                  trans_shiftdata <= {trans_shiftdata[6:0],1'b0};
                  if(trans_bitcnt==0) begin
                     trans_bitcnt    <= rw ? 4'd2      : 4'd9-1'b1; // 8bit data + 1bit ack
                     trans_shiftdata <= rw ? 8'h00     : wdata;
                     trans_bytecnt   <= rw ? num       : 1'b0;
                     fsm_st          <= rw ? `ST_START : `ST_DATA;
                  end
               end
               `ST_DATA: begin
                  trans_bitcnt    <= trans_bitcnt - 1'b1;
                  trans_shiftdata <= {trans_shiftdata[6:0],rw ? sda_in : 1'b0};
                  if(trans_bitcnt==0) begin
                     trans_bitcnt  <= 4'd9-1'b1; // 8bit data + 1bit ack / 8bit data + no ack(last byte)
                     trans_bytecnt <= trans_bytecnt - 1'b1;
                     if(trans_bytecnt==0) begin
                        trans_bitcnt  <= 4'd1; // 1bit stop
                        trans_bytecnt <= 0;
                        fsm_st        <= `ST_STOP;
                     end
                  end
               end
               `ST_STOP: begin
                  trans_bitcnt    <= trans_bitcnt - 1'b1;
                  trans_shiftdata <= {trans_shiftdata[6:0],rw ? sda_in : 1'b0};
                  if(trans_bitcnt==0) begin
                     trans_bitcnt <= 4'd0;
                     fsm_st       <= `I2C_DONE;
                  end
               end
               `I2C_DONE: begin
                  fsm_st       <= `I2C_IDLE;
               end
               default:
                  fsm_st <= `I2C_IDLE;
            endcase
         end
      end
   end
   
   reg        scl;
   reg        sdo;
   reg        sdo_en;
   reg        busy;
   reg        done;
   reg  [7:0] rdata;  // read data byte
   reg        rdv;    // read data valid
   always@* begin
      if(~arst_n) begin
         scl    <= 1'b1; 
         sdo    <= 1'b1;
         sdo_en <= 1'b1;
         busy   <= 1'b0;
         done   <= 1'b0;
         rdata  <= 0;
         rdv    <= 1'b0;
      end
      else begin
         case(fsm_st)
            `I2C_IDLE: begin
               scl    <= 1'b1; 
               sdo    <= 1'b1; 
               sdo_en <= 1'b1;
               busy   <= 1'b0;
               done   <= 1'b0;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
            `ST_START: begin
               scl    <=  trans_bitcnt==1;
               sdo    <= (trans_bitcnt==2) || ((trans_bitcnt==1)&&(div_cnt<P_CLK_DIV/2));
               sdo_en <= 1'b1;
               busy   <= 1'b1;
               done   <= 1'b0;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
            `ST_SADDR: begin
               scl    <= sclk_en;
               sdo    <= trans_shiftdata[7];
               sdo_en <= ~(trans_bitcnt==0);
               busy   <= 1'b1;
               done   <= 1'b0;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
            `ST_MADDR: begin
               scl    <= sclk_en;
               sdo    <= trans_shiftdata[7];
               sdo_en <= ~(trans_bitcnt==0);
               busy   <= 1'b1;
               done   <= 1'b0;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
            `ST_DATA: begin
               scl    <= sclk_en;
               sdo    <= rw ? ~(trans_bitcnt==0) : trans_shiftdata[7];
               sdo_en <= rw ? (trans_bytecnt>0)&&(trans_bitcnt==0) : ~(trans_bitcnt==0);
               busy   <= 1'b1;
               done   <= 1'b0;
               rdata  <= trans_shiftdata;
               rdv    <= rw&fsm_en&(trans_bitcnt==0)&(trans_bytecnt!=0);
            end
            `ST_STOP: begin
               scl    <= trans_bitcnt==0 ? 1'b1 : 1'b0;
               sdo    <= trans_bitcnt==0 ? (div_cnt>P_CLK_DIV/2) : 1'b0;
               sdo_en <= trans_bitcnt==0 ? 1'b1 : 1'b0;
               busy   <= 1'b1;
               done   <= 1'b0;
               rdata  <= trans_shiftdata;
               rdv    <= rw&fsm_en&(trans_bitcnt==1);
            end
            `I2C_DONE: begin
               scl    <= 1'b1; 
               sdo    <= 1'b1; 
               sdo_en <= 1'b1;
               busy   <= 1'b0;
               done   <= fsm_en;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
            default: begin
               scl    <= 1'b1; 
               sdo    <= 1'b1; 
               sdo_en <= 1'b1;
               busy   <= 1'b0;
               done   <= 1'b0;
               rdata  <= 0;
               rdv    <= 1'b0;
            end
         endcase
      end
   end
   
   assign sda = sdo_en ? sdo : 1'bZ;

endmodule