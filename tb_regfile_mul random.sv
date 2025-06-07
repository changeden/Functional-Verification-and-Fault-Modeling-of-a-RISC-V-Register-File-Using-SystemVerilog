`timescale 1ns/1ps
`default_nettype none

module tb_regfile_mulcov;

  // Parameters
  localparam WIDTH = 32;
  localparam DEPTH = 32;

  // DUT signals
  logic clk;
  logic we;
  logic [$clog2(DEPTH)-1:0] waddr, raddr1;
  logic [WIDTH-1:0] wdata;
  logic [WIDTH-1:0] rdata1;

  // Fault injection
  logic fault_enable;
  logic fault_type; // 0: stuck-at-0, 1: stuck-at-1
  logic [$clog2(DEPTH)-1:0] fault_addr;
  logic [WIDTH-1:0] fault_mask;

  // Scoreboard
  logic [WIDTH-1:0] golden_mem [0:DEPTH-1];
  logic [WIDTH-1:0] expected;

  // Instantiate DUT
  regfile #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
    .clk(clk),
    .we(we),
    .waddr(waddr),
    .wdata(wdata),
    .raddr1(raddr1),
    .raddr2(), // unused
    .rdata1(rdata1),
    .rdata2()  // unused
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

  // Covergroups
  covergroup fault_cov @(posedge clk);
    coverpoint fault_type;
    coverpoint fault_addr;
    cross fault_type, fault_addr;
  endgroup
  fault_cov cov_fault = new();

  covergroup write_cov @(posedge clk);
    coverpoint waddr { bins addr[] = {[0:31]}; }
    coverpoint wdata { wildcard bins some_data = {32'h????????}; }
    cross waddr, wdata;
  endgroup
  write_cov cov_write = new();

  covergroup read_cov @(posedge clk);
    coverpoint raddr1 { bins addr[] = {[0:31]}; }
  endgroup
  read_cov cov_read = new();

  // Directed write test
  initial begin
    we = 1;
    waddr = 5;
    wdata = 32'hCAFEBABE;
    raddr1 = 5;
    #10;
    we = 0;
    golden_mem[5] = 32'hCAFEBABE;
    expected = golden_mem[5];
    #10;
    cov_read.sample();
    cov_write.sample();
    if (rdata1 !== expected)
      $display("FAIL: Expected %h, got %h", expected, rdata1);
    else
      $display("PASS: x5 = %h", rdata1);
  end

  // Random Fault Injection
  int num_faults = 200;
  initial begin
    automatic int detected = 0;
    automatic int injected = 0;

    #30;
    $display("=== Random Fault Injection Campaign ===");

    repeat (num_faults) begin
      automatic int seed = {$urandom, $time, $realtime} ^ $urandom_range(0, 1000);
      automatic int fault_bit;
      automatic int num_fault_bits;

      fault_enable = 1;
      fault_type = $urandom(seed + 1) % 2;
      fault_addr = $urandom(seed + 2) % DEPTH;

      // Multi-bit fault mask generation
      fault_mask = 0;
      num_fault_bits = 2 + $urandom(seed + 3) % 3; // 2–4 bits
      for (int i = 0; i < num_fault_bits; i++) begin
        fault_bit = $urandom(seed + i + 10) % WIDTH;
        fault_mask |= (32'b1 << fault_bit);
      end

      // Stimulus
      waddr = fault_addr;
      wdata = (fault_type == 0) ? fault_mask : 32'b0;
      we = 1;
      #10;
      we = 0;
      golden_mem[fault_addr] = wdata;
      cov_write.sample();

      // Fault injection into golden model
      if (fault_type == 0)
        golden_mem[fault_addr] &= ~fault_mask;
      else
        golden_mem[fault_addr] |= fault_mask;

      expected = golden_mem[fault_addr];
      raddr1 = fault_addr;
      #10;
      cov_read.sample();
      cov_fault.sample();

      if (rdata1 !== expected) begin
        $display("[OK] Fault %0d mismatch @x%0d mask=%h: DUT=%h, EXP=%h",
                 injected, fault_addr, fault_mask, rdata1, expected);
        detected++;
      end else begin
        $display("[MISS] Fault %0d not detected @x%0d mask=%h",
                 injected, fault_addr, fault_mask);
      end

      injected++;
    end

    $display("Total detected multi-bit faults: %0d / %0d", detected, injected);
    $display("Functional Coverage (fault_cov): %0.2f%%", cov_fault.get_coverage());
    $display("Functional Coverage (write_cov): %0.2f%%", cov_write.get_coverage());
    $display("Functional Coverage (read_cov):  %0.2f%%", cov_read.get_coverage());
    $finish;
  end

endmodule
