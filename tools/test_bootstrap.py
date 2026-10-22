"""Synthetic end-to-end paired-bootstrap check; does not read held-out data."""
from pathlib import Path
import importlib.util,csv,math,tempfile,os
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('analysis_fixture',ROOT/'tools/analyze_holdout.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
temporaryBase=os.environ.get('ISC_TEST_TMPDIR')
with tempfile.TemporaryDirectory(prefix='isc-bootstrap-',dir=temporaryBase) as directory:
    scratch=Path(directory);out=scratch/'results/holdout';out.mkdir(parents=True)
    module.ROOT=scratch;module.OUT=out
    # Source-lock verification is mocked ONLY for this synthetic fixture.
    module.verify=lambda:{'bootstrap_analysis_seed':20261022,'bootstrap_resamples':10000}
    cases=['principal_pointing','principal_combined','short_small','long_large',
           'combined_new','severe_attenuation_new','beam_mismatch_new','alternate_tree_network']
    rows=[]
    for k,case in enumerate(cases):
        configs=[('optical_event','off'),('optical_event','frozen')]
        if k<2:configs=[('ideal_periodic','off'),('optical_periodic_no_recovery','off'),('optical_periodic','off')]+configs
        for mode,policy in configs:
            delta={'ideal_periodic':0,'optical_periodic_no_recovery':.1,'optical_periodic':.02,'optical_event':.03}[mode]
            if policy=='frozen':delta=.02
            for seed in range(101,121):
                base=1+seed*.0001
                rows.append(dict(case_name=case,mode=mode,policy=policy,seed=seed,
                                 fault_pair_rms_rad=base+delta,fault_tracking_rms_rad=base+delta,
                                 fault_control_effort_N2m2s=.01+delta*.001,
                                 attempted_packets=900 if policy=='frozen' else (1000 if mode=='optical_event' else 2000),
                                 queue_overflows=0,quaternion_norm_error=0,affected_availability=1,fault_window_recovered=1))
    with (out/'trials.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    (out/'validation.txt').write_text('Synthetic statistical fixture only.\n')
    module.main()
    contrasts=list(csv.DictReader((out/'paired_contrasts_ci.csv').open()))
    assert len(contrasts)==112
    selected=[r for r in contrasts if r['comparison']=='frozen_minus_event_off' and r['metric']=='fault_pair_rms_rad' and r['scale']=='absolute']
    expected=-.01*180/math.pi
    for r in selected:
        assert abs(float(r['mean'])-expected)<1e-9
        assert abs(float(r['ci_low'])-expected)<1e-9 and abs(float(r['ci_high'])-expected)<1e-9
    selected=[r for r in contrasts if r['comparison']=='frozen_minus_event_off' and r['metric']=='attempted_packets' and r['scale']=='percent']
    assert all(abs(float(r['mean'])+10)<1e-9 for r in selected)
message='BOOTSTRAP_ANALYSIS_PASS: constant paired differences retain zero-width intervals; per-seed attempt change is -10%; 112 expected contrast rows.\n'
(ROOT/'results/holdout/bootstrap_validation.txt').write_text(message,encoding='utf-8')
print(message)
