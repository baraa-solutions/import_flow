import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../searchable_dropdown_field.dart';
import '../extractor_controllers.dart';
import '../extractor_types.dart';
import 'extractor_bank_details_section.dart';
import 'extractor_trademark_section.dart';

/// Editable fields for extracting and updating Foreign Supplier details.
class ExtractorSupplierFields extends StatefulWidget {
  final ExtractorControllers controllers;

  const ExtractorSupplierFields({
    super.key,
    required this.controllers,
  });

  @override
  State<ExtractorSupplierFields> createState() => _ExtractorSupplierFieldsState();
}

class _ExtractorSupplierFieldsState extends State<ExtractorSupplierFields> {
  static const supplierTypeOptions = [
    'Manufacturer',
    'Foreign Supplier / Trader',
    'Authorized Agent / Distributor',
    'Exporter',
  ];

  static const regTypeOptions = [
    'Factory Registration',
    'Foreign Exporter Number (Nafeza)',
    'Company Registration Number',
    'VAT Number',
    'Tax Number',
    'Commercial Register',
  ];

  String _getSupplierTypeLabel(String val, bool isArabic) {
    if (!isArabic) return val;
    switch (val) {
      case 'Manufacturer':
        return 'مصنع';
      case 'Foreign Supplier / Trader':
        return 'مورد أجنبي أو تاجر';
      case 'Authorized Agent / Distributor':
        return 'وكيل معتمد أو موزع';
      case 'Exporter':
        return 'مصدر';
      default:
        return val;
    }
  }

  String _getRegTypeLabel(String val, bool isArabic) {
    if (!isArabic) return val;
    switch (val) {
      case 'Factory Registration':
        return 'سجل مصنع';
      case 'Foreign Exporter Number (Nafeza)':
        return 'رقم المصدر الأجنبي بمنظومة نافذة';
      case 'Company Registration Number':
        return 'رقم تسجيل الشركة';
      case 'VAT Number':
        return 'رقم ضريبة القيمة المضافة';
      case 'Tax Number':
        return 'الرقم الضريبي';
      case 'Commercial Register':
        return 'السجل التجاري';
      default:
        return val;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = widget.controllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Name
        TextFormField(
          controller: c.companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم المورد الأجنبي بالإنجليزية *' : 'Foreign Supplier Name *',
            prefixIcon: const Icon(Icons.business_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? (isArabic ? 'اسم المورد مطلوب' : 'Supplier name is required')
              : null,
        ),
        const SizedBox(height: 10),
        // Supplier Type & Registration Type
        Row(
          children: [
            Expanded(
              child: SearchableDropdownField<String>(
                value: supplierTypeOptions.contains(c.supplierType) ? c.supplierType : supplierTypeOptions.first,
                labelText: isArabic ? 'نوع المورد *' : 'Supplier Type *',
                items: supplierTypeOptions
                    .map((type) =>
                        SearchableDropdownItem<String>(value: type, label: _getSupplierTypeLabel(type, isArabic)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => c.supplierType = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SearchableDropdownField<String>(
                value: regTypeOptions.contains(c.supplierRegType) ? c.supplierRegType : regTypeOptions.first,
                labelText: isArabic ? 'نوع السجل الأجنبي *' : 'Registration Type *',
                items: regTypeOptions
                    .map((type) => SearchableDropdownItem<String>(value: type, label: _getRegTypeLabel(type, isArabic)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => c.supplierRegType = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Foreign Exporter ID & CargoX ID
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.foreignTaxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'رقم السجل ومعرف المصدر الأجنبي بمنظومة نافذة *'
                      : 'Foreign Exporter ID (Nafeza) *',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'رقم السجل مطلوب' : 'Foreign Exporter ID is required')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.cargoxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'معرف منصة كارجو إكس المعتمد' : 'CargoX Platform Registered ID',
                  prefixIcon: const Icon(Icons.hub_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Country & Country Code
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: c.countryCtrl.text.isNotEmpty ? c.countryCtrl.text : 'China (CN)',
                labelText: isArabic ? 'الدولة والمنشأ *' : 'Country *',
                items: kExtractorCountryList
                    .map((country) => SearchableDropdownItem(value: country['name']!, label: country['name']!))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      c.countryCtrl.text = v;
                      final match = kExtractorCountryList.firstWhere((item) => item['name'] == v, orElse: () => {});
                      if (match.isNotEmpty) c.countryCodeCtrl.text = match['code']!;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: c.countryCodeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود الدولة المكون من حرفين *' : 'Country Code (ISO 2-letter) *',
                  prefixIcon: const Icon(Icons.code, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'كود الدولة مطلوب' : 'Country code is required')
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Full Address
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'العنوان الكامل للمصنع والمقر *' : 'Full Address *',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? (isArabic ? 'العنوان مطلوب' : 'Address is required')
              : null,
        ),
        const SizedBox(height: 10),
        // Primary & Secondary Email
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الرئيسي' : 'Primary Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الثانوي' : 'Secondary / Additional Email',
                  prefixIcon: const Icon(Icons.mark_email_read_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Phone, Mobile, Fax
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.mobileCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'المحمول ورقم التواصل' : 'Mobile Number',
                  prefixIcon: const Icon(Icons.smartphone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.faxCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الفاكس' : 'Fax',
                  prefixIcon: const Icon(Icons.print_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Contact Person & Website
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول التواصل والمبيعات' : 'Contact Person & Sales',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني' : 'Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Beneficiary Bank Details
        ExtractorBankDetailsSection(
          controllers: c,
          titleAr: 'بيانات البنك المستفيد والحساب المصرفي',
          titleEn: 'Beneficiary Bank Details',
        ),
        const SizedBox(height: 10),
        // Compliance Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(isArabic ? 'شهادة آيزو العالمية' : 'ISO Certified', style: const TextStyle(fontSize: 11)),
                    value: c.hasIso,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => c.hasIso = val ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(isArabic ? 'قرار 43' : 'Decree 43', style: const TextStyle(fontSize: 11)),
                    value: c.registeredDecree43,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) => setState(() => c.registeredDecree43 = val ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(isArabic ? 'القائمة البيضاء' : 'White List', style: const TextStyle(fontSize: 11)),
                    value: c.whiteListRegistered,
                    activeColor: AppTheme.emerald,
                    onChanged: (val) => setState(() => c.whiteListRegistered = val ?? false),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Trademark Certificates & ISO 9001
        ExtractorTrademarkSection(controllers: c),
        const SizedBox(height: 10),
        // Brands & Notes
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.brandsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'العلامات التجارية والمنتجات' : 'Brands & Products',
                  prefixIcon: const Icon(Icons.category_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.notesCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
