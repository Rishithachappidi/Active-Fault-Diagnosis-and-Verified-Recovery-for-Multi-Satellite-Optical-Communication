# Proposed adaptive and self-trigger policies

These are empirical research extensions. No new Lyapunov, ISS, Zeno-exclusion or saturation-robustness theorem is claimed. A finite sample interval prevents infinitely many events in the implemented simulation; it does not establish continuous-time properties.

## Adaptive threshold

Let `q = delta ||s_sample||² + chi + epsilon`. Let F be estimated worst-axis loss, c its lower-bound evidence score, D the magnitude of the post-regression torque residual, U attempted broadcasts, B the budget, R a recent update-rate estimate, and p_drop the configured channel-loss fraction:

```
demand = a_e (||s|| + ||e1|| + ||e2||) + a_f F c + a_d min(5, D/0.01)
resource = a_c (U/max(1,B) + min(2,R/20) + p_drop)
scale = clip((1+resource)/(1+demand), 0.05, 3)
threshold = max(1e-9, q scale)
```

Default coefficients are 4, 3, 1, 1 respectively. R decays by exp(−dt) each sample and increases by one per update, giving a one-second exponential update-rate memory. More estimated error, credible loss or residual torque tightens the threshold; used budget, configured channel cost and recent rate relax it. U/max(1,B) is bounded implicitly by budget enforcement. High communication pressure may conflict with error-driven urgency; the clamp and maximum hold time expose that trade-off rather than proving it safe.

The proposed event policy fires at t=0, when sampled coordination error squared reaches the threshold, or when time since last update reaches maxInterval (default 1 s). Its chi uses the baseline equation with a nonnegative numerical clamp. Local control continues even if no broadcast is allowed. Diagnosis and per-sample trigger checks continue consuming resources even when communication is reduced.

## Fault-aware control

The physics-based baseline control structure remains. On an update, if evidence >0.5, commanded torque is divided per axis by clip(estimated effectiveness, 0.35, 1). Actual saturation remains ±0.2 Nm. This bounded gain compensation is heuristic and cannot restore authority to a failed axis. Baseline modes do not use it.

## Fault-aware self prediction

At an update, calculate the preserved repository self-trigger interval tau0 and the current adaptive scale. Set `tau = clip(tau0 sqrt(scale), dt, maxInterval)` and next time = t+tau. The predicted time stays fixed until the next deadline; the implementation does not claim to continuously reschedule an unknown future fault. Unexpected faults can therefore wait until the scheduled update. Diagnostics still sample every 50 ms, and display/physics continue at the integration step. “Self-triggered” does not mean the entire digital twin stops computing.

## Explainability and separation

Every logged update stores the pre-reset sampled error, threshold, scale, estimated severity, evidence, nuisance torque magnitude, actual inter-event interval, predicted next time, reason, and communication outcome. Observer inputs exclude plant effectiveness and injected disturbance truth. Truth is separately labeled for evaluation. The UI replays these records instead of generating canned explanations.
