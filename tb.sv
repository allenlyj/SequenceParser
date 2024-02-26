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

    //Send packet to module; can handle dataIn_Ready handshake; Can fake message with wrong length (cycles not matching msgLen field) )
    task sendPacket(input int stream, input int seq, input int length, input badLength=0);
        automatic reg[15:0] streamLE = {stream[7:0], stream[15:8]};
        automatic reg[31:0] seqLE = {seq[7:0], seq[15:8], seq[23:16], seq[31:24]};
        automatic reg[15:0] lengthLE = {length[7:0], length[15:8]};
        automatic int cycles = (length % 4 == 0) ? length/4 : length/4+1;
        automatic int i = 0;
        if (badLength)
            cycles = cycles - 1;
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
        //Total of 10 packets, 4th and 7th packet has seq gap
        //6th, 8th and 9th packet have bad length, still output bad data
        sendPacket(12, 1, 20);
        sendPacket(12, 2, 21);
        sendPacket(12, 3, 22);
        #23
        sendPacket(14, 2, 23);//Gap
        #9
        sendPacket(12, 4, 45);
        sendPacket(14, 3, 71);//Bad length too long
        sendPacket(15, 5, 44);//gap
        #45
        sendPacket(15, 6, 43, 1);//Bad length, length field and cycles not match
        sendPacket(14, 2, 9,1);//Bad length, too short
        sendPacket(14, 4, 15);
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

