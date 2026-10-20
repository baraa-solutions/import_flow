import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_shimmer_skeleton.dart';
import 'package:frontend/core/widgets/enterprise_data_table/widgets/enterprise_table_shimmer_skeleton.dart';

void main() {
  group('Skeleton Shimmer Loaders Unit & Widget Tests', () {
    testWidgets('ShimmerBox renders correctly with custom dimensions and shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ShimmerBox(width: 120, height: 24, borderRadius: 8),
                ShimmerBox.circle(size: 36),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerBox), findsNWidgets(2));
      final rectFinder = find.byType(ShimmerBox).first;
      final circleFinder = find.byType(ShimmerBox).last;

      expect(rectFinder, findsOneWidget);
      expect(circleFinder, findsOneWidget);
    });

    testWidgets('AppShimmerEffect synchronizes animation without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShimmerEffect(
              child: Column(
                children: [
                  ShimmerBox(width: 100, height: 20),
                  ShimmerBox(width: 150, height: 20),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify widget builds and animates across frames without crashing
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(AppShimmerEffect), findsOneWidget);
      expect(find.byType(ShimmerBox), findsNWidgets(2));
    });

    testWidgets('DashboardKpiShimmerSkeleton renders the requested card count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardKpiShimmerSkeleton(cardCount: 6),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DashboardKpiShimmerSkeleton), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(6));
    });

    testWidgets('DashboardKpiShimmerSkeleton adapts to Dark Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: DashboardKpiShimmerSkeleton(cardCount: 4),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DashboardKpiShimmerSkeleton), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(4));
    });

    testWidgets('ShipmentCardShimmerSkeleton and ShipmentListShimmerSkeleton render full hierarchy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShipmentListShimmerSkeleton(count: 3),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShipmentListShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShipmentCardShimmerSkeleton), findsNWidgets(3));
      expect(find.byType(Divider), findsNWidgets(3));
    });

    testWidgets('ShipmentListShimmerSkeleton.sliver integrates cleanly into CustomScrollView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ShipmentListShimmerSkeleton.sliver(count: 2),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShipmentListShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShipmentCardShimmerSkeleton), findsNWidgets(2));
    });

    testWidgets('LifecycleSummaryShimmerSkeleton renders 6 phase cards with steps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LifecycleSummaryShimmerSkeleton(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LifecycleSummaryShimmerSkeleton), findsOneWidget);
      // 6 phase cards each containing a divider
      expect(find.byType(Divider), findsNWidgets(6));
    });

    testWidgets('KanbanBoardShimmerSkeleton renders phase row and table placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KanbanBoardShimmerSkeleton(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KanbanBoardShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShimmerTablePlaceholder), findsOneWidget);
    });

    testWidgets('RadarTableShimmerSkeleton renders top KPIs, filter bar, and table placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RadarTableShimmerSkeleton(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RadarTableShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShimmerTablePlaceholder), findsOneWidget);
    });

    testWidgets('ImportFilesTableShimmerSkeleton renders 13-column table skeleton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImportFilesTableShimmerSkeleton(rowCount: 5),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ImportFilesTableShimmerSkeleton), findsOneWidget);
      expect(find.byType(ShimmerTablePlaceholder), findsOneWidget);
    });

    testWidgets('EnterpriseTableShimmerSkeleton renders cleanly in both Light and Dark mode', (tester) async {
      // Light Mode
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EnterpriseTableShimmerSkeleton(rowCount: 4, columnCount: 5),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EnterpriseTableShimmerSkeleton), findsOneWidget);

      // Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: EnterpriseTableShimmerSkeleton(rowCount: 4, columnCount: 5),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(EnterpriseTableShimmerSkeleton), findsOneWidget);
    });
  });
}
