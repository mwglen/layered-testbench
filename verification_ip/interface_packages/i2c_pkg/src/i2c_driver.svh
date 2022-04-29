class i2c_driver extends ncsu_component#(.T(i2c_transaction));
   
   i2c_configuration cfg;
   i2c_transaction   i2c_trans;
   virtual i2c_if    bus;

   //****************************************************************
   // CONSTRUCTOR
   //****************************************************************
   function new(string name = "", ncsu_component #(T) parent = null);
      super.new(name, parent);
   endfunction

   //****************************************************************
   // SET CONFIGURATION
   //****************************************************************
   function void set_configuration(i2c_configuration cfg);
      this.cfg = cfg;
   endfunction

   //****************************************************************
   // BLOCKING PUT
   //****************************************************************
   virtual task bl_put(T trans);
      if (trans == null) begin
         // Wait for an I2C Transaction
         bus.capture_transfer(trans);

         // If it was a read, provide read data
         if (trans.op == i2c_pkg::READ) begin
            // trans.data = gen.provide_data;
            bus.send_read_data(0);
         end
      end
   endtask
endclass
