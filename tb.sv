`include "parser.sv"
module tb_parser;

    //Input signals
    reg clk = 0, reset = 1'b1, dataInVal = 0, dataOutReady = 0, dataInLast = 0;
    reg [31:0] dataIn = 0;
    //Output signals
    wire dataInReady, dataOutVal, packetLost;
    wire [0:295] dataOut;
    parser yaojie(.clk(clk), .reset_b(reset), 
                   .dataIn(dataIn), .dataIn_val(dataInVal), 
                   .dataIn_ready(dataInReady), .dataIN_last(dataInLast),
                   .dataOut(dataOut), .dataOut_val(dataOutVal),
                   .dataOut_ready(dataOutReady), .packetLost(packetLost));
    

    always begin
        clk = 1'b0;
        #5ns
        clk = 1'b1;
        #5ns
    end

    initial begin
        dataInVal = 0;
        dataOutReady = 1'b1;
        #10ns clk = ~clk;
        #15ns dataInVal = ~dataInVal;
        #10ns dataOutReady = ~dataOutReady;
        #10ns dataIn = dataIn + 1;
    end

    always @ (posedge clk)
        $display ("T=%0t dataOut=0x%0h", $time, dataOut);
    always @ (negedge clk)
        $display ("T=%0t dataOut=0x%0h", $time, dataOut);
endmodule