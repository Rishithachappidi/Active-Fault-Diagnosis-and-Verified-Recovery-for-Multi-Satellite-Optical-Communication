# Satellite Optical Recovery website

Static page presenting the V2 comparison results for active fault diagnosis and verified recovery on multi-satellite laser links (MATLAB R2026a / Simulink, 320 matched trials).

- `index.html`: the page
- `data.js` / `data.json`: numbers summarized from the comparison batch by `build_data.py`
- `figures/`: MATLAB figures from the same batch

Live on GitHub Pages under `/optical-recovery/`. `render.yaml` at the repository root deploys this folder as a Render static site (Render → New → Blueprint → this repository).

To refresh after a new MATLAB run, run `build_data.py <batch folder name>` from the full project (it reads `revisions/v2/results/`) and copy the batch's `figures/*.png` here.
