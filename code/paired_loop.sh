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

declare -A TASK_DIRS
declare -A TASK_CONS

# Task directories
TASK_DIRS[MIDA]="/mnt/Psych/UIC/FMRI_ANALYSIS_MID/DBBI/GLM_Results/"
TASK_DIRS[MIDC]="/mnt/Psych/UIC/FMRI_ANALYSIS_MID/DBBI/GLM_Results/"
TASK_DIRS[DOORS]="/mnt/Psych/UIC/FMRI_ANALYSIS_DOORS/DBBI/GLM_Results/"
TASK_DIRS[GRT]="/mnt/Psych/UIC/FMRI_ANALYSIS_GRT/DBBI/GLM_Results/" 

# Task contrast files
TASK_CONS[MIDA]="con_0010.nii" 
TASK_CONS[MIDC]="con_0028.nii" 
TASK_CONS[DOORS]="con_0001.nii"
TASK_CONS[GRT]="con_0002.nii"

# Mask
MASK_FILE="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/resliced_mask.nii.gz"

# List of tasks
TASKS=(MIDA MIDC DOORS GRT)

# Loop through all pairwise comparisons
for ((i=0; i<${#TASKS[@]}; i++)); do
    for ((j=i+1; j<${#TASKS[@]}; j++)); do
        TASK1=${TASKS[$i]}
        TASK2=${TASKS[$j]}
        
        echo "${TASK1} vs ${TASK2}"
        
        TASK1_DIR=${TASK_DIRS[$TASK1]}
        TASK2_DIR=${TASK_DIRS[$TASK2]}
        TASK1_CON=${TASK_CONS[$TASK1]}
        TASK2_CON=${TASK_CONS[$TASK2]}
        
        # Create output subdirectory for this comparison
        COMP_OUTPUT="${OUTPUT_DIR}/${TASK1}_vs_${TASK2}/"
        mkdir -p ${COMP_OUTPUT}

        # Check if analysis already exists
        OUTPUT_FILE="${COMP_OUTPUT}/${TASK1}_vs_${TASK2}_clustere_corrp_tstat1.nii.gz"
        if [ -f "${OUTPUT_FILE}" ]; then
            echo "Output already exists, skipping analysis..."
            echo "Found: ${OUTPUT_FILE}"
            echo ""
            continue
        fi
        
        # Build subject list (subjects with both contrasts)
        SUBJECTS=()
        for subj_dir in ${TASK1_DIR}*/; do
            subj=$(basename ${subj_dir})
            
            if [ -f "${TASK1_DIR}${subj}/${TASK1_CON}" ] && [ -f "${TASK2_DIR}${subj}/${TASK2_CON}" ]; then
                SUBJECTS+=("${subj}")
            fi
        done
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
                     -sub ${TASK2_DIR}/${subj}/${TASK2_CON} -nan \
                     ${SCRATCH_DIR}/${subj}_diff_${TASK1}_${TASK2}.nii.gz
            
            echo "${SCRATCH_DIR}/${subj}_diff_${TASK1}_${TASK2}.nii.gz" >> ${SCRATCH_DIR}/diff_list_${TASK1}_${TASK2}.txt
        done
        
        # Merge difference images
        echo "Merging difference images..."
        fslmerge -t ${SCRATCH_DIR}/all_diffs_${TASK1}_${TASK2}.nii.gz \
                 $(cat ${SCRATCH_DIR}/diff_list_${TASK1}_${TASK2}.txt)
        
        # Create design matrix
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
        } > ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.con
        
        # Run randomise
        echo "Running randomise..."
        randomise -i ${SCRATCH_DIR}/all_diffs_${TASK1}_${TASK2}.nii.gz \
                  -o ${COMP_OUTPUT}/${TASK1}_vs_${TASK2} \
                  -d ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.mat \
                  -t ${SCRATCH_DIR}/design_${TASK1}_${TASK2}.con \
                  -m ${MASK_FILE} \
                  -n 500 \
                  -c 3.1 \
                  --uncorrp
        
        echo "${TASK1} vs ${TASK2} complete!"
        echo ""
    done
done