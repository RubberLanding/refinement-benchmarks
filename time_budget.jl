# Time budget (Phase 4, see `PLAN.md`): the time of each section of a refined run in the
# early state (from the refinement startup on) and in the developed state (from `t_start` on).
#
# `restart_with` isn't supported with refinement, so the developed state is simulated here
# once. Each measured run then starts from its own `deepcopy` of the integrator.
# Run from the worktree root, with one process per configuration and nothing else of ours
# running:
#   julia --project=run -t 8 benchmarks/time_budget.jl case=vortex_street ratio=2 \
#       nhs=tree_pruned t_start=4 out=benchmarks/results/budget/<name>
#
# Arguments (`key=value`): `case`, `size`, `nhs`, `refinement`, `shifting`, `ratio`, `update`,
# `steps`, `runs` as in `run_full.jl`, and
# - `t_start`: simulated time of the developed state
# - `pin`:     `auto` moves the process to the quietest cores before each run (see `quiet_cores`),
#              or `none`. It first waits until they are quiet, at most `max_wait` hours.
# - `max_load`, `max_runs`: runs with more than `max_load` cores of other load on our cores
#              and their siblings are repeated, up to `max_runs` runs in total. All runs are
#              written, with the load.
# - `states`:  `early`, `developed` or `early,developed`
# - `check`:   `true` compares a copy of the integrator with the original (a test)
# - `every`:   write a row of `progress.csv` every `every` steps
# - `out`:     output directory (required)
#
# Output in `out`: `early/` and `developed/` with the files of `run_full.jl` (`runs.csv` has
# additional columns with the load during the run) and `progress.csv`. Summarize them with
# `time_budget.py`.

include("run_full.jl")

const BUDGET_DEFAULTS = Dict("case" => "vortex_street", "size" => "small",
                             "nhs" => "tree_pruned", "refinement" => "on",
                             "shifting" => "fast", "ratio" => "", "update" => "serial",
                             "steps" => "100", "runs" => "3", "max_runs" => "8",
                             "pin" => "auto", "max_load" => "0.5", "max_wait" => "6", "t_start" => "4",
                             "states" => "early,developed", "check" => "false",
                             "every" => "20", "out" => "")

# The particle counts are recorded by callbacks that are copied with the integrator, so
# they write to this global and not to a captured vector
const COUNTS = NamedTuple[]

function global_count_recorder(label, interval)
    condition(u, t, integrator) = TP.condition_integrator_interval(integrator, interval)
    function affect!(integrator)
        for (system, n) in n_active(integrator.p.semi)
            push!(COUNTS, (; label, step=integrator.stats.naccept, t=integrator.t,
                           system=string(system), n))
        end
        TP.SciMLBase.u_modified!(integrator, false)
    end

    return DiscreteCallback(condition, affect!, save_positions=(false, false))
end

# ==========================================================================================
# ==== The load of the machine during a run, as in `ab_interleaved.py`
const TICKS = 100

function cpu_busy()
    busy = Dict{Int, Int}()
    for line in eachline("/proc/stat")
        m = match(r"^cpu(\d+) (.*)$", line)
        isnothing(m) && continue
        times = parse.(Int, split(m[2]))[1:8]
        busy[parse(Int, m[1])] = sum(times) - times[4] - times[5]
    end
    return busy
end

function own_cpu()
    fields = split(last(split(read("/proc/self/stat", String), ")")))
    return (parse(Int, fields[12]) + parse(Int, fields[13])) / TICKS
end

function cpu_list(text)
    cpus = Int[]
    for part in split(strip(text), ",")
        bounds = parse.(Int, split(part, "-"))
        append!(cpus, first(bounds):last(bounds))
    end
    return cpus
end

# The cores of this process and their hyperthread siblings
function watched_cpus()
    status = read("/proc/self/status", String)
    cpus = cpu_list(match(r"Cpus_allowed_list:\s*(\S+)", status)[1])
    siblings(cpu) = cpu_list(read("/sys/devices/system/cpu/cpu$cpu/topology/" *
                                  "thread_siblings_list", String))
    return sort!(unique!(reduce(vcat, siblings.(cpus))))
end

# The quietest groups of cores with a shared L3 cache (4 cores on this machine) that hold
# `threads` threads, and the other load on these cores and their siblings. They don't have to
# be neighbors: other jobs are spread over the machine, so 8 quiet neighbors can be rare.
function quiet_cores(threads)
    before = cpu_busy()
    sleep(3)
    after = cpu_busy()
    sys(cpu, file) = read("/sys/devices/system/cpu/cpu$cpu/$file", String)
    groups = unique(sort(cpu_list(sys(cpu, "cache/index3/shared_cpu_list")))
                    for cpu in keys(after))
    loads = [sum(after[c] - before[c] for c in group) / TICKS / 3 for group in groups]
    cpus = Int[]
    load = 0.0
    for i in sortperm(loads)
        length(cpus) >= threads && break
        # Only one hyperthread per core
        append!(cpus, [c for c in groups[i]
                       if c == minimum(cpu_list(sys(c, "topology/thread_siblings_list")))])
        load += loads[i]
    end

    return first(cpus, threads), load
end

# Move all threads of this process to the quietest cores. Wait until their other load is at
# most `max_load` cores, at most `max_wait` hours.
function pin!(config)
    config["pin"] == "auto" || return
    start = time()
    while true
        cpus, load = quiet_cores(Threads.nthreads())
        quiet = load <= parse(Float64, config["max_load"])
        if quiet || time() - start > 3600 * parse(Float64, config["max_wait"])
            run(pipeline(`taskset -acp $(join(cpus, ",")) $(getpid())`, stdout=devnull))
            @printf("on cores %s, other load %.2f cores, waited %.0f min\n",
                    join(cpus, ","), load, (time() - start) / 60)
            flush(stdout)
            return
        end
        sleep(30)
    end
end

load_state() = (; busy=cpu_busy(), own=own_cpu(), time=time())

function load_since(before)
    now = load_state()
    wall = now.time - before.time
    own = now.own - before.own
    difference(cpus) = sum(now.busy[c] - before.busy[c] for c in cpus) / TICKS

    return (; own_cores=own / wall,
            foreign_cores=max(difference(watched_cpus()) - own, 0.0) / wall,
            machine_cores=difference(keys(now.busy)) / wall, load1=Sys.loadavg()[1])
end

# ==========================================================================================
# ==== Runs
function do_steps!(integrator, steps)
    for _ in 1:steps
        step!(integrator)
        if !TP.SciMLBase.successful_retcode(TP.SciMLBase.check_error(integrator))
            error("time integration failed at t = $(integrator.t)")
        end
    end
end

function fresh_integrator(case)
    (; ode, callbacks, alg, solve_kwargs, meta) = deepcopy(case)
    if meta.refinement === :on
        callbacks = CallbackSet(global_count_recorder("before", meta.refinement_interval),
                                callbacks,
                                global_count_recorder("after", meta.refinement_interval))
    end

    return init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
end

# `make` returns the integrator to step, which is timed in the early state (startup)
function measure_state(make, case, steps)
    empty!(COUNTS)
    TP.reset_timer!(TP.timer())
    GC.gc()

    before = load_state()
    t0 = time_ns()
    integrator = make()
    time_init = (time_ns() - t0) / 1e9
    n_startup = n_active(integrator.p.semi)
    stats = (; integrator.stats.naccept, integrator.stats.nreject, integrator.stats.nf)
    t_begin = integrator.t
    # The startup and the steps are timed separately, so `init` isn't part of the step time
    startup_rows = filter(row -> startswith(row.path, "refinement startup"),
                          flatten_timer(TP.timer()))
    TP.reset_timer!(TP.timer())

    t1 = time_ns()
    do_steps!(integrator, steps)
    time_steps = (time_ns() - t1) / 1e9
    load = load_since(before)

    n_end = n_active(integrator.p.semi)
    nhs_bytes = Base.summarysize(integrator.p.semi.neighborhood_search_handler)
    run = (; time_init, time_steps, steps=integrator.stats.naccept - stats.naccept,
           rejected=integrator.stats.nreject - stats.nreject,
           rhs_evaluations=integrator.stats.nf - stats.nf, t_end=integrator.t,
           n_initial=case.meta.n_initial, n_startup=last(first(n_startup)),
           n_end=last(first(n_end)), n_total_end=sum(last, n_end), nhs_bytes, t_begin,
           load...)

    return (; run, rows=vcat(startup_rows, flatten_timer(TP.timer())), counts=copy(COUNTS))
end

function write_state(out, config, case, results)
    mkpath(out)
    numbered(f) = [(; run=i, row...) for (i, result) in enumerate(results) for row in f(result)]
    write_meta(joinpath(out, "meta.toml"),
               (; steps=config["steps"], runs=config["runs"], warmup=true), case.meta)
    write_csv(joinpath(out, "runs.csv"), numbered(r -> [r.run]))
    write_csv(joinpath(out, "timers.csv"), numbered(r -> r.rows))
    write_csv(joinpath(out, "counts.csv"), numbered(r -> r.counts))
end

function report_run(state, i, (; run))
    @printf("%s run %d: step %.2f ms, %d steps, %d RHS, %d rejected, %d to %d particles, other load %.2f cores\n",
            state, i, 1e3 * run.time_steps / run.steps, run.steps, run.rhs_evaluations,
            run.rejected, run.n_startup, run.n_end, run.foreign_cores)
    flush(stdout)
end

# Advance to the developed state, and write the progress
function develop(case, config, out)
    t_start = parse(Float64, config["t_start"])
    every = parse(Int, config["every"])
    pin!(config)
    integrator = fresh_integrator(case)
    start = time()
    open(joinpath(out, "progress.csv"), "w") do io
        println(io, "step,rejected,t,dt,wall_s,n_fluid,load1")
        write_row() = (println(io, join((integrator.stats.naccept, integrator.stats.nreject,
                                         integrator.t, integrator.dt, time() - start,
                                         last(first(n_active(integrator.p.semi))),
                                         Sys.loadavg()[1]), ","));
                       flush(io))
        write_row()
        while integrator.t < t_start
            do_steps!(integrator, 1)
            integrator.stats.naccept % every == 0 && write_row()
        end
        write_row()
    end
    @printf("developed state: t = %.3f, step %d, %.0f s\n", integrator.t,
            integrator.stats.naccept, time() - start)
    flush(stdout)

    return integrator
end

# A copy of the integrator must do the same as the original
function check_copy(integrator, steps)
    copied = deepcopy(integrator)
    do_steps!(copied, steps)
    do_steps!(integrator, steps)
    same = integrator.u.x[1] == copied.u.x[1] && integrator.u.x[2] == copied.u.x[2] &&
           integrator.t == copied.t && integrator.stats.nf == copied.stats.nf
    println("copy identical to the original after $steps steps: $same ",
            "(t = $(integrator.t), $(last(first(n_active(integrator.p.semi)))) particles)")
end

function budget(config, case)
    out = config["out"]
    steps = parse(Int, config["steps"])
    runs = parse(Int, config["runs"])
    states = split(config["states"], ",")
    mkpath(out)

    # Compile
    measure_state(() -> fresh_integrator(case), case, 2 * case.meta.refinement_interval + 1)
    println("warm"); flush(stdout)

    function measure_runs(state, make)
        results = []
        max_load = parse(Float64, config["max_load"])
        clean() = count(r -> r.run.foreign_cores <= max_load, results)
        while clean() < runs && length(results) < parse(Int, config["max_runs"])
            pin!(config)
            result = measure_state(make, case, steps)
            push!(results, result)
            report_run(state, length(results), result)
            # Write after each run, so that long runs can be inspected
            write_state(joinpath(out, state), config, case, results)
        end
    end

    "early" in states && measure_runs("early", () -> fresh_integrator(case))
    if "developed" in states
        integrator = develop(case, config, out)
        config["check"] == "true" && check_copy(deepcopy(integrator), steps)
        # The first copy steps on cold code and memory, so it is not measured
        measure_state(() -> deepcopy(integrator), case, 2 * case.meta.refinement_interval + 1)
        measure_runs("developed", () -> deepcopy(integrator))
    end
    println("Results in $out")
end

function budget_main(args)
    config = copy(BUDGET_DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end
    isempty(config["out"]) && error("`out` is required")
    ratio = isempty(config["ratio"]) ? (;) : (; spacing_ratio=parse(Int, config["ratio"]))
    # Keep the time span longer than the measured runs
    t_start = parse(Float64, config["t_start"])
    case = setup(Symbol(config["case"]);
                 size=something(tryparse(Float64, config["size"]), Symbol(config["size"])),
                 nhs=Symbol(config["nhs"]), refinement=Symbol(config["refinement"]),
                 shifting=Symbol(config["shifting"]), tspan=(0.0, 2 * t_start + 1),
                 update_strategy=config["update"] == "serial" ? SerialUpdate() :
                                 ParallelUpdate(), ratio...)

    # The examples define closures in `trixi_include`, which are newer than this function
    return Base.invokelatest(budget, config, case)
end

if abspath(PROGRAM_FILE) == @__FILE__
    budget_main(ARGS)
end
