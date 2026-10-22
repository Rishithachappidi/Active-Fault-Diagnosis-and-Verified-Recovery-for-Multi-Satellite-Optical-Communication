from pathlib import Path
import csv,statistics,math
root=Path(__file__).resolve().parents[1]
out=root/'results/tracking'
rows=list(csv.DictReader((out/'all_trials.csv').open(newline='',encoding='utf-8-sig')))
assert len(rows)==153
assert all(float(r['queue_overflows'])==0 for r in rows)
assert max(float(r['quaternion_norm_error']) for r in rows)<1e-12
modes=['ideal_periodic','optical_periodic_no_recovery','optical_periodic','optical_event']
scenarios=['healthy','pointing','body_actuator','moderate_attenuation','pointing_actuator','pointing_attenuation','actuator_attenuation','combined','attenuation']
def select(s,mode='optical_event',policy='off'):
    return [r for r in rows if r['scenario']==s and r['mode']==mode and r['policy']==policy]
def mean(s,field,mode='optical_event',policy='off'):
    return statistics.mean(float(r[field]) for r in select(s,mode,policy))
def deg(x):return x*180/math.pi
def sd(s,field,mode='optical_event',policy='off'):
    return statistics.stdev(float(r[field]) for r in select(s,mode,policy))
def number(v,fmt='.5f'):
    return format(v,fmt) if math.isfinite(v) else 'n/a'
lines=['# Moving-reference coordination: measured evaluation','',
       '153 new tracking trials: 108 main comparisons (nine scenarios × four modes × three seeds) and 45 diagnosis-management ablations. Seeds are 11, 23, 47. Runs last 75 s; the fault interval is [25,60) s. All principal errors below use the fault window. These are separate from the retained static-reference benchmark and optical audit.', '',
       '## Experiment and information constraints','',
       'Only SC1 reads the time-varying command. Each follower derives its target and feedforward rate from timestamped parent packets along SC1 → SC2 → SC3 → SC4 and known attitude offsets. Local hold/stabilization remains possible without packets; tracking an unknown changing leader does not. No alternative-route forwarding is implemented. Gains, fault components, topology, and seeds are matched across modes. The declared protocol and limits are in [the experiment plan](../../docs/TRACKING_EXPERIMENT_PLAN.md).', '',
       'Exact quaternion-geodesic errors are used after removing the specified formation offsets. Command tracking and pair disagreement are distinct. Payload overhead counts 64 bytes per attempted directed state packet; headers, pilots, terminal electrical energy, and computation are excluded.', '',
       '## 1. Does communication affect coordination?','',
       'Pointing-fault condition; means ± sample standard deviations across three channel seeds:', '',
       '| Mode | Pair disagreement RMS (deg) | Tracking RMS (deg) | Torque-squared effort (N² m² s) | Attempts | Payload KiB | Affected availability |',
       '|---|---:|---:|---:|---:|---:|---:|']
for m in modes:
    lines.append(f'| {m} | {deg(mean("pointing","fault_pair_rms_rad",m)):.4f} ± {deg(sd("pointing","fault_pair_rms_rad",m)):.4f} | {deg(mean("pointing","fault_tracking_rms_rad",m)):.4f} ± {deg(sd("pointing","fault_tracking_rms_rad",m)):.4f} | {mean("pointing","fault_control_effort_N2m2s",m):.5g} | {mean("pointing","attempted_packets",m):.1f} | {mean("pointing","state_payload_bytes",m)/1024:.2f} | {mean("pointing","affected_availability",m):.2%} |')
ideal=mean('pointing','fault_pair_rms_rad','ideal_periodic')
bad=mean('pointing','fault_pair_rms_rad','optical_periodic_no_recovery')
periodic=mean('pointing','fault_pair_rms_rad','optical_periodic')
event=mean('pointing','fault_pair_rms_rad')
saving=100*(1-mean('pointing','attempted_packets')/mean('pointing','attempted_packets','optical_periodic'))
lines += ['',f'Unrecovered pointing failure changes pair RMS by {deg(bad-ideal):+.4f}° relative to ideal transport. Recovery changes it by {deg(periodic-bad):+.4f}° under matched periodic scheduling. Event recovery changes pair RMS by {deg(event-periodic):+.4f}° versus recovered periodic transport, while changing attempts by {-saving:+.2f}%. These are separate recovery and scheduling comparisons, not a blanket claim that one mode dominates.', '',
          '![Main comparison](comparison.png)', '',
          'The sparse command-distribution chain makes the SC1–SC2 session important to all followers. This finding establishes communication dependence for this declared task/topology, not for every redundant spacecraft network. All satellites still have local stabilization; their missing information is the moving leader command.', '',
          '## 2. Diagnosis-informed communication management','',
          'The preliminary seed-11 pilot showed a measurable limitation before management policies were enabled. The recorded gate is:', '', '```text',(out/'management_gate.txt').read_text().strip(),'```','',
          'Management uses local observed power and accepted offset/gain estimates to assess severity and whether the available correction could restore service. Scheduling-only changes retry intervals; prediction-only changes the bounded constant-rate horizon; both combines them. Policy off remains the default. Changes below are relative to recovered event messaging with management off for the same scenario; positive error change means worse coordination.', '',
          '| Scenario | Policy | Pair RMS (deg) | Pair RMS change | Attempt change | Fault-window effort change |',
          '|---|---|---:|---:|---:|---:|']
manager_scenarios=['healthy','pointing','pointing_actuator','combined','attenuation']
for s in manager_scenarios:
    baseline=mean(s,'fault_pair_rms_rad');attempts=mean(s,'attempted_packets');effort=mean(s,'fault_control_effort_N2m2s')
    for p in ['schedule','prediction','both']:
        pair=mean(s,'fault_pair_rms_rad',policy=p)
        lines.append(f'| {s} | {p} | {deg(pair):.4f} | {100*(pair/baseline-1):+.2f}% | {100*(mean(s,"attempted_packets",policy=p)/attempts-1):+.2f}% | {100*(mean(s,"fault_control_effort_N2m2s",policy=p)/effort-1):+.2f}% |')
lines += ['', 'These policies are heuristic and diagnosis-conditioned. Feasibility is not a guaranteed recovery-time estimate; prediction uncertainty and actuator transients are not formally bounded. Increased retry attempts can waste bandwidth during an outage. Longer constant-rate extrapolation can worsen a maneuver with changing angular rate. Every policy row is retained, including neutral or adverse outcomes.', '',
          '## 3. Individual and combined faults','',
          'Recovered event configuration, policy off. Factorial attenuation is gain 0.65 in every matching cell. Severe attenuation gain 0.12 is a separate control and is never substituted into an interaction calculation.', '',
          '| Scenario | Pair RMS (deg) | Tracking RMS (deg) | Affected availability | Verified recovery runs | Fault saturation fraction |',
          '|---|---:|---:|---:|---:|---:|']
for s in scenarios:
    group=select(s)
    recovered=sum(float(r['fault_window_recovered'])==1 for r in group)
    applicable=sum(math.isfinite(float(r['fault_window_recovered'])) for r in group)
    result=f'{recovered}/{applicable}' if applicable else 'no outage'
    lines.append(f'| {s} | {deg(mean(s,"fault_pair_rms_rad")):.4f} | {deg(mean(s,"fault_tracking_rms_rad")):.4f} | {mean(s,"affected_availability"):.2%} | {result} | {mean(s,"fault_saturation_fraction"):.3%} |')
interactions=[]
for mode in modes:
    for seed in [11,23,47]:
        by={s:next(r for r in select(s,mode) if int(r['seed'])==seed) for s in scenarios}
        for field in ['fault_pair_rms_rad','fault_tracking_rms_rad','fault_control_effort_N2m2s','attempted_packets']:
            v=lambda s:float(by[s][field])
            pa=v('pointing_actuator')-v('pointing')-v('body_actuator')+v('healthy')
            pat=v('combined')-v('pointing_actuator')-v('pointing_attenuation')-v('actuator_attenuation')+v('pointing')+v('body_actuator')+v('moderate_attenuation')-v('healthy')
            interactions.append(dict(mode=mode,seed=seed,metric=field,PxA=pa,PxAxT=pat))
with (out/'interactions.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=['mode','seed','metric','PxA','PxAxT']);w.writeheader();w.writerows(interactions)
lines += ['', 'Pair-disagreement interaction contrasts (mean ± sample SD in degrees; three paired seeds):', '',
          '| Mode | P×A | P×A×T |','|---|---:|---:|']
for mode in modes:
    g=[r for r in interactions if r['mode']==mode and r['metric']=='fault_pair_rms_rad']
    a=[deg(r['PxA']) for r in g];b=[deg(r['PxAxT']) for r in g]
    lines.append(f'| {mode} | {statistics.mean(a):+.6f} ± {statistics.stdev(a):.6f} | {statistics.mean(b):+.6f} ± {statistics.stdev(b):.6f} |')
lines += ['', 'P×A = Y(PA)−Y(P)−Y(A)+Y(healthy). P×A×T uses all eight factorial cells. These are descriptive interactions on the chosen RMS/effort/count scale. A positive error contrast indicates an increase beyond additive effects on that scale; it is not a stability proof or evidence of a unique mechanism. Three seeds do not support strong significance claims. Zero saturation means the selected actuator fault did not exercise torque saturation; it must not be described as a severe authority-limit demonstration.', '',
          '## Validation and reproducibility','',
          '```text',(out/'validation.txt').read_text().strip(),'```','',
          '- The end-to-end blackout test changes the external command and confirms identical follower trajectories with zero deliveries; SC1 changes, demonstrating the absence of a hidden follower reference path.',
          '- All 153 tracking trials have zero queue overflow and quaternion norm error below 1e-12.',
          '- Simulink parity covers 32 s, including the optical fault onset and recovery behavior. The documented one-sample telemetry delay is aligned before comparison.',
          '- First-seed full logs and selected figures are retained for every configuration. CSV files contain all three seeds. `run_tracking_experiments` regenerates the matrix.', '',
          '## Interpretation','',
          'This extension provides experimentally measurable communication-dependent coordination and a direct, ablated connection from local diagnosis to communication policy. It does not establish that the policy improves every metric or that all combined faults are tolerated. Read the per-scenario rows and interaction traces rather than the best result alone.', '',
          'The scheduler is the project’s documented event-based rule. The exact self-triggered controller from the original attitude research has not been implemented or claimed. The prior optical beam-calibration failure, ideal reciprocal pilot/sensors, normalized Gaussian optics, fixed geometry, missing acquisition protocol, and lack of formal stability/hardware validation remain limitations.', '',
          '[Raw trials](all_trials.csv) · [Factorial contrasts](interactions.csv) · [Tracking model and metrics](../../docs/TRACKING_MODEL.md)']
diagnostics=['### Diagnostic estimates behind the policy','',
             'Recovered event configuration, policy off. Fit fractions include a previously accepted estimate until mismatch validation invalidates it; conditional offset error therefore includes that detection latency. These are not fault-classification accuracy percentages.','',
             '| Scenario | Accepted-fit fraction | Conditional offset RMS (microrad) | Estimated-infeasible fraction |',
             '|---|---:|---:|---:|']
for s in ['healthy','pointing','attenuation','combined']:
    diagnostics.append(f'| {s} | {mean(s,"affected_valid_fit_fraction"):.2%} | {mean(s,"conditional_offset_rms_rad")*1e6:.2f} | {mean(s,"affected_estimated_infeasible_fraction"):.2%} |')
diagnostics += ['', 'In severe attenuation, the estimated best aligned power is insufficient for most of the fault window, whereas the pointing condition is estimated feasible once identified. The separate physical recovery scores determine whether communication actually returned.','']
text='\n'.join(lines)+'\n'
text=text.replace('## 3. Individual and combined faults','\n'.join(diagnostics)+'\n## 3. Individual and combined faults')
(out/'REPORT.md').write_text(text,encoding='utf-8')
print(f'Validated {len(rows)} tracking rows; pointing event attempt saving {saving:.2f}%; report and factorial contrasts written.')
