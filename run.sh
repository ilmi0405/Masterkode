RAPL_ENERGY_FILE="../sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
# Path to the executable "MM" (assumed to be in the current directory)
EXECUTABLE="$PWD/MM"
# CSV log file (will be created in the MASTERKODE folder)
CSV_LOGFILE="$PWD/experiment_results.csv"
# Matrix sizes to test
Ns=(50 100 200 500 1000 1500)
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
# Write header: N, multiplication_type, seq_energy_uj, seq_time_s, par_energy_uj, par_time_s
echo "N,multiplication_type,seq_energy_uj,seq_time_s,par_energy_uj,par_time_s" > "$CSV_LOGFILE"
# --- Main Loop Over Multiplication Types and Matrix Sizes ---
for mult in "${mult_types[@]}"; do
    for N in "${Ns[@]}"; do
        # Arrays for sequential measurements
        seq_energy_vals=()
        seq_time_vals=()
        for (( i=1; i<=num_runs; i++ )); do
            # Read energy before run
            start_energy=$(cat "$RAPL_ENERGY_FILE")
            # Run the executable in sequential mode (mode "seq")
            output=$("$EXECUTABLE" "$N" seq "$mult")
            # Read energy after run
            end_energy=$(cat "$RAPL_ENERGY_FILE")
            # Calculate energy difference (in microjoules)
            energy=$(( end_energy - start_energy ))
            # Extract execution time (assumes a line like "Sequential flat:" or "Sequential transposed:")
            time_val=$(echo "$output" | grep -i "Sequential" | awk '{print $3}')
            seq_energy_vals+=("$energy")
            seq_time_vals+=("$time_val")
        done
        # Arrays for parallel measurements
        par_energy_vals=()
        par_time_vals=()
        for (( i=1; i<=num_runs; i++ )); do
            start_energy=$(cat "$RAPL_ENERGY_FILE")
            # Run the executable in parallel mode (mode "par")
            output=$("$EXECUTABLE" "$N" par "$mult")
            end_energy=$(cat "$RAPL_ENERGY_FILE")
            energy=$(( end_energy - start_energy ))
            time_val=$(echo "$output" | grep -i "Parallel" | awk '{print $3}')
            par_energy_vals+=("$energy")
            par_time_vals+=("$time_val")
        done
        # Compute medians for each measurement
        seq_energy_median=$(median "${seq_energy_vals[@]}")
        seq_time_median=$(median "${seq_time_vals[@]}")
        par_energy_median=$(median "${par_energy_vals[@]}")
        par_time_median=$(median "${par_time_vals[@]}")
        # Log the results in CSV format
        echo "$N,$mult,$seq_energy_median,$seq_time_median,$par_energy_median,$par_time_median" >> "$CSV_LOGFILE"
        echo "Completed N=$N, type=$mult: seq_energy=$seq_energy_median, seq_time=$seq_time_median, par_energy=$par_energy_median, par_time=$par_time_median"
    done
done
echo "All experiments completed. Results are saved in $CSV_LOGFILE"
