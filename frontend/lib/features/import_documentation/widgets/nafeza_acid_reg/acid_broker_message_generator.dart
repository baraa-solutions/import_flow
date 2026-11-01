class AcidBrokerMessageData {
  final String importerName;
  final String importerTaxId;
  final String importerAddress;
  final String exporterName;
  final String exporterRegId;
  final String exporterRegType;
  final String exporterCountry;
  final String exporterAddress;
  final String exporterPhone;
  final String cargoxId;
  final String proformaNo;
  final String proformaDate;
  final String invoiceType;
  final String poNo;
  final String polName;
  final String podName;
  final String customsBrokerName;
  final String requestedDate;

  const AcidBrokerMessageData({
    required this.importerName,
    required this.importerTaxId,
    required this.importerAddress,
    required this.exporterName,
    required this.exporterRegId,
    required this.exporterRegType,
    required this.exporterCountry,
    required this.exporterAddress,
    required this.exporterPhone,
    required this.cargoxId,
    required this.proformaNo,
    required this.proformaDate,
    required this.invoiceType,
    required this.poNo,
    required this.polName,
    required this.podName,
    required this.customsBrokerName,
    required this.requestedDate,
  });
}

class AcidBrokerMessageGenerator {
  static String buildWhatsAppMessage(AcidBrokerMessageData data) {
    final impName = data.importerName.isNotEmpty ? data.importerName : '-';
    final impTax = data.importerTaxId.isNotEmpty ? data.importerTaxId : '-';
    final impAddr = data.importerAddress.isNotEmpty ? data.importerAddress : '-';
    final expName = data.exporterName.isNotEmpty ? data.exporterName : '-';
    final expId = data.exporterRegId.isNotEmpty ? data.exporterRegId : '-';
    final expCountry = data.exporterCountry.isNotEmpty ? data.exporterCountry : '-';
    final expAddr = data.exporterAddress.isNotEmpty ? data.exporterAddress : '-';
    final expPhone = data.exporterPhone.isNotEmpty ? data.exporterPhone : '-';
    final cargox = data.cargoxId.isNotEmpty ? data.cargoxId : '-';
    final piNo = data.proformaNo.isNotEmpty ? data.proformaNo : '-';
    final piDate = data.proformaDate.isNotEmpty ? data.proformaDate : '-';
    final poNo = data.poNo.isNotEmpty ? data.poNo : '-';
    final pol = data.polName.isNotEmpty ? data.polName : '-';
    final pod = data.podName.isNotEmpty ? data.podName : '-';
    final reqDate = data.requestedDate.isNotEmpty ? data.requestedDate : '-';

    return '''📋 *طلب استخراج رقم ACID جديد*
━━━━━━━━━━━━━━━━━━━━
🏢 *المستورد المصري:* $impName
🔢 *البطاقة الضريبية:* $impTax
📍 *العنوان المسجل:* $impAddr

🌍 *المصدر الأجنبي:* $expName
🆔 *المعرف الضريبي / نوعه:* $expId (${data.exporterRegType})
🌐 *دولة المنشأ / التصدير:* $expCountry
📍 *عنوان المصدر:* $expAddr
📞 *هاتف المصدر:* $expPhone
🔑 *حساب كارجو إكس (CargoX ID):* $cargox

📄 *رقم الفاتورة المبدئية:* $piNo
📅 *تاريخ الفاتورة المبدئية:* $piDate
📑 *نوع الفاتورة:* ${data.invoiceType}
📦 *أمر الشراء (PO):* $poNo
🚢 *ميناء الشحن (POL):* $pol
⚓ *ميناء الوصول (POD):* $pod
📅 *تاريخ تقديم الطلب:* $reqDate
━━━━━━━━━━━━━━━━━━━━
⚠️ *ملاحظة:* يرجى مراجعة الفاتورة المبدئية وسرعة موافاتنا برقم الـ ACID فور صدوره مع خالص الشكر.''';
  }

  static String buildEmailMessage(AcidBrokerMessageData data) {
    final impName = data.importerName.isNotEmpty ? data.importerName : 'Import';
    final piNo = data.proformaNo.isNotEmpty ? data.proformaNo : '';
    final broker = data.customsBrokerName.isNotEmpty ? data.customsBrokerName : 'مكتب التخليص الجمركي';

    return '''الموضوع: طلب إصدار رقم ACID - شحنة $impName - فاتورة $piNo

السيد المخلص الجمركي المحترم / $broker
تحية طيبة وبعد،،،

يرجى التكرم ببدء إجراءات طلب واستخراج رقم القيد الجمركي المبدئي (ACID) عبر منظومة نافذة للشحنة الموضحة بياناتها أدناه:

1. بيانات المستورد المصري:
   - اسم المستورد: ${data.importerName}
   - الرقم الضريبي: ${data.importerTaxId}
   - العنوان: ${data.importerAddress}

2. بيانات المصدر الأجنبي:
   - اسم المصدر: ${data.exporterName}
   - نوع التسجيل والمعرف: ${data.exporterRegId} (${data.exporterRegType})
   - دولة المنشأ: ${data.exporterCountry}
   - عنوان المصدر: ${data.exporterAddress}
   - هاتف المصدر: ${data.exporterPhone}
   - كود كارجو إكس (CargoX): ${data.cargoxId}

3. بيانات الفاتورة والشحن:
   - رقم الفاتورة المبدئية: ${data.proformaNo}
   - تاريخ الفاتورة المبدئية: ${data.proformaDate}
   - أمر الشراء: ${data.poNo}
   - ميناء الشحن: ${data.polName}
   - ميناء الوصول: ${data.podName}

تجدون برفقه الفاتورة المبدئية للاطلاع والبدء في الإجراءات.
شاكرين لكم حسن تعاونكم الدائم.

قسم الاستيراد والتخليص الجمركي
Sorour Logistics ERP System''';
  }

  static String buildEnglishRequestMessage(AcidBrokerMessageData data) {
    final impName = data.importerName.isNotEmpty ? data.importerName : '-';
    final impTax = data.importerTaxId.isNotEmpty ? data.importerTaxId : '-';
    final impAddr = data.importerAddress.isNotEmpty ? data.importerAddress : '-';
    final expName = data.exporterName.isNotEmpty ? data.exporterName : '-';
    final expId = data.exporterRegId.isNotEmpty ? data.exporterRegId : '-';
    final expCountry = data.exporterCountry.isNotEmpty ? data.exporterCountry : '-';
    final expAddr = data.exporterAddress.isNotEmpty ? data.exporterAddress : '-';
    final expPhone = data.exporterPhone.isNotEmpty ? data.exporterPhone : '-';
    final cargox = data.cargoxId.isNotEmpty ? data.cargoxId : '-';
    final piNo = data.proformaNo.isNotEmpty ? data.proformaNo : '-';
    final piDate = data.proformaDate.isNotEmpty ? data.proformaDate : '-';
    final poNo = data.poNo.isNotEmpty ? data.poNo : '-';
    final pol = data.polName.isNotEmpty ? data.polName : '-';
    final pod = data.podName.isNotEmpty ? data.podName : '-';
    final reqDate = data.requestedDate.isNotEmpty ? data.requestedDate : '-';

    return '''📋 *Advance Cargo Information (ACID) Request*
━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏢 *Egyptian Importer:* $impName
🔢 *Tax ID:* $impTax
📍 *Registered Address:* $impAddr

🌍 *Foreign Exporter / Supplier:* $expName
🆔 *Exporter Reg. ID:* $expId (${data.exporterRegType})
🌐 *Country of Origin / Export:* $expCountry
📍 *Exporter Address:* $expAddr
📞 *Tel. / Mobile:* $expPhone
🔑 *CargoX Platform ID:* $cargox

📄 *Proforma Invoice No.:* $piNo
📅 *Proforma Invoice Date:* $piDate
📑 *Invoice Type:* ${data.invoiceType}
📦 *Purchase Order (PO):* $poNo
🚢 *Port of Loading (POL):* $pol
⚓ *Port of Discharge (POD):* $pod
📅 *Request Date:* $reqDate
━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Important Note:* Please initiate the ACID issuance on the Nafeza (MTS) portal and provide us with the 19-digit ACID number upon generation. Thank you.''';
  }
}
