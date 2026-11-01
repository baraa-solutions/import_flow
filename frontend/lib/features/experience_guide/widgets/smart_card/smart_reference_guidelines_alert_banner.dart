import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/guide_entry_model.dart';

class SmartReferenceGuidelinesAlertBanner extends StatelessWidget {
  final List<GuideEntryModel> matchedGuideEntries;

  const SmartReferenceGuidelinesAlertBanner({
    super.key,
    required this.matchedGuideEntries,
  });

  @override
  Widget build(BuildContext context) {
    if (matchedGuideEntries.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final hasCritical = matchedGuideEntries.any((e) => e.severity == 'critical');
    final accentColor = hasCritical ? AppTheme.flatCrimson : AppTheme.flatOrange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCritical ? Icons.warning_amber_rounded : Icons.info_outline,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasCritical ? l10n.guideCriticalAlertTitle : l10n.guideWarningAlertTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...matchedGuideEntries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: e.severity == 'critical'
                          ? AppTheme.flatCrimson.withValues(alpha: 0.25)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (e.severity == 'critical' ? AppTheme.flatCrimson : AppTheme.flatOrange)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              e.severity.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: e.severity == 'critical' ? AppTheme.flatCrimson : AppTheme.flatOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.localizedTitle(l10n),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        e.localizedContent(l10n),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
