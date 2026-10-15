# V2: diagnosis and clearance recovery revision

Start with V2_COMPARISON_REPORT.md. V2_STATUS.json records completion. The original project and historical results remain unchanged; 1,426 protected files were hash-verified.

Actual MATLAB R2026a / Simulink execution covers 4, 6, 8 and 10 satellites, eight scenarios and five matched seeds: 160 V2 trials against 160 V1 trials (64 historical results reused). Another 24 paired stress simulations and nine revision tests completed.

## Open and reproduce
From this directory in MATLAB:

```matlab
addpath(pwd);
setup_v2;
open_system('SatelliteOpticalNetwork_4_v2');
% Also available: SatelliteOpticalNetwork_6_v2, _8_v2 and _10_v2.
test_v2;
% Optional new batch, saved separately:
% folder = run_v2_suite;
```

Main executed batch: results/comparison_20261014_224749_328. Raw MAT/JSON records, original metrics, additional clearance metrics, tables and figures are retained. run_v2_suite(existingFolder) resumes missing trials and reuses completed records. Do not modify the method when resuming a batch; create another version for further changes.

Original compute_metrics.m is reused unchanged. Uncertain diagnoses count as detections but never exact isolations. Recovery is conditional on an actual outage and must occur before clearance. Prevention is reported separately. New post-clearance verification does not replace the old metric.

The new method uses independent measured angular rate, delivered-torque telemetry and bounded optical probes, with fit validation and correction rollback. Blockage remains observationally ambiguous. Initial constant sensor bias, ideal torque telemetry and the simplified link/traffic model limit interpretation. These results do not establish hardware reliability or research novelty.
