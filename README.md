# SIMON128/128 Round-Unrolling Study

One SIMON block-cipher core whose round-unroll factor `U` sweeps the area/throughput trade-off, with an on-the-fly key schedule and zero DSP / zero BRAM. The study shows the throughput optimum is a **plateau**, not a peak.

This is the artifact for a paper submitted to **IEEE CCECE 2027** (under review). Every
number below is reproduced by the scripts in this repository.

## Results

- Golden model matches the **official SIMON test vectors** (32/64, 64/128, 128/128)
- RTL bit-exact to the model over 201 vectors at 15 unroll factors, U = 1..12, 17, 34, 68, including nine that do not divide the 68 rounds
- Critical-path law T_clk(U) = 0.860 + 0.436·U ns (R² = 0.985), predicting U* ≈ 8.2
- Measured plateau: U = 5..10 all within 3% of peak throughput (2.79 Gb/s at U=5); U=10 costs 1.84× the area of U=5 for the same throughput
- A sweep restricted to divisors of the round count (U = 1, 2, 4, 17, 34, 68) misses the plateau and reports a spurious optimum at U=4, 5% below peak
- sky130 ASIC at U = 1, 2, 4: all DRC clean and LVS clean

## Reproducing

```bash
bash sim/run_sim.sh   # official + random vectors at all 15 unroll factors
```
```bash
PART=xck26-sfvc784-2LV-c bash synth/run_synth.sh   # area / throughput sweep
```
```bash
python3 model/unroll_law.py   # fit and validate the delay law
```

```bash
OPENLANE_DIR=/path/to/OpenLane DESIGN=simon_u1 bash asic/run_asic.sh   # sky130 RTL-to-GDSII
```

The `asic/` directory holds the OpenLane configuration for each
signed-off configuration; the flow itself is third-party (see Requirements).

## Requirements

Third-party tools, not included here. Any recent version should work; these are what the
reported numbers were produced with.

| tool | used | purpose |
|---|---|---|
| Icarus Verilog | 12.0 | simulation (`iverilog -g2012`) |
| Python 3 | 3.12 + numpy (matplotlib for figures) | golden models and analysis |
| AMD Vivado | 2024.2 | FPGA synthesis and place-and-route |
| OpenLane | v1.0.2, sky130A PDK | open-source RTL-to-GDSII |

## Layout

```
model/    Python golden model: the executable specification, and the analysis scripts
rtl/      synthesizable SystemVerilog
tb/       self-checking testbenches
sim/      one-command verification
synth/    Vivado scripts (constraints, sweeps, reporting)
results/  measured CSVs and the figures generated from them
```

## Notes

The pipelined AES-128 core used as a size reference in the paper is the author's separate [aes](https://github.com/Sarkar22/aes) project and is not duplicated here.

Note that SIMON and SPECK were proposed for ISO/IEC 29192-2, whose published edition specifies PRESENT and CLEFIA (per NIST IR 8114), and NIST's lightweight-cryptography process later selected Ascon. The unrolling methodology ports directly to PRESENT.

## License

MIT, see [LICENSE](LICENSE).
