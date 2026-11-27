# Scratch: load imbalance of the fluid loops and the call overhead of the support check
include("/mnt/ssd/home/nschum25/benchmark/benchmarks/run_full.jl")
med(f, n=40) = (for _ in 1:5; f(); end; median([1e3 * @elapsed(f()) for _ in 1:n]))

function state(; kw...)
    (; ode, callbacks, alg, solve_kwargs, meta) = setup(:vortex_street; size=:small, shifting=:fast, tspan=(0.0, 8.0), kw...)
    return Base.invokelatest(advance, ode, callbacks, alg, solve_kwargs)
end
function advance(ode, callbacks, alg, solve_kwargs)
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    while integrator.t < 4.0
        step!(integrator)
        TP.SciMLBase.successful_retcode(TP.SciMLBase.check_error(integrator)) || error("failed at t = $(integrator.t)")
        integrator.stats.naccept % 500 == 0 && (println("step $(integrator.stats.naccept) t $(integrator.t)"); flush(stdout))
    end
    TP.update_nhs!(integrator.p.semi, integrator.u.x[2])
    return integrator
end
function with_grid(integrator, nhs_template)
    semi = integrator.p.semi
    semi_ = Semidiscretization(semi.systems...; neighborhood_search=nhs_template, parallelization_backend=semi.parallelization_backend)
    semi_.update_callback_used[] = semi.update_callback_used[]
    TP.initialize_resized_neighborhood_searches!(semi_, integrator.u.x[2], trues(length(semi.systems)))
    return (; p=Base.setindex(integrator.p, semi_, :semi), u=integrator.u, t=integrator.t)
end

function analyse(name, integrator)
    semi = integrator.p.semi
    v_ode, u_ode = integrator.u.x
    system = first(semi.systems)
    nhs = TP.get_neighborhood_search(system, system, semi)
    x = TP.current_coordinates(TP.wrap_u(u_ode, system, semi), system)
    points = collect(TP.each_integrated_particle(system))
    n = length(points)
    radius = TP.search_radius_function(nhs, system, system)
    counts = zeros(Int, TP.nparticles(system))
    q(pts, backend) = isnothing(radius) ?
        foreach_point_neighbor((a, _, _, _) -> (@inbounds counts[a] += 1), x, x, nhs; points=pts, parallelization_backend=backend) :
        foreach_point_neighbor((a, _, _, _) -> (@inbounds counts[a] += 1), x, x, nhs; points=pts, search_radius=radius, parallelization_backend=backend)
    t8 = med(() -> q(points, PolyesterBackend()))
    t1 = med(() -> q(points, SerialBackend()), 10)
    chunks = [points[(div((i - 1) * n, 8) + 1):div(i * n, 8)] for i in 1:8]
    tc = [med(() -> q(c, SerialBackend()), 15) for c in chunks]
    @printf("%-8s n=%6d  empty query: 8 threads %6.3f ms, 1 thread %6.3f ms (speedup %.1f); serial time of 8 contiguous chunks [ms]: %s; max/mean %.2f\n",
            name, n, t8, t1, t1 / t8, join([@sprintf("%.2f", t) for t in tc], " "), maximum(tc) / mean(tc))
    if !isnothing(TP.get_refinement(system))
        h = [TP.smoothing_length(system, p) for p in points]
        fine = h .< 0.75 * maximum(h)
        @printf("         fine particles per chunk: %s of %d\n",
                join([count(fine[(div((i - 1) * n, 8) + 1):div(i * n, 8)]) for i in 1:8], " "), count(fine))
    end
    dv = zero(v_ode)
    kick!() = TP.kick!(dv, v_ode, u_ode, integrator.p, integrator.t)
    trhs = med(kick!, 100)
    TP.reset_timer!(TP.timer())
    for _ in 1:50; kick!(); end
    tm = Dict(r.path => r.time_ns / 1e6 / 50 for r in flatten_timer(TP.timer()))
    g(p) = get(tm, p, NaN)
    u = "kick! / update systems and nhs / "
    @printf("         RHS %.2f ms; interaction %.2f, avg. pressure (+ beta) %.2f, density %.2f\n", trhs, g("kick! / system interaction"),
            isnan(g(u * "compute average pressure and beta")) ? g(u * "compute average pressure") : g(u * "compute average pressure and beta"), g(u * "compute density"))
    return copy(dv), trhs
end


println("load ", Sys.loadavg())
tree = state(; nhs=:tree_variable, spacing_ratio=2)
println("t = ", tree.t, ", step ", tree.stats.naccept, ", ", n_active(tree.p.semi))
file = joinpath(EXAMPLES, "vortex_street_2d_refinement.jl")
mn, mx = example_global(:min_corner), example_global(:max_corner)
grid = Base.invokelatest(with_grid, tree, template_nhs(:grid, mn, mx, 0, SerialUpdate()))
states = Dict("tree" => tree, "grid" => grid)
before = Dict(k => Base.invokelatest(analyse, k, states[k]) for k in ("tree", "grid"))
function report_after(label)
    for k in ("tree", "grid")
        dv, t = Base.invokelatest(analyse, k, states[k])
        @printf("         %s %s: dv identical to before: %s, RHS %.2f -> %.2f ms\n", label, k, isequal(dv, before[k][1]), before[k][2], t)
    end
end
@eval TP begin
    @inline function skip_unsupported_pairs(f::F, ::Val{true}, system, neighbor_system, skip_value) where {F}
        return @inline function (particle, neighbor, pos_diff, distance)
            pair_in_support(system, neighbor_system, particle, neighbor, distance) || return skip_value
            return @inline f(particle, neighbor, pos_diff, distance)
        end
    end
end
println("==== @inline"); report_after("inline")
function dealt(points, b, nt=8)
    blocks = [points[i:min(i + b - 1, end)] for i in 1:b:length(points)]
    return reduce(vcat, [reduce(vcat, blocks[k:nt:end]; init=Int[]) for k in 1:nt])
end
const PTS = collect(Base.invokelatest(TP.each_active_particle, first(tree.p.semi.systems)))
@eval TP begin
    const ORDER_ = Ref{Vector{Int}}(Int[])
    @inline each_integrated_particle(system::EntropicallyDampedSPHSystem) = ORDER_[]
end
for b in (16, 64, 256)
    TP.ORDER_[] = dealt(PTS, b)
    println("==== @inline and blocks of $b"); report_after("both, blocks of $b,")
end
println("load ", Sys.loadavg())
