#!/usr/bin/env python3
"""Activation/deactivation figures from randomise tfce outputs."""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from nilearn import image, plotting
from nilearn.plotting import cm

BASE = "/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation"
TASKS = ["MIDA", "MIDC", "DOORS", "GRT"]
PTHR = 0.95   # 1 - p corrected
N_CUTS = 7

FIG_DIR = os.path.join(BASE, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

def thr_map(task, idx):
    pre = os.path.join(BASE, task, f"{task}_group_")
    corrp = image.load_img(f"{pre}_tfce_corrp_tstat{idx}.nii.gz")
    tmap = image.load_img(f"{pre}_tstat{idx}.nii.gz")
    return image.math_img(f"t * (c >= {PTHR})", t=tmap, c=corrp)

def plot_one(img, ax, title, cmap):
    if not np.any(img.get_fdata() != 0):
        ax.set_title(f"{title} (no sig voxels)")
        ax.axis("off")
        return
    plotting.plot_stat_map(img, display_mode="z", cut_coords=N_CUTS,
                           threshold=1e-6, cmap=cmap, title=title, axes=ax)

for task in TASKS:
    print(f"Plotting {task}")
    fig, axes = plt.subplots(2, 1, figsize=(12, 6))
    plot_one(thr_map(task, 1), axes[0], f"{task} activation", cm.red_transparent)
    plot_one(thr_map(task, 2), axes[1], f"{task} deactivation", cm.blue_transparent)
    out = os.path.join(FIG_DIR, f"{task}_activation.png")
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}")

print("Done")