/// Explains a no-match without inferring a clinical study from a broad phrase.
String noMatchGuidance(String query) {
  if (RegExp(r'\bsangre\b', caseSensitive: false).hasMatch(query)) {
    return '“Sangre” indica la muestra, pero no identifica un estudio único. '
        'Escribe el nombre que aparece en tu orden; por ejemplo, '
        '“biometría hemática” sólo si eso es lo que te solicitaron.';
  }
  return 'Prueba con el nombre completo de tu orden. Si aparecen sugerencias '
      'de escritura, no son estudios confirmados: elige una para buscarla '
      'y revisa los detalles.';
}
