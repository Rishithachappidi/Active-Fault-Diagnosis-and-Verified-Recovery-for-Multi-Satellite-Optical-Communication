# Reproducible parameter optimization

Primary method: NSGA-II style elitist nondominated sorting with crowding distance, binary tournament selection, simulated binary crossover (eta=10), and bounded Gaussian mutation (probability 1/dimension, standard deviation 10% of each bound). Gaussian mutation differs from the canonical polynomial mutation; the implementation does not claim a bit-for-bit reference algorithm. Reference: [Deb et al., 2002](https://doi.org/10.1109/4235.996017).

The search evaluates a population of 12 plus three offspring generations: 48 candidate parameter sets × two independent training environments, seeds 101 and 102. Seed 71 controls optimizer randomness. Original parameters are always included. Each candidate uses identical training conditions. The default run is 60 s, dt=0.01 s, 500 attempted broadcasts per spacecraft. This deliberately small search is an executable exploratory experiment, not evidence of global optimality.

Parameters: r [0.3,1], gainScale [0.65,1.4], delta [0.08,0.5], log10(epsilon) [−5,−3], beta1 [3,8], beta2 [6,14], gamma [0.2,0.8], errorWeight [1,8], faultWeight [1,6], commWeight [0.2,3], maxInterval [0.2,1.5]. k1 follows the parameterized gain equation; k2 follows k0/delta/degree. They are not independently optimized in ways that masquerade as satisfying the original gain theorem. The theorem is not asserted for any new schedule.

Each objective component is normalized by a fixed scale chosen before tuning:

| Component | Scale for 60 s |
|---|---:|
| Attitude RMSE | 0.15 MRP |
| Attempted broadcasts | 2,400 |
| Torque-squared effort | 10 N²m²s |
| Modeled computation | 40,000,000 operation units |
| Recovery time | 60 s |

Recovery null maps to the mission duration (not zero). Weights default [4,2,1,1,2] and are adjustable. J = sum(weight_j × normalized cost_j)/sum(weights) + penalty. Terminal failure adds 2; numerical divergence adds 100. Nondominated ranking uses the five mean normalized costs with the same penalty added to each. Weighted J selects the best evaluated candidate from the archive, not necessarily the best held-out mission policy.

Training and campaign seeds are disjoint. `results/optimization.json` saves method, seed, bounds through source version, scales, weights, original score, best parameters, all candidate scores and nondominated candidates. Every returned best parameter set is directly reusable in the UI. Validation shows modest training improvement, and ablation also shows worse tracking in some cases. Do not describe the optimized controller as uniformly superior.
