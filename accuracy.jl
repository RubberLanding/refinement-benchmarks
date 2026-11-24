# Accuracy of one configuration at a fixed simulated time, for the refined and uniform runs.
# One process per configuration; the run is not timed carefully, use `ab_interleaved.py`
# for times.
#
#   julia --project=<env> -t 8 benchmarks/accuracy.jl case=taylor_green size=small \
#       refinement=on out=<dir>
#
# Arguments (`key=value`): `case`, `size`, `nhs`, `refinement`, `shifting` as in `run_full.jl`,
# `t_end`, `samples`, `dtmax_factor` (multiplies `dtmax` of the case).
#
# - Taylor-Green: errors against the exact solution at the particles, weighted with the
#   volume, at `samples` equidistant times in `(0, t_end]`. The norms are relative to the
#   exact velocity.
# - Pipe flow: velocity on the sections `x = 0.25, 0.5, 0.75`, averaged over the samples in
#   the second half of the time. There is no exact solution, so `compare_accuracy.py`
#   compares the sections with a finer uniform run.
#
# Output in `out`: `accuracy.csv` (one row per sample), `sections.csv` (pipe flow),
# `accuracy_meta.csv`.

include("run_full.jl")

const ACCURACY_DEFAULTS = Dict("case" => "taylor_green", "size" => "small",
                               "nhs" => "", "refinement" => "on", "shifting" => "fast",
                               "t_end" => "", "samples" => "20", "dtmax_factor" => "1.0",
                               "out" => "")

# Wendland C2 with the same width in all runs, so that the sections of all runs have the
# same filter. `H_SECTION` is the coarse smoothing length of size `small`.
const H_SECTION = 1.5 * 0.4 / 34
const SECTIONS_X = (0.25, 0.5, 0.75)
wendland(q) = q < 2 ? (1 - q / 2)^4 * (2q + 1) : 0.0

fluid_values(integrator) = begin
    semi = integrator.p.semi
    system = first(semi.systems)
    v_ode, u_ode = integrator.u.x
    v = TP.wrap_v(v_ode, system, semi)
    u = TP.wrap_u(u_ode, system, semi)
    active = collect(TP.each_active_particle(system))
    x = [TP.current_coords(u, system, a) for a in active]
    vel = [TP.current_velocity(v, system, a) for a in active]
    # In both cases, the reference density is constant
    mass = [TP.hydrodynamic_mass(system, a) for a in active]
    return (; x, vel, mass)
end

function taylor_green_error(integrator)
    (; x, vel, mass) = fluid_values(integrator)
    t = integrator.t
    nu = 1.0 / 100
    factor = exp(-8 * pi^2 * nu * t)
    sum_sq = 0.0
    sum_abs = 0.0
    exact_sq = 0.0
    exact_abs = 0.0
    max_error = 0.0
    energy = 0.0
    sum_box = 0.0
    volume_box = 0.0
    exact_box = 0.0
    total = 0.0
    for (pos, v, m) in zip(x, vel, mass)
        p = mod.(pos, 1.0)
        exact = factor .* [-cos(2pi * p[1]) * sin(2pi * p[2]),
                           sin(2pi * p[1]) * cos(2pi * p[2])]
        difference = sqrt(sum(abs2, v .- exact))
        size_exact = sqrt(sum(abs2, exact))
        sum_sq += m * difference^2
        sum_abs += m * difference
        exact_sq += m * size_exact^2
        exact_abs += m * size_exact
        max_error = max(max_error, difference)
        energy += m * sum(abs2, v) / 2
        total += m
        if 0.35 < p[1] < 0.65 && 0.35 < p[2] < 0.65
            sum_box += m * difference^2
            exact_box += m * size_exact^2
            volume_box += m
        end
    end
    return (; t, steps=integrator.stats.naccept, n=length(x), mass=total,
            l2=sqrt(sum_sq / exact_sq), l1=sum_abs / exact_abs,
            max_over_U=max_error / factor,
            # The exact energy decays with `factor^2` from `1/4` (mean of |v|^2 / 2)
            energy_over_exact=energy / total / (0.25 * factor^2),
            l2_refined_box=sqrt(sum_box / max(exact_box, eps())))
end

# Velocity on points with a common filter, and the flux. The section points keep away
# from the walls by half a filter width.
function pipe_sections(integrator)
    (; x, vel, mass) = fluid_values(integrator)
    rows = NamedTuple[]
    for xs in SECTIONS_X
        near = [i for i in eachindex(x) if abs(x[i][1] - xs) < 2 * H_SECTION]
        for y in 0.02:0.02:0.38
            w = 0.0
            ux = 0.0
            uy = 0.0
            for i in near
                r = hypot(x[i][1] - xs, x[i][2] - y)
                weight = mass[i] * wendland(r / H_SECTION)
                w += weight
                ux += weight * vel[i][1]
                uy += weight * vel[i][2]
            end
            push!(rows, (; x=xs, y, ux=ux / w, uy=uy / w))
        end
    end
    return rows
end

function accuracy_main(args)
    config = copy(ACCURACY_DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end
    refinement = Symbol(config["refinement"])
    nhs = isempty(config["nhs"]) ? (refinement === :on ? :tree_variable : :grid) :
          Symbol(config["nhs"])
    size = something(tryparse(Float64, config["size"]), Symbol(config["size"]))
    case = setup(Symbol(config["case"]); size, nhs, refinement,
                 shifting=Symbol(config["shifting"]), update_strategy=SerialUpdate())
    t_end = isempty(config["t_end"]) ? (config["case"] == "taylor_green" ? 1.0 : 2.0) :
            parse(Float64, config["t_end"])
    return Base.invokelatest(accuracy_run, config, case, t_end)
end

function accuracy_run(config, case, t_end)
    (; ode, callbacks, alg, solve_kwargs, meta) = case
    samples = parse(Int, config["samples"])
    factor = parse(Float64, config["dtmax_factor"])
    solve_kwargs = merge(solve_kwargs, (; dtmax=factor * solve_kwargs.dtmax))
    out = config["out"]
    mkpath(out)
    is_pipe = config["case"] == "pipe_flow"

    t0 = time()
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    startup = time() - t0
    errors = NamedTuple[]
    n_min, n_max = typemax(Int), 0
    sections = Dict{Tuple{Float64, Float64}, Vector{NTuple{2, Float64}}}()
    n_samples = 0
    next = 1
    failed = ""
    steps_done = 0
    while integrator.t < t_end - 1e-12
        # Not `add_tstop!`, so that the step sizes are those of the normal run
        try
            step!(integrator)
        catch e
            # Keep what was recorded until here, e.g. when particles leave the domain
            failed = "t = $(round(integrator.t, digits=4)): " *
                     first(sprint(showerror, e), 80)
            break
        end
        steps_done += 1
        if is_pipe && steps_done % 10 == 0
            (; vel) = fluid_values(integrator)
            append_row(joinpath(out, "progress.csv"),
                       (; t=integrator.t, step=steps_done, n=length(vel),
                        max_speed=maximum(v -> sqrt(sum(abs2, v)), vel)))
        end
        if !TP.SciMLBase.successful_retcode(TP.SciMLBase.check_error(integrator))
            failed = "failed at t = $(integrator.t)"
            break
        end
        n = last(first(n_active(integrator.p.semi)))
        n_min, n_max = min(n, n_min), max(n, n_max)
        if integrator.t >= next * t_end / samples
            next = floor(Int, integrator.t / (t_end / samples)) + 1
            if is_pipe
                for row in pipe_sections(integrator)
                    append_row(joinpath(out, "sections_time.csv"),
                               (; sample=next - 1, t=integrator.t, row...))
                end
                if integrator.t >= t_end / 2
                    n_samples += 1
                    for row in pipe_sections(integrator)
                        push!(get!(sections, (row.x, row.y), NTuple{2, Float64}[]),
                              (row.ux, row.uy))
                    end
                end
            else
                push!(errors, taylor_green_error(integrator))
                append_row(joinpath(out, "accuracy.csv"), last(errors))
            end
        end
    end
    wall = time() - t0

    if is_pipe
        rows = [(; x=key[1], y=key[2], ux=mean(first.(values)), uy=mean(last.(values)),
                 ux_std=std(first.(values)), samples=length(values))
                for (key, values) in sort(collect(sections); by=first)]
        write_csv(joinpath(out, "sections.csv"), rows)
    end
    write_csv(joinpath(out, "accuracy_meta.csv"),
              [(; case=config["case"], size=config["size"], refinement=config["refinement"],
                shifting=config["shifting"], dtmax_factor=factor, dtmax=solve_kwargs.dtmax,
                max_spacing=meta.max_spacing, t_end=integrator.t, steps=steps_done,
                accepted=integrator.stats.naccept, rejected=integrator.stats.nreject,
                rhs=integrator.stats.nf, startup_wall=startup, wall,
                n_initial=meta.n_initial, n_min, n_max,
                n_final=last(first(n_active(integrator.p.semi))),
                commit=git_commit(pkgdir(TrixiParticles)),
                pn=git_commit(pkgdir(PointNeighbors)), failed=failed)])
    println("done: $(config["case"]) $(config["refinement"]) $failed, $steps_done steps, ",
            "$(round(wall, digits=1)) s")
end

append_row(file, row) = begin
    new = !isfile(file)
    open(file, "a") do io
        new && println(io, join(keys(row), ","))
        println(io, join(map(csv_value, values(row)), ","))
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    accuracy_main(ARGS)
end
