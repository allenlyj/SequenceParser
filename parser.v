module parser(clk, reset_b, dataIn, dataIn_val, dataIn_ready, dataIN_last, //receive interface
               dataOut, dataOut_val, dataOut_ready, packetLost); //send interface
    
    input clk, reset_b, dataIn_val, dataIN_last, dataOut_ready;
    input [31:0] dataIn;
    output dataIn_ready, dataOut_val, packetLost;
    output [0:295] dataOut;

    reg [31:0] outputPrepare [0:9];
    reg [31:0] outputFinal [0:9];
    reg [31:0] seqs [0:31];
    reg packetLostReg = 0;
    reg outputPending = 0;
    localparam [1:0] IDLE = 0;
    localparam [1:0] GET_2ND_WORD = 1;
    localparam [1:0] GET_DATA = 2;
    localparam [1:0] COMMIT_OUTPUT = 3;
    reg [1:0] receiverState = IDLE;
    reg [15:0] bytesLeft = 0;
    reg [15:0] currentStream = 0;
    reg [31:0] currentSeq = 0;
    reg [3:0] currentOutputIndex = 0;
    wire canMoveForward;
    wire [31:0] maskedInput;
    wire sequenceValid;
    wire [4:0] currentStreamTrimmed;

    integer i;
    genvar geni;

    assign dataIn_ready = !(outputPending || receiverState == COMMIT_OUTPUT);
    assign dataOut_val = outputPending;
    assign packetLost = packetLostReg;
    assign dataOut = outputFinal;
    assign canMoveForward = !outputPending & dataIn_val;
    assign currentStreamTrimmed = currentStream[4:0];
    assign sequenceValid = (currentSeq == seqs[currentStreamTrimmed] + 1);

    if (!dataIN_last) 
        assign maskedInput = dataIn;
    else begin
        case (bytesLeft)
            1 : assign maskedInput = {dataIn[31:24], 24'd0};
            2 : assign maskedInput = {dataIn[31:16], 16'd0};
            3 : assign maskedInput = {dataIn[31:8], 8'd0};
            4 : assign maskedInput = dataIn;
            default : assign maskedInput = 0; //Bad format, should not happen or should trigger error flag
        endcase
    end

    for (geni = 0; geni < 10; geni = geni+1) generate
        if (i != 9)
            assign dataOut[geni*32:geni*32+31] = outputFinal[geni];
        else
            assign dataOut[geni*32:geni*32+7] = outputFinal[geni][31:24];
    endgenerate

    always @ (posedge clk)
        if (!reset_b) begin
            outputPending <= 0;
            for (i = 0; i <= 31; i = i+1)
                seqs[i] <= 0;
            for (i = 0; i < 10; i = i + 1)
                outputPrepare[i] <= 0;
            receiverState <= IDLE;
            outputPrepare <= 0;
        end else begin
            // Only move forward if there is incoming data and no pending transaction
            case(receiverState)
            IDLE:
                if (canMoveForward) begin
                    bytesLeft <= dataIn[31:16]-4;
                    currentStream <= dataIn[15:0];
                    receiverState <= GET_2ND_WORD;
                end
            GET_2ND_WORD:
                if (canMoveForward) begin
                    bytesLeft <= bytesLeft - 4;
                    currentSeq <= dataIn;
                    receiverState <= GET_DATA;
                    currentOutputIndex <= 0;
                end
            GET_DATA:
                if (canMoveForward) begin
                    outputPrepare[currentOutputIndex] <= maskedInput;
                    currentOutputIndex <= currentOutputIndex + 1;
                    bytesLeft <= bytesLeft - 4;
                    if (dataIN_last)
                        receiverState <= COMMIT_OUTPUT;
                end
            COMMIT_OUTPUT: begin
                receiverState <= IDLE;
                for (i = 0; i < 10; i = i+1) begin
                    outputPrepare[i] <= 32'b0;
                    outputFinal[i] <= outputPrepare[i];
                end
                seqs[currentStreamTrimmed] <= currentSeq;
                packetLostReg <= !sequenceValid;
                outputPending <= 1'b1;
            end
            endcase

            if (outputPending & dataOut_ready) begin
                outputPending <= 1'b0;
                packetLostReg <= 1'b0;
            end
        end



        
endmodule