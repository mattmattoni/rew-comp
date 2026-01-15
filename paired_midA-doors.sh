#!/bin/bash

# Dirs & Subs
CONTRAST_DIR="/path/to/contrast/images"
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/"
SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"

mkdir -p ${SCRATCH_DIR}
cd ${SCRATCH_DIR}

TASK1="/mnt/Psych/UIC/FMRI_ANALYSIS_MID/DBBI/GLM_Results/"
TASK2="/mnt/Psych/UIC/FMRI_ANALYSIS_DOORS/DBBI/GLM_Results/"

TASK1_CON="con_0010.nii"
TASK2_CON="con_0001.nii" #Check this

SUBJECTS=()
for subj_dir in ${TASK1}*/; do
    subj=$(basename ${subj_dir})
    
    # Check if both contrast files exist
    if [ -f "${TASK1}${subj}/${TASK1_CON}" ] && [ -f "${TASK2}${subj}/${TASK2_CON}" ]; then
        SUBJECTS+=("${subj}")
    fi
done
N_SUBS=${#SUBJECTS[@]}
echo ${SUBJECTS[@]}


#echo "Computing Task1 - Task2 differences for ${N_SUBS} subjects..."
#
## Step 1: Compute difference images for each subject
#rm -f diff_list.txt
#for subj in "${SUBJECTS[@]}"; do
#    echo "Processing ${subj}..."
#    fslmaths ${CONTRAST_DIR}/${subj}/${TASK1_CON} \
#             -sub ${CONTRAST_DIR}/${subj}/${TASK2_CON} \
#             ${subj}_diff.nii.gz
#    
#    echo "${SCRATCH_DIR}/${subj}_diff.nii.gz" >> diff_list.txt
#done
#
## Step 2: Merge difference images into a 4D file
#echo "Merging difference images..."
#fslmerge -t all_diffs.nii.gz $(cat diff_list.txt)
#
## Step 3: Create design matrix for one-sample t-test
## Design matrix is just a column of 1s (testing if mean difference != 0)
#echo "Creating design matrix for one-sample t-test..."
#{
#    echo "/NumWaves 1"
#    echo "/NumPoints ${N_SUBS}"
#    echo "/PPheights 1"
#    echo ""
#    echo "/Matrix"
#    for ((i=0; i<N_SUBS; i++)); do
#        echo "1"
#    done
#} > design.mat
#
## Step 4: Create contrast file
## Single contrast: mean > 0 (Task1 > Task2)
#{
#    echo "/ContrastName1 Task1_gt_Task2"
#    echo "/NumWaves 1"
#    echo "/NumContrasts 1"
#    echo "/PPheights 1"
#    echo "/RequiredEffect 1"
#    echo ""
#    echo "/Matrix"
#    echo "1"
#} > design.con
#
## Step 5: Create a brain mask
#echo "Creating mask..."
#fslmaths all_diffs.nii.gz -Tmean mean_diff
#bet mean_diff mean_diff_brain -m -f 0.3
#mv mean_diff_brain_mask.nii.gz mask.nii.gz
#
## Step 6: Run randomise (one-sample t-test on differences)
#echo "Running randomise (one-sample t-test on differences)..."
#randomise -i all_diffs.nii.gz \
#          -o paired_ttest \
#          -d design.mat \
#          -t design.con \
#          -m mask.nii.gz \
#          -n 5000 \
#          -T \
#          --uncorrp
#
#