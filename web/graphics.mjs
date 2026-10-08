import {rotation,add,mul,norm,sub} from '../src/math.mjs';
import {A} from '../src/scenarios.mjs';
export const COLORS=['#62d8f0','#efc56e','#ad9ce5','#8bd1a6'];
export function canvasSize(canvas){const r=canvas.getBoundingClientRect(),d=Math.min(devicePixelRatio||1,2);if(canvas.width!==Math.round(r.width*d)||canvas.height!==Math.round(r.height*d)){canvas.width=Math.round(r.width*d);canvas.height=Math.round(r.height*d);}const ctx=canvas.getContext('2d');ctx.setTransform(d,0,0,d,0,0);return {ctx,w:r.width,h:r.height};}
export class FormationView {
 constructor(canvas,onSelect){this.canvas=canvas;this.yaw=.24;this.pitch=.42;this.zoom=1;this.pan=[0,0];this.focus=-1;this.follow=false;this.trails=Array.from({length:4},()=>[]);this.points=[];this.onSelect=onSelect;let drag=null;
 canvas.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,shift:e.shiftKey,moved:0};canvas.setPointerCapture(e.pointerId);};
 canvas.onpointermove=e=>{if(!drag)return;const dx=e.clientX-drag.x,dy=e.clientY-drag.y;drag.moved+=Math.abs(dx)+Math.abs(dy);if(drag.shift){this.pan[0]+=dx;this.pan[1]+=dy;}else {this.yaw+=dx*.006;this.pitch=Math.max(-1,Math.min(1,this.pitch+dy*.006));}drag.x=e.clientX;drag.y=e.clientY;};
 canvas.onpointerup=e=>{if(drag&&drag.moved<5){const r=canvas.getBoundingClientRect();let best=-1,d=45;this.points.forEach((p,i)=>{const v=Math.hypot(p[0]-e.clientX+r.left,p[1]-e.clientY+r.top);if(v<d){d=v;best=i;}});if(best>=0)onSelect(best);}drag=null;};
 canvas.onwheel=e=>{e.preventDefault();this.zoom=Math.max(.5,Math.min(2.5,this.zoom*Math.exp(-e.deltaY*.001)));};
 canvas.onkeydown=e=>{if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','+','-'].includes(e.key))e.preventDefault();if(e.shiftKey&&e.key.startsWith('Arrow')){this.pan[0]+=e.key==='ArrowLeft'?-15:e.key==='ArrowRight'?15:0;this.pan[1]+=e.key==='ArrowUp'?-15:e.key==='ArrowDown'?15:0;return;}if(e.key==='ArrowLeft')this.yaw-=.1;if(e.key==='ArrowRight')this.yaw+=.1;if(e.key==='ArrowUp')this.pitch+=.1;if(e.key==='ArrowDown')this.pitch-=.1;if(e.key==='+')this.zoom=Math.min(2.5,this.zoom+.1);if(e.key==='-')this.zoom=Math.max(.5,this.zoom-.1);};
 }
 reset(){this.yaw=.24;this.pitch=.42;this.zoom=1;this.pan=[0,0];this.focus=-1;this.follow=false;}
 draw(frame,selected,history=[]) {
 const {ctx:c,w,h}=canvasSize(this.canvas);if(!w||!h)return;c.clearRect(0,0,w,h);c.fillStyle='#09121c';c.fillRect(0,0,w,h);
 const positions=[[-2.1,0,-1.3],[1.9,.2,-1.2],[-1.65,.1,1.7],[1.8,0,1.6]];
 const origin=this.focus<0?[0,0,0]:positions[this.focus];
 const yaw=this.follow?this.yaw+Math.atan2(frame.s[selected][1],frame.s[selected][0]):this.yaw;
 const project=p=>{const a=sub(p,origin),x=a[0]*Math.cos(yaw)-a[2]*Math.sin(yaw),z=a[0]*Math.sin(yaw)+a[2]*Math.cos(yaw),y=a[1]*Math.cos(this.pitch)-z*Math.sin(this.pitch),zz=a[1]*Math.sin(this.pitch)+z*Math.cos(this.pitch);const k=Math.min(w/7.8,h/5.5)*this.zoom*9/(9+zz);return [w/2+x*k+this.pan[0],h*.57-y*k+this.pan[1],zz];};
 const line=(a,b,color,width=1,dash=[])=>{a=project(a);b=project(b);c.strokeStyle=color;c.lineWidth=width;c.setLineDash(dash);c.beginPath();c.moveTo(...a.slice(0,2));c.lineTo(...b.slice(0,2));c.stroke();c.setLineDash([]);};
 for(let k=-8;k<=8;k++){line([k,-.8,-8],[k,-.8,8],'#193041',.6);line([-8,-.8,k],[8,-.8,k],'#193041',.6);}
 const ring=(radius,color)=>{c.beginPath();for(let j=0;j<=100;j++){const p=project([radius*Math.cos(j*Math.PI/50),-.79,radius*Math.sin(j*Math.PI/50)]);j?c.lineTo(p[0],p[1]):c.moveTo(p[0],p[1]);}c.strokeStyle=color;c.lineWidth=.8;c.stroke();};ring(2.9,'#305364');ring(4.2,'#203849');
 this.points=positions.map(project);
 for(let i=0;i<4;i++)for(let j=0;j<4;j++)if(A[i][j]){const flash=frame.decision[j]&&frame.t-frame.decision[j].t<.18,isolated=frame.age[j]>3;line(positions[j],positions[i],isolated?'#685a44':flash?'#8bd1a6':'#335b67',flash?1.8:1,isolated?[3,6]:[5,7]);const a=this.points[j],b=this.points[i],x=a[0]*.25+b[0]*.75,y=a[1]*.25+b[1]*.75,angle=Math.atan2(b[1]-a[1],b[0]-a[0]);c.fillStyle='#71999f';c.beginPath();c.moveTo(x,y);c.lineTo(x-7*Math.cos(angle-.4),y-7*Math.sin(angle-.4));c.lineTo(x-7*Math.cos(angle+.4),y-7*Math.sin(angle+.4));c.fill();}
 for(const i of [0,1,2,3].sort((a,b)=>this.points[b][2]-this.points[a][2])){
  const R=rotation(frame.s[i]),o=positions[i],world=p=>add(o,R.map(row=>row.reduce((v,x,k)=>v+x*p[k],0)));
  const face=(vertices,fill,stroke='#6e8b9a')=>{c.beginPath();vertices.forEach((v,j)=>{const p=project(world(v));j?c.lineTo(p[0],p[1]):c.moveTo(p[0],p[1]);});c.closePath();c.fillStyle=fill;c.fill();c.strokeStyle=stroke;c.lineWidth=.8;c.stroke();};
  const color=frame.diagnosis[i].status==='critical'?'#ff827e':frame.diagnosis[i].status==='degraded'?'#efc56e':COLORS[i];
  const [x,y]=this.points[i];c.beginPath();c.ellipse(x,y+15,50*this.zoom,17*this.zoom,0,0,Math.PI*2);c.strokeStyle=i===selected?color:'#2b4351';c.lineWidth=i===selected?1.5:.6;c.stroke();
  const recent=history.filter(f=>f.t<=frame.t&&f.t>frame.t-6).filter((_,n)=>n%3===0);c.beginPath();recent.forEach((f,n)=>{const r=rotation(f.s[i]),v=project(add(o,r.map(row=>row[0]*.7)));n?c.lineTo(v[0],v[1]):c.moveTo(v[0],v[1]);});c.strokeStyle=color+'66';c.stroke();
  for(const side of [-1,1]){const x1=side*.3,x2=side*1.05;face([[x1,-.2,0],[x2,-.2,0],[x2,.2,0],[x1,.2,0]],'#123953','#4a92b3');for(let k=1;k<6;k++){const q=x1+(x2-x1)*k/6;line(world([q,-.2,0]),world([q,.2,0]),'#3e7691',.5);}line(world([x1,0,0]),world([x2,0,0]),'#3e7691',.5);}
  const v=[[-.27,-.22,-.23],[.27,-.22,-.23],[.27,.22,-.23],[-.27,.22,-.23],[-.27,-.22,.23],[.27,-.22,.23],[.27,.22,.23],[-.27,.22,.23]];
  [[0,1,2,3],[0,1,5,4],[1,2,6,5],[2,3,7,6],[4,5,6,7]].forEach((f,n)=>face(f.map(k=>v[k]),['#718391','#516776','#96a7ae','#b9c5c9','#778f9b'][n]));
  line(world([0,0,.23]),world([0,0,.58]),'#bdccd0',1.5);for(const [axis,col] of [[0,'#62d8f0'],[1,'#8bd1a6'],[2,'#ad9ce5']]){const v=[0,0,0];v[axis]=.7;line(o,world(v),col,1.3);}
  line(o,add(o,mul(frame.w[i],5)),'#efc56e',2);
  const rd=rotation(frame.reference.s);line(o,add(o,rd.map(row=>row[0]*.9)),'#b8d7e5',1,[2,4]);
  c.fillStyle=color;c.font='11px monospace';c.textAlign='center';c.fillText(`SC${i+1}`,x,y-45*this.zoom);c.fillStyle='#97b0bf';c.font='8px monospace';c.fillText(frame.age[i]>3?'LINK STALE':frame.diagnosis[i].status.toUpperCase(),x,y-32*this.zoom);
 }
 c.textAlign='left';c.font='8px monospace';c.fillStyle='#8296a6';c.fillText('DRAG ROTATE / SHIFT-DRAG PAN / SCROLL ZOOM',18,h-40);
 }
}
export function lineChart(canvas,series,{xLabel='Mission time / s',yLabel='',cursor=null}={}) {
 const {ctx:c,w,h}=canvasSize(canvas);c.clearRect(0,0,w,h);const legendCols=Math.max(1,Math.floor((w-64)/140)),legendRows=Math.ceil(series.length/legendCols);const m={l:64,r:24,t:15+legendRows*14,b:35},W=w-m.l-m.r,H=h-m.t-m.b;
 const all=series.flatMap(s=>s.points),xmax=Math.max(.00001,...all.map(p=>p[0])),ymin=Math.min(0,...all.map(p=>p[1])),ymax=Math.max(.00001,...all.map(p=>p[1])),span=ymax-ymin||1;
 c.font='9px monospace';c.textAlign='left';for(let k=0;k<=4;k++){const y=m.t+H*k/4;c.strokeStyle='#243440';c.beginPath();c.moveTo(m.l,y);c.lineTo(w-m.r,y);c.stroke();c.fillStyle='#9badbc';c.fillText((ymax-span*k/4).toPrecision(3),5,y+3);c.fillText((xmax*k/4).toPrecision(2),m.l+W*k/4-5,h-18);}
 for(const [i,s] of series.entries()){c.strokeStyle=s.color??COLORS[i%4];c.lineWidth=1.5;c.beginPath();s.points.forEach(([x,y],n)=>{const px=m.l+x/xmax*W,py=m.t+(ymax-y)/span*H;n?c.lineTo(px,py):c.moveTo(px,py);});c.stroke();c.fillStyle=s.color??COLORS[i%4];c.fillText(s.name,m.l+(i%legendCols)*140,13+Math.floor(i/legendCols)*14);}
 if(cursor!==null){c.strokeStyle='#d5e8f066';c.setLineDash([3,4]);c.beginPath();c.moveTo(m.l+cursor/xmax*W,m.t);c.lineTo(m.l+cursor/xmax*W,m.t+H);c.stroke();c.setLineDash([]);}
 c.fillStyle='#9badbc';c.fillText(xLabel,w/2-40,h-3);if(yLabel)c.fillText(yLabel,5,13);
}
export function scatter(canvas,rows,xkey,ykey,xLabel,yLabel) {
 const {ctx:c,w,h}=canvasSize(canvas);c.clearRect(0,0,w,h);const mx=Math.max(1,...rows.map(r=>r.metrics[xkey])),my=Math.max(.001,...rows.map(r=>r.metrics[ykey]));c.font='10px monospace';c.fillStyle='#9badbc';c.fillText(yLabel,16,20);c.fillText(xLabel,w/2-45,h-10);c.strokeStyle='#344955';c.strokeRect(48,36,w-75,h-80);
 const frontier=rows.filter(p=>!rows.some(q=>q.metrics[xkey]<=p.metrics[xkey]&&q.metrics[ykey]<=p.metrics[ykey]&&(q.metrics[xkey]<p.metrics[xkey]||q.metrics[ykey]<p.metrics[ykey]))).sort((a,b)=>a.metrics[xkey]-b.metrics[xkey]);
 const point=r=>[48+r.metrics[xkey]/mx*(w-75),h-44-r.metrics[ykey]/my*(h-80)];c.beginPath();frontier.forEach((r,i)=>{const [x,y]=point(r);i?c.lineTo(x,y):c.moveTo(x,y);});c.strokeStyle='#62d8f077';c.stroke();
 rows.forEach((r,i)=>{const [x,y]=point(r);c.fillStyle=COLORS[i%4];c.beginPath();c.arc(x,y,4,0,Math.PI*2);c.fill();c.fillText((i+1).toString(),x+7,y+4);});c.fillStyle='#9badbc';c.fillText('0',30,h-40);c.fillText(mx.toPrecision(3),w-70,h-28);c.fillText(my.toPrecision(3),5,40);
}
