import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Summary card component for Screen 22: Invoice vs B/L Matcher.
///
/// Displays KPI metrics (Match score, safe certification status, critical/warning badges,
/// gross weight variance, packages count variance, container counts) and the extracted data cards.
class InvoiceBlMatcherSummaryCard extends StatelessWidget {
  final Map<String, dynamic> matchResult;
  final bool showPackingList;

  const InvoiceBlMatcherSummaryCard({
    super.key,
    required this.matchResult,
    this.showPackingList = false,
  });

  bool _isArabic(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ||
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final score = (matchResult['match_score_percentage'] as num?)?.toDouble() ?? 0.0;
    final isSafe = matchResult['is_safe_for_certification'] == true;
    final criticalCount = (matchResult['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final warningCount = (matchResult['warning_discrepancies_count'] as num?)?.toInt() ?? 0;

    final color = isSafe ? (warningCount > 0 ? AppTheme.orange : AppTheme.emerald) : AppTheme.crimson;

    final inv = matchResult['invoice_data'] is Map
        ? Map<String, dynamic>.from(matchResult['invoice_data'] as Map)
        : <String, dynamic>{};
    final pl = matchResult['packing_list_data'] is Map
        ? Map<String, dynamic>.from(matchResult['packing_list_data'] as Map)
        : <String, dynamic>{};
    final bl = matchResult['bl_data'] is Map
        ? Map<String, dynamic>.from(matchResult['bl_data'] as Map)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Overall Match Score & Certification Safety Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final mainInfo = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSafe ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                      color: color,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isSafe ? l.invoiceBlMatcherStatusSafeTitle : l.invoiceBlMatcherStatusCriticalTitle,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l.invoiceBlMatcherMatchScore(score),
                                style: const TextStyle(color: AppTheme.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isSafe
                              ? l.invoiceBlMatcherStatusSafeDesc
                              : l.invoiceBlMatcherStatusCriticalDesc(criticalCount),
                          style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final counters = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBadgeCounter(context, l.invoiceBlMatcherCriticalCount(criticalCount), criticalCount, AppTheme.crimson),
                  const SizedBox(width: 8),
                  _buildBadgeCounter(context, l.invoiceBlMatcherWarningCount(warningCount), warningCount, AppTheme.orange),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mainInfo,
                    const SizedBox(height: 12),
                    counters,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: mainInfo),
                  const SizedBox(width: 16),
                  counters,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // 2. KPI Variances Strip (Weight, Packages, Containers)
        _buildKpiVarianceStrip(context, inv, pl, bl),
        const SizedBox(height: 16),

        // 3. Extracted Fields Cards (Invoice, Packing List, B/L)
        _buildExtractedFieldsCards(context, inv, pl, bl),
      ],
    );
  }

  Widget _buildBadgeCounter(BuildContext context, String labelText, int count, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0 ? col.withValues(alpha: 0.15) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: count > 0 ? col : AppTheme.borderOf(context)),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: count > 0 ? col : AppTheme.textSecondaryOf(context),
        ),
      ),
    );
  }

  Widget _buildKpiVarianceStrip(
    BuildContext context,
    Map<String, dynamic> inv,
    Map<String, dynamic> pl,
    Map<String, dynamic> bl,
  ) {
    final l = context.l10n;

    // Weight Extraction & Variance
    final invWeight = inv['gross_weight_kg'] ?? inv['total_gross_weight'] ?? '—';
    final blWeight = bl['gross_weight_kg'] ?? bl['total_gross_weight'] ?? '—';
    final isWeightMatch = invWeight != '—' && blWeight != '—' && invWeight.toString() == blWeight.toString();

    // Packages Extraction & Variance
    final invPackages = inv['total_packages'] ?? pl['total_packages'] ?? inv['packages_count'] ?? '—';
    final blPackages = bl['total_packages'] ?? bl['packages_count'] ?? '—';
    final isPackagesMatch = invPackages != '—' && blPackages != '—' && invPackages.toString() == blPackages.toString();

    // Container count
    dynamic containersVal = bl['containers'] ?? bl['container_count'] ?? inv['containers'];
    String containersTxt = '—';
    if (containersVal is List) {
      containersTxt = '${containersVal.length}';
    } else if (containersVal != null && containersVal.toString().isNotEmpty) {
      containersTxt = containersVal.toString();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        final items = [
          _buildVarianceCard(
            context: context,
            title: l.smartExtractorFieldTotalGrossWeight,
            icon: Icons.scale_outlined,
            firstLabel: l.invoiceBlMatcherColInvoiceValue,
            firstValue: '$invWeight',
            secondLabel: l.invoiceBlMatcherColBlValue,
            secondValue: '$blWeight',
            isMatch: isWeightMatch,
          ),
          _buildVarianceCard(
            context: context,
            title: l.smartExtractorFieldPackagesCount,
            icon: Icons.all_inbox_outlined,
            firstLabel: l.invoiceBlMatcherColInvoiceValue,
            firstValue: '$invPackages',
            secondLabel: l.invoiceBlMatcherColBlValue,
            secondValue: '$blPackages',
            isMatch: isPackagesMatch,
          ),
          _buildVarianceCard(
            context: context,
            title: context.l10n.idocAContainers,
            icon: Icons.directions_boat_outlined,
            firstLabel: l.invoiceBlMatcherColBlValue,
            firstValue: containersTxt,
            secondLabel: '',
            secondValue: '',
            isMatch: containersTxt != '—',
          ),
        ];

        if (isNarrow) {
          return Column(
            children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
          );
        }

        return Row(
          children: items
              .map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w)))
              .toList(),
        );
      },
    );
  }

  Widget _buildVarianceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String firstLabel,
    required String firstValue,
    required String secondLabel,
    required String secondValue,
    required bool isMatch,
  }) {
    final statusColor = isMatch ? AppTheme.emerald : (secondValue.isEmpty ? AppTheme.cobalt : AppTheme.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (secondValue.isNotEmpty)
                Icon(
                  isMatch ? Icons.check_circle_outline : Icons.error_outline,
                  size: 14,
                  color: statusColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  firstLabel.isNotEmpty ? '$firstLabel: $firstValue' : firstValue,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (secondValue.isNotEmpty) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$secondLabel: $secondValue',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMatch ? AppTheme.emerald : AppTheme.crimson,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFieldsCards(
    BuildContext context,
    Map<String, dynamic> inv,
    Map<String, dynamic> pl,
    Map<String, dynamic> bl,
  ) {
    final l = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryWide = constraints.maxWidth > 1050;
        final hasPacking = pl.isNotEmpty || showPackingList;

        final invCard = _buildDataSummaryCard(
          context: context,
          title: l.invoiceBlMatcherExtractedInvoiceTitle,
          icon: Icons.receipt_long,
          color: AppTheme.cobalt,
          data: inv,
        );

        final plCard = hasPacking
            ? _buildDataSummaryCard(
                context: context,
                title: context.l10n.idocAExtractedPackingList,
                icon: Icons.inventory_2,
                color: AppTheme.wcagCobalt,
                data: pl,
              )
            : null;

        final blCard = _buildDataSummaryCard(
          context: context,
          title: l.invoiceBlMatcherExtractedBlTitle,
          icon: Icons.directions_boat,
          color: AppTheme.emerald,
          data: bl,
        );

        if (hasPacking) {
          if (isVeryWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: invCard),
                const SizedBox(width: 14),
                Expanded(child: plCard!),
                const SizedBox(width: 14),
                Expanded(child: blCard),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: invCard),
                    const SizedBox(width: 14),
                    Expanded(child: plCard!),
                  ],
                ),
                const SizedBox(height: 14),
                blCard,
              ],
            );
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: invCard),
            const SizedBox(width: 16),
            Expanded(child: blCard),
          ],
        );
      },
    );
  }

  Widget _buildDataSummaryCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> data,
  }) {
    final l = context.l10n;
    final isArabic = _isArabic(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                context.l10n.noData,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            )
          else
            ...data.entries.map((e) {
              if (e.key.startsWith('_') || e.value == null || e.value.toString().isEmpty) {
                return const SizedBox.shrink();
              }
              final displayLabel = _localizeDataKey(e.key, l, isArabic);
              final valStr = '${e.value}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 135,
                      child: Text(
                        '$displayLabel:',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: CopyableText(
                        valStr,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _localizeDataKey(String key, AppLocalizations l, bool isArabic) {
    switch (key) {
      case 'invoice_number':
      case 'invoice_no':
        return l.smartExtractorFieldInvoiceNo;
      case 'invoice_date':
        return l.smartExtractorFieldInvoiceDate;
      case 'acid_number':
      case 'acid':
        return l.smartExtractorFieldAcidNo;
      case 'importer_tax_id':
        return l.smartExtractorFieldImporterTaxId;
      case 'supplier_name':
      case 'supplier':
      case 'shipper':
        return l.smartExtractorFieldSupplier;
      case 'importer_name':
      case 'importer':
      case 'consignee':
        return l.smartExtractorFieldImporter;
      case 'incoterm':
      case 'incoterms':
        return l.smartExtractorFieldIncoterms;
      case 'total_amount':
      case 'total_value':
      case 'invoice_value':
        return l.smartExtractorFieldTotalAmount;
      case 'currency':
        return l.currency;
      case 'gross_weight_kg':
      case 'total_gross_weight':
        return l.smartExtractorFieldTotalGrossWeight;
      case 'bl_number':
      case 'bl_no':
        return l.smartExtractorFieldBlNo;
      case 'carrier_name':
      case 'carrier':
        return l.smartExtractorFieldCarrier;
      case 'pol':
      case 'port_of_loading':
        return l.smartExtractorFieldPol;
      case 'pod':
      case 'port_of_discharge':
        return l.smartExtractorFieldPod;
      case 'total_cbm':
        return l.smartExtractorFieldTotalCbm;
      case 'total_packages':
      case 'packages_count':
        return l.smartExtractorFieldPackagesCount;
      case 'containers':
        return l.idocAContainers;
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }
}
