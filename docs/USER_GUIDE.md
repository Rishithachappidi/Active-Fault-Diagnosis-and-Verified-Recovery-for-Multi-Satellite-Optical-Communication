# User guide and source map

The main entry `start_project` now runs moving-reference leader–follower tracking. Start with the root README and `results/tracking/REPORT.md`. `start_static_project` preserves the earlier static demonstration. New entry points are `run_tracking_pilot`, `run_tracking_experiments`, and `validate_tracking_model`; model parameters can be selected with `build_model(isc_tracking_config(...))`.

## Entry points

| File | Purpose |
|---|---|
| `start_project.m` | Run the integrated demonstration, show metrics, build/open Simulink |
| `run_experiments.m` | Execute the 90-trial matched benchmark and export tables/plots |
| `run_tests.m` | Run numerical, physical, and causal checks |
| `audit_recovery.m` | Run recovery ablations, physical-state recomputation, and stress cases |
| `build_model.m` | Generate the live `.slx` model from source |
| `src/isc_config.m` | Nominal parameters and scenario selection |
| `src/isc_init.m` | Four-body, terminal, cache, queue, and estimator initial conditions |
| `src/isc_step.m` | Causal coupling of physics, messaging, diagnosis, and control |
| `src/isc_controller.m` | Observable-only distributed feedback and disturbance estimation |
| `src/isc_target.m` | Body attitude to terminal line-of-sight target |
| `src/isc_diagnose.m` | Observable-only pilot offset/gain fit and correction |
| `src/isc_faults.m` | Hidden experiment injections only |
| `src/isc_math.m` | Quaternion operations |
| `src/isc_run.m` | Reproducible standalone simulation and logging |
| `src/isc_metrics.m` | Explicit scoring windows and denominators |
| `src/isc_plot.m` | Six-panel trial visualization |
| `src/isc_sfunction.m` | Live Simulink execution of the same coupled core |
| `src/isc_pack.m` | Lossless numeric DWork state serialization |
| `src/isc_telemetry.m` | Documented Simulink output layout |

## Change a scenario

Use `isc_config` to choose a mode/scenario/seed; change numerical parameters on the returned structure. Mode booleans are initialized by `isc_config`, so **do not change only `c.mode`** to select another configuration. Call `isc_config` again instead.

For example:

```matlab
c = isc_config('optical_periodic','attenuation',23);
c.T = 120;
c.faultEnd = 80;
r = isc_run(c);
```

Experiment metrics assume the configured fault window lies inside the simulation. For brief smoke tests call `isc_step` directly or retain a duration extending past fault onset.

## Read results

Start with `results/RESULTS.md`, `comparison.png`, and `trials.csv`. For detailed review, load one scenario/configuration `.mat` file: `r` holds logs and metrics; `c` holds the exact parameters used.

Useful plots include power versus threshold, correction removal after fault clearance at 60 s, attempted versus delivered packets, and attitude error. Do not judge recovery solely from a supervisor label: inspect measured physical availability.

## Troubleshooting

- Undefined `isc_config`: run `addpath src` from the project root.
- Model missing: run `build_model` with a Simulink license.
- Reopened model cannot find its S-function: add the extracted `src` folder to the path first.
- Parameter edits seem ignored: update `c` in the Simulink **model workspace**, as shown in the README.
- Very low power under attenuation/blockage: this is expected. Pointing control cannot restore missing optical power or remove an obstruction.
- Similar attitude curves despite optical failure: all satellites know the absolute reference and other direct links can remain available. Link recovery and reduced coordination error are different outcomes.

## Suggested demonstration

1. Show the four attitude-error curves.
2. At 25 s, explain the injected SC1–SC2 terminal offset.
3. Show power dropping and the affected session losing packets.
4. Show the fitted correction and whether power crosses the threshold again.
5. At 60 s, show the fault clearing and stale correction being reconsidered.
6. Compare periodic versus event attempts, along with attitude RMS, rather than claiming communication savings alone establish better control.

The package contains a working simulation, not a finished research manuscript. Use measured tables when drafting a paper and keep limitations in the model specification visible.

For interpreting a sharp recovery command, open `results/recovery_audit/onset_timing.png`. It shows the injected offset, newly commanded correction, physical terminal residual, both endpoint powers, fit validity/session eligibility, and true effective residual over 24–32 seconds. Truth curves are audit outputs and are not available to the controller or optical supervisor.
