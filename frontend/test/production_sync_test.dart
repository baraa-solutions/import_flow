import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/production_sync/models/production_sync_model.dart';
import 'package:frontend/features/production_sync/providers/production_sync_provider.dart';
import 'package:frontend/features/production_sync/screens/production_sync_screen.dart';
import 'package:frontend/features/production_sync/services/local_process_sync_service.dart';
import 'package:frontend/features/production_sync/services/production_sync_service.dart';

void main() {
  group('ProductionSyncModel Unit Tests', () {
    test('SystemVersionInfoModel fromJson should parse correctly', () {
      final json = {
        'system_name': 'Sorour Logistics ERP',
        'version': '1.0.52',
        'build_number': 53,
        'release_date': '2026-08-28 15:30:00',
        'is_standalone': true,
        'environment': 'standalone',
        'database_path': 'sorour_logistics.db',
        'database_size_kb': 2500.5,
        'tables_count': 68,
        'total_backups_count': 12,
      };

      final model = SystemVersionInfoModel.fromJson(json);
      expect(model.systemName, 'Sorour Logistics ERP');
      expect(model.version, '1.0.52');
      expect(model.buildNumber, 53);
      expect(model.isStandalone, isTrue);
      expect(model.tablesCount, 68);
      expect(model.totalBackupsCount, 12);
    });

    test('RemoteUpdateCheckResultModel fromJson should parse update status and notes', () {
      final json = {
        'has_update': true,
        'current_version': '1.0.52',
        'latest_version': '1.0.53',
        'release_name': 'Sorour Logistics Release v1.0.53',
        'release_notes': [
          'Safe Auto-Update Engine integration',
          'In-Place Schema Upgrade support',
        ],
        'download_url': 'https://github.com/ahmedsalahsorour88/import_flow/releases/tag/v1.0.53',
        'is_mandatory': false,
        'check_status': 'UPDATE_AVAILABLE',
        'message': 'New update ready!',
      };

      final result = RemoteUpdateCheckResultModel.fromJson(json);
      expect(result.hasUpdate, isTrue);
      expect(result.currentVersion, '1.0.52');
      expect(result.latestVersion, '1.0.53');
      expect(result.releaseNotes.length, 2);
      expect(result.checkStatus, 'UPDATE_AVAILABLE');
    });

    test('DatabaseStatsModel fromJson should parse correctly', () {
      final json = {
        'exists': true,
        'path': 'C:/ImportFlow/sorour_logistics.db',
        'size_kb': 1588.0,
        'tables_count': 66,
        'total_records': 379,
        'mtime': '2026-08-22 23:45:00',
      };
      final stats = DatabaseStatsModel.fromJson(json);
      expect(stats.exists, isTrue);
      expect(stats.tablesCount, 66);
      expect(stats.totalRecords, 379);
      expect(stats.sizeKb, 1588.0);
    });

    test('SyncComparisonResponseModel should evaluate isFullySynchronized correctly', () {
      final json = {
        'dev_stats': {
          'exists': true,
          'size_kb': 1600.0,
          'tables_count': 66,
          'total_records': 379,
        },
        'prod_stats': {
          'exists': true,
          'size_kb': 1600.0,
          'tables_count': 66,
          'total_records': 379,
        },
        'is_fully_synchronized': true,
        'total_tables': 66,
        'matched_tables_count': 66,
        'differing_tables_count': 0,
        'schema_diffs_count': 0,
        'tables': [
          {
            'table_name': 'transport_locations',
            'dev_count': 54,
            'prod_count': 54,
            'diff': 0,
            'is_match': true,
            'status': 'متطابق (Matched)',
            'dev_columns_count': 10,
            'prod_columns_count': 10,
            'new_columns': [],
            'is_new_table': false,
            'has_schema_diff': false,
            'needs_sync': false,
          },
          {
            'table_name': 'customs_tariffs',
            'dev_count': 12,
            'prod_count': 12,
            'diff': 0,
            'is_match': true,
            'status': 'متطابق (Matched)',
            'dev_columns_count': 8,
            'prod_columns_count': 8,
            'new_columns': [],
            'is_new_table': false,
            'has_schema_diff': false,
            'needs_sync': false,
          }
        ]
      };

      final comp = SyncComparisonResponseModel.fromJson(json);
      expect(comp.isFullySynchronized, isTrue);
      expect(comp.matchedTablesCount, 66);
      expect(comp.differingTablesCount, 0);
      expect(comp.schemaDiffsCount, 0);
      expect(comp.tables.length, 2);
      expect(comp.tables.first.tableName, 'transport_locations');
      expect(comp.tables.first.isMatch, isTrue);
      expect(comp.tables.first.hasSchemaDiff, isFalse);
    });

    test('TableComparisonItemModel parses schema diff fields correctly', () {
      final json = {
        'table_name': 'import_files',
        'dev_count': 5,
        'prod_count': 5,
        'diff': 0,
        'is_match': false,
        'status': 'ترقية Schema (2 عمود جديد: acid_number, acid_expiry_date)',
        'dev_columns_count': 22,
        'prod_columns_count': 20,
        'new_columns': ['acid_number', 'acid_expiry_date'],
        'is_new_table': false,
        'has_schema_diff': true,
        'needs_sync': true,
      };

      final item = TableComparisonItemModel.fromJson(json);
      expect(item.tableName, 'import_files');
      expect(item.isMatch, isFalse);
      expect(item.hasSchemaDiff, isTrue);
      expect(item.isNewTable, isFalse);
      expect(item.needsSync, isTrue);
      expect(item.newColumns, containsAll(['acid_number', 'acid_expiry_date']));
      expect(item.devColumnsCount, 22);
      expect(item.prodColumnsCount, 20);
    });

    test('TableComparisonItemModel parses new_table flag correctly', () {
      final json = {
        'table_name': 'acid_validity_logs',
        'dev_count': 0,
        'prod_count': 0,
        'diff': 0,
        'is_match': false,
        'status': 'جدول جديد (New Table)',
        'dev_columns_count': 5,
        'prod_columns_count': 0,
        'new_columns': [],
        'is_new_table': true,
        'has_schema_diff': true,
        'needs_sync': true,
      };

      final item = TableComparisonItemModel.fromJson(json);
      expect(item.isNewTable, isTrue);
      expect(item.hasSchemaDiff, isTrue);
      expect(item.needsSync, isTrue);
      expect(item.isMatch, isFalse);
    });

    test('SyncActionResponseModel fromJson should parse action and message', () {
      final json = {
        'success': true,
        'action': 'PUSH_TO_PROD',
        'message': 'تمت مزامنة وتحديث قاعدة بيانات البرودكشن بنجاح تام!',
        'timestamp': '2026-08-22 23:45:00',
        'backup_file': 'sorour_logistics_prod_backup.db',
        'affected_tables_count': 66,
        'total_records_synced': 379,
      };

      final res = SyncActionResponseModel.fromJson(json);
      expect(res.success, isTrue);
      expect(res.action, 'PUSH_TO_PROD');
      expect(res.affectedTablesCount, 66);
      expect(res.totalRecordsSynced, 379);
    });

    test('LocalProcessSyncService retrieves db stats directly from filesystem', () {
      final service = LocalProcessSyncService(ProductionSyncService(Dio()));
      final stats = service.getDbStats(service.devDbPath);
      expect(stats.exists, isTrue);
      expect(stats.sizeKb, greaterThan(0));
      expect(stats.mtime, isNotNull);

      final backups = service.listBackups();
      expect(backups, isA<List<LocalBackupEntry>>());
    });

    test('SyncProgressEvent fromJson parses progress data correctly', () {
      final json = {
        'percent': 65,
        'stage': 'syncing',
        'table': 'cargo_insurance_certificates',
        'current_index': 48,
        'total_tables': 73,
        'records_synced': 5,
        'total_synced': 1450,
        'message': 'جارٍ فحص ومزامنة جدول: cargo_insurance_certificates (48/73) — تم تحديث 5 سجل',
      };

      final event = SyncProgressEvent.fromJson(json);
      expect(event.percent, 65);
      expect(event.stage, 'syncing');
      expect(event.table, 'cargo_insurance_certificates');
      expect(event.currentIndex, 48);
      expect(event.totalTables, 73);
      expect(event.recordsSynced, 5);
      expect(event.totalSynced, 1450);
      expect(event.message, contains('cargo_insurance_certificates'));
    });

    test('SyncTableDiff and SyncDiffSummary parse structured diff correctly', () {
      final json = {
        'exists': true,
        'target_exists': true,
        'total_new_records': 15,
        'tables_with_diff': 2,
        'new_tables_count': 1,
        'new_columns_count': 3,
        'tables': [
          {
            'table_name': 'transport_locations',
            'dev_count': 261,
            'prod_count': 256,
            'diff': 5,
            'status': 'NEW_DATA',
          },
          {
            'table_name': 'cargo_insurance_certificates',
            'dev_count': 10,
            'prod_count': 0,
            'diff': 10,
            'status': 'NEW_TABLE',
          },
          {
            'table_name': 'users',
            'dev_count': 4,
            'prod_count': 4,
            'diff': 0,
            'status': 'MATCH',
          },
        ]
      };

      final diffSummary = SyncDiffSummary.fromJson(json);
      expect(diffSummary.exists, isTrue);
      expect(diffSummary.totalNewRecords, 15);
      expect(diffSummary.tablesWithDiff, 2);
      expect(diffSummary.tables.length, 3);

      final t1 = diffSummary.tables[0];
      expect(t1.tableName, 'transport_locations');
      expect(t1.hasChanges, isTrue);
      expect(t1.isMatch, isFalse);
      expect(t1.diff, 5);

      final t2 = diffSummary.tables[1];
      expect(t2.status, 'NEW_TABLE');
      expect(t2.hasChanges, isTrue);

      final t3 = diffSummary.tables[2];
      expect(t3.isMatch, isTrue);
      expect(t3.hasChanges, isFalse);
    });

    testWidgets('ProductionSyncScreen mounts cleanly without initState inherited widget exceptions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productionSyncNotifierProvider.overrideWith((ref) => FakeProductionSyncNotifier()),
            systemVersionInfoProvider.overrideWith((ref) async => const SystemVersionInfoModel(
                  systemName: 'ImportFlow ERP - Test',
                  version: '1.0.52',
                  buildNumber: 53,
                  isStandalone: true,
                  environment: 'standalone',
                  databasePath: 'test.db',
                )),
            backupsListProvider.overrideWith((ref) async => []),
            updateCheckStateProvider.overrideWith((ref) => const AsyncValue.data(null)),
          ],
          child: MaterialApp(
            home: ProductionSyncScreen(
              service: FakeLocalProcessSyncService(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ProductionSyncScreen), findsOneWidget);
    });

    testWidgets('ProductionSyncScreen renders localized English banner without raw Arabic backend string', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productionSyncNotifierProvider.overrideWith((ref) => FakeProductionSyncNotifier()),
            systemVersionInfoProvider.overrideWith((ref) async => const SystemVersionInfoModel(
                  systemName: 'ImportFlow ERP - Test',
                  version: '1.0.73',
                  buildNumber: 74,
                  isStandalone: true,
                  environment: 'standalone',
                  databasePath: 'test.db',
                )),
            backupsListProvider.overrideWith((ref) async => []),
            updateCheckStateProvider.overrideWith((ref) => const AsyncValue.data(
                  RemoteUpdateCheckResultModel(
                    hasUpdate: false,
                    currentVersion: '1.0.73',
                    latestVersion: '1.0.73',
                    message: 'النظام محدث لأحدث إصدار رسمي.',
                  ),
                )),
          ],
          child: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: MaterialApp(
              locale: const Locale('en'),
              home: ProductionSyncScreen(
                service: FakeLocalProcessSyncService(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Should show English message from AppLocalizationsEn, NOT the raw Arabic from backend
      expect(find.text('System is up to date and running the latest version.'), findsOneWidget);
      expect(find.text('النظام محدث لأحدث إصدار رسمي.'), findsNothing);
    });
  });
}

class FakeProductionSyncNotifier extends StateNotifier<AsyncValue<SyncActionResponseModel?>>
    implements ProductionSyncNotifier {
  FakeProductionSyncNotifier() : super(const AsyncValue.data(null));

  @override
  Future<RemoteUpdateCheckResultModel> checkForUpdates({String? remoteUrl}) async {
    return const RemoteUpdateCheckResultModel(
      hasUpdate: false,
      currentVersion: '1.0.52',
      latestVersion: '1.0.52',
      message: 'Up to date',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalProcessSyncService implements LocalProcessSyncService {
  @override
  String get projectRoot => '/mock/root';
  @override
  String get devDbPath => '/mock/dev.db';
  @override
  String get prodDbPath => '/mock/prod.db';
  @override
  String get backupsPath => '/mock/backups';

  @override
  LocalDbStats getDbStats(String dbPath) => const LocalDbStats(
        exists: true,
        dbPath: '/mock/dev.db',
        sizeKb: 1024,
        mtime: '2026-08-28 12:00:00',
      );

  @override
  List<LocalBackupEntry> listBackups() => [
        const LocalBackupEntry(
          filename: 'test_backup.db',
          filepath: '/mock/backups/test_backup.db',
          tag: 'dev',
          mtime: '2026-08-28 12:00:00',
          sizeKb: 1024,
        ),
      ];

  @override
  Future<int> compareDatabases({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  }) async => 0;

  @override
  Future<int> createManualBackup({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
  }) async => 0;
}
