vcs -full64 -sverilog +acc +vpi -ntb_opts uvm-1.2 \
    +incdir+$UVM_HOME/src tb/simple_if.sv dut/simple_alu.sv tb/uvm_pkg.sv tb/top.sv \
    -l comp.log
./simv +UVM_NO_RELNOTES -l sim.log
