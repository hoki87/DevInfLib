/////////////////////////// DEFINE /////////////////////////////

////////////////// REGISTERS
// Mode Register
`define  RGAD_MR_0            10'h000
`define  RGAD_MR_1            10'h001
// Interrupt Register         
`define  RGAD_IR_0            10'h002
`define  RGAD_IR_1            10'h003
// Interrupt Mask Register    
`define  RGAD_IMR_0           10'h004
`define  RGAD_IMR_1           10'h005
// Source Hardware Address Register
`define  RGAD_SHAR_0          10'h008
`define  RGAD_SHAR_1          10'h009
`define  RGAD_SHAR_2          10'h00A
`define  RGAD_SHAR_3          10'h00B
`define  RGAD_SHAR_4          10'h00C
`define  RGAD_SHAR_5          10'h00D
// Gateway IP Address Register
`define  RGAD_GAR_0           10'h010
`define  RGAD_GAR_1           10'h011
`define  RGAD_GAR_2           10'h012
`define  RGAD_GAR_3           10'h013
// Subnet Mask Register       
`define  RGAD_SUBR_0          10'h014
`define  RGAD_SUBR_1          10'h015
`define  RGAD_SUBR_2          10'h016
`define  RGAD_SUBR_3          10'h017
// Source IP Address Register
`define  RGAD_SIPR_0          10'h018
`define  RGAD_SIPR_1          10'h019
`define  RGAD_SIPR_2          10'h01A
`define  RGAD_SIPR_3          10'h01B
// TX Memory Size Register    
`define  RGAD_TMSR_0          10'h020
`define  RGAD_TMSR_1          10'h021
`define  RGAD_TMSR_2          10'h022
`define  RGAD_TMSR_3          10'h023
`define  RGAD_TMSR_4          10'h024
`define  RGAD_TMSR_5          10'h025
`define  RGAD_TMSR_6          10'h026
`define  RGAD_TMSR_7          10'h027
// RX Memory Size Register    
`define  RGAD_RMSR_0          10'h028
`define  RGAD_RMSR_1          10'h029
`define  RGAD_RMSR_2          10'h02A
`define  RGAD_RMSR_3          10'h02B
`define  RGAD_RMSR_4          10'h02C
`define  RGAD_RMSR_5          10'h02D
`define  RGAD_RMSR_6          10'h02E
`define  RGAD_RMSR_7          10'h02F
// Memory Type Register       
`define  RGAD_MTYPER_0        10'h030
`define  RGAD_MTYPER_1        10'h031
// Fragment MTU Register      
`define  RGAD_FMTUR_0         10'h04E
`define  RGAD_FMTUR_1         10'h04F
// SOCKETn Register        
`define  RGAD_S0_MR_0         10'h200
`define  RGAD_S0_MR_1         10'h201
`define  RGAD_S0_CR           10'h203
`define  RGAD_S0_IMR_0        10'h204
`define  RGAD_S0_IMR_1        10'h205
`define  RGAD_S0_IR_0         10'h206
`define  RGAD_S0_IR_1         10'h207
`define  RGAD_S0_SSR          10'h209
`define  RGAD_S0_PORTR_0      10'h20A
`define  RGAD_S0_PORTR_1      10'h20B
`define  RGAD_S0_DPORTR_0     10'h212
`define  RGAD_S0_DPORTR_1     10'h213
`define  RGAD_S0_DIPR_0       10'h214
`define  RGAD_S0_DIPR_1       10'h215
`define  RGAD_S0_DIPR_2       10'h216
`define  RGAD_S0_DIPR_3       10'h217
`define  RGAD_S0_MSSR_0       10'h218
`define  RGAD_S0_MSSR_1       10'h219
`define  RGAD_S0_TX_WRSR_0    10'h220
`define  RGAD_S0_TX_WRSR_1    10'h221
`define  RGAD_S0_TX_WRSR_2    10'h222
`define  RGAD_S0_TX_WRSR_3    10'h223
`define  RGAD_S0_TX_FSR_0     10'h224
`define  RGAD_S0_TX_FSR_1     10'h225
`define  RGAD_S0_TX_FSR_2     10'h226
`define  RGAD_S0_TX_FSR_3     10'h227
`define  RGAD_S0_RX_RSR_0     10'h228
`define  RGAD_S0_RX_RSR_1     10'h229
`define  RGAD_S0_RX_RSR_2     10'h22A
`define  RGAD_S0_RX_RSR_3     10'h22B
`define  RGAD_S0_TX_FIFOR_0   10'h22E 
`define  RGAD_S0_TX_FIFOR_1   10'h22F
`define  RGAD_S0_RX_FIFOR_0   10'h230
`define  RGAD_S0_RX_FIFOR_1   10'h231
                           
`define  RGAD_S1_MR_0         10'h240
`define  RGAD_S1_MR_1         10'h241
`define  RGAD_S1_CR           10'h243
`define  RGAD_S1_IMR_0        10'h244
`define  RGAD_S1_IMR_1        10'h245
`define  RGAD_S1_IR_0         10'h246
`define  RGAD_S1_IR_1         10'h247
`define  RGAD_S1_SSR          10'h249
`define  RGAD_S1_PORTR_0      10'h24A
`define  RGAD_S1_PORTR_1      10'h24B
`define  RGAD_S1_DPORTR_0     10'h252
`define  RGAD_S1_DPORTR_1     10'h253
`define  RGAD_S1_DIPR_0       10'h254
`define  RGAD_S1_DIPR_1       10'h255
`define  RGAD_S1_DIPR_2       10'h256
`define  RGAD_S1_DIPR_3       10'h257
`define  RGAD_S1_MSSR_0       10'h258
`define  RGAD_S1_MSSR_1       10'h259
`define  RGAD_S1_TX_WRSR_0    10'h260
`define  RGAD_S1_TX_WRSR_1    10'h261
`define  RGAD_S1_TX_WRSR_2    10'h262
`define  RGAD_S1_TX_WRSR_3    10'h263
`define  RGAD_S1_TX_FSR_0     10'h264
`define  RGAD_S1_TX_FSR_1     10'h265
`define  RGAD_S1_TX_FSR_2     10'h266
`define  RGAD_S1_TX_FSR_3     10'h267
`define  RGAD_S1_RX_RSR_0     10'h268
`define  RGAD_S1_RX_RSR_1     10'h269
`define  RGAD_S1_RX_RSR_2     10'h26A
`define  RGAD_S1_RX_RSR_3     10'h26B
`define  RGAD_S1_TX_FIFOR_0   10'h26E 
`define  RGAD_S1_TX_FIFOR_1   10'h26F
`define  RGAD_S1_RX_FIFOR_0   10'h270
`define  RGAD_S1_RX_FIFOR_1   10'h271

                              
`define  RGAD_S2_MR_0         10'h280
`define  RGAD_S2_MR_1         10'h281
                              
`define  RGAD_S3_MR_0         10'h2C0
`define  RGAD_S3_MR_1         10'h2C1
                              
`define  RGAD_S4_MR_0         10'h300
`define  RGAD_S4_MR_1         10'h301
                              
`define  RGAD_S5_MR_0         10'h340
`define  RGAD_S5_MR_1         10'h341
                              
`define  RGAD_S6_MR_0         10'h380
`define  RGAD_S6_MR_1         10'h381
                              
`define  RGAD_S7_MR_0         10'h3C0
`define  RGAD_S7_MR_1         10'h3C1
// Identification Register    
`define  RGAD_IDR_0           10'h0FE
`define  RGAD_IDR_1           10'h0FF

////////////////// STATUS
`define  SOCK_MR_ALIGN        8'h01
`define  SOCK_MR_MULTI        8'h80
`define  SOCK_MR_MACFLT       8'h40
`define  SOCK_MR_ND           8'h20
`define  SOCK_MR_TCP          8'h01
`define  SOCK_MR_UDP          8'h02
                              
`define  SOCK_CR_OPEN         8'h01
`define  SOCK_CR_LISTEN       8'h02
`define  SOCK_CR_CONNECT      8'h04
`define  SOCK_CR_DISCON       8'h08
`define  SOCK_CR_CLOSE        8'h10
`define  SOCK_CR_SEND         8'h20
`define  SOCK_CR_SENDMAC      8'h21
`define  SOCK_CR_SENDKEEP     8'h22
`define  SOCK_CR_RECV         8'h40

`define  SOCK_SSR_CLOSED      8'h00
`define  SOCK_SSR_INIT        8'h13
`define  SOCK_SSR_LISTEN      8'h14
`define  SOCK_SSR_ESTABLISHED 8'h17
`define  SOCK_SSR_CLOSE_WAIT  8'h1C
`define  SOCK_SSR_UDP         8'h22

`define  SOCK_IR_SENDOK       8'h10
`define  SOCK_IR_TIMEOUT      8'h08
`define  SOCK_IR_RECV         8'h04
`define  SOCK_IR_DISCON       8'h02
`define  SOCK_IR_CON          8'h01

`define  PROT_TCP             1'b0
`define  PROT_UDP             1'b1
