import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/smart_reference_card_model.dart';
import '../providers/experience_guide_provider.dart';
import 'add_guide_entry_dialog.dart';
import 'experience_guide_management_dialog.dart';

class SmartShipmentReferenceCard extends ConsumerStatefulWidget {
  final int importFileId;
  final String? initialHsCode;
  final String? initialCategory;
  final String? initialPod;
  final String? initialSupplier;
  final String? initialCarrier;
  final VoidCallback? onGuidelineAdded;
  final List<PurchaseOrderModel>? linkedPOs;
  final ImportFileModel? file;

  const SmartShipmentReferenceCard({
    super.key,
    required this.importFileId,
    this.initialHsCode,
    this.initialCategory,
    this.initialPod,
    this.initialSupplier,
    this.initialCarrier,
    this.onGuidelineAdded,
    this.linkedPOs,
    this.file,
  });

  @override
  ConsumerState<SmartShipmentReferenceCard> createState() => _SmartShipmentReferenceCardState();
}

class _SmartShipmentReferenceCardState extends ConsumerState<SmartShipmentReferenceCard> {
  int _selectedHsIndex = 0; // 0 = All, 1..N = specific HS Code index

  void _copyCardData(BuildContext context, SmartReferenceCardModel card, {required bool isArabic}) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.smartReferenceCardTitle} ===');
    buffer.writeln('${isArabic ? "كود الملف" : "File Code"}: ${card.importFileCode}');
    if (card.customFileNumber != null && card.customFileNumber!.isNotEmpty) {
      buffer.writeln('${isArabic ? "الرقم المخصص" : "Custom File No"}: ${card.customFileNumber}');
    }
    buffer.writeln('\n[${l10n.refCardProductSection}]');
    buffer.writeln('${isArabic ? "بند التعريفة" : "HS Code"}: ${card.hsCode}');
    buffer.writeln('${isArabic ? "تصنيف الصنف" : "Category"}: ${card.productCategory}');
    buffer.writeln('${isArabic ? "إجمالي الحجم" : "Total Volume"}: ${card.totalCbm} ${isArabic ? "متر مكعب" : "m³"}');
    buffer.writeln('${isArabic ? "الوزن الإجمالي" : "Gross Weight"}: ${card.totalGrossWeightKg} ${isArabic ? "كجم" : "kg"}');
    buffer.writeln('${isArabic ? "عدد الطرود" : "Packages Count"}: ${card.packagesCount} ${isArabic ? "طرد" : "pkgs"}');

    buffer.writeln('\n[${l10n.refCardRouteSection}]');
    buffer.writeln('${isArabic ? "ميناء الشحن" : "POL"}: ${card.originPort}');
    buffer.writeln('${isArabic ? "ميناء الوصول" : "POD"}: ${card.destinationPort}');
    buffer.writeln('${isArabic ? "الناقل والخط الملاحي" : "Carrier"}: ${card.carrier}');

    buffer.writeln('\n[${l10n.refCardDatesSection}]');
    buffer.writeln('${isArabic ? "فترة سماح الحاويات" : "Free Days"}: ${card.freeDays} ${isArabic ? "يوم" : "days"}');
    buffer.writeln('${isArabic ? "حالة السماح" : "Free Time Status"}: ${card.freeTimeStatus}');

    buffer.writeln('\n[${l10n.refCardDocsSection}]');
    buffer.writeln('${isArabic ? "حالة الجاهزية" : "Docs Status"}: ${card.isDocsComplete ? (isArabic ? "مكتملة" : "Complete") : (isArabic ? "غير مكتملة" : "Incomplete")}');
    buffer.writeln('${isArabic ? "شهادة المنشأ" : "COO"}: ${card.hasCooAttached ? (isArabic ? "مرفقة ومصدقة" : "Attached") : (isArabic ? "غير مرفقة" : "Missing")}');
    if (card.pendingDocuments.isNotEmpty) {
      buffer.writeln('${isArabic ? "المستندات المعلقة" : "Pending Docs"}: ${card.pendingDocuments.join(", ")}');
    }

    buffer.writeln('\n[${l10n.refCardCostSection}]');
    buffer.writeln('${isArabic ? "المقدر" : "Estimated"}: ${card.estimatedCost} ${card.currency}');
    buffer.writeln('${isArabic ? "الفعلي" : "Actual"}: ${card.actualCost} ${card.currency}');
    buffer.writeln('${isArabic ? "الفارق" : "Variance"}: ${card.varianceAmount} (${card.variancePercentage}%)');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.referenceCardCopiedSuccess),
        backgroundColor: AppTheme.flatEmerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAddGuidelineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddGuideEntryDialog(
        initialHsCode: widget.initialHsCode,
        initialCategory: widget.initialCategory,
        initialDestinationPort: widget.initialPod,
        initialSupplier: widget.initialSupplier,
        initialShippingLine: widget.initialCarrier,
        onSuccess: () {
          ref.invalidate(smartReferenceCardProvider(widget.importFileId));
          ref.invalidate(experienceGuideProvider);
          if (widget.onGuidelineAdded != null) widget.onGuidelineAdded!();
        },
      ),
    );
  }

  void _openManageGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ExperienceGuideManagementDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';
    final cardAsync = ref.watch(smartReferenceCardProvider(widget.importFileId));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: cardAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.flatOrange, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'تعذر تحميل المرجع الذكي للشحنة: $err'
                        : 'Failed to load shipment smart reference: $err',
                    style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                    onPressed: () => ref.invalidate(smartReferenceCardProvider(widget.importFileId)),
                  )
                ],
              ),
            ),
          ),
          data: (card) => _buildCardContent(context, l10n, card, isDark: isDark, isArabic: isArabic),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    AppLocalizations l10n,
    SmartReferenceCardModel card, {
    required bool isDark,
    required bool isArabic,
  }) {
    // Multi-HS Code Breakdown Calculation
    final hsSummaries = card.hsSummaries;
    final hasMultiHs = hsSummaries.length > 1;

    final bool isAllSelected = _selectedHsIndex == 0 || hsSummaries.isEmpty;
    final HsCodeSummaryModel? currentHsItem = (!isAllSelected && _selectedHsIndex - 1 < hsSummaries.length)
        ? hsSummaries[_selectedHsIndex - 1]
        : null;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Card Header (Flexible with no overflow) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.flatCobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.flatCobalt, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.smartReferenceCardTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${card.importFileCode} ${card.customFileNumber != null && card.customFileNumber!.isNotEmpty ? "• ${card.customFileNumber}" : ""}',
                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: AppTheme.flatCobalt),
                  tooltip: isArabic ? 'تحديث بيانات الشحنة والمرجع' : 'Refresh Reference Card',
                  onPressed: () {
                    ref.invalidate(smartReferenceCardProvider(widget.importFileId));
                    ref.invalidate(similarShipmentsProvider(widget.importFileId));
                    ref.invalidate(detectedPatternsProvider);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.copy_all, size: 20, color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal),
                  tooltip: l10n.copyReferenceCardTooltip,
                  onPressed: () => _copyCardData(context, card, isArabic: isArabic),
                ),
                IconButton(
                  icon: const Icon(Icons.library_books_outlined, size: 20, color: AppTheme.flatCobalt),
                  tooltip: l10n.manageGuideEntriesBtn,
                  onPressed: () => _openManageGuideDialog(context),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addGuideEntryBtn, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.flatCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () => _openAddGuidelineDialog(context),
                ),
              ],
            ),
          ],
        ),
        Divider(height: 24, color: isDark ? AppTheme.darkBorder : null),

        // ── Matched Guidelines Alerts (Prominently displayed) ──
        if (card.matchedGuideEntries.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card.matchedGuideEntries.any((e) => e.severity == 'critical')
                  ? AppTheme.flatCrimson.withOpacity(0.08)
                  : AppTheme.flatOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: card.matchedGuideEntries.any((e) => e.severity == 'critical')
                    ? AppTheme.flatCrimson.withOpacity(0.4)
                    : AppTheme.flatOrange.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      card.matchedGuideEntries.any((e) => e.severity == 'critical')
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      color: card.matchedGuideEntries.any((e) => e.severity == 'critical')
                          ? AppTheme.flatCrimson
                          : AppTheme.flatOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      card.matchedGuideEntries.any((e) => e.severity == 'critical')
                          ? l10n.guideCriticalAlertTitle
                          : l10n.guideWarningAlertTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: card.matchedGuideEntries.any((e) => e.severity == 'critical')
                            ? AppTheme.flatCrimson
                            : AppTheme.flatOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...card.matchedGuideEntries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: e.severity == 'critical'
                                ? AppTheme.flatCrimson.withOpacity(0.25)
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
                                    color: (e.severity == 'critical' ? AppTheme.flatCrimson : AppTheme.flatOrange).withOpacity(0.15),
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
          ),
          const SizedBox(height: 16),
        ],

        // ── Grid of Information Cards ──
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // 1. Product Summary Box (with Multi-HS Tabs)
            _buildSectionBox(
              title: l10n.refCardProductSection,
              icon: Icons.inventory_2_outlined,
              accentColor: AppTheme.flatCobalt,
              isDark: isDark,
              customWidth: hasMultiHs ? 320 : 260,
              children: [
                if (hasMultiHs) ...[
                  // Multi-HS Code Selector Tabs
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
                          _buildHsTabChip(
                            label: isArabic ? 'الكل (${hsSummaries.length})' : 'All (${hsSummaries.length})',
                            isSelected: _selectedHsIndex == 0,
                            onTap: () => setState(() => _selectedHsIndex = 0),
                            isDark: isDark,
                          ),
                          ...hsSummaries.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final item = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildHsTabChip(
                                label: item.hsCode,
                                isSelected: _selectedHsIndex == idx,
                                onTap: () => setState(() => _selectedHsIndex = idx),
                                isDark: isDark,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
                _buildInfoRow(
                  l10n.refCardHsCodeLabel,
                  displayHsCode,
                  isBadge: true,
                  isDark: isDark,
                ),
                _buildInfoRow(
                  l10n.refCardCategoryLabel,
                  displayCategory,
                  isDark: isDark,
                ),
                _buildInfoRow(
                  l10n.refCardTotalCbmLabel,
                  '${displayCbm.toStringAsFixed(displayCbm % 1 == 0 ? 0 : 3)} ${isArabic ? 'متر مكعب' : 'm³'}',
                  isDark: isDark,
                ),
                _buildInfoRow(
                  l10n.refCardGrossWeightLabel,
                  '${displayGrossWeight.toStringAsFixed(displayGrossWeight % 1 == 0 ? 0 : 1)} ${isArabic ? 'كجم' : 'kg'}',
                  isDark: isDark,
                ),
                if (displayNetWeight > 0)
                  _buildInfoRow(
                    isArabic ? 'الوزن الصافي:' : 'Net Weight:',
                    '${displayNetWeight.toStringAsFixed(displayNetWeight % 1 == 0 ? 0 : 1)} ${isArabic ? 'كجم' : 'kg'}',
                    isDark: isDark,
                  ),
                _buildInfoRow(
                  l10n.refCardPackagesCountLabel,
                  '$displayPackages ${isArabic ? 'طرد' : 'pkgs'}',
                  isDark: isDark,
                ),
                if (displayQtyPcs > 0)
                  _buildInfoRow(
                    isArabic ? 'الكمية (قطع):' : 'Quantity (Pcs):',
                    '${displayQtyPcs.toInt()} ${isArabic ? 'قطعة' : 'pcs'}',
                    isDark: isDark,
                  ),
              ],
            ),

            // 2. Route & Carrier Box
            _buildSectionBox(
              title: l10n.refCardRouteSection,
              icon: Icons.directions_boat_outlined,
              accentColor: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
              isDark: isDark,
              customWidth: 260,
              children: [
                _buildInfoRow(l10n.refCardPolLabel, card.originPort, isDark: isDark),
                _buildInfoRow(l10n.refCardPodLabel, card.destinationPort, isHighlighted: true, isDark: isDark),
                _buildInfoRow(
                  l10n.refCardCarrierLabel,
                  card.carrier.isNotEmpty ? card.carrier : (isArabic ? 'معتمد' : 'Approved'),
                  isDark: isDark,
                ),
                _buildInfoRow(
                  isArabic ? 'الشروط التجارية:' : 'Incoterm:',
                  (card.routeSummary['incoterm_code'] as String?) ?? 'FOB',
                  isDark: isDark,
                ),
                _buildInfoRow(
                  isArabic ? 'نوع الشحن:' : 'Shipment Mode:',
                  (card.routeSummary['shipment_mode'] as String?) ?? 'Sea FCL',
                  isDark: isDark,
                ),
              ],
            ),

            // 3. Critical Dates & Free Time Box
            _buildSectionBox(
              title: l10n.refCardDatesSection,
              icon: Icons.access_time_rounded,
              accentColor: AppTheme.flatOrange,
              isDark: isDark,
              customWidth: 260,
              children: [
                _buildInfoRow(
                  l10n.refCardFreeDaysLabel,
                  '${card.freeDays} ${isArabic ? 'يوماً' : 'days'}',
                  isDark: isDark,
                ),
                _buildInfoRow(
                  isArabic ? 'تاريخ الوصول:' : 'Expected ETA:',
                  (card.criticalDates['required_eta'] as String?) ?? (isArabic ? 'قيد التحديد' : 'TBD'),
                  isDark: isDark,
                ),
                _buildInfoRow(
                  isArabic ? 'جاهزية البضاعة:' : 'Cargo Ready Date:',
                  (card.criticalDates['cargo_ready_date'] as String?) ?? (isArabic ? 'جاهزة' : 'Ready'),
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.flatEmerald.withOpacity(0.12),
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
            ),

            // 4. Customs Documents Readiness Box
            _buildSectionBox(
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
                        ? AppTheme.flatEmerald.withOpacity(0.12)
                        : AppTheme.flatCrimson.withOpacity(0.12),
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
                      Text(
                        card.isDocsComplete ? l10n.refCardDocsCompleteBadge : l10n.refCardDocsPendingBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: card.isDocsComplete ? AppTheme.flatEmerald : AppTheme.flatCrimson,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  isArabic ? 'شهادة المنشأ الأصلية:' : 'Original COO:',
                  card.hasCooAttached ? l10n.refCardCooAttachedBadge : l10n.refCardCooMissingBadge,
                  isAlert: !card.hasCooAttached && card.isCooRequired,
                  isDark: isDark,
                ),
                if (card.pendingDocuments.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${isArabic ? 'مستندات مطلوبة:' : 'Pending Docs:'} ${card.pendingDocuments.take(2).join(", ")}',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                  ),
                ],
              ],
            ),

            // 5. Cost Comparison Box
            _buildSectionBox(
              title: l10n.refCardCostSection,
              icon: Icons.monetization_on_outlined,
              accentColor: card.varianceAmount <= 0 ? AppTheme.flatEmerald : AppTheme.flatCrimson,
              isDark: isDark,
              customWidth: 260,
              children: [
                _buildInfoRow(l10n.refCardEstCostLabel, '${card.estimatedCost} ${card.currency}', isDark: isDark),
                _buildInfoRow(l10n.refCardActualCostLabel, '${card.actualCost} ${card.currency}', isDark: isDark),
                _buildInfoRow(
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHsTabChip({
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
          color: isSelected
              ? AppTheme.flatCobalt
              : (isDark ? AppTheme.darkSurface : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.flatCharcoal),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBox({
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
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

  Widget _buildInfoRow(
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
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: isBadge
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.flatCobalt.withOpacity(0.12),
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
                  ),
          ),
        ],
      ),
    );
  }
}
