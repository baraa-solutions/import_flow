import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/customs_clearance/screens/customs_clearance_screen.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockClearanceNotifier extends CustomsClearanceNotifier {
  final List<CustomsClearanceModel> initialRecords;
  _MockClearanceNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search,
  }) async {
    state = AsyncValue.data(initialRecords);
  }
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  _MockImportFilesNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = const AsyncValue.data([]);
  }
}

class _MockPartnersNotifier extends PartnersNotifier {
  _MockPartnersNotifier() : super(category: 'All', showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPartners({
    String? category,
    bool includeInactive = false,
    String? search,
  }) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  final mockClearance = CustomsClearanceModel(
    customsClearanceId: 10,
    clearanceCode: 'CLR-2026-0010',
    importFileId: 101,
    declaration46No: '46-ALX-2026-991',
    customsOfficeName: 'Alexandria Sea Port',
    channelType: 'Red Channel',
    totalDutyPayable: 63000.0,
    actualDutyTotal: 63000.0,
    paymentStatus: 'Paid & Verified',
    status: 'Duty Paid',
    deliveryOrderNumber: 'DO-MEDU-99881',
    freeDaysAllowed: 14,
    createdAt: '2026-08-23T00:00:00Z',
    updatedAt: '2026-08-23T00:00:00Z',
    owner: 'Admin',
  );

  group('CustomsClearanceScreen 4 Subtabs Tests', () {
    testWidgets('Renders Tab 0 (Customs Clearance Follow-up) correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([mockClearance])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('CLR-2026-0010'), findsWidgets);
      expect(find.textContaining('46-ALX-2026-991'), findsWidgets);
    });

    testWidgets('Renders Tab 1 (Drawing Samples & Shortage) correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([mockClearance])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 1),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('سحب العينات'), findsWidgets);
      expect(find.textContaining('تسجيل سحب عينة'), findsOneWidget);
    });

    testWidgets('Renders Tab 2 (Discrepancy & Damage) correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([mockClearance])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 2),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('الفاقد والتلف'), findsWidgets);
      expect(find.textContaining('تحرير محضر'), findsOneWidget);
    });

    testWidgets('Renders Tab 3 (Final Customs Duty Payment & Release) correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([mockClearance])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 3),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('سداد الرسوم والضرائب'), findsWidgets);
      expect(find.textContaining('سجل أذون سداد نافذة'), findsOneWidget);
    });

    testWidgets('FE07-T04: Card for a released record gates pay, release, and under-bond buttons', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final releasedRecord = CustomsClearanceModel(
        customsClearanceId: 20,
        clearanceCode: 'CLR-2026-0020',
        importFileId: 101,
        declaration46No: '46-ALX-2026-992',
        customsOfficeName: 'Alexandria Sea Port',
        channelType: 'Green Channel',
        nafezaClaimNumber: 'CLM-2026-0020',
        totalDutyPayable: 63000.0,
        actualDutyTotal: 63000.0,
        paymentStatus: 'Paid & Verified',
        status: 'Final Release Granted',
        releasePermitNo: 'REL-2026-0020',
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
        owner: 'Admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([releasedRecord])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pay button must be disabled (onPressed == null)
      final payBtnFinder = find.byKey(const Key('payDutyBtn_CLR-2026-0020'));
      expect(payBtnFinder, findsOneWidget);
      final IconButton payBtn = tester.widget(payBtnFinder);
      expect(payBtn.onPressed, isNull);
      expect(payBtn.tooltip, equals('تم الإفراج الجمركي النهائي بالفعل'));

      // Final release button must be disabled (onPressed == null)
      final releaseBtnFinder = find.byKey(const Key('finalReleaseBtn_CLR-2026-0020'));
      expect(releaseBtnFinder, findsOneWidget);
      final IconButton releaseBtn = tester.widget(releaseBtnFinder);
      expect(releaseBtn.onPressed, isNull);
      expect(releaseBtn.tooltip, equals('تم الإفراج الجمركي النهائي بالفعل'));

      // Under-bond button must be disabled (onPressed == null)
      final underBondBtnFinder = find.byKey(const Key('underBondBtn_CLR-2026-0020'));
      expect(underBondBtnFinder, findsOneWidget);
      final IconButton underBondBtn = tester.widget(underBondBtnFinder);
      expect(underBondBtn.onPressed, isNull);
      expect(underBondBtn.tooltip, equals('تم الإفراج الجمركي النهائي بالفعل'));

      // View button exists and opens read-only details dialog
      final viewBtnFinder = find.byKey(const Key('viewClearanceBtn_CLR-2026-0020'));
      expect(viewBtnFinder, findsOneWidget);
      final IconButton viewBtn = tester.widget(viewBtnFinder);
      expect(viewBtn.onPressed, isNotNull);

      await tester.tap(viewBtnFinder);
      await tester.pumpAndSettle();
      expect(find.textContaining('CLR-2026-0020'), findsWidgets);
      expect(find.textContaining('46-ALX-2026-992'), findsWidgets);
    });

    testWidgets('FE07-T04: Card for unassessed record disables Pay button with assessment tooltip', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final unassessedRecord = CustomsClearanceModel(
        customsClearanceId: 21,
        clearanceCode: 'CLR-2026-0021',
        importFileId: 101,
        nafezaClaimNumber: null,
        actualDutyTotal: 0.0,
        totalDutyPayable: 0.0,
        paymentStatus: 'Pending Payment',
        status: 'Under Customs Clearance',
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
        owner: 'Admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([unassessedRecord])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final payBtnFinder = find.byKey(const Key('payDutyBtn_CLR-2026-0021'));
      expect(payBtnFinder, findsOneWidget);
      final IconButton payBtn = tester.widget(payBtnFinder);
      expect(payBtn.onPressed, isNull);
      expect(payBtn.tooltip, equals('يجب تقييم الرسوم الجمركية أولاً'));
    });

    testWidgets('FE07-T04: Card for quarantine-locked record disables Final Release button', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final quarantineRecord = CustomsClearanceModel(
        customsClearanceId: 22,
        clearanceCode: 'CLR-2026-0022',
        importFileId: 101,
        nafezaClaimNumber: 'CLM-2026-0022',
        actualDutyTotal: 50000.0,
        totalDutyPayable: 50000.0,
        paymentStatus: 'Paid & Verified',
        status: 'Under Bond Released',
        isUnderBondRelease: true,
        quarantineLock: true,
        createdAt: '2026-08-23T00:00:00Z',
        updatedAt: '2026-08-23T00:00:00Z',
        owner: 'Admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier([quarantineRecord])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Scaffold(
                body: CustomsClearanceScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final releaseBtnFinder = find.byKey(const Key('finalReleaseBtn_CLR-2026-0022'));
      expect(releaseBtnFinder, findsOneWidget);
      final IconButton releaseBtn = tester.widget(releaseBtnFinder);
      expect(releaseBtn.onPressed, isNull);
      expect(releaseBtn.tooltip, equals('الشحنة تحت التحفظ الرقابي — يلزم رفع التحفظ أولاً'));

      // Under-bond button should be enabled in lab mode
      final underBondBtnFinder = find.byKey(const Key('underBondBtn_CLR-2026-0022'));
      expect(underBondBtnFinder, findsOneWidget);
      final IconButton underBondBtn = tester.widget(underBondBtnFinder);
      expect(underBondBtn.onPressed, isNotNull);
    });
  });
}
