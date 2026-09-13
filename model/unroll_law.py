#!/usr/bin/env python3
"""
Round-unrolling analysis for the SIMON paper.

Measured densely (U = 1,2,4,5,6,7,8,10,12,17,34,68) on KV260 post-P&R, the picture is:

  1. Clock period grows essentially linearly with U (more rounds per cycle = deeper
     combinational chain):   T_clk(U) ~ t0 + t_r * U
  2. Cycles per block fall as ceil(T/U) + 2.
  3. Their product gives throughput R(U) = BLK / [T_clk(U) * (ceil(T/U)+2)], which does
     NOT have a sharp peak: it rises to a broad PLATEAU and then decays.

Main result: the plateau (all points within a few percent of peak) spans U = 5..10, while
LUT area nearly doubles across it. The design rule is therefore to take the SMALLEST U on
the plateau. A sweep restricted to divisors of T, {1,2,4,17,34,68}, misses the plateau
entirely and reports a spurious optimum at U=4.

Outputs results/figures/fig_law.pdf and the numbers quoted in the paper.
"""
import csv, os, math
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CSV = os.path.join(ROOT, "results", "synth_sweep.csv")
BLK, T = 128, 68
FIT_MAX = 12          # fit the delay model over the practically useful range

rows = sorted(csv.DictReader(open(CSV)), key=lambda r: int(r["unroll"]))
U    = np.array([int(r["unroll"]) for r in rows], dtype=float)
fmax = np.array([float(r["fmax_mhz"]) for r in rows])
lut  = np.array([int(r["lut"]) for r in rows], dtype=float)
period = 1e3 / fmax
cycles = np.ceil(T / U) + 2
tput   = BLK * fmax * 1e6 / cycles / 1e9          # Gb/s
eff    = tput * 1e3 / lut                          # Mbps per LUT

# ---- linear delay model over the useful range ----
m = U <= FIT_MAX
A = np.vstack([np.ones(m.sum()), U[m]]).T
(t0, tr), *_ = np.linalg.lstsq(A, period[m], rcond=None)
pred = t0 + tr * U[m]
r2 = 1 - ((period[m] - pred) ** 2).sum() / ((period[m] - period[m].mean()) ** 2).sum()
U_star = math.sqrt(t0 * T / (2 * tr))              # continuous optimum of the model

# ---- empirical plateau ----
peak_i = int(np.argmax(tput)); peak = tput[peak_i]
TOL = 0.03
plat = U[(tput >= (1 - TOL) * peak)]
lo, hi = plat.min(), plat.max()
i_lo = int(np.where(U == lo)[0][0]); i_hi = int(np.where(U == hi)[0][0])

print(f"delay model (U<={FIT_MAX}):  T_clk = {t0:.3f} + {tr:.3f} U ns   R^2={r2:.4f}")
print(f"model optimum U* = sqrt(t0*T/(2*tr)) = {U_star:.1f}")
print(f"measured peak: U={U[peak_i]:.0f} at {peak:.2f} Gb/s")
print(f"plateau (within {TOL*100:.0f}% of peak): U = {lo:.0f}..{hi:.0f}")
print(f"  at U={lo:.0f}: {tput[i_lo]:.2f} Gb/s, {lut[i_lo]:.0f} LUT, {eff[i_lo]:.2f} Mbps/LUT")
print(f"  at U={hi:.0f}: {tput[i_hi]:.2f} Gb/s, {lut[i_hi]:.0f} LUT, {eff[i_hi]:.2f} Mbps/LUT")
print(f"  -> same throughput ({100*tput[i_hi]/tput[i_lo]:.1f}%) for {lut[i_hi]/lut[i_lo]:.2f}x the area")
print(f"divisor-only sweep {{1,2,4,17,34,68}} reports peak at U=4 "
      f"({tput[list(U).index(4)]:.2f} Gb/s), {100*(peak/tput[list(U).index(4)]-1):.0f}% below the true peak")
print("\n  U    LUT   Fmax   cyc   Gb/s  Mbps/LUT")
for i in range(len(U)):
    print(f"{U[i]:4.0f} {lut[i]:6.0f} {fmax[i]:6.1f} {cycles[i]:5.0f} {tput[i]:6.2f} {eff[i]:8.2f}")

# ---------------------------------------------------------------- figure ------
try:
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except Exception:
    print("\n(matplotlib unavailable; skipping the figure)"); raise SystemExit
C_BLUE, C_ORANGE, INK, MUTED, GRID = "#2a78d6", "#eb6834", "#0b0b0b", "#898781", "#e1e0d9"
plt.rcParams.update({"font.size": 7.5, "axes.edgecolor": "#c3c2b7", "axes.linewidth": 0.6,
                     "xtick.color": MUTED, "ytick.color": MUTED, "text.color": INK,
                     "axes.labelcolor": "#52514e"})
fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.0, 2.35))

uu = np.linspace(1, FIT_MAX, 200)
a1.plot(uu, t0 + tr * uu, color=C_BLUE, lw=1.4,
        label=f"$T_{{clk}}={t0:.2f}+{tr:.3f}U$  ($R^2$={r2:.3f})")
a1.plot(U[m], period[m], "o", ms=4.5, color=C_ORANGE, label="measured", zorder=3)
a1.set_xlabel("unroll factor $U$"); a1.set_ylabel("clock period (ns)")
a1.set_title("Critical path grows linearly with $U$", fontsize=8)
a1.legend(fontsize=6.4, frameon=False, loc="upper left")
for s in ("top", "right"): a1.spines[s].set_visible(False)

a2.axvspan(lo, hi, color=C_BLUE, alpha=0.10, lw=0)
a2.plot(U, tput, "-o", ms=4.5, lw=1.2, color=C_ORANGE, zorder=3, label="measured")
a2.set_xscale("log"); a2.set_xticks([1, 2, 4, 8, 17, 34, 68])
a2.set_xticklabels(["1", "2", "4", "8", "17", "34", "68"])
a2.set_xlabel("unroll factor $U$ (log)"); a2.set_ylabel("throughput (Gb/s)")
a2.set_title(f"Plateau at $U={lo:.0f}$–${hi:.0f}$, not a sharp peak", fontsize=8)
a2.annotate(f"plateau\n$U={lo:.0f}$–${hi:.0f}$", xy=((lo*hi)**0.5, peak*0.55),
            ha="center", fontsize=6.8, color="#52514e")
a2.plot([4], [tput[list(U).index(4)]], "s", ms=5, mfc="none", mec=INK, mew=1.0, zorder=4)
a2.annotate("divisor sweep\nstops here", xy=(4, tput[list(U).index(4)]),
            xytext=(1.25, 1.55), fontsize=6.4, color=INK,
            arrowprops=dict(arrowstyle="->", color=INK, lw=0.7))
for s in ("top", "right"): a2.spines[s].set_visible(False)

fig.tight_layout()
for ext in ("pdf", "png"):
    fig.savefig(os.path.join(ROOT, "results", "figures", f"fig_law.{ext}"), bbox_inches="tight", dpi=400)
print("\nwrote results/figures/fig_law.pdf")
