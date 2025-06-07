`timescale 1ns/1ps
`default_nettype none

module tb_regfile_all;

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
  int fault_mask_bit;

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
    .raddr2(),
    .rdata1(rdata1),
    .rdata2()
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Full Coverage Group: fault_type × fault_addr × fault_mask_bit
  covergroup full_fault_cov @(posedge clk);
    coverpoint fault_type;
    coverpoint fault_addr;
    coverpoint fault_mask_bit {
      bins bit_pos[] = {[0:31]};
    }
    cross fault_type, fault_addr, fault_mask_bit;
  endgroup
  full_fault_cov cov_full = new();

  // Initialization
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
    if (rdata1 !== expected)
      $display("FAIL: Expected %h, got %h", expected, rdata1);
    else
      $display("PASS: x5 = %h", rdata1);
  end

  // Full Fault Coverage Test
  initial begin
    automatic int detected = 0;
    automatic int injected = 0;

    #30;
    $display("=== Full Fault Injection Coverage Campaign ===");

    for (int t = 0; t < 2; t++) begin
      for (int a = 1; a < DEPTH; a++) begin
        for (int b = 0; b < WIDTH; b++) begin
          fault_type = t;
          fault_addr = a;
          fault_mask_bit = b;
          fault_mask = 32'b1 << fault_mask_bit;
          fault_enable = 1;

          // Write random data
          waddr = fault_addr;
          wdata = $urandom;
          we = 1;
          #10;
          we = 0;

          // Update golden model
          golden_mem[fault_addr] = wdata;
          if (fault_type == 0)
            golden_mem[fault_addr] &= ~fault_mask;
          else
            golden_mem[fault_addr] |= fault_mask;

          expected = golden_mem[fault_addr];
          raddr1 = fault_addr;
          #10;

          cov_full.sample(); // sample this triple (type, addr, bit)

          if (rdata1 !== expected) begin
            $display("[Mismatch] Fault %0d @x%0d[%0d]: DUT=%h, EXP=%h",
              injected, fault_addr, fault_mask_bit, rdata1, expected);
          end else begin
            $display("[Detected] Fault %0d @x%0d[%0d]",
              injected, fault_addr, fault_mask_bit);
            detected++;
          end

          injected++;
        end
      end
    end

    $display("Detected: %0d / %0d", detected, injected);
    $display("Functional Coverage (2048 bins): %0.2f%%", cov_full.get_coverage());
    $finish;
  end

endmodule


