`timescale 1ns / 1ps

// Nexys A7-100T board demo for the parameterized synchronous FIFO.
// SW[7:0] selects the byte to write.
// BTNU writes one byte; BTND reads one byte; BTNC resets the FIFO.
// LED[7:0] shows the most recently read byte.
// LED[8] = full, LED[9] = empty, LED[13:10] = occupancy count [3:0].
module nexys_a7_fifo_top (
    input  wire        CLK100MHZ,
    input  wire [7:0]  SW,
    input  wire        BTNC,
    input  wire        BTNU,
    input  wire        BTND,
    output reg  [15:0] LED
);

    localparam integer DATA_WIDTH = 8;
    localparam integer DEPTH = 16;
    localparam integer COUNT_WIDTH = $clog2(DEPTH + 1);

    wire rst = BTNC;
    wire write_pulse;
    wire read_pulse;

    wire [DATA_WIDTH-1:0] fifo_dout;
    wire fifo_full;
    wire fifo_empty;
    wire [COUNT_WIDTH-1:0] fifo_count;

    // Synchronize and debounce the mechanical buttons; produce one-cycle pulses.
    button_onepulse #(.CLK_HZ(100_000_000), .DEBOUNCE_MS(10)) u_write_button (
        .clk(CLK100MHZ), .rst(rst), .button_in(BTNU), .pulse_out(write_pulse)
    );

    button_onepulse #(.CLK_HZ(100_000_000), .DEBOUNCE_MS(10)) u_read_button (
        .clk(CLK100MHZ), .rst(rst), .button_in(BTND), .pulse_out(read_pulse)
    );

    synchronous_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) u_fifo (
        .clk(CLK100MHZ),
        .rst(rst),
        .wr_en(write_pulse),
        .rd_en(read_pulse),
        .din(SW),
        .dout(fifo_dout),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count)
    );

    // Keep the last read data visible; update status/count indicators continuously.
    always @(posedge CLK100MHZ) begin
        if (rst) begin
            LED <= 16'b0;
        end else begin
            LED[7:0]   <= fifo_dout;
            LED[8]     <= fifo_full;
            LED[9]     <= fifo_empty;
            LED[13:10] <= fifo_count[3:0];
            LED[15:14] <= 2'b00;
        end
    end

endmodule


module button_onepulse #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 10,
    parameter integer COUNTER_WIDTH =
        (CLK_HZ / 1000 * DEBOUNCE_MS <= 2) ? 1 : $clog2(CLK_HZ / 1000 * DEBOUNCE_MS)
) (
    input  wire clk,
    input  wire rst,
    input  wire button_in,
    output reg  pulse_out
);

    localparam integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;

    reg sync_ff1;
    reg sync_ff2;
    reg stable_state;
    reg [COUNTER_WIDTH-1:0] debounce_count;

    always @(posedge clk) begin
        if (rst) begin
            sync_ff1      <= 1'b0;
            sync_ff2      <= 1'b0;
            stable_state  <= 1'b0;
            debounce_count <= {COUNTER_WIDTH{1'b0}};
            pulse_out     <= 1'b0;
        end else begin
            sync_ff1 <= button_in;
            sync_ff2 <= sync_ff1;
            pulse_out <= 1'b0;

            if (sync_ff2 == stable_state) begin
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end else if (debounce_count >= DEBOUNCE_CYCLES - 1) begin
                stable_state <= sync_ff2;
                debounce_count <= {COUNTER_WIDTH{1'b0}};
                if (sync_ff2)
                    pulse_out <= 1'b1;
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end
        end
    end

endmodule
