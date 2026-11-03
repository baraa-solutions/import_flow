import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';

class SwiftReviewHeaderBanner extends StatelessWidget {
  final SwiftBatchModel batch;
  final bool isConfirmed;

  const SwiftReviewHeaderBanner({
    super.key,
    required this.batch,
    required this.isConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConfirmed
              ? [AppTheme.wcagEmerald, AppTheme.emerald]
              : [AppTheme.charcoal, AppTheme.cobalt],
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(
            isConfirmed ? Icons.verified_user : Icons.fact_check,
            color: AppTheme.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.faSwiftReviewTitle,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        batch.batchCode,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConfirmed
                      ? context.l10n.faSwiftReviewApprovedBanner
                      : context.l10n.faSwiftHumanReviewRequired,
                  style: TextStyle(
                    color: AppTheme.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConfirmed
                  ? AppTheme.wcagEmerald.withValues(alpha: 0.4)
                  : AppTheme.wcagOrange.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConfirmed ? AppTheme.emeraldBorder : AppTheme.orange,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.hourglass_top,
                  size: 13,
                  color: AppTheme.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isConfirmed
                      ? context.l10n.faSwiftHumanApproved
                      : context.l10n.faSwiftPendingReview,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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
