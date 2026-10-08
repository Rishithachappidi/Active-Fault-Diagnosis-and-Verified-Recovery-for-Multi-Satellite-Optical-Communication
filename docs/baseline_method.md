# Baseline preservation and regression

Original artifacts are hashed in `baseline/manifest.json`. The 29 original files remain unchanged; original `index.html` and README reside under `baseline/`. The eight original MATLAB/text simulation files and original SLX remain at their original paths. The fourteen supplied plots are unchanged. `npm run verify:baseline` checks every original hash.

The strict preset is `scenario: 'paper'` and permits `baseline-time`, `baseline-event`, `baseline-self` only. It locks 60 s, dt=0.001 s, original actuator effectiveness and original parameters. Injection, tuning, and parameter overrides are rejected. Budgets are effectively unlimited. Stress scenarios use the same policy equations with modified environmental assumptions and are labeled separately.

```
k1_i = gainScale * 2(gamma beta1 + beta2) / degree_i
k2_i = (k0+1) / (degree_i delta)
u_i = -k1_i s_sample - k2_i alpha (1+||omega||+||omega||²) sign(s_sample)
```

Case 1 telemetry reports the current-neighbor coordination used by its controller (the original MATLAB s_out diagnostic instead retains its initialized broadcast cache in Case 1). This diagnostic correction does not change baseline torques or trajectories. Case 1 updates at 10 Hz, including t=0 and excluding t=60. Case 2 fires when ||s_sample−s||² ≥ delta||s_sample||² + chi + epsilon. After a trigger, the sampled error is zero before updating chi. Case 3 performs 60 fixed-point iterations:

```
t_next = t + sqrt(delta||s||² + chi0 exp[-(beta1+beta2)t_next] + epsilon)
                 / (2||J^-1|| [5 k1||s|| + (5 k2+1)alpha Phi])
```

The minimum interval is dt and deadline comparisons use dt/2 tolerance, matching the MATLAB source. **The factor 2 is in the repository source, not printed Eq.26.** It is preserved without claiming that its outputs reproduce the paper's table. Baseline port update counts are 2,400 / 458 / 3,202, not the literal paper counts in the legacy browser.

`baseline/regression.json` is a frozen JavaScript port fixture, not independently measured MATLAB truth. The tests lock repeated behavior and analytical unit properties. For independent MATLAB validation, run `simulation/extensions/sff_validate_baseline.m`. It executes original functions with RK4 and compares counts and RMSE. For the original Simulink workflow use `R=sff_run_all` from `simulation/`. Neither MATLAB nor Simulink was available during this implementation, so no cross-runtime or SLX execution claim is made.
