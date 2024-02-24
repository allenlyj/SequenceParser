module tb_parser;

    //Input signals
    reg clk = 0, reset = 1'b1, dataInVal = 0, dataOutReady = 0, datainLast = 0;
    reg [31:0] dataIn = 0;
    //Output signals
    wire dataInReady, dataOutVal, packetLost;
    wire [0:295] dataOut;
    parser yaojie(clk, reset, dataIn, dataInVal, dataInReady, dataInLast,
                        dataOut, dataOutVal, dataOutReady, packetLost);
    initial begin
        clk = 0;
        dataInVal = 0;
        dataOutReady = 1'b1;
        forever begin
            #10ns clk = ~clk;
            #15ns dataInVal = ~dataInVal;
        end
    end
endmodule