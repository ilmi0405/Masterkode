#!/bin/bash
# measure_matrix_energy.sh
#
# Usage: ./measure_matrix_energy.sh <matrix_size> <flat|transposed>
#
# This script runs both the sequential and parallel versions of the matrix multiplication
# for the given multiplication type, measures energy consumption using RAPL,
# extracts the execution time from the program output, logs the results, and compares energy usage.

# --- Configuration ---
# Use relative path to RAPL file from the MASTERKODE folder
RAPL_ENERGY_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"

# Path to the executable "MM" in the current (MASTERKODE) folder
EXECUTABLE="$PWD/MM"

# Log file in the current (MASTERKODE) folder
LOGFILE="$PWD/energy_measurements.log"

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <matrix_size> <flat|transposed>"
    exit 1
fi

MATRIX_SIZE="$1"
MULT_TYPE="$2"
if [ "$MULT_TYPE" != "flat" ] && [ "$MULT_TYPE" != "transposed" ]; then
    echo "Second argument must be 'flat' or 'transposed'"
    exit 1
fi

# Function to read the current energy value from RAPL
function get_energy() {
    cat "$RAPL_ENERGY_FILE"
}

echo "==============================" >> "$LOGFILE"
echo "Matrix size: $MATRIX_SIZE, Multiplication type: $MULT_TYPE" >> "$LOGFILE"
echo "Date: $(date)" >> "$LOGFILE"

# --- Run Sequential Version ---
echo "Running sequential multiplication..."
SEQ_ENERGY_START=$(get_energy)
# Run in sequential mode ("seq") with the chosen multiplication type
SEQ_OUTPUT=$("$EXECUTABLE" "$MATRIX_SIZE" seq "$MULT_TYPE")
SEQ_ENERGY_END=$(get_energy)
SEQ_ENERGY=$(( SEQ_ENERGY_END - SEQ_ENERGY_START ))
# Extract the time (expects output like "Sequential flat:" or "Sequential transposed:")
SEQ_TIME=$(echo "$SEQ_OUTPUT" | grep -i "Sequential" | awk '{print $3}')

echo "Sequential run: Energy = ${SEQ_ENERGY} µJ, Time = ${SEQ_TIME} s" >> "$LOGFILE"

# --- Run Parallel Version ---
echo "Running parallel multiplication..."
PAR_ENERGY_START=$(get_energy)
# Run in parallel mode ("par") with the chosen multiplication type
PAR_OUTPUT=$("$EXECUTABLE" "$MATRIX_SIZE" par "$MULT_TYPE")
PAR_ENERGY_END=$(get_energy)
PAR_ENERGY=$(( PAR_ENERGY_END - PAR_ENERGY_START ))
# Extract the time (expects output like "Parallel flat:" or "Parallel transposed:")
PAR_TIME=$(echo "$PAR_OUTPUT" | grep -i "Parallel" | awk '{print $3}')

echo "Parallel run:   Energy = ${PAR_ENERGY} µJ, Time = ${PAR_TIME} s" >> "$LOGFILE"

# --- Compare Energy Consumption ---
if [ "$SEQ_ENERGY" -gt "$PAR_ENERGY" ]; then
    echo "Result: Parallel run used less energy." >> "$LOGFILE"
elif [ "$SEQ_ENERGY" -lt "$PAR_ENERGY" ]; then
    echo "Result: Sequential run used less energy." >> "$LOGFILE"
else
    echo "Result: Both runs used the same energy." >> "$LOGFILE"
fi

echo "------------------------------" >> "$LOGFILE"
echo "Measurement complete. Results saved in $LOGFILE"
