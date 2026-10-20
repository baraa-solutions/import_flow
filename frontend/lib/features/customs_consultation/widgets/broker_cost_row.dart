import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/customs_consultation_model.dart';
import '../../currencies/models/currency_model.dart';
import 'quick_expense_coding_dialog.dart';
import 'extraction_confidence_indicator.dart';

Widget buildBrokerCostRow({
  required BuildContext context,
  required Function(int, CustomsBrokerQuoteItemModel) onUpdate,
  required int index,
  required CustomsBrokerQuoteItemModel item,
  required List<CurrencyModel> currenciesList,
  WidgetRef? ref,
  double? referenceUsdExchangeRate,
}) {
  final l = context.l10n;
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final isForeign = item.currency.toUpperCase() != 'EGP';
  final isNegotiable = item.priceType == 'negotiable' ||
      (item.unitPrice == 0.0 && item.minPrice == null && item.maxPrice == null);
  final isRange = item.priceType == 'range';

  // Compute converted EGP if applicable
  double? convertedEgpTotal;
  if (isForeign && referenceUsdExchangeRate != null && referenceUsdExchangeRate > 0) {
    if (item.currency.toUpperCase() == 'USD') {
      convertedEgpTotal = item.unitPrice * item.qty * referenceUsdExchangeRate;
    }
  }

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.04) : AppTheme.charcoalSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.cloudWhite,
      ),
    ),
    child: Row(
      children: [
        // ── 1. Title, Coding Badge & Category ───────────────────────────────
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Code badge if coded
                  if (item.code != null && item.code!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.code!,
                        style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // AI/OCR Confidence indicator or uncoded badge (M1-5)
                  if (item.confidence != null || item.rawExtractedText != null || item.isUncoded) ...[
                    ExtractionConfidenceIndicator(
                      confidence: item.confidence,
                      rawExtractedText: item.rawExtractedText,
                      isUncoded: item.isUncoded,
                      onUncodedTap: ref == null
                          ? null
                          : () {
                              QuickExpenseCodingDialog.show(
                                context: context,
                                ref: ref,
                                currentExpenseName: item.expenseName,
                                currentCategory: item.category,
                                onSelected: (sel) {
                                  onUpdate(
                                    index,
                                    item.copyWith(
                                      code: sel.code,
                                      expenseName: sel.canonicalNameAr,
                                      category: sel.category,
                                      unitType: sel.unitType,
                                      isUncoded: false,
                                    ),
                                  );
                                },
                              );
                            },
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Foreign Currency Badge (M2-2)
                  if (isForeign) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_outlined, size: 10, color: AppTheme.wcagOrange),
                          const SizedBox(width: 2),
                          Text(
                            item.currency,
                            style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Name with copy
                  Expanded(
                    child: InkWell(
                      onTap: () => CopyHelper.copy(
                        context,
                        item.expenseName,
                        customMessage: context.l10n.ccExpenseItemNameCopied,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              item.expenseName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_outlined, size: 11, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),

                  // Note indicator 💬 icon with preview Tooltip (M2-3)
                  if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                    Tooltip(
                      message: '${isAr ? "ملاحظات البند:" : "Item Notes:"}\n${item.notes!.trim()}',
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

                  // Note templates menu button (M2-3)
                  PopupMenuButton<String>(
                    tooltip: isAr ? 'قوالب ملاحظات جاهزة' : 'Note templates',
                    icon: const Icon(Icons.playlist_add_rounded, size: 16, color: AppTheme.cobalt),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (template) {
                      final currentNotes = (item.notes ?? '').trim();
                      final newNotes = currentNotes.isEmpty
                          ? template
                          : (currentNotes.contains(template) ? currentNotes : '$currentNotes • $template');
                      onUpdate(index, item.copyWith(notes: newNotes));
                    },
                    itemBuilder: (ctx) => const [
                      'يُضاف عند الحاجة فقط',
                      'يشمل الضريبة',
                      'يتغير حسب سعر الصرف',
                      'يُحسب على الوزن الفعلي',
                      'لا يشمل الغرامات والأرضيات',
                      'شامل الروافع والكلارك',
                    ].map((t) => PopupMenuItem(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 12)),
                    )).toList(),
                  ),
                  const SizedBox(width: 4),

                  // Quick Coding trigger icon
                  if (ref != null && (item.isUncoded || item.code == null)) ...[
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: isAr ? 'تكويد سريع من الدليل' : 'Quick Code from Catalog',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        QuickExpenseCodingDialog.show(
                          context: context,
                          ref: ref,
                          currentExpenseName: item.expenseName,
                          currentCategory: item.category,
                          onSelected: (sel) {
                            onUpdate(
                              index,
                              item.copyWith(
                                code: sel.code,
                                expenseName: sel.canonicalNameAr,
                                category: sel.category,
                                unitType: sel.unitType,
                                isUncoded: false,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${item.category.split('(').first.trim()} | ${item.unitType}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── 2. Price Type & Input (Fixed / Range / Negotiable - M2-1) ──────────
        PopupMenuButton<String>(
          tooltip: isAr ? 'تغيير نوع السعر (ثابت / نطاق / تفاوضي)' : 'Change price type',
          icon: Icon(
            isNegotiable
                ? Icons.handshake_outlined
                : (isRange ? Icons.linear_scale_rounded : Icons.price_check_rounded),
            size: 18,
            color: isNegotiable ? AppTheme.wcagOrange : AppTheme.cobalt,
          ),
          onSelected: (type) {
            if (type == 'negotiable') {
              onUpdate(index, item.copyWith(priceType: 'negotiable', unitPrice: 0.0));
            } else if (type == 'range') {
              onUpdate(index, item.copyWith(priceType: 'range'));
            } else {
              onUpdate(index, item.copyWith(priceType: 'fixed'));
            }
          },
          itemBuilder: (ctx) => [
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
                  Text(isAr ? 'نطاق سعري (حد أدنى / أقصى)' : 'Price Range (Min/Max)', style: const TextStyle(fontSize: 12)),
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

        // Price input / display
        Expanded(
          flex: 3,
          child: isNegotiable
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.handshake_outlined, size: 14, color: AppTheme.wcagOrange),
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
                )
              : isRange
                  ? Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('broker_min_${item.expenseTypeId ?? item.expenseName}_${item.minPrice}'),
                            initialValue: item.minPrice != null && item.minPrice! > 0
                                ? (item.minPrice! % 1 == 0 ? item.minPrice!.toInt().toString() : item.minPrice!.toString())
                                : '',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: isAr ? 'أدنى' : 'Min',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            onChanged: (v) {
                              final minP = double.tryParse(v);
                              onUpdate(index, item.copyWith(minPrice: minP));
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('broker_max_${item.expenseTypeId ?? item.expenseName}_${item.maxPrice}'),
                            initialValue: item.maxPrice != null && item.maxPrice! > 0
                                ? (item.maxPrice! % 1 == 0 ? item.maxPrice!.toInt().toString() : item.maxPrice!.toString())
                                : '',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: isAr ? 'أقصى' : 'Max',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            onChanged: (v) {
                              final maxP = double.tryParse(v);
                              onUpdate(index, item.copyWith(maxPrice: maxP));
                            },
                          ),
                        ),
                      ],
                    )
                  : TextFormField(
                      key: ValueKey('broker_price_${item.expenseTypeId ?? item.expenseName}_${item.unitPrice}'),
                      initialValue: item.unitPrice == 0.0 ? '' : (item.unitPrice % 1 == 0 ? item.unitPrice.toInt().toString() : item.unitPrice.toString()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l.quoteItemPrice,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (v) {
                        final p = double.tryParse(v) ?? 0.0;
                        onUpdate(index, item.copyWith(unitPrice: p, priceType: p > 0 ? 'fixed' : 'negotiable'));
                      },
                    ),
        ),
        const SizedBox(width: 8),

        // ── 3. Currency Dropdown (M2-2) ──────────────────────────────────────
        Expanded(
          flex: 2,
          child: SearchableDropdownField<String>(
            value: currenciesList.any((c) => c.currencyCode == item.currency)
                ? item.currency
                : (currenciesList.isNotEmpty ? currenciesList.first.currencyCode : 'EGP'),
            labelText: l.quoteItemCurrency,
            items: currenciesList
                .map((c) => SearchableDropdownItem(
                      value: c.currencyCode,
                      label: '${c.currencyCode} (${c.currencySymbol})',
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                onUpdate(index, item.copyWith(currency: v));
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // ── 4. Qty Field ─────────────────────────────────────────────────────
        Expanded(
          flex: 1,
          child: TextFormField(
            key: ValueKey('broker_qty_${item.expenseTypeId ?? item.expenseName}'),
            initialValue: item.qty == 0.0 ? '1' : (item.qty == item.qty.roundToDouble() ? item.qty.toInt().toString() : item.qty.toString()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.quoteItemQuantity,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final q = double.tryParse(v) ?? 1.0;
              onUpdate(index, item.copyWith(qty: q));
            },
          ),
        ),
        const SizedBox(width: 10),

        // ── 5. Applicable Switch ─────────────────────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.isApplicable,
              activeThumbColor: AppTheme.emerald,
              onChanged: (v) => onUpdate(index, item.copyWith(isApplicable: v)),
            ),
            Text(
              item.isApplicable ? l.quoteItemApplicable : l.quoteItemNotApplicable,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: item.isApplicable ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),

        // ── 6. Line Total Display (with converted EGP if foreign currency) ────
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.isApplicable
                      ? (isNegotiable
                          ? (isAr ? 'تفاوضي' : 'Negotiable')
                          : '${(item.unitPrice * item.qty).toStringAsFixed(2)} ${item.currency}')
                      : '0.00 ${item.currency}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isNegotiable ? AppTheme.wcagOrange : (item.isApplicable ? AppTheme.emerald : AppTheme.textSecondary),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (convertedEgpTotal != null && item.isApplicable && !isNegotiable) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${convertedEgpTotal.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
