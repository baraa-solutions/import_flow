import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../services/local_process_sync_models.dart';

/// Card showing status and metadata of a database (Dev or Prod).
class ProductionSyncDbCard extends StatelessWidget {
  final String title;
  final String path;
  final LocalDbStats stats;
  final Color color;
  final IconData icon;
  final AppLocalizations l;

  const ProductionSyncDbCard({
    super.key,
    required this.title,
    required this.path,
    required this.stats,
    required this.color,
    required this.icon,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => CopyHelper.copy(context, path, customMessage: l.prodSyncCopyFieldTooltip),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            path,
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded, size: 10, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
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
}
