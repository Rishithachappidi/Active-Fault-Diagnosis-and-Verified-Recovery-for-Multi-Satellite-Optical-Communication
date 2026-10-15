# Satellite Optical Communication — final V2 package

This is the self-contained package to use. You do not need either previous ZIP.

## Open in MATLAB / Simulink
1. Extract the ZIP completely to a writable local folder.
2. In MATLAB, change Current Folder to this folder (the one containing START_HERE.md).
3. Run `start_v2`.

This opens the four-satellite V2 Simulink model and sets the paths. For other sizes run `open_system('SatelliteOpticalNetwork_6_v2')`, substituting 8 or 10 as needed.

The project was executed with MATLAB R2026a and Simulink. Both products and valid licenses are required. Nine revision tests can be rerun with `test_v2`; this executes simulations and writes new timestamped test results.

## Read the results
- Main report: revisions/v2/V2_COMPARISON_REPORT.md
- Metric definitions and ambiguity audit: revisions/v2/docs/METRIC_AUDIT_AND_IDENTIFIABILITY.md
- Main final results: revisions/v2/results/comparison_20261014_224749_328
- Stress results: revisions/v2/results/stress_20261014_225450_080
- Project status: revisions/v2/V2_STATUS.json

The main results directory contains tables, figures and raw simulation records. It covers 4, 6, 8 and 10 satellites, eight scenarios and five matched seeds. These remain simulation results, not proof of hardware reliability.

## Run experiments
After `start_v2`, run `folder = run_v2_suite;` for a NEW complete comparison batch. Existing results are preserved. Run `run_v2_stress` for a new stress batch or `audit_metrics_v1` to recompute the saved baseline metrics. These operations may take several minutes.

To regenerate figures from the included final records:
```matlab
plot_v2_comparison(fullfile(pwd,'revisions','v2','results','comparison_20261014_224749_328'));
```

## Why some original files remain
The matlab/, configs/ and simulink/ folders supply the shared physics, unchanged metrics and original baseline models. Do not remove them. The results/ folder holds the 64 historical proposed-method trials reused by V2 and the full historical baseline summary table. The other 96 matched baseline trials are in the V2 main batch.

Pilot outputs, build caches, old root reports/status/launchers, unrelated sensitivity/control/profile study outputs and historical raw trials not needed for this comparison have been omitted. All final V2 trial records remain. PACKAGE_CONTENTS.json lists exclusions; PACKAGE_MANIFEST.json hashes the delivered files. Historical preservation reports inside V2 record checks of the full source project before packaging, not a claim that every historical file is included here.
