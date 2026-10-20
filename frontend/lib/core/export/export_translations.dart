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
    'save_csv_dialog_title': {
      ExportLanguage.ar: 'حفظ كملف CSV',
      ExportLanguage.en: 'Save as CSV File',
    },
    'save_excel_file_dialog_title': {
      ExportLanguage.ar: 'حفظ كملف Excel (.xlsx)',
      ExportLanguage.en: 'Save as Excel File (.xlsx)',
    },
    'yes': {
      ExportLanguage.ar: 'نعم',
      ExportLanguage.en: 'Yes',
    },
    'no': {
      ExportLanguage.ar: 'لا',
      ExportLanguage.en: 'No',
    },
    'currency_egp': {
      ExportLanguage.ar: 'ج.م',
      ExportLanguage.en: 'EGP',
    },

    // ── Supplier & Foreign Exporter Card ──
    'supplier_card_title': {
      ExportLanguage.ar: 'Sorour Logistics ERP — بطاقة تعريف المورد الأجنبي',
      ExportLanguage.en: 'Sorour Logistics ERP — Foreign Supplier Profile Card',
    },
    'supplier_card_subtitle': {
      ExportLanguage.ar: 'بيانات التسجيل في منصات نافذة وكارجو إكس والتسجيلات الرقابية',
      ExportLanguage.en: 'Official Nafeza, CargoX, and Regulatory Registration Profile',
    },
    'supplier_sheet_name': {
      ExportLanguage.ar: 'بيانات المورد الأجنبي',
      ExportLanguage.en: 'Supplier Profile',
    },
    'supplier_file_name_prefix': {
      ExportLanguage.ar: 'بطاقة_المورد_الأجنبي',
      ExportLanguage.en: 'Supplier_Profile_Card',
    },
    'supplier_code': {
      ExportLanguage.ar: 'كود المورد',
      ExportLanguage.en: 'Supplier Code',
    },
    'supplier_company_name': {
      ExportLanguage.ar: 'اسم الشركة المصدرة',
      ExportLanguage.en: 'Foreign Exporter Name',
    },
    'supplier_country': {
      ExportLanguage.ar: 'دولة المصدر',
      ExportLanguage.en: 'Exporter Country',
    },
    'country_code': {
      ExportLanguage.ar: 'كود الدولة',
      ExportLanguage.en: 'Country Code',
    },
    'supplier_type': {
      ExportLanguage.ar: 'نوع المورد',
      ExportLanguage.en: 'Supplier Type',
    },
    'registration_type': {
      ExportLanguage.ar: 'نوع التسجيل',
      ExportLanguage.en: 'Registration Type',
    },
    'foreign_exporter_id': {
      ExportLanguage.ar: 'معرّف المصدر الأجنبي',
      ExportLanguage.en: 'Foreign Exporter ID',
    },
    'cargox_id': {
      ExportLanguage.ar: 'معرّف منصة كارجو إكس',
      ExportLanguage.en: 'CargoX Platform ID',
    },
    'decree_43': {
      ExportLanguage.ar: 'التسجيل بقرار 43',
      ExportLanguage.en: 'Decree 43 Registration',
    },
    'decree_43_registered': {
      ExportLanguage.ar: 'مسجل بقرار 43',
      ExportLanguage.en: 'Registered under Decree 43',
    },
    'decree_43_not_registered': {
      ExportLanguage.ar: 'غير مسجل بقرار 43',
      ExportLanguage.en: 'Not Registered under Decree 43',
    },
    'white_list': {
      ExportLanguage.ar: 'القائمة البيضاء',
      ExportLanguage.en: 'White List Status',
    },
    'white_list_registered': {
      ExportLanguage.ar: 'مدرج بالقائمة البيضاء',
      ExportLanguage.en: 'White-Listed',
    },
    'white_list_standard': {
      ExportLanguage.ar: 'عادي (غير مدرج)',
      ExportLanguage.en: 'Standard (Not White-Listed)',
    },
    'iso_status': {
      ExportLanguage.ar: 'شهادة الآيزو',
      ExportLanguage.en: 'ISO Certificate',
    },
    'has_iso': {
      ExportLanguage.ar: 'حاصل على ISO',
      ExportLanguage.en: 'ISO Certified',
    },
    'no_iso': {
      ExportLanguage.ar: 'بدون ISO',
      ExportLanguage.en: 'Not ISO Certified',
    },
    'platforms_section_title': {
      ExportLanguage.ar: 'بيانات التسجيل في منصات نافذة وكارجو إكس والامتثال الرقابي:',
      ExportLanguage.en: 'Nafeza & CargoX Registration & Regulatory Compliance:',
    },
    'platforms_excel_section_title': {
      ExportLanguage.ar: '--- بيانات التسجيل في منصات نافذة وكارجو إكس والامتثال ---',
      ExportLanguage.en: '--- Nafeza & CargoX Registration & Compliance ---',
    },
    'col_platform': {
      ExportLanguage.ar: 'المنصة / المعرّف الرقابي',
      ExportLanguage.en: 'Regulatory Platform / Identifier',
    },
    'col_value': {
      ExportLanguage.ar: 'القيمة / الكود المسجل',
      ExportLanguage.en: 'Registered Value / Code',
    },
    'bank_section_title': {
      ExportLanguage.ar: 'بيانات التحويل البنكي والسويفت الدولي:',
      ExportLanguage.en: 'Bank Transfer & International SWIFT Details:',
    },
    'bank_excel_section_title': {
      ExportLanguage.ar: '--- بيانات التحويل البنكي والسويفت ---',
      ExportLanguage.en: '--- Bank Transfer & SWIFT Details ---',
    },
    'bank_name': {
      ExportLanguage.ar: 'اسم البنك',
      ExportLanguage.en: 'Bank Name',
    },
    'swift_code': {
      ExportLanguage.ar: 'كود السويفت',
      ExportLanguage.en: 'SWIFT Code',
    },
    'account_number': {
      ExportLanguage.ar: 'رقم الحساب',
      ExportLanguage.en: 'Account Number',
    },
    'iban': {
      ExportLanguage.ar: 'رقم الآيبان (IBAN)',
      ExportLanguage.en: 'IBAN',
    },
    'brands': {
      ExportLanguage.ar: 'العلامات التجارية والمنتجات',
      ExportLanguage.en: 'Brands & Products',
    },
    'compliance_and_trademarks_excel': {
      ExportLanguage.ar: '--- الامتثال والعلامات التجارية ---',
      ExportLanguage.en: '--- Compliance & Trademarks ---',
    },
    'contact_section_title': {
      ExportLanguage.ar: 'بيانات التواصل ومسؤول الحساب:',
      ExportLanguage.en: 'Contact Details & Account Representative:',
    },
    'contact_excel_section': {
      ExportLanguage.ar: '--- بيانات التواصل ومسؤول الحساب ---',
      ExportLanguage.en: '--- Contact & Account Representative ---',
    },

    // ── Partner & Service Provider Card ──
    'partner_card_title': {
      ExportLanguage.ar: 'Sorour Logistics ERP — بطاقة الشريك ومقدم الخدمات اللوجستية',
      ExportLanguage.en: 'Sorour Logistics ERP — Logistics Partner Profile Card',
    },
    'partner_card_subtitle': {
      ExportLanguage.ar: 'وثيقة رسمية ببيانات الشريك ومقدم الخدمات اللوجستية والاعتمادات',
      ExportLanguage.en: 'Official Logistics Partner & Service Provider Profile Document',
    },
    'partner_sheet_name': {
      ExportLanguage.ar: 'بيانات الشريك ومقدم الخدمات',
      ExportLanguage.en: 'Partner Profile',
    },
    'partner_file_name_prefix': {
      ExportLanguage.ar: 'بطاقة_الشريك_اللوجستي',
      ExportLanguage.en: 'Logistics_Partner_Profile',
    },
    'partner_code': {
      ExportLanguage.ar: 'كود الشريك',
      ExportLanguage.en: 'Partner Code',
    },
    'partner_name': {
      ExportLanguage.ar: 'اسم الشريك / البنك',
      ExportLanguage.en: 'Partner / Bank Name',
    },
    'partner_type': {
      ExportLanguage.ar: 'تصنيف الخدمات',
      ExportLanguage.en: 'Service Classification',
    },
    'rating': {
      ExportLanguage.ar: 'التقييم العام',
      ExportLanguage.en: 'Rating',
    },
    'licenses_section_title': {
      ExportLanguage.ar: 'الرخص والأكواد والبيانات المهنية والرقابية:',
      ExportLanguage.en: 'Professional Licenses, Codes & Regulatory Details:',
    },
    'licenses_excel_section_title': {
      ExportLanguage.ar: '--- الرخص والأكواد والبيانات المهنية والرقابية ---',
      ExportLanguage.en: '--- Professional Licenses, Codes & Regulatory Details ---',
    },
    'scac_code': {
      ExportLanguage.ar: 'كود الناقل الملاحي (SCAC)',
      ExportLanguage.en: 'Carrier SCAC Code',
    },
    'clearance_license': {
      ExportLanguage.ar: 'رقم رخصة التخليص الجمركي',
      ExportLanguage.en: 'Customs Clearance License Number',
    },
    'authorized_ports': {
      ExportLanguage.ar: 'الموانئ المرخصة',
      ExportLanguage.en: 'Authorized Ports',
    },
    'default_free_days': {
      ExportLanguage.ar: 'أيام السماح الافتراضية',
      ExportLanguage.en: 'Default Free Days',
    },
    'fiata_id': {
      ExportLanguage.ar: 'معرّف الاتحاد الدولي لمنظمي الشحن (FIATA)',
      ExportLanguage.en: 'FIATA ID',
    },
    'shipping_modes': {
      ExportLanguage.ar: 'أنماط الشحن المدعومة',
      ExportLanguage.en: 'Supported Shipping Modes',
    },
    'supported_currencies': {
      ExportLanguage.ar: 'العملات المدعومة',
      ExportLanguage.en: 'Supported Currencies',
    },
    'transport_license': {
      ExportLanguage.ar: 'رقم رخصة النقل الداخلي',
      ExportLanguage.en: 'Inland Transport License',
    },
    'fleet_types': {
      ExportLanguage.ar: 'أنواع أسطول النقل',
      ExportLanguage.en: 'Fleet Types',
    },
    'coverage_areas': {
      ExportLanguage.ar: 'مناطق التغطية الجغرافية',
      ExportLanguage.en: 'Geographic Coverage Areas',
    },
    'insurance_license': {
      ExportLanguage.ar: 'رقم رخصة التأمين',
      ExportLanguage.en: 'Insurance License Number',
    },
    'insurance_coverages': {
      ExportLanguage.ar: 'تغطيات التأمين',
      ExportLanguage.en: 'Insurance Coverages',
    },
    'inspection_accreditation': {
      ExportLanguage.ar: 'رقم اعتماد الفحص والمطابقة',
      ExportLanguage.en: 'Inspection Accreditation ID',
    },
    'inspection_scope': {
      ExportLanguage.ar: 'نطاق الفحص المعتمد',
      ExportLanguage.en: 'Inspection Scope',
    },
    'commercial_register_num': {
      ExportLanguage.ar: 'السجل التجاري',
      ExportLanguage.en: 'Commercial Register',
    },
    'tax_id_num': {
      ExportLanguage.ar: 'البطاقة الضريبية',
      ExportLanguage.en: 'Tax ID',
    },
    'payment_terms_section': {
      ExportLanguage.ar: '--- شروط السداد والائتمان والحسابات ---',
      ExportLanguage.en: '--- Payment Terms & Credit Accounts ---',
    },
    'payment_terms_title': {
      ExportLanguage.ar: 'شروط السداد والحد الائتماني والحسابات:',
      ExportLanguage.en: 'Payment Terms, Credit Limits & Accounts:',
    },
    'payment_type': {
      ExportLanguage.ar: 'نوع السداد',
      ExportLanguage.en: 'Payment Type',
    },
    'credit_limit': {
      ExportLanguage.ar: 'الحد الائتماني',
      ExportLanguage.en: 'Credit Limit',
    },
    'bank_code': {
      ExportLanguage.ar: 'كود البنك',
      ExportLanguage.en: 'Bank Code',
    },
    'branch_name': {
      ExportLanguage.ar: 'اسم الفرع',
      ExportLanguage.en: 'Branch Name',
    },
    'contact_person': {
      ExportLanguage.ar: 'مسؤول الحساب',
      ExportLanguage.en: 'Contact Person',
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
