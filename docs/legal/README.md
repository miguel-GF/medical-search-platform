# Documentación de privacidad para revisión jurídica

Empieza por [el informe en lenguaje común](REVISION_PRIVACIDAD_PARA_ABOGADO_20261015.md).
Explica el funcionamiento real, qué está publicado y qué debe resolver el abogado.

La entrega para compartir está en
`privado/PRUEVIA_REVISION_PRIVACIDAD_PARA_ABOGADO_20261015.pdf`.
Incluye el aviso actual completo y el anterior. Esa carpeta se conserva localmente
y queda fuera de Git porque reproduce el nombre y domicilio del responsable.
No se publica como descarga en el sitio.

El PDF tiene fecha de corte: no se actualiza cuando cambia el sitio. Para una
revisión futura hay que comparar el aviso y las funciones realmente publicadas,
actualizar el informe y capturar de nuevo el aviso de forma privada.

Con las capturas existentes en `privado/` se puede regenerar la entrega:

```powershell
python scripts/render_privacy_lawyer_packet.py
```

Requiere las instalaciones existentes de Chrome, Playwright y PyMuPDF. El script
no publica documentos ni envía fotografías o datos de pacientes. Deja el PDF y
su HTML en `privado/`; recibos y previsualizaciones en artefactos ignorados.

La reapertura y sus límites están registrados en
[el cierre operativo](../PRIVACY_PUBLICATION_20261015.md). Un aviso más claro y
una aplicación accesible no equivalen a un dictamen de cumplimiento.
