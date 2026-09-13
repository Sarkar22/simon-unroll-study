#!/usr/bin/env bash
# Verify simon_enc against model vectors at several unroll factors.
set -e
cd "$(dirname "$0")/.."

VARIANT="${VARIANT:-128_128}"
echo ">> regenerating model (consts + vectors) for SIMON $VARIANT"
python3 model/simon_model.py --variant "$VARIANT" | tail -2

for U in 1 2 3 4 5 6 7 8 9 10 11 12 17 34 68; do
    iverilog -g2012 -DUNROLL=$U -I rtl -o sim/sim_u$U.vvp rtl/simon_enc.sv tb/tb_simon.sv 2>/dev/null
    vvp sim/sim_u$U.vvp +vec=sim/vectors.hex | grep -E "TEST (PASSED|FAILED)"
done
