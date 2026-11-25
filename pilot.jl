# Pilot: the number of particles over time, to find when a refined run is developed and what
# it costs to get there. The timings are only rough (one run, no interleaving).
#
# Run from the worktree root with
#   julia --project=run -t 8 benchmarks/pilot.jl case=vortex_street size=small ratio=2 t_end=8
#
# Arguments (`key=value`): `case`, `size`, `nhs`, `refinement`, `shifting`, `ratio`, `update`
# as in `run_full.jl`,
# - `t_end`: simulated time (the time span of the example is extended to it)
# - `every`: write a row every `every` steps (default: 20)
# - `out`:   output directory, `results/pilot/<timestamp>_<config>` by default
#
# Output in `out`: `meta.toml` and `progress.csv`, written during the run.

include("run_full.jl")

const PILOT_DEFAULTS = Dict("case" => "vortex_street", "size" => "small",
                            "nhs" => "tree_variable", "refinement" => "on",
                            "shifting" => "fast", "ratio" => "", "update" => "serial",
                            "t_end" => "8", "every" => "20", "out" => "")

function pilot_main(args)
    config = copy(PILOT_DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end
    t_end = parse(Float64, config["t_end"])
    ratio = isempty(config["ratio"]) ? (;) :
            (; spacing_ratio=parse(Int, config["ratio"]))
    case = setup(Symbol(config["case"]);
                 size=something(tryparse(Float64, config["size"]), Symbol(config["size"])),
                 nhs=Symbol(config["nhs"]), refinement=Symbol(config["refinement"]),
                 shifting=Symbol(config["shifting"]), tspan=(0.0, t_end),
                 update_strategy=config["update"] == "serial" ? SerialUpdate() :
                                 ParallelUpdate(), ratio...)

    # The examples define closures in `trixi_include`, which are newer than this function
    return Base.invokelatest(pilot, config, case, t_end)
end

function pilot(config, case, t_end)
    (; ode, callbacks, alg, solve_kwargs, meta) = case
    out = config["out"]
    if isempty(out)
        name = join((Dates.format(now(), "yyyymmdd-HHMMSS"), meta.case, meta.size, meta.nhs,
                     meta.refinement, meta.shifting, "ratio$(config["ratio"])",
                     "t$(Threads.nthreads())"), "_")
        out = joinpath(@__DIR__, "results", "pilot", name)
    end
    mkpath(out)
    write_meta(joinpath(out, "meta.toml"), (; steps="until t=$t_end", runs=1, warmup=false),
               meta)

    start = time()
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    open(joinpath(out, "progress.csv"), "w") do io
        println(io, "step,rejected,t,dt,wall_s,n_fluid,n_open_boundary,v_max,load1")
        every = parse(Int, config["every"])
        write_row() = begin
            counts = n_active(integrator.p.semi)
            n_open = sum((n for (name, n) in counts if name === :OpenBoundarySystem); init=0)
            fluid = first(integrator.p.semi.systems)
            v = TP.wrap_v(integrator.u.x[1], fluid, integrator.p.semi)
            v_max = maximum(a -> sqrt(sum(abs2, TP.current_velocity(v, fluid, a))),
                            TP.each_active_particle(fluid))
            println(io,
                    join((integrator.stats.naccept, integrator.stats.nreject, integrator.t,
                          integrator.dt, time() - start, last(first(counts)), n_open, v_max,
                          Sys.loadavg()[1]), ","))
            flush(io)
        end
        write_row()
        while integrator.t < t_end
            step!(integrator)
            if !TP.SciMLBase.successful_retcode(TP.SciMLBase.check_error(integrator))
                write_row()
                error("time integration failed at t = $(integrator.t)")
            end
            integrator.stats.naccept % every == 0 && write_row()
        end
        write_row()
    end
    println("Results in $out")

    return out
end

if abspath(PROGRAM_FILE) == @__FILE__
    pilot_main(ARGS)
end
