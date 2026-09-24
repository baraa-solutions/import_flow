import 'local_process_sync_service.dart';
import 'production_sync_service.dart';
import '../models/production_sync_model.dart';

LocalProcessSyncService createLocalProcessSyncService(ProductionSyncService api) =>
    LocalProcessSyncServiceWebImpl(api);

class LocalProcessSyncServiceWebImpl implements LocalProcessSyncService {
  final ProductionSyncService _apiService;

  LocalProcessSyncServiceWebImpl(this._apiService);

  SyncComparisonResponseModel? _cachedComparison;
  List<BackupItemModel> _cachedBackups = [];

  @override
  String get projectRoot => r'C:\Users\Hp\Desktop\ImportFlow';

  @override
  String get devDbPath => r'C:\Users\Hp\Desktop\ImportFlow\sorour_logistics.db';

  @override
  String get prodDbPath => r'C:\Users\Hp\Desktop\ImportFlow\dist\Sorour_Logistics_Standalone\sorour_logistics.db';

  @override
  String get backupsPath => r'C:\Users\Hp\Desktop\ImportFlow\backups';

  @override
  LocalDbStats getDbStats(String dbPath) {
    final isProd = dbPath.contains('dist') || dbPath.contains('Standalone') || dbPath.contains('prod');
    if (_cachedComparison != null) {
      final stats = isProd ? _cachedComparison!.prodStats : _cachedComparison!.devStats;
      return LocalDbStats(
        exists: stats.exists,
        dbPath: stats.path ?? dbPath,
        sizeKb: stats.sizeKb,
        mtime: stats.mtime ?? 'متصل بالسيرفر',
        error: stats.error,
      );
    }
    return LocalDbStats(
      exists: true,
      dbPath: dbPath,
      sizeKb: 2452.0,
      mtime: 'متصل بالسيرفر',
    );
  }

  @override
  List<LocalBackupEntry> listBackups() {
    return _cachedBackups.map((b) {
      return LocalBackupEntry(
        filename: b.filename,
        filepath: b.filepath,
        sizeKb: b.sizeKb,
        mtime: b.createdAt,
        tag: b.tag,
      );
    }).toList();
  }

  @override
  Future<int> compareDatabases({
    required void Function(String) onOutput,
    required void Function(String) onError,
    void Function(SyncDiffSummary)? onDiffSummary,
  }) async {
    try {
      onOutput('🔍 [API] جاري فحص ومقارنة قاعدتي البيانات عبر السيرفر...');
      final comp = await _apiService.getComparison();
      _cachedComparison = comp;

      // Update backups cache as well
      try {
        _cachedBackups = await _apiService.listBackups();
      } catch (_) {}

      final diffTables = comp.tables.map((t) {
        String status = 'MATCH';
        if (t.isNewTable) {
          status = 'NEW_TABLE';
        } else if (t.hasSchemaDiff) {
          status = 'SCHEMA_DIFF';
        } else if (t.diff > 0) {
          status = 'NEW_DATA';
        } else if (t.diff < 0) {
          status = 'BEHIND';
        }

        return SyncTableDiff(
          tableName: t.tableName,
          devCount: t.devCount,
          prodCount: t.prodCount,
          diff: t.diff,
          status: status,
        );
      }).toList();

      final summary = SyncDiffSummary(
        exists: true,
        targetExists: comp.prodStats.exists,
        totalNewRecords: comp.tables.where((t) => t.diff > 0).fold(0, (acc, t) => acc + t.diff),
        tablesWithDiff: comp.differingTablesCount,
        newTablesCount: comp.tables.where((t) => t.isNewTable).length,
        newColumnsCount: comp.schemaDiffsCount,
        tables: diffTables,
      );

      onDiffSummary?.call(summary);
      onOutput('📊 نتائج الفحص: إجمالي الجداول (${comp.totalTables}) | متطابقة (${comp.matchedTablesCount}) | بحاجة لتحديث (${comp.differingTablesCount})');
      if (comp.isFullySynchronized) {
        onOutput('✅ قاعدتا البيانات متطابقتان تماماً بنسبة 100%');
      } else {
        onOutput('⚠️ توجد تحديثات في ${comp.differingTablesCount} جدول جاهزة للمزامنة');
      }

      return 0;
    } catch (e) {
      onError('❌ [ERROR] فشل جلب مقارنة قاعدة البيانات: $e');
      return 1;
    }
  }

  @override
  Future<int> createManualBackup({
    required void Function(String) onOutput,
    required void Function(String) onError,
  }) async {
    try {
      onOutput('📸 [API] جاري إنشاء نسخة احتياطية فورية عبر السيرفر...');
      final backup = await _apiService.createManualBackup(target: 'dev');
      _cachedBackups = await _apiService.listBackups();
      onOutput('✅ [BACKUP] تم إنشاء نسخة الأمان بنجاح: ${backup.filename} (${backup.sizeKb} KB)');
      return 0;
    } catch (e) {
      onError('❌ [ERROR] فشل إنشاء النسخة الاحتياطية: $e');
      return 1;
    }
  }
}
