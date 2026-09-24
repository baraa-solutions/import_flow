import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:frontend/features/app_update/widgets/app_update_panel.dart';
import 'package:frontend/features/app_update/widgets/post_update_notice.dart';

import 'helpers/fake_app_update_service.dart';

const en = AppLocalizationsEn();

/// In-memory replacement for the SharedPreferences-backed store.
class _MemoryNoticeStore extends UpdateNoticeStore {
  String? seen;

  @override
  Future<String?> lastSeen() async => seen;

  @override
  Future<void> markSeen(String key) async => seen = key;
}

Widget _app(FakeAppUpdateService fake, Widget child, {_MemoryNoticeStore? store}) {
  return ProviderScope(
    overrides: [
      appUpdateServiceProvider.overrideWithValue(fake),
      canInstallUpdatesProvider.overrideWithValue(true),
      updateNoticeStoreProvider.overrideWithValue(store ?? _MemoryNoticeStore()),
    ],
    child: AppLocalizationsProvider(
      locale: const Locale('en'),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  group('PostUpdateNotice', () {
    testWidgets('rollback success shows the rollback-specific message', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(
        last: const UpdateLastResult(
          result: UpdateResultKind.success,
          kind: UpdateOperationKind.rollback,
          toVersion: '2.0.3',
        ),
      );
      await tester.pumpWidget(_app(fake, const PostUpdateNotice()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateRollbackSucceeded('2.0.3')), findsOneWidget);
      expect(find.text(en.updateSucceeded('2.0.3')), findsNothing);
    });

    testWidgets('rollback failure shows its message and offers no rollback', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(
        last: const UpdateLastResult(
          result: UpdateResultKind.failed,
          kind: UpdateOperationKind.rollback,
          detail: 'النسخة الاحتياطية تالفة',
        ),
      );
      await tester.pumpWidget(_app(fake, const PostUpdateNotice()));
      await tester.pumpAndSettle();
      expect(find.text('${en.updateRollbackFailed}: النسخة الاحتياطية تالفة'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, en.updateRollback), findsNothing);
    });

    testWidgets('failed update (kind missing) still offers rollback', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(last: const UpdateLastResult(result: UpdateResultKind.failed));
      await tester.pumpWidget(_app(fake, const PostUpdateNotice()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBarAction, en.updateRollback), findsOneWidget);
    });

    testWidgets('update success shows the update message only once', (tester) async {
      _bigView(tester);
      final store = _MemoryNoticeStore();
      const last = UpdateLastResult(
        result: UpdateResultKind.success,
        kind: UpdateOperationKind.update,
        toVersion: '2.1.0',
      );
      store.seen = last.noticeKey;
      await tester.pumpWidget(_app(FakeAppUpdateService(last: last), const PostUpdateNotice(), store: store));
      await tester.pumpAndSettle();
      expect(find.text(en.updateSucceeded('2.1.0')), findsNothing, reason: 'already shown before');
    });
  });

  group('AppUpdatePanel rollback button', () {
    testWidgets('hidden right after a rollback', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(
        last: const UpdateLastResult(result: UpdateResultKind.success, kind: UpdateOperationKind.rollback),
      );
      await tester.pumpWidget(_app(fake, const AppUpdatePanel()));
      await tester.pumpAndSettle();
      expect(find.byKey(AppUpdatePanel.rollbackKey), findsNothing);
    });

    testWidgets('shown after an update', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(
        last: const UpdateLastResult(result: UpdateResultKind.failed, kind: UpdateOperationKind.update),
      );
      await tester.pumpWidget(_app(fake, const AppUpdatePanel()));
      await tester.pumpAndSettle();
      expect(find.byKey(AppUpdatePanel.rollbackKey), findsOneWidget);
    });
  });
}
