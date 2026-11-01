import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../services/local_process_sync_models.dart';
import '../services/production_sync_export_service.dart';

/// Tab 1: System Updates & Safety Backups list and controls.
class ProductionSyncBackupsTab extends StatelessWidget {
  final List<LocalBackupEntry> backups;
  final bool isRunning;
  final AppLocalizations l;
  final VoidCallback onCreateInstantBackup;
  final VoidCallback onRefresh;
  final ValueChanged<LocalBackupEntry> onRestoreBackup;

  const ProductionSyncBackupsTab({
    super.key,
    required this.backups,
    required this.isRunning,
    required this.l,
    required this.onCreateInstantBackup,
    required this.onRefresh,
    required this.onRestoreBackup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Info & Quick Backup Actions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.prodSyncSchemaEngineTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.prodSyncSchemaEngineDesc,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                label: Text(
                  l.prodSyncCreateInstantBackupBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: isRunning ? null : onCreateInstantBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Backups List View
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.prodSyncBackupsArchiveHeader(backups.length),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.table_view_rounded, size: 18, color: AppTheme.cobalt),
                          tooltip: l.prodSyncExportTsvBtn,
                          onPressed: () => ProductionSyncExportService.saveBackupsTsvToFile(
                            context: context,
                            backups: backups,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined, size: 18, color: AppTheme.emerald),
                          tooltip: l.prodSyncExportExcelBtn,
                          onPressed: () => ProductionSyncExportService.saveBackupsCsvToFile(
                            context: context,
                            backups: backups,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.grey),
                          onPressed: onRefresh,
                          tooltip: l.prodSyncRefreshListTooltip,
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: backups.isEmpty
                      ? Center(
                          child: Text(l.prodSyncNoBackupsInFolder),
                        )
                      : ListView.separated(
                          itemCount: backups.length,
                          separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (ctx, idx) {
                            final b = backups[idx];
                            final isAuto = b.filename.startsWith('auto_pre_upgrade');
                            final tagColor = isAuto
                                ? AppTheme.cobalt
                                : b.tag.contains('prod')
                                    ? AppTheme.emerald
                                    : AppTheme.orange;
                            final tagLabel = isAuto
                                ? l.prodSyncAutoPreUpgradeTag
                                : (b.tag.contains('prod')
                                    ? l.prodSyncTargetProdLabel
                                    : (b.tag.contains('dev') ? l.prodSyncTargetDevLabel : b.tag));

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isAuto ? Icons.auto_awesome_rounded : Icons.inventory_2_outlined,
                                color: tagColor,
                                size: 22,
                              ),
                              title: InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  b.filename,
                                  customMessage: l.prodSyncCopyFieldTooltip,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        b.filename,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                              subtitle: Text(
                                '${l.prodSyncBackupCreatedAt(b.mtime)} • ${l.prodSyncBackupSize(b.sizeKb)} • ${isAuto ? l.prodSyncAutoPreUpgradeTag : l.prodSyncManualBackupTag}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tagColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tagLabel,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tagColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                    tooltip: l.prodSyncCopyRowSummaryBtn,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () {
                                      final summary = '${b.filename} | ${b.sizeKb} KB | ${b.mtime} | ${b.tag}';
                                      CopyHelper.copy(context, summary, customMessage: l.prodSyncCopyRowSummarySuccess);
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.orange,
                                      side: const BorderSide(color: AppTheme.orange),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.restore_rounded, size: 14),
                                    label: Text(l.prodSyncRestoreActionBtn, style: const TextStyle(fontSize: 10.5)),
                                    onPressed: isRunning ? null : () => onRestoreBackup(b),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
