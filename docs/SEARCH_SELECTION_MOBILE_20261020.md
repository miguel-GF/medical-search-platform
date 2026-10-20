# Selección de estudios y navegación móvil

20-oct-2026. **Implementado y observado localmente; publicación pendiente de
aprobación D-006.** La base productiva se consultó sólo para leer opciones ya
publicadas. Este cambio no registra nuevas equivalencias clínicas.

## Problema observado en producción

`hemática` y `hematica` devuelven Biometría hemática como candidato ambiguo,
confianza 0.473684 y ofertas vacías. El nombre completo devuelve el estudio con
sus ofertas. Existencia del estudio y confianza de una consulta parcial son
hechos distintos; la interfaz debe permitir elegir la sugerencia.

La UI anterior reconsultaba el nombre completo y ocultaba el botón cuando ese
nombre ya coincidía con la consulta. Si la respuesta seguía ambigua, el usuario
quedaba sin una acción útil. En móvil, elegir un proveedor sólo cambiaba un
panel más abajo, sin hacer evidente el resultado del toque.

## Comportamiento preparado

- Los candidatos y sugerencias tienen acción **Seleccionar este estudio**,
  incluso si su nombre coincide con el texto buscado.
- Un diálogo muestra consulta original y estudio elegido. Tras confirmar, la
  solicitud incluye el ID; el servidor comprueba que pertenece a los candidatos
  o sugerencias actuales de esa consulta.
- La respuesta contiene únicamente ese estudio y sus ofertas normales, con
  sucursal, precios efectivos y fuentes. La selección se distingue mediante
  `selection_method=user_confirmed`; no aprende un alias ni guarda equivalencia.
- Un ID inválido devuelve 400; una opción ajena o ya no disponible devuelve 409.
  El cliente exige ID correcto, estado resuelto y marca de selección explícita.
- La pantalla dice **Elegiste este estudio** y conserva el límite de cobertura
  de una orden completa. Las opciones ambiguas no entran al agrupador de ofertas.
- En el diseño estrecho existente (ancho útil menor a 820), elegir proveedor
  abre una pantalla con todas sus coincidencias y sucursales. Elegir una sucursal
  abre su pantalla. Atrás vuelve al estado y desplazamiento anteriores.
- El diseño amplio conserva los detalles en su panel lateral. La navegación usa
  los resultados ya recibidos; no recalcula precios ni realiza nuevas búsquedas.

## Observación real realizada

API local contra el catálogo productivo: `hematica` devuelve candidato sin ofertas;
confirmar Biometría hemática devuelve **34 opciones** del mismo estudio. También
funciona cuando la consulta ya es el nombre completo. IDs ajenos/incorrectos se
rechazan con 409/400. El servidor mantiene el contrato existente `api_search`
para sucursal y precio; no usa el detalle de estudio como sustituto de ofertas.

Chrome real sin interfaz, viewport 390×844, build Flutter debug y Worker locales:
consulta parcial → candidato → diálogo → selección → proveedor Chopo → sucursal
→ Atrás al proveedor → Atrás a resultados; después Ruiz → Atrás. La consulta
enfocada conserva `hematica`, la selección permanece y el botón del proveedor
vuelve exactamente a x30/y480/330×84. Sólo hubo las dos solicitudes de búsqueda;
abrir proveedor/sucursal no añadió consultas. Cero errores de página.

El primer observador buscaba una etiqueta semántica exacta que Flutter agrupa
con su descripción; la UI sí había completado la selección. Se corrigió el
selector del observador y se conservó la evidencia anterior. Asimismo, el input
semántico sin foco devuelve vacío; al enfocarlo se observa el texto real
conservado. No se confundieron esas limitaciones del observador con fallos de UI.

Al ampliar la misma ventana a 1280×900, elegir Ruiz conserva el panel lateral y
no aparece navegación Atrás de una pantalla nueva. Es una observación de Chrome
con ventana redimensionada, no una prueba física de todos los dispositivos.
No se ejecutaron suites formales. Se completaron análisis Dart acotado sin
incidencias, typecheck TypeScript y compilación debug. Los paquetes de producción
quedaron compilados y congelados en el mismo directorio de evidencia:
API aislada con typecheck y dry-run correctos; PWA release y headers con salida0,
49 archivos y fuentes intactas durante/después del build. `release-ready-observed.json`
conserva los hashes finales. Ninguna de estas compilaciones publicó el cambio.

Evidencia ignorada: `collectors/artifacts/search-flow-20261020/`, especialmente
`api-observed.json`, `local-api-observed.json`, `served-build.json` y
`run4/browser-observed.json` con capturas. Artefactos anteriores quedan conservados.

## Publicación concreta para aprobación

Regla aplicable: [D-006 y cambios críticos](DECISIONS.md#cambios-críticos-y-aprobación),
incluida publicación externa. La petición de implementación y navegación móvil
permite preparar este resultado; la activación externa espera autorización concreta.

1. **Cambio:** publicar selección explícita en API y navegación/selección en PWA.
   La API aislada parte del paquete publicado, cambia sólo `searchResponse` y
   conserva nueve módulos y toda su configuración. No publicar el checkpoint
   completo del API local con cambios administrativos ajenos a esta tarea.
2. **Justificación e impacto:** desbloquear consultas parciales y mostrar el
   resultado del toque en móvil. La confirmación añade una consulta de ofertas
   dentro de los recursos existentes; sin servicios o costos nuevos configurados.
   Mantener flags, controles, fuentes y datos clínicos actuales.
3. **Riesgos:** cliente nuevo requiere el parámetro de API nuevo; publicar API
   primero y PWA después. Opciones retiradas entre consulta y selección producen
   409. La elección humana no acredita equivalencia automática ni receta cubierta.
   Una PWA abierta puede conservar el build anterior hasta aceptar actualización.
4. **Alternativa:** conservar la versión pública y el resultado local mientras
   se decide. La búsqueda pública anterior sigue con el bloqueo reportado.
5. **Ejecución y comprobación:** volver a leer versiones remotas y hashes de los
   paquetes; publicar sólo API/PWA preparados, observar el caso en HTTP público
   y navegador móvil, versión/build recibidos y retorno Atrás. Conservar evidencia;
   no equiparar compilación o dry-run con despliegue real.
6. **Recuperación:** restaurar primero PWA a
   `2e1e136b-9e23-4969-9f59-ab350fb9510b` y después API a
   `45ed6a34-fcf6-4205-8d6b-0555926072d4`, observados vigentes el20-oct13:28UTC.
   Un cliente nuevo aún abierto debe actualizar su shell; la validación de la
   respuesta evita presentar una selección no confirmada por una API anterior.
7. **Decisión requerida:** autorizar publicación de estos dos paquetes concretos.
   No se ha desplegado durante esta tarea.

Archivos: `apps/api/src/app.ts`, `apps/patient/lib/main.dart`,
`apps/patient/lib/src/api_client.dart` y `apps/patient/lib/src/models.dart`.
