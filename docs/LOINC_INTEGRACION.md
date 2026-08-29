# Integración de LOINC en Pruevia

Este documento define la primera integración de LOINC sin convertirlo en la
identidad primaria del catálogo ni introducir una segunda base de datos.

## Qué se integra

LOINC es una terminología externa para identificar observaciones y estudios de
laboratorio. En Pruevia se usará como evidencia y mapping:

```text
catalog.items.id                 identidad interna estable
catalog.item_identifiers         system=loinc, code, version
health.lab_service_definitions   component/property/system/method/etc.
catalog.item_aliases             aliases aprobados en es-MX
health.service_components        composición de paneles
```

Los nombres comerciales, precios, sucursales y disponibilidad permanecen en
las tablas de catálogo y supply de Pruevia. LOINC no publica esos datos.

## Fuente y credenciales

La versión inicial debe ser la versión vigente que se obtenga de la descarga
oficial. El sitio de LOINC publica la versión, fecha, URL y MD5 del archivo; la
API exige usuario y contraseña mediante Basic Authentication. El registro es
gratuito, pero las credenciales nunca se guardan en Git.

La descarga oficial y el uso comercial están sujetos a la licencia LOINC. El
archivo completo y los índices derivados se mantienen fuera del repositorio en
`database/artifacts/loinc/`, que está ignorado por Git.

## Flujo reproducible

Ejecutar desde la raíz del repositorio:

```powershell
$env:LOINC_USERNAME = Read-Host "LOINC username"
$env:LOINC_PASSWORD = Read-Host "LOINC password"

python database/scripts/loinc_release.py metadata
python database/scripts/loinc_release.py download --output-dir database/artifacts/loinc

python database/scripts/loinc_release.py extract `
  --zip database/artifacts/loinc/Loinc_<VERSION>.zip `
  --output-dir database/artifacts/loinc/<VERSION>

python database/scripts/loinc_release.py index `
  --csv database/artifacts/loinc/<VERSION>/Loinc.csv `
  --class LAB `
  --output database/artifacts/loinc/<VERSION>/loinc_lab_active.jsonl
```

`download` valida el MD5 publicado por LOINC y elimina el ZIP si no coincide.
`index` conserva sólo los campos necesarios para búsqueda y revisión; por
defecto excluye términos deprecated/discouraged.

## Fixture de mappings

Los reviewers deben crear un fixture pequeño (por ejemplo,
`database/fixtures/loinc_mappings_v1.json`) y no editar SQL a mano:

```json
{
  "loinc_version": "2.83",
  "mappings": [
    {
      "item_id": "00000000-0000-0000-0000-000000001103",
      "loinc_code": "57021-8",
      "mapping_type": "exact",
      "verified": true,
      "approved": true,
      "source_note": "RELMA reviewed",
      "attributes": {
        "component": "Complete blood count",
        "property": "Number concentration",
        "time_aspect": "Point in time",
        "system": "Blood",
        "scale_type": "Quantitative",
        "method": "",
        "order_observation": "both"
      }
    }
  ]
}
```

El código de ejemplo es únicamente la forma del fixture; cada código debe
confirmarse en la release descargada antes de usarlo. Para generar la
migración revisable:

```powershell
python database/scripts/render_loinc_mapping.py `
  --fixture database/fixtures/loinc_mappings_v1.json `
  --output database/supabase/migrations/20260828xxxxxx_loinc_mappings_v1.sql
```

El renderer rechaza códigos inválidos, mappings duplicados y mappings `exact`
sin aprobación explícita.

El renderer rechaza códigos inválidos, mappings duplicados y mappings `exact`
sin verificación. Un mapping no exacto (`narrower`, `broader`, `related` o
`local`) sólo se publica si está activo y tiene `approved=true`; una sugerencia
no aprobada debe permanecer fuera de la migración.

## Mapeo seguro

La descarga no publica nada automáticamente. Cada mapping debe pasar por esta
secuencia:

1. seleccionar un `catalog.item` canónico de Pruevia;
2. buscar candidatos en RELMA/SearchLOINC;
3. verificar componente, propiedad, tiempo, sistema/muestra, escala y método;
4. verificar si es `order`, `observation` o `both`;
5. verificar todos los componentes obligatorios cuando sea un panel;
6. guardar el mapping en un fixture revisable;
7. publicar sólo códigos activos con `mapping_type=exact` o una relación
   explícitamente aprobada.

Un término fuzzy, vectorial o sugerido por IA sólo genera una propuesta. No
puede crear un alias global ni una equivalencia comercial por sí solo.

## Primera tanda

La primera tanda debe cubrir los servicios ya existentes y de mayor uso:

- biometría hemática;
- examen general de orina;
- glucosa;
- creatinina;
- TSH, T4 libre y T3;
- paneles de química sanguínea y perfil tiroideo sólo después de revisar su
  composición.

Electromiografía y otros estudios no laboratoriales se revisan aparte; no se
les asigna LOINC por similitud de nombre sin confirmar su clase y atributos.

## Actualizaciones y rollback

Cada release se identifica por versión, fecha, MD5 y hash local. Una nueva
versión no reemplaza silenciosamente la anterior:

```text
download → validate → compare → review deprecated/map_to → publish migration
```

Si un código queda deprecated, se conserva el historial y sólo se activa su
reemplazo después de revisión. El resolver mantiene el mapping anterior hasta
que la nueva migración sea validada.

## Criterios de salida

La primera integración se considera correcta cuando:

- el release se descargó y verificó reproduciblemente;
- todos los mappings tienen versión y evidencia;
- ningún alias no revisado se publicó;
- los paneles tienen composición explícita o permanecen ambiguos;
- `/search` y `/resolve` usan el mismo resolver (`clinical-resolver-v6`);
- las pruebas de paridad y las pruebas de catálogo pasan;
- el tamaño de Supabase sigue dentro del límite operativo elegido.

La tabla completa de LOINC no se subirá a Supabase en esta etapa. Sólo se
publicarán mappings y atributos revisados; el índice completo permanecerá
local hasta demostrar que el buscador necesita recuperarlo en tiempo de
ejecución.
