#!/bin/bash

OUTPUT_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/outputs/group_activation/"
SCRATCH_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/scratch/"
LOG_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"
SUBLIST_DIR="/mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/"

mkdir -p ${OUTPUT_DIR}
mkdir -p ${SCRATCH_DIR}
mkdir -p ${LOG_DIR}

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/group_activation_${TIMESTAMP}.log"
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
TASK_CONS[DOORS]="con_0001.nii"
TASK_CONS[GRT]="con_0002.nii"

# Sublist files (MIDA/MIDC share)
TASK_SUBLISTS[MIDA]="sublist_MID.txt"
TASK_SUBLISTS[MIDC]="sublist_MID.txt"
TASK_SUBLISTS[DOORS]="sublist_DOORS.txt"
TASK_SUBLISTS[GRT]="sublist_GRT.txt"

TASKS=(MIDA MIDC DOORS GRT)

for TASK in "${TASKS[@]}"; do
    echo "Group activation for ${TASK}"

    TASK_DIR=${TASK_DIRS[$TASK]}
    TASK_CON=${TASK_CONS[$TASK]}

    TASK_OUTPUT="${OUTPUT_DIR}/${TASK}/"
    mkdir -p ${TASK_OUTPUT}

    OUTPUT_FILE="${TASK_OUTPUT}/${TASK}_group_clustere_corrp_tstat1.nii.gz"
    #if [ -f "${OUTPUT_FILE}" ]; then
    #    echo "Output already exists, skipping analysis..."
    #    echo "Found: ${OUTPUT_FILE}"
    #    echo ""
    #    continue
    #fi

    # Read subject list from file
    SUBLIST="${SUBLIST_DIR}/${TASK_SUBLISTS[$TASK]}"
    if [ ! -f "${SUBLIST}" ]; then
        echo "WARNING: No sublist for ${TASK}, skipping..."
        continue
    fi

    SUBJECTS=()
    while read -r subj; do
        [ -z "${subj}" ] && continue
        if [ -f "${TASK_DIR}${subj}/${TASK_CON}" ]; then
            SUBJECTS+=("${subj}")
        else
            echo "Missing contrast for ${subj}, skipping"
        fi
    done < "${SUBLIST}"
    N_SUBS=${#SUBJECTS[@]}
    echo "N subjects with ${TASK}: ${N_SUBS}"

    if [ ${N_SUBS} -eq 0 ]; then
        echo "WARNING: No subjects found with contrast, skipping..."
        continue
    fi

    # Clean NaNs and build list
    echo "Cleaning NaN values from contrasts..."
    rm -f ${SCRATCH_DIR}/contrast_list_${TASK}.txt
    for subj in "${SUBJECTS[@]}"; do
        echo "Processing ${subj}..."
        fslmaths ${TASK_DIR}/${subj}/${TASK_CON} -nan \
                 ${SCRATCH_DIR}/${subj}_${TASK}_clean.nii.gz
        echo "${SCRATCH_DIR}/${subj}_${TASK}_clean.nii.gz" >> ${SCRATCH_DIR}/contrast_list_${TASK}.txt
    done

    # Merge into 4D
    echo "Merging contrasts..."
    fslmerge -t ${SCRATCH_DIR}/all_${TASK}.nii.gz \
             $(cat ${SCRATCH_DIR}/contrast_list_${TASK}.txt)

    # Design matrix (one-sample t-test)
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
    } > ${SCRATCH_DIR}/design_${TASK}.mat

    # Contrast file (activation + deactivation)
    {
        echo "/ContrastName1 ${TASK}_activation"
        echo "/ContrastName2 ${TASK}_deactivation"
        echo "/NumWaves 1"
        echo "/NumContrasts 2"
        echo "/PPheights 1 1"
        echo "/RequiredEffect 1 1"
        echo ""
        echo "/Matrix"
        echo "1"
        echo "-1"
    } > ${SCRATCH_DIR}/design_${TASK}.con

    echo "Running randomise..."
    randomise -i ${SCRATCH_DIR}/all_${TASK}.nii.gz \
          -o ${TASK_OUTPUT}/${TASK}_group_ \
          -d ${SCRATCH_DIR}/design_${TASK}.mat \
          -t ${SCRATCH_DIR}/design_${TASK}.con \
          -n 5000 \
          -T \
          -m /mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/masks/resliced_mask.nii.gz

    echo "${TASK} complete!"
    echo ""
done

echo "All group activations complete"