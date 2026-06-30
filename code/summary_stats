#!/bin/bash

SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation/"
MASK_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/"

OUT_FILE="${OUTPUT_DIR}/roi_mean_sd.txt"

declare -A ROI_MASKS
ROI_MASKS[mPFC]="${MASK_DIR}/mPFC_mask.nii.gz"
ROI_MASKS[NAcc]="${MASK_DIR}/NAcc_mask.nii.gz"

TASKS=(MIDA MIDC DOORS GRT)
ROIS=(mPFC NAcc)

printf "task\troi\tmean\tsd\tn\n" > ${OUT_FILE}

for TASK in "${TASKS[@]}"; do
    DATA="${SCRATCH_DIR}/all_${TASK}.nii.gz"
    if [ ! -f "${DATA}" ]; then
        echo "Missing ${DATA}, skipping"
        continue
    fi

    for ROI in "${ROIS[@]}"; do
        MASK=${ROI_MASKS[$ROI]}
        if [ ! -f "${MASK}" ]; then
            echo "Missing mask ${MASK}, skipping"
            continue
        fi

        VALS="${SCRATCH_DIR}/${TASK}_${ROI}_vals.txt"
        fslmeants -i ${DATA} -m ${MASK} -o ${VALS}

        awk -v task="${TASK}" -v roi="${ROI}" \
            '{s+=$1; ss+=$1*$1; n++}
             END {m=s/n; sd=sqrt((ss-n*m*m)/(n-1));
                  printf "%s\t%s\t%.4f\t%.4f\t%d\n", task, roi, m, sd, n}' \
            ${VALS} >> ${OUT_FILE}
    done
done

echo "Wrote ${OUT_FILE}"
cat ${OUT_FILE}