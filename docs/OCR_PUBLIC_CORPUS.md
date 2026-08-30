# Corpus público para pruebas OCR

Este documento registra fuentes externas que pueden usarse para pruebas locales
sin subir imágenes a Supabase ni incorporarlas al repositorio.

## Fuente principal: ClinOCR-Bench

[ClinOCR-Bench](https://github.com/ClinOCR-Bench/ClinOCR-Bench) es un corpus
sintético de documentos clínicos con transcripción auditada. Incluye seis
condiciones (normal, manuscrita, baja calidad, rotación, tablas y artefactos
mixtos), 384 documentos y licencia MIT. No es un corpus específico de recetas
de laboratorio: sirve para validar orientación, calidad, extracción de líneas y
eliminación de metadatos.

Descarga reproducible de la release `v1.0`:

```powershell
$root = Join-Path $env:TEMP "pruevia-clinocr-v1"
New-Item -ItemType Directory -Force -Path $root | Out-Null
$zip = Join-Path $root "ClinOCR-Bench-v1.0.zip"
curl.exe -L -o $zip `
  https://github.com/ClinOCR-Bench/ClinOCR-Bench/releases/download/v1.0/ClinOCR-Bench-v1.0.zip
(Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
# ce1d231138050abf7f458ba5e6bd75c6ee2f3832b72f22296843da4c5ba45457
Expand-Archive -LiteralPath $zip -DestinationPath $root -Force
```

La prueba local de una imagen es no persistente:

```powershell
cd apps/ocr-service
$env:PYTHONPATH = "src"
python -m pruevia_ocr_service.scan `
  --image "$root\ClinOCR-Bench\scans\handwriting\template_1_sample_1_handwriting.jpg" `
  --json
```

El formateador debe conservar la línea del estudio (por ejemplo, `MRI Brain
without contrast`) y descartar nombres, identificadores, teléfonos, hospitales
y narrativa del informe.

## Fuentes consideradas, no incorporadas

- [RxHandBD en Zenodo](https://zenodo.org/records/18478741): 5,578 recortes de
  palabras de recetas manuscritas, principalmente medicamentos y etiquetas en
  inglés/bengalí; no representa órdenes de laboratorio en español.
- [Medical Prescription OCR Dataset en Hugging Face](https://huggingface.co/datasets/chinmays18/medical-prescription-dataset):
  declara prescripciones sintéticas, pero el repositorio no ofrece en su ficha
  una licencia de datos suficientemente clara para copiar imágenes al producto.
- [Colección de Mendeley](https://data.mendeley.com/datasets/k62rfd23kz/2):
  contiene imágenes desidentificadas y licencia CC BY 4.0, pero está enfocada
  en medicamentos de Bangladesh; se mantiene como referencia externa.

Las recetas proporcionadas por el usuario se tratan como datos de prueba
privados: se conserva el resultado textual y los casos dorados, no la imagen
original, salvo autorización explícita.
