#!/bin/bash
# run_experiments.sh
#
# This script runs the MM executable for different matrix sizes and for two
# multiplication types ("flat" and "transposed"). For each combination,
# it runs both sequential and parallel modes 7 times, measures the energy consumption
# from multiple RAPL domains and the execution time, computes the medians, and
# saves the results in a CSV file.
#
# Usage: ./run_experiments.sh

# --- Configuration ---

# Define the RAPL energy file paths (relative to the MASTERKODE folder)
RAPL_PKG_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
RAPL_CORE_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0:0/energy_uj"
RAPL_UNCORE_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0:1/energy_uj"
RAPL_DRAM_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0:2/energy_uj"

# Path to the executable "MM" (assumed to be in the current directory)
EXECUTABLE="$PWD/MM"

# CSV log file (will be created in the MASTERKODE folder)
CSV_LOGFILE="$PWD/experiment_results.csv"

# Matrix sizes to test
Ns=(50 100 200 500 )

# Multiplication types to test
mult_types=("flat" "transposed")

# Number of runs per configuration
num_runs=7

# --- Function: Compute Median ---
# Given a list of numbers, this function prints the median.
# For an odd number of values (here 7) the median is the 4th value after sorting.
function median() {
    arr=("$@")
    sorted=($(printf "%s\n" "${arr[@]}" | sort -n))
    echo "${sorted[3]}"
}

# --- Reset the CSV Log File ---
# The header now includes energy values for:
# Package, Core, Uncore, DRAM and the execution time.
echo "N,multiplication_type,seq_pkg_energy,seq_core_energy,seq_uncore_energy,seq_dram_energy,seq_time,par_pkg_energy,par_core_energy,par_uncore_energy,par_dram_energy,par_time" > "$CSV_LOGFILE"

# --- Function: Read Energy from a Given File ---
function read_energy() {
    local file="$1"
    cat "$file"
}

# --- Main Loop Over Multiplication Types and Matrix Sizes ---
for mult in "${mult_types[@]}"; do
    for N in "${Ns[@]}"; do

        # Arrays for sequential measurements
        seq_pkg_energy_vals=()
        seq_core_energy_vals=()
        seq_uncore_energy_vals=()
        seq_dram_energy_vals=()
        seq_time_vals=()

        # Run the sequential configuration num_runs times
        for (( i=1; i<=num_runs; i++ )); do
            # Read all energy values before the run
            start_pkg=$(read_energy "$RAPL_PKG_FILE")
            start_core=$(read_energy "$RAPL_CORE_FILE")
            start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            start_dram=$(read_energy "$RAPL_DRAM_FILE")

            # Run the executable in sequential mode ("seq") with the chosen multiplication type
            output=$("$EXECUTABLE" "$N" seq "$mult")

            # Read all energy values after the run
            end_pkg=$(read_energy "$RAPL_PKG_FILE")
            end_core=$(read_energy "$RAPL_CORE_FILE")
            end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            end_dram=$(read_energy "$RAPL_DRAM_FILE")

            # Compute the differences (in microjoules)
            pkg_energy=$(( end_pkg - start_pkg ))
            core_energy=$(( end_core - start_core ))
            uncore_energy=$(( end_uncore - start_uncore ))
            dram_energy=$(( end_dram - start_dram ))

            # Extract execution time from output (assumes a line like "Sequential flat:" or "Sequential transposed:")
            time_val=$(echo "$output" | grep -i "Sequential" | awk '{print $3}')

            # Save values into the arrays
            seq_pkg_energy_vals+=("$pkg_energy")
            seq_core_energy_vals+=("$core_energy")
            seq_uncore_energy_vals+=("$uncore_energy")
            seq_dram_energy_vals+=("$dram_energy")
            seq_time_vals+=("$time_val")
        done

        # Arrays for parallel measurements
        par_pkg_energy_vals=()
        par_core_energy_vals=()
        par_uncore_energy_vals=()
        par_dram_energy_vals=()
        par_time_vals=()

        # Run the parallel configuration num_runs times
        for (( i=1; i<=num_runs; i++ )); do
            start_pkg=$(read_energy "$RAPL_PKG_FILE")
            start_core=$(read_energy "$RAPL_CORE_FILE")
            start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            start_dram=$(read_energy "$RAPL_DRAM_FILE")

            # Run the executable in parallel mode ("par") with the chosen multiplication type
            output=$("$EXECUTABLE" "$N" par "$mult")

            end_pkg=$(read_energy "$RAPL_PKG_FILE")
            end_core=$(read_energy "$RAPL_CORE_FILE")
            end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            end_dram=$(read_energy "$RAPL_DRAM_FILE")

            pkg_energy=$(( end_pkg - start_pkg ))
            core_energy=$(( end_core - start_core ))
            uncore_energy=$(( end_uncore - start_uncore ))
            dram_energy=$(( end_dram - start_dram ))

            time_val=$(echo "$output" | grep -i "Parallel" | awk '{print $3}')

            par_pkg_energy_vals+=("$pkg_energy")
            par_core_energy_vals+=("$core_energy")
            par_uncore_energy_vals+=("$uncore_energy")
            par_dram_energy_vals+=("$dram_energy")
            par_time_vals+=("$time_val")
        done

        # Compute medians for sequential measurements
        seq_pkg_energy_median=$(median "${seq_pkg_energy_vals[@]}")
        seq_core_energy_median=$(median "${seq_core_energy_vals[@]}")
        seq_uncore_energy_median=$(median "${seq_uncore_energy_vals[@]}")
        seq_dram_energy_median=$(median "${seq_dram_energy_vals[@]}")
        seq_time_median=$(median "${seq_time_vals[@]}")

        # Compute medians for parallel measurements
        par_pkg_energy_median=$(median "${par_pkg_energy_vals[@]}")
        par_core_energy_median=$(median "${par_core_energy_vals[@]}")
        par_uncore_energy_median=$(median "${par_uncore_energy_vals[@]}")
        par_dram_energy_median=$(median "${par_dram_energy_vals[@]}")
        par_time_median=$(median "${par_time_vals[@]}")

        # Log the results in CSV format
        echo "$N,$mult,$seq_pkg_energy_median,$seq_core_energy_median,$seq_uncore_energy_median,$seq_dram_energy_median,$seq_time_median,$par_pkg_energy_median,$par_core_energy_median,$par_uncore_energy_median,$par_dram_energy_median,$par_time_median" >> "$CSV_LOGFILE"

        echo "Completed N=$N, type=$mult: Seq(PKG=$seq_pkg_energy_median, CORE=$seq_core_energy_median, UNCORE=$seq_uncore_energy_median, DRAM=$seq_dram_energy_median, TIME=$seq_time_median) | Par(PKG=$par_pkg_energy_median, CORE=$par_core_energy_median, UNCORE=$par_uncore_energy_median, DRAM=$par_dram_energy_median, TIME=$par_time_median)"
    done
done

echo "All experiments completed. Results are saved in $CSV_LOGFILE"
