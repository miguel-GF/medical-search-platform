# Conteos internos publicados y cuatro destinos

23-oct-2026, hora de México; despliegues 24-oct04:42–04:45UTC.

El usuario autorizó publicar la propuesta recién descrita: totales agregados
para operación interna, sin texto médico ni identificadores de visitantes,
descritos en el aviso. No se habilita la analítica anterior con identificador.

## Destinos comprobados

| Destino | URL | Observación pública |
| --- | --- | --- |
| Landing | https://pruevia.com.mx | HTTP200 |
| App de pacientes/PWA | https://app.pruevia.com.mx | HTTP200, build y código comprobados |
| API | https://api.pruevia.com.mx/health | HTTP200; es un servicio técnico |
| Admin | https://admin.pruevia.com.mx | HTTP302 al acceso de Cloudflare, sin exponer el panel |

El formulario Android está en https://pruevia.com.mx/prueba-android.
No existe un cuarto frontend público de proveedores: su portal sigue cerrado.
La etiqueta histórica «Admin pausado» no acredita el estado del Worker detrás
de Access. En este corte se publicó Admin conservando esa protección; no se
validó una sesión real del operador con MFA ni se alteraron reglas de acceso.

## Implementación

El Worker cuenta solicitudes HTTP exitosas de búsqueda, selección explícita,
órdenes, combinación de órdenes e imágenes. `waitUntil` ejecuta el incremento
fuera de la respuesta, con llamada acotada y sin registrar errores con contenido
médico. Es una medición de solicitudes, aproximada y sin garantía de entrega.
No mide visitantes únicos; admite repeticiones y automatizaciones.

`analytics.usage_daily_totals` conserva exactamente tres columnas: día UTC,
acción de una lista cerrada y total. No hay tabla de eventos individuales ni
columnas de IP, cookies, identificador, estudio, URL, texto o imagen. Los reportes
muestran hasta365 días; las fechas de más de365 días se depuran con la siguiente
solicitud. Sin tráfico no se ejecuta esa limpieza. Esto no modifica el tratamiento
de datos técnicos de Cloudflare/Supabase descrito por separado.

RPCs nuevos con permiso sólo para `service_role`; tabla con RLS, sin permisos
para `anon` o `authenticated`. Lectura mediante la ruta administrativa ya
autorizada por servidor. Panel «Solicitudes atendidas» en la pestaña de analítica
del Admin. La PWA no muestra la fila de analítica desactivada ni crea identificador
para este conteo. Medición anterior, captura de consultas, feedback, proveedores,
reserva y crons continúan apagados.

## Secuencia y evidencia

1. Compilaciones API/Flutter/Nuxt/Admin terminadas correctamente. API compuesta
   sobre el release público congelado: sólo módulo de conteos, integración de
   `waitUntil`, configuración y una lectura administrativa. No se activó el
   candidato clínico aislado ni los cron de la configuración histórica.
2. Ensayo SQL con reversión comprobó incremento, rechazo de acciones desconocidas,
   tres columnas, RLS y permisos de funciones/tabla. Estado anterior restaurado.
3. Migración `20261024050000_aggregate_usage_totals.sql`, número116, enviada una
   vez. Inspección independiente: auditoría nueva, tabla vacía tras migrar,
   catálogo/ofertas/sedes y hashes del resolvedor intactos. No quedaron conteos
   sintéticos del ensayo. Marcadores previos y ausencia de reenvío conservados.
4. Landing y Patient con aviso globalv4 publicados; después Admin y API. Un
   segundo release de landing precisó la limpieza por actividad antes de activar
   la API. La primera lectura de `/privacidad` recibió redirección: la lectura
   independiente siguiendo la redirección confirmó HTTP200, v4 y texto correcto.
5. Verificación HTTP real: búsqueda200 incrementó el total observado de3 a4;
   consulta inválida400, lectura administrativa sin autorización401, ruta antigua
   de eventos503. Las otras solicitudes anteriores no se atribuyen a personas.
6. Navegador público390×844: cuatro acciones350px a x20, Ajustes sin fila de
   analítica, worker activo, build y JavaScript remoto coincidentes, cero errores.
   No se acredita el teléfono del usuario ni el ingreso privado de Admin.

No se ejecutó la suite completa de contratos ni suites de otras apps. La
verificación descrita usa la base y HTTP reales; no se confunde con mocks.

## Versiones finales

| Componente | Versión |
| --- | --- |
| API | `6398935d-4b7c-4b71-b181-6841b8c5ee1c` |
| Patient | `28e7a8c6-6790-4770-9d7d-5339439d2763` |
| Landing | `449f8496-2fb8-41ab-bb8c-aec96273636a` |
| Admin | `453ed6a5-127f-40f4-ba57-f68538f2bd67` |

BuildPatient `07794f103d08ef7b6e6f1b6da1f77ba452808d74090fb482c93bead64c8258b1`.
SHA256JS `c32c56dd93fec7211345731e14dd392543baa54957c409f4fd06d693824ce406`.
Aviso global: `pruevia-privacidad-2026-10-23-v4`; aviso de convocatoria Androidv3
conservado. [Adición entendible para abogado](legal/ADICION_CONTEOS_INTERNOS_20261023.md)
y [PDF](legal/ADICION_CONTEOS_INTERNOS_20261023.pdf).

Artefactos: `collectors/artifacts/aggregate-usage-release-20261023/`, con fuentes
congeladas, hashes, compilaciones, permisos, SQL enviado, ledger, versiones y
`live-verification.json`/`public-observed.json`. La corrección de redacción del
landing conserva su evidencia en `retention-wording/`. Sin secretos ni pacientes.

## Recuperación y pendientes

Para detener conteos, publicar el API anterior
`4cbf0101-70b5-43ae-b2e5-a7ebcad85786` o el mismo release con
`AGGREGATE_USAGE_ENABLED=false`. Conservar la tabla y migración aplicadas;
no borrar datos ni ledger para retroceder. Mantener el aviso que describe el
tratamiento efectuado y explicar su cierre si se retira la medición.
Frontends previos: Patient `31122ca0-2b81-49a8-a992-b1ed40346c04`, landing
`c8c862b5-b22c-476b-a6e6-2bc55a0dc83e`, Admin
`62fe579e-55d7-4021-bb7b-3c0c915989a0`. Recuperación preparada, no ejecutada.

Faltan la comprobación de la PWA del usuario, el recorrido del operador con MFA,
la revisión jurídica y la gestión externa de la prueba en Google Play. Los
4,045 registros pendientes del catálogo y el bloque nuevo de capturas no se
publicaron por esta petición. La expansión sigue pausada.
