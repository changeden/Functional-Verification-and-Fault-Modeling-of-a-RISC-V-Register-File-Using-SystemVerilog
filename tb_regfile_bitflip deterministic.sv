`timescale 1ns/1ps
`default_nettype none

module tb_regfile_bitflip_fullcov;

  localparam WIDTH = 32;
  localparam DEPTH = 32;

  logic clk;
  logic we;
  logic [$clog2(DEPTH)-1:0] waddr, raddr1;
  logic [WIDTH-1:0] wdata;
  logic [WIDTH-1:0] rdata1;

  logic [WIDTH-1:0] golden_mem [0:DEPTH-1];
  logic [WIDTH-1:0] expected;

  logic [$clog2(DEPTH)-1:0] fault_addr;
  int fault_bit;
  logic [WIDTH-1:0] fault_mask;

  // DUT
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

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Coverage
  covergroup bitflip_cov @(posedge clk);
    coverpoint fault_addr { bins all_addr[] = {[0:DEPTH-1]}; }
    coverpoint fault_bit  { bins all_bits[] = {[0:WIDTH-1]}; }
    cross fault_addr, fault_bit;
  endgroup

  bitflip_cov cov = new();

  // Full fault injection sweep
  initial begin
    automatic int detected = 0;
    automatic int injected = 0;

    #10;
    $display("=== Exhaustive Bit-Flip Fault Sweep ===");

    for (int addr = 0; addr < DEPTH; addr++) begin
      for (int bit_idx = 0; bit_idx < WIDTH; bit_idx++) begin
        fault_addr = addr;
        fault_bit  = bit_idx;
        fault_mask = 32'b1 << fault_bit;

        // Write base pattern
        waddr = fault_addr;
        wdata = $urandom(); // or fixed pattern like 32'hA5A5A5A5
        we = 1;
        #10;
        we = 0;
        golden_mem[fault_addr] = wdata;

        // Flip bit in golden reference
        golden_mem[fault_addr] ^= fault_mask;
        expected = golden_mem[fault_addr];

        // Read and compare
        raddr1 = fault_addr;
        #10;
        cov.sample();

        if (rdata1 !== expected) begin
          $display("[OK] Bit-flip @x%0d[%0d]: DUT=%h, EXP=%h",
                   fault_addr, fault_bit, rdata1, expected);
          detected++;
        end else begin
          $display("[MISS] Undetected fault @x%0d[%0d]", fault_addr, fault_bit);
        end

        injected++;
      end
    end

    $display("Total detected bit-flip faults: %0d / %0d", detected, injected);
    $display("Functional Coverage: %0.2f%%", cov.get_coverage());
    $finish;
  end

endmodule
