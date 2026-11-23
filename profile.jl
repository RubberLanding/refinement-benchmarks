# Phase 2, a deeper look at one state (see `PLAN.md` and `results/summary.md`).
#
# The state is taken after the refinement startup and `advance` time steps (with the
# refinement calls in these steps). On this state, the sections answer:
# - `distribution`: Which spacings do the fluid particles have, and where?
#   (Why does the pipe flow not benefit from the refinement?)
# - `pairs`: How many neighbors does the NHS return per particle with the uniform search
#   radius and with the per-particle search radii, and how many of them are in the
#   support? How long does the query alone take (empty loop body)?
#   (Is the RHS more expensive because of the neighbor loops?)
# - `rhs`: The timers of `rhs_calls` RHS evaluations without callbacks in between.
# - `profile_rhs`: Sampling profile of `profile_calls` RHS evaluations.
# - `shift`: One refinement call up to the shifting, then `shift_iterations` iterations of
#   Eq. 15 with the residual after each iteration and the time per iteration.
#   (Why is the shifting so expensive?)
# - `profile_shift`: Sampling profile of `profile_calls` calls of `compute_shift!`.
#
# Run from the worktree root with, for example,
#   julia --project=run -t 8 benchmarks/profile.jl case=taylor_green size=small \
#       nhs=tree_variable refinement=on
#
# Arguments (`key=value`, defaults in `PROFILE_DEFAULTS`):
# `case`, `size`, `nhs`, `refinement`, `update`, `shifting`, `ratio` as in `run_full.jl`,
# and
# - `advance`:          time steps after the startup before the state is taken
# - `rhs_calls`:        RHS evaluations for the timers and the query times
# - `profile_calls`:    RHS evaluations and `compute_shift!` calls for the profiles
# - `shift_iterations`: iterations in the `shift` section (default: `max_iterations`)
# - `sections`:         comma-separated list of the sections above, or `all`
# - `out`:              output directory, `results/profile/<timestamp>_<config>` by default
#
# Output in `out`: `meta.toml`, one CSV per section, the profiles as text
# (`profile_*_flat.txt` sorted by own time, `profile_*_tree.txt`) and `summary.txt`
# with what is printed.

include("run_full.jl")

using Profile

const PROFILE_DEFAULTS = Dict("case" => "taylor_green", "size" => "small",
                              "nhs" => "tree_variable", "refinement" => "on", "shifting" => "default", "ratio" => "",
                              "update" => "serial", "advance" => "20", "rhs_calls" => "50",
                              "profile_calls" => "200", "shift_iterations" => "0",
                              "sections" => "all", "out" => "")

const ALL_SECTIONS = ("distribution", "pairs", "rhs", "profile_rhs", "shift",
                      "profile_shift")

function parse_profile_arguments(args)
    config = copy(PROFILE_DEFAULTS)
    for arg in args
        key, value = split(arg, "="; limit=2)
        haskey(config, key) || error("unknown argument `$key`")
        config[key] = value
    end

    size = something(tryparse(Float64, config["size"]), Symbol(config["size"]))
    update_strategy = config["update"] == "serial" ? SerialUpdate() : ParallelUpdate()
    sections = config["sections"] == "all" ? ALL_SECTIONS :
               Tuple(split(config["sections"], ","))
    for section in sections
        section in ALL_SECTIONS || error("unknown section `$section`")
    end

    return (; case=Symbol(config["case"]), size, nhs=Symbol(config["nhs"]),
            refinement=Symbol(config["refinement"]), shifting=Symbol(config["shifting"]),
            options=isempty(config["ratio"]) ? (;) :
                    (; spacing_ratio=parse(Int, config["ratio"])), update_strategy,
            advance=parse(Int, config["advance"]),
            rhs_calls=parse(Int, config["rhs_calls"]),
            profile_calls=parse(Int, config["profile_calls"]),
            shift_iterations=parse(Int, config["shift_iterations"]), sections,
            out=config["out"])
end

# Print to stdout and to `summary.txt`
struct Report
    io::IOStream
end

function report(r::Report, args...)
    println(stdout, args...)
    println(r.io, args...)
    flush(r.io)
end

fluid_systems(semi) = filter(system -> system isa TP.AbstractFluidSystem,
                             collect(semi.systems))

system_name(system) = string(nameof(typeof(system)))

# The spacing of each active fluid particle from its mass
function particle_spacings(system)
    (; reference_density) = TP.get_refinement(system)
    active = TP.each_active_particle(system)

    return [(TP.hydrodynamic_mass(system, particle) / reference_density)^(1 / ndims(system))
            for particle in active]
end

# Run `f` `n` times and return the minimum and median time in ms
function time_ms(f, n)
    times = [1e3 * @elapsed(f()) for _ in 1:n]
    return minimum(times), median(times)
end

# ==========================================================================================
# ==== Distribution of the spacings
function section_distribution(r, out, semi, u_ode)
    report(r, "\n==== Distribution of the particle spacings")
    rows = NamedTuple[]

    for system in fluid_systems(semi)
        refinement = TP.get_refinement(system)
        if isnothing(refinement)
            report(r, "$(system_name(system)): no refinement")
            continue
        end
        (; min_spacing, max_spacing) = refinement

        spacings = particle_spacings(system)
        u = TP.wrap_u(u_ode, system, semi)
        active = collect(TP.each_active_particle(system))
        coords = [TP.current_coords(u, system, particle) for particle in active]

        # Level 0 is `min_spacing`, level 1 is `max_spacing`
        level(spacing) = clamp(log(spacing / min_spacing) / log(max_spacing / min_spacing),
                               0, 1)
        levels = level.(spacings)
        # The target spacing of Alg. 1 that splitting and merging aim for
        target_levels = level.(system.cache.target_spacing[active])
        n = length(levels)
        n_fine = count(<(0.1), levels)

        # Two particles of the mass `m` merge only if `2 m <= max_mass_factor * m_ref`
        # (see `merge_particles!`), so particles at `min_spacing` merge only where the
        # target spacing is at least `(2 / max_mass_factor)^(1 / ndims) * min_spacing`
        merge_level = level((2 / refinement.max_mass_factor)^(1 / ndims(system)) *
                            min_spacing)
        n_coarse = count(>(0.9), levels)

        # The area that the particles cover and the particles that a uniform distribution
        # at `min_spacing` would have in it
        area = sum(s -> s^ndims(system), spacings)
        n_uniform_min = area / min_spacing^ndims(system)
        n_uniform_max = area / max_spacing^ndims(system)

        report(r, @sprintf("%s: %d particles, %.0f%% at min_spacing (level < 0.1), %.0f%% graded, %.0f%% at max_spacing (level > 0.9)",
                           system_name(system), n, 100 * n_fine / n,
                           100 * (n - n_fine - n_coarse) / n, 100 * n_coarse / n))
        report(r, @sprintf("  target spacing: %.0f%% at level < 0.1, %.0f%% at level > 0.9, %.0f%% below the merge level %.2f (two particles at min_spacing can only merge above it)",
                           100 * count(<(0.1), target_levels) / n,
                           100 * count(>(0.9), target_levels) / n,
                           100 * count(<(merge_level), target_levels) / n, merge_level))
        report(r, @sprintf("  uniform at min_spacing: %.0f particles (refined / uniform = %.2f), uniform at max_spacing: %.0f",
                           n_uniform_min, n / n_uniform_min, n_uniform_max))

        # Profiles along each coordinate: particles and mean level in 20 strips
        for dim in 1:ndims(system)
            x = getindex.(coords, dim)
            x_min, x_max = extrema(x)
            n_bins = 20
            width = (x_max - x_min) / n_bins
            line = IOBuffer()
            target_line = IOBuffer()
            for bin in 1:n_bins
                lower = x_min + (bin - 1) * width
                upper = bin == n_bins ? x_max : lower + width
                in_bin = findall(xi -> lower <= xi <= upper, x)
                mean_level = isempty(in_bin) ? NaN : mean(levels[in_bin])
                mean_target = isempty(in_bin) ? NaN : mean(target_levels[in_bin])
                push!(rows, (; system=system_name(system), dim, bin, lower, upper,
                             n=length(in_bin), mean_level, mean_target_level=mean_target,
                             fine=count(<(0.1), levels[in_bin]),
                             coarse=count(>(0.9), levels[in_bin])))
                print(line, @sprintf("%5.2f", mean_level))
                print(target_line, @sprintf("%5.2f", mean_target))
            end
            report(r, @sprintf("  mean level along x%d (%.3g to %.3g, 20 strips):        ",
                               dim, x_min, x_max), String(take!(line)))
            report(r, @sprintf("  mean target level along x%d (%.3g to %.3g, 20 strips): ",
                               dim, x_min, x_max), String(take!(target_line)))
        end
    end

    write_csv(joinpath(out, "distribution.csv"), rows)
end

# ==========================================================================================
# ==== Neighbor pairs and query times
# The number of points in the leaves of each level of a `TreeCellList`.
# Each finest cell stores `(slot << 8) | level` of its leaf, and each non-empty leaf has
# its own list `slot` (slot 1 is the empty list), see `build_tree` in PointNeighbors.
function tree_leaf_levels(cell_list)
    (; leaves, cells) = cell_list
    counts = zeros(Int, cell_list.max_level + 1)
    for entry in leaves
        slot = entry >> 8
        slot > 1 || continue
        counts[(entry & 0xff) + 1] += length(cells[slot])
    end

    return counts
end

function section_pairs(r, out, semi, u_ode, n_calls)
    report(r, "\n==== Neighbors per particle and query times")
    report(r, @sprintf("%-28s %-28s %10s %10s %10s %10s %11s %11s", "system", "neighbor",
                       "uniform", "variable", "in support", "useful", "query R [ms]",
                       "query r [ms]"))
    rows = NamedTuple[]
    backend = semi.parallelization_backend

    # Only systems with their own smoothing length for the interaction as `system`
    # (see `pair_smoothing_lengths`)
    for system in semi.systems, neighbor in semi.systems
        system isa Union{TP.AbstractFluidSystem, TP.OpenBoundarySystem} || continue
        TP.has_system_interaction(system, neighbor, semi) || continue

        nhs = TP.get_neighborhood_search(system, neighbor, semi)
        iszero(PointNeighbors.search_radius(nhs)) && continue

        x = TP.current_coordinates(TP.wrap_u(u_ode, system, semi), system)
        y = TP.current_coordinates(TP.wrap_u(u_ode, neighbor, semi), neighbor)
        points = TP.each_integrated_particle(system)
        n_points = length(points)

        counts = zeros(Int, TP.nparticles(system))
        in_support = zeros(Int, TP.nparticles(system))

        # With the uniform search radius `R` (as in the loops without `search_radius`)
        foreach_point_neighbor(x, y, nhs; points,
                               parallelization_backend=backend) do a, b, _, d
            counts[a] += 1
            TP.pair_in_support(system, neighbor, a, b, d) && (in_support[a] += 1)
        end
        n_uniform = sum(counts)
        n_support = sum(in_support)

        query_uniform() = foreach_point_neighbor(x, y, nhs; points,
                                                 parallelization_backend=backend) do a, _, _, _
            counts[a] += 1
        end
        query_uniform()
        t_uniform, _ = time_ms(query_uniform, n_calls)

        # With the per-particle search radii (as in the loops with `query_search_radius`)
        search_radius = TP.search_radius_function(nhs, system, neighbor)
        n_variable = -1
        t_variable = NaN
        if !isnothing(search_radius)
            fill!(counts, 0)
            foreach_point_neighbor(x, y, nhs; points, search_radius,
                                   parallelization_backend=backend) do a, _, _, _
                counts[a] += 1
            end
            n_variable = sum(counts)

            query_variable() = foreach_point_neighbor(x, y, nhs; points, search_radius,
                                                      parallelization_backend=backend) do a,
                                                                                          _,
                                                                                          _,
                                                                                          _
                counts[a] += 1
            end
            t_variable, _ = time_ms(query_variable, n_calls)
        end

        if nhs isa TreeNeighborhoodSearch && system === neighbor
            counts_level = tree_leaf_levels(nhs.cell_list)
            cell_size = PointNeighbors.search_radius(nhs)
            report(r, "  tree leaves of $(system_name(system)): " *
                      join([@sprintf("level %d (cell size %.3g): %.0f%% of the points",
                                     level - 1, cell_size / 2^(level - 1),
                                     100 * n / sum(counts_level))
                            for (level, n) in enumerate(counts_level)], ", "))
        end

        n_returned = n_variable >= 0 ? n_variable : n_uniform
        row = (; system=system_name(system), neighbor=system_name(neighbor),
               nhs=string(nameof(typeof(nhs))), points=n_points,
               uniform_per_particle=n_uniform / n_points,
               variable_per_particle=n_variable >= 0 ? n_variable / n_points : NaN,
               in_support_per_particle=n_support / n_points,
               useful_fraction=n_support / n_returned, query_uniform_ms=t_uniform,
               query_variable_ms=t_variable)
        push!(rows, row)
        report(r, @sprintf("%-28s %-28s %10.1f %10.1f %10.1f %9.0f%% %11.3f %11.3f",
                           row.system, row.neighbor, row.uniform_per_particle,
                           row.variable_per_particle, row.in_support_per_particle,
                           100 * row.useful_fraction, t_uniform, t_variable))
    end
    report(r, "Neighbors per particle: `uniform` with the search radius R of the NHS, " *
              "`variable` with the per-particle radii (NaN: not used for this pair), " *
              "`in support` of the larger h. `useful`: in support / returned by the " *
              "query that the interaction uses. Query times with an empty loop body " *
              "(minimum of $n_calls).")

    write_csv(joinpath(out, "pairs.csv"), rows)
end

# ==========================================================================================
# ==== Timers of the RHS
function section_rhs(r, out, integrator, n_calls)
    report(r, "\n==== Timers of $n_calls RHS evaluations (kick!)")
    v_ode, u_ode = integrator.u.x
    dv_ode = zero(v_ode)
    TP.kick!(dv_ode, v_ode, u_ode, integrator.p, integrator.t)

    TP.reset_timer!(TP.timer())
    t_total = @elapsed for _ in 1:n_calls
        TP.kick!(dv_ode, v_ode, u_ode, integrator.p, integrator.t)
    end
    rows = flatten_timer(TP.timer())

    for row in rows
        startswith(row.path, "kick!") || continue
        time_per_call = row.time_ns / 1e6 / n_calls
        time_per_call < 0.01 && continue
        report(r, @sprintf("%-75s %9.3f ms/RHS %8.1f%%", row.path, time_per_call,
                           100 * row.time_ns / 1e9 / t_total))
    end
    report(r, @sprintf("wall time per RHS evaluation: %.3f ms", 1e3 * t_total / n_calls))

    write_csv(joinpath(out, "rhs_timers.csv"),
              [(; row..., per_call_ms=row.time_ns / 1e6 / n_calls) for row in rows])
end

# ==========================================================================================
# ==== Profiles
function write_profile(r, out, name, n_top)
    flat = joinpath(out, "profile_$(name)_flat.txt")
    open(flat, "w") do io
        Profile.print(IOContext(io, :displaysize => (100_000, 250)); format=:flat,
                      sortedby=:overhead, C=false, combine=true, mincount=10)
    end
    open(joinpath(out, "profile_$(name)_tree.txt"), "w") do io
        Profile.print(IOContext(io, :displaysize => (100_000, 250)); format=:tree,
                      C=false, combine=true, mincount=20, noisefloor=2.0)
    end

    # The frames with the most own time are at the end of the flat profile
    lines = filter(!isempty, readlines(flat))
    data_lines = filter(line -> occursin(r"^\s*\d+\s+\d+", line), lines)
    report(r, "Frames with the most own time (Count = inclusive, Overh = own samples, " *
              "all threads; spinning worker threads show up as overhead in " *
              "Polyester/ThreadingUtilities):")
    header = findfirst(line -> occursin("Overhead", line), lines)
    !isnothing(header) && report(r, lines[header])
    for line in reverse(data_lines[max(1, end - n_top + 1):end])
        report(r, line)
    end

    # Own time is mostly in inlined arithmetic, so also list the frames of TrixiParticles
    # and PointNeighbors by inclusive samples to see which loops the time is spent in
    count_of(line) = parse(Int, first(split(strip(line))))
    package_lines = filter(line -> occursin(r"@(TrixiParticles|PointNeighbors)/", line),
                           data_lines)
    sort!(package_lines, by=count_of, rev=true)
    report(r, "Frames of TrixiParticles and PointNeighbors with the most inclusive samples:")
    for line in package_lines[1:min(n_top, end)]
        report(r, line)
    end
    report(r, "Full profiles in $flat and profile_$(name)_tree.txt")
end

function section_profile_rhs(r, out, integrator, n_calls)
    report(r, "\n==== Profile of $n_calls RHS evaluations")
    v_ode, u_ode = integrator.u.x
    dv_ode = zero(v_ode)
    TP.kick!(dv_ode, v_ode, u_ode, integrator.p, integrator.t)

    Profile.clear()
    Profile.init(n=10^8, delay=0.0005)
    @profile for _ in 1:n_calls
        TP.kick!(dv_ode, v_ode, u_ode, integrator.p, integrator.t)
    end
    write_profile(r, out, "rhs", 30)
end

# ==========================================================================================
# ==== Shifting
# The steps of `refinement!` before the shifting (see `src/refinement/refinement.jl`)
function refinement_until_shift!(semi, v_ode, u_ode)
    TP.update_nhs!(semi, u_ode)
    foreach(semi.systems) do system
        isnothing(TP.get_refinement(system)) && return
        TP.apply_refinement_criteria!(system, v_ode, u_ode, semi)
        TP.update_target_spacing!(system, v_ode, u_ode, semi)
    end
    TP.merge_particles!(semi, v_ode, u_ode, before_splitting=true)
    TP.split_particles!(semi, v_ode, u_ode)
    TP.merge_particles!(semi, v_ode, u_ode)

    return semi
end

function percentile(x, p)
    isempty(x) && return NaN
    sorted = sort(x)
    return sorted[clamp(ceil(Int, p * length(sorted)), 1, length(sorted))]
end

function section_shift(r, out, integrator, n_iterations, n_profile)
    report(r, "\n==== Shifting of one refinement call")
    # Work on a copy, since the refinement changes the state
    integrator_ = deepcopy(integrator)
    semi = integrator_.p.semi
    v_ode, u_ode = integrator_.u.x
    dv_ode = zero(v_ode)

    n_before = n_active(semi)
    refinement_until_shift!(semi, v_ode, u_ode)
    report(r, "Active particles before / after merging and splitting: ",
           join(["$(name) $(n0) -> $(n1)"
                 for ((name, n0), (_, n1)) in zip(n_before, n_active(semi))], ", "))

    # The time of one RHS evaluation on this state, for comparison
    TP.kick!(zero(v_ode), v_ode, u_ode, integrator_.p, integrator_.t)
    t_rhs, _ = time_ms(() -> TP.kick!(zero(v_ode), v_ode, u_ode, integrator_.p,
                                      integrator_.t), 5)

    rows = NamedTuple[]
    for system in fluid_systems(semi)
        refinement = TP.get_refinement(system)
        isnothing(refinement) && continue
        shifting = refinement.shifting_technique
        shifting isa TP.ShiftingHaftu || continue

        (; total_shift, relative_shift) = system.cache
        theta = shifting.theta
        max_shift_factor = shifting.max_shift_factor
        tolerance = shifting.tolerance
        iterations = n_iterations > 0 ? n_iterations : shifting.max_iterations
        report(r, "$(system_name(system)): theta = $theta, max_shift_factor = " *
                  "$max_shift_factor, tolerance = $tolerance, $iterations iterations " *
                  "(without stopping at the tolerance)")

        v = TP.wrap_v(v_ode, system, semi)
        u = TP.wrap_u(u_ode, system, semi)
        TP.set_zero!(total_shift)
        TP.update_smoothing_lengths!(system, u, semi)
        TP.update_search_radii!(system, u, semi)

        active = collect(TP.each_active_particle(system))
        NDIMS = ndims(system)
        stopped_at = 0
        report(r, @sprintf("%5s %10s %10s %10s %8s %10s %10s %10s", "iter",
                           "max", "median", "p99", "above", "max total", "compute",
                           "apply"))
        for iteration in 1:iterations
            t_compute = 1e3 * @elapsed TP.compute_shift!(system, u, u_ode, semi)
            t_apply = 1e3 * @elapsed begin
                max_relative = TP.apply_shift!(system, u, semi, theta, max_shift_factor)
            end

            # `relative_shift` is `|δr_Eq15| / h` before limiting
            relative = relative_shift[active]
            total = [sqrt(sum(abs2, total_shift[((particle - 1) * NDIMS + 1):(particle * NDIMS)])) /
                     TP.smoothing_length(system, particle) for particle in active]
            above = count(>(tolerance), relative)
            if stopped_at == 0 && max_relative < tolerance
                stopped_at = iteration
            end

            row = (; system=system_name(system), iteration, max=max_relative,
                   median=median(relative), p99=percentile(relative, 0.99), above,
                   max_total_shift=maximum(total), median_total_shift=median(total),
                   compute_ms=t_compute, apply_ms=t_apply)
            push!(rows, row)
            if iteration <= 5 || iteration % 10 == 0 || iteration == iterations
                report(r, @sprintf("%5d %10.2e %10.2e %10.2e %8d %10.3f %10.3f %10.3f",
                                   iteration, row.max, row.median, row.p99, above,
                                   row.max_total_shift, t_compute, t_apply))
            end
        end

        per_iteration = median(row.compute_ms + row.apply_ms for row in rows)
        report(r, "Residuals are `|δr_Eq15| / h` before limiting, `max total` is the " *
                  "largest accumulated shift / h. `above`: particles above the tolerance.")
        report(r, stopped_at > 0 ?
                  "The tolerance is reached in iteration $stopped_at." :
                  "The tolerance is not reached in $iterations iterations.")
        report(r, @sprintf("One iteration: %.3f ms (median) = %.2f RHS evaluations (%.3f ms on this state)",
                           per_iteration, per_iteration / t_rhs, t_rhs))
    end

    write_csv(joinpath(out, "shift_history.csv"), rows)

    return integrator_
end

function section_profile_shift(r, out, integrator_, n_calls)
    report(r, "\n==== Profile of $n_calls calls of compute_shift!")
    semi = integrator_.p.semi
    _, u_ode = integrator_.u.x
    systems = filter(system -> TP.get_refinement(system) isa TP.ParticleRefinement,
                     fluid_systems(semi))
    isempty(systems) && return report(r, "No system with refinement")
    system = first(systems)
    u = TP.wrap_u(u_ode, system, semi)

    TP.compute_shift!(system, u, u_ode, semi)
    Profile.clear()
    Profile.init(n=10^8, delay=0.0005)
    @profile for _ in 1:n_calls
        TP.compute_shift!(system, u, u_ode, semi)
    end
    write_profile(r, out, "shift", 30)
end

# ==========================================================================================
function profile_main(args)
    config = parse_profile_arguments(args)
    case = setup(config.case; config.size, config.nhs, config.refinement,
                 config.update_strategy, config.shifting, config.options...)

    # The examples define closures in `trixi_include`, which are newer than this function
    return Base.invokelatest(profile_case, config, case)
end

function profile_case(config, case)
    (; ode, callbacks, alg, solve_kwargs, meta) = case

    out = config.out
    if isempty(out)
        name = join((Dates.format(now(), "yyyymmdd-HHMMSS"), config.case, config.size,
                     config.nhs, config.refinement, config.shifting,
                     ("ratio$(v)" for v in values(config.options))...,
                     "t$(Threads.nthreads())"), "_")
        out = joinpath(@__DIR__, "results", "profile", name)
    end
    mkpath(out)

    open(joinpath(out, "meta.toml"), "w") do io
        println(io, "date = \"$(now())\"")
        for (key, value) in pairs(meta)
            println(io, "$key = \"$value\"")
        end
        for key in (:advance, :rhs_calls, :profile_calls, :shift_iterations)
            println(io, "$key = $(getfield(config, key))")
        end
        println(io, "sections = \"$(join(config.sections, ","))\"")
        trixi_dir = pkgdir(TrixiParticles)
        pn_dir = pkgdir(PointNeighbors)
        println(io, "trixiparticles = \"$(git_branch(trixi_dir)) $(git_commit(trixi_dir))\"")
        println(io, "pointneighbors = \"$(git_branch(pn_dir)) $(git_commit(pn_dir))\"")
        println(io, "benchmarks = \"$(git_commit(@__DIR__))\"")
        println(io, "julia = \"$VERSION\"")
        println(io, "threads = $(Threads.nthreads())")
        println(io, "hostname = \"$(gethostname())\"")
        println(io, "cpu = \"$(Sys.cpu_info()[1].model)\"")
        println(io, "loadavg = \"$(join(round.(Sys.loadavg(), digits=1), " "))\"")
    end

    r = Report(open(joinpath(out, "summary.txt"), "w"))
    report(r, "==== $(config.case), $(config.size), $(config.nhs), refinement=$(config.refinement), ",
           "$(Threads.nthreads()) threads, load $(join(round.(Sys.loadavg(), digits=1), " "))")

    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    for _ in 1:config.advance
        step!(integrator)
    end
    semi = integrator.p.semi
    _, u_ode = integrator.u.x
    TP.update_nhs!(semi, u_ode)
    report(r, "State after the startup and $(config.advance) steps (t = ",
           @sprintf("%.4g", integrator.t), "): active particles ",
           join(["$name $n" for (name, n) in n_active(semi)], ", "))

    "distribution" in config.sections && section_distribution(r, out, semi, u_ode)
    "pairs" in config.sections && section_pairs(r, out, semi, u_ode, config.rhs_calls)
    "rhs" in config.sections && section_rhs(r, out, integrator, config.rhs_calls)
    "profile_rhs" in config.sections &&
        section_profile_rhs(r, out, integrator, config.profile_calls)

    shifted = nothing
    if config.refinement === :on && "shift" in config.sections
        shifted = section_shift(r, out, integrator, config.shift_iterations,
                                config.profile_calls)
    end
    if config.refinement === :on && "profile_shift" in config.sections
        section_profile_shift(r, out, something(shifted, integrator), config.profile_calls)
    end

    report(r, "\nResults in $out")
    close(r.io)

    return out
end

if abspath(PROGRAM_FILE) == @__FILE__
    profile_main(ARGS)
end
