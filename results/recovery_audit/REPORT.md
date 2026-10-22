# Recovery audit: correction, physical pointing, power, and availability

This audit follows a reported concern about fast compensation at 25 s. It adds 30 trials (ten cases × three seeds) and regenerates the 90-trial benchmark after a correctness fix. No parameters were tuned to maximize these audit scores. All audit trials use a 75 s horizon and the original [25,60) s fault window.

## Defect found and fixed

Invalidating an optical fit reset its history count but left the circular-buffer write position unchanged. A partial subsequent history could therefore reference stale slots. Invalidation now clears both arrays and resets the count and write position together. A regression test starts from a deliberately contaminated nonzero ring index and verifies that the next observation is stored in slot one with no old samples remaining. Eleven automated core checks pass.

## Why the original curves could be misread

The correction curve is the **new command**, not the current terminal position. The same sample’s power is computed using the physical terminal position before that new command advances the actuator. The command is then tracked through the first-order/rate-limited terminal dynamics; only a later power sample can reflect it. [The onset plot](onset_timing.png) separates commanded correction from actual encoder residual and plots the two endpoint powers.

The raw session flag is a power-qualified bidirectional channel: both endpoints exceed threshold at that instant. It is not a full acquisition/relock state machine. A separate recovery score requires one uninterrupted second above threshold after an observed outage, before the injected fault clears.

## Targeted results

| Case | Affected availability during fault, mean ± SD | Runs with one-second verified recovery | Mean recovery duration, including hold |
|---|---:|---:|---:|
| nominal | 96.86% ± 0.00 pp | 3/3 | 2.70 s |
| recovery off | 0.00% ± 0.00 pp | 0/3 | not recovered |
| no probe | 0.00% ± 0.00 pp | 0/3 | not recovered |
| limited correction | 46.14% ± 0.00 pp | 0/3 | not recovered |
| slow terminal | 94.86% ± 0.25 pp | 3/3 | 3.00 s |
| power noise 5pct | 96.81% ± 0.08 pp | 3/3 | 2.72 s |
| beam calibration error | 0.00% ± 0.00 pp | 0/3 | not recovered |
| double pointing fault | 0.00% ± 0.00 pp | 0/3 | not recovered |
| severe attenuation | 0.00% ± 0.00 pp | 0/3 | not recovered |
| blockage | 0.00% ± 0.00 pp | 0/3 | not recovered |

Case changes: recovery off disables fitting/correction/dither; no probe removes only dither; limited correction caps the compensation norm at 10 microrad; slow terminal changes its time constant from 0.12 to 0.8 s; noise raises multiplicative pilot noise from 0.8% to 5%; beam calibration error makes the true beam width 15% smaller than the estimator assumes; double fault doubles the hidden boresight offset. Attenuation uses gain 0.12, and blockage forces optical power to zero.

## Exact nominal timing, seed 11

- Injected fault begins at 25.00 s and remains present until 60.00 s.
- First affected-session outage: 25.30 s.
- First accepted significant offset fit: 27.00 s.
- First correction-command change exceeding 50 microrad: 27.00 s.
- End of first one-second continuous recovery verification: 28.00 s.

The estimator accepts an offset and issues a command after collecting post-fault evidence; restored power is not produced by clearing the injected fault early. Truth values are retained only for audit plots and independent recomputation. They are not passed to the estimator or attitude controller.

## Independent consistency checks

- Maximum power discrepancy across all 30 trials: 3.94e-19 W.
- Session-threshold rule disagreements across all trials: 0.
- Compensation never exceeds the configured norm limit in any audit trial.
- Recomputed power uses logged spacecraft attitude transformed back to quaternions, terminal encoder position, geometry, and audit-only injected plant values; it does not reuse the simulator’s logged residual.

These checks establish internal consistency of this implementation. They are not independent validation of the Gaussian optical model, the reciprocal pilot assumption, or actual hardware.

## Conclusion and limits

The nominal case demonstrates causal, observation-based recovery **inside the stated model**. It is also a favorable recovery problem: a static offset within terminal authority, known beam shape, noiseless attitude/encoder observations, continuous pilot dither, and an ideal local reciprocal pilot. Because log-Gaussian power is linear in the fitted parameters, an excited matched-model fit can estimate that offset accurately. Fast correction alone cannot establish broad robustness.

The controls and stress cases define the evidence boundary. Complete darkness/out-of-capture pointing errors, severe attenuation, and blockage do not acquire a valid correction that restores service in these tests. Reduced excitation, noise, and model mismatch must be interpreted from their measured rows rather than presumed to succeed or fail. The small three-seed sample is exploratory.

The project is a tested integrated simulation deliverable. Claims of reliable physical session reacquisition, flight readiness, or research-level stability still require a realistic acquisition/lock state machine, additive sensor/receiver noise, delayed pilot feedback, larger parameter sweeps, hardware-specific calibration, and appropriate analysis. Those extensions are not silently assumed complete.

[Raw audit trials](trials.csv) · [Refreshed benchmark results](../RESULTS.md) · [Model assumptions](../../docs/MODEL.md)
