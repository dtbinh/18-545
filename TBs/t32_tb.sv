`default_nettype none

`define CLOCK_PERIOD 20

module t32_tb;

	//////////// SIGNAL DECLARATIONS ////////////

    // general IO
    logic [17:0] LEDR;
    logic [8:0] LEDG;
    logic [17:0] switches;
    logic [3:0] btns;

    // RS-232/UART
    logic tx, rts;
    logic rx_pin;

    // VGA
    logic HS, VS;
    logic [23:0] VGA_RGB;
    logic VGA_clk;
    logic VGA_blank;

    // SRAM
    logic [19:0] sram_addr;
    wire [15:0] sram_io;
    logic sram_we_b;
    logic sram_oe_b;
    logic sram_ce_b;
    logic sram_ub_b;
    logic sram_lb_b;

    // SDRAM
    logic [12:0] dram_addr;
    wire [31:0] dram_dq;
    logic [1:0] dram_ba; // bank address
    logic [3:0] dram_dqm; // data mask
    logic dram_ras_n;
    logic dram_cas_n;
    logic dram_cke;
    logic dram_clk;
    logic dram_we_n;
    logic dram_cs_n;

    // PS2
    wire PS2_CLK;
    wire PS2_DAT;
     
    logic clk;

    logic rst;
    assign rst = ~btns[3]; // for SRAM model

	//////////// MODULE INSTANTIATIONS ////////////

    t_minus_32_days	t32(.*);
    sram			sr(.*);

	//////////// CLOCK AND RESET INITIAL BLOCK ////////////

    initial begin
        clk <= 1'b0;
        btns[3] <= 1'b1;
        #1;
        btns[3] <= 1'b0;
        #1;
        btns[3] <= 1'b1;
        forever #(`CLOCK_PERIOD/2) clk = ~clk;
    end

	//////////// MAIN INITIAL BLOCK ////////////

    int j;
    logic [7:0] message [128];

    initial begin

		btns[2:0] <= 3'b111;
    	rx_pin <= 1'b1;

        repeat (100) @(posedge clk);

		// Hit start button
        @(posedge clk);
        btns[0] <= 1'b0;
        repeat(100) @(posedge clk);
        btns[0] <= 1'b1;

        repeat (100) @(posedge clk);

        for(j=0; j<128; j++)
            message[j] = $random % 8'hFF;

        send_block(message,8'd1,1); // send message with error

        repeat (5000) @(posedge clk); // wait for NAK

        send_block(message,8'd1,0); // resend message without error

        send_EOT();

        repeat (10000) @(posedge clk); // wait for things to finish up

        $finish;
    end

    //////////// TASKS ////////////

    task send_EOT();
        send_byte(8'h04);
    endtask

    task send_block(input [7:0] message [128], input [7:0] block_num, input have_error);

        integer i;
        logic [7:0] x;
        logic [7:0] sum;
        
        sum = 0;

        send_byte(8'h01); // SOH
        send_byte(block_num); // byte 1
        send_byte(~block_num); // ~(byte 1)
        for(i=0; i<128; i++) begin
            x = message[i];
            sum += x;
            send_byte(x);
            $display("i: %d x: %b %h sum: %b %h",i,x,x,sum,sum);
        end
        if(have_error)
        	send_byte(sum-1);
        else
	        send_byte(sum);

    endtask: send_block

    task send_byte(input [7:0] data);

        repeat(434) @(posedge clk);

        rx_pin <= 1'b0; // indicates start

        for(j=0; j<8; j++) begin
            repeat(434) @(posedge clk);
            rx_pin <= data[j]; // first data bit
        end

        repeat(434) @(posedge clk);
        rx_pin <= 1'b1; // end of byte

    endtask: send_byte

endmodule: t32_tb