`timescale 1ns/1ps

module regfile #(
  parameter WIDTH = 32,
  parameter DEPTH = 32,
  parameter ADDRW = $clog2(DEPTH)
)(
  input clk,
  input we,
  input [ADDRW-1:0] waddr,
  input [WIDTH-1:0] wdata,
  input [ADDRW-1:0] raddr1,
  input [ADDRW-1:0] raddr2,
  output [WIDTH-1:0] rdata1,
  output [WIDTH-1:0] rdata2,
  input fault_enable,
  input [ADDRW-1:0] fault_addr,
  input [WIDTH-1:0] fault_mask,
  input [1:0] fault_type  // 0 = no fault, 1 = flip, 2 = stuck-0, 3 = stuck-1
);

  reg [WIDTH-1:0] mem [0:DEPTH-1];
  integer i;

  initial begin
    for (i = 0; i < DEPTH; i = i + 1)
      mem[i] = 0;
  end

  always @(posedge clk) begin
    if (we && waddr != 0)
      mem[waddr] <= wdata;
  end

  function [WIDTH-1:0] inject_fault(input [WIDTH-1:0] val, input [ADDRW-1:0] addr);
    if (fault_enable && addr == fault_addr) begin
      case (fault_type)
        1: return val ^ fault_mask;      // bit-flip
        2: return val & ~fault_mask;     // stuck-at-0
        3: return val | fault_mask;      // stuck-at-1
        default: return val;
      endcase
    end else return val;
  endfunction

  assign rdata1 = (raddr1 == 0) ? 0 : inject_fault(mem[raddr1], raddr1);
  assign rdata2 = (raddr2 == 0) ? 0 : inject_fault(mem[raddr2], raddr2);

endmodule
