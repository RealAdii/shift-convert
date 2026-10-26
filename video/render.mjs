import {bundle} from '@remotion/bundler';
import {renderMedia, renderStill, selectComposition} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
fs.mkdirSync('out', {recursive:true});
const serveUrl = await bundle({entryPoint:path.resolve('src/index.tsx')});
const composition = await selectComposition({serveUrl,id:'ShiftDemo'});
if (process.argv.includes('--stills')) {
  for (const frame of [30,130,173,207,278,350,429,480,555,660]) {
    await renderStill({serveUrl,composition,frame,output:path.resolve(`out/frame-${frame}.png`),scale:0.5});
    console.log(`Rendered frame ${frame}`);
  }
} else {
  await renderMedia({serveUrl,composition,codec:'h264',outputLocation:path.resolve('out/shift-demo.mp4'),crf:16,x264Preset:'medium',pixelFormat:'yuv420p',colorSpace:'bt709',concurrency:4,onProgress:({progress})=>{if(Math.floor(progress*100)%10===0)process.stdout.write(`\rRendering ${Math.round(progress*100)}%`);}});
  console.log('\nRendered out/shift-demo.mp4');
}
