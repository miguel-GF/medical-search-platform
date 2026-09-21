# Estrategia de Pruevia con costo inicial cero

Tipo: análisis y propuesta, no implementación.  
Fecha de revisión: 20-sep-2026.  
Alcance: lanzamiento centrado en pacientes, privacidad, prueba PWA/Android,
colaboración comunitaria, infraestructura gratuita y sostenibilidad futura.

Este documento no acredita que los cambios propuestos estén activos ni autoriza
una publicación. Antes de abrir formularios o procesar datos reales deben
completarse los controles y decisiones indicados.

## Conclusión ejecutiva

Pruevia puede iniciar con costo mensual de infraestructura de **$0** como una
plataforma gratuita y centrada en pacientes. La ruta recomendada es:

1. publicar primero landing y PWA;
2. mantener cerrado y sin enlaces públicos el alta de proveedores;
3. validar utilidad con 20 personas en la PWA;
4. permitir reportes comunitarios estructurados, nunca publicación automática;
5. resolver una dirección gratuita autorizada o patrocinio institucional;
6. realizar después la prueba cerrada formal de Android;
7. considerar aportaciones voluntarias y servicios pagados para proveedores sólo
   después de demostrar valor para pacientes.

No existe una herramienta informática que sustituya una dirección física cuando
Pruevia es responsable del tratamiento de datos personales. Sin embargo, la
dirección no tiene que ser fiscal, propia ni una oficina rentada: puede ser un
domicilio legítimamente designado para recibir notificaciones.

## Domicilio y privacidad

La Ley Federal de Protección de Datos Personales en Posesión de los Particulares
vigente exige que el aviso integral informe identidad y domicilio del responsable,
datos tratados —identificando los sensibles—, finalidades, limitación de uso,
procedimiento ARCO y comunicación de cambios.

Fuentes:

- [LFPDPPP vigente, artículo 15](https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf).
- [Guía para el aviso de privacidad](https://inicio.inai.org.mx/CalendarioCapacitacion/ManualAvisoPrivacidad.pdf).
- [Lineamientos del aviso de privacidad](https://sidof.segob.gob.mx/notas/docFuente/5284966).

La guía define el domicilio como el designado para oír y recibir notificaciones;
debe incluir calle, número, colonia, ciudad o municipio, estado y código postal.
Un correo electrónico no lo reemplaza.

### Alternativas sin renta mensual

1. Domicilio particular propio. Es gratuito, pero se vuelve públicamente accesible.
2. Oficina o negocio de una persona de confianza, con autorización escrita y
   capacidad real para recibir correspondencia dirigida a Pruevia o al responsable.
3. Domicilio de una incubadora, asociación o institución que acepte formalmente
   alojar el proyecto mediante convenio.
4. Organización aliada que asuma formalmente el papel de responsable, con un
   acuerdo que determine control, obligaciones, datos y atención de derechos.

No son soluciones válidas una dirección inventada, usada sin permiso, un buzón
que no reciba notificaciones o simplemente ocultar la dirección mediante código.

### Recursos gratuitos que vale la pena consultar

- El [Bufete Jurídico Gratuito de la BUAP](https://bufetejuridico.buap.mx/)
  declara prestar asesoría gratuita a la sociedad.
- La [Incubadora BUAP](https://ditco.buap.mx/incubadora/) ofrece acompañamiento
  empresarial, legal y de formalización.

No hay evidencia pública de que estas instituciones proporcionen domicilio. La
acción propuesta es presentarles el proyecto y preguntar por revisión del aviso,
incubación, patrocinio o una organización aliada; no usar su dirección sin convenio.

### Por qué no basta con afirmar que no se guardan datos

Aunque se eliminen cuentas y formularios, una operación pública puede implicar:

- una orden o fotografía con nombre y datos de salud;
- transmisión de la imagen o texto al servidor para OCR y resolución;
- IP y datos técnicos procesados por la infraestructura;
- identificadores pseudónimos para analítica;
- correos utilizados para organizar testers.

Procesar temporalmente no es lo mismo que no tratar. Google Play también exige
declarar datos enviados fuera del dispositivo aunque se procesen sólo en memoria;
si cumplen su definición de procesamiento efímero, pueden no mostrarse en la
ficha pública, pero sí deben informarse correctamente en el formulario.

Fuente: [Data Safety de Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-AE).

## Enfoque de producto: pacientes primero

Conviene posponer la apertura comercial de proveedores. El código puede permanecer
preparado, pero producción debe mantener cerrados y sin enlaces públicos:

- registro y reclamación de perfiles;
- carga de documentos;
- creación de nuevas cuentas de proveedor;
- correo operativo automático;
- suscripciones, cobros y contratos;
- dashboard de proveedores como producto comercial.

La primera versión pública puede concentrarse en:

- búsqueda sin cuenta;
- comparación de estudios, sucursales, precios, fechas y fuentes;
- procesamiento de una orden sin conservarla;
- acceso a sitios y agendas oficiales;
- feedback opcional y estructurado;
- reporte de información desactualizada.

Esto reduce soporte, datos personales, obligaciones contractuales y superficie de
seguridad. La primera pregunta de negocio pasa a ser si las personas encuentran
opciones útiles y confiables, no si un proveedor está dispuesto a pagar todavía.

## Colaboración comunitaria sin contaminar el catálogo

Los pacientes pueden detectar cambios, pero no deben publicar directamente datos
clínicos o comerciales. El flujo propuesto es:

1. seleccionar una oferta, estudio o sucursal ya existente;
2. elegir un motivo estructurado: precio desactualizado, estudio no disponible,
   dirección incorrecta, enlace roto, sucursal faltante o fuente oficial nueva;
3. indicar fecha observada y, opcionalmente, una URL pública;
4. bloquear recetas, resultados, nombres, teléfonos, correos y documentos personales;
5. guardar la propuesta en cuarentena;
6. revisar fuente, alcance y fecha desde Admin;
7. publicar sólo mediante una decisión auditable.

Una aportación de usuario es evidencia pendiente, no confirmación automática. La
similitud de texto, el volumen de reportes o una sugerencia de IA tampoco aprueban
equivalencias clínicas.

Se pueden recibir pistas de otros estados, pero deben mostrarse como pendientes.
La apertura formal de otra zona debe ocurrir cuando Puebla tenga cobertura medible
y el proceso de verificación sea mantenible.

## PWA antes de Google Play

La PWA puede publicarse e instalarse en Android desde el navegador sin una cuenta
de Play Console. Una prueba inicial de 20 personas puede medir:

- búsquedas resueltas y no resueltas;
- comprensión de resultados y cobertura parcial;
- clics hacia proveedores;
- información desactualizada;
- errores por dispositivo;
- percepción de utilidad.

Esta prueba no cuenta como prueba cerrada oficial de Google Play, pero permite
corregir el producto antes de pagar y antes de iniciar el reloj formal.

Cuando se cree la cuenta de Play Console:

- existe una cuota única vigente de 25 USD;
- cuentas personales nuevas requieren al menos 12 testers con opt-in continuo
  durante 14 días; la meta propia de Pruevia de 20 personas durante 21 días deja margen;
- deben completarse Data Safety y la declaración de aplicaciones de salud incluso
  para la prueba cerrada;
- la política de privacidad debe estar dentro de la aplicación y en una URL pública;
  Google requiere identidad y dirección legal para verificar al desarrollador.

Fuentes:

- [Registro de Play Console](https://support.google.com/googleplay/android-developer/answer/6112435?hl=es).
- [Requisitos de prueba cerrada](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB).
- [Declaración de aplicaciones de salud](https://support.google.com/googleplay/android-developer/answer/14738291?hl=es-419).
- [Información de cuenta de desarrollador](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en).
- [Tipos de cuenta](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en).

La guía de Google orienta a usar una cuenta de organización para aplicaciones de
salud. Antes de pagar debe definirse si Pruevia se publicará inicialmente como
proyecto personal o bajo una organización. Crear una organización sólo para
evitar la dirección no resuelve el problema y añade obligaciones.

## Infraestructura gratuita para el piloto

| Componente | Alternativa inicial | Límite relevante |
| --- | --- | --- |
| Landing, PWA y Admin | Cloudflare Pages | Sin garantía empresarial; funciones cuentan como Workers. |
| API | Cloudflare Workers Free | Cuotas de uso; medir antes de abrir ampliamente. |
| DNS, TLS y protección básica | Cloudflare | El dominio tiene renovación futura. |
| Correo entrante | Cloudflare Email Routing hacia Gmail | Reenvío, no buzón independiente. |
| Base producción | Primer proyecto Supabase Free | 500 MB, sin respaldos automáticos. |
| Base DEV | Segundo proyecto Supabase Free | Puede pausarse por inactividad. |
| Repositorio y CI básico | GitHub Free | No almacenar respaldos con datos personales en Git. |
| Backups | `pg_dump` cifrado y copia privada | Requiere operación y prueba de restauración propias. |

Fuentes:

- [Cloudflare Workers Free](https://developers.cloudflare.com/workers/platform/pricing/).
- [Cloudflare Email Routing](https://developers.cloudflare.com/dns/manage-dns-records/how-to/email-records/).
- [Supabase Free](https://supabase.com/pricing).

Supabase Free permite dos proyectos activos, pero los proyectos gratuitos pueden
pausarse después de una semana sin actividad y no incluyen respaldos automáticos.
Esto es aceptable para un piloto con recuperación preparada, no para prometer SLA.

No se recomienda migrar ahora a otra base o alojar producción en una computadora
personal: el costo de reescritura, seguridad y disponibilidad sería mayor que el
beneficio durante la validación.

## Aportaciones voluntarias futuras

Las aportaciones no deben ser parte de la primera prueba. Si más adelante se
habilitan:

- colocarlas inicialmente en el sitio web;
- no ofrecer funciones, contenido, posiciones, insignias ni mejor servicio;
- tratar igual a quien aporta y a quien no;
- llamarlas “aportaciones voluntarias para mantenimiento”, no “donativos
  deducibles”;
- registrar correctamente los ingresos y revisar obligaciones fiscales antes de cobrar.

Sólo una organización autorizada por el SAT puede emitir donativos deducibles.

Fuentes:

- [Donatarias autorizadas del SAT](https://www.sat.gob.mx/minisitio/DonatariasAutorizadas/tramites_solicitudes.html).
- [Política de pagos de Google Play](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en).

Google contempla aportaciones directas cuando el 100% llega al creador y no
otorgan contenido o servicios digitales, pero las reglas de pagos y enlaces
cambian. Deben revalidarse al momento de implementar, especialmente si se coloca
un enlace dentro de Android.

## Monetización posterior con proveedores

Si el uso por pacientes demuestra demanda, los proveedores podrían pagar por:

- administrar información verificada de su perfil;
- actualizar disponibilidad y precios con trazabilidad;
- consultar métricas agregadas de su propia marca o sucursal;
- integraciones de agenda o API;
- espacios promocionales claramente identificados.

El pago nunca debe modificar equivalencias clínicas, ocultar competidores ni
alterar silenciosamente el orden orgánico. El primer ingreso puede financiar
domicilio, infraestructura con respaldos y operación de datos.

## Ruta recomendada

### Etapa 0 — preparación sin apertura de datos

1. Conectar `pruevia.com.mx` a una landing informativa.
2. Configurar gratuitamente `soporte@pruevia.com.mx` y
   `privacidad@pruevia.com.mx` con reenvío.
3. Mantener cerrados testers, feedback libre y alta de proveedores.
4. Solicitar orientación al Bufete Jurídico e Incubadora BUAP.
5. Conseguir un domicilio gratuito autorizado o un patrocinio institucional.

### Etapa 1 — piloto paciente PWA

1. Publicar `app.pruevia.com.mx` sin cuenta de paciente.
2. Mostrar aviso integral y consentimiento opcional de analítica.
3. Probar con 20 personas y conservar métricas no clínicas.
4. Corregir cobertura y experiencia antes de ampliar funciones.
5. Preparar respaldo cifrado y restauración comprobada.

### Etapa 2 — comunidad

1. Añadir reportes estructurados sin archivos personales.
2. Moderar en Admin y conservar evidencia/fecha/decisión.
3. Aceptar pistas de otras zonas sin presentarlas como cobertura confirmada.

### Etapa 3 — Android cerrado

1. Definir tipo de cuenta de desarrollador.
2. Pagar una sola vez la cuota de Play Console.
3. Completar Data Safety, declaración de salud, ficha y política.
4. Reunir 20 opt-ins y entonces iniciar los 21 días.
5. Documentar uso, feedback y correcciones para solicitar acceso a producción.

### Etapa 4 — sostenibilidad

1. Evaluar aportaciones voluntarias en web.
2. Abrir proveedores sólo con aviso, operación y soporte completos.
3. Cobrar capacidades comerciales sin contaminar resultados clínicos.
4. Pasar a infraestructura pagada únicamente cuando uso, riesgo o ingresos lo justifiquen.

## Decisiones pendientes antes de publicar

- Identidad legal del responsable.
- Domicilio autorizado para notificaciones.
- Alcance del OCR durante el primer piloto.
- Retención de telemetría general y eliminación programada.
- Tipo de cuenta de Google Play.
- Política exacta de aportaciones futuras.
- Criterios medibles para abrir otra zona.

La recomendación actual es **pacientes primero, proveedores después, PWA antes de
Play y costo mensual cero durante la validación**. El principal bloqueo no es
técnico ni la renta de una oficina: es conseguir una dirección legítima gratuita
o una organización aliada y mantener el tratamiento de datos al mínimo real.
