# CONTEXT.md — Estructura de la aplicación windenergy

Sitio web estático (sin build step, sin framework, sin `package.json`) para
**ACM‑SL** (Automated Computing Machinery SL), publicado en GitHub Pages bajo
el dominio propio `www.acm-sl.com` (fichero `CNAME`). Repo:
`github.com/jslrpharo/windenergy`, rama `main` servida directamente.

Contenido: formación técnica sobre aerogeneradores — simuladores en tiempo
real, tutoriales, herramientas de ingeniería (análisis de tren de potencia,
convertidores DFIG back‑to‑back, visualizador de datos), y páginas SEO por
tema. Todo en 6 idiomas: `en, es, fr, de, it, pt`.

## 1. Página principal — `index.html` (~350 KB, monolítico)

`index.html` es una "SPA en un solo fichero": todas las secciones existen
como `<section id="...">` dentro de `<main>` y se muestran/ocultan con JS
(no hay rutas reales ni recarga de página al navegar entre secciones).

- **Landing** (`#landing`): grid de tarjetas (`.card`, clase `grid-6`) — el
  punto de entrada visual. Cada tarjeta es un `<a href="...">` (con
  `data-target` opcional) o un `<button data-target="...">` cuando no tiene
  una página HTML propia (p. ej. "Videos", "Our Training Approach").
- **Navegación por tarjetas**: `document.querySelectorAll('.card[data-target]')`
  intercepta el click (`preventDefault`) y llama a `showSection(id)`, que
  activa la `<section>` correspondiente, actualiza el breadcrumb
  (`renderBreadcrumb`/`_navStack`) y el `<title>`. `goHome()` vuelve a
  landing. Ver funciones sobre la línea 4430–4520.
- **i18n embebido**: por cada idioma hay un
  `<script id="i18n-XX" type="application/json">{ "clave": "texto", ... }</script>`
  (bloques `i18n-en`, `i18n-es`, `i18n-fr`, `i18n-de`, `i18n-it`, `i18n-pt`,
  alrededor de las líneas 2177–3780). `applyI18n(lang)` carga el diccionario
  y aplica:
  - `data-i18n="clave"` → `innerHTML` (o `placeholder` en `<input>`)
  - `data-i18n-placeholder="clave"` → `placeholder`
  - `data-i18n-href="clave"` → `href` (para enlazar a ficheros distintos
    según idioma, ver más abajo)
  - `data-bg-lang-pattern="img/foo-{lang}.png"` → sustituye `{lang}` e
    inyecta `background-image`
  - Enlaces `a[href*="tutorials/"]` se reescriben vía
    `localizeTutorialHref()` usando el mapa `TUTORIAL_PAGE_PATHS`.

  **Importante**: las 6 claves de cada bloque `i18n-XX` deben coincidir
  exactamente con las del bloque `i18n-en` (incluido el nombre de la clave,
  que nunca se traduce). Es fácil que una traducción quede huérfana o que se
  traduzca el nombre de la clave por error (p. ej. ocurrió con
  `languagename` → `nombre.idioma` en varios idiomas, y con
  `simuladorDFIG.50hz/60hz` en fr). Al tocar textos, verificar que el
  conjunto de claves siga siendo idéntico en los 6 bloques.

- **Selección de idioma**: `?lang=XX` en la URL, si no, `navigator.language`,
  si no `en` (ver bloque `DOMContentLoaded` cerca de la línea 5006). **No se
  persiste** en `localStorage`; por eso los enlaces internos (Home, Contact,
  Training Guide, tarjetas "Read more"/"Leer más", etc.) añaden
  `?lang=${lang}` manualmente al construir su `href`.
- **Overlay de bienvenida** (`#acmsl-welcome-overlay`): modal de primera
  visita con enlaces por perfil de usuario (estudiante, profesor,
  profesional...). Se oculta permanentemente una vez cerrado, usando
  `localStorage` (`OVERLAY_KEY`).
- **Buscador**: `#searchInput`/`#searchBtn`, alimentado por el bloque
  `<script id="searchKeywords" type="application/json">` (línea ~2143), que
  mapea listas de palabras clave a un `section` (id interno) o a una URL
  externa (`section: "archivo.html"`). Lo mantiene
  `extract_tutorial_keywords.py` (ver §5).
- **Vídeos**: modal `#videoModal` + `initVideosOnce()`, alimentado por
  `configurations/videos/videos-XX.xml` (uno por idioma).

## 2. Páginas de tema individuales (SEO) — un único fichero por tema

La mayoría de páginas de nivel raíz (`conceptos-energia-eolica.html`,
`parques-eolicos-red-electrica.html`, `simuladores-aerogeneradores-tiempo-real.html`,
`analisis-tren-potencia-aerogeneradores.html`,
`convertidores-back-to-back-dfig.html`,
`visualizacion-datos-aerogeneradores.html`,
`tutoriales-aerogeneradores.html`, `mantenimiento-aerogeneradores.html`,
`descargas-simuladores-aerogeneradores.html`,
`clientes-formacion-aerogeneradores.html`, `desarrollos.html`,
`articulos-referencias-tecnicas.html`, `contacto.html`, `formulario.html`,
`formulario-descarga.html`, `controlador-aerogenerador.html`,
`datalogger-dl1300-aerogeneradores.html`, `generador-programable-red-trifasica.html`,
`doble-tacometro-industrial-alta-resolucion.html`, `simulador-bonus-1300.html`,
`404.html`, `politica-cookies.html`, `politica-privacidad.html`) siguen un
**segundo patrón de i18n**, distinto al de `index.html`:

- Un único fichero HTML (no uno por idioma) que incluye `seo-i18n.js`.
- Ese script trae traducciones **comunes** (`COMMON`) más un diccionario
  específico de la página en un `<script id="XX" type="application/json">`
  al final del `<body>` — mismo mecanismo `data-i18n`/`?lang=`, prioridad
  `?lang=` → idioma del navegador → `en`.
- Cargan además `cookie-consent.css/js` (banner de cookies) y
  `legal-links.js` (añade enlaces de pie de página legal traducidos según
  `document.documentElement.lang`).

`Template_descripcion_equipos.html` es la plantilla base para crear nuevas
fichas de producto/equipo con esta misma estructura.

## 3. Páginas con fichero físico por idioma (patrón distinto — ¡ojo!)

Un pequeño grupo de páginas **no** usa diccionarios JS, sino un fichero HTML
separado por idioma:

- `our-training-approach.html` (en) + `-de`, `-es`, `-fr`, `-it`, `-pt`
- `ACMSL_Wind_Turbine_Training_Program.html` (en) + `-de`, `-es`, `-fr`,
  `-it`, `-pt`

Desde `index.html`, la tarjeta/sección que enlaza a estos ficheros usa
`data-i18n-href="card.grid.href12"` / `"training.card.program.href"`, cuyo
valor en cada bloque `i18n-XX` apunta al fichero `-XX.html` correspondiente
(p. ej. `"card.grid.href12": "our-training-approach-es.html"` en el bloque
`i18n-es`). Si se añade un idioma nuevo hay que crear el fichero **y** la
entrada `data-i18n-href` en los 6 bloques; si se edita el contenido hay que
tocar los 6 ficheros por separado (no hay una única fuente de verdad).

La tarjeta "Our Training Approach" está actualmente la primera del grid en
`index.html` (antes que "Introduction to Wind Turbine Concepts").

## 4. Directorios de contenido

```
tutorials/
  en/ es/ fr/ de/ it/ pt/   → tutoriales HTML traducidos por idioma (+ img/ propio)
  data/                     → wind_energy_mindmap-XX.mm (un mapa mental por idioma)
  js/                       → d3.v7.min.js, mm-data.js, mm-render.js (visor del mapa mental)
  tutorial.css

simulators/
  es/                       → exportaciones estáticas de tutoriales/ejercicios por
                              familia de simulador: DFIGTutorial, DFIGExercises,
                              DSASTutorial, DSASExercises, RRCTutorial, RRCExercises,
                              WFSSCADA (SCADA de parque eólico), GuiaParqueEolico,
                              Experiments, LdP_Help — cada uno con su variante
                              "...MkDocs" (sitio generado con MkDocs: assets/,
                              javascripts/, stylesheets/, search/, sitemap.xml)

productos/ES/GPTR/          → PDFs de producto (hojas técnicas, leaflets)

configurations/
  i18n/                     → en.json, es.json, fr.json, de.json, it.json, pt.json
  videos/                   → videos-XX.xml (catálogo de vídeos por idioma, usado
                              por el modal de vídeos de index.html)

img/                        → imágenes compartidas (fondos de tarjetas, diagramas, etc.)
```

> Nota: `simulators/` solo tiene subcarpeta `es/` (contenido histórico
> exportado en español), mientras que `tutorials/` sí tiene una carpeta por
> cada uno de los 6 idiomas — son dos árboles de contenido con propósitos y
> niveles de traducción distintos, no confundirlos.

## 5. Scripts y utilidades de mantenimiento

- `extract_tutorial_keywords.py` — escanea los `hndsd.js` de los tutoriales
  exportados (HelpNDoc), extrae palabras clave, las agrupa por sección del
  launcher (mapeo `PATH_TO_SECTION`) y regenera el bloque
  `<script id="searchKeywords">` de `index.html`. Modo dry‑run por defecto;
  `--apply` escribe los cambios.
- `generate_aerog_diagrams.py` — genera diagramas/imágenes (Pillow) para
  `tutorials/en/img/`.
- `worker-mailer.js` — código de un **Cloudflare Worker** (se despliega por
  separado, no se sirve desde este sitio) que procesa el envío de
  `formulario.html`/`formulario-descarga.html` vía SMTP2GO + hCaptcha.
- `cookie-consent.js/css` — banner de consentimiento de cookies, compartido
  por las páginas de tema (§2).
- `legal-links.js` — inyecta enlaces legales traducidos en el pie de página.
- `seo-i18n.js` — motor i18n ligero compartido por las páginas de tema (§2).

## 6. Otros

- `.github/agents/seo-optimizer.agent.md` — definición de un agente para
  tareas de optimización SEO del sitio.
- `sitemap.xml`, `sitemap-video.xml`, `robots.txt` — SEO/indexación.
- No hay pipeline de CI/build (`.github/workflows` no existe): el despliegue
  es el propio contenido estático de la rama `main` servido por GitHub
  Pages.
- `Copilot-25-jul2026-ai-contexto.md` — notas de una sesión de IA anterior
  sobre una futura tarjeta "WindTech Academy" (contenido/copy propuesto, aún
  no implementado); no es documentación de arquitectura.
