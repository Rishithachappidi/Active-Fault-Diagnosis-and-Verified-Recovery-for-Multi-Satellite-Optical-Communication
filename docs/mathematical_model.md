# Mathematical model and metric contract

The preserved nonlinear model is defined by equations (1–5), (8–11), (26) and (31) of the supplied Xie–Sheng–Chen paper, DOI 10.1109/TAES.2024.3355381. The repository-specific Eq.26 factor is described in [the audit](ARCHITECTURE.md).

For each spacecraft, sigma is a three-component Modified Rodrigues Parameter vector and omega is body angular velocity in rad/s:

```
G(sigma) = (1 - sigma' sigma) I/4 + skew(sigma)/2 + sigma sigma'/2
sigma_dot = G(sigma) omega
omega_dot = J^(-1) [-omega × (J omega) + Gamma sat(u) + drift + rho]
sat(u)_a = clip(u_a, -0.2, 0.2) Nm
s_i = e2_i + r e1_i
```

`src/scenarios.mjs` contains the original inertia, initial states, directed adjacency, reference and sinusoidal disturbance parameters. The reference satisfies its own MRP kinematics. All four vehicles read the same pre-broadcast neighbor snapshot per event-trigger sample. Time-driven control with a healthy channel reads current states; under loss it reads this sample's available states and cached states for unavailable neighbors. Broadcasts are all-or-nothing per sender, not independent per-link packet losses. Initial neighbor states are preloaded at mission initialization.

The integrator is fixed-step RK4 with held commanded torque. Fault profiles and disturbance forcing are evaluated at RK4 substages. Baseline chi is forward Euler exactly as in the source. Inertia is diagonal; there are no orbital states, translation control, wheel momentum dynamics, delays, orbital disturbance models, or actuator rate limits. MRP shadow switching is deliberately absent because changing charts would alter the baseline's component-difference controller. A norm above 100 or nonfinite state aborts and marks a run failed. This is a local-attitude testbed, not global SO(3) control.

## Full-rate metrics

Metrics integrate over `[0,T)`; the final sample is for display and final error only. Four-spacecraft attitude RMSE = sqrt(∫ sum_i ||sigma_i-sigma_d||² dt / (4T)). Angular velocity RMSE is analogous (rad/s). These are vector-norm RMSE, not per-axis RMSE or geodesic attitude error. Maximum error is the largest spacecraft MRP error norm in the integration samples. No degree/radian label is attached to MRP error. Maximum overshoot percent is the largest positive growth of any spacecraft error norm relative to its own initial norm: 100 max(i,t)[max(0, ||e_i(t)||/max(||e_i(0)||,1e-12) − 1)]. It is an excursion measure, not signed step-response overshoot.

Settling criterion: every spacecraft has MRP error norm ≤0.02 and angular-velocity error norm ≤0.01 rad/s, continuously from the reported convergence time through the end, with at least two seconds remaining. Success is this terminal finite-horizon criterion, not asymptotic stability. A later violation invalidates earlier settling. The tolerance corresponds to a fairly loose small-attitude threshold and must be tightened for pointing missions.

Recovery = max(0, convergenceTime − last scheduled fault transition). Gradual profiles use ramp completion. No recovery before a fault has occurred and two post-fault seconds have elapsed. Null means not observed, censored, or not applicable; it is never silently zero. Intermittent faults have no single definitive recovery event; the reported number is relative to the profile onset, so interpret only the full history in those missions.

Effort = ∫ sum_i ||sat(u_i)||² dt, units N²m²s. It is a torque-squared cost, **not joules**. Saturation = 100 × saturated axis-samples / all 12 axis-samples. Peak torque refers to saturated command; peak unsaturated command is separate. Controller updates count local computations. Communication events count attempted sender broadcasts, including drops, excluding budget denials. One broadcast can reach multiple neighbors. Savings = 100(1 − attempts / (4 ceil(T/0.1))), relative to an unlimited 10 Hz reference, not relative to budget-limited delivered packets. Negative savings are retained.

CPU estimates use 1,200 units per controller update, 180 per event-condition evaluation and 6,000 per 50 ms diagnosis sample per vehicle. These are explicit hypothetical costs, excluding physics/rendering, memory traffic and self-predictor iteration variation. They cannot be compared with flight processor utilization. A 64-byte message assumption converts attempts to modeled bandwidth.
