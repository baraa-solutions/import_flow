import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class ArchiveDocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final IconData icon;
  final Color color;
  final String defaultTitle;
  final bool isMandatoryCore;

  const ArchiveDocumentCard({
    super.key,
    required this.doc,
    required this.icon,
    required this.color,
    required this.defaultTitle,
    this.isMandatoryCore = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = (isAr ? doc['title_ar'] : doc['title_en'])?.toString() ?? doc['title_ar']?.toString() ?? defaultTitle;
    final isAvail = doc['is_available'] as bool? ?? false;
    final isWaived = doc['is_waived'] as bool? ?? false;
    final waiveReason = doc['waive_reason']?.toString();
    final legalNote = doc['legal_requirement_note']?.toString();
    final status = doc['status']?.toString() ?? 'NOT_STARTED';
    final refNo = doc['document_reference']?.toString() ?? 'N/A';
    final details = doc['details'] as Map<String, dynamic>? ?? {};
    final discrepancies = doc['discrepancies'] as List<dynamic>? ?? [];

    Color badgeColor;
    String badgeText;
    if (isWaived || status == 'WAIVED') {
      badgeColor = AppTheme.emerald;
      badgeText = l10n.docStatusWaived;
    } else if (status == 'APPROVED') {
      badgeColor = AppTheme.emerald;
      badgeText = l10n.docStatusApproved;
    } else if (status == 'MODIFICATIONS_REQUESTED') {
      badgeColor = AppTheme.crimson;
      badgeText = l10n.docStatusModificationsRequested;
    } else if (status == 'REVIEW_PENDING') {
      badgeColor = AppTheme.orange;
      badgeText = l10n.docStatusReviewPending;
    } else {
      badgeColor = AppTheme.textMutedOf(context);
      badgeText = l10n.docStatusNotStarted;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: discrepancies.isNotEmpty || isAvail || isWaived,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMandatoryCore
                        ? AppTheme.severityBackgroundOf(context, AppSeverity.danger)
                        : AppTheme.severityBackgroundOf(context, AppSeverity.info),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isMandatoryCore ? AppTheme.crimsonBorder : AppTheme.cobaltBorder),
                  ),
                  child: Text(
                    isMandatoryCore ? l10n.docMandatoryCore : l10n.docConditional,
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(11.0),
                      fontWeight: FontWeight.bold,
                      color: isMandatoryCore
                          ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
                          : AppTheme.severityForegroundOf(context, AppSeverity.info),
                    ),
                  ),
                ),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (refNo.isNotEmpty && refNo != 'N/A')
                  InkWell(
                    onTap: () => CopyHelper.copy(context, refNo),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.docReferenceLabel(refNo),
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_rounded, size: 11, color: AppTheme.textSecondaryOf(context)),
                        ],
                      ),
                    ),
                  )
                else
                  Text(l10n.docReferenceLabel(refNo),
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(11.0),
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (legalNote != null && legalNote.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isWaived
                          ? AppTheme.severityBackgroundOf(context, AppSeverity.success)
                          : AppTheme.severityBackgroundOf(context, AppSeverity.info),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isWaived ? AppTheme.emeraldBorder : AppTheme.cobaltBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isWaived ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: isWaived
                              ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                              : AppTheme.severityForegroundOf(context, AppSeverity.info),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            legalNote,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isWaived
                                  ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                                  : AppTheme.severityForegroundOf(context, AppSeverity.info),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (details.isNotEmpty) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: details.entries.map((e) {
                      final entryText = '${e.key}: ${e.value}';
                      return InkWell(
                        onTap: () => CopyHelper.copy(context, entryText, customMessage: l10n.centralDocsCopyDetailSuccess),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderOf(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(entryText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded, size: 11, color: AppTheme.textMutedOf(context)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (discrepancies.isNotEmpty) ...[
                  Text(
                    l10n.docModificationsRequestedTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.crimson),
                  ),
                  const SizedBox(height: 6),
                  ...discrepancies.map((d) {
                    final issueText = '${d['field']}: ${d['issue']} ➔ ${d['rectification']}';
                    return InkWell(
                      onTap: () => CopyHelper.copy(context, issueText, customMessage: l10n.centralDocsCopyDiscrepancySuccess),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.crimsonBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_left, color: AppTheme.crimson, size: 18),
                            Expanded(
                              child: Text(
                                issueText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.severityForegroundOf(context, AppSeverity.danger),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded, size: 13, color: AppTheme.crimson),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (isWaived) ...[
                  Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          waiveReason ?? l10n.docWaivedDefaultDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.severityForegroundOf(context, AppSeverity.success),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isAvail) ...[
                  Row(
                    children: [
                      const Icon(Icons.check, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.docNoDiscrepanciesDesc,
                          style: TextStyle(fontSize: 12, color: AppTheme.severityForegroundOf(context, AppSeverity.success)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
