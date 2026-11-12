import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';

class InvoiceFormBasicFields extends StatelessWidget {
  final bool isArabic;
  final bool isEditMode;
  final String partnerType;
  final ValueChanged<String?> onPartnerTypeChanged;
  final TextEditingController invoiceNumberCtrl;
  final TextEditingController partnerNameCtrl;
  /// Import file the invoice bills (logistics_service_invoices.shipment_id); null until picked.
  final int? shipmentId;
  final List<ImportFileModel> importFiles;
  final TextEditingController blNumberCtrl;
  final ValueChanged<int?> onShipmentIdChanged;
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
    required this.shipmentId,
    required this.importFiles,
    required this.blNumberCtrl,
    required this.onShipmentIdChanged,
    required this.onBlNumberChanged,
    required this.currency,
    required this.onCurrencyChanged,
    required this.exchangeRate,
    required this.onExchangeRateChanged,
    required this.onFetchCbeRate,
  });

  String? get _projectNames {
    final names = importFiles.where((f) => f.importFileId == shipmentId).firstOrNull?.projectNames?.trim();
    return names == null || names.isEmpty ? null : names;
  }

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<int>(
                    key: const ValueKey('invoiceImportFileField'),
                    value: shipmentId,
                    labelText: isArabic ? 'ملف الشحنة *' : 'Import File *',
                    hintText: isArabic ? 'اختر ملف الشحنة' : 'Select the import file',
                    isRequired: true,
                    validator: (v) => v == null ? (isArabic ? 'مطلوب' : 'Required') : null,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: f.importFileCode,
                              subtitle: f.supplierName,
                              searchValue: '${f.importFileCode} ${f.customFileNumber ?? ''} ${f.supplierName} '
                                  '${f.companyName} ${f.projectNames ?? ''}',
                            ))
                        .toList(),
                    onChanged: isEditMode ? null : onShipmentIdChanged,
                  ),
                  if (_projectNames != null) ...[
                    const SizedBox(height: 4),
                    AppStatusBadge(
                      key: const ValueKey('invoiceProjectBadge'),
                      label: '${isArabic ? 'المشروع / مركز التكلفة' : 'Project / Cost Center'}: $_projectNames',
                      severity: AppSeverity.info,
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ],
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
