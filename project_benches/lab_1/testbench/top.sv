`timescale 1ns / 10ps

import i2c_pkg::*;

module top();
  
  parameter int WB_ADDR_WIDTH = 2;
  parameter int WB_DATA_WIDTH = 8;
  parameter int NUM_I2C_BUSSES = 1;
  
  // My Parameters
  parameter int I2C_ADDR_WIDTH = 7;
  parameter int I2C_DATA_WIDTH = 8;
     
  bit  clk;
  bit  rst = 1'b1;
  wire cyc;
  wire stb;
  wire we;
  tri1 ack;
  wire [WB_ADDR_WIDTH-1:0] adr;
  wire [WB_DATA_WIDTH-1:0] dat_wr_o;
  wire [WB_DATA_WIDTH-1:0] dat_rd_i;
  wire irq;
  triand [NUM_I2C_BUSSES-1:0] scl;
  triand [NUM_I2C_BUSSES-1:0] sda;

  // Clock generator
  initial begin : clk_gen
      clk = 1'b0;
      forever #5 clk = ~clk;
  end
  
  // Reset generator
  initial begin : rst_gen
     rst = 1'b1;
     #113 rst = ~rst;
  end
 
  // Monitor Wishbone bus and display transfers in the transcript
  initial begin : wb_monitoring

     // Setup variables to store returned data
     bit [WB_ADDR_WIDTH-1:0] wb_mon_addr;
     bit [WB_DATA_WIDTH-1:0] wb_mon_data;
     bit wb_mon_we;
     
     // Wait 1000ns for things to cool down
     #1000
     
     // Start Monitoring
     forever begin
        wb_bus.master_monitor(wb_mon_addr, wb_mon_data, wb_mon_we);
        $display("WB PACKET: we=%b addr=0x%h data=0x%h", 
           wb_mon_we, wb_mon_addr, wb_mon_data);
     end
  end
  
  initial begin : i2c_monitoring

     // Setup variables to store returned data
     bit [WB_ADDR_WIDTH-1:0] i2c_mon_addr;
     i2c_op_t                i2c_mon_op;
     bit [WB_DATA_WIDTH-1:0] i2c_mon_data[];
     
     // Wait 1000ns for things to cool down
     #2000
     
     // Start Monitoring
     forever begin
        i2c_bus.monitor(i2c_mon_addr, i2c_mon_op, i2c_mon_data);
        case (i2c_mon_op)
          READ:  $display("I2C_BUS READ  Transfer: %d", i2c_mon_data[0]);
          WRITE: $display("I2C_BUS WRITE Transfer: %d", i2c_mon_data[0]);
        endcase
     end
  end
  
  enum bit[1:0] {
      CSR  = 2'b00, 
      DPR  = 2'b01, 
      CMDR = 2'b10, 
      FSMR = 2'b11
  } Registers;
   
  // Define the flow of the simulation
  initial begin : test_flow
     static bit [I2C_DATA_WIDTH-1:0] read_data = 0;
  
     // Wait 1000ns
     #1000
     
     iicmb_enable();

     // Wait 1000ns
     #1000
     
     iicmb_write(0, 0, {data});
     
     $finish;
  end

  task iicmb_enable();
     // Write byte "1xxxxxxx" to the CSR register 
     // // This sets bit E to '1', enabling the core
     wb_bus.master_write(CSR, 8'b1100_0000);
  endtask
 
  task iicmb_write(
     input bit [WB_ADDR_WIDTH-1:0] bus_id,
     input bit [I2C_ADDR_WIDTH-1:0] slave_addr,
     input bit [I2C_DATA_WIDTH-1:0] write_data
  );

    logic [7:0] tmp_data;
     
     //*****************************************************************
     // SELECT BUS
     //*****************************************************************
     // Write bus_id to the DPR
     wb_bus.master_write(DPR, bus_id);
     
     // Write byte "xxxxx110" to the CMDR
     // This is "Set Bus" command
     wb_bus.master_write(CMDR, 8'b110);
     
     // Wait for interrupt or until DON bit of CMDR reads '1'
     // If instead of DON the NAK bit is '1', then slave doesn't respond
     wait(irq); wb_bus.master_read(CMDR, tmp_data);
  
     //*****************************************************************
     // CAPTURE BUS
     //*****************************************************************
     // Write byte "xxxxx100" to the CMDR 
     // This is the "Start" command
     wb_bus.master_write(CMDR, 8'b100);
     
     // Wait for interrupt or until DON bit of CMDR reads '1'
     // If instead of DON the NAK bit is '1', then slave doesn't respond
     wait(irq); wb_bus.master_read(CMDR, tmp_data);
     
     //*****************************************************************
     // INITIATE CONTACT WITH SLAVE ON I2C BUS
     //*****************************************************************
     // Write slave address to the DPR 
     // The rightmost bit, 0 means writing
     wb_bus.master_write(DPR, {slave_addr, 1'b0});
     
     // Write byte "xxxxx001" to the CMDR
     // This is the "Write" command
     wb_bus.master_write(CMDR, 8'b001);
     
     // Wait for interrupt or until DON bit of CMDR reads '1'
     // If instead of DON the NAK bit is '1', then slave doesn't respond
     wait(irq); wb_bus.master_read(CMDR, tmp_data);
     
     //*****************************************************************
     // SEND WRITE COMMAND TO SLAVE ON I2C BUS
     //*****************************************************************
     // Write byte to the DPR
     wb_bus.master_write(DPR, write_data);
     
     // Write byte "xxxxx001" to the CMDR
     // This is "Write" command
     wb_bus.master_write(CMDR, 8'b001);
     
     // Wait for interrupt or until DON bit of CMDR reads '1'
     wait(irq); wb_bus.master_read(CMDR, tmp_data);
  
     //*****************************************************************
     // FREE SELECTED BUS
     //*****************************************************************
     // Write byte "xxxxx101" to the CMDR. 
     // This is "Stop" command
     wb_bus.master_write(CMDR, 8'b101);
     
     // Wait for interrupt or until DON bit of CMDR reads '1'
     wait(irq); wb_bus.master_read(CMDR, tmp_data);

  endtask
  
  // Instantiate the Wishbone master Bus Functional Model
  wb_if #(
        .ADDR_WIDTH(WB_ADDR_WIDTH),
        .DATA_WIDTH(WB_DATA_WIDTH)
        )
  wb_bus (
    // System sigals
    .clk_i(clk),
    .rst_i(rst),
    // Master signals
    .cyc_o(cyc),
    .stb_o(stb),
    .ack_i(ack),
    .adr_o(adr),
    .we_o(we),
    // Slave signals
    .cyc_i(),
    .stb_i(),
    .ack_o(),
    .adr_i(),
    .we_i(),
    // Shred signals
    .dat_o(dat_wr_o),
    .dat_i(dat_rd_i)
    );
  
  
  // Instantiate the I2C Interface
  i2c_if #(
        .NUM_BUSSES(NUM_I2C_BUSSES),
        .ADDR_WIDTH(I2C_ADDR_WIDTH),
        .DATA_WIDTH(I2C_DATA_WIDTH)
        )
  i2c_bus (
    .scl(scl[0]),  // I2C Clock
    .sda(sda[0])   // I2C Data
    );
     
  
  // Instantiate the DUT - I2C Multi-Bus Controller
  \work.iicmb_m_wb(str) #(.g_bus_num(NUM_I2C_BUSSES)) DUT
    (
      // -- Wishbone signals:
      .clk_i(clk),  // in    std_logic;       -- Clock
      .rst_i(rst),  // in    std_logic;       -- Synchronous reset (active high)
      // -------------
      .cyc_i(cyc),  // in    std_logic;       -- Valid bus cycle indication
      .stb_i(stb),  // in    std_logic;       -- Slave selection
      .ack_o(ack),  //   out std_logic;       -- Acknowledge output
      .we_i(we),    // in    std_logic;       -- Write enable
     
      .adr_i(adr),  // in    std_logic_vector(1 to 0);  -- Low bits of Wishbone address
      .dat_i(dat_wr_o),    // in    std_logic_vector(7 to 0);  -- Data input
      .dat_o(dat_rd_i),    //   out std_logic_vector(7 to 0);  -- Data output
     
      // -- Interrupt request:
      .irq(irq),    //   out std_logic;       -- Interrupt request
     
      // -- I2C interfaces:
      .scl_i(scl),  // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Clock inputs
      .sda_i(sda),  // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Data inputs
      .scl_o(scl),  //   out std_logic_vector(0 to g_bus_num - 1); -- I2C Clock outputs
      .sda_o(sda)   //   out std_logic_vector(0 to g_bus_num - 1)  -- I2C Data outputs
    );
 
endmodule
