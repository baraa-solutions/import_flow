import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/original_documents_collection_model.dart';

/// Header widget for Original Documents Collection Hub.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsHeader extends StatelessWidget {
  final OriginalDocumentsCollectionSessionModel? existingSession;

  const OriginalDocsHeader({
    super.key,
    this.existingSession,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = existingSession;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.markunread_mailbox_outlined,
                color: AppTheme.cobalt,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.originalDocsHubTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.originalDocsHubSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (session != null)
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  session.collectionCode,
                  customMessage: l.originalDocsCopyRowSuccess,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emerald),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.emerald,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.savedSessionBadge(session.collectionCode),
                        style: const TextStyle(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, size: 14, color: AppTheme.emerald),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
