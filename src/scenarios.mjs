import {copy,clamp} from './math.mjs';
export const J=[[5.1,4.8,5],[4.9,4.9,5.1],[5,5.2,5.1],[4.8,5.1,4.9]];
export const GAMMA=[[.8,.7,.8],[.6,.8,.7],[.5,.8,.6],[.7,.6,.7]];
export const S0=[[.15,.22,-.15],[.08,.18,-.13],[-.09,.12,.18],[.12,-.13,.15]];
export const W0=[[.15,-.08,.12],[-.14,.11,.13],[.16,.12,-.07],[-.13,-.17,.12]];
export const A=[[0,1,0,0],[1,0,1,0],[1,1,0,0],[1,0,0,0]], B=[1,0,0,0];
export const PARAMETERS=Object.freeze({r:.6,k0:.1,alpha:.001,delta:.3,epsilon:1e-4,chi0:.3,beta1:5,beta2:10,gamma:.5,gainScale:1,errorWeight:4,faultWeight:3,disturbanceWeight:1,commWeight:1,maxInterval:1});
const fault=(sc,target,kind='sudden',time=20,duration=10)=>({sc,target,kind,time,duration,period:4});
export const SCENARIOS=[
 {id:'paper',name:'Repository baseline',description:'Original 60 s plant, constant effectiveness and 1 ms solver. No new fault injection.',objective:'Preserve supplied MATLAB semantics.',gamma:GAMMA,faults:[]},
 {id:'nominal',name:'01 / Nominal formation',description:'Healthy actuators; original initial states and disturbances.',objective:'Track the common reference.',faults:[]},
 {id:'degradation',name:'02 / Single actuator degradation',description:'SC2 loses effectiveness gradually from T+20 s.',objective:'Detect loss and recover tracking.',faults:[fault(1,[.8,.45,.8],'gradual')]},
 {id:'failure',name:'03 / Sudden actuator failure',description:'SC2 X-axis loses all authority at T+20 s. Stabilization is not guaranteed.',objective:'Expose loss of controllability honestly.',faults:[fault(1,[0,.6,.8])]},
 {id:'multiple',name:'04 / Multiple actuator degradation',description:'SC2 and SC3 suffer partial losses.',objective:'Maintain coordination with two degraded vehicles.',faults:[fault(1,[.5,.4,.6]),fault(2,[.6,.5,.4],'gradual',25)]},
 {id:'disturbance',name:'05 / High disturbance',description:'Disturbance magnitude rises eightfold at T+20 s.',objective:'Measure rejection and false diagnosis.',faults:[],disturbanceScale:8},
 {id:'dropout',name:'06 / Communication dropout',description:'35% of attempted broadcasts are lost after T+20 s.',objective:'Quantify stale-neighbor effects.',faults:[],dropout:.35},
 {id:'noise',name:'07 / Sensor noise',description:'Independent Gaussian noise, 0.0001 MRP and rad/s standard deviation.',objective:'Quantify false alarms and trigger sensitivity.',faults:[],noise:.0001},
 {id:'combined',name:'08 / Combined fault',description:'SC2 degradation, 20% packet loss and increased disturbance.',objective:'Evaluate compounded uncertainty.',faults:[fault(1,[.45,.35,.5])],dropout:.2,disturbanceScale:3},
 {id:'worst',name:'09 / Worst-case stress mission',description:'Axis failure, intermittent SC3 loss, 50% dropout and noisy sensors.',objective:'Find failure boundaries, not guarantee recovery.',faults:[fault(1,[0,.3,.4]),fault(2,[.3,.4,.5],'intermittent',25)],dropout:.5,noise:.0002,disturbanceScale:8},
 {id:'demo',name:'Demo / Resilience sequence',description:'90 s mission replayed over 3 minutes; gradual SC2 loss at 10 s, severe at 30 s. Detection and recovery are computed.',objective:'Explain actual decisions without staged success.',duration:90,faults:[fault(1,[.8,.55,.8],'gradual',10,5),fault(1,[.4,.35,.5],'sudden',30)]}
];
export function scenario(id) {const s=SCENARIOS.find(s=>s.id===id);if(!s)throw Error('Unknown scenario: '+id);return copy(s);}
export function effectiveness(t,config) {
 const g=copy(config.gamma??Array.from({length:4},()=>[1,1,1]));
 for(const f of config.faults??[]) {
  if(t<f.time)continue;
  const q=f.kind==='gradual'?clamp((t-f.time)/Math.max(f.duration,.001),0,1):f.kind==='intermittent'?(Math.floor((t-f.time)/(f.period??4))%2===0?1:0):1;
  for(let a=0;a<3;a++)g[f.sc][a]=g[f.sc][a]*(1-q)+f.target[a]*q;
 }
 return g;
}
export function disturbances(t,i) {
 const a=Math.sin(.1*t),b=Math.cos(.2*t),c=Math.cos(.1*t),d=Math.sin(.2*t);
 return [[2+a,1+2*b,2+a],[1+2*b,2+a,1+2*b],[3+3*c,2+c,2+d],[2+d,1+2*d,3+3*c]][i].map(v=>v*.001);
}
export function drift(t,i) {return [[.2+.3*Math.cos(.2*t),-.3+.1*Math.cos(.1*t),.1-.2*Math.sin(.2*t)],[-.3+.1*Math.sin(.1*t),-.2+.3*Math.cos(.2*t),.3-.3*Math.sin(.1*t)],[-.2+.2*Math.sin(.1*t),-.2+.2*Math.cos(.3*t),.2-.1*Math.cos(.3*t)],[.1+.3*Math.cos(.2*t),-.3+.1*Math.sin(.2*t),.1-.2*Math.sin(.2*t)]][i].map(v=>v*.001);}
