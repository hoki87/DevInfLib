////////////////////////////////////////////////////////////////
//
//  Module  : at21_ctrl
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2019/9/16 21:53:25
//
////////////////////////////////////////////////////////////////
// 
//  Description: AT21CS01 controller
//               - page write
//               - page read
//               - id read
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////
`define PAGE_SIZE     8
`define CMD_SIZE      14

`define ST_RESET      3'b000
`define ST_START      3'b001
`define ST_DEVADDRR   3'b010
`define ST_DEVADDRW   3'b011
`define ST_MEMADDR    3'b100
`define ST_DATAIN     3'b101
`define ST_DATAOUT    3'b110
`define ST_STOP       3'b111

//                      1         2            3           4           5            6           7           8           9           10          11          12         13         14
`define CMD_DEFAULT   {`ST_START,`ST_START,   `ST_START,  `ST_START,  `ST_START,   `ST_START,  `ST_START,  `ST_START,  `ST_START,  `ST_START,  `ST_START,  `ST_START, `ST_START, `ST_START}
`define CMD_RD_MFID   {`ST_START,`ST_DEVADDRR,`ST_DATAIN, `ST_DATAIN, `ST_DATAIN,  `ST_STOP,   `ST_START,  `ST_START,  `ST_START,  `ST_START,  `ST_START,  `ST_START, `ST_START, `ST_START}
`define CMD_RD_SERNUM {`ST_START,`ST_DEVADDRW,`ST_MEMADDR,`ST_START,  `ST_DEVADDRR,`ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN,`ST_DATAIN,`ST_STOP }
`define CMD_RD_PAGE   {`ST_START,`ST_DEVADDRW,`ST_MEMADDR,`ST_START,  `ST_DEVADDRR,`ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN, `ST_DATAIN,`ST_DATAIN,`ST_STOP }
`define CMD_WR_PAGE   {`ST_START,`ST_DEVADDRW,`ST_MEMADDR,`ST_DATAOUT,`ST_DATAOUT, `ST_DATAOUT,`ST_DATAOUT,`ST_DATAOUT,`ST_DATAOUT,`ST_DATAOUT,`ST_DATAOUT,`ST_STOP,  `ST_START, `ST_START}

`define WR            1'b0
`define RD            1'b1
`define ACK           1'b0
`define NACK          1'b1

`define OPC_EEPROM    4'b1010
`define OPC_SERNUM    4'b1011
`define OPC_ROMZONE   4'b0111
`define OPC_MFID      4'b1100
`define OPC_STDSPD    4'b1101
`define OPC_HISPD     4'b1110

`define T_HISPD_RESET 96  // 96-  us
`define T_HISPD_DSCHG 150 // 150- us
`define T_HISPD_RRT   8   // 8-   us
`define T_HISPD_DRR   2   // 1-2  us
`define T_HISPD_MSDR  4   // 2-6  us
`define T_HISPD_DACK  24  // 8-24 us
`define T_HISPD_HTSS  150 // 150- us
`define T_HISPD_RCV   2   // 2 us
`define T_HISPD_BIT   16  //  -25 us
`define T_HISPD_LOW0  8   // 6-16 us
`define T_HISPD_LOW1  2   // 1-2 us
`define T_HISPD_RD    2   // 1-2 us
`define T_HISPD_MRS   3
`define T_HISPD_HLD0  6   // 2-6 us

`define T_HISPD_NACK  `T_HISPD_LOW1
`define T_HISPD_ACK   `T_HISPD_LOW0

`define BIT_NUM       8
`define ACK_NUM       1

/////////////////////////// MODULE //////////////////////////////
module at21_ctrl
(
   clkin,
   reset,
   write,
   shift_bytes,
   datain,
   addr,
   read,
   read_sn,
   busy,
   data_valid,
   dataout,
   sdo,
   sdo_en,
   sdi
);

   ///////////////// PARAMETER ////////////////
   parameter CLOCK_FREQ = 20_000000;
   parameter DEVADDR    = 3'b000;
   parameter CLOCK_DIV  = CLOCK_FREQ/1000000;

   ////////////////// PORT ////////////////////
   input          clkin;       // clock input
   input          reset;       // reset input, active high
   
   input          write;       // write input
   input          shift_bytes; // shift bytes input
   input  [7:0]   datain;      // data input
   input  [6:0]   addr;        // address
   input          read;        // read input
   input          read_sn;     // read 64-bit serial number
   output         busy;        // busy output
   output         data_valid;  // data valid output
   output [7:0]   dataout;     // data output
   
   output         sdo;         // serial data output
   output         sdo_en;      // serial data enable
   input          sdi;         // serial data input

   ////////////////// ARCH ////////////////////
   
   ////////////////// Clock div
   
   reg  [9:0]  clkdiv_cnt;
   
   always@(posedge clkin) begin
      if(reset) begin
         clkdiv_cnt <= 0;
      end
      else begin
         clkdiv_cnt <= clkdiv_cnt + 1'b1;
         if(clkdiv_cnt==CLOCK_DIV-1)
            clkdiv_cnt <= 0;
      end
   end
      
   ////////////////// FSM
      
   wire                    fsm_en=(clkdiv_cnt==CLOCK_DIV-1);
   reg  [2:0]              fsm_st;
   reg  [`CMD_SIZE*3-1:0]  fsm_cmd;
   reg  [3:0]              fsm_cnt;
   reg  [7:0]              fsm_time;
   wire [2:0]              fsm_st_next = fsm_cmd[`CMD_SIZE*3-1:`CMD_SIZE*3-3];
   reg                     busy;
   
   always@(posedge clkin) begin
      if(reset) begin
         fsm_st <= `ST_RESET;
         fsm_cmd <= `CMD_DEFAULT;
         fsm_cnt <= 0;
         fsm_time <= 0;
         busy <= 1'b0;
      end
      else begin
         if(fsm_en) begin
            case(fsm_st)
               `ST_RESET: begin
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_RESET+`T_HISPD_RRT+`T_HISPD_DACK-1) begin
                     fsm_time <= 0;
                     fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                     fsm_st <= fsm_st_next;
                  end
                  if(fsm_time==`T_HISPD_RESET+`T_HISPD_RRT+`T_HISPD_MSDR)
                     busy <= sdi;
               end
               `ST_START: begin
                  if(fsm_st_next!=`ST_START) begin
                     fsm_time <= fsm_time + 1'b1;
                     if(fsm_time==`T_HISPD_HTSS-1) begin
                        fsm_time <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                     busy <= 1'b1;
                  end
                  else begin
                     fsm_time <= 0;
                     fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                     fsm_st <= fsm_st_next;
                     busy <= 1'b0;
                  end
               end
               `ST_DEVADDRW: begin // {4-bit opcode,3-bit slave address,read} + ACK by slave
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_BIT-1) begin
                     fsm_time <= 0;
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==`BIT_NUM+`ACK_NUM-1) begin
                        fsm_cnt <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                  end
               end
               `ST_DEVADDRR: begin // {4-bit opcode,3-bit slave address,write} + ACK by slave
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_BIT-1) begin
                     fsm_time <= 0;
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==`BIT_NUM+`ACK_NUM-1) begin
                        fsm_cnt <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                  end
               end
               `ST_MEMADDR: begin // {1-bit dc,7-bit memory address} + ACK by slave
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_BIT-1) begin
                     fsm_time <= 0;
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==`BIT_NUM+`ACK_NUM-1) begin
                        fsm_cnt <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                  end
               end
               `ST_DATAIN: begin // 8-bit data + ACK/NACK by master
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_BIT-1) begin
                     fsm_time <= 0;
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==`BIT_NUM+`ACK_NUM-1) begin
                        fsm_cnt <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                  end
               end 
               `ST_DATAOUT: begin // 8-bit data + ACK by slave
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_BIT-1) begin
                     fsm_time <= 0;
                     fsm_cnt <= fsm_cnt + 1'b1;
                     if(fsm_cnt==`BIT_NUM+`ACK_NUM-1) begin
                        fsm_cnt <= 0;
                        fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                        fsm_st <= fsm_st_next;
                     end
                  end
               end
               `ST_STOP: begin
                  fsm_time <= fsm_time + 1'b1;
                  if(fsm_time==`T_HISPD_RCV-1) begin
                     fsm_time <= 0;
                     fsm_cmd <= {fsm_cmd[`CMD_SIZE*3-4:0],`ST_START};
                     fsm_st <= fsm_st_next;
                  end
               end
            endcase
         end
         if(fsm_st==`ST_START) begin
            if(write)
               fsm_cmd <= `CMD_WR_PAGE;
            else if(read)
               fsm_cmd <= `CMD_RD_PAGE;
            else if(read_sn)
               fsm_cmd <= `CMD_RD_SERNUM;
         end
      end
   end

   reg  [7:0]               tx_devaddr;
   reg  [7:0]               tx_memaddr;
   reg  [`PAGE_SIZE*8-1:0]  tx_dataout;
   reg  [7:0]               shift_byte;
   reg                      data_valid;
   reg  [7:0]               dataout;

   always@(posedge clkin) begin
      if(reset) begin
         tx_devaddr <= 0;
         tx_memaddr <= 0;
         tx_dataout <= 0;
         shift_byte <= 0;
         data_valid <= 1'b0;
         dataout <= 0;
      end
      else begin
         if(shift_bytes)
            tx_dataout <= {tx_dataout[`PAGE_SIZE*8-9:0],datain};
         case(fsm_st)
            `ST_RESET: begin
               tx_dataout <= 0;
               shift_byte <= 0;
            end
            `ST_START: begin
               if(write | read) begin
                  tx_devaddr <= {`OPC_EEPROM,DEVADDR,1'b0};
                  tx_memaddr <= {1'b0,addr};
               end
               else if(read_sn) begin
                  tx_devaddr <= {`OPC_SERNUM,DEVADDR,1'b0};
                  tx_memaddr <= 0;
               end
//               else if(fsm_cmd==`CMD_RD_MFID) begin
//                  tx_devaddr <= {`OPC_MFID,DEVADDR,1'b0};
//                  tx_memaddr <= 0;
//               end
            end
            `ST_DEVADDRW: begin
               if(fsm_cnt==0&fsm_time==0)
                  shift_byte <= tx_devaddr|`WR;
               if(fsm_en&fsm_time==`T_HISPD_BIT-1)
                  shift_byte <= {shift_byte[6:0],1'b0};
            end
            `ST_DEVADDRR: begin
               if(fsm_cnt==0&fsm_time==0)
                  shift_byte <= tx_devaddr|`RD;
               if(fsm_en&fsm_time==`T_HISPD_BIT-1)
                  shift_byte <= {shift_byte[6:0],1'b0};
            end
            `ST_MEMADDR: begin
               if(fsm_cnt==0&fsm_time==0)
                  shift_byte <= tx_memaddr;
               if(fsm_en&fsm_time==`T_HISPD_BIT-1)
                  shift_byte <= {shift_byte[6:0],1'b0};
            end
            `ST_DATAIN: begin
               if(fsm_en&fsm_time==`T_HISPD_MRS-1)
                  shift_byte <= {shift_byte[6:0],sdi};
               data_valid <= 1'b0;
               if(fsm_en&fsm_time==`T_HISPD_BIT-1&fsm_cnt==`BIT_NUM-1) begin
                  data_valid <= 1'b1;
                  dataout <= shift_byte;
               end
            end 
            `ST_DATAOUT: begin
               if(fsm_en&fsm_cnt==0&fsm_time==0) begin
                  shift_byte <= tx_dataout[`PAGE_SIZE*8-1:`PAGE_SIZE*8-8];
                  tx_dataout <= {tx_dataout[`PAGE_SIZE*8-9:0],8'h00};
               end
               if(fsm_en&fsm_time==`T_HISPD_BIT-1)
                  shift_byte <= {shift_byte[6:0],1'b0};
            end
            `ST_STOP: begin
               shift_byte <= 0;
            end
         endcase
      end
   end
   
   reg   sdo;
   reg   sdo_en;
   wire  sdo_next = shift_byte[7];
   
   always@* begin
      if(reset) begin
         sdo <= 1'b0;
         sdo_en <= 1'b0;
      end
      else begin
         case(fsm_st)
            `ST_RESET: begin
               sdo <= 1'b0;   // drive SI/O always low while device reset/power-up and discovery response
               if(fsm_time<`T_HISPD_RESET)  // T_DSCHG: master drive SI/O low to reset or interrupt the device 
                  sdo_en <= 1'b1;
               else if(fsm_time<`T_HISPD_RESET+`T_HISPD_RRT) // T_RRT: master release SI/O to allow device time to power-up and initialize
                  sdo_en <= 1'b0;
               else if(fsm_time<`T_HISPD_RESET+`T_HISPD_RRT+`T_HISPD_DRR) // T_MSDR: master drive SI/O low to start the discovery response acknowledge
                  sdo_en <= 1'b1;
               else
                  sdo_en <= 1'b0;
            end
            `ST_START: begin
               sdo <= 1'b0;
               sdo_en <= 1'b0;
            end
            `ST_DEVADDRR: begin
               sdo <= 1'b0;
               sdo_en <= fsm_cnt<`BIT_NUM ? (sdo_next ? fsm_time<`T_HISPD_LOW1 : fsm_time<`T_HISPD_LOW0) : (fsm_time<`T_HISPD_RD);
            end
            `ST_DEVADDRW: begin
               sdo <= 1'b0;
               sdo_en <= fsm_cnt<`BIT_NUM ? (sdo_next ? fsm_time<`T_HISPD_LOW1 : fsm_time<`T_HISPD_LOW0) : (fsm_time<`T_HISPD_RD);
            end
            `ST_MEMADDR: begin
               sdo <= 1'b0;
               sdo_en <= fsm_cnt<`BIT_NUM ? (sdo_next ? fsm_time<`T_HISPD_LOW1 : fsm_time<`T_HISPD_LOW0) : (fsm_time<`T_HISPD_RD);
            end
            `ST_DATAIN: begin
               sdo <= 1'b0;
               sdo_en <= fsm_cnt<`BIT_NUM ? (fsm_time<`T_HISPD_RD) : (fsm_st_next==`ST_STOP ? fsm_time<`T_HISPD_NACK : fsm_time<`T_HISPD_ACK);
            end 
            `ST_DATAOUT: begin
               sdo <= 1'b0;
               sdo_en <= fsm_cnt<`BIT_NUM ? (sdo_next ? fsm_time<`T_HISPD_LOW1 : fsm_time<`T_HISPD_LOW0) : (fsm_time<`T_HISPD_RD);
            end
            `ST_STOP: begin
               sdo <= 1'b0;
               sdo_en <= 1'b0;
            end
         endcase
      end
   end
      
endmodule