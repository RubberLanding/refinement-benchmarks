# Cases for the Phase 2 measurements (see `PLAN.md`).
#
# `setup(case; size, nhs, refinement, ...)` returns everything that is needed to run one
# case: the ODE problem, the callbacks, the time integration algorithm and its keywords,
# and a `NamedTuple` with metadata that is written to the results.
#
# Cases:
# - `:taylor_green`: Taylor-Green vortex with refinement (periodic, EDAC, no walls)
# - `:pipe_flow`: pipe flow with refinement (walls, open boundaries)
# - `:vortex_street`: flow past a cylinder with refinement near the cylinder and in the
#   wake (walls, open boundaries, vorticity criterion). Pass `spacing_ratio` for the ratio
#   of `max_spacing` to `min_spacing` (default 2).
#
# Sizes (`size`): `:tiny` (smoke tests and warm-up), `:small`, `:medium`, `:large`
# for about 10k, 40k and 160k fluid particles after the refinement startup.
# Pass a number to use this `particle_spacing` (the maximum spacing) directly.
#
# Neighborhood searches (`nhs`):
# - `:grid`: `GridNeighborhoodSearch` with a `FullGridCellList` and the largest radius
# - `:tree_uniform`: `TreeNeighborhoodSearch` with the largest radius for all particles
# - `:tree_variable`: `TreeNeighborhoodSearch` with one radius per particle (Phase 1)
#
# Refinement (`refinement`):
# - `:on`: refinement with the `ParticleRefinementCallback` of the example
# - `:min`, `:max`: no refinement, uniform at the minimum or maximum spacing (baselines)
#
# Shifting of the refinement (`shifting`):
# - `:default`: the `ShiftingHaftu()` default (θ = 0.5, at most 100 iterations)
# - `:fast`: `ShiftingHaftu(theta=1, max_iterations=20)`, the setting suggested by the
#   server study (`dev/refinement_diagnostics/README.md` on `server/refinement-diagnostics`)
# - `:fast_pst`: `:fast` with `pst_equilibrium=true` (needs 5819670)
#
# Cell capacity: cells that store the cylinder of the vortex street overflow the default of
# 100 at `spacing_ratio >= 4` (see `HANDOFF_CELL_CAPACITY.md`). `setup` then passes
# a larger `max_points_per_cell` (see `cell_capacity`), which can be overridden with
# `max_points_per_cell`.
#
# `update_strategy=SerialUpdate()` by default, since runs with `ParallelUpdate()` differ
# in the particle count (see `PLAN.md`, "Reproducibility").

using TrixiParticles
using PointNeighbors
using OrdinaryDiffEqLowStorageRK

const TP = TrixiParticles

const EXAMPLES = joinpath(examples_dir(), "fluid")

# Maximum spacing per size. The particle counts after the startup are in `results/sizes.md`.
# Taylor-Green: uniform `n × n` lattice with `n = 1 / particle_spacing`.
# Pipe flow: `0.4 / particle_spacing` particles across the pipe (even, so that
# `1 / particle_spacing` is an integer).
# The refinement grades over a fixed number of particle spacings, so the ratio of the
# particles after the startup to the initial particles decreases with the resolution
# (Taylor-Green: 3.8 at 1 / 20, 2.3 at 1 / 88; pipe flow: 4.1 at 0.4 / 20, 3.4 at 0.4 / 46).
const SPACINGS = (taylor_green=(tiny=0.05, small=1 / 64, medium=1 / 138, large=1 / 288),
                  pipe_flow=(tiny=0.02, small=0.4 / 34, medium=0.4 / 70, large=0.4 / 144),
                  # The channel is 2 x 1, so that `1 / particle_spacing` is an integer
                  vortex_street=(tiny=0.02, small=1 / 70, medium=1 / 140, large=1 / 280))

spacing_of(case, size::Symbol) = getfield(getfield(SPACINGS, case), size)
spacing_of(case, size::Real) = Float64(size)

# Since Julia 1.12, a function can't read a global that `trixi_include` defined while the
# function was already running (world age), so read the globals of the examples with this.
example_global(name) = Base.invokelatest(getglobal, @__MODULE__, name)

# The finest level of the tree such that the cells are not smaller than the compact support
# of the smallest smoothing length of the refinement
function tree_max_level(fluid_system)
    refinement = TP.get_refinement(fluid_system)
    isnothing(refinement) && return 0

    kernel = TP.system_smoothing_kernel(fluid_system)
    radius_max = TP.search_compact_support(fluid_system)
    radius_min = TP.compact_support(kernel,
                                    TP.spacing_to_smoothing_length(fluid_system,
                                                                   refinement.min_spacing))

    return max(floor(Int, log2(radius_max / radius_min)), 0)
end

# The capacity of the template cell list. The numbers were measured for sizes up to `small`
# (fullest cell: 152 particles at ratio 4, 607 at ratio 8); the capacity of searches that
# store refined fluid is larger and chosen by TrixiParticles.
# At ratio 3, the cylinder needs about 85.
function cell_capacity(case, refinement, spacing_ratio)
    (case === :vortex_street && refinement === :on) || return 100
    spacing_ratio <= 3 && return 100
    spacing_ratio <= 4 && return 200
    spacing_ratio <= 8 && return 700

    throw(ArgumentError("pass `max_points_per_cell` for `spacing_ratio` $spacing_ratio"))
end

function template_nhs(kind, min_corner, max_corner, max_level, update_strategy;
                      periodic_box=nothing, max_points_per_cell=100)
    NDIMS = length(min_corner)

    if kind === :grid
        cell_list = FullGridCellList(; min_corner, max_corner, max_points_per_cell)
        return GridNeighborhoodSearch{NDIMS}(; cell_list, update_strategy, periodic_box)
    elseif kind === :tree_uniform
        # With `QueryRadius()` and `max_level=0`, all particles have the uniform radius
        # and the leaves are the root cells of the size of the search radius.
        # These leaves can't be split, so they need more than the default 100 points:
        # in the refined zones of the pipe flow, a root cell holds more than 100.
        cell_list = TreeCellList(; min_corner, max_corner, max_level=0,
                                 max_points_per_cell=max(400, max_points_per_cell))
        return TreeNeighborhoodSearch{NDIMS}(; cell_list, periodic_box, update_strategy,
                                             neighbor_criterion=QueryRadius())
    elseif kind === :tree_variable
        cell_list = TreeCellList(; min_corner, max_corner, max_level, max_points_per_cell)
        return TreeNeighborhoodSearch{NDIMS}(; cell_list, periodic_box, update_strategy,
                                             neighbor_criterion=MaximumRadius())
    end

    throw(ArgumentError("unknown neighborhood search `$kind`"))
end

function setup(case; size=:tiny, nhs=:tree_variable, refinement=:on,
               update_strategy=SerialUpdate(), parallelization_backend=PolyesterBackend(),
               refinement_interval=10, shifting=:default, max_points_per_cell=nothing,
               kwargs...)
    max_spacing = spacing_of(case, size)
    shifting_technique = shifting_technique_of(shifting)

    if case === :taylor_green
        result = taylor_green(max_spacing, refinement, refinement_interval,
                              shifting_technique; kwargs...)
    elseif case === :pipe_flow
        result = pipe_flow(max_spacing, refinement, refinement_interval,
                           shifting_technique; kwargs...)
    elseif case === :vortex_street
        result = vortex_street(max_spacing, refinement, refinement_interval,
                               shifting_technique; kwargs...)
    else
        throw(ArgumentError("unknown case `$case`"))
    end
    (; systems, min_corner, max_corner, periodic_box, tspan) = result

    fluid_system = first(systems)
    max_level = tree_max_level(fluid_system)
    if isnothing(max_points_per_cell)
        max_points_per_cell = cell_capacity(case, refinement, get(kwargs, :spacing_ratio, 2))
    end
    # Also returned, to get the template NHS of another kind for the same systems
    nhs_of(kind) = template_nhs(kind, min_corner, max_corner, max_level, update_strategy;
                                periodic_box, max_points_per_cell)
    neighborhood_search = nhs_of(nhs)

    semi = Semidiscretization(systems...; neighborhood_search, parallelization_backend)
    ode = semidiscretize(semi, tspan)

    meta = (; case, size=string(size), max_spacing, nhs, refinement, shifting,
            update_strategy=nameof(typeof(update_strategy)),
            backend=nameof(typeof(parallelization_backend)), refinement_interval,
            max_level, max_points_per_cell,
            n_initial=length(TP.each_active_particle(fluid_system)),
            options=join(("$key=$value" for (key, value) in pairs(kwargs)), " "))

    return (; ode, result.callbacks, result.alg, result.solve_kwargs, meta, nhs_of)
end

shifting_technique_of(shifting) = shifting === :default ? nothing :
                                  shifting === :fast ?
                                  ShiftingHaftu(theta=1.0, max_iterations=20) :
                                  shifting === :fast_pst ?
                                  ShiftingHaftu(theta=1.0, max_iterations=20,
                                                pst_equilibrium=true) :
                                  throw(ArgumentError("unknown shifting `$shifting`"))

# The examples construct `ParticleRefinement` without `shifting_technique`. Include the
# example once without the systems to get its `refinement`, and return the overrides with
# a copy of it with `shifting_technique`. `no_systems` are the overrides that skip the
# construction of the systems of this example.
function shifting_overrides(file, shifting_technique, refinement, overrides, kwargs,
                            no_systems)
    (isnothing(shifting_technique) || refinement !== :on) && return overrides

    trixi_include(@__MODULE__, file; overrides..., kwargs..., no_systems..., semi=nothing,
                  ode=nothing, sol=nothing, saving_callback=nothing, info_callback=nothing)
    r = example_global(:refinement)
    refinement_ = ParticleRefinement(r.spacing_ratio, r.min_spacing, r.max_spacing,
                                     r.smoothing_length_factor, r.reference_density,
                                     r.criteria, r.splitting_pattern, r.max_mass_factor,
                                     r.min_mass_factor, shifting_technique,
                                     r.n_startup_rounds)

    return (; overrides..., refinement=refinement_)
end

# The spacing of the uniform baselines and the overrides of the example to switch
# the refinement off
function refinement_overrides(refinement, max_spacing, min_spacing_ratio, interval)
    if refinement === :on
        return max_spacing, (; refinement_callback=ParticleRefinementCallback(; interval))
    elseif refinement === :min
        spacing = max_spacing / min_spacing_ratio
    elseif refinement === :max
        spacing = max_spacing
    else
        throw(ArgumentError("unknown refinement `$refinement`"))
    end

    return spacing, (; refinement=nothing, refinement_callback=nothing)
end

# ==========================================================================================
# ==== Taylor-Green vortex
function taylor_green(max_spacing, refinement, refinement_interval, shifting_technique;
                      kwargs...)
    file = joinpath(EXAMPLES, "taylor_green_vortex_2d_refinement.jl")

    # `min_spacing = particle_spacing / 2` in the example
    particle_spacing, overrides = refinement_overrides(refinement, max_spacing, 2,
                                                       refinement_interval)

    # After the startup, there are 2.3 (at 1 / 88) to 3.8 (at 1 / 20) times the initial
    # particles. With a smaller buffer, `resize_systems!` recreates the NHS.
    n_initial = round(Int, 1 / particle_spacing)^2
    n_buffer_particles = refinement === :on ? ceil(Int, 2.0 * n_initial) : nothing
    overrides = shifting_overrides(file, shifting_technique, refinement,
                                   (; particle_spacing, n_buffer_particles, overrides...),
                                   kwargs, (; fluid_system=nothing))

    trixi_include(@__MODULE__, file; semi=nothing, ode=nothing, sol=nothing,
                  saving_callback=nothing, info_callback=nothing, overrides..., kwargs...)

    box_length = example_global(:box_length)
    min_corner = [0.0, 0.0]
    max_corner = [box_length, box_length]
    periodic_box = PeriodicBox(; min_corner, max_corner)

    # The example has `h / 4 * (c + U)` instead of `h / (4 (c + U))`, so only the viscous
    # limit applies (see `PLAN.md`). Use the correct limit until it is fixed in the example.
    h = example_global(:smoothing_length)
    c = example_global(:sound_speed)
    U = example_global(:U)
    nu = example_global(:nu)
    dt_max = min(h / (4 * (c + U)), h^2 / (8 * nu))

    return (; systems=(example_global(:fluid_system),), callbacks=example_global(:callbacks),
            alg=RDPK3SpFSAL49(), solve_kwargs=(; abstol=1e-8, reltol=1e-4, dtmax=dt_max),
            min_corner, max_corner, periodic_box, tspan=example_global(:tspan))
end

# ==========================================================================================
# ==== Pipe flow
function pipe_flow(max_spacing, refinement, refinement_interval, shifting_technique;
                   kwargs...)
    file = joinpath(EXAMPLES, "pipe_flow_2d_refinement.jl")

    # `min_spacing = particle_spacing / spacing_ratio` with `spacing_ratio = 2`.
    # The baselines use `spacing_ratio = 1`, so that the walls and open boundaries have
    # the spacing of the fluid.
    particle_spacing, overrides = refinement_overrides(refinement, max_spacing, 2,
                                                       refinement_interval)
    if refinement !== :on
        overrides = (; overrides..., spacing_ratio=1)
    end

    # After the startup, there are 3.4 (at 0.4 / 46) to 4.1 (at 0.4 / 20) times the initial
    # fluid particles, since the spatial criterion refines near the walls. The example has
    # a fixed buffer of 1000 particles for the refinement. With a smaller buffer,
    # `resize_systems!` recreates the NHS.
    n_fluid = round(Int, 1 / particle_spacing) * round(Int, 0.4 / particle_spacing)
    n_buffer_refinement_particles = refinement === :on ? ceil(Int, 3.5 * n_fluid) : 0
    overrides = shifting_overrides(file, shifting_technique, refinement,
                                   (; particle_spacing, n_buffer_refinement_particles,
                                    overrides...), kwargs,
                                   (; fluid_system=nothing, open_boundary=nothing))

    trixi_include(@__MODULE__, file; semi=nothing, ode=nothing, sol=nothing,
                  saving_callback=nothing, info_callback=nothing, overrides..., kwargs...)

    systems = (example_global(:fluid_system), example_global(:open_boundary),
               example_global(:boundary_system))

    return (; systems, callbacks=example_global(:callbacks), alg=RDPK3SpFSAL35(),
            solve_kwargs=(; abstol=1e-5, reltol=1e-3, dtmax=1e-2),
            min_corner=example_global(:min_corner), max_corner=example_global(:max_corner),
            periodic_box=nothing, tspan=example_global(:tspan))
end

# ==========================================================================================
# ==== Vortex street
function vortex_street(max_spacing, refinement, refinement_interval, shifting_technique;
                       spacing_ratio=2, kwargs...)
    file = joinpath(EXAMPLES, "vortex_street_2d_refinement.jl")

    # Override `min_spacing` and not `spacing_ratio`, since `trixi_include` would also
    # replace the keyword `spacing_ratio=1.2` of `ParticleRefinement`.
    # The baselines have the cylinder at the spacing of the fluid.
    particle_spacing, overrides = refinement_overrides(refinement, max_spacing,
                                                       spacing_ratio, refinement_interval)
    min_spacing = refinement === :on ? particle_spacing / spacing_ratio : particle_spacing
    overrides = (; overrides..., min_spacing)

    # The example has `refinement_shifting` for the `shifting_technique`
    if refinement === :on && !isnothing(shifting_technique)
        overrides = (; overrides..., refinement_shifting=shifting_technique)
    end

    # At the start, only the fluid near the cylinder is refined (the wake develops later),
    # and the example has a fixed buffer of 5000 particles for the refinement
    n_fluid = round(Int, 2 / particle_spacing) * round(Int, 1 / particle_spacing)
    n_buffer_refinement_particles = refinement === :on ? n_fluid : 0

    trixi_include(@__MODULE__, file; particle_spacing, n_buffer_refinement_particles,
                  semi=nothing, ode=nothing, sol=nothing, saving_callback=nothing,
                  info_callback=nothing, overrides..., kwargs...)

    systems = (example_global(:fluid_system), example_global(:open_boundary),
               example_global(:boundary_system_wall),
               example_global(:boundary_system_cylinder))

    return (; systems, callbacks=example_global(:callbacks), alg=RDPK3SpFSAL35(),
            solve_kwargs=(; abstol=1e-5, reltol=1e-3, dtmax=1e-2),
            min_corner=example_global(:min_corner), max_corner=example_global(:max_corner),
            periodic_box=nothing, tspan=example_global(:tspan))
end

# ==========================================================================================
# ==== Helpers for the scripts
function n_active(semi)
    return map(semi.systems) do system
        return nameof(typeof(system)) => length(TP.each_active_particle(system))
    end
end
