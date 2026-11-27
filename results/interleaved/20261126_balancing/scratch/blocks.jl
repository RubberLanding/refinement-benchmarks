# Scratch: load balancing of the threaded neighbor loops, block sizes interleaved in one
# process on the same state. Early state (from the startup) and developed state (t = 4).
#   julia --project=run -t 8 blocks.jl nhs=grid out=<dir>
# Block 0 is the order of `eachparticle` (no balancing). Each turn copies the state, sets the
# block size, and steps `steps` steps. The order of the labels alternates between blocks;
# the first block is discarded. Every run is written to `<out>/runs.csv`.
include("/mnt/ssd/home/nschum25/benchmark/benchmarks/time_budget.jl")

const ARGS_ = Dict(split(a, "="; limit=2) for a in ARGS)
const NHS = Symbol(get(ARGS_, "nhs", "grid"))
const RATIO = parse(Int, get(ARGS_, "ratio", "2"))
const OUT = ARGS_["out"]
const LABELS = parse.(Int, split(get(ARGS_, "blocks", "0,16,64,256"), ","))
const N_BLOCKS = parse(Int, get(ARGS_, "n", "6"))
const STEPS = parse(Int, get(ARGS_, "steps", "100"))
const STATES = split(get(ARGS_, "states", "early,developed"), ",")

fluid_buffer(semi) = first(semi.systems).buffer

# Early: the startup with the same block size, then `STEPS` steps
function make_early(case, block)
    (; ode, callbacks, alg, solve_kwargs) = deepcopy(case)
    TP.set_thread_block!(fluid_buffer(ode.p.semi), block)
    return init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
end

function make_developed(integrator, block)
    copied = deepcopy(integrator)
    TP.set_thread_block!(fluid_buffer(copied.p.semi), block)
    return copied
end

function turn(make, state, block, i, io)
    TP.reset_timer!(TP.timer())
    GC.gc()
    integrator = make()
    TP.reset_timer!(TP.timer())
    stats = (; integrator.stats.naccept, integrator.stats.nf)
    before = load_state()
    t0 = time_ns()
    do_steps!(integrator, STEPS)
    seconds = (time_ns() - t0) / 1e9
    load = load_since(before)
    timers = Dict(r.path => r.time_ns / 1e6 for r in flatten_timer(TP.timer()))
    nf = integrator.stats.nf - stats.nf
    n = sum(last, n_active(integrator.p.semi))
    stall = 1e6 * get(timers, "kick! / reset ∂v/∂t", NaN) / nf / n
    row = (state, block, i, 1e3 * seconds / STEPS, timers["kick!"] / nf,
           get(timers, "refinement", 0.0) / STEPS, integrator.stats.naccept - stats.naccept,
           nf, last(first(n_active(integrator.p.semi))), integrator.t, stall,
           load.foreign_cores)
    println(io, join(row, ","))
    flush(io)
    @printf("%-9s block %3d, turn %d: step %.2f ms, RHS %.3f ms, refinement %.2f ms/step, stall %.2f, load %.2f\n",
            state, block, i, row[4], row[5], row[6], stall, load.foreign_cores)
    flush(stdout)
    return integrator
end

function interleave(make, state, io)
    for i in 0:N_BLOCKS
        order = iseven(i) ? LABELS : reverse(LABELS)
        for block in order
            turn(() -> make(block), state, block, i, io)
        end
    end
end

function main()
    mkpath(OUT)
    config = copy(BUDGET_DEFAULTS)
    config["t_start"] = get(ARGS_, "t_start", "4")
    case = setup(:vortex_street; size=:small, nhs=NHS, refinement=:on, shifting=:fast,
                 tspan=(0.0, 9.0), update_strategy=SerialUpdate(), spacing_ratio=RATIO)
    open(joinpath(OUT, "runs.csv"), "w") do io
        println(io, "state,block,turn,step_ms,rhs_ms,refinement_ms_per_step,steps,nf,n_fluid,t_end,stall,foreign_cores")
        # Compile
        for block in LABELS
            integrator = Base.invokelatest(make_early, case, block)
            do_steps!(integrator, 3)
        end
        pin!(config)
        if "early" in STATES
            Base.invokelatest(interleave, block -> make_early(case, block), "early", io)
        end
        if "developed" in STATES
            integrator = Base.invokelatest(develop, case, config, OUT)
            pin!(config)
            Base.invokelatest(interleave, block -> make_developed(integrator, block),
                              "developed", io)
        end
    end
end

main()
