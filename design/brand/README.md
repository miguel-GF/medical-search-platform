# Identidad visual de Pruevia

La identidad activa representa un libro abierto: la página izquierda integra la
`P` de Pruevia y la derecha contiene dos líneas que remiten a una orden de
estudios. El nombre de la marca sigue siendo `Pruevia`.

## Archivos de producción

- `pruevia-mark.svg`: símbolo principal bicolor, teal `#0F766E` y verde
  `#65B586`, para superficies claras.
- `pruevia-symbol.svg`: versión monocromática sin contenedor; usa
  `currentColor` y conserva transparentes la `P` y las líneas.
- `render_assets.py`: genera la versión compacta blanca sobre teal para favicon,
  PWA, Android, iOS y splash del paciente. En Android conserva el PNG heredado
  y genera una capa adaptativa/monocromática dentro de la zona segura del sistema.

Los PNG se regeneran desde la raíz con
`python design/brand/render_assets.py`. Las propuestas P-ruta se conservan como
historial exploratorio y ya no son la marca activa.

## Criterios de selección

El símbolo debe conservar legibilidad a 16 px y 32 px, distinguirse de un pin de
ubicación, funcionar en monocromo y mantener una silueta clara en los iconos
maskable de Android/PWA. Los iconos funcionales no se reemplazan con la marca.
