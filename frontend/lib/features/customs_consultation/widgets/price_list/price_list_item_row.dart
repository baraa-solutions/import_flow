import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../extraction_confidence_indicator.dart';
import '../quick_expense_coding_dialog.dart';
import 'price_list_match_helper.dart';

/// Single interactive row in the customs expenses table.
class PriceListItemRow extends StatelessWidget {
  final WidgetRef ref;
  final Map<String, dynamic> item;
  final int indexInGroup;
  final int realIndex;
  final double? usdRefRate;
  final VoidCallback onClone;
  final VoidCallback? onDelete;
  final void Function(void Function()) onStateChanged;

  const PriceListItemRow({
    super.key,
    required this.ref,
    required this.item,
    required this.indexInGroup,
    required this.realIndex,
    required this.usdRefRate,
    required this.onClone,
    this.onDelete,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final standardPrice = (item['standard_price'] as num?)?.toDouble() ?? 0.0;
    final minPrice = (item['min_price'] as num?)?.toDouble();
    final maxPrice = (item['max_price'] as num?)?.toDouble();
    final isCustomItem = item['expense_type_id'] == null;
    final isForeign = (item['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';

    final pType = item['price_type']?.toString() ??
        (minPrice != null || maxPrice != null
            ? 'range'
            : (standardPrice == 0.0 ? 'negotiable' : 'fixed'));
    final isNegotiable = pType == 'negotiable' ||
        (standardPrice == 0.0 && minPrice == null && maxPrice == null);
    final isRange = pType == 'range';

    return Container(
      color: isCustomItem
          ? AppTheme.orangeLight
          : (indexInGroup.isEven ? AppTheme.white : AppTheme.charcoalSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // ── Title, Badges & Coding ──────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item['code'] != null && item['code'].toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['code'].toString(),
                          style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    if (item['confidence'] != null || item['raw_extracted_text'] != null || item['is_uncoded'] == true) ...[
                      ExtractionConfidenceIndicator(
                        confidence: (item['confidence'] as num?)?.toDouble(),
                        rawExtractedText: item['raw_extracted_text']?.toString(),
                        isUncoded: item['is_uncoded'] == true,
                        onUncodedTap: () => _openQuickCoding(context),
                      ),
                      const SizedBox(width: 4),
                    ] else if (isCustomItem) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.wcagOrange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.customItemBadge,
                          style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    if (isForeign) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_outlined, size: 10, color: AppTheme.wcagOrange),
                            const SizedBox(width: 2),
                            Text(
                              item['currency']?.toString() ?? 'USD',
                              style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    Expanded(
                      child: Text(
                        item['expense_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (item['notes'] != null && item['notes'].toString().trim().isNotEmpty) ...[
                      Tooltip(
                        message: '${isAr ? "ملاحظات البند:" : "Item Notes:"}\n${item['notes'].toString().trim()}',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(start: 4),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: AppTheme.cobalt),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    if (item['is_uncoded'] == true || item['code'] == null) ...[
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.cobalt),
                        tooltip: isAr ? 'تكويد سريع من الدليل' : 'Quick Code from Catalog',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _openQuickCoding(context),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
                Text(
                  '${getCategoryLabel(item['category']?.toString() ?? '', context)} | ${getUnitLabel(item['unit_type']?.toString() ?? '', context)}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Price Type Selector ─────────────────────────────────────────────
          PopupMenuButton<String>(
            tooltip: isAr ? 'تغيير نوع السعر: ثابت أو نطاق أو تفاوضي' : 'Change price type: fixed, range, negotiable',
            icon: Icon(
              isNegotiable
                  ? Icons.handshake_outlined
                  : (isRange ? Icons.linear_scale_rounded : Icons.price_check_rounded),
              size: 18,
              color: isNegotiable ? AppTheme.wcagOrange : AppTheme.cobalt,
            ),
            onSelected: (type) {
              onStateChanged(() {
                item['price_type'] = type;
                if (type == 'negotiable') {
                  item['standard_price'] = 0.0;
                }
              });
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                value: 'fixed',
                child: Row(
                  children: [
                    const Icon(Icons.price_check_rounded, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Text(isAr ? 'سعر ثابت' : 'Fixed Price', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'range',
                child: Row(
                  children: [
                    const Icon(Icons.linear_scale_rounded, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Text(isAr ? 'نطاق سعري' : 'Price Range', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'negotiable',
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined, size: 16, color: AppTheme.wcagOrange),
                    const SizedBox(width: 8),
                    Text(isAr ? 'سعر تفاوضي' : 'Negotiable', style: const TextStyle(fontSize: 12, color: AppTheme.wcagOrange)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),

          // ── Price Input Field / Range / Negotiable ──────────────────────────
          SizedBox(
            width: 140,
            child: isNegotiable
                ? InkWell(
                    onTap: () => onStateChanged(() => item['price_type'] = 'fixed'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.handshake_outlined, size: 13, color: AppTheme.wcagOrange),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'تفاوضي' : 'Negotiable',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : isRange
                    ? Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('dlg_min_${item["expense_type_id"] ?? item["expense_name"]}_$minPrice'),
                              initialValue: minPrice != null && minPrice > 0
                                  ? (minPrice % 1 == 0 ? minPrice.toInt().toString() : minPrice.toString())
                                  : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: isAr ? 'أدنى' : 'Min',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              ),
                              onChanged: (v) => item['min_price'] = double.tryParse(v),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('dlg_max_${item["expense_type_id"] ?? item["expense_name"]}_$maxPrice'),
                              initialValue: maxPrice != null && maxPrice > 0
                                  ? (maxPrice % 1 == 0 ? maxPrice.toInt().toString() : maxPrice.toString())
                                  : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: isAr ? 'أقصى' : 'Max',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              ),
                              onChanged: (v) => item['max_price'] = double.tryParse(v),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: ValueKey('dlg_price_${item["expense_type_id"] ?? item["expense_name"]}_$standardPrice'),
                            initialValue: standardPrice == 0.0
                                ? ''
                                : (standardPrice % 1 == 0 ? standardPrice.toInt().toString() : standardPrice.toString()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: l.approvedPriceField,
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v) ?? 0.0;
                              item['standard_price'] = p;
                              item['price_type'] = p > 0 ? 'fixed' : 'negotiable';
                            },
                          ),
                          if (isForeign && usdRefRate != null && usdRefRate! > 0 && standardPrice > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '≈ ${(standardPrice * usdRefRate!).toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                              style: const TextStyle(color: AppTheme.cobalt, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
          ),
          const SizedBox(width: 8),

          // ── Currency Dropdown ───────────────────────────────────────────────
          SizedBox(
            width: 100,
            child: SearchableDropdownField<String>(
              value: item['currency'] ?? 'EGP',
              items: const [
                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                SearchableDropdownItem(value: 'USD', label: 'USD'),
                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
              ],
              onChanged: (v) => onStateChanged(() => item['currency'] = v ?? 'EGP'),
            ),
          ),
          const SizedBox(width: 8),

          // ── Notes / Conditions Input & Templates ────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('dlg_notes_${item['expense_type_id'] ?? item['expense_name']}_${item['notes']}'),
                    initialValue: item['notes'] ?? '',
                    decoration: InputDecoration(
                      labelText: l.notesPriceRangeField,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) => item['notes'] = v,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: isAr ? 'قوالب ملاحظات جاهزة' : 'Note templates',
                  icon: const Icon(Icons.playlist_add_rounded, size: 18, color: AppTheme.cobalt),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (template) {
                    onStateChanged(() {
                      final currentNotes = (item['notes']?.toString() ?? '').trim();
                      final newNotes = currentNotes.isEmpty
                          ? template
                          : (currentNotes.contains(template) ? currentNotes : '$currentNotes • $template');
                      item['notes'] = newNotes;
                    });
                  },
                  itemBuilder: (c) => const [
                    'يُضاف عند الحاجة فقط',
                    'يشمل الضريبة',
                    'يتغير حسب سعر الصرف',
                    'يُحسب على الوزن الفعلي',
                    'لا يشمل الغرامات والأرضيات',
                    'شامل الروافع والكلارك',
                  ]
                      .map((t) => PopupMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 18),
            tooltip: l.cloneRowTooltip,
            onPressed: onClone,
          ),

          if (isCustomItem && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
              tooltip: l.deleteCustomItemTooltip,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  void _openQuickCoding(BuildContext context) {
    QuickExpenseCodingDialog.show(
      context: context,
      ref: ref,
      currentExpenseName: item['expense_name'],
      currentCategory: item['category'],
      onSelected: (sel) {
        onStateChanged(() {
          item['code'] = sel.code;
          item['expense_name'] = sel.canonicalNameAr;
          item['category'] = sel.category;
          item['unit_type'] = sel.unitType;
          item['is_uncoded'] = false;
        });
      },
    );
  }
}
