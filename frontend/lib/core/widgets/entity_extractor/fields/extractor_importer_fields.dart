import 'package:flutter/material.dart';

import '../../app_date_picker_field.dart';
import '../extractor_controllers.dart';
import 'extractor_bank_details_section.dart';
import 'extractor_trademark_section.dart';

/// Editable fields for extracting and updating Importer details.
class ExtractorImporterFields extends StatefulWidget {
  final ExtractorControllers controllers;

  const ExtractorImporterFields({
    super.key,
    required this.controllers,
  });

  @override
  State<ExtractorImporterFields> createState() => _ExtractorImporterFieldsState();
}

class _ExtractorImporterFieldsState extends State<ExtractorImporterFields> {
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
            labelText: isArabic ? 'اسم الشركة المستوردة *' : 'Company Name *',
            prefixIcon: const Icon(Icons.business_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? (isArabic ? 'اسم الشركة مطلوب' : 'Company name is required')
              : null,
        ),
        const SizedBox(height: 10),
        // Address & Country
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: c.addressCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'العنوان المسجل للشركة *' : 'Registered Address *',
                  prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'العنوان مطلوب' : 'Address is required')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: c.countryCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الدولة *' : 'Country *',
                  prefixIcon: const Icon(Icons.flag_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Importer Card ID & Expiry
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.importerCardCtrl,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'رقم البطاقة الاستيرادية المكون من 9 أرقام *'
                      : 'Importer Card ID (9 digits) *',
                  prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'البطاقة الاستيرادية مطلوبة' : 'Importer card is required')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDatePickerField(
                label: isArabic ? 'تاريخ انتهاء البطاقة الاستيرادية *' : 'Importer Card Expiry Date *',
                value: c.importerIdExpiry,
                isRequired: true,
                onChanged: (picked) {
                  if (picked != null) setState(() => c.importerIdExpiry = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // VAT Registration ID & Expiry
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.taxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'رقم التسجيل الضريبي والقيمة المضافة المكون من 9 أرقام *'
                      : 'VAT Registration ID (9 digits) *',
                  prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'الرقم الضريبي مطلوب' : 'Tax ID is required')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDatePickerField(
                label: isArabic ? 'تاريخ انتهاء التسجيل الضريبي *' : 'VAT Registration Expiry Date *',
                value: c.vatIdExpiry,
                isRequired: true,
                onChanged: (picked) {
                  if (picked != null) setState(() => c.vatIdExpiry = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Commercial Reg # & Expiry
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم السجل التجاري المكون من 15 رقماً *' : 'Commercial Reg # (15 digits) *',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isArabic ? 'السجل التجاري مطلوب' : 'Commercial register is required')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDatePickerField(
                label: isArabic ? 'تاريخ انتهاء السجل التجاري *' : 'Commercial Reg Expiry Date *',
                value: c.registrationExpiry,
                isRequired: true,
                onChanged: (picked) {
                  if (picked != null) setState(() => c.registrationExpiry = picked);
                },
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
                  labelText: isArabic ? 'رقم الهاتف' : 'Primary Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.mobileCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم المحمول' : 'Mobile Number',
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
        // Primary Email, Secondary Email, Website
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني الرسمي' : 'Official Email Address',
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
                  labelText: isArabic ? 'البريد الإلكتروني الثانوي' : 'Secondary Email',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
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
        // Legal Representative / Manager & Nafeza Token
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الممثل القانوني / مدير الاستيراد' : 'Legal Representative / Manager',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.nafezaTokenCtrl,
                obscureText: !c.showNafezaToken,
                decoration: InputDecoration(
                  labelText: isArabic ? 'معرف توكن نافذة المعتمد' : 'Nafeza E-Token ID',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18, color: Colors.blue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      c.showNafezaToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    tooltip: isArabic
                        ? (c.showNafezaToken ? 'إخفاء' : 'إظهار')
                        : (c.showNafezaToken ? 'Hide' : 'Show'),
                    onPressed: () => setState(() => c.showNafezaToken = !c.showNafezaToken),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Customs Bank Details
        ExtractorBankDetailsSection(
          controllers: c,
          titleAr: 'بيانات البنك المعتمد للتعاملات الجمركية',
          titleEn: 'Bank & Customs Account Details',
        ),
        const SizedBox(height: 10),
        // Trademark Section
        ExtractorTrademarkSection(controllers: c),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.notesCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'ملاحظات إضافية' : 'Additional Notes',
            prefixIcon: const Icon(Icons.notes_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}
