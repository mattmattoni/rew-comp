#!/usr/bin/env python3
"""Act/deact montages from randomise tfce outputs."""
import os
import numpy as np
import nibabel as nib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = "/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation"
TASKS = ["GRT"]
PTHR = 0.95
N_CUTS = 7

FIG_DIR = os.path.join(BASE, "figures", "GRT_test")
os.makedirs(FIG_DIR, exist_ok=True)

BG_PATH = os.path.join(FIG_DIR, "mni_bg.nii.gz")
bg = nib.load(BG_PATH).get_fdata() if os.path.isfile(BG_PATH) else None

def load_thr(task, idx):
    pre = os.path.join(BASE, task, f"{task}_group_")
    t = nib.load(f"{pre}_tstat{idx}.nii.gz").get_fdata()
    c = nib.load(f"{pre}_tfce_corrp_tstat{idx}.nii.gz").get_fdata()
    return np.where(c >= PTHR, t, np.nan)

def pick_slices(masks):
    sig = np.zeros(masks[0].shape, bool)
    for m in masks:
        sig |= np.isfinite(m)
    zsig = np.where(sig.any(axis=(0, 1)))[0]
    if zsig.size == 0:
        z0, z1 = int(sig.shape[2]*0.3), int(sig.shape[2]*0.75)
        return np.linspace(z0, z1, N_CUTS).astype(int)
    return np.linspace(zsig.min(), zsig.max(), N_CUTS).astype(int)

def draw_row(ax_row, stat, zs, cmap_name):
    cmap = plt.get_cmap(cmap_name).copy()
    cmap.set_bad(alpha=0)
    use_bg = bg is not None and bg.shape == stat.shape
    finite = stat[np.isfinite(stat)]
    vmax = np.nanpercentile(finite, 99) if finite.size else 1
    for ax, z in zip(ax_row, zs):
        if use_bg:
            ax.imshow(np.rot90(bg[:, :, z]), cmap="gray", origin="upper")
        ax.imshow(np.rot90(stat[:, :, z]), cmap=cmap, vmin=0, vmax=vmax, origin="upper")
        ax.axis("off")

for task in TASKS:
    act = load_thr(task, 1)
    deact = load_thr(task, 2)
    na, nd = int(np.isfinite(act).sum()), int(np.isfinite(deact).sum())
    has_bg = bg is not None and bg.shape == act.shape
    print(f"{task}: dims {act.shape}, act sig {na}, deact sig {nd}, bg {'yes' if has_bg else 'no'}")
    zs = pick_slices([act, deact])
    fig, axes = plt.subplots(2, N_CUTS, figsize=(2*N_CUTS, 5))
    draw_row(axes[0], act, zs, "hot")
    draw_row(axes[1], deact, zs, "cool")
    axes[0, 0].set_title(f"{task} activation", loc="left")
    axes[1, 0].set_title(f"{task} deactivation", loc="left")
    out = os.path.join(FIG_DIR, f"{task}_activation.png")
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}")

print("Done")