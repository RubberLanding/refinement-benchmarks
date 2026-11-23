#!/bin/bash
# Phase 3: measure the current state of `src/` under a label, for before/after
# comparisons in one session. Full runs (tree with per-particle radii, fast shifting,
# 3 runs) and the isolated RHS timers of `profile.jl`, for both cases.
# Run from the worktree root:
#   [MEASURE=../benchmark-measure] benchmarks/ab.sh <label> [threads]
set -u
# With `MEASURE=<worktree>`, TrixiParticles is loaded from that worktree (its `run/`),
# so that `src/` of this worktree can be edited while the measurement runs.
label=$1
threads=${2:-8}
measure=${MEASURE:-.}
project=$measure/run
out=benchmarks/results/phase3/$label
mkdir -p "$out"
echo "$(git -C "$measure" rev-parse --short HEAD) $(git -C "$measure" status --porcelain --untracked-files=no | tr '\n' ' ')" > "$out/commit.txt"

for case in taylor_green pipe_flow; do
    julia --project="$project" -t "$threads" benchmarks/run_full.jl case="$case" size=small \
        nhs=tree_variable refinement=on shifting=fast steps=100 runs=3 \
        out="$out/full_$case" > "$out/full_$case.log" 2>&1 || echo "FAILED full $case"
    julia --project="$project" -t "$threads" benchmarks/profile.jl case="$case" size=small \
        shifting=fast sections=pairs,rhs rhs_calls=100 \
        out="$out/profile_$case" > "$out/profile_$case.log" 2>&1 || echo "FAILED profile $case"
done
echo "$(date +%T) $label done"
