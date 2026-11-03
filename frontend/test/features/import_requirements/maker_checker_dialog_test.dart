import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_requirements/models/import_requirement_model.dart';
import 'package:frontend/features/import_requirements/widgets/governance/maker_checker_dialog.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocales.localizationsDelegates,
      supportedLocales: AppLocales.supportedLocales,
      home: AppLocalizationsProvider(
        locale: const Locale('ar'),
        child: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Session 4: Maker-Checker Governance Dialog Tests', () {
    final sampleRequirement = ImportRequirementModel(
      assessmentId: 101,
      assessmentCode: 'REQ-2026-00101',
      importFileId: 5,
      importFileCode: 'IMP-2026-0005',
      hsCode: '8471.30.00',
      commodityDescription: 'أجهزة حاسب آلي محمولة',
      countryOfOrigin: 'China',
      currency: 'USD',
      shipmentValue: 50000.0,
      shipmentValueUsd: 50000.0,
      decree43Applicable: true,
      whiteListRequired: true,
      whiteListVerified: true,
      cooRequired: true,
      cooStatus: 'Obtained',
      inspectionRequired: true,
      inspectionStatus: 'Completed',
      importPermitRequired: true,
      permitStatus: 'Approved',
      msdsRequired: false,
      msdsStatus: 'Not Required',
      halalCertRequired: false,
      halalCertStatus: 'Not Required',
      coaRequired: false,
      coaStatus: 'Not Required',
      overallStatus: 'Draft',
      riskLevel: 'Low',
      assessedBy: 'كمال - استشاري التخليص الجمركي',
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

    testWidgets('1. MakerCheckerDialog renders correctly with SelectionArea and Maker metadata', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          MakerCheckerDialog(
            requirement: sampleRequirement,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Dialog Title & Subtitle
      expect(find.text('حوكمة الصلاحيات والاعتماد المزدوج'), findsOneWidget);

      // Verify Maker Assessment metadata
      expect(find.text('REQ-2026-00101'), findsOneWidget);
      expect(find.text('كمال - استشاري التخليص الجمركي'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      expect(find.text('Low'), findsWidgets);

      // Verify Decision options exist
      expect(find.text('اعتماد مطابق ومصرح للشحن'), findsOneWidget);
      expect(find.text('استثناء تنفيذي معتمد'), findsOneWidget);
      expect(find.text('رفض وإعادة للدراسة'), findsOneWidget);
    });

    testWidgets('2. Selecting Executive Override displays mandatory justification field', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          MakerCheckerDialog(
            requirement: sampleRequirement,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, override reason field should not be visible
      expect(find.text('سند ومبرر الاستثناء التنفيذي الإلزامي'), findsNothing);

      // Tap Executive Override card
      final overrideCard = find.text('استثناء تنفيذي معتمد');
      expect(overrideCard, findsOneWidget);
      await tester.tap(overrideCard);
      await tester.pumpAndSettle();

      // Now mandatory override justification field must appear
      expect(find.text('سند ومبرر الاستثناء التنفيذي الإلزامي'), findsOneWidget);
    });
  });
}
