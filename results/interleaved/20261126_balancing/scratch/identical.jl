# Scratch: whole refined runs with the load balancing on (block 64) and off (block 0)
# must be bitwise identical. Vortex street small, ratio 2, SerialUpdate.
include("/mnt/ssd/home/nschum25/benchmark/benchmarks/run_full.jl")

function run_steps(case, block, steps)
    (; ode, callbacks, alg, solve_kwargs) = deepcopy(case)
    TP.set_thread_block!(first(ode.p.semi.systems).buffer, block)
    integrator = init(ode, alg; save_everystep=false, callback=callbacks, solve_kwargs...)
    t0 = time()
    for _ in 1:steps
        step!(integrator)
    end
    return integrator, time() - t0
end

for nhs in (:grid, :tree_pruned)
    case = setup(:vortex_street; size=:small, nhs, refinement=:on, shifting=:fast,
                 update_strategy=SerialUpdate(), spacing_ratio=2)
    Base.invokelatest(run_steps, case, 64, 3)   # compile
    off, t_off = Base.invokelatest(run_steps, case, 0, 200)
    on, t_on = Base.invokelatest(run_steps, case, 64, 200)
    same = off.u.x[1] == on.u.x[1] && off.u.x[2] == on.u.x[2] && off.t == on.t &&
           off.stats.nf == on.stats.nf && off.stats.naccept == on.stats.naccept
    n(i) = last(first(n_active(i.p.semi)))
    @printf("%-12s identical after 200 steps: %s (t = %.5f, %d / %d particles, nf %d / %d); wall %.1f s off, %.1f s on (single runs)\n",
            nhs, same, on.t, n(off), n(on), off.stats.nf, on.stats.nf, t_off, t_on)
    flush(stdout)
end
