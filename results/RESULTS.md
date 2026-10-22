# Measured results — integrated four-satellite project

Generated from 90 fresh MATLAB runs: five configurations × six scenarios × three seeds (11, 23, 47). Each trial lasts 90 s at a 0.05 s step. The following values are means across seeded runs; per-run values and standard deviations are in `trials.csv` and `summary.csv`.

## Main integrated configuration

| Scenario | Attitude RMS (deg) | All-link availability | Affected link during fault | Attempted directed packets | Delivered / attempted |
|---|---:|---:|---:|---:|---:|
| healthy | 0.01132 | 100.00% | 100.00% | 1908 | 84.21% |
| pointing | 0.01132 | 99.68% | 96.86% | 1908 | 83.95% |
| body actuator | 0.01144 | 100.00% | 100.00% | 1908 | 84.21% |
| attenuation | 0.01133 | 92.71% | 0.00% | 1908 | 79.63% |
| blockage | 0.01133 | 92.71% | 0.00% | 1908 | 79.63% |
| combined | 0.01144 | 99.48% | 94.14% | 1908 | 83.81% |

## Matched pointing-fault comparison

| Configuration | Attitude RMS (deg) | Affected link during fault | Attempted directed packets |
|---|---:|---:|---:|
| ideal_periodic | 0.01186 | 100.00% | 5400 |
| optical_periodic_no_recovery | 0.01124 | 0.00% | 5400 |
| optical_periodic | 0.01132 | 96.86% | 5400 |
| optical_event | 0.01132 | 96.86% | 1908 |
| optical_event_no_prediction | 0.01207 | 96.86% | 1946 |

Enabling optical recovery in the periodic configuration changes affected-link availability by 96.86 percentage points in the pointing scenario. Changing recovered periodic messaging to event messaging reduces directed attempts by 64.67% in that scenario.

These are different comparisons: the first isolates recovery with periodic scheduling held fixed; the second isolates scheduling with recovery enabled. They do not establish that every performance measure improves.

The attitude RMS includes the tail of the initial maneuver after 10 s, and all satellites have local absolute-reference feedback. Consequently, restoring one link does not necessarily reduce aggregate attitude RMS. Disabling prediction is an ablation, not a guaranteed worse controller under every noise realization.

The severely attenuated and blocked SC1–SC2 sessions cannot be repaired by beam steering. Other direct sessions remain available, so all-network availability can look high despite a completely failed affected session. No alternate-route forwarding is implemented.

## Validation

- Eleven automated numerical/causal/physical checks passed, including stale-history reset regression.
- All 90 trials have zero queue overflow and quaternion norm error below 1e-12.
- Standalone/Simulink parity, selected-case step-size sensitivity, and post-clearance compensation checks are recorded below.

```text
MATLAB 26.1.0.3251617 (R2026a) Update 2
simulink_max_abs_difference: 0
coarse_rms_rad: 0.00019641215388
fine_rms_rad: 0.000196988316351
rms_abs_difference_rad: 5.76162470533e-07
coarse_affected_availability: 0.968571428571
fine_affected_availability: 0.966452533904
post_clearance_max_correction_rad: 3.06691673498e-06
post_clearance_availability: 1
```

The Simulink output has a documented one-sample delay; parity compares the correctly aligned samples. Halving the step also changes noise sampling and discrete event timing, so the sensitivity result is not a formal order-of-convergence estimate.

## Interpretation and limits

This is one coupled engineering prototype, not a proof of a novel algorithm or flight qualification. Local sensors, reciprocal pilot measurement, fixed geometry, complete direct connectivity, and normalized optical power are simplified. Three seeded runs provide exploratory variability, not a large statistical study. See `../docs/MODEL.md` for every equation, assumption, and metric denominator.

## Recovery audit update

All benchmark values above were regenerated after correcting the circular-history reset. The independent 30-trial recovery audit distinguishes commanded correction from physical terminal response, reconstructs endpoint power from geometry, and challenges the method with excitation/authority/calibration changes. See [the recovery audit report](recovery_audit/REPORT.md).
