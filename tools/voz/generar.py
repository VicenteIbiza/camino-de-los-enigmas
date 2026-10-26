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
from piper import PiperVoice, SynthesisConfig
from guion import LINES, ROOT

# character -> (model, speaker, length scale, pitch in semitones, extra filter)
VOICES = {
    "narrador": ("miro-high", None, 1.1, 0.0, ""),
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
            pcm.append(np.zeros(int(sr * PAUSE.get(end, 0.3)), np.int16))
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
        filt += extra + ",aecho=0.9:0.5:28|51:0.12|0.07,loudnorm=I=-17:TP=-1.5:LRA=9"
        dst = os.path.join(out_dir, cid + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", filt, "-ar", "32000", "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
        os.unlink(tmp)
        print(cid, who, "%.1f s" % (len(audio) / sr))


if __name__ == "__main__":
    main(sys.argv[1])
