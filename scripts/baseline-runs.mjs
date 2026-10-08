import {simulate} from '../src/engine.mjs';import {writeFileSync} from 'node:fs';
// Regenerates results, never silently overwrites the frozen regression fixture.
for(const mode of ['baseline-time','baseline-event','baseline-self']){const r=simulate({scenario:'paper',mode});writeFileSync(`results/${mode}.json`,JSON.stringify(r));console.log(mode,r.metrics);}
