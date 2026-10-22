"""Create or verify a local source/protocol lock; never overwrite a lock."""
from pathlib import Path
import argparse,hashlib,json,datetime
ROOT=Path(__file__).resolve().parents[1]
LOCK=ROOT/'results/holdout/lock.json'
def verify():
    record=json.loads(LOCK.read_text(encoding='utf-8'))
    for name,digest in record['sources'].items():
        actual=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
        if actual!=digest:raise RuntimeError(f'Frozen source changed: {name}')
    return record
def freeze():
    if LOCK.exists():
        verify();print('Existing source/protocol lock verified; not overwritten.');return
    files=list(ROOT.glob('*.m'))+list((ROOT/'src').glob('*.m'))+list((ROOT/'tests').glob('*.m'))
    files += [ROOT/'docs/HELDOUT_PROTOCOL.md',ROOT/'tools/analyze_holdout.py',Path(__file__)]
    record={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'development_seeds':[11,23,47],'validation_seeds':[901,902],
            'evaluation_seeds':list(range(101,121)),'planned_trials':440,
            'bootstrap_resamples':10000,'bootstrap_analysis_seed':20261022,
            'sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}}
    LOCK.parent.mkdir(parents=True,exist_ok=True)
    LOCK.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(f'Locked {len(files)} sources before held-out evaluation.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--freeze',action='store_true');args=parser.parse_args()
    if args.freeze:freeze()
    else:record=verify();print(f'Verified {len(record["sources"])} frozen source/protocol hashes.')
