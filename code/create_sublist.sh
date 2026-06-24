for d in /mnt/Psych/UIC/FMRI_ANALYSIS_ICA/DBBI_MID_GRT_DOORS/DOORS/GLM_Results_Doors_3mm \
         /mnt/Psych/UIC/FMRI_ANALYSIS_ICA/DBBI_MID_GRT_DOORS/GRT/GLM_Results_GRT_3mm \
         /mnt/Psych/UIC/FMRI_ANALYSIS_ICA/DBBI_MID_GRT_DOORS/MID/GLM_Results_MID_3mm; do
  find "$d" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
done | sort | uniq -c | awk '$1==3 {print $2}' > /mnt/Psych/UIC/mmattoni/reward_comparison/rew-comp/logs/sublist.txt