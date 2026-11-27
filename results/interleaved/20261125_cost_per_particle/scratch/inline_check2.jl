include("/mnt/ssd/home/nschum25/benchmark/benchmarks/run_full.jl")
new_version = quote
    @inline function skip_unsupported_pairs(f::F, ::Val{true}, system, neighbor_system, skip_value) where {F}
        return @inline function (particle, neighbor, pos_diff, distance)
            if !pair_in_support(system, neighbor_system, particle, neighbor, distance)
                return skip_value
            end
            return @inline f(particle, neighbor, pos_diff, distance)
        end
    end
end
old_version = quote
    @inline function skip_unsupported_pairs(f::F, ::Val{true}, system, neighbor_system, skip_value) where {F}
        return @inline function (particle, neighbor, pos_diff, distance)
            if !pair_in_support(system, neighbor_system, particle, neighbor, distance)
                return skip_value
            end
            return f(particle, neighbor, pos_diff, distance)
        end
    end
end
relmax(a, b) = maximum(abs, a .- b) / maximum(abs, b)
function run(case, n)
    (; ode, callbacks, alg, solve_kwargs) = deepcopy(case)
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    states = []
    for i in 1:n
        step!(integrator)
        push!(states, (i, copy(integrator.u.x[1]), copy(integrator.u.x[2]), last(first(n_active(integrator.p.semi))), integrator.dt))
    end
    return states
end

for nhs in (:grid, :tree_variable)
    case = setup(:vortex_street; size=:small, nhs, shifting=:fast, spacing_ratio=2)
    Core.eval(TP, old_version)
    a = Base.invokelatest(run, case, 100)
    Core.eval(TP, new_version)
    b = Base.invokelatest(run, case, 100)
    println("==== $nhs")
    shown = 0
    for (x, y) in zip(a, b)
        same = isequal(x[2], y[2]) && isequal(x[3], y[3]) && x[5] == y[5]
        same && continue
        shown += 1
        shown <= 6 || break
        @printf("  step %3d differs: n %d / %d, rel. difference v %.1e, u %.1e, dt %.1e; entries that differ: v %d, u %d\n", x[1], x[4], y[4],
                length(x[2]) == length(y[2]) ? relmax(y[2], x[2]) : NaN, length(x[3]) == length(y[3]) ? relmax(y[3], x[3]) : NaN, abs(x[5] - y[5]) / x[5],
                count(!isequal(p...) for p in zip(x[2], y[2])), count(!isequal(p...) for p in zip(x[3], y[3])))
        if shown == 1
            i = findall(k -> !isequal(x[2][k], y[2][k]), eachindex(x[2]))
            println("     first differing v entries (old, new): ", [(x[2][k], y[2][k]) for k in first(i, 4)])
        end
    end
    shown == 0 && println("  identical for all 100 steps")
    @printf("  end: n %d / %d\n", a[end][4], b[end][4])
end
