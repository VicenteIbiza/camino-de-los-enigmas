# -*- coding: utf-8 -*-
"""Records the narration with offline neural voices (Piper, Castilian Spanish) and writes Ogg clips
for Godot into godot/audio/voz/.

    pip install piper-tts soundfile numpy
    python3 tools/voz/generar.py MODELS_DIR

MODELS_DIR holds the voices es_ES-miro-high, es_ES-sharvard-medium and es_ES-davefx-medium
(from the sherpa-onnx "tts-models" release or the Piper voice collection).
"""
import glob, os, re, subprocess, sys, tempfile, wave
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt
from piper import PiperVoice, SynthesisConfig
from guion import LINES, ROOT

# character -> (model, speaker, length scale, pitch in semitones, extra filter)
VOICES = {
    "narrador": ("miro-high", None, float(os.environ.get("LS", "1.15")), float(os.environ.get("SEMIS", "-1.5")), os.environ.get("STYLE", "epic")),
    "remigio": ("davefx-medium", None, 0.98, 0.8, ""),
    "anselmo": ("davefx-medium", None, 1.06, -0.6, ""),
    "rufino": ("sharvard-medium", 0, 1.0, -0.4, ""),
    "tobias": ("sharvard-medium", 0, 1.12, -2.0, ",aecho=0.8:0.6:90|160:0.35|0.22"),
    "petra": ("sharvard-medium", 1, 1.0, 0.0, ""),
    "brunilda": ("sharvard-medium", 1, 1.04, -1.6, ""),
    "alba": ("sharvard-medium", 1, 1.1, -0.6, ""),
    "lucia": ("sharvard-medium", 1, 0.96, 2.2, ""),
}
# pause after each sentence, by how it ends (seconds)
PAUSE = {".": 0.42, "…": 0.6, "?": 0.38, "!": 0.32, ":": 0.3}
EPIC_PAUSE = {".": 0.7, "…": 0.95, "?": 0.6, "!": 0.55, ":": 0.45}
SR = 32000
# story lines get a music bed under the voice; the timpani opens the boss lines
BED = ("intro_", "boss_", "final")


def hall(seconds=2.4, decay=0.75):
    """Impulse response of a big stone hall: dark, decaying noise after a short pre-delay."""
    rng = np.random.default_rng(7)
    t = np.arange(int(SR * seconds)) / SR
    ir = rng.standard_normal(t.size) * np.exp(-t / decay * 3.0)
    ir = sosfilt(butter(2, 3500, "low", fs=SR, output="sos"), ir)
    ir = np.concatenate([np.zeros(int(SR * 0.025)), ir])
    ir[0] = 0.0
    return ir / np.sqrt((ir ** 2).sum())


def saw(f, n, detune):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune, 0.0, detune):
        ph = (t * f * (1 + d)) % 1.0
        out += 2 * ph - 1
    return out / 3


def strings_bed(n, timpani=False):
    """Slow D minor string pad (i - VI - III - VII) with swells, for the narrator's story lines."""
    chords = [[73.42, 110.0, 146.83, 174.61, 220.0], [58.27, 116.54, 146.83, 174.61, 233.08],
              [87.31, 130.81, 174.61, 220.0, 261.63], [65.41, 130.81, 164.81, 196.0, 261.63]]
    seg = int(SR * 4.5)
    bed = np.zeros(n)
    for k, start in enumerate(range(0, n, seg)):
        m = min(seg + int(SR * 1.5), n - start)
        tone = sum(saw(f, m, 0.004) * (0.9 if i == 0 else 0.55) for i, f in enumerate(chords[k % 4]))
        env = np.minimum(1.0, np.arange(m) / (SR * 1.4)) * np.minimum(1.0, (m - np.arange(m)) / (SR * 1.4))
        bed[start:start + m] += tone * env
    bed = sosfilt(butter(2, 900, "low", fs=SR, output="sos"), bed)
    t = np.arange(n) / SR
    bed *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t)
    if timpani:
        for at, g in ((0.0, 1.0), (0.35, 0.6), (0.55, 1.0)):
            i = int(at * SR)
            m = min(int(SR * 1.6), n - i)
            tt = np.arange(m) / SR
            f = 62 * (1 + 0.25 * np.exp(-tt * 18))
            hit = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 4.5) * g
            hit += np.random.default_rng(i).standard_normal(m) * np.exp(-tt * 30) * 0.15 * g
            bed[i:i + m] += hit * 2.2
    bed *= np.minimum(1.0, (n - np.arange(n)) / (SR * 2.0))
    return bed / (np.abs(bed).max() + 1e-9)


def epic(voice, cid):
    """Deep storyteller in a stone hall, with strings underneath the story lines."""
    voice = voice / (np.abs(voice).max() + 1e-9)
    wet = fftconvolve(voice, hall())[: voice.size + int(SR * 2.0)]
    dry = np.concatenate([voice, np.zeros(wet.size - voice.size)])
    # the hall only on the story lines; gameplay lines stay dry so every word is clear
    wet_amount = float(os.environ.get("WET", "0.12")) if cid.startswith(BED) else 0.0
    mix = dry * 0.85 + wet / (np.abs(wet).max() + 1e-9) * wet_amount
    if cid.startswith(BED):
        lead = int(SR * (2.4 if cid.startswith("boss_") else 0.9))
        mix = np.concatenate([np.zeros(lead), mix])
        mix += strings_bed(mix.size, cid.startswith("boss_")) * 0.09
    return mix / (np.abs(mix).max() + 1e-9) * 0.9


def speakable(t):
    t = t.replace("«", "").replace("»", "").replace("—", ", ")
    # words in capitals (¡PUM!, ¡CRAAC!) are shouted words, not acronyms
    t = re.sub(r"\b([A-ZÁÉÍÓÚÑ]{2,})\b", lambda m: m.group(1).capitalize(), t)
    return t


def sentences(t):
    parts = re.findall(r"[^.!?…:]+(?:[.!?…:]+[»\"]?|$)", t)
    return [p.strip() for p in parts if p.strip()]


def main(models):
    out_dir = os.path.join(ROOT, "godot", "audio", "voz")
    os.makedirs(out_dir, exist_ok=True)
    loaded = {}
    only = set(sys.argv[2:])
    for cid, who, text in LINES:
        if only and cid not in only:
            continue
        model, spk, ls, semis, extra = VOICES[who]
        if model not in loaded:
            path = glob.glob(os.path.join(models, "*es_ES-%s*" % model, "*.onnx"))[0]
            loaded[model] = PiperVoice.load(path)
        voice = loaded[model]
        cfg = SynthesisConfig(speaker_id=spk, length_scale=ls, noise_scale=0.62, noise_w_scale=0.85)
        sr = voice.config.sample_rate
        pcm = [np.zeros(int(sr * 0.15), np.int16)]
        for s in sentences(speakable(text)):
            for chunk in voice.synthesize(s, syn_config=cfg):
                pcm.append(chunk.audio_int16_array)
            end = s.rstrip("»\"")[-1]
            pcm.append(np.zeros(int(sr * (EPIC_PAUSE if extra == "epic" else PAUSE).get(end, 0.3)), np.int16))
        audio = np.concatenate(pcm)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            tmp = f.name
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(audio.tobytes())
        # a little warmth and room so it sounds like a storyteller, not a phone menu
        filt = "highpass=f=70,lowpass=f=9000,equalizer=f=180:t=q:w=1:g=2,equalizer=f=3200:t=q:w=1.2:g=1.5"
        if semis:
            filt = "rubberband=pitch=%.4f:formant=preserved," % (2 ** (semis / 12.0)) + filt
        dst = os.path.join(out_dir, cid + ".ogg")
        if extra == "epic":
            # deeper and warmer, then the hall and the strings are added here in numpy
            filt += ",equalizer=f=110:t=q:w=1:g=3,acompressor=threshold=0.12:ratio=3:attack=8:release=180"
            mid = tmp + ".mid.wav"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", filt, "-ar", str(SR), "-ac", "1", mid], check=True)
            import soundfile as sf
            v, _ = sf.read(mid)
            sf.write(mid, epic(v, cid), SR)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mid, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", str(SR), "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
            os.unlink(mid)
            os.unlink(tmp)
            print(cid, who, "%.1f s" % (len(audio) / sr))
            continue
        filt += extra + ",aecho=0.9:0.5:28|51:0.12|0.07,loudnorm=I=-17:TP=-1.5:LRA=9"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", filt, "-ar", "32000", "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
        os.unlink(tmp)
        print(cid, who, "%.1f s" % (len(audio) / sr))


if __name__ == "__main__":
    main(sys.argv[1])
