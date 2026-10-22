"""Paired run-seed bootstrap analysis. Python standard library only."""
from pathlib import Path
import csv,json,math,random,statistics
from freeze_holdout import verify
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'results/holdout'
def main():
    lock=verify()
    rows=list(csv.DictReader((OUT/'trials.csv').open(newline='',encoding='utf-8-sig')))
    assert len(rows)==440
    assert set(int(r['seed']) for r in rows)==set(range(101,121))
    assert all(float(r['queue_overflows'])==0 for r in rows)
    assert max(float(r['quaternion_norm_error']) for r in rows)<1e-12
    cases=list(dict.fromkeys(r['case_name'] for r in rows))
    rng=random.Random(lock['bootstrap_analysis_seed'])
    indices=[rng.choices(range(20),k=20) for _ in range(lock['bootstrap_resamples'])]
    def interval(v):
        assert len(v)==20 and all(math.isfinite(x) for x in v)
        samples=sorted(sum(v[i] for i in draw)/20 for draw in indices)
        def quantile(p):
            pos=(len(samples)-1)*p;i=int(pos);f=pos-i
            return samples[i]*(1-f)+samples[min(i+1,len(samples)-1)]*f
        return statistics.mean(v),quantile(.025),quantile(.975)
    def group(case,mode,policy='off'):
        g=sorted([r for r in rows if r['case_name']==case and r['mode']==mode and r['policy']==policy],key=lambda r:int(r['seed']))
        assert [int(r['seed']) for r in g]==list(range(101,121))
        return g
    def values(g,field):return [float(r[field]) for r in g]
    fields=['fault_pair_rms_rad','fault_tracking_rms_rad','fault_control_effort_N2m2s','attempted_packets']
    summary=[];contrasts=[]
    for case in cases:
        keys=list(dict.fromkeys((r['mode'],r['policy']) for r in rows if r['case_name']==case))
        for mode,policy in keys:
            g=group(case,mode,policy)
            for field in fields:
                factor=180/math.pi if field.endswith('_rad') else 1
                v=[x*factor for x in values(g,field)];mean,lo,hi=interval(v)
                summary.append(dict(case_name=case,mode=mode,policy=policy,metric=field,n=20,mean=mean,ci_low=lo,ci_high=hi))
        comparison=[('frozen_minus_event_off','optical_event','frozen','optical_event','off')]
        if case in cases[:2]:
            comparison += [('no_recovery_minus_ideal','optical_periodic_no_recovery','off','ideal_periodic','off'),
                           ('recovery_minus_no_recovery','optical_periodic','off','optical_periodic_no_recovery','off'),
                           ('event_minus_recovered_periodic','optical_event','off','optical_periodic','off')]
        for name,am,ap,bm,bp in comparison:
            a=group(case,am,ap);b=group(case,bm,bp)
            for field in fields:
                av=values(a,field);bv=values(b,field)
                factor=180/math.pi if field.endswith('_rad') else 1
                for scale in ['absolute','percent']:
                    if scale=='percent':v=[100*(x/y-1) for x,y in zip(av,bv)]
                    else:v=[(x-y)*factor for x,y in zip(av,bv)]
                    mean,lo,hi=interval(v)
                    contrasts.append(dict(case_name=case,comparison=name,metric=field,scale=scale,n=20,mean=mean,ci_low=lo,ci_high=hi))
    def write(name,data):
        with (OUT/name).open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
    write('means_ci.csv',summary);write('paired_contrasts_ci.csv',contrasts)
    def result(case,mode,policy,field):
        return next(r for r in summary if r['case_name']==case and r['mode']==mode and r['policy']==policy and r['metric']==field)
    def contrast(case,name,field,scale='absolute'):
        return next(r for r in contrasts if r['case_name']==case and r['comparison']==name and r['metric']==field and r['scale']==scale)
    def fmt(r,d=4):return f'{r["mean"]:.{d}f} [{r["ci_low"]:.{d}f}, {r["ci_high"]:.{d}f}]'
    lines=['# Held-out evaluation: frozen management rule and paired confidence intervals','',
           '440 new runs use 20 independent seeds (101–120), with paired conditions across compared configurations. Initial attitudes/rates, reference phase, disturbance phases/amplitudes, and channel realizations vary. These runs were not used to choose the rule. The previous development tables and adverse outcomes are retained unchanged.', '',
           'The protocol and source were locally locked before evaluation, with hashes verified after completion. This is a local reproducibility record, not a public preregistration or proof of algorithmic novelty.', '',
           '## Frozen rule','',
           'No aggressive retries are enabled. Retry throttling to 1.6 s requires a valid optical fit that estimates insufficient steering-restored power. Otherwise event scheduling retains its 0.8 s maximum silence. Prediction extends from 1.5 to 3 s only during locally degraded optical evidence with a measurable pilot or accepted recoverable offset, parent age in [1.5,3) s, and a delivered-message angular-rate change at most 3e-4 rad/s². Unknown rate history, darkness, excessive rate change, or estimated infeasibility retains baseline prediction. Low past acceleration does not bound future prediction error.', '',
           '## Confidence intervals','',
           'Every bracket below is a 95% pointwise percentile bootstrap interval using 10,000 resamples of the 20 paired run-seed units. Angles are degrees. Time samples are not treated as independent experiments. Relative effects average per-seed percentages, not ratios of grand means. Intervals describe the declared sampled distribution, are exploratory, and are not adjusted for multiple comparisons.', '',
           '## Principal conditions','', '![Principal comparisons with pointwise confidence intervals](principal_ci.png)', '']
    for case in cases[:2]:
        lines += [f'### {case.replace("_"," ")}', '',
                  '| Configuration | Fault pair RMS (deg), mean [95% CI] | Tracking RMS (deg), mean [95% CI] | Attempts, mean [95% CI] |',
                  '|---|---:|---:|---:|']
        for mode,policy in [('ideal_periodic','off'),('optical_periodic_no_recovery','off'),('optical_periodic','off'),('optical_event','off'),('optical_event','frozen')]:
            lines.append(f'| {mode} / {policy} | {fmt(result(case,mode,policy,"fault_pair_rms_rad"))} | {fmt(result(case,mode,policy,"fault_tracking_rms_rad"))} | {fmt(result(case,mode,policy,"attempted_packets"),1)} |')
        lines += ['', '| Paired comparison | Pair RMS difference (deg), mean [95% CI] | Attempt change (%), mean [95% CI] |', '|---|---:|---:|']
        for name in ['no_recovery_minus_ideal','recovery_minus_no_recovery','event_minus_recovered_periodic','frozen_minus_event_off']:
            lines.append(f'| {name} | {fmt(contrast(case,name,"fault_pair_rms_rad"))} | {fmt(contrast(case,name,"attempted_packets","percent"),2)} |')
        lines.append('')
    lines += ['## Frozen-policy transfer to every declared case','',
              'All changes compare frozen management with event recovery policy off on matched seeds. Negative error/effort/attempt change means a reduction. The new-case comparisons do not include the full four-mode baseline matrix.', '',
              '![Policy transfer with pointwise confidence intervals](policy_transfer_ci.png)', '',
              '| Case | Pair RMS change (%), mean [95% CI] | Effort change (%), mean [95% CI] | Attempt change (%), mean [95% CI] |', '|---|---:|---:|---:|']
    for case in cases:
        lines.append(f'| {case} | {fmt(contrast(case,"frozen_minus_event_off","fault_pair_rms_rad","percent"),2)} | {fmt(contrast(case,"frozen_minus_event_off","fault_control_effort_N2m2s","percent"),2)} | {fmt(contrast(case,"frozen_minus_event_off","attempted_packets","percent"),2)} |')
    lines += ['', 'No parameter is changed after seeing these rows. An interval crossing zero is inconclusive on that chosen scale/distribution; an interval excluding zero still does not imply universal benefit or a new algorithm.', '',
              '## Availability and sustained recovery','',
              '| Case | Policy | Mean affected availability during fault | Verified recovery / runs with an outage |', '|---|---|---:|---:|']
    for case in cases:
        for policy in ['off','frozen']:
            g=group(case,'optical_event',policy);availability=statistics.mean(values(g,'affected_availability'))
            applicable=[float(r['fault_window_recovered']) for r in g if math.isfinite(float(r['fault_window_recovered']))]
            recovery=f'{sum(v==1 for v in applicable)}/{len(applicable)}' if applicable else 'no outage'
            lines.append(f'| {case} | {policy} | {availability:.2%} | {recovery} |')
    lines += ['', 'Severe attenuation can place even perfectly aligned power below receiver threshold; steering then cannot restore service. This is a physical limitation of the available actuator, not automatically a diagnosis or simulation error. Fit fractions and conditional offset errors are not classification accuracy, and no general optical-diagnosis accuracy percentage is claimed.', '',
              '## Validation and remaining evidence limits','', '```text',(OUT/'validation.txt').read_text().strip(),'```','',
              '- All 440 trials have zero queue overflow and unit-quaternion norm error below 1e-12.',
              '- Validation uses separate seeds 901/902; evaluation seeds are 101–120 and development seeds are 11/23/47.',
              '- Full first-seed logs are saved for each case/configuration; all 20 seed metrics are retained. Sources and protocol match the pre-evaluation hash lock.',
              '- Additional conditions change fault magnitude/duration, beam calibration, and a tree/network combination. The tree/network case changes both topology and transport jointly, so it does not isolate their individual effects.',
              '- The tested distribution is finite. These intervals do not cover all initial conditions, faults, disturbance laws, network topologies, or hardware uncertainties. Acquisition/lock physics, ideal sensors/pilots, fixed geometry, and the known beam-model limitation remain.',
              '- Evidence supports an engineering integration and condition-specific empirical comparisons. Algorithmic novelty, formal stability, and the exact self-triggered method from the original research are not established. The implemented scheduler remains the documented event-based rule.', '',
              '[Paired contrasts and intervals](paired_contrasts_ci.csv) · [Configuration means and intervals](means_ci.csv) · [All trials](trials.csv) · [Frozen protocol](../../docs/HELDOUT_PROTOCOL.md) · [Development results](../tracking/REPORT.md)']
    (OUT/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (OUT/'analysis.json').write_text(json.dumps({'trials':len(rows),'independent_seeds':20,'bootstrap_resamples':len(indices),'analysis_seed':lock['bootstrap_analysis_seed'],'source_hashes_verified':True,'intervals':'95% pointwise paired-seed percentile bootstrap; exploratory, unadjusted'},indent=2)+'\n',encoding='utf-8')
    print(f'Analyzed {len(rows)} held-out trials; source hashes verified; {len(contrasts)} paired CI rows written.')
if __name__=='__main__':main()
