import {clamp,cross} from './math.mjs';
// Windowed torque balance regression y = gamma*u + unknown torque.
// No true Gamma or disturbance input is accepted by this observer.
export class Diagnosis {
 constructor(inertia,noise=0,window=80) {this.J=inertia;this.noise=noise;this.window=window;this.rows=[];this.gamma=[1,1,1];this.se=[1,1,1];this.residual=[0,0,0];this.severity=0;this.confidence=0;this.status='unobservable';this.axis=0;this.disturbance=0;}
 update(w0,w1,u,dt) {
  const mid=w0.map((v,a)=>(v+w1[a])/2),gyro=cross(mid,mid.map((v,a)=>v*this.J[a]));
  const y=w1.map((v,a)=>this.J[a]*(v-w0[a])/dt+gyro[a]);
  this.rows.push({u:[...u],y});if(this.rows.length>this.window)this.rows.shift();
  this.residual=y.map((v,a)=>v-u[a]);
  const n=this.rows.length;let observable=0;
  for(let a=0;a<3;a++) {
   const xx=this.rows.reduce((s,r)=>s+r.u[a]**2,0),xy=this.rows.reduce((s,r)=>s+r.u[a]*r.y[a],0);
   if(n<10||xx<.0004) {this.se[a]=1;continue;}
   observable++;
   this.gamma[a]=clamp(xy/xx,0,1);
   const sse=this.rows.reduce((s,r)=>s+(r.y[a]-this.gamma[a]*r.u[a])**2,0);
   // Known measurement-noise floor and 0.01 Nm nuisance-torque allowance.
   const variance=Math.max(sse/Math.max(1,n-1),2*(this.J[a]*this.noise/dt)**2,.01**2);
   this.se[a]=Math.sqrt(variance/xx);
  }
  const losses=this.gamma.map((g,a)=>this.se[a]<.25?1-g:0);
  this.axis=losses.indexOf(Math.max(...losses));this.severity=Math.max(...losses);
  // Evidence score: lower 95% normal-approximation loss bound / estimated loss.
  // It is NOT a calibrated probability of fault.
  this.confidence=this.severity>0?clamp((this.severity-1.96*this.se[this.axis])/this.severity,0,1):0;
  const lower=this.severity-1.96*this.se[this.axis];
  this.status=!observable?'unobservable':lower>.65?'critical':lower>.2?'degraded':lower>.08?'warning':'healthy';
  this.disturbance=Math.sqrt(this.rows.at(-1).y.reduce((s,v,a)=>s+(v-this.gamma[a]*u[a])**2,0));
  return this;
 }
 snapshot(){return {gamma:[...this.gamma],se:[...this.se],residual:[...this.residual],severity:this.severity,confidence:this.confidence,status:this.status,axis:this.axis,disturbance:this.disturbance};}
}
