# Fixed metrics and identifiability audit

The original compute_metrics.m is used unchanged. Its hash is preserved in preserved_v1_manifest.json. All 64 saved proposed-method trials are independently recomputed and checked for exact equality before revised comparisons.

## Exact denominators
Evaluation samples: warmup <= t < T, i.e. [1,10) seconds at 20 ms = 450 samples per run. Diagnostics concern edge 1 only. Fault classes: 0 healthy, 1 boresight offset, 2 actuator gain, 3 actuator lag, 4 scalar optical loss, 5 blockage, 6 sensor bias, 7 uncertain, 8 combined offset/power.

Detection uses predicted != 0. Thus uncertain (7) is a detection, including a false positive during healthy samples. Precision = TP/(TP+FP), recall = TP/(TP+FN), false-alarm rate = FP/(FP+TN). Exact isolation divides exact label matches during true fault samples by all true fault samples; uncertainty gets zero credit. Uncertainty divides class-7 samples by all evaluation samples. Undefined ratios stay NaN.

Each sudden-fault trial has 300 fault samples and 150 healthy samples. Normal trials have 450 healthy samples and undefined isolation. The original 9.48% is the mean exact isolation across seven fault types; it is also the pooled ratio here because their exposures are equal. The old classifier could emit only 4 as a unique nonzero fault class. Power isolation was about 66.3%; dividing by seven yields about 9.48%.

Physical recovery is unchanged: an initial fault-window outage makes a run eligible; sustained 0.5 s availability must occur BEFORE scheduled clearance. Runs without an outage are NaN, not successes. Success percentage therefore conditions on an implementation-dependent outage cohort. Preventing sensor outages can reduce the eligible denominator and reduce this conditional percentage despite better service. Reports must show eligible/recovered/prevented counts, not hide this effect.

At nominal aligned power about 3.906 uW, pure power loss leaves 0.703 uW and combined loss leaves 1.367 uW, below 1.5 uW sensitivity. Pointing cannot repair these cases or blockage. Do not raise transmit power, lower sensitivity or move fault times to improve recovery statistics.

New post-clearance metrics are SUPPLEMENTARY: outage duration, false-alarm rate and a sustained-availability verification before run end. They do not replace original recovery. The diagnosis algorithm receives no clearance schedule.

## Why isolation was poor
- The old optical fit had no unique pointing, sensor, combined, gain or lag outputs.
- Its actuator threshold was proportional to maximum torque, far above much of the nominal excitation.
- One optical scan was permanently latched, overriding subsequent evidence.
- It applied offsets even when estimated aligned power could not reach sensitivity.
- Its claimed universal sensor/boresight ambiguity ignored available temporal information.

## Distinguishability with current measurements
|Classes|Observable evidence|Qualification|
|---|---|---|
|Boresight vs scalar optical loss|Bounded angular excitation identifies a log-power gradient and intercept|Requires non-dark power and adequate rank; no full posterior confidence claim|
|Sensor-bias changes vs boresight|Encoder angle minus integrated independent measured rate|Requires initially calibrated/healthy sensing and independent rate measurement; unknown initial constant biases remain confounded|
|Actuator gain vs lag|Delivered torque response to commanded torque over time|Requires informative history and reasonably accurate torque telemetry; estimates can be biased by sample/hold discretization|
|Combined offset and power loss|Both estimated gradient and attenuated aligned power|Only these modeled components; arbitrary multifault classification is not claimed|
|Blockage vs extinguished transmitter/deep attenuation|Not uniquely distinguishable with angle/rate/received power|Return uncertain, never force class 5|

The model's rate channel is independently measured angular rate plus noise, not a numerical derivative of the biased encoder. The revised observer exploits this EXISTING channel. It adds no privileged physical sensor or hidden truth. If real hardware derives rate from the same biased encoder, this distinction may fail. A dedicated test demonstrates the dependency.

## Revised method
Integrate rate with a trapezoidal update and compare encoder angle to the kinematic estimate. Fit actuator gain/time constant from finite-window torque dynamics with rank/residual checks. Use bounded coordinate probes only when an optical model residual calls for discrimination; stop when the optical regression is informative. Predict current received power continuously. Contradictory evidence invalidates an optical fit, rolls back its correction and enters a verification/cooldown state. Do not apply a correction whose estimated best-case aligned power cannot sustain service.

Model values, topology, schedules, seeds, receiver sensitivity, actuator limits and traffic remain unchanged. Simulink continuously integrates all physical terminals. Only the supervisor and estimator logging differ in separately saved V2 model copies; originals are never saved over.
