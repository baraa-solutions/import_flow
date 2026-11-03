class TariffParseResult {
  final Map<String, dynamic>? tariffData;
  final List<Map<String, dynamic>> agreements;
  final String? error;

  const TariffParseResult({
    this.tariffData,
    this.agreements = const [],
    this.error,
  });
}

class TariffLocalParser {
  static TariffParseResult parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TariffParseResult();
    }

    try {
      // 1. HS Code
      final hsMatch = RegExp(r'رقم\s*البند\s*:\s*([\d\.\s]+)').firstMatch(trimmed) ??
          RegExp(r'\b(\d{8,10})\b').firstMatch(trimmed);
      final hsCodeVal = hsMatch != null ? hsMatch.group(1)!.replaceAll('.', '').trim() : '';

      // 2. Description
      final descMatch = RegExp(r'نص\s*البند\s*:\s*(.*?)(?=\n\s*الضرائب|\n\s*المستندات|$)', dotAll: true).firstMatch(trimmed);
      final descVal = descMatch != null ? descMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim() : 'بند جمركي';

      // 3. Duty Rate
      final dutyMatch = RegExp(r'ضريبة\s*الوارد\s*\(\s*النظام\s*الاساسي\s*\)\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed) ??
          RegExp(r'ضريبة\s*الوارد\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
      final dutyVal = dutyMatch != null ? (double.tryParse(dutyMatch.group(1)!) ?? 0.0) : 0.0;

      // 4. VAT Rate
      final vatMatch = RegExp(r'ضريبة\s*قيمه\s*مضافه\s*:\s*([\d\.]+)\s*%|ضريبة\s*القيمة\s*المضافة\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
      final vatVal = vatMatch != null ? (double.tryParse(vatMatch.group(1) ?? vatMatch.group(2) ?? '14.0') ?? 14.0) : 14.0;

      // 5. Schedule Tax Rate
      final schedMatch = RegExp(r'ضريبة\s*الجدول\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
      final schedVal = schedMatch != null ? (double.tryParse(schedMatch.group(1)!) ?? 0.0) : 0.0;

      // 6. Development Fee
      final devMatch = RegExp(r'رسم\s*التنمية\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
      final devVal = devMatch != null ? (double.tryParse(devMatch.group(1)!) ?? 0.0) : 0.0;

      // 7. Import Fee
      final impMatch = RegExp(r'رسم\s*الوارد\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
      final impVal = impMatch != null ? (double.tryParse(impMatch.group(1)!) ?? 0.0) : 0.0;

      // 8. Documents & Prior Approvals
      final List<String> priorList = [];
      final List<String> authorities = [];
      bool reqInspection = false;

      final docSectionMatch = RegExp(r'المستندات\s*والأعمال\s*:(.*)', dotAll: true).firstMatch(trimmed);
      final List<Map<String, dynamic>> extractedAgreements = [];

      if (docSectionMatch != null) {
        final lines = docSectionMatch.group(1)!.split('\n');
        final List<String> consolidated = [];
        List<String> block = [];
        for (var l in lines) {
          final ls = l.trim();
          if (ls.isEmpty) {
            if (block.isNotEmpty) {
              consolidated.add(block.join(' '));
              block = [];
            }
          } else if (ls.startsWith('ر') || ls.startsWith('ق')) {
            if (block.isNotEmpty) {
              consolidated.add(block.join(' '));
              block = [];
            }
            block.add(ls);
          } else {
            block.add(ls);
          }
        }
        if (block.isNotEmpty) consolidated.add(block.join(' '));

        for (var dline in consolidated) {
          if (dline.startsWith('ق') || dline.contains('لايصرح') || dline.contains('لايفرج') || dline.contains('يشترط') || dline.contains('لا يتم استيراد')) {
            priorList.add(dline);
            reqInspection = true;
          }
          if (dline.contains('هـ .ع.ص.و') || dline.contains('هـ.ع.ص.و') || dline.contains('الصادرات والواردات')) {
            if (!authorities.contains('الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)')) {
              authorities.add('الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)');
            }
          }
          if (dline.contains('البيئة') || dline.contains('الأوزون') || dline.contains('الاوزون')) {
            if (!authorities.contains('جهاز شئون البيئة (EEAA)')) {
              authorities.add('جهاز شئون البيئة (EEAA)');
            }
          }

          if (dline.startsWith('ر') || dline.contains('اتفاقية') || dline.contains('تخفض') || dline.contains('يعفى')) {
            final notMatch = RegExp(r'(ر\d{4,5})').firstMatch(dline);
            final pubNotice = notMatch?.group(1);

            String name = 'اتفاقية تفضيلية (${pubNotice ?? "خاصة"})';
            String countries = 'OTHER';
            String doc = 'شهادة منشأ تفضيلية معتمدة';
            double? prefRate;

            if (dline.contains('صربيا')) {
              name = 'اتفاقية صربيا للتجارة الحرة';
              countries = 'RS';
              doc = 'شهادة منشأ صربية / EUR.1';
              prefRate = (dutyVal * 0.90);
            } else if (dline.contains('المملكة المتحدة')) {
              name = 'اتفاقية الشراكة المصرية والمملكة المتحدة (UK Partnership)';
              countries = 'GB';
              doc = 'شهادة منشأ المملكة المتحدة / EUR.1';
              prefRate = 0.0;
            } else if (dline.contains('ميركسور')) {
              name = 'اتفاقية أمريكا اللاتينية الميركسور (Mercosur)';
              countries = 'BR,AR,UY,PY';
              doc = 'شهادة منشأ اتفاقية الميركسور';
            } else if (dline.contains('تركيا')) {
              name = 'اتفاقية التجارة الحرة مع تركيا (Turkey FTA)';
              countries = 'TR';
              doc = 'شهادة EUR.1';
              prefRate = 0.0;
            } else if (dline.contains('الافتا') || dline.contains('الإفتا')) {
              name = 'اتفاقية دول الإفتا (EFTA)';
              countries = 'IS,LI,NO,CH';
              doc = 'شهادة EUR.1 / EFTA';
              prefRate = 0.0;
            } else if (dline.contains('أوربية') || dline.contains('أوروبية')) {
              name = 'اتفاقية الشراكة الأوروبية (EU Partnership)';
              countries = 'DE,FR,IT,ES,NL,BE,AT,SE,DK,FI,GR,PT,IE,PL,CZ,HU,RO,BG,HR,SK,SI,CY,MT,EE,LV,LT';
              doc = 'شهادة EUR.1';
              prefRate = 0.0;
            }

            extractedAgreements.add({
              'hs_code': hsCodeVal,
              'agreement_name': name,
              'reduction_type': prefRate == 0.0 ? 'full_duty_exemption' : 'percentage_of_duty',
              'reduction_percentage': prefRate == 0.0 ? 1.0 : (dline.contains('10%') ? 0.10 : 1.0),
              'preferential_duty_rate': prefRate,
              'publication_notice': pubNotice,
              'required_document': doc,
              'origin_countries': countries,
              'conditions_note': dline,
            });
          }
        }
      }

      final priorNote = priorList.isNotEmpty ? priorList.join('\n\n') : null;
      final authVal = authorities.isNotEmpty
          ? authorities.join(' / ')
          : (reqInspection ? 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)' : null);

      return TariffParseResult(
        tariffData: {
          'hs_code': hsCodeVal,
          'hs_description': descVal,
          'customs_category': (descVal.contains('آلات') || descVal.contains('أجهزة') || descVal.contains('تكييف')) ? 'MACHINERY_EQUIPMENT' : 'GENERAL_GOODS',
          'customs_duty_rate': dutyVal,
          'vat_rate': vatVal,
          'schedule_tax_rate': schedVal,
          'development_fee_rate': devVal,
          'import_fee_rate': impVal,
          'customs_service_fee_rate': 1.0,
          'requires_coo': true,
          'requires_inspection': reqInspection,
          'requires_acid': true,
          'regulatory_authority': authVal,
          'prior_approval_note': priorNote,
        },
        agreements: extractedAgreements,
      );
    } catch (e) {
      return TariffParseResult(error: 'تعذر استخراج بيانات البند: $e');
    }
  }
}
