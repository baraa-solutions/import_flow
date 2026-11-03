import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/display_name_resolver.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../import_files/models/import_file_model.dart';
import '../../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../../models/po_reconciliation_session_model.dart';
import '../../idoc_ui.dart';

/// Modal dialog displaying full details of a saved PO Reconciliation session.
class ReconciliationSessionDetailsModal {
  static Widget buildSessionStatusBadge(BuildContext context, String status) {
    final l = context.l10n;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'FULLY_MATCHED':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.success);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.success);
        label = l.poRecMatchStatusMatched;
        break;
      case 'ACCEPTED_WITH_WARNINGS':
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
        label = l.poRecMatchStatusWarning;
        break;
      case 'CRITICAL_DISCREPANCY':
      default:
        bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
        fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
        label = l.poRecMatchStatusCritical;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  static Widget _buildExtractedPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    const pillBg = AppTheme.white;
    final pillBorder = AppTheme.borderOf(context);
    final labelColor = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pillBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: labelColor), overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    const cardBg = AppTheme.white;
    final labelColor = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: labelColor), overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required ValueChanged<POReconciliationSessionModel> onLoadIntoEditor,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
    final shipmentTitle = rawFileCode.isNotEmpty
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
        : '';
    final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
        ? '$shipmentTitle ($rawFileCode)'
        : (rawFileCode.isNotEmpty ? rawFileCode : '—');

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_rounded, color: AppTheme.cobalt, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    l.poRecHistoryDetailsModalTitle(sess.sessionCode),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              buildSessionStatusBadge(context, sess.overallStatus),
            ],
          ),
          content: SizedBox(
            width: 750,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(context)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pills = [
                          _buildExtractedPill(
                            context,
                            label: l.poRecImportFileLabel,
                            value: fileDisplay,
                            icon: Icons.folder_rounded,
                          ),
                          _buildExtractedPill(
                            context,
                            label: l.poRecFinalInvoiceNoLabel,
                            value: sess.finalInvoiceNumber ?? '—',
                            icon: Icons.receipt_long,
                          ),
                          _buildExtractedPill(
                            context,
                            label: l.poRecFinalPackingListNoLabel,
                            value: sess.finalPackingListNumber ?? '—',
                            icon: Icons.inventory_2,
                          ),
                          _buildExtractedPill(
                            context,
                            label: l.poRecExtractedAcid,
                            value: sess.acidNumber ?? '—',
                            icon: Icons.tag,
                          ),
                        ];
                        if (constraints.maxWidth >= 750) {
                          return Row(
                            children: pills
                                .map((p) =>
                                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: p)))
                                .toList(),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pills
                              .map((p) => SizedBox(
                                    width: constraints.maxWidth > 400
                                        ? (constraints.maxWidth - 8) / 2
                                        : constraints.maxWidth,
                                    child: p,
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final mCards = [
                        _buildSummaryCard(
                          context,
                          title: l.poRecKpiTotalInvoice,
                          value: '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
                          icon: Icons.monetization_on,
                          color: AppTheme.cobalt,
                        ),
                        _buildSummaryCard(
                          context,
                          title: l.poRecKpiTotalPackages,
                          value: '${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                          icon: Icons.all_inbox,
                          color: AppTheme.charcoal,
                        ),
                        _buildSummaryCard(
                          context,
                          title: l.poRecKpiTotalGrossWeight,
                          value: '${PoPackingMatcher.formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit}',
                          icon: Icons.scale,
                          color: AppTheme.orange,
                        ),
                        _buildSummaryCard(
                          context,
                          title: l.poRecKpiTotalCbm,
                          value: '${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                          icon: Icons.view_in_ar,
                          color: AppTheme.emerald,
                        ),
                      ];
                      if (constraints.maxWidth >= 750) {
                        return Row(
                          children: mCards
                              .map((c) =>
                                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c)))
                              .toList(),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mCards
                            .map((c) => SizedBox(
                                  width: constraints.maxWidth > 400
                                      ? (constraints.maxWidth - 8) / 2
                                      : constraints.maxWidth,
                                  child: c,
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (sess.reconciledInvoiceItems != null && sess.reconciledInvoiceItems!.isNotEmpty) ...[
                    Text(
                      l.poRecHistoryDetailsCertifiedItemsTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: AppTheme.borderOf(context)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColItemCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColDescription,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColFinalQty,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColFinalUnitPrice,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColFinalTotal,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                          ],
                        ),
                        ...sess.reconciledInvoiceItems!.map((itm) {
                          final map = itm as Map<String, dynamic>;
                          final qty = (map['final_quantity'] as num?)?.toDouble() ?? 1.0;
                          final price = (map['final_unit_price'] as num?)?.toDouble() ?? 0.0;
                          final total = (map['total_amount'] as num?)?.toDouble() ?? (qty * price);
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  map['item_code']?.toString() ?? '—',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  map['description']?.toString() ?? '—',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText('$qty', isSelectable: false, style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText('$price', isSelectable: false, style: const TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  '${total.toStringAsFixed(2)} ${sess.currency}',
                                  isSelectable: false,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                  if (sess.reconciledPackingItems != null && sess.reconciledPackingItems!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l.poRecHistoryDetailsCertifiedPackingTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: AppTheme.borderOf(context)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColItemCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColPackageType,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColFinalPackagesCount,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColGrossWeight,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColNetWeight,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(l.poRecColCbm,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                          ],
                        ),
                        ...sess.reconciledPackingItems!.map((itm) {
                          final map = itm as Map<String, dynamic>;
                          final pkgs = (map['final_packages_count'] as num?)?.toDouble() ?? 0.0;
                          final gross = (map['final_gross_weight_kg'] as num?)?.toDouble() ?? 0.0;
                          final net = (map['final_net_weight_kg'] as num?)?.toDouble() ?? 0.0;
                          final cbm = (map['final_cbm'] as num?)?.toDouble() ?? 0.0;
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  map['item_code']?.toString() ?? '—',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  map['package_type']?.toString() ?? '—',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  '${pkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  '${PoPackingMatcher.formatWeight(gross)} ${l.poRecKgUnit}',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  '${PoPackingMatcher.formatWeight(net)} ${l.poRecKgUnit}',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: CopyableText(
                                  '${cbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                                  isSelectable: false,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.close,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(dialogCtx),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecHistoryLoadInEditorButton,
              icon: Icons.edit_note_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.pop(dialogCtx);
                onLoadIntoEditor(sess);
              },
            )),
          ],
        ),
      ),
    );
  }
}
