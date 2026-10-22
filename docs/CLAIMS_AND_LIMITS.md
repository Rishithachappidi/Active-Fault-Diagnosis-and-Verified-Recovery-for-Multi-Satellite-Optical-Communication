# Engineering evidence, statistical scope, and novelty

## Optical diagnosis and recovery

The project estimates pointing offset and optical gain from local pilot observations under a specified Gaussian optical model. It tests whether bounded pointing correction can restore power-qualified communication. A fitted model, accepted-fit fraction, or conditional offset error is not a confusion matrix or general classification accuracy.

Severe attenuation can make the maximum aligned power lower than the service threshold. Steering cannot create the missing optical power. Failed restoration in that condition is compatible with the physical model; it must be distinguished from an incorrect estimate or controller defect. The fit validation and beam-calibration limitations remain reported.

## Coordination and communication

The moving-reference task restricts the command to the leader. Followers need delivered parent messages to track it while preserving relative-attitude targets. Measured communication effects apply to the declared topology, command, plant, gains, and fault conditions. No alternate-route forwarding or universal network-connectivity result is claimed.

Event scheduling can reduce attempted state payloads while increasing tracking error or effort. Payload bytes do not include all optical-system energy, pilot bandwidth, or protocol overhead. The original scheduling-only policy's adverse outcomes remain in the development report. The new frozen policy is a candidate evaluated independently; it is not presumed superior.

## Statistical claims

Development used three channel seeds. The held-out study uses 20 new independent run seeds with randomized initial attitudes/rates, command phase, disturbance phases/amplitudes, and channel realizations. The same seed is paired across configurations. Multiple cases reuse that seed's exogenous draw, so 440 simulated runs do not represent 440 independent environmental samples.

Bootstrap intervals resample the 20 run-seed units within each case/contrast. They do not resample individual time samples as if independent. They are pointwise exploratory intervals without multiplicity adjustment. They describe the explicitly sampled distribution and finite case matrix, not all disturbances, initial states, faults, or communication topologies. A narrow interval establishes precision for that estimate under those assumptions, not universal robustness.

The source/protocol lock is a local reproducibility mechanism established before held-out evaluation. It is not an external/public preregistration. The frozen-policy rule and analysis are not retuned after reading held-out outcomes.

## Algorithmic novelty

The implementation provides an engineering integration and a reproducible empirical testbed. Useful measured interactions do not establish algorithmic novelty. The event scheduler is the documented project heuristic; the exact self-triggered controller from the original attitude-coordination research is not implemented or claimed.

A novelty claim would require a precise new method and a justified distinction from existing methods, appropriate stability/error/trigger analysis, and fair comparisons against identifiable published baselines. This project does not silently substitute its experimental architecture or additional features for those requirements.

## Remaining model limits

Optical acquisition/relock logic, realistic sensor and additive receiver noise, delayed/asymmetric pilot sensing, orbit propagation, terminal reaction torques, hardware calibration, and flight validation are outside the present implementation. The tested actuator degradation did not force torque saturation in the original development matrix. Mission-specific performance tolerances have not been supplied, so the reports provide errors and tradeoffs rather than claiming mission acceptance.

See the [held-out protocol](HELDOUT_PROTOCOL.md), [held-out results](../results/holdout/REPORT.md), [development results](../results/tracking/REPORT.md), and [optical recovery audit](../results/recovery_audit/REPORT.md).
