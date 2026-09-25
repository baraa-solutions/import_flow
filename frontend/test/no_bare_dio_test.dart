import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to construct a raw `Dio(` instance. Every other backend call
/// must go through the authenticated `dioProvider` / `uploadDioProvider`
/// (core/network/api_client.dart) so the JWT is attached.
const _allowList = <String, String>{
  // The authenticated clients themselves.
  'lib/core/network/api_client.dart': 'defines dioProvider / uploadDioProvider',
  // Login / refresh client: runs before a token exists (public routes).
  'lib/features/auth/providers/auth_provider.dart': 'login/refresh client',
  // Backend liveness probe on public /health before the app starts.
  'lib/main.dart': 'startup /health probe',
};

void main() {
  test('no bare Dio( outside the allow-list in lib/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from the frontend/ directory');

    final ctor = RegExp(r'(?<![A-Za-z0-9_])Dio\(');
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      if (_allowList.containsKey(rel)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first; // ignore comments
        if (ctor.hasMatch(code)) offenders.add('$rel:${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'Use ref.read(dioProvider) / ref.read(uploadDioProvider) instead of Dio():\n'
            '${offenders.join('\n')}');
  });

  test('allow-listed files still exist (keep the list honest)', () {
    for (final path in _allowList.keys) {
      expect(File(path).existsSync(), isTrue, reason: '$path no longer exists');
    }
  });
}
