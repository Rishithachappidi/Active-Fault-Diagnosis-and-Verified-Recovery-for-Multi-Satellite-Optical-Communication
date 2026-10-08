import {Simulation,simulate} from '../src/engine.mjs';
import {optimize,monteCarlo} from '../src/research.mjs';
self.onmessage=({data})=>{try{const progress=p=>postMessage({type:'progress',...p});let result;
 if(data.task==='run'){const s=new Simulation(data.options);while(s.step()){if(s.tick%1000===0)progress({done:s.tick,total:s.steps});}s.history.push(s.frame());result={config:s.config,metrics:s.metrics(),history:s.history,events:s.events,final:s.frame()};}
 else if(data.task==='optimize')result=optimize(data.options,progress);
 else if(data.task==='monte-carlo')result=monteCarlo(data.options,progress);
 else if(data.task==='compare'){result=[];const modes=['baseline-time','baseline-event','baseline-self','adaptive','fault-self','optimized'];for(const [k,mode] of modes.entries()){result.push(simulate({...data.options,mode,params:mode==='optimized'?data.options.params:{}}));progress({done:k+1,total:6});}}
 else throw Error('Unknown worker task');postMessage({type:'complete',task:data.task,result});
}catch(e){postMessage({type:'error',message:e.message});}};
