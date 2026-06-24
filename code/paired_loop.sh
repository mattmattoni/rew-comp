#!/bin/bash

OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/"
SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
LOG_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"
SUBLIST_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"

mkdir -p ${OUTPUT_DIR}
mkdir -p ${SCRATCH_DIR}
mkdir -p ${LOG_DIR}

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/reward_comparison_${TIMESTAMP}.log"
exec > >(tee -a ${LOG_FILE})
exec 2>&1

cd ${SCRATCH_DIR}

declare -A TASK_DIRS
declare -A TASK_CONS
declare -A TASK_SUBLISTS

# Task directories
TASK_DIRS[MIDA]="/mnt/Psych/UIC/FMRI_ANALYSIS_MID/DBBI/GLM_Results/"
TASK_DIRS[MIDC]="/mnt/Psych/UIC/FMRI_ANALYSIS_MID/DBBI/GLM_Results/"
TASK_DIRS[DOORS]="/mnt/Psych/UIC/FMRI_ANALYSIS_DOORS/DBBI/GLM_Results/"
TASK_DIRS[GRT]="/mnt/Psych/UIC/FMRI_ANALYSIS_GRT/DBBI/GLM_Results/"

# Task contrast files
TASK_CONS[MIDA]="con_0010.nii"
TASK_CONS[MIDC]="con_0028.nii"
TASK_CONS[DOORS]="con_0003.nii"
TASK_CONS[GRT]="con_0003.nii"

# Sublist files (MIDA/MIDC share)
TASK_SUBLISTS[MIDA]="sublist.txt"
TASK_SUBLISTS[MIDC]="sublist.txt"
TASK_SUBLISTS[DOORS]="sublist.txt"
TASK_SUBLISTS[GRT]="sublist.txt"

MASK_FILE="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/resliced_mask.nii.gz"

TASKS=(MIDA MIDC DOORS GRT)

for ((i=0; i<${#TASKS[@]}; i++)); do
    for ((j=i+1; j<${#TASKS[@]}; j++)); do
        TASK1=${TASKS[$i]}
        TASK2=${TASKS[$j]}

        echo "Processing ${TASK1} vs ${TASK2}"

        TASK1_DIR=${TASK_DIRS[$TASK1]}
        TASK2_DIR=${TASK_DIRS[$TASK2]}
        TASK1_CON=${TASK_CONS[$TASK1]}
        TASK2_CON=${TASK_CONS[$TASK2]}

        COMP_OUTPUT="${OUTPUT_DIR}/repeated/${TASK1}_vs_${TASK2}/"
        mkdir -p ${COMP_OUTPUT}

        OUTPUT_FILE="${COMP_OUTPUT}/${TASK1}_vs_${TASK2}_tfce_corrp_tstat1.nii.gz"
        if [ -f "${OUTPUT_FILE}" ]; then
            echo "Output already exists, skipping analysis..."
            echo "Found: ${OUTPUT_FILE}"
            echo ""
            continue
        fi

        # Subjects in both sublists with both contrasts
        SUBLIST1="${SUBLIST_DIR}/${TASK_SUBLISTS[$TASK1]}"
        SUBLIST2="${SUBLIST_DIR}/${TASK_SUBLISTS[$TASK2]}"
        if [ ! -f "${SUBLIST1}" ] || [ ! -f "${SUBLIST2}" ]; then
            echo "WARNING: Missing sublist for ${TASK1} or ${TASK2}, skipping..."
            continue
        fi

        SUBJECTS=()
        while read -r subj; do
            subj=${subj%$'\r'}
            [ -z "${subj}" ] && continue
            grep -qxF "${subj}" "${SUBLIST2}" || continue
            if [ -f "${TASK1_DIR}${subj}/${TASK1_CON}" ] && [ -f "${TASK2_DIR}${subj}/${TASK2_CON}" ]; then
                SUBJECTS+=("${subj}")
            fi
        done < "${SUBLIST1}"
        N_SUBS=${#SUBJECTS[@]}
        echo "N subjects with both ${TASK1} and ${TASK2}: ${N_SUBS}"

        if [ ${N_SUBS} -eq 0 ]; then
            echo "WARNING: No subjects found with both contrasts, skipping..."
            continue
        fi

        # Create difference images
        echo "Creating difference images..."
        rm -f ${SCRATCH_DIR}/diff_list_${TASK1}_${TASK2}.txt
        for subj in "${SUBJECTS[@]}"; do
            echo "Processing ${subj}..."

            fslmaths ${TASK1_DIR}/${subj}/${TASK1_CON} -nan \
                     ${SCRATCH_DIR}/tmp_${subj}_${TASK1}.nii.gz
            fslmaths ${TASK2_DIR}/${subj}/${TASK2_CON} -nan \
                     ${SCRATCH_DIR}/tmp_${subj}_${TASK2}.nii.gz

            # Joint mask where both tasks have valid data
            fslmaths ${SCRATCH_DIR}/tmp_${subj}_${TASK1}.nii.gz -bin \
                     ${SCRATCH_DIR}/tmp_mask1_${subj}.nii.gz
            fslmaths ${SCRATCH_DIR}/tmp_${subj}_${TASK2}.nii.gz -bin \
                     ${SCRATCH_DIR}/tmp_mask2_${subj}.nii.gz
            fslmaths ${SCRATCH_DIR}/tmp_mask1_${subj}.nii.gz \
                     -mul ${SCRATCH_DIR}/tmp_mask2_${subj}.nii.gz \
                     ${SCRATCH_DIR}/tmp_bothmask_${subj}.nii.gz

            # Subtract and apply joint mask
            fslmaths ${SCRATCH_DIR}/tmp_${subj}_${TASK1}.nii.gz \
                     -sub ${SCRATCH_DIR}/tmp_${subj}_${TASK2}.nii.gz \
                     -mas ${SCRATCH_DIR}/tmp_bothmask_${subj}.nii.gz \
                     ${SCRATCH_DIR}/${subj}_diff_${TASK1}_${TASK2}.nii.gz

            rm -f ${SCRATCH_DIR}/tmp_${subj}_${TASK1}.nii.gz \
                  ${SCRATCH_DIR}/tmp_${subj}_${TASK2}.nii.gz \
                  ${SCRATCH_DIR}/tmp_mask1_${subj}.nii.gz \
                  ${SCRATCH_DIR}/tmp_mask2_${subj}.nii.gz \
                  ${SCRATCH_DIR}/tmp_bothmask_${subj}.nii.gz

            echo "${SCRATCH_DIR}/${subj}_diff_${TASK1}_${TASK2}.nii.gz" >> ${SCRATCH_DIR}/diff_list_${TASK1}_${TASK2}.txt
        done

        # Merge difference images
        echo "Merging difference images..."
        fslmerge -t ${SCRATCH_DIR}/all_diffs_${TASK1}_${TASK2}.nii.gz \
                 $(cat ${SCRATCH_DIR}/diff_list_${TASK1}_${TASK2}.txt)

        # Design matrix
        echo "Creating design matrix..."
        {
            echo "/NumWaves 1"
            echo "/NumPoints ${N_SUBS}"
            echo "/PPheights 1"
            echo ""
            echo "/Matrix"
            for ((k=0; k<N_SUBS; k++)); do
                echo "1"
            done
        } > ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.mat

        # Contrast file
        {
            echo "/ContrastName1 ${TASK1}_gt_${TASK2}"
            echo "/ContrastName2 ${TASK2}_gt_${TASK1}"
            echo "/NumWaves 1"
            echo "/NumContrasts 2"
            echo "/PPheights 1 1"
            echo "/RequiredEffect 1 1"
            echo ""
            echo "/Matrix"
            echo "1"
            echo "-1"
        } > ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.con

        echo "Running randomise..."
        randomise -i ${SCRATCH_DIR}/all_diffs_${TASK1}_${TASK2}.nii.gz \
                  -o ${COMP_OUTPUT}/${TASK1}_vs_${TASK2}_ \
                  -d ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.mat \
                  -t ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.con \
                  -m ${MASK_FILE} \
                  -n 5000 \
                  -T

        echo "${TASK1} vs ${TASK2} complete!"
        echo ""
    done
done

echo "All comparisons complete"