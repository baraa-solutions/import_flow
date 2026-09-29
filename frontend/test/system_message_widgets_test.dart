import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/widgets/critical_alert_banner.dart';
import 'package:frontend/features/notifications/models/notification_model.dart';
import 'package:frontend/features/notifications/providers/notifications_provider.dart';
import 'package:frontend/features/operational_dashboard/widgets/dashboard_card_drilldown_dialog.dart';
import 'package:frontend/features/smart_tasks/models/smart_task_model.dart';

import 'helpers/localized_app.dart';

class _FakeNotifications extends StateNotifier<AsyncValue<List<NotificationModel>>>
    implements NotificationsNotifier {
  _FakeNotifications(List<NotificationModel> list) : super(AsyncValue.data(list));

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<void> markAsRead(int notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> triggerExpiryCheck() async {}
}

final _coded = NotificationModel.fromJson({
  'notification_id': 1,
  'title': 'Demurrage warning: IMP-2026-0002',
  'message': 'IMP-2026-0002 has 2 days left before the free time ends and demurrage starts. Speed up the clearance.',
  'severity': 'CRITICAL',
  'is_read': false,
  'created_at': '2026-09-29T10:00:00',
  'msg_code': 'NOTIF_DEMURRAGE_WARNING',
  'msg_params': {'import_file_code': 'IMP-2026-0002', 'days_left': 2},
});

final _legacy = NotificationModel.fromJson({
  'notification_id': 2,
  'title': 'تنبيه قديم محفوظ',
  'message': 'نص قديم',
  'severity': 'CRITICAL',
  'is_read': false,
  'created_at': '2026-09-01T10:00:00',
});

final _codedTask = SmartTaskModel.fromJson({
  'task_id': 10,
  'task_code': 'TSK-10',
  'title': '[IMP-2026-0001] - Booking Confirmation',
  'description': 'stored',
  'status': 'Pending',
  'import_file_code': 'IMP-2026-0001',
  'msg_code': 'LC_TASK_NEXT_STEP',
  'msg_params': {
    'import_file_code': 'IMP-2026-0001',
    'step_code': 'STEP_06',
    'completed_step_code': 'STEP_05',
    'phase_id': 3,
  },
});

final _legacyTask = SmartTaskModel.fromJson({
  'task_id': 11,
  'task_code': 'TSK-11',
  'title': 'Call the supplier about samples',
  'status': 'Pending',
});

Future<void> _pumpBanner(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [notificationsProvider.overrideWith((ref) => _FakeNotifications([_coded, _legacy]))],
    child: localizedApp(locale: locale, home: const Scaffold(body: CriticalAlertBanner())),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpTaskCards(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(localizedApp(
    locale: locale,
    home: Scaffold(
      body: Builder(builder: (context) {
        final l = context.l10n;
        final records = DashboardDrillDownHelper.getRecords(
          type: DashboardCardType.pendingTasks,
          shipments: const [],
          tasks: [_codedTask, _legacyTask],
          isArabic: l.isArabic,
          l: l,
        );
        return DashboardCardDrillDownDialog(
          title: 'Tasks',
          icon: Icons.task,
          themeColor: Colors.blue,
          records: records,
          isArabic: l.isArabic,
        );
      }),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('notification banner renders msg_code in the user language', () {
    testWidgets('Arabic', (tester) async {
      await _pumpBanner(tester, AppLocales.arabic);
      expect(find.textContaining('تحذير أرضيات: '), findsOneWidget);
      expect(find.textContaining('Demurrage warning'), findsNothing);
      expect(find.textContaining('تنبيه قديم محفوظ'), findsOneWidget); // legacy row: stored text
    });

    testWidgets('English', (tester) async {
      await _pumpBanner(tester, AppLocales.english);
      expect(find.textContaining('Demurrage warning: IMP-2026-0002'), findsOneWidget);
      expect(find.textContaining('تحذير أرضيات'), findsNothing);
      expect(find.textContaining('تنبيه قديم محفوظ'), findsOneWidget);
    });
  });

  group('task cards render msg_code; legacy tasks use cleanTaskTitle', () {
    testWidgets('Arabic', (tester) async {
      await _pumpTaskCards(tester, AppLocales.arabic);
      expect(find.textContaining('تأكيد الحجز الملاحي'), findsWidgets);
      expect(find.textContaining('Booking Confirmation'), findsNothing);
      expect(
        find.textContaining(DisplayNameResolver.cleanTaskTitle(_legacyTask.title, isArabic: true)),
        findsWidgets,
      );
    });

    testWidgets('English', (tester) async {
      await _pumpTaskCards(tester, AppLocales.english);
      expect(find.textContaining('Booking Confirmation'), findsWidgets);
      expect(find.textContaining('تأكيد الحجز الملاحي'), findsNothing);
      expect(
        find.textContaining(DisplayNameResolver.cleanTaskTitle(_legacyTask.title, isArabic: false)),
        findsWidgets,
      );
    });
  });
}
