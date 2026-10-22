"""Add explicit CSV unit metadata without changing any numerical result."""
from pathlib import Path
import csv
root=Path(__file__).resolve().parents[1]
for filename in ['means_ci.csv','paired_contrasts_ci.csv']:
    path=root/'results/holdout'/filename
    with path.open(newline='',encoding='utf-8-sig') as f:
        reader=csv.DictReader(f);fields=list(reader.fieldnames);rows=list(reader)
    if 'units' not in fields:fields.append('units')
    for row in rows:
        if row.get('scale')=='percent':row['units']='percent'
        elif row['metric'].endswith('_rad'):row['units']='degrees'
        elif row['metric'].endswith('N2m2s'):row['units']='N^2 m^2 s'
        else:row['units']='directed packets'
    with path.open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader();writer.writerows(rows)
print('CI CSV unit metadata added; all numerical values unchanged.')
