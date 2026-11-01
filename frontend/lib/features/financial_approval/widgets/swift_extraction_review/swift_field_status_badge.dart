import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/financial_approval_model.dart';

class SwiftFieldStatusBadge extends StatelessWidget {
  final SwiftFieldModel field;

  const SwiftFieldStatusBadge({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    if (field.isMandatory && field.isEmpty) {
      return Tooltip(
        message: context.l10n.faSwiftEmptyMandatoryBlocks,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.crimsonLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            context.l10n.faSwiftStatusEmpty,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppTheme.crimson,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (field.confidenceScore >= 0.8 && !field.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.emeraldLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.l10n.faSwiftStatusTrusted,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.emerald,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (!field.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.orangeLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.l10n.faSwiftStatusReviewed,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.cloudWhite,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.l10n.faSwiftOptional,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }
}
