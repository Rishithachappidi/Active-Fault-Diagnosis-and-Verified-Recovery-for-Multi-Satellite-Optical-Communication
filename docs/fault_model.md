# Fault scenarios and model-based diagnosis

The scenario table in `src/scenarios.mjs` supplies original initial states, a description, objective and configurable environment. Missions cover nominal, gradual single degradation, sudden axis failure, multiple degradation, increased disturbance, communication loss, sensor noise, combined stress, worst-case stress and demo. Monte Carlo is a separate campaign action rather than a fake single-run scenario. Healthy Gamma=I. Severe/degraded target diagonals are explicit arrays and can be edited per-axis in the UI or run configuration. A target of zero models unavailable control authority.

Each fault profile includes zero-based spacecraft index, onset, kind (sudden/gradual/intermittent), three effectiveness targets, ramp duration and intermittent period. Before onset Gamma is unchanged. Gradual loss interpolates over the ramp; intermittent loss alternates target and prior effectiveness every period seconds. Multiple active profiles apply in listed order. Noise is seeded independent Gaussian noise on each MRP and angular-velocity component. Dropout is a per-time-grid Bernoulli sender availability sample after the configured fault time. Noise and channel streams are generated independently of trigger counts so matched policies see the same samples on the same grid.

## Observer

Every 0.05 s, infer torque from two noisy angular-velocity samples and the **nominal** inertia:

```
y_a = J_a (omega_new,a - omega_old,a)/dt_obs + [omega_mid × J omega_mid]_a
r_a = y_a - mean(sat(u_a))
gamma_hat_a = clip(sum(u_a y_a)/sum(u_a²), 0, 1)
```

Regression uses the latest 80 observer samples (about 4 s). Unknown disturbance/drift is not subtracted using simulation truth. Inertia uncertainty, unmodeled torques, finite-difference error and noise can bias the effectiveness estimate. Accumulated saturated torque is averaged over the observer interval so changing commands are not incorrectly treated as constant.

An axis needs ≥10 observations and sum(u²)≥0.0004. Its uncertainty estimate is

```
v = max(SSE/(n-1), 2(J_a noiseStd/dt_obs)², 0.01²)
SE = sqrt(v / sum(u²))
```

Axes with SE≥0.25 are excluded from severity. F is the largest identifiable loss 1−gamma_hat. For that axis, L=F−1.96 SE and evidence=clip(L/F,0,1), or zero at F=0. The displayed percentage is this **evidence score, not a calibrated probability**. Residual samples overlap and are correlated; 1.96 is a transparent normal-approximation heuristic, not demonstrated 95% coverage.

State is critical for L>0.65, degraded for L>0.2, warning for L>0.08, otherwise healthy; with no sufficiently excited regression axes it is unobservable. Individual axes may remain uncertain even when the overall status is healthy. The inspector exposes per-axis standard errors. Initial losses, increased disturbances and noise can cause delayed or false indications. No fault-isolation guarantees or formal false-alarm probabilities are claimed.
