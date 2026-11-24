# Worker of `ab_interleaved.py`: one warm process that holds one case of one commit.
#
# The driver starts one worker per label and case, and lets them take turns. The worker
# compiles everything once (a short run and some RHS calls) and then waits for commands on
# stdin, one per line. After each command it prints a line that starts with `@@ `:
#   full <block> <file prefix>   one run of `steps` steps as in `run_full.jl`
#   rhs <block> <file prefix>    `rhs_calls` timed RHS evaluations on a fixed state
#   quit
# Everything else that the process prints goes to the log file.
#
# Arguments (`key=value`): `case`, `size`, `nhs`, `refinement`, `shifting`, `steps`, `rhs_calls`,
# `advance` (steps before the state of the RHS calls), `commit`, `pn_commit`, `out`.
#
# Output in `out`, one set of files per file prefix (empty for the measured blocks,
# `block0_` for the discarded first block), with a column `block` in each:
# `runs.csv`, `timers.csv` and `counts.csv` as in `run_full.jl`, `rhs_samples.csv` (one
# row per RHS evaluation), `rhs_timers_blocks.csv` (timer sections per RHS evaluation).

include("profile.jl")

const WORKER_DEFAULTS = Dict("case" => "taylor_green", "size" => "small",
                             "nhs" => "tree_variable", "refinement" => "on",
                             "shifting" => "fast",
                             "steps" => "100", "rhs_calls" => "100", "advance" => "20",
                             "commit" => "", "pn_commit" => "", "out" => "")

# RHS evaluations before the timed ones. The other workers ran in between, so the caches
# and the thread pool are cold.
const RHS_DISCARD = 20

reply(message) = (println(stdout, "@@ ", message); flush(stdout))

# Append `rows` to a CSV file and write the header if it is new
function append_csv(file, rows)
    isempty(rows) && return
    new = !isfile(file)
    open(file, "a") do io
        new && println(io, join(keys(first(rows)), ","))
        for row in rows
            println(io, join(map(csv_value, values(row)), ","))
        end
    end
end

# Same keys as in `write_meta`, but the sources are not git checkouts
function write_worker_meta(file, config, meta)
    open(file, "w") do io
        println(io, "date = \"$(now())\"")
        for (key, value) in pairs(meta)
            println(io, "$key = \"$value\"")
        end
        println(io, "steps = $(config["steps"])")
        println(io, "rhs_calls = $(config["rhs_calls"])")
        println(io, "advance = $(config["advance"])")
        println(io, "trixiparticles = \"$(config["commit"])\"")
        println(io, "pointneighbors = \"$(config["pn_commit"])\"")
        println(io, "source = \"$(pkgdir(TrixiParticles))\"")
        println(io, "benchmarks = \"$(git_commit(@__DIR__))\"")
        println(io, "julia = \"$VERSION\"")
        println(io, "threads = $(Threads.nthreads())")
        println(io, "hostname = \"$(gethostname())\"")
        println(io, "cpu = \"$(Sys.cpu_info()[1].model)\"")
        println(io, "loadavg = \"$(join(round.(Sys.loadavg(), digits=1), " "))\"")
    end
end

function full_block(case, steps, block, out, prefix)
    (; run, timer, counts) = measure((; refinement=case.meta.refinement), case, steps)
    # `run` numbers the rows as in `run_full.jl`, so the other scripts can read the files
    append_csv(joinpath(out, prefix * "runs.csv"), [(; run=block, block, run...)])
    append_csv(joinpath(out, prefix * "timers.csv"),
               [(; run=block, block, row...) for row in flatten_timer(timer)])
    append_csv(joinpath(out, prefix * "counts.csv"),
               [(; run=block, block, row...) for row in counts])

    return @sprintf("step %.2f ms, %d steps, %d RHS, %d particles at the end",
                    1e3 * run.time_steps / run.steps, run.steps, run.rhs_evaluations,
                    run.n_end)
end

function rhs_block(integrator, calls, block, out, prefix)
    v_ode, u_ode = integrator.u.x
    dv_ode = zero(v_ode)
    kick!() = TP.kick!(dv_ode, v_ode, u_ode, integrator.p, integrator.t)

    GC.gc()
    for _ in 1:RHS_DISCARD
        kick!()
    end

    TP.reset_timer!(TP.timer())
    samples = zeros(calls)
    for i in 1:calls
        t = time_ns()
        kick!()
        samples[i] = (time_ns() - t) / 1e6
    end
    timers = flatten_timer(TP.timer())

    particles = sum(last, n_active(integrator.p.semi))
    append_csv(joinpath(out, prefix * "rhs_samples.csv"),
               [(; block, call=i, ms=samples[i], particles) for i in 1:calls])
    append_csv(joinpath(out, prefix * "rhs_timers_blocks.csv"),
               [(; block, row..., per_call_ms=row.time_ns / 1e6 / calls)
                for row in timers])

    return @sprintf("RHS median %.3f ms, minimum %.3f ms, %d particles", median(samples),
                    minimum(samples), particles)
end

function worker_loop(config, case)
    steps = parse(Int, config["steps"])
    rhs_calls = parse(Int, config["rhs_calls"])
    out = config["out"]
    mkpath(out)
    write_worker_meta(joinpath(out, "meta.toml"), config, case.meta)

    # Compile: a short run with refinement, then the state of the RHS calls
    warmup = 2 * case.meta.refinement_interval + 1
    measure((; refinement=case.meta.refinement), case, warmup)

    (; ode, callbacks, alg, solve_kwargs) = deepcopy(case)
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    for _ in 1:parse(Int, config["advance"])
        step!(integrator)
    end
    TP.update_nhs!(integrator.p.semi, integrator.u.x[2])
    # The first call also compiles what `rhs_block` needs
    mktempdir(dir -> rhs_block(integrator, 5, 0, dir, ""))
    reply("ready pid=$(getpid())")

    for line in eachline(stdin)
        command, rest... = split(line)
        command == "quit" && break
        block = parse(Int, rest[1])
        prefix = length(rest) > 1 ? String(rest[2]) : ""
        message = command == "full" ? full_block(case, steps, block, out, prefix) :
                  command == "rhs" ? rhs_block(integrator, rhs_calls, block, out, prefix) :
                  error("unknown command `$command`")
        reply(message)
    end
end

function worker_main(args)
    config = copy(WORKER_DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end
    size = something(tryparse(Float64, config["size"]), Symbol(config["size"]))
    case = setup(Symbol(config["case"]); size, nhs=Symbol(config["nhs"]),
                 refinement=Symbol(config["refinement"]), shifting=Symbol(config["shifting"]),
                 update_strategy=SerialUpdate())

    # The examples define closures in `trixi_include`, which are newer than this function
    return Base.invokelatest(worker_loop, config, case)
end

if abspath(PROGRAM_FILE) == @__FILE__
    worker_main(ARGS)
end
