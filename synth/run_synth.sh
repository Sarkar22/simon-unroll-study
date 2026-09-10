#!/usr/bin/env bash
# Sweep the round-unroll factor and synth+impl each on KV260 (UltraScale+).
# Produces results/synth_sweep.csv for the area/throughput trade-off table.
set -e
cd "$(dirname "$0")/.."
PART="${PART:-xck26-sfvc784-2LV-c}"
PERIOD="${PERIOD:-2.0}"
UNROLLS="${UNROLLS:-1 2 4 17 34 68}"

rm -f results/synth_sweep.csv
mkdir -p results/synth
for U in $UNROLLS; do
    echo "######## simon_u$U (part=$PART) ########"
    vivado -mode batch -nojournal -log "results/synth/simon_u${U}.log" \
           -source synth/synth_one.tcl -tclargs "$PART" "$PERIOD" "$U"
done
echo "==== done -> results/synth_sweep.csv ===="
column -t -s, results/synth_sweep.csv
