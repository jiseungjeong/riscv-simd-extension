#!/usr/bin/env python3
"""
MNIST Benchmark Visualization
Generates a horizontal bar chart comparing Scalar vs Vector implementations
With overlay showing PVMAC improvement from 1-mul to 4-mul
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# Data from BENCHMARK_RESULTS.md (4 Multipliers - Fair Comparison)
implementations = [
    "VMAC.B\n(8 lanes, 3 cyc)",
    "PVMAC\n(4 lanes, 2 cyc)",
    "VMAC.H\n(4 lanes, 2 cyc)",
    "VMAC.W\n(2 lanes, 2 cyc)",
    "Scalar\n(1 lane)",
]
cycles_new = [176794, 256194, 345290, 688322, 916946]
speedups_new = [5.19, 3.58, 2.66, 1.33, 1.00]

# Old PVMAC (1 multiplier) for overlay
cycles_old_pvmac = 275250

# Colors from user's palette
colors = [
    "#4269D0",  # VMAC.B - blue
    "#EFB118",  # PVMAC - yellow/orange
    "#FF725C",  # VMAC.H - coral
    "#6CC5B0",  # VMAC.W - mint
    "#9498A0",  # Scalar - gray
]

# Create figure
fig, ax = plt.subplots(figsize=(12, 7))

# Create horizontal bar chart
bars = ax.barh(
    implementations, cycles_new, color=colors, edgecolor="black", linewidth=1.2
)

# Add overlay for old PVMAC (1 multiplier) - transparent bar on top of PVMAC
pvmac_idx = 1  # PVMAC is at index 1
old_pvmac_bar = ax.barh(
    implementations[pvmac_idx],
    cycles_old_pvmac,
    color="none",
    edgecolor="#8B4513",  # brown edge
    linewidth=3,
    linestyle="--",
    height=0.5,
    left=0,
)

# Add cycle count labels on bars (format: "### cycles\n(배수×)")
for i, (bar, cycle, speedup) in enumerate(zip(bars, cycles_new, speedups_new)):
    width = bar.get_width()
    ax.text(
        width + 20000,
        bar.get_y() + bar.get_height() / 2,
        f"{cycle:,} cycles\n({speedup:.2f}×)",
        va="center",
        ha="left",
        fontsize=11,
        fontweight="bold",
    )

# Labels and title
ax.set_xlabel("Cycles (lower is better)", fontsize=14, fontweight="bold")
ax.set_title(
    "MNIST MLP Inference Performance (4 Multipliers)\n(784→32→10, Single Image)",
    fontsize=16,
    fontweight="bold",
)

# Set x-axis limits and format
ax.set_xlim(0, 1150000)
ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f"{x/1000:.0f}K"))

# Add grid for readability
ax.xaxis.grid(True, linestyle="--", alpha=0.7)
ax.set_axisbelow(True)

# Add a legend for SEW
legend_elements = [
    mpatches.Patch(facecolor="#4269D0", edgecolor="black", label="SEW=8 (VMAC.B)"),
    mpatches.Patch(
        facecolor="#EFB118", edgecolor="black", label="PVMAC (4 mul, 2 cyc)"
    ),
    mpatches.Patch(
        facecolor="none",
        edgecolor="#8B4513",
        linestyle="--",
        linewidth=2,
        label="PVMAC (1 mul, 5 cyc) - Lab 7",
    ),
    mpatches.Patch(facecolor="#FF725C", edgecolor="black", label="SEW=16 (VMAC.H)"),
    mpatches.Patch(facecolor="#6CC5B0", edgecolor="black", label="SEW=32 (VMAC.W)"),
    mpatches.Patch(facecolor="#9498A0", edgecolor="black", label="Scalar (baseline)"),
]
ax.legend(handles=legend_elements, loc="lower right", fontsize=9)

# Tight layout
plt.tight_layout()

# Save figure
plt.savefig("mnist_benchmark.png", dpi=150, bbox_inches="tight")
plt.savefig("mnist_benchmark.pdf", bbox_inches="tight")
print("Saved: mnist_benchmark.png, mnist_benchmark.pdf")

# Show plot
plt.show()
