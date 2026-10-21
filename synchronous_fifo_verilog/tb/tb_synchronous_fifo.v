`timescale 1ns / 1ps

module tb_synchronous_fifo;

    localparam integer DATA_WIDTH = 8;
    localparam integer DEPTH = 16;
    localparam integer COUNT_WIDTH = $clog2(DEPTH + 1);

    reg clk = 1'b0;
    reg rst = 1'b0;
    reg wr_en = 1'b0;
    reg rd_en = 1'b0;
    reg [DATA_WIDTH-1:0] din = 0;

    wire [DATA_WIDTH-1:0] dout;
    wire full;
    wire empty;
    wire [COUNT_WIDTH-1:0] count;

    integer tests = 0;
    integer errors = 0;
    integer i;
    integer n;
    integer seed = 32'h13572468;

    // Reference queue implemented as a circular scoreboard.
    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH*4-1];
    integer model_wr = 0;
    integer model_rd = 0;
    integer model_count = 0;
    reg [DATA_WIDTH-1:0] expected_data;
    reg expected_read;
    reg expected_write;

    synchronous_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty),
        .count(count)
    );

    always #5 clk = ~clk;

    task check_status;
        begin
            tests = tests + 1;
            if (count !== model_count[COUNT_WIDTH-1:0]) begin
                $display("ERROR: count mismatch at %0t: DUT=%0d MODEL=%0d",
                         $time, count, model_count);
                errors = errors + 1;
            end
            if (full !== (model_count == DEPTH)) begin
                $display("ERROR: full mismatch at %0t", $time);
                errors = errors + 1;
            end
            if (empty !== (model_count == 0)) begin
                $display("ERROR: empty mismatch at %0t", $time);
                errors = errors + 1;
            end
        end
    endtask

    // Drive on falling edge, check results after next rising edge.
    task transact;
        input write_req;
        input read_req;
        input [DATA_WIDTH-1:0] write_data;
        begin
            @(negedge clk);
            wr_en = write_req;
            rd_en = read_req;
            din = write_data;

            expected_write = write_req && (model_count < DEPTH);
            expected_read  = read_req && (model_count > 0);

            if (expected_read) begin
                expected_data = model_mem[model_rd];
                model_rd = (model_rd + 1) % (DEPTH*4);
            end

            if (expected_write) begin
                model_mem[model_wr] = write_data;
                model_wr = (model_wr + 1) % (DEPTH*4);
            end

            if (expected_write && !expected_read)
                model_count = model_count + 1;
            else if (!expected_write && expected_read)
                model_count = model_count - 1;

            @(posedge clk);
            #1;
            if (expected_read && dout !== expected_data) begin
                $display("ERROR: data mismatch at %0t: expected=0x%02h got=0x%02h",
                         $time, expected_data, dout);
                errors = errors + 1;
            end
            check_status();
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst = 1'b1;
            wr_en = 1'b0;
            rd_en = 1'b0;
            din = 0;
            @(posedge clk);
            #1;
            model_wr = 0;
            model_rd = 0;
            model_count = 0;
            check_status();
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("fifo_waveform.vcd");
        $dumpvars(0, tb_synchronous_fifo);

        reset_dut();

        // Test 1: reads while empty must be ignored.
        transact(1'b0, 1'b1, 8'h00);
        transact(1'b0, 1'b1, 8'h00);

        // Test 2: fill to capacity, then attempt an overflow write.
        for (i = 0; i < DEPTH; i = i + 1)
            transact(1'b1, 1'b0, i[7:0]);
        transact(1'b1, 1'b0, 8'hEE);

        // Test 3: drain and verify FIFO ordering, then attempt underflow.
        for (i = 0; i < DEPTH; i = i + 1)
            transact(1'b0, 1'b1, 8'h00);
        transact(1'b0, 1'b1, 8'h00);

        // Test 4: simultaneous read/write while partially occupied.
        for (i = 0; i < 6; i = i + 1)
            transact(1'b1, 1'b0, (8'h40 + i));
        for (i = 0; i < 10; i = i + 1)
            transact(1'b1, 1'b1, (8'hA0 + i));
        for (i = 0; i < DEPTH; i = i + 1)
            transact(1'b0, 1'b1, 8'h00);

        // Test 5: randomized traffic; deterministic seed for repeatability.
        for (i = 0; i < 500; i = i + 1) begin
            n = $random(seed);
            transact(n[0], n[1], n[15:8]);
        end

        // Drain any remaining model contents.
        while (model_count > 0)
            transact(1'b0, 1'b1, 8'h00);

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;

        $display("----------------------------------------");
        $display("FIFO TEST SUMMARY");
        $display("Checks performed: %0d", tests);
        $display("Errors:           %0d", errors);
        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("----------------------------------------");
        $finish;
    end

endmodule
