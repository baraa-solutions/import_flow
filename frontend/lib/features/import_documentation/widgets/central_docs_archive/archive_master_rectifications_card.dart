import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../idoc_ui.dart';

class ArchiveMasterRectificationsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<dynamic> checklist;
  final int critical;
  final int warning;

  const ArchiveMasterRectificationsCard({
    super.key,
    required this.data,
    required this.checklist,
    required this.critical,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emailText = data['supplier_email_rectification_text']?.toString() ?? '';
    final waText = data['supplier_whatsapp_rectification_text']?.toString() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: critical > 0
              ? AppTheme.crimson.withValues(alpha: 0.5)
              : (warning > 0 ? AppTheme.orange.withValues(alpha: 0.5) : AppTheme.emerald.withValues(alpha: 0.5)),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      critical > 0 ? Icons.gavel : (warning > 0 ? Icons.warning_amber : Icons.verified),
                      color: critical > 0 ? AppTheme.crimson : (warning > 0 ? AppTheme.orange : AppTheme.emerald),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.masterRectificationsHeader,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    IdocUi.fit(AppButton(
                      label: l10n.copySupplierEmailBtn,
                      icon: Icons.email,
                      variant: AppButtonVariant.primary,
                      onPressed: () => CopyHelper.copy(context, emailText, customMessage: l10n.copySupplierEmailSuccess),
                    )),
                    IdocUi.fit(AppButton(
                      label: l10n.copyWhatsAppBtn,
                      icon: Icons.chat,
                      variant: AppButtonVariant.success,
                      onPressed: () => CopyHelper.copy(context, waText, customMessage: l10n.copyWhatsAppSuccess),
                    )),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (checklist.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.emeraldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.noDiscrepanciesSuccessMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: checklist.map((item) {
                  final sev = item['severity']?.toString() ?? 'WARNING';
                  final isCrit = sev == 'CRITICAL';
                  final docField = '${item['document']} - [${item['field']}]';
                  final issue = item['issue'] ?? '';
                  final rect = item['rectification'] ?? '';
                  final copyContent = '$docField: $issue ➔ $rect';

                  return InkWell(
                    onTap: () => CopyHelper.copy(context, copyContent),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCrit
                            ? AppTheme.severityBackgroundOf(context, AppSeverity.danger)
                            : AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCrit ? AppTheme.crimsonBorder : AppTheme.orange),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(isCrit ? Icons.error : Icons.warning_amber,
                              color: isCrit ? AppTheme.crimson : AppTheme.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        docField,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCrit ? AppTheme.crimson : AppTheme.charcoal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCrit
                                            ? AppTheme.severityBackgroundOf(context, AppSeverity.danger)
                                            : AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCrit ? l10n.severityCritical : l10n.severityWarning,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isCrit
                                              ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
                                              : AppTheme.charcoal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.copy_rounded, size: 14, color: isCrit ? AppTheme.crimson : AppTheme.orange),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(l10n.discrepancyIssueLabel(issue),
                                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context))),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.discrepancyRectificationLabel(rect),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCrit
                                        ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
                                        : AppTheme.charcoal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
