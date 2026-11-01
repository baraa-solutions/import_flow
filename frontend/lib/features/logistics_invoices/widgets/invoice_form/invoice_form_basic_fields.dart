import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';

class InvoiceFormBasicFields extends StatelessWidget {
  final bool isArabic;
  final bool isEditMode;
  final String partnerType;
  final ValueChanged<String?> onPartnerTypeChanged;
  final TextEditingController invoiceNumberCtrl;
  final TextEditingController partnerNameCtrl;
  final TextEditingController shipmentIdCtrl;
  final TextEditingController blNumberCtrl;
  final ValueChanged<int> onShipmentIdChanged;
  final ValueChanged<String> onBlNumberChanged;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final double exchangeRate;
  final ValueChanged<double> onExchangeRateChanged;
  final VoidCallback onFetchCbeRate;

  const InvoiceFormBasicFields({
    super.key,
    required this.isArabic,
    required this.isEditMode,
    required this.partnerType,
    required this.onPartnerTypeChanged,
    required this.invoiceNumberCtrl,
    required this.partnerNameCtrl,
    required this.shipmentIdCtrl,
    required this.blNumberCtrl,
    required this.onShipmentIdChanged,
    required this.onBlNumberChanged,
    required this.currency,
    required this.onCurrencyChanged,
    required this.exchangeRate,
    required this.onExchangeRateChanged,
    required this.onFetchCbeRate,
  });

  @override
  Widget build(BuildContext context) {
    const validPartnerTypes = ['freight', 'clearance', 'transport', 'inspection', 'insurance'];
    final effectiveType = validPartnerTypes.contains(partnerType) ? partnerType : 'freight';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Details Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                value: effectiveType,
                labelText: isArabic ? 'نوع الشريك اللوجستي' : 'Partner Type',
                decoration: InputDecoration(
                  labelText: isArabic ? 'نوع الشريك اللوجستي' : 'Partner Type',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  SearchableDropdownItem<String>(value: 'freight', label: isArabic ? 'شركة شحن ونولون' : 'Freight Forwarder'),
                  SearchableDropdownItem<String>(value: 'clearance', label: isArabic ? 'مخلص جمركي' : 'Customs Broker'),
                  SearchableDropdownItem<String>(value: 'transport', label: isArabic ? 'نقل داخلي' : 'Inland Transport'),
                  SearchableDropdownItem<String>(value: 'inspection', label: isArabic ? 'جهة فحص ومعاينة' : 'Inspection Agency'),
                  SearchableDropdownItem<String>(value: 'insurance', label: isArabic ? 'شركة تأمين بحري' : 'Marine Insurance'),
                ],
                onChanged: isEditMode ? null : onPartnerTypeChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: invoiceNumberCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الفاتورة *' : 'Invoice Number *',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: partnerNameCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الشريك اللوجستي *' : 'Partner Name *',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Shipment, B/L, Currency, and CBE Exchange Rate Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: shipmentIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الشحنة *' : 'Shipment ID *',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) onShipmentIdChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: blNumberCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم البوليصة' : 'B/L Number',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onBlNumberChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: SearchableDropdownField<String>(
                value: currency,
                labelText: isArabic ? 'العملة' : 'Currency',
                decoration: InputDecoration(
                  labelText: isArabic ? 'العملة' : 'Currency',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  SearchableDropdownItem<String>(value: 'USD', label: 'USD'),
                  SearchableDropdownItem<String>(value: 'EUR', label: 'EUR'),
                  SearchableDropdownItem<String>(value: 'GBP', label: 'GBP'),
                  SearchableDropdownItem<String>(value: 'EGP', label: 'EGP'),
                ],
                onChanged: onCurrencyChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextFormField(
                key: ValueKey('exchange_rate_$exchangeRate'),
                initialValue: exchangeRate.toString(),
                decoration: InputDecoration(
                  labelText: isArabic ? 'سعر الصرف' : 'Exchange Rate',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.sync, size: 16),
                    tooltip: isArabic ? 'جلب سعر البنك المركزي' : 'Fetch CBE Rate',
                    onPressed: onFetchCbeRate,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final r = double.tryParse(v);
                  if (r != null) onExchangeRateChanged(r);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
