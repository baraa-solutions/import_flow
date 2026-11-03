import 'package:flutter/material.dart';
import 'extractor_controllers.dart';

class ExtractorInspectionAgencyFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorInspectionAgencyFields({
    super.key,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = controllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c.companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة الفحص والمعاينة بالإنجليزية *' : 'Inspection & Testing Agency Name *',
            prefixIcon: const Icon(Icons.fact_check_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم جهة الفحص مطلوب' : 'Inspection agency name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الاعتماد والتسجيل بالرقابة على الصادرات' : 'GOIEC Accreditation & ISO Number',
                  prefixIcon: const Icon(Icons.verified_user_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.inspectionScopeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'نطاق الفحص والاختبارات المعتمدة *' : 'Accredited Inspection Scope & Tests *',
                  prefixIcon: const Icon(Icons.biotech_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المعامل والمقر الإقليمي' : 'Laboratories & Regional Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول المعاينة والمدير الفني' : 'Technical Director & Lead Inspector',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف' : 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للشهادات والتقارير *' : 'Certificates & Reports Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
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
      ],
    );
  }
}

class ExtractorInsuranceCompanyFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorInsuranceCompanyFields({
    super.key,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = controllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c.companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم شركة التأمين بالإنجليزية *' : 'Marine Insurance Company Name *',
            prefixIcon: const Icon(Icons.security_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة التأمين مطلوب' : 'Insurance company name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم ترخيص هيئة الرقابة المالية' : 'FRA Insurance License Number',
                  prefixIcon: const Icon(Icons.verified_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.policyTermsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'شروط ووثائق التأمين البحري المغطاة *' : 'Marine Cargo Coverage & Policy Terms *',
                  prefixIcon: const Icon(Icons.shield_outlined, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المقر الرئيسي وفروع التأمين البحري' : 'Headquarters & Marine Branches Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مسؤول الاكتتاب البحري والتعويضات' : 'Marine Underwriter & Claims Officer',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الخط الساخن ورقم الهاتف' : 'Hotline & Phone Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للوثائق والمطالبات *' : 'Policies & Claims Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
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
      ],
    );
  }
}

class ExtractorBankFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorBankFields({
    super.key,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final c = controllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c.companyNameCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'اسم البنك المصرفي بالإنجليزية *' : 'Bank Name *',
            prefixIcon: const Icon(Icons.account_balance_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم البنك مطلوب' : 'Bank name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.swiftCodeCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'SWIFT / BIC Code *',
                  prefixIcon: Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.blue),
                  hintText: 'e.g. CIBEGGCAXXX',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'كود السويفت مطلوب' : 'SWIFT code is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.branchNameCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'اسم الفرع المعتمد *' : 'Authorized Branch Name *',
                  prefixIcon: const Icon(Icons.store_rounded, size: 18),
                  hintText: isArabic ? 'الفرع الرئيسي للشركات' : 'Main Corporate Branch',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المقر والفرع' : 'Branch & Headquarters Address',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'هاتف الاعتمادات المستندية' : 'Trade Finance & LC Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'البريد الإلكتروني للفرع' : 'Branch Operations Email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
