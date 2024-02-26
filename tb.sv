`timescale 1ns/1ps
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
        #5;
        clk = 1'b1;
        #5;
    end

    task sendPacket(input int stream, input int seq, input int length, input badLength=0);
        automatic reg[15:0] streamLE = {stream[7:0], stream[15:8]};
        automatic reg[31:0] seqLE = {seq[7:0], seq[15:8], seq[23:16], seq[31:24]};
        automatic reg[15:0] lengthLE = {length[7:0], length[15:8]};
        automatic int cycles = (length % 4 == 0) ? length/4 : length/4+1;
        if (badLength)
            cycle = cycle + 1;
        automatic int i = 0;
        dataInVal = 1'b0;
        while (i < cycles) begin
            dataInVal = 1'b1;
            dataInLast = 1'b0;
            if (i == 0)
                dataIn = {lengthLE, streamLE};
            else if (i == 1)
                dataIn = seqLE;
            else
                //Encode data for easy message identify
                dataIn = (stream << 24) + (seq << 16) + (length << 8) + i;
            if (i == cycles-1)
                dataInLast = 1'b1;
            @ (posedge clk) begin
                if (dataInReady)
                    i = i + 1;
            end
        end
        dataInVal = 1'b0;
        dataInLast = 1'b0;
    endtask

    task report();
        while (1) begin
            @ (posedge clk) begin
                if (dataOutVal && dataOutReady)
                    $display("Valid output data=%x packetLost=%d", dataOut, packetLost);
            end
        end
    endtask

    initial begin
        reset = 1'b0;
        #50ns reset = 1'b1;
        sendPacket(12, 0, 20);
        sendPacket(13, 0, 21);
        sendPacket(14, 0, 22);
        #23
        sendPacket(14, 2, 23);
        #9
        sendPacket(12, 1, 45);
        sendPacket(14, 3, 47);
        sendPacket(15, 5, 44);
        #45
        sendPacket(15, 6, 43, 1);
    end

    //Model random receiver side blocking futher operation
    initial begin
        #252 dataOutReady = 1'b1;
        #88 dataOutReady = 1'b0;
        #155 dataOutReady = 1'b1;
    end

    initial begin
        report();
    end

    /*initial begin
        $monitor("valid=%d last=%d data=%8x ready=%d outValid=%d, outData=%x, packetLost=%d", dataInVal, dataInLast, dataIn, dataInReady, dataOutVal, dataOut, packetLost);
    end*/
endmodule

