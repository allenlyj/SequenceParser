transcript file "./history.log"

vlog -work work ./parser.sv
vlog -work work ./tb.sv

vsim -t 1ps -L work tb_parser

run 20 us