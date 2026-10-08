import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const manifest=JSON.parse(readFileSync(new URL('../baseline/manifest.json',import.meta.url)));
for(const [path,expected] of Object.entries(manifest)) {
 const actualPath=['index.html','README.md'].includes(path)?'baseline/'+path:path;
 const actual=createHash('sha256').update(readFileSync(new URL('../'+actualPath,import.meta.url))).digest('hex');
 if(actual!==expected) throw Error(`Original changed: ${path}`);
}
console.log(`All ${Object.keys(manifest).length} original artifacts preserved.`);
