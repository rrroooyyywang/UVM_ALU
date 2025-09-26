// tb/uvm_pkg.sv
`include "uvm_macros.svh"
package uvm_demo_pkg;
  import uvm_pkg::*;

  // 3.1 sequence item
  class alu_item extends uvm_sequence_item;
    rand bit [1:0] op;
    rand bit [7:0] a, b;
         bit [7:0] y_exp; // 期望值（scoreboard 用）
    `uvm_object_utils_begin(alu_item)
      `uvm_field_int(op, UVM_ALL_ON)
      `uvm_field_int(a , UVM_ALL_ON)
      `uvm_field_int(b , UVM_ALL_ON)
      `uvm_field_int(y_exp, UVM_ALL_ON | UVM_NOPRINT)
    `uvm_object_utils_end
    function new(string name="alu_item"); super.new(name); endfunction
    function void post_randomize();
      case(op)
        2'd0: y_exp = a + b;
        2'd1: y_exp = a - b;
        2'd2: y_exp = a ^ b;
        default: y_exp = a & b;
      endcase
    endfunction
  endclass

  // 3.2 sequencer
  class alu_sequencer extends uvm_sequencer #(alu_item);
    `uvm_component_utils(alu_sequencer)
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  // 3.3 driver
  class alu_driver extends uvm_driver #(alu_item);
    `uvm_component_utils(alu_driver)
    virtual simple_if.drv_mp vif;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual simple_if.drv_mp)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","driver no vif")
    endfunction
    task run_phase(uvm_phase phase);
      alu_item tr;
      vif.cb.req <= 0;
      forever begin
        seq_item_port.get_next_item(tr);
        // 驱动一次事务
        vif.cb.op  <= tr.op;
        vif.cb.a   <= tr.a;
        vif.cb.b   <= tr.b;
        vif.cb.req <= 1;
        @(vif.cb); // 1 个周期发起
        vif.cb.req <= 0;
        // 等 ack（固定 1 拍后应答，但这里用 while 更通用）
        do @(vif.cb); while (!vif.cb.ack);
        seq_item_port.item_done();
      end
    endtask
  endclass

  // 3.4 monitor
  class alu_txn extends uvm_object; // 监视到的“实际值”
    `uvm_object_utils(alu_txn)
    bit [1:0] op; bit [7:0] a,b,y;
    function new(string n="alu_txn"); super.new(n); endfunction
  endclass

  class alu_monitor extends uvm_component;
    `uvm_component_utils(alu_monitor)
    virtual simple_if.mon_mp vif;
    uvm_analysis_port #(alu_txn) ap;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      if(!uvm_config_db#(virtual simple_if.mon_mp)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","monitor no vif")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if (vif.req && vif.ack) begin
          alu_txn t = new();
          t.op = vif.op; t.a = vif.a; t.b = vif.b; t.y = vif.y;
          ap.write(t);
        end
      end
    endtask
  endclass

  // 3.5 agent
  class alu_agent extends uvm_component;
    `uvm_component_utils(alu_agent)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    alu_sequencer sqr; alu_driver drv; alu_monitor mon;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = alu_monitor::type_id::create("mon", this);
      if (is_active==UVM_ACTIVE)
        begin
          sqr = alu_sequencer::type_id::create("sqr", this);
          drv = alu_driver   ::type_id::create("drv", this);
        end
    endfunction
    function void connect_phase(uvm_phase phase);
      if (is_active==UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // 3.6 scoreboard
  class alu_scoreboard extends uvm_component;
    `uvm_component_utils(alu_scoreboard)
    uvm_analysis_export #(alu_txn) ap;
    int unsigned n_checked, n_err;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
    endfunction
    // 为了取期望值，这里简单重算（也可通过预测器或把 item 带入）
    function void write(alu_txn t);
      byte exp;
      unique case (t.op)
        2'd0: exp = t.a + t.b;
        2'd1: exp = t.a - t.b;
        2'd2: exp = t.a ^ t.b;
        default: exp = t.a & t.b;
      endcase
      n_checked++;
      if (t.y !== exp) begin
        `uvm_error("ALU_MISMATCH", $sformatf("a=%0d b=%0d op=%0d y=%0d exp=%0d", t.a,t.b,t.op,t.y,exp))
        n_err++;
      end
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("SCORE",
        $sformatf("Checked=%0d, Errors=%0d", n_checked, n_err), UVM_LOW)
    endfunction
  endclass

  // 3.7 env
  class alu_env extends uvm_env;
    `uvm_component_utils(alu_env)
    alu_agent       agent;
    alu_scoreboard  scb;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = alu_agent      ::type_id::create("agent", this);
      scb   = alu_scoreboard ::type_id::create("scb", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.mon.ap.connect(scb.ap);
    endfunction
  endclass

  // 3.8 sequence & test
  class alu_smoke_seq extends uvm_sequence #(alu_item);
    `uvm_object_utils(alu_smoke_seq)
    function new(string n="alu_smoke_seq"); super.new(n); endfunction
    task body();
      repeat (50) begin
        alu_item it = alu_item::type_id::create("it");
        assert(it.randomize() with { op inside {[0:3]}; });
        start_item(it);
        finish_item(it);
      end
    endtask
  endclass

  class alu_test extends uvm_test;
    `uvm_component_utils(alu_test)
    alu_env env;
    function new(string n, uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = alu_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      alu_smoke_seq seq = alu_smoke_seq::type_id::create("seq");
      seq.start(env.agent.sqr);
      phase.drop_objection(this);
    endtask
  endclass

endpackage
