import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/production_sync/services/local_process_sync_service.dart';
import 'package:frontend/features/production_sync/widgets/production_sync_hub_dialog.dart';

class _MockLocalProcessSyncService implements LocalProcessSyncService {
  @override
  String get projectRoot => 'mock_root';
  @override
  String get devDbPath => 'C:/data/dev.db';
  @override
  String get prodDbPath => 'C:/data/prod.db';
  @override
  String get backupsPath => 'mock_backups';

  @override
  LocalDbStats getDbStats(String dbPath) => LocalDbStats(
        exists: true,
        dbPath: dbPath,
        sizeKb: 2048,
        mtime: '2026-09-08 12:00',
      );

  @override
  List<LocalBackupEntry> listBackups() => const [
        LocalBackupEntry(
          filename: 'backup_prod_20260908.db',
          filepath: 'mock_backups/backup_prod_20260908.db',
          sizeKb: 2048,
          mtime: '2026-09-08 12:00',
          tag: 'prod',
        ),
      ];

  @override
  Future<int> compareDatabases({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  }) async {
    onDiffSummary?.call(const SyncDiffSummary(
      exists: true,
      targetExists: true,
      totalNewRecords: 0,
      tablesWithDiff: 0,
      tables: [],
    ));
    return 0;
  }

  @override
  Future<int> createManualBackup({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ar = AppLocalizationsAr();

  group('ProductionSyncHubDialog Widget Tests', () {
    testWidgets('renders dialog with SelectionArea, localized labels, and DB cards', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockService = _MockLocalProcessSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
          ],
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ProductionSyncHubDialog(service: mockService),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Check header title and subtitle
      expect(find.text(ar.prodSyncHubDialogTitle), findsOneWidget);
      expect(find.text(ar.prodSyncHubDialogSubtitle), findsOneWidget);

      // Check DB card titles
      expect(find.text(ar.prodSyncDevDbTitle), findsOneWidget);
      expect(find.text(ar.prodSyncProdDbTitle), findsOneWidget);

      // Operations tab: only the read-only compare action remains.
      expect(find.text(ar.prodSyncCompareTablesBtn), findsAtLeastNWidgets(1));
      // Retired (CTO decision): sync to prod, pull, full build, launch.
      expect(find.byIcon(Icons.cloud_upload_rounded), findsNothing);
      expect(find.byIcon(Icons.inventory_rounded), findsNothing);
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsNothing);
    });

    testWidgets('switches to Safety Backups tab and renders copyable backups', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockService = _MockLocalProcessSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
          ],
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ProductionSyncHubDialog(service: mockService),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Backups tab
      await tester.tap(find.text(ar.prodSyncTabSafetyBackups));
      await tester.pumpAndSettle();

      // Verify Backups Tab content
      expect(find.text(ar.prodSyncBackupsArchiveHeader(1)), findsOneWidget);
      expect(find.text(ar.prodSyncCopyDossierBtn), findsOneWidget);
      expect(find.text(ar.prodSyncCreateInstantBackupBtn), findsOneWidget);
      expect(find.text('backup_prod_20260908.db'), findsOneWidget);
      expect(find.text(ar.prodSyncRestoreActionBtn), findsOneWidget);
    });
  });
}
