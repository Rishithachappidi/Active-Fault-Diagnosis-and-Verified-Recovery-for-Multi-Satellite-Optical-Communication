# Satellite Optical Fault Recovery

Active fault diagnosis and verified recovery for multi-satellite optical (laser) communication networks, built in MATLAB R2026a and Simulink.

A supervisor watches each optical crosslink, identifies what failed (pointing, actuator, optical power, blockage or sensor faults), applies a correction only when it can actually restore service, and removes that correction once the fault clears. The repository compares the original supervisor (V1) with a revised one (V2) on networks of 4, 6, 8 and 10 satellites.

**Live simulator:** https://kaushalrog.github.io/Satellite-Optical-Fault-Recovery/ · **MATLAB results:** https://kaushalrog.github.io/Satellite-Optical-Fault-Recovery/results.html · **Attitude integration:** https://kaushalrog.github.io/Satellite-Optical-Fault-Recovery/integration.html

## Results at a glance

Four-satellite network, mean of five seeds, 320 matched Simulink trials in total.

| Metric | V1 | V2 |
|---|---:|---:|
| Detection accuracy | 72.06% | 96.53% |
| False-alarm rate | 33.42% | 2.98% |
| Exact fault isolation | 9.48% | 71.52% |
| Post-clearance outage | 0.599 s | 0.152 s |
| Diagnosis time | 0.020 s | 0.249 s |

Full analysis, including regressions and limits: [revisions/v2/V2_COMPARISON_REPORT.md](revisions/v2/V2_COMPARISON_REPORT.md). These are simulation results, not evidence of hardware reliability.

## Quick start

Requires MATLAB R2026a with Simulink. From the repository root in MATLAB:

```matlab
start_v2                     % set paths and open the 4-satellite V2 model
test_v2                      % run the nine revision tests
folder = run_v2_suite;       % run a new 320-trial comparison batch
plot_v2_comparison(folder)   % regenerate the figures
```

Other network sizes: `open_system('SatelliteOpticalNetwork_6_v2')`, or `_8_v2`, `_10_v2`.

## Repository layout

```
├── start_v2.m            Entry point: paths + 4-satellite V2 model
├── setup_project.m       Adds the shared MATLAB folders to the path
├── START_HERE.md         Step-by-step guide to the package
├── matlab/               Shared physics, diagnosis, recovery and metrics code (V1 baseline)
├── configs/              Network and experiment configurations (4, 6, 8, 10 satellites)
├── simulink/             Original V1 Simulink network models
├── revisions/v2/         V2 supervisor, models, tests, report and results
│   ├── models/           V2 Simulink models
│   ├── docs/             Metric audit and identifiability notes
│   └── results/          Comparison, stress and test batches (tables, figures, raw runs)
├── results/              Historical V1 trials reused by the V2 comparison
├── integration/          Coupled attitude control + optical recovery model
├── docs/                 Project website (served by GitHub Pages)
├── render.yaml           Render static-site deployment of docs/
└── PACKAGE_*.json        Package contents and file hashes
```

## Website

The site in [docs/](docs/) is plain HTML and JavaScript with no build step. Its front page is a live browser simulator: a JavaScript port of the MATLAB model where you inject faults and watch the V1 and V2 supervisors respond. A benchmark sweep there reruns the 80 four-satellite trials in about a second and compares them with the MATLAB averages. The verified MATLAB results are on `results.html`. GitHub Pages serves it from `main` → `/docs`. To deploy on Render instead, choose **New → Blueprint** in Render and select this repository; `render.yaml` publishes `docs/`.

To refresh the site after a new MATLAB run:

```bash
python3 docs/build_data.py comparison_YYYYMMDD_HHMMSS_SSS
cp revisions/v2/results/comparison_YYYYMMDD_HHMMSS_SSS/figures/*.png docs/figures/
```

## Integration with spacecraft attitude control

[`integration/`](integration/INTEGRATION.md) is the integrated system: this optical link recovery combined with the spacecraft formation attitude controller ([Spacecraft-Formation-Attitude-Control](https://github.com/kaushalrog/Spacecraft-Formation-Attitude-Control)) in one Simulink model, `IntegratedFormationOptical.slx`. Each transmitting spacecraft's attitude error becomes a line-of-sight error on its optical terminal, after a minimal coarse-pointing stage. Run `int_run_all` in MATLAB from that folder: it reproduces both baselines, runs four scenarios and 15 integration checks. Results page: https://kaushalrog.github.io/Satellite-Optical-Fault-Recovery/integration.html

## Earlier project

This repository previously held the spacecraft formation attitude-control project (event-triggered and self-triggered fault-tolerant control). It now lives in its own repository, [kaushalrog/Spacecraft-Formation-Attitude-Control](https://github.com/kaushalrog/Spacecraft-Formation-Attitude-Control), with its interactive digital twin at https://kaushalrog.github.io/Spacecraft-Formation-Attitude-Control/. An unchanged copy also remains on the [`attitude-control-archive`](../../tree/attitude-control-archive) branch here.
