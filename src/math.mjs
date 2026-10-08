export const add=(a,b)=>a.map((v,i)=>v+b[i]);
export const sub=(a,b)=>a.map((v,i)=>v-b[i]);
export const mul=(a,k)=>a.map(v=>v*k);
export const dot=(a,b)=>a.reduce((v,x,i)=>v+x*b[i],0);
export const norm=a=>Math.sqrt(dot(a,a));
export const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
export const clamp=(v,l,h)=>Math.max(l,Math.min(h,v));
export const copy=a=>structuredClone(a);
export function kinematics(s,w) {return add(add(mul(w,.25*(1-dot(s,s))),mul(cross(s,w),.5)),mul(s,.5*dot(s,w)));}
export function reference(t) {
 const s=[3+2*Math.sin(.1*t),5+3*Math.cos(.2*t),-2+Math.cos(.1*t)].map(v=>v*.001);
 const ds=[.2*Math.cos(.1*t),-.6*Math.sin(.2*t),-.1*Math.sin(.1*t)].map(v=>v*.001);
 // G G' = (1+s's)^2 I/16. Transpose reverses the skew term.
 const w=mul(add(add(mul(ds,.25*(1-dot(s,s))),mul(cross(s,ds),-.5)),mul(s,.5*dot(s,ds))),16/(1+dot(s,s))**2);
 return {s,w};
}
export function rotation(s) {
 const d=1+dot(s,s),[x,y,z]=mul(s,2/d),w=(1-dot(s,s))/d;
 return [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]];
}
export function rng(seed=1) {let a=seed>>>0;return ()=>{a+=0x6D2B79F5;let t=a;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return ((t^t>>>14)>>>0)/4294967296;};}
export function normal(r) {return Math.sqrt(-2*Math.log(Math.max(1e-12,r())))*Math.cos(2*Math.PI*r());}
