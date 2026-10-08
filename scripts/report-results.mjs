import {readFileSync,writeFileSync,readdirSync} from 'node:fs';import {createHash} from 'node:crypto';
const get=n=>JSON.parse(readFileSync('results/'+n+'.json')),fmt=(v,d=4)=>v===null?'—':Number(v).toFixed(d);
const modes=['baseline-time','baseline-event','baseline-self'],base=modes.map(mode=>({mode,...get(mode)})),opt=get('optimization'),mc=get('monte-carlo'),ex=get('experiments'),ab=get('ablation'),refine=get('step-refinement');
const table=rows=>'| Method | Attitude RMSE | ω RMSE | Updates | Attempts | Saved % | Effort N²m²s | Settling s | Recovery s | Success |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---|\n'+rows.map(r=>{let m=r.metrics;return `| ${r.mode??r.label} | ${fmt(m.attitudeRMSE)} | ${fmt(m.angularVelocityRMSE)} | ${m.controllerUpdates} | ${m.communicationEvents} | ${fmt(m.communicationSaved,1)} | ${fmt(m.controlEffort)} | ${fmt(m.convergenceTime,2)} | ${fmt(m.faultRecoveryTime,2)} | ${m.success?'PASS':'FAIL'} |`;}).join('\n');
let text=`# Results and engineering report

Generated from saved simulation JSON. All numbers below are measured by the new shared engine, not copied from the reference paper. Experiments are finite-horizon numerical evidence, not a stability or flight qualification claim.

## A. What existed before

Four-spacecraft MATLAB/Simulink attitude dynamics, three control policies, fourteen output plots, and a self-contained educational browser visualization. Browser/MATLAB trigger and integration semantics differed; the MATLAB Eq.26 implementation also differs from the PDF. All 29 original artifacts are preserved and hash-checked.

## B. What was added

Shared worker/Node simulation engine; strict locked baseline port; configurable faults; model-based torque residual diagnosis; adaptive scheduling and bounded effectiveness compensation; fault-aware self scheduling; attempted/delivered/dropped/budget-denied communication; NSGA-II; paired Monte Carlo; ablation and dt sensitivity; mission dashboard, comparison page, event replay, exports and a three-minute demonstration. Separate native MATLAB extension and Simulink builder are provided but unexecuted here.

## C. Mathematical changes

Baseline equations remain unchanged. Proposed policies scale the squared-error threshold using coordination/tracking errors, residual severity, nuisance torque and communication pressure; cap hold time; clamp chi; optionally divide commanded torque by bounded estimated effectiveness. Self prediction rescales the repository interval. No inherited theorem is asserted. See [model](mathematical_model.md) and [proposed policy](proposed_method.md).

## D. Algorithmic contribution

An empirically evaluated fault/communication-aware scheduling and diagnosis integration with reproducible experiments. Event-triggered fault-tolerant control itself belongs to the baseline literature. Literature-wide novelty is not established; see [novelty analysis](novelty_analysis.md).

## E. Optimization

${opt.method}. ${opt.evaluations} evaluated candidates, two training seeds ${opt.trainingSeeds.join(', ')}, random seed ${opt.seed}. Normalized training objective: original **${fmt(opt.original.objective,6)}**, selected **${fmt(opt.best.objective,6)}** (${fmt(100*(1-opt.best.objective/opt.original.objective),2)}% lower). This is a training score, not a held-out improvement guarantee. [Algorithm source](https://doi.org/10.1109/4235.996017).

Best parameters:

\`\`\`json
${JSON.stringify(opt.best.params,null,2)}
\`\`\`

## F. Experimental results

### Strict repository baseline port, 60 s at 1 ms

${table(base)}

The self-triggered baseline has negative savings. Its 3,202 updates are deliberately retained; no result was tuned to match the paper's table. These are deterministic port outputs pending independent MATLAB validation.

### Combined fault + 20% loss + 3× disturbance, seed 42, 60 s at 10 ms, budget 500

${table(ex.rows.filter(r=>r.scenario==='combined'))}

Savings use an unlimited 10 Hz denominator. All six methods receive the same capped mission channel. Baseline time and self reach the budget cap; local updates continue. Read accuracy, effort, budget and recovery together.

### Paired Monte Carlo, 100 scenarios and 500 runs

| Policy | Success | Mean RMSE | Median RMSE | P95 RMSE | Best RMSE | Worst RMSE | Recovery censored |
|---|---:|---:|---:|---:|---:|---:|---:|
${Object.entries(mc.summary).map(([m,s])=>`| ${m} | ${fmt(100*s.successRate,0)}% | ${fmt(s.attitudeRMSE.mean)} | ${fmt(s.attitudeRMSE.median)} | ${fmt(s.attitudeRMSE.p95)} | ${fmt(s.attitudeRMSE.best)} | ${fmt(s.attitudeRMSE.worst)} | ${s.faultRecoveryTime.censored}/100 |`).join('\n')}

The optimized and time-driven policies both pass all 100 sampled environments. This does not establish 100% operational reliability. Adaptive scheduling improves success relative to event-triggering in this sample but does not dominate time-driven tracking. Distribution assumptions and censoring are documented in [Monte Carlo protocol](monte_carlo.md).

### Ablation

${table(ab)}

Fault severity, communication pressure, tuning and compensation do not uniformly improve every cost. In this mission full compensation adds broadcasts and effort relative to E, while improving recovery modestly. B/C/D are package additions, not perfectly isolated causal interventions.

### Step sensitivity

| Method | dt s | RMSE | Attempts | Success |
|---|---:|---:|---:|---|
${refine.map(r=>`| ${r.mode} | ${r.dt} | ${fmt(r.metrics.attitudeRMSE,6)} | ${r.metrics.communicationEvents} | ${r.metrics.success} |`).join('\n')}

Stochastic sample paths change with dt. This is sensitivity evidence, not a pure deterministic convergence study.

### Figures

![Combined mission](../results/plots/combined-history.png)
![Monte Carlo](../results/plots/monte-carlo.png)
![Pareto](../results/plots/pareto.png)
![Ablation](../results/plots/ablation.png)
![Optimization](../results/plots/optimization.png)

### Full deterministic matrix

${['nominal','degradation','failure','multiple','dropout','disturbance','noise','combined'].map(s=>'#### '+s+'\n\n'+table(ex.rows.filter(r=>r.scenario===s))).join('\n\n')}

## G. UI/UX changes

Mission-control layout, 3D projected schematic vehicles with true simulated orientation, mouse/keyboard camera controls, selectable vehicle telemetry, real diagnosis evidence, update explanations, replay timeline, eight analysis tabs, loss/budget accounting, hardware cost profiles, comparison charts and JSON/CSV/PNG/print exports. The demo schedules faults but never schedules fictional detection or success. Scientific plots also export to SVG.

## H. Testing

Numerical suite: 24 tests passed at report generation, including three full 60 s baseline regressions, kinematics, plant, saturation, directed coordination, controller, self scheduling, adaptive response, fault profiles, excited-axis diagnosis, determinism, budget/dropout semantics, objective, nondominated sorting, seeded optimizer and censoring statistics. Original artifact integrity: 29/29 hashes preserved. Browser desktop/mobile smoke checks reported no JavaScript errors and no mobile page overflow. MATLAB/Simulink execution and HIL were unavailable and are not counted as passed.

## I. Limitations

No translational/orbital formation, global MRP chart handling, formal adaptive stability proof, calibrated probabilistic diagnosis, characterized hardware costs, or operational reliability inference. Optimization is small and training-scenario dependent. MATLAB extension and cross-runtime baseline parity remain unverified. See [complete limitations](limitations.md).

## J. Recommended future research

Independently validate with MATLAB/Simulink; calibrate detection delays and false alarms under sensor/inertia uncertainty; derive stability conditions with saturation and packet loss; model wheels and link delays; isolate adaptation channels; expand to 500 held-out environments per method; test real embedded execution and compare against additional published schedulers.
`;
writeFileSync('docs/RESULTS.md',text);
const files=['src/engine.mjs','src/math.mjs','src/scenarios.mjs','src/diagnosis.mjs','src/policies.mjs','src/research.mjs','scripts/experiments.mjs'];const hashes=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(readFileSync(p)).digest('hex')]));writeFileSync('results/provenance.json',JSON.stringify({generatedAt:new Date().toISOString(),node:process.version,platform:process.platform,arch:process.arch,sourceHashes:hashes,baseline:'repository MATLAB port; independent execution pending',campaign:{scenarios:100,runs:500,dt:.01,seed:2026},optimizer:{seed:71,trainingSeeds:[101,102],evaluations:48}},null,2));console.log('Wrote RESULTS.md and provenance.json');
const metricKeys=Object.keys(ex.rows[0].metrics);
writeFileSync('results/experiment-matrix.csv',['scenario,mode,'+metricKeys.join(','),...ex.rows.map(r=>[r.scenario,r.mode,...metricKeys.map(k=>r.metrics[k]??'')].join(','))].join('\n')+'\n');
writeFileSync('results/baseline-benchmark.csv',['mode,'+metricKeys.join(','),...base.map(r=>[r.mode,...metricKeys.map(k=>r.metrics[k]??'')].join(','))].join('\n')+'\n');
