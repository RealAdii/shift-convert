# Shift demo

A 12 second, 1920 x 1080, 60 fps animated walkthrough of PDF to JPG, crop, and background editing. It uses the app's real wheel and editor renders and actual Converter outputs. It is not a continuous screen recording.

## Rebuild on macOS

```sh
npm ci
npm run assets
npm run audio
npm run stills
npm run render
```

Run these commands from `video/`. `assets` builds the Swift app and writes generated PNGs into `public/`. `audio.py` makes an original 140 BPM percussion, bass and UI sound track without external samples. `render.mjs` renders the Remotion composition to `out/shift-demo.mp4`. Remotion downloads its headless browser on the first render if needed.

The edit follows the supplied reference's warm desktop background and drag, Shift, radial selection, crop and background sequence. The motion graphics digest informed short text beats, rapid object moves and the final circular wipe. No footage or audio from those references is redistributed.

All authored code and generated artwork and audio are covered by the repository's MIT license. The video toolchain dependencies keep their own licenses.
