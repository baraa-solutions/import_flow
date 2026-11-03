import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_date_picker_field.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/smart_upload_button.dart';
import '../../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../experience_guide/models/guide_entry_model.dart';
import '../../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../../import_companies/models/import_company_model.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../incoterms/models/incoterm_model.dart';
import '../../../projects/models/project_model.dart';
import '../../../suppliers/models/supplier_model.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../utils/po_payment_terms.dart';
import 'po_form_extractor.dart';

/// Commercial Header card containing PO reference, PI number, project,
/// importing company, supplier, incoterm, currency, FX rate, and payment terms.
class POFormHeaderCard extends ConsumerWidget {
  final GuideMatchResultModel? guideMatchResult;
  final List<ImportFileModel> importFiles;
  final List<ProjectModel> projects;
  final List<ImportCompanyModel> companies;
  final List<SupplierModel> suppliers;
  final List<IncotermModel> incoterms;
  final List<CurrencyModel> currencies;

  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;

  final TextEditingController poReferenceCtrl;
  final TextEditingController piCtrl;

  final DateTime orderDate;
  final ValueChanged<DateTime> onOrderDateChanged;

  final int? selectedProjectId;
  final ValueChanged<int?> onProjectChanged;

  final int? selectedCompanyId;
  final ValueChanged<int?> onCompanyChanged;

  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierChanged;

  final int? selectedIncotermId;
  final ValueChanged<int?> onIncotermChanged;

  final int? selectedCurrencyId;
  final ValueChanged<int?> onCurrencyChanged;

  final String? selectedCountryOfOrigin;
  final ValueChanged<String?> onCountryOfOriginChanged;

  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  final TextEditingController rateCtrl;
  final String? rateHelperText;

  final String? selectedPaymentTerms;
  final ValueChanged<String?> onPaymentTermsChanged;

  final ValueChanged<Map<String, dynamic>> onInvoiceDataExtracted;

  const POFormHeaderCard({
    super.key,
    required this.guideMatchResult,
    required this.importFiles,
    required this.projects,
    required this.companies,
    required this.suppliers,
    required this.incoterms,
    required this.currencies,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.poReferenceCtrl,
    required this.piCtrl,
    required this.orderDate,
    required this.onOrderDateChanged,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.selectedCompanyId,
    required this.onCompanyChanged,
    required this.selectedSupplierId,
    required this.onSupplierChanged,
    required this.selectedIncotermId,
    required this.onIncotermChanged,
    required this.selectedCurrencyId,
    required this.onCurrencyChanged,
    required this.selectedCountryOfOrigin,
    required this.onCountryOfOriginChanged,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.rateCtrl,
    required this.rateHelperText,
    required this.selectedPaymentTerms,
    required this.onPaymentTermsChanged,
    required this.onInvoiceDataExtracted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isArabic = l.isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (guideMatchResult != null && guideMatchResult!.matchedEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExperienceGuideAlertBanner(
              matchResult: guideMatchResult!,
            ),
          ),

        // Commercial Invoice Smart Extractor Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cobaltBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppTheme.cobalt, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'أداة قراءة واستخراج الفاتورة المبدئية' : 'Proforma Invoice Reader',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                    ),
                    Text(
                      isArabic
                          ? 'قم برفع الفاتورة المبدئية أو التجارية لاستخراج ترويسة الفاتورة والأسعار والبنود تلقائياً'
                          : 'Upload proforma/commercial invoice to extract header details, items and prices automatically',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SmartUploadButton(
                module: SmartUploadModule.commercialInvoice,
                compact: false,
                label: isArabic ? 'قراءة الفاتورة' : 'Read Invoice',
                onDataExtracted: (result) {
                  onInvoiceDataExtracted(result.extractedFields);
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(
                      context,
                      isArabic
                          ? 'تمت قراءة واستخراج بيانات الفاتورة المبدئية بنجاح'
                          : 'Proforma invoice extracted successfully',
                      severity: AppSeverity.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Import File Dropdown
        SearchableDropdownField<int?>(
          value: selectedImportFileId,
          labelText: isArabic ? 'ملف الشحنة الاستيرادية' : 'Import File',
          items: [
            SearchableDropdownItem<int?>(
              value: null,
              label: isArabic ? 'غير مرتبط بملف شحنة' : 'None / Unlinked',
            ),
            ...importFiles.map((f) => SearchableDropdownItem<int?>(
                  value: f.importFileId,
                  label: '${f.primaryNameWithCode} - ${f.companyName}',
                )),
          ],
          onChanged: onImportFileChanged,
        ),
        const SizedBox(height: 12),

        // PO Reference
        TextFormField(
          controller: poReferenceCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم أو مرجع أمر الشراء' : 'PO Reference / Name',
            hintText: isArabic ? 'مثال: وحدات تبريد مصنع الدلتا' : 'e.g. Delta Chiller Units 500kW',
            prefixIcon: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.cobalt, size: 18),
          ),
        ),
        const SizedBox(height: 12),

        // PI Number, Date, Project
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: piCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الفاتورة المبدئية' : 'Proforma Invoice #',
                  hintText: 'PI-2026-991',
                  prefixIcon: const Icon(Icons.receipt_long_outlined, color: AppTheme.cobalt, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppDatePickerField(
                label: isArabic ? 'تاريخ الفاتورة' : 'Invoice Date',
                value: orderDate,
                isRequired: true,
                allowClear: false,
                firstDate: DateTime(2000),
                lastDate: DateTime(2035),
                onChanged: (picked) {
                  if (picked != null) {
                    onOrderDateChanged(picked);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableDropdownField<int?>(
                value: selectedProjectId,
                labelText: isArabic ? 'المشروع' : 'Project',
                validator: (_) => selectedProjectId == null ? l.requiredField : null,
                items: projects
                    .map((p) => SearchableDropdownItem<int?>(
                          value: p.projectId,
                          label: '${p.projectCode} (${p.projectName})',
                        ))
                    .toList(),
                onChanged: onProjectChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Company and Supplier
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdownField<int?>(
                    value: selectedCompanyId,
                    labelText: isArabic ? 'الشركة المستوردة' : 'Importing Company',
                    validator: (_) => selectedCompanyId == null ? l.requiredField : null,
                    items: companies
                        .map((c) => SearchableDropdownItem<int?>(
                              value: c.companyId,
                              label: c.importerName,
                            ))
                        .toList(),
                    onChanged: onCompanyChanged,
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: () => UniversalEntityExtractorDialog.show(
                      context,
                      initialTarget: EntityTarget.company,
                      onSaved: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.domain_add, size: 13, color: AppTheme.cobalt),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isArabic ? '+ تكويد شركة مستوردة ذكياً' : '+ AI Import Company Coding',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdownField<int?>(
                    value: selectedSupplierId,
                    labelText: isArabic ? 'المورد الأجنبي' : 'Supplier',
                    validator: (_) => selectedSupplierId == null ? l.requiredField : null,
                    items: suppliers
                        .map((s) => SearchableDropdownItem<int?>(
                              value: s.supplierId,
                              label: s.companyName,
                            ))
                        .toList(),
                    onChanged: onSupplierChanged,
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: () => UniversalEntityExtractorDialog.show(
                      context,
                      initialTarget: EntityTarget.supplier,
                      onSaved: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 13, color: AppTheme.cobalt),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isArabic ? '+ تكويد مورد جديد ذكياً' : '+ AI Supplier Coding',
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Incoterm and Currency
        Row(
          children: [
            Expanded(
              child: SearchableDropdownField<int?>(
                key: ValueKey('incoterm_dropdown_${selectedIncotermId}_${incoterms.length}'),
                value: selectedIncotermId,
                labelText: isArabic ? 'شرط الشحن والتسليم' : 'Incoterm',
                validator: (_) => selectedIncotermId == null ? l.requiredField : null,
                items: incoterms
                    .map((i) => SearchableDropdownItem<int?>(
                          value: i.incotermId,
                          label: '${i.incotermCode} (${i.incotermName})',
                        ))
                    .toList(),
                onChanged: onIncotermChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableDropdownField<int?>(
                key: ValueKey('currency_dropdown_${selectedCurrencyId}_${currencies.length}'),
                value: selectedCurrencyId,
                labelText: isArabic ? 'العملة' : 'Currency',
                validator: (_) => selectedCurrencyId == null ? l.requiredField : null,
                items: currencies
                    .map((c) => SearchableDropdownItem<int?>(
                          value: c.currencyId,
                          label: '${c.currencyCode} (${c.currencyName})',
                        ))
                    .toList(),
                onChanged: onCurrencyChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Country of Origin and Status
        Row(
          children: [
            Expanded(
              child: SearchableDropdownField<String?>(
                value: selectedCountryOfOrigin,
                labelText: isArabic ? 'بلد المنشأ العام' : 'Country of Origin',
                items: [
                  if (selectedCountryOfOrigin != null)
                    SearchableDropdownItem<String?>(
                      value: null,
                      label: isArabic ? 'غير محدد' : 'Unspecified',
                    ),
                  ...PoFormExtractor.countryOptions.map((c) => SearchableDropdownItem<String?>(
                        value: c['name'],
                        label: isArabic ? c['nameAr']! : c['nameEn']!,
                      )),
                ],
                onChanged: onCountryOfOriginChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableDropdownField<String>(
                value: selectedStatus,
                labelText: l.status,
                items: [
                  for (final code in DomainEnums.codesOf(DomainEnumType.poStatus))
                    SearchableDropdownItem<String>(
                      value: code,
                      label: DomainEnums.label(l, DomainEnumType.poStatus, code),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onStatusChanged(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Exchange Rate and Payment Terms
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isArabic ? 'سعر الصرف' : 'Exchange Rate',
                  helperText: rateHelperText ?? l.poExchangeRateHelper,
                  helperStyle: rateHelperText != null
                      ? const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.w600)
                      : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l.poExchangeRateRequired;
                  }
                  final val = double.tryParse(v.trim());
                  if (val == null || val <= 0) {
                    return l.poExchangeRateRequired;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchableDropdownField<String>(
                value: selectedPaymentTerms,
                labelText: isArabic ? 'شروط السداد والدفع' : 'Payment Terms',
                validator: (_) =>
                    (selectedPaymentTerms == null || selectedPaymentTerms!.trim().isEmpty) ? l.requiredField : null,
                items: [
                  SearchableDropdownItem(
                    value: PoPaymentTerms.cashInAdvance,
                    label: isArabic ? 'تحويل بنكي مقدم' : 'Cash in Advance / SWIFT',
                  ),
                  SearchableDropdownItem(
                    value: PoPaymentTerms.letterOfCredit,
                    label: isArabic ? 'اعتماد مستندي' : 'Letter of Credit',
                  ),
                  SearchableDropdownItem(
                    value: PoPaymentTerms.cashAgainstDocuments,
                    label: isArabic ? 'تحصيل مستندي' : 'Cash Against Documents',
                  ),
                  SearchableDropdownItem(
                    value: PoPaymentTerms.openAccount,
                    label: isArabic ? 'حساب مفتوح' : 'Open Account',
                  ),
                ],
                onChanged: onPaymentTermsChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
