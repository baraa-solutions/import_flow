import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import 'extracted_quotation_option_model.dart';
import 'quotations_option_card.dart';
import 'quotations_parties_verification_panel.dart';

/// Comparison view presenting extracted fields, party verification, and quotation option cards.
class QuotationsExtractorComparisonView extends StatelessWidget {
  final List<ExtractedQuotationOption> options;
  final Map<String, dynamic>? primaryMetadata;
  final Map<String, String> customFields;
  final List<dynamic> partners;
  final List<dynamic> portsList;
  final VoidCallback onAddCustomField;
  final void Function(String key, String value) onEditCustomField;
  final void Function(String key) onDeleteCustomField;
  final VoidCallback onRegisterPartner;
  final ValueChanged<ExtractedQuotationOption> onAddSingleQuote;
  final VoidCallback onAddAllQuotes;
  final ValueChanged<ExtractedQuotationOption>? onCopySingleQuote;
  final VoidCallback? onCopyAllQuotes;

  const QuotationsExtractorComparisonView({
    super.key,
    required this.options,
    required this.primaryMetadata,
    required this.customFields,
    required this.partners,
    required this.portsList,
    required this.onAddCustomField,
    required this.onEditCustomField,
    required this.onDeleteCustomField,
    required this.onRegisterPartner,
    required this.onAddSingleQuote,
    required this.onAddAllQuotes,
    this.onCopySingleQuote,
    this.onCopyAllQuotes,
  });

  int _calculateTotalFieldsCount() {
    int count = 0;
    if (primaryMetadata != null) {
      if (primaryMetadata!['origin_port'] != null) count++;
      if (primaryMetadata!['destination_port'] != null) count++;
      if (primaryMetadata!['carrier_name'] != null) count++;
      if (primaryMetadata!['forwarder_name'] != null) count++;
      if (primaryMetadata!['etd_date'] != null) count++;
      if (primaryMetadata!['transit_days'] != null) count++;
      if (primaryMetadata!['free_days_demurrage'] != null) count++;
    }
    count += options.length;
    count += customFields.length;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final bool hasUnmappedWarning =
        primaryMetadata?['unmapped_expenses_warning'] != null || customFields.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),

        // ── Top Header with Add Manual Field Button ────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic
                  ? 'الحقول المستخرجة (${_calculateTotalFieldsCount()})'
                  : 'Extracted Fields (${_calculateTotalFieldsCount()})',
              style: const TextStyle(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            AppButton(
              label: isArabic ? '➕ إضافة بيان يدوي' : '➕ Add Manual Field',
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: onAddCustomField,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Entity Verification Panel ───────────────────────────────────────
        QuotationsPartiesVerificationPanel(
          primaryMetadata: primaryMetadata,
          options: options,
          partners: partners,
          portsList: portsList,
          onRegisterPartner: onRegisterPartner,
        ),
        const SizedBox(height: 12),

        // ── Unmapped / Special Expenses Warning Alert ───────────────────────
        if (hasUnmappedWarning) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        primaryMetadata?['unmapped_expenses_warning']?.toString() ??
                            (isArabic
                                ? '⚠️ تنبيه: تم اكتشاف مصروفات إضافية في العرض غير مكودة قياسياً في النولون — يرجى مراجعتها وتوجيهها لتضمينها في دراسة الشحن لعدم فقدان أي تكلفة.'
                                : '⚠️ Warning: Additional unmapped expenses detected in quotation — please review to include in freight cost analysis.'),
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? '💡 تم استخراج هذه البنود وتثبيتها أدناه (★) مع إمكانية تعديلها أو حذفها، وسيتم تضمينها تلقائياً في ملاحظات وتكاليف الشحنة.'
                      : '💡 These items have been extracted below (★) with edit/delete support, and will be included in shipment notes and costs.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Standard & Custom Extracted Fields List ─────────────────────────
        _buildExtractedFieldsList(context, isArabic),
        const SizedBox(height: 12),

        // ── Green Options Container & Cards ─────────────────────────────────
        _buildExtractedOptionsGreenContainer(context, isArabic),
      ],
    );
  }

  Widget _buildExtractedFieldsList(BuildContext context, bool isArabic) {
    final pol = primaryMetadata?['origin_port']?.toString() ?? options.firstOrNull?.originPort;
    final pod = primaryMetadata?['destination_port']?.toString() ?? options.firstOrNull?.destinationPort;
    final carrier = primaryMetadata?['carrier_name']?.toString() ?? options.firstOrNull?.carrierName;
    final fwd = primaryMetadata?['forwarder_name']?.toString() ?? options.firstOrNull?.forwarderName;
    final etd = primaryMetadata?['etd_date']?.toString() ?? options.firstOrNull?.etdDate;
    final transit = primaryMetadata?['transit_days']?.toString() ?? options.firstOrNull?.transitDays?.toString();
    final freeTime = primaryMetadata?['free_days_demurrage']?.toString() ?? options.firstOrNull?.freeTimeDays?.toString();

    return Column(
      children: [
        if (pol != null && pol.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'ميناء الشحن' : 'Port of Loading',
            value: pol,
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, pol),
          ),
        if (pod != null && pod.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'ميناء الوصول' : 'Port of Discharge',
            value: pod,
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, pod),
          ),
        if (carrier != null && carrier.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'الخط الملاحي' : 'Shipping Line',
            value: carrier,
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, carrier),
          ),
        if (fwd != null && fwd.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'وكيل الشحن أو الناقل' : 'Freight Forwarder',
            value: fwd,
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, fwd),
          ),
        if (etd != null && etd.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'تاريخ الإبحار' : 'Departure Date',
            value: etd,
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, etd),
          ),
        if (transit != null && transit.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'مدة الإبحار' : 'Transit Time',
            value: isArabic ? '$transit يوم مباشر' : '$transit days direct',
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, transit),
          ),
        if (freeTime != null && freeTime.isNotEmpty)
          ExtractedFieldRow(
            label: isArabic ? 'فترة السماح' : 'Free Time',
            value: isArabic ? '$freeTime يوم' : '$freeTime days',
            isCustom: false,
            onCopy: () => CopyHelper.copy(context, freeTime),
          ),

        // Custom & Unmapped Starred Fields
        ...customFields.entries.map(
          (e) => ExtractedFieldRow(
            label: '★ ${e.key}',
            value: e.value,
            isCustom: true,
            onCopy: () => CopyHelper.copy(context, e.value),
            onEdit: () => onEditCustomField(e.key, e.value),
            onDelete: () => onDeleteCustomField(e.key),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedOptionsGreenContainer(BuildContext context, bool isArabic) {
    final pol = primaryMetadata?['origin_port']?.toString() ?? options.firstOrNull?.originPort;
    final pod = primaryMetadata?['destination_port']?.toString() ?? options.firstOrNull?.destinationPort;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Row ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تم استخراج ${options.length} من عروض الأسعار بنجاح! راجع العروض أدناه ثم أضفها لدراسة المفاضلة:'
                      : 'Successfully extracted ${options.length} quotation(s)! Review below and add to benchmark study:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 20),
                tooltip: isArabic ? 'نسخ كافة العروض بتنسيق جدول بيانات' : 'Copy All Quotes (TSV / Excel)',
                onPressed: () {
                  if (onCopyAllQuotes != null) {
                    onCopyAllQuotes!();
                  } else {
                    _copyAllQuotes(context, isArabic);
                  }
                },
              ),
              const SizedBox(width: 6),
              AppButton(
                label: isArabic
                    ? 'إضافة كافة العروض (${options.length}) 🚀 +'
                    : 'Add All Quotes (${options.length}) 🚀 +',
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                icon: Icons.add_task,
                onPressed: onAddAllQuotes,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Ports Chips Row ───────────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (pol != null && pol.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight_takeoff, size: 15, color: AppTheme.cobalt),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'ميناء الشحن: $pol' : 'Port of Loading: $pol',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                ),
              if (pod != null && pod.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight_land, size: 15, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'ميناء الوصول: $pod' : 'Port of Discharge: $pod',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Quotation Cards Grid / Wrap ───────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              final cardWidth = isWide ? (constraints.maxWidth - 12) / 2 : double.infinity;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((opt) {
                  return SizedBox(
                    width: cardWidth,
                    child: QuotationsOptionCard(
                      option: opt,
                      onAddSingle: () => onAddSingleQuote(opt),
                      onCopy: () {
                        if (onCopySingleQuote != null) {
                          onCopySingleQuote!(opt);
                        } else {
                          _copySingleQuote(context, opt, isArabic);
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _copyAllQuotes(BuildContext context, bool isArabic) {
    if (options.isEmpty) return;
    final headers = isArabic
        ? ['الخط الملاحي', 'نوع الحاوية', 'النولون', 'المصاريف المحلية', 'الإجمالي', 'العملة', 'الترانزيت (أيام)', 'فترة السماح (أيام)', 'مباشر أو ترانزيت', 'ميناء الشحن', 'ميناء الوصول', 'ملاحظات']
        : ['Carrier', 'Container Type', 'Ocean Freight', 'Local Charges', 'Total', 'Currency', 'Transit Days', 'Free Time Days', 'Direct/Transit', 'Port of Loading', 'Port of Discharge', 'Notes'];

    final pol = primaryMetadata?['origin_port']?.toString() ?? options.firstOrNull?.originPort ?? '';
    final pod = primaryMetadata?['destination_port']?.toString() ?? options.firstOrNull?.destinationPort ?? '';

    final rows = options.map((opt) => [
      opt.carrierName,
      opt.containerType,
      opt.oceanFreight.toStringAsFixed(2),
      (opt.localCharges ?? 0).toStringAsFixed(2),
      opt.totalEstimatedCost.toStringAsFixed(2),
      opt.currency,
      opt.transitDays?.toString() ?? '',
      opt.freeTimeDays?.toString() ?? '',
      opt.isDirect ? (isArabic ? 'مباشر' : 'Direct') : (isArabic ? 'ترانزيت' : 'Transit'),
      opt.originPort ?? pol,
      opt.destinationPort ?? pod,
      opt.notes ?? '',
    ].join('\t')).join('\n');

    final tsv = '${headers.join('\t')}\n$rows';
    CopyHelper.copy(
      context,
      tsv,
      customMessage: isArabic
          ? 'تم نسخ جميع عروض الأسعار بصيغة جدول بنجاح!'
          : 'All quotations copied to clipboard (TSV / Excel) successfully!',
    );
  }

  void _copySingleQuote(BuildContext context, ExtractedQuotationOption opt, bool isArabic) {
    final pol = opt.originPort ?? primaryMetadata?['origin_port']?.toString() ?? '';
    final pod = opt.destinationPort ?? primaryMetadata?['destination_port']?.toString() ?? '';
    final text = isArabic
        ? '${opt.carrierName} | حاوية: ${opt.containerType} | نولون: \$${opt.oceanFreight.toStringAsFixed(0)} | إجمالي: \$${opt.totalEstimatedCost.toStringAsFixed(0)} | ترانزيت: ${opt.transitDays ?? "-"} يوم | سماح: ${opt.freeTimeDays ?? 14} يوم | من: $pol | إلى: $pod'
        : '${opt.carrierName} | Container: ${opt.containerType} | Freight: \$${opt.oceanFreight.toStringAsFixed(0)} | Total: \$${opt.totalEstimatedCost.toStringAsFixed(0)} | Transit: ${opt.transitDays ?? "-"}d | Free Time: ${opt.freeTimeDays ?? 14}d | POL: $pol | POD: $pod';
    CopyHelper.copy(
      context,
      text,
      customMessage: isArabic ? 'تم نسخ بيانات العرض بنجاح!' : 'Quote details copied successfully!',
    );
  }
}
