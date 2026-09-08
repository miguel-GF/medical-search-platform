# Seguridad: corte de trabajo del 4 de septiembre de 2026

Estado: **en curso; no aprobado para produccion**. Este documento distingue
controles comprobados de trabajo pendiente. No sustituye la revision del resto
del proyecto ni afirma que el software sea imposible de comprometer.

Revalidacion local: 7 de septiembre de 2026. El estado remoto y los pendientes
de despliegue descritos abajo siguen vigentes.

## Politica de AAL2

- Esta es una elevacion deliberada para superficies privilegiadas: proveedores
  y administradores manejan relaciones de cuenta, evidencia y decisiones
  operativas. No se aplica globalmente a la busqueda publica ni a la experiencia
  Patient, porque esas superficies no deben exigir una cuenta ni MFA.
- Todas las rutas administrativas y de proveedor, incluidas lecturas, exigen
  una sesion verificada por Supabase con `aal2`. Administracion tambien exige
  pertenecer a `ADMIN_USER_IDS`. AAL2 no reemplaza los permisos por recurso.
- No se confia en un `aal`, usuario o rol enviado en el cuerpo de la peticion.
  El Worker obtiene al usuario mediante `/auth/v1/user` y solo despues lee el
  nivel del JWT validado. Las RPC de servidor reciben ese contexto verificado.
- AAL1 sigue siendo necesario durante el inicio de sesion y el enrolamiento
  del segundo factor, sin autorizar datos ni operaciones de proveedor/admin.
  La busqueda publica no requiere una cuenta ni MFA.
- Las RPC de servidor y los resultados del escaner son exclusivos de
  `service_role`. Esa credencial nunca debe estar en una app, bundle o log.
- El Worker no acepta un `aal2` obsoleto como suficiente: exige un factor TOTP
  con estado `verified` en `factors` de la respuesta validada `/auth/v1/user`.
  Correccion del 8 de septiembre: `rest/v1/auth/factors` no es la ruta del SDK;
  `listFactors()` usa `getUser()`. Si el factor se elimino, se rechaza el acceso.
- La respuesta validada de `/auth/v1/user` debe marcar explicitamente
  `is_anonymous: false`; `true` o un campo ausente se rechazan para evitar que
  un cambio de forma en Auth convierta una identidad anonima en operador.
- La misma regla queda aplicada en PostgreSQL: el actor y las politicas de
  Storage solo aceptan `auth.users.is_anonymous is false`; un valor nulo o
  desconocido no se convierte en una identidad permanente por defecto.
- Las primeras migraciones de provider/Storage ya aplican esa identidad y el
  factor `verified`, para que una interrupcion entre migraciones no abra una
  ventana temporal de AAL2 anonimo.
- El bundle de Admin exige un allowlist exacto para el host del Worker y para
  el origen Supabase antes de compilar en produccion; la CSP generada usa esos
  mismos dos origenes y no acepta `https:` generico.

## Hallazgos comprobados en este corte

### Evidencia expuesta ante una politica de Storage demasiado amplia

La migracion pendiente de Storage restringia lectura/subida para
`authenticated`, pero no tenia restricciones equivalentes para `anon`.
Una politica permisiva adicional para ambos roles podia autorizar lecturas y
subidas anonimas dentro de `provider-claims`, aunque el bucket fuera privado.
No se afirma que esa politica amplia existiera en el entorno publicado.

Se reprodujo dentro de una transaccion con una politica deliberadamente amplia:
fallaron las pruebas 7 y 12 (lectura y subida anonimas) y la prueba 19 detecto el
objeto no autorizado. Se agregaron dos politicas restrictivas para `anon`.
Con la correccion, las 24 pruebas pasan, incluyendo aislamiento entre usuarios,
AAL1, AAL ausente, propiedad, rutas, cierre del reclamo e inmutabilidad.

Archivo: `database/supabase/migrations/20260904150000_provider_document_storage.sql`.
Contrato: `database/supabase/tests/provider_storage_boundary_test.sql`.

Estas son pruebas de RLS sobre metadatos con roles reales de PostgreSQL; no son
pruebas de subida/descarga HTTP ni de antivirus. Simulan el indicador de sesion
que Storage usa para DELETE para comprobar RLS en vez de la proteccion general
contra borrado SQL. No se borra ningun objeto real; los fixtures usan UUID
reservados para esta transaccion y terminan en ROLLBACK.

La defensa también comprueba el factor actual: un JWT `aal2` conservado después
de eliminar su factor ya no puede leer ni subir evidencia directamente por
Storage. La misma barrera rechaza identidades anonimas aunque su JWT incluya
`aal2` y un factor `verified`.

### CI podia ocultar resultados pgTAP fallidos

El workflow ejecutaba SQL y solo comprobaba la salida del proceso. La respuesta
de Management API conserva el ultimo conjunto de resultados: un fallo anterior
podia no estar visible, y un `not ok` de pgTAP no tiene por que producir un error
SQL. El nuevo `database/scripts/run_sql_contracts.py` captura plan, aserciones y
finish en una tabla temporal, y verifica numero, orden y resultado individual.
Falla ante errores del CLI, JSON incompleto, resultados vacios, duplicados,
faltantes, SKIP, TODO o cualquier asercion no aprobada.

CI ahora utiliza ese ejecutor. Los benchmarks generados se cambiaron a
ROLLBACK desde su generador para que todos los contratos tengan una frontera
transaccional uniforme. No se modificaron los casos ni resultados esperados.

### Vulnerabilidad en la dependencia de pruebas Python

La auditoría encontró `pytest 8.4.2` (`PYSEC-2026-1845`) en el entorno del
scanner. Se fijó `pytest 9.0.3` en el scanner y se elevó el mínimo de los extras
de desarrollo de collectors y OCR a `9.0.3`; el scanner quedó sin hallazgos en
`pip-audit`.

En la revisión posterior, `Pillow 11.3.0` apareció con varias alertas de
procesamiento de imágenes. El OCR ahora exige `Pillow >=12.3.0,<13`; una
instalación limpia resuelve 12.3.0 antes de ejecutar el servicio.

CI ahora actualiza `pip`/`setuptools`, instala `pip-audit` y audita las
dependencias resueltas de collectors, OCR, scanner y scripts de base de datos
antes de ejecutar sus pruebas. La auditoría aislada más reciente no encontró
vulnerabilidades conocidas; el paquete editable local se excluye del informe
porque no existe en PyPI.

El job de ramas protegidas también comprueba el esquema de privilegios efectivo
antes de ejecutar contratos o publicar el Worker; si quedan RPC antiguas para
`anon`/`authenticated`, el despliegue falla cerrado.

### La app Android no puede usar una firma de depuraciÃ³n en `release`

La configuraciÃ³n original apuntaba el tipo `release` al keystore `debug`.
Ahora se elimina ese fallback: un build de producciÃ³n exige las cuatro
variables de un keystore de release (`PRUEVIA_RELEASE_STORE_FILE`,
`PRUEVIA_RELEASE_STORE_PASSWORD`, `PRUEVIA_RELEASE_KEY_ALIAS` y
`PRUEVIA_RELEASE_KEY_PASSWORD`) y falla explÃ­citamente si faltan. La
sincronizaciÃ³n y los builds debug no requieren esos secretos.

### La redacciÃ³n de evidencia no puede recorrer JSON sin lÃ­mite

Los payloads de proveedores son datos no confiables. Aunque la ingesta limita
el tamaÃ±o total, un JSON compacto puede tener una profundidad extrema y hacer
que la redacciÃ³n recursiva agote la pila de PostgreSQL cuando un administrador
abre la evidencia. `20260906200000_review_json_depth_guard.sql` introduce una
frontera de 32 niveles y devuelve un marcador seguro cuando la alcanza; el
helper interno tampoco es ejecutable por `anon` o `authenticated`.

### Las imÃ¡genes base de los servicios ya no dependen de tags mutables

Los dos Dockerfiles fijan el manifiesto de Python por digest. Una actualizaciÃ³n
de la imagen base debe hacerse de forma intencional y pasar de nuevo la
revisiÃ³n de dependencias.

### Idempotencia de Admin aislada por operador

`idempotency-key` y `x-request-id` son cabeceras controladas por el cliente.
Antes de llegar a las RPC de mutaciÃƒÂ³n se derivan ahora a un SHA-256 que
incluye el UUID del administrador autenticado. Un mismo texto reutilizado por
dos administradores ya no puede cruzar el replay de una operaciÃƒÂ³n ni devolver
el resultado de otro operador.

### El entorno del Worker no puede degradarse por omision

El Worker solo relaja CORS, rate limiting y URLs HTTP en `development` o
`test`. Si `APP_ENV` falta o tiene un valor desconocido, exige origen HTTPS y
bindings de rate limit y rechaza endpoints Supabase HTTP, evitando un despliegue
accidental con controles de desarrollo.

### Los colectores y el OCR fallan cerrados ante entradas hostiles

Los clientes Chopo, Salud Digna, Ruiz y DENUE ahora acotan páginas, reintentos,
esperas, URLs, catálogos, filas y coordenadas; rechazan orígenes HTTP,
credenciales y segmentos de ruta inseguros. El modo de crawling hacia hosts
privados solo puede activarse con `APP_ENV=development` o `test`, evitando que
un flag operativo convierta el colector en un SSRF. La salida del motor OCR
también queda limitada a 500 líneas y 500 caracteres por línea.

El panel administrativo ya no apunta a `localhost` cuando falta `VITE_API_URL`
en una build de producción, y el Worker solo permite un OCR HTTP de loopback en
entornos locales.

La revisión de este corte detectó que una URL de API vacía podía convertirse en
una ruta relativa y enviar el bearer a la misma origin estática del panel. El
cliente Admin ahora trata una URL ausente como error de configuración antes de
leer el token; la regresión queda cubierta por las pruebas del panel.

También se cerró la validación del origen de Supabase Auth en el panel: una
URL HTTPS con puerto alterno, ruta adicional, credenciales, query o fragmento ahora se rechaza
antes de crear el cliente y de almacenar una sesión.

La misma frontera se aplica al Worker, al cliente y al servicio OCR: los
endpoints de Supabase/OCR no pueden incluir rutas adicionales. Esto evita que
una configuración manipulada dirija un bearer o una credencial de servicio a
una ruta interna del mismo host.

El Worker y el servicio OCR aplican la misma defensa de configuracion: un
endpoint no local requiere un token de servicio de al menos 32 bytes. Un token
corto solo puede usarse en el modo de desarrollo con loopback.

Las URLs de fuentes que salen del API y del panel administrativo solo conservan
HTTPS en el puerto TLS predeterminado y rechazan hosts locales, reservados o
literales IPv6. Patient añade ademas una lista estatica de dominios de
proveedores antes de abrir cualquier enlace externo.

RapidOCR queda fijado a `3.9.2` y sus modelos ONNX se preempaquetan en la
imagen desde el manifiesto con SHA-256. El proceso usa un directorio de solo
lectura y rechaza iniciar si falta un modelo; una petición no puede descargar
ni reemplazar modelos en caliente.

El cliente Flutter ahora desactiva redirecciones HTTP. Las consultas y las
imagenes no se reenvian automaticamente a un host distinto si el edge o el
servidor devuelve un `3xx` inesperado.

En builds profile/release, `API_ALLOWED_HOSTS` debe declarar el hostname exacto
del Worker; `API_BASE_URL` sin esa allowlist se rechaza antes de enviar texto o
imagenes clinicas.

Ademas, su cliente ya no usa `Response.fromStream` sin limite: consume las
respuestas incrementalmente, rechaza compresion y longitudes inconsistentes, y
aborta al superar 2 MiB antes de construir el objeto final. Asi una respuesta
hostil no puede forzar un buffer arbitrario en la app.

Las aplicaciones web ahora publican una CSP completa en `_headers`, con
`object-src`, `base-uri`, `frame-ancestors`, `form-action`, workers y fuentes
limitados. Patient permite unicamente los recursos locales, CanvasKit/WASM y
los hosts API generados desde `API_ALLOWED_HOSTS`; Admin mantiene scripts
locales y QR inline como datos. El Worker rechaza cuerpos comprimidos
para que el limite de bytes no pueda evadirse mediante expansion de gzip u otra
codificacion.

En Android, el manifiesto de Patient desactiva las copias de seguridad del
dispositivo (`allowBackup=false` y `fullBackupContent=false`); las preferencias
locales no contienen historiales clinicos.

Patient invalida resultados OCR tardios cuando la app se pausa, se destruye o
se borra una orden, y limpia la orden al salir de la pestaña de receta. Su
`API_BASE_URL` solo acepta un origen HTTPS limpio (HTTP queda limitado a
loopback en debug). Gradle no genera heap dumps automáticos durante builds
móviles y los archivos `.hprof` quedan excluidos del repositorio.

En iOS, `SceneDelegate` cubre el contenido con blur al pasar a segundo plano y
mientras el sistema detecta captura/grabacion de pantalla; la capa se elimina
al volver a un estado activo sin copiar ni persistir la informacion medica.

### Amplificacion de CPU en la respuesta del solver de paquetes

La respuesta JSON de Supabase estaba acotada por bytes, pero sus listas de
ofertas llegaban sin un limite de filas y el solver recorria todas las ofertas
para cada combinacion de sucursales. Un payload grande o una expansion anomala
del catalogo podia convertir una solicitud valida en trabajo cuadratico del
Worker. `apps/api/src/batch.ts` ahora limita las listas recibidas, descarta
indices de estudio no solicitados y conserva solo la mejor oferta por estudio y
sucursal antes de evaluar combinaciones. El contrato de regresion esta incluido
en las pruebas del API.

La sanitizacion de detalles publicos tambien rechaza colecciones con mas de
1,000 elementos o claves antes de crear copias recursivas. El endpoint OCR
aplica la misma politica de destino: en produccion solo acepta hosts publicos
por HTTPS y bloquea loopback, redes privadas/reservadas, nombres locales y
IPv6 literal; HTTP de loopback queda limitado al desarrollo local.

## Evidencia ejecutada en este corte

| Comprobacion | Resultado | Alcance |
| --- | --- | --- |
| `provider_storage_boundary_test.sql` | 25/25 | Migraciones pendientes ensayadas con ROLLBACK, incluido AAL2 obsoleto, identidad anonima y cuota de objetos por claim en Storage |
| `provider_claims_test.sql` | 62/62 | Flujo SQL de evidencia, permisos y reclamaciones; sin escaneo de bytes |
| `provider_scan_queue_test.sql` | 9/9 | Cola de escaneo privada, lease atómico, intentos acotados y backoff de reintentos |
| `provider_worker_boundary_test.sql` | 15/15 | Roles reales, aislamiento, rechazo de contexto falso, AAL1, actor sin factor vigente e identidad anonima |
| `security_privileges_test.sql` | 28/28 | Privilegios efectivos tras las migraciones pendientes, incluidos los dos helpers de Storage |
| `provider_aal2_test.sql` | 11/11 | Rechazo de AAL1, claim `aal` ausente, JWT `aal2` sin factor vigente e identidad anonima en las operaciones privilegiadas |
| `review_json_depth_test.sql` | 3/3 | RedacciÃ³n de secretos y truncamiento fail-closed de JSON profundamente anidado |
| `python -m pytest -q database/tests` | 120/120 | Scripts, contratos, configuración Auth local fail-closed, lectores de artefactos acotados, descargas LOINC y el gate del ledger de migraciones |
| API `npm test` y `npm run typecheck` | 100/100; tipado correcto | Pruebas locales, no trafico del Worker publicado; AAL2 exige factor vigente del mismo usuario y `is_anonymous: false` |
| Document scanner `python -m pytest -q` | 44/44 | Hash/MIME, limites, redireccion, socket ClamAV y respuestas fail-closed |
| OCR `python -m pytest -q` | 25/25 | Token obligatorio, rechazo de headers duplicados y comprimidos, modelos ausentes fail-closed, límites de imagen/respuesta, salida OCR acotada y token débil fuera de loopback |
| Admin `npm test` y typecheck | 18/18; tipado correcto | Respuestas acotadas, redirecciones bloqueadas, IDs de ruta codificados, autenticación de panel, orígenes Auth/API limpios y enlaces de fuentes con allowlist |
| Patient `flutter test` y `flutter analyze` | 19/19; sin issues | Respuestas JSON acotadas, origen HTTPS, allowlist de host en profile/release y sin redirecciones |
| Android Gradle `:app:tasks` + `:app:assembleRelease` | Configura correctamente; release falla sin keystore | No permite firmar `release` con debug keys |
| iOS Release signing | Configuración estática endurecida | Exige `Apple Distribution`, equipo y perfil suministrados por CI; no hay fallback a `iPhone Developer` |
| Collectors `python -m pytest -q` | 123/123 | Transporte público fijado, caps de ejecución, parser HTML/JSON-LD acotado, redirecciones, token DENUE y artefactos validados |

El historial remoto consultado en este corte confirma que
`20260904110000_provider_aal2_enforcement.sql` esta aplicado al proyecto DEV
enlazado `ymtcmfgwuzdqtsbuvzqf`. Las quince migraciones `20260904115000` a
`20260906240000` **siguen pendientes**. El verificador de orden remoto confirma
que el ledger aplicado sigue siendo un prefijo continuo; no se ha aplicado una
migracion posterior en aislamiento. Los ensayos no
registraron ni aplicaron permanentemente esas migraciones. No se desplego
ningun Worker en este corte.

La consulta de privilegios remotos mas reciente confirma el bloqueo operativo:
8 RPC propiedad del Worker siguen ejecutables por `anon` y `authenticated`, y
el esquema remoto aun expone 0 wrappers `api_server_provider_*` de servicio.
Mientras estos valores no sean `0` y `7` respectivamente tras la migracion, el
Data API puede saltarse los limites del Worker y el Worker nuevo no es
compatible con el esquema remoto.

`pip-audit` no reportó vulnerabilidades conocidas para las constraints del
scanner ni para las dependencias resueltas de collectors y OCR.

La ultima ejecucion de OCR fue 25/25 y la de collectors 123/123. El resumidor
de cobertura de Puebla ahora procesa JSONL no confiable en streaming y rechaza
artefactos sobredimensionados o alterados; los presupuestos de descubrimiento y
reintentos tienen limites estrictos. Los renderizadores offline de DENUE,
golden/review y el runner de collectors imponen un techo total de artefactos y
eliminan credenciales de las URLs propagadas. Las listas de URLs de Chopo y los
archivos `.env` de LOINC suministrados por operadores tambien tienen limites de
archivo, linea y entradas antes de analizarse. El ensayo SQL pendiente tambien
cubre la barrera de integridad del actor de auditoria (4/4).

La ejecucion de `supabase db advisors --linked` fue solo de lectura y detecto
23 funciones propias con `search_path` mutable. La migracion
`20260906180000_function_search_path_hardening.sql` fija esas funciones a
`pg_catalog`; aun falta aplicarla en remoto y volver a ejecutar los advisors.
El mismo informe indica que la proteccion de contrasenas filtradas de Auth esta
desactivada. Eso no se puede resolver desde una migracion SQL local: debe
activarse en la configuracion Auth del proyecto y comprobarse con una prueba de
registro/cambio de contrasena.

## Reproduccion

Desde la raiz, con el proyecto DEV enlazado y la migracion 1100 aplicada:

```powershell
powershell -NoProfile -File database/scripts/test_pending_security.ps1 -Test provider_storage_boundary_test.sql
powershell -NoProfile -File database/scripts/test_pending_security.ps1 -Test provider_claims_test.sql
powershell -NoProfile -File database/scripts/test_pending_security.ps1 -Test provider_worker_boundary_test.sql
powershell -NoProfile -File database/scripts/test_pending_security.ps1 -Test security_privileges_test.sql
python -m pytest -q database/tests
```

El script de ensayo solo sirve para la ventana concreta 1150-2400 y requiere
que esas migraciones no esten aplicadas. Ejecutar los ensayos secuencialmente
para evitar competir por los mismos bloqueos DDL. Nunca contra produccion.

Despues de migrar un entorno de pruebas, con Python y el CLI Supabase instalado:

```powershell
python database/scripts/run_sql_contracts.py
```

Este segundo ejecutor comprueba el esquema ya aplicado; no lo migra ni oculta
fallos por migraciones pendientes. `--test nombre.sql` selecciona una suite.
`--cli` permite indicar la ruta del ejecutable. El job remoto de CI solo corre
en pushes a `main`/`develop` protegidos (nunca con codigo de un pull request) y
falla cerrado si faltan los secretos de Supabase. Antes de los contratos,
`database/scripts/check_migration_order.py` exige que el ledger remoto sea un
prefijo exacto de las migraciones locales; una migracion posterior aplicada en
aislamiento bloquea el despliegue hasta corregirse.

## Pendientes que impiden dar por terminado el objetivo

- Escaner real de documentos: `apps/document-scanner` ya implementa el worker
  privado, descarga por HTTPS sin redirecciones, limita a 10 MiB, detecta firmas
  de bytes, verifica hash/extensión y usa ClamAV por socket Unix. Aún falta
  desplegarlo con un `clamd` aislado, actualizar firmas y comprobar el flujo
  contra Storage real; hasta entonces la RPC de base de datos por sí sola no es
  un escaneo y no debe usarse para aceptar evidencia.
- Completar y probar subida y revision documental de extremo a extremo,
  incluyendo visualizacion administrativa segura. No confundir una lista de
  metadatos con revisar el archivo real. Los documentos historicos sin escaneo
  no quedan validados automaticamente por estas migraciones.
- Coordinar despliegue de DB y Worker: el Worker local usa RPC que aun no
  existen en remoto; revocar las RPC antiguas antes de cambiar el Worker puede
  interrumpir el servicio. No ejecutar `db push` o despliegues aislados siguiendo
  instrucciones historicas. Hace falta un procedimiento de transicion probado
  (o mantenimiento controlado), comprobaciones HTTP y recuperacion segura.
- Aplicar tambien la migracion de `search_path` y activar la proteccion de
  contrasenas filtradas en Auth. No se debe cerrar la auditoria mientras el
  advisor remoto siga mostrando esos dos avisos sin una aceptacion documentada.
- Mantener aplicadas las barreras de factor actual y de identidad no anonima de
  `20260906190000_provider_aal2_current_factor.sql` y
  `20260906210000_provider_storage_current_factor.sql` y
  `20260906220000_provider_non_anonymous_identity.sql`; los wrappers de servicio
  y Storage deben comprobar un factor `verified` en `auth.mfa_factors` además
  del claim `aal2` recibido del Worker y rechazar usuarios anonimos.
- Verificar configuracion efectiva de Auth remoto, expiracion/revocacion de
  sesiones, recuperacion/invitaciones en navegador y permisos por cada recurso.
- Mantener la revisión de dependencias/cadena de suministro, aislamiento/
  recursos del OCR y configuración de red; CI ya falla ante vulnerabilidades
  conocidas y OCR fija su runtime/modelos y `constraints.txt`, pero faltan
  hashes por plataforma y pruebas de carga en el entorno real.
- Mantener `main` y `develop` protegidas con revision obligatoria y exigir una
  aprobacion de Environment para el deploy. Los jobs que manejan secretos
  comprueban `github.ref_protected`; si la proteccion se desactiva, deben
  quedar omitidos.
- Rotar inmediatamente cualquier token que haya existido en un `.env` local,
  aunque Git lo ignore. Los contextos Docker del scanner/OCR ya excluyen
  secretos y la imagen OCR comprueba los SHA-256 de sus tres modelos antes de
  copiarlos al runtime.
- Verificar HTTPS, cabeceras realmente servidas por el hosting, rate limits,
  secretos, alertas y procedimientos de recuperacion en el entorno desplegado.
  La app Patient solo abre enlaces HTTPS de los dominios de proveedores
  declarados en `lib/main.dart`; cualquier dominio nuevo requiere una revision
  y cambio de allowlist.
  La CSP de Patient debe generarse con `tool/render_web_headers.dart` usando el
  dominio real del Worker; no se debe restaurar `connect-src https:`. Confirmar
  ademas que el hosting no elimina `_headers` ni las reglas de no-cache para
  HTML/bootstrap/service worker.
- Aplicar `20260906230000_provider_storage_upload_quota.sql`: la subida ocurre
  antes de registrar el documento y la migracion limita a diez los objetos por
  claim con bloqueo transaccional para evitar carreras. La cuota solo afecta
  nuevas subidas; la evidencia existente permanece legible.
- Aplicar tambien `20260906240000_provider_change_json_size.sql` y mantener las
  rutas de Storage en minusculas canonicas; asi los limites de JSON y de objetos
  no pueden eludirse con variantes de mayusculas.

### Revalidacion adicional del 2026-09-06

- OCR service: **25/25** tests; los errores de inicializacion del motor ya no
  devuelven rutas, versiones ni detalles internos.
 - API: **100/100** tests y typecheck correctos; se agrego un limite de 1000
  entradas por coleccion, redaccion de claves con forma de credencial y el
  comprobante MFA ahora verifica explícitamente el `user_id` del factor y
  rechaza respuestas Auth sin `is_anonymous: false`.
- Admin: **18/18** tests y typecheck correctos; los mensajes upstream se
  localizan de forma generica y nunca muestran SQL, stack traces o secretos.
- Patient: **18/18** tests y `flutter analyze` sin issues; iOS incluye overlay
  de privacidad al pasar a segundo plano y durante captura de pantalla. La
  compilacion nativa iOS requiere ejecutarse en macOS/Xcode.
 - Contratos SQL pendientes: Storage **25/25** y provider claims **62/62**;
  tambien pasaron los contratos de Worker **15/15** y privilegios **28/28**.
- Gate de ledger remoto: **76/91** migraciones aplicadas, **15** pendientes y
  orden continuo verificado; el gate de esquema sigue fallando hasta migrar.

## Referencias tecnicas

- [MFA y AAL en Supabase](https://supabase.com/docs/guides/auth/auth-mfa).
- [Control de acceso de Storage](https://supabase.com/docs/guides/storage/security/access-control).
- [Proteccion de borrado SQL y cambios de Storage](https://supabase.com/blog/supabase-storage-performance-security-reliability-updates).
