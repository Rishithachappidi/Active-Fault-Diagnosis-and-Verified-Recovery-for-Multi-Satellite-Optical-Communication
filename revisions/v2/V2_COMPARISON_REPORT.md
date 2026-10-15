# V2 diagnosis and verified recovery: executed comparison

## Execution and preservation
- Original MATLAB source, metric implementation, SLX models and completed comparison results are unchanged: **1426 protected files hash-verified**.
- The four V2 SLX files are separately saved copies of the existing network models. Native continuous Simulink terminal plants are retained; the supervisor and estimator logging are revised. Every new result came from sim(), not a Python plant.
- **160 revised trials**: 4/6/8/10 satellites × 8 scenarios × 5 seeds.
- **160 matched V1 trials**: 64 reused verbatim from saved results, 96 additional trials with unchanged V1 code for seeds 303/404/505.
- **24 paired stress trials**: shifted fault times (2.7–6.7 s), higher angle noise (0.2 urad), seeds 707/808, 4/10 nodes and pointing/sensor/combined faults.
- **9 revision tests passed**. Saved V1 metrics recomputed exactly for all 64 historical proposed runs.
- No default receiver threshold, transmit power, fault schedule, topology, plant limit or original metric formula changed in the main comparison.
- Seeds 101/202 are the historical shared set; 303/404/505 were not used for pilot tuning. Results remain simulation-only evidence.

## Metric audit
Original detection accuracy is (TP+TN)/all 450 evaluation samples per trial. Uncertain class 7 counts as detection but never as correct exact isolation. Exact isolation is exact fault-class matches divided by 300 fault samples, excluding the healthy trial's undefined value. False-alarm rate is FP/(FP+TN). Physical recovery requires >=0.5 s sustained availability before scheduled clearance and is eligible only after an outage occurs.

The previous classifier could uniquely emit only power class 4; it could not uniquely emit pointing, actuator, sensor or combined classes. Its actuator gate was too large for the actual input, and the optical diagnosis/correction was latched after one scan. The earlier blanket claim of sensor/boresight ambiguity was too strong for transient faults: independently measured rate history is available in this plant.

The code and denominator audit are in [METRIC_AUDIT_AND_IDENTIFIABILITY.md](docs/METRIC_AUDIT_AND_IDENTIFIABILITY.md) and [v1_metric_audit.json](results/v1_metric_audit.json).

## Main numerical comparison
Four-node results; original per-run metrics averaged within each seed, then mean ± sample SD across five seeds. The same paired impaired-edge signals make the diagnostic results equal across sizes; network-average availability and route latency still depend on topology.

|Metric|V1|V2|
|---|---:|---:|
|Detection accuracy|72.056 ± 0.000 %|96.533 ± 0.122 %|
|Binary detection precision|79.883 ± 0.000 %|98.229 ± 0.093 %|
|Binary detection recall|71.190 ± 0.000 %|95.762 ± 0.213 %|
|False-alarm rate|33.417 ± 0.000 %|2.983 ± 0.149 %|
|Exact fault isolation|9.476 ± 0.000 %|71.524 ± 0.213 %|
|Uncertainty rate|44.361 ± 0.000 %|14.167 ± 0.000 %|
|Conditional physical recovery|40.000 ± 0.000 %|25.000 ± 0.000 %|
|Affected-link outage|3.582 ± 0.005 s|2.725 ± 0.002 s|
|Post-clearance outage|0.599 ± 0.004 s|0.152 ± 0.003 s|

These are the original macro aggregations, not a change to more favorable denominators. Exposure-pooled TP/FP/FN/TN metrics are provided separately, explicitly labeled, in pooled_detection_with_denominators.csv. One-versus-rest exact-class precision/recall/FAR use a different question than binary detection and are separately tabulated.

## Per-scenario isolation and service
Four nodes; five repeated trials. Full precision/recall/FAR, uncertainty and variability by class and size are in the linked tables.

|Scenario|V2 detection accuracy|V1 exact isolation|V2 exact isolation, mean ± SD|V2 uncertainty|V2 link outage|
|---|---:|---:|---:|---:|---:|
|normal|100%|undefined%|undefined ± undefined%|0%|0 s|
|pointing|98.44%|0%|76.33 ± 0%|15.56%|3.8 s|
|effectiveness|88.89%|0%|85.67 ± 1.491%|0%|0 s|
|lag|89.56%|0%|86.33 ± 0%|0%|0 s|
|power|98.44%|66.33%|76.33 ± 0%|15.56%|6 s|
|blockage|99.56%|0%|0 ± 0%|66.67%|6 s|
|sensor|98.93%|0%|99.67 ± 0%|0%|0 s|
|simultaneous|98.44%|0%|76.33 ± 0%|15.56%|6 s|

Blockage remains uncertain because zero received power cannot distinguish blockage from transmitter extinction or sufficiently deep attenuation. No forced class-5 assignment was used to inflate exact accuracy. Sensor-bias changes are identified using the encoder-minus-integrated-independent-rate innovation; this does not identify an unknown constant initial bias, and it would fail if rate were derived from the same biased encoder. Actuator estimates rely on the model's ideal delivered-torque telemetry and informative excitation; discretization biases the numerical parameter estimates.

## Recovery denominator and prevention
Per network size, the fixed 40-trial comparison has:
- V1: 10 recovered / 25 eligible outage cases.
- V2: 5 recovered / 20 eligible outage cases.
- 5 V1 outage cases prevented altogether by V2.
- 0 newly introduced fault-window outages.

Prevention removes cases from the original eligible denominator; it is not silently counted as recovery. The resulting conditional percentage must be read with these counts. The full baseline outage cohort is retained in recovery_eligibility_and_prevention.csv.

Pure power degradation and the combined offset/power case cannot regain physical service by pointing alone: even perfect alignment yields about 0.703 and 1.367 uW respectively, below the unchanged 1.5 uW sensitivity. V2 therefore avoids a futile combined-fault correction and reroutes. It does not claim to repair a damaged terminal.

## Stale corrections and post-clearance verification
The supervisor continuously compares measured power with its fitted optical prediction. Sustained contradiction invalidates the fit and removes its correction; it then verifies availability over a hold interval. Sensor correction follows the independently estimated bias and falls when that bias clears. No true fault label, onset or clearance time enters these decisions.

In shifted-time/high-noise stress trials, V2 verified post-clearance restoration in **12/12** runs. Evaluation uses the known clearance time, but control does not. Post-clearance outage/false alarms are supplementary measures and do not replace the original pre-clearance recovery statistic.

## Regressions and limits
- Actuator-effectiveness healthy-window false alarms increased from 0% to 4.667% (SD 1.491 percentage points); lag-case false alarms increased from 0% to 4.000%. Identifying actuator faults creates finite detection and clearance delays; the previous detector often missed them entirely. Compare healthy-window false alarms per scenario, not only the overall rate.
- Optical probes have service and control cost. They remain bounded but are not globally optimal experiments or a formal safety guarantee.
- The one-step actuator regression uses sampled signals; gain/time-constant estimates can be biased. Classification thresholds are model-specific.
- Blockage remains unisolated, and initial sensor bias remains confounded without calibration.
- Only five main seeds and two stress seeds are evaluated. These SDs are across trials, not confidence based on thousands of correlated time samples.
- Fixed topology, symmetric independent terminal per edge, ideal torque telemetry, threshold receiver and fluid traffic remain. No real-world reliability or research novelty is claimed.

## Tables, models and reproducibility
Main results: results/comparison_20261014_224749_328.

- [Original-metric overall comparison](results/comparison_20261014_224749_328/tables/overall_original_metrics.csv)
- [Per-scenario metrics and variability](results/comparison_20261014_224749_328/tables/per_scenario_metrics.csv)
- [Exact-class accuracy/precision/recall/FAR](results/comparison_20261014_224749_328/tables/exact_class_one_vs_rest.csv)
- [Exposure-pooled metrics and counts](results/comparison_20261014_224749_328/tables/pooled_detection_with_denominators.csv)
- [Four-versus-ten comparison](results/comparison_20261014_224749_328/tables/four_vs_ten.csv)
- [Held-out seed summaries](results/comparison_20261014_224749_328/tables/heldout_seed_metrics.csv)
- [All saved baseline methods, shared seeds](results/comparison_20261014_224749_328/tables/all_saved_baselines_shared_seeds.csv)
- [Paired trial deltas](results/comparison_20261014_224749_328/tables/paired_differences.csv)
- [Recovery cohorts](results/comparison_20261014_224749_328/tables/recovery_eligibility_and_prevention.csv)
- [Scalability figure](results/comparison_20261014_224749_328/figures/matched_scalability.png)
- [Recovery/clearance traces](results/comparison_20261014_224749_328/figures/clearance_and_recovery.png)
- SLX models: models/SatelliteOpticalNetwork_4_v2.slx, _6_v2.slx, _8_v2.slx, _10_v2.slx.
- Setup: add this v2 directory to MATLAB's path, run setup_v2, then test_v2. run_v2_suite creates a new batch; supplying an existing V2 batch resumes missing trials without overwriting completed MAT files. prepare_v2_models skips existing V2 models and never saves over V1.
