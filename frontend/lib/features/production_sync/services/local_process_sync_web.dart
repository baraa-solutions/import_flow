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
  Future<int> syncDevToProd({
    required void Function(String) onOutput,
    required void Function(String) onError,
    void Function(SyncProgressEvent)? onProgress,
    void Function(SyncDiffSummary)? onDiffSummary,
  }) async {
    try {
      onOutput('🚀 [API] بدء المزامنة الآمنة لقاعدة بيانات الإنتاج عبر السيرفر...');
      onProgress?.call(const SyncProgressEvent(
        percent: 20,
        stage: 'init',
        table: 'all',
        currentIndex: 1,
        totalTables: 10,
        recordsSynced: 0,
        totalSynced: 0,
        message: 'جارٍ أخذ نسخة احتياطية فورية وتطبيق الترقية الآمنة...',
      ));

      final res = await _apiService.syncDevToProd();
      onProgress?.call(const SyncProgressEvent(
        percent: 80,
        stage: 'merging',
        table: 'done',
        currentIndex: 10,
        totalTables: 10,
        recordsSynced: 0,
        totalSynced: 0,
        message: 'تمت ترقية الهيكل ومزامنة البيانات المرجعية بنجاح...',
      ));

      onOutput('✅ [SUCCESS] ${res.message}');
      if (res.backupFile != null) {
        onOutput('📦 [BACKUP] تم إنشاء نسخة أمان احتياطية: ${res.backupFile}');
      }
      onOutput('📊 عدد الجداول المحدثة: ${res.affectedTablesCount} | السجلات: ${res.totalRecordsSynced}');

      await compareDatabases(
        onOutput: onOutput,
        onError: onError,
        onDiffSummary: onDiffSummary,
      );

      onProgress?.call(const SyncProgressEvent(
        percent: 100,
        stage: 'completed',
        table: 'done',
        currentIndex: 10,
        totalTables: 10,
        recordsSynced: 0,
        totalSynced: 0,
        message: 'اكتملت المزامنة الآمنة بنجاح تام 100%',
      ));

      return 0;
    } catch (e) {
      onError('❌ [ERROR] فشل تنفيذ المزامنة عبر السيرفر: $e');
      return 1;
    }
  }

  @override
  Future<int> pullProdToDev({
    required void Function(String) onOutput,
    required void Function(String) onError,
    void Function(SyncProgressEvent)? onProgress,
  }) async {
    try {
      onOutput('🚀 [API] بدء سحب بيانات الإنتاج إلى بيئة التطوير...');
      onProgress?.call(const SyncProgressEvent(
        percent: 30,
        stage: 'init',
        table: 'all',
        currentIndex: 1,
        totalTables: 10,
        recordsSynced: 0,
        totalSynced: 0,
        message: 'جارٍ سحب ودمج بيانات الإنتاج بأمان...',
      ));

      final res = await _apiService.pullProdToDev();
      onOutput('✅ [SUCCESS] ${res.message}');
      if (res.backupFile != null) {
        onOutput('📦 [BACKUP] تم إنشاء نسخة أمان للتطوير: ${res.backupFile}');
      }

      onProgress?.call(const SyncProgressEvent(
        percent: 100,
        stage: 'completed',
        table: 'done',
        currentIndex: 10,
        totalTables: 10,
        recordsSynced: 0,
        totalSynced: 0,
        message: 'تم سحب ودمج البيانات بنجاح',
      ));
      return 0;
    } catch (e) {
      onError('❌ [ERROR] فشل سحب بيانات الإنتاج: $e');
      return 1;
    }
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
  Future<int> fullBuildAndSync({
    required void Function(String) onOutput,
    required void Function(String) onError,
    void Function(SyncProgressEvent)? onProgress,
    void Function(SyncDiffSummary)? onDiffSummary,
  }) async {
    onOutput('📦 [BUILD] بدء التجميع والمزامنة الشاملة للإنتاج...');
    return await syncDevToProd(
      onOutput: onOutput,
      onError: onError,
      onProgress: onProgress,
      onDiffSummary: onDiffSummary,
    );
  }

  @override
  Future<int> launchProductionApp({
    required void Function(String) onOutput,
    required void Function(String) onError,
  }) async {
    onOutput('🚀 [LAUNCH] لتشغيل تطبيق الإنتاج المستقل على ويندوز، استخدم الملف: dist/Start_Sorour_Logistics_Production.bat');
    return 0;
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
