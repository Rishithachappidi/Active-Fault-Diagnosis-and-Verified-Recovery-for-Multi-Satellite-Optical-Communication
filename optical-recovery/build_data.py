"""Summarize the V2 comparison batch into website/data.json (standard library only)."""
import csv, json, math, os, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'revisions', 'v2', 'results')
BATCH = sys.argv[1] if len(sys.argv) > 1 else 'comparison_20261016_000055_091'
SCEN = ['normal', 'pointing', 'effectiveness', 'lag', 'power', 'blockage', 'sensor', 'simultaneous']
SIZES = [4, 6, 8, 10]


def num(x):
    try:
        v = float(x)
    except (TypeError, ValueError):
        return None
    return None if math.isnan(v) else v


def mean(v):
    v = [x for x in v if x is not None]
    return sum(v) / len(v) if v else None


def sd(v):
    v = [x for x in v if x is not None]
    return statistics.stdev(v) if len(v) > 1 else (0.0 if v else None)


rows = list(csv.DictReader(open(os.path.join(RES, BATCH, 'all_trials.csv'))))
for r in rows:
    r['n'] = int(r['n']); r['seed'] = int(r['seed'])
seeds = sorted({r['seed'] for r in rows})


def pick(**kw):
    return [r for r in rows if all(r[k] == v for k, v in kw.items())]


def seed_summary(metric, n, impl):
    """Report convention: average per-run values within each seed, then mean +/- SD across seeds."""
    per_seed = [mean(num(r[metric]) for r in pick(n=n, implementation=impl, seed=s)) for s in seeds]
    return {'mean': mean(per_seed), 'sd': sd(per_seed)}


overall_metrics = ['detection_accuracy', 'precision', 'recall', 'false_positive_rate', 'isolation_accuracy',
                   'uncertain_frequency', 'recovery_success', 'link_outage_s', 'postclear_outage_s',
                   'postclear_false_alarm_rate', 'link_availability', 'diagnosis_time_s']
overall = {m: {i: seed_summary(m, 4, i) for i in ('v1', 'v2')} for m in overall_metrics}

scen_metrics = ['detection_accuracy', 'isolation_accuracy', 'false_positive_rate', 'uncertain_frequency',
                'link_outage_s', 'postclear_outage_s', 'link_availability']
scenario = {s: {i: {m: {'mean': mean(num(r[m]) for r in pick(n=4, scenario=s, implementation=i)),
                         'sd': sd([num(r[m]) for r in pick(n=4, scenario=s, implementation=i)])}
                    for m in scen_metrics} for i in ('v1', 'v2')} for s in SCEN}

size_metrics = ['link_availability', 'network_outage_s', 'latency_s', 'throughput_bps', 'packet_delivery_ratio',
                'detection_accuracy', 'isolation_accuracy', 'runtime_s']
by_size = {n: {i: {m: mean(num(r[m]) for r in pick(n=n, implementation=i)) for m in size_metrics}
               for i in ('v1', 'v2')} for n in SIZES}

recovery = []
for n in SIZES:
    e = {}
    for i in ('v1', 'v2'):
        vals = [num(r['recovery_success']) for r in pick(n=n, implementation=i)]
        e[i + '_eligible'] = sum(v is not None for v in vals)
        e[i + '_recovered'] = sum(v == 1 for v in vals)
    recovery.append({'n': n, **e})

stress_rows = list(csv.DictReader(open(os.path.join(RES, 'stress_20261014_225450_080', 'stress.csv'))))
stress = {i: {'trials': 0, 'verified': 0, 'postclear_outage_s': None, 'false_positive_rate': None,
              'detection_accuracy': None, 'isolation_accuracy': None} for i in ('v1', 'v2')}
for i in ('v1', 'v2'):
    sel = [r for r in stress_rows if r['implementation'] == i]
    stress[i]['trials'] = len(sel)
    stress[i]['verified'] = sum(num(r['postclear_restoration_verified']) == 1 for r in sel)
    for m in ('postclear_outage_s', 'false_positive_rate', 'detection_accuracy', 'isolation_accuracy'):
        stress[i][m] = mean(num(r[m]) for r in sel)

# Reproducibility check against the saved final batch
ref = {r['id']: r for r in csv.DictReader(open(os.path.join(RES, 'comparison_20261014_224749_328', 'all_trials.csv')))}
matched, differing = 0, 0
for r in csv.DictReader(open(os.path.join(RES, BATCH, 'all_trials.csv'))):
    o = ref.get(r['id'])
    if not o:
        continue
    matched += 1
    for c, v in r.items():
        if c in ('runtime_s', 'origin'):
            continue
        a, b = num(v), num(o.get(c))
        if (a is None) != (b is None) or (a is not None and abs(a - b) > 1e-9 * max(1, abs(b))):
            differing += 1
            break

origins = {}
for r in rows:
    origins[r['origin']] = origins.get(r['origin'], 0) + 1

out = {'batch': BATCH, 'reference_batch': 'comparison_20261014_224749_328', 'trials': len(rows), 'origins': origins,
       'seeds': seeds, 'scenarios': SCEN, 'sizes': SIZES, 'overall_n4': overall, 'scenario_n4': scenario,
       'by_size': by_size, 'recovery': recovery, 'stress': stress,
       'reproduction': {'matched_trials': matched, 'trials_with_differences': differing}}
HERE = os.path.dirname(os.path.abspath(__file__))
json.dump(out, open(os.path.join(HERE, 'data.json'), 'w'), indent=1)
with open(os.path.join(HERE, 'data.js'), 'w') as f:
    f.write('window.SITE_DATA = ' + json.dumps(out) + ';\n')
print(json.dumps({'overall_iso': overall['isolation_accuracy'], 'recovery': recovery[0], 'stress': stress,
                  'reproduction': out['reproduction']}, indent=1))
