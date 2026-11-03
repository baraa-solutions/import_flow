import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../services/local_process_sync_service.dart';

/// Database status cards (Dev DB and Prod DB) for ProductionSyncHubDialog
class SyncDbStatusCards extends StatelessWidget {
  final LocalProcessSyncService service;
  final LocalDbStats devStats;
  final LocalDbStats prodStats;

  const SyncDbStatusCards({
    super.key,
    required this.service,
    required this.devStats,
    required this.prodStats,
  });

  static Widget _buildDbCard({
    required BuildContext context,
    required String title,
    required String path,
    required LocalDbStats stats,
    required Color color,
    required IconData icon,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l.prodSyncCopyFieldTooltip,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => CopyHelper.copy(context, path, customMessage: l.prodSyncCopyFieldTooltip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                path.length > 18 ? '...${path.substring(path.length - 15)}' : path,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: AppTheme.charcoal,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.copy_rounded, size: 10, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stats.exists
                      ? '${l.prodSyncDbSizeLabel(stats.sizeKb)} • ${l.prodSyncDbLastModified(stats.mtime ?? "—")}'
                      : l.prodSyncDbNotFoundNotice,
                  style: TextStyle(
                    fontSize: 11,
                    color: stats.exists ? Colors.black87 : AppTheme.crimson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildDbCard(
              context: context,
              title: l.prodSyncDevDbTitle,
              path: service.devDbPath,
              stats: devStats,
              color: AppTheme.cobalt,
              icon: Icons.code_rounded,
              l: l,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDbCard(
              context: context,
              title: l.prodSyncProdDbTitle,
              path: service.prodDbPath,
              stats: prodStats,
              color: AppTheme.emerald,
              icon: Icons.desktop_windows_rounded,
              l: l,
            ),
          ),
        ],
      ),
    );
  }
}
