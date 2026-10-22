# Validation record

The frozen held-out policy adds five checks, bringing the validated implementation to 23 MATLAB checks (11 core, 7 tracking, 5 held-out policy checks). Validation uses seeds 901/902; evaluation uses 101–120. `validate_holdout` verifies 32 s live Simulink parity for the frozen policy through fault onset. `results/holdout/bootstrap_validation.txt` records a synthetic paired-bootstrap analysis check. New intervals resample run-seed pairs, not individual time samples. See `results/holdout/REPORT.md` and the immutable held-out protocol for the evaluation scope.

For the upgraded main task, `validate_tracking_model` runs eleven core checks and seven tracking/information-access checks, including an end-to-end blackout reference-access test. It compares live Simulink with standalone telemetry over 32 seconds, through the pointing-fault onset. Results are saved in `results/tracking/validation.txt`. The main experiment has 108 matched trials and 45 separately labeled management ablations; the declared pilot gate is retained. The static-task and audit validation below remain separate evidence.

Validation was performed with installed MATLAB R2026a Update 2 on Windows. The automated outcome and measured experiment results are recorded in `results/RESULTS.md` and the saved CSV/MAT logs.

`run_tests` checks quaternion/geometry consistency, exact optical offset and attenuation identification from synthetic observations, honest uncertainty under darkness, causal initial packet delivery, immutable queued payloads, exact state serialization, repeatability and physical bounds, event transmission savings, blockage interrupting state transport, and pointing compensation improving physical link availability.

It also contains a regression test for fit invalidation: the ring buffer's count, write position, and samples must all reset. Eleven checks are expected after that correction.

The live Simulink smoke test and standalone/Simulink parity check use the generated model and its actual S-function. Telemetry is compared with the documented one-sample offset. Step-size sensitivity compares the integrated pointing scenario at 0.05 and 0.025 s; this checks numerical sensitivity of the selected case rather than proving convergence for all possible parameters.

The benchmark has five configurations, six scenarios, and three seeds. Seeds provide repeated channel noise/loss realizations under matched physical conditions; the rigid-body disturbance is deterministic. All saved percentages and curves originate from these new runs. Historical results from the earlier projects are not imported.

Limits: simulation checks do not establish formal closed-loop stability, fault-isolation completeness, real sensor performance, optical hardware feasibility, or a new research contribution. There is no hardware-in-the-loop test or orbit propagation. The reciprocal pilot and noiseless attitude sensors are simplifying assumptions.

`audit_recovery` adds 30 targeted trials (ten configurations, three seeds), separate from the 90 benchmark trials. It independently reconstructs optical power from logged geometry and terminal position, verifies the endpoint threshold rule and steering bounds, and includes counterexamples where the method must not claim sustained recovery. Exact results and onset timings are in `results/recovery_audit/REPORT.md`. All published benchmark logs and tables were regenerated after the history-reset fix.
