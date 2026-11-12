import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/models/payment_pathway_status_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_files/providers/payment_pathway_provider.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/lifecycle_board/providers/lifecycle_board_provider.dart';
import 'package:frontend/features/lifecycle_board/providers/live_polling_provider.dart';
import 'package:frontend/features/lifecycle_board/screens/lifecycle_board_screen.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/lifecycle_matrix_layout.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/lifecycle_phase_matrix.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/matrix_tier_column.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/split_phase_tier_card.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/stacked_dual_phase_card.dart';
import 'package:frontend/features/lifecycle_board/widgets/matrix/standard_phase_card.dart';
import 'package:frontend/features/notifications/models/notification_model.dart';
import 'package:frontend/features/notifications/providers/notifications_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeNotificationsNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>>
    implements NotificationsNotifier {
  _FakeNotificationsNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<void> markAsRead(int notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> triggerExpiryCheck() async {}
}

class _FakeImportFilesNotifier extends ImportFilesNotifier {
  _FakeImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

// ── Fixtures (mirror modules/lifecycle_board/lifecycle_kanban_service.PHASES_DEFINITION) ──

const _phaseSteps = <int, List<String>>{
  1: ['STEP_01', 'STEP_02', 'STEP_03'],
  2: ['STEP_04', 'STEP_05'],
  3: ['STEP_06', 'STEP_07', 'STEP_08_PO', 'STEP_08_BL', 'STEP_08_MATCH', 'STEP_08_COO', 'STEP_08_COC', 'STEP_09'],
  4: ['STEP_10', 'STEP_11', 'STEP_12'],
  5: ['STEP_13', 'STEP_14', 'STEP_15', 'STEP_16', 'STEP_17', 'STEP_18'],
  6: ['STEP_19', 'STEP_20', 'STEP_21'],
};
const _phaseColors = ['#D97706', '#3498DB', '#16A085', '#C0392B', '#8E44AD', '#27AE60'];

List<PhaseSummaryModel> _phases() => [
      for (final entry in _phaseSteps.entries)
        PhaseSummaryModel(
          phaseId: entry.key,
          titleEn: 'Phase ${entry.key}',
          titleAr: 'المرحلة ${entry.key}',
          colorHex: _phaseColors[entry.key - 1],
          stepCodes: entry.value,
          totalActiveShipments: entry.key == 4 ? 1 : 0,
          stepCounts: {for (final s in entry.value) s: s == 'STEP_11' ? 1 : 0},
        ),
    ];

ShipmentStageCardModel _shipment({List<String> skipped = const []}) => ShipmentStageCardModel(
      importFileCode: 'IMP-2026-0007',
      companyName: 'Sorour Logistics',
      supplierName: 'Global Steel Ltd',
      stepCode: 'STEP_11',
      stepNameEn: 'Originals Collection',
      stepNameAr: 'تحصيل واستلام أصول المستندات',
      status: 'In-Progress',
      skippedStepCodes: skipped,
    );

ImportFileModel _importFile() => ImportFileModel(
      importFileId: 7,
      importFileCode: 'IMP-2026-0007',
      companyId: 1,
      companyName: 'Sorour Logistics',
      supplierId: 2,
      supplierName: 'Global Steel Ltd',
      shipmentMode: 'Sea FCL',
      incotermCode: 'CIF',
      priority: 'Normal',
      shipmentCategory: 'Commercial',
      status: 'Active',
      owner: 'Admin',
      progressPercent: 40.0,
      estimatedCost: 1000.0,
      estimatedCostCurrency: 'USD',
      currentModule: 'Lifecycle',
      currentStage: 'Draft',
      nextAction: 'Collect originals',
      invoicesData: const [],
      packingListsData: const [],
      projectIds: const [],
      skippedStages: const ['STEP_02'],
      createdAt: '2026-11-01T00:00:00',
      updatedAt: '2026-11-01T00:00:00',
    );

const _blockedPathway = PaymentPathwayStatus(
  importFileId: 7,
  importFileCode: 'IMP-2026-0007',
  paymentTerm: 'CAD',
  isPathwaySet: true,
  currentPhaseId: 4,
  currentStepCode: 'STEP_11',
  milestones: [
    PaymentMilestoneStatus(
      code: 'CAD_DOCS_RELEASED',
      labelEn: 'Bank released CAD documents',
      labelAr: 'إفراج البنك عن مستندات التحصيل',
      isCompleted: false,
    ),
    PaymentMilestoneStatus(
      code: 'CAD_COLLECTION_NOTICE',
      labelEn: 'Collection notice received',
      labelAr: 'استلام إشعار التحصيل',
      isCompleted: false,
    ),
  ],
  gates: [
    PaymentGateStatus(
      gate: 'STEP_12',
      labelEn: 'Bank Form 4',
      labelAr: 'نموذج 4 البنكي',
      requiredMilestones: ['CAD_DOCS_RELEASED'],
      missingMilestones: ['CAD_DOCS_RELEASED'],
      isSatisfied: false,
      isPassed: false,
    ),
    PaymentGateStatus(
      gate: 'PHASE_5',
      labelEn: 'Port Operations',
      labelAr: 'عمليات الميناء',
      requiredMilestones: ['CAD_COLLECTION_NOTICE'],
      missingMilestones: ['CAD_COLLECTION_NOTICE'],
      isSatisfied: false,
      isPassed: false,
    ),
    PaymentGateStatus(
      gate: 'STEP_08_COC',
      labelEn: 'Inspection',
      labelAr: 'الفحص',
      isSatisfied: false,
      isPassed: false,
      isWaived: true,
    ),
  ],
  isBlocked: true,
);

// ── Harness ───────────────────────────────────────────────────────────────────

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _boardApp({
  required Locale locale,
  ThemeMode themeMode = ThemeMode.light,
  double sidebarWidth = 0,
  double textScale = 1.0,
  List<ShipmentStageCardModel>? shipments,
}) {
  final rows = shipments ?? [_shipment()];
  final board = LifecycleBoardSummaryModel(phases: _phases(), totalActiveFiles: rows.length, allShipments: rows);
  final radar = LiveLogisticsSummaryModel.fromJson(const {'items': []});
  final isAr = locale.languageCode == 'ar';
  return ProviderScope(
    overrides: [
      lifecycleBoardSummaryProvider.overrideWith((ref) => Future.value(board)),
      liveLogisticsTrackingProvider.overrideWith((ref) => Future.value(radar)),
      livePollingProvider.overrideWith((ref) => Stream.value(radar)),
      refreshCountdownProvider.overrideWith((ref) => Stream.value(45)),
      notificationsProvider.overrideWith((ref) => _FakeNotificationsNotifier()),
      importFilesProvider.overrideWith((ref) => _FakeImportFilesNotifier([_importFile()])),
      paymentPathwayStatusProvider.overrideWith((ref, id) async => _blockedPathway),
    ],
    child: AppLocalizationsProvider(
      locale: locale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Row(
            children: [
              if (sidebarWidth > 0) SizedBox(width: sidebarWidth),
              const Expanded(child: LifecycleBoardScreen()),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpBoard(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void _expectFittedStrip(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
  expect(find.byKey(const ValueKey('matrix-strip-fitted')), findsOneWidget);
  expect(find.byKey(const ValueKey('matrix-strip-scrolling')), findsNothing);
  final strip = tester.getRect(find.byType(LifecyclePhaseMatrix));
  final screen = tester.getRect(find.byType(LifecycleBoardScreen));
  expect(strip.left, greaterThanOrEqualTo(screen.left));
  expect(strip.right, lessThanOrEqualTo(screen.right));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Matrix layout planner', () {
    test('splits long phases into ≤3-step tiers, short remainder first', () {
      List<int> sizes(int n) => splitStepsIntoTiers(List.generate(n, (i) => 'S$i')).map((t) => t.length).toList();
      expect(sizes(0), [0]);
      expect(sizes(1), [1]);
      expect(sizes(2), [2]);
      expect(sizes(3), [3]);
      expect(sizes(4), [1, 3]);
      expect(sizes(6), [3, 3]);
      expect(sizes(8), [2, 3, 3]);
      for (var n = 0; n <= 12; n++) {
        expect(sizes(n).every((s) => s <= kMatrixMaxStepsPerTier), isTrue, reason: '$n steps');
      }
    });

    test('maps the 6 board phases onto the 9-column symmetrical matrix', () {
      final blocks = planLifecycleMatrix(_phases());
      expect(blocks.map((b) => b.kind).toList(), [
        MatrixPhaseKind.standard,
        MatrixPhaseKind.stackedDual,
        MatrixPhaseKind.split,
        MatrixPhaseKind.standard,
        MatrixPhaseKind.split,
        MatrixPhaseKind.standard,
      ]);
      expect(blocks[2].tiers, [
        ['STEP_06', 'STEP_07'],
        ['STEP_08_PO', 'STEP_08_BL', 'STEP_08_MATCH'],
        ['STEP_08_COO', 'STEP_08_COC', 'STEP_09'],
      ]);
      expect(blocks[4].tiers.map((t) => t.length).toList(), [3, 3]);
      expect(matrixTierCount(blocks), 9);
      // Fits a 1366px window even with the 255px expanded sidebar and 24px strip padding.
      expect(matrixMinimumWidth(blocks), lessThan(1366 - 255 - 24));
      expect(kMatrixCardHeight, lessThanOrEqualTo(145));
    });

    test('gate state: blocked phase/step reasons, waived stages never locked', () {
      const state = LifecycleMatrixGateState(
        importFileCode: 'IMP-2026-0007',
        pathway: _blockedPathway,
        skippedStepCodes: {'STEP_02'},
      );
      final en = AppLocalizationsProvider.resolve(const Locale('en'));
      final ar = AppLocalizationsProvider.resolve(const Locale('ar'));
      expect(state.isPhaseBlocked(5), isTrue);
      expect(state.isPhaseBlocked(4), isFalse);
      expect(state.isStepBlocked('STEP_12'), isTrue);
      expect(state.isStepWaived('STEP_02'), isTrue);
      expect(state.isStepWaived('STEP_08_COC'), isTrue);
      expect(state.isStepBlocked('STEP_08_COC'), isFalse);
      expect(state.stepBlockReason('STEP_12', en), contains('Bank released CAD documents'));
      expect(state.stepBlockReason('STEP_12', ar), contains('إفراج البنك عن مستندات التحصيل'));
      expect(state.phaseBlockReason(5, en), contains('IMP-2026-0007'));
      expect(LifecycleMatrixGateState.empty.stepBlockReason('STEP_12', en), isNull);
    });
  });

  group('Lifecycle board matrix at 1366x768', () {
    testWidgets('fits without horizontal scroll, ≤3 rows per column, equal card heights', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('en')));
      _expectFittedStrip(tester);

      final tiers = tester.widgetList<MatrixTierColumn>(find.byType(MatrixTierColumn)).toList();
      expect(tiers.length, 9);
      expect(tiers.every((t) => t.stepCodes.length <= kMatrixMaxStepsPerTier), isTrue);

      for (var id = 1; id <= 6; id++) {
        expect(tester.getSize(find.byKey(ValueKey('matrix-phase-$id'))).height, kMatrixCardHeight);
      }
      expect(find.byType(StandardPhaseCard), findsNWidgets(3));
      expect(find.byType(StackedDualPhaseCard), findsOneWidget);
      expect(find.byType(SplitPhaseTierCard), findsNWidgets(2));
      expect(tester.getSize(find.byType(LifecyclePhaseMatrix)).height, lessThanOrEqualTo(145));
    });

    testWidgets('still fits beside the expanded 255px sidebar', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('ar'), sidebarWidth: 255));
      _expectFittedStrip(tester);
    });

    testWidgets('single-step stages stack vertically; split tiers sit side by side', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('en')));

      final step04 = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_04')));
      final step05 = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_05')));
      expect(step05.top, greaterThanOrEqualTo(step04.bottom - 0.5));
      expect(step05.left, closeTo(step04.left, 0.5));

      final step06 = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_06')));
      final step07 = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_07')));
      expect(step07.top, greaterThan(step06.top));

      final tierA = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_13')));
      final tierB = tester.getRect(find.byKey(const ValueKey('matrix-step-STEP_16')));
      expect(tierB.left, greaterThan(tierA.right - 0.5));
      expect(tierB.top, closeTo(tierA.top, 0.5));
    });

    testWidgets('RTL Arabic layout mirrors phase order', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('ar')));
      _expectFittedStrip(tester);
      final phase1 = tester.getRect(find.byKey(const ValueKey('matrix-phase-1')));
      final phase2 = tester.getRect(find.byKey(const ValueKey('matrix-phase-2')));
      expect(phase1.left, greaterThan(phase2.right));
    });

    testWidgets('dark mode renders on dark surfaces', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('en'), themeMode: ThemeMode.dark));
      _expectFittedStrip(tester);
      final card = tester.widget<Container>(find.byKey(const ValueKey('matrix-phase-1')));
      expect((card.decoration! as BoxDecoration).color, AppTheme.darkCardBackground);
    });

    testWidgets('focused file shows payment-gate locks and waived stages', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('en'), shipments: [_shipment(skipped: ['STEP_02'])]));

      expect(find.byKey(const ValueKey('matrix-phase-lock-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix-phase-lock-4')), findsNothing);
      expect(find.byKey(const ValueKey('matrix-step-lock-STEP_12')), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix-step-lock-STEP_08_COC')), findsNothing);

      final lockTooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.byKey(const ValueKey('matrix-step-lock-STEP_12')), matching: find.byType(Tooltip)).first,
      );
      expect(lockTooltip.message, contains('Bank released CAD documents'));

      final waived = tester.widget<Text>(
        find.descendant(of: find.byKey(const ValueKey('matrix-step-STEP_02')), matching: find.byType(Text)).first,
      );
      expect(waived.style?.decoration, TextDecoration.lineThrough);
      expect(find.byIcon(Icons.do_not_disturb_on_outlined), findsNWidgets(2)); // STEP_02 skipped + STEP_08_COC waived gate
    });

    testWidgets('no focus (several files) → no locks', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      final other = ShipmentStageCardModel(
        importFileCode: 'IMP-2026-0008',
        companyName: 'X',
        supplierName: 'Y',
        stepCode: 'STEP_01',
        stepNameEn: 'Freight Studies',
        stepNameAr: 'دراسات',
        status: 'In-Progress',
      );
      await _pumpBoard(tester, _boardApp(locale: const Locale('en'), shipments: [_shipment(), other]));
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('phase and step selection callbacks are preserved', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      int? selectedPhase;
      String? selectedStep;
      var showAll = 0;
      await tester.pumpWidget(AppLocalizationsProvider(
        locale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: LifecyclePhaseMatrix(
              phases: _phases(),
              totalActiveFiles: 1,
              selectedPhaseId: null,
              selectedStepCode: null,
              onSelectPhase: (id) => selectedPhase = id,
              onSelectStep: (id, code) {
                selectedPhase = id;
                selectedStep = code;
              },
              onShowAll: () => showAll++,
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('matrix-phase-header-5')));
      expect(selectedPhase, 5);
      await tester.tap(find.byKey(const ValueKey('matrix-step-STEP_08_BL')));
      expect((selectedPhase, selectedStep), (3, 'STEP_08_BL'));
      await tester.tap(find.byKey(const ValueKey('matrix-show-all')));
      expect(showAll, 1);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('text scale 1.25 (${locale.languageCode}): strip and page header never overflow', (tester) async {
        _setViewport(tester, const Size(1366, 768));
        await _pumpBoard(
          tester,
          _boardApp(locale: locale, textScale: 1.25, shipments: [_shipment(skipped: ['STEP_02'])]),
        );
        _expectFittedStrip(tester);
        expect(find.byKey(const ValueKey('matrix-show-all')), findsOneWidget);
        expect(find.byKey(const ValueKey('matrix-phase-lock-5')), findsOneWidget);
      });
    }

    testWidgets('text scale 1.1 with sidebar: page header stays within its fixed height', (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await _pumpBoard(tester, _boardApp(locale: const Locale('ar'), textScale: 1.1, sidebarWidth: 255));
      _expectFittedStrip(tester);
    });

    testWidgets('narrow window falls back to scrolling instead of overflowing', (tester) async {
      _setViewport(tester, const Size(800, 600));
      await _pumpBoard(tester, _boardApp(locale: const Locale('en')));
      expect(find.byKey(const ValueKey('matrix-strip-scrolling')), findsOneWidget);
    });
  });

  // Optional screenshots: MATRIX_SCREENSHOT_DIR=/path flutter test <this file>
  final screenshotDir = Platform.environment['MATRIX_SCREENSHOT_DIR'];
  group('Matrix screenshots', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('render ${mode.name} board at 1366x768', (tester) async {
        await tester.runAsync(_loadSystemFonts);
        _setViewport(tester, const Size(1366, 768));
        // Substitute Linux fonts have other metrics than Segoe UI: screenshots only, ignore layout noise.
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {};
        addTearDown(() => FlutterError.onError = originalOnError);
        final boundaryKey = GlobalKey();
        await _pumpBoard(
          tester,
          RepaintBoundary(
            key: boundaryKey,
            child: _boardApp(locale: const Locale('ar'), themeMode: mode, shipments: [_shipment(skipped: ['STEP_02'])]),
          ),
        );
        final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$screenshotDir/lifecycle_matrix_${mode.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }, skip: screenshotDir == null);
}

Future<void> _loadSystemFonts() async {
  // Latin under the theme family, Arabic under its fallback family ('Tahoma').
  final fonts = {
    'Segoe UI': '/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf',
    'Roboto': '/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf',
    'Tahoma': '/usr/share/fonts/google-noto-vf/NotoSansArabic[wght].ttf',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final loader = FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}
