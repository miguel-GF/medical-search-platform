# Worker privado de documentos

Este proceso no expone HTTP. Ejecuta una tanda acotada con
`pruevia-document-scanner --limit 10` desde un job privado y sale. Necesita:

- `SUPABASE_URL`: origen HTTPS exacto, sin ruta, query ni fragmento.
- `SUPABASE_SECRET_KEY`: secreto de servidor, solo en el gestor de secretos.
- `CLAMD_SOCKET`: socket Unix privado (por defecto `/run/clamav/clamd.sock`).

ClamAV debe correr como un daemon local aislado y solo exponerse por ese socket;
no se admite `TCPSocket`, porque el protocolo TCP de `clamd` no autentica a sus
clientes. El daemon debe tener `StreamMaxLength` de al menos 10 MiB, límites de
cola/hilos, `ReadTimeout` y `CommandReadTimeout` finitos, y `freshclam` debe
actualizar sus firmas desde un canal controlado. Si la versión o firmas no son
aceptables, el worker falla cerrado.

El worker descarga únicamente la clave emitida por la cola de la base de datos,
sin redirecciones ni proxies, limita la respuesta a 10 MiB, calcula SHA-256,
comprueba firmas de PDF/PNG/JPEG, verifica la extensión, analiza por `INSTREAM`
y registra solo estados `clean`, `infected` o `error`. Nunca registra bytes,
URLs completas, tokens ni mensajes de ClamAV. Solo `clean` con hash coincidente
puede satisfacer la restricción de la base; después aún hace falta revisión
administrativa explícita.

La imagen o job que lo ejecute debe montar únicamente el socket Unix y el
secreto. No se debe añadir una ruta del Worker, un endpoint público, un proxy
HTTP hacia el scanner ni una política de Storage que otorgue `anon` acceso.
