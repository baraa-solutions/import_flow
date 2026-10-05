import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-scan guard (package B): no fabricated customs references, no fixed
/// Form 46 rates, no non-FileSaveHelper PDF export, no shell command launch.
void main() {
  final root = Directory('lib/features/import_documentation');

  List<File> dartFiles() => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String stripComments(String src) =>
      src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('feature folder exists', () {
    expect(root.existsSync(), isTrue);
  });

  test('no fixed ACID numbers or real third-party party data', () {
    final banned = <String>[
      '7595528271015010011',
      '7595528271020210010',
      '5281534391023010013',
      '528153439',
      '913205813141920259',
      '5b1b827d',
      'SCAS For Construction',
      'Suzhou Yuheng',
    ];
    final hits = <String>[];
    for (final f in dartFiles()) {
      final src = stripComments(f.readAsStringSync());
      for (final b in banned) {
        if (src.contains(b)) hits.add('${f.path}: $b');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no Form 46 hard-coded rate, FOB fallback or fake tariff', () {
    final f = File('lib/features/import_documentation/screens/customs_declaration46_screen.dart');
    final src = stripComments(f.readAsStringSync());
    expect(src.contains('const exchangeRate ='), isFalse);
    expect(src.contains('50.7917'), isFalse);
    expect(src.contains('12500.0'), isFalse);
    expect(src.contains('* 0.02'), isFalse);
    expect(src.contains('* 0.025'), isFalse);
    expect(src.contains("'8471.30.00'"), isFalse);
    expect(src.contains('statusText = l.customsDeclStatusFulfilled;'), isFalse,
        reason: 'approval status must come from data, not a constant');
  });

  test('exports use FileSaveHelper, no Printing.sharePdf', () {
    final hits = <String>[];
    for (final f in dartFiles()) {
      if (stripComments(f.readAsStringSync()).contains('Printing.sharePdf')) hits.add(f.path);
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no shell command execution with user data', () {
    final hits = <String>[];
    for (final f in dartFiles()) {
      final src = stripComments(f.readAsStringSync());
      if (src.contains("'cmd'") || src.contains('runInShell: true')) hits.add(f.path);
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no 10+ digit numeric string literals in package B files', () {
    final files = [
      'screens/nafeza_acid_screen.dart',
      'screens/customs_declaration46_screen.dart',
      'widgets/coo_review_tab.dart',
      'widgets/inspection_review_tab.dart',
      'widgets/visual_draft_coo_sheet.dart',
      'widgets/visual_draft_inspection_sheet.dart',
      'services/coo_export_service.dart',
      'services/inspection_export_service.dart',
    ];
    final re = RegExp('[\'"][0-9]{10,}[\'"]');
    final hits = <String>[];
    for (final name in files) {
      final src = stripComments(File('lib/features/import_documentation/$name').readAsStringSync());
      if (re.hasMatch(src)) hits.add(name);
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
