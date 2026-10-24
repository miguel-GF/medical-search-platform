import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Stamp only generated public build files. No source or user data is modified.
String stampWebRelease(Directory output) {
  final index = File('${output.path}/index.html');
  final main = File('${output.path}/main.dart.js');
  final bootstrap = File('${output.path}/flutter_bootstrap.js');
  const meta = '<meta name="pruevia-build" content="__PRUEVIA_BUILD__">';
  var indexTemplate = index.readAsStringSync().replaceAll(
    RegExp(r'<meta name="pruevia-build" content="[^"]*">'),
    meta,
  );
  if (!indexTemplate.contains(meta) || !main.existsSync() || !bootstrap.existsSync()) {
    throw StateError(
      'Public build lacks update metadata placeholders or JavaScript',
    );
  }
  // Immutable entry URLs prevent an older installed worker from supplying its
  // cached bootstrap/main under the otherwise unchanged Flutter filenames.
  final mainHash = sha256.convert(main.readAsBytesSync()).toString();
  final mainName = 'main.$mainHash.dart.js';
  final mainPath = RegExp(r'"mainJsPath":"main(?:\.[a-f0-9]{64})?\.dart\.js"');
  final bootstrapSource = bootstrap.readAsStringSync();
  if (mainPath.allMatches(bootstrapSource).length != 1) {
    throw StateError('Expected exactly one Flutter JavaScript entrypoint');
  }
  final bootstrapBytes = utf8.encode(bootstrapSource.replaceAll(
    mainPath, '"mainJsPath":"$mainName"',
  ));
  final bootstrapHash = sha256.convert(bootstrapBytes).toString();
  final bootstrapName = 'flutter_bootstrap.$bootstrapHash.js';
  File('${output.path}/$mainName').writeAsBytesSync(main.readAsBytesSync());
  bootstrap.writeAsBytesSync(bootstrapBytes);
  File('${output.path}/$bootstrapName').writeAsBytesSync(bootstrapBytes);
  final bootstrapTag = RegExp(r'src="flutter_bootstrap(?:\.[a-f0-9]{64})?\.js"');
  if (bootstrapTag.allMatches(indexTemplate).length != 1) {
    throw StateError('Expected exactly one bootstrap script in public HTML');
  }
  indexTemplate = indexTemplate.replaceAll(bootstrapTag, 'src="$bootstrapName"');
  final files =
      output
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final fingerprints = <String, String>{};
  for (final file in files) {
    final name = file.path
        .substring(output.path.length + 1)
        .replaceAll('\\', '/');
    if (name == 'app-version.json') continue;
    if (RegExp(r'^(main\.[a-f0-9]{64}\.dart|flutter_bootstrap\.[a-f0-9]{64})\.js$').hasMatch(name) &&
        name != mainName && name != bootstrapName) continue;
    final bytes = name == 'index.html'
        ? utf8.encode(indexTemplate)
        : file.readAsBytesSync();
    fingerprints[name] = sha256.convert(bytes).toString();
  }
  final build = sha256
      .convert(utf8.encode(jsonEncode(fingerprints)))
      .toString();
  index.writeAsStringSync(indexTemplate.replaceAll('__PRUEVIA_BUILD__', build));
  File('${output.path}/app-version.json').writeAsStringSync(
    '${jsonEncode({'schema': 1, 'build': build, 'main_js_sha256': sha256.convert(main.readAsBytesSync()).toString()})}\n',
  );
  return build;
}

void main(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != '--output') {
    stderr.writeln(
      'usage: dart run tool/stamp_web_release.dart --output BUILD_DIRECTORY',
    );
    exitCode = 2;
    return;
  }
  stdout.writeln('Public build: ${stampWebRelease(Directory(arguments[1]))}');
}
