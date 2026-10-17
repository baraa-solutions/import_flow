import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_documentation/widgets/extraction_match_status_chip.dart';

void main() {
  Future<Chip> pumpChip(
    WidgetTester tester,
    String status,
    Object? severity, {
    Locale locale = const Locale('ar'),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Scaffold(
          body: ExtractionMatchStatusChip(matchStatus: status, severity: severity),
        ),
      ),
    ));
    return tester.widget<Chip>(find.byType(Chip));
  }

  group('ExtractionMatchStatusChip', () {
    testWidgets('EXTRACTION_FAILED shows idocBNotExtracted on charcoal regardless of severity', (tester) async {
      final chip = await pumpChip(tester, 'EXTRACTION_FAILED', 'BLOCKING');
      expect(find.text('لم يتم الاستخراج'), findsOneWidget);
      expect(chip.backgroundColor, AppTheme.charcoal);
    });

    testWidgets('labels follow the active locale', (tester) async {
      await pumpChip(tester, 'EXTRACTION_FAILED', null, locale: const Locale('en'));
      expect(find.text('Not extracted'), findsOneWidget);
      await pumpChip(tester, 'MATCH', null, locale: const Locale('en'));
      expect(find.text('Matched'), findsOneWidget);
    });

    testWidgets('MATCH shows idocBMatched and uses severity colour (emerald when no severity)', (tester) async {
      final chip = await pumpChip(tester, 'MATCH', null);
      expect(find.text('متطابق'), findsOneWidget);
      expect(chip.backgroundColor, AppTheme.emerald);
    });

    testWidgets('other statuses show the raw status text', (tester) async {
      final chip = await pumpChip(tester, 'MISMATCH', 'BLOCKING');
      expect(find.text('MISMATCH'), findsOneWidget);
      expect(chip.backgroundColor, AppTheme.crimson);
    });

    testWidgets('WARNING severity is orange', (tester) async {
      final chip = await pumpChip(tester, 'MISMATCH', 'WARNING');
      expect(chip.backgroundColor, AppTheme.orange);
    });

    testWidgets('MATCH with BLOCKING severity is still crimson (severity drives colour)', (tester) async {
      final chip = await pumpChip(tester, 'MATCH', 'BLOCKING');
      expect(chip.backgroundColor, AppTheme.crimson);
    });

    testWidgets('non-string severity falls back to emerald', (tester) async {
      final chip = await pumpChip(tester, '', 42);
      expect(chip.backgroundColor, AppTheme.emerald);
    });

    testWidgets('label style is 11px white', (tester) async {
      await pumpChip(tester, 'MATCH', null);
      final text = tester.widget<Text>(find.text('متطابق'));
      expect(text.style?.fontSize, 11);
      expect(text.style?.color, AppTheme.white);
    });
  });
}
