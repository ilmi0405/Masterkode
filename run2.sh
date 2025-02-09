#!/bin/bash
# run_experiments.sh
#
# This script runs experiments for either matrix or mergesort.
#
# For matrix:
#   - The MM executable is run for several matrix sizes and two multiplication types
#     ("flat" and "transposed").
#
# For mergesort:
#   - The mergesort executable is run for several array sizes.
#
# In each configuration, both sequential and parallel modes are run num_runs times.
# For each run, energy consumption is measured from multiple RAPL domains and the execution
# time is extracted from the program’s output. The median values over the runs are computed,
# and the results are saved in a CSV file.
#
# Usage: ./run_experiments.sh <mergesort|matrix>

# --- Check Arguments ---
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <mergesort|matrix>"
    exit 1
fi

ALGORITHM="$1"

# --- RAPL Energy File Paths (adjust as needed) ---
RAPL_PKG_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
RAPL_CORE_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:0/energy_uj"
RAPL_UNCORE_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:1/energy_uj"
RAPL_DRAM_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:2/energy_uj"

# --- Number of Runs per Configuration ---
num_runs=7

# --- Set Up Experiment Parameters Based on the Chosen Algorithm ---
case "$ALGORITHM" in
    "matrix")
        EXECUTABLE="$PWD/MM"
        CSV_LOGFILE="$PWD/experiment_results.csv"
        # Matrix sizes to test:
        Ns=(50 100 200 500 1000 1500 2500 3500)
        # Multiplication types to test:
        mult_types=("flat" "transposed")
        # For MM, the program prints a line such as:
        #    "Sequential flat: 0.123456" or "Parallel transposed: 0.123456"
        # so the timing value is in the third column.
        time_idx=3
        # CSV header includes an extra column for multiplication type.
        echo "N,multiplication_type,seq_pkg_energy,seq_core_energy,seq_uncore_energy,seq_dram_energy,seq_time,par_pkg_energy,par_core_energy,par_uncore_energy,par_dram_energy,par_time" > "$CSV_LOGFILE"
        ;;
    "mergesort")
        EXECUTABLE="$PWD/mergesort"
        CSV_LOGFILE="$PWD/mergesort_experiment_results.csv"
        # Array sizes to test (you can adjust these values as needed):
        Ns=(100000 200000 500000 1000000 2000000 3000000)
        # For mergesort, the output is expected to be like:
        #    "Sequential: 0.123456" or "Parallel: 0.123456"
        # so the timing value is in the second column.
        time_idx=2
        # CSV header (no multiplication type column here).
        echo "N,seq_pkg_energy,seq_core_energy,seq_uncore_energy,seq_dram_energy,seq_time,par_pkg_energy,par_core_energy,par_uncore_energy,par_dram_energy,par_time" > "$CSV_LOGFILE"
        ;;
    *)
        echo "Unknown algorithm '$ALGORITHM'. Use either 'mergesort' or 'matrix'."
        exit 1
        ;;
esac

# --- Utility Functions ---

# median: Given a list of numbers as arguments, print the median.
# (For an odd number of values—here 7—the median is the 4th value after sorting.)
function median() {
    arr=("$@")
    sorted=($(printf "%s\n" "${arr[@]}" | sort -n))
    echo "${sorted[3]}"
}

# read_energy: Reads the current energy value from a given file.
function read_energy() {
    local file="$1"
    cat "$file"
}

# --- Main Experiment Loops ---
echo "Starting experiments for $ALGORITHM..."
echo "Results will be saved in $CSV_LOGFILE"

if [ "$ALGORITHM" = "matrix" ]; then
    # Loop over multiplication types and matrix sizes.
    for mult in "${mult_types[@]}"; do
        for N in "${Ns[@]}"; do

            # Arrays for sequential measurements
            seq_pkg_energy_vals=()
            seq_core_energy_vals=()
            seq_uncore_energy_vals=()
            seq_dram_energy_vals=()
            seq_time_vals=()

            # Run sequential configuration num_runs times.
            for (( i=1; i<=num_runs; i++ )); do
                # Energy before run.
                start_pkg=$(read_energy "$RAPL_PKG_FILE")
                start_core=$(read_energy "$RAPL_CORE_FILE")
                start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                start_dram=$(read_energy "$RAPL_DRAM_FILE")

                # Run executable in sequential mode ("seq") with the chosen multiplication type.
                output=$("$EXECUTABLE" "$N" seq "$mult")

                # Energy after run.
                end_pkg=$(read_energy "$RAPL_PKG_FILE")
                end_core=$(read_energy "$RAPL_CORE_FILE")
                end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                end_dram=$(read_energy "$RAPL_DRAM_FILE")

                # Compute energy differences (in microjoules).
                pkg_energy=$(( end_pkg - start_pkg ))
                core_energy=$(( end_core - start_core ))
                uncore_energy=$(( end_uncore - start_uncore ))
                dram_energy=$(( end_dram - start_dram ))

                # Extract execution time (expects output like "Sequential flat: 0.123456")
                time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")

                # Save values into arrays.
                seq_pkg_energy_vals+=("$pkg_energy")
                seq_core_energy_vals+=("$core_energy")
                seq_uncore_energy_vals+=("$uncore_energy")
                seq_dram_energy_vals+=("$dram_energy")
                seq_time_vals+=("$time_val")
            done

            # Arrays for parallel measurements.
            par_pkg_energy_vals=()
            par_core_energy_vals=()
            par_uncore_energy_vals=()
            par_dram_energy_vals=()
            par_time_vals=()

            # Run parallel configuration num_runs times.
            for (( i=1; i<=num_runs; i++ )); do
                start_pkg=$(read_energy "$RAPL_PKG_FILE")
                start_core=$(read_energy "$RAPL_CORE_FILE")
                start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                start_dram=$(read_energy "$RAPL_DRAM_FILE")

                # Run executable in parallel mode ("par") with the chosen multiplication type.
                output=$("$EXECUTABLE" "$N" par "$mult")

                end_pkg=$(read_energy "$RAPL_PKG_FILE")
                end_core=$(read_energy "$RAPL_CORE_FILE")
                end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                end_dram=$(read_energy "$RAPL_DRAM_FILE")

                pkg_energy=$(( end_pkg - start_pkg ))
                core_energy=$(( end_core - start_core ))
                uncore_energy=$(( end_uncore - start_uncore ))
                dram_energy=$(( end_dram - start_dram ))

                time_val=$(echo "$output" | grep -i "Parallel" | awk "{print \$$time_idx}")

                par_pkg_energy_vals+=("$pkg_energy")
                par_core_energy_vals+=("$core_energy")
                par_uncore_energy_vals+=("$uncore_energy")
                par_dram_energy_vals+=("$dram_energy")
                par_time_vals+=("$time_val")
            done

            # Compute medians for sequential measurements.
            seq_pkg_energy_median=$(median "${seq_pkg_energy_vals[@]}")
            seq_core_energy_median=$(median "${seq_core_energy_vals[@]}")
            seq_uncore_energy_median=$(median "${seq_uncore_energy_vals[@]}")
            seq_dram_energy_median=$(median "${seq_dram_energy_vals[@]}")
            seq_time_median=$(median "${seq_time_vals[@]}")

            # Compute medians for parallel measurements.
            par_pkg_energy_median=$(median "${par_pkg_energy_vals[@]}")
            par_core_energy_median=$(median "${par_core_energy_vals[@]}")
            par_uncore_energy_median=$(median "${par_uncore_energy_vals[@]}")
            par_dram_energy_median=$(median "${par_dram_energy_vals[@]}")
            par_time_median=$(median "${par_time_vals[@]}")

            # Log the results in CSV format.
            echo "$N,$mult,$seq_pkg_energy_median,$seq_core_energy_median,$seq_uncore_energy_median,$seq_dram_energy_median,$seq_time_median,$par_pkg_energy_median,$par_core_energy_median,$par_uncore_energy_median,$par_dram_energy_median,$par_time_median" >> "$CSV_LOGFILE"

            echo "Completed: N=$N, type=$mult -> Seq(time=$seq_time_median s) | Par(time=$par_time_median s)"
        done
    done

elif [ "$ALGORITHM" = "mergesort" ]; then
    # Loop over array sizes.
    for N in "${Ns[@]}"; do

        # Arrays for sequential measurements.
        seq_pkg_energy_vals=()
        seq_core_energy_vals=()
        seq_uncore_energy_vals=()
        seq_dram_energy_vals=()
        seq_time_vals=()

        # Run sequential configuration num_runs times.
        for (( i=1; i<=num_runs; i++ )); do
            start_pkg=$(read_energy "$RAPL_PKG_FILE")
            start_core=$(read_energy "$RAPL_CORE_FILE")
            start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            start_dram=$(read_energy "$RAPL_DRAM_FILE")

            # Run executable in sequential mode ("seq"); mergesort expects two arguments: array size and mode.
            output=$("$EXECUTABLE" "$N" seq)

            end_pkg=$(read_energy "$RAPL_PKG_FILE")
            end_core=$(read_energy "$RAPL_CORE_FILE")
            end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            end_dram=$(read_energy "$RAPL_DRAM_FILE")

            pkg_energy=$(( end_pkg - start_pkg ))
            core_energy=$(( end_core - start_core ))
            uncore_energy=$(( end_uncore - start_uncore ))
            dram_energy=$(( end_dram - start_dram ))

            # For mergesort, the expected output is like "Sequential: 0.123456"
            time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")

            seq_pkg_energy_vals+=("$pkg_energy")
            seq_core_energy_vals+=("$core_energy")
            seq_uncore_energy_vals+=("$uncore_energy")
            seq_dram_energy_vals+=("$dram_energy")
            seq_time_vals+=("$time_val")
        done

        # Arrays for parallel measurements.
        par_pkg_energy_vals=()
        par_core_energy_vals=()
        par_uncore_energy_vals=()
        par_dram_energy_vals=()
        par_time_vals=()

        # Run parallel configuration num_runs times.
        for (( i=1; i<=num_runs; i++ )); do
            start_pkg=$(read_energy "$RAPL_PKG_FILE")
            start_core=$(read_energy "$RAPL_CORE_FILE")
            start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            start_dram=$(read_energy "$RAPL_DRAM_FILE")

            # Run executable in parallel mode ("par").
            output=$("$EXECUTABLE" "$N" par)

            end_pkg=$(read_energy "$RAPL_PKG_FILE")
            end_core=$(read_energy "$RAPL_CORE_FILE")
            end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
            end_dram=$(read_energy "$RAPL_DRAM_FILE")

            pkg_energy=$(( end_pkg - start_pkg ))
            core_energy=$(( end_core - start_core ))
            uncore_energy=$(( end_uncore - start_uncore ))
            dram_energy=$(( end_dram - start_dram ))

            time_val=$(echo "$output" | grep -i "Parallel" | awk "{print \$$time_idx}")

            par_pkg_energy_vals+=("$pkg_energy")
            par_core_energy_vals+=("$core_energy")
            par_uncore_energy_vals+=("$uncore_energy")
            par_dram_energy_vals+=("$dram_energy")
            par_time_vals+=("$time_val")
        done

        # Compute medians for sequential measurements.
        seq_pkg_energy_median=$(median "${seq_pkg_energy_vals[@]}")
        seq_core_energy_median=$(median "${seq_core_energy_vals[@]}")
        seq_uncore_energy_median=$(median "${seq_uncore_energy_vals[@]}")
        seq_dram_energy_median=$(median "${seq_dram_energy_vals[@]}")
        seq_time_median=$(median "${seq_time_vals[@]}")

        # Compute medians for parallel measurements.
        par_pkg_energy_median=$(median "${par_pkg_energy_vals[@]}")
        par_core_energy_median=$(median "${par_core_energy_vals[@]}")
        par_uncore_energy_median=$(median "${par_uncore_energy_vals[@]}")
        par_dram_energy_median=$(median "${par_dram_energy_vals[@]}")
        par_time_median=$(median "${par_time_vals[@]}")

        # Log the results in CSV format.
        echo "$N,$seq_pkg_energy_median,$seq_core_energy_median,$seq_uncore_energy_median,$seq_dram_energy_median,$seq_time_median,$par_pkg_energy_median,$par_core_energy_median,$par_uncore_energy_median,$par_dram_energy_median,$par_time_median" >> "$CSV_LOGFILE"

        echo "Completed: N=$N -> Seq(time=$seq_time_median s) | Par(time=$par_time_median s)"
    done
fi

echo "All experiments completed. Results are saved in $CSV_LOGFILE"
