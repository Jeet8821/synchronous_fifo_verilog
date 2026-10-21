`timescale 1ns / 1ps


module synchronous_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16,
    parameter integer PTR_WIDTH  = (DEPTH <= 2) ? 1 : $clog2(DEPTH),
    parameter integer COUNT_WIDTH = $clog2(DEPTH + 1)
) (
    input  wire                  clk,
    input  wire                  rst,      
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire                  full,
    output wire                  empty,
    output reg  [COUNT_WIDTH-1:0] count
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;

    wire write_accept = wr_en && !full;
    wire read_accept  = rd_en && !empty;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

   
    function [PTR_WIDTH-1:0] next_ptr;
        input [PTR_WIDTH-1:0] ptr;
        begin
            if (ptr == DEPTH - 1)
                next_ptr = {PTR_WIDTH{1'b0}};
            else
                next_ptr = ptr + 1'b1;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {PTR_WIDTH{1'b0}};
            rd_ptr <= {PTR_WIDTH{1'b0}};
            count  <= {COUNT_WIDTH{1'b0}};
            dout   <= {DATA_WIDTH{1'b0}};
        end else begin
            if (write_accept) begin
                mem[wr_ptr] <= din;
                wr_ptr <= next_ptr(wr_ptr);
            end

            if (read_accept) begin
                dout <= mem[rd_ptr];
                rd_ptr <= next_ptr(rd_ptr);
            end

            case ({write_accept, read_accept})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
