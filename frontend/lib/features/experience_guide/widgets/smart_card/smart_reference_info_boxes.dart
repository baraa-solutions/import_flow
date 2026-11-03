import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/smart_reference_card_model.dart';

Widget buildSectionBox({
  required String title,
  required IconData icon,
  required Color accentColor,
  required List<Widget> children,
  required bool isDark,
  double customWidth = 260,
}) {
  return Container(
    width: customWidth,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkSurface : const Color(0xFFF9FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Divider(height: 14, color: isDark ? AppTheme.darkBorder : null),
        ...children,
      ],
    ),
  );
}

Widget buildInfoRow(
  String label,
  String value, {
  bool isBadge = false,
  bool isHighlighted = false,
  bool isAlert = false,
  bool isDark = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 6,
          child: isBadge
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.flatCobalt),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: (isHighlighted || isAlert) ? FontWeight.bold : FontWeight.normal,
                    color: isAlert
                        ? AppTheme.flatCrimson
                        : (isHighlighted
                            ? AppTheme.flatEmerald
                            : (isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal)),
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
        ),
      ],
    ),
  );
}

Widget buildHsTabChip({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.flatCobalt : (isDark ? AppTheme.darkSurface : Colors.transparent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.flatCharcoal),
        ),
      ),
    ),
  );
}

class SmartReferenceProductBox extends StatelessWidget {
  final SmartReferenceCardModel card;
  final int selectedHsIndex;
  final ValueChanged<int> onSelectHsIndex;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceProductBox({
    super.key,
    required this.card,
    required this.selectedHsIndex,
    required this.onSelectHsIndex,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hsSummaries = card.hsSummaries;
    final hasMultiHs = hsSummaries.length > 1;

    final bool isAllSelected = selectedHsIndex == 0 || hsSummaries.isEmpty;
    final HsCodeSummaryModel? currentHsItem =
        (!isAllSelected && selectedHsIndex - 1 < hsSummaries.length) ? hsSummaries[selectedHsIndex - 1] : null;

    final String displayHsCode = currentHsItem != null
        ? currentHsItem.hsCode
        : (card.allHsCodes.isNotEmpty
            ? card.allHsCodes.join(', ')
            : (card.hsCode.isNotEmpty ? card.hsCode : (isArabic ? 'غير محدد' : 'Unspecified')));

    final String displayCategory = currentHsItem != null
        ? currentHsItem.description
        : (card.productCategory.isNotEmpty ? card.productCategory : (isArabic ? 'غير محدد' : 'Unspecified'));

    final double displayCbm = currentHsItem != null ? currentHsItem.cbm : card.totalCbm;
    final double displayGrossWeight = currentHsItem != null ? currentHsItem.grossWeightKg : card.totalGrossWeightKg;
    final double displayNetWeight = currentHsItem != null ? currentHsItem.netWeightKg : card.totalNetWeightKg;
    final int displayPackages = currentHsItem != null ? currentHsItem.packagesCount : card.packagesCount;
    final double displayQtyPcs = currentHsItem != null ? currentHsItem.quantityPcs : 0.0;

    return buildSectionBox(
      title: l10n.refCardProductSection,
      icon: Icons.inventory_2_outlined,
      accentColor: AppTheme.flatCobalt,
      isDark: isDark,
      customWidth: hasMultiHs ? 320 : 260,
      children: [
        if (hasMultiHs) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  buildHsTabChip(
                    label: isArabic ? 'الكل (${hsSummaries.length})' : 'All (${hsSummaries.length})',
                    isSelected: selectedHsIndex == 0,
                    onTap: () => onSelectHsIndex(0),
                    isDark: isDark,
                  ),
                  ...hsSummaries.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: buildHsTabChip(
                        label: item.hsCode,
                        isSelected: selectedHsIndex == idx,
                        onTap: () => onSelectHsIndex(idx),
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        buildInfoRow(
          l10n.refCardHsCodeLabel,
          displayHsCode,
          isBadge: true,
          isDark: isDark,
        ),
        buildInfoRow(
          l10n.refCardCategoryLabel,
          displayCategory,
          isDark: isDark,
        ),
        buildInfoRow(
          l10n.refCardTotalCbmLabel,
          '${displayCbm.toStringAsFixed(displayCbm % 1 == 0 ? 0 : 3)} ${isArabic ? 'متر مكعب' : 'm³'}',
          isDark: isDark,
        ),
        buildInfoRow(
          l10n.refCardGrossWeightLabel,
          '${displayGrossWeight.toStringAsFixed(displayGrossWeight % 1 == 0 ? 0 : 1)} ${isArabic ? 'كجم' : 'kg'}',
          isDark: isDark,
        ),
        if (displayNetWeight > 0)
          buildInfoRow(
            isArabic ? 'الوزن الصافي:' : 'Net Weight:',
            '${displayNetWeight.toStringAsFixed(displayNetWeight % 1 == 0 ? 0 : 1)} ${isArabic ? 'كجم' : 'kg'}',
            isDark: isDark,
          ),
        buildInfoRow(
          l10n.refCardPackagesCountLabel,
          '$displayPackages ${isArabic ? 'طرد' : 'pkgs'}',
          isDark: isDark,
        ),
        if (displayQtyPcs > 0)
          buildInfoRow(
            isArabic ? 'الكمية (قطع):' : 'Quantity (Pcs):',
            '${displayQtyPcs.toInt()} ${isArabic ? 'قطعة' : 'pcs'}',
            isDark: isDark,
          ),
      ],
    );
  }
}

class SmartReferenceRouteBox extends StatelessWidget {
  final SmartReferenceCardModel card;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceRouteBox({
    super.key,
    required this.card,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return buildSectionBox(
      title: l10n.refCardRouteSection,
      icon: Icons.directions_boat_outlined,
      accentColor: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
      isDark: isDark,
      customWidth: 260,
      children: [
        buildInfoRow(l10n.refCardPolLabel, card.originPort, isDark: isDark),
        buildInfoRow(l10n.refCardPodLabel, card.destinationPort, isHighlighted: true, isDark: isDark),
        buildInfoRow(
          l10n.refCardCarrierLabel,
          card.carrier.isNotEmpty ? card.carrier : (isArabic ? 'معتمد' : 'Approved'),
          isDark: isDark,
        ),
        buildInfoRow(
          isArabic ? 'الشروط التجارية:' : 'Incoterm:',
          (card.routeSummary['incoterm_code'] as String?) ?? 'FOB',
          isDark: isDark,
        ),
        buildInfoRow(
          isArabic ? 'نوع الشحن:' : 'Shipment Mode:',
          (card.routeSummary['shipment_mode'] as String?) ?? 'Sea FCL',
          isDark: isDark,
        ),
      ],
    );
  }
}

class SmartReferenceDatesBox extends StatelessWidget {
  final SmartReferenceCardModel card;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceDatesBox({
    super.key,
    required this.card,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return buildSectionBox(
      title: l10n.refCardDatesSection,
      icon: Icons.access_time_rounded,
      accentColor: AppTheme.flatOrange,
      isDark: isDark,
      customWidth: 260,
      children: [
        buildInfoRow(
          l10n.refCardFreeDaysLabel,
          '${card.freeDays} ${isArabic ? 'يوماً' : 'days'}',
          isDark: isDark,
        ),
        buildInfoRow(
          isArabic ? 'تاريخ الوصول:' : 'Expected ETA:',
          (card.criticalDates['required_eta'] as String?) ?? (isArabic ? 'قيد التحديد' : 'TBD'),
          isDark: isDark,
        ),
        buildInfoRow(
          isArabic ? 'جاهزية البضاعة:' : 'Cargo Ready Date:',
          (card.criticalDates['cargo_ready_date'] as String?) ?? (isArabic ? 'جاهزة' : 'Ready'),
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.flatEmerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isArabic
                ? '${card.freeDays} يوماً فترة سماح للحاويات — فترة آمنة'
                : '${card.freeDays} container free days — Safe window',
            style: const TextStyle(fontSize: 11, color: AppTheme.flatEmerald, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class SmartReferenceDocsBox extends StatelessWidget {
  final SmartReferenceCardModel card;
  final String? acidNum;
  final String? form4Num;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceDocsBox({
    super.key,
    required this.card,
    this.acidNum,
    this.form4Num,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return buildSectionBox(
      title: l10n.refCardDocsSection,
      icon: Icons.verified_user_outlined,
      accentColor: card.isDocsComplete ? AppTheme.flatEmerald : AppTheme.flatCrimson,
      isDark: isDark,
      customWidth: 260,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: card.isDocsComplete
                ? AppTheme.flatEmerald.withValues(alpha: 0.12)
                : AppTheme.flatCrimson.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                card.isDocsComplete ? Icons.check_circle : Icons.error_outline,
                size: 14,
                color: card.isDocsComplete ? AppTheme.flatEmerald : AppTheme.flatCrimson,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  card.isDocsComplete ? l10n.refCardDocsCompleteBadge : l10n.refCardDocsPendingBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: card.isDocsComplete ? AppTheme.flatEmerald : AppTheme.flatCrimson,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        buildInfoRow(
          isArabic ? 'شهادة المنشأ الأصلية:' : 'Original COO:',
          card.hasCooAttached ? l10n.refCardCooAttachedBadge : l10n.refCardCooMissingBadge,
          isAlert: !card.hasCooAttached && card.isCooRequired,
          isDark: isDark,
        ),
        if (acidNum != null && acidNum!.isNotEmpty) ...[
          const SizedBox(height: 4),
          buildInfoRow(
            isArabic ? 'رقم نافذة ACID:' : 'ACID Number:',
            acidNum!,
            isBadge: true,
            isDark: isDark,
          ),
        ],
        if (form4Num != null && form4Num!.isNotEmpty) ...[
          const SizedBox(height: 4),
          buildInfoRow(
            isArabic ? 'نموذج 4 بنكي:' : 'Bank Form 4:',
            form4Num!,
            isDark: isDark,
          ),
        ],
        if (card.pendingDocuments.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${isArabic ? 'مستندات مطلوبة:' : 'Pending Docs:'} ${card.pendingDocuments.take(2).join(", ")}',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
          ),
        ],
      ],
    );
  }
}

class SmartReferenceCostBox extends StatelessWidget {
  final SmartReferenceCardModel card;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceCostBox({
    super.key,
    required this.card,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return buildSectionBox(
      title: l10n.refCardCostSection,
      icon: Icons.monetization_on_outlined,
      accentColor: card.varianceAmount <= 0 ? AppTheme.flatEmerald : AppTheme.flatCrimson,
      isDark: isDark,
      customWidth: 260,
      children: [
        buildInfoRow(l10n.refCardEstCostLabel, '${card.estimatedCost} ${card.currency}', isDark: isDark),
        buildInfoRow(l10n.refCardActualCostLabel, '${card.actualCost} ${card.currency}', isDark: isDark),
        buildInfoRow(
          l10n.refCardVarianceLabel,
          '${card.varianceAmount} (${card.variancePercentage}%)',
          isAlert: card.varianceAmount > 0,
          isHighlighted: card.varianceAmount <= 0,
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        Text(
          card.varianceAmount <= 0
              ? (isArabic ? 'ضمن الميزانية التقديرية' : 'Within Estimated Budget')
              : (isArabic ? 'تجاوز الميزانية التقديرية' : 'Over Budget'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: card.varianceAmount <= 0 ? AppTheme.flatEmerald : AppTheme.flatCrimson,
          ),
        ),
      ],
    );
  }
}
