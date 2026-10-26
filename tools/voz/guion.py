# -*- coding: utf-8 -*-
"""Narration script: every line the game speaks aloud.

Each entry is (clip id, character, text). The narrator tells the story; quest givers speak their
own lines. Quest texts come from godot/data/misiones.json so the subtitles always match the voice.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

INTRO = [
    "Hace mucho tiempo, cuando los caminos aún no tenían nombre, este reino vivía en paz. "
    "En lo alto del castillo brillaba la Biblioteca del Saber, y quien tuviera una pregunta, allí encontraba su respuesta.",
    "Pero una noche de tormenta llegó el Dragón Carmesí. Se adueñó del castillo, apagó una a una las luces de la biblioteca… "
    "y llenó los caminos de trampas, acertijos y preguntas sin respuesta.",
    "Desde entonces, el Trol del Puente vigila la entrada del bosque. Y más adelante, el Gólem de Cristal guarda el camino que lleva al castillo. "
    "Nadie ha conseguido pasar.",
    "Y no os fiéis de las casillas tranquilas. En algunas duermen esqueletos que se despiertan en cuanto alguien pasa de largo.",
    "Por eso os hemos llamado a vosotros. No hace falta la espada más afilada, sino la mente más despierta. "
    "Si pensáis con calma y os ayudáis unos a otros, el reino volverá a brillar. ¿Preparados? Empieza la aventura.",
]

LINES = [("intro_%d" % (i + 1), "narrador", t) for i, t in enumerate(INTRO)] + [
    ("boss_troll", "narrador", "Bajo el puente asoma el Trol, enorme y gruñón. Nadie cruza sin vencerle… y solo una mente rápida puede conseguirlo."),
    ("boss_golem", "narrador", "El Gólem de Cristal se levanta entre destellos. Cada respuesta acertada le abrirá una grieta."),
    ("boss_dragon", "narrador", "Por fin, el Dragón Carmesí. Sus ojos arden como brasas. Es el último desafío: pensad bien cada respuesta."),
    ("final", "narrador", "Lo habéis conseguido. El Dragón Carmesí huye más allá de las montañas, y en lo alto del castillo, "
     "la Biblioteca del Saber vuelve a encenderse, ventana a ventana. Esta noche, todo el reino celebra vuestra hazaña. "
     "Y recordad siempre: no hay espada más fuerte que una mente despierta."),
    ("nivel", "narrador", "¡Te has hecho más fuerte! Elige en qué quieres mejorar."),
    ("tienda", "remigio", "¡Pasad, pasad! Tengo pistas, relojes de arena, dados de todas clases… y una espada que quema solo de mirarla. Vosotros elegís."),
    ("tienda_pobre", "remigio", "Uy, sin estrellas no hay trato, amigo. Vuelve cuando tengas alguna más."),
]

# quest giver -> voice character
GIVER = {
    "Doña Petra, la posadera": "petra", "Brunilda, la enana minera": "brunilda", "Tío Anselmo, el granjero": "anselmo",
    "Rufino, el montañero": "rufino", "El fantasma del abuelo Tobías": "tobias", "Lucía, la nieta invisible": "lucia",
    "Hermana Alba, la guardiana": "alba",
}
QUESTS = ["posada", "mina", "granja", "invierno", "ermita"]

quests = json.load(open(os.path.join(ROOT, "godot", "data", "misiones.json"), encoding="utf8"))
for qid in QUESTS:
    q = quests[qid]
    for ci, part in enumerate(q.get("chapters", [q])):
        giver = part.get("giver", q["giver"])["name"]
        LINES.append(("q_%s_%d" % (qid, ci), GIVER[giver], part["text"]))
        for k, ch in enumerate(part["choices"]):
            LINES.append(("q_%s_%d_%d_si" % (qid, ci, k), "narrador", ch["win"]))
            if ch.get("lose"):
                LINES.append(("q_%s_%d_%d_no" % (qid, ci, k), "narrador", ch["lose"]))

NAMES = {"narrador": "El Cronista", "remigio": "Remigio, el buhonero"}

if __name__ == "__main__":
    # subtitles for the game: clip id -> who speaks and what they say
    data = {cid: {"who": NAMES.get(who, ""), "text": text} for cid, who, text in LINES if not cid.startswith("q_")}
    with open(os.path.join(ROOT, "godot", "data", "narracion.json"), "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(len(data), "líneas")
