import '../../features/import_files/models/import_file_model.dart';

/// Single Central Service for Resolving Internal Codes to Human-Readable Names (Task D)
///
/// Used across:
/// 1. Screen UI (Dashboard cards, tables, escalation center, TO-DO lists, daily logs)
/// 2. Linked Outputs (TSV, CSV/Excel, Vector A4 PDF, Dossier clipboard export)
class DisplayNameResolver {
  // ── 1. Step / Operation Definitions ────────────────────────────────────────

  static const Map<String, Map<String, String>> _stepMap = {
    'STEP_01': {'ar': 'دراسات ومفاضلة النولون', 'en': 'Freight Studies'},
    'STEP_02': {'ar': 'الدراسات والاستشارات الجمركية', 'en': 'Customs Studies'},
    'STEP_03': {'ar': 'اشتراطات ومتطلبات الاستيراد', 'en': 'Import Requirements'},
    'STEP_04': {'ar': 'اعتماد الميزانية وصرف الدفعة', 'en': 'Budget Approval'},
    'STEP_05': {'ar': 'إصدار رقم التسجيل المسبق نافذة', 'en': 'Nafeza ACID Issue'},
    'STEP_06': {'ar': 'تأكيد الحجز الملاحي', 'en': 'Booking Confirmation'},
    'STEP_07': {'ar': 'تخصيص وتوزيع الحاويات والبضائع', 'en': 'Container Allocation'},
    'STEP_08': {'ar': 'مراجعة مسودات المستندات', 'en': 'Draft Review'},
    'STEP_08_PO': {'ar': 'مطابقة الفاتورة وقائمة التعبئة', 'en': 'PO & Packing Reconciliation'},
    'STEP_08_BL': {'ar': 'مراجعة مسودة بوليصة الشحن', 'en': 'Draft B/L Review'},
    'STEP_08_MATCH': {'ar': 'المطابقة الذكية للفاتورة والبوليصة', 'en': 'Invoice vs B/L Match'},
    'STEP_08_COO': {'ar': 'مسودة شهادة المنشأ و EUR.1', 'en': 'Draft COO & EUR.1'},
    'STEP_08_COC': {'ar': 'شهادات الفحص والمطابقة COC', 'en': 'Inspection Review COC'},
    'STEP_09': {'ar': 'الاعتماد النهائي للمستندات', 'en': 'Final Approval'},
    'STEP_10': {'ar': 'رفع التوثيق الإلكتروني للشاحن', 'en': 'CargoX Upload'},
    'STEP_11': {'ar': 'استلام وتدقيق أصول المستندات', 'en': 'Original Docs'},
    'STEP_12': {'ar': 'استخراج نموذج 4 البنكي', 'en': 'Bank Form 4'},
    'STEP_13': {'ar': 'قيد إقرار 46 ك.م جمركي', 'en': 'Form 46 KM'},
    'STEP_14': {'ar': 'الكشف والمعاينة والتثمين', 'en': 'Inspection & Valuation'},
    'STEP_15': {'ar': 'سحب العينات للجهات الرقابية', 'en': 'Sample Drawing'},
    'STEP_16': {'ar': 'تحرير محضر المعاينة الجمركية', 'en': 'Inspection Report'},
    'STEP_17': {'ar': 'سداد الضرائب والرسوم الجمركية', 'en': 'Duty Payment'},
    'STEP_18': {'ar': 'تسوية الأرضيات والحراسات', 'en': 'Demurrage & Guard'},
    'STEP_19': {'ar': 'إذن إضافة المخازن', 'en': 'Warehouse GRN'},
    'STEP_20': {'ar': 'تسوية تكلفة الاستيراد الشاملة', 'en': 'Landed Cost Settlement'},
    'STEP_21': {'ar': 'إغلاق وأرشفة الملف نهائياً', 'en': 'File Archive & Close'},
  };

  // ── 2. Phase Definitions ───────────────────────────────────────────────────

  static const Map<int, Map<String, String>> _phaseMap = {
    1: {'ar': 'المرحلة الأولى: التخطيط والدراسات المسبقة', 'en': 'Phase 1: Planning & Studies'},
    2: {'ar': 'المرحلة الثانية: الاعتمادات ورقم التسجيل المسبق', 'en': 'Phase 2: Approvals & ACID'},
    3: {'ar': 'المرحلة الثالثة: الحجز وتدقيق المستندات', 'en': 'Phase 3: Booking & Docs'},
    4: {'ar': 'المرحلة الرابعة: التوثيق الإلكتروني والنموذج البنكي', 'en': 'Phase 4: CargoX & Banking'},
    5: {'ar': 'المرحلة الخامسة: التخليص الجمركي والإفراج', 'en': 'Phase 5: Clearance & Release'},
    6: {'ar': 'المرحلة السادسة: المخازن والتسوية النهائية', 'en': 'Phase 6: Storage & Settlement'},
    7: {'ar': 'المرحلة السابعة: النقل الداخلي والتفريغ', 'en': 'Phase 7: Inland Transport & Delivery'},
    8: {'ar': 'المرحلة الثامنة: الاستلام والفحص المخزني', 'en': 'Phase 8: Warehouse Receiving & Inspection'},
    9: {'ar': 'المرحلة التاسعة: التسوية المالية وتكلفة الاستيراد', 'en': 'Phase 9: Financial Settlement & Landed Cost'},
    10: {'ar': 'المرحلة العاشرة: إغلاق وأرشفة الملف', 'en': 'Phase 10: Import File Closure & Archival'},
  };

  // ── 3. Shipment Name Resolvers ──────────────────────────────────────────────

  /// Resolves the primary commercial/human name of the shipment.
  /// If the user entered a custom name (e.g. "PET Stock", "شحنة بطاريات خام"),
  /// that name is returned. Otherwise, returns the fallback internal code.
  static String resolveShipmentName(ImportFileModel file, {bool isArabic = true}) {
    if (file.customFileNumber != null &&
        file.customFileNumber!.trim().isNotEmpty &&
        file.customFileNumber!.trim() != file.importFileCode) {
      return file.customFileNumber!.trim();
    }
    return file.importFileCode;
  }

  /// Returns the human-readable shipment name with secondary internal code for traceability:
  /// e.g. "PET Stock (IMP-2026-0004)" or "IMP-2026-0004" if no custom name exists.
  static String resolveShipmentTitle(
    ImportFileModel file, {
    bool isArabic = true,
    bool includeCodeSecondary = true,
  }) {
    final humanName = resolveShipmentName(file, isArabic: isArabic);
    if (humanName != file.importFileCode) {
      return includeCodeSecondary ? '$humanName (${file.importFileCode})' : humanName;
    }
    return file.importFileCode;
  }

  /// Resolves a shipment title by its raw internal code via the active shipments collection.
  /// Falls back gracefully to the code itself if the shipment is not in the collection.
  static String resolveShipmentTitleByCode(
    String? code, {
    List<ImportFileModel>? shipments,
    bool isArabic = true,
    bool includeCodeSecondary = true,
  }) {
    if (code == null || code.trim().isEmpty) return '-';
    final trimmed = code.trim();
    if (shipments != null && shipments.isNotEmpty) {
      for (final s in shipments) {
        if (s.importFileCode == trimmed || s.customFileNumber == trimmed) {
          return resolveShipmentTitle(s, isArabic: isArabic, includeCodeSecondary: includeCodeSecondary);
        }
      }
    }
    return trimmed;
  }

  /// Resolves just the commercial name (without secondary code) by code.
  static String resolveShipmentNameByCode(
    String? code, {
    List<ImportFileModel>? shipments,
    bool isArabic = true,
  }) {
    return resolveShipmentTitleByCode(
      code,
      shipments: shipments,
      isArabic: isArabic,
      includeCodeSecondary: false,
    );
  }

  // ── 4. Step / Operation Resolvers ──────────────────────────────────────────

  /// Normalizes and resolves a step code (e.g. "STEP_07", "step_7", "7")
  /// or legacy stage string into a clean, human-readable plain language operation title.
  static String resolveStepName(String? stepCodeOrName, {bool isArabic = true}) {
    if (stepCodeOrName == null || stepCodeOrName.trim().isEmpty) return '-';
    final s = stepCodeOrName.trim();

    // Exact code first, so sub-steps such as STEP_08_PO keep their own name
    // instead of collapsing to STEP_08 through the numeric pattern below.
    final exact = _stepMap[s.toUpperCase()];
    if (exact != null) return isArabic ? exact['ar']! : exact['en']!;

    // Check direct STEP_XX format
    final match = RegExp(r'STEP_0?(\d+)', caseSensitive: false).firstMatch(s);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null) {
        final key = 'STEP_${num.toString().padLeft(2, '0')}';
        if (_stepMap.containsKey(key)) {
          return isArabic ? _stepMap[key]!['ar']! : _stepMap[key]!['en']!;
        }
      }
    }


    // Check known operational stage phrases
    final lower = s.toLowerCase();
    if (lower.contains('freight') || lower.contains('نولون')) {
      return isArabic ? _stepMap['STEP_01']!['ar']! : _stepMap['STEP_01']!['en']!;
    }
    if (lower.contains('customs consult') || lower.contains('customs stud') || lower.contains('استشارة جمركية') || lower.contains('دراسة جمركية') || lower.contains('دراسات جمركية')) {
      return isArabic ? _stepMap['STEP_02']!['ar']! : _stepMap['STEP_02']!['en']!;
    }
    if (lower.contains('requirement') || lower.contains('اشتراطات')) {
      return isArabic ? _stepMap['STEP_03']!['ar']! : _stepMap['STEP_03']!['en']!;
    }
    if (lower.contains('budget') || lower.contains('ميزانية') || lower.contains('دفعة')) {
      return isArabic ? _stepMap['STEP_04']!['ar']! : _stepMap['STEP_04']!['en']!;
    }
    if (lower.contains('acid') || lower.contains('تسجيل مسبق')) {
      return isArabic ? _stepMap['STEP_05']!['ar']! : _stepMap['STEP_05']!['en']!;
    }
    if (lower.contains('booking') || lower.contains('حجز ملاحي')) {
      return isArabic ? _stepMap['STEP_06']!['ar']! : _stepMap['STEP_06']!['en']!;
    }
    if (lower.contains('container') || lower.contains('تخصيص الحاويات')) {
      return isArabic ? _stepMap['STEP_07']!['ar']! : _stepMap['STEP_07']!['en']!;
    }
    if (lower.contains('draft') || lower.contains('مسودة') || lower.contains('مسودات')) {
      return isArabic ? _stepMap['STEP_08']!['ar']! : _stepMap['STEP_08']!['en']!;
    }
    if (lower.contains('final approval') || lower.contains('اعتماد نهائي')) {
      return isArabic ? _stepMap['STEP_09']!['ar']! : _stepMap['STEP_09']!['en']!;
    }
    if (lower.contains('cargox') || lower.contains('توثيق إلكتروني')) {
      return isArabic ? _stepMap['STEP_10']!['ar']! : _stepMap['STEP_10']!['en']!;
    }
    if (lower.contains('original doc') || lower.contains('أصول المستندات')) {
      return isArabic ? _stepMap['STEP_11']!['ar']! : _stepMap['STEP_11']!['en']!;
    }
    if (lower.contains('form 4') || lower.contains('نموذج 4')) {
      return isArabic ? _stepMap['STEP_12']!['ar']! : _stepMap['STEP_12']!['en']!;
    }
    if (lower.contains('46') || lower.contains('إقرار 46')) {
      return isArabic ? _stepMap['STEP_13']!['ar']! : _stepMap['STEP_13']!['en']!;
    }
    if (lower.contains('inspection') && !lower.contains('report') || lower.contains('كشف ومعاينة') || lower.contains('تثمين')) {
      return isArabic ? _stepMap['STEP_14']!['ar']! : _stepMap['STEP_14']!['en']!;
    }
    if (lower.contains('sample') || lower.contains('عينات') || lower.contains('سحب عينات')) {
      return isArabic ? _stepMap['STEP_15']!['ar']! : _stepMap['STEP_15']!['en']!;
    }
    if (lower.contains('report') || lower.contains('محضر')) {
      return isArabic ? _stepMap['STEP_16']!['ar']! : _stepMap['STEP_16']!['en']!;
    }
    if (lower.contains('duty') || lower.contains('رسوم') || lower.contains('سداد')) {
      return isArabic ? _stepMap['STEP_17']!['ar']! : _stepMap['STEP_17']!['en']!;
    }
    if (lower.contains('demurrage') || lower.contains('أرضيات') || lower.contains('حراسات')) {
      return isArabic ? _stepMap['STEP_18']!['ar']! : _stepMap['STEP_18']!['en']!;
    }
    if (lower.contains('grn') || lower.contains('إذن إضافة') || lower.contains('مخازن')) {
      return isArabic ? _stepMap['STEP_19']!['ar']! : _stepMap['STEP_19']!['en']!;
    }
    if (lower.contains('landed') || lower.contains('تكلفة الاستيراد')) {
      return isArabic ? _stepMap['STEP_20']!['ar']! : _stepMap['STEP_20']!['en']!;
    }
    if (lower.contains('archive') || lower.contains('إغلاق') || lower.contains('أرشفة')) {
      return isArabic ? _stepMap['STEP_21']!['ar']! : _stepMap['STEP_21']!['en']!;
    }

    // Strip raw numeric prefixes like "1. ", "01. "
    final clean = s.replaceAll(RegExp(r'^\d+\.\s*'), '');
    return clean;
  }

  // ── 5. Phase Resolvers ─────────────────────────────────────────────────────

  /// Normalizes and resolves a phase code (e.g. "Phase 1", "المرحلة 1", "P1:")
  /// into an official clean localized title without Latin abbreviations in Arabic.
  static String resolvePhaseName(String? phaseCodeOrName, {bool isArabic = true}) {
    if (phaseCodeOrName == null || phaseCodeOrName.trim().isEmpty) return '-';
    final s = phaseCodeOrName.trim();

    // Check numeric phase
    final match = RegExp(r'(?:phase|المرحلة|P)\s*:?\s*(\d+)', caseSensitive: false).firstMatch(s);
    int? phaseNum;
    if (match != null) {
      phaseNum = int.tryParse(match.group(1)!);
    } else {
      final lower = s.toLowerCase();
      if (lower.contains('planning') || lower.contains('تخطيط')) {
        phaseNum = 1;
      } else if (lower.contains('acid') || lower.contains('اعتماد')) {
        phaseNum = 2;
      } else if (lower.contains('booking') || lower.contains('حجز')) {
        phaseNum = 3;
      } else if (lower.contains('cargox') || lower.contains('bank')) {
        phaseNum = 4;
      } else if (lower.contains('clearance') || lower.contains('تخليص')) {
        phaseNum = 5;
      } else if (lower.contains('warehouse') || lower.contains('مخازن') || lower.contains('settlement')) {
        phaseNum = 6;
      } else if (lower.contains('transport') || lower.contains('نقل')) {
        phaseNum = 7;
      } else if (lower.contains('grn') || lower.contains('استلام')) {
        phaseNum = 8;
      } else if (lower.contains('landed') || lower.contains('تسوية')) {
        phaseNum = 9;
      } else if (lower.contains('closure') || lower.contains('إغلاق') || lower.contains('closed')) {
        phaseNum = 10;
      }
    }

    if (phaseNum != null && _phaseMap.containsKey(phaseNum)) {
      return isArabic ? _phaseMap[phaseNum]!['ar']! : _phaseMap[phaseNum]!['en']!;
    }

    if (isArabic) {
      return s.replaceAll('Phase', 'المرحلة').replaceAll('STEP_', 'خطوة ');
    }
    return s;
  }

  /// Resolves an internal stage/step code into a human-readable business stage badge title (Task Problem 2 - Option 2).
  /// Replaces raw codes like 'PHASE-1: STEP_03', 'PHASE-4: STEP_11', 'PHASE-5' with clean descriptive business titles.
  static String resolveStageBadge(String? stageCode, {bool isArabic = true}) {
    if (stageCode == null || stageCode.trim().isEmpty) return '';
    final code = stageCode.trim();

    // Specific sub-codes
    if (code.contains('TAX')) {
      return isArabic ? 'الرسوم الجمركية والضرائب' : 'Customs Duty & Taxes';
    }
    if (code.contains('INS')) {
      return isArabic ? 'التأمين البحري' : 'Marine Cargo Insurance';
    }
    if (code.contains('MATCH')) {
      return isArabic ? 'مطابقة الفاتورة والبوليصة' : 'Invoice vs B/L Match';
    }
    if (code.contains('COC')) {
      return isArabic ? 'شهادات الفحص COC' : 'Inspection Review COC';
    }
    if (code.contains('_PO')) {
      return isArabic ? 'مطابقة الفاتورة والتعبئة' : 'PO & Packing Match';
    }
    if (code.contains('_BL')) {
      return isArabic ? 'مسودة بوليصة الشحن' : 'Draft B/L Review';
    }
    if (code.contains('_COO')) {
      return isArabic ? 'مسودة شهادة المنشأ' : 'Draft COO & EUR.1';
    }

    // Direct step resolution if code contains STEP_XX or STEP-XX
    final stepMatch = RegExp(r'STEP[_-]0?(\d+)', caseSensitive: false).firstMatch(code);
    if (stepMatch != null) {
      final num = int.tryParse(stepMatch.group(1)!);
      if (num != null) {
        final key = 'STEP_${num.toString().padLeft(2, '0')}';
        if (_stepMap.containsKey(key)) {
          return isArabic ? _stepMap[key]!['ar']! : _stepMap[key]!['en']!;
        }
      }
    }

    // Direct stepMap check
    if (_stepMap.containsKey(code)) {
      return isArabic ? _stepMap[code]!['ar']! : _stepMap[code]!['en']!;
    }

    // Phase-only check (e.g. 'PHASE-5', 'PHASE-3', 'PHASE-4')
    final phaseMatch = RegExp(r'PHASE[_-]?(\d+)', caseSensitive: false).firstMatch(code);
    if (phaseMatch != null) {
      final pNum = int.tryParse(phaseMatch.group(1)!);
      if (pNum != null) {
        switch (pNum) {
          case 1:
            return isArabic ? 'التخطيط والدراسات المسبقة' : 'Planning & Studies';
          case 2:
            return isArabic ? 'الاعتمادات ورقم ACID' : 'Approvals & ACID';
          case 3:
            return isArabic ? 'الحجز وتدقيق المستندات' : 'Booking & Draft Docs';
          case 4:
            return isArabic ? 'كارجو إكس والنموذج البنكي' : 'CargoX & Banking';
          case 5:
            return isArabic ? 'التخليص الجمركي والإفراج' : 'Customs Clearance';
          case 6:
            return isArabic ? 'المخازن والتسوية النهائية' : 'Warehouse & Settlement';
          default:
            return resolvePhaseName(code, isArabic: isArabic);
        }
      }
    }

    // Fallback to resolveStepName
    return resolveStepName(code, isArabic: isArabic);
  }

  // ── 6. Task Title Cleaner ──────────────────────────────────────────────────

  /// Cleans task titles by stripping raw internal shipment/step codes
  /// and replacing embedded (STEP_XX) tags with plain-language operation names.
  static String cleanTaskTitle(String rawTitle, {bool isArabic = true}) {
    var cleaned = rawTitle.trim();

    // Strip raw shipment code tag e.g. [IMP-2026-0004]
    cleaned = cleaned.replaceAll(RegExp(r'\[IMP-\d{4}-\d{4}\]\s*'), '');

    // Strip raw ACID tag e.g. [ACID: 5281534391023010013]
    cleaned = cleaned.replaceAll(RegExp(r'\[ACID:\s*\d+\]\s*'), '');

    // Strip leading dashes, em-dashes, en-dashes, or colons
    cleaned = cleaned.replaceAll(RegExp(r'^[—–\-:]\s*'), '');

    // Strip leading (STEP_XX) or STEP_XX prefix when followed by descriptive text
    cleaned = cleaned.replaceAll(RegExp(r'^\(?STEP_0?\d+\)?\s*[-—–:]*\s*', caseSensitive: false), '');

    // If title was only a step code or is now empty, resolve directly to step name
    if (cleaned.isEmpty || RegExp(r'^\(?STEP_0?\d+\)?$', caseSensitive: false).hasMatch(cleaned)) {
      return resolveStepName(rawTitle, isArabic: isArabic);
    }

    // If English mode, detect full Arabic task patterns and provide pure English equivalents
    if (!isArabic) {
      if (cleaned.contains('شهادة المنشأ') || cleaned.contains('COO') || cleaned.contains('Origin')) {
        return 'Authentication of Certificate of Origin (COO)';
      }
      if (cleaned.contains('إصدار شهادة الفحص المسبق') || cleaned.contains('GOEIC')) {
        return 'Pre-shipment Inspection Certificate (GOEIC)';
      }
      if (cleaned.contains('VGM') || (cleaned.contains('تخصيص') && cleaned.contains('VGM'))) {
        return 'Container Allocation & VGM Verification';
      }
      if (cleaned.contains('تخصيص وتوزيع الحاويات') || cleaned.contains('تخصيص الحاويات')) {
        return 'Container Allocation & Cargo Distribution';
      }
      if (cleaned.contains('اشتراطات الاستيراد') || cleaned.contains('الموافقات الرقابية')) {
        return 'Review Import Requirements & Regulatory Approvals';
      }
      if (cleaned.contains('نولون الشحن') || cleaned.contains('دراسات ومفاضلة النولون')) {
        return 'Freight Studies & Shipping Quotations';
      }
      if (cleaned.contains('الاستشارة الجمركية') || cleaned.contains('الدراسات والاستشارات الجمركية')) {
        return 'Customs Consultation & Tariff Studies';
      }
      if (cleaned.contains('الميزانية') || cleaned.contains('صرف الدفعة')) {
        return 'Budget Approval & Advance Payment';
      }
      if (cleaned.contains('التسجيل المسبق') || cleaned.contains('نافذة') || cleaned.contains('ACID')) {
        return 'Nafeza Advance Registration (ACID)';
      }
      if (cleaned.contains('الحجز الملاحي') || cleaned.contains('حجز الشحنة')) {
        return 'Freight Booking Confirmation';
      }
      if (cleaned.contains('مسودات المستندات') || cleaned.contains('مسودة')) {
        return 'Review Draft Shipping Documents';
      }
      if (cleaned.contains('CargoX') || cleaned.contains('التوثيق الإلكتروني')) {
        return 'CargoX Document Upload';
      }
      if (cleaned.contains('نموذج 4')) {
        return 'Bank Form 4 Issuance';
      }
      if (cleaned.contains('إقرار 46')) {
        return 'Customs Declaration Form 46';
      }
      if (cleaned.contains('الكشف والمعاينة') || cleaned.contains('المعاينة الجمركية')) {
        return 'Customs Inspection & Valuation';
      }
      if (cleaned.contains('سحب العينات')) {
        return 'Regulatory Sample Drawing';
      }
      if (cleaned.contains('سداد الضرائب') || cleaned.contains('الرسوم الجمركية')) {
        return 'Customs Duties & Taxes Settlement';
      }
      if (cleaned.contains('الأرضيات') || cleaned.contains('الحراسات')) {
        return 'Demurrage & Storage Settlement';
      }
      if (cleaned.contains('إذن إضافة') || cleaned.contains('استلام المخازن')) {
        return 'Warehouse GRN & Physical Receiving';
      }
      if (cleaned.contains('تكلفة الاستيراد')) {
        return 'Landed Cost Settlement';
      }
      if (cleaned.contains('أرشفة الملف') || cleaned.contains('إغلاق')) {
        return 'Import File Archival & Closure';
      }
    }

    // Replace any remaining (STEP_XX) tags with plain-language operation names
    cleaned = cleaned.replaceAllMapped(RegExp(r'\(STEP_0?(\d+)\)', caseSensitive: false), (m) {
      final num = int.tryParse(m.group(1)!);
      if (num != null) {
        final stepKey = 'STEP_${num.toString().padLeft(2, '0')}';
        final stepData = _stepMap[stepKey];
        final stepName = stepData != null ? (isArabic ? stepData['ar'] : stepData['en']) : null;
        if (stepName != null) {
          if (cleaned.contains(stepName)) {
            return '';
          }
          return '($stepName)';
        }
      }
      return '';
    });

    // Fix double parens like ((... or ))...
    cleaned = cleaned.replaceAll('((', '(').replaceAll('))', ')');

    if (isArabic) {
      cleaned = cleaned.replaceAll('(COO)', '').replaceAll('COO', '');
      cleaned = cleaned.replaceAll('GOEIC - ', '').replaceAll('(GOEIC)', '').replaceAll('GOEIC', '');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.contains('شهادة المنشأ')) {
        cleaned = 'استيفاء وتوثيق شهادة المنشأ المعتمدة رسمياً';
      }
      if (cleaned.contains('إصدار شهادة الفحص المسبق')) {
        cleaned = 'إصدار شهادة الفحص المسبق قبل الشحن (الهيئة العامة للرقابة على الصادرات والواردات)';
      }
      if (cleaned.contains('تخصيص وتوزيع الحاويات والـ VGM') || cleaned.contains('تخصيص وتوزيع الحاويات والـ - VGM') || cleaned.contains('VGM')) {
        cleaned = 'تخصيص وتوزيع الحاويات والتحقق من الأوزان المعتمدة';
      }
      if (cleaned.contains('تخصيص وتوزيع الحاويات والبضائع')) {
        cleaned = 'تخصيص وتوزيع الحاويات والبضائع';
      }
      if (cleaned.contains('مراجعة اشتراطات الاستيراد')) {
        cleaned = 'مراجعة اشتراطات الاستيراد والموافقات الرقابية';
      }
    }

    // Final clean of any leading/trailing dashes and spaces
    cleaned = cleaned.replaceAll(RegExp(r'^[—–\-:]\s*'), '').replaceAll(RegExp(r'\s*[—–\-:]$'), '').trim();

    return cleaned;
  }

  // ── 7. Action / Next Step Title Cleaner ─────────────────────────────────────

  /// Resolves an action string that might contain a STEP_XX prefix or stage code.
  /// If it contains additional descriptive text (e.g. "STEP_07 تدقيق بيانات تخصيص الحاويات وأوزان VGM..."),
  /// it strips the internal code and localizes the action description.
  static String resolveActionTitle(String? actionText, {bool isArabic = true}) {
    if (actionText == null || actionText.trim().isEmpty) return '-';
    var s = actionText.trim();

    // If it's pure STEP_XX or short step name, use resolveStepName
    if (RegExp(r'^STEP_0?\d+$', caseSensitive: false).hasMatch(s)) {
      return resolveStepName(s, isArabic: isArabic);
    }

    final lower = s.toLowerCase();
    if (lower.contains('vgm') || (lower.contains('تخصيص') && lower.contains('تدقيق'))) {
      return isArabic
          ? 'تدقيق بيانات تخصيص الحاويات وأوزان VGM ومراجعة مسودات الشحن'
          : 'VGM Verification & Shipping Drafts Review';
    }
    if (lower.contains('freight') || lower.contains('نولون') || lower.contains('scenarios') || lower.contains('bp-007') || lower.contains('bp-008')) {
      return isArabic
          ? 'تقييم سيناريوهات الشحن وطلب عروض أسعار النولون'
          : 'Evaluate Shipping Scenarios & Request Freight Quotes';
    }
    if (lower.contains('booking') || lower.contains('حجز')) {
      return isArabic
          ? 'تأكيد الحجز الملاحي ومتابعة إصدار إذن الشحن'
          : 'Confirm Freight Booking & Follow Shipping Order';
    }
    if (lower.contains('cargox') || lower.contains('توثيق')) {
      return isArabic
          ? 'رفع المستندات على منصة كارجو إكس (CargoX)'
          : 'Upload Documents via CargoX Platform';
    }
    if (lower.contains('customs') || lower.contains('جمرك') || lower.contains('46')) {
      return isArabic
          ? 'قيد الإقرار الجمركي رقم 46 ك.م والبدء في إجراءات الكشف'
          : 'Register Customs Form 46 & Initiate Clearance';
    }

    // Strip STEP_XX code prefix
    s = s.replaceAll(RegExp(r'^STEP_0?\d+[:\s—–-]*', caseSensitive: false), '').trim();
    if (s.isEmpty) {
      return resolveStepName(actionText, isArabic: isArabic);
    }
    return s;
  }

  // ── 8. Task Metadata & Description Resolvers (Task D & Task A) ─────────────

  /// Localizes task type (e.g. "System Generated", "Regulatory Compliance") to active language.
  static String resolveTaskType(String? taskType, {bool isArabic = true}) {
    if (taskType == null || taskType.trim().isEmpty) return '-';
    final t = taskType.trim();
    if (!isArabic) {
      if (t == 'توليد آلي من النظام' || t == 'آلي') return 'System Generated';
      if (t == 'اشتراطات رقابية' || t == 'رقابي') return 'Regulatory Compliance';
      if (t == 'مهمة يدوية' || t == 'يدوي') return 'Manual Task';
      if (t == 'تدقيق المستندات') return 'Document Review';
      if (t == 'سداد مالي') return 'Payment';
      if (t == 'تخليص جمركي') return 'Customs Clearance';
      if (t == 'متابعة تشغيلية') return 'Follow-up';
      if (t == 'عام') return 'General';
      return t;
    }
    switch (t.toLowerCase()) {
      case 'system generated':
        return 'توليد آلي من النظام';
      case 'regulatory compliance':
        return 'اشتراطات رقابية';
      case 'manual to-do':
      case 'manual task':
        return 'مهمة يدوية';
      case 'document review':
        return 'تدقيق المستندات';
      case 'customs clearance':
        return 'تخليص جمركي';
      case 'payment':
        return 'سداد مالي';
      case 'general':
        return 'عام';
      case 'follow-up':
        return 'متابعة تشغيلية';
      case 'reminder':
        return 'تذكير ومتابعة';
      default:
        return t;
    }
  }

  /// Localizes task status (e.g. "Pending", "In Progress", "Completed") to active language.
  static String resolveTaskStatus(String? status, {bool isArabic = true}) {
    if (status == null || status.trim().isEmpty) return '-';
    final s = status.trim();
    if (!isArabic) {
      if (s == 'معلقة' || s == 'معلق') return 'Pending';
      if (s == 'قيد التنفيذ' || s == 'جاري') return 'In Progress';
      if (s == 'مكتملة' || s == 'منجز') return 'Completed';
      if (s == 'ملغاة' || s == 'ملغي') return 'Cancelled';
      return s;
    }
    switch (s.toLowerCase()) {
      case 'pending':
        return 'معلقة';
      case 'in progress':
      case 'in-progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
      case 'canceled':
        return 'ملغاة';
      default:
        return s;
    }
  }

  /// Resolves and cleans a task description:
  /// 1. Replaces internal codes like IMP-YYYY-NNNN with resolved human-readable shipment name.
  /// 2. If English mode, localizes known operational task descriptions from Arabic to natural English.
  /// 3. If Arabic mode, ensures internal step codes (STEP_XX) are replaced with plain Arabic names.
  static String resolveTaskDescription(
    String? description, {
    bool isArabic = true,
    String? shipmentCode,
    List<ImportFileModel>? shipments,
  }) {
    if (description == null || description.trim().isEmpty) {
      return isArabic ? 'متابعة إنهاء المهمة المعلقة' : 'Follow up pending task execution';
    }
    var text = description.trim();

    // Resolve shipment title for replacing raw code
    final targetCode = shipmentCode ?? RegExp(r'IMP-\d{4}-\d{4}').firstMatch(text)?.group(0);
    final shipmentTitle = targetCode != null
        ? resolveShipmentNameByCode(targetCode, shipments: shipments, isArabic: isArabic)
        : null;

    if (!isArabic) {
      final lower = text.toLowerCase();
      // 1. Customs Studies / Consultation -> Requirements (STEP_02 -> STEP_03)
      if (text.contains('الاستشارة الجمركية') || text.contains('دراسة جمركية') || text.contains('اشتراطات') || lower.contains('regulatory')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Review import requirements and regulatory approvals$shipStr.';
      }
      // 2. Freight Studies -> Customs (STEP_01 -> STEP_02)
      if (text.contains('دراسات النولون') || text.contains('نولون') || text.contains('سيناريوهات')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Freight studies completed$shipStr. Proceeding to customs studies and tariff analysis.';
      }
      // 3. Budget / Finance (STEP_04)
      if (text.contains('اعتماد الميزانية') || text.contains('الميزانية التقديرية') || text.contains('صرف الدفعة')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Import budget approved$shipStr. Proceeding to advance payment and Nafeza ACID registration.';
      }
      // 4. ACID / Nafeza (STEP_05)
      if (text.contains('تسجيل مسبق') || text.contains('نافذة') || lower.contains('acid')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Nafeza advance registration (ACID) completed$shipStr. Proceeding to freight booking and document review.';
      }
      // 5. Booking / Container (STEP_06 / STEP_07)
      if (text.contains('حجز') || text.contains('رص الحاويات') || text.contains('تخصيص')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Freight booking confirmed$shipStr. Reviewing shipping drafts and container allocation.';
      }
      // 6. CargoX / Original Docs (STEP_10 / STEP_11)
      if (lower.contains('cargox') || text.contains('توثيق إلكتروني') || text.contains('أصول المستندات')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Documents uploaded to CargoX platform$shipStr. Proceeding to original documents receipt and bank Form 4.';
      }
      // 7. Bank Form 4 (STEP_12)
      if (text.contains('نموذج 4') || text.contains('البنكي')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Bank Form 4 issued$shipStr. Registering customs declaration Form 46 KM.';
      }
      // 8. Customs Form 46 (STEP_13)
      if (text.contains('46') || text.contains('إقرار 46')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Customs declaration Form 46 KM registered$shipStr. Initiating customs inspection and valuation.';
      }
      // 9. Inspection & Sampling (STEP_14 / STEP_15 / STEP_16)
      if (text.contains('معاينة') || text.contains('كشف') || text.contains('عينات') || text.contains('محضر')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Customs inspection and sampling completed$shipStr. Settling customs duties and taxes.';
      }
      // 10. Duty Payment & Demurrage (STEP_17 / STEP_18)
      if (text.contains('سداد الضرائب') || text.contains('رسوم') || text.contains('أرضيات') || text.contains('إفراج')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Customs duties settled and release obtained$shipStr. Scheduling inland transport.';
      }
      // 11. Warehouse GRN (STEP_19)
      if (text.contains('إذن إضافة') || text.contains('مخازن') || lower.contains('grn')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Warehouse GRN issued$shipStr. Finalizing landed cost settlement.';
      }
      // 12. Landed Cost & Archive (STEP_20 / STEP_21)
      if (text.contains('تكلفة الاستيراد') || lower.contains('landed') || text.contains('أرشفة') || text.contains('إغلاق')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Landed cost settlement completed$shipStr. Archiving and closing import file.';
      }
      // 13. System Generated default task
      if (text.contains('مهمة توليد آلي') || text.contains('توليد تلقائي')) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Automated system task to follow up operational procedures$shipStr.';
      }

      // Generic Arabic text in English mode: replace any embedded shipment codes and give clean translation
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
        final shipStr = shipmentTitle != null ? ' for shipment $shipmentTitle' : '';
        return 'Follow up pending operational requirements$shipStr.';
      }

      return text;
    }

    // Arabic mode: Replace raw shipment codes with resolved human-readable title
    if (shipmentTitle != null && targetCode != null) {
      text = text.replaceAll(targetCode, shipmentTitle);
    }
    // Replace raw STEP_XX with Arabic step name
    text = text.replaceAllMapped(RegExp(r'\(?STEP_0?(\d+)\)?', caseSensitive: false), (m) {
      final num = int.tryParse(m.group(1)!);
      if (num != null) {
        final key = 'STEP_${num.toString().padLeft(2, '0')}';
        return _stepMap[key]?['ar'] ?? m.group(0)!;
      }
      return m.group(0)!;
    });

    return text;
  }

  /// Resolves shipment update categories (e.g. 'Follow-up & Notes', 'Phase Cost Adjustment', 'Future Phase Alert')
  /// into cleanly localized Arabic/English labels.
  static String resolveUpdateCategory(String? category, {bool isArabic = true}) {
    if (category == null || category.trim().isEmpty) return '-';
    final s = category.trim();
    final lower = s.toLowerCase();
    if (lower.contains('cost') || lower.contains('تكلف')) {
      return isArabic ? 'تعديل تكلفة المرحلة' : 'Phase Cost Adjustment';
    }
    if (lower.contains('alert') || lower.contains('تنبيه')) {
      return isArabic ? 'تنبيه مرحلة مستقبلية' : 'Future Phase Alert';
    }
    if (lower.contains('follow') || lower.contains('note') || lower.contains('متابع') || lower.contains('ملاحظ')) {
      return isArabic ? 'متابعة وملاحظات' : 'Follow-up & Notes';
    }
    return s;
  }
}

