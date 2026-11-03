import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class Declaration46VarianceReasonCard extends StatelessWidget {
  final bool over10;
  final TextEditingController controller;

  const Declaration46VarianceReasonCard({
    super.key,
    required this.over10,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: over10 ? AppTheme.crimson.withValues(alpha: 0.05) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: over10 ? AppTheme.crimson.withValues(alpha: 0.6) : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: over10 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                over10 ? Icons.warning_amber_rounded : Icons.edit_note_outlined,
                color: over10 ? AppTheme.crimson : AppTheme.cobalt,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.form46VarianceReasonLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: over10 ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              if (over10) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.isArabic ? 'إلزامي (>10%)' : 'Mandatory (>10%)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('dutyVarianceReasonField'),
            controller: controller,
            maxLines: 2,
            validator: (val) {
              if (over10 && (val == null || val.trim().isEmpty)) {
                return l.form46VarianceReasonRequired;
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: l.form46VarianceReasonHint,
              border: const OutlineInputBorder(),
              isDense: true,
              fillColor: Theme.of(context).cardColor,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}
