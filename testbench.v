// Code your testbench here
// or browse Examples
module uart_tb ();

  // Testbench uses a 10 MHz clock
  // Want to interface to 115200 baud UART
  // 10000000 / 115200 = 87 Clocks Per Bit.
  parameter c_CLOCK_PERIOD_NS = 100;
  parameter c_CLKS_PER_BIT    = 87;
  parameter c_BIT_PERIOD      = 8600;
   
  reg r_Clock = 0;
  reg r_Tx_DV = 0;
  wire w_Tx_Done;
  reg [7:0] r_Tx_Byte = 0;
  reg r_Rx_Serial = 1;
  reg r_Rx_Parity = 0;
  wire [7:0] w_Rx_Byte;
   
  // Takes in input byte and serializes it 
  task UART_WRITE_BYTE;
    input [7:0] i_Data;
    integer     ii;
    begin
       
      // Send Start Bit
      r_Rx_Serial <= 1'b0;
      #(c_BIT_PERIOD);
      
      // Send Data Byte
      for (ii = 0; ii < 8; ii = ii + 1)
        begin
          r_Rx_Serial <= i_Data[ii];
          r_Rx_Parity <= r_Rx_Parity ^ i_Data[ii];
          #(c_BIT_PERIOD);
        end
      // Send Parity Bit
      r_Rx_Serial <= r_Rx_Parity;
      #(c_BIT_PERIOD);
      // Send Stop Bit
      r_Rx_Serial <= 1'b1;
      #(c_BIT_PERIOD);
     end
  endtask // UART_WRITE_BYTE
   
  // Instantiate UART receiver
  uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST
    (.i_Clock(r_Clock),
     .i_Rx_Serial(r_Rx_Serial),
     .o_Rx_DV(),
     .o_Rx_Byte(w_Rx_Byte)
     );
   
  // Instantiate UART transmitter
  uart_tx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_TX_INST
    (.i_Clock(r_Clock),
     .i_Tx_DV(r_Tx_DV),
     .i_Tx_Byte(r_Tx_Byte),
     .o_Tx_Active(),
     .o_Tx_Serial(),
     .o_Tx_Done(w_Tx_Done)
     );
 
  // Clock generation
  always
    #(c_CLOCK_PERIOD_NS/2) r_Clock <= !r_Clock;

  // Main Testing:
  initial begin
      // Transmit a command using UART transmitter (testing Tx functionality)
      //@(posedge r_Clock);
      @(posedge r_Clock);
      r_Tx_DV <= 1'b1;
      r_Tx_Byte <= 8'h2F;
      @(posedge r_Clock);
      r_Tx_DV <= 1'b0;
      @(posedge w_Tx_Done);
      if(w_Tx_Done)
      	$display("Transmission Complete: Byte 0x%h successfully sent.", r_Tx_Byte);
      else
        $display("Transmission not successful!");
       
      // Send a command to UART receiver (testing Rx functionality)
      @(posedge r_Clock);
      UART_WRITE_BYTE(8'h2F);
      @(posedge r_Clock);
             
      // Check if the correct byte was received
      $display("Received Byte is 0x%h",w_Rx_Byte);
      $display("Parity is %b",r_Rx_Parity);
      if (w_Rx_Byte == 8'h2F)
        $display("Receiver Test Passed - Correct Byte Received");
      else
        $display("Receiver Test Failed - Incorrect Byte Received");
      #10 $finish;
    end

endmodule
