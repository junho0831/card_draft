#!/usr/bin/env python3
"""Sample-free original score and procedural SFX. Python 3 + numpy + ffmpeg.
No recording, soundfont, downloaded sample, model or network input is used.
"""
import hashlib
import json
import re
import subprocess
import tempfile
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/original_v1'
SR = 32000
RNG = np.random.default_rng(20260910)
REPORT = {}

def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)

def tone(midi, duration, kind='bell'):
    t = np.arange(round(SR * duration)) / SR
    f = hz(midi)
    if kind == 'pad':
        x = sum(np.sin(2*np.pi*f*r*t + .18*np.sin(2*np.pi*.31*t)) * g
                for r, g in [(1,.65),(2,.19),(3,.08),(1.002,.14)])
        env = np.minimum(t/.35, 1) * np.minimum((duration-t)/.65, 1)
    elif kind == 'horn':
        x = sum(np.sin(2*np.pi*f*k*t)*(.65/k**1.5) for k in range(1,7))
        env = np.minimum(t/.09,1)*np.minimum((duration-t)/.24,1)
    else:
        x = sum(np.sin(2*np.pi*f*r*t)*g*np.exp(-t*d)
                for r,g,d in [(1,.7,2.5),(2,.2,5),(3.01,.1,8)])
        env = np.minimum(t/.008,1)*np.minimum((duration-t)/.08,1)
    return x * np.clip(env,0,1)

def noise(duration):
    x = RNG.normal(0,.28,round(SR*duration))
    return np.convolve(x,np.ones(5)/5,'same')

def drum(duration=.6, strength=1):
    t=np.arange(round(SR*duration))/SR
    phase=2*np.pi*(48*t+42*.035*(1-np.exp(-t/.035)))
    return strength*(.65*np.sin(phase)*np.exp(-t*8)+noise(duration)*np.exp(-t*28)) * np.minimum(t/.003,1)

def place(track, sound, start, gain=1, pan=0, loop=False):
    start=round(start*SR)
    pos=np.arange(len(sound))+start
    if loop:
        pos%=len(track)
    else:
        valid=pos<len(track);pos=pos[valid];sound=sound[valid]
    track[pos,0]+=sound*gain*np.sqrt((1-pan)/2)
    track[pos,1]+=sound*gain*np.sqrt((1+pan)/2)

def reverb(x, loop=False):
    y=x.copy()
    for seconds,g in [(.113,.16),(.227,.11),(.371,.07)]:
        n=round(seconds*SR)
        if loop:
            y+=np.roll(x[:,::-1],n,axis=0)*g
        else:
            y[n:]+=x[:-n,::-1]*g
    return y

def write(name,x,loop=False):
    x=reverb(x,loop)
    x-=x.mean(axis=0)
    peak=float(np.max(np.abs(x)))
    x*=.76/max(peak,1e-9)
    # A 5 ms boundary ramp protects against codec seam transients.
    edge=round(SR*.005)
    x[:edge]*=np.linspace(0,1,edge)[:,None]
    x[-edge:]*=np.linspace(1,0,edge)[:,None]
    with tempfile.TemporaryDirectory(prefix='card-draft-audio-') as temp:
        path=Path(temp)/'render.wav'
        with wave.open(str(path),'wb') as w:
            w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
            w.writeframes((x*32767).astype('<i2').tobytes())
        dest=OUT/f'{name}.ogg'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','5',str(dest)],check=True)
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(dest),'-f','f32le','-acodec','pcm_f32le','-'])
        decoded=np.frombuffer(raw,dtype='<f4')
        assert np.all(np.isfinite(decoded)) and np.max(np.abs(decoded))<.99, name
        REPORT[name]={'seconds':round(len(x)/SR,3),'loop':loop,'peak_dbfs':round(float(20*np.log10(np.max(np.abs(decoded)))),2),'rms_dbfs':round(float(20*np.log10(np.sqrt(np.mean(decoded**2)))),2),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}

def score():
    # 16 bars, 80 BPM, D minor with an original sparse six-note motif.
    # All four battle layers share tempo, harmony and exact duration.
    beat=.75; bar=4*beat; duration=16*bar
    chords=[(50,57,65),(46,53,62),(53,60,69),(48,55,64)]*4
    motif=[(0,74),(.75,69),(1.75,77),(2.5,76),(3.0,65),(3.5,72)]
    tracks={k:np.zeros((round(duration*SR),2)) for k in ['menu_theme','battle_base','battle_tension','battle_lethal','battle_low_hp']}
    for b,chord in enumerate(chords):
        for j,note in enumerate(chord):
            pad=tone(note,bar+1,'pad')
            for k in ['menu_theme','battle_base']:
                place(tracks[k],pad,b*bar,.15 if k=='menu_theme' else .12,(j-1)*.48,True)
        for step in range(8):
            note=chord[[0,1,2,1,0,2,1,2][step]]+12
            place(tracks['battle_base'],tone(note,.68),b*bar+step*beat/2,.095,(-1)**step*.3,True)
        if b%2==0:
            for offset,note in motif:
                place(tracks['menu_theme'],tone(note+(0 if b%4==0 else -2),1.7),b*bar+offset*beat,.17,.18,True)
        for offset in [0,1.5,2,3.5]:
            place(tracks['battle_tension'],drum(),b*bar+offset*beat,.6,0,True)
        for offset in [0,2]:
            place(tracks['battle_base'],drum(),b*bar+offset*beat,.17,0,True)
            place(tracks['battle_low_hp'],drum(.45),b*bar+offset*beat,.7,-.12,True)
            place(tracks['battle_low_hp'],drum(.3),b*bar+(offset+.35)*beat,.35,.12,True)
        if b%2==1:
            for j,note in enumerate([chord[1]+12,chord[2]+12,chord[0]+24]):
                place(tracks['battle_lethal'],tone(note,1.05,'horn'),b*bar+j*beat,.25,(j-1)*.2,True)
    for k,x in tracks.items():write(k,x,True)

def effect(name,index):
    bright=('elf' in name or name in ['heal','reward','combo'])
    dark=('undead' in name or 'death' in name or name=='defeat')
    base=57 if bright else 38 if dark else 45
    base+=index%3
    if name in ['hover','click','draw','play']:
        dur={'hover':.08,'click':.15,'draw':.32,'play':.34}[name]
        t=np.arange(round(SR*dur))/SR
        x=np.zeros((len(t),2));swish=noise(dur)*np.sin(np.pi*t/dur)**2
        place(x,swish,0,.5)
        place(x,tone(69 if name in ['hover','click'] else 45,dur),0,.18)
    elif name.startswith('hit') or name in ['impact_heavy','counter','direct_attack']:
        dur=.75 if name=='impact_heavy' else .45
        x=np.zeros((round(SR*dur),2))
        place(x,drum(dur),0,.8)
        t=np.arange(round(SR*dur))/SR
        ring=sum(np.sin(2*np.pi*f*t)*np.exp(-t*d) for f,d in [(hz(base+19),15),(hz(base+31)*1.07,22),(hz(base+38)*1.03,28)])
        place(x,ring,0,.18)
    else:
        celebratory=name in ['victory','victory_burst','reward','defeat']
        powerful=name.startswith('power') or name in ['finisher','victory_burst']
        dur=3.2 if celebratory else 1.6 if powerful else .85
        x=np.zeros((round(SR*dur),2))
        notes=[base+12,base+19,base+24,base+27] if not dark else [base+19,base+15,base+12,base]
        if name.startswith('equipment'):notes=[base+24,base+31];dur_note=.38
        else:dur_note=.8 if celebratory else .45
        for j,n in enumerate(notes):
            place(x,tone(n,dur_note,'horn' if powerful else 'bell'),j*(.3 if celebratory else .09),.3,(j/len(notes)-.5)*.7)
        if powerful or name.startswith('summon') or name=='summon':place(x,drum(.55),.08,.7)
        if name.startswith('spell') or name=='spell':
            t=np.arange(round(SR*.65))/SR
            place(x,noise(.65)*np.sin(np.pi*t/.65)**2,0,.45 if 'fire' in name else .18)
    write(name,x)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    keys=re.findall(r'streams\["([a-z_]+)"\] =', (ROOT/'src/services/audio_manager.gd').read_text().split('func _generate_all_sounds()')[1].split('func _generate_all_music()')[0])
    score()
    for i,key in enumerate(keys):effect(key,i)
    (OUT/'manifest.json').write_text(json.dumps({'generator':'tools/compose_original_audio.py','seed':20260910,'sample_rate':SR,'source':'Mathematical synthesis only; no third-party audio inputs','music':{'title':'Embers at the Border','bpm':80,'bars':16,'seconds':48},'files':REPORT},ensure_ascii=False,indent=2)+'\n')
    print(f'PASS: {len(REPORT)} original audio assets; decoded peak below -0.09 dBFS; finite samples.')
