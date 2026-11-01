import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../models/import_documentation_model.dart';
import '../bank_form4_localizer.dart';

/// Overall readiness badge for Pre-Form 4 pipeline
class BankForm4ReadinessBadge extends StatelessWidget {
  final BankingDocumentModel? doc;

  const BankForm4ReadinessBadge({
    super.key,
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc;
    if (d == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.textMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.3)),
        ),
        child: Text(
          BankForm4Localizer.readinessNotStarted(context),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
        ),
      );
    }

    if (d.canSubmitForm4) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.wcagEmerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.wcagEmerald),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 14, color: AppTheme.wcagEmerald),
            const SizedBox(width: 4),
            Text(
              BankForm4Localizer.readinessReady100(context),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.wcagEmerald),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pending_actions, size: 14, color: AppTheme.orange),
          const SizedBox(width: 4),
          Text(
            BankForm4Localizer.readinessPendingBlockers(context, d.blockers.length),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.orange),
          ),
        ],
      ),
    );
  }
}
