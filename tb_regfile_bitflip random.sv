`timescale 1ns/1ps
`default_nettype none

module tb_regfile_bitflip;

  localparam WIDTH = 32;
  localparam DEPTH = 32;

  logic clk;
  logic we;
  logic [$clog2(DEPTH)-1:0] waddr, raddr1;
  logic [WIDTH-1:0] wdata;
  logic [WIDTH-1:0] rdata1;

  logic [$clog2(DEPTH)-1:0] fault_addr;
  int fault_bit;
  logic [WIDTH-1:0] fault_mask;

  logic [WIDTH-1:0] golden_mem [0:DEPTH-1];
  logic [WIDTH-1:0] expected;

  // DUT instantiation
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

  // Simple Coverage
  covergroup fault_cov @(posedge clk);
    coverpoint fault_addr;
    coverpoint fault_bit;
    cross fault_addr, fault_bit;
  endgroup
  fault_cov cov_fault = new();

  // Main test
  int num_faults = 10000;
  initial begin
    automatic int detected = 0;
    automatic int injected = 0;

    #10;
    $display("=== Bit-Flip Fault Injection Campaign ===");

    repeat (num_faults) begin
      fault_addr = $urandom_range(0, DEPTH-1);
      fault_bit = $urandom_range(0, WIDTH-1);
      fault_mask = 32'b1 << fault_bit;

      // Write clean data
      waddr = fault_addr;
      wdata = $urandom();
      we = 1;
      #10;
      we = 0;
      golden_mem[fault_addr] = wdata;

      // Inject bit-flip into golden reference
      golden_mem[fault_addr] ^= fault_mask; // toggle bit

      expected = golden_mem[fault_addr];
      raddr1 = fault_addr;
      #10;

      cov_fault.sample();

      if (rdata1 !== expected) begin
        $display("[OK] Fault %0d bit-flip @x%0d[%0d]: DUT=%h, EXP=%h",
                 injected, fault_addr, fault_bit, rdata1, expected);
        detected++;
      end else begin
        $display("[MISS] Fault %0d not detected @x%0d[%0d]",
                 injected, fault_addr, fault_bit);
      end

      injected++;
    end

    $display("Total detected bit-flip faults: %0d / %0d", detected, injected);
    $display("Functional Coverage: %0.2f%%", cov_fault.get_coverage());
    $finish;
  end

endmodule
