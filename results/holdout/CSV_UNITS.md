# Held-out CSV units

`trials.csv` contains the original simulation metrics: fields ending in `_rad` are radians.

The confidence-interval tables retain those source metric names as identifiers. Their angular means/absolute differences and interval bounds are converted to **degrees**, as declared in the frozen analysis protocol. Their `units` column makes this explicit. Percent-effect rows are per-seed percentages. Control effort uses N² m² s; attempts use directed packet counts.

`annotate_ci_units.py` adds unit metadata after the locked numerical analysis. It does not change numerical strings, estimates, intervals, pairing, bootstrap draws, or policy parameters. The locked analysis and policy sources remain unchanged. If regenerating results, run this annotation step after `analyze_holdout.py`.

The optional `tools/render_ci_layout.m` wrapper pads categorical x-axis limits when redrawing figures so endpoint labels remain visible. It changes only graphics defaults, restores them afterward, and does not change the locked numerical or plotting source.
