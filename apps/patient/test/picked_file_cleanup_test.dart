import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pruevia_patient/src/picked_file_cleanup_io.dart';

void main() {
  test('deletes picker files staged below the operating-system temp root', () async {
    final directory = await Directory.systemTemp.createTemp('pruevia-picker-');
    final file = File('${directory.path}${Platform.pathSeparator}order.jpg');
    await file.writeAsBytes(const [0xff, 0xd8, 0xff]);
    try {
      await deletePickedFile(file.path);
      expect(await file.exists(), isFalse);
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('does not delete an original merely because its path contains temp', () async {
    final directory = await Directory.current.createTemp('pruevia-picker-original-');
    final nested = Directory('${directory.path}${Platform.pathSeparator}temp');
    await nested.create();
    final file = File('${nested.path}${Platform.pathSeparator}order.jpg');
    await file.writeAsBytes(const [0xff, 0xd8, 0xff]);
    try {
      await deletePickedFile(file.path);
      expect(await file.exists(), isTrue);
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
