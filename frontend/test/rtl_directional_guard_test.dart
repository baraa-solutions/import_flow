import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet guard for physical (left/right) layout APIs in lib/.
///
/// In Arabic the app is RTL, so `EdgeInsets.only(left:)`, `Alignment.centerLeft`,
/// `Border(left:)`, `BorderRadius.only(topLeft:)`, `TextAlign.left`,
/// `Positioned(left:)` and raw keyboard arrows do not mirror. Use the
/// directional forms (`EdgeInsetsDirectional`, `AlignmentDirectional`,
/// `BorderDirectional`, `BorderRadiusDirectional`, `TextAlign.start`,
/// `PositionedDirectional`, `DirectionalIcon`).
///
/// Legacy counts live in test/rtl_directional_baseline.json (per file). A file
/// may not exceed its baseline; a new file starts at 0. When you remove hazards,
/// lower the baseline (the test fails until you do, so the ratchet only tightens).
/// Regenerate after a deliberate change:
///   UPDATE_RTL_BASELINE=1 flutter test test/rtl_directional_guard_test.dart
///
/// Skipped: PDF/export/printing code (`pw.` widgets have no Directionality) and
/// CustomPainters (they paint in physical coordinates).
const _baselinePath = 'test/rtl_directional_baseline.json';

// `(?<![\w.])` skips `pw.EdgeInsets...` and other prefixed look-alikes.
final _patterns = <String, RegExp>{
  'EdgeInsets.fromLTRB': RegExp(r'(?<![\w.])EdgeInsets\.fromLTRB\('),
  'EdgeInsets.only(left/right)': RegExp(r'(?<![\w.])EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
  'Alignment.*Left/*Right': RegExp(
      r'(?<![\w.])Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b'),
  'Border(left/right)': RegExp(r'(?<![\w.])Border\([^)]*\b(left|right)\s*:'),
  'BorderRadius.only/horizontal(physical)': RegExp(
      r'(?<![\w.])BorderRadius\.(only|horizontal)\([^)]*\b(topLeft|topRight|bottomLeft|bottomRight|left|right)\s*:'),
  'TextAlign.left/right': RegExp(r'(?<![\w.])TextAlign\.(left|right)\b'),
  'Positioned(left/right)': RegExp(r'(?<![\w.])Positioned\([^)]*\b(left|right)\s*:'),
  'Icon(keyboard_arrow_left/right)': RegExp(r'(?<![\w.])Icon\(\s*Icons\.keyboard_(double_)?arrow_(left|right)'),
};

bool _isSkipped(String rel, String source) {
  final lower = rel.toLowerCase();
  if (lower.contains('export') || lower.contains('pdf') || lower.contains('print') ||
      lower.contains('painter')) {
    return true;
  }
  return source.contains('package:pdf/widgets.dart') || source.contains('extends CustomPainter');
}

String _stripComments(String source) => source
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

Map<String, int> _scan() {
  final counts = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll(r'\', '/');
    final source = entity.readAsStringSync();
    if (_isSkipped(rel, source)) continue;
    final code = _stripComments(source);
    var n = 0;
    for (final p in _patterns.values) {
      n += p.allMatches(code).length;
    }
    if (n > 0) counts[rel] = n;
  }
  return counts;
}

void main() {
  test('physical left/right layout APIs do not grow beyond the per-file baseline', () {
    expect(Directory('lib').existsSync(), isTrue, reason: 'run from the frontend/ directory');
    final current = _scan();
    final file = File(_baselinePath);

    if (Platform.environment['UPDATE_RTL_BASELINE'] == '1') {
      final sorted = Map.fromEntries(current.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
      return;
    }

    final baseline = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));

    final grown = <String>[];
    final shrunk = <String>[];
    for (final e in current.entries) {
      final allowed = baseline[e.key] ?? 0;
      if (e.value > allowed) grown.add('${e.key}: ${e.value} (baseline $allowed)');
      if (e.value < allowed) shrunk.add('${e.key}: ${e.value} (baseline $allowed)');
    }
    for (final e in baseline.entries) {
      if (!current.containsKey(e.key) && e.value > 0) shrunk.add('${e.key}: 0 (baseline ${e.value})');
    }

    expect(grown, isEmpty,
        reason: 'New non-directional layout code. Use EdgeInsetsDirectional / AlignmentDirectional / '
            'BorderDirectional / BorderRadiusDirectional / TextAlign.start / PositionedDirectional / '
            'DirectionalIcon:\n${grown.join('\n')}');
    expect(shrunk, isEmpty,
        reason: 'Hazards were removed - lower the baseline in $_baselinePath '
            '(or run with UPDATE_RTL_BASELINE=1):\n${shrunk.join('\n')}');
  });

  test('patterns catch the physical forms and ignore directional / pw. forms', () {
    int hits(String code) => _patterns.values.fold(0, (n, p) => n + p.allMatches(code).length);

    expect(hits('EdgeInsets.only(left: 4)'), 1);
    expect(hits('EdgeInsets.only(\n  top: 2,\n  right: 4)'), 1);
    expect(hits('EdgeInsets.fromLTRB(1, 2, 3, 4)'), 1);
    expect(hits('Alignment.centerLeft'), 1);
    expect(hits('Border(left: BorderSide())'), 1);
    expect(hits('BorderRadius.only(topLeft: r)'), 1);
    expect(hits('TextAlign.right'), 1);
    expect(hits('Positioned(top: 0, left: 8, child: x)'), 1);
    expect(hits('Icon(Icons.keyboard_double_arrow_left)'), 1);

    expect(hits('EdgeInsets.only(top: 4, bottom: 2)'), 0);
    expect(hits('EdgeInsetsDirectional.only(start: 4)'), 0);
    expect(hits('AlignmentDirectional.centerStart'), 0);
    expect(hits('BorderDirectional(start: s)'), 0);
    expect(hits('BorderRadius.vertical(top: r)'), 0);
    expect(hits('TextAlign.start'), 0);
    expect(hits('PositionedDirectional(start: 0)'), 0);
    expect(hits('pw.EdgeInsets.only(left: 4)'), 0);
    expect(hits('pw.Alignment.centerLeft'), 0);
    expect(hits('DirectionalIcon(Icons.keyboard_arrow_left)'), 0);
  });
}
