#!/bin/bash

MASK_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/"
REF="${MASK_DIR}/resliced_mask.nii.gz"
STD="${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz"
ATLAS="${FSLDIR}/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr25-2mm.nii.gz"
TMP="${MASK_DIR}/tmp_mask"

mkdir -p ${TMP}

# NAcc: HO subcortical labels 11 (L) + 21 (R)
fslmaths ${ATLAS} -thr 11 -uthr 11 -bin ${TMP}/nacc_L
fslmaths ${ATLAS} -thr 21 -uthr 21 -bin ${TMP}/nacc_R
fslmaths ${TMP}/nacc_L -add ${TMP}/nacc_R -bin ${TMP}/NAcc_std

# mPFC: 8mm sphere at MNI 0 46 -8
read VX VY VZ <<< $(echo "0 46 -8" | std2imgcoord -img ${STD} -std ${STD} -vox -)
VX=${VX%.*}; VY=${VY%.*}; VZ=${VZ%.*}
fslmaths ${STD} -mul 0 -add 1 -roi ${VX} 1 ${VY} 1 ${VZ} 1 0 1 ${TMP}/point
fslmaths ${TMP}/point -kernel sphere 8 -fmean -bin ${TMP}/mPFC_std -odt float

# Reslice both onto the con grid
flirt -in ${TMP}/NAcc_std -ref ${REF} -applyxfm -usesqform \
      -interp nearestneighbour -out ${MASK_DIR}/NAcc_mask
flirt -in ${TMP}/mPFC_std -ref ${REF} -applyxfm -usesqform \
      -interp nearestneighbour -out ${MASK_DIR}/mPFC_mask

fslmaths ${MASK_DIR}/NAcc_mask -bin ${MASK_DIR}/NAcc_mask
fslmaths ${MASK_DIR}/mPFC_mask -bin ${MASK_DIR}/mPFC_mask

echo "NAcc voxels:"; fslstats ${MASK_DIR}/NAcc_mask -V
echo "mPFC voxels:"; fslstats ${MASK_DIR}/mPFC_mask -V

rm -rf ${TMP}
echo "Masks written to ${MASK_DIR}"