import 'export_language.dart';

/// Centralized i18n dictionary for all Sorour Logistics ERP export services (PDF & Excel/CSV).
/// Ensures strict single-language exports without bilingual parentheses or hardcoded mixed strings.
class ExportTranslations {
  static const Map<String, Map<ExportLanguage, String>> _strings = {
    // ── ERP Branding & System Sign-offs ──
    'erp_title': {
      ExportLanguage.ar: 'نظام سرور اللوجستي الموحد لإدارة الاستيراد',
      ExportLanguage.en: 'Sorour Logistics ERP Enterprise System',
    },
    'erp_brand_tag': {
      ExportLanguage.ar: 'Sorour Logistics ERP',
      ExportLanguage.en: 'Sorour Logistics ERP',
    },
    'print_date': {
      ExportLanguage.ar: 'تاريخ الطباعة:',
      ExportLanguage.en: 'Print Date:',
    },
    'page': {
      ExportLanguage.ar: 'صفحة',
      ExportLanguage.en: 'Page',
    },
    'of': {
      ExportLanguage.ar: 'من',
      ExportLanguage.en: 'of',
    },

    // ── Importer Company Profile Card ──
    'importer_card_title': {
      ExportLanguage.ar: 'Sorour Logistics ERP — بطاقة بيانات الشركة المستوردة',
      ExportLanguage.en: 'Sorour Logistics ERP — Importer Company Profile Card',
    },
    'importer_card_subtitle': {
      ExportLanguage.ar: 'وثيقة رسمية ببيانات التسجيل والقيد التجاري والضريبي',
      ExportLanguage.en: 'Official Registration, Tax, and Commercial Record Document',
    },
    'importer_sheet_name': {
      ExportLanguage.ar: 'بيانات الشركة المستوردة',
      ExportLanguage.en: 'Importer Profile',
    },
    'importer_file_name_prefix': {
      ExportLanguage.ar: 'بطاقة_بيانات_الشركة',
      ExportLanguage.en: 'Company_Data_Card',
    },
    'importer_name': {
      ExportLanguage.ar: 'اسم الشركة المستوردة',
      ExportLanguage.en: 'Importer Company Name',
    },
    'country': {
      ExportLanguage.ar: 'الدولة',
      ExportLanguage.en: 'Country',
    },
    'default_egypt': {
      ExportLanguage.ar: 'جمهورية مصر العربية',
      ExportLanguage.en: 'Arab Republic of Egypt',
    },
    'address': {
      ExportLanguage.ar: 'العنوان',
      ExportLanguage.en: 'Address',
    },
    'phone': {
      ExportLanguage.ar: 'الهاتف',
      ExportLanguage.en: 'Phone',
    },
    'mobile': {
      ExportLanguage.ar: 'المحمول',
      ExportLanguage.en: 'Mobile',
    },
    'fax': {
      ExportLanguage.ar: 'الفاكس',
      ExportLanguage.en: 'Fax',
    },
    'email': {
      ExportLanguage.ar: 'البريد الإلكتروني',
      ExportLanguage.en: 'Primary Email',
    },
    'secondary_email': {
      ExportLanguage.ar: 'البريد الثانوي',
      ExportLanguage.en: 'Secondary Email',
    },
    'website': {
      ExportLanguage.ar: 'الموقع الإلكتروني',
      ExportLanguage.en: 'Website',
    },
    'nafeza_token': {
      ExportLanguage.ar: 'توكن نافذة',
      ExportLanguage.en: 'Nafeza Portal Token',
    },
    'token_configured': {
      ExportLanguage.ar: 'مربوط ومفعل',
      ExportLanguage.en: 'Configured & Active',
    },
    'token_not_configured': {
      ExportLanguage.ar: 'غير مربوط',
      ExportLanguage.en: 'Not Configured',
    },
    'notes': {
      ExportLanguage.ar: 'الملاحظات',
      ExportLanguage.en: 'Notes',
    },
    'company_notes': {
      ExportLanguage.ar: 'ملاحظات الشركة:',
      ExportLanguage.en: 'Company Notes:',
    },

    // ── Record Lifecycle Statuses ──
    'active_record': {
      ExportLanguage.ar: 'سجل نشط',
      ExportLanguage.en: 'Active Record',
    },
    'inactive_record': {
      ExportLanguage.ar: 'غير مفعّل',
      ExportLanguage.en: 'Inactive Record',
    },
    'active_status_label': {
      ExportLanguage.ar: 'حالة السجل',
      ExportLanguage.en: 'Record Status',
    },
    'active_short': {
      ExportLanguage.ar: 'نشط',
      ExportLanguage.en: 'Active',
    },
    'inactive_short': {
      ExportLanguage.ar: 'غير نشط',
      ExportLanguage.en: 'Inactive',
    },

    // ── Registration & Regulatory Table ──
    'reg_section_title': {
      ExportLanguage.ar: 'بيانات القيد والتراخيص الرسمية والرقابية:',
      ExportLanguage.en: 'Official Regulatory Licenses & Registrations:',
    },
    'reg_excel_section_title': {
      ExportLanguage.ar: '--- بيانات القيد والتسجيلات الرسمية ---',
      ExportLanguage.en: '--- Official Registration & License Records ---',
    },
    'col_document': {
      ExportLanguage.ar: 'البيان / المستند الرقابي',
      ExportLanguage.en: 'Regulatory Document / License',
    },
    'col_document_short': {
      ExportLanguage.ar: 'المستند',
      ExportLanguage.en: 'Document',
    },
    'col_reg_number': {
      ExportLanguage.ar: 'رقم القيد / التسجيل',
      ExportLanguage.en: 'Registration / License ID',
    },
    'col_expiry_date': {
      ExportLanguage.ar: 'تاريخ الانتهاء',
      ExportLanguage.en: 'Expiry Date',
    },
    'col_validity_status': {
      ExportLanguage.ar: 'حالة السريان',
      ExportLanguage.en: 'Validity Status',
    },
    'col_days_remaining': {
      ExportLanguage.ar: 'الأيام المتبقية',
      ExportLanguage.en: 'Days Remaining',
    },
    'col_status_short': {
      ExportLanguage.ar: 'الحالة',
      ExportLanguage.en: 'Status',
    },

    // ── Official Document Names ──
    'doc_importer_card': {
      ExportLanguage.ar: 'البطاقة الاستيرادية',
      ExportLanguage.en: 'Importer Card',
    },
    'doc_vat_card': {
      ExportLanguage.ar: 'البطاقة الضريبية',
      ExportLanguage.en: 'Tax ID Card',
    },
    'doc_commercial_register': {
      ExportLanguage.ar: 'السجل التجاري',
      ExportLanguage.en: 'Commercial Register',
    },

    // ── Trademark & Quality Section ──
    'cert_section_title': {
      ExportLanguage.ar: 'شهادات العلامات التجارية والجودة:',
      ExportLanguage.en: 'Trademark & Quality Certifications:',
    },
    'cert_excel_section_title': {
      ExportLanguage.ar: '--- شهادات العلامات التجارية والجودة ---',
      ExportLanguage.en: '--- Trademark & Quality Certifications ---',
    },
    'cert_wipo': {
      ExportLanguage.ar: 'الويبو (مدريد)',
      ExportLanguage.en: 'WIPO Madrid Monitor',
    },
    'cert_euipo': {
      ExportLanguage.ar: 'مكتب الملكية الفكرية الأوروبي (EUIPO)',
      ExportLanguage.en: 'EUIPO Intellectual Property',
    },
    'cert_global_brand': {
      ExportLanguage.ar: 'قاعدة بيانات العلامات التجارية العالمية',
      ExportLanguage.en: 'Global Brand Database',
    },
    'cert_iso9001': {
      ExportLanguage.ar: 'شهادة الآيزو 9001',
      ExportLanguage.en: 'ISO 9001 Certificate',
    },
    'status_registered': {
      ExportLanguage.ar: 'مسجل',
      ExportLanguage.en: 'Registered',
    },
    'status_not_registered': {
      ExportLanguage.ar: 'غير مسجل',
      ExportLanguage.en: 'Not Registered',
    },
    'status_certified': {
      ExportLanguage.ar: 'معتمد',
      ExportLanguage.en: 'Certified',
    },
    'status_not_certified': {
      ExportLanguage.ar: 'غير معتمد',
      ExportLanguage.en: 'Not Certified',
    },

    // ── Dialog & UI Strings ──
    'dialog_select_export_lang': {
      ExportLanguage.ar: 'تحديد لغة التحميل والتصدير',
      ExportLanguage.en: 'Select Export Language',
    },
    'dialog_select_export_desc': {
      ExportLanguage.ar: 'حدد اللغة التي ترغب في إنشاء وتصدير المستند بها:',
      ExportLanguage.en: 'Choose the language to generate and download this document:',
    },
    'lang_arabic_label': {
      ExportLanguage.ar: 'اللغة العربية (Arabic)',
      ExportLanguage.en: 'Arabic (العربية)',
    },
    'lang_arabic_desc': {
      ExportLanguage.ar: 'مستند عربي بالكامل، محاذاة من اليمين لليسار، عناوين وأرقام مطابقة',
      ExportLanguage.en: 'Full Arabic document, RTL layout, official Egyptian customs format',
    },
    'lang_english_label': {
      ExportLanguage.ar: 'اللغة الإنجليزية (English)',
      ExportLanguage.en: 'English (الإنجليزية)',
    },
    'lang_english_desc': {
      ExportLanguage.ar: 'مستند إنجليزي بالكامل، محاذاة من اليسار لليمين للتجارة الدولية',
      ExportLanguage.en: 'Full English document, LTR layout, international trade format',
    },
    'remember_default_choice': {
      ExportLanguage.ar: 'تذكر اختياري كلغة افتراضية للتصدير',
      ExportLanguage.en: 'Remember as default export language',
    },
    'btn_confirm_export': {
      ExportLanguage.ar: 'تأكيد وتنزيل',
      ExportLanguage.en: 'Confirm & Download',
    },
    'btn_cancel': {
      ExportLanguage.ar: 'إلغاء',
      ExportLanguage.en: 'Cancel',
    },
    'save_excel_dialog_title': {
      ExportLanguage.ar: 'حفظ كملف Excel / CSV',
      ExportLanguage.en: 'Save as Excel / CSV File',
    },
  };

  /// Returns the localized string for [key] in [lang].
  static String tr(String key, {required ExportLanguage lang}) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[ExportLanguage.ar] ?? key;
  }

  /// Formats computed validity for days remaining.
  /// E.g. Arabic: "سارية (1586 يوم)" or "سارٍ (1586 يوم)"
  /// English: "Valid (1586 days)"
  static String validityWithDays(
    int days, {
    required ExportLanguage lang,
    bool feminine = true,
  }) {
    if (lang.isArabic) {
      final prefix = feminine ? 'سارية' : 'سارٍ';
      return '$prefix ($days يوم)';
    } else {
      return 'Valid ($days ${days == 1 ? "day" : "days"})';
    }
  }

  /// Formats expired status string.
  /// E.g. Arabic: "منتهية الصلاحية" or "منتهي الصلاحية"
  /// English: "Expired"
  static String expiredStatus({
    required ExportLanguage lang,
    bool feminine = true,
  }) {
    if (lang.isArabic) {
      return feminine ? 'منتهية الصلاحية' : 'منتهي الصلاحية';
    } else {
      return 'Expired';
    }
  }

  /// Short status string for tabular Excel exports.
  /// E.g. Arabic: "سارية" / "منتهية"
  /// English: "Valid" / "Expired"
  static String shortValidity(
    bool isValid, {
    required ExportLanguage lang,
    bool feminine = true,
  }) {
    if (lang.isArabic) {
      if (isValid) {
        return feminine ? 'سارية' : 'سارٍ';
      } else {
        return feminine ? 'منتهية' : 'منتهٍ';
      }
    } else {
      return isValid ? 'Valid' : 'Expired';
    }
  }

  /// Formats trademark registration status.
  static String formatRegisteredStatus({
    required bool hasRegistration,
    String? registrationNumber,
    required ExportLanguage lang,
  }) {
    if (hasRegistration) {
      if (registrationNumber != null && registrationNumber.trim().isNotEmpty) {
        return registrationNumber.trim();
      }
      return tr('status_registered', lang: lang);
    }
    return tr('status_not_registered', lang: lang);
  }

  /// Formats quality certificate status.
  static String formatCertifiedStatus({
    required bool hasCertificate,
    String? certificateNumber,
    required ExportLanguage lang,
  }) {
    if (hasCertificate) {
      if (certificateNumber != null && certificateNumber.trim().isNotEmpty) {
        return certificateNumber.trim();
      }
      return tr('status_certified', lang: lang);
    }
    return tr('status_not_certified', lang: lang);
  }
}
