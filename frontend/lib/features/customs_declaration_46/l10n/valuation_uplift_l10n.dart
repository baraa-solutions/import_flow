import '../../../../core/localization/app_localizations.dart';

/// Pure bilingual localization extension for Customs Valuation Uplift (EPIC-CUST-VAL).
///
/// Strictly enforces 100% pure language separation: zero parenthesized bilingual stacking.
extension ValuationUpliftL10n on AppLocalizations {
  String get valuationUpliftTitle => isArabic
      ? 'مقارنة التثمين الجمركي وتحسين السعر'
      : 'Customs Valuation Assessment and Uplift';

  String get valuationUpliftSubtitle => isArabic
      ? 'فصل القيمة التجارية للمورد عن الوعاء المقبول جمركياً وتكلفة الوصول'
      : 'Segregation of Commercial Value from Assessed Customs CIF and Landed Cost';

  String get commercialInvoiceCifLabel => isArabic
      ? 'القيمة التجارية للمورد'
      : 'Commercial Supplier CIF';

  String get customsAssessedCifLabel => isArabic
      ? 'الوعاء المقبول جمركياً للتثمين'
      : 'Customs Assessed CIF Base';

  String get valuationDifferenceLabel => isArabic
      ? 'قيمة تحسين السعر الاسترشادي'
      : 'Valuation Uplift Variance';

  String get upliftPercentageLabel => isArabic
      ? 'نسبة الزيادة الاسترشادية'
      : 'Valuation Uplift Percentage';

  String get valuationReasonLabel => isArabic
      ? 'سبب وسند التحسين الاسترشادي'
      : 'Valuation Uplift Legal Reason';

  String get statusMatched => isArabic
      ? 'مطابق للفاتورة التجارية'
      : 'Commercial Invoice Matched';

  String get statusUplifted => isArabic
      ? 'خاضع لتحسين السعر الاسترشادي'
      : 'Subject to Valuation Uplift';

  String get supplierAccountTitle => isArabic
      ? 'حساب المورد 401'
      : 'Supplier AP Account 401';

  String get supplierAccountDesc => isArabic
      ? 'مسجل بالقيمة التجارية الفعلية للفاتورة دون أي تشويه أو زيادة'
      : 'Recorded strictly at actual commercial invoice value without distortion';

  String get landedCostAccountTitle => isArabic
      ? 'حساب بضاعة بالطريق 151'
      : 'Goods in Transit Account 151';

  String get landedCostAccountDesc => isArabic
      ? 'تحميل فروق الضرائب الناتجة عن التحسين كبند تكلفة وصول مستقل'
      : 'Uplift tax additions capitalized as a separate Landed Cost item';

  String get copyValuationSummaryBtn => isArabic
      ? 'نسخ بيانات التثمين'
      : 'Copy Valuation Summary';

  String get valuationCopiedSuccess => isArabic
      ? 'تم نسخ بيانات التثمين الجمركي بنجاح'
      : 'Valuation assessment data copied successfully';

  String get egpSuffix => isArabic ? 'ج.م' : 'EGP';
  String get usdSuffix => isArabic ? 'دولار' : 'USD';

  String get customsDeclaration46Title => isArabic
      ? 'الإقرار الجمركي ونموذج 46 ك.م'
      : 'Customs Declaration 46 Registration';

  String get declarationNumberLabel => isArabic
      ? 'رقم الإقرار الجمركي'
      : 'Declaration 46 Number';

  String get declarationDateLabel => isArabic
      ? 'تاريخ قيد الإقرار'
      : 'Declaration Date';

  String get customsOfficeLabel => isArabic
      ? 'المركز الجمركي'
      : 'Customs Port Office';

  String get channelTypeLabel => isArabic
      ? 'المسار الجمركي'
      : 'Customs Inspection Channel';

  String get tariffItemsCountLabel => isArabic
      ? 'عدد بنود التعريفة الجمركية'
      : 'Tariff Items Count';

  String get mtsCertificateNumberLabel => isArabic
      ? 'رقم شهادة نافذة المرجعية'
      : 'MTS Certificate Number';

  String get exchangeRateLabel => isArabic
      ? 'سعر الصرف الجمركي'
      : 'Customs Exchange Rate';

  String get isValuationUpliftedSwitch => isArabic
      ? 'تطبيق تحسين السعر الاسترشادي'
      : 'Apply Valuation Uplift';

  String get dutiesBreakdownTitle => isArabic
      ? 'بيان الرسوم والضرائب الجمركية'
      : 'Customs Duties and Taxes Breakdown';

  String get saveDeclarationBtn => isArabic
      ? 'حفظ الإقرار والتثمين'
      : 'Save Declaration and Valuation';

  String get recalculateUpliftBtn => isArabic
      ? 'إعادة احتساب الفرق'
      : 'Recalculate Uplift';
}
