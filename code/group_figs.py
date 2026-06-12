#!/usr/bin/env python3
"""Act/deact montages from randomise tfce outputs (nibabel/matplotlib)."""
import os
import numpy as np
import nibabel as nib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = "/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation"
TASKS = ["MIDA", "MIDC", "DOORS", "GRT"]
PTHR = 0.95
N_CUTS = 7

FIG_DIR = os.path.join(BASE, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

# Anatomical background from FSL, if dims match
bg_path = os.path.join(os.environ.get("FSLDIR", ""), "data/standard/MNI152_T1_2mm_brain.nii.gz")
bg = nib.load(bg_path).get_fdata() if os.path.isfile(bg_path) else None

def load_thr(task, idx):
    pre = os.path.join(BASE, task, f"{task}_group_")
    t = nib.load(f"{pre}_tstat{idx}.nii.gz").get_fdata()
    c = nib.load(f"{pre}_tfce_corrp_tstat{idx}.nii.gz").get_fdata()
    return np.where(c >= PTHR, t, np.nan)

def draw_row(ax_row, stat, cmap_name):
    cmap = plt.get_cmap(cmap_name).copy()
    cmap.set_bad(alpha=0)
    use_bg = bg is not None and bg.shape == stat.shape
    z0, z1 = int(stat.shape[2]*0.28), int(stat.shape[2]*0.78)
    zs = np.linspace(z0, z1, N_CUTS).astype(int)
    finite = stat[np.isfinite(stat)]
    vmax = np.nanpercentile(finite, 99) if finite.size else 1
    for ax, z in zip(ax_row, zs):
        if use_bg:
            ax.imshow(np.rot90(bg[:, :, z]), cmap="gray", origin="upper")
        ax.imshow(np.rot90(stat[:, :, z]), cmap=cmap, vmin=0, vmax=vmax, origin="upper")
        ax.axis("off")

for task in TASKS:
    print(f"Plotting {task}")
    fig, axes = plt.subplots(2, N_CUTS, figsize=(2*N_CUTS, 5))
    draw_row(axes[0], load_thr(task, 1), "hot")
    draw_row(axes[1], load_thr(task, 2), "cool")
    axes[0, 0].set_title(f"{task} activation", loc="left")
    axes[1, 0].set_title(f"{task} deactivation", loc="left")
    out = os.path.join(FIG_DIR, f"{task}_activation.png")
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}")

print("Done")