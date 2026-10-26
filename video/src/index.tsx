import React from 'react';
import {registerRoot, Composition} from 'remotion';
import {Demo} from './Demo';
registerRoot(() => <Composition id="ShiftDemo" component={Demo} width={1920} height={1080} fps={60} durationInFrames={720}/>);
