#!/usr/bin/env python3
"""Pairwise comparison montages from randomise tfce outputs."""
import os
import numpy as np
import nibabel as nib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = "/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/repeated"
PTHR = 0.95
N_CUTS = 7

FIG_DIR = os.path.join(BASE, "figures")
os.makedirs(FIG_DIR, exist_ok=True)

BG_PATH = "/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation/figures/mni_bg.nii.gz"
bg = nib.load(BG_PATH).get_fdata() if os.path.isfile(BG_PATH) else None

PAIRS = sorted(d for d in os.listdir(BASE)
               if "_vs_" in d and os.path.isdir(os.path.join(BASE, d)))

def load_thr(pair, idx):
    pre = os.path.join(BASE, pair, f"{pair}_")
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

for pair in PAIRS:
    t1, t2 = pair.split("_vs_")
    d1 = load_thr(pair, 1)
    d2 = load_thr(pair, 2)
    n1, n2 = int(np.isfinite(d1).sum()), int(np.isfinite(d2).sum())
    has_bg = bg is not None and bg.shape == d1.shape
    print(f"{pair}: dims {d1.shape}, {t1}>{t2} sig {n1}, {t2}>{t1} sig {n2}, bg {'yes' if has_bg else 'no'}")
    zs = pick_slices([d1, d2])
    fig, axes = plt.subplots(2, N_CUTS, figsize=(2*N_CUTS, 5))
    draw_row(axes[0], d1, zs, "hot")
    draw_row(axes[1], d2, zs, "cool")
    axes[0, 0].set_title(f"{t1} > {t2}", loc="left")
    axes[1, 0].set_title(f"{t2} > {t1}", loc="left")
    out = os.path.join(FIG_DIR, f"{pair}.png")
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}")

print("Done")