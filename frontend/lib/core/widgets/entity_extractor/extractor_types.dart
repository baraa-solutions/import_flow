import 'package:flutter/material.dart';

enum EntityTarget {
  supplier,
  company,
  customsBroker,
  shippingLine,
  freightForwarder,
  inlandTransport,
  inspectionAgency,
  insuranceCompany,
  bank,
  partner,
}

const List<Map<String, String>> kExtractorCountryList = [
  {'name': 'China (CN)', 'code': 'CN'},
  {'name': 'Egypt (EG)', 'code': 'EG'},
  {'name': 'United States (US)', 'code': 'US'},
  {'name': 'Germany (DE)', 'code': 'DE'},
  {'name': 'Italy (IT)', 'code': 'IT'},
  {'name': 'Turkey (TR)', 'code': 'TR'},
  {'name': 'United Arab Emirates (AE)', 'code': 'AE'},
  {'name': 'Saudi Arabia (SA)', 'code': 'SA'},
  {'name': 'India (IN)', 'code': 'IN'},
  {'name': 'United Kingdom (GB)', 'code': 'GB'},
  {'name': 'Spain (ES)', 'code': 'ES'},
  {'name': 'France (FR)', 'code': 'FR'},
  {'name': 'Japan (JP)', 'code': 'JP'},
  {'name': 'South Korea (KR)', 'code': 'KR'},
  {'name': 'Russia (RU)', 'code': 'RU'},
  {'name': 'Brazil (BR)', 'code': 'BR'},
];

String getTargetName(BuildContext context, EntityTarget t) {
  final isArabic = Directionality.of(context) == TextDirection.rtl;
  switch (t) {
    case EntityTarget.supplier:
      return isArabic ? 'المورد الأجنبي' : 'Foreign Supplier';
    case EntityTarget.company:
      return isArabic ? 'الشركة المستوردة' : 'Importing Company';
    case EntityTarget.customsBroker:
      return isArabic ? 'المخلص الجمركي' : 'Customs Broker';
    case EntityTarget.shippingLine:
      return isArabic ? 'الخط الملاحي' : 'Shipping Line';
    case EntityTarget.freightForwarder:
      return isArabic ? 'شركة الشحن الدولي' : 'Freight Forwarder';
    case EntityTarget.inlandTransport:
      return isArabic ? 'الناقل البري' : 'Inland Transport';
    case EntityTarget.inspectionAgency:
      return isArabic ? 'جهة الفحص والمعاينة' : 'Inspection Agency';
    case EntityTarget.insuranceCompany:
      return isArabic ? 'شركة التأمين' : 'Insurance Company';
    case EntityTarget.bank:
      return isArabic ? 'البنك المصرفي' : 'Authorized Bank';
    case EntityTarget.partner:
      return isArabic ? 'الشريك اللوجستي' : 'Logistics Partner';
  }
}

String getModuleForTarget(EntityTarget t) {
  switch (t) {
    case EntityTarget.supplier:
      return 'supplier-entity';
    case EntityTarget.company:
      return 'import-company-entity';
    case EntityTarget.customsBroker:
      return 'customs-broker-entity';
    case EntityTarget.shippingLine:
      return 'shipping-line-entity';
    case EntityTarget.freightForwarder:
      return 'freight-forwarder-entity';
    case EntityTarget.inlandTransport:
      return 'inland-transport-entity';
    case EntityTarget.inspectionAgency:
      return 'inspection-agency-entity';
    case EntityTarget.insuranceCompany:
      return 'insurance-company-entity';
    case EntityTarget.bank:
      return 'bank-entity';
    case EntityTarget.partner:
      return 'partner-entity';
  }
}

IconData getTargetIcon(EntityTarget target) {
  switch (target) {
    case EntityTarget.supplier:
      return Icons.public;
    case EntityTarget.company:
      return Icons.domain_rounded;
    case EntityTarget.customsBroker:
      return Icons.badge_rounded;
    case EntityTarget.shippingLine:
      return Icons.directions_boat_rounded;
    case EntityTarget.freightForwarder:
      return Icons.local_shipping_rounded;
    case EntityTarget.inlandTransport:
      return Icons.fire_truck_rounded;
    case EntityTarget.inspectionAgency:
      return Icons.fact_check_rounded;
    case EntityTarget.insuranceCompany:
      return Icons.security_rounded;
    case EntityTarget.bank:
      return Icons.account_balance;
    case EntityTarget.partner:
      return Icons.handshake;
  }
}

String getPlaceholderForTarget(EntityTarget target, bool isArabic) {
  if (isArabic) {
    switch (target) {
      case EntityTarget.supplier:
        return 'الصق هنا ترويسة الفاتورة المبدئية أو كارت المورد الأجنبي:\n\nمثال:\nشركة شينخوا العالمية للنسيج المحدودة\nعنوان المصنع: طريق كانغ شينغ، تشانغشو، الصين\nالرقم الضريبي: 91320581MA1X7... كود كارجو إكس: 0x71C8a9...\nالهاتف: +86-512-52889988\nالبريد الإلكتروني: export@yuheng.com\nكود السويفت: BKCHCNBJ920';
      case EntityTarget.company:
        return 'الصق هنا بيانات الشركة المستوردة أو السجل التجاري والبطاقة الضريبية:\n\nمثال:\nشركة النيل للاستيراد والتصدير ش.م.م\nالعنوان: 15 شارع مصدق، الدقي، الجيزة، مصر\nالسجل التجاري: 184520 | البطاقة الاستيرادية: 489201\nالرقم الضريبي: 200-183-044\nالهاتف: +20 2 3762 1000 | البريد: info@nile-import.com\nتوكن نافذة: NFT-88921-EG';
      case EntityTarget.customsBroker:
        return 'الصق هنا كارت أو بيانات مكتب التخليص الجمركي:\n\nمثال:\nمكتب الأهرام للتخليص الجمركي والخدمات اللوجستية\nالعنوان: 14 شارع السلطان حسين، الإسكندرية، مصر\nرقم رخصة التخليص: 14820-2021 | الرقم الضريبي: 312-884-912\nموانئ العمل: ميناء الإسكندرية، الدخيلة، السخنة، دمياط\nمسؤول التخليص: طارق محمود (01001234567)\nالبريد: clearance@ahram-customs.com | الهاتف: 034876000';
      case EntityTarget.shippingLine:
        return 'الصق هنا بيانات الخط الملاحي والناقل البحري:\n\nمثال:\nشركة هاباج لويد للملاحة البحرية\nكود سكاك: HLCU\nالبريد الإلكتروني: egypt@hlag.com | الهاتف: +20 2 2696 4500\nالعنوان: مجمع سيتي ستارز، مبنى 3، مصر الجديدة، القاهرة';
      case EntityTarget.freightForwarder:
        return 'الصق هنا بيانات شركة الشحن الدولي:\n\nمثال:\nشركة أبيكس العالمية للشحن والتفريغ المحدودة\nالسجل التجاري: 294810 | رخصة فياتا: EG-7721\nخدمات الشحن: شحن بحري كلي وجزئي، شحن جوي، نقل متعدد الوسائط\nمسؤول التسعير: كريم نبيل (01223456789)\nالبريد: pricing@apex-freight.com | الهاتف: 0222998877\nالعنوان: 22 شارع حسن علام، مصر الجديدة، القاهرة';
      case EntityTarget.inlandTransport:
        return 'الصق هنا بيانات شركة النقل البري والأسطول:\n\nمثال:\nشركة الرواد للنقل الثقيل وخدمات الأسطول\nترخيص النقل: TR-88412 | الرقم الضريبي: 412-990-123\nأنواع الأسطول: تريلات حاويات، سطحات 40 قدم، لوابد، مبردات\nمسؤول الحركة: مصطفى جمال (01118889999 - على مدار الساعة)\nالبريد: dispatch@rowad-transport.com\nالجراج: قطعة 4، المنطقة الصناعية، العاشر من رمضان';
      case EntityTarget.inspectionAgency:
        return 'الصق هنا بيانات شركة الفحص والمعاينة:\n\nمثال:\nالشركة الدولية للفحص والمعاينة وإصدار الشهادات\nرقم الاعتماد: GOIEC-REG-4412 أو أيزو 17020\nنطاق الفحص: فحص ما قبل الشحن، شهادات المطابقة، تحاليل كيميائية\nمسؤول المعاينة: م. حسام فاروق (01025554433)\nالبريد: egypt.industrial@sgs.com | الهاتف: 034887766\nالعنوان: المنطقة الحرة، ميناء الإسكندرية';
      case EntityTarget.insuranceCompany:
        return 'الصق هنا بيانات شركة التأمين البحري:\n\nمثال:\nشركة مصر للتأمين - قطاع التأمين البحري وجسم السفن\nترخيص الرقابة المالية: INS-001 | الرقم الضريبي: 100-200-300\nمسؤول الاكتتاب: أيمن حلمي (01007776655)\nالخط الساخن: 19990 | البريد: marine.cargo@misr-ins.com.eg\nالتغطية: شروط مجمع مكتتبي التأمين في لندن (أ) - كافة الأخطار والحروب والإضرابات\nالعنوان: 7 شارع طلعت حرب، وسط البلد، القاهرة';
      case EntityTarget.bank:
        return 'الصق هنا بيانات البنك المصرفي والسويفت كود:\n\nمثال:\nالبنك الأهلي المصري\nكود السويفت: NBEGEGCX001\nكود البنك: NBE-001 | الفرع: فرع الشركات الرئيسي\nمسؤول العمليات: أحمد سالم\nالهاتف: +20 2 2594 5000 | البريد: corporate@nbe.com.eg\nالعنوان: 1187 كورنيش النيل، القاهرة، مصر';
      case EntityTarget.partner:
        return 'الصق هنا بيانات الشريك اللوجستي...';
    }
  } else {
    switch (target) {
      case EntityTarget.supplier:
        return 'Paste proforma invoice header or supplier business card text here:\n\nExample:\nSuzhou Yuheng Textile Co., Ltd\nFactory Address: No.16, Kangsheng Road, Changshu, Jiangsu, China\nVAT Number: 91320581MA1X7... CargoX ID: 0x71C8a9...\nTel: +86-512-52889988\nEmail: export@yuheng.com\nSWIFT: BKCHCNBJ920';
      case EntityTarget.company:
        return 'Paste importing company registration or tax card text here:\n\nExample:\nNile Import & Export SAE\nAddress: 15 Mossadak St., Dokki, Giza, Egypt\nCommercial Reg: 184520 | Importer Card: 489201\nTax ID: 200-183-044\nPhone: +20 2 3762 1000 | Email: info@nile-import.com\nNafeza Token: NFT-88921-EG';
      case EntityTarget.customsBroker:
        return 'Paste customs broker card or agency details here:\n\nExample:\nAl-Ahram Customs Clearance & Logistics Office\nAddress: 14 El-Sultan Hussein St., Alexandria, Egypt\nCustoms License No: 14820/2021 | Tax ID: 312-884-912\nOperating Ports: Alexandria Port, Dekheila, Sokhna, Damietta\nContact: Customs Specialist Tarek Mahmoud (+20 100 123 4567)\nEmail: clearance@ahram-customs.com | Tel: +20 3 487 6000';
      case EntityTarget.shippingLine:
        return 'Paste shipping line or carrier details here:\n\nExample:\nHapag-Lloyd AG\nSCAC Code: HLCU\nTracking URL: https://www.hapag-lloyd.com/en/online-business/track/track-by-booking-solution.html\nWebsite: https://www.hapag-lloyd.com\nEmail: egypt@hlag.com | Tel: +20 2 2696 4500\nAddress: Citystars Complex, Building 3, Heliopolis, Cairo, Egypt';
      case EntityTarget.freightForwarder:
        return 'Paste freight forwarder company details here:\n\nExample:\nApex Global Freight Forwarding Ltd\nCommercial Register: 294810 | FIATA ID: EG-7721\nServices: Ocean FCL/LCL, Air Cargo, Multimodal Transport\nContact: Pricing Manager Karim Nabil (+20 122 345 6789)\nEmail: pricing@apex-freight.com | Web: https://www.apex-freight.com\nAddress: 22 Hassan Allam St., Heliopolis, Cairo, Egypt';
      case EntityTarget.inlandTransport:
        return 'Paste inland transport & fleet company details here:\n\nExample:\nAl-Rowad Heavy Inland Transport & Fleet Services\nTransport License: TR-88412 | Tax ID: 412-990-123\nFleet Types: Container Chassis, 40ft Flatbed, Lowbed, Refrigerated\nOperations Dispatcher: Mostafa Gamal (+20 111 888 9999 - 24/7)\nEmail: dispatch@rowad-transport.com\nGarage & Hub: Plot 4, 10th of Ramadan Industrial Zone, Egypt';
      case EntityTarget.inspectionAgency:
        return 'Paste inspection & testing agency details here:\n\nExample:\nSGS Egypt International Inspection & Testing\nAccreditation No: GOIEC-REG-4412 / ISO 17020\nScope: Pre-Shipment Inspection (PSI), Verification of Conformity (VOC), Chemical Testing\nContact: Eng. Hossam Farouk (+20 102 555 4433)\nEmail: egypt.industrial@sgs.com | Web: https://www.sgs.com\nAddress: Alexandria Port Free Zone / Cairo Industrial Hub';
      case EntityTarget.insuranceCompany:
        return 'Paste marine cargo insurance company details here:\n\nExample:\nMisr Insurance Company - Marine Hull & Cargo Department\nFRA Authority License: INS-001 | Tax ID: 100-200-300\nMarine Underwriting Specialist: Ayman Helmy (+20 100 777 6655)\nHotline: 19990 | Marine Email: marine.cargo@misr-ins.com.eg\nWeb: https://www.misr-ins.com.eg\nCoverage: Institute Cargo Clauses (A) - All Risks, War & Strikes\nAddress: 7 Talaat Harb St., Downtown, Cairo, Egypt';
      case EntityTarget.bank:
        return 'Paste bank & SWIFT code details here:\n\nExample:\nNational Bank of Egypt (NBE)\nSWIFT / BIC Code: NBEGEGCX001\nBank Code: NBE-001 | Branch: Corporate Main Branch\nContact: Trade Finance Officer Ahmed Salem\nPhone: +20 2 2594 5000 | Email: corporate@nbe.com.eg\nAddress: 1187 Corniche El-Nil, Cairo, Egypt';
      case EntityTarget.partner:
        return 'Paste partner data here...';
    }
  }
}
