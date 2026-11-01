import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

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
