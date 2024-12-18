// Code your design here

module uart
  #(parameter CLKS_PER_BIT = 87) // Default value for baud rate calculation
(
	input        i_Clock,
	input        i_Rx_Serial,
	input        i_Tx_DV,
	input [7:0]  i_Tx_Byte,
	output [7:0] o_Rx_Byte,
	output       o_Tx_Active,
	output       o_Tx_Serial,
	output       o_Tx_Done,
	output		 o_Rx_Active,
	output       o_Rx_DV//,
	//inout 		 LED_COM
);

// Instantiate the UART receiver module
uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_RX_INST(
	.i_Clock(i_Clock),
	.i_Rx_Serial(i_Rx_Serial), 	// Connect Rx Serial input
	.o_Rx_Active(o_Rx_Active),
	.o_Rx_DV(o_Rx_DV),
	.o_Rx_Byte(o_Rx_Byte)     	// Output received byte
 );

  // Instantiate the UART transmitter module
uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_TX_INST(
	.i_Clock(i_Clock),
	.i_Tx_DV(i_Tx_DV),			//Reset
	.i_Tx_Byte(i_Tx_Byte),     	// Input byte to be transmitted
	.o_Tx_Active(o_Tx_Active),
	.o_Tx_Serial(o_Tx_Serial), 	// Connect serial output
	.o_Tx_Done(o_Tx_Done)
);
	//assign LED_COM=1;
endmodule

// Transmitter

module uart_tx 
#(parameter CLKS_PER_BIT)
(
 input       i_Clock,
 input       i_Tx_DV,
 input [7:0] i_Tx_Byte, 
 output reg  o_Tx_Active,
 output reg  o_Tx_Serial,
 output reg  o_Tx_Done
 );
  
parameter s_IDLE         = 3'b000;
parameter s_TX_START_BIT = 3'b001;
parameter s_TX_DATA_BITS = 3'b010;
parameter s_TX_PARITY_BIT = 3'b011;
parameter s_TX_STOP_BIT  = 3'b100;
parameter s_CLEANUP      = 3'b101;
   
reg [2:0]    r_SM_Main     = 0;
reg [7:0]    r_Clock_Count = 0;
reg [2:0]    r_Bit_Index   = 0;
reg [7:0]    r_Tx_Data     = 0;
reg 		 r_Tx_Parity   = 0;
reg          r_Tx_Done     = 0;
reg          r_Tx_Active   = 0;
     
always @(posedge i_Clock) begin
	if(i_Tx_DV == 1'b0) r_SM_Main <= s_IDLE;
    case (r_SM_Main) 
		s_IDLE : //Case 0
		begin
			o_Tx_Serial   <= 1'b1;         // Drive Line High for Idle
			r_Tx_Done     <= 1'b0;
			r_Clock_Count <= 0;
			r_Bit_Index   <= 0;
             
			if (i_Tx_DV == 1'b1)
			begin
				//r_Tx_Active <= 1'b1;
				r_Tx_Data   <= i_Tx_Byte;
				r_SM_Main   <= s_TX_START_BIT;
			end
			else
				r_SM_Main <= s_IDLE;
		end // case: s_IDLE
         
         
		// Send out Start Bit. Start bit = 0
		s_TX_START_BIT : //Case 1
		begin
			o_Tx_Serial <= 1'b0;
			r_Tx_Active <= 1'b1;
			// Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
			if(r_Clock_Count < CLKS_PER_BIT-1)
			begin
				r_Clock_Count <= r_Clock_Count + 1;
				r_SM_Main     <= s_TX_START_BIT;
			end
			else
			begin
				r_Clock_Count <= 0;
				r_SM_Main     <= s_TX_DATA_BITS;
			end
        end // case: s_TX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
        s_TX_DATA_BITS : //Case 2
        begin
			o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
             
			if(r_Clock_Count < CLKS_PER_BIT-1)
			begin
				r_Clock_Count <= r_Clock_Count + 1;
				r_SM_Main     <= s_TX_DATA_BITS;
			end
			else
			begin
				r_Clock_Count <= 0;
                r_Tx_Parity <= r_Tx_Parity ^  r_Tx_Data[r_Bit_Index];
				// Check if we have sent out all bits
				if(r_Bit_Index < 7)
				begin
					r_Bit_Index <= r_Bit_Index + 1;
					r_SM_Main   <= s_TX_DATA_BITS;
				end
				else
				begin
					r_Bit_Index <= 0;
					r_SM_Main   <= s_TX_PARITY_BIT;
				end
			end
        end // case: s_TX_DATA_BITS
        s_TX_PARITY_BIT : //Case 3
		begin
			
			o_Tx_Serial <= r_Tx_Parity;
            
			// Wait CLKS_PER_BIT-1 clock cycles for parity bit to finish
			if(r_Clock_Count < CLKS_PER_BIT-1)
			begin
				r_Clock_Count <= r_Clock_Count + 1;
				r_SM_Main     <= s_TX_PARITY_BIT;
			end
			else
			begin
				r_Clock_Count <= 0;
				r_SM_Main     <= s_TX_STOP_BIT;
			end
			
		end // case: s_Tx_PARITY_BIT
      
        // Send out Stop bit.  Stop bit = 1
        s_TX_STOP_BIT : //Case 3
		begin
			o_Tx_Serial <= 1'b1;
            
				// Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
				if(r_Clock_Count < CLKS_PER_BIT-1)
				begin
				r_Clock_Count <= r_Clock_Count + 1;
				r_SM_Main     <= s_TX_STOP_BIT;
				end
				else
				begin
					r_Clock_Count <= 0;
					r_Tx_Done     <= 1'b1;
					r_SM_Main     <= s_CLEANUP;
					r_Tx_Active   <= 1'b0;
				end
		end // case: s_Tx_STOP_BIT
         

			// Stay here 1 clock
		s_CLEANUP :
		begin
            r_Tx_Done <= 1'b1;
            r_SM_Main <= s_IDLE;
        end
         
         
        default :
			r_SM_Main <= s_IDLE;
         
        endcase
	o_Tx_Active <= r_Tx_Active;
	o_Tx_Done   <= r_Tx_Done;
end
   
endmodule

//Receiver

module uart_rx 
#(parameter CLKS_PER_BIT)
(
	input        i_Clock,
	input        i_Rx_Serial,
	output reg	 o_Rx_Active,
	output       o_Rx_DV,
	output [7:0] o_Rx_Byte
);
    
  // State machine implementation (as provided earlier)
parameter s_IDLE         = 3'b000;
parameter s_RX_START_BIT = 3'b001;
parameter s_RX_DATA_BITS = 3'b010;
parameter s_TX_PARITY_BIT = 3'b011;
parameter s_RX_STOP_BIT  = 3'b100;
parameter s_CLEANUP      = 3'b101;
   
reg           r_Rx_Data_R = 1'b1;
reg           r_Rx_Data   = 1'b1;
   
reg [7:0]     r_Clock_Count = 0;
reg [2:0]     r_Bit_Index   = 0;
reg [7:0]     r_Rx_Byte     = 0;
reg			  r_Rx_Active	= 0; //Check if receiver working
reg           r_Rx_DV       = 0;
reg [2:0]     r_SM_Main     = 0;
  
// Main logic for UART receiver
always @(posedge i_Clock) begin
	r_Rx_Data_R <= i_Rx_Serial;
	r_Rx_Data   <= r_Rx_Data_R;
    
	case (r_SM_Main)
		s_IDLE : 
		begin
		r_Rx_DV       <= 1'b0;
		r_Clock_Count <= 0;
		r_Bit_Index   <= 0;
		if (r_Rx_Data == 1'b0) r_SM_Main <= s_RX_START_BIT;
		else r_SM_Main <= s_IDLE;
		end
		
		s_RX_START_BIT : 
		begin
		r_Rx_Active <= 1'b1;
		//Check middle of start bit to ensure it is still low
        if (r_Clock_Count == (CLKS_PER_BIT-1)/2) 
			begin
			if(r_Rx_Data == 1'b0)
				begin
				r_Clock_Count <= 0;
				r_SM_Main <= s_RX_DATA_BITS;
				end
			else r_SM_Main <= s_IDLE;
			end
        else
			begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main <= s_RX_START_BIT;
			end
		end

		s_RX_DATA_BITS : 
		begin
        if (r_Clock_Count < CLKS_PER_BIT-1)
        begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main     <= s_RX_DATA_BITS;
		end
        else 
			begin
			r_Clock_Count <= 0;
			r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
			if (r_Bit_Index < 7)
			begin
				r_Bit_Index <= r_Bit_Index + 1;
				r_SM_Main     <= s_RX_DATA_BITS;
			end
			else
			begin 
				r_Bit_Index <= 0;
				r_SM_Main <= s_RX_STOP_BIT; 
			end
			end
		end

		s_RX_STOP_BIT : 
		begin
        if (r_Clock_Count < CLKS_PER_BIT-1)
        begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main <= s_RX_STOP_BIT;
		end
        else 
			begin
				r_Rx_DV       <= 1'b1;
				r_Clock_Count <= 0;
				r_Rx_Active   <= 1'b0;
				r_SM_Main     <= s_CLEANUP;
			end
		end

		s_CLEANUP : 
		begin
		r_SM_Main <= s_IDLE;
		r_Rx_DV   <= 1'b0;
		end
	endcase
	o_Rx_Active <= r_Rx_Active;
end

	assign o_Rx_DV   = r_Rx_DV;
	assign o_Rx_Byte = r_Rx_Byte;

endmodule
