`ifndef RV32E_IMEM_MODEL_SV
`define RV32E_IMEM_MODEL_SV

/**
 * IMEM model for RV32E.
 * Models the instruction memory with $readmemh compatibility.
 */
class rv32e_imem_model;

  int m_depth;
  bit [31:0] m_mem[];

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------
  function new(string name = "rv32e_imem_model");
    m_depth = 1024;
    m_mem = new[m_depth];
  endfunction : new

  //--------------------------------------------------------------------------
  // set_depth() - Set memory depth
  //--------------------------------------------------------------------------
  function void set_depth(int depth);
    m_depth = depth;
    m_mem = new[m_depth];
  endfunction : set_depth

  //--------------------------------------------------------------------------
  // load_hex() - Load from hex file
  //--------------------------------------------------------------------------
  function void load_hex(string hex_file);
    int fd;
    string line;
    int addr = 0;

    fd = $fopen(hex_file, "r");
    if (fd == 0) begin
      `uvm_error("HEX_FILE", $sformatf("Cannot open hex file: %s", hex_file))
      return;
    end

    while ($fgets(line, fd) != 0) begin
      line = $trim(line);
      if (line == "" || line[0] == "@") continue;
      
      if (addr < m_depth) begin
        m_mem[addr] = $svfscan("%x", line);
        addr++;
      end
    end

    $fclose(fd);
    `uvm_info("IMEM", $sformatf("Loaded %0d words from %s", addr, hex_file), UVM_MEDIUM)
  endfunction : load_hex

  //--------------------------------------------------------------------------
  // read() - Read from memory
  //--------------------------------------------------------------------------
  function bit [31:0] read(int addr);
    if (addr >= 0 && addr < m_depth) begin
      return m_mem[addr];
    end
    return 32'h0;
  endfunction : read

  //--------------------------------------------------------------------------
  // write() - Write to memory (not used for IMEM, but included for completeness)
  //--------------------------------------------------------------------------
  function void write(int addr, bit [31:0] data, bit [3:0] be = 4'b1111);
    // IMEM is typically write-protected
    `uvm_warning("IMEM_WRITE", "IMEM write attempted - ignored (write-protected)")
  endfunction : write

endclass : rv32e_imem_model

`endif // RV32E_IMEM_MODEL_SV
