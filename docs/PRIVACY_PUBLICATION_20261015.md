# Privacidad y reapertura pública — 15 de octubre de 2026

Estado observado: **12:25 UTC / 06:25 Puebla**, sobre los dominios existentes.
Autorización concreta del usuario: volver a levantar la aplicación en producción
con su base después del cambio de privacidad, para revisión en línea del abogado.
No se interpreta como aprobación jurídica del aviso.

## Resultado publicado

| Superficie | Versión Cloudflare | Observación real |
| --- | --- | --- |
| Landing | `18d3718c-1e45-4054-8859-26bf6c25c6ca` | 200, enlaces a Patient y aviso nuevo |
| API | `72bc81ed-f6a5-4dde-a834-15ae2dc30b63` | health 200; TSH una coincidencia; sangre/orina guía por muestra |
| Patient | `5bda3d31-f3b4-4fae-8f07-41c8339c5350` | 200 sin redirección; JS remoto igual al build por SHA-256 |

Aviso `pruevia-privacidad-2026-10-15-v1`. El cierre del recordatorio guarda
versión y fecha por navegador/instalación durante 180 días. Landing guarda
también caducidad explícita; Patient la calcula. No envía ese cierre al servidor,
no utiliza IP y no es constancia de lectura, firma o consentimiento médico.
Enlace permanente; nueva versión o vencimiento vuelven a mostrarlo. Los orígenes
landing/app guardan preferencias separadas. Limpiar datos o cambiar de dispositivo
puede mostrarlo antes. Si falla almacenamiento, landing conserva la sesión;
Patient permite continuar y avisa que no guardó la preferencia.

## Alcance y controles conservados

- Misma base productiva enlazada `ymtcmfgwuzdqtsbuvzqf`; no nuevas credenciales,
  migraciones, cambios de permisos, escrituras clínicas ni borrado histórico.
- Lectura remota previa: 499 conceptos / 234 ofertas / 74 marcas / 158 sedes /
  4,471 pendientes / 112 migraciones. No confundir identidades con cobertura.
- Captura interna de consultas: `PUBLIC_SEARCH_REVIEW_CAPTURE_ENABLED=false`
  con guard de servidor D-019. La versión HEAD sola no tenía ese guard.
- `PUBLIC_ANALYTICS_ENABLED=false`: eventos y clics devuelven 503 antes del RPC.
  Build Patient también desactiva analítica, feedback y portal proveedor.
- Registro Android y feedback comprobados false en configuración de base y
  respuesta pública. Intake/documentos de proveedor false en API pública.
- Sin cron; normalización/DENUE automáticos false. Admin permanece pausado y
  Access no se modifica. CORS HTTPS exacto, límites, JWT/MFA/RLS/TLS conservados.
- OCR conserva autorización específica; la configuración usa Workers AI.
  No se enviaron imágenes ni se verificó la calidad OCR en esta operación.
- Supabase y Cloudflare conservan sus secretos remotos existentes. El aviso usa
  la identidad y domicilio previamente publicados, desde configuración ignorada;
  no se copiaron esos valores al repositorio.

## Evidencia y límites

`collectors/artifacts/privacy-release-20261015/` contiene recibos, logs privados
de herramientas, builds/hashes, observación HTTP y navegador. Los logs de
Cloudflare pueden contener metadatos de la cuenta: no son artefactos públicos.

API preparada desde SHA fijo `689567b7090d13b24edf6101b740b8c1f43cdcd8`
con sólo guards de captura/analítica, tipos y configuración de cierre. No incluye
los endpoints Admin, spelling ni scheduler nuevos del árbol de trabajo.
Bundle API SHA-256 `e23c3a48c023fdf20ee1626199bd14d9657a1e277deb876af8d05f13aaa90bb7`.
Patient usa el árbol revisado con mejoras previas de búsqueda/instalación;
su build/hashes están fijados en `patient-build-receipt.json`.

Nuxt generate, Flutter release y Wrangler dry-run/deploy terminaron 0. CORS real:
origen app 204, ajeno 403. Eventos/clics 503 `analytics_disabled`. Navegador local:
recordatorio persiste al recargar, plazo 180 días, versión distinta lo vuelve a
mostrar; landing/aviso móvil sin desborde. Observación pública del navegador
registrada en `browser-public-after.json`: ambos recordatorios se ocultan al
recargar; Patient vuelve a mostrarlo con fecha vencida; se accede a búsqueda
desde móvil; no hubo errores de página. La revisión usa un navegador nuevo,
no demuestra el estado de todas las instalaciones previas.
No se ejecutaron suites formales, registro de testers, envío de correo, análisis
de datos de pacientes ni lectura de fotografías. Estos resultados no prueban
todos los flujos clínicos, retención de infraestructura ni cumplimiento legal.

## Entrega al abogado

Informe editable en [lenguaje común](legal/REVISION_PRIVACIDAD_PARA_ABOGADO_20261015.md).
PDF privado en `docs/legal/privado/PRUEVIA_REVISION_PRIVACIDAD_PARA_ABOGADO_20261015.pdf`:
once páginas, aviso actual exacto y copia anterior para comparación. Se excluye
de Git por contener identidad/domicilio. Capturas y recibo de PDF en
`collectors/artifacts/privacy-legal-review-20261015/`.

Pendientes inmediatos: revisión jurídica del consentimiento para datos sensibles
sin cuenta, identidad/domicilio, órdenes de menores o terceros, contratos y países
de prestadores, plazos/purgas/respaldos y actuación sobre el antecedente D-019.
No se eliminó ni consultó su contenido. El propietario autorizó publicar; esa
instrucción no resuelve estos pendientes ni constituye dictamen del abogado.

## Recuperación

Se conservaron versiones remotas previas mediante `deployments list`, sin
modificar secretos. Si aparece un problema atribuible a la reapertura, restaurar
las versiones de pausa mediante Wrangler rollback sobre el Worker exacto:

| Worker | Versión anterior |
| --- | --- |
| `pruevia-api` | `d8090ae6-dc38-4575-9cfe-0ced6b6826a9` |
| `pruevia-patient` | `928c5957-4457-470f-b765-cd96a86e87ea` |
| `pruevia-landing` | `fdbd3693-c018-4ef6-a02c-ce77cd15a6ca` |

Comprobar después API 503, app redirigida y landing accesible. No tocar Admin,
Access, DNS ni Supabase para recuperar esta publicación. Un rollback de landing
restauraría también el aviso anterior: conservar la copia nueva y valorar una
corrección del enlace/landing que mantenga la información de privacidad actual.
No se ejecutó recuperación porque las observaciones de publicación fueron correctas.
