import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/core/widgets/dedicated_stage_scaffold.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class FakeDensityNotifier extends DisplayDensityNotifier {
  FakeDensityNotifier(DisplayDensityMode initial) : super() {
    state = initial;
  }
}

class _EmptyImportFilesNotifier extends ImportFilesNotifier {
  _EmptyImportFilesNotifier() : super(Dio()) {
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

/// The header shows a human-readable stage label, not the raw stage code.
final String _badge = DisplayNameResolver.resolveStageBadge('STEP_08_BL', isArabic: false);

/// Header icon / title are rendered at 90% of the density token (see DedicatedStageScaffold).
double _icon(DisplayDensityMode m) => m.headerIconSize * 0.9;
double _title(DisplayDensityMode m) => DisplayDensityMode.clampFontSize(m.headerTitleFontSize * 0.9);

void main() {
  Widget buildTestWidget({
    required DisplayDensityMode densityMode,
    double width = 1366,
    double height = 768,
  }) {
    return ProviderScope(
      overrides: [
        displayDensityProvider.overrideWith((ref) => FakeDensityNotifier(densityMode)),
      ],
      child: MaterialApp(
        home: SizedBox(
          width: width,
          height: height,
          child: DedicatedStageScaffold(
            stageCode: 'STEP_08_BL',
            titleAr: 'مراجعة مسودة بوليصة الشحن',
            titleEn: 'Bill of Lading Review',
            headerIcon: Icons.directions_boat,
            showStageLifecycleControls: false,
            headerActions: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.description, size: 16),
                label: const Text('Formal Letter'),
              ),
            ],
            body: const Center(child: Text('Main Stage Body Content')),
          ),
        ),
      ),
    );
  }

  group('DedicatedStageScaffold Density & Layout Tests', () {
    testWidgets('Renders all header elements and content correctly in Comfortable mode', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(densityMode: DisplayDensityMode.comfortable));
      await tester.pumpAndSettle();

      expect(find.text('Bill of Lading Review'), findsOneWidget);
      expect(find.text(_badge), findsOneWidget);
      expect(find.byIcon(Icons.directions_boat), findsOneWidget);
      expect(find.text('Formal Letter'), findsOneWidget);
      expect(find.text('Main Stage Body Content'), findsOneWidget);

      // Verify Icon size in Comfortable mode
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.directions_boat));
      expect(iconWidget.size, equals(_icon(DisplayDensityMode.comfortable)));

      // Verify Title font size in Comfortable mode
      final titleText = tester.widget<Text>(find.text('Bill of Lading Review'));
      expect(titleText.style?.fontSize, equals(_title(DisplayDensityMode.comfortable)));

      // Verify Stage badge font size adheres to 11px floor rule
      final badgeText = tester.widget<Text>(find.text(_badge));
      expect(badgeText.style?.fontSize, greaterThanOrEqualTo(11.0));
    });

    testWidgets('Scales header and icon down in Compact mode while keeping >= 11px', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(densityMode: DisplayDensityMode.compact));
      await tester.pumpAndSettle();

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.directions_boat));
      expect(iconWidget.size, equals(_icon(DisplayDensityMode.compact)));

      final titleText = tester.widget<Text>(find.text('Bill of Lading Review'));
      expect(titleText.style?.fontSize, equals(_title(DisplayDensityMode.compact)));

      final badgeText = tester.widget<Text>(find.text(_badge));
      expect(badgeText.style?.fontSize, greaterThanOrEqualTo(11.0));
    });

    testWidgets('Scales header and icon down in Ultra-Compact mode with strict 11px floor rule', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(densityMode: DisplayDensityMode.ultraCompact));
      await tester.pumpAndSettle();

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.directions_boat));
      expect(iconWidget.size, equals(_icon(DisplayDensityMode.ultraCompact)));

      final titleText = tester.widget<Text>(find.text('Bill of Lading Review'));
      expect(titleText.style?.fontSize, equals(_title(DisplayDensityMode.ultraCompact)));

      final badgeText = tester.widget<Text>(find.text(_badge));
      expect(badgeText.style?.fontSize, greaterThanOrEqualTo(11.0));
    });

    testWidgets('Body workspace fills the remaining viewport down to the bottom edge', (tester) async {
      // Since 83f71fc the scaffold uses a maximized body (the former +72px bottom
      // anti-occlusion buffer was removed), so the body reaches the bottom of the view.
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(densityMode: DisplayDensityMode.comfortable));
      await tester.pumpAndSettle();

      final bodyFinder = find.byWidgetPredicate(
        (w) => w is Center && w.child is Text && (w.child as Text).data == 'Main Stage Body Content',
      );
      expect(bodyFinder, findsOneWidget);
      expect(find.ancestor(of: bodyFinder, matching: find.byType(Expanded)), findsWidgets);
      expect(tester.getRect(bodyFinder).bottom, moreOrLessEquals(768.0));
    });

    testWidgets('Renders without overflow on narrow screens (< 1000px)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        densityMode: DisplayDensityMode.compact,
        width: 800,
        height: 600,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bill of Lading Review'), findsOneWidget);
      expect(find.text('Formal Letter'), findsOneWidget);
    });
  });

  group('DedicatedStageScaffold adaptive header (lifecycle controls never clipped)', () {
    Widget buildWithControls(double width) => ProviderScope(
          overrides: [
            displayDensityProvider.overrideWith((ref) => FakeDensityNotifier(DisplayDensityMode.comfortable)),
            importFilesProvider.overrideWith((ref) => _EmptyImportFilesNotifier()),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: MaterialApp(
              home: DedicatedStageScaffold(
                stageCode: 'STEP_08_MATCH',
                titleAr: 'المطابقة الذكية للفاتورة والبوليصة',
                titleEn: 'Smart Invoice vs B/L Match & Variance Reconciliation',
                headerIcon: Icons.rule_folder_outlined,
                showStageLifecycleControls: true,
                headerActions: [
                  OutlinedButton(onPressed: () {}, child: const Text('Re-run Matching')),
                ],
                body: const Center(child: Text('Body')),
              ),
            ),
          ),
        );

    RenderAdaptiveStageHeader headerRender(WidgetTester tester) =>
        tester.renderObject<RenderAdaptiveStageHeader>(find.byType(AdaptiveStageHeaderLayout));

    testWidgets('at 800px the controls move to a second row and Hold & Stop is fully visible and tappable', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWithControls(800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(headerRender(tester).isSingleRow, isFalse);

      final holdFinder = find.text(const AppLocalizationsEn().stopShipmentAtThisStageBtn);
      final skipFinder = find.text(const AppLocalizationsEn().skipStepBtn);
      expect(holdFinder, findsOneWidget);
      expect(skipFinder, findsOneWidget);

      final headerRect = tester.getRect(find.byType(AdaptiveStageHeaderLayout));
      for (final f in [holdFinder, skipFinder]) {
        final r = tester.getRect(f);
        expect(r.left >= headerRect.left && r.right <= headerRect.right, isTrue,
            reason: '$f must be fully inside the header ($r vs $headerRect)');
        expect(r.left >= 0 && r.right <= 800, isTrue, reason: '$f must be inside the viewport ($r)');
      }

      await tester.tap(holdFinder, warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Hold & Stop opens the file-selection dialog');
    });

    testWidgets('on a wide desktop the header stays a single row', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWithControls(1920));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(headerRender(tester).isSingleRow, isTrue);
    });
  });
}
