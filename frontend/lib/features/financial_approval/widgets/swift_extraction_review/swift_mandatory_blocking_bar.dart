import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/financial_approval_model.dart';

class SwiftMandatoryBlockingBar extends StatelessWidget {
  final SwiftBatchModel batch;
  final bool isConfirmed;
  final bool isConfirming;
  final VoidCallback onCancel;
  final VoidCallback onConfirmReview;

  const SwiftMandatoryBlockingBar({
    super.key,
    required this.batch,
    required this.isConfirmed,
    required this.isConfirming,
    required this.onCancel,
    required this.onConfirmReview,
  });

  @override
  Widget build(BuildContext context) {
    final canConfirm = batch.allMandatoryValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canConfirm ? AppTheme.emeraldLight : AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canConfirm ? AppTheme.emerald : AppTheme.crimsonBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            canConfirm ? Icons.check_circle : Icons.warning_amber_rounded,
            color: canConfirm ? AppTheme.wcagEmerald : AppTheme.crimson,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canConfirm
                      ? context.l10n.faSwiftAllMandatoryOk
                      : context.l10n.faSwiftMatchingBlocked,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: canConfirm ? AppTheme.wcagEmerald : AppTheme.crimson,
                  ),
                ),
                if (!canConfirm) ...[
                  const SizedBox(height: 4),
                  Text(
                    batch.missingMandatoryFields.join(' • '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crimson,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          AppButton(
            label: context.l10n.faSwiftCancelReview,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onCancel,
          ),
          const SizedBox(width: 10),
          AppButton(
            label: isConfirmed
                ? context.l10n.faSwiftApprovedGoMatch
                : context.l10n.faSwiftConfirmAndMatch,
            variant: AppButtonVariant.primary,
            icon: isConfirmed ? Icons.check_circle : Icons.verified,
            isLoading: isConfirming,
            onPressed: (!canConfirm || isConfirming) ? null : onConfirmReview,
          ),
        ],
      ),
    );
  }
}
