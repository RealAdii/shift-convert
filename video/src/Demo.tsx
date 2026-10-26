import React from 'react';
import {AbsoluteFill, Audio, Easing, Img, interpolate, staticFile, useCurrentFrame} from 'remotion';

const ease = Easing.bezier(0.18, 0.85, 0.22, 1);
const progress = (f:number, a:number, b:number) => interpolate(f,[a,b],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp',easing:ease});
const lerp = (a:number,b:number,t:number) => a+(b-a)*t;
const ink = '#222321';
const font = '-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif';

const ShiftMark:React.FC<{size?:number}> = ({size=70}) => <svg width={size} height={size} viewBox="0 0 80 80" fill="none"><path d="M40 8L9 39H28V69H52V39H71L40 8Z" stroke="currentColor" strokeWidth="6" strokeLinejoin="round"/></svg>;
const Cursor:React.FC<{x:number,y:number,down?:boolean}> = ({x,y,down=true}) => <div style={{position:'absolute',left:x,top:y,zIndex:30,filter:'drop-shadow(0 3px 3px #0005)'}}><svg width="40" height="52" viewBox="0 0 40 52"><path d="M4 3V38L14 29L22 47L29 44L21 27H35Z" fill="#171817" stroke="white" strokeWidth="2.6" strokeLinejoin="round"/></svg>{down&&<div style={{position:'absolute',left:24,top:31,width:25,height:25,borderRadius:50,background:'#28b956',color:'white',fontSize:25,lineHeight:'24px',textAlign:'center',fontWeight:600}}>+</div>}</div>;
const File:React.FC<{x:number,y:number,name:string,asset?:string,scale?:number,selected?:boolean,opacity?:number}> = ({x,y,name,asset='document.png',scale=1,selected=false,opacity=1}) => <div style={{position:'absolute',left:x,top:y,width:180,transform:`translate(-50%,-50%) scale(${scale})`,opacity,textAlign:'center',zIndex:selected?25:10}}><div style={{display:'inline-flex',padding:5,borderRadius:5,background:'white',boxShadow:'0 8px 16px #38222738'}}><Img src={staticFile(asset)} style={{width:78,height:asset==='document.png'?104:78,objectFit:'contain'}}/></div><div style={{fontSize:18,fontWeight:600,color:'white',textShadow:'0 1px 3px #0009',marginTop:9,lineHeight:1.25}}><span style={{padding:'2px 5px',background:selected?'#176bdc':'transparent',borderRadius:3}}>{name}</span></div></div>;
const Key:React.FC<{f:number,start:number,label?:string}> = ({f,start,label='tap shift'}) => {
 const p=progress(f,start,start+8), out=progress(f,start+36,start+44); const down=f>=start+7&&f<start+15;
 return <div style={{position:'absolute',left:120,bottom:125,display:'flex',alignItems:'center',gap:20,opacity:p*(1-out),transform:`translateY(${(1-p)*15}px)`,zIndex:40}}><div style={{background:down?'#fc905e':'#fffdf1',color:ink,width:89,height:77,display:'grid',placeItems:'center',borderRadius:16,boxShadow:`0 ${down?2:7}px 0 #b8a68f,0 12px 22px #0002`,transform:`translateY(${down?5:0}px)`}}><ShiftMark size={43}/></div><span style={{fontSize:28,fontWeight:550,color:'white',textShadow:'0 2px 8px #0003'}}>{label}</span></div>;
};
const Wheel:React.FC<{state:string,x?:number,y?:number,scale?:number,opacity?:number}> = ({state,x=1100,y=530,scale=1,opacity=1}) => <Img src={staticFile(state+'.png')} style={{position:'absolute',left:x-253.5,top:y-285,width:507,height:572,transform:`scale(${scale})`,opacity,zIndex:15}}/>;
const Heading:React.FC<{children:React.ReactNode,small?:string,color?:string}> = ({children,small,color='white'}) => <div style={{position:'absolute',left:118,top:136,zIndex:20,color}}>{small&&<div style={{fontSize:17,fontWeight:600,letterSpacing:3,marginBottom:18,opacity:.8}}>{small}</div>}<div style={{fontSize:110,fontWeight:650,letterSpacing:-6,lineHeight:1.02}}>{children}</div></div>;
const Editor:React.FC<{asset:string,f:number,start:number}> = ({asset,f,start}) => {const p=progress(f,start,start+10); return <div style={{position:'absolute',left:960,top:530,transform:`translate(-50%,-50%) translateY(${30*(1-p)}px) scale(${lerp(.96,1,p)})`,opacity:p,zIndex:20,borderRadius:24,overflow:'hidden',boxShadow:'0 24px 80px #44210c50'}}><Img src={staticFile(asset)} style={{width:510,display:'block'}}/></div>};

export const Demo:React.FC = () => {
 const f=useCurrentFrame();
 const drag=progress(f,22,82);
 const hover=progress(f,137,166);
 const cropDrag=progress(f,255,283);
 const end=progress(f,571,600);
 const sourceX=lerp(650,1100,drag), sourceY=lerp(570,530,drag);
 return <AbsoluteFill style={{fontFamily:font,color:ink,background:'#f6f4ec',overflow:'hidden'}}>
  <Audio src={staticFile('soundtrack.wav')}/>
  {f<600&&<AbsoluteFill style={{background:'radial-gradient(ellipse at 64% 112%,#b7b0e5 0%,transparent 52%),radial-gradient(ellipse at 8% 88%,#fa3549 0%,transparent 57%),radial-gradient(ellipse at 40% -12%,#ffce64 0%,transparent 55%),linear-gradient(120deg,#f0a254,#b46c39 75%,#96739c)',transform:`scale(${1+f*.000035})`}}/>}
  {f<558&&<div style={{position:'absolute',top:23,left:40,right:40,display:'flex',justifyContent:'space-between',color:'#fff9',fontSize:14,fontWeight:550,zIndex:3}}><div style={{display:'flex',gap:24}}><span>⇧</span><span>Shift</span><span style={{fontWeight:400}}>Your desktop, fewer steps.</span></div><span>LOCAL FILES / LOCAL MAGIC</span></div>}

  {f<111&&<>
   <Heading small="NO UPLOAD. NO DETOUR.">drag.</Heading>
   <File x={650} y={570} name="Field notes.pdf" opacity={1-drag*.45}/>
   {f>=22&&<><File x={sourceX} y={sourceY} name="Field notes.pdf" selected scale={.9}/><Cursor x={sourceX+16} y={sourceY+20}/></>}
  </>}
  {f>=111&&f<225&&<>
   <Heading>shift.</Heading>
   <File x={650} y={570} name="Field notes.pdf"/>
   <Wheel state={f<153?'formats-idle':'formats-jpg'} opacity={progress(f,111,119)*(1-progress(f,198,208))} scale={lerp(.91,1,progress(f,111,123))}/>
   {f<192&&<><File x={lerp(1100,1218,hover)} y={lerp(530,434,hover)} name="Field notes.pdf" selected scale={.66}/><Cursor x={lerp(1116,1234,hover)} y={lerp(550,454,hover)}/></>}
   {f>=192&&<><File x={1100} y={610} name="Field notes.jpg" scale={lerp(.85,1,progress(f,192,202))}/><Cursor x={1234} y={454} down={false}/><div style={{position:'absolute',left:1022,top:728,color:'white',fontSize:19,fontWeight:600}}>✓ saved beside original</div></>}
   <Key f={f} start={105}/>
  </>}
  {f>=225&&f<315&&<>
   <Heading>crop.</Heading>
   <File x={650} y={570} name="Field notes.jpg"/>
   {f>=241&&<Wheel state={f<271?'tools-idle':'tools-crop'} opacity={progress(f,241,250)*(1-progress(f,298,307))} scale={lerp(.93,1,progress(f,241,253))}/>}
   <File x={lerp(1100,1100,cropDrag)} y={lerp(530,383,cropDrag)} name="Field notes.jpg" selected scale={.66}/><Cursor x={1116} y={lerp(550,403,cropDrag)}/>
   <Key f={f} start={238} label="shift again"/>
  </>}
  {f>=315&&f<398&&<>
   <Heading small="KEEP THE GOOD PART.">crop.</Heading>
   <Editor asset="editor-crop.png" f={f} start={315}/>
   <Cursor x={1130} y={f<355?745:805} down={false}/>
  </>}
  {f>=398&&f<451&&<>
   <Heading>add color.</Heading>
   <Wheel state={f<420?'tools-idle':'tools-add-background'} opacity={1-progress(f,440,450)}/>
   <File x={lerp(1100,1230,progress(f,400,430))} y={lerp(530,608,progress(f,400,430))} asset="cropped.png" name="Field notes Cropped.jpg" selected scale={.64}/>
   <Cursor x={lerp(1116,1246,progress(f,400,430))} y={lerp(550,628,progress(f,400,430))}/>
   <Key f={f} start={398}/>
  </>}
  {f>=451&&f<523&&<>
   <Heading>little glow-up.</Heading>
   <Editor asset="editor-background.png" f={f} start={451}/>
   <Cursor x={1150} y={794} down={false}/>
  </>}
  {f>=523&&f<600&&<>
   <Heading small="RIGHT WHERE YOU STARTED.">done.</Heading>
   {['Field notes.pdf','Field notes.jpg','Cropped.jpg','With background.png'].map((name,i)=>{
    const p=progress(f,523+i*6,537+i*6);
    return <File key={name} x={610+i*260} y={600+(1-p)*50} name={name} asset={i<2?'document.png':i===2?'cropped.png':'background.png'} scale={1.45} opacity={p}/>;
   })}
  </>}
  {f>=571&&f<601&&<div style={{position:'absolute',left:'50%',top:'50%',width:2300,height:2300,borderRadius:'50%',background:'#f6f4ec',transform:`translate(-50%,-50%) scale(${end})`,zIndex:60}}/>}
  {f>=600&&<AbsoluteFill style={{alignItems:'center',justifyContent:'center',background:'#f6f4ec'}}>
   <div style={{display:'flex',alignItems:'center',gap:30,transform:`translateY(${(1-progress(f,600,611))*16}px)`,opacity:progress(f,600,608)}}><ShiftMark size={132}/><span style={{fontSize:185,fontWeight:700,letterSpacing:-10}}>shift</span><span style={{fontSize:22,alignSelf:'flex-start',marginTop:39,fontWeight:500,border:'1.5px solid #222321',borderRadius:30,padding:'8px 16px'}}>for Mac</span></div>
   <div style={{fontSize:42,letterSpacing:-1,marginTop:25}}>drag. shift. done.</div>
   <div style={{fontSize:25,color:'#66675e',marginTop:46}}>Free. Local. Open source.</div>
   <div style={{position:'absolute',bottom:92,fontSize:23,fontWeight:550,letterSpacing:.1}}>github.com/RealAdii/shift-convert</div>
  </AbsoluteFill>}
 </AbsoluteFill>;
};
