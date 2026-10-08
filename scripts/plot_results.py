"""Static research figures from saved data only. Requires matplotlib + numpy."""
from pathlib import Path
import json, os
os.environ.setdefault('MPLCONFIGDIR','/tmp/formation-matplotlib')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
root=Path(__file__).resolve().parents[1]; out=root/'results/plots';out.mkdir(exist_ok=True)
load=lambda name:json.loads((root/'results'/f'{name}.json').read_text())
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'figure.dpi':160,'savefig.bbox':'tight','axes.grid':True,'grid.alpha':.2})
colors=['#247da3','#d68d27','#7965a9','#2d946c','#cc6760','#415681']
methods=['baseline-time','baseline-event','baseline-self','adaptive','fault-self','optimized']
labels=['Baseline time','Baseline event','Baseline self','Adaptive event','Fault-aware self','Optimized']
def save(fig,name):
 fig.savefig(out/(name+'.png'));fig.savefig(out/(name+'.svg'));plt.close(fig)
fig,axes=plt.subplots(2,2,figsize=(11,7),layout='constrained')
for m,l,c in zip(methods,labels,colors):
 r=load('comparison-'+m);t=np.array([h['t'] for h in r['history']]);err=np.array([np.sqrt(np.mean(np.sum((np.array(h['s'])-h['reference']['s'])**2,axis=1))) for h in r['history']]);werr=np.array([np.sqrt(np.mean(np.sum((np.array(h['w'])-h['reference']['w'])**2,axis=1))) for h in r['history']]);comm=[sum(h['attempts']) for h in r['history']];eff=[h['metrics']['controlEffort'] for h in r['history']]
 for ax,y,title,unit in zip(axes.flat,[err,werr,comm,eff],['Attitude tracking','Angular velocity tracking','Attempted broadcasts','Integrated control effort'],['MRP RMS','rad/s RMS','Broadcasts','N² m² s']):
  ax.plot(t,y,label=l,color=c,lw=1.2);ax.set(title=title,xlabel='Time (s)',ylabel=unit);ax.axvline(20,color='k',ls=':',lw=.8)
axes[0,0].legend(fontsize=8);fig.suptitle('Combined fault + packet loss | seed 42 | 60 s | dt = 0.01 s')
save(fig,'combined-history')
mc=load('monte-carlo');ms=list(mc['summary']);fig,axes=plt.subplots(1,3,figsize=(13,4),layout='constrained')
data=[[r['metrics']['attitudeRMSE'] for r in mc['rows'] if r['mode']==m] for m in ms]
axes[0].boxplot(data,tick_labels=['Time','Event','Self','Adaptive','Optimized'],showmeans=True);axes[0].set(title='Paired Monte Carlo tracking',ylabel='Attitude RMSE (MRP)')
for i,(m,v) in enumerate(zip(ms,data)):axes[1].step(sorted(v),np.arange(1,101)/100,label=m,color=colors[i],where='post')
axes[1].set(title='Empirical distribution',xlabel='Attitude RMSE (MRP)',ylabel='Cumulative fraction');axes[1].legend(fontsize=7)
axes[2].bar(['Time','Event','Self','Adaptive','Optimized'],[mc['summary'][m]['successRate']*100 for m in ms],color=colors[:5]);axes[2].set(title='Terminal settling success',ylabel='Success rate (%)',ylim=(0,110))
for i,m in enumerate(ms):axes[2].text(i,mc['summary'][m]['successRate']*100+2,f"{mc['summary'][m]['successRate']*100:.0f}%",ha='center')
fig.suptitle('100 paired randomized scenarios | seeds 2026–2125 | 500 total runs')
save(fig,'monte-carlo')
ex=load('experiments')['rows'];rows=[r for r in ex if r['scenario']=='combined'];fig,axes=plt.subplots(1,3,figsize=(13,4),layout='constrained')
for ax,key,title in zip(axes,['communicationEvents','controlEffort','computationUnits'],['Broadcast attempts','Control effort (N² m² s)','Modeled computation units']):
 for i,r in enumerate(rows):ax.scatter(r['metrics'][key],r['metrics']['attitudeRMSE'],color=colors[i],s=40);ax.annotate(str(i+1),(r['metrics'][key],r['metrics']['attitudeRMSE']),xytext=(5,3),textcoords='offset points')
 frontier=[p for p in rows if not any(q['metrics'][key]<=p['metrics'][key] and q['metrics']['attitudeRMSE']<=p['metrics']['attitudeRMSE'] and (q['metrics'][key]<p['metrics'][key] or q['metrics']['attitudeRMSE']<p['metrics']['attitudeRMSE']) for q in rows)];frontier.sort(key=lambda r:r['metrics'][key]);ax.plot([r['metrics'][key] for r in frontier],[r['metrics']['attitudeRMSE'] for r in frontier],ls='--',color='#8b9aa3');ax.set(xlabel=title,ylabel='Attitude RMSE (MRP)')
fig.suptitle('Combined mission Pareto views | 1 Time · 2 Event · 3 Self · 4 Adaptive · 5 Fault-self · 6 Optimized')
save(fig,'pareto')
ab=load('ablation');fig,axes=plt.subplots(1,3,figsize=(12,4),layout='constrained')
for ax,k,title in zip(axes,['attitudeRMSE','communicationEvents','controlEffort'],['Attitude RMSE (MRP)','Broadcast attempts','Control effort (N² m² s)']):ax.bar(list('ABCDEF'),[r['metrics'][k] for r in ab],color=colors);ax.set(ylabel=title,xlabel='A baseline / B trigger / C severity / D comm / E tuning / F full')
fig.suptitle('Ablation | same combined mission | contributions are not uniformly beneficial')
save(fig,'ablation')
opt=load('optimization');fig,ax=plt.subplots(figsize=(7,4),layout='constrained');y=[p['objective'] for p in opt['history']];ax.plot(range(1,len(y)+1),y,'.',color='#8a9ca9',label='Evaluated candidates');ax.plot(range(1,len(y)+1),np.minimum.accumulate(y),color='#247da3',label='Best so far');ax.set(xlabel='Candidate evaluation',ylabel='Normalized weighted training objective',title='NSGA-II search | training seeds 101–102');ax.legend();save(fig,'optimization')
print('Generated 5 figures, each PNG + SVG.')
