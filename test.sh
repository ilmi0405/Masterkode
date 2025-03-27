

# --- RAPL Energy File Paths (adjust as needed) ---
RAPL_PKG_FILE="../../../sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
RAPL_CORE_FILE="../../../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:0/energy_uj"
RAPL_UNCORE_FILE="../../../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:1/energy_uj"
RAPL_DRAM_FILE="../../../sys/class/powercap/intel-rapl/intel-rapl:0/intel-rapl:0:2/energy_uj"

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

# read_energy: Reads the current energy value from a given file.
function read_energy() {
    local file="$1"
    cat "$file"
}

#!/bin/bash
if [ "$#" -eq 0 ]; then
    ALGORITHMS=("mergesort" "matrix")
else
    ALGORITHMS=("$1")
fi

for ALGORITHM in "${ALGORITHMS[@]}"; do
    if [ "$ALGORITHM" = "matrix" ]; then
        EXECUTABLE="$PWD/MM"
        CSV_LOGFILE="$PWD/experiment_results.csv"
        # Matrix sizes to test:
        Ns=(50 100 200 500 1000 1500 2500 3500 5000)
        # Multiplication types to test:
        mult_types=("flat" "transposed")
        time_idx=3
        echo "N,multiplication_type,mode,threads,pkg_energy,core_energy,uncore_energy,dram_energy,time" > "$CSV_LOGFILE"
        echo "Starting experiments for matrix multiplication..."
        echo "Results will be saved in $CSV_LOGFILE"

        for mult in "${mult_types[@]}"; do
            for N in "${Ns[@]}"; do
                # ---- Sequential Run ----
                seq_pkg_energy_vals=()
                seq_core_energy_vals=()
                seq_uncore_energy_vals=()
                seq_dram_energy_vals=()
                seq_time_vals=()

                for (( i=1; i<=num_runs; i++ )); do
                    start_pkg=$(read_energy "$RAPL_PKG_FILE")
                    start_core=$(read_energy "$RAPL_CORE_FILE")
                    start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                    start_dram=$(read_energy "$RAPL_DRAM_FILE")

                    output=$("$EXECUTABLE" "$N" seq "$mult")

                    end_pkg=$(read_energy "$RAPL_PKG_FILE")
                    end_core=$(read_energy "$RAPL_CORE_FILE")
                    end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                    end_dram=$(read_energy "$RAPL_DRAM_FILE")

                    pkg_energy=$(( end_pkg - start_pkg ))
                    core_energy=$(( end_core - start_core ))
                    uncore_energy=$(( end_uncore - start_uncore ))
                    dram_energy=$(( end_dram - start_dram ))

                    time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")

                    seq_pkg_energy_vals+=("$pkg_energy")
                    seq_core_energy_vals+=("$core_energy")
                    seq_uncore_energy_vals+=("$uncore_energy")
                    seq_dram_energy_vals+=("$dram_energy")
                    seq_time_vals+=("$time_val")
                done

                seq_pkg_energy_median=$(median "${seq_pkg_energy_vals[@]}")
                seq_core_energy_median=$(median "${seq_core_energy_vals[@]}")
                seq_uncore_energy_median=$(median "${seq_uncore_energy_vals[@]}")
                seq_dram_energy_median=$(median "${seq_dram_energy_vals[@]}")
                seq_time_median=$(median "${seq_time_vals[@]}")

                echo "$N,$mult,seq,,$seq_pkg_energy_median,$seq_core_energy_median,$seq_uncore_energy_median,$seq_dram_energy_median,$seq_time_median" >> "$CSV_LOGFILE"
                echo "Completed matrix sequential: N=$N, type=$mult -> Time=$seq_time_median s"

                # ---- Parallel Runs ----
                for thread in "${thread_counts[@]}"; do
                    par_pkg_energy_vals=()
                    par_core_energy_vals=()
                    par_uncore_energy_vals=()
                    par_dram_energy_vals=()
                    par_time_vals=()

                    for (( i=1; i<=num_runs; i++ )); do
                        start_pkg=$(read_energy "$RAPL_PKG_FILE")
                        start_core=$(read_energy "$RAPL_CORE_FILE")
                        start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                        start_dram=$(read_energy "$RAPL_DRAM_FILE")

                        output=$("$EXECUTABLE" "$N" par "$mult" "$thread")

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

                    par_pkg_energy_median=$(median "${par_pkg_energy_vals[@]}")
                    par_core_energy_median=$(median "${par_core_energy_vals[@]}")
                    par_uncore_energy_median=$(median "${par_uncore_energy_vals[@]}")
                    par_dram_energy_median=$(median "${par_dram_energy_vals[@]}")
                    par_time_median=$(median "${par_time_vals[@]}")

                    echo "$N,$mult,par,$thread,$par_pkg_energy_median,$par_core_energy_median,$par_uncore_energy_median,$par_dram_energy_median,$par_time_median" >> "$CSV_LOGFILE"
                    echo "Completed matrix parallel: N=$N, type=$mult, threads=$thread -> Time=$par_time_median s"
                done

            done
        done

    elif [ "$ALGORITHM" = "mergesort" ]; then
        EXECUTABLE="$PWD/mergesort"
        CSV_LOGFILE="$PWD/mergesort_experiment_results.csv"
        Ns=(1000 10000 100000 1000000 10000000 100000000 500000000 1000000000)
        time_idx=2
        echo "N,mode,threads,pkg_energy,core_energy,uncore_energy,dram_energy,time" > "$CSV_LOGFILE"
        echo "Starting experiments for mergesort..."
        echo "Results will be saved in $CSV_LOGFILE"

        for N in "${Ns[@]}"; do
            # ---- Sequential Run ----
            seq_pkg_energy_vals=()
            seq_core_energy_vals=()
            seq_uncore_energy_vals=()
            seq_dram_energy_vals=()
            seq_time_vals=()

            for (( i=1; i<=num_runs; i++ )); do
                start_pkg=$(read_energy "$RAPL_PKG_FILE")
                start_core=$(read_energy "$RAPL_CORE_FILE")
                start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                start_dram=$(read_energy "$RAPL_DRAM_FILE")

                output=$("$EXECUTABLE" "$N" seq)

                end_pkg=$(read_energy "$RAPL_PKG_FILE")
                end_core=$(read_energy "$RAPL_CORE_FILE")
                end_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                end_dram=$(read_energy "$RAPL_DRAM_FILE")

                pkg_energy=$(( end_pkg - start_pkg ))
                core_energy=$(( end_core - start_core ))
                uncore_energy=$(( end_uncore - start_uncore ))
                dram_energy=$(( end_dram - start_dram ))

                time_val=$(echo "$output" | grep -i "Sequential" | awk "{print \$$time_idx}")

                seq_pkg_energy_vals+=("$pkg_energy")
                seq_core_energy_vals+=("$core_energy")
                seq_uncore_energy_vals+=("$uncore_energy")
                seq_dram_energy_vals+=("$dram_energy")
                seq_time_vals+=("$time_val")
            done

            seq_pkg_energy_median=$(median "${seq_pkg_energy_vals[@]}")
            seq_core_energy_median=$(median "${seq_core_energy_vals[@]}")
            seq_uncore_energy_median=$(median "${seq_uncore_energy_vals[@]}")
            seq_dram_energy_median=$(median "${seq_dram_energy_vals[@]}")
            seq_time_median=$(median "${seq_time_vals[@]}")

            echo "$N,seq,,$seq_pkg_energy_median,$seq_core_energy_median,$seq_uncore_energy_median,$seq_dram_energy_median,$seq_time_median" >> "$CSV_LOGFILE"
            echo "Completed mergesort sequential: N=$N -> Time=$seq_time_median s"

            # ---- Parallel Runs ----
            for thread in "${thread_counts[@]}"; do
                par_pkg_energy_vals=()
                par_core_energy_vals=()
                par_uncore_energy_vals=()
                par_dram_energy_vals=()
                par_time_vals=()

                for (( i=1; i<=num_runs; i++ )); do
                    start_pkg=$(read_energy "$RAPL_PKG_FILE")
                    start_core=$(read_energy "$RAPL_CORE_FILE")
                    start_uncore=$(read_energy "$RAPL_UNCORE_FILE")
                    start_dram=$(read_energy "$RAPL_DRAM_FILE")

                    output=$("$EXECUTABLE" "$N" par "$thread")

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

                par_pkg_energy_median=$(median "${par_pkg_energy_vals[@]}")
                par_core_energy_median=$(median "${par_core_energy_vals[@]}")
                par_uncore_energy_median=$(median "${par_uncore_energy_vals[@]}")
                par_dram_energy_median=$(median "${par_dram_energy_vals[@]}")
                par_time_median=$(median "${par_time_vals[@]}")

                echo "$N,par,$thread,$par_pkg_energy_median,$par_core_energy_median,$par_uncore_energy_median,$par_dram_energy_median,$par_time_median" >> "$CSV_LOGFILE"
                echo "Completed mergesort parallel: N=$N, threads=$thread -> Time=$par_time_median s"
            done
        done

    else
        echo "Unknown algorithm '$ALGORITHM'. Use either 'mergesort' or 'matrix'."
        exit 1
    fi
done

echo "All experiments completed. Results are saved in their respective CSV log files."
