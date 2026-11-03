import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/app_status_badge.dart';
import 'package:frontend/features/warehouse_receiving/widgets/claim_status_badge.dart';
import 'package:frontend/features/warehouse_receiving/widgets/shortage_claim_dialog.dart';

Widget _wrap(Widget child, [Locale locale = const Locale('ar')]) {
  return AppLocalizationsProvider(
    locale: locale,
    child: MaterialApp(
      locale: locale,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ClaimStatusBadge Tests', () {
    testWidgets('renders properly with default localized text in Arabic', (tester) async {
      await tester.pumpWidget(_wrap(const ClaimStatusBadge(status: 'SUBMITTED')));
      await tester.pumpAndSettle();

      expect(find.text('مقدمة للمورد'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsOneWidget);
    });

    testWidgets('renders approved and rejected factory constructors', (tester) async {
      await tester.pumpWidget(_wrap(
        const Column(
          children: [
            ClaimStatusBadge.approved(),
            ClaimStatusBadge.rejected(),
            ClaimStatusBadge.waived(),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('معتمدة للتعويض'), findsOneWidget);
      expect(find.text('مطالبة مرفوضة'), findsOneWidget);
      expect(find.text('تم التجاوز والتنازل'), findsOneWidget);
    });

    testWidgets('renders English localized text in en locale', (tester) async {
      await tester.pumpWidget(_wrap(const ClaimStatusBadge.underReview(), const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Under Technical Review'), findsOneWidget);
    });
  });

  group('ShortageClaimDialog Tests', () {
    testWidgets('renders shortage summary details properly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(
        const ShortageClaimDialog(
          importFileId: 101,
          grnCode: 'GRN-2026-0001',
          totalShortageQty: 5,
          estimatedAmount: 2500.0,
          currency: 'USD',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('GRN-2026-0001'), findsWidgets);
      expect(find.textContaining('101'), findsWidgets);
      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('2500.00 USD'), findsWidgets);
    });

    testWidgets('toggles decision tab between claim and waive', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(
        const ShortageClaimDialog(
          importFileId: 101,
          grnCode: 'GRN-2026-0001',
          totalShortageQty: 5,
          estimatedAmount: 2500.0,
          currency: 'USD',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('فتح مطالبة للمورد'), findsOneWidget);
      expect(find.text('تجاهل وتنازل مع سبب'), findsOneWidget);

      // Tap on waive tab
      await tester.tap(find.text('تجاهل وتنازل مع سبب'));
      await tester.pumpAndSettle();

      // Should show waiver reason field and notice
      expect(find.text('سبب التجاوز والتنازل *'), findsOneWidget);
      expect(find.text('تأكيد التنازل مع السبب'), findsOneWidget);
    });
  });
}
