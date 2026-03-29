#!/bin/bash

# Dirs
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/"
VIZ_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/visualizations/"

# Create visualization directory
mkdir -p ${VIZ_DIR}

# Standard brain for underlay
UNDERLAY="$FSLDIR/data/standard/MNI152_T1_2mm_brain"

echo "Creating visualization images..."

w# Group Activation Visualizations
echo "Processing group activations..."

GROUP_DIR="${OUTPUT_DIR}/group_activation"
TASKS=(MIDA MIDC DOORS GRT)

for TASK in "${TASKS[@]}"; do
    TASK_DIR="${GROUP_DIR}/${TASK}"
    CORRP_FILE="${TASK_DIR}/${TASK}_group_clustere_corrp_tstat1.nii.gz"
    TSTAT_FILE="${TASK_DIR}/${TASK}_group_tstat1.nii.gz"
    
    if [ -f "${CORRP_FILE}" ]; then
        echo "Creating visualization for ${TASK} group activation..."
        
        # Threshold corrected p-values at p < 0.05 (corrp > 0.95)
        fslmaths ${CORRP_FILE} -thr 0.95 -bin ${VIZ_DIR}/${TASK}_sig_mask.nii.gz
        
        # Mask t-stats by significant voxels
        fslmaths ${TSTAT_FILE} -mas ${VIZ_DIR}/${TASK}_sig_mask.nii.gz ${VIZ_DIR}/${TASK}_sig_tstats.nii.gz
        
        # Create image (axial slices)
        slicer ${UNDERLAY} ${VIZ_DIR}/${TASK}_sig_tstats.nii.gz \
               -l /usr/share/fsl/5.0/etc/luts/renderjet.lut \
               -a ${VIZ_DIR}/${TASK}_activation.png
        
        echo "Saved: ${VIZ_DIR}/${TASK}_activation.png"
    else
        echo "Warning: ${CORRP_FILE} not found, skipping..."
    fi
done


echo "Processing pairwise comparisons..."
# All pairwise combinations
COMPARISONS=(
    "MIDA_vs_MIDC"
    "MIDA_vs_DOORS"
    "MIDA_vs_GRT"
    "MIDC_vs_DOORS"
    "MIDC_vs_GRT"
    "DOORS_vs_GRT"
)

for COMP in "${COMPARISONS[@]}"; do
    COMP_DIR="${OUTPUT_DIR}/${COMP}"
    
    # Extract task names
    TASK1=$(echo $COMP | cut -d'_' -f1)
    TASK2=$(echo $COMP | cut -d'_' -f3)
    
    # Contrast 1: TASK1 > TASK2
    CORRP1="${COMP_DIR}/${COMP}_clustere_corrp_tstat1.nii.gz"
    TSTAT1="${COMP_DIR}/${COMP}_tstat1.nii.gz"
    
    if [ -f "${CORRP1}" ]; then
        echo "Creating visualization for ${TASK1} > ${TASK2}..."
        
        # Threshold and mask
        fslmaths ${CORRP1} -thr 0.95 -bin ${VIZ_DIR}/${COMP}_contrast1_mask.nii.gz
        fslmaths ${TSTAT1} -mas ${VIZ_DIR}/${COMP}_contrast1_mask.nii.gz ${VIZ_DIR}/${COMP}_contrast1_tstats.nii.gz
        
        # Create image
        slicer ${UNDERLAY} ${VIZ_DIR}/${COMP}_contrast1_tstats.nii.gz \
               -l /usr/share/fsl/5.0/etc/luts/renderjet.lut \
               -a ${VIZ_DIR}/${COMP}_${TASK1}_gt_${TASK2}.png
        
        echo "Saved: ${VIZ_DIR}/${COMP}_${TASK1}_gt_${TASK2}.png"
    fi
    
    # Contrast 2: TASK2 > TASK1
    CORRP2="${COMP_DIR}/${COMP}_clustere_corrp_tstat2.nii.gz"
    TSTAT2="${COMP_DIR}/${COMP}_tstat2.nii.gz"
    
    if [ -f "${CORRP2}" ]; then
        echo "Creating visualization for ${TASK2} > ${TASK1}..."
        
        # Threshold and mask
        fslmaths ${CORRP2} -thr 0.95 -bin ${VIZ_DIR}/${COMP}_contrast2_mask.nii.gz
        fslmaths ${TSTAT2} -mas ${VIZ_DIR}/${COMP}_contrast2_mask.nii.gz ${VIZ_DIR}/${COMP}_contrast2_tstats.nii.gz
        
        # Create image
        slicer ${UNDERLAY} ${VIZ_DIR}/${COMP}_contrast2_tstats.nii.gz \
               -l /usr/share/fsl/5.0/etc/luts/renderjet.lut \
               -a ${VIZ_DIR}/${COMP}_${TASK2}_gt_${TASK1}.png
        
        echo "Saved: ${VIZ_DIR}/${COMP}_${TASK2}_gt_${TASK1}.png"
    fi
done

# Clean up temporary mask files
echo "Cleaning up temporary files..."
rm -f ${VIZ_DIR}/*_mask.nii.gz

echo "Images saved in: ${VIZ_DIR}"
