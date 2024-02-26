transcript file "./history.log"

vlog -work work ./parser.sv
vlog -work work +acc=rnpbc ./tb.sv

vsim -t 1ps -L work tb_parser

config wave -signalnamewidth 1

do wave.do
run 2 us