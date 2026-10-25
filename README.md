# El Camino de los Enigmas

Juego de tablero cooperativo de acertijos, adivinanzas y retos para 1 a 4 jugadores, de **ES GAMES**.

## Contenido

| Carpeta | Qué hay |
|---|---|
| `godot/` | El juego en el motor **Godot 4.3**: tablero hexagonal en 3D, héroes animados, posada y mazmorra. |
| `web/` | La versión anterior, hecha en el navegador con three.js: preguntas, jefes, misiones, tienda y fichas de héroe. |

## Abrir el proyecto de Godot

1. Descarga Godot 4.3 (versión estándar) desde https://godotengine.org.
2. En el gestor de proyectos pulsa **Importar** y elige `godot/project.godot`.
3. Pulsa **F5** para jugar.

## Exportar la versión web

Con las plantillas de exportación de Godot 4.3 instaladas:

```
godot --headless --path godot --export-release "Web" build/index.html
```

La exportación usa la variante sin hilos (`thread_support=false`), que funciona en el Safari del iPhone sin cabeceras especiales.

## Créditos

- Modelos 3D: packs **KayKit** de Kay Lousberg (Adventurers, Medieval Hexagon y Dungeon Remastered), licencia CC0. Ver `godot/assets/LICENSE-KayKit-*.txt`.
- Fuentes: Grenze, Grenze Gotisch y Atkinson Hyperlegible, licencia SIL Open Font License 1.1.
- Retratos de los héroes y logo: ES GAMES.
