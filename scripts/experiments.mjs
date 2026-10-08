import {writeFileSync,readFileSync,mkdirSync} from 'node:fs';
import {simulate} from '../src/engine.mjs';import {optimize,monteCarlo,ABLATIONS} from '../src/research.mjs';
mkdirSync('results',{recursive:true});
const save=(n,x)=>writeFileSync('results/'+n+'.json',JSON.stringify(x));
const modes=['baseline-time','baseline-event','baseline-self','adaptive','fault-self','optimized'];
console.log('Optimization: 12 candidates x 4 populations, 2 training seeds');
const opt=optimize({},p=>{if(p.done%12===0)console.log(`Optimizer ${p.done}/${p.total}`);});save('optimization',opt);
const rows=[];
for(const scenario of ['nominal','degradation','failure','multiple','dropout','disturbance','noise','combined'])for(const mode of modes){const r=simulate({scenario,mode,dt:.01,params:mode==='optimized'?opt.best.params:{},budget:500});rows.push({scenario,mode,metrics:r.metrics});if(scenario==='combined')save('comparison-'+mode,r);console.log(scenario,mode,r.metrics.attitudeRMSE.toFixed(5),r.metrics.success);}
save('experiments',{dt:.01,duration:60,seed:42,budget:500,rows});
const ablation=ABLATIONS.map(a=>({...a,metrics:simulate({scenario:'combined',mode:a.mode,features:a.features,params:a.mode==='optimized'?opt.best.params:{},dt:.01,budget:500,record:false}).metrics}));save('ablation',ablation);
console.log('Monte Carlo: 100 paired scenarios x 5 methods');
const mc=monteCarlo({n:100,params:opt.best.params},p=>{if(p.done%10===0)console.log(`Monte Carlo ${p.done}/${p.total}`);});save('monte-carlo',mc);
const convergence=[];for(const mode of ['baseline-event','adaptive','optimized'])for(const dt of [.01,.005,.001]){const r=simulate({scenario:'combined',mode,params:mode==='optimized'?opt.best.params:{},dt,budget:500,record:false});convergence.push({mode,dt,metrics:r.metrics});}save('step-refinement',convergence);
save('demo',simulate({scenario:'demo',mode:'adaptive',dt:.005,budget:1000}));
console.log('Experiments complete.');
