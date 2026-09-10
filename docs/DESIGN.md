# Design notes — SIMON area/throughput core

## 1. SIMON in brief
SIMON is a family of lightweight Feistel block ciphers (NSA, 2013). Block = 2n bits,
key = m·n bits, T rounds. The default here is **SIMON128/128**: n=64, m=2, T=68.

**Round function** (state words x=upper, y=lower; round key k_i):
```
x, y  <-  ( y XOR (ROL(x,1) AND ROL(x,8)) XOR ROL(x,2) XOR k_i ),  x
```
Only AND, XOR and constant rotations — no S-box, no arithmetic. This is what makes the
serial↔parallel area/throughput study clean and the verification trivially bit-exact.

**Key schedule** (m key words, z-sequence j, constant on the low two bits):
```
k_i = ~k_{i-m}  XOR  (I XOR ROR1)(ROR3(k_{i-1}) [XOR k_{i-3} if m==4])  XOR  z[j][i-m] XOR 3
```
(The `~` plus the `XOR 3` realises the spec constant 2^n−4 on the word.)

## 2. Verification chain
`model/simon_model.py` implements SIMON and **self-checks against the official test
vectors** (32/64, 64/128, 128/128) before emitting anything. It generates:
- `rtl/simon_consts.svh` — variant params + `GZSEQ` (the per-round key-gen z bits),
- `sim/vectors.hex` — official + 200 deterministic pseudo-random (key, pt, ct) triples.
The RTL reuses these constants, so passing `sim/vectors.hex` proves RTL == spec.

## 3. On-the-fly key scheduling (the subtle part)
A fixed M-word shift register `KR`; round r consumes `KR[M-1]`; each round a new key is
generated from `KR[0]` (=k_{r+M-1}) and `KR[M-1]` (=k_r) and pushed in at index 0:
```
rk      = KR[M-1]
tmp     = ROR3(KR[0]) [XOR KR[M-2] if M==4];  tmp ^= ROR1(tmp)
newkey  = ~KR[M-1] ^ tmp ^ GZSEQ[r] ^ 3
KR      <- { newkey, KR[0..M-2] }      // shift; KR[M-1] drops
```
Initialised with the master key words so the first M rounds consume them directly.
This exact recurrence was validated in Python against the model for m=2 and m=4 before
being committed to RTL (the easy bug: forgetting to *advance* the window in the last M
rounds when no new key is generated).

## 4. The unroll knob
`UNROLL=U` instantiates U copies of {round + key-gen} combinationally per cycle; an FSM
runs `ceil(T/U)` cycles per block. A per-step `active = (round < T)` guard makes any U
correct even when U∤T. Thus one parameter sweeps:
- **area** ∝ U (more combinational round logic),
- **latency** = ceil(T/U) (+ load/done overhead),
- **F_max** decreases as U grows (longer combinational round chain),
- **throughput** = BLK · F_max / cycles_per_block — the headline trade-off curve.

## 5. What the paper measures
- Area (LUT/FF), F_max, power vs U on KV260 (place&route).
- Throughput (Mb/s) and **area-efficiency (Mbps/LUT)** vs U; pick the knee.
- Comparison vs an AES-128 core on the same part (lightweight-vs-standard cipher).
- Zero DSP / zero BRAM at every U (pure logic) — fits IoT endpoints.
