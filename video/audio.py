"""Original 140 BPM percussion, bass and UI sound design. No sampled music."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
DURATION = 12
random.seed(17)
samples = [0.0] * (RATE * DURATION)

def add(start, length, kind, gain=1.0, frequency=100):
    first = int(start * RATE)
    phase = 0.0
    for i in range(int(length * RATE)):
        index = first + i
        if index >= len(samples):
            break
        t = i / RATE
        u = t / length
        if kind == 'kick':
            f = 46 + 115 * math.exp(-t * 45)
            phase += 2 * math.pi * f / RATE
            value = math.sin(phase) * math.exp(-t * 16) + random.uniform(-1, 1) * math.exp(-t * 300) * 0.2
        elif kind == 'hat':
            value = random.uniform(-1, 1) * math.exp(-t * 110)
        elif kind == 'clap':
            value = (random.uniform(-1, 1) * 0.8 + math.sin(2 * math.pi * 190 * t) * 0.2) * math.exp(-t * 32)
        elif kind == 'bass':
            value = (math.sin(2 * math.pi * frequency * t) + 0.22 * math.sin(4 * math.pi * frequency * t)) * min(1, t * 150) * math.exp(-t * 9)
        elif kind == 'tap':
            value = (random.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 1800 * t) * 0.4) * math.exp(-t * 240)
        elif kind == 'chime':
            value = (math.sin(2 * math.pi * frequency * t) + 0.35 * math.sin(2 * math.pi * frequency * 1.5 * t)) * math.exp(-t * 12) * min(1, t * 500)
        else:
            value = random.uniform(-1, 1) * math.sin(math.pi * u) ** 2 * 0.3
        samples[index] += value * gain

beat = 60 / 140
for n in range(28):
    t = n * beat
    add(t, .28, 'kick', .38 if n < 24 else .24)
    add(t + beat / 2, .05, 'hat', .13)
    if n % 2:
        add(t, .15, 'clap', .19)
    add(t + .015, .3, 'bass', .15, [73.416, 73.416, 87.307, 65.406][(n // 4) % 4])
    if n % 4 == 3:
        add(t + beat * .75, .04, 'hat', .08)
for t in [.37, 1.87, 3.15, 4.1, 4.55, 5.24, 6.63, 7.13, 7.54, 8.5]:
    add(t, .05, 'tap', .33)
for t in [1.78, 3.7, 5.16, 7.43, 9.5]:
    add(t, .19, 'whoosh', .17)
for t in [3.22, 6.2, 8.7]:
    add(t, .23, 'chime', .2, 880)
add(10.0, .7, 'chime', .18, 587.33)
add(10.08, .65, 'chime', .14, 880)
peak = max(abs(x) for x in samples)
out = Path(__file__).parent / 'public' / 'soundtrack.wav'
out.parent.mkdir(exist_ok=True)
with wave.open(str(out), 'wb') as wav:
    wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
    frames = bytearray()
    for i, value in enumerate(samples):
        fade = min(1, i / 240, (len(samples) - i) / 4800)
        value = math.tanh(value / max(peak, .6) * 1.4) * .7 * max(0, fade)
        pcm = int(value * 32767)
        frames += struct.pack('<hh', pcm, pcm)
    wav.writeframes(frames)
print(out)
