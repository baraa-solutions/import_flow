import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../services/local_process_sync_service.dart';
import '../../services/production_sync_export_service.dart';

/// Tab 2: Backups Archive for ProductionSyncHubDialog
class SyncBackupsTab extends StatelessWidget {
  final List<LocalBackupEntry> backups;
  final LocalDbStats devStats;
  final LocalDbStats prodStats;
  final SyncDiffSummary? diffSummary;
  final bool isRunning;
  final VoidCallback onCreateManualBackup;
  final ValueChanged<LocalBackupEntry> onRestoreBackup;

  const SyncBackupsTab({
    super.key,
    required this.backups,
    required this.devStats,
    required this.prodStats,
    required this.diffSummary,
    required this.isRunning,
    required this.onCreateManualBackup,
    required this.onRestoreBackup,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.prodSyncBackupsArchiveHeader(backups.length),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                    ),
                    Text(
                      l.prodSyncBackupsDialogSub,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: Text(l.prodSyncCopyDossierBtn, style: const TextStyle(fontSize: 11.5)),
                    onPressed: backups.isEmpty
                        ? null
                        : () => ProductionSyncExportService.copyDossierToClipboard(
                              context: context,
                              devStats: devStats,
                              prodStats: prodStats,
                              diffSummary: diffSummary,
                              backups: backups,
                            ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                    label: Text(l.prodSyncCreateInstantBackupBtn, style: const TextStyle(fontSize: 11.5)),
                    onPressed: isRunning ? null : onCreateManualBackup,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: backups.isEmpty
                ? Center(
                    child: Text(l.prodSyncNoBackupsDialogSub),
                  )
                : ListView.separated(
                    itemCount: backups.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, idx) {
                      final b = backups[idx];
                      final tagColor = b.tag.contains('prod')
                          ? AppTheme.emerald
                          : b.tag.contains('dev')
                              ? AppTheme.cobalt
                              : AppTheme.orange;
                      final tagText = b.tag.contains('prod')
                          ? l.prodSyncTargetProdLabel
                          : (b.tag.contains('dev') ? l.prodSyncTargetDevLabel : b.tag);

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 20),
                        title: Row(
                          children: [
                            Tooltip(
                              message: l.prodSyncCopyFieldTooltip,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => CopyHelper.copy(
                                  context,
                                  b.filename,
                                  customMessage: l.prodSyncCopyFieldTooltip,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        b.filename,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${l.prodSyncBackupCreatedAt(b.mtime)} • ${l.prodSyncBackupSize(b.sizeKb)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: l.prodSyncCopyRowSummaryBtn,
                              child: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                onPressed: () {
                                  final summary = '${b.filename} | $tagText | ${b.sizeKb} KB | ${b.mtime}';
                                  CopyHelper.copy(context, summary, customMessage: l.prodSyncCopyRowSummarySuccess);
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tagText,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tagColor),
                              ),
                            ),
                            const SizedBox(width: 8),
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
    );
  }
}
