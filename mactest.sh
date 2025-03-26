#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <mergesort|matrix>"
    exit 1
fi

ALGORITHM="$1"

# --- Number of Runs per Configuration ---
num_runs=7

# --- Define thread counts for parallel runs ---
thread_counts=(2 4 8)

# --- Utility Functions ---

# median: Given a list of numbers as arguments, print the median.
# (For an odd number of values—here 7—the median is the 4th value after sorting.)
function median() {
    arr=("$@")
    sorted=($(printf "%s\n" "${arr[@]}" | sort -n))
    echo "${sorted[3]}"
}

# get_cpu_power: Uses powermetrics to capture an instantaneous CPU power reading (in mW)
function get_cpu_power() {
    # Runs powermetrics for one sample and extracts the CPU Power value.
    sudo powermetrics --samplers cpu_power -n 1 | grep "CPU Power:" | awk '{print $3}'
}

# --- Experiments for Matrix Multiplication ---
if [ "$ALGORITHM" = "matrix" ]; then
    EXECUTABLE="$PWD/MM"
    CSV_LOGFILE="$PWD/matrix_experiment_results.csv"
    # Matrix sizes to test:
    Ns=(50 100 200 500 1000 1500 2500 3500)
    # Multiplication types to test:
    mult_types=("flat" "transposed")
    # For MM, the program prints a line like:
    #   "Sequential flat: 0.123456" or "Parallel transposed: 0.123456"
    # so the timing value is in the third column.
    time_idx=3
    # CSV header: (energy is in mJ, cpu_power in mW, time in seconds)
    echo "N,multiplication_type,mode,threads,energy (mJ),cpu_power (mW),time (s)" > "$CSV_LOGFILE"

    echo "Starting experiments for matrix multiplication on M1..."
    echo "Results will be saved in $CSV_LOGFILE"

    for mult in "${mult_types[@]}"; do
        for N in "${Ns[@]}"; do
            seq_energy_vals=()
            seq_cpu_power_vals=()
            seq_time_vals=()

            for (( i=1; i<=num_runs; i++ )); do
                output=$("$EXECUTABLE" "$N" seq "$mult")
                # Extract runtime (assumed to be the 3rd column of the output)
                time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")
                cpu_power=$(get_cpu_power)
                # Approximate energy consumption (mJ)
                energy=$(echo "$cpu_power * $time_val" | bc -l)
                seq_energy_vals+=("$energy")
                seq_cpu_power_vals+=("$cpu_power")
                seq_time_vals+=("$time_val")
            done

            seq_energy_median=$(median "${seq_energy_vals[@]}")
            seq_cpu_power_median=$(median "${seq_cpu_power_vals[@]}")
            seq_time_median=$(median "${seq_time_vals[@]}")

            # Write a row for the sequential run (threads field left empty)
            echo "$N,$mult,seq,,$seq_energy_median,$seq_cpu_power_median,$seq_time_median" >> "$CSV_LOGFILE"
            echo "Completed matrix sequential: N=$N, type=$mult -> Time=$seq_time_median s"

            # ---- Parallel Runs ----
            for thread in "${thread_counts[@]}"; do
                par_energy_vals=()
                par_cpu_power_vals=()
                par_time_vals=()

                for (( i=1; i<=num_runs; i++ )); do
                    output=$("$EXECUTABLE" "$N" par "$mult" "$thread")
                    time_val=$(echo "$output" | grep -i "Parallel" | awk "{print \$$time_idx}")
                    cpu_power=$(get_cpu_power)
                    energy=$(echo "$cpu_power * $time_val" | bc -l)
                    par_energy_vals+=("$energy")
                    par_cpu_power_vals+=("$cpu_power")
                    par_time_vals+=("$time_val")
                done

                par_energy_median=$(median "${par_energy_vals[@]}")
                par_cpu_power_median=$(median "${par_cpu_power_vals[@]}")
                par_time_median=$(median "${par_time_vals[@]}")

                echo "$N,$mult,par,$thread,$par_energy_median,$par_cpu_power_median,$par_time_median" >> "$CSV_LOGFILE"
                echo "Completed matrix parallel: N=$N, type=$mult, threads=$thread -> Time=$par_time_median s"
            done
        done
    done

# --- Experiments for Merge Sort ---
elif [ "$ALGORITHM" = "mergesort" ]; then
    EXECUTABLE="$PWD/mergesort"
    CSV_LOGFILE="$PWD/mergesort_experiment_results.csv"
    # Array sizes to test:
    Ns=(1000 10000 100000 1000000 10000000 100000000 500000000)
    # For mergesort, the output is expected to be like:
    # "Sequential: 0.123456" or "Parallel: 0.123456"
    # so the timing value is in the second column.
    time_idx=2
    echo "N,mode,threads,energy (mJ),cpu_power (mW),time (s)" > "$CSV_LOGFILE"

    echo "Starting experiments for mergesort on M1..."
    echo "Results will be saved in $CSV_LOGFILE"

    for N in "${Ns[@]}"; do
        seq_energy_vals=()
        seq_cpu_power_vals=()
        seq_time_vals=()

        for (( i=1; i<=num_runs; i++ )); do
            output=$("$EXECUTABLE" "$N" seq)
            time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")
            cpu_power=$(get_cpu_power)
            energy=$(echo "$cpu_power * $time_val" | bc -l)
            seq_energy_vals+=("$energy")
            seq_cpu_power_vals+=("$cpu_power")
            seq_time_vals+=("$time_val")
        done

        seq_energy_median=$(median "${seq_energy_vals[@]}")
        seq_cpu_power_median=$(median "${seq_cpu_power_vals[@]}")
        seq_time_median=$(median "${seq_time_vals[@]}")

        echo "$N,seq,,$seq_energy_median,$seq_cpu_power_median,$seq_time_median" >> "$CSV_LOGFILE"
        echo "Completed mergesort sequential: N=$N -> Time=$seq_time_median s"

        for thread in "${thread_counts[@]}"; do
            par_energy_vals=()
            par_cpu_power_vals=()
            par_time_vals=()

            for (( i=1; i<=num_runs; i++ )); do
                output=$("$EXECUTABLE" "$N" par "$thread")
                time_val=$(echo "$output" | grep -i "Parallel" | awk "{print \$$time_idx}")
                cpu_power=$(get_cpu_power)
                energy=$(echo "$cpu_power * $time_val" | bc -l)
                par_energy_vals+=("$energy")
                par_cpu_power_vals+=("$cpu_power")
                par_time_vals+=("$time_val")
            done

            par_energy_median=$(median "${par_energy_vals[@]}")
            par_cpu_power_median=$(median "${par_cpu_power_vals[@]}")
            par_time_median=$(median "${par_time_vals[@]}")

            echo "$N,par,$thread,$par_energy_median,$par_cpu_power_median,$par_time_median" >> "$CSV_LOGFILE"
            echo "Completed mergesort parallel: N=$N, threads=$thread -> Time=$par_time_median s"
        done
    done

else
    echo "Unknown algorithm '$ALGORITHM'. Use either 'mergesort' or 'matrix'."
    exit 1
fi

echo "All experiments completed. Results are saved in $CSV_LOGFILE"
