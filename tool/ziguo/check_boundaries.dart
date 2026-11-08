import 'dart:io';

/// Resolves relative imports too; string-prefix checks alone can be bypassed.
List<String> boundaryViolations(Directory root) {
  final violations = <String>[];
  final lib = Directory('${root.path}/lib').absolute.uri;
  for (final area in ['features', 'domain', 'data']) {
    final directory = Directory('${root.path}/lib/ziguo/$area');
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in RegExp(
        "(?:import|export|part)\\s+['\"]([^'\"]+)['\"]",
      ).allMatches(file.readAsStringSync())) {
        final path = match.group(1)!;
        var forbidden =
            path.startsWith('package:quax/') &&
            !path.startsWith('package:quax/ziguo/');
        if (!path.contains(':')) {
          final resolved = file.absolute.uri.resolve(path).normalizePath();
          forbidden =
              resolved.toString().startsWith(lib.toString()) &&
              !resolved.toString().startsWith(lib.resolve('ziguo/').toString());
        }
        if (forbidden) violations.add('${file.path}: $path');
      }
    }
  }
  return violations;
}

void main(List<String> args) {
  final failures = boundaryViolations(
    Directory(args.isEmpty ? '.' : args.first),
  );
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln('Ziguo import boundaries: passed');
  }
}
