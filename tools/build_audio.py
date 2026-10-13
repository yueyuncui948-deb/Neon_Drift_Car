"""Generate original looping motor/skid sounds with Python's standard library."""
import math
import random
import struct
import wave
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
out.mkdir(parents=True, exist_ok=True)
rate = 22050
rng = random.Random(1701)
for name in ['motor', 'skid']:
    values = []
    filtered = 0.0
    for i in range(rate):
        t = i / rate
        if name == 'motor':
            value = .42*math.sin(2*math.pi*65*t)+.20*math.sin(2*math.pi*130*t)+.1*math.sin(2*math.pi*260*t)
        else:
            filtered = filtered*.7+rng.uniform(-1,1)*.3
            value = filtered*.65+.07*math.sin(2*math.pi*1100*t)
            value *= min(1, i/200, (rate-1-i)/200)
        values.append(struct.pack('<h',int(max(-1,min(1,value))*32767)))
    with wave.open(str(out / f'{name}.wav'),'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(b''.join(values))
print('Generated original motor and skid WAV loops')
