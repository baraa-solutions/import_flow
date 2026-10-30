import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🏛️ Strict UI Standards & Widget Unification CI Gate', () {
    final libDir = Directory('lib');

    test('Zero DropdownButtonFormField Rule across entire codebase', () {
      final violatingFiles = <String>[];
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('.g.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (content.contains('DropdownButtonFormField')) {
          violatingFiles.add(file.path);
        }
      }

      expect(
        violatingFiles,
        isEmpty,
        reason:
            'Canonical Widget Standard Violation: DropdownButtonFormField is strictly forbidden. '
            'Use SearchableDropdownField<T> from "package:frontend/core/widgets/widgets.dart" instead.\n'
            'Violating files:\n${violatingFiles.join('\n')}',
      );
    });

    test('Zero Unsanitized Clipboard.setData Rule across feature modules', () {
      final featuresDir = Directory('lib/features');
      if (!featuresDir.existsSync()) return;

      final violatingFiles = <String>[];
      final dartFiles = featuresDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('.g.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (content.contains('Clipboard.setData')) {
          violatingFiles.add(file.path);
        }
      }

      expect(
        violatingFiles,
        isEmpty,
        reason:
            'Bidi Sanitization Standard Violation: Raw Clipboard.setData is strictly forbidden in feature modules. '
            'Use CopyHelper.copy(context, text) from "package:frontend/core/widgets/widgets.dart" '
            'to ensure bidirectional Unicode isolate characters are purged before reaching the clipboard.\n'
            'Violating files:\n${violatingFiles.join('\n')}',
      );
    });

    test('Arabic l10n Anti-Stacking Rule (Zero bilingual parentheses stacking)', () {
      final arFile = File('lib/core/localization/app_localizations_ar.dart');
      expect(arFile.existsSync(), isTrue);

      // Read lines and exclude comment lines
      final content = arFile
          .readAsLinesSync()
          .where((line) => !line.trim().startsWith('//'))
          .join('\n');
      
      // Prohibited parenthesized acronym patterns in Arabic interface
      final prohibitedPatterns = [
        '(Export Excel)',
        '(PO)',
        '(FT)',
        '(ACID)',
        '(VAT)',
        '(WHT)',
        '(TSV)',
        '(LDM)',
        '(DTHC)',
        '(ATD)',
        '(GIT)',
        '(PO PKG)',
        '(HS Code)',
        '(LCL CBM)',
        '(Telex Release)',
        '(Standard COO)',
        '(GSP)',
        '(GAFTA)',
        '(Draft B/L)',
        '(GRN)',
        '(MTS)',
        '(CargoX)',
        '(DUNS)',
      ];

      final foundViolations = <String>[];
      for (final pattern in prohibitedPatterns) {
        if (content.contains(pattern)) {
          foundViolations.add(pattern);
        }
      }

      expect(
        foundViolations,
        isEmpty,
        reason:
            'Anti-Stacking Standard Violation: Found prohibited bilingual acronyms in Arabic localization: '
            '${foundViolations.join(', ')}.\nAll UI labels must be pure natural Arabic.',
      );
    });
  });
}
