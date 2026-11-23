# Phase 2, full runs (see `PLAN.md`): time per step for the RHS and the refinement
# callback, and the time of the refinement startup, with the TimerOutputs of each phase.
#
# The example is included once. The warm-up run and each measured run start from their
# own `deepcopy` of the ODE problem and the callbacks. Including the example again would
# create new types for its anonymous functions (e.g. the refinement criteria), which are
# part of the system types, so everything would be compiled again in every run.
# The warm-up has `2 * refinement_interval + 1` steps, then `runs` measured runs of
# `steps` time steps each follow.
# Run from the worktree root with, for example,
#   julia --project=run -t 8 benchmarks/run_full.jl case=taylor_green size=small \
#       nhs=tree_variable refinement=on steps=100 runs=5
#
# Arguments (`key=value`, defaults in `DEFAULTS`):
# - `case`:       `taylor_green`, `pipe_flow`
# - `size`:       `tiny`, `small`, `medium`, `large` or a maximum particle spacing
# - `nhs`:        `grid`, `tree_uniform`, `tree_variable`
# - `refinement`: `on`, `min`, `max` (`min` and `max` are the uniform baselines)
# - `update`:     `serial` or `parallel` update strategy of the NHS
# - `shifting`:   `default` or `fast` (see `setups.jl`)
# - `ratio`:      `spacing_ratio` of the vortex street (see `setups.jl`)
# - `steps`:      time steps per run after the startup
# - `runs`:       measured runs
# - `warmup`:     `true` or `false`
# - `out`:        output directory, `results/full/<timestamp>_<config>` by default
#
# Output in `out`:
# - `meta.toml`:   configuration, commits, Julia version, threads and machine
# - `runs.csv`:    one row per run (wall times, steps, RHS evaluations, particle counts)
# - `timers.csv`:  the timer tree of each run, one row per section
# - `counts.csv`:  active particles of each system before and after each refinement call

include("setups.jl")

using Dates
using Printf
using Statistics
const TimerOutputs = TP.TimerOutputs

const DEFAULTS = Dict("case" => "taylor_green", "size" => "tiny", "nhs" => "tree_variable",
                      "refinement" => "on", "shifting" => "default", "ratio" => "", "update" => "serial", "steps" => "100",
                      "runs" => "5", "warmup" => "true", "out" => "")

function parse_arguments(args)
    config = copy(DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end

    size = something(tryparse(Float64, config["size"]), Symbol(config["size"]))
    update_strategy = config["update"] == "serial" ? SerialUpdate() :
                      config["update"] == "parallel" ? ParallelUpdate() :
                      error("unknown update strategy `$(config["update"])`")

    return (; case=Symbol(config["case"]), size, nhs=Symbol(config["nhs"]),
            refinement=Symbol(config["refinement"]), shifting=Symbol(config["shifting"]),
            options=isempty(config["ratio"]) ? (;) :
                    (; spacing_ratio=parse(Int, config["ratio"])), update_strategy,
            steps=parse(Int, config["steps"]), runs=parse(Int, config["runs"]),
            warmup=parse(Bool, config["warmup"]), out=config["out"])
end

# ==========================================================================================
# ==== One run
# A callback that records the active particles of each system at the refinement steps.
# One is placed before and one after the refinement callback (callbacks are applied
# in order).
function count_recorder(records, label, interval)
    condition(u, t, integrator) = TP.condition_integrator_interval(integrator, interval)
    function affect!(integrator)
        for (system, n) in n_active(integrator.p.semi)
            push!(records, (; label, step=integrator.stats.naccept, t=integrator.t,
                            system=string(system), n))
        end
        TP.SciMLBase.u_modified!(integrator, false)
    end

    return DiscreteCallback(condition, affect!, save_positions=(false, false))
end

function measure(config, case, steps)
    (; ode, callbacks, alg, solve_kwargs, meta) = deepcopy(case)
    interval = meta.refinement_interval

    counts = NamedTuple[]
    if config.refinement === :on
        callbacks = CallbackSet(count_recorder(counts, "before", interval), callbacks,
                                count_recorder(counts, "after", interval))
    end

    TP.reset_timer!(TP.timer())
    GC.gc()

    t0 = time_ns()
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    time_init = (time_ns() - t0) / 1e9
    n_startup = n_active(integrator.p.semi)

    t1 = time_ns()
    for _ in 1:steps
        step!(integrator)
        if !TP.SciMLBase.successful_retcode(TP.SciMLBase.check_error(integrator))
            error("time integration failed at t = $(integrator.t)")
        end
    end
    time_steps = (time_ns() - t1) / 1e9

    timer = deepcopy(TP.timer())
    n_end = n_active(integrator.p.semi)

    run = (; time_init, time_steps, steps=integrator.stats.naccept,
           rejected=integrator.stats.nreject, rhs_evaluations=integrator.stats.nf,
           t_end=integrator.t, n_initial=meta.n_initial, n_startup=last(first(n_startup)),
           n_end=last(first(n_end)), n_total_end=sum(last, n_end))

    return (; run, timer, counts, meta)
end

# ==========================================================================================
# ==== Output
# All sections of the timer as rows with the path from the root
function flatten_timer(timer)
    rows = NamedTuple[]
    function visit(t, path)
        for (name, child) in t.inner_timers
            child_path = isempty(path) ? name : path * " / " * name
            push!(rows, (; path=child_path, ncalls=TimerOutputs.ncalls(child),
                         time_ns=TimerOutputs.time(child),
                         allocated_bytes=TimerOutputs.allocated(child)))
            visit(child, child_path)
        end
    end
    visit(timer, "")

    return rows
end

csv_value(x::AbstractString) = occursin(r"[,\"]", x) ? "\"" * replace(x, "\"" => "\"\"") * "\"" : x
csv_value(x) = string(x)

function write_csv(file, rows)
    isempty(rows) && return
    open(file, "w") do io
        println(io, join(keys(first(rows)), ","))
        for row in rows
            println(io, join(map(csv_value, values(row)), ","))
        end
    end
end

function git_commit(dir)
    commit = readchomp(`git -C $dir rev-parse --short HEAD`)
    dirty = !isempty(readchomp(`git -C $dir status --porcelain --untracked-files=no`))
    return dirty ? commit * "-dirty" : commit
end

function git_branch(dir)
    return readchomp(`git -C $dir rev-parse --abbrev-ref HEAD`)
end

function write_meta(file, config, meta)
    trixi_dir = pkgdir(TrixiParticles)
    pn_dir = pkgdir(PointNeighbors)
    open(file, "w") do io
        println(io, "date = \"$(now())\"")
        for (key, value) in pairs(meta)
            println(io, "$key = \"$value\"")
        end
        println(io, "steps = $(config.steps)")
        println(io, "runs = $(config.runs)")
        println(io, "warmup = $(config.warmup)")
        println(io, "trixiparticles = \"$(git_branch(trixi_dir)) $(git_commit(trixi_dir))\"")
        println(io, "pointneighbors = \"$(git_branch(pn_dir)) $(git_commit(pn_dir))\"")
        println(io, "benchmarks = \"$(git_commit(@__DIR__))\"")
        println(io, "julia = \"$VERSION\"")
        println(io, "threads = $(Threads.nthreads())")
        println(io, "hostname = \"$(gethostname())\"")
        println(io, "cpu = \"$(Sys.cpu_info()[1].model)\"")
        # The machine may be shared, so record the load at the end of the runs
        println(io, "loadavg = \"$(join(round.(Sys.loadavg(), digits=1), " "))\"")
    end
end

# The time per call of a top-level section, in ms
function section_ms(rows, path)
    index = findfirst(row -> row.path == path, rows)
    isnothing(index) && return (; total=0.0, ncalls=0)

    return (; total=rows[index].time_ns / 1e6, ncalls=rows[index].ncalls)
end

function print_summary(runs, timer_rows)
    println()
    @printf("%4s %10s %10s %6s %7s %8s %8s %10s %10s %10s\n", "run", "init [s]",
            "steps [s]", "steps", "RHS", "n_start", "n_end", "RHS [ms]", "refine/call",
            "startup [s]")
    for (i, (run, rows)) in enumerate(zip(runs, timer_rows))
        kick = section_ms(rows, "kick!")
        drift = section_ms(rows, "drift!")
        refinement = section_ms(rows, "refinement")
        startup = section_ms(rows, "refinement startup")
        @printf("%4d %10.3f %10.3f %6d %7d %8d %8d %10.3f %10.1f %10.3f\n", i,
                run.time_init, run.time_steps, run.steps, run.rhs_evaluations,
                run.n_startup, run.n_end, (kick.total + drift.total) / run.rhs_evaluations,
                refinement.ncalls > 0 ? refinement.total / refinement.ncalls : 0.0,
                startup.total / 1e3)
    end
    @printf("median: init %.3f s, steps %.3f s, time per step %.2f ms\n",
            median(r.time_init for r in runs), median(r.time_steps for r in runs),
            1e3 * median(r.time_steps / r.steps for r in runs))
end

# ==========================================================================================
function main(args)
    config = parse_arguments(args)

    case = setup(config.case; config.size, config.nhs, config.refinement,
                 config.update_strategy, config.shifting, config.options...)

    # The examples define closures in `trixi_include`, which are newer than `main`
    return Base.invokelatest(measure_all, config, case)
end

function measure_all(config, case)
    if config.warmup
        println("==== Warm-up")
        measure(config, case, 2 * case.meta.refinement_interval + 1)
    end

    out = config.out
    if isempty(out)
        name = join((Dates.format(now(), "yyyymmdd-HHMMSS"), config.case, config.size,
                     config.nhs, config.refinement, config.shifting,
                     ("ratio$(v)" for v in values(config.options))...,
                     lowercase(string(config.update_strategy)),
                     "t$(Threads.nthreads())"), "_")
        out = joinpath(@__DIR__, "results", "full", replace(name, "()" => ""))
    end
    mkpath(out)

    runs = NamedTuple[]
    timers = []
    timer_rows = Vector{NamedTuple}[]
    all_timers = NamedTuple[]
    all_counts = NamedTuple[]
    meta = nothing
    for i in 1:config.runs
        println("==== Run $i/$(config.runs)")
        result = measure(config, case, config.steps)
        meta = result.meta

        rows = flatten_timer(result.timer)
        push!(runs, (; run=i, result.run...))
        push!(timers, result.timer)
        push!(timer_rows, rows)
        append!(all_timers, [(; run=i, row...) for row in rows])
        append!(all_counts, [(; run=i, row...) for row in result.counts])

        # Write after each run, so that long runs can be inspected
        write_meta(joinpath(out, "meta.toml"), config, meta)
        write_csv(joinpath(out, "runs.csv"), runs)
        write_csv(joinpath(out, "timers.csv"), all_timers)
        write_csv(joinpath(out, "counts.csv"), all_counts)
    end

    print_summary(runs, timer_rows)
    println("Results in $out")
    i_median = sortperm([r.time_steps for r in runs])[cld(length(runs), 2)]
    println("Timers of the median run ($i_median):")
    TimerOutputs.print_timer(timers[i_median])

    return out
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
