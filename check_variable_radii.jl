# Phase 1 checks for the variable search radii with the `TreeNeighborhoodSearch`.
#
# Each case is run with the tree NHS with variable radii until the end of the refinement
# startup (`init`). On this state:
# 1. Neighbors: the tree with variable radii must find the same pairs within the support
#    of the larger smoothing length (`pair_in_support`) as a search with the uniform search
#    radius, for all pairs of systems with variable smoothing lengths
#    (fluid-fluid, fluid-open boundary, open boundary-fluid).
# 2. Results: one RHS (`kick!`) and one shift of the refinement (Eq. 15, `compute_shift!`)
#    with the grid NHS, the tree NHS with a uniform radius and the tree NHS with variable
#    radii must agree up to rounding.
#
# Comparing whole runs does not work: with the grid NHS alone, two runs already end the
# refinement startup with different numbers of particles, since rounding differences from
# the parallel NHS update change split and merge decisions.
#
# Run from the worktree root with
#   julia --project=run -t 8 benchmarks/check_variable_radii.jl

using TrixiParticles
using PointNeighbors
using OrdinaryDiffEqLowStorageRK
using Printf

const TP = TrixiParticles

const EXAMPLES = joinpath(examples_dir(), "fluid")

# The finest level of the tree such that the cells are not smaller than the compact support
# of the smallest smoothing length of the refinement
function tree_max_level(fluid_system)
    refinement = TP.get_refinement(fluid_system)
    kernel = TP.system_smoothing_kernel(fluid_system)

    radius_max = TP.search_compact_support(fluid_system)
    radius_min = TP.compact_support(kernel,
                                    TP.spacing_to_smoothing_length(fluid_system,
                                                                   refinement.min_spacing))

    return max(floor(Int, log2(radius_max / radius_min)), 0)
end

# `kind` is `:grid`, `:tree_uniform` or `:tree_variable`
function template_nhs(kind, min_corner, max_corner, max_level; periodic_box=nothing)
    NDIMS = length(min_corner)

    if kind === :grid
        return GridNeighborhoodSearch{NDIMS}(; cell_list=FullGridCellList(; min_corner,
                                                                          max_corner),
                                             update_strategy=ParallelUpdate(),
                                             periodic_box)
    elseif kind === :tree_uniform
        # With `QueryRadius()`, all particles have the uniform search radius
        cell_list = TreeCellList(; min_corner, max_corner, max_level=0)
        return TreeNeighborhoodSearch{NDIMS}(; cell_list, periodic_box,
                                             neighbor_criterion=QueryRadius())
    end

    cell_list = TreeCellList(; min_corner, max_corner, max_level)
    return TreeNeighborhoodSearch{NDIMS}(; cell_list, periodic_box,
                                         neighbor_criterion=MaximumRadius())
end

# ==========================================================================================
# ==== Cases
# Each case returns the ODE problem with the tree NHS with variable radii and a function
# `kind -> template NHS` to create the other neighborhood searches.
function taylor_green(; particle_spacing=0.05, kwargs...)
    file = joinpath(EXAMPLES, "taylor_green_vortex_2d_refinement.jl")

    # Include once without solving to get the fluid system for the tree depth
    trixi_include(@__MODULE__, file; particle_spacing, sol=nothing, ode=nothing,
                  semi=nothing, kwargs...)
    max_level = tree_max_level(fluid_system)

    min_corner = [0.0, 0.0]
    max_corner = [box_length, box_length]
    periodic_box = PeriodicBox(; min_corner, max_corner)
    nhs_of(kind) = template_nhs(kind, min_corner, max_corner, max_level; periodic_box)

    trixi_include(@__MODULE__, file; particle_spacing, nhs=nhs_of(:tree_variable),
                  sol=nothing, saving_callback=nothing,
                  info_callback=InfoCallback(interval=10_000), kwargs...)

    return (; ode, callbacks, alg=RDPK3SpFSAL49(),
            solve_kwargs=(; abstol=1e-8, reltol=1e-4, dtmax=dt_max), max_level, nhs_of)
end

function pipe_flow(; particle_spacing=0.02, kwargs...)
    file = joinpath(EXAMPLES, "pipe_flow_2d_refinement.jl")

    trixi_include(@__MODULE__, file; particle_spacing, sol=nothing, ode=nothing,
                  semi=nothing, kwargs...)
    max_level = tree_max_level(fluid_system)

    # `min_corner` and `max_corner` of the example
    nhs_of(kind) = template_nhs(kind, min_corner, max_corner, max_level)

    trixi_include(@__MODULE__, file; particle_spacing, nhs=nhs_of(:tree_variable),
                  sol=nothing, saving_callback=nothing,
                  info_callback=InfoCallback(interval=10_000), kwargs...)

    return (; ode, callbacks, alg=RDPK3SpFSAL35(),
            solve_kwargs=(; abstol=1e-5, reltol=1e-3, dtmax=1e-2), max_level, nhs_of)
end

# ==========================================================================================
# ==== Check 1: neighbors
function check_neighbors(semi, u_ode)
    all_equal = true

    for system in semi.systems, neighbor in semi.systems
        tree = TP.get_neighborhood_search(system, neighbor, semi)
        TP.uses_variable_search_radius(tree, system, neighbor) || continue

        # This NHS is never used and not built (e.g. open boundary - open boundary)
        radius = PointNeighbors.search_radius(tree)
        iszero(radius) && continue

        x = TP.current_coordinates(TP.wrap_u(u_ode, system, semi), system)
        y = TP.current_coordinates(TP.wrap_u(u_ode, neighbor, semi), neighbor)
        points = collect(TP.each_integrated_particle(system))

        # Reference: all pairs within the uniform search radius
        reference_nhs = TrivialNeighborhoodSearch{ndims(system)}(; search_radius=radius,
                                                                 eachpoint=TP.each_active_particle(neighbor),
                                                                 periodic_box=tree.periodic_box)
        reference = Set{Tuple{Int, Int}}()
        n_reference = Ref(0)
        foreach_point_neighbor(x, y, reference_nhs; points,
                               parallelization_backend=SerialBackend()) do a, b, _, d
            n_reference[] += 1
            TP.pair_in_support(system, neighbor, a, b, d) && push!(reference, (a, b))
        end

        found = Set{Tuple{Int, Int}}()
        n_found = Ref(0)
        search_radius = TP.search_radius_function(tree, system, neighbor)
        foreach_point_neighbor(x, y, tree; points, search_radius,
                               parallelization_backend=SerialBackend()) do a, b, _, d
            n_found[] += 1
            TP.pair_in_support(system, neighbor, a, b, d) && push!(found, (a, b))
        end

        equal = found == reference
        all_equal &= equal
        @printf("  %-28s -> %-28s pairs in support: %8d (%s), returned: tree %8d, uniform %8d (%.2f)\n",
                nameof(typeof(system)), nameof(typeof(neighbor)), length(reference),
                equal ? "equal" :
                "DIFFERENT: $(length(setdiff(reference, found))) missing, " *
                "$(length(setdiff(found, reference))) extra",
                n_found[], n_reference[], n_found[] / n_reference[])
    end

    return all_equal
end

# ==========================================================================================
# ==== Check 2: one RHS and one shift of the refinement with each NHS
# A semidiscretization of the same systems with another NHS, initialized with the current
# coordinates
function semi_with_nhs(semi, u_ode, neighborhood_search)
    semi_ = Semidiscretization(semi.systems...; neighborhood_search,
                               parallelization_backend=semi.parallelization_backend)
    TP.initialize_resized_neighborhood_searches!(semi_, u_ode,
                                                 trues(length(semi.systems)))

    # The `UpdateCallback` of the run is also used for this semidiscretization
    semi_.update_callback_used[] = semi.update_callback_used[]

    return semi_
end

# `dv` and the shift of Eq. 15 of the active particles of each system
function evaluate(p, v_ode, u_ode)
    (; semi) = p
    dv_ode = zero(v_ode)
    TP.kick!(dv_ode, v_ode, u_ode, p, 0.0)

    return map(semi.systems) do system
        active = collect(TP.each_active_particle(system))
        # Walls have no integrated variables
        dv_system = TP.wrap_v(dv_ode, system, semi)
        dv = size(dv_system, 2) == 0 ? zeros(0, 0) : dv_system[:, active]

        shift = nothing
        if !isnothing(TP.get_refinement(system))
            u = TP.wrap_u(u_ode, system, semi)
            TP.compute_shift!(system, u, u_ode, semi)
            # The shift is stored flat (see `add_svector_flat!`)
            shift = reshape(system.cache.shift, ndims(system), :)[:, active]
        end

        return (; name=nameof(typeof(system)), active, dv, shift)
    end
end

function relative_difference(a, b)
    return maximum(abs, a - b; init=0.0) / max(maximum(abs, b; init=0.0), eps())
end

function check_results(integrator, nhs_of)
    (; p) = integrator
    v_ode, u_ode = integrator.u.x

    results = map((:grid, :tree_uniform, :tree_variable)) do kind
        semi_ = semi_with_nhs(p.semi, u_ode, nhs_of(kind))
        p_ = Base.setindex(p, semi_, :semi)

        return kind => evaluate(p_, v_ode, u_ode)
    end

    reference = last(first(results))
    max_difference = 0.0
    for (kind, result) in results[2:end], (system_ref, system) in zip(reference, result)
        diff_dv = relative_difference(system.dv, system_ref.dv)
        diff_shift = isnothing(system.shift) ? 0.0 :
                     relative_difference(system.shift, system_ref.shift)
        max_difference = max(max_difference, diff_dv, diff_shift)

        @printf("  %-14s %-28s %6d active, relative max |Δdv| = %.2e, |Δshift| = %.2e\n",
                kind, system.name, length(system.active), diff_dv, diff_shift)
    end

    return max_difference
end

# ==========================================================================================
function check_case(case)
    (; ode, callbacks, alg, solve_kwargs, max_level, nhs_of) = case
    println("Tree max_level = $max_level")

    # `init` runs the refinement startup in the initialization of the callback
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    semi = integrator.p.semi
    _, u_ode = integrator.u.x
    TP.update_nhs!(semi, u_ode)

    println("Check 1: neighbors after the refinement startup")
    neighbors_equal = check_neighbors(semi, u_ode)

    println("Check 2: one RHS and one shift (Eq. 15), relative to the grid NHS")
    max_difference = check_results(integrator, nhs_of)

    return neighbors_equal, max_difference
end

if abspath(PROGRAM_FILE) == @__FILE__
    cases = ("Taylor-Green vortex" => () -> taylor_green(),
             "Taylor-Green vortex, summation density" => () -> taylor_green(density_calculator=SummationDensity()),
             "Pipe flow" => () -> pipe_flow(),
             "Pipe flow, summation density" => () -> pipe_flow(fluid_density_calculator=SummationDensity()))

    summary = map(cases) do (name, case_function)
        println("==== $name")
        # The examples define closures in `trixi_include`, which are newer than this
        # function, so the functions that use them are called with `invokelatest`
        case = case_function()
        return name => Base.invokelatest(check_case, case)
    end

    println("==== Summary")
    for (name, (neighbors_equal, max_difference)) in summary
        @printf("%-40s neighbors equal: %-5s max relative difference: %.2e\n", name,
                neighbors_equal, max_difference)
    end
end
