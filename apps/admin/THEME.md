# Tema visual del portal administrativo

La identidad visual del admin está centralizada en `src/theme.css`. Los
componentes y `src/style.css` consumen variables CSS; evita poner colores
hexadecimales directamente en los componentes.

## Cambiar la paleta

1. Edita los valores del bloque `:root` en `src/theme.css`.
2. Cambia primero `--brand-primary`, `--brand-primary-strong`,
   `--brand-primary-hover` y `--brand-secondary`.
3. Ajusta las variables `--color-*` de superficies, texto y estados si la
   nueva marca necesita más contraste.
4. Ejecuta `npm run typecheck`, `npm test` y `npm run build` desde
   `apps/admin`.

El bloque `:root[data-theme="dark"]` contiene la variante oscura opcional.
Los colores principales se mantienen alineados con
`apps/patient/lib/src/theme.dart`.

El color de la barra del navegador se declara aparte en `index.html`
(`meta[name="theme-color"]`), porque los metadatos no pueden leer una
variable CSS; mantenlo igual que `--brand-primary`.
