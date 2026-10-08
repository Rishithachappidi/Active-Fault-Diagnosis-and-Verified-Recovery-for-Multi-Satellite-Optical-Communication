import {simulate} from './engine.mjs';
import {rng,normal,clamp,copy} from './math.mjs';
import {S0,W0,J,PARAMETERS} from './scenarios.mjs';
export const METRICS=['attitudeRMSE','angularVelocityRMSE','convergenceTime','finalAttitudeError','finalAngularVelocityError','communicationEvents','controlEffort','faultRecoveryTime','maxAttitudeError','maximumOvershootPercent','saturationPercent'];
export function aggregate(rows) {
 const stats={n:rows.length,successRate:rows.length?rows.filter(r=>r.success).length/rows.length:null,numericalFailures:rows.filter(r=>r.failed).length};
 for(const key of METRICS){const a=rows.map(r=>r[key]).filter(v=>v!==null&&Number.isFinite(v)).sort((a,b)=>a-b);const q=p=>{const x=(a.length-1)*p,i=Math.floor(x);return a.length?a[i]+(a[Math.ceil(x)]-a[i])*(x-i):null;};stats[key]={observed:a.length,censored:rows.length-a.length,mean:a.length?a.reduce((s,v)=>s+v,0)/a.length:null,median:q(.5),p95:q(.95),worst:a.at(-1)??null,best:a[0]??null};}
 return stats;
}
export function randomizedEnvironment(seed) {
 const r=rng(seed),uniform=(a,b)=>a+(b-a)*r();
 return {s0:S0.map(s=>s.map(v=>v+normal(r)*.035)),w0:W0.map(w=>w.map(v=>v+normal(r)*.025)),inertia:J.map(j=>j.map(v=>v*uniform(.85,1.15))),gamma:Array.from({length:4},()=>Array.from({length:3},()=>uniform(.8,1))),disturbanceBase:uniform(.5,2),disturbanceScale:uniform(1,4),faultTime:uniform(15,30),dropout:uniform(0,.35),noise:uniform(0,.00015),faults:[{sc:Math.floor(r()*4),target:Array.from({length:3},()=>uniform(.2,.8)),kind:r()<.5?'sudden':'gradual',time:uniform(15,30),duration:uniform(2,10)}]};
}
export function monteCarlo({n=100,seed=2026,modes=['baseline-time','baseline-event','baseline-self','adaptive','optimized'],params={},dt=.01,duration=60,budget=500}={},progress=()=>{}) {
 if(!Number.isInteger(n)||n<1||n>1000)throw Error('Campaign size must be 1–1000');
 const rows=[];for(let k=0;k<n;k++) {const environment=randomizedEnvironment(seed+k);for(const mode of modes){const options={scenario:'combined',environment,mode,seed:seed+k,params:mode==='optimized'?params:{},duration,dt,budget,record:false};const r=simulate(options);rows.push({run:k,seed:seed+k,mode,config:r.config,metrics:r.metrics});}progress({done:k+1,total:n});}
 return {kind:'paired Monte Carlo',n,seed,dt,duration,budget,rows,summary:Object.fromEntries(modes.map(m=>[m,aggregate(rows.filter(r=>r.mode===m).map(r=>r.metrics))]))};
}
export function objective(m,weights=[4,2,1,1,2],scales={tracking:.15,communication:2400,effort:10,computation:40000000,recovery:60}) {
 if(weights.length!==5||weights.some(w=>!Number.isFinite(w)||w<0)||weights.every(w=>w===0))throw Error('Five nonnegative weights with nonzero sum required');
 const components=[m.attitudeRMSE/scales.tracking,m.communicationEvents/scales.communication,m.controlEffort/scales.effort,m.computationUnits/scales.computation,(m.faultRecoveryTime??scales.recovery)/scales.recovery];
 const penalty=m.failed?100:!m.success?2:0;
 return {components,value:components.reduce((s,v,i)=>s+v*weights[i],0)/weights.reduce((a,b)=>a+b,0)+penalty,penalty};
}
export const BOUNDS={r:[.3,1],gainScale:[.65,1.4],delta:[.08,.5],logEpsilon:[-5,-3],beta1:[3,8],beta2:[6,14],gamma:[.2,.8],errorWeight:[1,8],faultWeight:[1,6],commWeight:[.2,3],maxInterval:[.2,1.5]};
const keys=Object.keys(BOUNDS);
const decode=x=>Object.fromEntries(x.map((v,i)=>keys[i]==='logEpsilon'?['epsilon',10**v]:[keys[i],v]));
export const dominates=(a,b)=>a.every((v,i)=>v<=b[i])&&a.some((v,i)=>v<b[i]);
export function rankPopulation(pop) {
 const pending=new Set(pop);let rank=0;
 while(pending.size){const front=[...pending].filter(p=>![...pending].some(q=>q!==p&&dominates(q.f,p.f)));for(const p of front){p.rank=rank;p.crowding=0;pending.delete(p);}for(let k=0;k<front[0].f.length;k++){front.sort((a,b)=>a.f[k]-b.f[k]);front[0].crowding=front.at(-1).crowding=Infinity;const range=front.at(-1).f[k]-front[0].f[k];if(range)for(let i=1;i<front.length-1;i++)front[i].crowding+=(front[i+1].f[k]-front[i-1].f[k])/range;}rank++;}
 return pop.sort((a,b)=>a.rank-b.rank||b.crowding-a.crowding);
}
export function optimize({seed=71,population=12,generations=3,weights=[4,2,1,1,2],dt=.01,duration=60,budget=500,trainingSeeds=[101,102]}={},progress=()=>{}) {
 if(!Number.isInteger(population)||population<4||population>64||!Number.isInteger(generations)||generations<1||generations>20)throw Error('Population 4–64, generations 1–20 required');
 const random=rng(seed),archive=[],scales={tracking:.15,communication:4*duration/.1,effort:duration/6,computation:40000000*duration/60,recovery:duration};
 const evaluate=x=>{const params=decode(x),runs=trainingSeeds.map(s=>simulate({scenario:'combined',environment:randomizedEnvironment(s),seed:s,mode:'optimized',params,dt,duration,budget,record:false}).metrics);const scores=runs.map(m=>objective(m,weights,scales)),f=scores[0].components.map((_,k)=>scores.reduce((s,o)=>s+o.components[k]+o.penalty,0)/scores.length),score=scores.reduce((s,o)=>s+o.value,0)/scores.length;const p={x,params,f,score,metrics:runs};archive.push(p);progress({done:archive.length,total:population*(generations+1)});return p;};
 const original=keys.map(k=>k==='logEpsilon'?-4:PARAMETERS[k]);let pop=[evaluate(original)];while(pop.length<population)pop.push(evaluate(keys.map(k=>{const [l,h]=BOUNDS[k];return l+(h-l)*random();})));
 for(let g=0;g<generations;g++){
  rankPopulation(pop);const tournament=()=>{const a=pop[Math.floor(random()*pop.length)],b=pop[Math.floor(random()*pop.length)];return a.rank<b.rank||a.rank===b.rank&&a.crowding>b.crowding?a:b;};
  const children=[];while(children.length<population){const a=tournament(),b=tournament();const x=a.x.map((v,k)=>{const [l,h]=BOUNDS[keys[k]],u=random(),eta=10,beta=u<=.5?(2*u)**(1/(eta+1)):(1/(2*(1-u)))**(1/(eta+1));let child=.5*((1+beta)*v+(1-beta)*b.x[k]);if(random()<1/keys.length)child+=normal(random)*.1*(h-l);return clamp(child,l,h);});children.push(evaluate(x));}pop=rankPopulation([...pop,...children]).slice(0,population);
 }
 const best=archive.reduce((a,b)=>a.score<=b.score?a:b);
 const pareto=archive.filter(p=>!archive.some(q=>dominates(q.f,p.f)));
 return {method:'NSGA-II: nondominated sorting, crowding, tournament, SBX crossover, bounded Gaussian mutation',seed,population,generations,trainingSeeds,dt,duration,budget,weights,scales,evaluations:archive.length,best:{params:best.params,objective:best.score,metrics:best.metrics},original:{params:decode(original),objective:archive[0].score,metrics:archive[0].metrics},pareto:pareto.map(p=>({params:p.params,objectives:p.f,objective:p.score})),history:archive.map((p,i)=>({evaluation:i+1,objective:p.score}))};
}
export const ABLATIONS=[
 {label:'A / baseline',mode:'baseline-event',features:{}},
 {label:'B / adaptive trigger',mode:'adaptive',features:{diagnosis:false,communication:false,compensation:false}},
 {label:'C / + fault severity',mode:'adaptive',features:{communication:false,compensation:false}},
 {label:'D / + communication pressure',mode:'adaptive',features:{compensation:false}},
 {label:'E / + optimized parameters',mode:'optimized',features:{compensation:false}},
 {label:'F / full framework',mode:'optimized',features:{}}
];
