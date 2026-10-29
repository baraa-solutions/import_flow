import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/import_requirements/widgets/pillars/pillars.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocales.localizationsDelegates,
    supportedLocales: AppLocales.supportedLocales,
    theme: AppTheme.lightTheme,
    home: AppLocalizationsProvider(
      locale: const Locale('ar'),
      child: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Session 2: 5 Regulatory Pillars & Workspace Tests', () {
    testWidgets('1. Pillar 1: Decree 43 renders, has SelectionArea, and triggers callbacks', (tester) async {
      bool applicable = false;
      bool verified = false;
      bool justRequested = false;
      bool taskCreated = false;
      final regCtrl = TextEditingController(text: 'REG-12345');

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (ctx, setState) => Pillar1Decree43Widget(
              decree43Applicable: applicable,
              whiteListVerified: verified,
              factoryRegCtrl: regCtrl,
              decree43Action: null,
              decree43Justification: null,
              onDecree43ApplicableChanged: (v) => setState(() => applicable = v),
              onWhiteListVerifiedChanged: (v) => setState(() => verified = v),
              onRequestJustification: () => justRequested = true,
              onCreateDashboardTask: () => taskCreated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify factory registration text
      expect(find.text('REG-12345'), findsOneWidget);

      // Verify CheckboxListTiles
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      // Toggle Applicable checkbox
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(applicable, isTrue);

      // Verify Decision Card appears when applicable and not verified
      expect(find.text('REG-12345'), findsOneWidget);
      expect(find.byType(AppButton), findsNWidgets(2));

      // Tap justification request
      await tester.tap(find.byType(AppButton).first);
      expect(justRequested, isTrue);

      // Tap task creation
      await tester.tap(find.byType(AppButton).last);
      expect(taskCreated, isTrue);

      regCtrl.dispose();
    });

    testWidgets('2. Pillar 2: Certificate of Origin renders, has SelectionArea, and handles inputs', (tester) async {
      bool cooReq = false;
      String? cooType = 'EUR.1';
      String cooStatus = 'Pending';
      final notesCtrl = TextEditingController(text: 'Preferential Tariff Note');

      await tester.pumpWidget(
        _buildTestApp(
          Pillar2CooWidget(
            cooRequired: cooReq,
            cooType: cooType,
            cooStatus: cooStatus,
            cooNotesCtrl: notesCtrl,
            onCooRequiredChanged: (v) => cooReq = v,
            onCooTypeChanged: (v) => cooType = v,
            onCooStatusChanged: (v) => cooStatus = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify notes text
      expect(find.text('Preferential Tariff Note'), findsOneWidget);

      // Verify copy icon button
      expect(find.byIcon(Icons.copy), findsOneWidget);

      // Verify SearchableDropdownField widgets
      expect(find.byType(SearchableDropdownField<String>), findsNWidgets(2));

      notesCtrl.dispose();
    });

    testWidgets('3. Pillar 3: Pre-Shipment Inspection renders with accredited bodies and report fields', (tester) async {
      final repCtrl = TextEditingController(text: 'ILAC-2026-99');
      final notesCtrl = TextEditingController(text: 'Inspection at port of loading');

      await tester.pumpWidget(
        _buildTestApp(
          Pillar3InspectionWidget(
            inspectionRequired: true,
            inspectionBody: 'SGS',
            inspectionStatus: 'Completed',
            inspReportNoCtrl: repCtrl,
            inspNotesCtrl: notesCtrl,
            onInspectionRequiredChanged: (_) {},
            onInspectionBodyChanged: (_) {},
            onInspectionStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Report No & Notes
      expect(find.text('ILAC-2026-99'), findsOneWidget);
      expect(find.text('Inspection at port of loading'), findsOneWidget);

      // 2 copy buttons (one per field)
      expect(find.byIcon(Icons.copy), findsNWidgets(2));

      repCtrl.dispose();
      notesCtrl.dispose();
    });

    testWidgets('4. Pillar 4: Prior Regulatory Permits renders authority dropdown and permit controls', (tester) async {
      final permitCtrl = TextEditingController(text: 'GOEIC-PERM-552');
      final notesCtrl = TextEditingController(text: 'Valid for 6 months');

      await tester.pumpWidget(
        _buildTestApp(
          Pillar4PermitsWidget(
            importPermitRequired: true,
            permitIssuingAuthority: 'GOEIC',
            permitStatus: 'Approved',
            permitNumberCtrl: permitCtrl,
            permitNotesCtrl: notesCtrl,
            onImportPermitRequiredChanged: (_) {},
            onPermitIssuingAuthorityChanged: (_) {},
            onPermitStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Permit No & Notes
      expect(find.text('GOEIC-PERM-552'), findsOneWidget);
      expect(find.text('Valid for 6 months'), findsOneWidget);

      permitCtrl.dispose();
      notesCtrl.dispose();
    });

    testWidgets('5. Pillar 5: Technical Certificates & Sailing Readiness renders checklist and sailing controls', (tester) async {
      final dateCtrl = TextEditingController(text: '2026-11-15');
      final notesCtrl = TextEditingController(text: 'MSDS verified by safety officer');

      await tester.pumpWidget(
        _buildTestApp(
          Pillar5TechCertsWidget(
            msdsRequired: true,
            halalCertRequired: false,
            coaRequired: true,
            sailingStatus: 'Cleared for Sailing',
            riskLevel: 'Low',
            overallStatus: 'Confirmed',
            sailingDateCtrl: dateCtrl,
            specialNotesCtrl: notesCtrl,
            onMsdsRequiredChanged: (_) {},
            onHalalCertRequiredChanged: (_) {},
            onCoaRequiredChanged: (_) {},
            onSailingStatusChanged: (_) {},
            onRiskLevelChanged: (_) {},
            onOverallStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify sailing date and notes
      expect(find.text('2026-11-15'), findsOneWidget);
      expect(find.text('MSDS verified by safety officer'), findsOneWidget);

      // 3 Checkboxes (MSDS, Halal, COA)
      expect(find.byType(CheckboxListTile), findsNWidgets(3));

      // 3 Dropdowns (Sailing Status, Risk Level, Overall Status)
      expect(find.byType(SearchableDropdownField<String>), findsNWidgets(3));

      dateCtrl.dispose();
      notesCtrl.dispose();
    });

    testWidgets('6. AdaptivePillarAlertBanner reactively updates content across pillar indices', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AdaptivePillarAlertBanner(
            activePillarIndex: 0,
            hsCode: '3901.20',
            commodityDescription: 'Polyethylene resin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify HS Code rendered in banner
      expect(find.textContaining('3901.20'), findsOneWidget);

      // Shield icon is present
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Re-pump with activePillarIndex = 2 (Inspection)
      await tester.pumpWidget(
        _buildTestApp(
          const AdaptivePillarAlertBanner(
            activePillarIndex: 2,
            hsCode: '3901.20',
            commodityDescription: 'Polyethylene resin',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('7. PillarsWorkspaceCard switches tabs and renders children in SelectionArea', (tester) async {
      int activeTab = 0;

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (ctx, setState) => PillarsWorkspaceCard(
              activePillarIndex: activeTab,
              onPillarTabSelected: (idx) => setState(() => activeTab = idx),
              whiteListVerified: true,
              cooFulfilled: false,
              inspectionFulfilled: true,
              permitFulfilled: false,
              techCertsFulfilled: true,
              hsCode: '8471.30',
              commodityDescription: 'Laptops',
              pillar1Child: const Text('CONTENT_PILLAR_1'),
              pillar2Child: const Text('CONTENT_PILLAR_2'),
              pillar3Child: const Text('CONTENT_PILLAR_3'),
              pillar4Child: const Text('CONTENT_PILLAR_4'),
              pillar5Child: const Text('CONTENT_PILLAR_5'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea is present at card root
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Pillar 1 content is visible initially
      expect(find.text('CONTENT_PILLAR_1'), findsOneWidget);

      // Find tab for Pillar 2 and tap it
      final tabs = find.byType(InkWell);
      expect(tabs, findsNWidgets(5));

      await tester.tap(tabs.at(1));
      await tester.pumpAndSettle();

      expect(activeTab, equals(1));
      expect(find.text('CONTENT_PILLAR_2'), findsOneWidget);
    });

    testWidgets('8. Decree43JustificationDialog renders with SelectionArea and sample chips', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Decree43JustificationDialog(
            initialJustification: 'Test existing justification',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SelectionArea is present
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify existing text
      expect(find.text('Test existing justification'), findsOneWidget);

      // Verify ActionChips exist for sample reasons
      expect(find.byType(ActionChip), findsWidgets);

      // Tap first ActionChip
      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      // Verify Save and Cancel buttons exist
      expect(find.byType(AppButton), findsNWidgets(2));
    });
  });
}
