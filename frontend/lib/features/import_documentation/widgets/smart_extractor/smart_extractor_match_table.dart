import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../idoc_ui.dart';

/// Full tab view for Cross-Audit radar comparing Commercial Invoice vs Bill of Lading.
class SmartExtractorMatchTable extends StatelessWidget {
  final bool isAuditing;
  final VoidCallback onRunAudit;
  final Map<String, dynamic>? auditResult;

  const SmartExtractorMatchTable({
    super.key,
    required this.isAuditing,
    required this.onRunAudit,
    required this.auditResult,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartExtractorAuditTriggerCard(
            isAuditing: isAuditing,
            onRunAudit: onRunAudit,
          ),
          if (auditResult != null) ...[
            const SizedBox(height: 16),
            SmartExtractorAuditScorecard(auditResult: auditResult!),
            const SizedBox(height: 16),
            SmartExtractorAuditMatrixTable(auditResult: auditResult!),
            const SizedBox(height: 16),
            SmartExtractorCorrectionNoticeCard(auditResult: auditResult!),
          ],
        ],
      ),
    );
  }
}

/// Card triggering cross-check audit comparing extracted Invoice against B/L.
class SmartExtractorAuditTriggerCard extends StatelessWidget {
  final bool isAuditing;
  final VoidCallback onRunAudit;

  const SmartExtractorAuditTriggerCard({
    super.key,
    required this.isAuditing,
    required this.onRunAudit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Card(
      elevation: 0,
      color: AppTheme.orangeLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.orange),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.security, color: AppTheme.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.smartExtractorAuditCardTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  Text(
                    l.smartExtractorAuditCardSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            IdocUi.fit(AppButton(
              label: l.smartExtractorRunAuditButton,
              icon: Icons.play_arrow,
              variant: AppButtonVariant.warning,
              isLoading: isAuditing,
              onPressed: isAuditing ? null : onRunAudit,
            )),
          ],
        ),
      ),
    );
  }
}

/// Scorecard summarizing audit score, compliance verdict, critical mismatches, and warnings.
class SmartExtractorAuditScorecard extends StatelessWidget {
  final Map<String, dynamic> auditResult;

  const SmartExtractorAuditScorecard({
    super.key,
    required this.auditResult,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final score =
        (auditResult['compliance_score'] as num?)?.toDouble() ?? 0.0;
    final verdict = auditResult['verdict'] as String? ?? 'COMPLIANT';
    final verdictAr = auditResult['verdict_ar'] as String? ?? '';
    final criticals =
        (auditResult['critical_errors'] as List<dynamic>?) ?? [];
    final warnings = (auditResult['warnings'] as List<dynamic>?) ?? [];

    Color badgeColor = AppTheme.emerald;
    AppSeverity severity = AppSeverity.success;
    String verdictDisplay = l.smartExtractorAuditCompliant;

    if (verdict == 'CRITICAL_MISMATCH') {
      badgeColor = AppTheme.crimson;
      severity = AppSeverity.danger;
      verdictDisplay = l.smartExtractorAuditCriticalMismatch;
    } else if (verdict == 'WARNINGS_DETECTED') {
      badgeColor = AppTheme.orange;
      severity = AppSeverity.warning;
      verdictDisplay = l.smartExtractorAuditWarningsDetected;
    }

    if (isArabic && verdictAr.isNotEmpty) {
      verdictDisplay = verdictAr;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AppStatusBadge(
                  label: l.smartExtractorMatchRatio(score),
                  severity: severity,
                  size: AppStatusBadgeSize.medium,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    verdictDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            if (criticals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.crimsonLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.crimsonBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: criticals
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel,
                                    color: AppTheme.crimson, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.crimson,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.orangeLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppTheme.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Audit matrix breakdown displaying discrepancy detection across fields.
class SmartExtractorAuditMatrixTable extends StatelessWidget {
  final Map<String, dynamic> auditResult;

  const SmartExtractorAuditMatrixTable({
    super.key,
    required this.auditResult,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final matrix =
        ((auditResult['audit_matrix']) as List<dynamic>?) ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.smartExtractorAuditMatrixTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      AppTheme.surfaceAltOf(context)),
                  columnSpacing: 14,
                  columns: [
                    DataColumn(label: Text(l.smartExtractorColCheckItem)),
                    DataColumn(label: Text(l.smartExtractorColInvoiceValue)),
                    DataColumn(label: Text(l.smartExtractorColBlValue)),
                    DataColumn(label: Text(l.smartExtractorColStatus)),
                    DataColumn(
                        label: Text(l.smartExtractorColDetailsGuidance)),
                  ],
                  rows: matrix.map((m) {
                    final item = m as Map<String, dynamic>;
                    final status = item['status'] ?? 'PASS';
                    AppSeverity statusSeverity = AppSeverity.success;
                    IconData statusIcon = Icons.check_circle;
                    String statusLabel = l.smartExtractorAuditPass;

                    if (status == 'CRITICAL') {
                      statusSeverity = AppSeverity.danger;
                      statusIcon = Icons.cancel;
                      statusLabel = l.smartExtractorAuditCritical;
                    } else if (status == 'WARNING') {
                      statusSeverity = AppSeverity.warning;
                      statusIcon = Icons.warning;
                      statusLabel = l.smartExtractorAuditWarning;
                    }

                    final checkTitle = isArabic
                        ? (item['title_ar'] ??
                            item['title_en'] ??
                            item['check_code'] ??
                            '')
                        : (item['title_en'] ??
                            item['title_ar'] ??
                            item['check_code'] ??
                            '');
                    final invVal = '${item['invoice_value'] ?? '-'}';
                    final blVal = '${item['bl_value'] ?? '-'}';
                    final details = isArabic
                        ? '${item['details_ar'] ?? item['details_en'] ?? '-'}'
                        : '${item['details_en'] ?? item['details_ar'] ?? '-'}';

                    final rowSummary =
                        '$checkTitle\t$invVal\t$blVal\t$statusLabel\t$details';

                    return DataRow(cells: [
                      DataCell(
                        CopyableTableCell(
                          value: checkTitle,
                          rowSummary: rowSummary,
                          child: Text(
                            checkTitle,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: invVal,
                          rowSummary: rowSummary,
                          child: Text(invVal),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: blVal,
                          rowSummary: rowSummary,
                          child: Text(blVal),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: statusLabel,
                          rowSummary: rowSummary,
                          child: AppStatusBadge(
                            label: statusLabel,
                            severity: statusSeverity,
                            icon: statusIcon,
                            size: AppStatusBadgeSize.small,
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: details,
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 280,
                            child: Text(
                              details,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Discrepancy correction notice card with one-click bilingual clipboard helpers.
class SmartExtractorCorrectionNoticeCard extends StatelessWidget {
  final Map<String, dynamic> auditResult;

  const SmartExtractorCorrectionNoticeCard({
    super.key,
    required this.auditResult,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final noticeEn =
        (auditResult['correction_notice_en'] ?? '').toString();
    final noticeAr =
        (auditResult['correction_notice_ar'] ?? '').toString();

    return Card(
      elevation: 0,
      color: AppTheme.surfaceAltOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: AppTheme.charcoal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.smartExtractorNoticeCardTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    l.smartExtractorNoticeCardSubtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IdocUi.fit(AppButton(
              label: l.smartExtractorCopyEnglishNoticeButton,
              icon: Icons.copy,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                CopyHelper.copy(
                  context,
                  noticeEn,
                  customMessage: l.smartExtractorNoticeEnCopied,
                );
              },
            )),
            const SizedBox(width: 8),
            IdocUi.fit(AppButton(
              label: l.smartExtractorCopyArabicNoticeButton,
              icon: Icons.copy,
              variant: AppButtonVariant.primary,
              onPressed: () {
                CopyHelper.copy(
                  context,
                  noticeAr,
                  customMessage: l.smartExtractorNoticeArCopied,
                );
              },
            )),
          ],
        ),
      ),
    );
  }
}
