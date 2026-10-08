# Paired Monte Carlo protocol

The saved campaign has 100 random environments × five policies = 500 simulations, all 60 s at dt=0.01 s. Seeds 2026–2125 are held out from tuning. Policies: time, event, self, adaptive event, optimized. Use the campaign API to include fault-aware self as a sixth policy or expand N to 500 (2,500 runs). Failed outcomes remain in both the denominator and raw dataset.

| Random quantity | Distribution |
|---|---|
| Initial MRP | Baseline component + Gaussian sigma 0.035 |
| Initial angular velocity | Baseline component + Gaussian sigma 0.025 rad/s |
| Diagonal inertia | Independent baseline × U(0.85,1.15) |
| Initial effectiveness | Independent U(0.8,1) |
| Disturbance base multiplier | U(0.5,2) |
| Post-onset multiplier | U(1,4) |
| Disturbance / dropout onset | U(15,30) s |
| Dropout probability | U(0,0.35) |
| Measurement noise sigma | U(0,0.00015), same numeric sigma for MRP and rad/s |
| Affected spacecraft | Discrete uniform among four |
| Target effectiveness | Per axis U(0.2,0.8) |
| Actuator fault onset | U(15,30) s |
| Fault shape | Equiprobable sudden / gradual |
| Ramp duration | U(2,10) s |

These distributions are research assumptions, not characterized flight populations. Complete axis failure is tested in deterministic missions, not this campaign. No confidence interval on operational reliability follows from a success percentage here.

For each method, the report includes success fraction, numerical failures, mean, median, linearly interpolated 95th percentile, minimum, maximum and censored count for each metric. Recovery and convergence statistics exclude nulls and explicitly count them. Do not compare uncensored means without inspecting failures. `results/monte-carlo.json` retains every run's resolved configuration and seed.

At 0.01/0.005/0.001 s, packet-loss/noise draws align per grid index, not per continuous-time realization; step refinement in stochastic scenarios therefore tests both discretization and forcing changes. Deterministic refinement tests should be used before numerical-convergence claims. The current saved refinement is a sensitivity check, not a proof of solver convergence.
