import '../models/production_sync_model.dart';

/// Local database statistics.
class LocalDbStats {
  final bool exists;
  final String dbPath;
  final double sizeKb;
  final String? mtime;
  final String? error;

  const LocalDbStats({
    required this.exists,
    required this.dbPath,
    this.sizeKb = 0,
    this.mtime,
    this.error,
  });
}

/// A single backup file entry.
class LocalBackupEntry {
  final String filename;
  final String filepath;
  final double sizeKb;
  final String mtime;
  final String tag;

  const LocalBackupEntry({
    required this.filename,
    required this.filepath,
    required this.sizeKb,
    required this.mtime,
    required this.tag,
  });
}

/// Represents live progress event emitted during synchronization.
class SyncProgressEvent {
  final int percent;
  final String stage;
  final String table;
  final int currentIndex;
  final int totalTables;
  final int recordsSynced;
  final int totalSynced;
  final String message;

  const SyncProgressEvent({
    required this.percent,
    this.stage = 'syncing',
    this.table = '',
    this.currentIndex = 0,
    this.totalTables = 0,
    this.recordsSynced = 0,
    this.totalSynced = 0,
    required this.message,
  });

  factory SyncProgressEvent.fromJson(Map<String, dynamic> json) {
    return SyncProgressEvent(
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      stage: json['stage'] as String? ?? 'syncing',
      table: json['table'] as String? ?? '',
      currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
      totalTables: (json['total_tables'] as num?)?.toInt() ?? 0,
      recordsSynced: (json['records_synced'] as num?)?.toInt() ?? 0,
      totalSynced: (json['total_synced'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Represents comparison diff information for a specific database table.
class SyncTableDiff {
  final String tableName;
  final int devCount;
  final int prodCount;
  final int diff;
  final String status;

  const SyncTableDiff({
    required this.tableName,
    required this.devCount,
    required this.prodCount,
    required this.diff,
    required this.status,
  });

  factory SyncTableDiff.fromJson(Map<String, dynamic> json) {
    return SyncTableDiff(
      tableName: json['table_name'] as String? ?? '',
      devCount: (json['dev_count'] as num?)?.toInt() ?? 0,
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
      diff: (json['diff'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'MATCH',
    );
  }

  bool get hasChanges => diff != 0 || status == 'NEW_TABLE' || status == 'NEW_DATA';
  bool get isMatch => diff == 0 && status == 'MATCH';
}

/// Aggregated diff summary between Dev and Prod databases.
class SyncDiffSummary {
  final bool exists;
  final bool targetExists;
  final int totalNewRecords;
  final int tablesWithDiff;
  final int newTablesCount;
  final int newColumnsCount;
  final List<SyncTableDiff> tables;

  const SyncDiffSummary({
    this.exists = false,
    this.targetExists = false,
    this.totalNewRecords = 0,
    this.tablesWithDiff = 0,
    this.newTablesCount = 0,
    this.newColumnsCount = 0,
    this.tables = const [],
  });

  factory SyncDiffSummary.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'] as List<dynamic>? ?? [];
    final parsedTables = rawTables
        .map((e) => SyncTableDiff.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SyncDiffSummary(
      exists: json['exists'] as bool? ?? false,
      targetExists: json['target_exists'] as bool? ?? false,
      totalNewRecords: (json['total_new_records'] as num?)?.toInt() ?? 0,
      tablesWithDiff: (json['tables_with_diff'] as num?)?.toInt() ?? 0,
      newTablesCount: (json['new_tables_count'] as num?)?.toInt() ?? 0,
      newColumnsCount: (json['new_columns_count'] as num?)?.toInt() ?? 0,
      tables: parsedTables,
    );
  }

  /// Builds the summary from the backend `GET /compare` response (used by the
  /// web service and by the desktop server-side fallback).
  factory SyncDiffSummary.fromComparison(SyncComparisonResponseModel comp) {
    return SyncDiffSummary(
      exists: true,
      targetExists: comp.prodStats.exists,
      totalNewRecords: comp.tables.where((t) => t.diff > 0).fold(0, (acc, t) => acc + t.diff),
      tablesWithDiff: comp.differingTablesCount,
      newTablesCount: comp.tables.where((t) => t.isNewTable).length,
      newColumnsCount: comp.schemaDiffsCount,
      tables: comp.tables.map(_tableDiffFromComparison).toList(),
    );
  }

  static SyncTableDiff _tableDiffFromComparison(TableComparisonItemModel t) {
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
  }
}
