import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'extractor_controllers.dart';

class ExtractorCustomsBrokerFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorCustomsBrokerFields({
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
            labelText: isArabic ? 'اسم مكتب أو شركة التخليص الجمركي *' : 'Customs Brokerage Firm Name *',
            prefixIcon: const Icon(Icons.badge_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم المستخلص مطلوب' : 'Broker name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم رخصة التخليص الجمركي *' : 'Customs Broker License Number *',
                  prefixIcon: const Icon(Icons.assignment_ind_rounded, size: 18, color: Colors.blue),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'رقم الرخصة مطلوب' : 'License number is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.portsCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'موانئ ومواقع العمل الجمركي *' : 'Operating Ports & Customs Zones *',
                  prefixIcon: const Icon(Icons.anchor_rounded, size: 18),
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
                controller: c.taxIdCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الرقم الضريبي' : 'Tax ID',
                  prefixIcon: const Icon(Icons.pin_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'السجل التجاري' : 'Commercial Register',
                  prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المكتب والمقر الرئيسي' : 'Office Address & Headquarters',
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
                  labelText: isArabic ? 'المخلص الجمركي المعتمد والمسؤول' : 'Certified Customs Specialist',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف والمحمول' : 'Phone & Mobile Number',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.emailCtrl,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: isArabic ? 'البريد الإلكتروني للعمليات' : 'Operations Email Address',
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}

class ExtractorShippingLineFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorShippingLineFields({
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
            labelText: isArabic ? 'اسم الخط الملاحي بالإنجليزية *' : 'Shipping Line Carrier Name *',
            prefixIcon: const Icon(Icons.directions_boat_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم الخط الملاحي مطلوب' : 'Shipping line name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: c.scacCodeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'كود الناقل الملاحي المعتمد *' : 'SCAC Carrier Code *',
                  prefixIcon: const Icon(Icons.qr_code_rounded, size: 18, color: Colors.blue),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'كود الناقل الملاحي مطلوب' : 'SCAC code is required') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: c.trackingUrlCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رابط التتبع الحي للشحنات *' : 'Cargo Tracking Website URL *',
                  prefixIcon: const Icon(Icons.travel_explore_rounded, size: 18, color: Colors.blue),
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
                controller: c.websiteCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'الموقع الإلكتروني الرسمي' : 'Official Website URL',
                  prefixIcon: const Icon(Icons.language_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.emailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'بريد العمليات وخدمة العملاء *' : 'Operations & Customer Service Email *',
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
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
                controller: c.secondaryEmailCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: isArabic ? 'بريد الحجوزات الثانوي' : 'Secondary / Booking Email',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'أرقام هواتف وخدمة عملاء الوكيل' : 'Agency Customer Service & Phone',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عناوين مقرات الوكيل الملاحي في مصر' : 'Agency & Office Addresses',
            prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}

class ExtractorFreightForwarderFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorFreightForwarderFields({
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
            labelText: isArabic ? 'اسم شركة الشحن الدولي بالإنجليزية *' : 'Freight Forwarding Company Name *',
            prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة الشحن مطلوب' : 'Forwarder name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.commercialRegisterCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رخصة الفياتا والسجل التجاري' : 'FIATA License & Commercial Register',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.servicesScopeCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'مجالات وخطوط الشحن المغطاة' : 'Covered Freight Modes & Trade Lanes',
                  prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان المكتب والمقر الرئيسي' : 'Office Address & Headquarters',
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
                  labelText: isArabic ? 'مسؤول التسعير والعمليات' : 'Pricing & Operations Lead',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم الهاتف والمحمول' : 'Phone & Mobile Number',
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
                  labelText: isArabic ? 'بريد عروض الأسعار والعمليات *' : 'Pricing & Operations Email *',
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
        const SizedBox(height: 10),
        // Financial & Credit Conditions
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.charcoal),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'شروط الائتمان والعمليات المالية' : 'Credit Terms & Financial Conditions',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: c.defaultFreeDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'أيام السماح الافتراضية *' : 'Default Free Days *',
                        prefixIcon: const Icon(Icons.timer_outlined, size: 16),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'حقل إلزامي لحساب تاريخ الاستحقاق' : 'Required') : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: c.paymentTermsCtrl,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'شروط الدفع' : 'Payment Terms',
                        prefixIcon: const Icon(Icons.credit_card_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: c.creditLimitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isArabic ? 'الحد الائتماني' : 'Credit Limit',
                        prefixIcon: const Icon(Icons.monetization_on_outlined, size: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExtractorInlandTransportFields extends StatelessWidget {
  final ExtractorControllers controllers;

  const ExtractorInlandTransportFields({
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
            labelText: isArabic ? 'اسم شركة النقل البري بالإنجليزية *' : 'Inland Transport Company Name *',
            prefixIcon: const Icon(Icons.fire_truck_rounded, size: 18),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isArabic ? 'اسم شركة النقل مطلوب' : 'Transport company name is required') : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.brokerLicenseCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'رقم ترخيص النقل البري والسجل' : 'Transport License & Reg Number',
                  prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.fleetTypesCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'أنواع وتجهيزات أسطول الشاحنات *' : 'Fleet Types & Truck Equipment *',
                  prefixIcon: const Icon(Icons.view_carousel_rounded, size: 18, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.addressCtrl,
          decoration: InputDecoration(
            labelText: isArabic ? 'عنوان الجراج والمستودع الرئيسي ومناطق التغطية' : 'Central Garage & Depot Location',
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
                  labelText: isArabic ? 'مسؤول الحركة والتشغيل' : 'Fleet & Dispatch Coordinator',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: c.phoneCtrl,
                decoration: InputDecoration(
                  labelText: isArabic ? 'هاتف الطوارئ والتتبع على مدار الساعة *' : '24/7 Emergency & Tracking Phone *',
                  prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.emailCtrl,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: isArabic ? 'البريد الإلكتروني للتشغيل' : 'Operations Email Address',
            prefixIcon: const Icon(Icons.email_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}
