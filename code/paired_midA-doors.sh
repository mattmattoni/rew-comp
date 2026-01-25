#!/bin/bash

# Dirs & Subs
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/"
SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
LOG_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"

# Create directories
mkdir -p ${OUTPUT_DIR}
mkdir -p ${SCRATCH_DIR}
mkdir -p ${LOG_DIR}

# Set up logging
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/reward_comparison_${TIMESTAMP}.log"

# Redirect all output to log file
exec > >(tee -a ${LOG_FILE})
exec 2>&1

cd ${SCRATCH_DIR}

TASK1="MID"
TASK2="DOORS"

TASK1_DIR="/mnt/Psych/UIC/FMRI_ANALYSIS_${TASK1}/DBBI/GLM_Results/"
TASK2_DIR="/mnt/Psych/UIC/FMRI_ANALYSIS_${TASK2}/DBBI/GLM_Results/"

TASK1_CON="con_0010.nii"
TASK2_CON="con_0001.nii" #Check this

# Build subject list
SUBJECTS=()
for subj_dir in ${TASK1_DIR}*/; do
    subj=$(basename ${subj_dir})
    
    # Check if both contrast files exist
    if [ -f "${TASK1_DIR}${subj}/${TASK1_CON}" ] && [ -f "${TASK2_DIR}${subj}/${TASK2_CON}" ]; then
        SUBJECTS+=("${subj}")
    fi
done
N_SUBS=${#SUBJECTS[@]}
echo "Sublist: ${SUBJECTS[@]}"
echo "N= $N_SUBS"

# Estimate difference images for each subject
echo "Creating difference images..."
rm -f ${SCRATCH_DIR}/diff_list.txt
for subj in "${SUBJECTS[@]}"; do
    echo "Processing ${subj}..."
    fslmaths ${TASK1_DIR}/${subj}/${TASK1_CON} -nan \
             -sub ${TASK2_DIR}/${subj}/${TASK2_CON} -nan \
             ${SCRATCH_DIR}/${subj}_diff.nii.gz
    
    echo "${SCRATCH_DIR}/${subj}_diff.nii.gz" >> ${SCRATCH_DIR}/diff_list.txt
done

# Merge difference images into a 4D file
echo "Merging difference images..."
fslmerge -t ${SCRATCH_DIR}/all_diffs.nii.gz $(cat ${SCRATCH_DIR}/diff_list.txt)


# Create design matrix for one-sample t-test
echo "Creating design matrix for one-sample t-test..."
{
    echo "/NumWaves 1"
    echo "/NumPoints ${N_SUBS}"
    echo "/PPheights 1"
    echo ""
    echo "/Matrix"
    for ((i=0; i<N_SUBS; i++)); do
        echo "1"
    done
} > ${SCRATCH_DIR}/design.mat

# Create contrast file (two-tailed)
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
} > ${SCRATCH_DIR}/design.con


# Create a brain mask
echo "Creating mask..."
fslmaths ${SCRATCH_DIR}/all_diffs.nii.gz -Tmean ${SCRATCH_DIR}/mean_diff
fslmaths ${SCRATCH_DIR}/mean_diff -abs -bin ${SCRATCH_DIR}/mask.nii.gz

# Run randomise (output results to OUTPUT_DIR)
echo "Running randomise (one-sample t-test on differences)..."
randomise -i ${SCRATCH_DIR}/all_diffs.nii.gz \
          -o ${OUTPUT_DIR}/paired_ttest \
          -d ${SCRATCH_DIR}/design.mat \
          -t ${SCRATCH_DIR}/design.con \
          -m ${SCRATCH_DIR}/mask.nii.gz \
          -n 10000 \
          -T \
          --uncorrp

echo "Analysis complete"