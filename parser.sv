module parser(clk, reset_b, dataIn, dataIn_val, dataIn_ready, dataIN_last, //receive interface
               dataOut, dataOut_val, dataOut_ready, packetLost); //send interface
    
    input clk, reset_b, dataIn_val, dataIN_last, dataOut_ready;
    input [31:0] dataIn;
    output dataIn_ready, dataOut_val, packetLost;
    //output reg[0:295] dataOut;
    output[0:295] dataOut;
    reg [31:0] outputPrepare [0:9]; //Prepare (aggregate incoming stream)
    reg [31:0] seqs [0:31]; //Stores next sequence expected for each stream
    reg packetLostReg = 0;
    reg outputPending = 0;
    localparam [1:0] IDLE = 0;
    localparam [1:0] GET_2ND_WORD = 1;
    localparam [1:0] GET_DATA = 2;
    reg [1:0] receiverState = IDLE;
    reg [15:0] bytesLeft = 0;
    reg [15:0] currentStream = 0;
    reg [31:0] currentSeq = 0;
    reg [31:0] expectedSeq = 0;
    reg [31:0] nextExpectedSeq = 0;
    reg [3:0] currentOutputIndex = 0;
    wire canMoveForward;
    reg [31:0] maskedInput;
    wire sequenceValid;
    wire [4:0] currentStreamTrimmed;
    
    // Extra logic to detect bad length
    reg lengthOverflow;
    reg badLengthReg;

    assign dataIn_ready = !outputPending;
    assign dataOut_val = outputPending;
    
    assign canMoveForward = !outputPending & dataIn_val;
    assign currentStreamTrimmed = currentStream[4:0];
    assign sequenceValid = (currentSeq == seqs[currentStreamTrimmed] + 1);

    always @ (dataIN_last or dataIn or bytesLeft) begin
        if (!dataIN_last) 
            maskedInput = dataIn;
        else begin
            case (bytesLeft)
                1 : maskedInput = {dataIn[31:24], 24'd0};
                2 : maskedInput = {dataIn[31:16], 16'd0};
                3 : maskedInput = {dataIn[31:8], 8'd0};
                default : maskedInput = dataIn;
            endcase
        end
    end
    /*
    always @ (*) begin
        for (int i = 0; i < 9; i++) begin
            if (outputPending) begin
                if (!badLengthReg)
                    dataOut[32*i +:32] = outputPrepare[i];
                else
                    dataOut[32*i +:32] = 32'hFFFFFFFF;
            end else
                dataOut[32*i +:32] = 0;
        end
        dataOut[288:295] = outputPending ? (badLengthReg ? 8'hFF : outputPrepare[9][31:24]) : 0;
    end*/

    assign dataOut = outputPending ? (badLengthReg ? {37{8'hFF}} : {outputPrepare[0], outputPrepare[1], outputPrepare[2],
                                                           outputPrepare[3], outputPrepare[4], outputPrepare[5],
                                                           outputPrepare[6], outputPrepare[7], outputPrepare[8],
                                                           outputPrepare[9][31:24]}) : 0;
    assign packetLost = outputPending ? packetLostReg : 0;

    always @ (posedge clk)
        if (!reset_b) begin
            outputPending <= 0;
            for (int j = 0; j <= 31; j = j+1) begin
                seqs[j] <= 1;
            end
            for (int j = 0; j < 10; j = j + 1) begin
                outputPrepare[j] <= 0;
            end
            receiverState <= IDLE;
        end else begin
            // Only move forward if there is incoming data and no pending transaction
            case(receiverState)
            IDLE:
                if (canMoveForward) begin
                    bytesLeft <= {dataIn[23:16], dataIn[31:24]}-4;
                    currentStream <= {dataIn[7:0], dataIn[15:8]};
                    receiverState <= GET_2ND_WORD;
                    lengthOverflow <= {dataIn[23:16], dataIn[31:24]} > 45;
                end
            GET_2ND_WORD:
                if (canMoveForward) begin
                    if (dataIN_last) begin
                        $display("Terrible short format, ignore seq checks, recover to IDLE");
                        receiverState <= IDLE;
                        outputPending <= 1'b1;
                        badLengthReg <= 1'b1;
                    end else begin
                        bytesLeft <= bytesLeft - 4;
                        currentSeq <= {dataIn[7:0], dataIn[15:8], dataIn[23:16], dataIn[31:24]};
                        nextExpectedSeq <= {dataIn[7:0], dataIn[15:8], dataIn[23:16], dataIn[31:24]}+1; //Break write and increment to 2 differrent cycles
                        expectedSeq <= seqs[currentStreamTrimmed];
                        receiverState <= GET_DATA;
                        currentOutputIndex <= 0;
                    end
                end
            GET_DATA:
                if (canMoveForward) begin
                    outputPrepare[currentOutputIndex] <= maskedInput;
                    currentOutputIndex <= currentOutputIndex + 1;
                    bytesLeft <= bytesLeft - 4;
                    if (dataIN_last) begin
                        packetLostReg <= (currentSeq != expectedSeq);
                        outputPending <= 1'b1;
                        seqs[currentStreamTrimmed] <= nextExpectedSeq;
                        receiverState <= IDLE;
                        badLengthReg <= bytesLeft == 0 || bytesLeft >4 || lengthOverflow;
                        lengthOverflow <= 1'b0;
                    end 
                end
            default : receiverState <= IDLE; //Something wrong
            endcase

            if (outputPending & dataOut_ready) begin
                if (badLengthReg) begin
                    $display("Bad length detected");
                end
                outputPending <= 1'b0;
                packetLostReg <= 1'b0;
                badLengthReg <= 1'b0;
                for (int j = 0; j < 10; j = j+1) begin
                    outputPrepare[j] <= 32'b0;
                end
            end
        end



        
endmodule