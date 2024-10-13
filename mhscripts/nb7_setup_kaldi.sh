#!/bin/bash
# Usage: source nb7_setup_kaldi.sh

# Start tracking the total execution time
SECONDS=0

# Get the current timestamp
TIMESTAMP=$(date +"%y%m%d_%H%M")

# Redirect STDOUT and STDERR to a log file and still display them on screen
LOG_FILE="/mhlogs/kaldi_setup_$TIMESTAMP.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Logging setup to: $LOG_FILE"

# Check if the bind-mounted directories exist and contain files
check_directory() {
    DIR=$1
    if [ -d "$DIR" ]; then
        if [ "$(ls -A $DIR)" ]; then
            echo "Directory $DIR exists and contains files."
        else
            echo "Directory $DIR exists but is empty."
            exit 1
        fi
    else
        echo "Directory $DIR does not exist."
        exit 1
    fi
}

# Confirm that host paths are present and contain files
check_directory "/mhbook"
check_directory "/mhclasses"
check_directory "/mhdata"
check_directory "/mhlogs"
check_directory "/mhscripts"

# Copy /mhbook/very/ to /opt/kaldi/egs/very/
echo "Copying /mhbook/very/ to /opt/kaldi/egs/very/"
cp -r /mhbook/very/ /opt/kaldi/egs/very/

# Display the total time taken and the log file location
duration=$SECONDS
echo
echo "Total time taken: $(($duration / 60)) minutes and $(($duration % 60)) seconds."
echo "A log of this setup is saved at: $LOG_FILE"

# End of Script
