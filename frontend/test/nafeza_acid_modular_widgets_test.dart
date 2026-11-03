import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/screens/nafeza_acid_screen.dart';
import 'package:frontend/features/import_documentation/widgets/acid_expiry_tracker_strip.dart';
import 'package:frontend/features/import_documentation/widgets/acid_items_compliance_checklist.dart';
import 'package:frontend/features/import_documentation/widgets/nafeza_acid_registration_tab.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String responseBody = '[]';
    if (options.path.contains('tracker')) {
      responseBody = jsonEncode({
        'items': [],
        'total_acids_count': 0,
        'valid_count': 0,
        'expiring_soon_count': 0,
        'expired_count': 0,
      });
    } else if (options.path.contains('compare')) {
      responseBody = jsonEncode({
        'all_matched': true,
        'has_critical_error': false,
        'match_percentage': 100.0,
        'total_compared_fields': 0,
        'matched_count': 0,
        'discrepant_count': 0,
        'items': [],
      });
    }

    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget createTestableWidget(Widget child, {Locale locale = const Locale('ar')}) {
  final mockDio = Dio()..httpClientAdapter = _MockHttpAdapter();

  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(mockDio),
      localeProvider.overrideWith((ref) {
        final n = LocaleNotifier();
        n.setLocale(locale);
        return n;
      }),
    ],
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Material(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nafeza ACID Modular Architecture Tests', () {
    testWidgets('NafezaAcidScreen renders VerticalStageScaffold with PHASE-1 badge and BackToDashboardButton', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestableWidget(const NafezaAcidScreen(initialSubTab: 0)),
      );
      await tester.pumpAndSettle();

      // Verify VerticalStageScaffold is present
      expect(find.byType(VerticalStageScaffold), findsOneWidget);

      // Verify stageCode badge is PHASE-1: NAFEZA_ACID
      final scaffold = tester.widget<VerticalStageScaffold>(find.byType(VerticalStageScaffold));
      expect(scaffold.stageCode, equals('PHASE-1: NAFEZA_ACID'));

      // Verify BackToDashboardButton is in headerActions
      expect(find.byType(BackToDashboardButton), findsWidgets);

      // Verify SelectionArea wraps the screen
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('NafezaAcidRegistrationTab renders form elements properly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestableWidget(const SingleChildScrollView(child: NafezaAcidRegistrationTab())),
      );
      await tester.pumpAndSettle();

      // Verify form elements
      expect(find.byKey(const Key('saveAcidRequestSubmitBtn')), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('AcidItemsComplianceChecklist renders empty state and comparison structure', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestableWidget(const SingleChildScrollView(child: AcidItemsComplianceChecklist())),
      );
      await tester.pumpAndSettle();

      // Comparison run button
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('AcidItemsComplianceChecklist displays discrepancy items when comparison result is provided', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyResult = AcidComparisonResult(
        allMatched: false,
        hasCriticalError: false,
        matchPercentage: 80.0,
        totalComparedFields: 5,
        matchedCount: 4,
        discrepantCount: 1,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_name',
            labelAr: 'اسم المستورد',
            labelEn: 'Importer Name',
            requestedValue: 'شركة الاستيراد المتحدة',
            generatedValue: 'شركة الاستيراد المتحدة',
            isMatched: true,
            severity: 'info',
          ),
          AcidDiscrepancyItem(
            field: 'proforma_invoice_no',
            labelAr: 'رقم الفاتورة المبدئية',
            labelEn: 'Proforma Invoice No.',
            requestedValue: 'PI-2026-001',
            generatedValue: 'PI-2026-002',
            isMatched: false,
            severity: 'warning',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestableWidget(SingleChildScrollView(child: AcidItemsComplianceChecklist(comparisonResult: dummyResult))),
      );
      await tester.pumpAndSettle();

      expect(find.text('اسم المستورد'), findsOneWidget);
      expect(find.text('رقم الفاتورة المبدئية'), findsOneWidget);
      expect(find.text('PI-2026-001'), findsOneWidget);
      expect(find.text('PI-2026-002'), findsOneWidget);
    });

    testWidgets('AcidExpiryTrackerStrip renders summary cards and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestableWidget(const SingleChildScrollView(child: AcidExpiryTrackerStrip())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('acidExpiryTrackerSearchField')), findsOneWidget);
      expect(find.byKey(const Key('acidExpiryCopyBtn')), findsOneWidget);
      expect(find.byKey(const Key('acidExpiryExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('acidExpiryPdfBtn')), findsOneWidget);
    });

    testWidgets('SubTab switching operates correctly across tabs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestableWidget(const NafezaAcidScreen(initialSubTab: 4)),
      );
      await tester.pumpAndSettle();

      // Tab 4 is Expiry Tracker Strip
      expect(find.byType(AcidExpiryTrackerStrip), findsOneWidget);
    });
  });
}
