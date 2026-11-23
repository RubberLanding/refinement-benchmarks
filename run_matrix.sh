#!/bin/bash
# Phase 2: all full-run configurations of one size and thread count, one after another.
# Run from the worktree root:
#   benchmarks/run_matrix.sh <size> <threads> [steps] [runs]
set -u
size=$1
threads=$2
steps=${3:-100}
runs=${4:-5}
log_dir=benchmarks/results/full/logs
mkdir -p "$log_dir"

for case in taylor_green pipe_flow; do
    for config in "nhs=tree_variable refinement=on" "nhs=tree_uniform refinement=on" \
                  "nhs=grid refinement=on" "nhs=grid refinement=min" \
                  "nhs=grid refinement=max"; do
        name="${case}_${size}_t${threads}_$(echo "$config" | tr ' =' '__')"
        echo "$(date +%T) start $name"
        julia --project=run -t "$threads" benchmarks/run_full.jl case="$case" size="$size" \
            steps="$steps" runs="$runs" $config > "$log_dir/$name.log" 2>&1 \
            && echo "$(date +%T) done $name" || echo "$(date +%T) FAILED $name"
    done
done
echo "$(date +%T) matrix finished"
