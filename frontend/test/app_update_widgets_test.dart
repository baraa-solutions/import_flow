import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:frontend/features/app_update/widgets/update_banner.dart';
import 'package:frontend/features/app_update/widgets/update_dialog.dart';
import 'package:frontend/features/app_update/widgets/update_feedback.dart';
import 'package:frontend/features/app_update/widgets/update_rollback_dialog.dart';

import 'helpers/fake_app_update_service.dart';

const en = AppLocalizationsEn();

Widget _app({
  required FakeAppUpdateService fake,
  required Widget home,
  bool admin = true,
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [
      appUpdateServiceProvider.overrideWithValue(fake),
      canInstallUpdatesProvider.overrideWithValue(admin),
      updatePollIntervalProvider.overrideWithValue(const Duration(milliseconds: 5)),
      ...extra,
    ],
    child: AppLocalizationsProvider(
      locale: const Locale('en'),
      child: MaterialApp(home: Scaffold(body: home)),
    ),
  );
}

/// Button that opens a dialog through a real Navigator context.
class _Opener extends StatelessWidget {
  const _Opener(this.open);
  final void Function(BuildContext) open;

  @override
  Widget build(BuildContext context) =>
      Center(child: TextButton(onPressed: () => open(context), child: const Text('open')));
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

DioException _dioError(int code, Object detail) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: code, data: {'detail': detail}),
  );
}

void main() {
  group('UpdateBanner', () {
    testWidgets('hidden when the check is offline', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: offlineCheck), home: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsNothing);
      expect(find.textContaining('2.1.0'), findsNothing);
    });

    testWidgets('hidden when up to date', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(), home: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsNothing);
    });

    testWidgets('optional update shows and "remind me later" hides it', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: optionalCheck), home: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateAvailableBanner('2.1.0')), findsOneWidget);
      await tester.tap(find.byKey(UpdateBanner.remindLaterKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsNothing);
    });

    testWidgets('mandatory: no dismiss, dialog opens automatically and cannot be dismissed', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: mandatoryCheck), home: const UpdateBanner()));
      await tester.pumpAndSettle();

      expect(find.byKey(UpdateBanner.remindLaterKey), findsNothing);
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.byKey(UpdateDialog.remindLaterKey), findsNothing);
      expect(find.byKey(UpdateDialog.signOutKey), findsOneWidget);
      expect(find.text(en.updateMandatoryNotice), findsOneWidget);

      // Barrier tap and Escape must not close it.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
    });
  });

  group('UpdateDialog', () {
    testWidgets('shows version, size and release notes; download starts polling to ready', (tester) async {
      _bigView(tester);
      // Two idle reads (notifier creation + dialog mount), then the backend
      // verifies and becomes ready after the download request.
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [
        UpdateStatus.idle,
        UpdateStatus.idle,
        UpdateStatus(state: UpdateState.verifying),
        UpdateStatus(state: UpdateState.ready, version: '2.1.0'),
      ]);
      await tester.pumpWidget(_app(
        fake: fake,
        home: _Opener((c) => showUpdateDialog(c, optionalCheck)),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.updateDialogTitle('2.1.0')), findsOneWidget);
      expect(find.text(en.updateSize('202.8')), findsOneWidget);
      expect(find.text('• Improvements'), findsOneWidget);

      await tester.tap(find.byKey(UpdateDialog.downloadKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('download:2.1.0'));
      expect(find.byKey(UpdateDialog.installKey), findsOneWidget);
    });

    testWidgets('failed state shows error_detail and offers retry', (tester) async {
      _bigView(tester);
      const detail = 'الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه';
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [
        UpdateStatus(state: UpdateState.failed, errorCode: 'hash_mismatch', errorDetail: detail),
      ]);
      await tester.pumpWidget(_app(fake: fake, home: _Opener((c) => showUpdateDialog(c, optionalCheck))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('${en.updateFailed}: $detail'), findsOneWidget);
      expect(find.text(en.updateRetry), findsOneWidget);
    });

    testWidgets('install -> restarting overlay -> exit after the delay', (tester) async {
      _bigView(tester);
      var exited = 0;
      final fake = FakeAppUpdateService(
        check: optionalCheck,
        statuses: const [UpdateStatus(state: UpdateState.ready, version: '2.1.0')],
      );
      await tester.pumpWidget(_app(
        fake: fake,
        home: _Opener((c) => showUpdateDialog(c, optionalCheck)),
        extra: [appExitProvider.overrideWithValue(() => exited++)],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(UpdateDialog.installKey));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, contains('apply:2.1.0'));
      expect(find.text(en.updateInstalling), findsWidgets);
      expect(exited, 0);
      await tester.pump(updateExitDelay);
      expect(exited, 1);
    });

    testWidgets('non-admin sees the notice only, no install/download buttons', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(
        fake: FakeAppUpdateService(check: optionalCheck),
        admin: false,
        home: _Opener((c) => showUpdateDialog(c, optionalCheck)),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(en.updateAdminOnlyNotice), findsOneWidget);
      expect(find.byKey(UpdateDialog.downloadKey), findsNothing);
      expect(find.byKey(UpdateDialog.installKey), findsNothing);
    });

    testWidgets('backend 501 detail is shown as a SnackBar', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(
        check: optionalCheck,
        statuses: const [UpdateStatus(state: UpdateState.ready, version: '2.1.0')],
      )..actionError = _dioError(501, 'غير متاح بعد');
      await tester.pumpWidget(_app(fake: fake, home: _Opener((c) => showUpdateDialog(c, optionalCheck))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateDialog.installKey));
      await tester.pumpAndSettle();
      expect(find.text('غير متاح بعد'), findsOneWidget);
    });
  });

  test('403 is replaced by the localized no-permission message', () {
    expect(updateErrorText(en, _dioError(403, 'Permission denied: system.update')), en.updateNoPermission);
    expect(updateErrorText(en, _dioError(409, 'جاري تنزيل التحديث بالفعل')), 'جاري تنزيل التحديث بالفعل');
  });

  group('UpdateRollbackDialog', () {
    testWidgets('shows backup time + warning and needs explicit confirmation', (tester) async {
      _bigView(tester);
      var exited = 0;
      final backupTime = DateTime(2026, 9, 24, 9, 15);
      final fake = FakeAppUpdateService(
        last: UpdateLastResult(
          result: UpdateResultKind.failed,
          backupFile: 'pre_update/b.db',
          backupCreatedAt: backupTime,
        ),
      );
      await tester.pumpWidget(_app(
        fake: fake,
        home: const _Opener(showUpdateRollbackDialog),
        extra: [appExitProvider.overrideWithValue(() => exited++)],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.updateRollbackWarning('2026-09-24 09:15')), findsOneWidget);

      // Disabled until acknowledged.
      await tester.tap(find.byKey(UpdateRollbackDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);

      await tester.tap(find.byKey(UpdateRollbackDialog.acknowledgeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateRollbackDialog.confirmKey));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, ['rollback:pre_update/b.db']);
      await tester.pump(updateExitDelay);
      expect(exited, 1);
    });

    testWidgets('no backup -> message and no confirm button', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(), home: const _Opener(showUpdateRollbackDialog)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(en.updateRollbackNoBackup), findsOneWidget);
      expect(find.byKey(UpdateRollbackDialog.confirmKey), findsNothing);
    });
  });
}
