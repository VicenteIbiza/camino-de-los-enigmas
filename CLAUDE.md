# El Camino de los Enigmas — notas para continuar

Juego de tablero 3D cooperativo de adivinanzas, acertijos, problemas y retos de habilidad, de **ES GAMES**.
Lo crea un padre con su hijo de 10 años, muy listo. Todo el juego y su texto van en **castellano de España**.
Se juega en iPhone/iPad en horizontal.

## Dónde está cada cosa

- `godot/`: el juego actual, en Godot 4.3 (renderer Compatibility, GDScript, export web sin hilos).
  - `main.gd`: tablero, héroes, turnos, jefes, minijefes, misiones, tienda, niveles, vidas, introducción y HUD.
  - `question_panel.gd`: ventana de preguntas (escritas, de opciones y retos de habilidad), con Pista y Reloj.
  - `quest_box.gd`: ventana de misiones. `modal_box.gd`: tienda, bolsa y subida de nivel. `narrator.gd`: voz y subtítulos.
  - `data/preguntas.json`, `data/misiones.json`, `data/narracion.json` (subtítulos de la narración).
  - `audio/voz/*.ogg`: narración grabada. `assets/`: modelos KayKit (CC0), retratos, fuentes, icono y logo de ES GAMES.
- `tools/voz/`: `guion.py` (todos los textos hablados) y `generar.py` (los graba con voces Piper es_ES).
- `docs/`: versión web exportada, servida por GitHub Pages (https://vicenteibiza.github.io/camino-de-los-enigmas/).
- `web/el-camino-de-los-enigmas.html`: versión antigua en three.js (v17); fuente de reglas y datos ya portados.

## Reglas actuales

- **Jugadores:** de 1 a 4 en el mismo dispositivo, por turnos. Hay 5 héroes con modelo: Auron, Ragnar, Ignara, Sylwen y Vex.
- **Tiradas:** hasta 3 tiradas por turno mientras se acierte.
- **Fallar:** retrocedes 2 casillas, salvo si estás frente a un jefe o minijefe. En ese caso te quedas y en tu siguiente turno vuelves a luchar («¡A la lucha!»).
- **Jefes** (Trol, Gólem, Dragón):
  - Los dados de porcentaje fijan el nivel del desafío.
  - Si aciertas, haces daño; si fallas, pierdes de ½ a 2 corazones según ese nivel.
- **Minijefes:** cuatro esqueletos escondidos. Lanzan maldiciones a quien pasa por su casilla y retan a duelo a quien se para en ella. Si pierdes el duelo, pierdes ½ corazón.
- **Vidas:** se cuentan en medios corazones. Empiezas con 3 corazones y ganas uno más en los niveles 4, 7 y 10. La posada te cura del todo.
- **Si caes:**
  - El Elixir de vida te levanta solo.
  - Un compañero que llega a tu casilla (también con el Portal) te levanta con 2 corazones.
  - Si no, Doña Petra te lleva a la posada y pierdes 2 estrellas.
- **Cooperar:** los héroes que comparten casilla cooperan.
  - Si uno acierta, todos ganan estrella y experiencia.
  - Contra un jefe, cada compañero suma +1 de daño.
  - En las tiradas de misión, cada compañero suma +10.
- **Experiencia:** necesitas 30 + nivel×20 para subir; el nivel máximo es el 10.
  - Al subir eliges un atributo: Fuerza (+1 de daño), Sabiduría (+5 s por pregunta) o Suerte (+1 al dado de las maldiciones).
- **Tienda** (Remigio, casilla ◈): la bolsa tiene 3 huecos. Vende pista, reloj de arena, dado doble, escudo, portal, dado trucado, espada de fuego, poción y elixir.

## Cómo compilar y publicar

1. Descarga Godot 4.3 estable y sus plantillas web.
2. Ejecuta `godot --headless --import` dentro de `godot/`.
3. Exporta con `godot --headless --export-release "Web" ../docs/index.html`.
4. Borra los `*.import` que aparezcan en `docs/`.

Al subir `docs/` a `main`, GitHub Pages publica la versión pública.

La narración se regenera con `python3 tools/voz/generar.py CARPETA_MODELOS [ids…]`:
- **Requisitos:** `pip install piper-tts soundfile numpy scipy` y ffmpeg con rubberband.
- **Modelos:** las voces `es_ES-miro-high`, `es_ES-sharvard-medium` y `es_ES-davefx-medium`, del release «tts-models» de k2-fsa/sherpa-onnx en GitHub.
- **Subtítulos:** después ejecuta `python3 tools/voz/guion.py`, que actualiza `godot/data/narracion.json`.
- **El narrador** («El Cronista») tiene que sonar épico pero entenderse bien:
  - La voz va 1,5 semitonos más grave y lenta, con 1.15.
  - La introducción, los jefes y el final llevan cuerdas en re menor, timbales y un eco muy suave.
  - Las frases de las misiones van sin eco: con eco se entienden mucho peor.

## Pendiente

- **Juego en línea con código de partida.** Está aparcado hasta tener una cuenta nueva de Supabase: la cuenta actual ya tiene 2 proyectos gratis. La idea es esta:
  - Una tabla de partidas con el estado por jugador.
  - El jugador del turno escribe y los demás leen.
  - El estado de cada jugador ya está separado en `players` / `PFIELDS` dentro de `main.gd`.
- **Más contenido:** los otros 5 retos de habilidad de la versión web (laberinto, minas, deslizante, atrapa, sudoku), más misiones en el tablero, un dragón con modelo de verdad y los otros 7 héroes del arte (Elara, Morvath, Kaida, Bronn, Drakon, Nyra, Thalion).
- **Fase A:** app de iOS compilada en la nube con GitHub Actions (macOS) y TestFlight. Necesita cuenta de Apple Developer, de 99 €/año.

## Normas

- **Textos:** usa las ideas de los libros de aventuras de Devir solo como inspiración. Nunca copies textos ni nombres con derechos.
- **Público:** el juego es para niños. Las preguntas deben ser claras y las explicaciones, amables.
