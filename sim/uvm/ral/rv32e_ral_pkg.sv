`ifndef RV32E_RAL_PKG_SV
`define RV32E_RAL_PKG_SV

/**
 * RV32E RAL Package.
 * Contains register model definitions.
 */
package rv32e_ral_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ============================================================================
  // MSTATUS Register
  // ============================================================================
  class rv32e_mstatus_reg extends uvm_reg;

    // Fields
    uvm_reg_field mie;

    // Constructor
    function new(string name = "mstatus");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      mie = uvm_reg_field::type_id::create("mie");
      mie.configure(this, 1, 7, "RW", 0, 1'b1, 1, 0, 1);
    endfunction : build

  endclass : rv32e_mstatus_reg

  // ============================================================================
  // MIE Register
  // ============================================================================
  class rv32e_mie_reg extends uvm_reg;

    // Fields
    uvm_reg_field mtie;
    uvm_reg_field meie;

    // Constructor
    function new(string name = "mie");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      mtie = uvm_reg_field::type_id::create("mtie");
      mtie.configure(this, 1, 7, "RW", 0, 1'b0, 1, 0, 1);

      meie = uvm_reg_field::type_id::create("meie");
      meie.configure(this, 1, 11, "RW", 0, 1'b0, 1, 0, 1);
    endfunction : build

  endclass : rv32e_mie_reg

  // ============================================================================
  // MIP Register
  // ============================================================================
  class rv32e_mip_reg extends uvm_reg;

    // Fields
    uvm_reg_field mtip;
    uvm_reg_field meip;

    // Constructor
    function new(string name = "mip");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      mtip = uvm_reg_field::type_id::create("mtip");
      mtip.configure(this, 1, 7, "R", 0, 1'b0, 1, 0, 1);

      meip = uvm_reg_field::type_id::create("meip");
      meip.configure(this, 1, 11, "R", 0, 1'b0, 1, 0, 1);
    endfunction : build

  endclass : rv32e_mip_reg

  // ============================================================================
  // MTVEC Register
  // ============================================================================
  class rv32e_mtvec_reg extends uvm_reg;

    // Constructor
    function new(string name = "mtvec");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      // Mode field (bits 1:0) - direct mode (0) or vectored mode (1)
      // Address field (bits 31:2) - interrupt vector base address
    endfunction : build

  endclass : rv32e_mtvec_reg

  // ============================================================================
  // MEPC Register
  // ============================================================================
  class rv32e_mepc_reg extends uvm_reg;

    // Constructor
    function new(string name = "mepc");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      // Exception PC (bits 31:0)
    endfunction : build

  endclass : rv32e_mepc_reg

  // ============================================================================
  // MCAUSE Register
  // ============================================================================
  class rv32e_mcause_reg extends uvm_reg;

    // Fields
    uvm_reg_field interrupt;
    uvm_reg_field exception_code;

    // Constructor
    function new(string name = "mcause");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      interrupt = uvm_reg_field::type_id::create("interrupt");
      interrupt.configure(this, 1, 31, "R", 0, 1'b0, 1, 0, 1);

      exception_code = uvm_reg_field::type_id::create("exception_code");
      exception_code.configure(this, 31, 0, "R", 0, 32'h0, 1, 0, 1);
    endfunction : build

  endclass : rv32e_mcause_reg

  // ============================================================================
  // MTIME Register (64-bit)
  // ============================================================================
  class rv32e_mtime_reg extends uvm_reg;

    // Constructor
    function new(string name = "mtime");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      // Free-running counter (bits 31:0)
    endfunction : build

  endclass : rv32e_mtime_reg

  // ============================================================================
  // MTIMECMP Register (64-bit)
  // ============================================================================
  class rv32e_mtimecmp_reg extends uvm_reg;

    // Constructor
    function new(string name = "mtimecmp");
      super.new(name, 32);
    endfunction : new

    // Build
    function void build(uvm_reg_addr_t base_addr, uvm_reg_map map);
      // Compare value (bits 31:0)
    endfunction : build

  endclass : rv32e_mtimecmp_reg

  // ============================================================================
  // RV32E Register Block
  // ============================================================================
  class rv32e_reg_block extends uvm_reg_block;

    // Registers
    rv32e_mstatus_reg    mstatus;
    rv32e_mie_reg        mie;
    rv32e_mip_reg        mip;
    rv32e_mtvec_reg      mtvec;
    rv32e_mepc_reg       mepc;
    rv32e_mcause_reg     mcause;
    rv32e_mtime_reg      mtime_lo;
    rv32e_mtime_reg      mtime_hi;
    rv32e_mtimecmp_reg   mtimecmp_lo;
    rv32e_mtimecmp_reg   mtimecmp_hi;

    // Map
    uvm_reg_map main_map;

    // Constructor
    function new(string name = "rv32e_reg_block");
      super.new(name);
    endfunction : new

    // Build
    function void build();
      // Create main map
      main_map = create_map("main_map", 32'h0, 4, UVM_LITTLE_ENDIAN);

      // Configure registers
      mstatus = rv32e_mstatus_reg::type_id::create("mstatus");
      mstatus.configure(this, null, "mstatus");
      mstatus.build();
      main_map.add_reg(mstatus, 32'h300, "RW");

      mie = rv32e_mie_reg::type_id::create("mie");
      mie.configure(this, null, "mie");
      mie.build();
      main_map.add_reg(mie, 32'h304, "RW");

      mip = rv32e_mip_reg::type_id::create("mip");
      mip.configure(this, null, "mip");
      mip.build();
      main_map.add_reg(mip, 32'h344, "RO");

      mtvec = rv32e_mtvec_reg::type_id::create("mtvec");
      mtvec.configure(this, null, "mtvec");
      mtvec.build();
      main_map.add_reg(mtvec, 32'h305, "RW");

      mepc = rv32e_mepc_reg::type_id::create("mepc");
      mepc.configure(this, null, "mepc");
      mepc.build();
      main_map.add_reg(mepc, 32'h341, "RW");

      mcause = rv32e_mcause_reg::type_id::create("mcause");
      mcause.configure(this, null, "mcause");
      mcause.build();
      main_map.add_reg(mcause, 32'h342, "RW");

      mtime_lo = rv32e_mtime_reg::type_id::create("mtime_lo");
      mtime_lo.configure(this, null, "mtime_lo");
      mtime_lo.build();
      main_map.add_reg(mtime_lo, 32'h1F50, "RW");

      mtime_hi = rv32e_mtime_reg::type_id::create("mtime_hi");
      mtime_hi.configure(this, null, "mtime_hi");
      mtime_hi.build();
      main_map.add_reg(mtime_hi, 32'h1F54, "RW");

      mtimecmp_lo = rv32e_mtimecmp_reg::type_id::create("mtimecmp_lo");
      mtimecmp_lo.configure(this, null, "mtimecmp_lo");
      mtimecmp_lo.build();
      main_map.add_reg(mtimecmp_lo, 32'h1F58, "RW");

      mtimecmp_hi = rv32e_mtimecmp_reg::type_id::create("mtimecmp_hi");
      mtimecmp_hi.configure(this, null, "mtimecmp_hi");
      mtimecmp_hi.build();
      main_map.add_reg(mtimecmp_hi, 32'h1F5C, "RW");

      // Lock the block
      lock_model();
    endfunction : build

  endclass : rv32e_reg_block

endpackage : rv32e_ral_pkg

`endif // RV32E_RAL_PKG_SV
