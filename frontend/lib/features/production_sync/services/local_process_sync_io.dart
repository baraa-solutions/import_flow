import 'dart:io';
import 'dart:convert';
import 'local_process_sync_service.dart';
import 'production_sync_service.dart';

String _joinPath(String p1, [String? p2, String? p3, String? p4]) {
  final sep = Platform.pathSeparator;
  String res = p1;
  if (p2 != null) res = '$res$sep$p2';
  if (p3 != null) res = '$res$sep$p3';
  if (p4 != null) res = '$res$sep$p4';
  return res;
}

String _baseName(String fullPath) {
  final sep = Platform.pathSeparator;
  final idx = fullPath.lastIndexOf(sep);
  if (idx >= 0 && idx < fullPath.length - 1) {
    return fullPath.substring(idx + 1);
  }
  return fullPath;
}

String _resolveProjectRoot() {
  bool isTrueRoot(Directory dir) {
    if (!dir.existsSync()) return false;
    final hasPubspec = File(_joinPath(dir.path, 'frontend', 'pubspec.yaml')).existsSync();
    final hasModules = Directory(_joinPath(dir.path, 'modules')).existsSync();
    final hasSyncScript = File(_joinPath(dir.path, 'sync_to_production.py')).existsSync();
    return (hasPubspec || hasModules) && hasSyncScript;
  }

  // 1. Check Directory.current and its parents
  try {
    Directory dir = Directory.current;
    for (int i = 0; i < 8; i++) {
      if (isTrueRoot(dir)) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // 2. Check Platform.resolvedExecutable and its parents
  try {
    final exe = File(Platform.resolvedExecutable);
    Directory dir = exe.parent;
    for (int i = 0; i < 8; i++) {
      if (isTrueRoot(dir)) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // 3. Check USERPROFILE / HOME desktop folder
  try {
    final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (userProfile.isNotEmpty) {
      final candidatePaths = [
        _joinPath(userProfile, 'Desktop', 'SorourLogistics'),
        _joinPath(userProfile, 'Desktop', 'Sorour_Logistics'),
        _joinPath(userProfile, 'Desktop', 'ImportFlow'),
        _joinPath(userProfile, 'Desktop', 'import_flow'),
        _joinPath(userProfile, 'Documents', 'SorourLogistics'),
        _joinPath(userProfile, 'Documents', 'ImportFlow'),
        _joinPath(userProfile, 'SorourLogistics'),
        _joinPath(userProfile, 'ImportFlow'),
      ];
      for (final cand in candidatePaths) {
        if (isTrueRoot(Directory(cand))) {
          return cand;
        }
      }
    }
  } catch (_) {}

  // 4. Check well-known workspace paths on Windows
  const knownWindowsPaths = [
    r'F:\SorourLogistics',
    r'C:\SorourLogistics',
    r'D:\SorourLogistics',
    r'E:\SorourLogistics',
    r'C:\Users\Hp\Desktop\SorourLogistics',
    r'C:\Users\Hp\Desktop\ImportFlow',
    r'C:\ImportFlow',
    r'D:\ImportFlow',
    r'E:\ImportFlow',
  ];
  for (final kp in knownWindowsPaths) {
    try {
      if (isTrueRoot(Directory(kp))) {
        return kp;
      }
    } catch (_) {}
  }

  // 5. Fallback: search for any sync_to_production.py in parents
  try {
    Directory dir = Directory.current;
    for (int i = 0; i < 8; i++) {
      if (File(_joinPath(dir.path, 'sync_to_production.py')).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return Directory.current.path;
  } catch (_) {}

  return r'C:\Users\Hp\Desktop\ImportFlow';
}

LocalProcessSyncService createLocalProcessSyncService(ProductionSyncService api) =>
    LocalProcessSyncServiceImpl(api);

class LocalProcessSyncServiceImpl implements LocalProcessSyncService {
  final String _projectRoot;
  final ProductionSyncService _api;

  LocalProcessSyncServiceImpl(this._api) : _projectRoot = _resolveProjectRoot();

  @override
  String get projectRoot => _projectRoot;

  @override
  String get devDbPath => _joinPath(_projectRoot, 'sorour_logistics.db');

  @override
  String get prodDbPath => _joinPath(
        _projectRoot,
        'dist',
        'Sorour_Logistics_Standalone',
        'sorour_logistics.db',
      );

  @override
  String get backupsPath => _joinPath(_projectRoot, 'backups');

  Future<String> _findPythonExecutable() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final candidates = [
        'python',
        'py',
        'python3',
        if (userProfile.isNotEmpty) _joinPath(userProfile, r'AppData\Local\Programs\Python\Python312\python.exe'),
        if (userProfile.isNotEmpty) _joinPath(userProfile, r'AppData\Local\Programs\Python\Python311\python.exe'),
        if (userProfile.isNotEmpty) _joinPath(userProfile, r'AppData\Local\Programs\Python\Python310\python.exe'),
        r'C:\Program Files\Python312\python.exe',
        r'C:\Program Files\Python311\python.exe',
      ];
      for (final cmd in candidates) {
        if (cmd.contains(Platform.pathSeparator) && !File(cmd).existsSync()) {
          continue;
        }
        try {
          final res = await Process.run(cmd, ['--version'], runInShell: true);
          if (res.exitCode == 0) return cmd;
        } catch (_) {}
      }
    } catch (_) {}
    return 'python';
  }

  @override
  LocalDbStats getDbStats(String dbPath) {
    try {
      final file = File(dbPath);
      if (!file.existsSync()) {
        return LocalDbStats(exists: false, dbPath: dbPath);
      }
      final stat = file.statSync();
      final sizeKb = stat.size / 1024.0;
      final mtime = stat.modified.toLocal().toString().substring(0, 19);
      return LocalDbStats(
        exists: true,
        dbPath: dbPath,
        sizeKb: double.parse(sizeKb.toStringAsFixed(1)),
        mtime: mtime,
      );
    } catch (e) {
      return LocalDbStats(exists: true, dbPath: dbPath, error: e.toString());
    }
  }

  @override
  List<LocalBackupEntry> listBackups() {
    try {
      final dir = Directory(backupsPath);
      if (!dir.existsSync()) return [];
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files.map((f) {
        final stat = f.statSync();
        final nameBase = _baseName(f.path);
        String tag = 'backup';
        if (nameBase.contains('prod_before_sync')) {
          tag = 'prod_before_sync';
        } else if (nameBase.contains('dev_snapshot')) {
          tag = 'dev_snapshot';
        } else if (nameBase.contains('dev_before_pull')) {
          tag = 'dev_before_pull';
        } else if (nameBase.contains('prod_before_pack')) {
          tag = 'prod_before_pack';
        } else if (nameBase.contains('prod_snapshot')) {
          tag = 'prod_snapshot';
        } else if (nameBase.contains('manual')) {
          tag = 'manual';
        }
        return LocalBackupEntry(
          filename: nameBase,
          filepath: f.path,
          sizeKb: double.parse((stat.size / 1024.0).toStringAsFixed(1)),
          mtime: stat.modified.toLocal().toString().substring(0, 19),
          tag: tag,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> _runScript(
    List<String> args, {
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncProgressEvent progress)? onProgress,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  }) async {
    onOutput('⚡ > python -u sync_to_production.py ${args.join(' ')}');
    onOutput('📂 Project Root: $_projectRoot');
    onOutput('────────────────────────────────────────────────────────────────────────');

    final scriptPath = _joinPath(_projectRoot, 'sync_to_production.py');
    if (!File(scriptPath).existsSync()) {
      onError('❌ [ERROR] لم يتم العثور على ملف sync_to_production.py في المسار: $scriptPath');
      return 1;
    }

    try {
      final pythonCmd = await _findPythonExecutable();
      final process = await Process.start(
        pythonCmd,
        ['-u', scriptPath, ...args],
        workingDirectory: _projectRoot,
        runInShell: true,
        environment: {
          'PYTHONUNBUFFERED': '1',
          'PYTHONIOENCODING': 'utf-8',
        },
      );

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('[PROGRESS] ')) {
          try {
            final jsonStr = line.substring(11).trim();
            final parsed = json.decode(jsonStr) as Map<String, dynamic>;
            onProgress?.call(SyncProgressEvent.fromJson(parsed));
          } catch (_) {}
        } else if (line.startsWith('[DIFF_DATA] ')) {
          try {
            final jsonStr = line.substring(12).trim();
            final parsed = json.decode(jsonStr) as Map<String, dynamic>;
            onDiffSummary?.call(SyncDiffSummary.fromJson(parsed));
          } catch (_) {}
        }
        onOutput(line);
      });

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .where((l) => l.trim().isNotEmpty)
          .listen(onError);

      final exitCode = await process.exitCode;
      onOutput('────────────────────────────────────────────────────────────────────────');
      if (exitCode == 0) {
        onOutput('✅ اكتملت العملية بنجاح تام (Exit Code: 0)');
      } else {
        onError('❌ انتهت العملية مع رمز خطأ: $exitCode');
      }
      return exitCode;
    } catch (e) {
      onError('⚠️ تعذر تشغيل سطر أوامر بايثون محلياً: $e');
      onError('🔄 جارٍ التحويل التلقائي للتنفيذ الآمن عبر السيرفر (FastAPI Engine)...');
      try {
        final api = _api;
        if (args.contains('--compare')) {
          final comp = await api.getComparison();
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
          onDiffSummary?.call(SyncDiffSummary(
            exists: true,
            targetExists: comp.prodStats.exists,
            totalNewRecords: comp.tables.where((t) => t.diff > 0).fold(0, (acc, t) => acc + t.diff),
            tablesWithDiff: comp.differingTablesCount,
            newTablesCount: comp.tables.where((t) => t.isNewTable).length,
            newColumnsCount: comp.schemaDiffsCount,
            tables: diffTables,
          ));
          onOutput('✅ تم جلب مقارنة قاعدة البيانات بنجاح عبر السيرفر');
          return 0;
        }
        onError('❌ Unsupported action: ${args.join(' ')}');
        return 1;
      } catch (apiErr) {
        onError('❌ فشل التنفيذ عبر السيرفر أيضاً: $apiErr');
        return 1;
      }
    }
  }

  @override
  Future<int> compareDatabases({
    required void Function(String) onOutput,
    required void Function(String) onError,
    void Function(SyncDiffSummary)? onDiffSummary,
  }) =>
      _runScript(
        ['--compare'],
        onOutput: onOutput,
        onError: onError,
        onDiffSummary: onDiffSummary,
      );

  @override
  Future<int> createManualBackup({
    required void Function(String) onOutput,
    required void Function(String) onError,
  }) async {
    onOutput('📸 جارٍ إنشاء لقطة فورية لقاعدة البيانات...');
    final devFile = File(devDbPath);
    if (!devFile.existsSync()) {
      onError('❌ لم يتم العثور على قاعدة بيانات التطوير: $devDbPath');
      return 1;
    }

    try {
      final bDir = Directory(backupsPath);
      if (!bDir.existsSync()) bDir.createSync(recursive: true);

      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final backupPath = _joinPath(backupsPath, 'sorour_logistics_manual_$ts.db');
      devFile.copySync(backupPath);

      final bFile = File(backupPath);
      final sizeKb = bFile.statSync().size / 1024.0;
      onOutput('✅ تم إنشاء نسخة الأمان بنجاح: ${_baseName(backupPath)} (${sizeKb.toStringAsFixed(1)} KB)');
      return 0;
    } catch (e) {
      onError('❌ فشل إنشاء نسخة الأمان: $e');
      return 1;
    }
  }
}
