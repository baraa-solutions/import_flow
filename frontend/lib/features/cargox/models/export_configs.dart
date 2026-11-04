// Typed export configuration models and enums for Dual Document Extraction (Task K).
//
// Encapsulates independent dimensions for:
//   1. File Packaging: Single Sheet ↔ ZIP Archive per Invoice
//   2. Content Detail: Consolidated ↔ Detailed
//   3. Invoice Grouping & Packing List Structure

/// Dimension 1: Packaging mode across documents
enum FilePackagingMode {
  singleFile,
  zipPerInvoice;

  String get labelAr => this == singleFile ? 'ملف موحد' : 'ملف ZIP لكل فاتورة';
  String get labelEn => this == singleFile ? 'Single File' : 'ZIP per Invoice';
  String get descAr => this == singleFile ? 'حفظ البيانات في جدول بيانات مجمع واحد' : 'توليد ملف مضغوط يحتوي ملفا منفصلا لكل فاتورة';
  String get descEn => this == singleFile ? 'All records in a single spreadsheet' : 'Generate a ZIP archive with separate files per invoice';
}

/// Dimension 2: Detail level across documents
enum ContentDetailMode {
  consolidated,
  detailed;

  String get labelAr => this == consolidated ? 'مجمع' : 'مفصل';
  String get labelEn => this == consolidated ? 'Consolidated' : 'Detailed';
  String get descAr => this == consolidated ? 'دمج البنود المتشابهة لتسهيل الإجراءات' : 'عرض كافة البنود بدون دمج وبأعلى درجات الدقة';
  String get descEn => this == consolidated ? 'Combine matching lines for streamlined clearance' : 'Full item-by-item breakdown without grouping';
}

/// Dimension 3 (Invoice): Line item grouping strategy
enum InvoiceGroupingMode {
  byHsCode,
  byPriceGroup,
  flat;

  String get labelAr {
    switch (this) {
      case InvoiceGroupingMode.byHsCode:
        return 'حسب بند التعريفة (HS)';
      case InvoiceGroupingMode.byPriceGroup:
        return 'حسب بند التعريفة والسعر';
      case InvoiceGroupingMode.flat:
        return 'بدون تجميع (مفصل)';
    }
  }

  String get labelEn {
    switch (this) {
      case InvoiceGroupingMode.byHsCode:
        return 'By HS Code';
      case InvoiceGroupingMode.byPriceGroup:
        return 'By HS Code & Price';
      case InvoiceGroupingMode.flat:
        return 'Without Grouping';
    }
  }

  String get descAr {
    switch (this) {
      case InvoiceGroupingMode.byHsCode:
        return 'سطر واحد لكل HS Code — إذا اختلفت الأسعار يُفعَّل التقسيم التلقائي تلقائياً';
      case InvoiceGroupingMode.byPriceGroup:
        return 'فصل البنود ذات الأسعار المختلفة تحت نفس بند التعريفة ✅ آمن جمركياً';
      case InvoiceGroupingMode.flat:
        return 'عرض كل سطر في الفاتورة مستقلاً كما ورد في الأصل';
    }
  }

  String get descEn {
    switch (this) {
      case InvoiceGroupingMode.byHsCode:
        return 'One line per HS code — auto-splits by price when prices differ (customs safe)';
      case InvoiceGroupingMode.byPriceGroup:
        return 'Separate lines when items share HS code but differ in price ✅ Customs compliant';
      case InvoiceGroupingMode.flat:
        return 'Keep every original line item exactly as issued';
    }
  }
}

/// Dimension 3 (Packing List): Package and container organization structure
enum PackingListStructure {
  byHsCode,
  flat,
  byPallet,
  byCarton;

  String get labelAr {
    switch (this) {
      case PackingListStructure.byHsCode:
        return 'حسب بند التعريفة (HS)';
      case PackingListStructure.flat:
        return 'مفصل بالكامل';
      case PackingListStructure.byPallet:
        return 'بالبالتات والطرود';
      case PackingListStructure.byCarton:
        return 'بالكراتين والعبوات';
    }
  }

  String get labelEn {
    switch (this) {
      case PackingListStructure.byHsCode:
        return 'By HS Code';
      case PackingListStructure.flat:
        return 'Fully Detailed';
      case PackingListStructure.byPallet:
        return 'By Pallets';
      case PackingListStructure.byCarton:
        return 'By Cartons & Packages';
    }
  }

  String get descAr {
    switch (this) {
      case PackingListStructure.byHsCode:
        return 'سطر واحد لكل بند تعريفة جمركية وهو الأكثر شيوعاً';
      case PackingListStructure.flat:
        return 'كل بند استيراد في سطر مستقل';
      case PackingListStructure.byPallet:
        return 'تنظيم هرمي بالبالتات يتطلب إدخال تفاصيل البالتات';
      case PackingListStructure.byCarton:
        return 'كل طرد أو كرتونة في سطر مستقل مع بيانات الأبعاد';
    }
  }

  String get descEn {
    switch (this) {
      case PackingListStructure.byHsCode:
        return 'One line per customs tariff HS code (Most common)';
      case PackingListStructure.flat:
        return 'Each import item on an independent line';
      case PackingListStructure.byPallet:
        return 'Organized by pallets (requires entering pallet details)';
      case PackingListStructure.byCarton:
        return 'Each carton or package on an independent line';
    }
  }
}

/// Typed model for Commercial Invoice export dimensions.
class InvoiceExportConfig {
  final FilePackagingMode packaging;
  final ContentDetailMode detail;
  final InvoiceGroupingMode grouping;

  const InvoiceExportConfig({
    this.packaging = FilePackagingMode.singleFile,
    this.detail = ContentDetailMode.consolidated,
    this.grouping = InvoiceGroupingMode.byPriceGroup,
  });

  /// Maps independent dimensions to legacy backend API mode string.
  String toApiInvoiceMode() {
    if (packaging == FilePackagingMode.singleFile) {
      return detail == ContentDetailMode.consolidated ? 'all_consolidated' : 'all_detailed';
    } else {
      return detail == ContentDetailMode.consolidated ? 'per_invoice_consolidated' : 'per_invoice_detailed';
    }
  }

  /// Maps independent grouping to backend API grouping string.
  String toApiInvoiceGrouping() {
    switch (grouping) {
      case InvoiceGroupingMode.byHsCode:
        return 'by_hs_code';
      case InvoiceGroupingMode.byPriceGroup:
        return 'by_price_group';
      case InvoiceGroupingMode.flat:
        return 'flat';
    }
  }

  InvoiceExportConfig copyWith({
    FilePackagingMode? packaging,
    ContentDetailMode? detail,
    InvoiceGroupingMode? grouping,
  }) {
    return InvoiceExportConfig(
      packaging: packaging ?? this.packaging,
      detail: detail ?? this.detail,
      grouping: grouping ?? this.grouping,
    );
  }
}

/// Typed model for Customs Packing List export dimensions.
class PackingListExportConfig {
  final FilePackagingMode packaging;
  final ContentDetailMode detail;
  final PackingListStructure structure;
  final bool includePalletDetails;

  const PackingListExportConfig({
    this.packaging = FilePackagingMode.singleFile,
    this.detail = ContentDetailMode.consolidated,
    this.structure = PackingListStructure.byHsCode,
    this.includePalletDetails = false,
  });

  /// Invariant Rule: Dimension 4 ('Include Pallet Details') is ONLY permitted
  /// when Dimension 3 is 'By Pallets' or 'By Cartons & Packages'.
  bool get isPalletToggleAllowed =>
      structure == PackingListStructure.byPallet || structure == PackingListStructure.byCarton;

  /// Effective includePalletDetails value enforcing invariant rule.
  bool get effectiveIncludePalletDetails => isPalletToggleAllowed && includePalletDetails;

  /// Maps independent dimensions to legacy backend API mode string.
  String toApiPackingListMode() {
    if (packaging == FilePackagingMode.singleFile) {
      return detail == ContentDetailMode.consolidated ? 'all_consolidated' : 'all_detailed';
    } else {
      return detail == ContentDetailMode.consolidated ? 'per_invoice_consolidated' : 'per_invoice_detailed';
    }
  }

  /// Maps structure to backend API structure string.
  String toApiPackingListStructure() {
    switch (structure) {
      case PackingListStructure.byHsCode:
        return 'by_hs_code';
      case PackingListStructure.flat:
        return 'flat';
      case PackingListStructure.byPallet:
        return 'by_pallet';
      case PackingListStructure.byCarton:
        return 'by_carton';
    }
  }

  PackingListExportConfig copyWith({
    FilePackagingMode? packaging,
    ContentDetailMode? detail,
    PackingListStructure? structure,
    bool? includePalletDetails,
  }) {
    final nextStructure = structure ?? this.structure;
    final isAllowed = nextStructure == PackingListStructure.byPallet || nextStructure == PackingListStructure.byCarton;
    final nextIncludePallets = isAllowed ? (includePalletDetails ?? this.includePalletDetails) : false;

    return PackingListExportConfig(
      packaging: packaging ?? this.packaging,
      detail: detail ?? this.detail,
      structure: nextStructure,
      includePalletDetails: nextIncludePallets,
    );
  }
}
