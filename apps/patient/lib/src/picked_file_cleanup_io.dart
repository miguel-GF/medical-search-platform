import 'dart:io';

Future<void> deletePickedFile(String path) async {
  // image_picker normally stages captures in the app cache/temp directory.
  // Never delete a user-selected original outside those disposable roots.
  try {
    final file = File(path);
    if (!await file.exists()) return;
    final temporaryRoot = _canonical(await Directory.systemTemp.resolveSymbolicLinks());
    final canonicalFile = _canonical(await file.resolveSymbolicLinks());
    final root = temporaryRoot.endsWith('/') ? temporaryRoot : '$temporaryRoot/';
    if (!canonicalFile.startsWith(root)) return;
    await file.delete();
  } catch (_) {
    // Best effort: the bytes are already released and the OS owns cache GC.
  }
}

String _canonical(String value) => value.replaceAll('\\', '/').toLowerCase();
