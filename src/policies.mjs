import {norm,dot,clamp,sub} from './math.mjs';
import {A,B,J} from './scenarios.mjs';
export const MODES=['baseline-time','baseline-event','baseline-self','adaptive','fault-self','optimized'];
export function coordination(i,s,w,bs,bw,ref,r) {
 const e1=s.map((v,a)=>B[i]*(v-ref.s[a])),e2=w.map((v,a)=>B[i]*(v-ref.w[a]));
 for(let j=0;j<4;j++)if(A[i][j])for(let a=0;a<3;a++){e1[a]+=s[a]-bs[j][a];e2[a]+=w[a]-bw[j][a];}
 return {e1,e2,s:e1.map((v,a)=>r*v+e2[a])};
}
export function gains(i,p) {const d=A[i].reduce((a,b)=>a+b,0)+B[i];return [p.gainScale*2*(p.gamma*p.beta1+p.beta2)/d,(p.k0+1)/(d*p.delta)];}
export function control(i,s,w,p,estimate=null) {
 const [k1,k2]=gains(i,p),phi=1+norm(w)+dot(w,w);
 return s.map((v,a)=>(-k1*v-k2*p.alpha*phi*Math.sign(v))/(estimate?clamp(estimate[a],.35,1):1));
}
export function selfNext(i,t,s,w,p,dt,factor=2) {
 const [k1,k2]=gains(i,p),den=factor/Math.min(...J[i])*(5*k1*norm(s)+(5*k2+1)*p.alpha*(1+norm(w)+dot(w,w)));
 let next=t;for(let n=0;n<60;n++)next=t+Math.sqrt(p.delta*dot(s,s)+p.chi0*Math.exp(-(p.beta1+p.beta2)*next)+p.epsilon)/den;
 return Math.max(t+dt,next);
}
export function adaptiveThreshold({s,e1,e2,severity,disturbance,used,budget,rate,dropout},p,base) {
 const pressure=Number.isFinite(budget)?used/Math.max(1,budget):0;
 const demand=p.errorWeight*(norm(s)+norm(e1)+norm(e2))+p.faultWeight*severity+p.disturbanceWeight*Math.min(5,disturbance/.01);
 const resource=p.commWeight*(pressure+Math.min(2,rate/20)+dropout);
 const scale=clamp((1+resource)/(1+demand),.05,3);
 return {threshold:Math.max(1e-9,base*scale),scale,demand,resource};
}
export const sampledError=(held,s)=>dot(sub(held,s),sub(held,s));
