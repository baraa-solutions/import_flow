import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/vertical_stage_scaffold.dart';
import 'package:frontend/core/widgets/dedicated_stage_scaffold.dart';
import 'package:frontend/core/widgets/page_header.dart';

import 'package:dio/dio.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

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

void main() {
  Widget buildTestApp({
    required Widget child,
    Size size = const Size(1200, 800),
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
      ],
      child: AppLocalizationsProvider(
        locale: locale,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // Since 83f71fc long titles are intentionally truncated with an ellipsis
  // (VerticalStageScaffold: up to 2 lines; DedicatedStageScaffold: single line).
  // These tests assert that behaviour and that the header never overflows.
  group('Type A Header Title Visibility Tests (Problem 1 Fix)', () {
    testWidgets('Freight Shipping Scenarios & Carrier Evaluation renders in full with multiple action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 768));

      final testWidget = VerticalStageScaffold(
        stageCode: 'STEP_01',
        titleEn: 'Freight Shipping Scenarios & Carrier Evaluation',
        titleAr: 'دراسات وسيناريوهات الشحن والمفاضلة',
        headerIcon: Icons.alt_route_outlined,
        tabs: const [
          VerticalNavTabItem(
            icon: Icons.calculate_outlined,
            titleEn: 'Scenarios Evaluator',
            titleAr: 'دراسات وسيناريوهات الشحن',
          ),
        ],
        selectedIndex: 0,
        onTabSelected: (_) {},
        showStageLifecycleControls: true,
        headerActions: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: const Text('Search & Clone Study'),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Extract Freight Quotes'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
        body: const Center(child: Text('Content Area')),
      );

      await tester.pumpWidget(buildTestApp(child: testWidget, size: const Size(1100, 768)));
      await tester.pumpAndSettle();

      // Find the title Text widget
      final titleFinder = find.text('Freight Shipping Scenarios & Carrier Evaluation');
      expect(titleFinder, findsOneWidget, reason: 'Title must be present in the tree');

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.overflow, TextOverflow.ellipsis, reason: 'Long titles are truncated with an ellipsis (83f71fc)');
      expect(titleText.maxLines, 2, reason: 'Type A title may wrap to at most 2 lines');
      expect(titleText.softWrap, isTrue, reason: 'Title must be allowed to soft-wrap');

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
      // Verify Problem 2 Fix: Raw internal code is hidden, human-readable name is displayed
      expect(find.text('PHASE-1: STEP_03'), findsNothing, reason: 'Raw internal phase/step code must not be shown to user');
      expect(find.text('Freight Studies'), findsOneWidget, reason: 'Badge must show human-readable stage name');
    });

    testWidgets('Longest Type A Screen Title (52 chars) renders completely on standard desktop width', (tester) async {
      const longestTitleEn = 'Customs Broker Consultation & Inspection Workspace';
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      final testWidget = VerticalStageScaffold(
        stageCode: 'PHASE-1: STEP_02',
        titleEn: longestTitleEn,
        titleAr: 'استشارات التخليص الجمركي والفحص المسبق',
        headerIcon: Icons.gavel_outlined,
        tabs: const [
          VerticalNavTabItem(
            icon: Icons.table_chart,
            titleEn: 'Tab 1',
            titleAr: 'تبويب 1',
          ),
        ],
        selectedIndex: 0,
        onTabSelected: (_) {},
        showStageLifecycleControls: true,
        headerActions: [
          OutlinedButton(onPressed: () {}, child: const Text('Action 1')),
          OutlinedButton(onPressed: () {}, child: const Text('Action 2')),
        ],
        body: const Center(child: Text('Content')),
      );

      await tester.pumpWidget(buildTestApp(child: testWidget, size: const Size(1024, 768)));
      await tester.pumpAndSettle();

      final titleFinder = find.text(longestTitleEn);
      expect(titleFinder, findsOneWidget);

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(titleText.maxLines, 2);
      expect(tester.takeException(), isNull);

      // Verify Problem 2 Fix
      expect(find.text('PHASE-1: STEP_02'), findsNothing);
      expect(find.text('Customs Studies'), findsOneWidget);
    });

    testWidgets('Longest Arabic Screen Title renders completely in RTL mode', (tester) async {
      const longestTitleAr = 'مراجعة الرسوم الجمركية والضرائب وتكاليف البنود';
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      final testWidget = VerticalStageScaffold(
        stageCode: 'PHASE-1: STEP_02-TAX',
        titleEn: 'Customs Duty Review & Tax Calculation Workspace',
        titleAr: longestTitleAr,
        headerIcon: Icons.calculate_outlined,
        tabs: const [
          VerticalNavTabItem(
            icon: Icons.table_chart,
            titleEn: 'Tab 1',
            titleAr: 'تبويب 1',
          ),
        ],
        selectedIndex: 0,
        onTabSelected: (_) {},
        showStageLifecycleControls: true,
        headerActions: [
          OutlinedButton(onPressed: () {}, child: const Text('إجراء 1')),
        ],
        body: const Center(child: Text('Content')),
      );

      await tester.pumpWidget(buildTestApp(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: testWidget,
        ),
        size: const Size(1024, 768),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final titleFinder = find.text(longestTitleAr);
      expect(titleFinder, findsOneWidget);

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(titleText.maxLines, 2);
      expect(tester.takeException(), isNull);

      // Verify Problem 2 Fix in Arabic RTL
      expect(find.text('PHASE-1: STEP_02-TAX'), findsNothing);
      expect(find.text('الرسوم الجمركية والضرائب'), findsOneWidget);
    });

    testWidgets('DedicatedStageScaffold renders long title with ellipsis and no overflow', (tester) async {
      const dedicatedTitle = 'Smart Invoice vs B/L Match & Variance Reconciliation';
      await tester.binding.setSurfaceSize(const Size(1150, 768));

      final testWidget = DedicatedStageScaffold(
        stageCode: 'STEP_08_MATCH',
        titleEn: dedicatedTitle,
        titleAr: 'المطابقة الذكية للفاتورة والبوليصة',
        headerIcon: Icons.rule_folder_outlined,
        showStageLifecycleControls: true,
        headerActions: [
          OutlinedButton(onPressed: () {}, child: const Text('Re-run Matching')),
        ],
        body: const Center(child: Text('Dedicated Content')),
      );

      await tester.pumpWidget(buildTestApp(child: testWidget, size: const Size(1150, 768)));
      await tester.pumpAndSettle();

      final titleFinder = find.text(dedicatedTitle);
      expect(titleFinder, findsOneWidget);

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);

      // Verify Problem 2 Fix in DedicatedStageScaffold
      expect(find.text('STEP_08_MATCH'), findsNothing);
      expect(find.text('Invoice vs B/L Match'), findsOneWidget);
    });

    testWidgets('Phase-only stageCode (PHASE-5) resolves to clean business title without raw code', (tester) async {
      final testWidget = VerticalStageScaffold(
        stageCode: 'PHASE-5',
        titleEn: 'Port Operations & Customs Clearance Hub',
        titleAr: 'عمليات الميناء والتخليص الجمركي',
        headerIcon: Icons.local_shipping_outlined,
        tabs: const [
          VerticalNavTabItem(icon: Icons.table_chart, titleEn: 'Clearance', titleAr: 'التخليص'),
        ],
        selectedIndex: 0,
        onTabSelected: (_) {},
        body: const Center(child: Text('Phase 5 Body')),
      );

      await tester.pumpWidget(buildTestApp(child: testWidget, size: const Size(1200, 768)));
      await tester.pumpAndSettle();

      expect(find.text('PHASE-5'), findsNothing);
      expect(find.text('Customs Clearance'), findsOneWidget);
    });

    testWidgets('PageHeader renders full title without truncation', (tester) async {
      const pageTitle = 'Comprehensive Freight Shipping Scenarios & Multi-Carrier Comparative Evaluation';
      await tester.binding.setSurfaceSize(const Size(1100, 768));

      const testWidget = Scaffold(
        appBar: PageHeader(
          title: pageTitle,
          icon: Icons.local_shipping_outlined,
          actions: [
            Icon(Icons.refresh),
          ],
        ),
        body: Center(child: Text('Body')),
      );

      await tester.pumpWidget(buildTestApp(child: testWidget, size: const Size(1100, 768)));
      await tester.pumpAndSettle();

      final titleFinder = find.text(pageTitle);
      expect(titleFinder, findsOneWidget);

      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.overflow, isNot(TextOverflow.ellipsis));
      expect(titleText.maxLines, 2);
      expect(tester.takeException(), isNull);
    });
  });
}
