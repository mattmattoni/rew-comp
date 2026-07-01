#!/bin/bash

SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation/"
MASK_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/"
SUBLIST="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/sublist.txt"

declare -A ROI_MASKS
ROI_MASKS[mPFC]="${MASK_DIR}/mPFC_mask.nii.gz"
ROI_MASKS[NAcc]="${MASK_DIR}/NAcc_mask.nii.gz"

TASKS=(MIDA MIDC DOORS GRT)
ROIS=(mPFC NAcc)

for TASK in "${TASKS[@]}"; do
    DATA="${SCRATCH_DIR}/all_${TASK}.nii.gz"
    [ ! -f "${DATA}" ] && { echo "Missing ${DATA}, skipping"; continue; }

    for ROI in "${ROIS[@]}"; do
        MASK=${ROI_MASKS[$ROI]}
        VALS="${SCRATCH_DIR}/${TASK}_${ROI}_vals.txt"
        OUT="${OUTPUT_DIR}/${TASK}_${ROI}_persubj.txt"

        fslmeants -i ${DATA} -m ${MASK} -o ${VALS}

        printf "subj\tactivation\n" > ${OUT}
        paste ${SUBLIST} ${VALS} | sort -k2 -g >> ${OUT}
    done
done

echo "Per-subject tables in ${OUTPUT_DIR}"
echo "--- GRT mPFC (sorted) ---"
cat ${OUTPUT_DIR}/GRT_mPFC_persubj.txt