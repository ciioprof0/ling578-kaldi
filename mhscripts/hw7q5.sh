#!/bin/bash

# List of trainnum values
trainnums=(100 300 500 700 900 1100 1300 1500)

# File paths
R_SCRIPT="r2.sh"
CLEANUP_SCRIPT="cleanup.sh"
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}" .sh)

# Create a timestamped log file name
TIMESTAMP=$(date +"%y%m%d_%H%M")
LOG_FILE="/mhlogs/${SCRIPT_NAME}_${TIMESTAMP}.log"

# Run cleanup.sh script initially
bash $CLEANUP_SCRIPT

# Start total time measurement
total_start_time=$(date +%s)

# Loop over the trainnum values
for trainnum in "${trainnums[@]}"; do
    echo "Running experiment with trainnum=$trainnum"

    # Replace the trainnum value in the r2.sh script
    sed -i "s/^trainnum=[0-9]*/trainnum=$trainnum/" $R_SCRIPT

    # Start time measurement for individual trial
    trial_start_time=$(date +%s)

    # Run the r2.sh script
    bash $R_SCRIPT

    # Collect WER error rates for mono and tri1
    echo "Collecting WER for trainnum=$trainnum" >> $LOG_FILE
    grep WER exp/mono/decode/wer* >> $LOG_FILE
    grep WER exp/tri1/decode/wer* >> $LOG_FILE

    # Run cleanup.sh script
    bash $CLEANUP_SCRIPT

    # End time measurement for individual trial and log the elapsed time
    trial_end_time=$(date +%s)
    trial_elapsed_time=$((trial_end_time - trial_start_time))
    echo "Finished experiment with trainnum=$trainnum (Elapsed time: ${trial_elapsed_time}s)" >> $LOG_FILE
    echo "-----------------------------" >> $LOG_FILE

done

# End total time measurement
total_end_time=$(date +%s)
total_elapsed_time=$((total_end_time - total_start_time))

echo "All experiments completed. Total elapsed time: ${total_elapsed_time}s." >> $LOG_FILE
echo "Results are stored in $LOG_FILE."
echo
