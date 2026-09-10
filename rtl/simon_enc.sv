/*
 * simon_enc.sv -- SIMON block-cipher encryption core with a round-unroll knob.
 *
 * One architectural parameter, UNROLL (U), spans the area/throughput trade-off:
 *   U=1   : iterative, 1 round/cycle, T cycles/block   (smallest)
 *   U=k   : k rounds/cycle, ceil(T/k) cycles/block
 *   U=T   : single-cycle (combinational rounds)         (fastest, largest)
 *
 * On-the-fly key scheduling: an M-word shift register; round r uses KR[M-1],
 * the next key enters at index 0. Verified bit-exact against model/simon_model.py
 * (which matches the official SIMON test vectors).
 *
 * Variant (N,M,T,GZSEQ) comes from rtl/simon_consts.svh (generated).
 * Block/key I/O are flat vectors; {x,y} = i_block with x = upper N bits.
 */
`timescale 1ns/1ps
module simon_enc #(
    parameter int UNROLL = 1
) (
    input  logic              clk,
    input  logic              rst,
    input  logic [255:0]      i_key,    // low KEYW bits used
    input  logic [255:0]      i_block,  // low BLK  bits used  (x=upper, y=lower)
    input  logic              i_valid,
    output logic              o_ready,
    output logic [255:0]      o_ct,
    output logic              o_valid,
    input  logic              i_ready
);
    `include "simon_consts.svh"

    localparam int CW = $clog2(T + UNROLL + 1);

    function automatic logic [N-1:0] rotl(input logic [N-1:0] a, input int k);
        rotl = (a << k) | (a >> (N - k));
    endfunction
    function automatic logic [N-1:0] rotr(input logic [N-1:0] a, input int k);
        rotr = (a >> k) | (a << (N - k));
    endfunction

    logic [N-1:0] x_q, y_q;
    logic [N-1:0] kr_q [0:M-1];
    logic [CW-1:0] cnt_q;
    typedef enum logic [1:0] {IDLE, BUSY, DONE} st_t;
    st_t st_q;

    assign o_ready = (st_q == IDLE);
    assign o_valid = (st_q == DONE);
    assign o_ct    = {{(256-BLK){1'b0}}, x_q, y_q};

    // ---- combinational UNROLL-round chain ----
    logic [N-1:0] sx [0:UNROLL];
    logic [N-1:0] sy [0:UNROLL];
    logic [N-1:0] sk [0:UNROLL][0:M-1];
    // shared combinational temporaries (loop is elaboration-unrolled)
    logic [CW-1:0] rnd;
    logic          active, zb;
    logic [N-1:0]  rk, fx, nx, tmp, newk;
    integer s, t;

    always_comb begin
        sx[0] = x_q; sy[0] = y_q;
        for (t = 0; t < M; t++) sk[0][t] = kr_q[t];
        for (s = 0; s < UNROLL; s++) begin
            rnd    = cnt_q + s[CW-1:0];
            active = (rnd < T[CW-1:0]);
            rk     = sk[s][M-1];
            fx     = (rotl(sx[s],1) & rotl(sx[s],8)) ^ rotl(sx[s],2);
            nx     = sy[s] ^ fx ^ rk;
            sx[s+1] = active ? nx    : sx[s];
            sy[s+1] = active ? sx[s] : sy[s];
            // on-the-fly next round key
            tmp = rotr(sk[s][0], 3);
            if (M == 4) tmp = tmp ^ sk[s][M-2];
            tmp = tmp ^ rotr(tmp, 1);
            zb  = active ? GZSEQ[rnd] : 1'b0;
            newk = (~sk[s][M-1]) ^ tmp ^ {{(N-1){1'b0}}, zb} ^ {{(N-2){1'b0}}, 2'b11};
            sk[s+1][0] = active ? newk : sk[s][0];
            for (t = 1; t < M; t++)
                sk[s+1][t] = active ? sk[s][t-1] : sk[s][t];
        end
    end

    // ---- sequential control ----
    integer u;
    always_ff @(posedge clk) begin
        if (rst) begin
            st_q <= IDLE; cnt_q <= '0; x_q <= '0; y_q <= '0;
            for (u = 0; u < M; u++) kr_q[u] <= '0;
        end else begin
            case (st_q)
                IDLE: if (i_valid) begin
                    x_q <= i_block[BLK-1 -: N];
                    y_q <= i_block[N-1 : 0];
                    for (u = 0; u < M; u++) kr_q[u] <= i_key[(M-1-u)*N +: N];
                    cnt_q <= '0; st_q <= BUSY;
                end
                BUSY: begin
                    x_q <= sx[UNROLL]; y_q <= sy[UNROLL];
                    for (u = 0; u < M; u++) kr_q[u] <= sk[UNROLL][u];
                    cnt_q <= cnt_q + UNROLL[CW-1:0];
                    if ((cnt_q + UNROLL[CW-1:0]) >= T[CW-1:0]) st_q <= DONE;
                end
                DONE: if (i_ready) st_q <= IDLE;
                default: st_q <= IDLE;
            endcase
        end
    end
endmodule
