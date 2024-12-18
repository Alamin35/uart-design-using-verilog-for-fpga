module uart_rx 
#(parameter CLKS_PER_BIT=3)
(
	input        i_Clock,
	input        i_Rx_Serial,
	output  	 o_Rx_Active,
	output       o_Rx_DV,
	output [7:0] o_Rx_Byte,
	output 		 o_Rx_Parity,
	output 		 o_Rx_Error,
	inout LED_COM
);
    
  // State machine implementation (as provided earlier)
parameter s_IDLE         = 3'b000;
parameter s_RX_START_BIT = 3'b001;
parameter s_RX_DATA_BITS = 3'b010;
parameter s_RX_PARITY_BIT= 3'b011;
parameter s_RX_STOP_BIT  = 3'b100;
parameter s_CLEANUP      = 3'b101;
   
reg           r_Rx_Data_R = 1'b1;
reg           r_Rx_Data   = 1'b1;
   
reg [7:0]     r_Clock_Count = 0;
reg [2:0]     r_Bit_Index   = 0;
reg [7:0]     r_Rx_Byte     = 0;
reg			  r_Rx_Active	= 0; //Check if receiver working
reg			  r_Rx_Parity   = 0;
reg 		  r_Rx_Error	= 0;
reg           r_Rx_DV       = 0;
reg [2:0]     r_SM_Main     = 0;
  
// Main logic for UART receiver
always @(posedge i_Clock) begin
	r_Rx_Data_R <= i_Rx_Serial;
	r_Rx_Data   <= r_Rx_Data_R;
    
	case (r_SM_Main)
		s_IDLE : //Case 0
		begin
		r_Rx_DV       <= 1'b0;
		r_Clock_Count <= 0;
		r_Bit_Index   <= 0;
		r_Rx_Byte	  <= 0;
		r_Rx_Active	  <= 0;
		r_Rx_Parity	  <= 0;
		r_Rx_Error	  <= 0;
		if (r_Rx_Data == 1'b0)
		begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main <= s_RX_START_BIT;
		end
		else r_SM_Main <= s_IDLE;
		end
		
		s_RX_START_BIT : //Case 1
		begin
		//r_Rx_Active <= 1'b1;
		//Check middle of start bit to ensure it is still low
        if (r_Clock_Count == (CLKS_PER_BIT-1)/2) 
			begin
			if(r_Rx_Data == 1'b0)
				begin
				r_Clock_Count <= 0;
				r_Rx_Active <= 1'b1;
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

		s_RX_DATA_BITS : //Case 2
		begin
		//r_Rx_Active <= 1'b1;
        if (r_Clock_Count < CLKS_PER_BIT-1)
        begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main     <= s_RX_DATA_BITS;
		end
        else 
			begin
			r_Clock_Count <= 0;
			r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
			r_Rx_Parity <= r_Rx_Parity ^ r_Rx_Data;
			if (r_Bit_Index < 7)
			begin
				r_Bit_Index <= r_Bit_Index + 1;
				r_SM_Main     <= s_RX_DATA_BITS;
			end
			else
			begin 
				r_Bit_Index <= 0;
				r_SM_Main <= s_RX_PARITY_BIT; 
			end
			end
		end
		
		s_RX_PARITY_BIT : //Case 3
		begin
        if (r_Clock_Count < CLKS_PER_BIT-1)
        begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main <= s_RX_PARITY_BIT;
		end
        else 
			begin
				//r_Rx_DV       <= 1'b1;
				r_Clock_Count <= 0;
				//r_Rx_Active   <= 1'b0;
				r_Rx_Error	  <= (r_Rx_Parity ^ r_Rx_Data);
				r_SM_Main     <= s_RX_STOP_BIT;
			end
		end
		
		s_RX_STOP_BIT : //Case 4 
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

		s_CLEANUP : //Case 5
		begin
        if (r_Clock_Count < CLKS_PER_BIT-1)
        begin
			r_Clock_Count <= r_Clock_Count + 1;
			r_SM_Main <= s_CLEANUP;
		end
        else 
			begin
				r_SM_Main <= s_IDLE;
				r_Rx_DV   <= 1'b0;
				r_Rx_Byte <= 0;
				r_Rx_Error <= 0;
			end
		end 
	endcase
end
	assign o_Rx_Active = r_Rx_Active;
	assign o_Rx_DV   = r_Rx_DV;
	assign o_Rx_Byte = r_Rx_Byte;
	assign o_Rx_Parity = r_Rx_Parity;
	assign o_Rx_Error = r_Rx_Error;
	assign LED_COM=1;

endmodule
