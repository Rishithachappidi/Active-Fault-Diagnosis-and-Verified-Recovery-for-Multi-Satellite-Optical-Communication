import {add,sub,mul,dot,norm,cross,clamp,copy,kinematics,reference,rng,normal} from './math.mjs';
import {J,GAMMA,S0,W0,A,PARAMETERS,scenario,effectiveness,disturbances,drift} from './scenarios.mjs';
import {Diagnosis} from './diagnosis.mjs';
import {MODES,coordination,control,selfNext,adaptiveThreshold,sampledError} from './policies.mjs';
export function configuration(options={}) {
 const strict=options.scenario==='paper'||!options.scenario;
 const sc={...scenario(options.scenario??'paper'),...copy(options.environment??{})};
 const c={mode:options.mode??'baseline-event',scenario:sc.id,seed:options.seed??42,dt:options.dt??.001,duration:options.duration??sc.duration??60,budget:options.budget??1000,params:{...PARAMETERS,...options.params},environment:sc,record:options.record!==false,sampleEvery:options.sampleEvery??.1,features:{adaptive:true,diagnosis:true,communication:true,compensation:true,...options.features}};
 if(!MODES.includes(c.mode))throw Error('Unknown controller');
 if(!Number.isFinite(c.dt)||c.dt<.0001||c.dt>.02||!Number.isFinite(c.duration)||c.duration<=0||c.duration>300)throw Error('Use dt 0.0001–0.02 s and duration 0–300 s');
 if(!Number.isFinite(c.sampleEvery)||c.sampleEvery<c.dt)throw Error('Sample interval must be finite and at least dt');
 if(Math.abs(c.duration/c.dt-Math.round(c.duration/c.dt))>1e-6)throw Error('Duration must be an integer multiple of dt');
 if(!Number.isInteger(c.budget)||c.budget<0||c.budget>1000000)throw Error('Budget must be an integer from 0 to 1000000');
 if(strict) {
  if(!c.mode.startsWith('baseline-'))throw Error('Strict repository baseline requires a baseline controller; select a stress scenario for extensions');
  if(options.environment||options.params||options.dt&&options.dt!==.001||options.duration&&options.duration!==60)throw Error('Strict baseline is locked. Use a stress scenario for modifications.');
  c.dt=.001;c.duration=60;c.environment=scenario('paper');c.budget=1000000;c.params={...PARAMETERS};
 }
 const p=c.params;
 for(const [key,v] of Object.entries(p))if(!Number.isFinite(v)||v<=0)throw Error('Positive finite parameter required: '+key);
 if(p.delta>=1||p.gamma>=1)throw Error('delta and gamma must be below one');
 for(const f of sc.faults??[])if(!Number.isInteger(f.sc)||f.sc<0||f.sc>3||!Array.isArray(f.target)||f.target.length!==3||f.target.some(v=>!Number.isFinite(v)||v<0||v>1)||!['sudden','gradual','intermittent'].includes(f.kind)||!Number.isFinite(f.time)||f.time<0||!Number.isFinite(f.duration)||f.duration<=0)throw Error('Invalid fault profile');
 for(const key of ['dropout','noise'])if(sc[key]!==undefined&&(!Number.isFinite(sc[key])||sc[key]<0||(key==='dropout'&&sc[key]>1)))throw Error('Invalid '+key);
 for(const key of ['inertia','gamma','s0','w0'])if(sc[key]&&(sc[key].length!==4||sc[key].some(row=>row.length!==3||row.some(v=>!Number.isFinite(v)||(key==='inertia'&&v<=0)||(key==='gamma'&&(v<0||v>1))))))throw Error('Invalid '+key);
 c.strict=strict;return c;
}
export function derivative(t,s,w,u,inertia,gamma,distScale=1,i=0) {
 const gyro=cross(w,w.map((v,a)=>v*inertia[a])),rho=disturbances(t,i),bias=drift(t,i);
 return {s:kinematics(s,w),w:w.map((_,a)=>(-gyro[a]+gamma[a]*clamp(u[a],-.2,.2)+distScale*rho[a]+bias[a])/inertia[a])};
}
export class Simulation {
 constructor(options={}) {
  this.config=configuration(options);const c=this.config;this.p=c.params;this.t=0;this.tick=0;this.steps=Math.round(c.duration/c.dt);this.duration=this.steps*c.dt;
  this.s=copy(c.environment.s0??S0);this.w=copy(c.environment.w0??W0);this.inertia=copy(c.environment.inertia??J);
  this.bs=copy(this.s);this.bw=copy(this.w);this.held=Array.from({length:4},()=>[0,0,0]);this.u=copy(this.held);this.chi=Array(4).fill(this.p.chi0);this.next=Array(4).fill(0);this.last=Array(4).fill(null);this.receivedAt=Array(4).fill(0);this.updates=Array(4).fill(0);this.attempts=Array(4).fill(0);this.delivered=Array(4).fill(0);this.denied=Array(4).fill(0);this.dropped=Array(4).fill(0);this.rate=Array(4).fill(0);
  this.diag=J.map(j=>new Diagnosis(j,c.environment.noise??0));this.noiseRng=rng(c.seed);this.dropRng=rng(c.seed^0xabcdef);this.status=Array(4).fill('unobservable');this.history=[];this.events=[];this.lastDecision=Array(4).fill(null);this.errors=[];this.threshold=Array(4).fill(0);this.diagPeriod=Math.max(1,Math.round(.05/c.dt));this.obsPrev=copy(this.w);this.torqueSum=copy(this.held);this.obsSamples=0;this.evalCount=0;this.sqA=0;this.sqW=0;this.effort=0;this.saturation=0;this.peak=0;this.peakCommand=0;this.maxError=0;this.maxOvershoot=0;this.initialErrors=this.s.map(s=>norm(sub(s,reference(0).s)));this.lastViolation=0;this.faultFlags=new Set();this.failed=false;this.lastFrame=-Infinity;
 }
 event(type,i,detail) {if(this.config.record)this.events.push({t:this.t,type,sc:i,detail});}
 step() {
  if(this.tick>=this.steps||this.failed)return false;
  const c=this.config,p=this.p,h=c.dt,t=this.t,env=c.environment,ref=reference(t),extended=!c.mode.startsWith('baseline-');
  const ms=this.s.map(s=>s.map(v=>v+(env.noise??0)*normal(this.noiseRng))),mw=this.w.map(w=>w.map(v=>v+(env.noise??0)*normal(this.noiseRng)));
  // Generate channel availability every time step, independent of policy decisions.
  const lost=Array.from({length:4},()=>this.dropRng()<(t>=(env.faultTime??20)?env.dropout??0:0));
  if(this.tick>0&&this.tick%this.diagPeriod===0) {
   for(let i=0;i<4;i++) {
    this.diag[i].update(this.obsPrev[i],mw[i],mul(this.torqueSum[i],1/this.obsSamples),this.obsSamples*h);
    if(this.diag[i].status!==this.status[i]) {this.event('diagnosis',i,`${this.status[i]} → ${this.diag[i].status}; axis ${'XYZ'[this.diag[i].axis]}; evidence ${this.diag[i].confidence.toFixed(3)}`);this.status[i]=this.diag[i].status;}
   }
   this.obsPrev=copy(mw);this.torqueSum=Array.from({length:4},()=>[0,0,0]);this.obsSamples=0;
  } else if(this.tick===0)this.obsPrev=copy(mw);
  for(const [n,f] of (env.faults??[]).entries())if(t>=f.time&&!this.faultFlags.has(n)){this.event('injection',f.sc,`${f.kind} profile → [${f.target}]`);this.faultFlags.add(n);}
  const snapS=copy(this.bs),snapW=copy(this.bw);
  // Periodic control reads this sample's delivered neighbor measurements.
  // In a healthy unlimited channel this exactly recovers Eq.31 current states.
  if(c.mode==='baseline-time'&&!c.strict)for(let j=0;j<4;j++)if(t>=this.next[j]-h/2&&this.attempts[j]<c.budget&&!lost[j]){snapS[j]=[...ms[j]];snapW[j]=[...mw[j]];}
  for(let i=0;i<4;i++) {
   const direct=c.mode==='baseline-time'&&c.strict;
   const e=coordination(i,ms[i],mw[i],direct?ms:snapS,direct?mw:snapW,ref,p.r);this.errors[i]=e;
   let err=sampledError(this.held[i],e.s),held2=dot(this.held[i],this.held[i]);
   const base=p.delta*held2+this.chi[i]+p.epsilon;
   const diagnosis=this.diag[i];
   const adapt=adaptiveThreshold({...e,severity:c.features.diagnosis?diagnosis.severity*diagnosis.confidence:0,disturbance:c.features.diagnosis?diagnosis.disturbance:0,used:this.attempts[i],budget:c.features.communication?c.budget:Infinity,rate:this.rate[i],dropout:c.features.communication?(env.dropout??0):0},p,base);
   this.threshold[i]=extended&&c.features.adaptive?adapt.threshold:base;
   let fire=false,reason='hold';
   if(c.mode==='baseline-time'){fire=t>=this.next[i]-h/2;reason='periodic 10 Hz';}
   else if(c.mode==='baseline-self'||c.mode==='fault-self'){fire=t>=this.next[i]-h/2;reason=c.mode==='fault-self'?'fault-aware predicted deadline':'repository self-trigger deadline';}
   else {this.evalCount++;fire=t===0||err>=this.threshold[i]||(extended&&this.last[i]!==null&&t-this.last[i]>=p.maxInterval);reason=t===0?'initial update':err>=this.threshold[i]?'sampled coordination error exceeded threshold':'maximum hold interval';}
   this.rate[i]*=Math.exp(-h);
   if(fire) {
    const reliable=c.features.diagnosis&&diagnosis.confidence>.5;
    this.u[i]=control(i,e.s,mw[i],p,extended&&c.features.compensation&&reliable?diagnosis.gamma:null);
    this.held[i]=[...e.s];this.updates[i]++;this.rate[i]++;
    let communication;
    if(this.attempts[i]>=c.budget) {this.denied[i]++;communication='budget exhausted; local update only';}
    else {this.attempts[i]++;if(lost[i]){this.dropped[i]++;communication='packet lost';}else{this.delivered[i]++;this.bs[i]=[...ms[i]];this.bw[i]=[...mw[i]];this.receivedAt[i]=t;communication='broadcast delivered';}}
    let next=null;
    if(c.mode==='baseline-time')next=this.next[i]+.1;
    else if(c.mode==='baseline-self'||c.mode==='fault-self') {
     next=selfNext(i,t,e.s,mw[i],p,h);
     if(c.mode==='fault-self')next=t+clamp((next-t)*Math.sqrt(adapt.scale),h,p.maxInterval);
    }
    if(next!==null)this.next[i]=next;
    this.lastDecision[i]={t,reason,errorSquared:err,threshold:this.threshold[i],coordination:norm(e.s),severity:diagnosis.severity,evidence:diagnosis.confidence,disturbance:diagnosis.disturbance,thresholdScale:extended?adapt.scale:1,communication,interval:this.last[i]===null?null:t-this.last[i],next:next,forecastInterval:next===null?null:next-t};
    this.event('update',i,copy(this.lastDecision[i]));this.last[i]=t;
    err=0;held2=dot(e.s,e.s);
   }
   if(c.mode==='baseline-event'||c.mode==='adaptive'||c.mode==='optimized')this.chi[i]+=h*(-p.beta1*this.chi[i]+p.beta2*(p.delta*held2+p.epsilon-err));
   else if(c.mode!=='baseline-time')this.chi[i]=p.chi0*Math.exp(-(p.beta1+p.beta2)*t);
   if(extended)this.chi[i]=Math.max(0,this.chi[i]);
  }
  const gamma=effectiveness(t,env),gammaHalf=effectiveness(t+h/2,env),gammaEnd=effectiveness(t+h,env),scale=(env.disturbanceBase??1)*(t>=(env.faultTime??20)?env.disturbanceScale??1:1);
  const ae=this.s.map(s=>norm(sub(s,ref.s))),we=this.w.map(w=>norm(sub(w,ref.w)));
  this.maxError=Math.max(this.maxError,...ae);this.maxOvershoot=Math.max(this.maxOvershoot,...ae.map((v,i)=>100*Math.max(0,v/Math.max(1e-12,this.initialErrors[i])-1)));
  this.currentGamma=gamma;this.acceleration=[];
  if(c.record&&t-this.lastFrame>=c.sampleEvery-h/2){this.history.push(this.frame());this.lastFrame=t;}
  this.sqA+=ae.reduce((a,b)=>a+b*b,0)*h;this.sqW+=we.reduce((a,b)=>a+b*b,0)*h;
  if(Math.max(...ae)>.02||Math.max(...we)>.01)this.lastViolation=t+h;
  for(let i=0;i<4;i++) {
   const u=this.u[i].map(v=>clamp(v,-.2,.2));
   this.torqueSum[i]=add(this.torqueSum[i],u);
   this.effort+=dot(u,u)*h;this.saturation+=this.u[i].filter(v=>Math.abs(v)>.2).length*h;this.peak=Math.max(this.peak,...u.map(Math.abs));this.peakCommand=Math.max(this.peakCommand,...this.u[i].map(Math.abs));
   const s=this.s[i],w=this.w[i],der=(tt,ss,ww)=>derivative(tt,ss,ww,u,this.inertia[i],(tt===t+h?gammaEnd:gammaHalf)[i],(env.disturbanceBase??1)*(tt>=(env.faultTime??20)?env.disturbanceScale??1:1),i);
   const a=derivative(t,s,w,u,this.inertia[i],gamma[i],scale,i),b=der(t+h/2,add(s,mul(a.s,h/2)),add(w,mul(a.w,h/2))),cc=der(t+h/2,add(s,mul(b.s,h/2)),add(w,mul(b.w,h/2))),d=der(t+h,add(s,mul(cc.s,h)),add(w,mul(cc.w,h)));
   this.acceleration.push(a.w);
   this.s[i]=s.map((v,k)=>v+h*(a.s[k]+2*b.s[k]+2*cc.s[k]+d.s[k])/6);this.w[i]=w.map((v,k)=>v+h*(a.w[k]+2*b.w[k]+2*cc.w[k]+d.w[k])/6);
   // No silent MRP chart switch: baseline semantics preserved. Divergence is a failed run.
   if(!this.s[i].every(Number.isFinite)||norm(this.s[i])>100||norm(this.w[i])>100){this.failed=true;this.event('failure',i,'numerical divergence / chart limit');}
  }
  this.obsSamples++;this.tick++;this.t=this.tick*h;return true;
 }
 metrics() {
  const t=this.t,ref=reference(t),ae=this.s.map(s=>norm(sub(s,ref.s))),we=this.w.map(w=>norm(sub(w,ref.w)));
  const settled=!this.failed&&t-this.lastViolation>=2&&Math.max(...ae)<=.02&&Math.max(...we)<=.01;
  const lastFault=Math.max(-1,...(this.config.environment.faults??[]).map(f=>f.time+(f.kind==='gradual'?f.duration:0)),...(this.config.environment.dropout||this.config.environment.disturbanceScale?[this.config.environment.faultTime??20]:[]));
  const attempts=this.attempts.reduce((a,b)=>a+b,0),updates=this.updates.reduce((a,b)=>a+b,0),periodic=4*Math.ceil((t-1e-10)/.1);
  return {attitudeRMSE:t?Math.sqrt(this.sqA/(4*t)):0,angularVelocityRMSE:t?Math.sqrt(this.sqW/(4*t)):0,maxAttitudeError:this.maxError,maximumOvershootPercent:this.maxOvershoot,convergenceTime:settled?this.lastViolation:null,success:settled,finalAttitudeError:Math.max(...ae),finalAngularVelocityError:Math.max(...we),controllerUpdates:updates,communicationEvents:attempts,delivered:this.delivered.reduce((a,b)=>a+b,0),dropped:this.dropped.reduce((a,b)=>a+b,0),budgetDenied:this.denied.reduce((a,b)=>a+b,0),communicationSaved:periodic?100*(1-attempts/periodic):0,controlEffort:this.effort,saturationPercent:t?100*this.saturation/(12*t):0,peakTorque:this.peak,peakCommand:this.peakCommand,faultRecoveryTime:lastFault>=0&&t>=lastFault+2&&settled?Math.max(0,this.lastViolation-lastFault):null,triggerEvaluations:this.evalCount,computationUnits:updates*1200+this.evalCount*180+Math.floor(this.tick/this.diagPeriod)*4*6000,failed:this.failed,elapsed:t};
 }
 frame() {
  return {t:this.t,s:copy(this.s),w:copy(this.w),reference:reference(this.t),u:copy(this.u),saturated:this.u.map(u=>u.map(v=>clamp(v,-.2,.2))),gamma:effectiveness(this.t,this.config.environment),coordination:this.errors.map(e=>norm(e.s)),threshold:[...this.threshold],chi:[...this.chi],updates:[...this.updates],attempts:[...this.attempts],delivered:[...this.delivered],age:this.receivedAt.map(t=>this.t-t),diagnosis:this.diag.map(d=>d.snapshot()),decision:copy(this.lastDecision),acceleration:this.s.map((s,i)=>derivative(this.t,s,this.w[i],this.u[i],this.inertia[i],effectiveness(this.t,this.config.environment)[i],(this.config.environment.disturbanceBase??1)*(this.t>=(this.config.environment.faultTime??20)?this.config.environment.disturbanceScale??1:1),i).w),disturbanceTruth:this.s.map((_,i)=>mul(disturbances(this.t,i),(this.config.environment.disturbanceBase??1)*(this.t>=(this.config.environment.faultTime??20)?this.config.environment.disturbanceScale??1:1))),metrics:this.metrics()};
 }
 run() {while(this.step());if(this.config.record)this.history.push(this.frame());return {config:this.config,metrics:this.metrics(),history:this.history,events:this.events,final:this.frame()};}
}
export const simulate=options=>new Simulation(options).run();
