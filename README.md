# Communication-Aware Fault-Tolerant Attitude Coordination of Four Satellites



One integrated MATLAB/Simulink simulation: spacecraft motion changes optical pointing, optical power gates delayed state packets, received messages determine follower targets and local diagnosis can optionally adjust messaging/prediction during recovery.

The main experiment tracks a moving attitude command. **Only SC1 receives that command.** Followers maintain specified attitude offsets through a declared leader–follower chain (SC1 → SC2 → SC3 → SC4). They retain local stabilization during an outage, but cannot independently track the unknown moving command.

## Run

Tested on MATLAB R2026a Update 2. Simulink is required for the `.slx` model; the standalone simulator requires no specialized toolbox.

1. Extract this folder and open it in MATLAB.
2. Run `start_project` for the moving-reference pointing-fault demonstration and live model.
3. Run `validate_tracking_model` for core checks, information-access tests, and live parity through fault onset.
4. Run `run_tracking_pilot` for the initial communication-dependence check.
5. Run `run_tracking_experiments` for 108 main trials and, if the pilot supports it, 45 management-ablation trials.

```matlab
addpath src
c = isc_tracking_config('optical_event','pointing_actuator',11,'off');
r = isc_run(c);
disp(struct2table(r.trackingMetrics))
isc_tracking_plot(r,c,fullfile('results','my_tracking_case.png'))
build_model(c)
out = sim('IntegratedSatelliteControl');
```

To change an open model, assign `c` in its model workspace:

```matlab
mw = get_param('IntegratedSatelliteControl','ModelWorkspace');
mw.assignin('c',c);
```

Keep `src` on the MATLAB path after reopening the model. Configuration helpers set mode booleans; call them to select a mode rather than editing only `c.mode`.

## Evaluation

The expanded statistical evaluation is in [the held-out report](results/holdout/REPORT.md): 20 new run seeds, a locally frozen decision rule, new fault conditions and a second tree/network setting, and paired-seed confidence intervals. See [the frozen protocol](docs/HELDOUT_PROTOCOL.md) and [claims and limits](docs/CLAIMS_AND_LIMITS.md). Development results below remain unchanged, including adverse policy outcomes.

To reproduce it: run `validate_holdout`; create or verify the local lock with `python tools/freeze_holdout.py --freeze`; run `run_holdout_experiments`; run `python tools/analyze_holdout.py`; add explicit CSV units with `python tools/annotate_ci_units.py`; then `plot_holdout_results`. If sources differ from a supplied lock, do not silently overwrite it or describe changed code as the same frozen evaluation. The supplied lock records the sources used for the delivered results. Validation uses separate seeds 901/902.

Start with [the tracking report](results/tracking/REPORT.md), [comparison figure](results/tracking/comparison.png), and [all trial values](results/tracking/all_trials.csv). Hypotheses and parameters were declared before inspecting rankings in [the experiment plan](docs/TRACKING_EXPERIMENT_PLAN.md).

| Configuration | State transport | Optical recovery | Scheduling |
|---|---|---|---|
| `ideal_periodic` | One-sample causal ideal delivery | Off | Periodic |
| `optical_periodic_no_recovery` | Power-gated, delayed, lossy | Off | Periodic |
| `optical_periodic` | Power-gated, delayed, lossy | On | Periodic |
| `optical_event` | Power-gated, delayed, lossy | On | Event-based |

Policies `off`, `schedule`, `prediction`, and `both` separately test diagnosis-informed per-link retries and bounded neighbor extrapolation. The default is `off`: a heuristic is not presumed to improve every metric. It uses only local pilot power, accepted optical estimates, and nominal correction limits, without injected fault values or true link availability.

Nine scenarios include the complete pointing/actuator/moderate-attenuation factorial and separate severe attenuation. Metrics include exact quaternion-geodesic pair disagreement, leader-relative error, tracking, torque effort, packet attempts/payload bytes, information age, physical availability, and verified recovery.

`run_tracking_experiments` exports paired-seed factorial contrasts through `isc_tracking_interactions`. After validation and experiments, the optional standard-library Python command `python tools/report_tracking.py` regenerates the Markdown report from those saved measurements. Python is not required to simulate or calculate the MATLAB tables.

## Shared implementation and retained experiments

`isc_step` is the physical/communication kernel. `isc_tracking_target` supplies command-dependent targets while preserving the local feedback form and observer. The live Simulink S-function executes this kernel. Its four spacecraft panels expose telemetry; they are not result playback or separate hardware processors. Telemetry has a documented one-sample output delay.

The earlier static-reference condition remains reproducible with `start_static_project`, `run_experiments`, and `audit_recovery`. Its [90-trial results](results/RESULTS.md) and [30-trial recovery audit](results/recovery_audit/REPORT.md) are background experiments in the same project. Do not substitute their percentages for moving-reference results.

## Evidence boundaries

- The first project's exact MATLAB source was unavailable locally. This fresh implementation uses quaternions and does not reproduce the paper's exact self-triggered or dynamic event-triggered method. Its event scheduler is separately documented.
- The prior optical audit fixed a stale-history reset defect. Its beam-calibration failure remains documented; the tracking extension does not silently claim that limitation is solved.
- The sparse command-distribution chain has no alternate-route forwarding. A single edge failure need not have the same effect in a redundant topology.
- All moving-task configurations use a 0.06 s terminal servo; the static task uses 0.12 s. This task-specific setting was declared before rankings were inspected. Local controller gains are unchanged.
- Raw availability is power-threshold eligibility, with a separate one-second recovery scoring hold. Acquisition/lock protocol, fixed geometry, ideal attitude/encoder sensing, and reciprocal pilot measurement remain simplifications.
- This is an engineering testbed, not flight qualification, a stability proof, or an established novel published algorithm. Three seeded channel trials provide exploratory variability .

See [tracking equations and metrics](docs/TRACKING_MODEL.md), [base physics](docs/MODEL.md), [validation](docs/VALIDATION.md), and [change history](CHANGELOG.md).
