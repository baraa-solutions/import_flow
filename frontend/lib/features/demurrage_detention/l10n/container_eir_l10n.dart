import '../../../core/localization/app_localizations.dart';

/// Extension providing 100% pure language separation for Container EIR & Demurrage Freeze.
/// Adheres strictly to the ERP rule: NO mixing Arabic and English in parentheses.
extension ContainerEirLocalizationsExtension on AppLocalizations {
  String get containerEirDialogTitle =>
      isArabic ? 'توثيق إيصال إرجاع الفارغ وإيقاف الغرامة' : 'Empty Container EIR Return and Demurrage Freeze';

  String get containerEirDialogSubtitle => isArabic
      ? 'تسجيل إيصال إرجاع الحاوية الفارغة وتجميد احتساب غرامة التأخير اليومية فوراً'
      : 'Register empty container return receipt and immediately freeze daily demurrage accrual';

  String get containerLedgerTitle =>
      isArabic ? 'كشف حساب الحاويات وتتبع الغرامات الموقوفة' : 'Container Ledger and Frozen Demurrage Tracker';

  String get containerNumberLabel => isArabic ? 'رقم الحاوية' : 'Container Number';

  String get containerNumberHint => isArabic ? 'مثال: إم إس سي يو 1234567' : 'e.g. MSCU1234567';

  String get selectContainerPrompt => isArabic ? 'اختر الحاوية المراد توثيق إرجاعها' : 'Select container to return';

  String get eirNumberLabel => isArabic ? 'رقم إيصال إرجاع الحاوية الفارغة' : 'Empty Return Receipt Number';

  String get eirNumberHint => isArabic ? 'مثال: إي آي آر 998877' : 'e.g. EIR-998877';

  String get returnDateLabel => isArabic ? 'تاريخ تسليم الحاوية الفارغة' : 'Empty Container Return Date';

  String get returnTimeLabel => isArabic ? 'توقيت التسليم الدقيق' : 'Exact Return Timestamp';

  String get depotNameLabel => isArabic ? 'اسم مستودع التسليم' : 'Empty Return Depot';

  String get depotNameHint => isArabic ? 'مثال: مستودع الخط الملاحي بالدخيلة' : 'e.g. Dekheila Carrier Depot';

  String get inspectionConditionLabel => isArabic ? 'حالة الحاوية عند الفحص والاستلام' : 'Container Return Condition';

  String get conditionSoundClean => isArabic ? 'سليمة ونظيفة' : 'Sound and Clean';

  String get conditionDamaged => isArabic ? 'بها تلفيات وأضرار' : 'Damaged';

  String get conditionRequiresCleaning => isArabic ? 'تحتاج غسيل وتنظيف' : 'Requires Washing and Cleaning';

  String get truckPlateLabel => isArabic ? 'رقم لوحة الشاحنة الناقلة' : 'Truck Plate Number';

  String get truckPlateHint => isArabic ? 'مثال: أ ب ج 1234' : 'e.g. ABC 1234';

  String get customsSealLabel => isArabic ? 'رقم سيل المعاينة الجمركية' : 'Customs Inspection Seal';

  String get customsSealHint => isArabic ? 'مثال: سي يو إس 5544' : 'e.g. CUS-5544';

  String get gateOutDateLabel => isArabic ? 'تاريخ خروج البوابة' : 'Gate Out Date';

  String get demurrageFreezeNotice => isArabic
      ? 'تنبيه نظامي صارم: بمجرد اعتماد إيصال الإرجاع، يتوقف عداد غرامات التأخير وحبس الحاوية لهذه الحاوية فوراً، بينما يستمر احتساب باقي الحاويات غير المرتجعة.'
      : 'Strict System Notice: Upon validating this EIR receipt, daily demurrage and detention accumulation halts immediately for this container, while unreturned containers continue accruing fines.';

  String get notesLabel => isArabic ? 'ملاحظات تشغيلية إضافية' : 'Additional Operational Notes';

  String get notesHint => isArabic ? 'أدخل أي ملاحظات فحص أو تسليم...' : 'Enter any inspection or return notes...';

  String get confirmEirBtn => isArabic ? 'اعتماد إيصال الإرجاع وتجميد الغرامة' : 'Confirm EIR Return and Freeze Demurrage';

  String get gateOutBtn => isArabic ? 'تسجيل خروج البوابة' : 'Register Gate Out';

  String get cancelBtn => isArabic ? 'إلغاء' : 'Cancel';

  String get closeBtn => isArabic ? 'إغلاق' : 'Close';

  String get saveSuccessNotice => isArabic
      ? 'تم توثيق إيصال الإرجاع وإيقاف احتساب غرامة الحاوية بنجاح'
      : 'EIR return recorded and demurrage calculation frozen successfully';

  String get saveErrorNotice => isArabic
      ? 'حدث خطأ أثناء حفظ بيانات إرجاع الحاوية'
      : 'An error occurred while saving container return details';

  String get requiredEirNumber => isArabic ? 'يرجى إدخال رقم إيصال الإرجاع' : 'Please enter the EIR receipt number';

  String get requiredContainer => isArabic ? 'يرجى اختيار رقم الحاوية' : 'Please select a container';

  String get copyContainerNumber => isArabic ? 'نسخ رقم الحاوية' : 'Copy Container Number';

  String get copyEirNumber => isArabic ? 'نسخ رقم إيصال الإرجاع' : 'Copy EIR Receipt Number';

  String get copySuccess => isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard';

  String get statusReturnedStopped => isArabic ? 'مرتجعة فارغة - الغرامة موقوفة' : 'Returned Empty - Demurrage Stopped';

  String get statusActiveAccruing => isArabic ? 'نشطة - غرامات جارية' : 'Active - Accruing Demurrage';

  String get statusGatedOut => isArabic ? 'خرجت من البوابة' : 'Gated Out';

  String get totalContainersLabel => isArabic ? 'إجمالي الحاويات' : 'Total Containers';

  String get returnedContainersLabel => isArabic ? 'الحاويات المرتجعة' : 'Returned Containers';

  String get activeContainersLabel => isArabic ? 'الحاويات النشطة' : 'Active Containers';

  String get totalDemurrageCostLabel => isArabic ? 'إجمالي غرامات التأخير' : 'Total Demurrage Fines';

  String get totalCostEgpLabel => isArabic ? 'التكلفة الإجمالية بالجنيه' : 'Total Cost in Egyptian Pounds';

  String get individualDemurrageLabel => isArabic ? 'الغرامة الفردية للحاوية' : 'Individual Demurrage Cost';

  String get stopReasonLabel => isArabic ? 'سبب إيقاف الغرامة' : 'Demurrage Freeze Reason';

  String get noContainersFound => isArabic ? 'لا توجد حاويات مسجلة لهذا الملف' : 'No containers found for this file';

  String get openContainerEirDialog =>
      isArabic ? 'تتبع الحاويات وإيصال إرجاع الفارغ' : 'Container Tracking and EIR Return';
}
