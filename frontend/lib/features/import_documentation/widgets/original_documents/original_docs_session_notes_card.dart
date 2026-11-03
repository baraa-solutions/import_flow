import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Notes and discrepancy override reason card for Original Documents Collection.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsSessionNotesCard extends StatelessWidget {
  final TextEditingController notesController;
  final TextEditingController overrideReasonController;

  const OriginalDocsSessionNotesCard({
    super.key,
    required this.notesController,
    required this.overrideReasonController,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.sessionNotesLabel,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                  tooltip: l.originalDocsCopyRowSuccess,
                  onPressed: () {
                    final text = notesController.text.trim();
                    if (text.isNotEmpty) {
                      CopyHelper.copy(
                        context,
                        text,
                        customMessage: l.originalDocsCopyRowSuccess,
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: overrideReasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.overrideReasonLabel,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppTheme.cobalt),
                  tooltip: l.originalDocsCopyRowSuccess,
                  onPressed: () {
                    final text = overrideReasonController.text.trim();
                    if (text.isNotEmpty) {
                      CopyHelper.copy(
                        context,
                        text,
                        customMessage: l.originalDocsCopyRowSuccess,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
