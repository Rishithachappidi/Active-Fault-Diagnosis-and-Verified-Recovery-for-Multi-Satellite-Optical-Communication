# Mathematical model, causality, and assumptions

This document specifies the retained base/static task and shared physical kernel. The current moving-reference demonstration uses the reference-information pattern and metrics in [TRACKING_MODEL.md](TRACKING_MODEL.md); it does not give every follower the live absolute command described in the earlier task below. Terminal reaction torques on the spacecraft body are not modeled.

## Coordinates and physical layout

Four spacecraft are held at the corners of a 1 km square in a fixed inertial plane. Translational motion and orbital dynamics are outside this first version. Each spacecraft has three independent two-axis optical terminal mounts, nominally aligned with its neighbors. There are six bidirectional sessions and twelve directed packet channels. No body is required to point simultaneously in three different directions: independently mounted terminals provide those directions.

`q_i` is a unit scalar-first Hamilton quaternion mapping body vectors to inertial vectors; `omega_i` is body angular rate. The reference is the identity quaternion for all spacecraft. `isc_math` supplies quaternion exponential/logarithm, multiplication, and rotation matrices. State propagation normalizes the quaternion every step.

## Rigid-body plant

\[
J\dot\omega_i=\operatorname{diag}(\eta_i)u_i+d_i-\omega_i\times J\omega_i,
\qquad
\dot q_i=\tfrac12 q_i\otimes[0;\omega_i].
\]

`J = diag(0.030,0.025,0.020)` kg m². Each torque axis is limited to ±0.002 N m. A small deterministic sinusoidal external torque acts on all spacecraft. These are illustrative small-spacecraft parameters, not the first project's ±0.2 N m case. Angular velocity uses explicit midpoint integration; quaternion updates use the midpoint angular rate and an exponential increment. The default step is 0.05 s; a smaller-step comparison is provided in validation.

## Attitude feedback

The controller uses the local rotation-vector attitude error, angular rate, a weighted sum of received relative-attitude errors expressed in local body axes, and a bounded disturbance estimate:

\[
u_i=\operatorname{sat}\left[-k_p(e_i+\kappa\sum_j w_{ij}e_{ij})
-k_d\omega_i-k_s\tanh((\omega_i+\lambda e_i)/\phi)
-\hat d_i+\omega_i\times J\omega_i\right].
\]

The bounded low-pass disturbance estimate uses the difference between measured angular acceleration and nominal torque response. It compensates aggregate disturbance/model mismatch; it does not identify an actuator fault type or read actuator-effectiveness truth. Differentiated rate is idealized here because local attitude/rate sensing is noiseless. Hardware use would require a noise-robust observer and sensor model.

Packets contain the sending spacecraft's attitude, angular rate, and sampling timestamp. A receiver predicts attitude with constant angular rate, for at most 1.5 s. After that, the cached state continues to age and its coupling weight decays exponentially. A receiver with no prior packet from a neighbor omits that neighbor; it does not access the true simulated neighbor state. All spacecraft also use a known absolute reference, providing local stabilization during communication outages.

## Terminal geometry and dynamics

For directed endpoint `a`, the known inertial line of sight is transformed through the sender's measured body attitude. A mount-fixed basis converts it into azimuth/elevation targets. The terminal actuator tracks that target plus any diagnostic dither and estimated boresight correction, with a 0.12 s first-order response, ±0.10 rad travel, and 0.035 rad/s rate limit.

The observed residual `x_a` is the terminal encoder angle minus the geometry/attitude-derived target. A hidden injected boresight offset `b_a` acts only in the optical plant. The local angular approximation `x_a+b_a` is used in the Gaussian beam model. It is appropriate for small residual errors; it is not a full diffraction or telescope ray-tracing model.

\[
P_a=P_{0,a}g_a\exp[-2\|x_a+b_a\|^2/\alpha^2],
\quad P_{0,a}=10^{-6}(1000/r_a)^2\ \mathrm W.
\]

`alpha = 300 microrad`; required power is `0.20 microW`. Blockage sets power to zero. A session is available only when both paired endpoint channels exceed threshold. Power uses distance scaling and a normalized Gaussian model; aperture sizes, wavelength, detailed receiver noise/BER, atmospheric effects, Doppler, light-time pointing, and data-rate adaptation are not modeled. Propagation time at 1 km is negligible compared with the deliberately imposed communication-stack delays.

The terminal observer receives a local reciprocal acquisition/tracking pilot measurement responding to its own alignment, plus local encoder/attitude observations. This assumes a suitable reciprocal pilot sensor is available even when state packets fail. It carries **no neighbor attitude or state payload**. Pilot acquisition, pilot bandwidth/latency, and transmit/receive cross-coupling are idealized. This explicit assumption makes local alignment estimation possible without feeding the state controller a hidden communication bypass. A more detailed bidirectional telescope model should replace it before hardware claims.

## Optical diagnosis and correction

For the local pilot, normalized log power yields a linear regression:

\[
z=\log(P/P_0)+2\|x\|^2/\alpha^2
=\beta_0+\beta_x x_1/\alpha+\beta_y x_2/\alpha.
\]

\[
\hat b=-\alpha[\beta_x;\beta_y]/4,
\qquad \hat g=\exp(\beta_0+2\|\hat b\|^2/\alpha^2).
\]

Recovery-enabled terminals use a bounded four-direction dither (48 microrad, 0.4 s per direction) for persistent excitation. A two-second rolling history is fit every 0.2 s; rank, residual, offset, and gain checks gate acceptance. Dither runs continuously, including healthy operation, and thus has a real pointing cost. Pilot/dither electrical energy is not included in the torque-effort metric. Invalidation clears the full history, count, and write position, so a partial new history cannot include samples collected before the reset.

The applied correction is `-estimated_offset`, limited to 450 microrad, and withheld if the estimated best aligned power is insufficient. A fit inconsistent with current pilot measurements on three decision checks is invalidated, its history is restarted, and stale correction is removed. No fault start/end times are passed to this supervisor.

Labels are 0 healthy fit, 1 pointing offset, 2 attenuation, 3 dark/uncertain/insufficient fit, and 4 combined offset/attenuation. A dark channel is never asserted to be proven blockage. No sensor-bias classifier, actuator-class classifier, complete acquisition search, optical-power actuator, or alternate-route forwarding is claimed in this version. Redundant direct links in the complete graph can still carry their own state packets.

## Packet transport and scheduling

At each time step: measure optical power; deliver due packets if the session remains available; decide whether to send; compute control from delivered caches; advance the physical plant. Optical observations precede that step's terminal actuator update. Thus terminal correction cannot instantly change the measured power that triggered it.

Impaired transport adds 0.10–0.20 s of delay, rounded upward to the simulation grid, and 2% independent random loss. The bidirectional session must be available at both enqueue and delivery. Each directed edge has 32 queue slots; overflow is counted and tested to remain zero. Payloads retain their sampled values even as the source spacecraft moves. Arrival timestamps must be newer than the cached timestamp; out-of-order stale packets cannot overwrite newer information.

Periodic messaging occurs every 0.2 s. Event messaging compares the actual local attitude/rate with constant-rate extrapolation of the last broadcast state. It sends when the angle innovation exceeds 150 microrad or rate innovation exceeds 100 microrad/s, subject to a 0.1 s minimum and 0.8 s maximum silence. This is a predictive event-based transmission rule, not a dynamic event-trigger theorem or a self-triggered controller. Feedback torque is computed every 0.05 s in all configurations. Transmission scheduling and torque-update scheduling are distinct.

An attempted directed packet counts once per neighbor. One spacecraft broadcast therefore contributes three directed attempts. The ideal reference uses one sample of delivery latency for causality and has no optical gating or random loss. Packets still pending at simulation termination are attempts without a delivery in that trial.

## Fault scenarios

Fault windows are `[25,60)` s. Edge SC1–SC2 is the affected optical session. Pointing injects `[255;-120]` microrad at both endpoints. Attenuation sets both gains to 0.12 (below service threshold even at perfect alignment). Blockage forces their power to zero. Body-actuator degradation scales SC2's three torque axes by `[0.35;0.50;0.40]`. Combined uses that actuator fault, the pointing offset, and endpoint optical gain 0.65. Diagnosis/control do not receive these parameters.

## Metrics and their denominators

- Attitude RMS: square root of the mean squared rotation-vector norm over all four satellites and `10 <= t < 90` s. Final RMS uses the last ten seconds.
- Fault peak: largest individual satellite attitude error during `25 <= t < 60` s.
- Link availability: up endpoint-channel samples divided by all 12 endpoint-channel samples in the evaluation window. Paired endpoints share session availability, so this also equals the six-session fraction.
- Affected availability: up samples of the two SC1–SC2 endpoints during the fault window, divided by the number of such samples.
- Delivery ratio: delivered directed packets divided by attempted directed packets over the entire run.
- Control effort: `sum(u.^2)*dt`, in N² m² s. It is not electrical energy in joules.
- Information age: mean age of initialized off-diagonal caches in the evaluation window. Never-received caches are excluded from this conditional mean; it should not be treated as a measure of network connectivity.
- Recovery: first continuous one-second period of affected-session availability **after an observed outage and before the fault clears**. Duration is measured from the first outage to the end of that verification hold. If no outage occurs, recovery is not applicable (`NaN`); unrecovered outages have flag 0 and `NaN` duration.

Fault truth is used only for injection and metric windows. We do not report an optical diagnosis accuracy percentage: label 3 includes uncertainty and startup/insufficient excitation, and actuator truth is not the same label space. Independent trials are the seeded runs, not individual time samples. With three seeds, standard deviations are exploratory and are not strong population confidence statements.

## Simulink execution

`isc_sfunction` is a Level-2 discrete MATLAB S-function executing the same `isc_step` used by the standalone simulation. Numeric queues, histories, and plant/controller states reside in DWork. Top-level telemetry is delayed one sample because the discrete Update method stores the next output. At Simulink time `t+dt`, telemetry corresponds to standalone time `t`. The first Simulink sample is zero initialization. No `.mat` result file is read by the live model.

The 120-value telemetry vector contains four nine-value spacecraft groups (attitude log, angular rate, commanded torque), 12 powers, 12 session flags, 24 correction components, 12 diagnosis labels, 16 cache ages, four per-step attempted counts, and four per-step delivered counts. There is no external live control input port; parameters are selected in the model workspace. The model requires normal simulation and MATLAB S-functions; generated embedded code and accelerator execution are not validated.

## Recovery audit: interpretation of apparent fast recovery

The `correction` log is the new supervisor command at the current time. `gimbal`, `residual`, and `power` are the actual physical values sampled before that new command advances the terminal actuator. A sharp command change does not mean an instantaneous physical correction. The audit zoom plot separates those signals.

The raw `up` flag is an ideal power-qualified bidirectional session: both endpoint powers exceed the threshold at that sample. It has no acquisition state machine, hysteresis, detection noise, lock timer, or frame/BER decoding model. The one-second recovery hold is a scoring rule and does not alter raw packet transport eligibility. Consequently, raw availability and verified recovery are different quantities.

Two optional experiment-only fields challenge the matched-model assumption: `pointingFaultScale` scales hidden boresight injection, and `plantDivergenceScale` changes the optical plant's true beam width while leaving the estimator's nominal width unchanged. Neither field enters the diagnosis or controller API. Audit-only truth fields are logged for independent reconstruction, never consumed by feedback. The audit also removes dither, constrains correction, slows the actuator, increases pilot noise, and tests unrecoverable attenuation/blockage.

Recovery onset power is not instantaneous service evidence: it must follow a measured outage, persist for the configured one-second scoring hold, and occur before fault clearance. Finite authority, missing excitation, or a dark out-of-capture-range pilot can prevent recovery. The model has no broad acquisition scan capable of recovering every dark initial condition.
