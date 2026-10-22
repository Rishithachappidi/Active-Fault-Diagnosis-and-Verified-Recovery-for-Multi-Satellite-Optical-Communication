# Frozen decision rule and held-out statistical evaluation

This protocol is frozen before inspecting seeds 101–120. Development data are only the previously reported seeds 11, 23, 47. The new rule is a candidate selected after those development results, not an algorithm claimed novel or optimal. Existing adverse scheduling-only and joint-policy rows remain in the project.

## Frozen policy

No aggressive retry interval is used. The ordinary maximum silence remains 0.8 s. Only local state 3 with a valid optical fit (estimated best achievable power below the service margin) increases retry silence to 1.6 s. This is resource throttling during estimated steering infeasibility, not a repair for attenuation.

For an affected parent link, temporarily extend bounded constant-rate prediction from 1.5 to 3 s only when all conditions hold:

1. Local optical evidence is degraded/uncertain but a measurable pilot remains (at least 1% of nominal power), or an accepted fit identifies a potentially recoverable offset at least 0.2 nominal beam width.
2. The last parent sample is at least 1.5 s old but younger than 3 s.
3. At least two increasing-timestamp parent messages have supplied a finite observed angular-rate change no greater than 3e-4 rad/s². Prior rate is rotated into the latest message frame before differencing.

Otherwise use the baseline horizon. A valid estimate of insufficient aligned power disables this prediction extension. Local feasibility assessment still assumes the reciprocal pilot model. Low past rate change does not guarantee low future acceleration; the rule is a heuristic and may fail. There is no fault-time, injected-severity, true-availability, or current-neighbor-state input.

The rule and all constants are fixed for the entire held-out run. Their source hashes are recorded in `results/holdout/lock.json` and checked after execution. There will be no retuning to make the held-out rows favorable. An implementation defect may be fixed only with an explicit record and restart, not by silently reusing favorable completed rows.

## Independent units and cases

Use 20 independent run seeds: 101 through 120, distinct from development seeds. A dedicated seeded stream samples initial rotation-vector perturbations (normal, SD 0.002 rad per component), initial angular rates (normal, SD 1e-4 rad/s), a uniform reference phase, independent uniform disturbance phases, and per-axis disturbance multipliers uniform on [0.7,1.3]. These quantities and channel draws are paired across compared configurations. No claim is made that this sampling distribution represents every spacecraft mission.

Every run lasts 75 s at 0.05 s. Case definitions are fixed:

| Case | Perturbation beyond the sampled initial conditions/disturbances |
|---|---|
| principal_pointing | Original pointing magnitude/window; held-out seeds and phases |
| principal_combined | Original three-factor magnitudes/window; held-out seeds and phases |
| short_small | Pointing scale 0.6; fault [31,43) s |
| long_large | Pointing scale 1.25; fault [18,63) s |
| combined_new | Pointing scale 1.2, gain 0.55, effectiveness [0.25,0.4,0.3], fault [28,52) s |
| severe_attenuation_new | Gain 0.08, fault [22,55) s |
| beam_mismatch_new | True beam width scale 0.9, pointing scale 0.9, fault [20,58) s |
| alternate_tree_network | Parent map [0,1,1,2], pointing scale 1.1, delay 0.20–0.35 s, loss 10% |

The first two cases compare five configurations: ideal periodic, impaired periodic without recovery, recovered periodic, recovered event with policy off, recovered event with frozen policy. That is 2×5×20=200 trials. The six additional cases compare recovered event off versus frozen: 6×2×20=240. Total 440 held-out trials. The additional cases test policy transfer; they do not supply a complete four-mode baseline comparison for each new topology/fault combination.

Use metrics from each case's own fault window. Do not pool repeated time samples as independent trials. Save the first seed's full logs per case/configuration and metrics for all seeds. The alternate-tree/network case changes two factors jointly, so it tests transfer under that joint condition rather than isolating topology from network delay/loss.

## Confidence intervals and interpretation

Principal comparisons in each principal case: no-recovery minus ideal fault-window pair RMS; recovered periodic minus no-recovery pair RMS; recovered event minus recovered periodic pair RMS and packet-attempt percent change; frozen minus event-off pair RMS and percent change. Also report tracking, control effort, attempts, and feasibility/recovery outcomes.

Confidence intervals are 95% pointwise paired-seed percentile bootstrap intervals, with 10,000 resamples of the 20 run-seed units and a fixed analysis RNG. For relative effects, calculate the per-seed percentage before averaging. Absolute-error contrasts are in degrees. The same resampled indices preserve pairing. Per-configuration means and intervals are descriptive over the sampled run distribution. Intervals are exploratory and not adjusted for all comparisons/cases. Do not equate repeatability, a narrow interval, or an interval excluding zero with universal robustness or algorithmic novelty.

The new initial conditions and phases intentionally broaden the tested distribution beyond the original three channel-only seeds. Fault magnitudes/durations and topology remain a finite declared matrix, not a random sample of all possible missions. Static Gaussian optics, reciprocal pilot sensing, missing lock-acquisition physics, and the known calibration limitation remain explicit. Fit fractions and conditional offset errors are not classification accuracy; no general optical-diagnosis accuracy claim is made.
