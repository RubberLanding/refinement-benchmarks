#!/bin/bash
# Accuracy runs of the refined and uniform configurations (see `accuracy.jl`).
# Run from the worktree root, after the timing sessions (it loads the machine):
#   benchmarks/run_accuracy.sh <output directory> [parallel runs]
# The sources in `.ab_src` come from `ab_interleaved.py`.
out=$1
parallel=${2:-5}
base=5b73bd7
final=c4b66ab
mkdir -p "$out"
run() {  # label, commit, arguments of accuracy.jl
    label=$1; commit=$2; case=$3; shift 3
    mkdir -p "$out/$case/$label"
    echo "julia --project=benchmarks/.ab_src/$commit/run -t 8 benchmarks/accuracy.jl" \
        "case=$case $* out=$out/$case/$label > $out/$case/$label/run.log 2>&1 && echo done $case $label || echo FAILED $case $label"
}
{
    # Refined first, they take longest
    run refined_base $base taylor_green refinement=on
    run refined_final $final taylor_green refinement=on
    run refined_final_half_dt $final taylor_green refinement=on dtmax_factor=0.5
    run uniform_fine $final taylor_green refinement=min
    run uniform_fine_double_dt $final taylor_green refinement=min dtmax_factor=2
    run uniform_coarse $final taylor_green refinement=max
    # About as many particles as the refined run
    run uniform_same_n $final taylor_green refinement=min size=$(python3 -c "print(1 / 52)")
    run reference $final pipe_flow refinement=min size=$(python3 -c "print(0.4 / 68)")
    run refined_base $base pipe_flow refinement=on
    run refined_final $final pipe_flow refinement=on
    run uniform_fine $final pipe_flow refinement=min
    run uniform_coarse $final pipe_flow refinement=max
    run uniform_same_n $final pipe_flow refinement=min size=$(python3 -c "print(0.4 / 31)")
} > "$out/commands.txt"
tr '\n' '\0' < "$out/commands.txt" | xargs -0 -P "$parallel" -I{} bash -c '{}'
