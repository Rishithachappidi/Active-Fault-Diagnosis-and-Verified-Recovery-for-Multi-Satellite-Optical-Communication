# Project website

Static site with two pages. No build step.

- `index.html` + `sim/`: live simulator. `sim/engine.js` is a JavaScript port of the MATLAB/Simulink model (optics, pointing control, fault injection, V1 and V2 supervisors, rerouting, metrics); `sim/app.js` is the interface.
- `results.html`: the verified MATLAB comparison results.

- `data.js` / `data.json`: numbers summarized by `build_data.py` from a comparison batch in `revisions/v2/results/`
- `figures/`: MATLAB figures from the same batch

Served by GitHub Pages from `main` → `/docs`, and deployable on Render through `render.yaml` at the repository root.

The published numbers come from batch `comparison_20261016_000055_091`, a full rerun that matched the committed batch `comparison_20261014_224749_328` exactly on all 320 trials.
