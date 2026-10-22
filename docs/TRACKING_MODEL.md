# Moving-reference task and diagnosis-informed management

## Information pattern

Only SC1's feedback path calls `isc_reference`. Its small sinusoidal rotation vector becomes a quaternion; angular rate comes from a short quaternion increment. Desired spacecraft attitude is `q_ref(t) * offset_i`. Followers never call the live reference generator in feedback. Reference phase is read only by the leader branch and offline scoring.

The parent map is `[0,1,2,3]`. Bidirectional state packets use SC1–SC2, SC2–SC3, SC3–SC4. Parent targets use forward messages; reverse traffic represents symmetric state sharing and counts toward overhead. Other physical terminals continue local pilot/pointing dynamics without state scheduling. No alternate-route forwarding is implemented.

Follower i with parent j uses `q_d,i = predicted_q_j * conj(offset_j) * offset_i`. Parent angular rate is transformed through the offset rotation. Constant-rate propagation stops after a bounded horizon, after which attitude is held and desired feedforward rate is zero. Without any received parent history, a follower holds its stored initial attitude. Local stabilization remains available while an unknown leader maneuver becomes untrackable.

The feedback structure is retained: quaternion error, rate-error damping, smooth sliding term, bounded disturbance observer, gyro compensation, and unchanged torque gains/limits. The target/rate source changes. This tracking branch does not also use the old all-neighbor consensus sum. It is a new leader-following task, not the reference paper's controller reproduction.

## Declared task parameters

Reference rotation vector: `[.018 sin(.11t+p), .012 sin(.07t+.4+p), .010 sin(.09t-.2+p)]` rad. It is not sent as an oracle packet; followers infer motion indirectly from actual parents. Relative offset vectors are columns of `[0 .004 -.003 .002; 0 -.002 .003 .001; 0 .002 .001 -.003]` rad.

Runs last 75 s, fault interval [25,60) s, step 0.05 s. Every moving-task mode uses a 0.06 s terminal servo. This is an explicit task-specific setting, declared before rankings were inspected, rather than a claim that static and moving-task results are directly interchangeable. Other plant/controller/optical/delay settings retain `isc_config` values. No formal convergence proof follows.

## Diagnosis to communication management

`isc_link_management` receives local measured pilot power, fitted offset/gain/validity, nominal aligned power, beam width, correction limit, and service threshold. It receives neither injected faults/times nor the true `up` flag.

Remaining offset after maximum correction is estimated as `max(norm(offset_hat)-maxCorrection,0)`. Predicted best power is nominal power times fitted gain times Gaussian loss at that residual. Feasibility requires 10% margin. This ignores fit uncertainty and servo/transient limits; it is an indicator, not a guaranteed recovery-time forecast.

States: 0 observed power at least 1.2 times service threshold; 1 degraded with uncertain fit; 2 degraded with estimated feasible correction; 3 degraded with estimated insufficient best power. Severity is clipped `1-observed_power/nominal_power`. A compensated link may return to state 0 while its boresight fault persists.

Scheduling policy changes per-endpoint maximum silence to 0.2 s in states 1/2, 1.6 s in state 3, baseline 0.8 s in state 0. State 3 throttles retries even during changing local motion. Diagnostic pilots continue. No failed channel is bypassed.

Prediction policy uses the follower's own reciprocal endpoint assessment of its parent session. States 1/2 extend its constant-rate horizon from 1.5 to 3 s; other states use 1.5 s. This assumes reciprocal pilot information is relevant to the bidirectional session; asymmetric faults are not validated. Prediction can become worse during acceleration. Scheduling-only, prediction-only, and joint policies are separate ablations, with policy off as the default.

## Metrics

Offline scoring forms `common_i = q_i * conj(offset_i)`. Pair error is `norm(Log(conj(common_i)*common_j))` for all six pairs, an exact quaternion-geodesic de-offset formation error. Leader-relative error compares followers with actual `common_1`. Command tracking compares `q_i` with `q_ref*offset_i`. Scoring truth never enters follower feedback.

Windows are evaluation [10,75), fault [25,60), post-clearance [60,75). RMS takes the square root after averaging squared angular norms across the relevant times/pairs/spacecraft. Principal metrics are fault-window pair RMS and tracking RMS, with follower-only and leader-relative scores retained. These do not mix the fault response with a much larger initial maneuver.

Torque-squared effort is not electrical energy. A directed state payload contains eight doubles: quaternion, angular rate, timestamp = 64 bytes per attempt. Queue metadata, packet headers, pilots, acknowledgments, terminal energy, and processing cost are excluded. Parent age is conditional on initialized caches; uninitialized fraction is also reported. Fitted-offset error is conditional on accepted fits and accompanied by fit fraction; it is not unconditional fault-isolation accuracy.

## Fault interactions

All eight factorial cells use identical pointing offset P, actuator-effectiveness A, and attenuation gain T=0.65. Gain 0.12 is a ninth severe control. Per-mode/per-seed P×A and P×A×T contrasts use the declared scalar metric scales. Their mean/sample SD are descriptive with n=3. A nonzero contrast does not itself identify a unique physical mechanism; inspect terminal residual/power, motion, effort, and saturation traces.

Moderate attenuation need not interrupt communication. Actuator degradation need not saturate a low-demand maneuver. Ideal communication can coexist with actuator-induced error. Those outcomes are retained rather than tuned away.
