import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../models/purchase_order_model.dart';

/// Summary card displaying multi-currency financial totals, estimated duties & VAT, and notes.
class POFormSummaryBar extends StatelessWidget {
  final List<POLineItemModel> items;
  final List<CurrencyModel> currencies;
  final int? selectedCurrencyId;
  final double exchangeRate;
  final List<CustomsTariffModel> tariffs;
  final TextEditingController notesCtrl;

  const POFormSummaryBar({
    super.key,
    required this.items,
    required this.currencies,
    required this.selectedCurrencyId,
    required this.exchangeRate,
    required this.tariffs,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;

    final activeCurrency = currencies.where((c) => c.currencyId == selectedCurrencyId).firstOrNull ??
        CurrencyModel(currencyId: 0, currencyCode: 'USD', currencyName: 'USD', currencySymbol: '\$');

    final double totalForeign = items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));
    final double effectiveRate = exchangeRate > 0 ? exchangeRate : 1.0;
    final double totalEgp = totalForeign * effectiveRate;

    // Estimate customs duty and VAT based on linked tariffs
    double estimatedDutyEgp = 0.0;
    double estimatedVatEgp = 0.0;
    for (final item in items) {
      final lineEgp = (item.quantity * item.unitPrice) * effectiveRate;
      final matchedTariff = item.tariffId != null
          ? tariffs.where((t) => t.tariffId == item.tariffId).firstOrNull
          : null;
      final dutyRate = (matchedTariff?.customsDutyRate ?? 5.0) / 100.0;
      final vatRate = (matchedTariff?.vatRate ?? 14.0) / 100.0;

      final duty = lineEgp * dutyRate;
      final vat = (lineEgp + duty) * vatRate;
      estimatedDutyEgp += duty;
      estimatedVatEgp += vat;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite, width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial KPI Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Foreign Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'إجمالي الفاتورة الأجنبية' : 'Foreign Subtotal',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activeCurrency.currencyCode} ${totalForeign.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ],
              ),

              // Exchange Rate
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'سعر الصرف المعتمد' : 'Exchange Rate',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${effectiveRate.toStringAsFixed(4)} EGP',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  ),
                ],
              ),

              // Local Total (EGP)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'المعادل بالجنيه المصري' : 'EGP Equivalent',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${totalEgp.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                  ),
                ],
              ),

              // Estimated Duties & VAT
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'تقديرات الجمارك وضريبة الوارد' : 'Est. Customs & VAT',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isArabic
                          ? 'جمارك: ${estimatedDutyEgp.toStringAsFixed(0)} ج.م | ضريبة: ${estimatedVatEgp.toStringAsFixed(0)} ج.م'
                          : 'Duty: ${estimatedDutyEgp.toStringAsFixed(0)} EGP | VAT: ${estimatedVatEgp.toStringAsFixed(0)} EGP',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.cloudWhite),
          const SizedBox(height: 10),

          // PO Notes
          TextFormField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: isArabic ? 'ملاحظات وتعليمات أمر الشراء' : 'PO Notes & Instructions',
              hintText: isArabic ? 'أدخل أي شروط خاصة أو ملاحظات...' : 'Enter any special instructions...',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
