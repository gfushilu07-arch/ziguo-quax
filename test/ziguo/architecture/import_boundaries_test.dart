import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ziguo/check_boundaries.dart';

void main() {
  test('production features depend only on own interfaces', () {
    expect(boundaryViolations(Directory.current), isEmpty);
  });
  test('detects both package imports and relative escapes', () {
    final root = Directory.systemTemp.createTempSync('ziguo-boundaries-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/lib/ziguo/features/example.dart')
      ..createSync(recursive: true);
    file.writeAsStringSync(
      "import 'package:quax/client/client.dart';\nimport '../../client/client.dart';\nimport '../domain/source_ref.dart';\nimport 'package:quax/ziguo/domain/source_ref.dart';\n",
    );
    expect(boundaryViolations(root), hasLength(2));
  });
}
