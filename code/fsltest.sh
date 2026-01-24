#!/bin/bash

# Dirs & Subs
OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/"
SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
LOG_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"

TASK1="MID"
TASK2="DOORS"

TASK1_DIR="/mnt/Psych/UIC/FMRI_ANALYSIS_${TASK1}/DBBI/GLM_Results/"
TASK2_DIR="/mnt/Psych/UIC/FMRI_ANALYSIS_${TASK2}/DBBI/GLM_Results/"

TASK1_CON="con_0010.nii"
TASK2_CON="con_0001.nii" #Check this


# Convert both contrast files for DARC322
fslchfiletype NIFTI_GZ ${TASK1_DIR}/DARC322/${TASK1_CON} ${SCRATCH_DIR}/DARC322_task1_converted
fslchfiletype NIFTI_GZ ${TASK2_DIR}/DARC322/${TASK2_CON} ${SCRATCH_DIR}/DARC322_task2_converted

# Check if converted files are valid
fslstats ${SCRATCH_DIR}/DARC322_task1_converted -R
fslstats ${SCRATCH_DIR}/DARC322_task2_converted -R

# Try subtraction on converted files
fslmaths ${SCRATCH_DIR}/DARC322_task1_converted \
         -sub ${SCRATCH_DIR}/DARC322_task2_converted \
         ${SCRATCH_DIR}/DARC322_diff_test

# Check result
fslstats ${SCRATCH_DIR}/DARC322_diff_test -R