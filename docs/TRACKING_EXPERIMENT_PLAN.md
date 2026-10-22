# Communication-dependent coordination experiment: declared design

This protocol is recorded before inspecting tracking results. The existing static-reference benchmark remains available. This extension changes the task/reference information pattern, retaining the rigid-body plant, optical diagnosis, torque bounds, disturbance observer, and local feedback structure. It does not implement the original research paper's self-triggered method.

## H1: communication has a measurable coordination effect

Only SC1 receives the time-varying attitude command. Followers 2, 3, 4 obtain their targets from timestamped parent-state messages along the fixed logical chain 1–2–3–4. Known constant attitude offsets define the formation. No follower calls the global reference generator in its control path. With no packet history a follower holds its initial orientation; an aged parent packet is propagated for a bounded interval and then held with zero feedforward rate. This preserves local stabilization but cannot reproduce an unknown leader maneuver indefinitely.

All four main configurations use the same logical topology: ideal periodic transport, impaired periodic transport without optical recovery, impaired periodic transport with recovery, and impaired event transport with recovery. Direct physical terminals outside the chain are not scheduled as an alternate communication route. This is an explicitly sparse command-distribution architecture, not a claim that every network topology requires the failed edge.

The experiment also includes a communication blackout negative control and a reference-access unit test. Healthy and actuator-only cases expose tracking differences unrelated to the optical fault. No gains or fault strengths will be selected after looking at performance rankings.

## H2: a diagnosis-informed management policy addresses an observed limitation

First compare ideal, unrecovered, recovered periodic, and recovered event transport for the pointing case. The management experiment proceeds if unrecovered optical loss increases follower tracking or pairwise formation error over ideal transport, or recovered event transport has a measurable command-information interruption. If that condition is absent, management is recorded as unnecessary for this task rather than claimed as a benefit.

Candidate policy uses only the endpoint's pilot power, fitted offset/gain/validity, nominal beam law, and correction limit. It estimates the best power achievable with remaining uncompensated offset. It classifies locally healthy, degraded/uncertain, estimated recoverable, or estimated infeasible. During a degraded/uncertain or estimated recoverable interval, an optional scheduling policy lowers maximum message silence from 0.8 to 0.2 s, and an optional receiver policy raises constant-rate extrapolation horizon from 1.5 to 3.0 s. Estimated infeasibility lengthens the scheduling retry interval to 1.6 s. A healthy observed power margin restores baseline policy immediately. These are heuristic hypotheses, not optimal rules or uncertainty guarantees.

Compare recovery/event transport with management off, scheduling only, prediction only, and both. Report whether extra attempts buy any coordination benefit; do not label more transmissions as an improvement by themselves. Constant-rate prediction can be wrong during a changing maneuver. Feasibility is an estimate, not knowledge of the injected fault. Policy changes do not use the true link-up flag or injected severity.

## H3: isolate fault interactions

Use a full 2×2×2 factorial design with fixed component magnitudes: optical pointing offset P, SC2 actuator degradation A, and optical attenuation T (gain 0.65). Include all eight subsets: none, P, A, T, P+A, P+T, A+T, P+A+T. Also retain severe attenuation (gain 0.12) as a separate unrecoverable control. The severe case is not substituted into a factorial interaction calculation.

The user-facing A–F narrative uses healthy, pointing, actuator, severe attenuation, pointing+actuator, and the three-factor combination; the two-factor attenuation cases and moderate attenuation provide the additional cells needed for interpretable interactions. Report the full scenario mapping.

Use paired seeds 11, 23, 47, a 75 s run, fault interval [25,60) s, step 0.05 s, and fixed reference/offset/gain settings. Full main benchmark: 9 scenarios × 4 modes × 3 seeds = 108 runs. Conditional management study: five scenarios (healthy, pointing, pointing+actuator, combined, severe attenuation) × three additional policies × three seeds = 45 runs. The manager-off comparison is reused from the main benchmark. Seeds represent channel randomness, not independently sampled plants.

## Metrics and interactions

Score exact quaternion-geodesic tracking error against the commanded formation, error relative to the actual leader, and pairwise formation disagreement for all six pairs and the three logical edges. Evaluate all-run/post-transient, fault-window, and post-clearance windows separately. Report torque-squared effort, saturation, directed attempts/deliveries, payload overhead, parent-information age, failed-link availability, sustained recovery, and manager-state occupancy.

For any fault-window scalar metric Y, report paired-seed P×A interaction `Y(PA)-Y(P)-Y(A)+Y(healthy)`. For all three factors, report `Y(PAT)-Y(PA)-Y(PT)-Y(AT)+Y(P)+Y(A)+Y(T)-Y(healthy)`. Positive interaction in an error metric means a larger error than additive component effects on that chosen scale, not proof of a unique causal mechanism. No significance claim is made from three seeds. Inspect physical pointing/power and motion curves before attributing a nonzero interaction.

Predeclared parameters: rotation-vector reference amplitudes [0.018,0.012,0.010] rad with frequencies [0.11,0.07,0.09] rad/s; relative offsets specified in `isc_tracking_config`. A 0.06 s terminal servo is used for this moving-reference task in every mode; this is an explicit task-specific parameter, not an outcome-based gain adjustment. The original static task retains its 0.12 s servo. Local feedback gains are unchanged.

Acceptance is transparency and causal correctness, not a required ranking: no hidden reference access, immutable causal packets, torque/terminal bounds, reproducible trials, exact metric definitions, and complete reporting of success, failure, or lack of policy benefit.
