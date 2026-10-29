import 'app_localizations.dart';
import 'domain_enum_labels.dart';

/// Arabic localization for Sorour Logistics ERP.
class AppLocalizationsAr extends AppLocalizations {
  const AppLocalizationsAr();

  // ── Navigation / Sidebar ─────────────────────────────────────────────────
  @override String get appTitle => 'سرور للخدمات اللوجستية';
  @override String get appSubtitle => 'نظام إدارة الاستيراد';
  @override String get masterData => 'البيانات والجداول الأساسية';
  @override String get masterDataSub => 'البيانات المرجعية والسجلات';
  @override String get shipmentPlanning => 'تخطيط الشحنة وأوامر الشراء';
  @override String get shipmentPlanningSub => 'الملفات وأوامر الشراء والحسابات';
  @override String get phase1 => 'المرحلة 1: التخطيط والدراسات';
  @override String get phase1Sub => 'دراسات الشحن والجمارك';
  @override String get phase2 => 'المرحلة 2: بداية الشحنة';
  @override String get phase2Sub => 'الميزانية والـ ACID';
  @override String get phase3 => 'المرحلة 3: حجز الشحن والمستندات';
  @override String get phase3Sub => 'الحجز والتدقيق المستندي';
  @override String get phase4 => 'المرحلة 4: التوثيق الرقمي والبنكي';
  @override String get phase4Sub => 'CargoX والأصول والنماذج البنكية';
  @override String get phase5 => 'المرحلة 5: الميناء والتخليص';
  @override String get phase5Sub => 'التصريح الجمركي والإفراج';
  @override String get phase6 => 'المرحلة 6: الاستلام والإغلاق';
  @override String get phase6Sub => 'المستودع وتكلفة الوصول والإغلاق';
  @override String get dashboardAndReports => 'لوحة القيادة والتقارير';
  @override String get dashboardAndReportsSub => 'المؤشرات والتدقيق والتقارير';

  // ── Sidebar Menu Items ────────────────────────────────────────────────────
  @override String get importCompanies => 'الشركات المستوردة';
  @override String get foreignSuppliers => 'دليل الموردين الأجانب';
  @override String get partnersAndBanks => 'الشركاء والبنوك ومقدمو الخدمات';
  @override String get projectsAndCostCenters => 'المشاريع ومراكز التكلفة';
  @override String get portsAndLocations => 'الموانئ والمنافذ الجمركية';
  @override String get incotermsRules => 'الشروط التجارية الدولية';
  @override String get customsTariffSchedule => 'جدول التعريفة الجمركية';
  @override String get currenciesAndRates => 'العملات وأسعار الصرف';
  @override String get importFiles => 'ملفات الشحنات الاستيرادية';
  @override String get purchaseOrders => 'أوامر الشراء وإثبات المنشأ';
  @override String get cbmCalculator => 'حاسبة الأحجام وتوزيع الحاويات';
  @override String get freightStudies => 'دراسات ومفاضلة نولون الشحن';
  @override String get freightQuotations => 'مقارنة عروض أسعار الشحن';
  @override String get customsStudies => 'الدراسات والاستشارات الجمركية';
  @override String get clearanceQuotations => 'عروض ومقايسات التخليص والاستخراج';
  @override String get importRequirements => 'متطلبات واشتراطات الاستيراد';
  @override String get financeApprovals => 'اعتمادات الميزانية وسداد الموردين';
  @override String get acidOperations => 'الرقم التعريفي المبدئي للشحنة ACID';
  @override String get freightBooking => 'حجز النولون وتأكيد الخط الملاحي';
  @override String get freightAllocations => 'تخصيص وتوزيع الحاويات';
  @override String get cargoShippingTracking => 'متابعة حركة الشحن البحري والجوي';
  @override String get packingReconciliation => 'مطابقة وتأكيد الفاتورة والباكينج';
  @override String get draftDocsReview => 'مراجعة مسودات بوالص الشحن';
  @override String get draftCOO => 'مسودة وتوليد شهادة المنشأ';
  @override String get draftInspection => 'مسودة وتوليد شهادة الفحص والمطابقة';
  @override String get docsCustomsApproval => 'الاعتماد النهائي للمستندات جمركياً';
  @override String get centralDocsHub => 'الأرشيف المركزي لمستندات الشحنة';
  @override String get customsDutyEstimator => 'حساب ومراجعة الضرائب الجمركية';
  @override String get cargoXBlockchain => 'منظومة الشحن المسبق والبلوك تشين';
  @override String get originalsCollection => 'تحصيل أصول مستندات الشحنة';
  @override String get bankForm4 => 'النموذج الإحصائي والتحويل البنكي نموذج 4';
  @override String get customsDeclaration46 => 'شهادة الإجراءات الجمركية إقرار 46 ك.م';
  @override String get customsClearanceFollowup => 'متابعة الكشف والتثمين الجمركي';
  @override String get drawingSamples => 'سحب العينات وتحديد عجز البضائع';
  @override String get discrepancyDamage => 'إثبات الفاقد والتلف الجمركي';
  @override String get finalCustomsPayment => 'سداد الرسوم والضرائب الجمركية النهائية';
  @override String get demurrageDetention => 'تتبع غرامات الأرضيات وحراسات الحاويات';
  @override String get goodsInTransit => 'رصيد ومطابقة البضاعة في الطريق';
  @override String get warehouseReceiving => 'إذن إضافة المخزن واستلام الشحنة';
  @override String get receivedShipmentsReport => 'تقرير الشحنات المستلمة بالمخزن';
  @override String get landedCostSettlement => 'حساب تكلفة الوصول النهائية للوحدة';
  @override String get landedCostComparison => 'مقارنة تكاليف الوصول';
  @override String get importFileFinalClosure => 'الإغلاق المالي والإداري لملف الاستيراد';
  @override String get operationalDashboard => 'لوحة التحكم ومؤشرات الأداء';
  @override String get lifecycleBoard => 'لوحة تتبع ومراحل الشحنات التفاعلية';
  @override String get masterShipmentReport => 'تقرير الشحنة الشامل المدمج';
  @override String get dynamicReportBuilder => 'مُنشئ التقارير المخصصة';
  @override String get quickUpdateEngine => 'محرك التحديث السريع';
  @override String get smartTasksAndAlerts => 'المهام والتنبيهات الذكية';
  @override String get systemAuditLogs => 'سجل التدقيق والرقابة';
  @override String get productionSyncHub => 'مركز مزامنة وتحديث الإنتاج';
  @override String get swiftReconciliation => 'مطابقة سويفت والتحويلات';
  @override String get cargoInsurance => 'تأمين الشحن البحري';
  @override String get userManagement => 'إدارة المستخدمين والصلاحيات';
  @override String get tabOptionsTooltip => 'خيارات النوافذ والتبويبات';
  @override String get closeOtherTabs => 'إغلاق التبويبات الأخرى';
  @override String get closeAllTabs => 'إغلاق كل التبويبات الإضافية';

  // ── Buttons ───────────────────────────────────────────────────────────────
  @override String get save => 'حفظ';
  @override String get saveDraft => 'حفظ مؤقت';
  @override String get saveAndConfirm => 'حفظ وتأكيد السجل';
  @override String get updateRecord => 'تحديث وحفظ السجل';
  @override String get cancel => 'إلغاء';
  @override String get close => 'إغلاق وتراجع';
  @override String get resetForm => 'تفريغ وبدء تسجيل جديد';
  @override String get refresh => 'تحديث';
  @override String get liveRefresh => 'إعادة تحميل حية';
  @override String get edit => 'تعديل';
  @override String get delete => 'حذف';
  @override String get viewDetails => 'عرض التفاصيل';
  @override String get print => 'طباعة وتصدير';
  @override String get exportExcel => 'تصدير Excel';
  @override String get exportPdf => 'تصدير PDF';
  @override String get importExcel => 'استيراد Excel';
  @override String get downloadTemplate => 'تحميل النموذج';
  @override String get uploading => 'جاري الرفع...';
  @override String get backToDashboard => 'العودة للداش بورد';

  // ── Common Messages ───────────────────────────────────────────────────────
  @override String get connectionError => 'تعذر الاتصال بسيرفر النظام';
  @override String get connectionErrorDetail =>
      'تأكد من تشغيل سيرفر الباك إند ثم اضغط على زر إعادة المحاولة.';
  @override String get retryConnection => 'إعادة المحاولة وتحديث البيانات';
  @override String get loading => 'جاري التحميل...';
  @override String get saving => 'جاري الحفظ...';
  @override String get noData => 'لا توجد بيانات';
  @override String get search => 'بحث';
  @override String get searchHint => 'بحث سريع...';
  @override String get clearSearch => 'مسح';
  @override String get ok => 'موافق';
  @override String get confirm => 'تأكيد';
  @override String get warning => 'تحذير';
  @override String get error => 'خطأ';
  @override String get success => 'نجاح';
  @override String get importSuccessful => 'تم الاستيراد بنجاح';
  @override String get approved => 'معتمد';
  @override String get pending => 'قيد الانتظار';
  @override String get statusPending => 'قيد الانتظار';
  @override String get rejected => 'مرفوض';
  @override String get importWithAlerts => 'تم الاستيراد مع تنبيهات';
  @override String get alertsErrors => 'التنبيهات والأخطاء:';
  @override String get preparingExport => 'جاري تحضير ملف التصدير...';
  @override String get dataActionsTitle => 'عمليات البيانات والتصدير/الاستيراد';

  // ── System Info ───────────────────────────────────────────────────────────
  @override String get systemVersion => 'إصدار المنظومة';
  @override String get buildId => 'رقم البناء';
  @override String get backendEngine => 'الخادم المدمج';
  @override String get database => 'قاعدة البيانات';
  @override String get operatingMode => 'نمط التشغيل';
  @override String get licenseAndRights => 'الترخيص والحقوق';
  @override String get systemInfo => 'معلومات الإصدار والنظام';
  @override String get syncHub => 'مركز المزامنة والتحديث';
  @override String get expandSidebar => 'إظهار القائمة الجانبية الكاملة';
  @override String get collapseSidebar => 'إخفاء القائمة لتوسيع الشاشة';
  @override String get userOptions => 'خيارات المستخدم';
  @override String get logout => 'تسجيل الخروج';
  @override String get versionBadge => 'v1.0.2 (Build 2026.08)';

  // ── Tooltips ─────────────────────────────────────────────────────────────
  @override String get viewDetailsTooltip => 'عرض التفاصيل';
  @override String get editTooltip => 'تعديل السجل';
  @override String get printTooltip => 'طباعة وتصدير PDF';
  @override String get deleteTooltip => 'حذف / إيقاف التفعيل';
  @override String get syncHubTooltip => 'مركز مزامنة وتحديث الإنتاج';
  @override String get systemInfoTooltip => 'معلومات الإصدار والنظام';
  @override String get backToDashboardTooltip => 'العودة إلى لوحة التحكم';
  @override String get languageToggleTooltip => 'تغيير اللغة (عربي / إنجليزي)';
  @override String get confirmDeleteTitle => 'تأكيد الحذف';
  @override String confirmDeleteMessage(String code) => code.isNotEmpty ? 'هل أنت متأكد من حذف "$code"؟ لا يمكن التراجع عن هذا الإجراء.' : 'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.';
  @override String get deletedSuccessfully => 'تم الحذف بنجاح';
  @override String get copyCode => 'نسخ الكود';
  @override String get moreActionsTooltip => 'إجراءات إضافية';
  @override String get deactivateRecord => 'تعطيل السجل';
  @override String get restoreRecord => 'استعادة السجل';
  @override String get viewActivityLog => 'سجل النشاطات';
  @override String get editRecord => 'تعديل السجل';
  @override String get genericErrorMessage => 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.';
  @override String get tableSearchHint => 'بحث...';
  @override String get tableNoData => 'لا توجد سجلات';
  @override String get tableNoResults => 'لا توجد نتائج مطابقة للبحث أو الفلاتر';
  @override String get tableClearFilters => 'إعادة ضبط الفلاتر';
  @override String get tableCustomizeColumns => 'تخصيص الأعمدة';
  @override String get tableExportCsv => 'تصدير CSV';
  @override String get tableExportExcel => 'تصدير Excel';
  @override String get tableRowCopied => 'تم نسخ بيانات الصف إلى الحافظة';
  @override String get tableRetry => 'إعادة المحاولة';
  @override String get tableActions => 'الإجراءات';
  @override String tableTotalCount(int count) => 'الإجمالي: $count سجل';
  @override String tableSelectedCount(int count) => 'تم تحديد $count';
  @override String get resetToDefaults => 'استعادة الافتراضي';
  @override String get apply => 'تطبيق';
  @override String get recordNotFoundOrDeleted => 'السجل غير موجود أو تم حذفه';
  @override String get entityNotFoundOrDeleted => recordNotFoundOrDeleted;
  @override String get entityDetailsTitle => 'تفاصيل السجل';
  @override String get importFilePickerSelectFile => 'اختر ملف الاستيراد';
  @override String get importFilePickerNoFilesFound => 'لا توجد ملفات استيراد متاحة';
  @override String get importFilePickerFileRequired => 'يرجى اختيار ملف الاستيراد للمتابعة';
  @override String get importFilePickerContinue => 'متابعة';
  @override String get importFilePickerSearchHint => 'ابحث برقم الملف، المورد، الشركة...';

  // ── Role Switcher ─────────────────────────────────────────────────────────
  @override String get switchAsAdmin => 'تبديل كـ: مدير النظام 🔴';
  @override String get switchAsManager => 'تبديل كـ: مدير 🔵';
  @override String get switchAsSpecialist => 'تبديل كـ: أخصائي 🟢';
  @override String get productionSyncTitle => 'مزامنة ونشر الإنتاج';

  // ── Sidebar Search ────────────────────────────────────────────────────────
  @override String get quickSearch => 'بحث سريع...';

  // ── Operational Dashboard ───────────────────────────────────────────────────
  @override String get operationalDashboardTitle => 'لوحة التحكم ومساحة العمليات';
  @override String get priority => 'الأولوية:';
  @override String get priorityAll => 'الكل';
  @override String get priorityLow => 'منخفض';
  @override String get priorityMedium => 'متوسط';
  @override String get priorityHigh => 'عالي';
  @override String get priorityCritical => 'حرج';
  @override String get customsBrokerLabel => 'المخلص الجمركي:';
  @override String get allBrokers => 'جميع المخلصين';
  @override String get quickSearchLabel => 'بحث سريع:';
  @override String get dashboardSearchHint => 'كود الشحنة، أمر الشراء، المورد...';
  @override String get resetFilters => 'إعادة ضبط الفلاتر';
  @override String get clearFilter => 'إلغاء التصفية';
  @override String get serverConnectionError => 'تعذر الاتصال بسيرفر الخادم';
  @override String get serverConnectionHint => 'يرجى التأكد من تشغيل خادم الباك إند أو الضغط على زر إعادة المحاولة.';
  @override String get matchingShipments => 'عدد الشحنات المطابقة';
  @override String get lastUpdated => 'آخر تحديث للبيانات';
  @override String get noMatchingShipments => 'لا توجد شحنات مطابقة';
  @override String get noMatchingShipmentsDesc => 'لم يتم العثور على أي شحنات تطابق خيارات التصفية الحالية.';
  @override String get clearFiltersShowAll => 'إلغاء الفلاتر وعرض الكل';
  @override String get currentPhase => 'المرحلة الحالية';
  @override String get operationalStep => 'الخطوة التشغيلية';
  @override String get unassigned => 'غير محدد';
  @override String get closedShipment => 'شحنة مغلقة';
  @override String get recordDailyUpdate => 'تسجيل تحديث يومي';
  @override String get closeStopShipment => 'إغلاق وإيقاف الشحنة';
  @override String get nextStepAction => '🎯 النقطة التالية والإجراء القادم:';
  @override String get responsiblePerson => 'المسؤول';
  @override String get executeStepNow => 'تنفيذ الخطوة الآن';
  @override String get openShipmentTasks => 'قائمة المهام التنفيذية المفتوحة للشحنة';
  @override String get manageAllTasks => 'إدارة كل المهام';
  @override String get taskCompletedSuccessfully => '✅ تم إنجاز المهمة بنجاح';
  @override String get riskAlertsCenter => 'مركز التنبيهات والمخاطر التشغيلية:';
  @override String get dailyCheckinsLog => 'سجل التحديثات التشغيلية واليومية المباشرة:';
  @override String get addDailyUpdate => 'إضافة تحديث يومي';
  @override String get noDailyUpdates => 'لا توجد تحديثات يومية مسجلة اليوم.';
  @override String get aiSmartExtractorTitle => 'أداة التكويد والاستخراج الذكي بالذكاء الاصطناعي:';
  @override String get smartExtractSupplier => 'تكويد مورد أجنبي ذكي 🌍';
  @override String get smartExtractCompany => 'تكويد شركة مستوردة ذكي 🏢';
  @override String get smartExtractPartner => 'تكويد شريك أو مخلص ذكي 🤝';
  @override String get smartExtractBank => 'تكويد بنك معتمد ذكي 🏦';
  @override String get quickShortcutsTitle => 'روابط الاختصارات السريعة لإنشاء وإدخال السجلات:';
  @override String get createNewProject => 'إنشاء مشروع جديد';
  @override String get createNewImportFile => 'إنشاء ملف استيرادي';
  @override String get createNewImportCompany => 'إنشاء شركة مستوردة';
  @override String get createNewSupplier => 'إنشاء مورد خارجي';
  @override String get createNewPartnerBank => 'إنشاء بنك أو شريك معتمد';
  @override String get createNewCustomsTariff => 'إدخال تعريفة جمركية';
  @override String get createNewLocation => 'إدخال موانئ ومواقع';
  @override String get createNewCurrency => 'إدخال عملة جديدة';
  @override String get createNewExchangeRate => 'تعديل سعر صرف جديد';
  @override String get interactiveOperationsBoardTitle => 'لوحة تتبع ومراحل الشحنات التفاعلية';
  @override String get interactiveOperationsBoardDesc => 'لوحة بصرية متكاملة مدمجة داخل البرنامج (6 مراحل كبرى — 25 خطوة تشغيلية) تدعم تتبع وتعدد المراحل النشطة ونقل الشحنات لحظياً.';
  @override String get openInteractiveBoard => 'فتح لوحة المراحل التفاعلية';
  @override String get lifecycleBoardSummaryTitle => 'ملخص مسار عمليات الشحنات (25 خطوة تشغيلية)';
  @override String get lifecycleBoardSummaryDesc => 'متابعة حية لتوزيع ملفات الشحنات عبر 6 مراحل رئيسية و 25 خطوة تشغيلية تفصيلية';
  @override String get fullOperationsBoardButton => 'لوحة مسار العمليات الكاملة (25 خطوة) ↗️';
  @override String get shipmentCountUnit => 'شحنة';
  @override String get tasksCountUnit => 'مهام';
  @override String get kpiTodaysTasks => 'مهام اليوم';
  @override String get kpiTodaysTasksSub => 'المهام المطلوب تنفيذها اليوم';
  @override String get kpiPendingTasks => 'المهام المعلقة';
  @override String get kpiPendingTasksSub => 'المهام التي لم يتم الانتهاء منها';
  @override String get kpiUpcomingShipments => 'الشحنات القادمة';
  @override String get kpiUpcomingShipmentsSub => 'متوقع وصولها القادم';
  @override String get kpiArrivingThisWeek => 'شحنات هذا الأسبوع';
  @override String get kpiArrivingThisWeekSub => 'وصول بالأسبوع الحالي';
  @override String get kpiEtaChanges => 'تعديلات موعد الوصول المتوقع';
  @override String get kpiEtaChangesSub => 'تم تعديل موعد وصولها';
  @override String get kpiWaitingPayment => 'معلق للسداد';
  @override String get kpiWaitingPaymentSub => 'موافقات مالية معلقة (المرحلة 2)';
  @override String get kpiWaitingForm4 => 'بانتظار نموذج 4';
  @override String get kpiWaitingForm4Sub => 'إجراءات نموذج 4 بنك مصر';
  @override String get kpiPendingRequirements => 'متطلبات معلقة';
  @override String get kpiPendingRequirementsSub => 'مستندات وموافقات غير مكتملة';
  @override String get kpiHighPriorityAlerts => 'تنبيهات عالية الأولوية';
  @override String get kpiHighPriorityAlertsSub => 'أولوية عالية وحرجة';
  @override String get retry => 'إعادة المحاولة';
  @override String get purchaseOrder => 'أمر الشراء:';

  // ── Task E: Drill-down Dialog & KPI Cards ──────────────────────────────────
  @override String get drillDownDialogTitle => 'تفاصيل وسجلات';
  @override String get drillDownItemsCountSuffix => 'عنصر';
  @override String get drillDownSearchHint => 'بحث بالاسم، كود الشحنة، المسؤول...';
  @override String get drillDownCopyAllBtn => 'نسخ كافة السجلات';
  @override String get drillDownCopiedAllToast => 'تم نسخ كافة السجلات إلى الحافظة بنجاح';
  @override String get drillDownCopiedItemToast => 'تم نسخ السجل إلى الحافظة';
  @override String get drillDownEmptyTitle => 'لا توجد سجلات حالياً';
  @override String get drillDownEmptyDesc => 'لا توجد عناصر مطابقة لهذه الفئة في الوقت الحالي. ستظهر أي عناصر قادمة هنا تلقائياً فور توفرها.';
  @override String get drillDownLabelWhat => 'الموضوع / الإجراء المطلوب';
  @override String get drillDownLabelWho => 'المسؤول / الجهة المعنية';
  @override String get drillDownLabelWhen => 'الموعد المحدد / التوقيت';
  @override String get drillDownLabelStatus => 'الحالة';
  @override String get drillDownLabelNextAction => 'الخطوة التالية';
  @override String get drillDownDataGapBadge => 'فجوة بيانات';
  @override String get drillDownTimeDataGap => 'التوقيت الدقيق بالساعة (HH:mm) غير مسجل بقاعدة البيانات (مسجل كتاريخ فقط).';
  @override String get drillDownPendingReasonDataGap => 'كود سبب التعليق غير مسجل في جدول مخصص؛ مستخرج من الملاحظات أو حالة التأخير.';
  @override String get drillDownEtaChangeDataGap => 'تاريخ الوصول المجدول مسجل؛ سجل التعديلات السابقة وأسباب التغيير لم يبدأ تتبعه بعد.';
  @override String get drillDownPaymentDeadlineDataGap => 'الموعد النهائي المحدد من البنك للسداد غير مسجل بشكل مستقل عن تاريخ جاهزية الشحنة.';
  @override String get drillDownActionFocusShipment => 'عرض وتحديد الشحنة';
  @override String get drillDownActionCompleteTask => 'إتمام المهمة';
  @override String get drillDownActionDailyUpdate => 'تسجيل تحديث';
  @override String get drillDownCloseBtn => 'إغلاق';
  @override String get drillDownCardClickHint => 'اضغط للاطلاع على كافة السجلات والتفاصيل';

  // ── Operational Dashboard Exports, Pathways & Steps ────────────────────────
  @override String get operationalExportTsvBtn => 'تصدير جدول العمليات جدولي';
  @override String get operationalExportExcelBtn => 'تصدير إكسيل مفصل';
  @override String get operationalExportPdfBtn => 'طباعة تقرير العمليات';
  @override String get operationalCopyDossierBtn => 'نسخ ملخص العمليات';
  @override String get operationalExportTsvDialogTitle => 'حفظ جدول العمليات التشغيلية';
  @override String get operationalExportExcelDialogTitle => 'حفظ ملف إكسيل العمليات التشغيلية';
  @override String get operationalReportTitle => 'تقرير مساحة العمليات والمتابعة التشغيلية';
  @override String get operationalPdfSystemBranding => 'نظام سرور للخدمات اللوجستية وإدارة الاستيراد والتخليص الجمركي';
  @override String get operationalPdfOfficialBadge => 'وثيقة رسمية معتمدة';
  @override String get operationalPdfFilterCriteria => 'معايير التصفية: ';
  @override String get operationalReportGeneratedAt => 'تاريخ ووقت الإصدار';
  @override String get operationalReportGeneratedBy => 'المستخدم';
  @override String get operationalDossierCriteria => 'معايير التصفية: ';
  @override String get operationalCopiedTsvSuccess => 'تم حفظ وتصدير جدول العمليات بنجاح';
  @override String get operationalCopiedExcelSuccess => 'تم حفظ وتصدير ملف إكسيل بنجاح';
  @override String get operationalCopiedDossierSuccess => 'تم نسخ ملخص مساحة العمليات إلى الحافظة بنجاح';
  @override String get operationalTsvHeaderShipmentName => 'اسم الشحنة';
  @override String get operationalTsvHeaderFileCode => 'كود ملف الاستيراد';
  @override String get operationalTsvHeaderCustomFileNo => 'رقم الملف الجمركي';
  @override String get operationalTsvHeaderImporter => 'الشركة المستوردة';
  @override String get operationalTsvHeaderSupplier => 'المورد الأجنبي';
  @override String get operationalTsvHeaderPriority => 'الأولوية';
  @override String get operationalTsvHeaderCurrentPhase => 'المرحلة الحالية';
  @override String get operationalTsvHeaderOperationalStep => 'الخطوة التشغيلية';
  @override String get operationalTsvHeaderBroker => 'المخلص الجمركي';
  @override String get operationalTsvHeaderPoNumber => 'أمر الشراء';
  @override String get operationalTsvHeaderProgress => 'نسبة الإنجاز';
  @override String get operationalTsvHeaderNextAction => 'المسار التالي المطلوب';
  @override String get operationalTsvHeaderStatus => 'حالة الشحنة';
  @override String operationalPdfPageOf(int page, int total) => 'صفحة $page من $total';

  @override String get pathwayPrevFilePlanning => 'المسار السابق: تخطيط الملف';
  @override String get pathwayPrevFreightStudies => 'المسار السابق: دراسات ومفاضلة النولون';
  @override String get pathwayCurrent => 'المسار الحالي';
  @override String get pathwayNext => 'المسار التالي المطلوب';
  @override String get pathwayNextImportReqs => 'مراجعة اشتراطات الاستيراد والموافقات الرقابية';

  @override String get nextStepDefaultTitle => 'متابعة الإجراءات التشغيلية';
  @override String get nextStepDefaultDesc => 'استكمال متطلبات المرحلة الحالية';
  @override String get responsibleImportTeam => 'فريق الاستيراد';
  @override String get nextStepImportReqsTitle => 'المسار التالي: استيفاء اشتراطات ومتطلبات الاستيراد (خطوة 03)';
  @override String get nextStepImportReqsDesc => 'مراجعة بنود التعريفة والموافقات المسبقة من الجهات الرقابية وهيئات الفحص والتسجيل';
  @override String get responsibleImportSpecialist => 'أخصائي الاستيراد والتخليص الجمركي';
  @override String get nextStepCustomsConsultTitle => 'المسار التالي: إعداد الاستشارة والدراسة الجمركية (خطوة 02)';
  @override String get nextStepCustomsConsultDesc => 'مراجعة بنود التعريفة الجمركية واحتساب الضرائب والرسوم المقدرة وتكليف المخلص';
  @override String get nextStepFinanceApprovalTitle => 'المرحلة 2: الاعتماد المالي وصرف الدفعة';
  @override String get nextStepFinanceApprovalDesc => 'مراجعة الميزانية وإصدار طلب الصرف والتحويل البنكي للمورد';
  @override String get responsibleFinanceDept => 'الإدارة المالية';
  @override String get nextStepNafezaAcidTitle => 'المرحلة 3: استخراج رقم التسجيل المسبق وتوثيق المستندات رقمياً';
  @override String get nextStepNafezaAcidDesc => 'تسجيل الشحنة على نافذة واستخراج رقم التسجيل المسبق للشحنات';
  @override String get responsibleNafezaSpecialist => 'أخصائي نافذة';
  @override String get nextStepFreightBookingTitle => 'المرحلة 4: حجز الشحن وتأكيد تخصيص الحاويات وبوالص الشحن';
  @override String get nextStepFreightBookingDesc => 'تأكيد حجز الباخرة مع الخط الملاحي وإصدار مسودة البوليصة وتأكيد الشحن';
  @override String get nextStepTransitTrackingTitle => 'المرحلة 5: تتبع الإبحار والتوثيق الإلكتروني ومراقبة الوصول';
  @override String get nextStepTransitTrackingDesc => 'متابعة إبحار السفينة وتاريخ الوصول المتوقع واستلام مستندات الشاحن';
  @override String get responsibleShippingCarrier => 'وكيل الشحن';
  @override String get nextStepArrivalNoticeTitle => 'المرحلة 6: إشعار وصول الشحنة وقيد الإقرار الجمركي 46';
  @override String get nextStepArrivalNoticeDesc => 'استلام إخطار الوصول وتكليف المخلص الجمركي بفتح ملف الكشف الجمركي';
  @override String get nextStepDutyPaymentTitle => 'المرحلة 7: استكمال الكشف وسداد الرسوم وإصدار إذن الإفراج';
  @override String get nextStepDutyPaymentDesc => 'متابعة المعاينة الجمركية وسحب العينات وسداد الضرائب والرسوم';
  @override String get nextStepInlandTransportTitle => 'المرحلة 8: النقل الداخلي واستلام المخازن وإذن الإضافة المخزنية';
  @override String get nextStepInlandTransportDesc => 'تنسيق سيارات النقل واستلام البضاعة في المخازن وفحص الكميات والجودة';
  @override String get responsibleWarehouseCustodian => 'أمين المخزن';
  @override String get nextStepLandedCostTitle => 'المرحلة 9: تسوية تكلفة الاستيراد الشاملة والنهائية';
  @override String get nextStepLandedCostDesc => 'تجميع كافة الفواتير ومصاريف النولون والجمارك واحتساب التكلفة الفعلية';
  @override String get responsibleFinanceAuditing => 'الحسابات والمراجعة المالية';
  @override String get nextStepClosureTitle => 'المرحلة 10: مراجعة شروط الأرشفة وإغلاق الملف التاريخي';
  @override String get nextStepClosureDesc => 'التحقق من اكتمال كافة الفواتير والمستندات وإغلاق الملف نهائياً';
  @override String get responsibleImportManager => 'مدير الاستيراد';

  // ── Screen 1: Import Files & Shipments ────────────────────────────────────
  @override String get importFilesManagementTitle => 'إدارة وملفات استيراد الشحنات';
  @override String get uploadImportDocument => 'رفع وثيقة ملف استيراد (PDF / Word / Excel)';
  @override String get addNewImportFile => 'إضافة ملف استيراد شحنة جديد';
  @override String get editImportFile => 'تعديل وتحديث بيانات ملف الاستيراد';
  @override String get generateComprehensiveReport => 'استخراج تقرير الشحنات الشامل';
  @override String get searchByShipmentOrCompany => 'بحث بكود الشحنة أو الشركة...';
  @override String get statusAll => 'جميع الحالات';
  @override String get statusOpen => 'مفتوح';
  @override String get statusInProgress => 'قيد التنفيذ';
  @override String get statusClosed => 'مغلق';
  @override String get importFileIdLabel => 'رقم ملف الاستيراد';
  @override String get importingCompany => 'الشركة المستوردة';
  @override String get foreignSupplier => 'المورد الأجنبي';
  @override String get status => 'الحالة';
  @override String get actions => 'إجراءات';
  @override String get smartInvoiceBlExtractorButton => 'استخلاص الفواتير والبوالص الذكي';
  @override String get whatIfSimulatorButton => 'محاكي الأزمات وتحوط الصرف';
  @override String get colIncoterms => 'الشروط التجارية';
  @override String get colPort => 'الميناء';
  @override String get colWarehouse => 'المستودع';
  @override String get colDirectTransit => 'مباشر / ترانزيت';
  @override String get colPickupDate => 'تاريخ الاستلام';
  @override String get colDocDate => 'تاريخ المستندات';
  @override String get colSwift => 'رقم السويفت البنكي';
  @override String get colCarrier => 'الخط الملاحي / الناقل';
  @override String get colAcid => 'رقم القيد الجمركي المبدئي';
  @override String get colForm4 => 'نموذج 4 البنكي';
  @override String get colForm46 => 'إقرار 46 ك.م';
  @override String get saveComprehensiveReportDialogTitle => 'حفظ التقرير الشامل لملفات الاستيراد بصيغة Excel / CSV';
  @override String get poNumberShortPrefix => 'أمر شراء: ';
  @override String get piNumberShortPrefix => 'فاتورة مبدئية: ';
  @override String get importFileReviewChangesTitle => 'مراجعة وتأكيد تعديلات ملف الاستيراد';
  @override String get importFileSavedSuccess => 'تم حفظ وتحديث ملف الاستيراد بنجاح!';
  @override String get notesInstructions => 'الملاحظات والتعليمات';
  @override String get poInvoiceLabel => 'أمر الشراء / الفاتورة';
  @override String get transportModeIncoterm => 'وسيلة النقل / الشروط';
  @override String get priorityType => 'الأولوية';
  @override String get targetEta => 'تاريخ الوصول المتوقع';
  @override String get currentPhaseStage => 'المرحلة الحالية';
  @override String get progressPercentLabel => 'نسبة الإنجاز %';
  @override String get nextActionLabel => 'الخطوة القادمة';
  @override String get responsiblePersonLabel => 'المسؤول';
  @override String get stopShipmentTooltip => 'إغلاق وإيقاف الشحنة عند هذه المرحلة';
  @override String get reopenShipmentTooltip => 'إعادة فتح وتنشيط الشحنة المغلقة';
  @override String get freightRfqTooltip => 'طلب أسعار نولون الشحن';
  @override String get printFileHistoryTooltip => 'طباعة ملف الشحنة الشامل والتاريخ التشغيلي';
  @override String get noImportFilesFound => 'لا توجد ملفات استيراد مسجلة بالنظام. اضغط إضافة ملف جديد.';
  @override String get confirmDeleteImportFileTitle => 'تأكيد الحذف';
  @override String get confirmDeleteImportFileMessage => 'هل أنت متأكد من حذف ملف الاستيراد رقم';
  @override String get evaluateMasterReportTitle => 'استخراج وتقييم تقرير الشحنات الشامل';
  @override String get selectShipmentForReport => 'اختر رقم الشحنة / ملف الاستيراد المطلوب إنشاء التقرير المدمج الخاص بها:';
  @override String get allShipmentFiles => 'جميع الشحنات والملفات';
  @override String get shipmentNoPrefix => 'شحنة رقم:';
  @override String get createAndDisplayReport => 'إنشاء وعرض التقرير';
  @override String get masterImportReportTitle => 'تقرير ملخص ملفات الاستيراد المدمج والشامل';
  @override String get filteredForShipment => 'مصفى لحساب الشحنة رقم:';
  @override String get printReport => 'طباعة التقرير';
  @override String get filterReportByShipment => 'تصفية التقرير برقم الشحنة:';
  @override String get totalFilesMetric => 'إجمالي الملفات';
  @override String get openFilesMetric => 'الملفات المفتوحة';
  @override String get inProgressMetric => 'قيد التنفيذ';
  @override String get totalCostMetric => 'إجمالي التكلفة';
  @override String get operationalTrackingMatrixSection => '1. جدول التتبع العملياتي للشحنات';
  @override String get cargoAndLinkedPosSection => '2. ملخص الفواتير وأحجام التعبئة وأوامر الشراء التفصيلية لكل شحنة';
  @override String get invoicesCountAndNumbers => 'عدد الفواتير وأرقامها';
  @override String get invoicesUnit => 'فواتير';
  @override String get totalCbmFromPackingList => 'إجمالي الـ CBM من قوائم التعبئة';
  @override String get cbmSumDescription => 'مجموع CBM كافة قوائم التعبئة';
  @override String get totalGrossWeightFromPl => 'إجمالي الوزن القائم';
  @override String get grossWeightSumDescription => 'مجموع الوزن من كافة قوائم التعبئة';
  @override String get linkedPurchaseOrdersTitle => 'أوامر الشراء المرتبطة';
  @override String get posUnit => 'أوامر شراء';
  @override String get packingListsUnit => 'قوائم تعبئة';
  @override String get noLinkedPosForFile => 'لا توجد أوامر شراء مسندة حالياً لهذا الملف.';
  @override String get paymentTermsLabel => 'طريقة وشروط السداد';
  @override String get packingListItemsCol => 'قوائم التعبئة';
  @override String get weightCbmCol => 'الوزن / CBM';
  @override String get palletsShippingPlan => 'بالتة (مخطط الشحن)';
  @override String get packingItemsCount => 'بند تعبئة';
  @override String get visualLoadPlannerTitle => 'مخطط ومحاكاة رص الحاويات';
  @override String get containerLoadPlanButton => 'مخطط رص الحاويات';
  @override String get exportReportExcelPdf => 'تصدير التقرير';
  @override String get reportCopiedToClipboard => 'تم إعداد نسخة التقرير المدمجة ونقلها للحافظة بنجاح! جاهز للطباعة';
  @override String get csvExportSuccess => 'تم استخراج وتنزيل تقرير ملخص ملفات الاستيراد المدمج بصيغة CSV بنجاح!';
  @override String get sideViewTitle => 'مسقط جانبي';
  @override String get topViewTitle => 'مسقط علوي';
  @override String get internalDimensions => 'الأبعاد الداخلية';
  @override String get containerLoadFailed => 'فشل التحميل (طرود كبيرة الحجم/الوزن)';
  @override String get containerOverfilled => 'ممتلئة طوليًا (أبعاد الممر تعوق الرص الجانبي)';
  @override String get containerEmpty => 'فاضية جدًا لسه (استغلال طول ومساحة ضعيف)';
  @override String get containerGoodUtil => 'استغلال جيد للمساحة';
  @override String get allStackableChip => 'بضائع تقبل الرص';
  @override String get allNonStackableChip => 'بضائع لا تقبل الرص';
  @override String get mixedStackingChip => 'مزيج يقبل ولا يقبل الرص';
  @override String get containerSpecType => 'نوع الحاوية';
  @override String get requiredCount => 'العدد المطلوب';
  @override String get effectiveCapacityCbm => 'السعة الفعالة CBM';
  @override String get spaceUtilizationPercent => 'استغلال المساحة %';
  @override String get weightUtilizationPercent => 'استغلال الوزن %';
  @override String get acidStatusTitle => 'بيانات القيد الجمركي المبدئي';
  @override String get customsReleasedBadge => 'صُرفت من الجمرك (معفى من التنبيهات)';
  @override String get underClearanceBadge => 'قيد التخليص والصرف';
  @override String get cargoStackingScenariosTitle => 'نتائج احتمالات رص الحاويات وتوزيع الشحنة';
  @override String get scenariosMatrixButton => 'مقارنة الحالات البديلة';
  @override String get scenarioAllStackableTitle => 'الاحتمال الأول: بضائع تقبل الرص بالكامل';
  @override String get scenarioAllNonStackableTitle => 'الاحتمال الثاني: بضائع لا تقبل الرص';
  @override String get scenarioMixedStackingTitle => 'الاحتمال الثالث: مزيج يقبل ولا يقبل الرص';
  @override String get saveContainerImageTooltip => 'حفظ صورة المخطط';
  @override String get exportContainerExcelTooltip => 'تصدير إكسل (Export Excel)';
  @override String get exportContainerPdfTooltip => 'تصدير تقرير PDF';
  @override String get saveContainerImageDialogTitle => 'حفظ صورة مخطط الحاوية PNG';
  @override String get exportContainerExcelDialogTitle => 'تصدير جدول محاكي الحاويات Excel';
  @override String get exportContainerPdfDialogTitle => 'تصدير تقرير محاكي الحاويات PDF';
  @override String get containerImageCaptureError => 'تعذر التقاط صورة المخطط من الشاشة.';
  @override String get containerExportError => 'خطأ أثناء تصدير الملف: ';
  @override String get closePlannerBtn => 'إغلاق المخطط';
  @override String get savedShippingStudiesTitle => 'دراسات وسيناريوهات الشحن المسجلة للشحنة';
  @override String get date => 'التاريخ';
  @override String get shipmentCategoryLabel => 'تصنيف الشحنة';
  @override String get fileOpeningDateLabel => 'تاريخ فتح الملف';
  @override String get logisticsAndPortsDetails => 'بيانات النقل وموانئ الشحن لطلب النولون';
  @override String get portOfLoadingLabel => 'ميناء الشحن';
  @override String get portOfDischargeLabel => 'ميناء الوصول والتفريغ';
  @override String get cargoReadyDateLabel => 'تاريخ جاهزية البضاعة';
  @override String get targetFreeDaysLabel => 'أيام السماح المطلوبة (FT)';
  @override String get serviceTypePreferenceLabel => 'تفضيل مسار الخدمة';
  @override String get pickupAddressLabel => 'عنوان الاستلام / المصنع';
  @override String get shippingInstructionsLabel => 'تعليمات واشتراطات الشحن الخاصة';
  @override String get multiProjectsTitle => 'إسناد الشحنة للمشاريع';
  @override String get notes => 'الملاحظات والتعليمات';
  @override String get liveReload => 'إعادة تحميل حية';
  @override String get clearAndReset => 'تفريغ وبدء تسجيل جديد';
  @override String get customsClearanceBroker => 'المخلص الجمركي';
  @override String get freightRfqTitle => 'طلب أسعار نولون الشحن الدولي';
  @override String get emailDraftTab => 'نموذج الإيميل الرسمي';
  @override String get whatsappTemplateTab => 'رسالة الواتساب';
  @override String get shipmentSpecsTab => 'ملخص مواصفات الشحنة';
  @override String get grossWeightMetric => 'الوزن القائم';
  @override String get netWeightMetric => 'الوزن الصافي';
  @override String get commodityTitle => 'اسم البضاعة';
  @override String get closeShipmentTitle => 'إيقاف وإغلاق الشحنة';
  @override String get reason => 'سبب الإيقاف والملاحظات';
  @override String get cbmVolumeMetric => 'الحجم الإجمالي بالمتر المكعب';
  @override String get currency => 'العملة';
  @override String get owner => 'المسؤول';
  @override String get purchaseOrdersTitle => 'أوامر الشراء والفواتير المبدئية';
  @override String get purchaseOrdersSubtitle => 'المرحلة الأولى: إدارة وتسجيل أوامر الشراء، الفواتير المبدئية، وحساب الـ CBM والأوزان الإجمالية';
  @override String get smartInvoiceExtract => 'استخراج الفاتورة والتعبئة الذكي';
  @override String get newPurchaseOrder => 'أمر شراء جديد';
  @override String get editPurchaseOrder => 'تعديل أمر الشراء';
  @override String get totalOrdersMetric => 'إجمالي أوامر الشراء';
  @override String get totalFobMetric => 'إجمالي قيمة البضاعة';
  @override String get totalCargoCbmMetric => 'إجمالي الحجم CBM';
  @override String get totalGrossWeightMetric => 'إجمالي الوزن القائم';
  @override String get searchByPoHint => 'بحث برقم أمر الشراء أو الفاتورة أو الملاحظات...';
  @override String get filterByProject => 'تصفية حسب المشروع';
  @override String get allProjects => 'جميع المشاريع';
  @override String get filterByStatus => 'تصفية حسب الحالة';
  @override String get allStatuses => 'جميع الحالات';
  @override String get showInactive => 'إظهار غير النشط';
  @override String get poReferenceCol => 'رقم أمر الشراء';
  @override String get invoiceDateCol => 'تاريخ الفاتورة';
  @override String get importFileCol => 'ملف الاستيراد';
  @override String get piNumberCol => 'رقم الفاتورة المبدئية';
  @override String get countryOfOriginCol => 'بلد المنشأ';
  @override String get actionsCol => 'الإجراءات';
  @override String get poLineItemsTab => 'بنود الفاتورة المبدئية';
  @override String get reviewPackingListTab => 'بيان التعبئة والوزن';
  @override String get palletizationPlanTitle => 'مخطط وحدات الشحن والبالتات';
  @override String get totalPalletsMetric => 'إجمالي البالتات';
  @override String get palletSimulation3D => 'محاكاة ورص الحاويات 3D';
  @override String get palletTypeCol => 'نوع ومقاس البالتة';
  @override String get palletCountCol => 'عدد البالتات';
  @override String get palletDimensionsCol => 'الأبعاد (L × W × H)';
  @override String get palletWeightCol => 'وزن البالتة القائم';
  @override String get palletTotalWeightCol => 'إجمالي الوزن';
  @override String get palletVolumeCol => 'حجم السطر CBM';
  @override String get palletStackingInstructionsCol => 'تعليمات الرص';
  @override String get stackable => 'قابل للرص';
  @override String get nonStackable => 'غير قابل للرص';
  @override String get discrepancyWarningTitle => 'تنبيه: عدم تطابق بين الفاتورة المبدئية وبيان التعبئة';
  @override String get discrepancyJustificationLabel => 'سبب الاستمرار وتبرير الاختلاف';
  @override String get backToEdit => 'الرجوع للتعديل';
  @override String get continueAndSave => 'الاستمرار وحفظ أمر الشراء';
  @override String get summaryByHsCodeReport => 'ملخص بيان التعبئة حسب البند الجمركي';
  @override String get hsCode => 'البند الجمركي';
  @override String get quantityMetric => 'الكمية';
  @override String get requiredField => 'هذا الحقل مطلوب';
  @override String enterFieldHint(String label) => 'أدخل $label...';
  @override String get saveChanges => 'حفظ التعديلات';
  @override String get noDataFound => 'لا توجد بيانات مسجلة';
  @override String get statusDraft => 'مسودة';
  @override String get statusPoApproved => 'معتمد';
  @override String get statusInTransit => 'في الطريق';
  @override String confirmDeactivatePo(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل أمر الشراء ($name)؟';
  @override String confirmRestorePo(String name) => 'هل أنت متأكد من استعادة أمر الشراء ($name)؟';
  @override String get deactivatePoTooltip => 'إيقاف تفعيل أمر الشراء';
  @override String get restorePoTooltip => 'استعادة أمر الشراء';
  @override String get poBalanceLedgerTooltip => 'ميزان أمر الشراء والشحنات الجزئية';
  @override String printPoAndPackingList(String name, String code) => 'طباعة أمر الشراء وقائمة التعبئة: $name ($code)';
  @override String get cbmAndGrossWeightCol => 'الحجم CBM والوزن القائم';
  @override String get masterPalletPlanTitle => 'مخطط وحدات الشحن والبالتات';
  @override String palletCountWithUnit(int count) => '$count بالتة';
  @override String palletCbmWithUnit(String cbm) => 'حجم البالتات: $cbm م³';
  @override String simulateAndLoad3d(int count) => 'محاكاة ورص الحاويات 3D ($count بالتة)';
  @override String get qtyPcsCol => 'القطع PCS';
  @override String get qtyPkgCol => 'الطرود PKG';
  @override String get dimensionsCmCol => 'الأبعاد (سم)';
  @override String get netWeightCol => 'الوزن الصافي (كجم)';
  @override String get grossWeightCol => 'الوزن القائم (كجم)';
  @override String get totalNetWeightCol => 'إجمالي الوزن الصافي (كجم)';
  @override String get totalGrossWeightCol => 'إجمالي الوزن القائم (كجم)';
  @override String get noCargoOrPalletToSimulate => 'لا توجد أصناف قائمة تعبئة أو بالتات للمحاكاة';
  @override String get noSuitableContainers => 'لا توجد حاويات مناسبة';
  @override String containerLoadPlanTitle(String name, String code) => 'مخطط الرص وتوزيع الحاويات 3D — $name ($code)';
  @override String containerLoadPlanMetrics(String volume, String weight, String fleet) => 'حجم الشحنة: $volume م³ | الوزن: $weight كجم | الحاويات المطلوبة: $fleet';
  @override String get topView => 'مسقط علوي';
  @override String get sideView => 'مسقط جانبي';
  @override String containerIndexTitle(int index, String name) => 'حاوية #$index: $name';
  @override String packagesOrPalletsCount(int count) => '$count طرد / بالتة';
  @override String get copyAllData => 'نسخ كافة البيانات';
  @override String get copyAllPoDataSuccess => 'تم نسخ كافة بيانات وبنود أمر الشراء بنجاح (جاهزة للصق في Excel أو Word)';

  // ── CBM Calculator ───────────────────────────────────────────────────────
  @override String get cbmCalculatorTitle => 'حاسبة الأحجام والوزن الجوي';
  @override String get cbmCalculatorSubtitle => 'احتساب الأحجام CBM، الوزن الجوي المحاسبي، وتوصيات الحاويات ووسيلة الشحن';
  @override String get quickOperationalCalculatorTab => 'حاسبة القياسات التشغيلية السريعة';
  @override String get savedCalculationsRegistryTab => 'سجل دراسة وحسابات الشحن المحفوظة';
  @override String get activeEditSessionBanner => 'وضع تعديل جلسة محفوظة';
  @override String get activeEditSessionHint => 'يتم الآن تعديل طرود وقياسات هذه الجلسة. يمكنك حفظ التعديلات مباشرة في نفس الجلسة أو كجلسة جديدة.';
  @override String get saveChangesInSession => 'حفظ التعديلات في الجلسة';
  @override String get newBlankSession => 'جلسة جديدة فارغة';
  @override String get totalCbmVolumeMetric => 'إجمالي الحجم بالمتر المكعب';
  @override String get airChargeableWtMetric => 'الوزن الجوي المحاسبي';
  @override String get volumetricWeight => 'الوزن الحجمي';
  @override String get recommendedShippingMetric => 'وسيلة الشحن المقترحة';
  @override String get cargoStackingInstructions => 'تعليمات التحميل والرص:';
  @override String get stackableOption => 'قابل للرص';
  @override String get nonStackableOption => 'غير قابل للرص';
  @override String get allStackableOption => 'بضائع تقبل الرص';
  @override String get allNonStackableOption => 'بضائع لا تقبل الرص';
  @override String get mixedStackingOption => 'مزيج يقبل ولا يقبل الرص';
  @override String get compareContainersMatrix => 'مقارنة خيارات الحاويات';
  @override String get visualLoadPlanSimulator => 'مخطط ومحاكاة رص الحاويات';
  @override String get packageMeasurementsTitle => 'أبعاد وأوزان طرود الشحنة';
  @override String get airFreightMode => 'شحن جوي';
  @override String get seaFreightMode => 'شحن بحري';
  @override String get addPackageLine => 'إضافة سطر طرد';
  @override String get saveCalculationSession => 'حفظ الجلسة التشغيلية';
  @override String get saveAsNewSession => 'حفظ كجلسة جديدة';
  @override String get unitCol => 'الوحدة';
  @override String get qtyCol => 'العدد';
  @override String get lengthCol => 'الطول';
  @override String get widthCol => 'العرض';
  @override String get heightCol => 'الارتفاع';
  @override String get stackingCol => 'الرص';
  @override String get grossWtPerUnitCol => 'وزن الوحدة (كجم)';
  @override String get calculatedOutputsCol => 'النتائج المحسوبة';
  @override String get deleteRowTooltip => 'حذف السطر';
  @override String get packageTypeCol => 'نوع الطرد';
  @override String get calculationSessionTitle => 'عنوان جلسة الحساب';
  @override String get notesAndCargoRemarks => 'ملاحظات ومواصفات البضاعة';
  @override String get containerOptionsAnalysis => 'تحليل خيارات الحاويات وسيناريوهات التحميل';
  @override String get totalShipmentSummary => 'إجمالي الشحنة';
  @override String get approvedRecommendation => 'التوصية المعتمدة';
  @override String get containerSpecCol => 'نوع ومواصفات الحاوية';
  @override String get requiredCountCol => 'العدد المطلوب';
  @override String get spaceUtilizationCol => 'استغلال المساحة %';
  @override String get weightUtilizationCol => 'استغلال الوزن %';
  @override String get recommendationCol => 'التوصية';
  @override String get bestOptionBadge => 'الخيار الأنسب';
  @override String get viableAlternative => 'بديل قابل للتطبيق';
  @override String get chooseStackingScenario => 'اختر سيناريو الرص للمعاينة:';
  @override String get smartHybridOption => '🌟 رص ذكي هجين (أفقي + على السيف)';
  @override String get flatOnlyOption => '📦 رص مسطح فقط';
  @override String get onEdgeOption => '📐 رص على السيف فقط';
  @override String get smartHybridSavingsMessage => '💡 التوصية الذكية: يوفر الرص الهجين حاويات إضافية بتعبئة المساحات الجانبية!';
  @override String get orientationPreferenceLabel => 'نمط الرص المفضل:';
  @override String get requiredFleet => 'الأسطول المطلوب:';
  @override String get containerPlanTitle => 'مخطط رص الحاوية';
  @override String get closePlan => 'إغلاق المخطط';
  @override String get totalCalculationsMetric => 'إجمالي الحسابات';
  @override String get activeSessionsMetric => 'جلسات نشطة';
  @override String get totalGrossWeightRegistryMetric => 'إجمالي الوزن القائم';
  @override String get refreshRegistry => 'تحديث السجل';
  @override String get searchCalculationsHint => 'ابحث بكود الحساب، العنوان، ملف الشحنة، أو الملاحظات...';
  @override String get calcCodeCol => 'كود الحساب';
  @override String get shippingStrategyCol => 'استراتيجية الشحن';
  @override String get recommendedContainerCol => 'الحاوية المقترحة';
  @override String get linkPoProjectCol => 'الارتباط (أمر شراء / مشروع)';
  @override String get confirmSoftDelete => 'تأكيد الحذف المنطقي';
  @override String get confirmDeleteCalcMessage => 'هل أنت متأكد من حذف جلسة الحساب هذه؟ يمكن استعادتها لاحقاً من قائمة إظهار الملغية.';
  @override String get operationFailed => 'فشلت العملية';
  @override String get operationSuccessful => 'تمت العملية بنجاح';
  @override String get showDeleted => 'إظهار الملغية';
  @override String get hideDeleted => 'إخفاء الملغية';
  @override String get restore => 'استعادة';
  @override String cbmSessionDetailsTitle(String code) => 'تفاصيل دراسة الأحجام والأوزان ($code)';
  @override String get cbmSessionActiveBadge => 'جلسة نشطة';
  @override String get cbmSessionCancelledBadge => 'جلسة ملغاة';
  @override String cbmSessionLinkedPo(String po) => 'أمر شراء: $po';
  @override String cbmSessionImportFile(String file) => 'ملف: $file';
  @override String get cbmSessionStandalone => 'جلسة مستقلة';
  @override String cbmCargoNotes(String notes) => 'ملاحظات الشحنة: $notes';
  @override String cbmCreationDate(String date) => 'تاريخ الإنشاء: $date';
  @override String cbmStrategy(String strategy) => 'الاستراتيجية: $strategy';
  @override String get cbmStandardMetricsTitle => 'المؤشرات القياسية ومحددات الشحن:';
  @override String get cbmContainerComparisonTitle => 'مقارنة سيناريوهات الحاويات:';
  @override String get cbmScenarioApprovedStackable => 'المعتمد: سيناريو القابل للرص';
  @override String get cbmScenarioApprovedNonStackable => 'المعتمد: سيناريو غير القابل للرص';
  @override String get cbmScenarioHypothesisCol => 'السيناريو والفرضية';
  @override String get cbmScenarioStackableCol => 'سيناريو يقبل الرص';
  @override String get cbmScenarioNonStackableCol => 'سيناريو لا يقبل الرص';
  @override String get cbmRequiredContainerCount => 'الحاوية والعدد المطلوب';
  @override String get cbmSpaceUtilizationPercent => 'نسبة استغلال المساحة %';
  @override String get cbmReopenInCalcBtn => 'إعادة فتح وتعديل في الحاسبة';
  @override String get cbmEditMetadataBtn => 'تعديل البيانات';
  @override String get cbmLinkToPoProjectBtn => 'ربط بأمر شراء / مشروع';
  @override String get cbmPrintExportReportBtn => 'طباعة وتصدير التقرير';
  @override String cbmEditMetadataDialogTitle(String code) => 'تعديل بيانات الجلسة: $code';
  @override String get cbmMetadataTitleLabel => 'عنوان دراسة القياسات *';
  @override String get cbmMetadataNotesLabel => 'ملاحظات وبيان الشحنة';
  @override String get cbmMetadataSavedSuccess => 'تم تحديث بيانات الجلسة بنجاح';
  @override String cbmPrintableReportTitle(String code) => 'تقرير احتساب حجوم وأوزان الشحنة ($code)';
  @override String get cbmPrintDownloadCsvBtn => 'تنزيل ملف بيانات CSV';
  @override String get cbmPrintReportBtn => 'طباعة التقرير';
  @override String cbmLinkPoDialogTitle(String code) => 'ربط الجلسة ($code) بشحنة وأمر شراء';
  @override String get cbmLinkSelectPoLabel => 'اختر أمر الشراء';
  @override String get cbmLinkSelectPoSearchHint => 'ابحث عن أمر الشراء...';
  @override String get cbmLinkSelectProjectLabel => 'اختر المشروع';
  @override String get cbmLinkSelectProjectSearchHint => 'ابحث عن المشروع...';
  @override String get cbmLinkSavedSuccess => 'تم ربط سجل الحسابات بنجاح';
  @override String get cbmVisualPlannerTitle => 'مخطط ومحاكاة رص الحاويات';
  @override String get cbmFloorAreaUtilization => 'استغلال أرضية الحاوية';
  @override String get cbmWoodenPalletsFloor => 'طبالي خشبية أرضية';
  @override String get cbmInternalDimensionsLabel => 'الأبعاد الداخلية:';
  @override String get cbmPackageDimensionsCol => 'الأبعاد L x W x H (cm)';
  @override String get cbmStackingAccepts => '📦 يقبل الرص';
  @override String get cbmStackingRejects => '🚫 لا يقبل الرص';
  @override String get cbmNotLinked => 'غير مرتبط';
  @override String get cbmDownloadCsvTitle => 'حفظ تقرير قياسات وأوزان الشحنة بصيغة CSV / Excel';
  @override String cbmSendingReportToScreen(String code) => 'جار إرسال التقرير $code للشاشة التفاعلية للطباعة والتصدير...';
  @override String get cbmRowLineCbm => 'CBM';
  @override String get cbmRowLineGross => 'الإجمالي';
  @override String get cbmRowLineAirVol => 'الوزن الجوي';
  @override String get copyAllCbmDataSuccess => 'تم نسخ بيانات جلسة الحساب كاملةً إلى الحافظة.';

  // ── Freight Studies (Shipping Scenarios) ───────────────────────────────────
  @override String get freightStudiesTitle => 'دراسات وسيناريوهات الشحن والمفاضلة';
  @override String get scenariosEvaluatorTab => 'دراسة وسيناريوهات الشحن';
  @override String get savedEvaluationsLogTab => 'سجل الدراسات المحفوظة';
  @override String get extractFreightQuotes => 'استخراج عروض أسعار النولون';
  @override String get activeEditStudyBanner => 'وضع تعديل دراسة محفوظة';
  @override String get activeEditStudyHint => 'يتم الآن تعديل خيارات وعروض هذه الدراسة. سيتم حفظ التعديلات على نفس الدراسة.';
  @override String get cancelEditAndStartNew => 'إلغاء التعديل والبدء من جديد';
  @override String get avgWarehouseArrivalMetric => 'متوسط موعد التوصيل للمخزن';
  @override String get earliestLineMetric => 'أسرع خط ملاحي وصولاً';
  @override String get latestLineMetric => 'أبطأ خط ملاحي وصولاً';
  @override String get recommendedLineMetric => 'الخط الموصى به رسمياً';
  @override String get studySetupAndParameters => 'إعدادات ومعلمات دراسة الشحن';
  @override String get studyTitleLabel => 'مسمى دراسة خيارات الشحن';
  @override String get crdLabel => 'تاريخ جاهزية البضاعة';
  @override String get avgForm4DaysLabel => 'أيام نموذج 4 المتوقعة';
  @override String get avgClearanceDaysLabel => 'أيام التخليص الجمركي المتوقعة';
  @override String get cargoStackingType => 'نوع التحميل والتخزين';
  @override String get shippingCarrierOptions => 'خيارات وعروض شحن الشركات';
  @override String get addNewShippingOption => 'إضافة خيار شحن جديد';
  @override String get freightForwarderCol => 'وكيل الشحن / الناقل';
  @override String get shippingLineCol => 'الخط الملاحي';
  @override String get vesselNameCol => 'اسم الباخرة / الرحلة';
  @override String get voyageCol => 'رقم الرحلة';
  @override String get portOfLoadingCol => 'ميناء التحميل والشحن';
  @override String get portOfDischargeCol => 'ميناء الوصول والتفريغ';
  @override String get sailingDateCol => 'تاريخ الإبحار الفعلي';
  @override String get estimatedArrivalDateCol => 'تاريخ تاريخ الوصول المتوقع';
  @override String get expectedDelayCol => 'أيام التأخير المتوقعة';
  @override String get riskLevelCol => 'مستوى المخاطر';
  @override String get freeTimeDaysCol => 'أيام السماح المجانية';
  @override String get quoteCurrencyCol => 'عملة عرض السعر';
  @override String get quoteDetails => 'تفاصيل عرض السعر';
  @override String get hideQuote => 'إخفاء عرض السعر';
  @override String get totalQuoteValue => 'إجمالي قيمة العرض';
  @override String rateMissingWarning(String codes) => 'سعر الصرف مفقود: $codes';
  @override String scenarioSaveRateMissingError(int index, String provider, String codes) => 'تعذر حفظ دراسة الشحن: سعر الصرف مفقود للعملات ($codes) في سيناريو $index ($provider).';
  @override String get container40ftItem => 'شحن حاوية 40 قدم';
  @override String get container20ftItem => 'شحن حاوية 20 قدم';
  @override String get lclCbmItem => 'شحن CBM لشحنة LCL';
  @override String get expressCourierItem => 'البريد السريع للمستندات';
  @override String get eurAtrItem => 'شهادة المنشأ التفضيلية';
  @override String get solasVgmItem => 'مصاريف التحقق من الوزن (SOLAS/VGM)';
  @override String get vgmNotificationItem => 'إخطار إقرار الوزن (VGM Notification)';
  @override String get telexReleaseItem => 'إطلاق الفاكس الملاحي (Telex Release)';
  @override String get insuranceItem => 'بوليصة التأمين البحري';
  @override String get bookingCancellationItem => 'غرامة إلغاء الحجز';
  @override String get ics2FilingFeeItem => 'رسوم إيداع بيان الحمول الرقمية (ICS2)';
  @override String get documentFeesItem => 'مصاريف المستندات الإضافية';
  @override String get waiverLetterFeeItem => 'مصاريف خطاب التنازل';
  @override String get othersFeeItem => 'مصاريف أخرى';
  @override String get dthcItem => 'تفريغ ومناولة ميناء الوصول (DTHC)';
  @override String get storagePerWeekItem => 'أرضيات / تخزين لأول أسبوع';
  @override String get extraDayStorageItem => 'أرضيات / تخزين لليوم الإضافي';
  @override String get clearanceBrokerFeeItem => 'أتعاب التخليص الجمركي';
  @override String get inspectionFeeItem => 'مصاريف الفحص والعرض الجمركي';
  @override String get inlandTransportFeeItem => 'النقل والتعتيق الداخلي للمصنع';
  @override String get portClearanceExpensesItem => 'مصاريف الموانئ والأرضيات والتخليص';
  @override String get suggestedSuffix => 'مقترح';
  @override String get applicable => 'مطبق';
  @override String get notApplicable => 'غير مطبق';
  @override String get itemPriceCol => 'سعر البند';
  @override String get sideBySideComparison => 'جدول المقارنة التفصيلي لخيارات الشحن';
  @override String get saveAndSubmitStudy => 'حفظ الدراسة والنتائج';
  @override String get saveDraftContinueLater => 'حفظ مؤقت ومتابعة لاحقة';
  @override String get clearAndStartNew => 'تفريغ وبدء تسجيل جديد';
  @override String get totalStudiesMetric => 'إجمالي الدراسات';
  @override String get avgTransitMetric => 'متوسط الترانزيت';
  @override String get withRecommendationMetric => 'مع توصية';
  @override String get searchStudiesHint => 'ابحث بكود الدراسة، العنوان، أو الملاحظات...';
  @override String get studyCodeCol => 'كود الدراسة';
  @override String get optionsCountCol => 'عدد الخيارات';
  @override String get confirmDeleteStudyMessage => 'هل أنت متأكد من حذف هذه الدراسة؟ يمكن استعادتها لاحقاً من قائمة إظهار الملغية.';
  @override String get quantity => 'الكمية';
  @override String get activeStatus => 'نشطة';
  @override String get noResultsFound => 'لا توجد نتائج مطابقة للبحث';
  @override String get linkImportFile => 'ربط بملف استيراد';
  @override String get titleField => 'العنوان';
  @override String get linkPurchaseOrder => 'ربط بأمر الشراء';
  @override String get linkProject => 'ربط بمشروع';
  @override String get confirmDelete => 'تأكيد الحذف';
  @override String get view => 'عرض';
  @override String get statusCol => 'الحالة';

  // ── Screen 6: Customs Studies & Consultations ──────────────────────────
  @override String get customsStudiesTitle => 'مركز الاستشارة والفحص ومراجعة الضرائب الجمركية';
  @override String get customsWorkspaceTab => 'مركز الاستشارة والفحص الجمركي';
  @override String get consultationsLogTab => 'سجل الدراسات المحفوظة';
  @override String get brokerPriceListsTab => 'قوائم الأسعار وتكويد المصروفات';
  @override String get clearanceQuotesTab => 'عروض التخليص والاستخراج الذكي';
  @override String get taxReviewWorkspaceTab => 'مركز احتساب ومراجعة الضرائب';
  @override String get taxReviewLogTab => 'سجل مراجعات الضرائب المحفوظة';
  @override String get customsDutyReviewTitle => 'مركز مراجعة واحتساب الضرائب والرسوم الجمركية';
  @override String get customsInspectionReadiness => 'جاهزية الفحص الجمركي';
  @override String get itemsAndDocsCount => 'عدد البنود والمستندات';
  @override String get blockingIssuesCount => 'عوائق التخليص';
  @override String get clearanceReadyStatus => 'جاهزة للتخليص';
  @override String get avgReadinessMetric => 'متوسط الجاهزية';
  @override String get openBlockingIssues => 'عوائق مفتوحة';
  @override String get searchConsultationsHint => 'بحث بالكود أو العنوان أو المستخلص...';
  @override String get statusFilterLabel => 'تصفية الحالة';
  @override String get customsCalculationEngine => 'محرك حساب الرسوم والضرائب الجمركية للشحنة';
  @override String get customsCalculationEngineSub => 'يستدعي بنود التعريفة الجمركية والقيم والاشتراطات تلقائياً من ملف الشحنة وأوامر الشراء المربوطة ويحسب الجمارك وضريبة القيمة المضافة ورسم التنمية';
  @override String get fetchReconciledFinalInvoice => 'استدعاء بنود وقيم الفاتورة والباكينج ليست النهائية المعتمدة';
  @override String get syncHsRequirementsToChecklist => 'مزامنة اشتراطات بنود التعريفة الجمركية مع قائمة المستندات';
  @override String get customsExchangeRate => 'سعر الصرف الجمركي';
  @override String get studyDateLabel => 'تاريخ الدراسة الجمركية';
  @override String get freightEgpLabel => 'النولون البحري أو الجوي';
  @override String get insuranceEgpLabel => 'التأمين البحري';
  @override String get customsTariffItemCol => 'بند التعريفة';
  @override String get itemDescriptionAndOriginCol => 'بيان الصنف والمنشأ';
  @override String get quantityAndUnitCol => 'الكمية والوحدة';
  @override String get fobEgpCol => 'القيمة تسليم ميناء الشحن فوب';
  @override String get cifEgpCol => 'القيمة الجمركية الشاملة سيف';
  @override String get customsDutyCol => 'ضريبة الوارد';
  @override String get vatCol => 'ضريبة القيمة المضافة';
  @override String get otherTaxesCol => 'ضريبة الجدول ورسم التنمية والخدمات';
  @override String get totalTaxesAndDutiesCol => 'إجمالي الضرائب والرسوم';
  @override String get regulatoryRequirementsCol => 'الاشتراطات والعروض';
  @override String get customsChecklistTitle => 'قائمة فحص واشتراطات المستندات الجمركية';
  @override String get addNewChecklistItem => 'إضافة بند جديد للفحص';
  @override String get responsiblePartyLabel => 'الجهة المسؤولة';
  @override String get blockingConditionTooltip => 'بند يعطل الإفراج الجمركي';
  @override String get nonBlockingConditionTooltip => 'بند غير معطل للإفراج';
  @override String get applyAndLinkFinancialEstimate => 'اعتماد وربط التقدير المالي للدراسة';
  @override String get smartClearanceQuoteExtractor => 'استخراج ذكي لمقايسة تخليص';
  @override String get saveCustomsStudy => 'حفظ دراسة الاستشارة الجمركية';
  @override String get saveTaxReviewSession => 'حفظ جلسة مراجعة الضرائب الجمركية';
  @override String get saveConsultationChanges => 'حفظ تعديلات المراجعة الجمركية';
  @override String get consultationDetailsTitle => 'تفاصيل دراسة ومراجعة التخليص الجمركي';
  @override String get blockingIssuesTitle => 'تقرير عوائق واشتراطات التخليص الجمركي المفتوحة';
  @override String get nafezaDeclarationBreakdown => 'تفاصيل بنود التحصيل وإقرار نافذة الجمركي';
  @override String get categoryCol => 'التصنيف';
  @override String get totalExpenses => 'إجمالي المصروفات';
  @override String get export => 'تصدير';
  @override String get allFiles => 'جميع الملفات';
  @override String get requiredDocCheckbox => 'مستند إلزامي';
  @override String get blockingShipmentCheckbox => 'مانع للشحن والتخليص';
  @override String get responsibleCustomsBroker => 'المستخلص الجمركي';
  @override String get responsibleSupplierExporter => 'المورد أو المصدر الأجنبي';
  @override String get responsibleImporterTeam => 'فريق الاستيراد بالشركة';
  @override String get responsibleFreightForwarder => 'وكيل الشحن والنقل';
  @override String get validationIssuesTitle => 'تنبيهات واستيفاء بيانات الدراسة';
  @override String get validationIssuesDesc => 'يرجى استكمال البيانات الإلزامية التالية لتتمكن من حفظ الدراسة بنجاح.';
  @override String get validationTitleRequired => 'عنوان وموضوع الاستشارة الجمركية';
  @override String get validationTitleRequiredDesc => 'حقل إلزامي لا يمكن تركه فارغاً.';
  @override String get validationTitleRequiredRec => 'يرجى كتابة عنوان واضح وموجز لموضوع دراسة الفحص والاستشارة الجمركية.';
  @override String get validationBrokerRequired => 'المستخلص الجمركي المعني';
  @override String get validationBrokerRequiredDesc => 'لم يتم تحديد المستخلص الجمركي المسؤول عن دراسة الملف.';
  @override String get validationBrokerRequiredRec => 'يرجى اختيار المستخلص الجمركي من القائمة المنسدلة.';
  @override String get validationChecklistRequired => 'قائمة الفحص والمستندات الجمركية';
  @override String get validationChecklistRequiredDesc => 'قائمة فحص المستندات والاشتراطات فارغة تماماً.';
  @override String get validationChecklistRequiredRec => 'يرجى إضافة مستند أو اشتراط واحد على الأقل في قائمة الفحص.';
  @override String get consultationReviewChangesTitle => 'مراجعة وتأكيد تعديلات الدراسة الجمركية';
  @override String get sectionGeneralInfo => 'البيانات العامة للدراسة';
  @override String get sectionBrokerInfo => 'المستخلص الجمركي';
  @override String get sectionFinancialEstimates => 'التقديرات المالية';
  @override String get sectionOperationalLink => 'الربط التشغيلي';
  @override String get sectionChecklistDocs => 'قائمة فحص المستندات';
  @override String get totalDocsCountLabel => 'إجمالي عدد المستندات والاشتراطات';
  @override String docsCountSuffix(dynamic count) => '$count مستند';
  @override String get activeEditBannerDesc => 'قم بتعديل بيانات الفحص والمستندات والرسوم ثم اضغط "حفظ التعديلات" لتحديث الدراسة نفسها، أو "حفظ كنسخة جديدة" لإنشاء دراسة منفصلة.';
  @override String activeEditBannerTitle(dynamic code) => 'وضع التعديل النشط: أنت الآن تقوم بتعديل دراسة الاستشارة الجمركية رقم ($code)';
  @override String get saveEditsBtn => 'حفظ التعديلات';
  @override String get saveAsNewCopyBtn => 'حفظ كنسخة جديدة';
  @override String get cancelEditTooltip => 'إلغاء التعديل والعودة كدراسة جديدة فارغة';
  @override String get convertedToNewSessionToast => 'تم تحويل الجلسة إلى دراسة جديدة منفصلة، اضغط "حفظ دراسة الاستشارة الجمركية" للحفظ';
  @override String get defaultStudyTitleClearance => 'دراسة المراجعة الجمركية الأولية لخط إنتاج ومعدات الشحنة';
  @override String get defaultStudyTitleTaxReview => 'مراجعة واحتساب الضرائب والرسوم الجمركية للشحنة';
  @override String get varianceCol => 'الفارق والتغير';
  @override String get preliminaryPoLabel => 'مبدئي:';
  @override String get recalculatedLabel => 'المعاد احتسابه:';
  @override String get varianceLabel => 'الفارق:';
  @override String get originPrefix => 'المنشأ:';
  @override String get applyRecalculatedDutiesTitle => 'اعتماد وتطبيق الرسوم الجمركية والضرائب الجديدة';
  @override String applyRecalculatedDutiesSuccess(dynamic amount) => 'تم اعتماد وتطبيق قيمة الرسوم الجمركية والضرائب الجديدة ($amount ج.م). يمكنك الآن حفظ أو تحديث الدراسة الجمركية.';
  @override String get selectImportFileFirstWarning => 'يرجى اختيار ملف الشحنة الاستيرادية أولاً لاستدعاء الفاتورة النهائية.';
  @override String recalculationSuccessMsg(dynamic num) => 'تم استدعاء بنود وقيم الفاتورة والباكينج ليست النهائية المعتمدة بنجاح ($num) وإعادة احتساب الرسوم بدقة.';
  @override String get recalculationFallbackMsg => 'تم احتساب الرسوم بناءً على بنود أمر الشراء المبدئي لعدم وجود جلسة مطابقة نهائية معتمدة بعد.';
  @override String recalculationErrorMsg(dynamic err) => 'تعذر استدعاء وإعادة احتساب البنود: $err';
  @override String get applyAllQuoteItems => 'تطبيق الكل';
  @override String get disableAllQuoteItems => 'تعطيل الكل';
  @override String get addCustomExpenseRow => 'إضافة مصروف إضافي';
  @override String get quoteItemApplicable => 'مطبق';
  @override String get quoteItemNotApplicable => 'غير مطبق';
  @override String get quoteItemPrice => 'سعر البند';
  @override String get quoteItemQuantity => 'الكمية';
  @override String get quoteItemCurrency => 'العملة';
  @override String get selectBrokerFirstMsg => 'يرجى اختيار المستخلص الجمركي لعرض وتطبيق قائمة أسعاره المعتمدة.';
  @override String get filterByBroker => 'تصفية حسب المخلص الجمركي';
  @override String get searchBrokerHint => 'ابحث عن مخلص...';
  @override String get createBrokerPriceListBtn => 'إنشاء قائمة أسعار جديدة لمخلص';
  @override String get noBrokerPriceListsFound => 'لا توجد قوائم أسعار مسجلة للمخلصين المحددين.';
  @override String get addPriceListNowBtn => 'إضافة قائمة أسعار الآن';
  @override String get activePriceListStatus => 'سارية';
  @override String get archivedPriceListStatus => 'مؤرشفة';
  @override String get editPricesAndItemsBtn => 'تعديل الأسعار والبنود';
  @override String get archivePriceListTooltip => 'أرشفة قائمة الأسعار';
  @override String get confirmArchivePriceListTitle => 'تأكيد أرشفة قائمة الأسعار';
  @override String confirmArchivePriceListMsg(dynamic title) => 'هل أنت متأكد من رغبتك في أرشفة قائمة الأسعار "$title"؟';
  @override String get archiveBtn => 'أرشفة';
  @override String get priceListNotesHeader => 'ملاحظات وشروط:';
  @override String get expenseItemNameCol => 'اسم المصروف أو البند';
  @override String get expenseCategoryCol => 'التصنيف';
  @override String get expenseUnitCol => 'الوحدة';
  @override String get standardPriceCol => 'السعر المعتمد';
  @override String get priceRangeAndNotesCol => 'نطاق السعر والملاحظات';
  @override String get searchExpenseCatalogHint => 'بحث في دليل المصروفات...';
  @override String get addNewExpenseTypeBtn => 'تكويد نوع مصروف جديد';
  @override String get expenseCodeCol => 'الكود';
  @override String get expenseNameArCol => 'اسم المصروف (عربي)';
  @override String get expenseNameEnCol => 'اسم المصروف (إنجليزي)';
  @override String get calculationUnitCol => 'وحدة الحساب';
  @override String get defaultCurrencyCol => 'العملة الافتراضية';
  @override String get newExpenseTypeDialogTitle => 'تكويد نوع مصروف جديد في الدليل';
  @override String get expenseCodeField => 'كود المصروف';
  @override String get expenseNameArField => 'اسم المصروف بالعربية *';
  @override String get expenseNameEnField => 'اسم المصروف بالإنجليزية (اختياري)';
  @override String get defaultCalculationUnitField => 'وحدة الحساب الافتراضية';
  @override String get saveExpenseBtn => 'حفظ المصروف';
  @override String get noBrokersRegistered => 'لا يوجد مخلصين جمركيين مسجلين في الشركاء.';
  @override String editPriceListTitle(dynamic title) => 'تعديل وتحديث أسعار قائمة المستخلص: $title';
  @override String get createPriceListTitle => 'إنشاء وتحديد أسعار قائمة جديدة للمستخلص الجمركي';
  @override String get priceListTitleField => 'عنوان قائمة الأسعار *';
  @override String get targetPortField => 'الميناء المعني';
  @override String get effectiveDateField => 'تاريخ السريان';
  @override String get generalTermsAndNotesField => 'ملاحظات وشروط عامة';
  @override String get filterCategoryLabel => 'تصفية التصنيف';
  @override String get allCategoriesItem => 'جميع التصنيفات';
  @override String get fillStandardRatesBtn => 'تعبئة بالأسعار الاسترشادية';
  @override String get zeroOutRatesBtn => 'تصفير الكل';
  @override String get standardRatesFilledToast => 'تم استدعاء وتعبئة الأسعار الاسترشادية القياسية المصرية بنجاح!';
  @override String get approvedPriceField => 'السعر المعتمد *';
  @override String get notesPriceRangeField => 'ملاحظات أو نطاق السعر';
  @override String totalExpensesCountSummary(dynamic total, dynamic priced) => 'إجمالي بنود المصروفات بالقائمة: $total بند ($priced بند مسعر بقيمة)';
  @override String get savePriceListEditsBtn => 'حفظ تعديلات القائمة';
  @override String get createAndSavePriceListBtn => 'إنشاء وحفظ قائمة الأسعار';
  @override String get priceListTitleRequired => 'يرجى كتابة عنوان قائمة الأسعار.';
  @override String get selectBrokerRequired => 'الرجاء اختيار المستخلص الجمركي';
  @override String get priceListUpdatedSuccess => 'تم تحديث وتعديل أسعار القائمة بنجاح!';
  @override String get priceListCreatedSuccess => 'تم إنشاء قائمة أسعار المخلص وحفظ الأسعار بنجاح!';
  @override String get customsExpenseCodingTitle => 'تكويد المصروفات الجمركية المرجعية';
  @override String get linkAsAliasTab => '🔗 ربط كمرادف لبند معتمد';
  @override String get registerNewCatalogCodeTab => '➕ تسجيل كود جديد بالكتالوج';
  @override String get approvedCatalogItemLabel => 'البند المعتمد في الكتالوج *';
  @override String get searchApprovedCatalogHint => 'ابحث في بنود الكتالوج المعتمدة...';
  @override String get documentAliasLabel => 'الاسم أو المرادف في المستند *';
  @override String get documentAliasHint => 'مثال: عوائد تفريغ ميناء / كارتة / أتعاب استثنائية';
  @override String get referenceItemCodeLabel => 'كود البند المرجعي *';
  @override String get searchReferenceCodeHint => 'ابحث في الأكواد المرجعية...';
  @override String get officialCategoryLabel => 'الفئة الرسمية *';
  @override String get canonicalArabicNameLabel => 'الاسم العربي المعتمد للبند *';
  @override String get canonicalEnglishNameOptionalLabel => 'الاسم بالإنجليزية (اختياري)';
  @override String get unitTypeLabel => 'نوع الوحدة *';
  @override String get approvedPriceLabel => 'السعر المعتمد *';
  @override String get itemNotesAndConditionsLabel => 'ملاحظات وشروط البند';
  @override String get saveAndMapAliasBtn => 'حفظ وتكويد المرادف';
  @override String get registerCodeInCatalogBtn => 'تسجيل الكود بالكتالوج';
  @override String itemCodedSuccessfullyToast(dynamic alias, dynamic code) => '✨ تم تكويد "$alias" وربطه بنجاح بالكود المرجعي $code';
  @override String itemRegisteredInCatalogToast(dynamic code) => '✨ تم تسجيل الكود المرجعي الجديد $code بالكتالوج بنجاح';
  @override String get needsCodingBadge => 'بحاجة لتكويد';
  @override String get customItemBadge => 'بند مخصص';
  @override String get deleteCustomItemTooltip => 'حذف البند المخصص';
  @override String get addCustomItemOrAliasBtn => '➕ تكويد بند جديد أو ربط مرادف';
  @override String get smartFileExtractionBtn => '✨ استخراج ذكي من ملف';
  @override String get fillApprovedArabicNameRequired => 'يرجى إدخال الاسم العربي المعتمد للبند';
  @override String get selectReferenceCodeRequired => 'يرجى اختيار أو تحديد كود البند المرجعي';
  @override String get pleaseEnterItemPrice => 'يرجى تحديد السعر';
  @override String get invalidItemPrice => 'السعر غير صالح';
  @override String get selectDateTooltip => 'اختيار التاريخ';
  @override String get showArchivedChip => 'إظهار المؤرشفة';
  @override String get hideArchivedChip => 'إخفاء المؤرشفة';
  @override String get restoreConsultationTitle => 'استعادة دراسة الاستشارة';
  @override String restoreConsultationMsg(dynamic code, dynamic title) => 'هل ترغب في استعادة وتفعيل دراسة الاستشارة الجمركية "$code - $title"؟';
  @override String get restoreAndActivateBtn => 'استعادة وتفعيل';
  @override String restoreConsultationSuccess(dynamic code) => 'تم استعادة وتفعيل دراسة الاستشارة ($code) بنجاح';
  @override String get deleteConsultationTitle => 'تأكيد حذف الدراسة';
  @override String deleteConsultationMsg(dynamic code, dynamic title) => 'هل أنت متأكد من حذف دراسة الاستشارة الجمركية "$code - $title"؟\n\nسيتم أرشفة الدراسة مع إمكانية استعادتها لاحقاً.';
  @override String get deleteAndArchiveBtn => 'حذف وأرشفة';
  @override String deleteConsultationSuccess(dynamic code) => 'تم حذف وأرشفة دراسة الاستشارة ($code) بنجاح';
  @override String get restoreDeletedTooltip => 'استعادة الدراسة المحذوفة';
  @override String get deleteStudyTooltip => 'حذف الدراسة (أرشفة منطقية)';
  @override String blockingIssuesBadge(dynamic count) => '$count عائق';
  @override String approvedDocsCountBadge(dynamic approved, dynamic total) => '$approved/$total مستند معتمد';
  @override String get agreementEur1 => 'اتفاقية الشراكة المصرية الأوروبية';
  @override String get agreementEur1Doc => 'شهادة حركة البضائع أصلية أو إعلان الفاتورة للمصدر المعتمد';
  @override String agreementEur1Exemption(dynamic rate) => 'إعفاء جمركي كامل لضريبة الوارد (0% بدلاً من $rate%) بموجب اتفاقية الشراكة المصرية الأوروبية.';
  @override String get agreementMercosur => 'اتفاقية التجارة الحرة مع دول الميركسور';
  @override String get agreementMercosurDoc => 'شهادة منشأ الميركسور الأصلية المستوفاة لنموذج التصديق وقواعد المنشأ';
  @override String agreementMercosurExemption(dynamic rate) => 'إعفاء جمركي كامل لضريبة الوارد (0% بدلاً من $rate%) بموجب اتفاقية التجارة الحرة مع تجمع الميركسور.';
  @override String get agreementGafta => 'منطقة التجارة الحرة العربية الكبرى';
  @override String get agreementGaftaDoc => 'شهادة منشأ عربية موحدة معتمدة من الغرفة التجارية والجمارك';
  @override String agreementGaftaExemption(dynamic rate) => 'إعفاء جمركي كامل لضريبة الوارد (0% بدلاً من $rate%) بموجب اتفاقية تيسير وتنمية التبادل التجاري بين الدول العربية.';
  @override String get agreementTurkey => 'اتفاقية التجارة الحرة مع تركيا';
  @override String get agreementTurkeyDoc => 'شهادة حركة البضائع التركية الرسمية';
  @override String agreementTurkeyExemption(dynamic rate) => 'إعفاء جمركي كامل للمنتجات الصناعية (0% بدلاً من $rate%) بموجب اتفاقية التجارة الحرة بين مصر وتركيا.';
  @override String get agreementUk => 'اتفاقية المشاركة المصرية البريطانية';
  @override String get agreementUkDoc => 'إعلان منشأ المملكة المتحدة على الفاتورة أو شهادة الحركة';
  @override String agreementUkExemption(dynamic rate) => 'إعفاء جمركي كامل (0% بدلاً من $rate%) بموجب اتفاقية المشاركة المصرية البريطانية.';
  @override String get nafezaCalculationFlat => 'قطعي';
  @override String get nafezaCalculationReference => 'مرجعي';
  @override String get nafezaCalculationDerived => 'مشتق';
  @override String get nafezaCollectionPrefix => 'تحصيل';
  @override String get statusClearanceReady => 'جاهز للإفراج';
  @override String get statusBlocked => 'معطل لوجود موانع إفراج';
  @override String get statusActionRequired => 'مطلوب إجراء';
  @override String get statusPendingReview => 'قيد المراجعة';
  @override String get statusApproved => 'معتمد ومستوفى';
  @override String get statusRejected => 'مرفوض';
  @override String get statusVerified => 'تم التحقق';
  @override String get statusReceived => 'مستلم';
  @override String get freightAutoFetchedToast => 'تم استدعاء النولون تلقائياً من سيناريوهات الشحن';
  @override String get noPoItemsForHsSync => 'لم يتم العثور على بنود أوامر شراء مرتبطة بهذا الملف لاحتساب شروطها';
  @override String hsRequirementsSyncedToast(dynamic count, dynamic addedCount) => 'تمت مزامنة اشتراطات $count بند جمركي — تم إضافة $addedCount مستند لقائمة فحص الشحنة بنجاح';
  @override String get acidReqChecklistDoc => 'قيد رقم التسجيل المسبق للشحنة الكاملة (نافذة)';
  @override String get cooReqChecklistDoc => 'شهادة المنشأ الموثقة للشحنة الكاملة';
  @override String get goeicReqChecklistDoc => 'عرض وفحص هيئة الرقابة على الصادرات والواردات للشحنة الكاملة';
  @override String authorityApprovalChecklistDoc(dynamic authority) => 'موافقة $authority الفنية المسبقة';
  @override String brokerQuoteExtractedToast(dynamic broker) => 'تم استخلاص وتطبيق بنود مقايسة التخليص بنجاح ($broker)';
  @override String activeEditModeBannerTitle(dynamic code) => 'وضع التعديل النشط: أنت الآن تقوم بتعديل دراسة الاستشارة الجمركية رقم ($code)';
  @override String get activeEditModeBannerSub => 'قم بتعديل بيانات الفحص والمستندات والرسوم ثم اضغط حفظ التعديلات لتحديث الدراسة نفسها، أو حفظ كنسخة جديدة لإنشاء دراسة منفصلة.';
  @override String get saveAsNewCopy => 'حفظ كنسخة جديدة';
  @override String get modifiedCopySuffix => 'نسخة معدلة';
  @override String get convertedToNewStudyToast => 'تم تحويل الجلسة إلى دراسة جديدة منفصلة، اضغط حفظ دراسة الاستشارة الجمركية للحفظ';
  @override String get defaultTaxReviewSessionTitle => 'مراجعة واحتساب الضرائب والرسوم الجمركية للشحنة';
  @override String get defaultCustomsConsultationTitle => 'دراسة المراجعة الجمركية الأولية لخط إنتاج ومعدات الشحنة';
  @override String get selectImportFileFirstToast => 'يرجى اختيار ملف الشحنة الاستيرادية أولاً لاستدعاء الفاتورة النهائية.';
  @override String get defaultCustomsBrokerName => 'مكتب تخليص';
  @override String get defaultImportItemDescription => 'صنف مستورد';
  @override String get customPriceListNoRegisteredTitle => 'قائمة أسعار مخصصة (لم يتم العثور على قائمة معتمدة مسجلة)';
  @override String get customsStudyValidationAlertsTitle => 'تنبيهات واستيفاء بيانات الدراسة';
  @override String get completeRequiredDataErrorMsg => 'يرجى استكمال البيانات الإلزامية التالية لتتمكن من حفظ الدراسة بنجاح.';
  @override String get consultationTitleFieldValidation => 'عنوان وموضوع الاستشارة الجمركية';
  @override String get consultationTitleFieldIssue => 'حقل إلزامي لا يمكن تركه فارغاً.';
  @override String get consultationTitleFieldRec => 'يرجى كتابة عنوان واضح وموجز لموضوع دراسة الفحص والاستشارة الجمركية.';
  @override String get customsBrokerFieldValidation => 'المستخلص الجمركي المعني';
  @override String get customsBrokerFieldIssue => 'لم يتم تحديد المستخلص الجمركي المسؤول عن دراسة الملف.';
  @override String get customsBrokerFieldRec => 'يرجى اختيار المستخلص الجمركي من القائمة المنسدلة.';
  @override String get checklistFieldValidation => 'قائمة الفحص والمستندات الجمركية';
  @override String get checklistFieldIssue => 'قائمة فحص المستندات والاشتراطات فارغة تماماً.';
  @override String get checklistFieldRec => 'يرجى إضافة مستند أو اشتراط واحد على الأقل في قائمة الفحص.';
  @override String get reviewCustomsStudyDiffTitle => 'مراجعة وتأكيد تعديلات الدراسة الجمركية';
  @override String get diffSectionGeneralData => 'البيانات العامة للدراسة';
  @override String get diffSectionCustomsBroker => 'المستخلص الجمركي';
  @override String get diffSectionFinancialEstimates => 'التقديرات المالية';
  @override String get diffSectionOperationalLink => 'الربط التشغيلي';
  @override String get diffSectionChecklist => 'قائمة فحص المستندات';
  @override String get diffFieldEstimatedDuties => 'الرسوم الجمركية والضرائب التقديرية';
  @override String get diffFieldLinkedImportFile => 'ملف الشحنة المرتبط';
  @override String get diffFieldTotalChecklistDocs => 'إجمالي عدد المستندات والاشتراطات';
  @override String get customsStudySavedSuccess => 'تم حفظ مراجعة الضرائب والرسوم الجمركية بنجاح!';
  @override String get customsStudyUpdatedSuccess => 'تم تحديث مراجعة الضرائب الجمركية بنجاح!';
  @override String get unableToSaveCustomsStudy => 'تعذر حفظ مراجعة الضرائب الجمركية';

  // ── Screen 57: Original Documents Collection & Courier ──────────────────
  @override String get originalDocsAndCargoXScaffoldTitle => 'تحصيل المستندات وكارجو إكس — المرحلة 4';
  @override String get originalDocsCollectionTabTitle => 'تحصيل أصول المستندات وتتبع الكورير';
  @override String get cargoxBlockchainTabTitle => 'منظومة كارجو إكس والمانيفست الرقمي';
  @override String get refreshDataTooltip => 'تحديث البيانات';
  @override String get originalDocsHubTitle => 'تحصيل أصول المستندات وتتبع طرود الكورير';
  @override String get originalDocsHubSubtitle => 'استدعاء تلقائي للمستندات المطلوبة من الأرشيف المركزي للشحنة، تتبع طرود البريد السريع المتعددة، وتدقيق استلام الأصول الورقية.';
  @override String savedSessionBadge(dynamic code) => 'جلسة محفوظة: $code';
  @override String get selectImportFileLabel => 'اختيار ملف الشحنة';
  @override String errorFetchingImportFiles(dynamic err) => 'خطأ في جلب ملفات الاستيراد: $err';
  @override String errorFetchingArchiveData(dynamic err) => 'خطأ في استدعاء بيانات الأرشيف: $err';
  @override String get statTotalRequiredDocs => 'إجمالي المستندات المطلوبة';
  @override String get statReceivedOriginals => 'تم استلام الأصل الورقي';
  @override String get statVerifiedDocs => 'تم الفحص والتدقيق';
  @override String get statPendingDocs => 'قيد الانتظار';
  @override String get statReadinessRate => 'نسبة الاكتمال والجاهزية';
  @override String get courierDispatchPackagesHeader => 'طرود وبوالص الشحن السريع للكورير:';
  @override String get addCourierAwbBtn => 'إضافة بوليصة كورير';
  @override String get noCouriersRegisteredMsg => 'لم يتم تسجيل بوالص كورير بعد. اضغط زر إضافة بوليصة لإدراج شحنة بريد سريع.';
  @override String get courierTrackingNoField => 'رقم بوليصة الكورير (رقم التتبع)';
  @override String get courierCompanyField => 'شركة الكورير';
  @override String get dispatchDateField => 'تاريخ الإرسال (السنة-الشهر-اليوم)';
  @override String get isReceivedCheckbox => 'تم الاستلام';
  @override String get receivedByNameField => 'اسم المستلم';
  @override String get deleteCourierTooltip => 'حذف طرد الكورير';
  @override String get physicalDocsVerificationMatrixHeader => 'مصفوفة استلام وتدقيق أصول المستندات الورقية:';
  @override String get addCustomDocBtn => 'إضافة مستند إضافي';
  @override String get defaultNewCustomDocName => 'مستند إضافي جديد';
  @override String get selectCourierPlaceholder => 'اختر الكورير';
  @override String get colCourierNo => 'رقم الكورير';
  @override String get colDocCategory => 'تصنيف الوثيقة';
  @override String get colDocName => 'اسم المستند';
  @override String get colRequirement => 'الإلزامية';
  @override String get colResponsibleParty => 'الجهة المسؤولة';
  @override String get colPhysicalReceived => 'تم الاستلام الورقي';
  @override String get colReceivedDate => 'تاريخ الاستلام';
  @override String get colVerified => 'تم الفحص والتدقيق';
  @override String get colAuditor => 'القائم بالتدقيق';
  @override String get colDocStatus => 'الحالة';
  @override String get colRemarks => 'ملاحظات';
  @override String get colAction => 'إجراء';
  @override String get hintAuditor => 'المدقق';
  @override String get hintRemarks => 'ملاحظات...';
  @override String get reqBadgeYes => 'إلزامي';
  @override String get reqBadgeConditional => 'مشروط';
  @override String get reqBadgeNo => 'اختياري';
  @override String get statusBadgeVerified => 'تم التحقق';
  @override String get statusBadgeReceived => 'مستلم';
  @override String get statusBadgeInTransit => 'في الطريق';
  @override String get statusBadgeDiscrepant => 'غير مطابق مع وجود ملاحظات';
  @override String get statusBadgePending => 'قيد الانتظار';
  @override String get saveDraftSessionBtn => 'حفظ مؤقت';
  @override String get completeCollectionBtn => 'اعتماد واكتمال التحصيل';
  @override String get unverifiedMandatoryDocsWarning => 'توجد مستندات إلزامية لم يتم تدقيقها بعد. يرجى ذكر مبرر الاعتماد قبل التأكيد النهائي.';
  @override String sessionSavedSuccess(dynamic code) => 'تم حفظ وتحديث جلسة تحصيل أصول المستندات بنجاح [$code]';
  @override String sessionSaveError(dynamic err) => 'خطأ في حفظ الجلسة: $err';
  @override String excelExportSuccess(dynamic bytes) => 'تم توليد وتصدير ملف الإكسيل بنجاح ($bytes بايت)';
  @override String excelExportError(dynamic err) => 'خطأ في تصدير ملف الإكسيل: $err';
  @override String get collectionRegistryHeader => 'سجل جلسات تحصيل أصول المستندات:';
  @override String get searchRegistryHint => 'بحث برقم الكود أو الشحنة...';
  @override String get filterStatusAll => 'جميع الحالات';
  @override String get filterStatusDraft => 'مسودة';
  @override String get filterStatusPartiallyReceived => 'مستلم جزئياً';
  @override String get filterStatusFullyReceived => 'مستلم بالكامل';
  @override String get filterStatusFullyVerified => 'معتمد ومدقق بالكامل';
  @override String get noRegisteredSessionsFound => 'لا توجد جلسات تحصيل مسجلة بعد.';
  @override String errorFetchingRegistry(dynamic err) => 'خطأ في جلب السجل: $err';
  @override String get colSessionCode => 'كود الجلسة';
  @override String get colImportFile => 'ملف الشحنة';
  @override String get colAcidNumber => 'رقم القيد المسبق';
  @override String get colSupplierName => 'المورد الأجنبي';
  @override String get colTotalDocs => 'إجمالي المستندات';
  @override String get colReceivedDocs => 'تم الاستلام';
  @override String get colVerifiedDocs => 'تم التدقيق';
  @override String get colCompletionPercentage => 'نسبة الإنجاز';
  @override String get colUpdatedAt => 'تاريخ التحديث';
  @override String get docCatCommercial => 'تجاري';
  @override String get docCatCertificate => 'شهادات';
  @override String get docCatShipping => 'شحن';
  @override String get docCatEgyptImport => 'استيراد مصر';
  @override String get docCatBanking => 'بنكي';
  @override String get docCatRegulatory => 'رقابي';
  @override String get docCatOther => 'أخرى';
  @override String get courierCompanyHandDelivery => 'تسليم باليد';
  @override String get courierCompanyOther => 'أخرى';
  @override String get partySupplier => 'المورد الأجنبي';
  @override String get partyFreightForwarder => 'وكيل الشحن';
  @override String get partyCustomsBroker => 'المخلص الجمركي';
  @override String get partyBank => 'البنك';
  @override String get partyImporter => 'الشركة المستوردة';
  @override String get partyCarrier => 'الخط الملاحي';
  @override String get sessionNotesLabel => 'ملاحظات عامة على جلسة التحصيل';
  @override String get overrideReasonLabel => 'مبرر اعتماد التحصيل في حالة وجود مستندات غير مكتملة';
  @override String get courierCompanyDhl => 'دي إتش إل';
  @override String get courierCompanyFedex => 'فيديكس';
  @override String get courierCompanyAramex => 'أرامكس';
  @override String get courierCompanyUps => 'يو بي إس';
  @override String get courierCompanyNaqel => 'ناقل إكسبريس';
  @override String get courierCompanySmsa => 'سمسا إكسبريس';
  @override String get originalDocsExportTsvBtn => 'تصدير جدول مجدول';
  @override String get originalDocsExportExcelBtn => 'تصدير إكسيل';
  @override String get originalDocsPrintPdfBtn => 'طباعة تقرير مصدق';
  @override String get originalDocsCopyDossierBtn => 'نسخ ملف البيانات';
  @override String get originalDocsCopiedDossierSuccess => 'تم نسخ ملف وثائق الشحنة إلى الحافظة بنجاح';
  @override String get originalDocsCopiedTsvSuccess => 'تم تصدير ونسخ جدول البيانات بنجاح';
  @override String get originalDocsCopiedExcelSuccess => 'تم تصدير ملف الإكسيل بنجاح';
  @override String get originalDocsExportTsvDialogTitle => 'تصدير جدول وثائق الشحنة';
  @override String get originalDocsExportExcelDialogTitle => 'تصدير وثائق الشحنة بصيغة إكسيل';
  @override String get originalDocsExportPdfDialogTitle => 'طباعة بيان وثائق الشحنة';
  @override String get originalDocsDossierTitle => 'ملف حصر وتدقيق أصول مستندات الشحنة';
  @override String get originalDocsCopyRowSuccess => 'تم نسخ بيانات السطر إلى الحافظة بنجاح';
  @override String get originalDocsTsvHeaderCourierNo => 'رقم الكورير';
  @override String get originalDocsTsvHeaderDocCategory => 'تصنيف الوثيقة';
  @override String get originalDocsTsvHeaderDocName => 'اسم المستند';
  @override String get originalDocsTsvHeaderRequirement => 'الإلزامية';
  @override String get originalDocsTsvHeaderResponsibleParty => 'الجهة المسؤولة';
  @override String get originalDocsTsvHeaderPhysicalReceived => 'الاستلام الورقي';
  @override String get originalDocsTsvHeaderReceivedDate => 'تاريخ الاستلام';
  @override String get originalDocsTsvHeaderVerified => 'الفحص والتدقيق';
  @override String get originalDocsTsvHeaderAuditor => 'المدقق';
  @override String get originalDocsTsvHeaderStatus => 'الحالة';
  @override String get originalDocsTsvHeaderRemarks => 'الملاحظات';
  @override String get originalDocsRegistryDossierTitle => 'سجل جلسات تحصيل أصول المستندات';
  @override String get originalDocsRegistryTsvHeaderCode => 'كود الجلسة';
  @override String get originalDocsRegistryTsvHeaderFile => 'ملف الشحنة';
  @override String get originalDocsRegistryTsvHeaderAcid => 'رقم القيد المسبق';
  @override String get originalDocsRegistryTsvHeaderSupplier => 'المورد الأجنبي';
  @override String get originalDocsRegistryTsvHeaderTotalDocs => 'إجمالي المستندات';
  @override String get originalDocsRegistryTsvHeaderReceivedDocs => 'المستلم';
  @override String get originalDocsRegistryTsvHeaderVerifiedDocs => 'المدقق';
  @override String get originalDocsRegistryTsvHeaderCompletion => 'نسبة الإنجاز';
  @override String get originalDocsRegistryTsvHeaderStatus => 'الحالة';
  @override String get originalDocsRegistryTsvHeaderUpdatedAt => 'تاريخ التحديث';
  @override String get originalDocsRegistryCopiedSuccess => 'تم نسخ سجل الجلسات إلى الحافظة بنجاح';
  @override String get originalDocsLoadSessionTooltip => 'فتح وتحميل الجلسة';
  @override String get courierAlertsHeader => 'تنبيهات ومتابعة الكورير ومواعيد الاستلام';
  @override String courierAlertCriticalCount(dynamic count) => '$count طرود متأخرة تجاوزت المهلة المحددة';
  @override String courierAlertWarningCount(dynamic count) => '$count طرود تقترب من مهلة التسليم';
  @override String get courierTrackingRegistryTab => 'سجل تتبع الكورير وإثبات ميعاد الاستلام';
  @override String get sessionsRegistryTab => 'سجل جلسات تحصيل المستندات';
  @override String get confirmCourierDeliveryBtn => 'إثبات وتأكيد ميعاد الاستلام';
  @override String get courierDeliveryProofDialogTitle => 'إثبات ميعاد استلام طرد الكورير (POD)';
  @override String get courierReceiptDateLabel => 'تاريخ الاستلام الفعلي';
  @override String get courierReceiptTimeLabel => 'وقت الاستلام (HH:mm)';
  @override String get courierReceivedByLabel => 'اسم المستلم';
  @override String get courierPodRefLabel => 'رقم إشعار التسليم / البوليصة (POD Ref)';
  @override String get markAssociatedDocsReceivedLabel => 'تحديث حالة مستندات الطرد إلى "تم الاستلام" تلقائياً';
  @override String get courierReceiptRecordedSuccess => 'تم إثبات وتسجيل ميعاد استلام الكورير بنجاح';
  @override String daysInTransitLabel(dynamic days) => '$days يوم في الطريق';
  @override String get filterStatusInTransit => 'في الطريق';
  @override String get filterStatusDelivered => 'تم الاستلام';

  // ── Screen 59: Production Sync Screen & Hub ───────────────────────────────
  @override String get prodSyncScreenTitle => 'مركز مزامنة وتحديث الإنتاج';
  @override String get prodSyncScreenSubtitle => 'أداة المزامنة الفورية لقواعد البيانات والتعديلات من داخل النظام مباشرة';
  @override String get prodSyncHubDialogTitle => 'مركز حماية ومزامنة الإنتاج';
  @override String get prodSyncHubDialogSubtitle => 'ترقية هيكل البيانات وإدارة النسخ الاحتياطية والاستعادة دون المساس ببيانات التشغيل';
  @override String get prodSyncTabCompareTables => 'مقارنة ومزامنة الجداول';
  @override String get prodSyncTabSchemaUpgrade => 'ترقية هيكل البيانات';
  @override String get prodSyncTabSafetyBackups => 'سجل النسخ الاحتياطية والاستعادة';
  @override String get prodSyncDevDbTitle => 'قاعدة بيانات التطوير';
  @override String get prodSyncDevDbSubtitle => 'الملف النشط في بيئة العمل الحالية';
  @override String get prodSyncDevDbUpgradeSub => 'مصدر الميزات الجديدة والترقيات';
  @override String get prodSyncProdDbTitle => 'قاعدة بيانات الإنتاج';
  @override String get prodSyncProdDbSubtitle => 'الملف المدمج في حزمة البرنامج المستقلة';
  @override String get prodSyncProdDbUpgradeSub => 'الهدف التشغيلي — بياناتها محمية بالكامل';
  @override String prodSyncDbSize(dynamic size) => 'الحجم: $size';
  @override String prodSyncDbTablesCount(dynamic count) => 'الجداول: $count';
  @override String prodSyncDbRecordsCount(dynamic count) => 'السجلات: $count';
  @override String prodSyncFullySynchronizedTitle(dynamic matched) => 'قواعد البيانات متطابقة تماماً بنسبة مئة بالمئة ($matched جدول متطابق)';
  @override String get prodSyncFullySynchronizedSub => 'الإنتاج يعمل بأحدث نسخة متوافقة بالكامل مع بيئة التطوير.';
  @override String prodSyncDifferencesDetectedTitle(dynamic differing) => 'تم رصد اختلافات في البيانات ($differing جدول به تعديلات غير مدمجة)';
  @override String get prodSyncDifferencesDetectedSub => 'يمكنك بضغطة زر واحدة مزامنة وتحديث قاعدة بيانات الإنتاج فوراً دون الحاجة لإعادة التثبيت.';
  @override String prodSyncUpgradeReadyTitle(dynamic count) => 'توجد ميزات جديدة جاهزة للترقية ($count جدول)';
  @override String get prodSyncUpgradeReadySub => 'اضغط "ترقية الإنتاج" لإضافة الميزات الجديدة فقط — بياناتك التشغيلية محمية تماماً.';
  @override String get prodSyncSafetyGuaranteeTitle => 'ضمان الحماية الكاملة لبيانات التشغيل';
  @override String get prodSyncSafetyGuaranteeBody => 'الترقية تضيف فقط الجداول والأعمدة الجديدة • لا تحذف أي سجل • لا تعدل بيانات الموردين أو الشركات أو أوامر الشراء أو ملفات الشحن • نسخة احتياطية تلقائية قبل البدء';
  @override String get prodSyncSyncNowBtn => 'مزامنة وتحديث الإنتاج الآن';
  @override String get prodSyncUpgradeBtn => 'ترقية الإنتاج';
  @override String get prodSyncPullFromProdBtn => 'سحب من الإنتاج';
  @override String get prodSyncCreateSnapshotBtn => 'أخذ نسخة احتياطية فورية';
  @override String get prodSyncCreateDevSnapshotBtn => 'نسخة احتياطية الآن (بيئة التطوير)';
  @override String prodSyncTablesMatchHeader(dynamic filtered, dynamic total) => 'فحص وتطابق جداول النظام ($filtered / $total جدول)';
  @override String prodSyncTablesUpgradeHeader(dynamic filtered, dynamic total) => 'تفاصيل الجداول ($filtered / $total) — الجداول ذات الفروق ستتلقى الأعمدة الجديدة فقط';
  @override String get prodSyncSearchTablesHint => 'بحث في الجداول...';
  @override String prodSyncDevRecordsCount(dynamic count) => 'التطوير: $count سجل';
  @override String prodSyncProdRecordsCount(dynamic count) => 'الإنتاج: $count سجل';
  @override String get prodSyncTableStatusUpdated => 'محدث';
  @override String get prodSyncBackupsSectionHeader => 'النسخ الاحتياطية المؤرشفة لقاعدة البيانات';
  @override String get prodSyncBackupsSectionSub => 'يتم حفظ نسخة احتياطية مشفرة في مجلد النسخ الاحتياطية قبل كل عملية مزامنة لضمان أمان البيانات بالكامل';
  @override String get prodSyncBackupsDialogSub => 'يمكنك استعادة أي نسخة — يتم حفظ نسخة أمان من الوضع الحالي قبل الاستعادة';
  @override String get prodSyncNoBackupsFound => 'لا توجد نسخ احتياطية محفوظة بعد';
  @override String get prodSyncNoBackupsDialogSub => 'يتم أخذ نسخة احتياطية تلقائياً قبل كل ترقية وعند إغلاق النظام';
  @override String get prodSyncRestoreToProdBtn => 'استعادة إلى الإنتاج';
  @override String get prodSyncRestoreToDevBtn => 'استعادة إلى التطوير';
  @override String prodSyncBackupCreatedAt(dynamic date) => 'تاريخ الإنشاء: $date';
  @override String prodSyncBackupSize(dynamic size) => 'الحجم: $size';
  @override String prodSyncBackupTag(dynamic tag) => 'النوع: $tag';
  @override String get prodSyncConfirmUpgradeTitle => 'تأكيد ترقية الإنتاج';
  @override String get prodSyncConfirmUpgradeWhatHappens => 'ما سيحدث:\n• نسخة احتياطية أمان تلقائية قبل البدء\n• إضافة الجداول الجديدة (إن وجدت)\n• إضافة الأعمدة الجديدة لكل جدول موجود\n• دمج بيانات المرجعية الجديدة';
  @override String get prodSyncConfirmUpgradeWhatWontHappen => 'ما لن يحدث أبداً:\n• لن يُمسّ أي مورد أو شركة أو أمر شراء أو ملف شحن\n• لن يُحذف أي سجل موجود في الإنتاج\n• لن يُعدَّل أي بيان تشغيلي مُدخل يدوياً';
  @override String get prodSyncConfirmUpgradeSubmitBtn => 'تأكيد الترقية';
  @override String get prodSyncConfirmRestoreTitle => 'تأكيد الاستعادة';
  @override String prodSyncConfirmRestoreMsg(dynamic target) => 'سيتم استعادة النسخة التالية إلى قاعدة بيانات $target:';
  @override String get prodSyncConfirmRestoreWarning => 'سيتم حفظ نسخة أمان من الوضع الحالي قبل الاستعادة، ثم استبدال قاعدة البيانات بالنسخة المختارة.';
  @override String get prodSyncConfirmRestoreSubmitBtn => 'تأكيد الاستعادة';
  @override String get prodSyncTargetProdLabel => 'الإنتاج';
  @override String get prodSyncTargetDevLabel => 'التطوير';
  @override String prodSyncBackupCreatedSuccess(dynamic filename) => 'تم إنشاء النسخة الاحتياطية: $filename';
  @override String prodSyncSyncError(dynamic err) => 'فشلت المزامنة: $err';
  @override String prodSyncPullError(dynamic err) => 'فشل السحب: $err';
  @override String prodSyncRestoreError(dynamic err) => 'فشلت الاستعادة: $err';
  @override String get prodSyncComparingDatabasesProgress => 'جاري فحص ومقارنة قواعد البيانات...';
  @override String prodSyncErrorFetchingComparison(dynamic err) => 'تعذر جلب بيانات المقارنة: $err';
  @override String get prodSyncExportTsvBtn => 'تصدير جدول نصوص';
  @override String get prodSyncExportExcelBtn => 'تصدير إكسيل';
  @override String get prodSyncExportPdfBtn => 'تقرير تشخيصي (بي دي إف)';
  @override String get prodSyncCopyDossierBtn => 'نسخ التقرير الشامل';
  @override String get prodSyncCopyDossierSuccess => 'تم نسخ تقرير المزامنة الشامل إلى الحافظة بنجاح';
  @override String get prodSyncExportTsvSuccess => 'تم نسخ جدول البيانات إلى الحافظة بنجاح';
  @override String get prodSyncExportExcelSuccess => 'تم تصدير ملف إكسيل بنجاح';
  @override String get prodSyncCopyRowSummaryBtn => 'نسخ ملخص الصف';
  @override String get prodSyncCopyRowSummarySuccess => 'تم نسخ ملخص الجدول إلى الحافظة';
  @override String get prodSyncCopyFieldTooltip => 'نسخ القيمة';
  @override String get prodSyncVersionBadgeLabel => 'رقم الإصدار';
  @override String get prodSyncDevDbPathBadge => 'مسار قاعدة بيانات التطوير';
  @override String get prodSyncProdDbPathBadge => 'مسار قاعدة بيانات الإنتاج';
  @override String get prodSyncBackupTagBadge => 'نوع النسخة الاحتياطية';
  @override String get prodSyncBackupFilenameBadge => 'اسم ملف النسخة';
  @override String get prodSyncTsvHeaderTableName => 'اسم الجدول';
  @override String get prodSyncTsvHeaderDevCount => 'سجلات بيئة التطوير';
  @override String get prodSyncTsvHeaderProdCount => 'سجلات بيئة الإنتاج';
  @override String get prodSyncTsvHeaderDiff => 'الفارق العددي';
  @override String get prodSyncTsvHeaderStatus => 'حالة المطابقة';
  @override String get prodSyncTsvHeaderBackupFile => 'اسم ملف النسخة';
  @override String get prodSyncTsvHeaderBackupTag => 'نوع النسخة';
  @override String get prodSyncTsvHeaderBackupSize => 'الحجم';
  @override String get prodSyncTsvHeaderBackupDate => 'تاريخ الإنشاء';
  @override String get prodSyncScreenHeaderTitle => 'مركز إدارة التحديثات والنسخ الاحتياطي';
  @override String get prodSyncScreenHeaderSubtitle => 'الترقية التلقائية الآمنة لقاعدة البيانات وإدارة نقاط الاسترجاع وفحص الإصدارات السحابية';
  @override String get prodSyncRefreshSystemStatusTooltip => 'تحديث حالة النظام';
  @override String get prodSyncTabUpdatesAndBackups => 'إدارة التحديثات ونقاط الاسترجاع';
  @override String get prodSyncTabDevToolsAndDiff => 'أدوات المطور والمقارنة المباشرة';
  @override String get prodSyncSystemUpToDateMsg => 'النظام محدث ومستقر بأحدث إصدار مثبت.';
  @override String get prodSyncCheckingCloudUpdates => 'جاري فحص الإصدارات الجديدة عبر السحابة...';
  @override String get prodSyncOfflineModeMsg => 'يعمل النظام في الوضع المحلي المستقل دون اتصال.';
  @override String get prodSyncCheckUpdatesBtn => 'فحص التحديثات';
  @override String prodSyncWhatsNewInVersion(dynamic version) => 'المميزات الجديدة في إصدار $version:';
  @override String get prodSyncSchemaEngineTitle => 'محرك الترقية التراكمي الآمن لهيكل البيانات';
  @override String get prodSyncSchemaEngineDesc => 'يقوم النظام تلقائياً بأخذ لقطة أمان قبل كل ترقية، مع إضافة الجداول والأعمدة الجديدة دون المساس ببيانات التشغيل.';
  @override String get prodSyncCreateInstantBackupBtn => 'إنشاء نقطة استرجاع فورية';
  @override String prodSyncBackupsArchiveHeader(dynamic count) => 'أرشيف النسخ الاحتياطية ونقاط الاسترجاع ($count نسخة محفوظة)';
  @override String get prodSyncRefreshListTooltip => 'تحديث القائمة';
  @override String get prodSyncNoBackupsInFolder => 'لا توجد نسخ احتياطية سابقة في المجلد المخصص.';
  @override String get prodSyncAutoPreUpgradeTag => 'ترقية تلقائية آمنة';
  @override String get prodSyncManualBackupTag => 'نسخة يدوية';
  @override String get prodSyncRestoreActionBtn => 'استعادة';
  @override String get prodSyncCompareTablesBtn => 'فحص ومقارنة الجداول';
  @override String get prodSyncDbNotFoundNotice => 'لم يتم العثور على الملف بعد (سيتم إنشاؤه عند أول مزامنة)';
  @override String prodSyncDbLastModified(dynamic date) => 'آخر تعديل: $date';
  @override String prodSyncDbSizeLabel(dynamic size) => 'الحجم: $size كيلوبايت';
  @override String get prodSyncConfirmRestoreTitleDialog => 'تأكيد استعادة النسخة الاحتياطية';
  @override String prodSyncConfirmRestoreMsgDialog(dynamic name) => 'هل أنت متأكد من استعادة هذه النسخة: $name؟';
  @override String get prodSyncConfirmRestoreSafeNotice => 'سيقوم النظام تلقائياً بإنشاء نسخة أمان فورية من الوضع الحالي قبل تطبيق الاسترجاع لضمان عدم فقدان أي بيانات نهائياً.';
  @override String get prodSyncCancelAction => 'إلغاء';
  @override String get prodSyncRestoreNowAction => 'استعادة الآن';
  @override String prodSyncActionStarting(dynamic name) => 'جارٍ بدء عملية: $name...';
  @override String prodSyncActionSuccess(dynamic name) => 'اكتملت عملية [$name] بنجاح!';
  @override String prodSyncActionFailed(dynamic name) => 'انتهت عملية [$name] مع أخطاء. راجع السجل.';
  @override String prodSyncActionUnexpectedErr(dynamic err) => 'استثناء غير متوقع: $err';
  @override String prodSyncDiffStatusNewRecords(dynamic count) => '+$count سجل جديد سيضاف';
  @override String get prodSyncDiffStatusNewTable => 'جدول جديد بالكامل';
  @override String prodSyncDiffStatusProdSurplus(dynamic count) => '$count في بيئة الإنتاج';
  @override String get prodSyncDiffStatusMatched => 'متطابق تماماً';
  @override String get prodSyncDiffFilterModified => 'توجد تعديلات فقط';
  @override String prodSyncDiffFilterAll(dynamic count) => 'جميع الجداول ($count)';
  @override String get prodSyncDiffFilterMatched => 'متطابقة';
  @override String get prodSyncDiffPanelTitle => 'التغيرات الجاهزة للتحديث في قاعدة بيانات الإنتاج';
  @override String get prodSyncDiffPanelSubtitle => 'كشف تفصيلي بالفروقات والجداول التي تحتوي على سجلات جديدة أو معدلة';
  @override String get prodSyncDiffCheckBtn => 'فحص التغيرات الآن';
  @override String get prodSyncDiffEmptyInstruction => 'اضغط على "فحص التغيرات الآن" أو "مقارنة الجداول" لعرض ما سيتم إضافته بالتحديد إلى الإنتاج';
  @override String get prodSyncDiffAllMatchedSuccess => 'لا توجد فروقات أو تعديلات معلقة — كافة الجداول متطابقة تماماً مع الإنتاج!';
  @override String get prodSyncDiffNoSearchResults => 'لا توجد جداول مطابقة لخيارات البحث الحالية.';
  @override String get prodSyncTerminalTitle => 'سجل التنفيذ المباشر للأوامر';
  @override String get prodSyncTerminalReadyMsg => 'جاهز للتشغيل. اختر العملية المطلوبة من الأعلى للبدء.';
  @override String get prodSyncTerminalRunningMsg => 'جاري التنفيذ...';
  @override String get prodSyncTerminalCopyTooltip => 'نسخ السجل';
  @override String get prodSyncTerminalClearTooltip => 'مسح الشاشة';
  @override String get prodSyncTerminalCopiedToast => 'تم نسخ سجل المخرجات بالكامل إلى الحافظة';
  @override String prodSyncProgressTablesCount(dynamic current, dynamic total, dynamic synced) => 'الجداول: $current من $total | إجمالي السجلات المنقولة والمحدثة: $synced';

  // ── Screen 63: Goods In Transit (GIT) Ledger ─────────────────────────────
  @override String get gitLedgerTabTitle => 'رصيد البضاعة بالطريق وتتبع الشحنات';
  @override String get gitLedgerScaffoldTitle => 'رصيد ومطابقة البضاعة في الطريق';
  @override String gitErrorFetchingData(dynamic err) => 'خطأ في جلب بيانات البضاعة بالطريق: $err';
  @override String get gitInfoBannerTitle => 'تقرير رصيد البضاعة في الطريق تفصيلي لكل أمر شراء';
  @override String get gitInfoBannerSubtitle => 'هذا التقرير يمثل رصيد البضائع المشحونة طبقاً للفواتير وقوائم التعبئة المعتمدة، ويتم تحديثه وخصم الكميات تلقائياً فور تأكيد الاستلام النهائي بالمخزن.';
  @override String get gitExportExcelBtn => 'تصدير إكسيل';
  @override String get gitExportSuccessMsg => 'تم تصدير تقرير البضاعة في الطريق بنجاح';
  @override String get gitKpiInTransitShipments => 'الشحنات في الطريق';
  @override String gitKpiShipmentsValue(dynamic count) => '$count شحنة';
  @override String get gitKpiPurchaseOrders => 'أوامر الشراء';
  @override String gitKpiPurchaseOrdersValue(dynamic count) => '$count أمر شراء';
  @override String get gitKpiInvoicedQuantity => 'إجمالي العدد بالفاتورة';
  @override String gitKpiQuantityValue(dynamic qty) => '$qty قطعة';
  @override String get gitKpiPackagesCount => 'إجمالي الكراتين والطرود';
  @override String gitKpiPackagesValue(dynamic count) => '$count طرد';
  @override String get gitKpiActiveContainers => 'عدد الحاويات النشطة';
  @override String gitKpiContainersValue(dynamic count) => '$count حاوية';
  @override String get gitSearchHint => 'بحث برقم الشحنة، أمر الشراء، كود أو اسم الصنف...';
  @override String get gitFilterAll => 'جميع البضائع';
  @override String get gitFilterInTransitOnly => 'البضاعة في الطريق فقط (الرصيد الفعلي)';
  @override String get gitFilterDeliveredOnly => 'الشحنات المستلمة بالمخزن فقط';
  @override String get gitRefreshTooltip => 'تحديث الرصيد';
  @override String get gitTableSectionHeader => 'جدول رصيد البضاعة في الطريق تفصيلي لكل أمر شراء';
  @override String get gitNoDataFound => 'لا توجد بضائع في الطريق مطابقة لمعايير البحث حالياً.';
  @override String get gitColFileCode => 'رقم ملف الشحنة';
  @override String get gitColPoNumber => 'رقم أمر الشراء';
  @override String get gitColItemCode => 'كود الصنف';
  @override String get gitColItemName => 'اسم وبيان الصنف';
  @override String get gitColInvoicedQty => 'العدد بالفاتورة';
  @override String get gitColPackagesCount => 'عدد الكراتين والطرود';
  @override String get gitColContainers => 'عدد الحاويات ونوعها';
  @override String get gitColCertifiedDate => 'تاريخ الاعتماد';
  @override String get gitColLedgerStatus => 'حالة الرصيد';
  @override String get gitStatusDeliveredToWarehouse => 'تم الاستلام بالمخزن';
  @override String get gitStatusInTransit => 'في الطريق';
  @override String get gitExportTsvBtn => 'تصدير مجدول';
  @override String get gitPrintPdfBtn => 'طباعة تقرير';
  @override String get gitCopyDossierBtn => 'نسخ ملف البيانات';
  @override String get gitCopiedTsvSuccess => 'تم نسخ وتصدير سجل البضاعة في الطريق بصيغة مجدولة بنجاح';
  @override String get gitCopiedExcelSuccess => 'تم تصدير سجل البضاعة في الطريق بصيغة إكسيل بنجاح';
  @override String get gitCopiedDossierSuccess => 'تم نسخ ملف بيانات البضاعة في الطريق بالكامل إلى الحافظة';
  @override String get gitCopyRowSummaryBtn => 'نسخ ملخص البند';
  @override String get gitCopyRowSummarySuccess => 'تم نسخ ملخص بند البضاعة في الطريق إلى الحافظة بنجاح';
  @override String get gitCopyFieldTooltip => 'نسخ القيمة';
  @override String get gitPdfTitle => 'تقرير رصيد ومطابقة البضاعة في الطريق';
  @override String get gitPdfSubtitle => 'حصر تفصيلي للبضائع المشحونة والمطابقة الجمركية والمخزنية';
  @override String get gitDossierHeader => 'ملف رصيد البضاعة في الطريق ومطابقة الشحنات';
  @override String get gitDossierKpiSummary => 'ملخص مؤشرات الرصيد والحركة';
  @override String get gitDossierRecordsDetails => 'تفاصيل بنود البضاعة في الطريق';
  @override String get gitDossierFooter => 'نهاية ملف رصيد البضاعة في الطريق — معتمد من نظام سرور لإدارة سلاسل الإمداد';
  @override String get gitPackageTypeCol => 'نوع التعبئة';
  @override String get gitContainerTypeCol => 'نوع الحاوية';
  @override String get gitColActions => 'الإجراءات';

  // ── Screen 64: Warehouse Received Shipments Detailed Report ───────────────
  @override String get whReportTabTitle => 'تقرير الشحنات المستلمة بالمخزن تفصيلي';
  @override String get whReportScaffoldTitle => 'تقرير الشحنات المستلمة بالمخزن ومطابقة الفروق';
  @override String whReportErrorFetchingData(dynamic err) => 'خطأ في جلب تقرير الشحنات المستلمة: $err';
  @override String get whReportInfoBannerTitle => 'تقرير الشحنات المستلمة بالمخازن ومطابقة الفروق';
  @override String get whReportInfoBannerSubtitle => 'حصر شامل لكل الشحنات التي تم تأكيد استلامها بالمخازن مفصلة بأوامر الشراء ومطابقة الكميات المقر عنها بالفاتورة مع المستلم الفعلي والفاقد والتالف والعينات المسحوبة.';
  @override String get whReportExportExcelBtn => 'تصدير إكسيل';
  @override String get whReportExportSuccessMsg => 'تم تصدير تقرير الشحنات المستلمة بنجاح';
  @override String get whReportKpiInvoicedQty => 'إجمالي العدد بالفاتورة';
  @override String get whReportKpiReceivedQty => 'المستلم الفعلي بالمخزن';
  @override String get whReportKpiDamagedQty => 'إجمالي التالف';
  @override String get whReportKpiShortageQty => 'إجمالي العجز';
  @override String get whReportKpiSamplesQty => 'العينات المسحوبة';
  @override String get whReportKpiVarianceQty => 'صافي الفروق';
  @override String whReportUnitsValue(dynamic count) => '$count وحدة';
  @override String get whReportSearchHint => 'بحث برقم الشحنة، أمر الشراء، كود أو اسم الصنف...';
  @override String get whReportTableSectionHeader => 'جدول الشحنات المستلمة تفصيلي لكل أمر شراء';
  @override String get whReportNoDataFound => 'لا توجد شحنات مستلمة مطابقة لمعايير البحث حالياً.';
  @override String get whReportColImportFile => 'ملف الشحنة';
  @override String get whReportColPoNumber => 'أمر الشراء';
  @override String get whReportColContainerAndTruck => 'الحاويات والسيارة';
  @override String get whReportColItemAndDescription => 'الصنف وبيانه';
  @override String get whReportColInvoicedQty => 'العدد بالفاتورة';
  @override String get whReportColShortageQty => 'الفاقد والعجز';
  @override String get whReportColDamagedQty => 'التالف';
  @override String get whReportColSamplesQty => 'عينات مسحوبة';
  @override String get whReportColReceivedQty => 'المستلم بالمخزن';
  @override String get whReportColVarianceQty => 'الفارق';
  @override String get whReportColReceiptStatus => 'حالة الاستلام';
  @override String get whReportStatusApprovedAndReceived => 'معتمد ومستلم';
  @override String get whReportExportTsvBtn => 'تصدير جدول مفصول بمسافات';
  @override String get whReportPrintPdfBtn => 'طباعة تقرير بي دي إف';
  @override String get whReportCopyDossierBtn => 'نسخ الملف الشامل';
  @override String get whReportCopiedTsvSuccess => 'تم نسخ بيانات تقرير الشحنات المستلمة كجدول إلى الحافظة بنجاح';
  @override String get whReportCopiedExcelSuccess => 'تم نسخ بيانات تقرير الشحنات المستلمة بتنسيق إكسيل إلى الحافظة بنجاح';
  @override String get whReportCopiedDossierSuccess => 'تم نسخ الملف الشامل للشحنات المستلمة إلى الحافظة بنجاح';
  @override String get whReportCopyRowSummaryBtn => 'نسخ ملخص بيانات السطر';
  @override String get whReportCopyRowSummarySuccess => 'تم نسخ ملخص السطر إلى الحافظة بنجاح';
  @override String get whReportCopyFieldTooltip => 'نسخ القيمة للحافظة';
  @override String get whReportSearchCopied => 'تم نسخ نص البحث إلى الحافظة';
  @override String get whReportColActions => 'إجراءات';
  @override String get whReportColWarehouse => 'المستودع';
  @override String get whReportColArrivalDate => 'تاريخ الوصول';
  @override String whReportCopyBadgeSuccess(String label, String value) => 'تم نسخ $label ($value) إلى الحافظة';
  @override String get whReportPdfTitle => 'تقرير الشحنات المستلمة بالمخزن ومطابقة الفروق تفصيلي';
  @override String get whReportPdfSubtitle => 'حصر شامل للشحنات وأوامر الشراء ومطابقة الكميات الفعلية مع الفواتير والعجز والتالف';
  @override String get whReportDossierHeader => 'تقرير الشحنات المستلمة بالمخزن تفصيلي ومطابقة الفروق';
  @override String get whReportDossierKpiSummary => 'ملخص المؤشرات التشغيلية للمستودع';
  @override String get whReportDossierRecordsDetails => 'بيانات السجلات والشحنات المستلمة تفصيلياً';
  @override String get whReportDossierFooter => 'نهاية التقرير - نظام سرور اللوجستي لإدارة الاستيراد والمخازن';

  // ── Screen 8: Financial Approvals & Budgets ─────────────────────────────
  @override String get financialApprovalsTitle => 'الموافقات المالية وإدارة الميزانية';
  @override String get paymentRequestsTab => 'طلبات السداد المالي للمورد';
  @override String get importBudgetApprovalTab => 'اعتماد الميزانية الاستيرادية';
  @override String get savedBudgetsRegistryTab => 'سجل الميزانيات المعتمدة';
  @override String get paymentRequestsRegistryTab => 'سجل طلبات السداد والتحويلات';
  @override String get swiftReconciliationTab => 'استخراج ومطابقة السويفت (MT103)';
  @override String get createPaymentRequestTitle => 'إصدار طلب سداد وتحويل مالي للمورد';
  @override String get editPaymentRequestTitle => 'تعديل بيانات طلب السداد الحالي';
  @override String get activeEditModeBanner => 'وضع التعديل النشط';
  @override String get cancelEdit => 'إلغاء التعديل';
  @override String get paymentTitleLabel => 'عنوان طلب السداد';
  @override String get paymentTypeLabel => 'طريقة / نوع السداد';
  @override String get requestedAmountLabel => 'المبلغ المطلوب بالعملة';
  @override String get beneficiarySupplierLabel => 'المورد المستفيد';
  @override String get selectSupplierFromMasterData => 'اختر المورد من البيانات المرجعية';
  @override String get beneficiaryBankDetails => 'بيانات التحويل البنكي للمورد المستفيد';
  @override String get bankNameLabel => 'اسم بنك المورد';
  @override String get swiftCodeLabel => 'كود السويفت';
  @override String get ibanAccountLabel => 'رقم الحساب / الآيبان';
  @override String get requestDateLabel => 'تاريخ تقديم الطلب';
  @override String get dueDateLabel => 'تاريخ الاستحقاق المطلوب';
  @override String get paymentNotesLabel => 'ملاحظات طلب السداد';
  @override String get issuePaymentRequestButton => 'إصدار طلب السداد للإدارة المالية';
  @override String get savePaymentChangesButton => 'حفظ تعديلات طلب السداد';
  @override String get importBudgetSetupTitle => 'اعتماد ميزانية ملف الاستيراد الشاملة';
  @override String get budgetTitleLabel => 'عنوان الميزانية الاستيرادية';
  @override String get estimatedInvoiceValue => 'قيمة الفاتورة المبدئية';
  @override String get estimatedFreightCost => 'تكلفة النولون المقدرة';
  @override String get customsAndVatEstimate => 'الضرائب والجمارك والـ VAT';
  @override String get clearanceAndTransportEstimate => 'أتعاب التخليص والنقل';
  @override String get budgetApprovalNotes => 'ملاحظات وتوجيهات اعتماد الميزانية';
  @override String get approveAndCertifyBudget => 'التصديق واعتماد الميزانية';
  @override String get saveBudgetChanges => 'حفظ تعديلات الميزانية';
  @override String get totalBudgetEgp => 'إجمالي الميزانية الاستيرادية الكلية المعتمدة';
  @override String get consolidatedBudgetSummary => 'تقرير توزيع بنود الميزانية حسب العملات';
  @override String get totalBudgetsMetric => 'إجمالي الميزانيات';
  @override String get approvedBudgetsMetric => 'ميزانيات معتمدة';
  @override String get pendingBudgetsMetric => 'قيد المراجعة / مسودة';
  @override String get totalValueEgpMetric => 'إجمالي القيمة التقديرية';
  @override String get searchBudgetsHint => 'البحث بكود الميزانية أو العنوان أو كود الشحنة...';
  @override String get searchPaymentsHint => 'البحث بكود الطلب أو اسم المورد أو رقم الملف أو العنوان...';
  @override String get paymentRequestsLogTitle => 'سجل العمليات والتحويلات المالية للموردين';
  @override String get noMatchingPayments => 'لا توجد طلبات سداد مالي مطابقة لخيارات البحث والتصفية.';
  @override String get noMatchingBudgets => 'لا توجد اعتمادات ميزانية مطابقة لمعايير البحث.';
  @override String get swiftExtractorTitle => 'استخراج ومطابقة إشعار التحويل البنكي (SWIFT MT103)';
  @override String get swiftUploadDocument => 'رفع مستند السويفت';
  @override String get swiftPasteText => 'لصق نص رسالة السويفت';
  @override String get swiftMatchedSuccess => 'تمت المطابقة مع طلب السداد بنجاح';
  @override String get swiftExecuteReconciliation => 'تنفيذ المطابقة والاعتماد المالي';
  @override String get paymentCodeCol => 'كود الطلب';
  @override String get bankSwiftCol => 'البنك / السويفت';
  @override String get equivalentEgpCol => 'المعادل بالجنيه المصري';
  @override String get requestDueDateCol => 'تاريخ الطلب / الاستحقاق';
  @override String get draftStatus => 'مسودة';
  @override String get paidStatus => 'تم التحويل';
  @override String get reconciledStatus => 'مطابق بالسويفت';
  @override String get importFile => 'ملف الشحنة';
  @override String get notLinked => 'غير مرتبط';
  @override String get currencyCol => 'العملة';
  @override String get exchangeRateCol => 'سعر الصرف';
  @override String get poNumberCol => 'رقم أمر الشراء';
  @override String get projectNameCol => 'اسم المشروع';
  @override String get invoiceAmount => 'قيمة الفاتورة';
  @override String get reset => 'تفريغ';
  @override String get budgetApprovalTab => 'اعتماد ميزانية الشحنة';
  @override String get savedBudgetsTab => 'سجل الميزانيات المحفوظة';
  @override String get paymentRequestsLogTab => 'سجل التحويلات وسداد الموردين';
  @override String get paymentRequestHeader => 'إصدار طلب سداد مالي لمورد / جهة خارجية';
  @override String get paymentRequestSub => 'إنشاء طلب تحويل مالي مستندي وتوجيهه للإدارة المالية';
  @override String get duplicatePaymentRequestTitle => 'طلب سداد مالي محفوظ مسبقاً';
  @override String duplicatePaymentRequestMessage(String code, String title) => '⚠️ تم إصدار وحفظ طلب سداد مالي سابق لملف الشحنة هذا ($code - $title).\n\nوفقاً للسياسة، لا يمكن إنشاء طلب جديد مكرر، ويجب الذهاب للتعديل على الطلب الحالي.';
  @override String get cancelSelection => 'إلغاء التحديد';
  @override String get viewAndEditPaymentRequest => 'استعراض وتعديل طلب السداد الحالي';
  @override String get duplicateBudgetTitle => 'اعتماد ميزانية محفوظ مسبقاً';
  @override String duplicateBudgetMessage(String code, String title) => '⚠️ تم اعتماد ميزانية سابقة لملف الشحنة هذا ($code - $title).\n\nوفقاً للسياسة، لا يمكن إنشاء اعتماد ميزانية مكرر، ويجب الذهاب للاستعراض والتعديل على الميزانية الحالية.';
  @override String get viewAndPrintBudget => 'استعراض وطباعة الميزانية الحالية';
  @override String paymentRequestUpdatedSuccess(String code) => '✅ تم تعديل طلب السداد بنجاح ($code)';
  @override String paymentRequestCreatedSuccess(String code) => '✅ تم إصدار طلب السداد بنجاح ($code)';
  @override String get savePaymentFailedTitle => 'تعذر حفظ طلب السداد المالي';
  @override String paymentLoadedForEditMsg(String code) => '✏️ تم تحميل طلب السداد ($code) للتعديل';
  @override String budgetLoadedForEditMsg(String code) => '✏️ تم استدعاء وتحميل بيانات الميزانية ($code) للنموذج للتعديل';
  @override String get confirmDeletePaymentTitle => 'تأكيد حذف طلب السداد';
  @override String confirmDeletePaymentMessage(String code, String title) => 'هل أنت متأكد من رغبتك في حذف طلب السداد المالي ($code - $title)؟\n\nسيتم أرشفة السجل وإمكانية استعادته لاحقاً.';
  @override String paymentDeletedSuccess(String code) => '🗑️ تم حذف طلب السداد ($code) بنجاح';
  @override String deleteErrorMsg(String error) => '❌ خطأ أثناء الحذف: $error';
  @override String budgetUpdatedSuccess(String code) => '✅ تم تعديل الميزانية الاستيرادية ($code) بنجاح';
  @override String budgetCreatedSuccess(String code) => '✅ تم اعتماد وحفظ الميزانية الاستيرادية ($code)';
  @override String budgetApprovedSuccess(String code) => '✅ تم اعتماد الميزانية الاستيرادية ($code) بنجاح';
  @override String get saveAndApproveBudget => 'حفظ واعتماد الميزانية';
  @override String faOpenPaymentSameType(String code) => 'يوجد طلب سداد مالي قيد الإجراء من نفس النوع لهذا الملف ($code)';
  @override String get freightExchangeRateLabel => 'سعر صرف النولون بالجنيه المصري';
  @override String get autoGeneratedCode => 'توليد تلقائي للكود';
  @override String get saveBudgetFailedTitle => 'تعذر اعتماد وحفظ الميزانية الاستيرادية';
  @override String get swiftPaymentPrefix => 'سداد تحويل سويفت';
  @override String get orderingCustomerPrefix => 'الآمر بالتحويل';
  @override String get paymentDetailsPrefix => 'التفاصيل';
  @override String swiftDataExtractedSuccess(String filename) => filename.isNotEmpty ? '📄 تم استخراج بيانات السويفت بنجاح من مستند "$filename" وتعبئة النموذج ⚡' : '⚡ تم استخراج بيانات السويفت البنكي وتعبئة حقول طلب السداد بنجاح!';
  @override String get emptyTextError => 'نص فارغ';
  @override String get swiftTextParseError => '⚠️ تعذر قراءة بيانات السويفت من النص. يرجى التأكد من احتواء النص على بيانات التحويل.';
  @override String swiftFileExtractError(String err) => '❌ تعذر استخراج البيانات من الملف: $err';
  @override String paymentRequestDetailsTitle(String code) => 'طلب سداد مالي: $code';
  @override String beneficiarySupplierDetails(String supplier) => 'المورد المستفيد: $supplier';
  @override String get foreignAmountMetric => 'المبلغ بالعملة الأجنبية';
  @override String get exportAndShareOptionsTitle => 'خيارات التصدير، الطباعة والمشاركة المباشرة:';
  @override String get paymentDataCopied => '📋 تم نسخ بيانات طلب السداد للحافظة بنجاح';
  @override String get extractAndMatchSwiftBtn => 'استخراج ومطابقة السويفت ⚡';
  @override String get swiftReferenceInputLabel => 'رقم إشعار التحويل البنكي (السويفت) *';
  @override String get approvePaymentAction => 'اعتماد الطلب';
  @override String get markAsPaidAction => 'تأكيد التحويل والسداد';
  @override String get sendPaymentWhatsAppTitle => 'إرسال تفاصيل السداد عبر واتساب';
  @override String get whatsAppNumberLabel => 'رقم الواتساب مع كود الدولة (اختياري - مثال: 201001234567)';
  @override String get whatsAppNumberHint => 'اتركه فارغاً لاختيار جهة الاتصال في واتساب مباشرة';
  @override String get messagePreviewLabel => 'معاينة نص الرسالة:';
  @override String get openWhatsAppBtn => 'فتح في واتساب 🚀';
  @override String get sendPaymentEmailTitle => 'إرسال طلب السداد عبر البريد الإلكتروني';
  @override String get recipientEmailLabel => 'البريد الإلكتروني للمستلم';
  @override String emailSubjectLabel(String subject) => 'الموضوع: $subject';
  @override String get openEmailClientBtn => 'فتح برنامج البريد 📧';
  @override String budgetDetailsTitle(String code) => 'اعتماد الميزانية: $code';
  @override String get budgetReportCopied => '📋 تم نسخ تقرير الميزانية للحافظة بنجاح';
  @override String get sendBudgetWhatsAppTitle => 'مشاركة اعتماد الميزانية عبر واتساب';
  @override String get sendBudgetEmailTitle => 'إرسال تقرير الميزانية بالبريد الإلكتروني';
  @override String get approveNewBudgetAction => 'اعتماد ميزانية جديدة';
  @override String budgetCodeCopied(String code) => '📋 تم نسخ كود الميزانية ($code)';
  @override String get approvedByLabel => 'المعتمد من:';
  @override String get printOfficialPdf => 'طباعة المستند الرسمي PDF';
  @override String get importCostItemCol => 'بند التكلفة الاستيرادية';
  @override String get amountInCurrencyCol => 'القيمة بالعملة';
  @override String get commercialInvoiceItem => 'فاتورة البضاعة التجارية';
  @override String get freightItem => 'النولون والشحن الدولي';
  @override String get customsAndVatItem => 'الضرائب والجمارك والقيمة المضافة';
  @override String get clearanceAndInlandTransportItem => 'أتعاب التخليص والنقل الداخلي';
  @override String get totalApprovedBudgetItem => 'إجمالي الميزانية المعتمدة الكلية';
  @override String get notesAndInstructionsLabel => 'ملاحظات وتوجيهات:';
  @override String get confirmDeleteBudgetTitle => 'تأكيد حذف اعتماد الميزانية';
  @override String confirmDeleteBudgetMessage(String code, String title) => 'هل أنت متأكد من رغبتك في حذف اعتماد الميزانية ($code - $title)؟';
  @override String budgetDeletedSuccess(String code) => '🗑️ تم حذف اعتماد الميزانية ($code) بنجاح';
  @override String get noBudgetsPlaceholderMessage => 'قم بإنشاء ميزانية استيرادية جديدة أو تغيير فلاتر البحث';
  @override String get approveNewBudgetNow => 'اعتماد ميزانية جديدة الآن ➕';
  @override String get paymentSummaryCopied => '📋 تم نسخ بيانات طلب السداد بنجاح';
  @override String get budgetSummaryCopied => '📋 تم نسخ ملخص اعتماد الميزانية إلى الحافظة بنجاح';
  @override String get editInForm => 'تعديل بالنموذج';
  @override String get openMailClient => 'فتح تطبيق البريد';
  @override String get sendNow => 'إرسال الآن';
  @override String get customsAuthority => 'مصلحة الجمارك';

  // ── Screen 11: Nafeza ACID Operations ───────────────────────────────────
  @override String get nafezaAcidTitle => 'منظومة نافذة والتسجيل المسبق للشحنات';
  @override String get searchAndCloneAcidBtn => 'بحث واستنساخ طلب ACID';
  @override String get searchAndCloneAcidDialogTitle => 'بحث واستنساخ طلب ACID سابق';
  @override String get searchAcidHint => 'ابحث برقم ACID أو ملف الشحنة أو المورد أو الفاتورة...';
  @override String get noAcidsFound => 'لم يتم العثور على طلبات ACID مطابقة';
  @override String get cloneAcidSuccess => 'تم استنساخ بيانات طلب ACID بنجاح وجاهزة للمراجعة';
  @override String get acidClonedResetNotice => 'ملاحظة: تم تصفير رقم ACID وحالة الإفراج تلقائياً';
  @override String get importFromPreviousAcidSessionBtn => 'استيراد نص من جلسة سابقة';
  @override String get rawTextImportedSuccess => 'تم استيراد نص إشعار نافذة بنجاح من الجلسة السابقة';
  @override String get cloneAcidRecordTooltip => 'استنساخ سجل ACID إلى مسودة جديدة';
  @override String get copyDiscrepancyReportBtn => 'نسخ تقرير المطابقة';
  @override String get discrepancyReportCopiedSuccess => 'تم نسخ تقرير المطابقة الجمركية إلى الحافظة بنجاح';
  @override String get emptyComparisonHint => 'اختر ملف شحنة ثم اضغط "تشغيل المقارنة والتحقق" لفحص تطابق بيانات ACID المستخرجة مع أمر الشراء والفاتورة.';
  @override String get acidRequestTab => 'طلب إصدار الرقم المبدئي';
  @override String get smartMtsParserTab => 'الإدخال الذكي من نافذة';
  @override String get discrepancyMatrixTab => 'المقارنة والتحقق الجمركي';
  @override String get acidRegistryTab => 'سجل إصدارات ACID';
  @override String get expiryTrackerTab => 'متتبع الصلاحية والإفراج';
  @override String get acidInfoBanner => 'تسجيل وطلب استخراج رقم القيد الجمركي المبدئي وفق متطلبات مصلحة الجمارك المصرية ومنظومة نافذة (MTS). اختر ملف الشحنة لتحميل بيانات المستورد والمورد الأجنبي تلقائياً.';
  @override String get selectImportFileAcidLabel => 'اختر ملف الشحنة لطلب ACID';
  @override String get searchFileOrSupplierHint => 'ابحث برقم الملف أو اسم المورد أو الشركة...';
  @override String get importerAndExporterSection => '1. بيانات المستورد والمصدر الأجنبي';
  @override String get importerSectionTitle => 'الشركة المستوردة';
  @override String get importerTaxIdLabel => 'الرقم الضريبي للمستورد';
  @override String get importerAddressLabel => 'عنوان المستورد المسجل بنافذة';
  @override String get foreignExporterSectionTitle => 'المصدر الأجنبي';
  @override String get foreignExporterIdLabel => 'رقم السجل / المعرف الضريبي بالخارج';
  @override String get regTypeLabel => 'نوع التسجيل';
  @override String get countryOfOriginExportLabel => 'دولة المنشأ / التصدير';
  @override String get cargoxPlatformIdLabel => 'معرف منصة كارجو إكس (CargoX)';
  @override String get proformaPortsBrokerSection => '2. بيانات الفاتورة المبدئية والموانئ والمخلص';
  @override String get proformaInvoiceNoLabel => 'رقم الفاتورة المبدئية';
  @override String get proformaInvoiceDateLabel => 'تاريخ الفاتورة';
  @override String get invoiceTypeLabel => 'نوع الفاتورة المقدمة';
  @override String get customsBrokerResponsibleLabel => 'المخلص الجمركي المسؤول';
  @override String get brokerPhoneLabel => 'هاتف المخلص للتواصل';
  @override String get acidRequestDateLabel => 'تاريخ تقديم الطلب بنافذة';
  @override String get saveAcidRequestButton => 'حفظ بيانات الطلب وإرسالها للمطابقة';
  @override String get updateAcidRequestButton => 'تعديل وحفظ طلب ACID';
  @override String get goToSmartParserButton => 'الانتقال للإدخال الذكي من نافذة';
  @override String get brokerDispatchMessageTitle => 'رسالة طلب إصدار ACID الجاهزة للإرسال للمخلص الجمركي';
  @override String get brokerDispatchMessageSub => 'تم تجميع وتوليد الرسالة تلقائياً بكافة البيانات المستدعاة من الشحنة لتسهيل إرسالها للمخلص عبر الواتساب أو الإيميل بنقرة واحدة.';
  @override String get copyArabicWhatsApp => 'نسخ عربي (WhatsApp)';
  @override String get copyEnglishRequest => 'نسخ بالإنجليزية (English)';
  @override String get emailTemplateButton => 'قالب الإيميل';
  @override String get smartParserInfoBanner => 'المحلل الذكي لنصوص نافذة (MTS Smart Parser): الصق النص الخام المستلم من إشعار نافذة أو البريد الإلكتروني. سيقوم النظام باستخراج رقم ACID، تاريخ الصلاحية، بيانات المصدر والمستورد تلقائياً وبدقة 100%.';
  @override String get linkImportFileResult => 'ربط بنتيجة ملف شحنة';
  @override String get pasteRawMtsTextTitle => 'الصق نص إشعار نافذة الخام هنا';
  @override String get loadSampleMtsTextButton => 'تحميل نص إشعار نافذة نموذجي';
  @override String get pasteFromClipboardButton => 'لصق من الحافظة';
  @override String get runSmartParserButton => 'تشغيل المحلل الذكي واستخراج البيانات';
  @override String get clearTextButton => 'مسح النص';
  @override String get parsedMtsSuccessTitle => 'البيانات المستخرجة بنجاح من نص نافذة';
  @override String get parsedMtsNoAcidTitle => 'نتائج الاستخراج (لم يتم العثور على رقم ACID في النص)';
  @override String get goToVerificationButton => 'الانتقال للمطابقة والتحقق';
  @override String get saveAndCertifyAcidButton => 'حفظ واعتماد بيانات ACID بالشحنة';
  @override String get saveTempDraftButton => 'حفظ مؤقت (مسودة)';
  @override String get editExtractedDataButton => 'تعديل البيانات المستخرجة';
  @override String get codeSupplierButton => 'تكويد / تحديث المورد';
  @override String get acidNumberCol => 'رقم ACID';
  @override String get issueDateCol => 'تاريخ الإصدار';
  @override String get expiryDateCol => 'تاريخ الصلاحية';
  @override String get foreignExporterCol => 'المصدر الأجنبي';
  @override String get importerCompanyCol => 'الشركة المستوردة';
  @override String get actionCol => 'الإجراءات';
  @override String get daysRemainingCol => 'الأيام المتبقية';
  @override String get validityStatusCol => 'حالة الصلاحية';
  @override String get runDiscrepancyMatrixButton => 'تشغيل مصفوفة المطابقة الفورية';
  @override String get perfectMatchTitle => 'المطابقة الجمركية كاملة بنسبة 100%';
  @override String get discrepancyFoundTitle => 'يوجد عدم تطابق في بعض الحقول الجمركية الأساسية!';
  @override String get customsFieldCol => 'الحقل الجمركي';
  @override String get requestedValueCol => 'البيان المطلوب (النظام)';
  @override String get generatedValueCol => 'البيان الصادر (نافذة)';
  @override String get matchingStatusCol => 'حالة المطابقة';
  @override String get discrepancyOverrideJustificationLabel => 'ملاحظات وتبرير اعتماد الفروق';
  @override String get verifyAndCertifyAcidButton => 'اعتماد وتثبيت رقم ACID بملف الشحنة';
  @override String get searchAcidRegistryHint => 'بحث في سجل أرقام ACID برقم القيد، المورد، رقم الملف...';
  @override String get newAcidRequestButton => 'طلب ACID جديد';
  @override String get totalAcidsCard => 'إجمالي أرقام ACID';
  @override String get validAcidsCard => 'ساري (> 14 يوم)';
  @override String get expiringSoonAcidsCard => 'أوشك على الانتهاء (≤ 14 يوم)';
  @override String get expiredAcidsCard => 'منتهي الصلاحية';
  @override String get searchExpiryTrackerHint => 'بحث في متتبع الصلاحيات والإفراج الجمركي...';
  @override String get validStatusBadge => 'ساري وصالح';
  @override String get expiringSoonStatusBadge => 'أوشك على الانتهاء';
  @override String get expiredStatusBadge => 'منتهي الصلاحية';
  @override String get matchedStatus => 'مطابق';
  @override String get discrepancyStatus => 'فروق';
  @override String get issuedAndValidStatus => 'صادر وساري';
  @override String get tempDraftStatus => 'مسودة مؤقتة';
  @override String get underReviewStatus => 'قيد المراجعة';
  @override String get commercialInvoiceLabel => 'فاتورة تجارية';
  @override String get proformaInvoiceLabel => 'فاتورة مبدئية';
  @override String acidSessionDeletedSuccess(String code) => 'تم حذف سجل ACID ($code) بنجاح';
  @override String acidSessionLoadedForEdit(String code) => 'تم فتح طلب ACID ($code) للتعديل الكامل';
  @override String get mtsExtractedDataUpdated => 'تم تحديث بيانات نافذة المستخرجة بنجاح';
  @override String get errorSavingDraft => 'خطأ في حفظ مسودة ACID';
  @override String get errorSavingAcid => 'خطأ في حفظ طلب ACID';
  @override String get errorDeletingAcid => 'خطأ في حذف سجل ACID';
  @override String get errorCustomsComparison => 'خطأ في المقارنة الجمركية';
  @override String get errorCertifyingAcid => 'خطأ في اعتماد رقم ACID';
  @override String get errorParsingMts => 'خطأ في تحليل نص نافذة';
  @override String get errorCodingSupplier => 'خطأ في تكويد المورد';
  @override String get foreignSupplierNotInData => 'اسم المصدر الأجنبي غير موجود في بيانات نافذة';
  @override String supplierCodedSuccess(String name) => 'تم تكويد وتحديث المورد الأجنبي ($name) بنجاح';
  @override String acidRequestUpdatedSuccess(String code) => 'تم تعديل وتحديث بيانات طلب ACID ($code) بنجاح';
  @override String get acidRequestSavedSuccess => 'تم تسجيل وحفظ طلب ACID بنجاح';
  @override String get acidCertifiedSuccess => 'تم اعتماد وتثبيت رقم ACID بنجاح ✅';
  @override String get mtsNoticeDisclaimerAlertTitle => 'تنبيه: نص تذييل الإيميل فقط';
  @override String get mtsNoticeDisclaimerAlertContent => 'النص الملصق يحتوي فقط على إشعار السرية وتذييل الإيميل القانوني (Email Disclaimer):\n\n«MTS EMAIL NOTICE This Electronic Mail...»\n\nولا يحتوي على بيانات إشعار القيد الجمركي (رقم ACID، تاريخ الصلاحية، المصدر والمستورد).\n\n👉 يرجى نسخ محتوى الإيميل الرئيسي من الأعلى، أو تجربة النموذج بالنقر على الزر أدناه.';
  @override String get mtsNoticeNoAcidAlertTitle => 'لم يتم العثور على رقم ACID في النص الملصق';
  @override String get mtsNoticeNoAcidAlertContent => 'النص الذي تم لصقه ينقصه السطور العلوية الأولى من إشعار نافذة (التي تحتوي على رقم ACID المكون من 19 رقماً وتواريخ الصلاحية).\n\n📌 للتجربة الفورية ورؤية جدول الاستخراج بالكامل، اضغط على "تحميل إشعار نافذة نموذجي".';
  @override String get loadSampleMtsAndExtract => 'تحميل نص نموذجي واستخراجه فوراً';
  @override String get loadSampleMtsAndTest => 'تحميل نص إشعار نافذة نموذجي وتجربته فوراً';
  @override String acidExtractedSuccess(String acid) => '✅ تم استخراج رقم ACID: $acid وكافة بيانات الشحنة بنجاح!';
  @override String get selectImportFileFirst => 'يرجى اختيار ملف الشحنة أولاً';
  @override String get pasteMtsTextFirst => 'يرجى لصق نص نافذة أولاً';
  @override String get selectImportFileToVerify => 'يرجى اختيار ملف الشحنة للتحقق';
  @override String get whatsAppMessageCopied => '✅ تم نسخ رسالة الواتساب';
  @override String get acidRequestCopied => '✅ تم نسخ رسالة طلب ACID';
  @override String get emailTemplateCopied => '✅ تم نسخ قالب البريد الإلكتروني';
  @override String get discrepancyOverrideReasonHint => 'أدخل مبرر استثناء الفروقات الجمركية...';
  @override String get mtsNotificationHint => 'إشعار نافذة [رقم ACID: 19 رقماً]...';
  @override String get vatRegType => 'الرقم الضريبي (VAT)';
  @override String get crRegType => 'السجل التجاري (CR)';
  @override String get taxIdRegType => 'البطاقة الضريبية (Tax ID)';
  @override String get dunsRegType => 'معرف دانز (DUNS)';
  @override String get companyRegNumberType => 'رقم السجل التجاري للشركة';
  @override String get foreignExporterNafezaType => 'رقم المصدر الأجنبي (نافذة)';
  @override String get factoryRegType => 'تسجيل المصنع';
  @override String get poLabelPrefix => 'أمر شراء';

  // ── Screen 16: Bank Form 4 ──────────────────────────────────────────────
  @override String get bankForm4Title => 'المستندات والتوثيق البنكي ونموذج 4';
  @override String get form4RequestTab => 'طلب وتوثيق نموذج 4';
  @override String get bankForm4RegistryTab => 'سجل النماذج البنكية';
  @override String bankForm4EditingBanner(String code) => 'أنت الآن في وضع تعديل النموذج البنكي المرجعي: $code';
  @override String get cancelEditNewForm4 => 'إلغاء التعديل والعودة لطلب جديد';
  @override String get selectImportFileForm4Label => 'اختر ملف الشحنة المرتبط بإصدار نموذج 4';
  @override String get bankApplicationDetailsSection => 'تفاصيل طلب التوثيق والتحويل البنكي';
  @override String get issuingBankLabel => 'البنك المصدر المعتمد';
  @override String get selectBankHint => 'اختر البنك...';
  @override String get bankAmountLabel => 'المبلغ المطلوب توثيقه';
  @override String get transferCurrencyLabel => 'عملة التحويل';
  @override String get selectCurrencyHint => 'اختر العملة...';
  @override String get bankRequestDateLabel => 'تاريخ تقديم الطلب للبنك';
  @override String get bankNotesLabel => 'ملاحظات وتوجيهات خاصة لفرع البنك';
  @override String get form4ChecklistSectionTitle => 'قائمة المستندات المرفقة بملف نموذج 4 للبنك';
  @override String get form4ItemProformaInvoice => 'الفاتورة المبدئية المعتمدة';
  @override String get form4ItemPackingList => 'قائمة التعبئة والتغليف';
  @override String get form4ItemCertificateOfOrigin => 'شهادة المنشأ الموثقة';
  @override String get form4ItemBillOfLading => 'مسودة بوليصة الشحن';
  @override String get form4ItemAcidNotice => 'إشعار التسجيل المسبق نافذة';
  @override String get form4ItemMarineInsurance => 'وثيقة التأمين البحري';
  @override String get form4ItemBankApplication => 'طلب تحويل البنك موقع ومختوم';
  @override String get form4ItemAdminFeeReceipt => 'إيصال سداد المصاريف الإدارية';
  @override String get saveForm4Button => 'حفظ وتسجيل طلب نموذج 4';
  @override String get updateForm4Button => 'تحديث نموذج 4';
  @override String get goToBankRegistryButton => 'الانتقال لسجل النماذج البنكية';
  @override String get searchBankRegistryHint => 'بحث في سجل النماذج البنكية بالرمز، البنك، رقم الملف...';
  @override String get newForm4RequestButton => 'طلب نموذج 4 جديد';
  @override String get documentCodeCol => 'كود المستند';
  @override String get certifiedBankCol => 'البنك المعتمد';
  @override String get amountAndCurrencyCol => 'المبلغ والعملة';
  @override String get requestDateCol => 'تاريخ التقديم';
  @override String get endorsementStatusCol => 'حالة التوثيق';
  @override String get endorsedStatusBadge => 'معتمد وموثق';
  @override String get bankProcessingStatusBadge => 'قيد المعالجة البنكية';
  @override String get form4SavedSuccess => 'تم حفظ نموذج 4 البنكي بنجاح';
  @override String get form4SaveError => 'خطأ في حفظ نموذج 4';
  @override String get searchAndCloneBankForm4Btn => 'نسخ من نموذج سابق';
  @override String get searchAndCloneBankForm4DialogTitle => 'البحث ونسخ نموذج 4 بنكي سابق';
  @override String get searchBankForm4Hint => 'بحث بكود المستند، البنك، كود الشحنة، أو المبلغ...';
  @override String get noBankForm4Found => 'لم يتم العثور على نماذج بنكية مطابقة للبحث';
  @override String get cloneBankForm4Success => 'تم نسخ بيانات نموذج 4 بنجاح مع تصفير المحددات الإلزامية';
  @override String get bankForm4ClonedResetNotice => 'سيتم تصفير كود النموذج وإعادة ضبط تاريخ الطلب وفك الارتباط بالسجل السابق';
  @override String get cloneBankForm4RecordTooltip => 'نسخ نموذج 4 بنكي';

  // ── Screen 18: Draft B/L Review ──────────────────────────────────────────
  @override String get draftBlStage0ReviewSheet => '1. ورقة المراجعة والتدقيق';
  @override String get draftBlStage1RevisionReport => '2. تقرير التعديلات وخطاب الخط الملاحي';
  @override String get draftBlStage2VersionBranching => '3. إدارة النسخ والإصدارات';
  @override String get draftBlStage3DualApproval => '4. الاعتماد الثنائي';
  @override String get draftBlStage4FinalRegistry => '5. السجل النهائي المعتمد';
  @override String get draftBlReviewSheetTitle => 'ورقة مراجعة واعتماد مسودة بوليصة الشحن';
  @override String get draftBlReviewSheetSub => 'يقوم النظام تلقائياً باستدعاء كافة البيانات المرجعية للشحنة من الحجز الملاحي وبيان العبوة المعتمد، ومقارنتها مباشرة بمسودة الخط الملاحي.';
  @override String draftBlMismatchesFound(int count) => 'يوجد $count اختلافات غير مطابقة';
  @override String get draftBlPerfectMatchReady => 'مطابقة تامة 100% جاهزة للاعتماد';
  @override String get draftBlSelectImportFileLabel => 'ملف الشحنة الاستيرادي *';
  @override String get draftBlRefreshAndCompare => 'تحديث ومقارنة البيانات';
  @override String get draftBlSmartExtractorTitle => '📥 استخراج ذكي من ملفات ومسودات البوليصة';
  @override String get draftBlSmartExtractorSub => 'ارفع ملف المسودة مباشرة من الخط الملاحي أو الصق نص المسودة للاستخراج والمطابقة الآلية الفورية';
  @override String get draftBlUploadAndExtractButton => '📁 رفع واستخراج ملف المسودة (PDF، Word، Excel)';
  @override String get draftBlExtractingFileProgress => 'جاري قراءة واستخراج بيانات الملف...';
  @override String draftBlFileExtractedSuccess(String filename, String sizeKb) => 'تم استخراج: $filename ($sizeKb KB)';
  @override String get draftBlReuploadTooltip => 'إعادة رفع ملف آخر';
  @override String get draftBlExtractedBlNumberLabel => 'رقم البوليصة المستخرج:';
  @override String get draftBlCopyBlNumberTooltip => 'نسخ رقم البوليصة';
  @override String draftBlCopiedBlNumberSnackbar(String blNumber) => '✔ تم نسخ رقم البوليصة ($blNumber) إلى الحافظة';
  @override String get draftBlEditBlNumberTitle => 'تعديل رقم بوليصة الشحن';
  @override String get draftBlSafetyAlertTitle => '⚠️ تنبيه أمان رقابي: المستند المستخرج يحتوي على حقول حرجة غير مكتملة أو تحتاج تأكيد يدوي';
  @override String get draftBlSafetyAlertSub => 'يرجى مراجعة وتأكيد الحقول الحرجة بالجدول أدناه لتفادي المقارنة أو الاعتماد بناءً على بيانات غير مكتملة.';
  @override String get draftBlSmartExtractionComplete => '✅ تم الاستخراج الذكي الشامل واكتمال كافة الحقول الحرجة بنسبة 100%.';
  @override String get draftBlPasteRawTextTitle => 'أو الصق نص المسودة يدوياً:';
  @override String get draftBlPasteRawTextHint => 'الصق هنا النص المنسوخ من مسودة البوليصة أو الإيميل...';
  @override String get draftBlExtractFromTextButton => '⚡ استخراج ومطابقة ذكية من النص';
  @override String get draftBlReferenceVisualSheetTitle => '1. ملخص الشحنة المرجعي كشكل بوليصة شحن';
  @override String get draftBlReferenceVisualSheetSub => 'البيانات المرجعية المسجلة داخل النظام من ماستر داتا المورد والمستورد وبيان العبوة والحجز الملاحي ومعايير نافذة (ACID)';
  @override String get draftBlExtractedVisualSheetTitle => '5. شكل بوليصة مسودة الخط الملاحي المستخرجة';
  @override String get draftBlExtractedVisualSheetSub => 'مطابقة حية وتأكيد لصحة بيانات بوليصة الشحن مع متطلبات نافذة (ACID)';
  @override String get draftBlSwitchToGridView => 'التبديل إلى عرض البطاقات التفصيلية';
  @override String get draftBlSwitchToVisualBl => 'عرض كشكل بوليصة رسمية';
  @override String get draftBlAutoSummaryTitle => '1. ملخص الشحنة المرجعي التلقائي';
  @override String get draftBlAutoSummarySub => 'البيانات المرجعية المسجلة داخل النظام من ماستر داتا المورد والمستورد والحجز الملاحي وبيان العبوة المعتمد.';
  @override String get draftBlSummaryShipper => 'الشاحن';
  @override String get draftBlSummaryConsignee => 'المستورد';
  @override String get draftBlSummaryNotifyParty => 'جهة الإخطار';
  @override String get draftBlSummaryVesselVoyage => 'الباخرة والرحلة';
  @override String get draftBlSummaryPorts => 'الموانئ';
  @override String get draftBlSummaryFreightTerms => 'شروط النولون';
  @override String get draftBlSummaryBookingNo => 'رقم الحجز';
  @override String get draftBlSummaryAcidNo => 'رقم القيد الجمركي المبدئي';
  @override String get draftBlSummaryImporterTaxId => 'البطاقة الضريبية للمستورد';
  @override String get draftBlSummaryShipperReg => 'رقم تسجيل المصدر';
  @override String get draftBlSummaryContainers => 'الحاويات والرصاص';
  @override String get draftBlSummaryGrossWeight => 'الوزن القائم';
  @override String get draftBlSummaryNetWeight => 'الوزن الصافي';
  @override String get draftBlSummaryCbm => 'الحجم الإجمالي';
  @override String get draftBlSummaryPackages => 'عدد ونوع الطرود';
  @override String get draftBlChecklistSectionTitle => '2. قائمة التدقيق والمطابقة الشاملة';
  @override String get draftBlChecklistSectionSub => 'جدول المطابقة المباشر لكل حقل بين بيانات النظام وقيم المسودة مع تحديد الحالة وتحديد الإجراء والجهة المسؤولة.';
  @override String get draftBlSaveSessionButton => 'حفظ جلسة المراجعة';
  @override String get draftBlRevisionReportCarrierButton => 'تقرير التعديلات للخط الملاحي ➔';
  @override String get draftBlSelectFileToStartChecklist => 'يرجى اختيار ملف الشحنة لبدء المطابقة الآلية';
  @override String get draftBlChecklistColField => 'الحقل';
  @override String get draftBlChecklistColSystemValue => 'البيانات بالنظام';
  @override String get draftBlChecklistColDraftValue => 'قيمة المسودة';
  @override String get draftBlChecklistColStatus => 'الحالة';
  @override String get draftBlChecklistColRequiredAction => 'الإجراء والتصحيح المطلوب';
  @override String get draftBlChecklistColResponsibleParty => 'الجهة المسؤولة';
  @override String get draftBlChecklistColReasonNotes => 'السبب والملاحظات';
  @override String get draftBlStatusCorrect => 'مطابق';
  @override String get draftBlStatusIncorrect => 'غير مطابق';
  @override String get draftBlStatusNA => 'غير مطلوب';
  @override String get draftBlPartyShippingLine => 'الخط الملاحي';
  @override String get draftBlPartySupplier => 'المورد الأجنبي';
  @override String get draftBlPartyImporter => 'المستورد';
  @override String get draftBlPartyCustomsBroker => 'المخلص الجمركي';
  @override String get draftBlCopySystemValueTooltip => 'نسخ قيمة النظام للمسودة وتأكيد المطابقة';
  @override String get draftBlEnterDraftValueHint => 'أدخل قيمة المسودة...';
  @override String get draftBlMatchedHint => 'مطابق';
  @override String get draftBlEnterCorrectionHint => 'اكتب التصحيح المطلوب...';
  @override String get draftBlEnterReasonHint => 'السبب أو الملاحظات...';
  @override String get draftBlSelectFileToViewRevision => '⚠️ يرجى اختيار وتحديد ملف الشحنة أولاً لعرض تقرير التعديلات وخطاب الخط الملاحي';
  @override String get draftBlBackToSelectFile => 'العودة لاختيار الملف';
  @override String get draftBlRevisionReportTitle => 'تقرير التعديلات المطلوبة';
  @override String get draftBlRevisionReportSub => 'يضم هذا التقرير فقط البنود غير المطابقة المطلوب تعديلها من الخط الملاحي أو المورد.';
  @override String get draftBlProceedToVersionHistory => 'المتابعة لسجل النسخ (المرحلة 3)';
  @override String get draftBlNoAmendmentsNeeded => 'رائع! لا توجد أي تعديلات مطلوبة. كافة بنود المسودة مطابقة تماماً للمنظومة.';
  @override String get draftBlRevisionColItem => 'البند';
  @override String get draftBlRevisionColRequiredAction => 'الإجراء والتصحيح المطلوب';
  @override String get draftBlRevisionColResponsible => 'الجهة المسؤولة';
  @override String get draftBlRevisionColReason => 'السبب';
  @override String get draftBlCarrierRequestLetterTitle => 'خطاب طلب التعديل الرسمي للخط الملاحي';
  @override String get draftBlCopyLetterButton => 'نسخ الخطاب';
  @override String get draftBlLetterCopiedSnackbar => '✔ تم نسخ خطاب التعديل إلى الحافظة بنجاح';
  @override String get draftBlSelectFileToViewVersions => '⚠️ يرجى اختيار وتحديد ملف الشحنة أولاً لعرض إدارة النسخ والتعديلات';
  @override String get draftBlVersionBranchingTitle => 'إدارة النسخ والإصدارات';
  @override String get draftBlVersionBranchingSub => 'عند استلام مسودة معدلة جديدة (v2, v3)، يقوم النظام بقفل البنود المطابقة سابقاً، وإعادة فتح البنود ذات الملاحظات فقط للتأكد من تعديلها.';
  @override String get draftBlProceedToDualApproval => 'المتابعة للاعتماد الثنائي (المرحلة 4)';
  @override String draftBlActiveVersionBanner(String version, String stage, int lockedCount) => 'النسخة الحالية النشطة: $version ($stage) | البنود المقفلة: $lockedCount';
  @override String get draftBlSelectFileToCompleteApproval => '⚠️ يرجى اختيار وتحديد ملف الشحنة أولاً لإتمام الاعتماد الثنائي للبوليصة';
  @override String get draftBlApprovalBlockedTitle => '🚨 حظر الاعتماد التام: توجد اختلافات حرجة تمنع اعتماد البوليصة';
  @override String get draftBlImporterApprovalTitle => '1. اعتماد مسؤول الاستيراد';
  @override String get draftBlImporterApproverNameLabel => 'اسم مسؤول الاعتماد *';
  @override String get draftBlImporterNotesLabel => 'ملاحظات وتوجيهات الاستيراد';
  @override String get draftBlApproveAndAcceptButton => 'اعتماد وموافقة';
  @override String get draftBlRejectDraftButton => 'رفض المسودة';
  @override String get draftBlBrokerApprovalTitle => '2. اعتماد المخلص الجمركي';
  @override String get draftBlBrokerApproverNameLabel => 'اسم المخلص الجمركي المعتمد *';
  @override String get draftBlBrokerNotesLabel => 'ملاحظات التخليص ومطابقة نافذة';
  @override String get draftBlBrokerApproveButton => 'اعتماد جمركي وموافقة';
  @override String get draftBlFinalRegistryTitle => 'سجل مسودات البوليصة المعتمدة نهائياً';
  @override String get draftBlFinalRegistrySub => 'النسخ المعتمدة هنا أصبحت غير قابلة للتعديل وتعتبر الوثيقة الحاكمة لإصدار البوليصة الأصلية والإفراج الجمركي.';
  @override String get draftBlRefreshRegistry => 'تحديث السجل';
  @override String get draftBlSearchRegistryHint => 'ابحث برقم البوليصة، رقم الجلسة، الخط الملاحي، أو المرحلة...';
  @override String get draftBlNoRegistriesFound => 'لا توجد نتائج مطابقة لبحثك';
  @override String get draftBlNoRegistriesYet => 'لا توجد جلسات مراجعة مسجلة حتى الآن';
  @override String get draftBlTryDifferentSearch => 'جرّب البحث برقم بوليصة آخر';
  @override String get draftBlExtractNewDraftHint => 'قم باستخراج واعتماد مسودة بوليصة جديدة من التاب الأول';
  @override String get draftBlRegistryColSessionId => 'رقم الجلسة';
  @override String get draftBlRegistryColBlNumber => 'رقم البوليصة';
  @override String get draftBlRegistryColShippingLine => 'الخط الملاحي';
  @override String get draftBlRegistryColVesselVoyage => 'السفينة والرحلة';
  @override String get draftBlRegistryColStage => 'المرحلة';
  @override String get draftBlRegistryColImporterApproval => 'اعتماد المستورد';
  @override String get draftBlRegistryColBrokerApproval => 'اعتماد المخلص';
  @override String get draftBlRegistryColStatus => 'الحالة';
  @override String get draftBlRegistryColActions => 'الإجراءات';
  @override String get draftBlViewBlTooltip => 'معاينة البوليصة';
  @override String get draftBlPrintBlTooltip => 'طباعة البوليصة';
  @override String get draftBlDownloadPdfTooltip => 'تنزيل PDF';
  @override String get draftBlPrintButton => 'طباعة البوليصة';
  @override String get draftBlDownloadPdfButton => 'تنزيل PDF';
  @override String get draftBlDownloadExcelButton => 'تنزيل Excel';
  @override String get draftBlSessionSavedSuccess => '✔ تم حفظ جلسة مراجعة درافت البوليصة بنجاح';
  @override String get draftBlSessionSaveError => 'خطأ أثناء حفظ الجلسة';
  @override String draftBlComparisonMismatch(int count) => '⚠️ تم استخراج ومطابقة المسودة: يوجد $count اختلاف يجب تعديلهم';
  @override String get draftBlComparisonMatchSuccess => '✔ تمت المطابقة بنجاح: مسودة البوليصة مطابقة تماماً لبيانات المنظومة';
  @override String draftBlComparisonError(dynamic e) => 'خطأ أثناء المقارنة: $e';
  @override String get draftBlFileReadError => 'تعذر قراءة بيانات الملف المختار';
  @override String draftBlExtractedWithCritical(String fileName) => '⚠️ تم الاستخراج من ($fileName) مع وجود حقول حرجة تحتاج تأكيدك ومراجعتك اليدوية';
  @override String draftBlExtractedSuccess(String fileName) => '✅ تم بنجاح استخراج بيانات المسودة من ملف ($fileName) وتعبئة حقول المراجعة';
  @override String draftBlExtractionError(dynamic e) => 'حدث خطأ أثناء استخراج الملف: $e';
  @override String get draftBlDualApprovalCompleted => '🎉 تم اكتمال الاعتماد الثنائي وتثبيت درافت البوليصة كـ معتمدة نهائياً';
  @override String get draftBlRevisionRequiredAlert => '⚠️ تم رفض المسودة وإعادتها لمرحلة التعديل المطلوبة';
  @override String draftBlRoleApprovalRegistered(String role) => '✔ تم تسجيل اعتماد $role بنجاح، في انتظار الاعتماد الآخر';
  @override String draftBlApprovalError(dynamic e) => 'خطأ أثناء الاعتماد: $e';
  @override String get draftBlPdfExportSuccess => '✔ تم تصدير البوليصة بصيغة PDF بنجاح';
  @override String draftBlPdfExportError(dynamic e) => 'خطأ أثناء تصدير PDF: $e';
  @override String draftBlPrintError(dynamic e) => 'خطأ أثناء إرسال أمر الطباعة: $e';
  @override String get searchFileOrShipmentHint => 'ابحث برقم الملف أو كود الشحنة...';
  @override String get searchFileOrCompanyHint => 'ابحث برقم الملف أو اسم الشركة...';
  @override String get unspecified => 'غير محدد';
  @override String get draftBlNoLetterGeneratedYet => 'لا يوجد خطاب مولد حالياً.';
  @override String get draftBlRegistryUpdatedSuccess => 'تم تحديث قائمة السجل النهائي المعتمد بنجاح';
  @override String draftBlPreviewSessionSnack(int id, String blNo) => 'معاينة الجلسة #$id: $blNo';
  @override String get searchAndCloneDraftBlBtn => 'البحث ونسخ مسودة سابقة';
  @override String get searchAndCloneDraftBlDialogTitle => 'البحث ونسخ مسودة بوليصة شحن (Draft B/L)';
  @override String get searchDraftBlHint => 'ابحث برقم البوليصة، الخط الملاحي، السفينة، أو كود المراجعة...';
  @override String get noDraftBlFound => 'لم يتم العثور على مسودات بوالص شحن مطابقة';
  @override String get cloneDraftBlSuccess => 'تم استنساخ بيانات مسودة البوليصة وتصفير المعرفات واعتمادات الأطراف بنجاح';
  @override String get draftBlClonedResetNotice => 'تنبيه: تم تصفير رقم البوليصة، فك الارتباط بمعرف الجلسة السابقة، وتعيين الاعتمادات المزدوجة إلى قيد الانتظار.';
  @override String get cloneDraftBlRecordTooltip => 'استنساخ هذه المسودة';

  // ── Screen 19: Draft COO / EUR.1 Review ──────────────────────────────────
  @override String get cooStage1Requirements => '1. متطلبات شهادة المنشأ و EUR.1';
  @override String get cooStage2DraftInput => '2. إدخال واستخراج الدرافت';
  @override String get cooStage3DiscrepancyMatrix => '3. مصفوفة المقارنة والفروق';
  @override String get cooStage4Registry => '4. سجل مراجعات المنشأ';
  @override String get cooDecisionEngineTitle => 'محرك اتخاذ القرار الجمركي لشهادات المنشأ';
  @override String get cooDecisionEngineSub => 'توجيه ذكي لنوع الشهادة تلقائياً بناءً على بلد المنشأ المذكور في الفواتير والاتفاقيات الدولية';
  @override String get cooRecheckAgreementButton => 'إعادة فحص الاتفاقية';
  @override String cooInvoiceOriginBadge(String origin) => '🌍 بلد المنشأ بالفاتورة: $origin';
  @override String get cooManualChoiceRequiredBadge => '⚠️ مطلوب اختيار يدوي (اتفاقيات متعددة)';
  @override String cooApprovedCertBadge(String cert) => '✔ الشهادة المعتمدة: $cert';
  @override String cooExistingReviewBanner(String code, String status) => 'ℹ️ توجد دراسة مسجلة مسبقاً لهذا الملف [كود الجلسة: $code - الحالة: $status]. سيتم تحديث وتعديل نفس الدراسة المعتمدة لضمان عدم تكرار السجلات.';
  @override String get cooReviewRegistryButton => 'سجل المراجعات';
  @override String get cooGenerateDraftHeader => 'توليد واستدعاء مسودة شهادة المنشأ الرسمية';
  @override String get cooSelectImportFileLabel => 'اختر ملف الشحنة *';
  @override String get cooSearchFileHint => 'ابحث برقم الملف...';
  @override String get cooCertTypeLabel => 'نوع شهادة المنشأ *';
  @override String get cooSelectCertTypeHint => 'اختر نوع الشهادة...';
  @override String get cooCertTypeEur1 => 'EUR.1 (الاتفاقية المصرية الأوروبية - قواعد معدلة)';
  @override String get cooCertTypeChina => 'شهادة منشأ الصين (CCPIT - اتفاقية الصين ومصر)';
  @override String get cooCertTypeStandard => 'شهادة منشأ عادية (Standard COO)';
  @override String get cooCertTypeFormA => 'نموذج أ - نظام الأفضليات المعمم (GSP)';
  @override String get cooCertTypeAgadir => 'شهادة اتفاقية أغادير';
  @override String get cooCertTypeGafta => 'شهادة منطقة التجارة الحرة العربية الكبرى (GAFTA)';
  @override String get cooOpenVisualPreviewButton => '⚡ فتح المعاينة المصورة والتصدير';
  @override String get cooNextDraftInputButton => 'التالي: إدخال الدرافت';
  @override String get cooOfficialDraftPreviewTitle => 'معاينة المسودة الرسمية لشهادة المنشأ';
  @override String get cooAutoFillFieldsButton => 'اعتماد وتعبئة الحقول تلقائياً';
  @override String get cooDraftFilledSuccess => '✔ تم ملء بيانات المسودة الرسمية بنجاح';
  @override String cooGenerateDraftError(String e) => 'خطأ أثناء توليد المسودة: $e';
  @override String get cooDraftInputTitle => 'إدخال واستخراج بيانات درافت شهادة المنشأ';
  @override String get cooRunComparisonButton => 'تشغيل المقارنة';
  @override String get cooLinkedImportFileLabel => 'اختر ملف الشحنة المربوط *';
  @override String get cooSelectFileWarning => '⚠️ يرجى اختيار وتحديد ملف الشحنة أولاً حتى يتم استخراج البيانات ومقارنتها بسجلات النظام.';
  @override String get cooDraftCertNumberLabel => 'رقم درافت الشهادة *';
  @override String get cooOriginCountryLabel => 'بلد المنشأ *';
  @override String get cooDestinationCountryLabel => 'بلد المقصد *';
  @override String get cooExporterNameLabel => 'اسم المصدر أو الشاحن *';
  @override String get cooExporterRegIdLabel => 'كود المصدر الأجنبي أو السجل الضريبي';
  @override String get cooImporterNameLabel => 'اسم المستورد أو المرسل إليه *';
  @override String get cooInvoiceNumberLabel => 'رقم الفاتورة المذكورة *';
  @override String get cooSmartUploadButtonLabel => 'رفع واستخراج شهادة المنشأ الذكي (PDF, Word, Excel)';
  @override String get cooRawTextSectionTitle => 'النص الخام لدرافت شهادة المنشأ (OCR):';
  @override String get cooSmartExtractFromTextButton => '⚡ استخراج وتعبئة ذكية من النص';
  @override String get cooRawTextHint => 'الصق النص الكامل للشهادة هنا (مثل نصوص CCPIT أو EUR.1)...';
  @override String get cooPasteTextOrUploadWarning => 'يرجى لصق نص الشهادة أو رفع الملف أولاً';
  @override String get cooAiExtractSuccess => '✔ تم استخراج ومطابقة بيانات الشهادة بالذكاء الاصطناعي بنجاح';
  @override String cooExtractError(String e) => 'خطأ أثناء الاستخراج: $e';
  @override String get cooSelectFileFirstForComparison => 'يرجى اختيار ملف الشحنة أولاً';
  @override String cooComparisonError(String e) => 'خطأ أثناء المقارنة: $e';
  @override String get cooSelectFileToViewMatrix => '⚠️ يجب اختيار ملف الشحنة أولاً لعرض مصفوفة المقارنة';
  @override String get cooBackToSelectFile => 'العودة لاختيار الملف';
  @override String get cooRunComparisonPreviousStep => 'يرجى تشغيل المقارنة في الخطوة السابقة لاستعراض مصفوفة الفروق';
  @override String get cooBackToRunComparison => 'العودة لتشغيل المقارنة';
  @override String get cooCriticalMismatchAlert => '🚨 توجد اختلافات حرجة في بيانات شهادة المنشأ';
  @override String get cooMinorDiscrepancyAlert => '⚠️ توجد فروق طفيفة في الشهادة';
  @override String get cooPerfectMatchSuccess => '✔ شهادة المنشأ مطابقة 100%';
  @override String get cooExportPdfButton => 'تصدير PDF';
  @override String get cooExportExcelButton => 'تصدير Excel';
  @override String get cooSaveToRegistryButton => 'حفظ بالسجل';
  @override String get cooExportingPdfReportSnackbar => 'جارٍ تصدير تقرير مطابقة شهادة المنشأ...';
  @override String get cooExcelCopiedSnackbar => '📊 تم نسخ وتصدير بيانات المطابقة إلى Excel بنجاح';
  @override String get cooMatrixColField => 'الحقل';
  @override String get cooMatrixColSystemValue => 'القيمة بالنظام';
  @override String get cooMatrixColDraftValue => 'القيمة بالدرافت';
  @override String get cooMatrixColStatus => 'حالة التطابق';
  @override String get cooMatrixColDetails => 'التفاصيل';
  @override String get cooOverrideReasonTitle => 'سبب ومبررات الموافقة على الاختلافات (إلزامي للاعتماد والحفظ):';
  @override String get cooOverrideReasonSub => 'عند وجود فروق أو اختلافات في شهادة المنشأ، يجب تسجيل سبب الموافقة والاعتماد (مثال: ملحق تفويضي من المصدر أو الاسم التجاري موثق بالسجل)، أو الضغط على العودة للتعديل ومخاطبة المورد.';
  @override String get cooOverrideReasonLabel => 'سبب ومبرر الموافقة على الاختلافات *';
  @override String get cooOverrideReasonHint => 'اكتب مبررات قبول الاختلافات هنا قبل الحفظ...';
  @override String get cooSaveWithJustificationButton => '✔ اعتماد وحفظ مع ذكر سبب الموافقة';
  @override String get cooReturnToEditAndNotifySupplierButton => '↩ العودة لتعديل المسودة ومخاطبة المورد';
  @override String get cooMustProvideJustificationSnackbar => '⚠️ يجب كتابة سبب ومبرر الموافقة على الاختلافات قبل الاعتماد والحفظ، أو الضغط على [العودة للتعديل ومخاطبة المورد].';
  @override String get cooSessionSavedSuccess => '✔ تم حفظ جلسة مراجعة شهادة المنشأ بنجاح بالسجل';
  @override String cooSaveError(String e) => 'خطأ في الحفظ: $e';
  @override String get cooRegistryTitle => 'سجل مراجعات شهادات المنشأ واليورو 1';
  @override String get cooReviewNewDraftButton => 'مراجعة درافت جديد';
  @override String get cooNoReviewsYet => 'لا توجد مراجعات مسجلة';
  @override String get cooRegistryColCode => 'كود الجلسة';
  @override String get cooRegistryColType => 'النوع';
  @override String get cooRegistryColNumber => 'رقم الشهادة';
  @override String get cooRegistryColExporter => 'المصدر';
  @override String get cooRegistryColStatus => 'الحالة';
  @override String get cooRegistryColDate => 'تاريخ الإنشاء';
  @override String get cooRegistryColActions => 'الإجراءات';
  @override String get cooEditSessionTooltip => 'تعديل الجلسة';
  @override String get cooViewDetailsTooltip => 'معاينة التفاصيل';
  @override String get cooDownloadPdfTooltip => 'تنزيل PDF';
  @override String get cooDeleteSessionTooltip => 'حذف الجلسة';
  @override String cooLoadedSessionForEditSnackbar(String code) => 'تم تحميل بيانات الجلسة ($code) للتعديل';
  @override String cooDetailsDialogTitle(String code) => 'تفاصيل جلسة مراجعة شهادة المنشأ: $code';
  @override String get cooDetailsCertTypeAndNumber => 'نوع الشهادة ورقمها';
  @override String get cooDetailsExporterAndImporter => 'المصدر والمستورد';
  @override String get cooDetailsOriginAndDestination => 'بلد المنشأ والمقصد';
  @override String get cooDetailsOverrideReason => 'سبب ومبرر الموافقة على الاختلافات';
  @override String get cooDetailsMatrixTitle => 'مصفوفة الفروق والمطابقة:';
  @override String get cooDeleteDialogTitle => 'تأكيد حذف جلسة مراجعة المنشأ';
  @override String cooDeleteDialogContent(String code, String cert) => 'هل أنت متأكد من حذف جلسة المراجعة رقم ($code) لشهادة ($cert)؟';
  @override String get cooDeleteSuccessSnackbar => '✔ تم حذف جلسة المراجعة بنجاح';
  @override String cooDeleteErrorSnackbar(String e) => 'خطأ في الحذف: $e';
  @override String cooVisualPreviewTitle(String type) => 'معاينة مسودة شهادة المنشأ الرسمية: $type';
  @override String get cooVisualRefreshTooltip => 'تحديث حي للبيانات المستدعاة';
  @override String get cooVisualCopyButton => 'نسخ البيانات 📋';
  @override String get cooVisualCopiedSnackbar => '📋 تم نسخ بيانات شهادة المنشأ إلى الحافظة';
  @override String get cooVisualExcelButton => 'حفظ كملف إكسل 📊';
  @override String get cooVisualExcelReadySnackbar => '📊 تم توليد وتجهيز بيانات الإكسل لشهادة المنشأ بنجاح';
  @override String get cooVisualPrintPdfButton => 'حفظ وطباعة PDF 🖨️';
  @override String get cooCustomsClearanceNote => 'ملاحظة جمركية: في مرحلة التخليص الجمركي بمصر، يُشترط أن يحتوي البند 11 على ختم وتوقيع المصدر، وأن يحتوي البند 12 على الختم الرسمي للجهة المعتمدة (ختم الجمارك وختم الغرفة التجارية) أو رمز التحقق الإلكتروني (QR Code أو Barcode) في حال الشهادات الإلكترونية.';
  @override String cooExcelSavedSuccess(String path) => '✅ تم حفظ ملف الإكسل بنجاح في: $path';
  @override String get cooDetailsExporterLabel => 'المصدر';
  @override String get cooDetailsImporterLabel => 'المستورد';
  @override String get searchAndCloneCooBtn => 'بحث واستنساخ مسودة شهادة منشأ';
  @override String get searchAndCloneCooDialogTitle => 'بحث واستنساخ مسودة شهادة المنشأ و EUR.1';
  @override String get searchCooHint => 'ابحث برقم الشهادة، المصدر، المستورد، أو النوع...';
  @override String get noCooReviewsFound => 'لا توجد مراجعات لشهادات المنشأ مطابقة للبحث';
  @override String get cloneCooSuccess => 'تم استنساخ مسودة شهادة المنشأ وتوليد درافت جديد بنجاح';
  @override String get cooClonedResetNotice => 'تم استنساخ شهادة المنشأ مع تصفير رقم الشهادة وتحديث لقطة النظام';
  @override String get cloneCooRecordTooltip => 'استنساخ مسودة شهادة المنشأ';
  @override String get cooRegistrySearchHint => 'بحث في سجل شهادات المنشأ...';

  // ── Screen 20: Customs Docs Approval (CustomsDocumentApprovalTab) ─────────
  @override String get customsApprovalSelectFileForMatrixWarning => '⚠️ برجاء اختيار ملف الشحنة أولاً لإجراء الفحص المتقاطع.';
  @override String customsApprovalMatrixCheckCompleted(String compliance) => '✅ تم الانتهاء من الفحص المتقاطع الآلي: $compliance';
  @override String customsApprovalMatrixCheckFailed(String error) => '❌ فشل إجراء الفحص: $error';
  @override String get customsApprovalSelectFileWarning => '⚠️ برجاء اختيار ملف الشحنة أولاً.';
  @override String get customsApprovalStandardListGeneratedSuccess => '✅ تم توليد قائمة مستندات الاعتماد القياسية بنجاح.';
  @override String customsApprovalGenerateFailed(String error) => '❌ خطأ أثناء التوليد: $error';
  @override String get customsApprovalSelectFileForTicketWarning => '⚠️ برجاء اختيار ملف الشحنة لربط التذكرة.';
  @override String get customsApprovalImportFileLabel => 'ملف الشحنة المستوردة';
  @override String get customsApprovalSearchFileHint => 'ابحث برقم الملف أو اسم الشركة...';
  @override String get customsApprovalRunAiMatrixButton => 'فحص متقاطع ذكي';
  @override String get customsApprovalAutoGenerateStandardListButton => 'توليد القائمة القياسية';
  @override String get customsApprovalRaiseTicketButton => 'تذكرة استدراك للمورد';
  @override String get customsApprovalFilterAll => 'الكل';
  @override String get customsApprovalFilterPending => 'قيد المراجعة';
  @override String get customsApprovalFilterApproved => 'معتمد';
  @override String get customsApprovalFilterRejected => 'مرفوض';
  @override String get customsApprovalFilterDiscrepancy => 'يوجد فروق';
  @override String get customsApprovalTabDualSignoff => 'مصفوفة الاعتماد الثنائي والفحص المتقاطع';
  @override String get customsApprovalTabCentralArchive => 'الأرشيف المركزي وملخص إخطارات التعديل';
  @override String customsApprovalMatrixComplianceResult(String compliance, int passed, int total) => 'نتيجة المطابقة المتقاطعة: $compliance ($passed من $total مطابق)';
  @override String customsApprovalMatrixRecommendations(String recs) => 'توصيات الجمارك: $recs';
  @override String customsApprovalMatrixOpenTicketsCount(int count) => 'تذاكر مفتوحة: $count';
  @override String get customsApprovalDualTierHeader => 'مصفوفة اعتماد المستندات الجمركية';
  @override String get customsApprovalNoDocuments => 'لا توجد مستندات مسجلة. اضغط "توليد القائمة القياسية" للبدء.';
  @override String customsApprovalError(String error) => 'خطأ: $error';
  @override String customsApprovalDocRef(String ref) => 'رقم: $ref';
  @override String customsApprovalCommercialReviewStatus(String status) => 'المراجعة التجارية: $status';
  @override String customsApprovalBrokerReviewStatus(String status) => 'اعتماد المخلص الجمركي: $status';
  @override String get customsApprovalTicketsHeader => 'سجل تذاكر الاستدراك والاستفسارات';
  @override String get customsApprovalNewTicketButton => 'تذكرة جديدة';
  @override String get customsApprovalNoTickets => 'لا توجد تذاكر استدراك مفتوحة. كافة المستندات متطابقة.';
  @override String customsApprovalTicketExpectedVsFound(String expected, String found) => 'المتوقع: $expected ➔ الوارد بالمسودة: $found';
  @override String get customsApprovalResolveTicketButton => 'تسجيل رد المورد وإغلاق التذكرة';
  @override String customsApprovalCommercialDialogTitle(String docType) => 'المراجعة التجارية: $docType';
  @override String get customsApprovalCommercialReviewerLabel => 'اسم المراجع التجاري *';
  @override String get customsApprovalRequiredField => 'الحقل إلزامي';
  @override String get customsApprovalCommercialDecisionLabel => 'قرار المراجعة *';
  @override String get customsApprovalSelectDecisionHint => 'اختر القرار...';
  @override String get customsApprovalDecisionCommercialApproved => 'معتمد تجارياً';
  @override String get customsApprovalDecisionCommercialUnderReview => 'قيد المراجعة';
  @override String get customsApprovalDecisionCommercialRejected => 'مرفوض لوجود أخطاء';
  @override String get customsApprovalCommercialNotesLabel => 'ملاحظات المراجعة التجارية';
  @override String get customsApprovalSaveApprovalButton => 'حفظ الاعتماد';
  @override String customsApprovalBrokerDialogTitle(String docType) => 'اعتماد المخلص الجمركي: $docType';
  @override String get customsApprovalBrokerOfficeLabel => 'مكتب التخليص الجمركي *';
  @override String get customsApprovalBrokerReviewerNameLabel => 'اسم المخلص الجمركي المعتمد *';
  @override String get customsApprovalBrokerDecisionLabel => 'قرار المطابقة الجمركية *';
  @override String get customsApprovalDecisionBrokerApproved => 'معتمد للإفراج الجمركي';
  @override String get customsApprovalDecisionBrokerConditionallyApproved => 'معتمد بشرط';
  @override String get customsApprovalDecisionBrokerRejected => 'مرفوض جمركياً';
  @override String get customsApprovalBrokerNotesLabel => 'ملاحظات وتعهدات التخليص';
  @override String get customsApprovalBrokerSaveStampButton => 'اعتماد رسمي وختم';
  @override String get customsApprovalRaiseTicketDialogTitle => 'إصدار تذكرة استدراك للمورد';
  @override String get customsApprovalIssueCategoryLabel => 'تصنيف عدم المطابقة *';
  @override String get customsApprovalSelectCategoryHint => 'اختر التصنيف...';
  @override String get customsApprovalCatHsMismatch => 'عدم تطابق بند التعريفة الجمركية';
  @override String get customsApprovalCatWeightDiscrepancy => 'اختلاف في الأوزان';
  @override String get customsApprovalCatCbmDiscrepancy => 'اختلاف الحجم التكعيبي';
  @override String get customsApprovalCatValueMismatch => 'اختلاف القيمة أو العملة';
  @override String get customsApprovalCatMissingAcid => 'غياب الرقم التعريفي المبدئي للشحنة';
  @override String get customsApprovalCatIncotermConflict => 'تعارض شرط الشحن الدولي';
  @override String get customsApprovalCatOther => 'أخرى';
  @override String get customsApprovalSeverityLabel => 'درجة الخطورة *';
  @override String get customsApprovalSelectSeverityHint => 'اختر درجة الخطورة...';
  @override String get customsApprovalSevCritical => 'حرج يمنع الشحن والإفراج';
  @override String get customsApprovalSevMajor => 'رئيسي يتطلب تعديل المسودة';
  @override String get customsApprovalSevMinor => 'بسيط للتنبيه';
  @override String get customsApprovalIssueDescLabel => 'وصف الخطأ والتناقض بالتفصيل *';
  @override String get customsApprovalIssueDescMinLength => 'الوصف يجب أن يكون 5 أحرف على الأقل';
  @override String get customsApprovalExpectedValueLabel => 'القيمة الصحيحة المطلوبة';
  @override String get customsApprovalFoundValueLabel => 'القيمة الخاطئة بالمسودة';
  @override String get customsApprovalSupplierActionLabel => 'الإجراء المطلوب من المورد تنفيذه';
  @override String get customsApprovalCreateTicketSubmitButton => 'إصدار التذكرة';
  @override String customsApprovalResolveTicketDialogTitle(String ticketCode) => 'إغلاق تذكرة الاستدراك: $ticketCode';
  @override String get customsApprovalSupplierResponseLabel => 'رد المورد وتعديل المسودة *';
  @override String get customsApprovalResolverNameLabel => 'اسم المراجع القائم بالإغلاق *';
  @override String get customsApprovalFinalStatusLabel => 'الحالة النهائية *';
  @override String get customsApprovalSelectStatusHint => 'اختر الحالة...';
  @override String get customsApprovalStatusResolved => 'تم تصحيح المسودة';
  @override String get customsApprovalStatusWaived => 'تم التنازل مع تعهد';
  @override String get customsApprovalStatusClosed => 'مغلقة';
  @override String get customsApprovalConfirmResolveTicketButton => 'تأكيد الإغلاق';

  // Screen 20 Additional: Document Types & Status Resolvers
  @override String get customsApprovalDocCommercialInvoice => 'الفاتورة التجارية';
  @override String get customsApprovalDocPackingList => 'بيان التعبئة والتغليف';
  @override String get customsApprovalDocBillOfLading => 'بوليصة الشحن';
  @override String get customsApprovalDocCertificateOfOrigin => 'شهادة المنشأ';
  @override String get customsApprovalDocEur1 => 'شهادة الحركة يورو 1';
  @override String get customsApprovalDocInspectionCertificate => 'شهادة الفحص والتفتيش';
  @override String get customsApprovalDocBankForm4 => 'نموذج 4 البنكي';
  @override String get customsApprovalDocProformaInvoice => 'الفاتورة المبدئية';

  @override String get customsApprovalStatusApprovedForClearance => 'معتمد للإفراج الجمركي';
  @override String get customsApprovalStatusRectificationRequired => 'مطلوب استدراك وتعديل';
  @override String get customsApprovalStatusConditionallyApproved => 'معتمد بشرط';
  @override String get customsApprovalStatusUnderReview => 'قيد المراجعة';
  @override String get customsApprovalStatusPendingReview => 'بانتظار المراجعة';
  @override String get customsApprovalStatusDraft => 'مسودة';
  @override String get customsApprovalStatusRejected => 'مرفوض';
  @override String get customsApprovalStatusApproved => 'معتمد';
  @override String get customsApprovalStatusPending => 'قيد الانتظار';

  @override String get customsApprovalComplianceFullyCompliant => 'مطابق بالكامل';
  @override String get customsApprovalComplianceNonCompliant => 'غير مطابق';
  @override String get customsApprovalComplianceDiscrepancies => 'توجد فروق وتناقضات';
  @override String get customsApprovalComplianceCriticalBlocker => 'مانع حرج للشحن';

  @override String get customsApprovalSevCriticalBadge => 'حرج';
  @override String get customsApprovalSevMajorBadge => 'رئيسي';
  @override String get customsApprovalSevMinorBadge => 'بسيط';

  @override String get customsApprovalTicketStatusOpen => 'مفتوحة';

  @override String get customsApprovalDefaultCommercialReviewer => 'المراجع التجاري المختص';
  @override String get customsApprovalDefaultBrokerOffice => 'مكتب التخليص الجمركي المعتمد';
  @override String get customsApprovalDefaultLegalOfficer => 'المراجع القانوني';
  @override String get customsApprovalDefaultComplianceOfficer => 'مسؤول المطابقة';

  // Screen 20: Search & Clone Customs Document Approvals
  @override String get searchAndCloneCustomsApprovalBtn => 'بحث واستنساخ اعتماد مستندات سابق';
  @override String get searchAndCloneCustomsApprovalDialogTitle => 'البحث واستنساخ اعتماد مستندات وتعديلات المورد';
  @override String get searchCustomsApprovalHint => 'ابحث بكود الملف، نوع المستند، اسم الشركة، أو حالة الاعتماد...';
  @override String get noCustomsApprovalsFound => 'لم يتم العثور على اعتمادات مستندات مطابقة';
  @override String get cloneCustomsApprovalSuccess => 'تم استنساخ قائمة المستندات وتصفير حالات الاعتماد بنجاح';
  @override String get customsApprovalClonedResetNotice => 'تنبيه: تم تصفير كافة الاعتمادات التجارية والجمركية إلى قيد الانتظار وتفريغ الملاحظات السابقة.';
  @override String get cloneApprovalRecordTooltip => 'استنساخ متطلبات هذا المستند';
  @override String get cloneTicketRecordTooltip => 'استنساخ هذه التذكرة';

  // ── Screen 21: PO & Packing Reconciliation ───────────────────────────────
  @override String get poRecSampleLoadedSuccess => 'تم تحميل النموذج التجريبي بنجاح';
  @override String poRecFileSelected(String name, String sizeKb) => 'تم اختيار الملف: $name ($sizeKb ك.ب)';
  @override String poRecFilePickFailed(String error) => 'فشل في اختيار الملف: $error';
  @override String poRecExtractedDigitalFileNotice(String filename) => '[تم تحميل ملف رقمي: $filename — سيتم استخراج ومعالجة بنوده آلياً عند الضغط على زر الاستخراج والمطابقة]';
  @override String get poRecInputValidationTitle => 'تنبيه: تحقق من مدخلات الاستخراج والمطابقة';
  @override String get poRecInputValidationDesc => 'تم رصد الملاحظات التالية في المدخلات التي تمنع إتمام الاستخراج والمطابقة بدقة:';
  @override String get poRecInputValidationRecHeader => 'إرشادات تصحيح المدخلات والحل المقترح:';
  @override String get poRecInputValidationGotIt => 'فهمت، سأقوم بالتصحيح';
  @override String get poRecIssueNoFileSelected => 'لم يتم اختيار الملف الاستيرادي المرجعي.';
  @override String get poRecRecSelectFileFromList => 'يرجى تحديد الملف الاستيرادي من القائمة المنسدلة في أعلى الشاشة.';
  @override String get poRecIssueEmptyInputs => 'لم يتم إدخال أو رفع أي مستند (الفاتورة التجارية أو قائمة التعبئة فارغتان تماماً).';
  @override String get poRecRecProvideInputs => 'قم برفع ملف المستندات أو لصق النص التجاري أو الضغط على "تحميل نموذج تجريبي".';
  @override String get poRecServerSuccessNotice => 'تم الاستخراج الذكي والمطابقة بنجاح من السيرفر! راجع النتائج بالأسفل';
  @override String get poRecFallbackSuccessNotice => 'تم إجراء التحليل والمطابقة محلياً بنجاح عبر محرك الطوارئ المدمج';
  @override String get poRecApplyExtractedSuccess => 'تم تطبيق البيانات المستخرجة في جداول الفاتورة والباكينج ليست بنجاح!';
  @override String get poRecSaveSessionSelectFileWarning => 'يرجى اختيار ملف الشحنة أولاً لحفظ الجلسة';
  @override String get poRecExistingSessionWarningTitle => 'تنبيه: ملف الشحنة له جلسة سابقة';
  @override String poRecExistingSessionWarningContent(String sessionCode) => 'يوجد بالفعل جلسة مطابقة محفوظة لهذا الملف الاستيرادي (رمز الجلسة: $sessionCode).\n\nوفقاً لضوابط المنظومة، لا يُسمح بإنشاء أكثر من جلسة حفظ لنفس الملف الاستيرادي لمنع تكرار وتضارب البيانات.\n\nهل ترغب في تحديث الجلسة الحالية بالبيانات الجديدة؟';
  @override String get poRecUpdateExistingSessionButton => 'تحديث الجلسة الحالية';
  @override String poRecSaveSessionError(String error) => 'خطأ أثناء حفظ الجلسة: $error';
  @override String get poRecVarianceAlertTitle => 'تنبيه: وجود فروق في المطابقة';
  @override String get poRecVarianceAlertContent => 'تم رصد فروق بين أمر الشراء الأصلي والفاتورة والباكينج ليست النهائية:\n• سيتم اعتماد القيم والكميات النهائية كمرجع رسمي.\n• سيتم تحديث رصيد البضاعة في الطريق (GIT) بالكميات المعتمدة.\nهل ترغب في المتابعة وتأكيد الاعتماد؟';
  @override String get poRecCancelAndReview => 'إلغاء والمراجعة';
  @override String get poRecConfirmCertifyButton => 'تأكيد الاعتماد والمطابقة';
  @override String get poRecCertificationSuccess => 'تم اعتماد مطابقة المستندات وتحديث ملف الاستيراد وسجل الجلسات بنجاح!';
  @override String poRecCertificationError(String error) => 'خطأ أثناء اعتماد المطابقة: $error';
  @override String poRecSessionLoadedInEditor(String sessionCode) => 'تم تحميل جلسة المطابقة ($sessionCode) في شاشة التعديل والمطابقة!';

  @override String poRecEditSessionTitle(String code) => 'تعديل جلسة المطابقة: $code';
  @override String get poRecNewSessionTitle => 'مراجعة وتأكيد الفاتورة التجارية والباكينج ليست النهائية';
  @override String poRecOpenSessionBadge(String code) => 'جلسة مفتوحة: $code';
  @override String get poRecHeaderDescription => 'البيانات والكميات والأسعار والأوزان المعتمدة هنا هي المرجع الحاكم لدرافت البوليصة، والمخزون بالطريق، والإفراج الجمركي، واستلام المخزن.';
  @override String get poRecSearchFileHint => 'ابحث عن ملف الشحنة برقم الملف أو الكود...';
  @override String get poRecImportFileLabel => 'ملف الشحنة المرجعي *';
  @override String get poRecSelectFileRequired => 'يرجى اختيار ملف الشحنة';
  @override String get poRecFinalInvoiceNoLabel => 'رقم الفاتورة التجارية النهائية *';
  @override String get poRecFinalInvoiceNoHint => 'مثال: V1-2562';
  @override String get poRecFinalPackingListNoLabel => 'رقم قائمة التعبئة النهائية (اختياري)';
  @override String get poRecFinalPackingListNoHint => 'مثال: PL-2562';
  @override String get poRecRequired => 'مطلوب';
  @override String get poRecTotalSummaryRow => 'الإجمالي الكلي';

  @override String get poRecKpiTotalInvoice => 'إجمالي الفاتورة النهائية';
  @override String get poRecKpiTotalPackages => 'إجمالي الطرود الفعلية';
  @override String get poRecKpiTotalGrossWeight => 'إجمالي الوزن القائم';
  @override String get poRecKpiTotalNetWeight => 'إجمالي الوزن الصافي';
  @override String get poRecKpiTotalCbm => 'إجمالي الحجم بالمتر المكعب';
  @override String get poRecPackagesUnit => 'طرد';
  @override String get poRecKgUnit => 'كجم';
  @override String get poRecCbmUnit => 'م³';

  @override String get poRecInvoiceSectionTitle => '1. مراجعة وتأكيد بنود وأسعار الفاتورة التجارية النهائية';
  @override String get poRecResetToOriginalValuesButton => 'إعادة تعيين للقيم الأصلية';
  @override String get poRecUpdateSessionButton => 'تحديث جلسة المطابقة';
  @override String get poRecSaveSessionButton => 'حفظ جلسة المطابقة';
  @override String get poRecCertifyFinalDataButton => 'اعتماد ومطابقة البيانات النهائية';
  @override String get poRecSelectFileToViewPoItems => 'يرجى اختيار ملف الشحنة لعرض بنود أمر الشراء للمطابقة';
  @override String get poRecColItemCode => 'كود الصنف';
  @override String get poRecColDescription => 'الوصف';
  @override String get poRecColPoQty => 'كمية PO';
  @override String get poRecColFinalQty => 'الكمية النهائية *';
  @override String get poRecColQtyVariance => 'فارق الكمية';
  @override String get poRecColPoUnitPrice => 'سعر وحدة PO';
  @override String get poRecColFinalUnitPrice => 'سعر الوحدة النهائي *';
  @override String get poRecColPriceVariance => 'فارق السعر';
  @override String get poRecColFinalTotal => 'الإجمالي النهائي';
  @override String get poRecColHsCode => 'بند التعريفة الجمركية';

  @override String get poRecPackingSectionTitle => '2. مراجعة وتأكيد قائمة التعبئة والأوزان والطرود والأحجام';
  @override String get poRecSelectFileToViewPackingItems => 'يرجى اختيار ملف الشحنة لعرض بنود قائمة التعبئة';
  @override String get poRecColPackageType => 'نوع الطرد';
  @override String get poRecColPoPackagesCount => 'عبوات أمر الشراء (PO PKG)';
  @override String get poRecColFinalPackagesCount => 'عدد الطرود النهائية *';
  @override String get poRecColPkgVariance => 'فارق العبوات';
  @override String get poRecColGrossWeight => 'الوزن القائم (كجم) *';
  @override String get poRecColNetWeight => 'الوزن الصافي (كجم) *';
  @override String get poRecColCbm => 'الحجم (م³) *';

  @override String get poRecExtractorTitle => 'أداة الرفع والاستخراج الذكي والمطابقة الثلاثية';
  @override String get poRecExtractorSubtitle => 'استخراج بنود الفاتورة النهائية وقائمة التعبئة ومطابقتها آلياً مع أمر الشراء بالسستم وكشف الفوارق';
  @override String get poRecLoadSampleDemoButton => 'تحميل نموذج تجريبي حقيقي (G.I. INDUSTRIAL)';
  @override String get poRecHideTool => 'إخفاء الأداة';
  @override String get poRecShowTool => 'عرض الأداة';
  @override String get poRecExtractorTabInvoice => '1. الفاتورة التجارية النهائية';
  @override String get poRecExtractorTabPacking => '2. قائمة التعبئة والأوزان';
  @override String get poRecChangeFile => 'تغيير الملف';
  @override String get poRecUploadFile => 'رفع ملف المستندات';
  @override String get poRecPasteInvoiceHint => 'ألصق نص الفاتورة التجارية هنا أو ارفع الملف الرقمي...';
  @override String get poRecPastePackingHint => 'ألصق نص قائمة التعبئة هنا أو ارفع الملف الرقمي...';
  @override String get poRecExtractingProgress => 'جاري الاستخراج والمطابقة الذكية...';
  @override String get poRecExecuteSmartExtractionButton => 'تنفيذ الاستخراج الذكي والمطابقة مع بيانات السستم';
  @override String get poRecStatusFullyMatchedTitle => 'مطابقة تامة بنسبة 100% — لا توجد أي فوارق أو تعارضات';
  @override String poRecStatusWarningsTitle(int count) => 'توجد فوارق أو تنبيهات غير حرجة ($count تنبيه) — يمكن المراجعة والاعتماد';
  @override String poRecStatusCriticalTitle(int count) => 'توجد فوارق حرجة ($count خطأ حرج) — يجب تدقيقها وتعديلها قبل الاعتماد!';
  @override String get poRecApplyExtractedToTablesButton => 'تطبيق البيانات المستخرجة في جداول المطابقة أدناه';
  @override String get poRecHeaderComplianceChecksTitle => 'فحص ومطابقة البيانات الحاكمة:';
  @override String get poRecColCheckItem => 'بند الفحص';
  @override String get poRecColSystemValue => 'القيمة بالسستم';
  @override String get poRecColExtractedValue => 'القيمة بالمستند المرفوع';
  @override String get poRecColMatchStatus => 'حالة المطابقة';
  @override String get poRecColDetails => 'التفاصيل';
  @override String get poRecMatchStatusMatched => 'مطابق';
  @override String get poRecMatchStatusWarning => 'تنبيه';
  @override String get poRecMatchStatusCritical => 'تعارض حرج';
  @override String get poRecExtractedDocMetadataTitle => 'البيانات المستخرجة من المستندات الرقمية:';
  @override String get poRecExtractedInvNo => 'رقم الفاتورة المستخرج';
  @override String get poRecExtractedInvAmount => 'إجمالي قيمة الفاتورة';
  @override String get poRecExtractedAcid => 'رقم ACID المستخرج';
  @override String get poRecExtractedPackagesWeight => 'إجمالي الطرود والوزن';

  @override String get poRecHistorySectionTitle => 'سجل جلسات المطابقة المحفوظة';
  @override String get poRecHistorySectionSubtitle => 'أرشيف جلسات مطابقة وتدقيق مستندات الشحن والفواتير وقوائم التعبئة';
  @override String poRecHistoryTotalSessionsBadge(int count) => '$count جلسة محفوظة';
  @override String get poRecHistoryKpiTotalSessions => 'إجمالي الجلسات المحفوظة';
  @override String get poRecHistoryKpiFullMatch => 'مطابقة بنسبة 100%';
  @override String get poRecHistoryKpiWithVariances => 'جلسات بها فوارق أو تنبيهات';
  @override String get poRecHistoryKpiTotalCertifiedValue => 'إجمالي القيمة المعتمدة';
  @override String get poRecHistoryNewSessionButton => 'جلسة مطابقة جديدة';
  @override String get poRecHistorySearchHint => 'بحث برمز الجلسة، رقم الملف، اسم الشركة، رقم الفاتورة، أو رقم ACID...';
  @override String poRecHistoryFilterAll(int count) => 'الكل ($count)';
  @override String get poRecHistoryFilterMatched => 'مطابق بالكامل';
  @override String get poRecHistoryFilterWarnings => 'فوارق مقبولة';
  @override String get poRecHistoryFilterCritical => 'فوارق حرجة';
  @override String get poRecHistoryRefreshTooltip => 'تحديث السجلات';
  @override String get poRecHistoryEmptyTitle => 'لا توجد جلسات مطابقة محفوظة حتى الآن.';
  @override String get poRecHistoryNoMatchFilter => 'لا توجد جلسات مطابقة مطابقة لمعايير البحث والفلترة.';
  @override String get poRecHistoryCreateFirstSessionButton => 'إنشاء أول جلسة مطابقة';
  @override String get poRecHistoryColIndex => '#';
  @override String get poRecHistoryColSessionCode => 'رمز الجلسة';
  @override String get poRecHistoryColImportFileImporter => 'ملف الشحنة والمستورد';
  @override String get poRecHistoryColInvoicePacking => 'الفاتورة والباكينج';
  @override String get poRecHistoryColTotalValue => 'إجمالي القيمة';
  @override String get poRecHistoryColPackagesWeight => 'الطرود والأوزان';
  @override String get poRecHistoryColCbm => 'الحجم بالمتر المكعب';
  @override String get poRecHistoryColStatus => 'حالة المطابقة';
  @override String get poRecHistoryColSavedDate => 'تاريخ الحفظ';
  @override String get poRecHistoryColActions => 'الإجراءات';
  @override String get poRecHistoryCopyCodeTooltip => 'نسخ رمز الجلسة';
  @override String get poRecHistoryCodeCopiedNotice => 'تم نسخ رمز الجلسة';
  @override String get poRecHistoryViewDetailsTooltip => 'عرض تفاصيل وتقرير الجلسة';
  @override String get poRecHistoryLoadIntoEditorTooltip => 'تحميل الجلسة في شاشة التعديل والمطابقة';
  @override String get poRecHistoryPrintTooltip => 'نسخ تقرير المطابقة للطباعة (Ctrl+P)';
  @override String get poRecHistoryDeleteTooltip => 'حذف الجلسة';
  @override String get poRecHistoryDeleteConfirmTitle => 'تأكيد حذف جلسة المطابقة';
  @override String poRecHistoryDeleteConfirmContent(String code, String file) => 'هل أنت متأكد من رغبتك في حذف جلسة المطابقة ($code) الخاصة بملف الشحنة ($file)؟';
  @override String get poRecHistoryDeletePermanent => 'حذف نهائياً';
  @override String poRecHistoryDeletedSuccess(String code) => 'تم حذف جلسة المطابقة ($code) بنجاح';
  @override String get poRecHistoryPrintCopiedSuccess => 'تم نسخ تقرير جلسة المطابقة للحافظة بنجاح! جاهز للطباعة والمشاركة';
  @override String poRecHistorySavedDialogTitle(String code) => 'تم حفظ جلسة المطابقة بنجاح ($code)';
  @override String get poRecHistorySavedUniqueNotice => 'تم تسجيل الجلسة كمرجع موثق وحصري لهذا الملف الاستيرادي لمنع أي تكرار.';
  @override String get poRecHistoryCopyReportButton => 'نسخ تقرير الجلسة للطباعة';
  @override String poRecHistoryDetailsModalTitle(String code) => 'تقرير جلسة المطابقة: $code';
  @override String get poRecHistoryDetailsCertifiedItemsTitle => 'بنود الفاتورة المعتمدة في الجلسة:';
  @override String get poRecHistoryDetailsCertifiedPackingTitle => 'بنود وقياسات قائمة التعبئة المعتمدة في الجلسة:';
  @override String get poRecHistoryLoadInEditorButton => 'تحميل في شاشة التعديل';
  @override String get poRecDiff => 'الفارق';
  @override String get poRecMissingInPacking => 'غير موجود بالباكينج';
  @override String get poRecMissingInInvoice => 'غير موجود بالفاتورة';
  @override String get poRecQtyDiff => 'فارق كمية';
  @override String get poRecOk => 'مطابق';
  @override String get poRecUnassignedHsCode => 'بدون بند جمركي';
  @override String get poRecInvoicePrefix => 'فاتورة:';
  @override String get poRecPackingPrefix => 'كشف تعبئة:';
  @override String get poRecGrossPrefix => 'الوزن القائم:';
  @override String get poRecCheckFieldInvoiceNumber => 'رقم الفاتورة التجارية النهائية';
  @override String get poRecCheckFieldAcidNumber => 'رقم القيد الجمركي المبدئي';
  @override String get poRecCheckFieldTotalAmount => 'إجمالي قيمة الفاتورة التجارية';
  @override String get poRecCheckFieldTotalPackages => 'إجمالي عدد الطرود';
  @override String get poRecCheckFieldGrossWeight => 'الوزن الإجمالي القائم';
  @override String get poRecCheckFieldSupplierName => 'اسم المورد الأجنبي';
  @override String get poRecCheckFieldImporterName => 'اسم الشركة المستوردة';
  @override String get poRecCheckFieldHsCode => 'البند الجمركي (HS Code)';
  @override String get poRecCheckFieldTaxId => 'البطاقة الضريبية للمستورد';
  @override String get poRecCheckMsgInvoiceMatched => 'تم استخراج وتطابق رقم الفاتورة التجارية بنجاح';
  @override String get poRecCheckMsgAcidMatched => 'رقم القيد الجمركي متطابق تماماً بين الفاتورة وكشف التعبئة والمنظومة';
  @override String get poRecCheckMsgTotalAmountMatched => 'إجمالي القيمة متطابق تماماً بنسبة مائة بالمائة';
  @override String get poRecCheckNotSpecified => 'غير محدد بالمنظومة';
  @override String get poRecReportTitle => 'نظام سرور للخدمات اللوجستية - تقرير المطابقة النهائية لأمر الشراء وكشف التعبئة';
  @override String get poRecReportSessionCode => 'كود الجلسة';
  @override String get poRecReportImportFile => 'ملف الشحنة';
  @override String get poRecReportImporter => 'المستورد';
  @override String get poRecReportShipper => 'المورد';
  @override String get poRecReportAcid => 'رقم القيد الجمركي';
  @override String get poRecReportInvoiceNo => 'الفاتورة التجارية النهائية';
  @override String get poRecReportPackingNo => 'كشف التعبئة النهائي';
  @override String get poRecReportTotalValue => 'إجمالي القيمة';
  @override String get poRecReportPackages => 'إجمالي الطرود';
  @override String get poRecReportGrossWeight => 'الوزن القائم';
  @override String get poRecReportNetWeight => 'الوزن الصافي';
  @override String get poRecReportTotalCbm => 'إجمالي الحجم بالمتر المكعب';
  @override String get poRecReportOverallStatus => 'الحالة الكلية';
  @override String get poRecReportCertifiedBy => 'تم الاعتماد بواسطة';
  @override String get poRecReportCsvHeader => 'كود الصنف,الوصف,بند التعريفة,الكمية,سعر الوحدة,إجمالي المبلغ,الطرود,الوزن القائم,الوزن الصافي,الحجم';
  @override String get poRecReportPreviewTitle => 'معاينة تقرير المطابقة النهائي';

  // Screen 21: Search & Clone PO Reconciliation Sessions
  @override String get searchAndClonePoReconBtn => 'استنساخ جلسة مطابقة سابقة';
  @override String get searchAndClonePoReconDialogTitle => 'بحث واستنساخ جلسة مطابقة الفاتورة وقائمة التعبئة';
  @override String get searchPoReconHint => 'ابحث برقم الجلسة، رقم الفاتورة، كود الشحنة، أو المستورد...';
  @override String get noPoReconFound => 'لم يتم العثور على جلسات مطابقة مطابقة لمعايير البحث';
  @override String get clonePoReconSuccess => 'تم استنساخ جلسة المطابقة بنجاح وفتحها في نافذة التعديل';
  @override String get poReconClonedResetNotice => 'تنبيه: تم إنشاء كود مسودة جديد وتفريغ بيانات الاعتماد والتوثيق لبدء جلسة مستقلة';
  @override String get clonePoReconRecordTooltip => 'استنساخ جلسة المطابقة هذه كمسودة جديدة';
  @override String get copyPoReconBtn => 'نسخ جدول المطابقة';
  @override String get exportPoReconExcelBtn => 'تصدير جدول المطابقة إلى Excel';
  @override String get exportPoReconPdfBtn => 'تصدير تقرير المطابقة إلى PDF';

  // ── Screen 23: Customs Declaration 46 ──────────────────────────────────────
  @override String get customsDeclStageTitle => 'الإقرار الجمركي المبدئي وشهادة 46 ك.م';
  @override String get customsDeclTabInitialForm => 'قيد الإقرار الجمركي المبدئي';
  @override String get customsDeclTabRegistry => 'سجل شهادات 46 ومتابعتها';
  @override String get customsDeclRefreshTooltip => 'تحديث البيانات';
  @override String get customsDeclInfoBanner => 'مسودة إقرار 46 ك.م الجاهزة للربط مع نافذة. يتم سحب رقم ACID المعتمد، ورقم نموذج 4 البنكي الموثق، وبيانات بوليصة الشحن تلقائياً لحساب الوعاء الضريبي والضرائب المقدرة طبقاً لجدول التعريفة الجمركية والاتفاقيات التفضيلية.';
  @override String get customsDeclSelectFileLabel => 'ملف الشحنة لقيد شهادة 46 *';
  @override String get customsDeclSearchFileHint => 'ابحث برقم الملف أو اسم المورد...';
  @override String get customsDeclAttributesHeader => 'بيانات الإقرار الجمركي وأرقام القيد المعتمدة:';
  @override String get customsDeclDeclarationNoLabel => 'رقم الإقرار والشهادة الجمركية (46 ك.م) *';
  @override String get customsDeclSubmissionDateLabel => 'تاريخ القيد المبدئي *';
  @override String get customsDeclAcidNumberLabel => 'رقم القيد الجمركي المبدئي المسبق';
  @override String get customsDeclForm4NumberLabel => 'رقم نموذج 4 البنكي المعتمد';
  @override String get customsDeclBlNumberLabel => 'رقم بوليصة الشحن';
  @override String get customsDeclDutiesHeader => 'الوعاء الضريبي والرسوم المقدرة (بالجنيه المصري):';
  @override String get customsDeclCifValueLabel => 'القيمة للأغراض الجمركية سيف (جنيه)';
  @override String get customsDeclImportDutyLabel => 'ضريبة الوارد المقدرة (جنيه)';
  @override String get customsDeclVatLabel => 'ضريبة القيمة المضافة (جنيه)';
  @override String get customsDeclTotalDutiesLabel => 'إجمالي الضرائب والرسوم المقدرة';
  @override String get customsDeclExemptionHeader => 'الموقف الجمركي وتطبيق الإعفاءات التفضيلية:';
  @override String get customsDeclExemptionConditionsHeader => '📌 الشروط والضوابط الإلزامية للاستفادة من الإعفاء الجمركي:';
  @override String get customsDeclEur1ExemptionTitle => 'اتفاقية الشراكة المصرية الأوروبية — إعفاء جمركي 0% لضريبة الوارد';
  @override String get customsDeclEur1Condition1 => 'تقديم شهادة المنشأ الأوروبية الرسمية المعتمدة ومستوفاة للأختام الرسمية.';
  @override String get customsDeclEur1Condition2 => 'إثبات الشحن والنقل المباشر من دولة المنشأ بالاتحاد الأوروبي إلى الموانئ المصرية.';
  @override String get customsDeclEur1Condition3 => 'إدراج رقم القيد المسبق وقيد المصنع المعتمد بالفاتورة التجارية وبوليصة الشحن.';
  @override String customsDeclMfnExemptionTitle(String rate) => 'خاضع للتعريفة الجمركية العامة — ضريبة الوارد $rate%';
  @override String get customsDeclMfnCondition1 => 'تقديم شهادة المنشأ الرسمية الموثقة من الغرفة التجارية لدولة المصدر.';
  @override String get customsDeclMfnCondition2 => 'سداد الرسوم والضرائب الجمركية المقررة عبر إذن سداد منظومة نافذة.';
  @override String get customsDeclRegulatoryHeader => 'العروض والموافقات المطلوبة والاشتراطات الرقابية:';
  @override String get customsDeclColHsCode => 'بند التعريفة الجمركية';
  @override String get customsDeclColAuthority => 'جهة العرض الرقابي';
  @override String get customsDeclColInspection => 'فحص مسبق';
  @override String get customsDeclColCoo => 'شهادة المنشأ';
  @override String get customsDeclColRequirements => 'الاشتراطات والملاحظات الرقابية';
  @override String get customsDeclColApprovalStatus => 'حالة الموافقة';
  @override String get customsDeclStatusFulfilled => 'مستوفى ومعتمد';
  @override String get customsDeclDefaultAuthority => 'الهيئة العامة للرقابة على الصادرات والواردات';
  @override String get customsDeclDefaultNote => 'مطلوب العرض الفني وسحب عينات مطابقة للمواصفات القياسية المصرية';
  @override String get customsDeclDefaultItemDesc => 'بند البضائع والمنتجات المستوردة';
  @override String get customsDeclVisualInspectionNote => 'فحص ظاهري ومطابقة مستندية قبل الإفراج الجمركي';
  @override String get customsDeclSaveButton => 'حفظ وقيد الإقرار الجمركي المبدئي';
  @override String get customsDeclSavingProgress => 'جارٍ الحفظ...';
  @override String get customsDeclSelectFileWarning => 'يرجى اختيار ملف الشحنة أولاً';
  @override String get customsDeclSaveSuccess => 'تم قيد وحفظ مسودة الإقرار الجمركي (46 ك.م) بنجاح';
  @override String get customsDeclRegistrySearchHint => 'بحث في سجل الإقرارات الجمركية وشهادات 46...';
  @override String get customsDeclRegisterNewButton => 'قيد إقرار جديد';
  @override String get customsDeclColDeclarationNo => 'رقم الإقرار (46 ك.م)';
  @override String get customsDeclColFileNumber => 'رقم الملف';
  @override String get customsDeclColSupplier => 'المورد الأجنبي';
  @override String get customsDeclColRegistrationDate => 'تاريخ القيد';
  @override String get customsDeclColDeclarationStatus => 'حالة الإقرار';
  @override String get customsDeclStatusRegisteredNafeza => 'مقيد مبدئياً على نافذة';
  @override String get customsDeclRequiredField => 'هذا الحقل إلزامي';
  @override String get customsDeclCopyValueTooltip => 'نسخ القيمة إلى الحافظة';
  @override String get customsDeclPrintPreviewButton => 'معاينة ونسخ ملخص الإقرار';
  @override String get customsDeclPreviewTitle => 'وثيقة قيد الإقرار الجمركي المبدئي (46 ك.م)';
  @override String get customsDeclCopySummarySuccess => 'تم نسخ ملخص الإقرار الجمركي بنجاح';
  @override String get customsDeclExportTsvButton => 'نسخ كجدول بيانات';
  @override String get customsDeclExportSuccess => 'تم نسخ بيانات الإقرار بصيغة TSV متوافقة مع Excel';
  @override String get customsDeclExportRegistryTsv => 'تصدير السجل (TSV)';
  @override String get customsDeclCopyAllSuccess => 'تم نسخ كامل سجل شهادات 46 بصيغة TSV';
  @override String get customsDeclCloseDialog => 'إغلاق';
  @override String get customsDeclAssessmentTitle => 'التقييم الجمركي وبنود التعريفة — شهادة 46 ك.م';
  @override String get customsDeclViewAssessmentTooltip => 'معاينة التقييم الجمركي وبنود التعريفة';
  @override String get customsDeclAssessmentSubtitle => 'تفصيل وعاء القيمة الجمركية، نسب ضريبة الوارد، القيمة المضافة، والرسوم المقررة';
  @override String get customsDeclShipmentParticularsHeader => 'بيانات الشحنة والإقرار الجمركي';
  @override String get customsDeclValuationBreakdownHeader => 'تفصيل وعاء القيمة للأغراض الجمركية (سيف)';
  @override String get customsDeclFobForeignLabel => 'قيمة الفاتورة التجارية (فوب)';
  @override String get customsDeclFreightEgpLabel => 'نولون الشحن (جنيه)';
  @override String get customsDeclInsuranceEgpLabel => 'التأمين البحري المقدر (جنيه)';
  @override String get customsDeclCifTotalEgpLabel => 'إجمالي القيمة الجمركية (سيف - جنيه)';
  @override String get customsDeclTariffTaxesHeader => 'جدول الضرائب والرسوم الجمركية المقررة';
  @override String get customsDeclImportDutyRateLabel => 'ضريبة الوارد المقررة';
  @override String get customsDeclVatRateLabel => 'ضريبة القيمة المضافة';
  @override String get customsDeclDevFeeLabel => 'رسم التنمية المقترح';
  @override String get customsDeclCustomsServicesFeeLabel => 'رسوم الخدمات الجمركية';
  @override String get customsDeclColActions => 'الإجراءات';
  @override String get customsDeclAssessmentCopySuccess => 'تم نسخ التقييم الجمركي وبنود التعريفة إلى الحافظة بنجاح';
  @override String get customsDeclMetricTotalDeclarations => 'إجمالي الإقرارات';
  @override String get customsDeclMetricTotalCif => 'إجمالي القيمة الجمركية (سيف)';
  @override String get customsDeclMetricTotalDuties => 'إجمالي الضرائب والرسوم';
  @override String get customsDeclMetricExemptions => 'إعفاءات الشراكة الأوروبية';
  @override String get customsDeclFxRateLabel => 'سعر صرف الدولار الجمركي';
  @override String get customsDeclVatBaseLabel => 'الوعاء الضريبي للقيمة المضافة';
  @override String get searchAndCloneCustomsDeclBtn => 'استنساخ إقرار 46 جمركي';
  @override String get cloneCustomsDeclDialogTitle => 'بحث واستنساخ إقرار جمركي سابق (شهادة 46 ك.م)';
  @override String get cloneCustomsDeclDialogSubtitle => 'اختر إقراراً جمركياً أو ملف شحنة لاستنساخ بيانات التقييم الجمركي كمسودة جديدة قابلة للتعديل';
  @override String get cloneCustomsDeclSuccess => 'تم استنساخ بيانات الإقرار الجمركي كمسودة جديدة (46 ك.م) قابلة للتعديل بنجاح';
  @override String get cloneCustomsDeclRowTooltip => 'استنساخ هذا الإقرار كمسودة جديدة';
  @override String get copyApprovalRowSuccess => 'تم نسخ سطر الموافقة الرقابية كـ TSV بنجاح';
  @override String get copyApprovalTableSuccess => 'تم نسخ جدول الموافقات الرقابية كـ TSV بنجاح';
  @override String get exportExcelApprovalsTooltip => 'تصدير الموافقات الرقابية إلى Excel';
  @override String get exportPdfApprovalsTooltip => 'طباعة / تصدير PDF';
  @override String get exportRegistryExcelTooltip => 'تصدير سجل الإقرارات إلى Excel';
  @override String get exportRegistryPdfTooltip => 'طباعة / تصدير سجل الإقرارات PDF';
  @override String get copyRegistryRowSuccess => 'تم نسخ بيانات سطر الإقرار بصيغة TSV بنجاح';
  @override String get copyRegistryTableSuccess => 'تم نسخ سجل الإقرارات الجمركية بصيغة TSV بنجاح';
  @override String get cloneFromAssessmentBtn => 'استنساخ كمسودة جديدة';

  // ── Screen 24/27: Customs Clearance Management ────────────────────────────────
  @override String get searchAndCloneCustomsClearanceBtn => 'بحث واستنساخ بيان تخليص سابق';
  @override String get cloneCustomsClearanceDialogTitle => 'استنساخ بيان تخليص ومعاينة جمركية';
  @override String get cloneCustomsClearanceDialogSubtitle => 'اختر بياناً سابقاً لنسخ بيانات التخليص في مسودة جديدة';
  @override String get cloneCustomsClearanceTooltip => 'استنساخ هذا البيان الجمركي';
  @override String get copyCustomsClearanceRowSuccess => 'تم نسخ بيانات سجل التخليص بصيغة TSV بنجاح';
  @override String get copyCustomsClearanceTableSuccess => 'تم نسخ جدول التخليص الجمركي بصيغة TSV بنجاح';
  @override String get exportCustomsClearanceExcelTooltip => 'تصدير سجل التخليص الجمركي إلى Excel';
  @override String get exportCustomsClearancePdfTooltip => 'تصدير سجل التخليص الجمركي إلى PDF';
  @override String get customsClearanceStageTitle => 'الميناء والتخليص الجمركي والمعاينة والمطابقة';
  @override String get customsClearanceTabFollowUp => 'متابعة الكشف والتثمين والتفتيش الجمركي';
  @override String get customsClearanceTabSamples => 'سحب العينات وتحديد عجز البضائع';
  @override String get customsClearanceTabDiscrepancy => 'إثبات الفاقد والتلف الجمركي ومحاضر النقص';
  @override String get customsClearanceTabDutyPayment => 'سداد الرسوم والضرائب الجمركية النهائية';
  @override String customsClearanceErrorFetch(String error) => 'خطأ في جلب بيانات التخليص الجمركي: $error';
  @override String get customsClearanceSearchHint => 'بحث بكود التخليص، رقم 46 ك.م، إذن التسليم...';
  @override String get customsClearanceFilterAll => 'جميع الحالات';
  @override String get customsClearanceFilterInspection => 'قيد المعاينة والفحص';
  @override String get customsClearanceFilterDutyRequested => 'مطلوب سداد الجمارك';
  @override String get customsClearanceFilterDutyPaid => 'تم سداد الرسوم';
  @override String get customsClearanceFilterFinalRelease => 'تم الإفراج النهائي';
  @override String get customsClearanceStatusInspectionRecorded => 'تم تسجيل المعاينة وسحب العينات';
  @override String get customsClearanceStatusDutiesAssessed => 'تم تقدير الرسوم - جاهز للسداد';
  @override String get customsClearanceStatusDutyPaidReady => 'تم سداد الرسوم - جاهز للإفراج النهائي';
  @override String get customsClearanceStatusUnderBondReleased => 'مفرج عنه تحت التحفظ';
  @override String get customsClearanceStatusLabRejected => 'غير مطابق للمواصفات - مرفوض';
  @override String get customsClearanceStatusInvoicesVerified => 'تم تسجيل وتدقيق الفواتير';
  @override String get customsClearanceNewRecordButton => 'تسجيل معاملة تخليص';
  @override String get customsClearanceEmptyRecords => 'لا توجد سجلات تخليص جمركي مطابقة للبحث حالياً.';
  @override String get customsClearanceDeclaration46Label => '46 ك.م';
  @override String get customsClearanceDeliveryOrderLabel => 'إذن التسليم';
  @override String get customsClearanceOfficeLabel => 'الجمرك / المركز';
  @override String get customsClearanceFileRefLabel => 'ملف الشحنة المرجعي';
  @override String customsClearanceFreeDaysLabel(int days) => 'فترة السماح بالميناء: $days يوم';
  @override String get customsClearanceTotalDutiesCard => 'إجمالي الرسوم';
  @override String customsClearanceEstimatedDutiesCard(String est, String diff, String percent) => 'التقديري: $est ج.م (الفارق: $diff ج.م [$percent%])';
  @override String get customsClearancePaymentStatusLabel => 'حالة السداد';
  @override String get customsClearanceStatusPaid => 'تم السداد والتحقق';
  @override String get customsClearanceStatusPendingPayment => 'مطلوب السداد';
  @override String get customsClearanceEditTooltip => 'تعديل المعاملة';
  @override String get customsClearancePayTooltip => 'سداد ومطابقة الجمارك من نافذة';
  @override String get customsClearanceReleaseTooltip => 'إصدار الإفراج النهائي';
  @override String get customsClearanceSamplesBannerTitle => 'منظومة سحب العينات وتتبع الفحص المعملي وتحديد عجز البضائع';
  @override String get customsClearanceSamplesBannerDesc => 'توثيق إيصالات المعامل الرقابية (الهيئة العامة للرقابة على الصادرات والواردات، والهيئة القومية لسلامة الغذاء، ومصلحة الكيمياء، وهيئة الطاقة الذرية) ومتابعة المهلة القانونية لنتائج التحليل ومطابقة الأوزان والطرود الفعلية.';
  @override String get customsClearanceAddSampleButton => 'تسجيل سحب عينة';
  @override String get customsClearanceSamplesTableTitle => 'سجل العينات المسحوبة للفحص والتحليل المعملي';
  @override String get customsClearanceColSampleCode => 'كود العينة';
  @override String get customsClearanceColAuthority => 'الجهة الرقابية أو المعمل';
  @override String get customsClearanceColDrawingDate => 'تاريخ السحب';
  @override String get customsClearanceColReceiptNo => 'رقم الإيصال';
  @override String get customsClearanceColTestType => 'نوع الفحص والتحليل';
  @override String get customsClearanceColTestResult => 'نتيجة الفحص';
  @override String get customsClearanceColNotes => 'ملاحظات';
  @override String get customsClearanceSamplePassed => 'مطابقة للمواصفات';
  @override String get customsClearanceSamplePending => 'قيد الفحص المعملي';
  @override String get customsClearanceAddSampleDialogTitle => 'تسجيل سحب عينة معملية جديدة';
  @override String get customsClearanceSampleAuthLabel => 'الجهة الرقابية أو المعمل *';
  @override String get customsClearanceSampleReceiptLabel => 'رقم إيصال السحب *';
  @override String get customsClearanceSampleTestTypeLabel => 'نوع التحليل المطلوب *';
  @override String get customsClearanceSampleNotesLabel => 'ملاحظات الكشاف والمعمل';
  @override String get customsClearanceSampleSaveButton => 'حفظ العينة';
  @override String get customsClearanceSampleSaveSuccess => 'تم تسجيل سحب العينة المعملية بنجاح';
  @override String get customsClearanceDamageBannerTitle => 'سجل إثبات الفاقد والتلف الجمركي ومحاضر المعاينة المشتركة';
  @override String get customsClearanceDamageBannerDesc => 'توثيق محاضر كسر الحاويات والبلل والنقص مع مندوب التوكيل الملاحي والجمارك والتأمين البحري لتحصيل التعويضات.';
  @override String get customsClearanceAddDamageButton => 'تحرير محضر مشترك';
  @override String get customsClearanceDamageTableTitle => 'محاضر المعاينة المشتركة والمطالبات التأمينية';
  @override String get customsClearanceColProtocolNo => 'رقم المحضر';
  @override String get customsClearanceColDeclarationNo => 'الإقرار الجمركي (46 ك.م)';
  @override String get customsClearanceColContainerNo => 'رقم الحاوية';
  @override String get customsClearanceColDamageType => 'طبيعة الضرر والتلف';
  @override String get customsClearanceColDamagedQty => 'الكمية التالفة';
  @override String get customsClearanceColEstimatedLoss => 'الخسارة المقدرة (جنيه)';
  @override String get customsClearanceColResponsibleParty => 'الجهة المتسببة بالضرر';
  @override String get customsClearanceColClaimStatus => 'حالة المطالبة';
  @override String get customsClearanceColDate => 'التاريخ';
  @override String get customsClearanceClaimApproved => 'معتمدة للتعويض';
  @override String get customsClearanceClaimSubmitted => 'مقدمة لشركة التأمين';
  @override String get customsClearanceAddDamageDialogTitle => 'تحرير محضر تلف وفاقد جمركي ومعاينة مشتركة';
  @override String get customsClearanceDamageDeclLabel => 'رقم الإقرار (46 ك.م) *';
  @override String get customsClearanceDamageContainerLabel => 'رقم الحاوية *';
  @override String get customsClearanceDamageTypeLabel => 'طبيعة الضرر والتلف *';
  @override String get customsClearanceDamagedQtyLabel => 'الكمية التالفة *';
  @override String get customsClearanceDamageLossLabel => 'الخسارة المقدرة (جنيه) *';
  @override String get customsClearanceDamagePartyLabel => 'الجهة المسؤولة عن الضرر *';
  @override String get customsClearanceDamageNotesLabel => 'تفاصيل المحضر المشترك والمعاينة';
  @override String get customsClearanceDamageSaveButton => 'حفظ المحضر';
  @override String get customsClearanceDamageSaveSuccess => 'تم تحرير وحفظ محضر المعاينة المشتركة بنجاح';
  @override String get customsClearancePaymentBannerTitle => 'منظومة سداد الرسوم والضرائب الجمركية وإذن الإفراج النهائي';
  @override String get customsClearancePaymentBannerDesc => 'مطابقة إذن سداد نافذة وتوثيق إيصالات السداد البنكي وحفظ الفروق المالية واعتماد إذن الإفراج وتصريح خروج البوابة.';
  @override String get customsClearanceDutyLedgerTableTitle => 'سجل أذون سداد نافذة المعتمدة ومطابقة الرسوم';
  @override String get customsClearanceEmptyDutyLedger => 'لا توجد مطالبات سداد مسجلة حالياً.';
  @override String get customsClearanceColClearanceCode => 'كود التخليص';
  @override String get customsClearanceColDecl46 => 'الإقرار (46 ك.م)';
  @override String get customsClearanceColCustomsOffice => 'الجمرك المختص';
  @override String get customsClearanceColActualDuty => 'الرسوم الفعلية (نافذة)';
  @override String get customsClearanceColEstimatedDuty => 'الرسوم التقديرية';
  @override String get customsClearanceColDutyVariance => 'الفارق المالي';
  @override String get customsClearanceColPaymentStatus => 'حالة السداد';
  @override String get customsClearanceColActions => 'إجراءات السداد والإفراج';
  @override String get customsClearanceBtnPaymentDetails => 'تفاصيل السداد';
  @override String get customsClearanceBtnPayReconcile => 'سداد ومطابقة';
  @override String get customsClearanceBtnFinalRelease => 'الإفراج النهائي';
  @override String get customsClearanceNewDialogTitle => 'تسجيل معاملة تخليص جمركي وميناء جديدة';
  @override String customsClearanceEditDialogTitle(String code) => 'تعديل بيانات التخليص الجمركي ($code)';
  @override String get customsClearanceExtractNafezaBtn => 'استخلاص من نافذة';
  @override String get customsClearanceExtractNafezaSuccess => 'تم استخلاص وتعبئة بيانات إقرار نافذة والرسوم بنجاح!';
  @override String get customsClearanceImportFileLabel => 'ملف الشحنة الاستيرادية المرتكز عليه *';
  @override String get customsClearanceImportFileSearchHint => 'ابحث برقم الملف أو كود الشحنة...';
  @override String get customsClearanceSelectFileValidator => 'يرجى اختيار ملف الشحنة';
  @override String get customsClearanceDecl46Label => 'رقم الإقرار الجمركي (46 ك.م)';
  @override String get customsClearanceDoNumberLabel => 'رقم إذن التسليم';
  @override String get customsClearanceFreeDaysInputLabel => 'أيام السماح بالميناء';
  @override String get customsClearanceOfficeInputLabel => 'اسم الجمرك والدائرة الجمركية *';
  @override String get customsClearanceOfficeValidator => 'يرجى إدخال اسم الجمرك';
  @override String get customsClearanceChannelLabel => 'المسار الجمركي *';
  @override String get customsClearanceChannelRed => 'مسار أحمر (معاينة وعينات)';
  @override String get customsClearanceChannelGreen => 'مسار أخضر (إفراج مستندي)';
  @override String get customsClearanceChannelYellow => 'مسار أصفر (مراجعة مستندية)';
  @override String get customsClearanceDutyBreakdownHeader => 'مطالبة الرسوم والضرائب الجمركية (بالجنيه المصري):';
  @override String get customsClearanceImportDutyInput => 'ضريبة الوارد';
  @override String get customsClearanceVatInput => 'ضريبة القيمة المضافة';
  @override String get customsClearanceScheduleTaxInput => 'ضريبة الجدول';
  @override String get customsClearanceWhtInput => 'أرباح تجارية وصناعية';
  @override String get customsClearanceLabFeesInput => 'رسوم معملية وخدمات';
  @override String get customsClearanceEstimatedDutyInput => 'التقديري من النظام';
  @override String get customsClearanceSaveRecordBtn => 'حفظ المعاملة';
  @override String get customsClearanceSaveRecordSuccess => 'تم حفظ معاملة التخليص بنجاح';
  @override String customsClearanceSaveRecordError(String err) => 'خطأ أثناء الحفظ: $err';
  @override String customsClearanceDutyPaymentDialogTitle(String code) => 'سداد ومطابقة رسوم الجمارك ($code)';
  @override String get customsClearanceExtractReceiptBtn => 'استخلاص إيصال السداد';
  @override String customsClearanceEstimatorDutyBoxLabel(String amount) => 'الرسوم التقديرية: $amount ج.م';
  @override String customsClearanceNafezaDutyBoxLabel(String amount) => 'المطلوب بطلب سداد نافذة: $amount ج.م';
  @override String get customsClearanceVarianceBoxLabel => 'فارق التباين الضريبي:';
  @override String get customsClearanceActualPaidInput => 'إجمالي المبلغ الفعلي المسدد (جنيه) *';
  @override String get customsClearanceBankReceiptInput => 'رقم إيصال السداد البنكي والتحويل *';
  @override String get customsClearanceVarianceReasonInput => 'أسباب الفارق إن وجدت (تسويات معملية، بنود إضافية...)';
  @override String get customsClearanceConfirmPaymentBtn => 'تأكيد السداد والترحيل';
  @override String get customsClearancePaymentSuccess => 'تم توثيق سداد الرسوم الجمركية ومطابقة نافذة بنجاح';
  @override String customsClearancePaymentError(String err) => 'خطأ أثناء توثيق السداد: $err';
  @override String get customsClearanceFinalReleaseDialogTitle => 'إصدار تصريح الإفراج الجمركي النهائي';
  @override String get customsClearanceFinalReleaseDialogDesc => 'سيتم تغيير حالة المعاملة إلى الإفراج النهائي المعتمد وجاهزية خروج الحاويات من الميناء.';
  @override String get customsClearanceReleasePermitInput => 'رقم تصريح الإفراج الجمركي وتصريح البوابة *';
  @override String get customsClearanceConfirmReleaseBtn => 'اعتماد الإفراج النهائي';
  @override String get customsClearanceReleaseSuccess => 'تم منح الإفراج الجمركي النهائي بنجاح!';
  @override String customsClearanceReleaseError(String err) => 'خطأ أثناء منح الإفراج: $err';
  @override String get customsClearanceAiBrokerExtractorBtn => 'تكويد مستخلص جمركي بالذكاء الاصطناعي ✨';
  @override String get customsClearanceUnderBondTooltip => 'مسار السحب على عهدة وفك التحفظ المعملي';
  @override String get underBondReleaseDialogTitle => 'مسار الإفراج تحت التحفظ وقفل الفحص المعملي';
  @override String underBondReleaseDeclSubtitle(String declNo) => 'إقرار جمركي رقم 46: $declNo';
  @override String get underBondModeUnderBond => 'سحب على عهدة (تحت التحفظ)';
  @override String get underBondModeLabVerdict => 'تسجيل نتيجة المعامل وفك الحظر';
  @override String get underBondInfoBanner => 'يسمح هذا المسار بنقل البضاعة لمخزن المصنع تحت التحفظ الجمركي لحين صدور نتائج معامل الفحص والرقابة، مع إغلاق أذون الصرف بالمخازن آلياً.';
  @override String get underBondGuaranteeRefLabel => 'رقم خطاب الضمان البنكي أو التعهد الجمركي';
  @override String get underBondQuarantineLocLabel => 'موقع مخزن التحفظ المعملي (مخازن المصنع)';
  @override String get underBondDefaultQuarantineLoc => 'مخزن الشركة الرئيسي - السادس من أكتوبر';
  @override String get underBondConfirmReleaseBtn => 'تأكيد السحب على عهدة وتفعيل القفل المخزني';
  @override String get underBondRequiredFieldsError => 'يرجى ملء رقم خطاب الضمان وموقع التحفظ';
  @override String get underBondReleaseSuccess => 'تم السحب على عهدة تحت التحفظ بنجاح، وتفعيل قفل الحظر المخزني';
  @override String underBondActionError(String error) => 'فشل الإجراء: $error';
  @override String get underBondLabInfoBanner => 'تسجيل تقرير الفحص الصادر من المعامل المركزية (الرقابة على الصادرات والواردات، سلامة الغذاء، الطاقة الذرية). النتيجة الإيجابية تفك قفل الصرف وتتيح تشغيل البضاعة فوراً.';
  @override String get underBondLabCertLabel => 'رقم شهادة الفحص المعملي الصادرة';
  @override String get underBondLabVerdictLabel => 'نتيجة الفحص المعملي';
  @override String get underBondLabVerdictPassed => 'مطابق للمواصفات القياسية معتمد ✅';
  @override String get underBondLabVerdictRejected => 'غير مطابق ومرفوض نهائياً ⛔';
  @override String get underBondLabRemarksLabel => 'ملاحظات المعمل أو رقم قرار الإفراج النهائي';
  @override String get underBondApproveReleaseBtn => 'اعتماد المطابقة وفك قفل الصرف المخزني';
  @override String get underBondRejectReleaseBtn => 'تثبيت الرفض وحظر التشغيل';
  @override String get underBondLabCertRequiredError => 'يرجى إدخال رقم شهادة الفحص المعملي';
  @override String get underBondLabApprovedSuccess => 'تم فك التحفظ واعتماد المطابقة المعملية بنجاح ✅';
  @override String get underBondLabRejectedAlert => 'تم تسجيل رفض العينة المعملية وإلزام إعادة التصدير ⛔';
  @override String underBondLabResultError(String error) => 'فشل تسجيل النتيجة: $error';
  @override String get underBondConfirmLiftTitle => 'تأكيد رفع التحفظ الجمركي';
  @override String get underBondConfirmLiftBody => 'سيؤدي هذا الإجراء إلى رفع التحفظ الرقابي عن الشحنة وقد يتيح الإفراج النهائي. هل تريد المتابعة؟';
  @override String get underBondConfirmLiftConfirm => 'تأكيد ورفع التحفظ';
  @override String get underBondConfirmLiftCancel => 'إلغاء';
  @override String get underBondLabVerdictRequired => 'نتيجة الفحص المعملي مطلوبة';
  @override String get underBondRefRequired => 'رقم خطاب الضمان الجمركي مطلوب';
  @override String get underBondRefMinLength => 'رقم خطاب الضمان يجب ألا يقل عن 3 أحرف';
  @override String get underBondRefInvalid => 'يرجى إدخال رقم خطاب ضمان صالح';
  @override String get underBondLocationRequired => 'موقع المستودع الجمركي مطلوب';
  @override String get underBondCertRequired => 'رقم شهادة الفحص المعملي مطلوب';
  @override String get underBondCertMinLength => 'رقم شهادة الفحص يجب ألا يقل عن 3 أحرف';
  @override String get underBondCertInvalid => 'يرجى إدخال رقم شهادة فحص معملي صالح';
  @override String get customsClearanceExportTsvBtn => 'نسخ السجل كجدول تبويب مفصول';
  @override String get customsClearanceExportTsvSuccess => 'تم نسخ جدول التخليص الجمركي إلى الحافظة بنجاح';
  @override String get customsClearanceCopyFieldTooltip => 'نسخ القيمة';

  // ── Screen 60: Customs Clearance - Drawing Samples & Shortage Tracking ───────
  @override String get drawingSamplesScreenTitle => 'سحب العينات وتتبع الفحص وعجز البضائع';
  @override String get drawingSamplesScreenSubtitle => 'توثيق إيصالات المعامل الرقابية ومتابعة المهلة القانونية لنتائج الفحص ومطابقة عجز البضائع المفرغة';
  @override String get drawingSamplesTabDrawnSamples => 'العينات المسحوبة للفحص المعملي';
  @override String get drawingSamplesTabShortageReconciliation => 'سجل مطابقة الأوزان وتحديد عجز البضائع';
  @override String get drawingSamplesKpiTotalSamples => 'إجمالي العينات المسحوبة';
  @override String get drawingSamplesKpiPassedSamples => 'عينات مطابقة للمواصفات';
  @override String get drawingSamplesKpiPendingSamples => 'عينات قيد الفحص والتحليل';
  @override String get drawingSamplesKpiShortageCount => 'حالات العجز المثبتة';
  @override String get drawingSamplesExportTsvBtn => 'تصدير جدول تبويب مفصول';
  @override String get drawingSamplesExportExcelBtn => 'تصدير جدول أكسيل';
  @override String get drawingSamplesPrintPdfBtn => 'طباعة تقرير الفحص والعجز';
  @override String get drawingSamplesCopyDossierBtn => 'نسخ ملف الحافظة الشامل';
  @override String get drawingSamplesCopiedDossierSuccess => 'تم نسخ ملف الحافظة الشامل للعينات والعجز إلى الحافظة بنجاح';
  @override String get drawingSamplesCopiedTsvSuccess => 'تم نسخ بيانات الجدول بترميز التبويب إلى الحافظة بنجاح';
  @override String get drawingSamplesCopiedExcelSuccess => 'تم تصدير ملف جدول البيانات بنجاح';
  @override String get drawingSamplesCopyRowSummaryBtn => 'نسخ ملخص الصف';
  @override String get drawingSamplesCopyRowSummarySuccess => 'تم نسخ ملخص السجل إلى الحافظة بنجاح';
  @override String get drawingSamplesCopyFieldTooltip => 'نسخ القيمة';
  @override String get drawingSamplesSearchHint => 'بحث برقم العينة أو الإيصال أو الجهة أو الإقرار...';
  @override String get drawingSamplesFilterAll => 'كافة العينات';
  @override String get drawingSamplesFilterPassed => 'مطابقة فقط';
  @override String get drawingSamplesFilterPending => 'قيد الفحص فقط';
  @override String get drawingSamplesEmptySamples => 'لا توجد سجلات عينات مسحوبة مسجلة';
  @override String get drawingSamplesEmptyShortage => 'لا توجد محاضر عجز مسجلة';
  @override String get drawingSamplesColFileCode => 'كود الملف';
  @override String get drawingSamplesColSampledBodies => 'الجهات الرقابية المسحوبة';
  @override String get drawingSamplesColSamplingDate => 'تاريخ السحب';
  @override String get drawingSamplesColGoeicCert => 'شهادة الفحص أو الرقابة';
  @override String get drawingSamplesColTestStatus => 'حالة الفحص';
  @override String get drawingSamplesColLabResult => 'نتيجة المعمل';
  @override String get ccShortageNotAvailable => 'سيتم حفظ محاضر النقص فور ربط سجل النقص بقاعدة البيانات';
  @override String get importFilePickerTitle => 'اختيار ملف الشحنة';
  @override String get importFilePickerSelectPrompt => 'يرجى اختيار ملف الشحنة للمتابعة';
  @override String get ccActionNeedsAssessment => 'يجب تقييم الرسوم الجمركية أولاً';
  @override String get ccActionNeedsPayment => 'يجب سداد الرسوم الجمركية أولاً';
  @override String get ccActionQuarantineLocked => 'الشحنة تحت التحفظ الرقابي — يلزم رفع التحفظ أولاً';
  @override String get ccActionAlreadyReleased => 'تم الإفراج الجمركي النهائي بالفعل';
  @override String get customsClearanceViewTooltip => 'عرض تفاصيل المعاملة الجمركية';
  @override String get drawingSamplesShortageSectionTitle => 'سجل إثبات ومطابقة عجز البضائع المفرغة';
  @override String get drawingSamplesShortageSectionDesc => 'مقارنة أوزان وطرود المانيفست بالبضائع المفرغة فعلياً لإثبات العجز واستنزال الرسوم الجمركية أو مطالبة الناقل';
  @override String get drawingSamplesAddShortageBtn => 'إثبات محضر عجز جديد';
  @override String get drawingSamplesAddShortageDialogTitle => 'تسجيل محضر إثبات عجز بضائع مفرغة';
  @override String get drawingSamplesSummaryHeader => 'موجز ومؤشرات المنظومة';
  @override String get drawingSamplesColSampleCode => 'كود العينة';
  @override String get drawingSamplesColShortageCode => 'رقم المحضر';
  @override String get drawingSamplesColContainerPkg => 'رقم الحاوية أو الطرد';
  @override String get drawingSamplesColItemDesc => 'بيان الصنف والبضاعة';
  @override String get drawingSamplesColManifestQty => 'كمية المانيفست';
  @override String get drawingSamplesColLandedQty => 'الكمية المفرغة فعلياً';
  @override String get drawingSamplesColShortageQty => 'مقدار العجز';
  @override String get drawingSamplesColShortagePct => 'نسبة العجز';
  @override String get drawingSamplesColShortageAction => 'الإجراء الجمركي المعتمد';
  @override String get drawingSamplesColShortageNotes => 'ملاحظات المعاينة';
  @override String get drawingSamplesShortageActionDeductDuty => 'استنزال الضريبة والرسوم الجمركية';
  @override String get drawingSamplesShortageActionCarrierClaim => 'مطالبة التوكيل الملاحي بالتعويض';
  @override String get drawingSamplesShortageActionSurveyEndorsement => 'محضر معاينة مشتركة معتمد';
  @override String get drawingSamplesShortageSaveSuccess => 'تم تسجيل محضر إثبات العجز بنجاح';
  @override String get drawingSamplesFieldSampleId => 'كود العينة';
  @override String get drawingSamplesFieldAuthority => 'الجهة الرقابية أو المعمل';
  @override String get drawingSamplesFieldReceiptNo => 'رقم إيصال السحب';
  @override String get drawingSamplesFieldDrawingDate => 'تاريخ السحب';
  @override String get drawingSamplesFieldTestType => 'نوع الفحص والتحليل المطلوب';
  @override String get drawingSamplesFieldDeclarationNo => 'الإقرار الجمركي 46 ك.م';
  @override String get drawingSamplesFieldStatus => 'حالة ونتيجة الفحص';
  @override String get drawingSamplesFieldNotes => 'ملاحظات الكشاف والمعمل';
  @override String get drawingSamplesFieldContainerNo => 'رقم الحاوية أو الطرد';
  @override String get drawingSamplesFieldItemDesc => 'وصف البضاعة والصنف';
  @override String get drawingSamplesFieldManifestQty => 'الكمية بالمانيفست (طرود أو كجم)';
  @override String get drawingSamplesFieldLandedQty => 'الكمية المفرغة فعلياً (طرود أو كجم)';
  @override String get drawingSamplesValidationRequired => 'هذا الحقل إلزامي';
  @override String get drawingSamplesValidationPositiveNumber => 'يرجى إدخال رقم صحيح وموجب';
  @override String get drawingSamplesValidationLandedExceeds => 'لا يمكن أن تزيد الكمية المفرغة عن كمية المانيفست';

  // ── Screen 61: Customs Clearance - Discrepancy & Damage Registry ───────────────
  @override String get discrepancyDamageScreenTitle => 'إثبات الفاقد والتلف الجمركي ومحاضر النقص';
  @override String get discrepancyDamageScreenSubtitle => 'توثيق محاضر كسر الحاويات والبلل والنقص مع مندوب التوكيل الملاحي والجمارك والتأمين البحري لتحصيل التعويضات';
  @override String get discrepancyDamageKpiTotalProtocols => 'إجمالي المحاضر';
  @override String get discrepancyDamageKpiTotalLoss => 'إجمالي الخسائر المقدرة';
  @override String get discrepancyDamageKpiClaimsSubmitted => 'مطالبات قيد المتابعة';
  @override String get discrepancyDamageKpiClaimsApproved => 'مطالبات معتمدة للتعويض';
  @override String get discrepancyDamageExportTsvBtn => 'تصدير جدول نصي';
  @override String get discrepancyDamageExportExcelBtn => 'تصدير جدول إكسيل';
  @override String get discrepancyDamagePrintPdfBtn => 'طباعة تقرير بي دي إف';
  @override String get discrepancyDamageCopyDossierBtn => 'نسخ حافظة المحاضر';
  @override String get discrepancyDamageCopiedDossierSuccess => 'تم نسخ حافظة محاضر التلف والفاقد الجمركي إلى الحافظة بنجاح';
  @override String get discrepancyDamageCopiedTsvSuccess => 'تم تصدير وحفظ جدول المحاضر بنجاح';
  @override String get discrepancyDamageCopiedExcelSuccess => 'تم تصدير وحفظ جدول المحاضر بنسق إكسيل بنجاح';
  @override String get discrepancyDamageCopyRowSummaryBtn => 'نسخ ملخص المحضر';
  @override String get discrepancyDamageCopyRowSummarySuccess => 'تم نسخ ملخص محضر المعاينة بنجاح';
  @override String get discrepancyDamageCopyFieldTooltip => 'نسخ القيمة';
  @override String get discrepancyDamageSearchHint => 'بحث برقم المحضر، الإقرار، الحاوية، طبيعة الضرر، أو الجهة المتسببة...';
  @override String get discrepancyDamageFilterAll => 'كافة الحالات';
  @override String get discrepancyDamageFilterSubmitted => 'مقدمة للتأمين';
  @override String get discrepancyDamageFilterApproved => 'معتمدة للتعويض';
  @override String get discrepancyDamageFilterUnderReview => 'قيد التحقيق والمعاينة';
  @override String get discrepancyDamageEmptyRecords => 'لا توجد محاضر معاينة مشتركة أو إثبات فاقد مسجلة حالياً.';
  @override String get discrepancyDamageAddProtocolBtn => 'تحرير محضر مشترك جديد';
  @override String get discrepancyDamageAddDialogTitle => 'تحرير محضر تلف وفاقد جمركي ومعاينة مشتركة';
  @override String get discrepancyDamageSummaryHeader => 'ملخص المحضر الجمركي';
  @override String get discrepancyDamageColProtocolNo => 'رقم المحضر';
  @override String get discrepancyDamageColDeclarationNo => 'الإقرار الجمركي';
  @override String get discrepancyDamageColContainerNo => 'رقم الحاوية';
  @override String get discrepancyDamageColDamageType => 'طبيعة الضرر والتلف';
  @override String get discrepancyDamageColDamagedQty => 'الكمية التالفة';
  @override String get discrepancyDamageColEstimatedLoss => 'الخسارة المقدرة';
  @override String get discrepancyDamageColResponsibleParty => 'الجهة المتسببة بالضرر';
  @override String get discrepancyDamageColClaimStatus => 'حالة المطالبة';
  @override String get discrepancyDamageColDate => 'تاريخ المعاينة';
  @override String get discrepancyDamageColCommittee => 'لجنة المعاينة المشتركة';
  @override String get discrepancyDamageColNotes => 'ملاحظات وتفاصيل التقرير';
  @override String get discrepancyDamageColActions => 'الإجراءات';
  @override String get discrepancyDamageClaimApproved => 'معتمدة للتعويض';
  @override String get discrepancyDamageClaimSubmitted => 'مقدمة لشركة التأمين';
  @override String get discrepancyDamageClaimUnderReview => 'قيد المعاينة والتحقيق';
  @override String get discrepancyDamageFieldProtocolNo => 'كود المحضر';
  @override String get discrepancyDamageFieldDeclarationNo => 'رقم الإقرار الجمركي (46 ك.م)';
  @override String get discrepancyDamageFieldContainerNo => 'رقم الحاوية أو الطرد';
  @override String get discrepancyDamageFieldDamageType => 'طبيعة ونوع التلف والضرر';
  @override String get discrepancyDamageFieldDamagedQty => 'الكمية أو عدد الطرود المتضررة';
  @override String get discrepancyDamageFieldEstimatedLoss => 'قيمة الخسارة المقدرة (بالجنيه)';
  @override String get discrepancyDamageFieldResponsibleParty => 'الجهة المسؤولة عن الضرر';
  @override String get discrepancyDamageFieldCommittee => 'أعضاء لجنة المعاينة المشتركة';
  @override String get discrepancyDamageFieldNotes => 'ملاحظات وقرارات اللجنة المشتركة';
  @override String get discrepancyDamageValidationRequired => 'هذا الحقل إلزامي لتوثيق المحضر قانونياً';
  @override String get discrepancyDamageValidationPositiveNumber => 'يرجى إدخال قيمة عددية صحيحة موجبة';
  @override String get discrepancyDamageSaveSuccess => 'تم تحرير وحفظ محضر المعاينة المشتركة وإثبات الضرر بنجاح';
  @override String get discrepancyDamageCurrencyEgp => 'جنيه مصري';

  // ── Screen 62: Customs Clearance - Final Duty Payment & Release ────────────
  @override String get finalDutyScreenTitle => 'منظومة سداد الرسوم والضرائب الجمركية وإذن الإفراج النهائي';
  @override String get finalDutyScreenSubtitle => 'مطابقة إذن سداد نافذة وتوثيق إيصالات السداد البنكي وحفظ الفروق المالية واعتماد إذن الإفراج وتصريح خروج البوابة';
  @override String get finalDutySummaryHeader => 'ملخص منظومة سداد الرسوم الجمركية والإفراج النهائي';
  @override String get finalDutyKpiTotalPayable => 'إجمالي الرسوم المطلوبة';
  @override String get finalDutyKpiOutstanding => 'إجمالي الرسوم المستحقة';
  @override String get finalDutyKpiTotalPaid => 'إجمالي الرسوم المسددة';
  @override String get finalDutyKpiPendingPayment => 'مطالبات قيد السداد';
  @override String get finalDutyKpiNetVariance => 'صافي الفروقات الجمركية';
  @override String get finalDutyExportTsvBtn => 'تصدير جدول';
  @override String get finalDutyExportExcelBtn => 'تصدير إكسل';
  @override String get finalDutyPrintPdfBtn => 'طباعة تقرير';
  @override String get finalDutyCopyDossierBtn => 'نسخ الحافظة';
  @override String get finalDutyCopiedDossierSuccess => 'تم نسخ حافظة سداد الرسوم الجمركية والإفراج للحافظة';
  @override String get finalDutyCopiedTsvSuccess => 'تم نسخ جدول سداد الرسوم الجمركية بترميز نصوص';
  @override String get finalDutyCopiedExcelSuccess => 'تم تصدير جدول سداد الرسوم الجمركية بصيغة إكسل';
  @override String get finalDutyCopyRowSummaryBtn => 'نسخ ملخص السجل';
  @override String get finalDutyCopyRowSummarySuccess => 'تم نسخ ملخص المعاملة للحافظة';
  @override String get finalDutyCopyFieldTooltip => 'نسخ القيمة';
  @override String get finalDutySearchHint => 'ابحث بكود التخليص أو رقم الإقرار أو الجمرك المختص...';
  @override String get finalDutyFilterAll => 'كافة المعاملات';
  @override String get finalDutyFilterPaid => 'تم السداد';
  @override String get finalDutyFilterPending => 'قيد السداد';
  @override String get finalDutyFilterReleased => 'إفراج نهائي';
  @override String get finalDutyEmptyRecords => 'لا توجد مطالبات سداد أو معاملات تخليص مسجلة حالياً.';
  @override String get finalDutyColBankReceipt => 'إيصال السداد البنكي';
  @override String get finalDutyColReleasePermit => 'تصريح الإفراج الجمركي';
  @override String get finalDutyCurrencyEgp => 'جنيه مصري';
  @override String get finalDutyStatusPaidVerified => 'مسدد ومطابق';
  @override String get finalDutyStatusPendingPayment => 'بانتظار السداد';
  @override String get finalDutyStatusReleased => 'إفراج نهائي معتمد';
  @override String get finalDutyDossierHeader => 'تقرير سداد الرسوم الجمركية والإفراج النهائي — نظام سير العمل الاستيرادي';
  @override String get finalDutyDossierKpiSummary => 'المؤشرات المالية والإجرائية العامة:';
  @override String get finalDutyDossierRecordsDetails => 'سجل تسوية الرسوم والضرائب الجمركية:';
  @override String get finalDutyPdfTitle => 'تقرير سداد الرسوم والضرائب الجمركية وتصاريح الإفراج';
  @override String get finalDutyPdfSubtitle => 'سجل المطابقة المالية لأذون سداد نافذة وتوثيق إيصالات البنك وتصاريح الخروج';

  // ── Screen 25: Freight Booking ─────────────────────────────────────────────
  @override String get freightBookingStageTitle => 'حجز الشحن وتخصيص الحاويات';
  @override String get freightBookingTabRegistry => 'سجل حجوزات الشحن والناقلين';
  @override String get freightBookingTabNewRequest => 'طلب حجز شحن جديد';
  @override String get freightBookingCreateButton => 'إنشاء حجز شحن جديد';
  @override String get freightBookingSearchHint => 'بحث بكود الحجز أو رقم التأكيد...';
  @override String get freightBookingFilterStatusLabel => 'تصفية حسب الحالة';
  @override String get freightBookingFilterStatusHint => 'ابحث عن الحالة...';
  @override String get freightBookingStatusAll => 'جميع الحالات';
  @override String get freightBookingStatusDraft => 'مسودة';
  @override String get freightBookingStatusRequested => 'تم طلب الحجز';
  @override String get freightBookingStatusConfirmed => 'مؤكد';
  @override String get freightBookingStatusSailed => 'أبحر / غادر';
  @override String get freightBookingEmptyRecords => 'لا توجد حجوزات شحن مسجلة بالنظام. اضغط إضافة حجز جديد.';
  @override String get freightBookingColActions => 'العمليات ⚡';
  @override String get freightBookingColBookingCode => 'كود الحجز';
  @override String get freightBookingColImportFile => 'ملف الشحنة';
  @override String get freightBookingColConfirmationNo => 'رقم تأكيد الحجز';
  @override String get freightBookingColCarrierForwarder => 'الخط الملاحي والوكيل';
  @override String get freightBookingColRoute => 'مسار الشحن (POL ➔ POD)';
  @override String get freightBookingColVesselVoyage => 'السفينة ورقم الرحلة';
  @override String get freightBookingColDeparture => 'تاريخ المغادرة';
  @override String get freightBookingColArrival => 'تاريخ الوصول';
  @override String get freightBookingColContainers => 'الحاويات المخصصة';
  @override String get freightBookingColTotalFreight => 'إجمالي النولون USD';
  @override String get freightBookingColStatus => 'الحالة';
  @override String freightBookingApprovedQuoteLabel(String provider) => 'عرض معتمد: $provider';
  @override String freightBookingWhArrivalLabel(String date) => 'مخزن: $date';
  @override String get freightBookingPendingDate => 'لم يحدد بعد';
  @override String get freightBookingViewTooltip => 'عرض تفاصيل الحجز';
  @override String get freightBookingEditTooltip => 'تعديل حجز الشحن';
  @override String get freightBookingPrintTooltip => 'طباعة بطاقة الحجز';
  @override String get freightBookingDeleteTooltip => 'حذف حجز الشحن';
  @override String get freightBookingDeleteConfirmTitle => 'تأكيد الحذف';
  @override String freightBookingDeleteConfirmMessage(String code) => 'هل أنت متأكد من حذف حجز الشحن $code؟';
  @override String get freightBookingNewDialogTitle => 'إنشاء حجز شحن ملاحي';
  @override String freightBookingEditDialogTitle(String code) => 'تعديل حجز الشحن: $code';
  @override String get freightBookingCloseTooltip => 'إغلاق النافذة';
  @override String get freightBookingTabBookingDetails => '1. تفاصيل الحجز وعروض الشحن';
  @override String get freightBookingTabCostBreakdown => '2. بنود التكلفة والنولون';
  @override String get freightBookingImportFileLabel => 'ملف الشحنة الاستيرادية *';
  @override String get freightBookingImportFileHint => 'ابحث عن ملف الشحنة...';
  @override String get freightBookingConfirmNoInputLabel => 'رقم تأكيد الحجز *';
  @override String get freightBookingConfirmNoValidator => 'أدخل رقم تأكيد الحجز';
  @override String get freightBookingEvaluatedQuotesHeader => 'عروض وسيناريوهات الشحن المقيمة للملف:';
  @override String freightBookingAvailableQuotesBadge(int count) => '$count عرض متاح';
  @override String get freightBookingNoEvaluatedQuotes => 'لم يتم العثور على دراسة سيناريوهات شحن محفوظة لهذا الملف. يمكنك تعبئة بيانات الناقل أدناه يدوياً.';
  @override String get freightBookingApplyQuoteInstruction => 'اضغط على زر "اعتماد وتطبيق هذا العرض" لتعبئة بيانات الناقل، الموانئ، السفينة، المواعيد، التكاليف، والحاويات آلياً:';
  @override String get freightBookingBestQuoteBadge => 'الأفضل في الدراسة';
  @override String freightBookingQuoteVesselDetails(String vessel, String voyage, String pol, String pod) => 'سفينة: $vessel | رحلة: $voyage | موانئ: $pol ➔ $pod';
  @override String freightBookingQuoteScheduleDetails(String sailing, String eta, int days) => 'إبحار: $sailing ➔ وصول متوقع: $eta | فري تايم: $days يوم';
  @override String freightBookingQuoteStudyRef(String code, String date) => 'دراسة: $code ($date)';
  @override String get freightBookingSelectedQuoteBtn => 'العرض المعتمد ⭐';
  @override String get freightBookingApplyQuoteBtn => 'اعتماد هذا العرض';
  @override String freightBookingQuoteAppliedSuccess(String provider, String vessel) => 'تم استدعاء وتحديث بيانات العرض المعتمد بنجاح ($provider - $vessel)!';
  @override String get freightBookingShippingLineLabel => 'الخط الملاحي *';
  @override String get freightBookingShippingLineHint => 'ابحث عن الخط الملاحي...';
  @override String get freightBookingForwarderLabel => 'وكيل الشحن';
  @override String get freightBookingForwarderHint => 'ابحث عن وكيل الشحن...';
  @override String get freightBookingPolLabel => 'ميناء التحميل *';
  @override String get freightBookingPolHint => 'ابحث عن ميناء التحميل...';
  @override String get freightBookingPodLabel => 'ميناء الوصول *';
  @override String get freightBookingPodHint => 'ابحث عن ميناء الوصول...';
  @override String get freightBookingEtdLabel => 'تاريخ المغادرة المتوقع *';
  @override String get freightBookingEtaLabel => 'تاريخ الوصول المتوقع *';
  @override String get freightBookingAtdLabel => 'تاريخ المغادرة الفعلي';
  @override String freightBookingDelayBannerDelayed(int days) => '⚠️ تأخير في الإبحار: $days يوم عن الموعد المجدول';
  @override String get freightBookingDelayBannerOnTime => '✅ تم الإبحار في الموعد المجدول (لا توجد تأخيرات)';
  @override String freightBookingExpectedWhArrival(String date) => 'موعد الوصول للمخزن المتوقع: $date';
  @override String get freightBookingFreeDaysInput => 'الأيام المجانية بالميناء *';
  @override String get freightBookingWarehouseDaysInput => 'أيام الوصول للمخزن';
  @override String get freightBookingStatusInputLabel => 'حالة الحجز *';
  @override String get freightBookingVesselNameInput => 'اسم السفينة';
  @override String get freightBookingVoyageNoInput => 'رقم الرحلة';
  @override String get freightBookingReleaseOrderInput => 'إذن الإفراج عن الحاويات';
  @override String get freightBookingContainerTypeInput => 'نوع الحاوية المطلوب حجزها';
  @override String get freightBookingContainersQtyInput => 'عدد الحاويات المحجوزة';
  @override String get freightBookingEquipmentNote => 'ℹ️ ملاحظة: تخصيص الحاويات التفصيلي، أرقام السيل، أوزان VGM، والفحص يتم في مرحلة (متابعة وتجهيز التحميل).';
  @override String get freightBookingCostBreakdownTitle => 'تفاصيل بنود عرض السعر الشاملة:';
  @override String freightBookingBaseCurrencyLabel(String cur) => 'العملة الأساسية: $cur';
  @override String get freightBookingItemRateLabel => 'سعر البند';
  @override String get freightBookingCurrencyLabel => 'العملة';
  @override String get freightBookingQuantityLabel => 'الكمية';
  @override String get freightBookingCbmVolumeLabel => 'الحجم CBM';
  @override String get freightBookingItemActive => 'مطبق';
  @override String get freightBookingItemInactive => 'غير مطبق';
  @override String get freightBookingItem40ft => '1. شحن حاوية 40 قدم';
  @override String get freightBookingItem20ft => '2. شحن حاوية 20 قدم';
  @override String get freightBookingItemLcl => '3. نولون مجزأ (LCL CBM)';
  @override String get freightBookingItemCourier => '4. البريد السريع للمستندات';
  @override String get freightBookingItemEur1 => '5. شهادة المنشأ التفضيلية';
  @override String get freightBookingItemVgm => '6. مصاريف التحقق من الوزن المعتمد';
  @override String get freightBookingItemVgmNotif => '7. إخطار إقرار الوزن';
  @override String get freightBookingItemTelex => '8. إطلاق الفاكس الملاحي';
  @override String get freightBookingItemInsurance => '9. بوليصة التأمين البحري';
  @override String get freightBookingInsuranceHint => 'سجل التأمين البحري في شاشة وثائق التأمين، فهو لا يدخل ضمن تكاليف الحجز.';
  @override String get freightBookingItemCancellation => '10. غرامة إلغاء الحجز';
  @override String get freightBookingItemIcs2 => '11. رسوم بيان الحمول المسبقة (ICS2)';
  @override String get freightBookingItemOther => '12. مصاريف ورسوم أخرى';
  @override String get freightBookingItemDocFees => '13. مصاريف إصدار وثائق الشحن';
  @override String get freightBookingItemWaiver => '14. رسوم خطاب التنازل';
  @override String get freightBookingItemDthc => '15. تفريغ ومناولة ميناء الوصول (DTHC)';
  @override String get freightBookingItemStorageWeek => '16. أرضيات وتخزين الأسبوع الأول';
  @override String get freightBookingItemStorageExtra => '17. أرضيات وتخزين الأيام الإضافية';
  @override String get freightBookingMismatchTitle => 'تنبيه عدم تطابق الحاويات';
  @override String freightBookingMismatchWarning(String assigned, String suggested) => 'عدد الحاويات المخصصة ونوعها ($assigned) مختلف عن الحاوية المقترحة ($suggested).';
  @override String get freightBookingMismatchPrompt => 'هل ترغب في الاستمرار وتثبيت هذا التخصيص؟';
  @override String get freightBookingMismatchNote => 'في حال اختيار "نعم"، يتطلب النظام إدخال سبب التغيير لتوثيق القرار.';
  @override String get freightBookingMismatchBtnNo => 'لا (العودة للمطابقة)';
  @override String get freightBookingMismatchBtnYes => 'نعم (الاستمرار وكتابة السبب)';
  @override String get freightBookingMismatchReasonTitle => 'سبب تغيير الحاويات المقترحة *';
  @override String get freightBookingMismatchReasonHint => 'اكتب سبب اعتماد هذا التخصيص المختلف...';
  @override String get freightBookingMismatchReasonValidator => 'يجب إدخال سبب التغيير للاستمرار';
  @override String get freightBookingMismatchReasonConfirm => 'تأكيد وحفظ';
  @override String get freightBookingDuplicateTitle => 'تنبيه: الشحنة مسجلة بالفعل!';
  @override String get freightBookingDuplicateMessage => 'ملف الشحنة الاستيرادية المختار مرتبط بالفعل بحجز شحن محفوظ:';
  @override String get freightBookingDuplicateRowFile => 'ملف الشحنة:';
  @override String get freightBookingDuplicateRowCode => 'كود الحجز:';
  @override String get freightBookingDuplicateRowConfirmNo => 'رقم تأكيد الحجز:';
  @override String get freightBookingDuplicateRowLine => 'الخط الملاحي:';
  @override String get freightBookingDuplicateRowStatus => 'الحالة الحالية:';
  @override String get freightBookingDuplicateNotice => 'قواعد النظام تمنع إنشاء أكثر من حجز لنفس الملف الاستيرادي. يمكنك التحويل لتعديل الحجز الحالي فوراً.';
  @override String get freightBookingDuplicateBtnCancel => 'إلغاء والتراجع';
  @override String get freightBookingDuplicateBtnSwitch => 'التحويل إلى التعديل';
  @override String get freightBookingBtnCloseDiscard => 'إغلاق وتراجع';
  @override String get freightBookingBtnLiveReload => 'إعادة تحميل حية';
  @override String get freightBookingBtnClearNew => 'تفريغ وبدء تسجيل جديد';
  @override String get freightBookingBtnSaveDraft => 'حفظ مسودة ومتابعة لاحقة';
  @override String get freightBookingBtnSaveConfirm => 'حفظ وتأكيد حجز الشحن';
  @override String get freightBookingBtnUpdate => 'تحديث وحفظ الحجز';
  @override String get freightBookingSaveSuccess => 'تم حفظ وتأكيد حجز الشحن بنجاح!';
  @override String freightBookingViewTitle(String code) => 'تفاصيل حجز الشحن: $code';
  @override String get freightBookingViewShippingLine => 'الخط الملاحي:';
  @override String get freightBookingViewConfirmNo => 'رقم التأكيد:';
  @override String get freightBookingViewRouteSection => 'المسار والمواعيد:';
  @override String get freightBookingViewPol => 'ميناء التحميل:';
  @override String get freightBookingViewPod => 'ميناء الوصول:';
  @override String freightBookingViewVesselVoyage(String vessel, String voyage) => 'السفينة: $vessel (رحلة: $voyage)';
  @override String freightBookingViewTransitTime(int days) => 'مدة الترانزيت: $days يوم';
  @override String freightBookingViewEtd(String date) => 'تاريخ المغادرة: $date';
  @override String freightBookingViewEta(String date) => 'تاريخ الوصول: $date';
  @override String freightBookingViewAtd(String date, String delay) => 'تاريخ المغادرة الفعلي (ATD): $date ($delay)';
  @override String freightBookingViewExpectedWh(String date) => 'وصول المخزن المتوقع: $date';
  @override String get freightBookingViewContainersSection => 'الحاويات وأرقام السيل المخصصة:';
  @override String get freightBookingViewChargesSection => 'بنود التكاليف والنولون المعتمدة:';
  @override String get freightBookingViewTotalFreight => 'إجمالي النولون التقديري بالدولار:';
  @override String freightBookingPrintTitle(String code) => 'طباعة بطاقة حجز الشحن: $code';
  @override String freightBookingPrintManifestHeader(String code) => 'سند تأكيد حجز الشحن الملاحي ($code)';
  @override String freightBookingPrintDate(String date) => 'تاريخ الطباعة: $date';
  @override String get freightBookingPrintContainersHeader => 'قائمة الحاويات وأرقام السيل:';
  @override String get freightBookingPrintChargesHeader => 'إجمالي النولون والمصاريف المعتمدة:';
  @override String freightBookingPrintGrandTotal(String amount) => 'الإجمالي العام: \$ $amount USD';
  @override String get freightBookingPrintNowBtn => 'طباعة الآن';
  @override String get freightBookingPrintSuccess => 'تم إرسال سند الحجز للطباعة بنجاح!';
  // ── Screen 25 extra keys (hardcoded strings fixed) ────────────────────────
  @override String get freightBookingAiShippingLineBtn => 'تكويد خط ملاحي بالذكاء الاصطناعي ✨';
  @override String get freightBookingAiForwarderBtn => 'تكويد شركة شحن بالذكاء الاصطناعي ✨';
  @override String get freightBookingDraftPendingLabel => 'مسودة معلقة';
  @override String freightBookingForwarderPrefixLabel(String name) => 'الوكيل: $name';
  @override String freightBookingEtdPrefixLabel(String date) => 'م.انطلاق: $date';
  @override String freightBookingAtdPrefixLabel(String date) => 'انطلاق فعلي: $date';
  @override String freightBookingEtaPrefixLabel(String date) => 'م.وصول: $date';
  @override String freightBookingBasedOnQuote(String name) => 'مبني على عرض أسعار: $name';
  @override String freightBookingCostSavingsBadgeAmount(String diff, String pct) => 'توفير: \$ $diff ($pct%)';
  @override String freightBookingCostIncreaseBadgeAmount(String diff) => 'زيادة: \$ $diff';
  @override String get freightBookingCostMatchBadge => 'مطابق: \$ 0.00';
  @override String get freightBookingNetDifference => 'الفرق';
  @override String get freightBookingBreakdownHeader => '📊 تفاصيل احتساب التوفير ناتج حاصل ضرب فرق السعر × الكمية:';
  @override String freightBookingBreakdownSavingsUnit(String name, String orig, String exec, String unitDiff, String qty, String unitType, String savings) => '• $name: (\$$orig - \$$exec = \$$unitDiff) × $qty $unitType = \$$savings USD توفير';
  @override String get freightBookingPrintSystemHeader => 'SOROUR LOGISTICS ERP - CARRIER BOOKING CONFIRMATION';
  @override String get searchAndCloneFreightBookingBtn => 'بحث واستنساخ حجز سابق';
  @override String get cloneFreightBookingDialogTitle => 'استنساخ حجز شحن بحري / جوي';
  @override String get cloneFreightBookingDialogSubtitle => 'اختيار حجز شحن سابق واستنساخه كمسودة جديدة مع تصفير أرقام التأكيد والبوالص';
  @override String get cloneBookingRowTooltip => 'استنساخ حجز الشحن كمسودة جديدة';
  @override String get copyBookingRowSuccess => 'تم نسخ بيانات حجز الشحن إلى الحافظة بنجاح';
  @override String get copyBookingsTableSuccess => 'تم نسخ جدول حجوزات الشحن كـ TSV بنجاح';
  @override String get exportBookingsExcelTooltip => 'تصدير سجل الحجوزات إلى Excel';
  @override String get exportBookingsPdfTooltip => 'تصدير سجل الحجوزات إلى PDF';

  // ── Screen 26 & 52: Cargo Shipping Tracking & Freight Allocations (VGM) ───
  @override String get searchAndCloneCargoShippingBtn => 'بحث واستنساخ شحنة سابقة';
  @override String get cloneCargoShippingDialogTitle => 'استنساخ سجل شحن وحاويات';
  @override String get cloneCargoShippingDialogSubtitle => 'اختر شحنة سابقة واستنسخ تجهيز الحاويات والـ VGM كمسودة جديدة';
  @override String get cloneCargoShippingTooltip => 'استنساخ الشحنة وتخصيص الحاويات كمسودة جديدة';
  @override String get cargoShippingDuplicateContainerTooltip => 'تكرار / استنساخ الحاوية (Ctrl + D)';
  @override String get copyCargoShippingRowSuccess => 'تم نسخ بيانات الشحنة إلى الحافظة بنجاح';
  @override String get copyCargoShippingTableSuccess => 'تم نسخ جدول سجل الشحنات كـ TSV بنجاح';
  @override String get exportCargoShippingExcelTooltip => 'تصدير سجل الشحنات إلى Excel';
  @override String get exportCargoShippingPdfTooltip => 'تصدير سجل الشحنات إلى PDF';
  @override String get cargoShippingAllocationsTitle => 'تخصيص وتوزيع الحاويات والوزن الإجمالي المعتمد للشحن';
  @override String get cargoShippingTrackingTitle => 'متابعة حركة الشحن وتحميل وتوريد الحاويات وضبط المهل';
  @override String get cargoShippingFormTab => 'تجهيز الشحن ومتابعة التحميل';
  @override String get cargoShippingRegistryTab => 'سجل متابعة الشحنات والتحميل';
  @override String get cargoShippingUploadBlLabel => 'رفع واستخراج بيانات بوليصة الشحن';
  @override String cargoShippingUploadBlSuccess(String blNo) => 'تم استخراج بيانات بوليصة الشحن بنجاح ($blNo)';
  @override String get cargoShippingLinkedFileBannerPrefix => 'ملف الاستيراد المربوط:';
  @override String get cargoShippingSupplierLabel => 'المورد:';
  @override String get cargoShippingCodeLabel => 'كود الشحنة:';
  @override String get cargoShippingCancelStartNew => 'إلغاء والبدء من جديد';
  @override String get cargoShippingStep1Title => '1. تخصيص الحاويات والوزن المعتمد';
  @override String get cargoShippingStep2Title => '2. متابعة تحميل وتوريد الحاويات وضبط المهل';
  @override String get cargoShippingImportFileLabel => 'ملف الشحنة الاستيرادية المربوط *';
  @override String get cargoShippingImportFileHint => 'اختر ملف الشحنة...';
  @override String get cargoShippingImportFileDefault => '-- اختر ملف الشحنة --';
  @override String get cargoShippingPreviouslyRegistered => '(مسجل سابقاً)';
  @override String get cargoShippingSelectFileValidator => 'يرجى اختيار ملف الشحنة';
  @override String get cargoShippingShipmentTypeLabel => 'نوع الشحنة *';
  @override String get cargoShippingFclLabel => 'حاوية كاملة';
  @override String get cargoShippingLclLabel => 'شحن جزئي مشترك - تجميع مخازن';
  @override String cargoShippingAggregatedCargoMetrics(String cbm, String weight) => 'حمولة الملف المجمعة من قوائم التعبئة: $cbm m³ | $weight kg';
  @override String get cargoShippingCargoStackingLabel => 'نوع التحميل والتخزين:';
  @override String get cargoShippingStackable => 'قابل للرص';
  @override String get cargoShippingNonStackable => 'غير قابل للرص';
  @override String cargoShippingAutoRecommendation(int count, String code, String spaceUtil, String weightUtil) => 'اقتراح الحاوية التلقائي: $count x $code (استغلال المساحة: $spaceUtil% | استغلال الوزن: $weightUtil%)';
  @override String get cargoShippingContainersHeader => 'بيانات تخصيص الحاويات وأرقام الأقفال والوزن الإجمالي المعتمد:';
  @override String cargoShippingBookingMatchRequired(int registered, int expected) => 'لا يمكن الحفظ: عدد الحاويات المسجلة ($registered) يجب أن يساوي عدد الحاويات في البوكينج ($expected).';
  @override String get cargoShippingBookingLimitReached => 'تم الوصول للحد الأقصى لعدد الحاويات المعتمدة في البوكينج';
  @override String cargoShippingBookingStatusBadge(String bookingCode, String summary) => 'حاويات البوكينج ($bookingCode): $summary';
  @override String get cargoShippingBookingStatusMatch => 'مطابق للبوكينج';
  @override String get cargoShippingBookingStatusMismatch => 'غير مطابق للبوكينج';
  @override String get cargoShippingAddContainerType => 'إضافة نوع حاوية جديد';
  @override String get cargoShippingContainerType => 'نوع الحاوية';
  @override String get cargoShippingQty => 'العدد';
  @override String get cargoShippingVgmWeight => 'الوزن الإجمالي المعتمد (كجم)';
  @override String get cargoShippingUnitDetailsHeader => 'تفاصيل أرقام الحاويات والسيل لكل وحدة:';
  @override String cargoShippingUnitPrefix(int number) => 'حاوية #$number: ';
  @override String get cargoShippingContainerNo => 'رقم الحاوية';
  @override String get cargoShippingSealNo => 'رقم القفل الملاحي';
  @override String get cargoShippingCfsHeader => 'بيانات محطة ومخزن تجميع الشحنة:';
  @override String get cargoShippingCfsWarehouseLabel => 'اسم وموقع مخزن تجميع البضائع';
  @override String get cargoShippingImportFileTrackingLabel => 'ملف الشحنة الاستيرادية المربوط للمتابعة *';
  @override String get cargoShippingImportFileTrackingHint => 'اختر ملف الشحنة لمتابعة التوريد والتحميل...';
  @override String cargoShippingActiveFileTrackingBanner(String fileCode, String company, String supplier, String acid) => 'ملف الاستيراد: [$fileCode] $company | المورد: $supplier | ACID: $acid';
  @override String get cargoShippingMetricTotalContainers => 'إجمالي الحاويات';
  @override String get cargoShippingMetricInProgress => 'جاري التحميل والتوريد';
  @override String get cargoShippingMetricGatedIn => 'دخلت الميناء';
  @override String get cargoShippingMetricSlaBreached => 'تجاوزت المهلة المحددة (48 ساعة)';
  @override String cargoShippingContainerCardHeader(int index, String containerNo, String containerType, String sealNo) => 'حاوية #$index: $containerNo ($containerType) | سيل: $sealNo';
  @override String get cargoShippingSlaBreachedBadge => 'تجاوزت مهلة الـ 48 ساعة';
  @override String get cargoShippingQuickSaveContainer => 'حفظ تحديث هذه الحاوية 💾';
  @override String get cargoShippingMilestone1 => '1. التخصيص';
  @override String get cargoShippingMilestone2 => '2. وصول للمورد';
  @override String get cargoShippingMilestone3 => '3. بداية التحميل';
  @override String get cargoShippingMilestone4 => '4. نهاية التحميل';
  @override String get cargoShippingMilestone5 => '5. دخول الميناء';
  @override String get cargoShippingMilestone1Title => 'تاريخ ووقت التخصيص';
  @override String get cargoShippingMilestone2Title => 'وصول للمورد';
  @override String get cargoShippingMilestone3Title => 'بداية التحميل';
  @override String get cargoShippingMilestone4Title => 'نهاية التحميل';
  @override String get cargoShippingMilestone5Title => 'دخول الميناء';
  @override String get cargoShippingPickMilestone1 => 'تسجيل تاريخ ووقت تخصيص الحاوية';
  @override String get cargoShippingPickMilestone2 => 'تسجيل وصول الحاوية لدى المورد';
  @override String get cargoShippingPickMilestone3 => 'تسجيل بداية تحميل وتعبئة الحاوية';
  @override String get cargoShippingPickMilestone4 => 'تسجيل نهاية التحميل وتركيب السيل';
  @override String get cargoShippingPickMilestone5 => 'تسجيل دخول الحاوية بوابة الميناء';
  @override String get cargoShippingPickBtn => 'اختيار 📅';
  @override String get cargoShippingSetNowBtn => 'الآن ⚡';
  @override String get cargoShippingClickToSetDateTime => 'انقر لتسجيل التاريخ والوقت 📅';
  @override String cargoShippingNotesHeader(String containerName) => 'تدوين وملاحظات مراحل التسلسل الزمني للحاوية ($containerName):';
  @override String get cargoShippingSelectMilestoneTarget => 'اختر المرحلة المستهدفة: ';
  @override String get cargoShippingTagDriverDelayed => '⚠️ تأخر السائق في الاستلام';
  @override String get cargoShippingTagPermitPending => '⏳ انتظار إذن وتصريح التحميل';
  @override String get cargoShippingTagContainerInspection => '🔍 فحص سلامة الحاوية والسيل';
  @override String get cargoShippingTagPortCongestion => '🛑 ازدحام عند بوابة الميناء';
  @override String get cargoShippingTagPalletizedCargo => '📦 بضاعة معبأة على بالتات خشبية';
  @override String get cargoShippingTagVisualCheck => '📝 فحص ظاهري ومطابقة الباكنج ليست';
  @override String cargoShippingNoteHint(String stepTitle) => 'اكتب ملاحظة تفصيلية للمرحلة المحددة ($stepTitle)...';
  @override String get cargoShippingSaveNote => 'حفظ الملاحظة 💾';
  @override String get cargoShippingClearNote => 'مسح الملاحظة';
  @override String cargoShippingLclTrackingHeader(String warehouse) => 'متابعة تجميع بضائع الشحن الجزئي المشترك بمخزن: $warehouse';
  @override String get cargoShippingQuickSaveLcl => 'حفظ مرحلة الشحن الجزئي 💾';
  @override String get cargoShippingLclMilestone1 => '1. جدولة التجميع';
  @override String get cargoShippingLclMilestone2 => '2. وصول مخزن التجميع';
  @override String get cargoShippingLclMilestone3 => '3. بداية التعبئة';
  @override String get cargoShippingLclMilestone4 => '4. نهاية التعبئة';
  @override String get cargoShippingLclMilestone5 => '5. دخول الميناء';
  @override String get cargoShippingLclPickMilestone1 => 'تسجيل تاريخ وتوقيت جدولة التجميع بمخزن البضائع';
  @override String get cargoShippingLclPickMilestone2 => 'تسجيل وصول البضاعة لمخزن التجميع المشترك';
  @override String get cargoShippingLclPickMilestone3 => 'تسجيل بداية تعبئة الحاوية المجمعة';
  @override String get cargoShippingLclPickMilestone4 => 'تسجيل اكتمال تعبئة وتجهيز الحاوية';
  @override String get cargoShippingLclPickMilestone5 => 'تسجيل دخول الحاوية المجمعة للميناء';
  @override String get cargoShippingAutoCompleteCycle => 'استيفاء وتأكيد دورة التحميل ودخول الميناء ⚡';
  @override String get cargoShippingClearStartNew => 'تفريغ وبدء تسجيل جديد 🔄';
  @override String get cargoShippingSaveDraft => 'حفظ مؤقت ومتابعة لاحقة 💾';
  @override String get cargoShippingUpdateStudy => 'تحديث وحفظ دراسة ملف الاستيراد';
  @override String get cargoShippingSaveStudy => 'حفظ دراسة ملف الاستيراد وتأكيد المتابعة';
  @override String get cargoShippingRegistrySearchHint => 'بحث باسم أو كود ملف الاستيراد، اسم الشركة، كود الشحن، أو رقم الحاوية...';
  @override String get cargoShippingStatusFilterLabel => 'حالة الشحن';
  @override String get cargoShippingStatusAll => 'كافة الحالات';
  @override String get cargoShippingStatusCargoReady => 'جاهزية البضاعة';
  @override String get cargoShippingStatusCompleted => 'مكتمل';
  @override String get cargoShippingSlaFilterLabel => 'مهلة الـ 48 ساعة للتوريد';
  @override String get cargoShippingSlaAll => 'كافة المهل';
  @override String get cargoShippingSlaOnTimeFilter => 'ضمن المهلة';
  @override String get cargoShippingSlaBreachedFilter => 'متأخرة عن المهلة';
  @override String get cargoShippingActiveFilterLabel => 'السجلات النشطة أو المحذوفة';
  @override String get cargoShippingActiveAll => 'كافة السجلات (النشطة والمحذوفة)';
  @override String get cargoShippingActiveOnly => 'النشطة فقط';
  @override String get cargoShippingDeletedOnly => 'المحذوفة فقط';
  @override String get cargoShippingNoMatchingRecords => 'لا توجد دراسات متابعة مطابقة للبحث الحالي.';
  @override String get cargoShippingCreateNewRecord => 'تسجيل ومتابعة شحنة جديدة';
  @override String get cargoShippingSoftDeletedBadge => 'محذوف منطقياً';
  @override String cargoShippingGatedCountBadge(int count, int total) => 'دخلت الميناء: $count من $total';
  @override String get cargoShippingSlaBreached => '⚠️ متأخر عن المهلة الزمنية';
  @override String get cargoShippingSlaOnTime => '✅ ضمن مهلة الـ 48 ساعة';
  @override String get cargoShippingEditTooltip => 'تعديل ومتابعة الحاويات وإعادة التفعيل';
  @override String get cargoShippingRestoreTooltip => 'استعادة وتفعيل السجل';
  @override String cargoShippingLoadSuccessSnack(String identifier) => '📂 تم استدعاء البيانات وتحديثات المراحل المحفوظة للشحنة ($identifier) بنجاح!';
  @override String cargoShippingSaveContainerMilestoneSuccess(String containerNo, String status) => '💾 تم حفظ وتحديث مرحلة الحاوية ($containerNo) بنجاح! الحالة: $status';
  @override String cargoShippingSaveLclMilestoneSuccess(String status) => '💾 تم حفظ وتحديث مرحلة الشحن الجزئي بنجاح! الحالة: $status';
  @override String get cargoShippingAutoCompleteSuccess => '⚡ تم استيفاء دورة التحميل ودخول الميناء لجميع الحاويات بنجاح!';
  @override String cargoShippingStudySaveSuccess(String code) => '✅ تم حفظ وتحديث دراسة ومتابعة ملف الاستيراد ($code) بنجاح!';
  @override String get cargoShippingDraftSaveSuccess => '💾 تم الحفظ المؤقت بنجاح (Draft)! تم الاحتفاظ بالبيانات ويمكنك استكمال المراحل في أي وقت.';
  @override String cargoShippingRestoreSuccess(String code) => '♻️ تم استعادة سجل متابعة الشحن ($code) بنجاح!';
  @override String cargoShippingDeleteSuccess(String code) => '🗑️ تم حذف سجل الشحن ($code) منطقياً.';
  @override String get cargoShippingDeleteConfirmTitle => 'تأكيد الحذف المنطقي لسجل الشحن';
  @override String cargoShippingDeleteConfirmMessage(String code, String fileCode) => 'هل أنت متأكد من حذف سجل الشحن ($code) لملف الاستيراد ($fileCode)؟\n\nيمكنك استعادته أو إعادة تفعيله في أي وقت من خلال تعديله أو عبر زر الاستعادة.';
  @override String get cargoShippingConfirmDeleteBtn => 'تأكيد الحذف';
  @override String get cargoShippingDuplicateWarningTitle => 'تنبيه عدم التكرار أو تعارض الحاوية';
  @override String get cargoShippingGoToSavedRegistry => 'الانتقال لسجل المتابعة المحفوظ';
  @override String get cargoShippingDateSequenceError => '⚠️ لا يمكن اختيار تاريخ ووقت يسبق توقيت المرحلة السابقة في التسلسل الزمني!';
  @override String get cargoShippingSelectFileFirstForContainer => '⚠️ يرجى اختيار ملف الشحنة الاستيرادية المربوط أولاً في الخطوة 1 قبل حفظ تحديثات الحاوية.';
  @override String get cargoShippingSelectFileFirstForLcl => '⚠️ يرجى اختيار ملف الشحنة الاستيرادية المربوط أولاً في الخطوة 1 قبل حفظ تحديثات الشحن الجزئي.';
  @override String cargoShippingQuickSaveError(String msg) => '❌ تعذر الحفظ المؤقت للمرحلة: $msg';
  @override String cargoShippingLclSaveError(String msg) => '❌ تعذر حفظ مرحلة الشحن الجزئي المشترك: $msg';
  @override String get cargoShippingFillRequiredFields => 'يرجى التأكد من تعبئة جميع الحقول المطلوبة.';
  @override String get cargoShippingSelectLinkedFilePrompt => 'يرجى اختيار ملف الشحنة الاستيرادية المربوط أولاً.';
  @override String get cargoShippingStatusGatedIn => 'دخلت الميناء';
  @override String get cargoShippingStatusLoadingCompleted => 'اكتمل التحميل';
  @override String get cargoShippingStatusLoadingInProgress => 'جاري التحميل';
  @override String get cargoShippingStatusArrivedAtSupplier => 'وصلت لدى المورد';
  @override String get cargoShippingStatusArrivedAtCfs => 'وصلت لمخزن التجميع المشترك';
  @override String get cargoShippingStatusAssigned => 'تم التخصيص';
  @override String get cargoShippingStatusPendingAssignment => 'قيد التخصيص';
  @override String get cargoShippingAiExtractorBtn => 'المحلل الذكي للبوالص والفواتير';
  @override String get cargoShippingExportManifestBtn => 'نسخ بيان الحاويات والشحن';
  @override String get cargoShippingManifestCopySuccess => 'تم نسخ بيان تفاصيل الحاويات والأوزان المعتمدة بنجاح!';
  @override String get cargoShippingCopyFieldTooltip => 'نسخ القيمة للحافظة';
  @override String get cargoShippingAcidPrefix => 'القيد الجمركي المبدئي';
  @override String get cargoShippingManifestHeader => 'بيان تخصيص الحاويات والوزن الإجمالي المعتمد للشحن';
  @override String get cargoShippingColUnitNumber => 'م';
  @override String get cargoShippingColContainerNo => 'رقم الحاوية';
  @override String get cargoShippingColContainerType => 'نوع الحاوية';
  @override String get cargoShippingColSealNo => 'رقم القفل الملاحي';
  @override String get cargoShippingColGrossWeight => 'الوزن الإجمالي (كجم)';
  @override String get cargoShippingColVgmStatus => 'حالة التحقق من الوزن';
  @override String get cargoShippingColVgmRef => 'مرجع الوزن المعتمد';
  @override String get cargoShippingColTrackingStatus => 'حالة التتبع';

  // Screen 52: Cargo Shipping 48h SLA Tracking & Export Toolbar
  @override String get cargoShippingSlaStageTitle => 'متابعة حركة الشحن وتحميل وتوريد الحاويات والتتبع الزمني 48 ساعة';
  @override String get cargoShippingSlaExportTsvBtn => 'تصدير جدول نصوص';
  @override String get cargoShippingSlaExportExcelBtn => 'تصدير جدول إكسيل';
  @override String get cargoShippingSlaPrintPdfBtn => 'طباعة وحفظ مستند';
  @override String get cargoShippingSlaCopyDossierBtn => 'نسخ الملخص الشامل';
  @override String get cargoShippingSlaCopyDossierSuccess => 'تم نسخ ملخص تتبع الشحن والتوريد للحافظة';
  @override String get cargoShippingSlaDossierHeader => 'ملخص متابعة حركة الشحن وتحميل الحاويات والتتبع الزمني 48 ساعة';
  @override String get cargoShippingSlaExportTsvDialogTitle => 'حفظ جدول نصوص تتبع الشحن';
  @override String get cargoShippingSlaExportExcelDialogTitle => 'حفظ جدول إكسيل تتبع الشحن';
  @override String get cargoShippingSlaTsvHeaderUnit => 'م';
  @override String get cargoShippingSlaTsvHeaderContainerNo => 'رقم الحاوية';
  @override String get cargoShippingSlaTsvHeaderContainerType => 'نوع الحاوية';
  @override String get cargoShippingSlaTsvHeaderSealNo => 'رقم السيل والرصاص';
  @override String get cargoShippingSlaTsvHeaderAssignmentDate => 'تاريخ التخصيص';
  @override String get cargoShippingSlaTsvHeaderArrivalDate => 'تاريخ الوصول للمورد';
  @override String get cargoShippingSlaTsvHeaderLoadingStartDate => 'بدء التحميل';
  @override String get cargoShippingSlaTsvHeaderLoadingEndDate => 'انتهاء التحميل';
  @override String get cargoShippingSlaTsvHeaderPortGateInDate => 'دخول الميناء';
  @override String get cargoShippingSlaTsvHeaderSlaStatus => 'حالة المهلة 48 ساعة';
  @override String get cargoShippingSlaTsvHeaderTrackingStatus => 'حالة التتبع';
  @override String get cargoShippingSlaTsvHeaderNotes => 'ملاحظات التحميل';
  @override String get cargoShippingSlaSummaryHeader => 'مؤشرات تتبع الشحن والمهلة الزمنية';
  @override String get cargoShippingSlaCopyContainerSuccess => 'تم نسخ رقم الحاوية';
  @override String get cargoShippingSlaCopySealSuccess => 'تم نسخ رقم السيل';
  @override String get cargoShippingSlaCopyMilestoneSuccess => 'تم نسخ تفاصيل المرحلة';

  // Screen 28: Warehouse Receiving & Inspection (GRN)
  @override String get searchAndCloneWarehouseReceivingBtn => 'بحث واستنساخ إذن إضافة سابق';
  @override String get cloneWarehouseReceivingDialogTitle => 'استنساخ إذن إضافة وفحص مخزني (GRN)';
  @override String get cloneWarehouseReceivingDialogSubtitle => 'اختر إذن إضافة مخزني سابق لنسخ تفاصيل الأصناف وكميات الفحص كمسودة جديدة';
  @override String get cloneWarehouseReceivingTooltip => 'استنساخ إذن الإضافة كمسودة جديدة';
  @override String get copyWarehouseReceivingRowSuccess => 'تم نسخ بيانات إذن الإضافة (GRN) إلى الحافظة';
  @override String get copyWarehouseReceivingTableSuccess => 'تم نسخ جدول أذون الإضافة المخزنية إلى الحافظة';
  @override String get exportWarehouseReceivingExcelTooltip => 'تصدير سجل أذون الإضافة إلى Excel';
  @override String get exportWarehouseReceivingPdfTooltip => 'تصدير سجل أذون الإضافة إلى PDF';
  @override String get warehouseReceivingStageTitle => 'استلام البضائع بالمخازن وفحص الجودة';
  @override String get warehouseReceivingTabRegistry => 'سجل أذون الإضافة المخزنية';
  @override String get warehouseReceivingTabNewEntry => 'إنشاء إذن استلام وفحص مخزني';
  @override String get warehouseReceivingRefreshTooltip => 'تحديث البيانات';
  @override String get warehouseReceivingNewGrnBtn => 'تسجيل وصول شاحنة واستلام محضر جديد';
  @override String get warehouseReceivingSearchHint => 'بحث برقم الإذن، الشاحنة، السائق...';
  @override String get warehouseReceivingStatusAll => 'جميع الحالات';
  @override String get warehouseReceivingStatusDraft => 'مسودة مؤقتة (بانتظار العد)';
  @override String get warehouseReceivingStatusGoodsReceived => 'تم الاستلام النهائي بالمخزن';
  @override String get warehouseReceivingStatusDiscrepancy => 'مُثبت به عجز أو تلف جمركي';
  @override String get warehouseReceivingEmptyRecords => 'لا توجد سجلات استلام بمخازن الشركة حالياً.';
  @override String get warehouseReceivingTruckAndDriver => 'الشاحنة والسائق';
  @override String get warehouseReceivingArrivalDatetime => 'تاريخ ووقت الوصول';
  @override String get warehouseReceivingInspector => 'مسئول الاستلام والجودة';
  @override String get warehouseReceivingDiscrepancyStatus => 'حالة الفروق';
  @override String get warehouseReceivingMetricInvoiced => 'الفاتورة';
  @override String get warehouseReceivingMetricAccepted => 'المقبول';
  @override String get warehouseReceivingMetricShortage => 'العجز';
  @override String get warehouseReceivingMetricDamaged => 'التلف';
  @override String get warehouseReceivingConfirmFinalReceiptBtn => 'تأكيد الاستلام النهائي للمخزن';
  @override String get warehouseReceivingRecordDiscrepancyBtn => 'إثبات عجز أو تلف';
  @override String warehouseReceivingPrintGrnSnack(String grn, String wh) => 'طباعة محضر استلام البضاعة: $grn ($wh)';
  @override String get warehouseReceivingDeleteTitle => 'حذف محضر الاستلام';
  @override String get warehouseReceivingDeleteConfirmMessage => 'هل أنت متأكد من نقل محضر الاستلام للمحذوفات؟';
  @override String get warehouseReceivingViewTooltip => 'عرض محضر الاستلام';
  @override String get warehouseReceivingEditTooltip => 'تعديل محضر الاستلام';
  @override String get warehouseReceivingPrintTooltip => 'طباعة محضر الاستلام';
  @override String get warehouseReceivingDeleteTooltip => 'حذف محضر الاستلام (حذف منطقي)';
  @override String get warehouseReceivingSealIntact => 'الرصاص أصل وسليم';
  @override String get warehouseReceivingSealBroken => 'الرصاص تالف أو مكسور';
  @override String get warehouseReceivingConfirmReceiptTitle => 'تأكيد الاستلام النهائي للمخزن';
  @override String warehouseReceivingConfirmReceiptMessage(String grn) => 'هل تريد تأكيد الاستلام النهائي للشحنة رقم [$grn] بالمخزن؟\n\n⚠️ هذا الإجراء سيقوم بتثبيت الكميات الفعلية وإغلاق المحضر وخصم رصيد الشحنة من تقرير البضاعة في الطريق.';
  @override String get warehouseReceivingConfirmReceiptBtn => 'نعم، تأكيد الاستلام النهائي';
  @override String warehouseReceivingConfirmReceiptSuccess(String grn) => 'تم تأكيد الاستلام النهائي لـ $grn وخصم رصيد البضاعة بالطريق بنجاح';
  @override String warehouseReceivingConfirmReceiptError(String error) => 'خطأ أثناء تأكيد الاستلام: $error';
  @override String get warehouseReceivingNewDialogTitle => 'تسجيل محضر استلام شحنة جديدة بالمخزن';
  @override String get warehouseReceivingEditDialogTitle => 'تعديل بيانات المحضر وتأكيد الاستلام';
  @override String get warehouseReceivingDispatchAlertTitle => 'تنبيه إداري عاجل:';
  @override String get warehouseReceivingDispatchAlertDesc => 'يجب إرسال أوراق الشحنة المعتمدة (قائمة التعبئة والفاتورة التجارية) فوراً إلى مسؤولي المخزن لمطابقة البضائع عند وصول الشاحنة.';
  @override String get warehouseReceivingDispatchSentBtn => 'تم الإرسال للمخزن';
  @override String get warehouseReceivingDispatchSendBtn => 'إرسال إشعار للمخزن وتوليد مهمة';
  @override String get warehouseReceivingDispatchSuccessSnack => 'تم إرسال إشعار المستندات وتوليد مهمة ذكية في لوحة العمليات لمسؤولي المخزن بنجاح';
  @override String get warehouseReceivingImportFileLabel => 'ملف الشحنة الاستيرادية *';
  @override String get warehouseReceivingSelectFileValidator => 'يرجى اختيار ملف الشحنة';
  @override String get warehouseReceivingWarehouseNameLabel => 'اسم المخزن والفرع *';
  @override String get warehouseReceivingWarehouseNameValidator => 'يرجى إدخال اسم المخزن';
  @override String get warehouseReceivingTruckPlateLabel => 'رقم الشاحنة واللوحة';
  @override String get warehouseReceivingDriverNameLabel => 'اسم السائق';
  @override String get warehouseReceivingSealNumberLabel => 'رقم السيل والرصاص الأمني';
  @override String get warehouseReceivingSealIntactSwitch => 'سلامة السيل';
  @override String get warehouseReceivingMultiPoHeader => 'بيانات جرد واختبار كميات الأصناف تفصيلياً بكل أمر شراء:';
  @override String get warehouseReceivingAddItemBtn => 'إضافة صنف';
  @override String warehouseReceivingPoLabel(String po) => 'أمر الشراء: $po';
  @override String get warehouseReceivingItemNameLabel => 'اسم وبيان الصنف';
  @override String get warehouseReceivingInvoicedQtyLabel => 'العدد بالفاتورة';
  @override String get warehouseReceivingAcceptedQtyLabel => 'المستلم الفعلي';
  @override String get warehouseReceivingShortageQtyLabel => 'العجز';
  @override String get warehouseReceivingDamagedQtyLabel => 'التلف';
  @override String get warehouseReceivingSamplesQtyLabel => 'عينات مسحوبة';
  @override String get warehouseReceivingSaveDraftBtn => 'حفظ مؤقت (مسودة بانتظار العد)';
  @override String get warehouseReceivingSaveFinalBtn => 'تأكيد الاستلام النهائي للمخزن';
  @override String get warehouseReceivingDraftSuccessSnack => 'تم حفظ المحضر كمسودة مؤقتة بانتظار العد الفعلي للمخزن';
  @override String get warehouseReceivingFinalSuccessSnack => 'تم تأكيد الاستلام النهائي للمخزن وخصم رصيد البضاعة بالطريق بنجاح';
  @override String warehouseReceivingDiscrepancyDialogTitle(String grn) => 'إثبات عجز وتلف رسمي لمحضر: $grn';
  @override String get warehouseReceivingDiscrepancyTypeLabel => 'نوع التباين والعجز *';
  @override String get warehouseReceivingDiscrepancyTypeShortageAndDamage => 'عجز وتلف كلي';
  @override String get warehouseReceivingDiscrepancyTypeShortageOnly => 'عجز طرود فقط';
  @override String get warehouseReceivingDiscrepancyTypeDamageOnly => 'تلف وكسر بضائع فقط';
  @override String get warehouseReceivingDiscrepancyTypeBrokenSeal => 'كسر سيل وتباين مشمول';
  @override String get warehouseReceivingDiscrepancyNotesLabel => 'ملاحظات وتفاصيل الفحص *';
  @override String get warehouseReceivingDiscrepancyNotesValidator => 'يرجى كتابة الملاحظات';
  @override String get warehouseReceivingQuarantineSwitch => 'عزل البضاعة في منطقة الحجر';
  @override String get warehouseReceivingInsuranceClaimSwitch => 'رفع مطالبة تعويض تأمين بحري';
  @override String get warehouseReceivingClaimRefLabel => 'رقم مرجع المطالبة التأمينية';
  @override String get warehouseReceivingCertifyDiscrepancyBtn => 'اعتماد محضر العجز والتلف';
  @override String get warehouseReceivingDiscrepancySuccessSnack => 'تم توثيق محضر العجز والتلف بنجاح';
  @override String get warehouseReceivingQuarantineLockBadge => 'محظور الصرف: تحت التحفظ الجمركي';
  @override String get warehouseReceivingQuarantineStatusBlocked => 'محظور الصرف (تحت التحفظ)';
  @override String get warehouseReceivingQuarantineStatusCheck => 'فحص صلاحية الصرف';
  @override String get warehouseReceivingQuarantineAlertBlocked => 'محظور الصرف: البضاعة تحت التحفظ الجمركي المعملي لحين صدور نتيجة الفحص الإيجابية.';
  @override String get warehouseReceivingQuarantineAlertCleared => 'البضاعة مفرج عنها نهائياً ومصرح بصرفها وتشغيلها بالمصنع.';
  @override String get warehouseReceivingExportTsvBtn => 'تصدير جدول أذون الاستلام كجدول بيانات';
  @override String get warehouseReceivingExportTsvSuccess => 'تم نسخ بيانات أذون الاستلام الفعلي إلى الحافظة بتنسيق جدول بيانات بنجاح';
  @override String get warehouseReceivingCopyFieldTooltip => 'نسخ القيمة';
  @override String warehouseReceivingPrintReceiptSuccess(String grn) => 'تم نسخ محضر استلام البضاعة $grn إلى الحافظة بنجاح';
  @override String get warehouseReceivingColGrnCode => 'رقم إذن الاستلام';
  @override String get warehouseReceivingColWarehouse => 'المخزن';
  @override String get warehouseReceivingColStatus => 'الحالة';
  @override String get warehouseReceivingColQuarantine => 'الحجر الجمركي';
  @override String get warehouseReceivingColTruckDriver => 'السائق والشاحنة';
  @override String get warehouseReceivingColArrivalDate => 'تاريخ الوصول';
  @override String get warehouseReceivingColInspector => 'مسئول الاستلام';
  @override String get warehouseReceivingColDiscrepancy => 'حالة الفروق';
  @override String get warehouseReceivingColInvoicedQty => 'الكمية بالفاتورة';
  @override String get warehouseReceivingColAcceptedQty => 'الكمية المقبولة';
  @override String get warehouseReceivingColShortageQty => 'كمية العجز';
  @override String get warehouseReceivingColDamagedQty => 'كمية التلف';

  // ==========================================
  // Screen 29: Landed Cost Settlement (FinancialSettlementScreen & OdooJournalEntryDialog)
  // ==========================================
  @override String get searchAndCloneFinancialSettlementBtn => 'بحث واستنساخ تسوية تكلفة سابقة';
  @override String get cloneFinancialSettlementDialogTitle => 'استنساخ تسوية تكلفة الوصول';
  @override String get cloneFinancialSettlementDialogSubtitle => 'إنشاء مسودة تسوية جديدة مستنسخة مع تصفير المعرفات وإعادة الضبط';
  @override String get cloneFinancialSettlementTooltip => 'استنساخ هذه التسوية كمسودة جديدة';
  @override String get copyFinancialSettlementRowSuccess => 'تم نسخ بيانات التسوية المحددة إلى الحافظة';
  @override String get copyFinancialSettlementTableSuccess => 'تم نسخ جدول تسويات التكلفة إلى الحافظة';
  @override String get exportFinancialSettlementExcelTooltip => 'تصدير سجل التسويات إلى Excel';
  @override String get exportFinancialSettlementPdfTooltip => 'تصدير سجل التسويات إلى PDF';
  @override String get financialSettlementStageTitle => 'التسوية المالية وتكلفة البند النهائي';
  @override String get financialSettlementTabRegistry => 'سجل تسويات تكلفة الوصول';
  @override String get financialSettlementTabNewEntry => 'احتساب وتسوية تكلفة شحنة جديدة';
  @override String get financialSettlementRefreshTooltip => 'تحديث البيانات';
  @override String get financialSettlementNewSettlementBtn => 'تسجيل فواتير مصاريف واحتساب تكلفة الوصول';
  @override String get financialSettlementSearchHint => 'بحث برقم التسوية، اسم المحاسب...';
  @override String get financialSettlementFetchError => 'خطأ في جلب بيانات التسوية المالية:';
  @override String get financialSettlementEmptyRecords => 'لا توجد تسويات مالية لتكلفة الوصول مسجلة حالياً.';
  @override String financialSettlementAccountantLabel(String accountant) => 'المحاسب: $accountant';
  @override String get financialSettlementStatusDraft => 'مسودة مؤقتة';
  @override String get financialSettlementStatusCalculated => 'مُحتسب وموزع';
  @override String get financialSettlementStatusApproved => 'معتمد نهائياً';
  @override String get financialSettlementMetricFobTotal => 'إجمالي قيمة فاتورة الشراء';
  @override String get financialSettlementMetricExpensesTotal => 'إجمالي المصاريف والنولون';
  @override String get financialSettlementMetricLandedCostTotal => 'تكلفة الوصول الشاملة';
  @override String get financialSettlementMetricMarkupFactor => 'معامل زيادة التكلفة';
  @override String get financialSettlementExpensesSectionHeader => '1️⃣ فواتير ومصاريف الاستيراد المسجلة:';
  @override String get financialSettlementColInvoiceNo => 'رقم الفاتورة';
  @override String get financialSettlementColCategory => 'نوع البند والتصنيف';
  @override String get financialSettlementColProvider => 'المورد ومقدم الخدمة';
  @override String get financialSettlementColAmountFx => 'المبلغ بالعملة الأجنبية';
  @override String get financialSettlementColExchangeRate => 'سعر الصرف';
  @override String get financialSettlementColAmountEgp => 'المبلغ بالجنيه';
  @override String get financialSettlementColAllocationRule => 'قاعدة التوزيع';
  @override String get financialSettlementCategoryFreight => 'نولون شحن';
  @override String get financialSettlementCategoryCustomsDuty => 'ضرائب وجمارك';
  @override String get financialSettlementCategoryBrokerage => 'أتعاب تخليص';
  @override String get financialSettlementCategoryLocalTransport => 'نقل بري وداخلي';
  @override String get financialSettlementCategoryStorage => 'أرضيات وتخزين';
  @override String get financialSettlementRuleVolumeBased => 'حسب الحجم';
  @override String get financialSettlementRuleValueBased => 'حسب القيمة';
  @override String get financialSettlementRuleWeightBased => 'حسب الوزن الإجمالي';
  @override String get financialSettlementRuleEqual => 'بالتساوي';
  @override String get financialSettlementItemsSectionHeader => '2️⃣ جدول تكلفة الوصول للوحدة وتوزيع المصاريف:';
  @override String get financialSettlementColItemCode => 'كود الصنف';
  @override String get financialSettlementColItemName => 'اسم الصنف';
  @override String get financialSettlementColQty => 'الكمية';
  @override String get financialSettlementColFobUnit => 'سعر الوحدة بفاتورة الشراء';
  @override String get financialSettlementColAllocatedFreight => 'نولون مخصص';
  @override String get financialSettlementColAllocatedCustoms => 'جمارك مخصصة';
  @override String get financialSettlementColAllocatedClearance => 'تخليص مخصص';
  @override String get financialSettlementColAllocatedTransport => 'نقل مخصص';
  @override String get financialSettlementColUnitLandedCost => 'تكلفة الوصول للوحدة';
  @override String get financialSettlementColMarkupFactor => 'معامل الزيادة';
  @override String get financialSettlementExportOdooBtn => '📒 تصدير قيد اليومية للنظام المالي';
  @override String get financialSettlementRecalculateBtn => 'إعادة احتساب التكاليف';
  @override String financialSettlementRecalculateSuccessSnack(String code) => 'تمت إعادة توزيع التكاليف لسجل التسوية: $code بنجاح';
  @override String financialSettlementPrintSnack(String code, String total) => 'طباعة كشف ومطابقة تكلفة الوصول: $code (الإجمالي: $total ج.م)';
  @override String get financialSettlementViewTooltip => 'عرض تفاصيل التسوية';
  @override String get financialSettlementEditTooltip => 'تعديل وإعادة احتساب';
  @override String get financialSettlementPrintTooltip => 'طباعة كشف تكلفة الوصول';
  @override String get financialSettlementDeleteTooltip => 'حذف سجل التسوية';
  @override String get financialSettlementDeleteTitle => 'حذف سجل التسوية';
  @override String get financialSettlementDeleteMessage => 'هل أنت متأكد من نقل سجل التسوية المالية للمحذوفات؟';
  @override String get financialSettlementDialogTitle => 'تسجيل مصاريف وبنود شحنة لاحتساب تكلفة الوصول';
  @override String get financialSettlementImportFileLabel => 'ملف الشحنة الاستيرادية *';
  @override String get financialSettlementImportFileSearchHint => 'ابحث عن ملف الشحنة بالرقم أو اسم الشركة...';
  @override String get financialSettlementImportFileValidator => 'يرجى اختيار ملف الشحنة';
  @override String get financialSettlementExpenseSectionHeader => 'بيانات فاتورة المصروف والخدمات اللوجستية:';
  @override String get financialSettlementInvoiceNoLabel => 'رقم الفاتورة *';
  @override String get financialSettlementCategoryLabel => 'فئة المصروف *';
  @override String get financialSettlementCategorySearchHint => 'ابحث عن فئة المصروف...';
  @override String get financialSettlementProviderNameLabel => 'اسم مورد الخدمة *';
  @override String get financialSettlementAmountFxLabel => 'المبلغ بالعملة الأجنبية';
  @override String get financialSettlementExchangeRateLabel => 'سعر الصرف';
  @override String get financialSettlementAllocationRuleLabel => 'قاعدة توزيع المصروف على الأصناف *';
  @override String get financialSettlementAllocationRuleSearchHint => 'ابحث عن قاعدة التوزيع...';
  @override String get financialSettlementItemSectionHeader => 'بيانات صنف الشحنة والاستيراد:';
  @override String get financialSettlementItemCodeLabel => 'كود الصنف';
  @override String get financialSettlementItemNameLabel => 'اسم الصنف';
  @override String get financialSettlementQtyReceivedLabel => 'الكمية المستلمة';
  @override String get financialSettlementFobUnitPriceLabel => 'سعر الفاتورة للوحدة بالجنيه';
  @override String get financialSettlementLiveReloadBtn => 'إعادة تحميل حية';
  @override String get financialSettlementResetFormBtn => 'تفريغ وبدء تسجيل جديد';
  @override String get financialSettlementSaveAndAllocateBtn => 'حفظ وتوزيع بنود المصروف';
  @override String financialSettlementSaveError(String error) => 'خطأ أثناء حفظ وحساب التسوية: $error';
  @override String get odooJournalLoading => 'جارٍ إعداد وتوليد قيد اليومية المزدوج المتوازن للنظام المحاسبي...';
  @override String odooJournalFetchError(String error) => 'خطأ أثناء جلب القيد: $error';
  @override String odooJournalTitle(String code) => 'قيد اليومية المحاسبي المزدوج وتصدير النظام المالي ($code)';
  @override String odooJournalSubtitle(String fileCode, String ref) => 'ملف الاستيراد: $fileCode | المرجع: $ref';
  @override String get odooJournalBalanced => '🟢 قيد متوازن 100% (المدين = الدائن)';
  @override String odooJournalUnbalanced(String diff) => '🔴 غير متوازن (فارق: $diff ج.م)';
  @override String get odooJournalMetaImporter => 'الشركة المستوردة';
  @override String get odooJournalMetaSupplier => 'المورد الأجنبي';
  @override String get odooJournalMetaProject => 'المشروع أو الحساب التحليلي';
  @override String get odooJournalMetaDate => 'تاريخ القيد';
  @override String get odooJournalMetaTotalDebitCredit => 'إجمالي المدين والدائن';
  @override String get odooJournalLinesSectionHeader => 'تفاصيل بنود القيد المحاسبي المزدوج:';
  @override String get odooJournalColAccountCode => 'رقم الحساب';
  @override String get odooJournalColAccountName => 'اسم الحساب الدفتري';
  @override String get odooJournalColPartner => 'الطرف أو الشريك';
  @override String get odooJournalColLabel => 'بيان وشرح القيد';
  @override String get odooJournalColDebit => 'مدين (ج.م)';
  @override String get odooJournalColCredit => 'دائن (ج.م)';
  @override String get odooJournalColForeignCurrency => 'العملة الأجنبية';
  @override String get odooJournalColCostCategory => 'تصنيف التكلفة';
  @override String get odooJournalExportCsvBtn => '📥 تحميل ملف البيانات المجدولة الجاهز للاستيراد';
  @override String get odooJournalExportExcelBtn => '📊 تحميل كشف جدول البيانات المحاسبي التفصيلي';
  @override String odooJournalExportingSnack(String filename, String directUrl) => 'جارٍ التصدير: $filename\nالرابط المباشر: $directUrl';
  @override String get financialSettlementCopyFieldTooltip => 'نسخ القيمة للحافظة';
  @override String get financialSettlementExportTsvBtn => 'تصدير كشف التسويات (جدول بيانات)';
  @override String get financialSettlementExportTsvSuccess => 'تم نسخ كشف التسويات المالية بنجاح للحافظة بصيغة جدول بيانات';
  @override String get financialSettlementCopyBreakdownTsvBtn => 'نسخ تفاصيل التكلفة';
  @override String get financialSettlementCopyBreakdownSuccess => 'تم نسخ تفاصيل تكلفة الوصول وتوزيع المصاريف بنجاح';
  @override String get financialSettlementPrintSummarySuccess => 'تم نسخ تقرير وملخص تكلفة الوصول للحافظة بنجاح';
  @override String get financialSettlementCurrencyEgp => 'ج.م';
  @override String get odooJournalCopyTsvBtn => 'نسخ القيد المحاسبي (جدول)';
  @override String get odooJournalCopyTsvSuccess => 'تم نسخ قيود اليومية بنجاح بصيغة جدول بيانات';
  @override String get odooJournalSaveCsvDialogTitle => 'حفظ قيود اليومية للنظام المالي بصيغة ملف بيانات';
  @override String get odooJournalSaveExcelDialogTitle => 'حفظ مستند القيد والتكلفة الإجمالية بصيغة كشف حساب';
  @override String get odooJournalCatGoods => 'بضائع';
  @override String get odooJournalCatFreight => 'شحن';
  @override String get odooJournalCatCustoms => 'جمارك';
  @override String get odooJournalCatClearance => 'تخليص';
  @override String get odooJournalCatTransport => 'نقل';
  @override String get odooJournalCatDemurrage => 'غرامات';
  @override String get odooJournalCatPriceAdjustment => 'تسوية سعر';

  // ---------------------------------------------------------------------------
  // Screen 30: File Closure & Archival
  // ---------------------------------------------------------------------------
  @override String get searchAndCloneFileClosureBtn => 'بحث واستنساخ أرشفة سابقة';
  @override String get cloneFileClosureDialogTitle => 'استنساخ شهادة إغلاق وأرشفة ملف (مسودة)';
  @override String get cloneFileClosureDialogSubtitle => 'تكرار سجل إغلاق وأرشفة شحنة سابق إلى مسودة جديدة مع تصفير المعرفات الحساسة.';
  @override String get cloneFileClosureTooltip => 'استنساخ شهادة الإغلاق هذه كمسودة جديدة';
  @override String get copyFileClosureRowSuccess => 'تم نسخ بيانات شهادة إغلاق الملف كجدول بنجاح';
  @override String get copyFileClosureTableSuccess => 'تم نسخ سجل الملفات المؤرشفة بالكامل كجدول بنجاح';
  @override String get exportFileClosureExcelTooltip => 'تصدير سجل الشحنات المؤرشفة إلى Excel';
  @override String get exportFileClosurePdfTooltip => 'تصدير سجل الشحنات المؤرشفة إلى PDF';
  @override String get fileClosureStageTitle => 'إغلاق الملف والأرشفة التاريخية';
  @override String get fileClosureTabArchivedRegistry => 'سجل الملفات المغلقة والمؤرشفة';
  @override String get fileClosureTabCloseFile => 'إغلاق وأرشفة ملف شحنة';
  @override String get fileClosureRefreshTooltip => 'تحديث البيانات';
  @override String get fileClosureNewCertificateBtn => 'إصدار شهادة إغلاق وأرشفة شحنة نهائياً';
  @override String get fileClosureSearchHint => 'بحث بكود الشهادة، المراجع...';
  @override String get fileClosureFetchError => 'خطأ في جلب بيانات أرشيف الشحنات:';
  @override String get fileClosureEmptyRecords => 'لا توجد شحنات مغلقة ومؤرشفة نهائياً حالياً.';
  @override String fileClosureClosedFilesBannerTitle(int count) => 'سجل الشحنات المغلقة مسبقاً ($count شحنة مغلقة بالأرشيف):';
  @override String get fileClosureClosedBadge => 'مغلق';
  @override String fileClosureStopReason(String reason) => 'سبب الإيقاف: $reason';
  @override String get fileClosureReopenBtn => 'إعادة فتح وتنشيط الشحنة';
  @override String fileClosureFileRefLabel(int id) => 'ملف الشحنة المرجعي: #$id';
  @override String fileClosureVaultLabel(String location) => 'مستودع الأرشيف: $location';
  @override String get fileClosureStatusBadgeClosed => 'مغلق ومؤرشف بالكامل (100%)';
  @override String get fileClosureChecklistHeader => 'شروط الإغلاق المكتملة:';
  @override String get fileClosureChecklistDocsOriginals => 'المستندات الأصلية والتبادل الرقمي';
  @override String get fileClosureChecklistCustomsCleared => 'الإفراج الجمركي ونموذج 46';
  @override String get fileClosureChecklistWarehouseGrn => 'فحص واستلام المخازن';
  @override String get fileClosureChecklistLandedCost => 'التسوية المالية وتكلفة الوصول';
  @override String get fileClosureChecklistTasksClosed => 'إغلاق المهام التشغيلية';
  @override String fileClosureArchivalNotes(String notes) => 'ملاحظات الأرشيف: $notes';
  @override String fileClosureAuditorLabel(String auditor) => 'المراجع المسؤول: $auditor';
  @override String fileClosureCertificateDialogTitle(String code) => 'شهادة الإغلاق والأرشفة: $code';
  @override String fileClosureCertFileNo(int id) => 'رقم ملف الشحنة: #$id';
  @override String fileClosureCertLocation(String loc) => 'موقع الأرشيف: $loc';
  @override String fileClosureCertAuditor(String name) => 'المراجع: $name';
  @override String fileClosureCertClosedDate(String date) => 'تاريخ الإغلاق: $date';
  @override String fileClosureCertNotes(String notes) => 'الملاحظات: $notes';
  @override String fileClosureEditSnack(String code) => 'تعديل بيانات وأرشفة الملف: $code';
  @override String fileClosurePrintSnack(String code, int fileId) => 'طباعة شهادة الإغلاق الرسمي والأرشفة النهائية: $code (ملف #$fileId)';
  @override String get fileClosureDeleteTitle => 'حذف سجل الأرشفة';
  @override String get fileClosureDeleteMessage => 'هل أنت متأكد من نقل سجل الإغلاق للمحذوفات؟';
  @override String get fileClosureViewTooltip => 'عرض شهادة الإغلاق';
  @override String get fileClosureEditTooltip => 'تعديل الأرشفة';
  @override String get fileClosurePrintTooltip => 'طباعة شهادة الإغلاق والأرشفة';
  @override String get fileClosureDeleteTooltip => 'حذف سجل الإغلاق (حذف منطقي)';
  @override String get fileClosureDialogTitle => 'إصدار شهادة إغلاق وأرشفة شحنة نهائياً';
  @override String get fileClosureSelectImportFile => 'اختر ملف الشحنة للإغلاق النهائي *';
  @override String get fileClosureSelectImportFileHint => 'ابحث عن ملف الشحنة بالرقم أو اسم الشركة...';
  @override String get fileClosureSelectImportFileValidator => 'يرجى اختيار ملف الشحنة';
  @override String get fileClosureMandatoryChecklistHeader => 'قائمة التحقق الإلزامية للإغلاق:';
  @override String get fileClosureCheck1Docs => '1️⃣ استلام المستندات الأصلية والتبادل الإلكتروني';
  @override String get fileClosureCheck2Customs => '2️⃣ إتمام الإفراج الجمركي وسداد الضرائب والإيقاف الجمركي (إقرار 46)';
  @override String get fileClosureCheck3Warehouse => '3️⃣ استلام البضائع بالمخازن وإصدار إذن الإضافة';
  @override String get fileClosureCheck4LandedCost => '4️⃣ التسوية المالية وتوزيع المصاريف وحساب تكلفة الوصول';
  @override String get fileClosureCheck5Tasks => '5️⃣ إغلاق كافة المهام والتنبيهات المرتبطة بالشحنة';
  @override String get fileClosureAuditorNameLabel => 'اسم المراجع المسؤول *';
  @override String get fileClosureAuditorNameValidator => 'يلزم إدخال اسم المراجع';
  @override String get fileClosureVaultLocationLabel => 'مستودع الأرشيف الرقمي *';
  @override String get fileClosureArchivalNotesLabel => 'ملاحظات الأرشفة والتدقيق';
  @override String get fileClosureLiveReloadBtn => 'إعادة تحميل حية 🔄';
  @override String get fileClosureResetFormBtn => 'تفريغ وبدء تسجيل جديد 🔄';
  @override String get fileClosureCertifySubmitBtn => 'اعتماد الإغلاق والأرشفة النهائية ✅';
  @override String get fileClosureChecklistIncompleteWarning => 'تنبيه: يلزم اكتمال جميع البنود الـ 5 في قائمة التحقق لإغلاق الملف نهائياً.';
  @override String fileClosureSaveError(String error) => 'خطأ أثناء إغلاق وأرشفة الملف: $error';
  @override String get fileClosureCopyFieldTooltip => 'نسخ القيمة للحافظة';
  @override String get fileClosureExportTsvBtn => 'تصدير كشف الأرشيف (جدول بيانات)';
  @override String get fileClosureExportTsvSuccess => 'تم نسخ كشف سجل الأرشيف بنجاح للحافظة بصيغة جدول بيانات';
  @override String get fileClosureCopyCertTsvBtn => 'نسخ بيانات الشهادة';
  @override String get fileClosureCopyCertSuccess => 'تم نسخ بيانات شهادة الإغلاق والأرشفة للحافظة بنجاح';
  @override String fileClosurePrintSuccess(String code) => 'تم نسخ مستند شهادة الإغلاق الرسمي والأرشفة النهائية: $code للحافظة بنجاح';
  @override String fileClosureDraftSavedSuccess(String pct, int completed) => 'تم حفظ تقدم الإغلاق مؤقتاً بنجاح (نسبة الإنجاز: $pct% - $completed من 5 مهام)';
  @override String get fileClosureCertifiedSuccess => 'تم اعتماد وإصدار شهادة الإغلاق النهائي والأرشفة بنجاح!';
  @override String get fileClosureChecklistCompletionLabel => 'نسبة اكتمال المهام والأوراق الكلية:';
  @override String get fileClosureSaveDraftTip => '💡 يمكنك استخدام زر "حفظ كمسودة مؤقتة" لحفظ تقدم الإنجاز ومتابعة باقي الأوراق لاحقاً.';
  @override String get fileClosureSaveDraftBtn => 'حفظ كمسودة مؤقتة 💾';
  @override String get fileClosureColClosureCode => 'كود الإغلاق';
  @override String get fileClosureColImportFile => 'ملف الشحنة';
  @override String get fileClosureColArchiveVault => 'مستودع الأرشيف';
  @override String get fileClosureColAuditor => 'المراجع المسؤول';
  @override String get fileClosureColClosedDate => 'تاريخ الإغلاق';
  @override String get fileClosureColDocsVerified => 'المستندات الأصلية';
  @override String get fileClosureColCustomsCleared => 'الإفراج الجمركي';
  @override String get fileClosureColWarehouseReceived => 'استلام المخازن';
  @override String get fileClosureColLandedCostSettled => 'التسوية المالية';
  @override String get fileClosureColTasksClosed => 'إغلاق المهام';
  @override String get fileClosureColNotes => 'ملاحظات الأرشفة';

  // Reopen Shipment Dialog
  @override String reopenShipmentDialogTitle(String code) => 'إعادة فتح وتنشيط الشحنة ($code)';
  @override String reopenShipmentRestoredPhase(String phase) => 'المرحلة التي ستعود إليها الشحنة: $phase';
  @override String get reopenShipmentNotice => 'ملاحظة: سيتم إلغاء حالة الإغلاق وتغيير حالة الشحنة إلى نشطة وإعادتها بنفس البيانات والتفاصيل إلى المرحلة التشغيلية التي تم إيقافها عندها.';
  @override String get reopenShipmentReasonLabel => '* سبب إعادة فتح وتنشيط الشحنة والملاحظات التفصيلية';
  @override String get reopenShipmentReasonHint => 'اكتب هنا سبب استئناف وإعادة فتح الشحنة المغلقة مسبقاً...';
  @override String get reopenShipmentReasonValidatorEmpty => 'يرجى إدخال سبب إعادة فتح الشحنة.';
  @override String get reopenShipmentReasonValidatorMin => 'يجب ألا يقل سبب إعادة الفتح عن 3 حروف.';
  @override String reopenShipmentSuccessSnack(String code, String phase) => 'تم إعادة فتح وتنشيط الشحنة ($code) وإعادتها بنجاح لمرحلة ($phase)!';
  @override String reopenShipmentErrorSnack(String err) => 'حدث خطأ أثناء إعادة فتح الشحنة: $err';
  @override String get reopenShipmentConfirmBtn => 'تأكيد إعادة الفتح والتنشيط';

  // ---------------------------------------------------------------------------
  // Screen 31: Projects & Cost Centers
  // ---------------------------------------------------------------------------
  @override String get projectsScreenTitle => 'مشاريع الاستيراد ومراكز التكلفة';
  @override String get projectsScreenSubtitle => 'المرجع الأساسي لعمليات الاستيراد متعددة الشحنات ومتعددة الشركات';
  @override String get createNewProjectBtn => 'إنشاء مشروع جديد';
  @override String get projectsSearchHint => 'بحث بكود المشروع، الاسم، المسؤول...';
  @override String projectsFetchError(String error) => 'تعذر الاتصال بالسيرفر وجلب المشاريع:\n$error';
  @override String get noProjectsFound => 'لم يتم العثور على مشاريع استيراد.';
  @override String get projectCodeCol => 'كود المشروع';
  @override String get projectNameAndOwnerCol => 'اسم المشروع والمسؤول';
  @override String get companyAndSupplierCol => 'الشركة المستوردة والمورد';
  @override String get typeAndCategoryCol => 'النوع والتصنيف';
  @override String get budgetUsdCol => 'الميزانية بالدولار';
  @override String get capabilitiesCol => 'المحددات والمزايا';
  @override String projectOwnerLabel(String owner) => 'المسؤول: $owner';
  @override String projectCompanyFallback(int id) => 'الشركة #$id';
  @override String projectSupplierFallback(int id) => 'المورد #$id';
  @override String projectSupplierLabel(String supplier) => 'المورد: $supplier';
  @override String get projectCommitmentsLabel => 'الالتزامات';
  @override String get projectRemainingBudgetLabel => 'المتبقي من الميزانية';
  @override String projectMissingRateCurrencies(String currencies) => 'أسعار الصرف غير متوفرة لعملات: $currencies';
  @override String get projectUtilizationLabel => 'نسبة الاستهلاك';
  @override String get capMultiShipment => 'متعدد الشحنات';
  @override String get capMultiCompany => 'متعدد الشركات';
  @override String projectPrintSnack(String name, String code) => 'طباعة بيانات المشروع ومراكز التكلفة: $name ($code)';
  @override String get confirmActionTitle => 'تأكيد الإجراء';
  @override String confirmDeactivateProject(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل المشروع ($name)؟';
  @override String confirmActivateProject(String name) => 'هل أنت متأكد من إعادة تفعيل المشروع ($name)؟';
  @override String get deactivateBtn => 'إيقاف التفعيل';
  @override String get activateBtn => 'تفعيل';
  @override String get deactivateProjectTooltip => 'إيقاف تفعيل المشروع';
  @override String get activateProjectTooltip => 'إعادة تفعيل المشروع';
  @override String get createProjectDialogTitle => 'إنشاء مشروع استيراد جديد';
  @override String editProjectDialogTitle(String code) => 'تعديل المشروع ($code)';
  @override String get projectPrerequisitesMissing => 'يرجى التأكد من تهيئة الشركات المستوردة، الموردين، والشروط التجارية أولاً.';
  @override String get projectNameLabel => 'اسم المشروع *';
  @override String get projectNameHint => 'مثال: مشروع محطة الطاقة الشمسية بالسخنة - المرحلة الأولى';
  @override String get projectOwnerLabelField => 'مدير أو مسؤول المشروع *';
  @override String get projectOwnerHint => 'مثال: م. حسن محمود';
  @override String get importingCompaniesFieldLabel => 'الشركات المستوردة للمشروع *';
  @override String get primarySupplierLabel => 'المورد الرئيسي *';
  @override String get defaultIncotermLabel => 'شرط الشحن الدولي الافتراضي *';
  @override String get importTypeLabel => 'نوع الاستيراد *';
  @override String get priorityLabel => 'مستوى الأولوية *';
  @override String get projectStatusLabel => 'حالة المشروع *';
  @override String get allowedShipmentCategoriesLabel => 'أنواع الشحنات المتاحة للمشروع *';
  @override String get estTotalBudgetUsdLabel => 'الميزانية التقديرية بالدولار';
  @override String get estTotalBudgetUsdHint => 'مثال: 500000';
  @override String get targetEndDateLabel => 'تاريخ الانتهاء المستهدف';
  @override String get targetEndDateHint => 'YYYY-MM-DD';
  @override String get targetEndDateCol => 'الانتهاء المستهدف';
  @override String get allowMultiShipmentTitle => 'السماح بالشحن على دفعات متتابعة';
  @override String get allowMultiShipmentSubtitle => 'يسمح بتوزيع توريد المشروع على عدة شحنات ورسائل جمركية متتابعة';
  @override String get allowMultiCompanyTitle => 'السماح بتعدد الكيانات والشركات';
  @override String get allowMultiCompanySubtitle => 'يسمح بالتعامل مع عدة مخلصين وخطوط ملاحية وموردين فرعيين للمشروع';
  @override String get projectNotesLabel => 'ملاحظات ووصف المشروع';
  @override String get selectAtLeastOneCompanyError => 'يرجى اختيار شركة مستوردة واحدة على الأقل.';
  @override String get selectAtLeastOneCategoryError => 'يرجى اختيار نوع شحن واحد على الأقل.';
  @override String get createProjectSubmitBtn => 'إنشاء المشروع';
  @override String get saveChangesSubmitBtn => 'حفظ التعديلات';
  @override String get statusOnHold => 'قيد الانتظار';
  @override String get priorityUrgent => 'عاجل جداً';
  @override String get importTypeDirectCommercial => 'تجاري مباشر';
  @override String get importTypeFreeZone => 'منطقة حرة';
  @override String get importTypeTemporaryRelease => 'سماح مؤقت';
  @override String get importTypeDrawback => 'استرداد جمركي';
  @override String get importTypeProjectEquipment => 'معدات مشروعات';
  @override String get categoryFclContainer => 'حاوية كاملة';
  @override String get categoryLclBreakbulk => 'شحن بحري مجزأ';
  @override String get categoryAirFreight => 'شحن جوي';
  @override String get categoryBulkCargo => 'بضائع صب';
  @override String get categoryMultimodal => 'شحن متعدد الوسائط';
  @override String get categoryCourier => 'بريد سريع (Courier)';
  @override String get budgetCurrencyLabel => 'عملة الميزانية';
  @override String get projectsCopyFieldTooltip => 'نسخ البيانات';
  @override String get projectsExportTsvBtn => 'تصدير المشاريع (جدول)';
  @override String get projectsExportTsvSuccess => 'تم نسخ بيانات جميع المشاريع كجدول بنجاح';
  @override String get projectCopySummaryBtn => 'نسخ ملخص المشروع';
  @override String get projectCopySummarySuccess => 'تم نسخ بيانات وملخص المشروع إلى الحافظة بنجاح';
  @override String get projectBudgetNotSet => 'غير محدد';
  @override String get projectIncotermFallback => 'شرط الشحن';
  @override String get projectColActive => 'الحالة التشغيلية';
  @override String get projectColShipmentCategories => 'أنواع الشحن المتاحة';
  @override String get projectActiveYes => 'نشط';
  @override String get projectActiveNo => 'متوقف';
  @override String get projectMultiShipmentYes => 'نعم';
  @override String get projectMultiShipmentNo => 'لا';
  @override String get projectMultiCompanyYes => 'نعم';
  @override String get projectMultiCompanyNo => 'لا';
  @override String get projectNotesFallback => 'لا توجد ملاحظات';
  @override String get projectsToolbarTitle => 'المشاريع ومراكز التكلفة';

  // ── Screen 32: Egyptian Import Companies ──────────────────────────────────
  @override String get importCompaniesScreenTitle => 'الشركات المستوردة المصرية';
  @override String get importCompaniesScreenSubtitle => 'إدارة بيانات المستوردين والتراخيص الرسمية وتواريخ الصلاحية';
  @override String get includeDeactivatedLabel => 'عرض الشركات المتوقفة:';
  @override String get addImporterCompanyBtn => 'إضافة شركة مستوردة';
  @override String get searchImporterHint => 'بحث باسم المستورد، رقم القيد، أو رقم التسجيل الضريبي...';
  @override String importersFetchError(String error) => 'تعذر الاتصال بالسيرفر وجلب الشركات المستوردة:\n$error';
  @override String get retryConnectionBtn => 'إعادة المحاولة';
  @override String get noImportCompaniesFound => 'لم يتم العثور على شركات مستوردة.';
  @override String get statusActive => 'نشطة';
  @override String get statusInactive => 'متوقفة';
  @override String importerRowMeta(String importerId, String vatId, String regNumber) => 'بطاقة استيرادية: $importerId | ضريبي: $vatId | سجل: $regNumber';
  @override String get badgeImportId => 'البطاقة الاستيرادية';
  @override String get badgeVatExpiry => 'التسجيل الضريبي';
  @override String get badgeComReg => 'السجل التجاري';
  @override String get expiryExpired => 'منتهي الصلاحية';
  @override String expiryDaysLeft(int days) => 'متبقي $days يوم';
  @override String expiryValidDays(int days) => 'سارٍ ($days يوم)';
  @override String confirmDeactivateCompany(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل الشركة ($name)؟';
  @override String confirmActivateCompany(String name) => 'هل أنت متأكد من إعادة تفعيل الشركة ($name)؟';
  @override String get deactivateCompanyTooltip => 'إيقاف تفعيل الشركة';
  @override String get activateCompanyTooltip => 'إعادة تفعيل الشركة';
  @override String get editImporterCompanyTitle => 'تعديل بيانات الشركة المستوردة';
  @override String get addImporterCompanyTitle => 'إضافة شركة استيراد مصرية جديدة';
  @override String get closeDialogTooltip => 'إغلاق النافذة';
  @override String get companyNameLabel => 'اسم الشركة المستوردة *';
  @override String get companyNameHint => 'مثال: شركة الفراعنة للاستيراد والتصدير';
  @override String get addressLabel => 'العنوان *';
  @override String get addressHint => 'مثال: 12 شارع رمسيس، القاهرة';
  @override String get countryLabel => 'الدولة *';
  @override String get importerCardIdLabel => 'رقم البطاقة الاستيرادية (9 أرقام) *';
  @override String get importerCardIdHint => 'مثال: 528153439';
  @override String get importerCardExpiryLabel => 'تاريخ انتهاء البطاقة الاستيرادية *';
  @override String get vatRegIdLabel => 'رقم التسجيل الضريبي (9 أرقام) *';
  @override String get vatRegIdHint => 'مثال: 528153439';
  @override String get vatRegExpiryLabel => 'تاريخ انتهاء التسجيل الضريبي *';
  @override String get commercialRegNumLabel => 'رقم السجل التجاري (15 رقم) *';
  @override String get commercialRegNumHint => 'مثال: 100200000070828';
  @override String get commercialRegExpiryLabel => 'تاريخ انتهاء السجل التجاري *';
  @override String get phoneNumberLabel => 'رقم الهاتف';
  @override String get phoneNumberHint => 'مثال: 01000000000';
  @override String get cancelAndCloseBtn => 'إلغاء وإغلاق ✕';
  @override String get updateCompanyBtn => 'حفظ التعديلات';
  @override String get saveCompanyBtn => 'حفظ بيانات الشركة';
  @override String get diffCompanyName => 'اسم الشركة المستوردة';
  @override String get diffImporterCardId => 'رقم البطاقة الاستيرادية';
  @override String get diffImporterCardExpiry => 'تاريخ انتهاء البطاقة الاستيرادية';
  @override String get diffVatId => 'رقم التسجيل الضريبي';
  @override String get diffCommercialReg => 'رقم السجل التجاري';
  @override String get diffAddress => 'العنوان';
  @override String get diffPhone => 'رقم الهاتف';
  @override String get diffConfirmCompanyTitle => 'مراجعة وتأكيد تعديلات الشركة المستوردة';
  @override String get importerProfileSubtitle => 'بطاقة بيانات الشركة المستوردة والتراخيص الرقابية';
  @override String get officialRegistrationsHeader => 'بيانات القيد والتراخيص الرسمية';
  @override String get importerCardIdRowLabel => 'رقم البطاقة الاستيرادية';
  @override String get vatTaxIdRowLabel => 'رقم التسجيل الضريبي';
  @override String get commercialRegRowLabel => 'رقم السجل التجاري';
  @override String expiryEndingSoon(int days) => 'ينتهي قريباً ($days يوم)';
  @override String expiryValidDaysRemaining(int days) => 'سارٍ ($days يوم)';
  @override String expiryDateLabel(String date) => 'الانتهاء: $date';
  @override String copiedToClipboard(String value) => 'تم نسخ $value إلى الحافظة';
  @override String get locationAndContactHeader => 'بيانات الموقع والتواصل';
  @override String get countryRowLabel => 'الدولة';
  @override String get egyptCountryFallback => 'جمهورية مصر العربية';
  @override String get addressRowLabel => 'العنوان';
  @override String get phoneRowLabel => 'الهاتف';
  @override String get emailRowLabel => 'البريد الإلكتروني';
  @override String get administrativeNotesHeader => 'ملاحظات إدارية ورقمية';
  @override String get printSavePdfBtn => 'طباعة وحفظ المستند 🖨️';
  @override String get downloadExcelBtn => 'تصدير جدول بيانات 📊';
  @override String excelSavedSuccess(String path) => 'تم حفظ ملف الإكسل بنجاح: $path';
  @override String get whatsappShareBtn => 'مشاركة واتساب 💬';
  @override String get emailShareBtn => 'مشاركة بريد إلكتروني ✉️';
  @override String get whatsappPreviewTitle => 'نص مشاركة الواتساب';
  @override String get copyWhatsappTextBtn => 'نسخ نص رسالة الواتساب 📋';
  @override String get whatsappCopiedSuccess => 'تم نسخ نص الواتساب للحافظة بنجاح!';
  @override String get emailPreviewTitle => 'نموذج البريد الإلكتروني';
  @override String emailSubjectPrefix(String subject) => 'الموضوع: $subject';
  @override String get copyEmailTextBtn => 'نسخ نص وموضوع البريد الإلكتروني 📋';
  @override String get emailCopiedSuccess => 'تم نسخ نص وموضوع الإيميل للحافظة بنجاح!';
  @override String get importCompaniesCopyFieldTooltip => 'نسخ البيانات إلى الحافظة';
  @override String get importCompaniesExportTsvBtn => 'تصدير الشركات (جدول)';
  @override String get importCompaniesExportTsvSuccess => 'تم نسخ بيانات الشركات المستوردة كجدول بنجاح';
  @override String get importCompanyCopySummaryBtn => 'نسخ ملخص الشركة';
  @override String get importCompanyCopySummarySuccess => 'تم نسخ ملخص الشركة المستوردة إلى الحافظة بنجاح';
  @override String get importCompaniesTsvHeaderCode => 'معرف الشركة';
  @override String get importCompaniesTsvHeaderName => 'اسم الشركة المستوردة';
  @override String get importCompaniesTsvHeaderImporterCard => 'رقم البطاقة الاستيرادية';
  @override String get importCompaniesTsvHeaderImporterCardExpiry => 'تاريخ انتهاء البطاقة الاستيرادية';
  @override String get importCompaniesTsvHeaderVatId => 'رقم التسجيل الضريبي';
  @override String get importCompaniesTsvHeaderVatExpiry => 'تاريخ انتهاء التسجيل الضريبي';
  @override String get importCompaniesTsvHeaderComReg => 'رقم السجل التجاري';
  @override String get importCompaniesTsvHeaderComRegExpiry => 'تاريخ انتهاء السجل التجاري';
  @override String get importCompaniesTsvHeaderCountry => 'الدولة';
  @override String get importCompaniesTsvHeaderAddress => 'العنوان';
  @override String get importCompaniesTsvHeaderPhone => 'الهاتف';
  @override String get importCompaniesTsvHeaderStatus => 'حالة النشاط';
  @override String get importCompaniesTsvHeaderNotes => 'ملاحظات';
  @override String get importerCardIdLabelShort => 'بطاقة استيرادية';
  @override String get vatTaxIdLabelShort => 'تسجيل ضريبي';
  @override String get commercialRegLabelShort => 'سجل تجاري';
  @override String get importCompaniesMobileLabel => 'رقم الموبايل';
  @override String get importCompaniesFaxLabel => 'رقم الفاكس';
  @override String get importCompaniesPrimaryEmailLabel => 'البريد الإلكتروني الأساسي';
  @override String get importCompaniesSecondaryEmailLabel => 'البريد الإلكتروني الثانوي';
  @override String get importCompaniesWebsiteLabel => 'الموقع الإلكتروني';
  @override String get importCompaniesNafezaTokenSection => 'رمز نافذة والربط الرقمي';
  @override String get importCompaniesNafezaTokenLabel => 'رمز نافذة (مشفر آمن)';
  @override String get importCompaniesShowTokenTooltip => 'إظهار الرمز';
  @override String get importCompaniesHideTokenTooltip => 'إخفاء الرمز';
  @override String get importCompaniesCertificatesSection => 'شهادات العلامة التجارية والجودة';
  @override String get importCompaniesWipoTitle => 'شهادة وايپو مدريد (WIPO)';
  @override String get importCompaniesWipoRegLabel => 'رقم تسجيل WIPO Madrid';
  @override String get importCompaniesEuipoTitle => 'شهادة العلامة الأوروبية (EUIPO)';
  @override String get importCompaniesEuipoRegLabel => 'رقم تسجيل EUIPO';
  @override String get importCompaniesIsoTitle => 'شهادات إدارة الجودة ISO';

  // ── Screen 33: Foreign Suppliers ──
  @override String get suppliersScreenTitle => 'دليل الموردين والمصدرين الأجانب';
  @override String get suppliersScreenSubtitle => 'إدارة بيانات المصدرين الأجانب، أرقام القيد بنافذة، ومعرفات كارجو إكس والدول المصدرة';
  @override String get aiExtractorAndCodingBtn => '⚡ الاستخراج والترميز الذكي';
  @override String get addForeignSupplierBtn => 'إضافة مورد أجنبي جديد';
  @override String get searchSuppliersHint => 'بحث باسم المورد، الكود، معرف كارجو إكس، رقم القيد، أو الدولة...';
  @override String get showInactiveSuppliersLabel => 'عرض الموردين المتوقفين:';
  @override String suppliersFetchError(String error) => 'تعذر الاتصال بالسيرفر وجلب الموردين الأجانب:\n$error';
  @override String get noSuppliersFound => 'لم يتم العثور على موردين أجانب.';
  @override String supplierRowMeta(String exporterId, String? cargoxId, String address, String? brands) {
    final cx = cargoxId != null && cargoxId.isNotEmpty ? ' | كارجو إكس: $cargoxId' : '';
    final br = brands != null && brands.isNotEmpty ? ' | علامات: $brands' : '';
    return 'معرف المصدر: $exporterId$cx | العنوان: $address$br';
  }
  @override String supplierTypeAndReg(String type, String regType) => 'النوع: $type ($regType)';
  @override String confirmDeactivateSupplier(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل المورد ($name)؟';
  @override String confirmActivateSupplier(String name) => 'هل أنت متأكد من إعادة تفعيل المورد ($name)؟';
  @override String get deactivateSupplierTooltip => 'إيقاف تفعيل المورد';
  @override String get activateSupplierTooltip => 'إعادة تفعيل المورد';
  @override String get editSupplierDialogTitle => 'تعديل بيانات المورد الأجنبي';
  @override String get addSupplierDialogTitle => 'إضافة مورد ومصدّر أجنبي جديد';
  @override String get supplierCompanyNameLabel => 'اسم شركة المورد *';
  @override String get supplierCompanyNameHint => 'مثال: شركة الصناعات العامة المحدودة';
  @override String get supplierTypeLabel => 'نوع المورد *';
  @override String get supplierTypeManufacturer => 'مصنع أو جهة إنتاج';
  @override String get supplierTypeTrader => 'مورد أجنبي أو شركة تجارية';
  @override String get supplierTypeAgent => 'وكيل معتمد أو موزع';
  @override String get supplierTypeExporter => 'مصدّر';
  @override String get supplierRegTypeLabel => 'نوع التسجيل والتوثيق *';
  @override String get regTypeFactory => 'قيد مصنع';
  @override String get regTypeNafezaExporter => 'رقم المصدر الأجنبي (نافذة)';
  @override String get regTypeCompanyReg => 'رقم السجل التجاري للشركة';
  @override String get regTypeVat => 'رقم التسجيل الضريبي للقيمة المضافة';
  @override String get regTypeTax => 'الرقم الضريبي العام';
  @override String get regTypeCommercial => 'السجل التجاري';
  @override String get supplierForeignExporterIdLabel => 'معرف المصدر الأجنبي (نافذة) *';
  @override String get foreignExporterIdHint => 'مثال: رقم القيد بالمصدر الأجنبي';
  @override String get cargoxIdLabel => 'معرف منصة كارجو إكس';
  @override String get cargoxIdHint => 'مثال: معرف الحساب في كارجو إكس';
  @override String get supplierCountryLabel => 'دولة المورد *';
  @override String get supplierCountryHint => 'إيطاليا، الصين، ألمانيا، إلخ';
  @override String get supplierCountryCodeLabel => 'كود الدولة المعتمد *';
  @override String get supplierCountryCodeHint => 'كود الدولة حرفين';
  @override String get supplierAddressLabel => 'العنوان بالكامل *';
  @override String get supplierAddressHint => 'مثال: شارع الصناعة، مبنى 7، المدينة، الدولة';
  @override String get supplierEmailLabel => 'البريد الإلكتروني الرئيسي';
  @override String get supplierEmailHint => 'export@supplier.com';
  @override String get supplierSecondaryEmailLabel => 'بريد إلكتروني إضافي';
  @override String get supplierSecondaryEmailHint => 'sales@supplier.com';
  @override String get supplierPhoneLabel => 'رقم الهاتف الأرضي';
  @override String get supplierPhoneHint => 'رقم الهاتف مع كود الدولة';
  @override String get supplierMobileLabel => 'رقم المحمول';
  @override String get supplierMobileHint => 'رقم المحمول مع كود الدولة';
  @override String get supplierFaxLabel => 'رقم الفاكس';
  @override String get supplierFaxHint => 'رقم الفاكس مع كود الدولة';
  @override String get supplierWebsiteLabel => 'الموقع الإلكتروني';
  @override String get supplierWebsiteHint => 'www.supplier.com';
  @override String get beneficiaryBankDetailsHeader => 'بيانات البنك المستفيد والسويفت:';
  @override String get beneficiaryBankNameLabel => 'اسم البنك المستفيد';
  @override String get beneficiaryBankNameHint => 'مثال: بنك الصين، دويتشه بنك';
  @override String get beneficiarySwiftCodeLabel => 'كود السويفت البنكي';
  @override String get beneficiarySwiftCodeHint => 'كود التحويل السريع للبنك';
  @override String get beneficiaryAccountNumberLabel => 'رقم الحساب البنكي';
  @override String get beneficiaryAccountNumberHint => 'رقم الحساب البنكي للمستفيد';
  @override String get beneficiaryIbanLabel => 'رقم الحساب الدولي (آيبان)';
  @override String get beneficiaryIbanHint => 'رقم الآيبان الدولي للحساب';
  @override String get complianceAndCertsHeader => 'الامتثال والشهادات الرقابية:';
  @override String get isoCertifiedCheck => 'حاصل على شهادة الأيزو المعترف بها';
  @override String get decree43Check => 'مسجل بقرار 43 للهيئة العامة للرقابة على الصادرات والواردات';
  @override String get whiteListCheck => 'مسجل بالقائمة الاستيرادية البيضاء';
  @override String get brandsProductLinesLabel => 'العلامات التجارية وخطوط الإنتاج';
  @override String get brandsProductLinesHint => 'مثال: كلينت، نوفير، بروباور';
  @override String get supplierNotesLabel => 'ملاحظات إضافية عن المورد';
  @override String get supplierNotesHint => 'أي تفاصيل أو اشتراطات خاصة بالتعامل مع المورد...';
  @override String get updateSupplierBtn => 'حفظ تعديلات المورد';
  @override String get saveSupplierBtn => 'حفظ بيانات المورد الأجنبي';
  @override String get diffSupplierCompanyName => 'اسم شركة المورد';
  @override String get diffSupplierType => 'نوع المورد';
  @override String get diffSupplierRegType => 'نوع التسجيل';
  @override String get diffForeignExporterId => 'معرف المصدر الأجنبي (نافذة)';
  @override String get diffCargoXId => 'معرف منصة كارجو إكس';
  @override String get diffSupplierCountry => 'دولة المورد';
  @override String get diffSupplierEmail => 'البريد الإلكتروني';
  @override String get diffSupplierPhone => 'الهاتف';
  @override String get diffConfirmSupplierTitle => 'مراجعة وتأكيد تعديلات المورد الأجنبي';
  @override String get supplierProfileSubtitle => 'بطاقة تعريف المورد الأجنبي والتسجيل الرقابي';
  @override String get nafezaCargoXComplianceHeader => 'بيانات التسجيل في نافذة وكارجو إكس والامتثال';
  @override String get foreignExporterIdFieldLabel => 'معرّف المصدر الأجنبي (نافذة)';
  @override String get cargoxPlatformIdFieldLabel => 'معرّف منصة كارجو إكس';
  @override String get notRegisteredCargoX => 'غير مسجل';
  @override String get supplierTypeFieldLabel => 'نوع المورد';
  @override String get supplierOriginCountryFieldLabel => 'الدولة والمنشأ';
  @override String get complianceCertificatesLabel => 'شهادات الامتثال:';
  @override String get isoCertifiedTag => 'شهادة الأيزو';
  @override String get decree43Tag => 'قرار 43';
  @override String get whiteListTag => 'القائمة البيضاء';
  @override String get bankingSwiftSectionHeader => 'بيانات التحويل البنكي والسويفت';
  @override String get beneficiaryBankFieldLabel => 'اسم البنك المستفيد';
  @override String get swiftCodeFieldLabel => 'كود السويفت';
  @override String get accountNumberFieldLabel => 'رقم الحساب البنكي';
  @override String get ibanFieldLabel => 'رقم الآيبان';
  @override String get contactAddressBrandsHeader => 'العنوان ووسائل الاتصال والعلامات التجارية';
  @override String get fullAddressFieldLabel => 'العنوان الكامل';
  @override String get phoneFieldLabel => 'الهاتف';
  @override String get emailFieldLabel => 'البريد الإلكتروني';
  @override String get websiteFieldLabel => 'الموقع الإلكتروني';
  @override String get brandsFieldLabel => 'العلامات التجارية والمنتجات';
  @override String get additionalNotesHeader => 'ملاحظات إدارية إضافية';
  @override String get suppliersCopyFieldTooltip => 'نسخ البيانات';
  @override String get suppliersExportTsvBtn => 'تصدير الموردين (جدول)';
  @override String get suppliersExportTsvSuccess => 'تم نسخ بيانات الموردين كجدول بنجاح';
  @override String get supplierCopySummaryBtn => 'نسخ ملخص بيانات المورد';
  @override String get supplierCopySummarySuccess => 'تم نسخ بيانات المورد للحافظة بنجاح';
  @override String get supplierCodeBadgeLabel => 'كود المورد';
  @override String get routeIntelligenceBtnTooltip => 'بطاقة ذكاء المسار والمورد والتاريخ التفاوضي';
  @override String get goeicVerificationBtnTooltip => 'فحص الرقابة على الصادرات والواردات والقرار 43';
  @override String get supplierTsvHeaderCode => 'كود المورد';
  @override String get supplierTsvHeaderName => 'اسم شركة المورد';
  @override String get supplierTsvHeaderType => 'نوع المورد';
  @override String get supplierTsvHeaderRegType => 'نوع القيد';
  @override String get supplierTsvHeaderForeignExporterId => 'رقم المصدر الأجنبي';
  @override String get supplierTsvHeaderCargoxId => 'معرف منصة كارجو إكس';
  @override String get supplierTsvHeaderCountry => 'دولة المنشأ';
  @override String get supplierTsvHeaderCountryCode => 'كود الدولة';
  @override String get supplierTsvHeaderAddress => 'العنوان الكامل';
  @override String get supplierTsvHeaderPhone => 'الهاتف';
  @override String get supplierTsvHeaderEmail => 'البريد الإلكتروني';
  @override String get supplierTsvHeaderBankName => 'اسم البنك المستفيد';
  @override String get supplierTsvHeaderSwiftCode => 'كود السويفت';
  @override String get supplierTsvHeaderIban => 'الآيبان الدولي';
  @override String get supplierTsvHeaderStatus => 'الحالة';
  @override String get supplierTsvHeaderBrands => 'العلامات التجارية';
  @override String get supplierTsvHeaderNotes => 'ملاحظات إضافية';
  @override String get routeIntelligenceDialogTitle => 'بطاقة ذكاء المسار والمورد والتاريخ التفاوضي';
  @override String get routeIntelligenceAiRecommendationTitle => 'توصية الذكاء الاصطناعي للاعتماد والتفاوض:';
  @override String get routeIntelligenceAvgCycleDays => 'متوسط دورة الاستيراد';
  @override String get routeIntelligenceRecentFreight => 'آخر نولون مسجل';
  @override String get routeIntelligenceRecentClearance => 'آخر أتعاب تخليص';
  @override String get routeIntelligenceNotRecorded => 'غير مسجل';
  @override String get routeIntelligenceItemPricesTitle => 'تاريخ أسعار الأصناف من هذا المورد:';
  @override String get routeIntelligenceNoPurchasesYet => 'لا توجد مشتريات سابقة مسجلة لأصناف هذا المورد بعد.';
  @override String get routeIntelligenceItemCodeCol => 'كود الصنف';
  @override String get routeIntelligenceItemDescCol => 'الوصف';
  @override String get routeIntelligenceLastUnitPriceCol => 'آخر سعر وحدة';
  @override String get routeIntelligenceOrderCodeCol => 'أمر الشراء';
  @override String get routeIntelligenceNotesTitle => 'الملاحظات التشغيلية والتحذيرات السابقة:';
  @override String get routeIntelligenceDaysSuffix => 'يوم';
  @override String get routeIntelligenceCurrencyEgp => 'جنيه';
  @override String get routeIntelligencePriceChangeCol => 'نسبة التغير';
  @override String get routeIntelligenceDossierCopied => 'تم نسخ بطاقة الذكاء التفاوضي للحافظة بنجاح';
  @override String get routeIntelligenceCopyDossierBtn => 'نسخ البطاقة';
  @override String get routeIntelligenceAverageTransitDays => 'متوسط زمن الإبحار';
  @override String get smartEmailListenerBtnTooltip => 'المستمع الذكي لإيميلات الخطوط الملاحية وإشعارات الوصول';
  @override String get smartEmailListenerDialogTitle => 'المستمع الذكي لإيميلات الخطوط الملاحية وإشعارات الوصول';
  @override String get smartEmailListenerSenderLabel => 'البريد الإلكتروني للراسل';
  @override String get smartEmailListenerSubjectLabel => 'عنوان الرسالة';
  @override String get smartEmailListenerBodyLabel => 'نص الإشعار الوارد';
  @override String get smartEmailListenerPreviewBtn => 'تحليل واستخراج البيانات';
  @override String get smartEmailListenerProcessBtn => 'معالجة وتحديث الموعد وتوليد مهمة السداد';
  @override String get smartEmailListenerParsedCardTitle => 'البيانات المستخرجة آلياً';
  @override String get smartEmailListenerLogsTabTitle => 'سجل الإيميلات الواردة والمعالجة';
  @override String get smartEmailListenerLoadSampleBtn => 'تحميل نموذج إشعار تجريبي';
  @override String get smartEmailListenerBlNumberLabel => 'رقم بوليصة الشحن';
  @override String get smartEmailListenerEtaLabel => 'تاريخ الوصول المتوقع';
  @override String get smartEmailListenerVesselLabel => 'اسم الباخرة الناقلة';
  @override String get smartEmailListenerVoyageLabel => 'رقم الرحلة';
  @override String get smartEmailListenerContainersLabel => 'أرقام الحاويات المستخرجة';
  @override String get smartEmailListenerMatchedFileLabel => 'الملف الاستيرادي المطابق';
  @override String get smartEmailListenerTaskCreatedLabel => 'مهمة سداد إذن التسليم المولدة';
  @override String get formalLetterDialogTitle => 'توليد وميكنة المخاطبات والخطابات الرسمية';
  @override String get formalLetterTemplateLabel => 'نوع الخطاب الرسمي المعتمد';
  @override String get formalLetterRecipientLabel => 'الجهة الموجه إليها الخطاب';
  @override String get formalLetterBankNameLabel => 'اسم البنك';
  @override String get formalLetterBankBranchLabel => 'فرع البنك';
  @override String get formalLetterBrokerNameLabel => 'اسم المخلص الجمركي';
  @override String get formalLetterBrokerLicenseLabel => 'رقم رخصة التخليص الجمركي';
  @override String get formalLetterExtensionDaysLabel => 'مهلة السماح الإضافية المطلوبة باليوم';
  @override String get formalLetterCustomNotesLabel => 'ملاحظات وتعهدات إضافية';
  @override String get formalLetterGenerateBtn => 'صياغة وتوليد نص الخطاب';
  @override String get formalLetterCopyBtn => 'نسخ نص الخطاب بالكامل';
  @override String get formalLetterExportTxtBtn => 'تصدير كملف نصي';
  @override String get formalLetterLetterheadHint => 'ملاحظة: يُطبع الخطاب على مطبوعات الشركة الرسمية ممهوراً بالختم والتوقيع البنكي المعتمد.';
  @override String get formalLetterSelectShipmentPrompt => 'يرجى اختيار ملف الشحنة المراد صياغة الخطاب له:';
  @override String get goeicHubDialogTitle => 'بوابة فحص الرقابة على الصادرات والواردات';
  @override String get goeicHsCodeFieldLabel => 'بند التعريفة الجمركية';
  @override String get goeicCoiCertificateCheckbox => 'شهادة فحص مسبق معتمدة';
  @override String get goeicCheckComplianceBtn => 'فحص المطابقة الرقابية';
  @override String get goeicInspectionAgencyFieldLabel => 'شركة الفحص والمعاينة الدولية';
  @override String get goeicCoiNumberFieldLabel => 'رقم شهادة الفحص المسبق';
  @override String get goeicDecree43MandatoryYes => 'نعم (إلزامي)';
  @override String get goeicDecree43MandatoryNo => 'لا';
  @override String get goeicFactoryRegisteredYes => 'مسجل ومعتمد';
  @override String get goeicFactoryRegisteredNo => 'غير مسجل';
  @override String get goeicFactoryNotAvailable => 'غير متوفر';
  @override String get goeicVerdictBlocked => 'محظور: انتهاك القرار 43 لسنة 2016 (المصنع غير مقيد بالقائمة البيضاء)';
  @override String get goeicVerdictPending => 'معلق: المصنع مقيد ولكن يشترط إرفاق شهادة فحص ما قبل الشحن';
  @override String get goeicVerdictApproved => 'مصرح بالشحن: الشحنة والمصنع مستوفيان لكافة اشتراطات الرقابة';
  @override String get goeicRecommendedActionLabel => 'الإجراء الموصى به:';
  @override String get goeicSubjectToDecree43 => 'خضوع الصنف للقرار 43:';
  @override String get goeicFactoryRegistrationStatus => 'قيد المصنع بالهيئة:';

  // ── Screen 34: External Partners & Service Providers (Partners & Banks) ──
  @override String get partnersScreenTitle => 'الشركاء ومقدمو الخدمات الخارجية';
  @override String get partnersScreenSubtitle => 'إدارة البنوك التجارية، الخطوط الملاحية، المخلصين الجمركيين، وكلاء الشحن، وشركاء الخدمات اللوجستية';
  @override String get addExternalPartnerBtn => 'إضافة شريك خارجي جديد';
  @override String get partnerCatAll => 'الكل';
  @override String get partnerCatBank => 'بنك';
  @override String get partnerCatShippingLine => 'خط ملاحي';
  @override String get partnerCatCustomsBroker => 'مخلص جمركي';
  @override String get partnerCatFreightForwarder => 'وكيل شحن';
  @override String get partnerCatInlandTransport => 'نقل بري';
  @override String get partnerCatInspectionAgency => 'هيئة فحص ومعاينة';
  @override String get partnerCatInsuranceCompany => 'شركة تأمين';
  @override String get partnersCopyFieldTooltip => 'نسخ البيانات';
  @override String get partnersExportTsvBtn => 'تصدير الشركاء (جدول بيانات) 📊';
  @override String get partnersExportTsvSuccess => 'تم نسخ بيانات الشركاء بتنسيق جدول بيانات بنجاح';
  @override String get partnerCopySummaryBtn => 'نسخ ملخص الشريك';
  @override String get partnerCopySummarySuccess => 'تم نسخ ملخص بيانات الشريك بنجاح';
  @override String get partnerCodeBadgeLabel => 'كود الشريك: ';
  @override String get partnerScorecardBtn => 'تقييم الأداء';
  @override String get partnerScorecardTooltip => 'بطاقة تقييم مستوى أداء الخدمة';
  @override String get scorecardDialogTitle => 'بطاقة تقييم أداء الشريك اللوجستي';
  @override String scorecardPartnerSubtitle(String name, String type) => 'الشريك: $name  •  نوع الخدمة: $type';
  @override String scorecardTierLabel(String tier) => 'التصنيف المعتمد: $tier';
  @override String scorecardTotalJobs(int count) => 'إجمالي العمليات المقيّمة: $count عملية تشغيلية سابقة';
  @override String get scorecardKpiHeader => 'مؤشرات الأداء التشغيلي التفصيلية:';
  @override String get scorecardAvgClearanceDays => 'متوسط زمن التخليص (أيام)';
  @override String get scorecardGreenChannelRate => 'نسبة المسار الأخضر (%)';
  @override String get scorecardSlaAdherenceRate => 'الالتزام بمستوى الخدمة المتفق عليه (%)';
  @override String get scorecardAvgArrivalDelayDays => 'متوسط تأخير الوصول (أيام)';
  @override String get scorecardScheduleReliability => 'موثوقية الجداول الملاحية (%)';
  @override String get scorecardStrengthsHeader => 'نقاط القوة والتميز:';
  @override String get scorecardImprovementsHeader => 'فرص التحسين وملاحظات التدقيق:';
  @override String get supplierScorecardBtnTooltip => 'بطاقة تقييم أداء المورد ومؤشرات الجودة';
  @override String get supplierScorecardTitle => 'بطاقة تقييم أداء وموثوقية المورد الأجنبي';
  @override String supplierScorecardSubtitle(String name, String country) => 'المورد: $name • الدولة: $country';
  @override String get supplierScorecardCrdRate => 'نسبة الالتزام بموعد جاهزية البضاعة';
  @override String get supplierScorecardDocAccuracy => 'دقة ومطابقة مستندات الشحن';
  @override String get supplierScorecardFulfillmentRate => 'نسبة إنجاز وتوريد أوامر الشراء';
  @override String supplierScorecardTotalOrders(int count) => 'إجمالي أوامر الشراء المنجزة: $count';
  @override String get supplierScorecardCopySuccess => 'تم نسخ ملخص أداء المورد إلى الحافظة بنجاح';
  @override String get partnersTsvHeaderCode => 'كود الشريك';
  @override String get partnersTsvHeaderName => 'اسم الشريك';
  @override String get partnersTsvHeaderCategories => 'تصنيف الخدمات';
  @override String get partnersTsvHeaderCountry => 'الدولة';
  @override String get partnersTsvHeaderAddress => 'العنوان';
  @override String get partnersTsvHeaderPhone => 'الهاتف';
  @override String get partnersTsvHeaderMobile => 'المحمول';
  @override String get partnersTsvHeaderFax => 'الفاكس';
  @override String get partnersTsvHeaderEmail => 'البريد الإلكتروني';
  @override String get partnersTsvHeaderSecondaryEmail => 'بريد إضافي';
  @override String get partnersTsvHeaderWebsite => 'الموقع الإلكتروني';
  @override String get partnersTsvHeaderSwift => 'كود السويفت';
  @override String get partnersTsvHeaderScac => 'كود الناقل الملاحي';
  @override String get partnersTsvHeaderLicense => 'رخصة التخليص الجمركي';
  @override String get partnersTsvHeaderCommercialReg => 'السجل التجاري';
  @override String get partnersTsvHeaderTaxId => 'الرقم الضريبي';
  @override String get partnersTsvHeaderStatus => 'الحالة';
  @override String get partnersTsvHeaderNotes => 'الملاحظات';
  @override String get soaExportTsvBtn => 'تصدير كشف الحساب (جدول بيانات) 📊';
  @override String get soaExportTsvSuccess => 'تم نسخ كشف الحساب بتنسيق جدول بيانات بنجاح';
  @override String get soaCurrencyEgp => 'ج.م';
  @override String get searchPartnersHint => 'بحث باسم الشريك، الكود، كود السويفت، رقم الترخيص، البطاقة الضريبية، أو الدولة...';
  @override String get showInactivePartnersLabel => 'عرض المتوقفين:';
  @override String get partnersFetchError => 'تعذر الاتصال بالسيرفر وجلب الشركاء:\n\$error';
  @override String get noPartnersFound => 'لم يتم العثور على شركاء بالفلاتر المحددة.';
  @override String get partnerCodeCol => 'الكود';
  @override String get partnerNameAndCategoryCol => 'اسم الشريك والتصنيف';
  @override String get registrationAndLicenseCol => 'بيانات القيد والترخيص';
  @override String get contactDetailsCol => 'بيانات التواصل';
  @override String get partnerStatusCol => 'الحالة';
  @override String get partnerActionsCol => 'الإجراءات';
  @override String partnerSwiftLabel(String code) => 'السويفت: $code';
  @override String partnerScacLabel(String code) => 'كود الناقل: $code';
  @override String partnerLicenseLabel(String num) => 'ترخيص: $num';
  @override String partnerRegLabel(String num) => 'سجل: $num';
  @override String partnerCountryLabel(String country) => 'الدولة: $country';
  @override String get noEmailLabel => 'لا يوجد بريد';
  @override String get noPhoneLabel => 'لا يوجد هاتف';
  @override String get partnerStatementOfAccountBtn => 'كشف حساب';
  @override String get partnerStatementOfAccountTooltip => 'كشف حساب الشريك والأرصدة بالعملات';
  @override String confirmDeactivatePartner(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل الشريك ($name)؟';
  @override String confirmActivatePartner(String name) => 'هل أنت متأكد من إعادة تفعيل الشريك ($name)؟';
  @override String get deactivatePartnerTooltip => 'إيقاف تفعيل الشريك';
  @override String get activatePartnerTooltip => 'إعادة تفعيل الشريك';
  @override String get editPartnerDialogTitle => 'تعديل بيانات الشريك الخارجي والبنك';
  @override String get addPartnerDialogTitle => 'إضافة شريك خارجي وبنك جديد';
  @override String get partnerCategoriesLabel => 'تصنيفات الشريك (اختر تصنيفاً واحداً أو أكثر) *';
  @override String get partnerNameLabel => 'اسم الشريك أو الشركة *';
  @override String get partnerNameHint => 'مثال: البنك الأهلي المصري، ميرسك لاين، لوجستيات الشحن';
  @override String get bankingDetailsHeader => 'بيانات الحساب البنكي';
  @override String get bankSwiftCodeLabel => 'كود السويفت *';
  @override String get bankSwiftCodeHint => 'كود السويفت البنكي';
  @override String get bankCodeLabel => 'كود البنك';
  @override String get bankCodeHint => 'كود البنك';
  @override String get branchNameLabel => 'اسم الفرع';
  @override String get branchNameHint => 'مثال: الفرع الرئيسي، القاهرة';
  @override String get shippingLineDetailsHeader => 'بيانات الخط الملاحي';
  @override String get scacCarrierCodeLabel => 'كود الناقل الملاحي *';
  @override String get scacCarrierCodeHint => 'كود الناقل الملاحي';
  @override String get defaultFreeDaysLabel => 'فترة السماح الافتراضية (أيام) *';
  @override String get defaultFreeDaysHint => 'مثال: 14 أو 21 يوم';
  @override String partnerFreeDaysBadge(int days) => '$days يوم سماح';
  @override String get trackingWebUrlLabel => 'رابط تتبع الشحنات الملاحية';
  @override String get trackingWebUrlHint => 'رابط التتبع الإلكتروني';
  @override String get freightForwarderDetailsHeader => 'بيانات وكيل الشحن الدولي وعروض الأسعار';
  @override String get fiataLicenseLabel => 'رخصة الفياتا / ترخيص الشحن الدولي';
  @override String get fiataLicenseHint => 'مثال: FIATA-EG-7721';
  @override String get shippingModesLabel => 'طرق ومجالات الشحن المدعومة';
  @override String get shippingModesHint => 'مثال: Sea FCL, Sea LCL, Air Freight, Land';
  @override String get supportedCurrenciesLabel => 'العملات المعتمدة لعروض الأسعار';
  @override String get supportedCurrenciesHint => 'مثال: USD, EUR, EGP';
  @override String partnerFiataBadge(String fiata) => 'فياتا: $fiata';
  @override String get inspectionAgencyDetailsHeader => 'بيانات جهة الفحص والاعتماد';
  @override String get inspectionAccreditationNumLabel => 'رقم اعتماد جهة الفحص (GOIEC / ISO) *';
  @override String get inspectionAccreditationNumHint => 'مثال: GOIEC-EG-9001 أو ISO-17020';
  @override String get inspectionScopeLabel => 'نطاق الفحص والمعاينة وشهادات المطابقة (CoC / VOC)';
  @override String get inspectionScopeHint => 'مثال: Pre-shipment Inspection, CoC/VOC, Food, Machinery';
  @override String partnerAccreditationBadge(String num) => 'اعتماد: $num';
  @override String get customsBrokerLicenseHeader => 'ترخيص التخليص الجمركي والموانئ المعتمدة';
  @override String get customsClearanceLicenseNumLabel => 'رقم ترخيص مزاولة التخليص الجمركي *';
  @override String get customsClearanceLicenseNumHint => 'رقم رخصة التخليص الجمركي';
  @override String get authorizedPortsLabel => 'الموانئ والمنافذ الجمركية المعتمدة للعمل';
  @override String get authorizedPortsHint => 'مثال: ميناء الإسكندرية، السخنة، بورسعيد، دمياط، مطار القاهرة';
  @override String partnerPortsBadge(String ports) => 'الموانئ: $ports';
  @override String get inlandTransportDetailsHeader => 'بيانات أسطول وترخيص النقل البري';
  @override String get transportLicenseNumLabel => 'رقم ترخيص النقل البري *';
  @override String get transportLicenseNumHint => 'مثال: MOT-EG-8844 / ترخيص وزارة النقل';
  @override String get fleetTypesLabel => 'أنواع الشاحنات والأسطول *';
  @override String get fleetTypesHint => 'مثال: تريلات حاويات 20/40 قدم، كساحات، برادات، جامبو';
  @override String get coverageAreasLabel => 'نطاق التغطية والمحافظات المعتمدة';
  @override String get coverageAreasHint => 'مثال: موانئ الإسكندرية، السخنة، بورسعيد، دمياط، القاهرة الكبرى';
  @override String partnerFleetBadge(String fleet) => 'الأسطول: $fleet';
  @override String partnerCoverageBadge(String areas) => 'التغطية: $areas';
  @override String get insuranceDetailsHeader => 'بيانات ترخيص وتغطيات التأمين البحري';
  @override String get insuranceLicenseNumLabel => 'رقم ترخيص هيئة الرقابة المالية (FRA) *';
  @override String get insuranceLicenseNumHint => 'مثال: FRA-INS-302 / هيئة الرقابة المالية';
  @override String get insuranceCoverageTypesLabel => 'أنواع التغطيات التأمينية المعتمدة *';
  @override String get insuranceCoverageTypesHint => 'مثال: شروط معهد التأمين A / B / C، كل الأخطار، أخطار الحرب';
  @override String partnerInsuranceCoverageBadge(String cov) => 'تغطية: $cov';
  @override String get partnerTaxIdLabel => 'رقم التسجيل الضريبي';
  @override String get partnerTaxIdHint => 'الرقم الضريبي';
  @override String get partnerCommercialRegLabel => 'رقم السجل التجاري';
  @override String get partnerCommercialRegHint => 'رقم السجل التجاري';
  @override String get partnerPrimaryEmailLabel => 'البريد الإلكتروني الرئيسي';
  @override String get partnerPrimaryEmailHint => 'contact@partner.com';
  @override String get partnerSecondaryEmailLabel => 'بريد إلكتروني إضافي';
  @override String get partnerSecondaryEmailHint => 'trade@partner.com';
  @override String get partnerPhoneLabel => 'رقم الهاتف';
  @override String get partnerPhoneHint => 'رقم الهاتف مع كود المحافظة';
  @override String get partnerMobileLabel => 'رقم المحمول';
  @override String get partnerMobileHint => 'رقم المحمول';
  @override String get partnerFaxLabel => 'رقم الفاكس';
  @override String get partnerFaxHint => 'رقم الفاكس';
  @override String get partnerWebsiteUrlLabel => 'الموقع الإلكتروني';
  @override String get partnerWebsiteUrlHint => 'www.partner.com';
  @override String get partnerAddressLabel => 'العنوان';
  @override String get partnerAddressHint => 'العنوان، المدينة';
  @override String get partnerCountryLabelField => 'الدولة *';
  @override String get updatePartnerBtn => 'حفظ تعديلات الشريك';
  @override String get savePartnerBtn => 'حفظ بيانات الشريك';
  @override String get savingChanges => 'جاري حفظ التعديلات...';
  @override String get diffPartnerName => 'اسم مقدم الخدمة أو الشريك';
  @override String get diffPartnerType => 'نوع الشريك';
  @override String get diffPartnerEmail => 'البريد الإلكتروني';
  @override String get diffPartnerPhone => 'الهاتف';
  @override String get diffPartnerAddress => 'العنوان';
  @override String get diffPartnerCountry => 'الدولة';
  @override String get diffConfirmPartnerTitle => 'مراجعة وتأكيد تعديلات مقدم الخدمة أو الشريك';
  @override String get partnerProfileTitle => 'بطاقة تعريف الشريك ومقدم الخدمة';
  @override String get professionalLicensesSection => 'الرخص المهنية والأكواد والبيانات القانونية';
  @override String get partnerSwiftCodeDetailLabel => 'كود السويفت البنكي';
  @override String get partnerScacCodeDetailLabel => 'كود الخط الملاحي';
  @override String get clearanceLicenseDetailLabel => 'رقم ترخيص التخليص الجمركي';
  @override String get commercialRegDetailLabel => 'السجل التجاري';
  @override String get taxIdDetailLabel => 'البطاقة الضريبية';
  @override String get creditTermsSection => 'شروط السداد والائتمان المالي';
  @override String get paymentTermsDetailLabel => 'نوع وشروط السداد';
  @override String get creditLimitDetailLabel => 'الحد الائتماني';
  @override String get ratingDetailLabel => 'التقييم';
  @override String get bankCodeDetailLabel => 'كود البنك';
  @override String get branchNameDetailLabel => 'اسم الفرع';
  @override String get contactAndAddressSection => 'بيانات التواصل والعنوان الرسمي';
  @override String get contactPersonDetailLabel => 'مسؤول الاتصال';
  @override String get countryDetailLabel => 'الدولة';
  @override String get phoneMobileDetailLabel => 'الهاتف أو المحمول';
  @override String get emailDetailLabel => 'البريد الإلكتروني';
  @override String get fullAddressDetailLabel => 'العنوان الكامل';
  @override String get websiteDetailLabel => 'الموقع الإلكتروني';
  @override String get additionalNotesSection => 'ملاحظات إضافية';
  @override String get partnerStatementShortcutBtn => 'كشف حساب 📑';
  @override String get editPartnerBtn => 'تعديل';
  @override String partnerSoaTitle(String name) => 'كشف حساب مقدم الخدمة — $name';
  @override String partnerSoaSubtitle(String type, String taxId) => 'تصنيف الشريك: $type | الرقم الضريبي: $taxId | العملات والحركات المالية';
  @override String get calculatingSoaMsg => 'جاري احتساب كشف الحساب وتجميع الأرصدة...';
  @override String soaFetchError(String error) => 'حدث خطأ أثناء جلب كشف الحساب: $error';
  @override String get noSoaDataAvailable => 'لا توجد بيانات مالية متاحة لهذا الشريك';
  @override String get multiCurrencyBalancesHeader => 'ملخص الأرصدة والمستحقات بكل عملة:';
  @override String get totalInvoicedLabel => 'إجمالي الفواتير:';
  @override String get totalPaidLabel => 'المبالغ المسددة:';
  @override String get balanceDueLabel => 'الرصيد المستحق:';
  @override String transactionsLedgerHeader(int count) => 'سجل العمليات والفواتير والمدفوعات ($count حركة مسجلة):';
  @override String invoicesCountLabel(int invoices, int payments) => 'فواتير: $invoices | دفعات: $payments';
  @override String get noLedgerEntriesFound => 'لا توجد حركات فواتير أو مدفوعات مسجلة لهذا الشريك حتى الآن';
  @override String get ledgerDateCol => 'التاريخ';
  @override String get ledgerTypeCol => 'النوع';
  @override String get ledgerRefCol => 'المرجع';
  @override String get ledgerImportFileCol => 'ملف الشحنة';
  @override String get ledgerProjectCol => 'اسم المشروع';
  @override String get ledgerBlCol => 'رقم البوليصة';
  @override String get ledgerImporterCol => 'الشركة المستوردة';
  @override String get ledgerDescriptionCol => 'البيان والوصف';
  @override String get ledgerCurrencyCol => 'العملة';
  @override String get ledgerDebitCol => 'مدين (مستحق)';
  @override String get ledgerCreditCol => 'دائن (مسدد)';
  @override String get ledgerRunningBalanceCol => 'الرصيد التراكمي';
  @override String get ledgerStatusCol => 'الحالة';
  @override String get ledgerInvoiceBadge => 'فاتورة';
  @override String get ledgerPaymentBadge => 'سداد';
  @override String get partnerSoaRecordInvoiceBtn => 'تسجيل فاتورة جديدة';
  @override String get partnerSoaRecordPaymentBtn => 'تسجيل دفعة مسددة';
  @override String get partnerSoaExportExcelBtn => 'تصدير كملف إكسل';
  @override String get partnerSoaExportPdfBtn => 'تصدير كشف حساب PDF';
  @override String get partnerSoaPrintBtn => 'طباعة كشف الحساب';
  @override String get soaFooterText => 'سرور للخدمات اللوجستية — وحدة محاسبة الموردين ومقدمي الخدمات متعددة العملات';
  @override String get closeBtn => 'إغلاق';

  // Screen 35: Incoterms Rules (Incoterms 2020 · Cost Items · Responsibility Matrix)
  @override String get incotermsScreenTitle => 'الشروط التجارية الدولية';
  @override String get incotermsScreenSubtitle => 'إصدارات شروط التجارة الدولية، بنود التكلفة ومصفوفة توزيع المسؤوليات';
  @override String get incotermsTabRules => 'شروط التجارة';
  @override String get incotermsTabCostItems => 'بنود التكلفة';
  @override String get incotermsTabMatrix => 'مصفوفة المسؤوليات';
  @override String get searchIncotermsHint => 'بحث بالكود، الاسم، أو التصنيف...';
  @override String get showInactiveIncotermsLabel => 'عرض الشروط المتوقفة:';
  @override String get addIncotermBtn => 'إضافة شرط تجاري جديد';
  @override String get noIncotermsFound => 'لم يتم العثور على شروط تجارة دولية.';
  @override String get incotermCodeCol => 'كود الشرط';
  @override String get incotermNameCol => 'الاسم والبيان';
  @override String get incotermVersionCol => 'الإصدار';
  @override String get incotermStatusCol => 'الحالة';
  @override String get incotermActionsCol => 'الإجراءات';
  @override String printIncotermSnack(String code, String name) => 'طباعة بيانات شرط التجارة الدولي: $code ($name)';
  @override String confirmDeactivateIncoterm(String code) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل شرط التجارة ($code)؟';
  @override String confirmActivateIncoterm(String code) => 'هل أنت متأكد من إعادة تفعيل شرط التجارة ($code)؟';
  @override String get deactivateIncotermTooltip => 'إيقاف تفعيل الشرط';
  @override String get activateIncotermTooltip => 'إعادة تفعيل الشرط';
  @override String get editIncotermDialogTitle => 'تعديل بيانات شرط التجارة الدولي';
  @override String get addIncotermDialogTitle => 'إضافة شرط تجارة دولي جديد';
  @override String get incotermCodeLabel => 'كود شرط التجارة *';
  @override String get incotermFullNameLabel => 'الاسم الكامل للشرط *';
  @override String get incotermVersionLabel => 'إصدار الغرفة التجارية الدولية';
  @override String get incotermDescriptionLabel => 'الوصف وتحديد نقطة انتقال المخاطر';
  @override String get addCostItemBtn => 'إضافة بند تكلفة جديد';
  @override String get showInactiveCostItemsLabel => 'عرض البنود المتوقفة:';
  @override String get noCostItemsFound => 'لم يتم العثور على بنود تكلفة.';
  @override String get costItemCodeCol => 'كود البند';
  @override String get costItemNameCol => 'اسم بند التكلفة';
  @override String get costItemCategoryCol => 'التصنيف';
  @override String get costItemStatusCol => 'الحالة';
  @override String get costItemActionsCol => 'الإجراءات';
  @override String get costCategoryFreight => 'شحن ونولون';
  @override String get costCategoryCustoms => 'جمارك وضرائب';
  @override String get costCategoryPort => 'موانئ وأرضيات';
  @override String get costCategoryBank => 'بنوك وتمويل';
  @override String get costCategoryOther => 'مصاريف أخرى';
  @override String printCostItemSnack(String code, String name) => 'طباعة بيانات بند التكلفة: $code ($name)';
  @override String confirmDeactivateCostItem(String code) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل بند التكلفة ($code)؟';
  @override String confirmActivateCostItem(String code) => 'هل أنت متأكد من إعادة تفعيل بند التكلفة ($code)؟';
  @override String get deactivateCostItemTooltip => 'إيقاف تفعيل بند التكلفة';
  @override String get activateCostItemTooltip => 'إعادة تفعيل بند التكلفة';
  @override String get editCostItemDialogTitle => 'تعديل بيانات بند التكلفة';
  @override String get addCostItemDialogTitle => 'إضافة بند تكلفة جديد';
  @override String get costItemCodeLabel => 'كود بند التكلفة *';
  @override String get costItemNameLabel => 'اسم بند التكلفة *';
  @override String get costCategoryLabel => 'تصنيف التكلفة *';
  @override String get costItemDescriptionLabel => 'وصف وتفاصيل بند التكلفة';
  @override String get filterByIncotermLabel => 'تصفية حسب شرط التجارة:';
  @override String get allIncotermsOption => 'كافة الشروط التجارية (11 شرطاً)';
  @override String get showingAllMatrixResponsibilities => 'عرض مصفوفة المسؤوليات لكافة الشروط التجارية';
  @override String get filteringResponsibilitiesForSelectedTerm => 'عرض وتصفية المسؤوليات للشرط المحدد';
  @override String get noMatrixDataFound => 'لا توجد بيانات مسؤوليات مسجلة.';
  @override String get matrixIncotermCol => 'شرط التجارة';
  @override String get matrixCostItemCol => 'بند التكلفة';
  @override String get matrixCategoryCol => 'التصنيف';
  @override String get matrixResponsibleCol => 'الجهة المسؤولة';
  @override String get matrixIncludedCol => 'مدرج بالسعر';
  @override String get matrixNotesCol => 'ملاحظات وشروط';
  @override String get matrixActionsCol => 'الإجراءات';
  @override String get partyBuyerImporter => 'المشتري (المستورد)';
  @override String get partySellerExporter => 'البائع (المورد)';
  @override String get partyShared => 'مشترك بين الطرفين';
  @override String get editResponsibilityTooltip => 'تعديل توزيع المسؤولية';
  @override String editResponsibilityDialogTitle(String code) => 'تعديل توزيع المسؤولية · $code';
  @override String incotermPrefix(String code) => 'شرط التجارة: $code';
  @override String costItemPrefix(String name, String category) => 'بند التكلفة: $name ($category)';
  @override String get matrixResponsiblePartyFieldLabel => 'الجهة المسؤولة عن التكلفة *';
  @override String get includedInSellerPriceTitle => 'مدرج ضمن سعر الفاتورة للبائع';
  @override String get includedInSellerPriceSubtitle => 'هل يتحمل البائع هذه التكلفة ضمن سعر الفاتورة النهائي؟';
  @override String get commentNotesLabel => 'ملاحظات وشروط إضافية';
  @override String get commentNotesHint => 'إضافة تفاصيل أو شروط خاصة ببند التكلفة...';
  @override String get updatedSuccessfully => 'تم تحديث البيانات بنجاح';
  @override String get incotermsCopyFieldTooltip => 'نسخ القيمة إلى الحافظة';
  @override String get incotermsExportTsvBtn => 'تصدير شروط التجارة (جدول بيانات)';
  @override String get incotermsExportTsvSuccess => 'تم نسخ بيانات شروط التجارة بنجاح (جدول بيانات)';
  @override String get incotermCopySummaryBtn => 'نسخ ملخص الشرط التجاري';
  @override String get incotermCopySummarySuccess => 'تم نسخ ملخص الشرط التجاري بنجاح إلى الحافظة';
  @override String get incotermCodeBadgeLabel => 'كود الشرط: ';
  @override String get costItemsExportTsvBtn => 'تصدير بنود التكلفة (جدول بيانات)';
  @override String get costItemsExportTsvSuccess => 'تم نسخ بنود التكلفة بنجاح (جدول بيانات)';
  @override String get costItemCopySummaryBtn => 'نسخ ملخص بند التكلفة';
  @override String get costItemCopySummarySuccess => 'تم نسخ ملخص بند التكلفة بنجاح إلى الحافظة';
  @override String get costItemCodeBadgeLabel => 'كود بند التكلفة: ';
  @override String get matrixExportTsvBtn => 'تصدير مصفوفة المسؤوليات (جدول بيانات)';
  @override String get matrixExportTsvSuccess => 'تم نسخ مصفوفة المسؤوليات بنجاح (جدول بيانات)';
  @override String get matrixCopySummaryBtn => 'نسخ توزيع المسؤولية';
  @override String get matrixCopySummarySuccess => 'تم نسخ تفاصيل المسؤولية بنجاح إلى الحافظة';
  @override String get incotermsTsvHeaderCode => 'كود الشرط';
  @override String get incotermsTsvHeaderName => 'اسم الشرط التجاري';
  @override String get incotermsTsvHeaderVersion => 'الإصدار والمعيار';
  @override String get incotermsTsvHeaderDescription => 'الوصف وتفاصيل انتقال المخاطر';
  @override String get incotermsTsvHeaderStatus => 'حالة التفعيل';
  @override String get costItemsTsvHeaderCode => 'كود بند التكلفة';
  @override String get costItemsTsvHeaderName => 'اسم بند التكلفة';
  @override String get costItemsTsvHeaderCategory => 'تصنيف التكلفة';
  @override String get costItemsTsvHeaderDescription => 'الوصف وتفاصيل التخصيص';
  @override String get costItemsTsvHeaderStatus => 'حالة التفعيل';
  @override String get matrixTsvHeaderIncoterm => 'شرط التجارة';
  @override String get matrixTsvHeaderCostItem => 'بند التكلفة';
  @override String get matrixTsvHeaderCategory => 'تصنيف التكلفة';
  @override String get matrixTsvHeaderResponsible => 'الجهة المسؤولة';
  @override String get matrixTsvHeaderIncluded => 'مدرج بسعر الفاتورة';
  @override String get matrixTsvHeaderNotes => 'ملاحظات وشروط';
  @override String get exportIncotermsPdfBtn => 'طباعة وحفظ مستند شرط التجارة';
  @override String get exportIncotermsExcelBtn => 'تصدير جدول شرط التجارة إلى جدول بيانات';
  @override String get incotermResponsibilitiesSectionTitle => 'مصفوفة توزيع بنود التكلفة والمسؤوليات:';
  @override String get includedInPriceYes => 'نعم (مدرج بالسعر)';
  @override String get includedInPriceNo => 'لا (غير مدرج)';

  // Screen 36: Customs Tariff Schedule & HS Codes
  @override String get customsTariffScreenTitle => 'التعريفة الجمركية وبنود التعريفة المنسقة';
  @override String get customsTariffScreenSubtitle => 'فئات ضريبة الوارد المصرية، القيمة المضافة، ضريبة الجدول، رسم التنمية والاشتراطات الاستيرادية';
  @override String get importExcelCsvBtn => 'استيراد ملف جدول بيانات';
  @override String get hsExplorerBtn => '🔍 استعلام وبحث شامل';
  @override String get smartNafezaDiffEngineBtn => '✨ نافذة الذكي';
  @override String get dutyCalculatorBtn => 'حاسبة الرسوم والضرائب';
  @override String get addTariffManualBtn => '+ إضافة بند يدوي';
  @override String get searchTariffsHint => 'بحث بكود البند، الوصف، أو التصنيف...';
  @override String get showInactiveTariffsLabel => 'عرض المتوقف:';
  @override String noTariffsMatchingQuery(String query) => 'لم يتم العثور على أي بند يطابق البحث: "$query"';
  @override String get noTariffsFound => 'لا توجد بنود جمركية مسجلة.';
  @override String get tariffHsCodeCol => 'كود البند الجمركي';
  @override String get tariffDescAndAuthorityCol => 'الوصف والجهة الرقابية';
  @override String get tariffCategoryCol => 'التصنيف';
  @override String get tariffTaxRatesBreakdownCol => 'تفاصيل الضرائب والرسوم';
  @override String get tariffRequirementsCol => 'الاشتراطات';
  @override String get tariffStatusCol => 'الحالة';
  @override String get tariffActionsCol => 'الإجراءات';
  @override String rateDutyBadge(String rate) => 'وارد: $rate';
  @override String rateVatBadge(String rate) => 'ق.م: $rate';
  @override String rateSchedBadge(String rate) => 'جدول: $rate';
  @override String rateDevBadge(String rate) => 'تنمية: $rate';
  @override String govAuthorityPrefix(String auth) => 'الجهة: $auth';
  @override String printTariffSnack(String code, String desc) => 'طباعة بيانات البند الجمركي: $code ($desc)';
  @override String confirmDeactivateTariff(String code) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل البند الجمركي ($code)؟';
  @override String confirmActivateTariff(String code) => 'هل أنت متأكد من إعادة تفعيل البند الجمركي ($code)؟';
  @override String get deactivateTariffTooltip => 'إيقاف تفعيل البند';
  @override String get activateTariffTooltip => 'إعادة تفعيل البند';
  @override String get importingTariffDataset => 'جاري استيراد وتحديث جدول التعريفة الجمركية...';
  @override String get importCompletedTitle => 'اكتمل الاستيراد بنجاح';
  @override String importSummaryContent(int total, int imported, int updated) => 'تمت معالجة $total بند جمركي بنجاح!\n• بنود جديدة تم إنشاؤها: $imported\n• بنود سابقة تم تحديثها: $updated';
  @override String importFailedSnack(String error) => 'فشل الاستيراد: $error';
  @override String get nafezaDetailsModalTitle => 'تفاصيل البند الجمركي';
  @override String get itemNumberLabel => 'رقم البند : ';
  @override String get itemDescriptionLabel => 'نص البند : ';
  @override String get taxesSectionHeader => 'الضرائب والرسوم :';
  @override String get importDutyLabel => 'ضريبة الوارد';
  @override String get vatLabel => 'ضريبة القيمة المضافة';
  @override String get scheduleTaxLabel => 'ضريبة الجدول';
  @override String get developmentFeeLabel => 'رسم التنمية';
  @override String get importFeeLabel => 'رسم الوارد';
  @override String get customsServiceFeeLabel => 'رسوم الخدمات الجمركية';
  @override String get basicFeesLabel => 'رسوم أساسية';
  @override String get documentsAndProceduresHeader => 'المستندات والأعمال :';
  @override String get preferentialAgreementsSubheader => 'الاتفاقيات التفضيلية والإعفاءات الجمركية';
  @override String get addPreferentialAgreementBtn => 'إضافة اتفاقية';
  @override String get noPreferentialAgreements => 'لا توجد اتفاقيات تفضيلية مسجلة لهذا البند.';
  @override String get fullExemptionBadge => 'إعفاء جمركي كامل (0%)';
  @override String reductionPercentageBadge(String pct) => 'تخفيض جمركي: $pct%';
  @override String applicableCountriesLabel(String countries) => 'الدول المشمولة: $countries';
  @override String conditionsLabel(String conditions) => 'الشروط: $conditions';
  @override String get regulatoryApprovalsSubheader => 'الموافقات الرقابية المسبقة وجهات العرض';
  @override String get requiresCooRule => 'يشترط تقديم شهادة منشأ معتمدة وموثقة';
  @override String get requiresInspectionRule => 'خاضع لرقابة وفحص هيئة الرقابة على الصادرات والواردات';
  @override String get requiresAcidRule => 'إلزامية استخراج الرقم التعريفي المسبق للشحنة';
  @override String addAgreementDialogTitle(String code) => 'إضافة اتفاقية تفضيلية للبند $code';
  @override String get agreementNameLabel => 'اسم الاتفاقية *';
  @override String get agreementNameHint => 'مثال: اتفاقية الشراكة المصرية الأوروبية، الكوميسا، أغادير';
  @override String get agreementCountriesLabel => 'دول المنشأ المعنية *';
  @override String get agreementCountriesHint => 'رموز الدول مفصولة بفواصل';
  @override String get dutyReductionPctLabel => 'نسبة التخفيض الجمركي % *';
  @override String get dutyReductionPctHint => '100 للإعفاء الكامل، 10 للتخفيض 10%';
  @override String get agreementConditionsLabel => 'شروط وملاحظات الإفراج التفضيلية';
  @override String get agreementConditionsHint => 'مثال: مصحوبة بشهادة منشأ تفضيلية أو نموذج معتمد';
  @override String get saveAgreementBtn => 'حفظ الاتفاقية';
  @override String verifyTariffDialogTitle(String code) => 'توثيق وتدقيق بيانات البند الجمركي ($code)';
  @override String get verificationProtocolHeader => 'بروتوكول التدقيق والتوثيق المعتمد:';
  @override String get verificationProtocolText => '• يُحظر الاستعلام الخارجي المباشر، كافة البيانات تحفظ وتحدث محلياً.\n• تعديل نسب الضرائب يقوم بأرشفة الإصدار الحالي وإنشاء إصدار نشط جديد.\n• التقديرات التاريخية تحتفظ بنسبتها المسجلة وقت الاحتساب.';
  @override String get verifiedByAuditorLabel => 'اسم المراجع المعتمد *';
  @override String get sourceUrlLabel => 'رابط المصدر في بوابة نافذة';
  @override String get confidenceLevelLabel => 'درجة الموثوقية والتدقيق *';
  @override String get confirmVerificationBtn => 'تأكيد واعتماد التوثيق';
  @override String get verifyTariffBtn => 'توثيق وتدقيق البند';
  @override String get editTariffBtn => 'تعديل البند';
  @override String get agreementNameRequired => 'مطلوب إدخال اسم الاتفاقية';
  @override String get agreementCountriesRequired => 'مطلوب إدخال دول المنشأ';
  @override String get invalidNumberError => 'رقم غير صحيح';
  @override String get agreementAddedSuccess => 'تمت إضافة الاتفاقية التفضيلية بنجاح';
  @override String agreementAddFailed(String error) => 'فشلت إضافة الاتفاقية: $error';
  @override String get auditorNameRequired => 'اسم المراجع مطلوب';
  @override String get verificationSuccessSnack => 'تم توثيق وتدقيق بيانات البند الجمركي بنجاح';
  @override String verificationFailedSnack(String error) => 'فشل التوثيق: $error';
  @override String get confidenceManualAudit => 'تدقيق وتوثيق يدوي معتمد';
  @override String get confidenceOfficialGazette => 'قرار رسمي منشور بالجريدة الرسمية';
  @override String get confidenceDraft => 'مسودة غير مدققة';
  @override String get priorApprovalSpecialConditionsLabel => 'ملاحظات الموافقة المسبقة والاشتراطات الخاصة';
  @override String get taxRatesVerificationHeader => 'تدقيق ومراجعة فئات الضرائب والرسوم:';
  @override String get dutyRateLabel => 'نسبة ضريبة الوارد %';
  @override String get vatRateLabel => 'نسبة ضريبة القيمة المضافة %';
  @override String get scheduleTaxRateLabel => 'نسبة ضريبة الجدول %';
  @override String tariffVerifiedSuccess(String code) => 'تم توثيق وتدقيق البند الجمركي $code بنجاح';

  // Screen 36: Customs Tariff TSV Export & Actions
  @override String get customsTariffExportTsvBtn => 'تصدير جدول التعريفة';
  @override String get customsTariffExportTsvSuccess => 'تم نسخ بيانات جدول التعريفة الجمركية إلى الحافظة بنجاح';
  @override String get tariffCopySummaryBtn => 'نسخ بطاقة البند الجمركي';
  @override String get tariffCopySummarySuccess => 'تم نسخ ملخص البند الجمركي إلى الحافظة بنجاح';
  @override String get tariffCodeBadgeLabel => 'بند التعريفة: ';
  @override String get tariffCopyFieldTooltip => 'نسخ القيمة';
  @override String get exportTariffPdfBtn => 'طباعة وحفظ مستند التعريفة';
  @override String get exportTariffExcelBtn => 'تصدير جدول بيانات البند';

  // Screen 36: TSV Column Headers
  @override String get tariffTsvHeaderHsCode => 'كود البند الجمركي';
  @override String get tariffTsvHeaderDescription => 'وصف البند';
  @override String get tariffTsvHeaderCategory => 'التصنيف';
  @override String get tariffTsvHeaderDutyRate => 'ضريبة الوارد %';
  @override String get tariffTsvHeaderVatRate => 'ضريبة القيمة المضافة %';
  @override String get tariffTsvHeaderScheduleTax => 'ضريبة الجدول %';
  @override String get tariffTsvHeaderDevFee => 'رسم التنمية %';
  @override String get tariffTsvHeaderImportFee => 'رسم الوارد %';
  @override String get tariffTsvHeaderAuthority => 'الجهة الرقابية';
  @override String get tariffTsvHeaderRequirements => 'الاشتراطات';
  @override String get tariffTsvHeaderStatus => 'الحالة';

  // Screen 36: Smart Form & Manual Dialog
  @override String get tariffDialogTitleAdd => 'إضافة بند جمركي واشتراطات';
  @override String tariffDialogTitleEdit(String code) => 'تعديل بند جمركي - $code';
  @override String get tariffModeSmartText => 'الإدخال بالنص الكامل';
  @override String get tariffModeManualForm => 'الإدخال اليدوي المفصل';
  @override String get quickExamplesLabel => 'أمثلة تجريبية سريعة:';
  @override String get exampleAirConditioners => 'مكيفات';
  @override String get examplePlasticsBuilding => 'لدائن وبناء';
  @override String get clearTextBtn => 'مسح النص';
  @override String get pasteTariffBlockLabel => 'الصق نص البند الجمركي والضرائب والاشتراطات بالكامل هنا *';
  @override String get pasteTariffBlockHint => 'رقم البند :\n8415820010\nنص البند :\nآلات وأجهزة تكييف...\nالضرائب :\nضريبة الوارد : 60%\nضريبة الجدول : 8%\nضريبة قيمه مضافه : 14%';
  @override String get parseNowTooltip => 'تحليل النص فورياً';
  @override String parsedPreviewHeader(String code) => 'معاينة البيانات المستخرجة آلياً ($code)';
  @override String get editFieldsManuallyBtn => 'تعديل الحقول يدوياً';
  @override String get diffHistoryTitle => 'تحليل الاختلافات وسريان التاريخ';
  @override String get newHsVersionTitle => 'نسخة بند جديدة';
  @override String get diffDetailsHeader => 'تفاصيل الفروقات المرصودة:';
  @override String get hsCodeLabelReq => 'رقم البند *';
  @override String get hsCodeHint => 'مثال: 8415820010';
  @override String get customsCategoryLabel => 'التصنيف الجمركي';
  @override String get customsCategoryHint => 'مثال: أجهزة تكييف أو إلكترونيات';
  @override String get hsDescriptionLabelReq => 'نص ووصف البند الجمركي *';
  @override String get hsDescriptionRequiredError => 'مطلوب إدخال نص البند';
  @override String get taxRatesBreakdownSection => 'نسب الضرائب والرسوم (%) :';
  @override String get dutyRateInputLabel => 'ضريبة الوارد % *';
  @override String get vatRateInputLabel => 'ضريبة القيمة المضافة % *';
  @override String get scheduleTaxInputLabel => 'ضريبة الجدول %';
  @override String get devFeeInputLabel => 'رسم التنمية %';
  @override String get importFeeInputLabel => 'رسم الوارد %';
  @override String get docsAndClearanceSection => 'اشتراطات المستندات والإفراج الرقابي :';
  @override String get requiresAcidCheckbox => 'يتطلب رقم القيد الجمركي المسبق';
  @override String get requiresCooCheckbox => 'يتطلب شهادة منشأ';
  @override String get requiresInspectionCheckbox => 'يتطلب فحص مطابقة';
  @override String get govAuthorityLabel => 'الجهة الرقابية المختصة';
  @override String get govAuthorityHint => 'مثال: الهيئة العامة للرقابة على الصادرات والواردات';
  @override String get priorApprovalsLabel => 'المستندات، الأعمال، والاشتراطات الرقابية المسبقة';
  @override String get priorApprovalsHint => 'مثال: لا يصرح باستيراد الصنف إلا بموافقة مسبقة أو تسجيل المصانع';
  @override String get tariffNotesLabel => 'ملاحظات إضافية وقيود الجمرك';
  @override String get saveAllTariffAndAgreementsBtn => 'إضافة وحفظ البند والاتفاقيات بالكامل';
  @override String get addTariffBtnShort => 'إضافة البند';
  @override String get saveTariffChangesBtn => 'حفظ التعديلات';
  @override String get savingProgress => 'جاري الحفظ...';
  @override String get pasteTextFirstError => 'يرجى لصق نص البند الجمركي أولاً';
  @override String get cannotExtractHsCodeError => 'تعذر استخراج رقم البند من النص المدخل';
  @override String get saveFailureTitle => 'تفاصيل أسباب تعذر الحفظ';
  @override String get saveFailureIntro => 'حدثت الأخطاء التالية أثناء معالجة وحفظ البيانات:';
  @override String get adjustInputsBtn => 'حسناً وتعديل المدخلات';
  @override String get tariffAddedSuccess => 'تمت إضافة البند الجمركي وكافة اشتراطاته والاتفاقيات بنجاح';
  @override String get tariffUpdatedSuccess => 'تم تحديث البند الجمركي بنجاح';

  // Screen 36: Nafeza Details Dialog
  @override String get nafezaDetailsCopyTooltip => 'نسخ تفاصيل التعريفة الجمركية';
  @override String get nafezaDetailsCopySuccess => 'تم نسخ تفاصيل التعريفة الجمركية بنجاح';

  // Screen 37: Ports & Transport Locations
  @override String get transportLocationsScreenTitle => 'الموانئ والمنافذ الجمركية';
  @override String get transportLocationsScreenSubtitle => 'دليل الموانئ البحرية، المطارات الجوية، الموانئ الجافة والمنافذ البرية';
  @override String get addTransportLocationBtn => 'إضافة منفذ أو ميناء جديد';
  @override String get locationTypeAll => 'الكل';
  @override String get locationTypeSeaPort => 'ميناء بحري';
  @override String get locationTypeAirport => 'مطار جوي';
  @override String get locationTypeDryPort => 'ميناء جاف';
  @override String get locationTypeLandBorder => 'منفذ بري';
  @override String get locationTypeIcd => 'مستودع جمركي أو ميناء داخلي';
  @override String get locationTypeRailTerminal => 'محطة سكة حديد';
  @override String get searchTransportLocationsHint => 'بحث بكود المنفذ، الاسم، المدينة...';
  @override String locationsFetchError(String error) => 'تعذر الاتصال بالسيرفر وجلب بيانات الموانئ والمنافذ:\n$error';
  @override String get noTransportLocationsFound => 'لا توجد موانئ أو منافذ مسجلة.';
  @override String get unLocodeCol => 'كود المنفذ';
  @override String get locationNameCol => 'اسم المنفذ أو الميناء';
  @override String get locationTypeCol => 'النوع';
  @override String get countryCol => 'الدولة';
  @override String get cityCol => 'المدينة';
  @override String printLocationSnack(String name, String code) => 'طباعة بيانات المنفذ أو الميناء: $name ($code)';
  @override String confirmDeactivateLocation(String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل الميناء أو المنفذ ($name)؟';
  @override String confirmActivateLocation(String name) => 'هل أنت متأكد من إعادة تفعيل الميناء أو المنفذ ($name)؟';
  @override String get deactivateLocationTooltip => 'إيقاف تفعيل المنفذ';
  @override String get activateLocationTooltip => 'إعادة تفعيل المنفذ';
  @override String showingLocationsCount(int start, int end, int total, String type) => 'عرض $start–$end من إجمالي $total منفذ ($type)';
  @override String get addLocationDialogTitle => 'إضافة منفذ أو ميناء شحن جديد';
  @override String editLocationDialogTitle(String locode) => 'تعديل بيانات المنفذ ($locode)';
  @override String get unLocodeLabel => 'كود المنفذ الدولي *';
  @override String get unLocodeHint => 'مثال: كود دولي خماسي مثل ميناء الإسكندرية';
  @override String get locationTypeLabel => 'نوع المنفذ أو الميناء *';
  @override String get locationNameLabel => 'اسم المنفذ أو الميناء *';
  @override String get locationNameHint => 'مثال: ميناء الإسكندرية البحري';
  @override String get countryLabelRequired => 'الدولة *';
  @override String get countryHint => 'مثال: جمهورية مصر العربية';
  @override String get cityLabelRequired => 'المدينة *';
  @override String get cityHint => 'مثال: الإسكندرية';
  @override String get locationNotesLabel => 'ملاحظات وتفاصيل إضافية';
  @override String get createLocationSubmitBtn => 'إضافة المنفذ';
  @override String get importingLocationsDataset => 'جاري استيراد وتحديث المنافذ والموانئ من الملف...';
  @override String get importWarningsTitle => 'تنبيهات الاستيراد';
  @override String get locationsImportSuccess => 'تم استيراد المنافذ والموانئ بنجاح!';
  @override String get locationsExportTsvBtn => 'تصدير المنافذ (جدول نصوص)';
  @override String get locationsExportTsvSuccess => 'تم نسخ جدول المنافذ والموانئ إلى الحافظة';
  @override String get locationCopySummaryBtn => 'نسخ ملخص بيانات المنفذ';
  @override String get locationCopySummarySuccess => 'تم نسخ تفاصيل المنفذ إلى الحافظة';
  @override String get locationLocodeBadgeLabel => 'كود المنفذ الدولي';
  @override String get locationCopyFieldTooltip => 'نسخ قيمة الحقل';
  @override String get exportLocationPdfBtn => 'طباعة أو حفظ مستند';
  @override String get exportLocationExcelBtn => 'تصدير ملف إكسل';
  @override String get locationsTsvHeaderUnLocode => 'كود المنفذ الدولي';
  @override String get locationsTsvHeaderName => 'اسم المنفذ أو الميناء';
  @override String get locationsTsvHeaderType => 'نوع المنفذ';
  @override String get locationsTsvHeaderCountry => 'الدولة';
  @override String get locationsTsvHeaderCity => 'المدينة';
  @override String get locationsTsvHeaderStatus => 'الحالة';
  @override String get locationsTsvHeaderNotes => 'الملاحظات';

  // Screen 38: Currencies & Exchange Rates
  @override String get currenciesScreenTitle => 'العملات وأسعار الصرف';
  @override String get currenciesScreenSubtitle => 'إدارة أكواد العملات، أسعار البنوك التجارية وأسعار الصرف الجمركية الرسمية';
  @override String get liveCurrencyConverterBtn => 'محول العملات الحي';
  @override String get currencyGainLossBtn => 'فروق أسعار العملات';
  @override String get updateExchangeRatesBtn => 'تحديث أسعار الصرف';
  @override String get addCurrencyBtn => 'إضافة عملة جديدة';
  @override String get searchCurrenciesHint => 'بحث بكود العملة أو الاسم...';
  @override String currenciesFetchError(String error) => 'تعذر الاتصال بالسيرفر وجلب بيانات العملات:\n$error';
  @override String get noCurrenciesFound => 'لم يتم العثور على عملات مسجلة.';
  @override String get isoCodeCol => 'كود العملة';
  @override String get currencyNameCol => 'اسم العملة';
  @override String get currencySymbolCol => 'الرمز';
  @override String get commercialRateBankCol => 'سعر البنك التجاري';
  @override String get customsRateOfficialCol => 'سعر الجمارك الرسمي';
  @override String get baseCurrencyTooltip => 'عملة الأساس (الجنيه المصري)';
  @override String get viewRateHistoryTooltip => 'عرض السجل التاريخي لتحديث أسعار الصرف';
  @override String get baseCurrencyRateLabel => '1.0000 (أساس)';
  @override String rateToEgpFormatted(String code, String rate) => '1 $code = $rate جنيه';
  @override String get rateNotSet => 'غير محدد';
  @override String printCurrencyDetailsSnack(String code, String name) => 'طباعة بيانات وسجل أسعار العملة: $code ($name)';
  @override String confirmDeactivateCurrency(String code, String name) => 'هل أنت متأكد من رغبتك في إيقاف تفعيل عملة ($code - $name)؟';
  @override String confirmActivateCurrency(String code, String name) => 'هل أنت متأكد من إعادة تفعيل عملة ($code - $name)؟';
  @override String get cannotDeactivateBaseCurrencyTooltip => 'لا يمكن تعطيل عملة الأساس';
  @override String get deactivateCurrencyTooltip => 'إيقاف تفعيل العملة';
  @override String get activateCurrencyTooltip => 'إعادة تفعيل العملة';
  @override String showingCurrenciesCount(int start, int end, int total) => 'عرض $start–$end من إجمالي $total عملة';
  @override String get addCurrencyDialogTitle => 'إضافة عملة جديدة';
  @override String editCurrencyDialogTitle(String code) => 'تعديل بيانات العملة ($code)';
  @override String get isoCodeLabel => 'كود العملة القياسي (3 أحرف) *';
  @override String get isoCodeHint => 'مثال: الدولار، اليورو';
  @override String get isoCodeLengthError => 'يجب أن يتكون الكود من 3 أحرف';
  @override String get currencyNameLabel => 'اسم العملة *';
  @override String get currencyNameHint => 'مثال: دولار أمريكي، يورو';
  @override String get currencySymbolLabel => 'رمز العملة *';
  @override String get currencySymbolHint => 'مثال: رمز العملة';
  @override String get createCurrencySubmitBtn => 'إضافة العملة';
  @override String exchangeRateHistoryTitle(String name) => 'السجل التاريخي لأسعار الصرف — $name';
  @override String get baseCurrencySystemDesc => 'العملة الأساسية للنظام (الجنيه المصري)';
  @override String get rateHistorySubtitle => 'سجل التحديثات والتغيرات في أسعار البنك والجمارك الرسمية';
  @override String get currentCommercialRateStat => 'سعر البنك التجاري الحالي';
  @override String get currentCustomsRateStat => 'سعر الصرف الجمركي الرسمي';
  @override String get rateSpreadStat => 'الفارق بين السعرين';
  @override String get historicalUpdatesCountStat => 'عدد التحديثات التاريخية';
  @override String recordsCountBadge(int count) => '$count سجلات';
  @override String get notSetLabel => 'غير محدد';
  @override String get exchangeRateTimelineHeader => 'سجل التحديثات الزمنية لأسعار الصرف:';
  @override String get recordNewExchangeRateBtn => 'تحديث سعر صرف جديد';
  @override String get baseCurrencyNoticeTitle => 'الجنيه المصري هو عملة الأساس في النظام';
  @override String get baseCurrencyNoticeSubtitle => 'سعر الصرف دائماً 1.0000 ولا يتطلب تحديث أسعار تاريخية مقابل نفسه.';
  @override String noRateHistoryForCurrency(String code) => 'لا يوجد سجل أسعار تاريخي مسجل لعملة ($code) حتى الآن.';
  @override String get recordFirstExchangeRateBtn => 'تسجيل أول سعر صرف';
  @override String get currentActiveRateBadge => 'السعر الحالي الساري';
  @override String get commercialBankRateLabel => 'سعر البنك:';
  @override String get customsExchangeRateLabel => 'سعر الجمارك:';
  @override String get spreadVarianceLabel => 'الفارق:';
  @override String rateSourcePrefix(String source) => 'بواسطة: $source';
  @override String get updateExchangeRatesDialogTitle => 'تحديث أسعار الصرف (البنكي والجمركي)';
  @override String get selectForeignCurrencyLabel => 'اختيار العملة الأجنبية *';
  @override String get commercialRateInputLabel => 'سعر صرف البنك التجاري مقابل الجنيه *';
  @override String get customsRateInputLabel => 'سعر الصرف الجمركي الرسمي مقابل الجنيه *';
  @override String get rateInputHint => 'مثال: 50.25';
  @override String get enterValidRateError => 'أدخل سعر صحيح أكبر من صفر';
  @override String effectiveDateLabel(String date) => 'تاريخ سريان السعر: $date';
  @override String get saveRateSubmitBtn => 'حفظ سعر الصرف';
  @override String get liveCurrencyConverterDialogTitle => 'محول العملات الحي';
  @override String get liveCurrencyConverterDialogSubtitle => 'قم بإدخال المبلغ واختيار العملات لنشاط التحويل المباشر:';
  @override String get amountToConvertLabel => 'المبلغ المراد تحويله *';
  @override String get amountToConvertHint => '10000';
  @override String get enterValidAmountError => 'أدخل مبلغاً صحيحاً أكبر من صفر';
  @override String get fromCurrencyLabel => 'من عملة';
  @override String get toCurrencyLabel => 'إلى عملة';
  @override String get appliedRateTypeLabel => 'نوع سعر الصرف المطبق';
  @override String get rateTypeCommercialOption => 'سعر البنك التجاري';
  @override String get rateTypeCustomsOption => 'سعر الصرف الجمركي الرسمي';
  @override String get convertCurrencyNowBtn => 'تحويل العملة الآن';
  @override String get convertedAmountLabel => 'المبلغ المحول:';
  @override String appliedRatePrefix(dynamic rate) => 'سعر الصرف المطبق: $rate';
  @override String baseEgpEquivalentPrefix(dynamic amount) => 'المكافئ بالجنيه المصري: $amount جنيه';
  @override String get fxGainLossDialogTitle => 'حاسبة فروق أسعار العملات';
  @override String get fxGainLossDialogSubtitle => 'حساب الفرق المالي الناتج عن تغير سعر الصرف بين تاريخ الربط وتاريخ التسوية:';
  @override String get foreignAmountLabel => 'المبلغ بالعملة الأجنبية *';
  @override String get currencyLabel => 'العملة *';
  @override String get initialRateLabel => 'سعر الربط المبدئي *';
  @override String get initialRateHint => '49.00';
  @override String get settlementRateLabel => 'سعر التسوية والدفع *';
  @override String get settlementRateHint => '47.50';
  @override String get calculateGainLossBtn => 'حساب فروق العملة الآن';
  @override String initialCostAtBooking(dynamic amount, dynamic rate) => 'التكلفة المبدئية عند الربط: $amount جنيه (سعر: $rate)';
  @override String actualCostAtSettlement(dynamic amount, dynamic rate) => 'التكلفة الفعلية عند التسوية: $amount جنيه (سعر: $rate)';
  @override String get currenciesExportTsvBtn => 'تصدير العملات (جدول نصوص)';
  @override String get currenciesExportTsvSuccess => 'تم نسخ بيانات جدول العملات بنجاح';
  @override String get currencyCopySummaryBtn => 'نسخ ملخص العملة وأسعار الصرف';
  @override String get currencyCopySummarySuccess => 'تم نسخ ملخص العملة وأسعار الصرف للحافظة';
  @override String get currencyCodeBadgeLabel => 'كود العملة';
  @override String get currencyCopyFieldTooltip => 'نسخ القيمة';
  @override String get exportCurrencyPdfBtn => 'طباعة أو حفظ بطاقة العملة';
  @override String get exportCurrencyExcelBtn => 'تصدير جدول العملات';
  @override String get currenciesTsvHeaderIsoCode => 'كود العملة';
  @override String get currenciesTsvHeaderName => 'اسم العملة';
  @override String get currenciesTsvHeaderSymbol => 'الرمز';
  @override String get currenciesTsvHeaderIsBase => 'عملة أساسية';
  @override String get currenciesTsvHeaderCommercialRate => 'سعر الصرف التجاري (جنيه)';
  @override String get currenciesTsvHeaderCustomsRate => 'سعر الصرف الجمركي (جنيه)';
  @override String get currenciesTsvHeaderStatus => 'الحالة';
  @override String get currenciesTsvHeaderDecimals => 'الكسور العشرية';

  // Generic Pagination
  @override String get rowsPerPageLabel => 'الصفوف بالصفحة:';
  @override String get firstPageTooltip => 'الصفحة الأولى';
  @override String get previousPageTooltip => 'الصفحة السابقة';
  @override String pageOfTotal(dynamic page, dynamic totalPages) => '$page من $totalPages';
  @override String get nextPageTooltip => 'الصفحة التالية';
  @override String get lastPageTooltip => 'الصفحة الأخيرة';

  // Screen 43: Regulatory Requirements & Pre-Shipment Compliance
  @override String get importRequirementsScreenTitle => 'تقييم متطلبات ومستندات الاستيراد والموافقات التنظيمية';
  @override String get importRequirementsFormTab => '📋 تقييم ومطابقة المتطلبات التنظيمية';
  @override String get importRequirementsRegistryTab => '📑 سجل دراسات المتطلبات المحفوظة';
  @override String editingRequirementBanner(dynamic code) => 'أنت الآن في وضع تعديل واستكمال التقييم: ($code) — سيتم تحديث السجل وإعادة تفعيله فور الحفظ.';
  @override String get cancelEditingAndStartNewBtn => 'إلغاء التعديل والبدء من جديد';
  @override String get requirementsLifecycleCardTitle => 'نطاق ومسار المتطلبات (من إصدار الرقم المسبق حتى الإبحار والشحن الفعلي):';
  @override String sailingStatusBadge(dynamic status) => 'حالة الإبحار: $status';
  @override String get acidIssuanceStep => 'إصدار الرقم المسبق للشحنة';
  @override String get preShipmentInspectionStep => 'فحص ومطابقة ما قبل الشحن';
  @override String get approvalsAndCertsStep => 'الموافقات والشهادات';
  @override String get sailingClearanceStep => 'التصريح بالإبحار والشحن';
  @override String get pendingInspectionCoordination => 'قيد الفحص والتنسيق';
  @override String get completedAndPassedInspection => 'تمت المطابقة';
  @override String get allCertsFulfilled100 => 'مستوفاة بالكامل';
  @override String get pendingApprovals => 'قيد الاعتماد';
  @override String get linkImportFileAndConsultationHeader => 'ربط ملف الشحنة الاستيرادية والاستشارة الجمركية:';
  @override String consultationStudyBadge(dynamic code, dynamic readiness) => 'دراسة الاستشارة: $code (جاهزية $readiness%)';
  @override String get linkedImportFileFieldLabel => 'ملف الشحنة المربوط *';
  @override String get selectImportFileHint => 'اختر ملف الشحنة الاستيرادية...';
  @override String get selectImportFileOption => '-- اختر ملف الشحنة --';
  @override String get acidNotIssued => 'لم يصدر';
  @override String get pleaseSelectImportFileError => 'يرجى اختيار ملف الشحنة';
  @override String get acidNumberFieldLabel => 'رقم القيد الجمركي المسبق للشحنة (اختياري)';
  @override String get acidNumberRequiredError => 'مطلوب إدخال رقم القيد الجمركي المسبق';
  @override String get acidNumberOptionalHint => 'يُستدعى آلياً من ملف الشحنة عند استخراجه لاحقاً';
  @override String get foreignSupplierFieldLabel => 'المورد الخارجي والمصنع';
  @override String get foreignSupplierHint => 'المورد الأجنبي...';
  @override String get notSpecifiedOption => '-- غير محدد --';
  @override String prefillImportRequirementSuccess(dynamic count, dynamic code) => '⚡ تم استدعاء بنود التعريفة ($count بند) والمتطلبات تلقائياً للملف $code';
  @override String hsCodesSelectorCardTitle(dynamic count) => 'بنود التعريفة الجمركية المرتبطة بالشحنة — $count بنود مسجلة:';
  @override String totalHsValueBadge(dynamic value, dynamic currency) => 'إجمالي القيمة: $value $currency';
  @override String hsItemCodeLabel(dynamic hs, dynamic item) => '$hs ($item)';
  @override String hsItemDescLabel(dynamic desc, dynamic value, dynamic currency) => '$desc | $value $currency';
  @override String get hsCodeFieldLabel => 'بند التعريفة الجمركية *';
  @override String get hsCodeRequiredError => 'مطلوب إدخال بند التعريفة الجمركية';
  @override String get commodityDescFieldLabel => 'وصف السلعة والصنف التجاري *';
  @override String get commodityDescRequiredError => 'مطلوب إدخال وصف الصنف';
  @override String get countryOfOriginFieldLabel => 'بلد المنشأ والتصدير *';
  @override String get countryOfOriginRequiredError => 'مطلوب إدخال بلد المنشأ';
  @override String get currencyFieldLabel => 'العملة *';
  @override String get valueInCurrencyFieldLabel => 'القيمة بالعملة *';
  @override String get pillar1Decree43Tab => '١. قرار ٤٣ وتسجيل المصانع';
  @override String get pillar2CooTab => '٢. شهادة المنشأ والاتفاقيات';
  @override String get pillar3InspectionTab => '٣. فحص ما قبل الشحن';
  @override String get pillar4PermitsTab => '٤. موافقات وتصاريح جهات العرض';
  @override String get pillar5TechCertsTab => '٥. الشهادات الفنية وتأكيد الإبحار';
  @override String get pillar1Header => 'المحور الأول: قرار ٤٣ لسنة ٢٠١٦ وتسجيل المصانع المؤهلة بالهيئة';
  @override String get decree43ApplicableCheck => 'يخضع الصنف لقرار ٤٣ لسنة ٢٠١٦ (تسجيل مصانع)';
  @override String get decree43ApplicableSub => 'السلع تامة الصنع والمنتجات الاستهلاكية الواجب قيد مصنعها';
  @override String get whiteListVerifiedCheck => 'المصنع مسجل بالقائمة البيضاء';
  @override String get whiteListVerifiedSub => 'تم التحقق من قيد المصنع بالهيئة العامة للرقابة على الصادرات والواردات';
  @override String get factoryRegNumFieldLabel => 'رقم قيد المصنع بالهيئة';
  @override String get factoryRegNumHint => 'مثال: رقم القيد المعتمد بالهيئة';
  @override String get pillar2Header => 'المحور الثاني: شهادة المنشأ والاتفاقيات التفضيلية';
  @override String get cooRequiredCheck => 'شهادة المنشأ إلزامية';
  @override String get cooTypeFieldLabel => 'نوع شهادة المنشأ';
  @override String get cooTypeEur1Option => 'شهادة يورو ١ (الشراكة الأوروبية، إفتا، تركيا)';
  @override String get cooTypeFormAOption => 'نموذج أ (النظام المعمم للمزايا)';
  @override String get cooTypeGaftaOption => 'شهادة منشأ جامعة الدول العربية (منطقة التجارة العربية الكبرى)';
  @override String get cooTypeComesaOption => 'شهادة الكوميسا (السوق المشتركة لشرق وجنوب إفريقيا)';
  @override String get cooTypeStandardChamberOption => 'شهادة منشأ عادية معتمدة وموثقة من الغرفة التجارية';
  @override String get cooStatusFieldLabel => 'حالة الاستيفاء';
  @override String get cooStatusPendingOption => 'قيد الاستيفاء من المصنع';
  @override String get cooStatusObtainedOption => 'تم الاستلام والتحقق';
  @override String get cooStatusWaivedOption => 'معفاة أو مستثناة';
  @override String get cooNotesFieldLabel => 'ملاحظات المنشأ والاتفاقيات التفضيلية والإعفاءات';
  @override String get cooNotesHint => 'مثال: إعفاء جمركي بنسبة ١٠٠٪ طبقاً للاتفاقية';
  @override String get pillar3Header => 'المحور الثالث: فحص ما قبل الشحن والشهادات المعملية';
  @override String get inspectionRequiredCheck => 'شهادة الفحص إلزامية';
  @override String get inspectionBodyFieldLabel => 'جهة الفحص الدولية المعتمدة';
  @override String get inspectionBodySgsOption => 'الشركة العامة للمعاينة';
  @override String get inspectionBodyBvOption => 'بيرو فيريتاس';
  @override String get inspectionBodyTuvOption => 'توف راينلاند';
  @override String get inspectionBodyIntertekOption => 'إنترتك الدولية';
  @override String get inspectionBodyQimaOption => 'كيما لخدمات الفحص';
  @override String get inspectionBodyIlacOption => 'معمل دولي معتمد أيزو';
  @override String get inspectionStatusFieldLabel => 'حالة الفحص';
  @override String get inspectionStatusPendingOption => 'قيد التنسيق والطلب';
  @override String get inspectionStatusScheduledOption => 'تم تحديد موعد المعاينة';
  @override String get inspectionStatusCompletedOption => 'تم الفحص واجتياز المطابقة';
  @override String get inspectionStatusRejectedOption => 'غير مطابق للمواصفات';
  @override String get inspectionReportNumFieldLabel => 'رقم شهادة وتقرير الفحص';
  @override String get inspectionNotesFieldLabel => 'ملاحظات الفحص والنتائج المعملية';
  @override String get pillar4Header => 'المحور الرابع: موافقات وتصاريح جهات العرض والجهات الرقابية المسبقة';
  @override String get importPermitRequiredCheck => 'تصريح مسبق إلزامي';
  @override String get issuingAuthorityFieldLabel => 'جهة العرض والترخيص';
  @override String get authorityEeaaOption => 'جهاز شئون البيئة';
  @override String get authorityNfsaOption => 'الهيئة القومية لسلامة الغذاء';
  @override String get authorityEdaOption => 'هيئة الدواء المصرية';
  @override String get authorityNtraOption => 'الجهاز القومي لتنظيم الاتصالات';
  @override String get authorityPublicSecurityOption => 'الأمن العام ومصلحة الأمن والرقابة';
  @override String get authorityChemistryOption => 'مصلحة الكيمياء والطاقة الذرية';
  @override String get authorityGoeicOption => 'الهيئة العامة للرقابة على الصادرات والواردات';
  @override String get permitStatusFieldLabel => 'حالة التصريح';
  @override String get permitStatusAppliedOption => 'تم تقديم الطلب';
  @override String get permitStatusApprovedOption => 'تمت الموافقة والاعتماد';
  @override String get permitStatusRejectedOption => 'مرفوض';
  @override String get permitNumberFieldLabel => 'رقم التصريح والموافقة الرقابية';
  @override String get permitNotesFieldLabel => 'ملاحظات وشروط الموافقة الرقابية';
  @override String get pillar5Header => 'المحور الخامس: الشهادات الفنية الخاصة وتأكيد الجاهزية للإبحار';
  @override String get msdsRequiredCheck => 'شهادة صحيفة بيانات الأمان';
  @override String get halalCertRequiredCheck => 'شهادة الذبح الحلال';
  @override String get coaRequiredCheck => 'شهادة التحليل المخبري';
  @override String get sailingStatusFieldLabel => 'حالة الإبحار والشحن الفعلي';
  @override String get sailingStatusPreSailingOption => 'قبل الإبحار';
  @override String get sailingStatusClearedOption => 'مصرح وجاهز للإبحار';
  @override String get sailingStatusSailedOption => 'تم الإبحار والشحن الفعلي';
  @override String get sailingDateFieldLabel => 'تاريخ الإبحار الفعلي والمتوقع';
  @override String get riskLevelFieldLabel => 'تقييم المخاطر';
  @override String get riskLevelLowOption => 'منخفض';
  @override String get riskLevelMediumOption => 'متوسط';
  @override String get riskLevelHighOption => 'مرتفع';
  @override String get overallStatusDraftOption => 'مسودة';
  @override String get overallStatusInProgressOption => 'قيد الاستيفاء';
  @override String get overallStatusCompleteOption => 'مكتمل';
  @override String get overallStatusConfirmedOption => 'معتمد ومصرح للشحن';
  @override String get completeAllPillarsBtn => 'استيفاء وتأكيد كافة المحاور ⚡';
  @override String get completeAllPillarsSuccessSnack => '⚡ تم استيفاء وتأكيد جاهزية كافة المحاور وتجهيز الشحنة للإبحار!';
  @override String get saveRequirementDraftBtn => 'حفظ مؤقت ومتابعة لاحقة 💾';
  @override String get updateRequirementSubmitBtn => 'تحديث وحفظ التعديلات';
  @override String get saveRequirementSubmitBtn => 'حفظ واعتماد التقييم التأكيدي';
  @override String get fillRequiredFieldsError => 'الرجاء التأكد من تعبئة جميع الحقول المطلوبة.';
  @override String updateRequirementSuccessSnack(dynamic code) => '✅ تم تعديل وحفظ تقييم المتطلبات ($code) بنجاح!';
  @override String get createRequirementSuccessSnack => '✅ تم إنشاء وحفظ تقييم المتطلبات التنظيمية والمطابقة بنجاح!';
  @override String get saveRequirementErrorTitle => 'تنبيه عدم التكرار وخطأ بالحفظ';
  @override String get goToSavedRequirementsBtn => 'الانتقال للسجلات المحفوظة والتعديل عليها';
  @override String get searchRequirementsHint => 'بحث برقم التقييم، البند الجمركي، رقم القيد المسبق، المورد، أو الوصف...';
  @override String get complianceStatusFilterLabel => 'حالة المطابقة';
  @override String get riskLevelFilterLabel => 'مستوى المخاطر';
  @override String get activeDeletedFilterLabel => 'السجلات النشطة والمحذوفة';
  @override String get allRecordsActiveAndDeleted => 'كافة السجلات (النشطة والمحذوفة)';
  @override String get activeOnlyOption => 'النشطة فقط';
  @override String get deletedOnlyOption => 'المحذوفة فقط';
  @override String get noRequirementsFound => 'لا توجد تقييمات مسجلة مطابقة للبحث الحالي.';
  @override String get createNewRequirementBtn => 'إنشاء دراسة تقييم جديدة';
  @override String requirementsFetchError(dynamic error) => 'خطأ في تحميل سجلات التقييم:\n$error';
  @override String get fallbackImportingCompany => 'الشركة المستوردة';
  @override String requirementRowSubtitle(dynamic hs, dynamic desc, dynamic val, dynamic curr, dynamic supp, dynamic origin) => 'البند الجمركي: $hs — $desc | القيمة: $val $curr | المورد: $supp ($origin)';
  @override String sailingStatusBadgeRow(dynamic status) => 'حالة الإبحار: $status';
  @override String requirementStatusBadgeRow(dynamic status) => 'الحالة: $status';
  @override String riskLevelBadgeRow(dynamic risk) => 'المخاطر: $risk';
  @override String hsItemsCountBadge(dynamic count) => '$count بنود تعريفة';
  @override String get decree43VerifiedBadge => 'قرار ٤٣ معتمد';
  @override String get cooObtainedBadge => 'منشأ مستوفى';
  @override String get inspectionPassedBadge => 'فحص معتمد مجتاز';
  @override String get editRequirementTooltip => 'تعديل واستكمال التقييم وإعادة تفعيله';
  @override String loadedRequirementForEditingSnack(dynamic code) => '📂 تم تحميل التقييم ($code) وجاهز للتعديل والمطابقة!';
  @override String get restoreRequirementTooltip => 'استعادة وتفعيل التقييم';
  @override String restoredRequirementSuccessSnack(dynamic code) => '♻️ تم استعادة التقييم ($code) بنجاح!';
  @override String get deleteRequirementTooltip => 'حذف منطقي';
  @override String get confirmDeleteRequirementTitle => 'تأكيد الحذف المنطقي للتقييم';
  @override String confirmDeleteRequirementContent(dynamic code, dynamic file) => 'هل أنت متأكد من حذف تقييم المتطلبات ($code) للملف ($file)؟\n\nيمكنك استعادته أو إعادة تفعيله في أي وقت من خلال تعديله أو عبر زر الاستعادة.';
  @override String deletedRequirementSuccessSnack(dynamic code) => '🗑️ تم حذف التقييم ($code) منطقياً.';

  // Screen 43: Additional Export, Copy, and Detail Getters
  @override String get requirementsExportTsvBtn => 'تصدير جدول نصوص';
  @override String get requirementsExportTsvSuccess => 'تم نسخ جدول المتطلبات التنظيمية إلى الحافظة بنجاح';
  @override String get requirementsExportExcelBtn => 'تصدير إكسيل';
  @override String get requirementsExportPdfBtn => 'طباعة تقرير (بي دي إف)';
  @override String get requirementCopySummaryBtn => 'نسخ ملخص التقييم';
  @override String get requirementCopySummarySuccess => 'تم نسخ ملخص التقييم الرقابي إلى الحافظة بنجاح';
  @override String get requirementCodeBadgeLabel => 'كود التقييم: ';
  @override String get requirementAcidBadgeLabel => 'رقم القيد الجمركي المسبق: ';
  @override String get requirementHsBadgeLabel => 'بند التعريفة الجمركية: ';
  @override String get requirementCopyFieldTooltip => 'انقر لنسخ الحقل إلى الحافظة';
  @override String get printRequirementSlipBtn => 'طباعة إشعار المطابقة (بي دي إف)';
  @override String get requirementDetailsDialogTitle => 'تفاصيل دراسة المتطلبات الرقابية وما قبل الشحن';
  @override String get requirementSelectHsInstruction => 'حدد البند لعرض واستيفاء متطلباته الخمسة بشكل منفصل:';
  @override String requirementPillarsProgressBadge(dynamic count) => '$count من ٥ مستوفى';
  @override String get decree43NotRegisteredBadge => 'قرار ٤٣: غير مسجل';
  @override String get decree43ExemptionChangeBtn => 'تغيير إلى استثناء قانوني';
  @override String get decree43SampleReasonGoeicReview => 'طلب قيد المصنع مسجل بالفعل برقم وارد بهيئة الرقابة على الصادرات والواردات وقيد المراجعة';
  @override String get decree43CommonExemptionsTitle => 'أسباب الإعفاء الشائعة والمعتمدة قانوناً (انقر للتحديد السريع):';
  @override String get decree43JustificationHint => 'أدخل المبرر أو السند القانوني للإعفاء...';
  @override String get decree43TaskExplanation => 'تم جدولة مهمة إلزامية لفريق العمل بمتابعة قيد المصنع بالهيئة العامة للرقابة على الصادرات والواردات وتنبيه لوحة المتابعة.';
  @override String complianceBannerTitle(dynamic hs, dynamic desc) => 'شريط الامتثال والتنبيهات الرقابية للبند: $hs ($desc)';
  @override String get compliancePillar1Mandatory => 'قرار وزير التجارة والصناعة رقم ٤٣ لسنة ٢٠١٦: يُشترط للإفراج عن السلع تامة الصنع أن تكون منتجة بمصانع مسجلة بالقائمة البيضاء للهيئة العامة للرقابة على الصادرات والواردات.';
  @override String get compliancePillar1Warning => 'في حالة عدم تسجيل المصنع، يُحظر الإفراج الجمركي ويُمنع إصدار الرقم التعريفي المبدئي ما لم يتم توثيق استثناء رسمي أو تسجيل المصنع فوراً.';
  @override String get compliancePillar1Exemption => 'يُعفى من التسجيل: مستلزمات الإنتاج والخامات وقطع الغيار للمصانع والشركات الخدمية (مادة ٢)، وكذلك الاستيراد للاستخدام الخاص والعينات غير التجارية.';
  @override String get compliancePillar2Mandatory => 'تقديم أصل شهادة المنشأ موثقة من الغرفة التجارية بالدولة المصدرة ومطابقة تماماً للفاتورة وقائمة التعبئة وبوليصة الشحن.';
  @override String get compliancePillar2Warning => 'تضارب بلد المنشأ مع بلد الشحن بدون شهادة حركة، أو اختلاف اسم المصدر يؤدي لفقدان المزايا التفضيلية وتطبيق الرسوم الجمركية كاملة.';
  @override String get compliancePillar2Exemption => 'الاتفاقيات التفضيلية: شهادات اليورو ١ للشراكة الأوروبية، اتفاقية التجارة الحرة العربية الكبرى، الكوميسا، اتفاقية تركيا، اتفاقية أغادير تمنح تخفيضات جمركية وإعفاءات كاملة من ضريبة الوارد.';
  @override String get compliancePillar3Mandatory => 'فحص السلع الخاضعة وإصدار شهادة مطابقة وفحص مسبق معتمد من جهة فحص دولية معتمدة قبل إبحار الشحنة.';
  @override String get compliancePillar3Warning => 'الشحن بدون شهادة فحص معتمدة يستوجب سحب عينات معملية إجبارية بالهيئة العامة للرقابة مع مخاطر الرفض وإعادة التصدير على نفقة المستورد.';
  @override String get compliancePillar3Exemption => 'تسهيلات الشركات المعتمدة ببرنامج المشغل الاقتصادي المعتمد تخضع للفحص الظاهري والمطابقة السريعة بالمسار الأخضر.';
  @override String get compliancePillar4Mandatory => 'استخراج الموافقات المسبقة والتسجيل لدى الجهات التنظيمية المصرية قبل فتح الاعتماد والشحن.';
  @override String get compliancePillar4Warning => 'شحن أي بضائع خاضعة دون تصريح مسبق يمنع إدراج الشحنة على منصة نافذة، ويعرضها للتحفظ والمصادرة الجمركية.';
  @override String get compliancePillar4Exemption => 'المستوردون الصناعيون المصرح لهم يمكنهم طلب الإفراج تحت التحفظ خارج الدائرة الجمركية للتخزين بالمصنع لحين صدور المطابقة النهائية.';
  @override String get compliancePillar5Mandatory => 'استيفاء صحيفة بيانات سلامة المادة للبضائع الكيماوية والخطرة متضمنة كود الأمم المتحدة ورقم المادة، وشهادة الحلال للحوم والأغذية، وشهادة التحليل المخبري المعتمدة.';
  @override String get compliancePillar5Warning => 'عدم وضوح تاريخ الصلاحية ورقم التشغيلة باللغة العربية على العبوات يؤدي لرفض الإفراج من الهيئة القومية لسلامة الغذاء أو الحجر الصحي.';
  @override String get compliancePillar5Exemption => 'السلع الجافة، المعدات، وقطع الغيار الميكانيكية والصناعية معفاة كلياً من متطلبات صحيفة سلامة المواد وشهادة الحلال، وتكتفي بالفحص الفني للكتالوج.';
  @override String reqAcidNumberBadge(dynamic acid) => 'رقم القيد المسبق: $acid';
  @override String get acidIssuedInPhaseText => 'يُستخرج لاحقاً (مرحلة القيد المسبق)';

  // TSV Column Headers for Export
  @override String get requirementsTsvHeaderCode => 'كود التقييم';
  @override String get requirementsTsvHeaderFileCode => 'رقم ملف الشحنة';
  @override String get requirementsTsvHeaderHsCode => 'بند التعريفة';
  @override String get requirementsTsvHeaderCommodity => 'وصف السلعة';
  @override String get requirementsTsvHeaderValue => 'قيمة الشحنة';
  @override String get requirementsTsvHeaderCurrency => 'العملة';
  @override String get requirementsTsvHeaderOrigin => 'بلد المنشأ';
  @override String get requirementsTsvHeaderSupplier => 'المورد المصنع';
  @override String get requirementsTsvHeaderDecree43 => 'قرار ٤٣ تسجيل مصانع';
  @override String get requirementsTsvHeaderCoo => 'شهادة المنشأ';
  @override String get requirementsTsvHeaderInspection => 'فحص ما قبل الشحن';
  @override String get requirementsTsvHeaderPermit => 'الموافقات الرقابية';
  @override String get requirementsTsvHeaderTechCerts => 'الشهادات الفنية';
  @override String get requirementsTsvHeaderSailingStatus => 'حالة الإبحار';
  @override String get requirementsTsvHeaderOverallStatus => 'حالة التقييم العامة';
  @override String get requirementsTsvHeaderRiskLevel => 'مستوى المخاطر';
  @override String get requirementsTsvHeaderAssessedBy => 'المقيّم المسؤول';
  @override String get requirementsTsvHeaderNotes => 'الملاحظات والاشتراطات';

  // ── Screen 44: Demurrage & Detention ───────────────────────────────────────
  @override String get demurrageScreenTitle => 'حاسبة ومتابعة فترات السماح وغرامات الحاويات والأرضيات';
  @override String get containerTrackingsTab => 'جلسات تتبع الحاويات الحية';
  @override String get simulatorAndTierCalcTab => 'محاكي وحاسبة الشرائح التصاعدية';
  @override String get carrierTariffPoliciesTab => 'سياسات تعريفة الخطوط الملاحية';
  @override String get totalActiveTrackingsMetric => 'إجمالي الجلسات النشطة';
  @override String activeShipmentsCount(dynamic count) => '$count شحنة';
  @override String get incurredDemurrageShipmentsMetric => 'شحنات بها غرامات سارية';
  @override String get totalCalculatedDemurrageMetric => 'إجمالي الغرامات المحسوبة';
  @override String get searchDemurrageHint => 'بحث برقم البوليصة أو كود التتبع أو الخط الملاحي...';
  @override String get allStatusesOption => 'جميع الحالات';
  @override String get statusFreeTimeActive => 'فترة السماح سارية';
  @override String get statusDemurrageIncurred => 'غرامة أرضيات سارية';
  @override String get statusDetentionIncurred => 'غرامة تأخير فارغ';
  @override String get statusPushedToSettlement => 'تم الترحيل للتسوية';
  @override String get startNewTrackingBtn => 'بدء تتبع شحنة جديدة';
  @override String get noTrackingsFound => 'لا توجد جلسات تتبع مطابقة للبحث';
  @override String billOfLadingLabel(dynamic blNo) => 'بوليصة: $blNo';
  @override String get dischargeDateLabel => 'تاريخ التفريغ';
  @override String get gateOutDateLabel => 'خروج الميناء';
  @override String get notGatedOutYet => 'لم تخرج بعد';
  @override String get emptyReturnDateLabel => 'إعادة الحاوية الفارغة';
  @override String get notReturnedYet => 'لم تُعد بعد';
  @override String get containersCountLabel => 'عدد الحاويات';
  @override String containersCountValue(dynamic count) => '$count حاوية';
  @override String get totalEstimatedCostLabel => 'إجمالي التكلفة التقديرية';
  @override String get updateGateOutAndReturnDatesBtn => 'تحديث تواريخ الخروج والإعادة';
  @override String get pushToFinancialSettlementBtn => 'ترحيل للتسوية المالية';
  @override String get alreadyPushedToSettlementBtn => 'تم ترحيل المصروف للتسوية';
  @override String get calculationSettingsTitle => 'إعدادات ومحددات الحساب';
  @override String get shippingLineFieldLabel => 'الخط الملاحي';
  @override String get containerTypeFieldLabel => 'نوع الحاوية';
  @override String get containersCountFieldLabel => 'عدد الحاويات';
  @override String get exchangeRateFieldLabel => 'سعر الصرف مقابل الجنيه';
  @override String get grantedFreeDaysHeader => 'فترات السماح الممنوحة';
  @override String get portDemurrageFreeDaysLabel => 'سماح الأرضيات بالميناء (يوم)';
  @override String get emptyReturnFreeDaysLabel => 'سماح إعادة الفارغ (يوم)';
  @override String get operationalMilestonesHeader => 'المحطات الزمنية التشغيلية';
  @override String get vesselDischargeDateMilestone => 'تاريخ تفريغ الحاويات من السفينة';
  @override String get portGateOutDateMilestone => 'تاريخ خروج الحاوية من بوابة الميناء';
  @override String get notGatedOutCalculatedToday => 'لم تخرج بعد (تحتسب حتى اليوم)';
  @override String get emptyReturnToDepotMilestone => 'تاريخ إعادة الحاوية الفارغة لساحة الخط';
  @override String get recalculateDemurrageNowBtn => 'إعادة احتساب الغرامات الآن';
  @override String get initializingSimulationResults => 'جاري تهيئة نتائج المحاكاة...';
  @override String get totalDemurrageCostSummaryTitle => 'ملخص التكلفة الإجمالية للغرامات والأرضيات';
  @override String get demurrageFeeMetric => 'غرامة أرضيات';
  @override String get detentionFeeMetric => 'غرامة تأخير فارغ';
  @override String get portStorageFeeMetric => 'أرضيات الميناء';
  @override String daysOverdueFormatted(dynamic days) => '$days يوم تأخير';
  @override String get totalDueComprehensiveCost => 'إجمالي التكلفة الشاملة المستحقة:';
  @override String egpCurrencyAmount(dynamic amount) => '$amount جنيه مصري';
  @override String get tieredBreakdownTitle => 'تفاصيل الشرائح التصاعدية المطبقة';
  @override String get colCategory => 'البند';
  @override String get colConsumedDays => 'الأيام المستهلكة';
  @override String get colFreeDays => 'أيام السماح';
  @override String get colOverdueDays => 'أيام الغرامة';
  @override String get colFeeAmount => 'قيمة الغرامة';
  @override String daysCountFormatted(dynamic days) => '$days يوم';
  @override String demurrageCategoryLabel(dynamic category) {
    switch (category?.toString()) {
      case 'Demurrage':
        return 'أرضيات الخط الملاحي';
      case 'Detention':
        return 'تأخير إعادة الفارغ';
      case 'Port Storage':
        return 'تخزين ساحات الميناء';
      default:
        return category?.toString() ?? '';
    }
  }
  @override String get carrierTariffPoliciesTitle => 'سياسات وشرائح الخطوط الملاحية المعتمدة';
  @override String get carrierTariffPoliciesSubtitle => 'جداول فترات السماح والشرائح التصاعدية لكل خط ملاحي ونوع حاوية';
  @override String get addCarrierPolicyBtn => 'إضافة سياسة خط ملاحي جديدة';
  @override String get noCarrierPoliciesFound => 'لا توجد سياسات مضافة حالياً. يمكنك الضغط على "إضافة سياسة جديدة" أو استخدام السياسات الافتراضية.';
  @override String currencyLabelFormatted(dynamic curr) => 'العملة: $curr';
  @override String get demurrageFreeLabel => 'سماح الأرضيات';
  @override String get detentionFreeLabel => 'سماح الفارغ';
  @override String get portStorageFreeLabel => 'سماح تخزين الميناء';
  @override String get dailyStorageRateLabel => 'رسم التخزين اليومي';
  @override String egpPerDayFormatted(dynamic rate) => '$rate جنيه/يوم';
  @override String get addTrackingDialogTitle => 'بدء تتبع شحنة وحاويات جديدة';
  @override String get arrivalPortFieldLabel => 'ميناء الوصول';
  @override String get blNumberFieldLabel => 'رقم بوليصة الشحن';
  @override String get containerNumberFieldLabel => 'رقم الحاوية';
  @override String get portDischargeDateTile => 'تاريخ تفريغ الحاويات بالميناء';
  @override String get saveAndStartTrackingBtn => 'حفظ وبدء التتبع';
  @override String get trackingCreatedSuccessSnack => 'تم بدء تتبع الشحنة بنجاح';
  @override String get saveTrackingErrorSnack => 'حدث خطأ أثناء الحفظ';
  @override String updateTrackingDatesDialogTitle(dynamic code) => 'تحديث تواريخ الشحنة ($code)';
  @override String get gateOutDateTile => 'تاريخ خروج الحاوية من الميناء';
  @override String get emptyReturnDateTile => 'تاريخ إعادة الحاوية الفارغة للخط';
  @override String get notRecordedOption => 'غير مسجل';
  @override String get saveAndRecalculateBtn => 'حفظ وإعادة الاحتساب';
  @override String get datesUpdatedAndRecalculatedSuccessSnack => 'تم تحديث التواريخ وإعادة احتساب الغرامات بنجاح';
  @override String get datesUpdateErrorSnack => 'حدث خطأ أثناء التحديث';
  @override String get pushedToSettlementSuccessSnack => 'تم ترحيل المصروف بنجاح إلى ملف التسوية المالية';
  @override String get pushToSettlementErrorSnack => 'حدث خطأ أثناء الترحيل';
  @override String get addPolicyDialogTitle => 'إضافة سياسة خط ملاحي جديدة';
  @override String get demurrageFreeDaysFieldLabel => 'سماح الأرضيات (يوم)';
  @override String get detentionFreeDaysFieldLabel => 'سماح الفارغ (يوم)';
  @override String get portStorageFreeDaysFieldLabel => 'سماح تخزين الميناء (يوم)';
  @override String get dailyStorageRateEgpFieldLabel => 'رسم التخزين اليومي (جنيه)';
  @override String get savePolicyBtn => 'حفظ السياسة';
  @override String get policyCreatedSuccessSnack => 'تمت إضافة السياسة بنجاح';
  @override String get genericErrorSnack => 'حدث خطأ أثناء العملية';
  @override String get requiredFieldValidation => 'حقل مطلوب';
  @override String localizedDemurrageStatus(dynamic status) {
    switch (status?.toString()) {
      case 'Free Time Active':
        return 'فترة السماح سارية';
      case 'Demurrage Incurred':
        return 'غرامة أرضيات سارية';
      case 'Detention Incurred':
        return 'غرامة تأخير فارغ';
      case 'Pushed to Settlement':
        return 'تم الترحيل للتسوية';
      default:
        return status?.toString() ?? '';
    }
  }
  // Screen 44 Additions: TSV Headers, Export, Copy & Dual Clock
  @override String get demurrageTsvHeaderTrackingCode => 'كود التتبع';
  @override String get demurrageTsvHeaderBlNumber => 'رقم بوليصة الشحن';
  @override String get demurrageTsvHeaderCarrier => 'الخط الملاحي';
  @override String get demurrageTsvHeaderPort => 'ميناء الوصول';
  @override String get demurrageTsvHeaderDischargeDate => 'تاريخ التفريغ';
  @override String get demurrageTsvHeaderGateOutDate => 'تاريخ خروج البوابة';
  @override String get demurrageTsvHeaderEmptyReturnDate => 'تاريخ إرجاع الفارغ';
  @override String get demurrageTsvHeaderContainersCount => 'عدد الحاويات';
  @override String get demurrageTsvHeaderTotalDemurrageFx => 'غرامات الخط الملاحي';
  @override String get demurrageTsvHeaderTotalDetentionFx => 'غرامات تأخير الفارغ';
  @override String get demurrageTsvHeaderTotalStorageEgp => 'أرضيات ساحات الميناء';
  @override String get demurrageTsvHeaderCurrency => 'العملة';
  @override String get demurrageTsvHeaderExchangeRate => 'سعر الصرف';
  @override String get demurrageTsvHeaderTotalCostEgp => 'إجمالي التكلفة التقديرية بالجنيه';
  @override String get demurrageTsvHeaderStatus => 'حالة التتبع';
  @override String get demurrageTsvHeaderPushedSettlement => 'مرحل للتسوية المالية';
  @override String get demurrageExportTsvBtn => 'تصدير جدول نصوص';
  @override String get demurrageExportTsvSuccess => 'تم نسخ جدول بيانات متابعة الحاويات بنجاح';
  @override String get demurrageExportExcelBtn => 'تصدير إكسيل';
  @override String get demurrageExportPdfBtn => 'طباعة كشف المتابعة';
  @override String get demurragePrintSlipTooltip => 'طباعة إذن احتساب الغرامات والأرضيات';
  @override String get demurrageCopySummaryBtn => 'نسخ ملخص بيانات التتبع';
  @override String get demurrageCopySummarySuccess => 'تم نسخ ملخص تتبع الشحنة بنجاح';
  @override String get demurrageCodeBadgeLabel => 'كود التتبع';
  @override String get demurrageBlBadgeLabel => 'بوليصة الشحن';
  @override String get demurrageCopyFieldTooltip => 'انقر للنسخ للحافظة';
  @override String get dualClockRadarBtn => 'رادار غرامات وأرضيات الحاويات';
  @override String get dualClockRadarDialogTitle => 'رادار المتابعة المزدوج: غرامات التأخير وأرضيات الميناء';
  @override String get dualClockCarrierClockTitle => 'غرامات التوكيل الملاحي';
  @override String get dualClockPortClockTitle => 'أرضيات هيئة الميناء';
  @override String get dualClockWarning72hTitle => 'تحذير حاسم: متبقي أقل من 72 ساعة على مضاعفة شريحة أرضيات ساحة الميناء!';
  @override String get dualClockGateOutSectionTitle => 'التتبع المنفصل وخروج الحاويات الجزئي';
  @override String get dualClockContainerNoLabel => 'رقم الحاوية';
  @override String get dualClockContainerNoHint => 'أدخل رقم الحاوية المراد تسجيل خروجها';
  @override String get dualClockEirReceiptLabel => 'رقم إيصال الفحص والتحاسب';
  @override String get dualClockRecordGateOutBtn => 'تثبيت الخروج';
  @override String get dualClockEnterContainerValidation => 'يرجى إدخال رقم الحاوية أولاً';
  @override String get dualClockGateOutSuccessSnack => 'تم تثبيت بيانات خروج الحاوية بنجاح';
  @override String get dualClockGateOutErrorSnack => 'فشل حفظ بيانات خروج الحاوية';
  @override String get dualClockRetryBtn => 'إعادة المحاولة';
  @override String get dualClockCopyMetricsBtn => 'نسخ مؤشرات الرادار';
  @override String get dualClockCopyMetricsSuccess => 'تم نسخ مؤشرات رادار المتابعة بنجاح';
  @override String get dualClockFreeDaysRemaining => 'في نطاق السماح';
  @override String get dualClockOverdueDaysNote => 'تجاوزت فترة السماح';
  @override String get dualClockCurrentTierPrefix => 'الشريحة الحالية';
  @override String get dualClockStandardTierLabel => 'شريحة اعتيادية';
  @override String get simBreakdownCopyTsvBtn => 'نسخ تفاصيل الحساب';
  @override String get simBreakdownCopyTsvSuccess => 'تم نسخ تفاصيل شرائح الحساب بنجاح';
  @override String get policyCopySummaryBtn => 'نسخ ملخص سياسة الخط';
  @override String get policyCopySummarySuccess => 'تم نسخ ملخص سياسة الخط الملاحي بنجاح';
  @override String get policiesExportTsvBtn => 'تصدير سياسات الخطوط';
  @override String get policiesExportTsvSuccess => 'تم نسخ سياسات الخطوط الملاحية بنجاح';
  @override String get policiesTsvHeaderCarrier => 'الخط الملاحي';
  @override String get policiesTsvHeaderContainerType => 'نوع الحاوية';
  @override String get policiesTsvHeaderDemurrageFreeDays => 'سماح الأرضيات (يوم)';
  @override String get policiesTsvHeaderDetentionFreeDays => 'سماح الفارغ (يوم)';
  @override String get policiesTsvHeaderPortStorageFreeDays => 'سماح تخزين الميناء (يوم)';
  @override String get policiesTsvHeaderDailyStorageRateEgp => 'رسم التخزين اليومي (جنيه)';
  @override String get policiesTsvHeaderCurrency => 'العملة';

  // ── Screen 47: Audit Logs ──────────────────────────────────────────────────
  @override String get auditLogsScreenTitle => 'سجل التدقيق والتتبع التاريخي للنظام';
  @override String get auditLogsScreenSubtitle => 'التتبع الشامل لعمليات وتعديلات النظام وفروق الحقول وسجلات المستخدمين';
  @override String get liveRefreshBtn => 'تحديث حي';
  @override String get filterEntityLabel => 'الكيان:';
  @override String get filterActionLabel => 'نوع العملية:';
  @override String get filterAllOption => 'الكل';
  @override String get auditEntityImportCompany => 'الشركة المستوردة';
  @override String get auditEntitySupplier => 'المورد';
  @override String get auditEntityExternalServiceProvider => 'مقدم الخدمة والبنك';
  @override String get auditEntityUser => 'المستخدم';
  @override String auditEntityLabel(dynamic type) {
    switch (type?.toString()) {
      case 'ImportCompany':
        return 'الشركة المستوردة';
      case 'Supplier':
        return 'المورد الأجنبي';
      case 'ExternalServiceProvider':
        return 'مقدم الخدمة والبنك';
      case 'User':
        return 'المستخدم';
      case 'All':
        return 'الكل';
      default:
        return type?.toString() ?? '';
    }
  }
  @override String get auditActionCreate => 'إضافة';
  @override String get auditActionUpdate => 'تعديل';
  @override String get auditActionDelete => 'حذف';
  @override String get auditActionRestore => 'استعادة';
  @override String auditActionLabel(dynamic action) {
    switch (action?.toString().toUpperCase()) {
      case 'CREATE':
        return 'إضافة';
      case 'UPDATE':
        return 'تعديل';
      case 'DELETE':
        return 'حذف';
      case 'RESTORE':
        return 'استعادة';
      case 'ALL':
        return 'الكل';
      default:
        return action?.toString() ?? '';
    }
  }
  @override String get searchAuditLogsHint => 'بحث في السجلات بكود الكيان، المستخدم، أو تفاصيل التغيير...';
  @override String auditLogsFetchError(dynamic error) => 'خطأ في تحميل سجلات التدقيق:\n$error';
  @override String get noAuditLogsFound => 'لا توجد سجلات تدقيق مطابقة لمعايير البحث الحالية.';
  @override String auditEntityWithCode(dynamic type, dynamic code) => '$type #$code';
  @override String get systemMutationFallback => 'تم تسجيل حركة تعديل بالنظام';
  @override String performedByUser(dynamic user) => 'تم بواسطة: $user';
  @override String get auditLogsExportTsvBtn => 'تصدير السجلات (جدول نصوص)';
  @override String get auditLogsExportTsvSuccess => 'تم نسخ جدول سجلات التدقيق للحافظة';
  @override String get auditLogCopySummaryBtn => 'نسخ تفاصيل السجل';
  @override String get auditLogCopySummarySuccess => 'تم نسخ تفاصيل السجل للحافظة بنجاح';
  @override String get auditLogEntityCodeBadgeLabel => 'كود الكيان';
  @override String get auditLogCopyFieldTooltip => 'نسخ القيمة';
  @override String get exportAuditLogPdfBtn => 'تصدير سجل المراجعة (بي دي إف)';
  @override String get exportAuditLogExcelBtn => 'تصدير السجلات (إكسيل)';
  @override String get viewEntityHistoryBtn => 'عرض سجل الكيان الكامل';
  @override String get auditLogsTsvHeaderLogId => 'معرف السجل';
  @override String get auditLogsTsvHeaderAction => 'نوع العملية';
  @override String get auditLogsTsvHeaderEntityType => 'نوع الكيان';
  @override String get auditLogsTsvHeaderEntityCode => 'كود الكيان';
  @override String get auditLogsTsvHeaderSummary => 'ملخص التغيير';
  @override String get auditLogsTsvHeaderPerformedBy => 'تم بواسطة';
  @override String get auditLogsTsvHeaderTimestamp => 'تاريخ وتوقيت العملية';
  @override String get rowHistoryDialogTitle => 'سجل التعديلات وتتبع التغييرات';
  @override String rowHistoryDialogSubtitle(dynamic entityType, dynamic entityTitle) => '$entityType: $entityTitle';
  @override String get rowHistoryRefreshTooltip => 'تحديث سجل التغييرات الحي';
  @override String get rowHistoryLoading => 'جاري جلب سجل التتبع الحي من الخادم...';
  @override String get rowHistoryEmpty => 'لا توجد تعديلات مسجلة لهذا الكيان حتى الآن.';
  @override String get rowHistoryCloseBtn => 'إغلاق';
  @override String get rowHistoryExportTsvBtn => 'تصدير السجل (جدول نصوص)';
  @override String get rowHistoryExportTsvSuccess => 'تم نسخ سجل الكيان للحافظة';
  @override String get rowHistoryExportPdfBtn => 'تصدير سجل التغييرات (بي دي إف)';
  @override String get rowHistoryCopySummaryBtn => 'نسخ ملخص التغيير';
  @override String get rowHistoryCopySummarySuccess => 'تم نسخ ملخص التغيير للحافظة';

  // ── Screen 48: Lifecycle Kanban Board ───────────────────────────────────────
  @override String get lifecycleBoardTitle => 'لوحة تتبع ومتابعة مراحل الشحنات التفاعلية المباشرة (6 مراحل و 25 خطوة)';
  @override String get lifecycleBoardSubtitle => 'متابعة مراحل الشحنات التفاعلية المباشرة — اختيار المرحلة لعرض وتحديث جدول الملفات';
  @override String get refreshLiveBoardTooltip => 'تحديث البيانات المباشرة';
  @override String lifecycleBoardError(dynamic error) => 'حدث خطأ أثناء تحميل بيانات اللوحة:\n$error';
  @override String get majorPhasesHeader => 'المستويات الستة الكبرى — اضغط على أي مرحلة لعرض وتحديث شحناتها بالجدول أدناه:';
  @override String totalActiveShipmentsCount(dynamic files, dynamic stages) => 'إجمالي الشحنات: $files ملف ($stages مرحلة)';
  @override String get showAllPhasesBtn => 'عرض كافة المراحل';
  @override String get allShipmentsAllPhases => 'كافة الشحنات في جميع المراحل';
  @override String get searchLifecycleTableHint => 'بحث بكود الشحنة، المورد، أمر الشراء، أو الملاحظات...';
  @override String shipmentsCountFormatted(dynamic count) => '$count شحنة';
  @override String get colShipmentCode => 'كود الشحنة';
  @override String get colPreviousStep => 'المسار السابق';
  @override String get colCurrentStep => 'المسار الحالي';
  @override String get colNextStep => 'المسار التالي';
  @override String get colImportCompany => 'الشركة المستوردة';
  @override String get colForeignSupplier => 'المورد الأجنبي';
  @override String get colPurchaseOrder => 'أمر الشراء';
  @override String get colModeAndIncoterm => 'نوع الشحن والشرط';
  @override String get colEstimatedValue => 'القيمة التقديرية';
  @override String get colNotesAndActivities => 'الملاحظات والأنشطة';
  @override String get colActionsAndAdvance => 'الإجراءات والترحيل';
  @override String get notesUnderFollowupFallback => 'قيد المتابعة التشغيلية';
  @override String get executeAndAdvanceStepBtn => 'تنفيذ وترحيل الخطوة';
  @override String get noShipmentsInStage => 'لا توجد شحنات مسجلة حالياً في هذه المرحلة المحددة';
  @override String get noShipmentsInStageDesc => 'يمكنك اختيار مرحلة أخرى من الأقسام بالأعلى أو إلغاء التصفية لعرض كافة الشحنات.';
  @override String lifecycleStepName(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'دراسات النولون';
      case 'STEP_02':
        return 'الدراسات الجمركية';
      case 'STEP_03':
        return 'اشتراطات الاستيراد';
      case 'STEP_04':
        return 'اعتماد الميزانية';
      case 'STEP_05':
        return 'إصدار الرقم المبدئي';
      case 'STEP_06':
        return 'تأكيد الحجز';
      case 'STEP_07':
        return 'تخصيص الحاويات';
      case 'STEP_08':
        return 'مراجعة المسودات';
      case 'STEP_08_PO':
        return 'مطابقة الفاتورة وقائمة التعبئة';
      case 'STEP_08_BL':
        return 'مراجعة مسودة بوليصة الشحن';
      case 'STEP_08_MATCH':
        return 'المطابقة الذكية للفاتورة والبوليصة';
      case 'STEP_08_COO':
        return 'مسودة شهادة المنشأ و EUR.1';
      case 'STEP_08_COC':
        return 'شهادات الفحص والمطابقة COC';
      case 'STEP_09':
        return 'الاعتماد النهائي للمستندات';
      case 'STEP_10':
        return 'رفع المستندات إلكترونياً';
      case 'STEP_11':
        return 'أصول المستندات والشحن';
      case 'STEP_12':
        return 'النموذج البنكي المعتمد';
      case 'STEP_13':
        return 'إقرار الإجراءات الجمركية';
      case 'STEP_14':
        return 'الكشف والتثمين الجمركي';
      case 'STEP_15':
        return 'سحب وفحص العينات';
      case 'STEP_16':
        return 'محضر المعاينة والأضرار';
      case 'STEP_17':
        return 'سداد الرسوم والضرائب';
      case 'STEP_18':
        return 'الأرضيات وغرامات الحاويات';
      case 'STEP_19':
        return 'إذن الإضافة المخزني';
      case 'STEP_20':
        return 'تسوية التكلفة الإجمالية';
      case 'STEP_21':
        return 'إغلاق وأرشفة الملف';
      default:
        return stepCode;
    }
  }
  @override String lifecyclePhaseName(int phaseId, String fallbackAr, String fallbackEn) {
    switch (phaseId) {
      case 1:
        return 'دراسات الشحن والجمارك';
      case 2:
        return 'اعتماد الميزانية وإجراءات التسجيل';
      case 3:
        return 'الحجز الملاحي ومراجعة المسودات';
      case 4:
        return 'التحويل الرقمي والإجراءات البنكية';
      case 5:
        return 'التخليص الجمركي والكشف والتثمين';
      case 6:
        return 'الاستلام المخزني والتكلفة الإجمالية';
      default:
        return fallbackAr.isNotEmpty ? fallbackAr : fallbackEn;
    }
  }

  // Dialog & Advance / Skip / Hold Actions
  @override String stepActionCardTitle(String stepName) => 'بطاقة تنفيذ الخطوة: $stepName';
  @override String get onHoldStatusTag => 'معلقة مؤقتاً';
  @override String get importFileLabel => 'ملف الشحنة';
  @override String get importingCompanyLabel => 'الشركة المستوردة';
  @override String get foreignSupplierLabel => 'المورد الأجنبي';
  @override String get purchaseOrderLabel => 'أمر الشراء';
  @override String get estimatedValueLabel => 'القيمة التقديرية';
  @override String get currentStepRequirementsHeader => 'بيانات ومتطلبات الخطوة التشغيلية الحالية:';
  @override String get targetNextPhasesHeader => 'المراحل التالية المستهدفة بعد الإنجاز (يمكن اختيار أكثر من مرحلة بالتوازي):';
  @override String get stepNotesHeader => 'ملاحظات وسجل التحديثات لهذه الخطوة:';
  @override String get stepNotesHint => 'اكتب الملاحظات الفنية، التوجيهات أو المرجع التشغيلي...';
  @override String get skipStepBtn => 'تخطي المرحلة';
  @override String get resumeShipmentBtn => 'استئناف الشحنة';
  @override String get holdShipmentBtn => 'إيقاف مؤقت';
  @override String get savingAndAdvancing => 'جاري الحفظ والترحيل...';
  @override String get completeAndAdvanceBtn => 'اكتمال الخطوة وترحيل الشحنة';
  @override String stepAdvanceSuccessSnack(dynamic nextSteps, dynamic fileCode) => 'تم حفظ الخطوة وتفعيل المراحل التالية ($nextSteps) بنجاح للشحنة $fileCode.';
  @override String get stepAdvanceErrorSnack => 'حدث خطأ أثناء حفظ الخطوة. يرجى مراجعة الخادم.';
  @override String get skipStepDialogTitle => 'تخطي هذه المرحلة';
  @override String skipStepConfirmText(dynamic stepName, dynamic fileCode) => 'هل أنت متأكد من تخطي الخطوة ($stepName) للشحنة $fileCode؟';
  @override String get skipReasonLabel => 'سبب التخطي *';
  @override String get skipReasonHint => 'مثال: شحنة شاملة النولون، أو إعفاء نظامي...';
  @override String get skipReasonRequired => 'يلزم إدخال سبب التخطي';
  @override String get confirmSkipAndAdvanceBtn => 'تأكيد التخطي والترحيل';
  @override String stepSkippedSuccessSnack(dynamic nextSteps, dynamic fileCode) => 'تم تخطي الخطوة بنجاح وتفعيل المراحل التالية ($nextSteps) للشحنة $fileCode.';
  @override String get shipmentResumedSuccessSnack => 'تم استئناف الشحنة ومواصلة دورة العمل بنجاح.';
  @override String get holdDialogTitle => 'إيقاف مؤقت أو تعليق الشحنة';
  @override String holdConfirmText(dynamic fileCode, dynamic stepName) => 'سيتم تعليق الشحنة $fileCode مؤقتاً عند هذه الخطوة ($stepName).';
  @override String get holdReasonLabel => 'سبب الإيقاف المؤقت *';
  @override String get holdReasonHint => 'مثال: في انتظار موافقة البنك، أو مراجعة مع المورد...';
  @override String get holdReasonRequired => 'يلزم إدخال سبب الإيقاف';
  @override String get confirmHoldBtn => 'تأكيد الإيقاف المؤقت';
  @override String get shipmentHeldSuccessSnack => 'تم تعليق الشحنة مؤقتاً بنجاح.';
  @override String stepParam1Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'اسم الخط الملاحي أو شركة الشحن المعتمدة';
      case 'STEP_02':
        return 'بند التعريفة الجمركية';
      case 'STEP_03':
        return 'جهة العرض والرقابة المطلوبة';
      case 'STEP_04':
        return 'مبلغ الدفعة المعتمدة للمورد';
      case 'STEP_05':
        return 'الرقم التعريفي المبدئي للشحنة';
      case 'STEP_06':
        return 'رقم تأكيد الحجز الملاحي';
      case 'STEP_12':
        return 'رقم النموذج البنكي المعتمد';
      case 'STEP_13':
        return 'رقم شهادة الإجراءات الجمركية';
      case 'STEP_19':
        return 'رقم إذن الإضافة المخزني';
      default:
        return 'المرجع التشغيلي الرئيسي للخطوة';
    }
  }
  @override String stepParam2Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'سعر النولون البحري للحاوية';
      case 'STEP_02':
        return 'نسبة ضريبة الوارد أو الجمارك %';
      case 'STEP_04':
        return 'البنك المعتمد للتحويل';
      case 'STEP_05':
        return 'فترة صلاحية الرقم المبدئي (أيام)';
      case 'STEP_06':
        return 'اسم السفينة الناقلة';
      case 'STEP_12':
        return 'البنك المصدر للنموذج';
      case 'STEP_13':
        return 'جمرك الإفراج المعتمد';
      case 'STEP_19':
        return 'المستودع المستلم';
      default:
        return 'الملاحظة الإجرائية الفرعية';
    }
  }
  @override String stepParam3Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'مدة الإبحار المتوقعة (أيام)';
      case 'STEP_02':
        return 'نسبة ضريبة القيمة المضافة %';
      case 'STEP_04':
        return 'رقم المرجع المصرفي للتحويل';
      case 'STEP_05':
        return 'رقم تسجيل المصنع الأجنبي';
      case 'STEP_06':
        return 'توزيع الحاويات وعدد الطرود';
      case 'STEP_12':
        return 'القيمة المعتمدة بالنموذج';
      case 'STEP_13':
        return 'اسم المخلص الجمركي المعتمد';
      case 'STEP_19':
        return 'حالة الفحص والاستلام الفعلي';
      default:
        return 'بيانات إضافية';
    }
  }

  // CL-003 Live Logistics Tracking Radar
  @override String get viewModeKanbanPhases => 'عرض مراحل العمليات (6 مراحل)';
  @override String get viewModeLiveRadar => 'رادار التتبع اللوجستي الحي';
  @override String get kpiInTransit => 'في الطريق للميناء';
  @override String get kpiInPort => 'في الميناء وقيد التخليص';
  @override String get kpiHighDemurrageRisk => 'خطر غرامات أرضيات';
  @override String get kpiUnderTesting => 'عينات قيد الفحص المعملي';
  @override String get kpiIncompleteDocs => 'نواقص مستندية';
  @override String get riskFilterAll => 'جميع مستويات الخطر';
  @override String get riskFilterCritical => 'خطر حرج';
  @override String get riskFilterWarning => 'تحذير أو متوسط';
  @override String get riskFilterSafe => 'آمن';
  @override String get sampleFilterAll => 'جميع حالات العينات';
  @override String get sampleFilterUnderTesting => 'قيد الفحص المعملي';
  @override String get sampleFilterApproved => 'معتمدة ومطابقة';
  @override String get sampleFilterRejected => 'مرفوضة';
  @override String get colVesselAndBl => 'السفينة والخط وبوليصة الشحن';
  @override String get colEtaCountdown => 'الوصول المتوقع وأيام الميناء';
  @override String get colDemurrageRisk => 'مؤشر غرامات الأرضيات والسماح';
  @override String get colSampleTesting => 'فحص العينات الرقابية';
  @override String get colDocReadiness => 'اكتمال المستندات';
  @override String get colQuickActions => 'إجراءات سريعة';
  @override String get btnDemurrageSimulator => 'محاكي الغرامات';
  @override String get btnRegulatorySamples => 'اشتراطات وفحص';
  @override String get btnCustoms46 => 'إقرار 46 ك.م';
  @override String get btnCentralArchive => 'أرشيف المستندات';
  @override String get missingDocsTooltip => 'المستندات الناقصة: ';
  @override String get allDocsCompleted => 'كافة المستندات مكتملة ومعتمدة بنجاح';
  @override String daysRemainingToEta(dynamic days) => 'متبقي $days يوم على الوصول';
  @override String daysInPort(dynamic days) => 'في الميناء منذ $days يوم';
  @override String freeDaysRemainingBadge(dynamic days) => 'متبقي $days يوم سماح';
  @override String get demurrageIncurredBadge => 'بدء احتساب الغرامات';

  // Screen 48: Lifecycle Board Exports & Helpers
  @override String get lifecycleExportTsvBtn => 'تصدير جدول نصوص';
  @override String get lifecycleExportExcelBtn => 'تصدير إكسيل غير مدمج';
  @override String get lifecyclePrintPdfBtn => 'طباعة تقرير أفقي';
  @override String get lifecycleCopySummaryBtn => 'نسخ ملخص تشغيلي';
  @override String get lifecycleCopySummarySuccess => 'تم نسخ الملخص التشغيلي للحافظة';
  @override String get lifecycleCopyDossierBtn => 'نسخ ملف التتبع الشامل';
  @override String get lifecycleCopyDossierSuccess => 'تم نسخ ملف التتبع الشامل للحافظة';
  @override String get lifecycleExportTsvDialogTitle => 'حفظ تقرير مراحل الشحنات كجدول نصوص';
  @override String get lifecycleExportExcelDialogTitle => 'حفظ تقرير مراحل الشحنات كملف إكسيل';
  @override String get lifecyclePrintPdfDialogTitle => 'تقرير دورة العمل اللوجستية ومراحل الشحنات';
  @override String get lifecycleDossierHeader => 'تقرير متابعة دورة العمل ومراحل الشحنات';
  @override String get radarDossierHeader => 'تقرير رادار التتبع اللوجستي المباشر';
  @override String get radarExportTsvDialogTitle => 'حفظ رادار التتبع اللوجستي كجدول نصوص';
  @override String get radarExportExcelDialogTitle => 'حفظ رادار التتبع اللوجستي كملف إكسيل';
  @override String get radarPrintPdfDialogTitle => 'رادار التتبع اللوجستي الحي للشحنات';
  @override String liveRadarError(dynamic error) => 'حدث خطأ أثناء تحميل رادار التتبع اللوجستي:\n$error';
  @override String get searchLiveRadarHint => 'بحث بالملف، البوليصة، المورد، أو الخط...';
  @override String get colBillOfLadingPrefix => 'بوليصة';
  @override String get colEtaPrefix => 'الوصول المتوقع';
  @override String demurrageFeesFormatted(dynamic fx, dynamic egp) => 'غرامات: $fx دولار ($egp جنيه)';
  @override String freeDaysConsumed(dynamic used, dynamic total) => 'مستهلك $used من $total يوم سماح';
  @override String get colCarrierUnderPrep => 'قيد التجهيز';

  // Kanban TSV Headers
  @override String get lifecycleTsvHeaderFileCode => 'كود الشحنة';
  @override String get lifecycleTsvHeaderPreviousStep => 'المسار السابق';
  @override String get lifecycleTsvHeaderCurrentStep => 'المسار الحالي';
  @override String get lifecycleTsvHeaderNextStep => 'المسار التالي';
  @override String get lifecycleTsvHeaderCompany => 'الشركة المستوردة';
  @override String get lifecycleTsvHeaderSupplier => 'المورد الأجنبي';
  @override String get lifecycleTsvHeaderPoNumber => 'أمر الشراء';
  @override String get lifecycleTsvHeaderShipmentMode => 'نوع الشحن والشرط';
  @override String get lifecycleTsvHeaderEstimatedCost => 'القيمة التقديرية';
  @override String get lifecycleTsvHeaderStatus => 'حالة الشحنة';
  @override String get lifecycleTsvHeaderNotes => 'الملاحظات والأنشطة';

  // Radar TSV Headers
  @override String get radarTsvHeaderFileCode => 'كود الشحنة والشرط';
  @override String get radarTsvHeaderCarrierVessel => 'الناقل والسفينة';
  @override String get radarTsvHeaderBlRoute => 'رقم البوليصة والمسار';
  @override String get radarTsvHeaderArrivalStatus => 'حالة الوصول ومؤقت الميناء';
  @override String get radarTsvHeaderDemurrageRisk => 'مؤشر غرامات الأرضيات';
  @override String get radarTsvHeaderTestingStatus => 'فحص العينات الرقابية';
  @override String get radarTsvHeaderDocReadiness => 'نسبة اكتمال المستندات';

  // ==========================================
  // Screen 49: Freight Quotations Comparison (FreightQuotationsComparisonScreen)
  // ==========================================
  @override
  String get freightQuotationsComparisonTitle => 'مقارنة عروض أسعار الشحن';
  @override
  String get selectImportFileDropdownLabel => 'اختر ملف الاستيراد لمقارنة عروض الأسعار';
  @override
  String get selectImportFileDropdownHint => 'ابحث برقم الملف، اسم المورد الأجنبي، أو الشركة المستوردة...';
  @override
  String get unknownSupplierFallback => 'مورد غير معروف';
  @override
  String freightQuotesLoadError(String error) => 'حدث خطأ أثناء تحميل عروض الأسعار: $error';
  @override
  String get selectImportFilePrompt => 'الرجاء اختيار ملف استيراد لعرض ومقارنة عروض الأسعار';
  @override
  String get noFreightQuotesForFile => 'لا توجد عروض أسعار مسجلة لهذا الملف';
  @override
  String get notSelectedYet => 'لم يتم الاختيار بعد';
  @override
  String get metricCheapestQuote => 'الأرخص';
  @override
  String get metricFastestQuote => 'الأسرع';
  @override
  String transitDaysCount(dynamic days) => '$days يوم';
  @override
  String get metricCurrentlySelected => 'المختار حالياً';
  @override
  String get badgeBestPrice => 'الأفضل سعراً';
  @override
  String get unknownCarrierFallback => 'غير معروف';
  @override
  String get totalFreightCostLabel => 'إجمالي التكلفة';
  @override
  String get oceanFreightLabel => 'الشحن البحري';
  @override
  String get localChargesLabel => 'مصاريف محلية';
  @override
  String get transitDurationLabel => 'مدة الترانزيت';
  @override
  String get sailingDateLabel => 'تاريخ الإبحار';
  @override
  String get estimatedArrivalDateLabel => 'تاريخ الوصول المتوقع';
  @override
  String get remarksLabel => 'ملاحظات:';
  @override
  String get quoteAwardedBtn => 'تم الاختيار';
  @override
  String get awardQuoteBtn => 'اختيارها';
  @override
  String get freightQuoteSelectedSuccess => 'تم اختيار عرض السعر بنجاح';
  @override
  String get freightQuoteAwardedSuccess => 'تم اختيار واعتماد عرض السعر بنجاح';
  @override
  String freightQuoteAwardError(String error) => 'خطأ في اعتماد العرض: $error';
  @override
  String get freightQuotationsExportTsvBtn => 'تصدير جدول مجدول';
  @override
  String get freightQuotationsExportExcelBtn => 'تصدير جدول إكسيل';
  @override
  String get freightQuotationsPrintPdfBtn => 'طباعة وحفظ التقرير';
  @override
  String get freightQuotationsCopyDossierBtn => 'نسخ ملف المقارنة';
  @override
  String get freightQuotationsCopyDossierSuccess => 'تم نسخ تقرير مقارنة عروض الأسعار إلى الحافظة';
  @override
  String get freightQuotationsDossierHeader => 'تقرير المقارنة الشاملة لعروض أسعار الشحن والترسية';
  @override
  String get freightQuotationsExportTsvDialogTitle => 'تصدير بيانات عروض الأسعار بتنسيق مجدول';
  @override
  String get freightQuotationsExportExcelDialogTitle => 'تصدير بيانات عروض الأسعار إكسيل';
  @override
  String get freightQuotesTsvHeaderCarrier => 'شركة الشحن والناقل البحري';
  @override
  String get freightQuotesTsvHeaderTotalCost => 'إجمالي تكلفة الشحن';
  @override
  String get freightQuotesTsvHeaderOceanFreight => 'نولون الشحن البحري';
  @override
  String get freightQuotesTsvHeaderLocalCharges => 'المصاريف والرسوم المحلية';
  @override
  String get freightQuotesTsvHeaderInlandCharges => 'النقل الداخلي والتعتيق';
  @override
  String get freightQuotesTsvHeaderTransitDays => 'مدة الإبحار بالأيام';
  @override
  String get freightQuotesTsvHeaderSailingDate => 'تاريخ الإبحار الفعلي';
  @override
  String get freightQuotesTsvHeaderArrivalDate => 'تاريخ الوصول المتوقع';
  @override
  String get freightQuotesTsvHeaderFreeDays => 'فترة السماح بالأيام';
  @override
  String get freightQuotesTsvHeaderStatus => 'حالة الترسية والاعتماد';
  @override
  String get freightQuotesTsvHeaderRemarks => 'الملاحظات والشروط الإضافية';
  @override
  String get vesselNameLabel => 'اسم السفينة الناقلة';
  @override
  String get voyageNumberLabel => 'رقم الرحلة البحرية';
  @override
  String get oceanFreightCostLabel => 'نولون الشحن البحري بالدولار';
  @override
  String get localChargesCostLabel => 'المصاريف والرسوم المحلية بالدولار';
  @override
  String get inlandCostLabel => 'النقل الداخلي والتعتيق بالدولار';
  @override
  String get sailingDateFormLabel => 'تاريخ الإبحار الفعلي';
  @override
  String get arrivalDateFormLabel => 'تاريخ الوصول المتوقع للميناء';
  @override
  String get freeDaysPodFormLabel => 'فترة السماح بالجمارك بالأيام';
  @override
  String get remarksFormLabel => 'ملاحظات وشروط العرض';

  // ==========================================
  // Screen 50: Landed Cost Comparison (LandedCostComparisonScreen)
  // ==========================================
  @override
  String landedCostComparisonTitle(dynamic fileCode) => 'مقارنة تكلفة الوصول الشاملة — تقديري مقابل فعلي [$fileCode]';
  @override
  String landedCostLoadError(dynamic error) => 'حدث خطأ أثناء تحميل بيانات التكلفة: $error';
  @override
  String get noLandedCostDataRegistered => 'لم يتم تسجيل بيانات تكلفة الوصول الشاملة بعد لهذا الملف';
  @override
  String get expenseBreakdownHeader => 'تفاصيل وبنود المصروفات الفعلية';
  @override
  String get itemLandedCostHeader => 'تكلفة الأصناف بعد توزيع المصروفات';
  @override
  String get estimatedCostHeader => 'التكلفة التقديرية';
  @override
  String get actualCostHeader => 'التكلفة الفعلية';
  @override
  String get fobValueCardTitle => 'قيمة البضاعة فوب';
  @override
  String get totalExpensesCardTitle => 'إجمالي المصروفات الإضافية';
  @override
  String get totalLandedCostCardTitle => 'إجمالي تكلفة الوصول الشاملة';
  @override
  String get estAbbreviation => 'تقديري';
  @override
  String get actAbbreviation => 'فعلي';
  @override
  String get colExpenseCategory => 'الفئة';
  @override
  String get colExpenseProvider => 'مقدم الخدمة أو المورد';
  @override
  String get colExpenseCurrency => 'العملة';
  @override
  String get colExpenseAmountFx => 'القيمة بالعملة الأجنبية';
  @override
  String get colExpenseExchangeRate => 'سعر الصرف';
  @override
  String get colExpenseAmountEgp => 'القيمة بالجنيه المصري';
  @override
  String get colItemCode => 'كود الصنف';
  @override
  String get colItemName => 'اسم الصنف';
  @override
  String get colItemQty => 'الكمية';
  @override
  String get colFobUnitPrice => 'سعر الوحدة فوب';
  @override
  String get colLandedUnitPrice => 'تكلفة الوحدة الإجمالية الواصلة';
  @override
  String get colCostMarkupFactor => 'معامل التكلفة';
  @override
  String landedCostOverBudgetBanner(dynamic percent) => 'تجاوزت التكلفة الفعلية الميزانية التقديرية بنسبة $percent%';
  @override
  String landedCostUnderBudgetBanner(dynamic percent) => 'وفر المشروع $percent% من الميزانية التقديرية المعتمدة';
  @override
  String expenseCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'freight':
        return 'نولون وشحن';
      case 'customs':
        return 'جمارك وضرائب';
      case 'clearance':
        return 'أتعاب تخليص';
      case 'transport':
        return 'نقل وتعتيق داخلي';
      case 'storage':
        return 'أرضيات وتخزين';
      default:
        return 'مصروفات أخرى';
    }
  }

  // Screen 50 Export & Incoterms Additions
  @override
  String get landedCostExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get landedCostExportExcelBtn => 'تصدير إكسيل';
  @override
  String get landedCostPrintPdfBtn => 'طباعة مستند متجه';
  @override
  String get landedCostCopyDossierBtn => 'نسخ ملخص التكلفة';
  @override
  String get landedCostCopyDossierSuccess => 'تم نسخ ملخص تكلفة الوصول للحافظة بنجاح';
  @override
  String get landedCostDossierHeader => 'ملخص مقارنة تكلفة الوصول الشاملة للشحنة';
  @override
  String get landedCostExportTsvDialogTitle => 'تصدير مقارنة التكلفة كملف نصوص';
  @override
  String get landedCostExportExcelDialogTitle => 'تصدير مقارنة التكلفة لملف إكسيل';
  @override
  String get incoRuleExporterCoversLabel => 'مشمول في الفاتورة (على البائع):';
  @override
  String get incoRuleImporterCoversLabel => 'إضافات تكلفة الوصول (على المستورد):';
  @override
  String get incoCifRuleTitle => 'قاعدة تسليم شامل النولون والتأمين البحري';
  @override
  String get incoCifRuleDesc => 'فاتورة الشراء تشمل نولون الشحن الدولي والتأمين البحري. تكلفة الوصول الواصلة للمستورد تتكون من: قيمة الفاتورة الشاملة مع الضرائب والرسوم الجمركية وأتعاب التخليص ومصاريف الميناء والنقل الداخلي.';
  @override
  String get incoCifExporterCovers => 'النولون الدولي • التأمين البحري • إجراءات التصدير';
  @override
  String get incoCifImporterCovers => 'الجمارك والضرائب • أتعاب التخليص • رسوم محطة الوصول والميناء • النقل الداخلي';
  @override
  String get incoCfrRuleTitle => 'قاعدة تسليم شامل نولون الشحن فقط';
  @override
  String get incoCfrRuleDesc => 'فاتورة الشراء تشمل نولون الشحن الدولي فقط. تكلفة الوصول للمستورد تشمل: قيمة الفاتورة مع وثيقة التأمين البحري والضرائب والرسوم الجمركية وأتعاب التخليص والنقل الداخلي.';
  @override
  String get incoCfrExporterCovers => 'النولون الدولي • إجراءات التصدير';
  @override
  String get incoCfrImporterCovers => 'التأمين البحري • الجمارك والضرائب • أتعاب التخليص • النقل الداخلي';
  @override
  String get incoExwRuleTitle => 'قاعدة تسليم أرض المصنع بالمنشأ';
  @override
  String get incoExwRuleDesc => 'فاتورة الشراء تغطي ثمن البضاعة بأرض المصنع فقط. المستورد يتحمل كافة التكاليف من بلد المنشأ حتى الوصول: قيمة الفاتورة ونقل المنشأ وتخليص التصدير والنولون والتأمين والجمارك والتخليص والنقل الداخلي.';
  @override
  String get incoExwExporterCovers => 'تجهيز البضاعة بالمصنع';
  @override
  String get incoExwImporterCovers => 'نقل وتخليص المنشأ • النولون والتأمين • الجمارك والضرائب • التخليص والنقل الداخلي';
  @override
  String get incoDdpRuleTitle => 'قاعدة تسليم خالص الرسوم والجمارك والضرائب';
  @override
  String get incoDdpRuleDesc => 'فاتورة الشراء تغطي كافة التكاليف بما فيها الشحن والتأمين والرسوم الجمركية والتوصيل. المستورد لا يتحمل سوى أي مصاريف استثنائية للتخزين إن وجدت.';
  @override
  String get incoDdpExporterCovers => 'النولون والتأمين • الضرائب والجمارك • النقل حتى المستودع';
  @override
  String get incoDdpImporterCovers => 'التفريغ أو التخزين الاستثنائي';
  @override
  String get incoFobRuleTitle => 'قاعدة تسليم على ظهر السفينة بميناء الشحن';
  @override
  String get incoFobRuleDesc => 'فاتورة الشراء تشمل ثمن البضاعة وتحميلها على السفينة بميناء الشحن. تكلفة الوصول للمستورد تتكون من: قيمة الفاتورة المعتمدة ونولون الشحن والتأمين البحري والرسوم الجمركية والضرائب والتخليص والنقل الداخلي.';
  @override
  String get incoFobExporterCovers => 'نقل وتخليص المنشأ • التحميل بميناء الشحن';
  @override
  String get incoFobImporterCovers => 'النولون الدولي • التأمين البحري • الجمارك والضرائب • التخليص والنقل الداخلي';
  @override
  String get landedCostTsvHeaderSection => 'القسم';
  @override
  String get landedCostTsvHeaderCodeOrCategory => 'الكود أو الفئة';
  @override
  String get landedCostTsvHeaderNameOrProvider => 'البيان أو المورد';
  @override
  String get landedCostTsvHeaderQtyOrCurrency => 'الكمية أو العملة';
  @override
  String get landedCostTsvHeaderUnitPriceOrFx => 'سعر الوحدة أو القيمة الأجنبية';
  @override
  String get landedCostTsvHeaderExchangeRate => 'سعر الصرف';
  @override
  String get landedCostTsvHeaderTotalCostEgp => 'القيمة بالجنيه المصري';
  @override
  String get landedCostTsvHeaderMarkupOrVariance => 'معامل التكلفة أو نسبة الانحراف';

  // ==========================================
  // Screen 51: Central Docs Hub (CentralDocsArchiveScreen)
  // ==========================================
  @override
  String get centralDocsArchiveTitle => 'الأرشيف المركزي لمستندات وتعديلات الشحنة';
  @override
  String get closeAndReturn => 'إغلاق والعودة';
  @override
  String get selectCentralArchiveFileLabel => 'اختر ملف الشحنة للاستعراض المركزي';
  @override
  String get selectCentralArchiveFileHint => 'ابحث برقم الملف أو اسم المستورد أو المورد...';
  @override
  String get refreshArchiveBtn => 'تحديث الأرشيف';
  @override
  String get selectShipmentFilePrompt => 'يرجى اختيار ملف شحنة من القائمة أعلاه';
  @override
  String get centralArchivePlaceholderDesc => 'سيتم استعراض الفاتورة النهائية، قائمة التعبئة، مسودة البوليصة، مسودة شهادة المنشأ، شهادة الفحص، وملخص التعديلات فوراً.';
  @override
  String get centralArchiveLoadingPrompt => 'جارٍ جلب وتجميع الأرشيف المركزي ومطابقة المستندات...';
  @override
  String centralArchiveLoadError(dynamic error) => 'خطأ أثناء جلب بيانات الأرشيف: $error';
  @override
  String get readinessReadyForRelease => 'جاهز تماماً للإفراج والرفع على كارجو إكس';
  @override
  String get readinessActionRequired => 'يتطلب تصحيحات وتعديلات حاسمة قبل إصدار الأصول';
  @override
  String get readinessInReview => 'قيد استكمال ومراجعة مسودات المستندات';
  @override
  String fileCodeLabel(dynamic code) => 'كود الملف: $code';
  @override
  String customsFileNumberLabel(dynamic num) => 'رقم الملف الجمركي: $num';
  @override
  String get importerCompanyLabel => 'الشركة المستوردة:';
  @override
  String get exporterSupplierLabel => 'المورد الأجنبي أو المصدر:';
  @override
  String get acidNumberLabel => 'رقم القيد الجمركي (اسيد):';
  @override
  String get shippingRouteLabel => 'مسار الشحن (ميناء الشحن إلى ميناء التفريغ):';
  @override
  String get totalPackagesAndWeightLabel => 'إجمالي الطرود والوزن:';
  @override
  String get totalInvoiceValueLabel => 'القيمة الإجمالية:';
  @override
  String packagesCountText(dynamic pkgs, dynamic weight) => '$pkgs طرد | $weight كجم';
  @override
  String get complianceReportHeader => 'تقرير مطابقة متطلبات الاستيراد والرقابة النوعية';
  @override
  String complianceSummaryTag(dynamic origin, dynamic hsCode, dynamic commodity) => 'المنشأ: $origin | بند التعريفة: $hsCode | $commodity';
  @override
  String get chipCooLabel => 'شهادة المنشأ';
  @override
  String cooRequiredText(dynamic type) => 'مطلوبة ($type)';
  @override
  String get cooNotRequiredText => 'معفاة وغير مطلوبة';
  @override
  String get chipVocLabel => 'فحص ما قبل الشحن';
  @override
  String inspRequiredText(dynamic agency) => 'مطلوب ($agency)';
  @override
  String get inspNotRequiredText => 'غير خاضع للرقابة';
  @override
  String get chipDecree43Label => 'قرار ثلاثة وأربعين وتسجيل المصنع';
  @override
  String get decree43WhiteListed => 'مسجل بالقائمة البيضاء';
  @override
  String get decree43RegistrationRequired => 'يلزم قيد المصنع';
  @override
  String get decree43NotApplicable => 'غير خاضع';
  @override
  String get masterRectificationsHeader => 'ملخص التعديلات والفروق المطلوبة الصريحة:';
  @override
  String get copySupplierEmailBtn => 'نسخ إيميل التعديلات للمورد';
  @override
  String get copySupplierEmailSuccess => 'تم نسخ إيميل التعديلات للمورد بنجاح';
  @override
  String get copyWhatsAppBtn => 'نسخ رسالة واتساب';
  @override
  String get copyWhatsAppSuccess => 'تم نسخ رسالة واتساب السريعة بنجاح';
  @override
  String get noDiscrepanciesSuccessMessage => 'لا توجد أي فروق أو تعديلات مطلوبة. كافة المسودات مطابقة تماماً وجاهزة للإفراج والرفع على كارجو إكس.';
  @override
  String get severityCritical => 'حرج مانع للإفراج';
  @override
  String get severityWarning => 'تنبيه تحذيري';
  @override
  String discrepancyIssueLabel(dynamic issue) => 'الملاحظة: $issue';
  @override
  String discrepancyRectificationLabel(dynamic rect) => 'التعديل المطلوب: $rect';
  @override
  String get fiveCoreDocsSectionTitle => 'أرشيف المستندات الخمسة المعتمدة وتفاصيل التعديلات لكل وثيقة:';
  @override
  String get docTitleCommercialInvoice => '١. الفاتورة التجارية النهائية المعتمدة';
  @override
  String get docTitlePackingList => '٢. قائمة التعبئة النهائية المعتمدة';
  @override
  String get docTitleBillOfLading => '٣. مسودة بوليصة الشحن البحرية';
  @override
  String get docTitleCertificateOfOrigin => '٤. مسودة شهادة المنشأ';
  @override
  String get docTitleInspectionCertificate => '٥. مسودة شهادة الفحص والمطابقة النوعية';
  @override
  String get docMandatoryCore => 'إلزامي حتمي';
  @override
  String get docConditional => 'شرطي وحسب البند';
  @override
  String docReferenceLabel(dynamic ref) => 'المرجع: $ref';
  @override
  String get docStatusWaived => 'معفاة وغير مطلوبة';
  @override
  String get docStatusApproved => 'معتمد بنجاح';
  @override
  String get docStatusModificationsRequested => 'مطلوب تعديلات';
  @override
  String get docStatusReviewPending => 'قيد التدقيق';
  @override
  String get docStatusNotStarted => 'غير مدرج بعد';
  @override
  String get docModificationsRequestedTitle => 'التعديلات المطلوبة لهذا المستند:';
  @override
  String get docWaivedDefaultDesc => 'هذا المستند غير مطلوب ومعفى قانونياً ولا يؤثر على جاهزية الإفراج.';
  @override
  String get docNoDiscrepanciesDesc => 'هذا المستند لا يحتوي على أي ملاحظات أو فروق.';

  // Screen 51 Export & Toolbar Getters
  @override
  String get centralDocsExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get centralDocsExportExcelBtn => 'تصدير جدول إكسيل';
  @override
  String get centralDocsPrintPdfBtn => 'طباعة وحفظ مستند';
  @override
  String get centralDocsCopyDossierBtn => 'نسخ الملخص الشامل';
  @override
  String get centralDocsCopyDossierSuccess => 'تم نسخ ملخص الأرشيف المركزي للشحنة بنجاح';
  @override
  String get centralDocsDossierHeader => 'ملخص الأرشيف المركزي لمستندات وتعديلات الشحنة';
  @override
  String get centralDocsExportTsvDialogTitle => 'حفظ جدول نصوص الأرشيف المركزي';
  @override
  String get centralDocsExportExcelDialogTitle => 'حفظ جدول إكسيل للأرشيف المركزي';
  @override
  String get centralDocsTsvHeaderDocName => 'اسم المستند';
  @override
  String get centralDocsTsvHeaderDocType => 'طبيعة المستند';
  @override
  String get centralDocsTsvHeaderRefNo => 'الرقم المرجعي';
  @override
  String get centralDocsTsvHeaderStatus => 'الحالة الإجرائية';
  @override
  String get centralDocsTsvHeaderDiscrepanciesCount => 'عدد الملاحظات';
  @override
  String get centralDocsTsvHeaderIssues => 'الملاحظات والفروق';
  @override
  String get centralDocsTsvHeaderRectifications => 'التعديلات المطلوبة';
  @override
  String get centralDocsTsvHeaderLegalNote => 'السند القانوني أو سبب الإعفاء';
  @override
  String get centralDocsDossierComplianceTitle => 'مطابقة متطلبات الاستيراد والرقابة النوعية';
  @override
  String get centralDocsDossierCoreDocsTitle => 'المستندات الأساسية والشرطية';
  @override
  String get centralDocsDossierDiscrepanciesTitle => 'سجل الملاحظات والتعديلات المطلوبة';
  @override
  String get centralDocsCopyDetailSuccess => 'تم نسخ بيان المستند بنجاح';
  @override
  String get centralDocsCopyDiscrepancySuccess => 'تم نسخ تفاصيل التعديل بنجاح';

  // Screen 53: Draft Inspection COC (ShipmentDraftDocsScreen & InspectionReviewTab)
  @override
  String get inspStepRequirements => 'متطلبات شهادة الفحص والمطابقة';
  @override
  String get inspStepDraftInput => 'إدخال واستخراج الدرافت';
  @override
  String get inspStepDiscrepancyMatrix => 'مصفوفة المقارنة والفروق';
  @override
  String get inspStepRegistry => 'سجل شهادات الفحص المعتمدة';
  @override
  String existingInspectionReviewBanner(dynamic code, dynamic status) =>
      'توجد دراسة مسجلة مسبقاً لهذا الملف [كود الجلسة: $code - الحالة: $status]. سيتم تحديث وتعديل نفس الدراسة المعتمدة لضمان عدم تكرار السجلات.';
  @override
  String get inspectionRegistryBtn => 'سجل الشهادات';
  @override
  String get inspRequirementsHeader => 'توليد متطلبات شهادة الفحص المسبق قبل الشحن';
  @override
  String get selectInspectionFileLabel => 'اختر ملف الشحنة *';
  @override
  String get selectInspectionFileHint => 'ابحث برقم الملف...';
  @override
  String get inspectionCertTypeLabel => 'نوع شهادة الفحص *';
  @override
  String get inspectionCertTypeHint => 'اختر نوع الفحص...';
  @override
  String get optInspectionCoc => 'شهادة المطابقة النوعية';
  @override
  String get optInspectionCoa => 'شهادة التحليل المخبري';
  @override
  String get optInspectionVoc => 'التحقق من المطابقة';
  @override
  String get optInspectionPsi => 'تقرير المعاينة قبل الشحن';
  @override
  String get inspectionAgencyLabel => 'جهة الفحص الدولية *';
  @override
  String get inspectionAgencyHint => 'اختر جهة الفحص...';
  @override
  String get openInspectionPreviewBtn => 'فتح المعاينة والتصدير';
  @override
  String get nextInspectionInputBtn => 'التالي: إدخال الدرافت';
  @override
  String inspectionVisualPreviewDialogTitle(dynamic agency, dynamic certType) =>
      'المعاينة المصورة لمسودة شهادة الفحص: $agency ($certType)';
  @override
  String get applyInspectionDraftDataBtn => 'اعتماد وتعبئة الحقول تلقائياً';
  @override
  String get inspectionDraftDataAppliedSuccess => 'تم ملء بيانات درافت شهادة الفحص بنجاح';
  @override
  String get inspDraftInputHeader => 'إدخال واستخراج بيانات درافت شهادة الفحص';
  @override
  String get runInspectionComparisonBtn => 'تشغيل المطابقة';
  @override
  String get linkedInspectionFileLabel => 'اختر ملف الشحنة المربوط *';
  @override
  String get linkedInspectionFileHint => 'ابحث برقم الملف أو اسم الشركة...';
  @override
  String get pleaseSelectInspectionFileWarning =>
      'يرجى اختيار وتحديد ملف الشحنة أولاً حتى يتم استخراج البيانات ومقارنتها بسجلات النظام.';
  @override
  String get certNumberFieldLabel => 'رقم درافت الشهادة *';
  @override
  String get regulatoryAuthorityFieldLabel => 'الجهة الرقابية المصرية المختصة *';
  @override
  String get inspectedInvoiceNumberFieldLabel => 'رقم الفاتورة الخاضعة للفحص *';
  @override
  String get exporterShipperFieldLabel => 'اسم المصدر أو الشاحن *';
  @override
  String get importerApplicantFieldLabel => 'اسم المستورد أو طالب الفحص *';
  @override
  String get standardSpecFieldLabel => 'المواصفة القياسية المعتمدة *';
  @override
  String get smartUploadInspectionBtn => 'رفع واستخراج شهادة الفحص الذكي';
  @override
  String get rawTextInspectionHeader => 'النص الخام لدرافت شهادة الفحص';
  @override
  String get smartExtractFromTextBtn => 'استخراج ومطابقة ذكية من النص';
  @override
  String get rawTextInspectionHint => 'الصق النص الكامل لشهادة الفحص هنا...';
  @override
  String get pleaseSelectFileFirstPrompt => 'يرجى اختيار ملف الشحنة أولاً';
  @override
  String inspectionComparisonError(dynamic err) => 'خطأ أثناء المقارنة: $err';
  @override
  String get overrideReasonMandatoryWarning =>
      'يجب كتابة سبب ومبرر الموافقة على الاختلافات قبل الاعتماد والحفظ، أو الضغط على العودة للتعديل ومخاطبة المورد.';
  @override
  String get saveInspectionReviewSuccess => 'تم حفظ جلسة مراجعة شهادة الفحص بنجاح بالسجل';
  @override
  String saveInspectionReviewError(dynamic err) => 'خطأ في الحفظ: $err';
  @override
  String get generateDraftSelectFileFirstPrompt => 'يرجى اختيار ملف الشحنة أولاً لتوليد درافت شهادة الفحص';
  @override
  String get cancelAndClose => 'إلغاء وإغلاق';
  @override
  String get exportPdfBtn => 'تصدير التقرير';
  @override
  String get exportExcelBtn => 'تصدير جدول البيانات';
  @override
  String generateDraftError(dynamic err) => 'خطأ أثناء توليد المسودة: $err';
  @override
  String get pasteRawTextFirstPrompt => 'يرجى لصق نص شهادة الفحص أو رفع الملف أولاً';
  @override
  String inspectionOcrWarningsAlert(dynamic warnings) => 'تنبيهات الاستخراج: $warnings';
  @override
  String get inspectionDraft48hWarningAlert =>
      'تم اكتشاف مسودة — يرجى تأكيد الفحص خلال مهلة الـ 48 ساعة لتفادي رفض الإفراج.';
  @override
  String get inspectionExtractionSuccess => 'تم استخراج ومطابقة بيانات شهادة الفحص والمطابقة بنجاح';
  @override
  String get mustSelectFileForMatrixWarning => 'يجب اختيار ملف الشحنة أولاً لعرض مصفوفة المقارنة';
  @override
  String get returnToSelectFileBtn => 'العودة لاختيار الملف';
  @override
  String get pleaseRunComparisonPrompt => 'يرجى تشغيل المطابقة في الخطوة السابقة لاستعراض مصفوفة الفروق';
  @override
  String get returnToRunComparisonBtn => 'العودة لتشغيل المطابقة';
  @override
  String get hasCriticalMismatchStatus => 'توجد اختلافات حرجة في بيانات شهادة الفحص';
  @override
  String get hasMinorDiscrepanciesStatus => 'توجد فروق طفيفة في بيانات شهادة الفحص';
  @override
  String get inspectionConforms100Status => 'شهادة الفحص مطابقة تماماً بنسبة 100%';
  @override
  String get exportingInspectionPdfPrompt => 'جارٍ تصدير تقرير مطابقة شهادة الفحص...';
  @override
  String get copiedInspectionExcelSuccess => 'تم نسخ وتصدير بيانات المطابقة إلى جدول البيانات بنجاح';
  @override
  String get saveToInspectionRegistryBtn => 'حفظ بالسجل';
  @override
  String get colInspField => 'الحقل';
  @override
  String get colInspSystemValue => 'القيمة بالنظام';
  @override
  String get colInspDraftValue => 'القيمة بالدرافت';
  @override
  String get colInspMatchStatus => 'حالة التطابق';
  @override
  String get colInspDetails => 'التفاصيل';
  @override
  String get inspOverrideReasonBoxTitle => 'سبب ومبررات الموافقة على الاختلافات (إلزامي للاعتماد والحفظ):';
  @override
  String get inspOverrideReasonBoxDesc =>
      'عند وجود فروق أو اختلافات في شهادة الفحص والمطابقة، يجب تسجيل سبب الموافقة والاعتماد، أو الضغط على العودة للتعديل ومخاطبة المورد.';
  @override
  String get inspOverrideReasonFieldLabel => 'سبب ومبرر الموافقة على الاختلافات *';
  @override
  String get inspOverrideReasonFieldHint => 'اكتب مبررات قبول الاختلافات هنا قبل الحفظ...';
  @override
  String get approveAndSaveWithReasonBtn => 'اعتماد وحفظ مع ذكر سبب الموافقة';
  @override
  String get returnToEditAndContactSupplierBtn => 'العودة لتعديل المسودة ومخاطبة المورد';
  @override
  String inspReviewsRegistryTitle(dynamic count) => 'سجل مراجعات واعتماد شهادات الفحص والتفتيش ($count جلسة)';
  @override
  String get startNewInspReviewBtn => 'بدء مراجعة جديدة';
  @override
  String get noInspReviewsYet => 'لا توجد جلسات مراجعة مسجلة لشهادات الفحص حتى الآن.';
  @override
  String get colInspSessionCode => 'كود الجلسة';
  @override
  String get colInspCertType => 'نوع الفحص';
  @override
  String get colInspAgency => 'جهة الفحص';
  @override
  String get colInspCertNo => 'رقم الشهادة';
  @override
  String get colInspStatus => 'الحالة';
  @override
  String get colInspCreatedAt => 'تاريخ الإنشاء';
  @override
  String get colInspActions => 'الإجراءات';
  @override
  String get editInspSessionTooltip => 'تعديل الجلسة';
  @override
  String get viewInspDetailsTooltip => 'معاينة التفاصيل';
  @override
  String get downloadInspPdfTooltip => 'تنزيل التقرير';
  @override
  String get deleteInspSessionTooltip => 'حذف الجلسة';
  @override
  String loadedInspSessionForEdit(dynamic code) => 'تم تحميل بيانات الجلسة ($code) للتعديل';
  @override
  String inspDetailsDialogTitle(dynamic code) => 'تفاصيل جلسة مراجعة شهادة الفحص: $code';
  @override
  String get tileInspTypeAndAgency => 'نوع الفحص والجهة المصدرة';
  @override
  String get tileInspCertNoAndStatus => 'رقم الشهادة والحالة';
  @override
  String get tileInspOverrideReason => 'سبب ومبرر الموافقة على الاختلافات';
  @override
  String get sectionInspDiscrepancyMatrix => 'مصفوفة الفروق والمطابقة:';
  @override
  String get confirmDeleteInspSessionTitle => 'تأكيد حذف جلسة مراجعة الفحص';
  @override
  String confirmDeleteInspSessionContent(dynamic code, dynamic cert) =>
      'هل أنت متأكد من حذف جلسة المراجعة رقم ($code) لشهادة ($cert)؟';
  @override
  String get inspSessionDeletedSuccess => 'تم حذف جلسة مراجعة الفحص بنجاح';
  @override
  String deleteInspSessionError(dynamic err) => 'خطأ في الحذف: $err';
  @override
  String visualDraftInspectionToolbarTitle(dynamic agency, dynamic certType) =>
      'مسودة شهادة الفحص والمطابقة: $agency ($certType)';
  @override
  String get liveRefreshTooltip => 'تحديث حي للبيانات المستدعاة';
  @override
  String get copyInspectionDataBtn => 'نسخ البيانات';
  @override
  String get copiedInspectionDataSuccess => 'تم نسخ بيانات شهادة الفحص إلى الحافظة';
  @override
  String get saveExcelCsvBtn => 'حفظ جدول البيانات';
  @override
  String get excelReadySuccess => 'تم تجهيز بيانات جدول البيانات لشهادة الفحص بنجاح';
  @override
  String get savePrintPdfBtn => 'حفظ وطباعة التقرير';
  @override
  String get egyptVerificationOfConformityHeader => 'التحقق الإلزامي من المطابقة في مصر';
  @override
  String get countryOfOriginHeader => 'بلاد المنشأ المستدعاة:';
  @override
  String get hsCodesHeader => 'بنود التعريفة الجمركية:';
  @override
  String get commercialInvoicesHeader => 'الفواتير التجارية المرفقة الخاضعة للفحص:';
  @override
  String get colInvoiceAmountCurrency => 'القيمة والعملة';
  @override
  String get colInvoiceNo => 'رقم الفاتورة';
  @override
  String get colInvoiceDate => 'تاريخ الفاتورة';
  @override
  String get colIncoterm => 'الشرط التجاري';
  @override
  String methodOfShipmentLabel(dynamic val) => 'طريقة الشحن: $val';
  @override
  String countryOfShipmentLabel(dynamic val) => 'بلد الشحن: $val';
  @override
  String pointOfEntryLabel(dynamic val) => 'ميناء الوصول: $val';
  @override
  String totalDeclaredValueLabel(dynamic val) => 'القيمة الإجمالية المصرح عنها: $val';
  @override
  String get inspectedItemsHeader => 'بنود البضائع والمواصفات المعتمدة:';
  @override
  String get colItemNo => 'م';
  @override
  String get colQuantity => 'الكمية';
  @override
  String get colOrigin => 'المنشأ';
  @override
  String get colProductType => 'نوع المنتج';
  @override
  String get colDescriptionBrandModel => 'الوصف (الماركة والموديل)';
  @override
  String get colAdoptedStandard => 'المواصفة المعتمدة';
  @override
  String placeOfInspectionLabel(dynamic val) => 'مكان الفحص: $val';
  @override
  String dateOfInspectionLabel(dynamic val) => 'تاريخ الفحص: $val';
  @override
  String issuingOfficeLabel(dynamic val) => 'المكتب المصدر: $val';
  @override
  String get egyptianMandatoryStandardsHeader => 'المواصفات القياسية المصرية وبروتوكولات الفحص:';
  @override
  String get conformityAssessmentResultConforming => 'نتيجة تقييم المطابقة: مطابق وصالح للإفراج الجمركي';
  @override
  String authorizedAgencyLabel(dynamic val) => 'الجهة المعتمدة: $val';
  @override
  String get egyptianCustomsComplianceHeader => 'الامتثال الجمركي والرقابي المصري';
  @override
  String get importerCellLabel => 'المستورد (الاسم، العنوان والرقم الضريبي):';
  @override
  String get exporterCellLabel => 'المصدر والمصنع (الاسم والعنوان):';
  @override
  String get exportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get copyDossierBtn => 'نسخ دوسيه الفحص الشامل';
  @override
  String get copiedDossierSuccess => 'تم نسخ دوسيه الفحص الشامل إلى الحافظة بنجاح';
  @override
  String get copiedInspectionTsvSuccess => 'تم تجهيز وتصدير جدول نصوص الفحص بنجاح';
  @override
  String get exportTsvDialogTitle => 'حفظ جدول نصوص فحص الشحنة';
  @override
  String get exportExcelDialogTitle => 'حفظ جدول بيانات فحص الشحنة';
  @override
  String get exportPdfDialogTitle => 'حفظ مسودة شهادة الفحص والمطابقة';
  @override
  String cocNoPrefix(dynamic val) => 'رقم الشهادة: $val';
  @override
  String acidNoPrefix(dynamic val) => 'رقم القيد الجمركي: $val';
  @override
  String get certHeaderCocVoc => 'شهادة المطابقة النوعية والتفتيش الفني';
  @override
  String get noticeBannerDraftConfirm => 'مسودة للتحقق — يرجى التأكيد خلال 48 ساعة قبل الإصدار النهائي لتفادي التعطيل الجمركي';
  @override
  String get importerTaxIdHeader => 'بيانات المستورد (الاسم، العنوان، والرقم الضريبي)';
  @override
  String get exporterProducerHeader => 'بيانات المصدر والمنتج (الاسم والعنوان)';
  @override
  String get inspectionDossierHeader => 'ملف ودوسيه مراجعة واعتماد شهادة الفحص والمطابقة';
  @override
  String get inspectionDossierBasicInfo => 'البيانات الأساسية والجهات المعنية';
  @override
  String get inspectionDossierInvoices => 'الفواتير التجارية المرفقة الخاضعة للفحص';
  @override
  String get inspectionDossierItems => 'بنود البضائع المفحوصة والمواصفات المعتمدة';
  @override
  String get inspectionDossierStandards => 'المواصفات القياسية المصرية وبروتوكولات الفحص';
  @override
  String get inspectionDossierDiscrepancies => 'نتائج مصفوفة المقارنة والمطابقة والفروق';
  @override
  String get colTsvItemNo => 'م';
  @override
  String get colTsvProductType => 'نوع المنتج';
  @override
  String get colTsvOrigin => 'بلد المنشأ';
  @override
  String get colTsvDescription => 'الوصف والماركة والموديل';
  @override
  String get colTsvQuantity => 'الكمية';
  @override
  String get colTsvStandard => 'المواصفة القياسية المعتمدة';

  // ── Screen 54: CargoX Blockchain Hub & Standard Commercial Invoice ──────────
  @override
  String get cargoxHubTitle => 'منظومة كارجو إكس والبلوك تشين والمانيفست الرقمي';
  @override
  String get cargoxLiveRefreshTooltip => 'تحديث حي';
  @override
  String get cargoxEmbeddedTitle => 'منظومة كارجو إكس والبلوك تشين:';
  @override
  String get cargoxTabStandardInvoice => 'الفاتورة المعيارية والمطابقة';
  @override
  String get cargoxTabCreateEnvelope => 'تجهيز وتوليد المظروف';
  @override
  String get cargoxTabTrackingHub => 'مركز تتبع أظرف البلوك تشين';
  @override
  String get cargoxTabManifestViewer => 'معاينة وتصدير المانيفست الرقمي';
  @override
  String get cargoxSegStandardInvoice => 'الفاتورة المعيارية';
  @override
  String get cargoxSegCreateEnvelope => 'تجهيز المظروف';
  @override
  String get cargoxSegTrackingHub => 'تتبع البلوك تشين';
  @override
  String get cargoxSegManifestViewer => 'المانيفست الرقمي';

  // Tab 1: Envelope Creation
  @override
  String get cargoxEnvelopeGenTitle => 'تجهيز وتوليد مظروف كارجو إكس المشفر';
  @override
  String get cargoxEnvelopeGenDesc => 'يتم إنشاء المظروف الرقمي وتوقيعه إلكترونياً بالتشفير الرقمي وربطه برقم القيد الجمركي ومستندات الشحن المعتمدة قبل التحويل لمصلحة الجمارك المصرية.';
  @override
  String get cargoxSection1ShipmentAcid => '١. بيانات الشحنة والربط مع منظومة التسجيل المسبق للشحنات:';
  @override
  String get cargoxImportFileField => 'ملف الشحنة الاستيرادية *';
  @override
  String get cargoxSearchFileHint => 'ابحث عن ملف الشحنة...';
  @override
  String get cargoxUnlinkedOption => '-- غير مرتبط بملف شحنة --';
  @override
  String get cargoxAcidNumberField => 'رقم القيد الجمركي المسبق (١٩ رقماً) *';
  @override
  String get cargoxAcidValidationDigits => 'يجب أن يتكون من ١٩ رقماً';
  @override
  String get cargoxBlNumberField => 'رقم بوليصة الشحن';
  @override
  String get cargoxImporterCompanyField => 'الشركة المستوردة *';
  @override
  String get cargoxForeignSupplierField => 'المورد الأجنبي *';
  @override
  String get cargoxSupplierCargoxIdField => 'معرف منصة كارجو إكس للمورد *';
  @override
  String get cargoxSection2AttachedDocs => '٢. قائمة المستندات المحملة داخل المظروف:';
  @override
  String get cargoxRestoreDefaultDocsBtn => 'استعادة القائمة القياسية';
  @override
  String get cargoxColDocType => 'نوع المستند';
  @override
  String get cargoxColDocNumber => 'رقم المرجع';
  @override
  String get cargoxColFileName => 'اسم الملف';
  @override
  String get cargoxColFileSize => 'الحجم (كيلوبايت)';
  @override
  String get cargoxColAcidMatch => 'مطابقة القيد الجمركي';
  @override
  String get cargoxColActions => 'حذف';
  @override
  String get cargoxDocMatchedBadge => 'مطابق بنسبة مئة بالمئة';
  @override
  String get cargoxAddDocToEnvelopeBtn => 'إضافة مستند جديد للمظروف';
  @override
  String get cargoxAddDocDialogTitle => 'إضافة مستند جديد للمظروف';
  @override
  String get cargoxDocTypeField => 'نوع المستند *';
  @override
  String get cargoxDocNumberField => 'رقم المستند';
  @override
  String get cargoxDocFileNameField => 'اسم الملف *';
  @override
  String get cargoxAddDocSubmitBtn => 'إضافة للمظروف';
  @override
  String get cargoxGenerateAndSignEnvelopeBtn => 'توليد وتوقيع مظروف كارجو إكس بالبلوك تشين';
  @override
  String get cargoxAtLeastOneDocError => 'يرجى إضافة مستند واحد على الأقل داخل المظروف';
  @override
  String cargoxEnvelopeCreatedSuccess(dynamic code) => 'تم توليد وتوقيع مظروف كارجو إكس بنجاح ($code)';
  @override
  String get cargoxEnvelopeCreateError => 'خطأ أثناء إنشاء المظروف';

  // Tab 2: Tracking Hub
  @override
  String get cargoxMetricTotalEnvelopes => 'إجمالي المظاريف';
  @override
  String get cargoxMetricAcceptedCustoms => 'تم قبولها بالجمارك';
  @override
  String get cargoxMetricInProgress => 'قيد المعالجة والرفع';
  @override
  String get cargoxMetricAcidVerified => 'مطابقة القيد الجمركي بالكامل';
  @override
  String get cargoxSearchEnvelopesHint => 'ابحث برقم المظروف، رقم القيد، المورد، أو البوليصة...';
  @override
  String get cargoxFilterAllStatuses => 'جميع الحالات';
  @override
  String get cargoxFilterDraft => 'مسودة';
  @override
  String get cargoxFilterUploaded => 'مرفوع بالبلوك تشين';
  @override
  String get cargoxFilterAccepted => 'مقبول بالجمارك';
  @override
  String get cargoxPrepareNewEnvelopeBtn => 'تجهيز مظروف جديد';
  @override
  String get cargoxNoEnvelopesFound => 'لا توجد مظاريف مطابقة لشروط البحث';
  @override
  String get cargoxMetaAcidNumber => 'رقم القيد الجمركي المسبق:';
  @override
  String get cargoxMetaSupplier => 'المورد الأجنبي:';
  @override
  String get cargoxMetaSupplierCargoxId => 'معرف كارجو إكس للمورد:';
  @override
  String get cargoxMetaBlNumber => 'رقم البوليصة:';
  @override
  String get cargoxMetaPendingIssuance => 'قيد الإصدار';
  @override
  String get cargoxMetaBlockchainTxHash => 'معرّف المعاملة بالبلوك تشين:';
  @override
  String get cargoxMetaCustomsReceipt => 'إيصال الجمارك:';
  @override
  String get cargoxCopiedToClipboard => 'تم النسخ إلى الحافظة بنجاح';
  @override
  String get cargoxCheckAcidBtn => 'فحص القيد الجمركي';
  @override
  String get cargoxDigitalManifestBtn => 'المانيفست الرقمي';
  @override
  String get cargoxSealAndTransferBtn => 'إغلاق وتحويل للجمارك';
  @override
  String get cargoxDeliveredAndAcceptedBadge => 'تم التسليم والاعتماد الجمركي';
  @override
  String cargoxAcidReportDialogTitle(dynamic code) => 'تقرير مطابقة القيد الجمركي ($code)';
  @override
  String cargoxTargetAcidLabel(dynamic acid) => 'رقم القيد الجمركي المستهدف: $acid';
  @override
  String cargoxMatchRatioLabel(dynamic match, dynamic total) => 'نسبة المطابقة: $match من إجمالي $total مستندات';
  @override
  String get cargoxConfirmSealTransferTitle => 'تأكيد الإغلاق والتحويل للجمارك';
  @override
  String cargoxConfirmSealTransferContent(dynamic code) => 'هل أنت متأكد من إغلاق المظروف ($code) وتوقيعه رقمياً وتحويله لمنظومة نافذة والجمارك المصرية؟';
  @override
  String get cargoxConfirmTransferBtn => 'تأكيد التحويل الجمركي';
  @override
  String cargoxSealSuccessSnackbar(dynamic msg, dynamic receipt) => '$msg (إيصال: $receipt)';
  @override
  String get cargoxAcidCheckError => 'خطأ أثناء فحص القيد الجمركي';
  @override
  String get cargoxTransferError => 'خطأ أثناء تحويل المظروف للجمارك';
  @override
  String get cargoxFetchManifestError => 'خطأ أثناء جلب المانيفست الرقمي';

  // Tab 3: Manifest Viewer
  @override
  String cargoxManifestTitle(dynamic code, dynamic acid) => 'المانيفست الرقمي الرسمي: $code (رقم القيد: $acid)';
  @override
  String get cargoxCopyJsonBtn => 'نسخ البيانات الرقمية';
  @override
  String get cargoxManifestCopiedToast => 'تم نسخ المانيفست الرقمي إلى الحافظة بنجاح';
  @override
  String get cargoxSelectEnvelopeForManifestPrompt => 'يرجى اختيار مظروف من مركز التتبع لعرض المانيفست الرقمي الخاص به';

  // Standard Commercial Invoice Hub SubTab
  @override
  String get standardInvoiceHubTitle => 'مركز إدارة وتوليد الفاتورة التجارية المعيارية';
  @override
  String get standardInvoiceHubDesc => 'توليد نموذج إكسيل الموحد ذو النطاقات المسمّاة، مطابقة بيانات المورد آلياً، واكتشاف الفروق الجمركية قبل إرسال المظروف لكارجو إكس ونافذة.';
  @override
  String get standardInvoiceFileSelectorLabel => 'اختيار ملف الشحنة الاستيرادية *';
  @override
  String get standardInvoiceFileSelectorHint => 'ابحث برقم الملف، رقم القيد الجمركي، اسم المورد أو الشركة...';
  @override
  String get standardInvoiceFetchError => 'خطأ في تحميل ملفات الشحن:';
  @override
  String standardInvoiceExistingSessionTitle(dynamic code) => 'تم العثور على دراسة ومطابقة سابقة محفوظة لهذه الشحنة برقم: [$code]';
  @override
  String standardInvoiceExistingSessionSubtitle(dynamic date, dynamic status, dynamic total, dynamic curr, dynamic count) => 'تاريخ الحفظ: $date | الحالة: $status | إجمالي الفاتورة: $total $curr ($count بنود)';
  @override
  String get standardInvoiceViewSessionBtn => 'عرض التفاصيل';
  @override
  String get standardInvoiceTool1Title => '١. توليد نموذج الإكسيل المعياري';
  @override
  String get standardInvoiceTool1Subtitle => 'تجهيز ملف إكسيل بنطاقات مسمّاة لإرساله للمورد';
  @override
  String get standardInvoiceTool1Btn => 'تحميل نموذج إكسيل الموحد';
  @override
  String get standardInvoiceTool2Title => '٢. قراءة واستخراج فاتورة المورد';
  @override
  String get standardInvoiceTool2Subtitle => 'رفع ملف الإكسيل المكتمل واستخراجه آلياً';
  @override
  String get standardInvoiceTool2Btn => 'رفع وقراءة فاتورة المورد';
  @override
  String get standardInvoiceTabExtracted => 'بيانات الفاتورة المستخرجة';
  @override
  String get standardInvoiceTabComparison => 'مصفوفة المطابقة والفروق';
  @override
  String get standardInvoiceTabGovernance => 'الاعتماد والتحكم الجمركي';
  @override
  String get standardInvoiceTabRegistry => 'سجل الفواتير المعيارية';
  @override
  String get standardInvoiceTabCustomsTracks => 'المسارات الجمركية';
  @override
  String get standardInvoiceNoExtractedData => 'لم يتم رفع وقراءة ملف فاتورة المورد بعد.';
  @override
  String get standardInvoiceNoExtractedDataSub => 'قم بتحميل النموذج أولاً ثم ارفعه بعد قيام المورد بملء البيانات.';
  @override
  String standardInvoiceDetailsHeader(dynamic invNum, dynamic date) => 'تفاصيل الفاتورة: $invNum ($date)';
  @override
  String get standardInvoiceSellerCardTitle => 'بيانات المصدّر الأجنبي';
  @override
  String get standardInvoiceBuyerCardTitle => 'بيانات المستورد المحلي';
  @override
  String sellerCompanyLabel(dynamic company) => 'الشركة: $company';
  @override
  String sellerTaxIdLabel(dynamic taxId) => 'الرقم الضريبي: $taxId';
  @override
  String sellerCountryLabel(dynamic country) => 'الدولة: $country';
  @override
  String sellerAddressLabel(dynamic address) => 'العنوان: $address';
  @override
  String buyerCompanyLabel(dynamic company) => 'الشركة: $company';
  @override
  String buyerTaxIdLabel(dynamic taxId) => 'الرقم الضريبي: $taxId';
  @override
  String buyerAcidNumberLabel(dynamic acid) => 'رقم القيد الجمركي: $acid';
  @override
  String buyerIncotermAndCurrencyLabel(dynamic incoterm, dynamic curr) => 'شرط التسليم: $incoterm | العملة: $curr';
  @override
  String get standardInvoiceExtractedItemsHeader => 'جدول البنود المستخرجة';
  @override
  String get standardInvoiceNoComparisonData => 'لم يتم إجراء المطابقة بعد.';
  @override
  String get standardInvoiceNoComparisonDataSub => 'قم برفع فاتورة المورد لتشغيل محرك المطابقة واكتشاف الفروق تلقائياً.';
  @override
  String get standardInvoiceMatch100Banner => 'مطابقة تامة بنسبة مئة بالمئة — لا توجد أي فروق جمركية أو مالية';
  @override
  String standardInvoiceCriticalMismatchBanner(dynamic count) => 'تحذير جمركي حرج: يوجد $count عدم تطابق حرج (رقم القيد / الرقم الضريبي / بند التعريفة)';
  @override
  String standardInvoiceDiscrepanciesBanner(dynamic count) => 'تنبيه: يوجد $count اختلافات بسيطة تحتاج مراجعة قبل الاعتماد';
  @override
  String get standardInvoiceCompHeadersSection => '١. مطابقة الترويسة والبيانات الأساسية والامتثال الرقابي';
  @override
  String get standardInvoiceCompFinancialsSection => '٢. مطابقة القيم المالية والضرائب والتكاليف';
  @override
  String get standardInvoiceCompItemsSection => '٣. مصفوفة مطابقة بنود الأصناف والتعريفة الجمركية';
  @override
  String get standardInvoiceColComparedField => 'الحقل المقارن';
  @override
  String get standardInvoiceColSystemValue => 'القيمة المعتمدة بالنظام';
  @override
  String get standardInvoiceColSupplierValue => 'القيمة بفاتورة المورد';
  @override
  String get standardInvoiceColMatchStatus => 'حالة التطابق';
  @override
  String get standardInvoiceColDiffAndNotes => 'الفروق والملاحظات';
  @override
  String get standardInvoiceColHsSystem => 'بند التعريفة (النظام)';
  @override
  String get standardInvoiceColHsSupplier => 'بند التعريفة (المورد)';
  @override
  String get standardInvoiceColQtySystem => 'الكمية (النظام)';
  @override
  String get standardInvoiceColQtySupplier => 'الكمية (المورد)';
  @override
  String get standardInvoiceColPriceSystem => 'السعر (النظام)';
  @override
  String get standardInvoiceColPriceSupplier => 'السعر (المورد)';
  @override
  String get standardInvoiceRectificationSectionTitle => 'إخطارات تصحيح الفاتورة الجاهزة للمورد';
  @override
  String get standardInvoiceRectificationEnTitle => 'إخطار التصحيح بالإنجليزي (إيميل المورد)';
  @override
  String get standardInvoiceRectificationArTitle => 'إخطار التصحيح بالعربية (واتساب أو إيميل)';
  @override
  String get standardInvoiceGovernanceTitle => 'حالة اعتماد الفاتورة المعيارية والرقابة الإجرائية';
  @override
  String get standardInvoiceStatusDraft => 'مسودة';
  @override
  String get standardInvoiceStatusUnderReview => 'قيد المراجعة والتدقيق';
  @override
  String get standardInvoiceStatusApproved => 'معتمدة ومطابقة جمركياً';
  @override
  String get standardInvoiceStatusRejected => 'مرفوضة وتحتاج تعديل المورد';
  @override
  String get standardInvoiceOverrideWarningBanner => 'تنبيه إجرائي إلزامي: تم رصد فروق في الفاتورة. يُشترط كتابة مبرر وسبب التجاوز والاعتماد قبل الحفظ.';
  @override
  String get standardInvoiceOverrideReasonLabel => 'مبرر وسبب الموافقة على الاختلافات الجمركية *';
  @override
  String get standardInvoiceOverrideReasonHint => 'اكتب المبرر الإداري أو المالي للموافقة على الفروق...';
  @override
  String get standardInvoiceOverrideRequiredError => 'حقل إلزامي: لا يمكن اعتماد الفاتورة مع وجود فروق بدون توضيح السبب والمبرر.';
  @override
  String get standardInvoiceInternalNotesLabel => 'ملاحظات التدقيق الداخلي';
  @override
  String get standardInvoiceSaveSessionBtn => 'حفظ واعتماد جلسة مراجعة الفاتورة المعيارية';
  @override
  String standardInvoiceSessionSavedSuccess(dynamic code) => 'تم حفظ واعتماد جلسة مراجعة الفاتورة المعيارية بنجاح [$code]';
  @override
  String get standardInvoiceRegistrySearchHint => 'بحث في سجل الفواتير برقم الجلسة، رقم القيد، المورد...';
  @override
  String get standardInvoiceFilterAll => 'كل الحالات';
  @override
  String get standardInvoiceColSessionCode => 'كود الجلسة';
  @override
  String get standardInvoiceColFileCode => 'ملف الشحنة';
  @override
  String get standardInvoiceColAcid => 'رقم القيد';
  @override
  String get standardInvoiceColInvoiceNum => 'رقم الفاتورة';
  @override
  String get standardInvoiceColSupplier => 'المصدر الأجنبي';
  @override
  String get standardInvoiceColTotal => 'الإجمالي';
  @override
  String get standardInvoiceColItemsCount => 'البنود';
  @override
  String get standardInvoiceColStatus => 'الحالة';
  @override
  String get standardInvoiceColUpdatedAt => 'تاريخ التحديث';
  @override
  String get standardInvoiceNoSessionsFound => 'لا توجد جلسات فواتير مسجلة.';
  @override
  String get standardInvoiceSelectFileFirstError => 'يرجى اختيار ملف الشحنة أولاً.';
  @override
  String standardInvoiceGeneratedSuccess(dynamic fileCode, dynamic bytesLength) => 'تم توليد الفاتورة بنجاح: $fileCode ($bytesLength بايت)';
  @override
  String standardInvoiceExtractedSuccess(dynamic num, dynamic itemsCount) => 'تم استخراج الفاتورة بنجاح: $num ($itemsCount بنود)';
  @override
  String standardInvoiceSessionLoadedToast(dynamic code) => 'تم استدعاء بيانات الجلسة $code';
  @override
  String standardInvoiceCopiedToClipboard(dynamic label) => 'تم نسخ $label إلى الحافظة بنجاح';
  @override
  String get standardInvoiceMustProvideOverrideJustification => 'يجب كتابة سبب ومبرر اعتماد الفاتورة مع وجود فروق جمركية.';
  @override
  String get required => 'حقل إلزامي';
  @override
  String get errorPrefix => 'خطأ';
  @override
  String get copy => 'نسخ';
  @override
  String get colProductCode => 'كود الصنف';
  @override
  String get colHsCode => 'بند التعريفة';
  @override
  String get colDescription => 'الوصف التجاري';
  @override
  String get colUnit => 'الوحدة';
  @override
  String get colUnitPrice => 'سعر الوحدة';
  @override
  String get colTotalAmount => 'القيمة الإجمالية';
  @override
  String get colGrossWeight => 'الوزن الإجمالي';

  // Screen 54 Extensions: CargoX Toolbar, TSV/Excel Headers, Extraction Modes, Dossier
  @override
  String get cargoxExportTsvBtn => 'تصدير جدول مظاريف الشحنات';
  @override
  String get cargoxExportExcelBtn => 'تصدير إكسيل مظاريف الشحنات';
  @override
  String get cargoxPrintPdfBtn => 'طباعة تقرير المظاريف المتجه';
  @override
  String get cargoxCopyDossierBtn => 'نسخ ملخص منظومة الشحن الرقمية';
  @override
  String get cargoxCopiedDossierSuccess => 'تم نسخ ملخص منظومة كارجو إكس إلى الحافظة بنجاح';
  @override
  String get cargoxCopiedTsvSuccess => 'تم نسخ جدول المظاريف إلى الحافظة';
  @override
  String get cargoxCopiedExcelSuccess => 'تم تصدير ملف إكسيل المظاريف بنجاح';
  @override
  String get cargoxExportTsvDialogTitle => 'حفظ جدول مظاريف الشحنات';
  @override
  String get cargoxExportExcelDialogTitle => 'حفظ إكسيل مظاريف الشحنات';
  @override
  String get cargoxExportPdfDialogTitle => 'حفظ تقرير مظاريف الشحنات المتجه';
  @override
  String get cargoxAiDocumentExtractionBtn => 'استخلاص وتدقيق المستندات الذكي';
  @override
  String get cargoxTsvHeaderEnvelopeCode => 'كود المظروف';
  @override
  String get cargoxTsvHeaderImportFile => 'ملف الشحن';
  @override
  String get cargoxTsvHeaderAcid => 'رقم القيد الجمركي المبدئي';
  @override
  String get cargoxTsvHeaderSupplier => 'المورد الأجنبي';
  @override
  String get cargoxTsvHeaderSupplierCargoxId => 'معرف منصة كارجو إكس';
  @override
  String get cargoxTsvHeaderBlNumber => 'رقم بوليصة الشحن';
  @override
  String get cargoxTsvHeaderStatus => 'حالة المظروف الجمركي';
  @override
  String get cargoxTsvHeaderDocsCount => 'عدد المستندات';
  @override
  String get cargoxTsvHeaderTxHash => 'بصمة البلوك تشين الرقمية';
  @override
  String get cargoxTsvHeaderCustomsReceipt => 'إيصال الاستلام الجمركي';
  @override
  String get cargoxTsvHeaderTransferredAt => 'تاريخ الإرسال للجمارك';
  @override
  String get cargoxDossierHeader => 'ملف توثيق مظاريف الشحنات عبر منصة كارجو إكس والبلوك تشين';
  @override
  String get cargoxDossierMetricsTitle => 'مؤشرات الإرسال والتوثيق الجمركي';
  @override
  String get cargoxDossierEnvelopesTitle => 'بيان مظاريف الشحن الرقمية';
  @override
  String cargoxCopiedEnvelopeSuccess(dynamic code) => 'تم نسخ كود المظروف: $code';
  @override
  String cargoxCopiedAcidSuccess(dynamic acid) => 'تم نسخ رقم القيد الجمركي المبدئي: $acid';
  @override
  String get cargoxCopiedTxHashSuccess => 'تم نسخ بصمة البلوك تشين الرقمية';
  @override
  String get cargoxCopiedReceiptSuccess => 'تم نسخ إيصال الاستلام الجمركي';
  @override
  String get cargoxExtractEngineTitle => 'محرك استخلاص الفواتير متعدد المسارات';
  @override
  String cargoxExtractFileSubtitle(dynamic file, dynamic supplier, dynamic acid) => 'الملف: $file — المورد: $supplier (رقم القيد: $acid)';
  @override
  String get cargoxChooseExtractionPathPrompt => 'اختر مسار الاستخلاص المطلوب لملف الإكسيل:';
  @override
  String get cargoxModeConsolidatedTitle => '١. ملف واحد مجمع';
  @override
  String get cargoxModeConsolidatedSubtitle => 'دمج بنود نفس بند التعريفة الجمركية بالسعر المرجح (معتمد للجمارك المصرية)';
  @override
  String get cargoxModeDetailedTitle => '٢. ملف واحد مفصل';
  @override
  String get cargoxModeDetailedSubtitle => 'استخراج كل سطر بشكل منفصل بنفس تفاصيل أمر الشراء';
  @override
  String get cargoxModePerInvoiceConsolidatedTitle => '٣. ملف مجمع لكل فاتورة داخل أرشيف مضغوط';
  @override
  String get cargoxModePerInvoiceConsolidatedSubtitle => 'توليد ملف إكسيل مجمع منفصل لكل فاتورة داخل حزمة أرشيف';
  @override
  String get cargoxModePerInvoiceDetailedTitle => '٤. ملف مفصل لكل فاتورة داخل أرشيف مضغوط';
  @override
  String get cargoxModePerInvoiceDetailedSubtitle => 'توليد ملف إكسيل مفصل منفصل لكل فاتورة داخل حزمة أرشيف';
  @override
  String get cargoxLiveItemsPreviewBtn => 'معاينة حية للبنود المستخلصة';
  @override
  String get cargoxLiveItemsPreviewHeader => 'تفاصيل البنود المستخلصة والأوزان (معاينة حية):';
  @override
  String cargoxInvoicesCountAndLines(dynamic invCount, dynamic linesCount) => 'عدد الفواتير: $invCount | عدد الأسطر: $linesCount';
  @override
  String get cargoxAdoptAsCustomsTrackBtn => 'اعتماد كمسار جمركي مستقل';
  @override
  String cargoxAdoptCustomsTrackSuccess(dynamic code) => 'تم اعتماد وحفظ المسار الجمركي: $code وتحديث تبويب المسارات الجمركية';
  @override
  String cargoxExtractionError(dynamic err) => 'خطأ أثناء الاستخلاص: $err';
  @override
  String cargoxSaveTrackError(dynamic err) => 'خطأ أثناء حفظ المسار الجمركي: $err';
  @override
  String cargoxLivePreviewGrossNet(dynamic gross, dynamic net, dynamic unit) => 'القائم: $gross $unit | الصافي: $net $unit';
  @override
  String cargoxLivePreviewTotalValue(dynamic total, dynamic curr) => 'إجمالي القيمة: $total $curr';
  @override
  String cargoxLivePreviewInvoiceBadge(dynamic inv) => 'فاتورة: $inv';
  @override
  String get cargoxDocTypeCommercialInvoice => 'فاتورة تجارية';
  @override
  String get cargoxDocTypePackingList => 'قائمة التعبئة';
  @override
  String get cargoxDocTypeDraftBl => 'مسودة بوليصة الشحن';
  @override
  String get cargoxDocTypeCooEur1 => 'شهادة المنشأ أو الحركة الأوروبية';
  @override
  String get cargoxDocTypeCoa => 'شهادة التحليل المخبري';
  @override
  String cargoxCopiedAttachedDocSuccess(dynamic docName) => 'تم نسخ بيانات المستند: $docName';
  @override
  String get standardInvoiceSessionsExportTsvBtn => 'تصدير سجل الجلسات';
  @override
  String get standardInvoiceSessionsExportExcelBtn => 'تصدير إكسيل الجلسات';
  @override
  String get standardInvoiceSessionsPrintPdfBtn => 'طباعة سجل الجلسات المتجه';
  @override
  String get standardInvoiceSessionsCopyDossierBtn => 'نسخ ملخص جلسات الفواتير';
  @override
  String get standardInvoiceSessionsDossierHeader => 'سجل جلسات مطابقة وتدقيق الفواتير القياسية';
  @override
  String standardInvoiceCopiedSessionSuccess(dynamic code) => 'تم نسخ كود الجلسة: $code';
  @override
  String get standardInvoiceManufacturer => 'جهة التصنيع';
  @override
  String get standardInvoiceWeightNet => 'الوزن الصافي';
  @override
  String get standardInvoiceTabTitle => 'الفاتورة التجارية القياسية';
  @override
  String get standardInvoicePackingListTitle => 'قائمة التعبئة والتغليف';
  @override
  String get cargoxDownloadZipBtn => 'تحميل الأرشيف المضغوط';
  @override
  String customsTrackEditDialogTitle(dynamic code) => 'تعديل المسار الجمركي ($code)';
  @override
  String get customsTrackCustomsStatus => 'الحالة الجمركية:';
  @override
  String get customsTrackStatusSealed => 'مغلق وموثق';
  @override
  String get customsTrackNotesAndDeclaration => 'الملاحظات والبيان الجمركي:';
  @override
  String get customsTrackNotesHint => 'اكتب أي ملاحظات خاصة بالمسار الجمركي...';
  @override
  String get customsTrackSaveBtn => 'حفظ التعديلات';
  @override
  String get customsTrackUpdateSuccessToast => 'تم تحديث المسار الجمركي بنجاح';
  @override
  String get customsTrackDeleteDialogTitle => 'تأكيد حذف المسار الجمركي';
  @override
  String customsTrackDeleteDialogMessage(dynamic code) => 'هل أنت متأكد من رغبتك في حذف المسار الجمركي "$code"؟ لن يتم حذفه نهائياً بل نقله إلى الأرشيف المحذوف.';
  @override
  String customsTrackDeleteSuccessToast(dynamic code) => 'تم حذف المسار الجمركي $code بنجاح';

  // Screen 55: Customs Clearance Quotations & RFQ Evaluator
  @override
  String get clearanceQuotesScreenTitle => 'عروض ومقايسات التخليص الجمركي وقوائم الأسعار';
  @override
  String get clearanceQuotesScreenSubtitle => 'طلب عروض الأسعار ومقارنة التكاليف المعيارية بين المخلصين';
  @override
  String get clearanceQuotesEmbeddedTitle => 'عروض ومقايسات التخليص الجمركي والاستخراج الذكي';
  @override
  String get clearanceQuotesTabRfqs => 'طلب ومقارنة عروض التخليص الجمركي';
  @override
  String get clearanceQuotesTabPriceLists => 'قوائم أسعار بنود التخليص الثابتة';
  @override
  String get clearanceQuotesSmartExtractorBtn => 'استخراج ذكي لمقايسة تخليص';
  @override
  String get clearanceQuotesCreateRfqBtn => 'إنشاء طلب عرض أسعار جديد';
  @override
  String get clearanceQuotesSearchHint => 'بحث بكود الطلب، العنوان، أو الميناء...';
  @override
  String get clearanceQuotesStatusAll => 'جميع الحالات';
  @override
  String get clearanceQuotesStatusDraft => 'مسودة';
  @override
  String get clearanceQuotesStatusReceived => 'عروض مستلمة';
  @override
  String get clearanceQuotesStatusAwarded => 'معتمد ومُرسى';
  @override
  String get clearanceQuotesNoRfqsFound => 'لا توجد طلبات عروض أسعار تخليص حالياً.';
  @override
  String get clearanceQuotesAwardedBannerPrefix => 'تم اعتماد وترسية التخليص الجمركي على:';
  @override
  String clearanceQuotesReceivedQuotesHeader(dynamic count) => 'العروض المستلمة من المخلصين ($count)';
  @override
  String get clearanceQuotesSmartExtractQuoteBtn => 'استخراج ذكي للعرض';
  @override
  String get clearanceQuotesAddManualQuoteBtn => 'إضافة عرض يدوي';
  @override
  String get clearanceQuotesNoQuotesYet => 'لم يتم إدخال عروض أسعار لهذا الطلب بعد.';
  @override
  String get clearanceQuotesColBroker => 'المخلص الجمركي';
  @override
  String get clearanceQuotesColClearanceFee => 'أتعاب التخليص';
  @override
  String get clearanceQuotesColInlandTransport => 'النقل الداخلي';
  @override
  String get clearanceQuotesColInspectionFee => 'فحص وعرض';
  @override
  String get clearanceQuotesColPortExpenses => 'موانئ وتخزين';
  @override
  String get clearanceQuotesColMiscellaneous => 'نثريات';
  @override
  String get clearanceQuotesColEstimatedTotal => 'الإجمالي التقديري';
  @override
  String get clearanceQuotesColDuration => 'المدة';
  @override
  String get clearanceQuotesColStatusActions => 'الحالة والإجراءات';
  @override
  String get clearanceQuotesStatusAwardedBadge => 'معتمد';
  @override
  String get clearanceQuotesAwardAndApproveBtn => 'ترسية واعتماد';
  @override
  String clearanceQuotesDaysCount(dynamic days) => '$days أيام';
  @override
  String get clearanceQuotesBadgePort => 'الميناء:';
  @override
  String get clearanceQuotesBadgeShipmentType => 'نوع الشحنة:';
  @override
  String get clearanceQuotesBadgeHsCode => 'بند التعريفة:';
  @override
  String get clearanceQuotesBadgeWeight => 'الوزن:';
  @override
  String get clearanceQuotesBadgeVolume => 'الحجم:';
  @override
  String get clearanceQuotesBadgeLowestCost => 'أقل عرض:';
  @override
  String get clearanceQuotesBadgeFastestDuration => 'أسرع مدة:';
  @override
  String get clearanceQuotesPriceListTitle => 'قوائم أسعار بنود التخليص والنقل الجمركي المعتمدة';
  @override
  String get clearanceQuotesPriceListSubtitle => 'إدارة الأسعار المعيارية لكل مخلص جمركي وميناء وصول';
  @override
  String get clearanceQuotesAddPriceItemBtn => 'إضافة بند لقائمة الأسعار';
  @override
  String get clearanceQuotesNoPriceItemsFound => 'لا توجد بنود أسعار مسجلة بعد.';
  @override
  String get clearanceQuotesColPricePort => 'الميناء';
  @override
  String get clearanceQuotesColPriceServiceType => 'نوع الخدمة';
  @override
  String get clearanceQuotesColPriceContainerType => 'نوع الحاوية';
  @override
  String get clearanceQuotesColPriceStandardRate => 'السعر المعياري';
  @override
  String get clearanceQuotesColPriceNotes => 'ملاحظات';
  @override
  String get clearanceQuotesColPriceDelete => 'حذف';
  @override
  String get clearanceQuotesDialogCreateRfqTitle => 'إنشاء طلب عرض أسعار تخليص جمركي';
  @override
  String get clearanceQuotesFieldRfqTitle => 'عنوان الطلب *';
  @override
  String get clearanceQuotesFieldRfqTitleRequired => 'العنوان مطلوب';
  @override
  String get clearanceQuotesFieldLinkImportFile => 'ربط بملف استيراد (اختياري)';
  @override
  String get clearanceQuotesFieldClearancePort => 'ميناء التخليص الجمركي *';
  @override
  String get clearanceQuotesFieldShipmentType => 'نوع الشحنة والحاوية *';
  @override
  String get clearanceQuotesFieldContainersCount => 'عدد الحاويات *';
  @override
  String get clearanceQuotesFieldGrossWeightKg => 'الوزن القائم (كجم)';
  @override
  String get clearanceQuotesFieldCbm => 'الحجم بالمتر المكعب';
  @override
  String get clearanceQuotesSubmitCreateRfqBtn => 'إنشاء الطلب';
  @override
  String get clearanceQuotesDialogAddQuoteTitle => 'إضافة عرض أسعار مخلص جمركي';
  @override
  String get clearanceQuotesFieldCustomsBroker => 'المخلص الجمركي *';
  @override
  String get clearanceQuotesFieldClearanceFeeEgp => 'أتعاب التخليص الجمركي بالجنيه *';
  @override
  String get clearanceQuotesFieldInlandFeeEgp => 'النقل الداخلي للمصنع بالجنيه *';
  @override
  String get clearanceQuotesFieldInspectionFeeEgp => 'مصاريف فحص وعرض بالجنيه';
  @override
  String get clearanceQuotesFieldPortExpEgp => 'رسوم موانئ وأرضيات بالجنيه';
  @override
  String get clearanceQuotesFieldMiscFeeEgp => 'نثريات ومصروفات إدارية بالجنيه';
  @override
  String get clearanceQuotesFieldEstimatedDays => 'مدة التخليص المقدرة بالأيام *';
  @override
  String get clearanceQuotesTotalEstimatedQuoteLabel => 'الإجمالي التقديري للعرض:';
  @override
  String get clearanceQuotesSubmitSaveQuoteBtn => 'حفظ العرض';
  @override
  String get clearanceQuotesSmartExtractorDialogTitle => 'الاستخلاص الذكي لعروض أسعار ومقايسات التخليص';
  @override
  String get clearanceQuotesSmartExtractorPrompt => 'الصق نص عرض السعر أو البريد الإلكتروني أو اختر ملف المقايسة لاستخلاص البنود آلياً:';
  @override
  String get clearanceQuotesSmartExtractorInputHint => 'مثال:\nعرض أسعار تخليص جمركي من مكتب النسر...\nأتعاب التخليص: ٣٥٠٠ جنيه\nنقل داخلي: ٧٠٠٠ جنيه\nمصاريف فحص وعرض: ١٥٠٠ جنيه...';
  @override
  String get clearanceQuotesExtractingState => 'جاري الاستخراج...';
  @override
  String get clearanceQuotesExtractFromTextBtn => 'استخراج فوري من النص';
  @override
  String get clearanceQuotesUploadDocBtn => 'رفع مستند مقايسة';
  @override
  String get clearanceQuotesExtractedBrokerPrefix => 'المخلص المستخرج:';
  @override
  String get clearanceQuotesExtractedPortPrefix => 'الميناء:';
  @override
  String get clearanceQuotesExtractedContainerPrefix => 'الحاوية:';
  @override
  String get clearanceQuotesExtractedTotalPrefix => 'إجمالي التكلفة المقدرة:';
  @override
  String get clearanceQuotesApplyExtractedQuoteBtn => 'تطبيق وإضافة العرض';
  @override
  String get clearanceQuotesUseExtractedQuoteBtn => 'تطبيق واستخدام العرض';
  @override
  String clearanceQuotesExtractedSuccessToast(dynamic broker, dynamic total) => 'تم استخلاص عرض المخلص بنجاح: $broker - الإجمالي: $total جنيه';
  @override
  String get clearanceQuotesDialogAddPriceItemTitle => 'إضافة بند لقائمة أسعار التخليص';
  @override
  String get clearanceQuotesFieldServiceCategory => 'نوع بند الخدمة *';
  @override
  String get clearanceQuotesFieldStandardPriceEgp => 'السعر المعياري بالجنيه *';
  @override
  String get clearanceQuotesFieldStandardPriceRequired => 'السعر مطلوب';
  @override
  String get clearanceQuotesSubmitSavePriceItemBtn => 'حفظ البند';
  @override
  String get clearanceQuotesCatClearanceFee => 'أتعاب التخليص الجمركي';
  @override
  String get clearanceQuotesCatInlandTransport => 'النقل الداخلي';
  @override
  String get clearanceQuotesCatInspectionFee => 'مصاريف الفحص والعرض';
  @override
  String get clearanceQuotesCatPortCharges => 'رسوم ومصاريف الموانئ';
  @override
  String get clearanceQuotesConfirmAwardTitle => 'تأكيد اعتماد وترسية التخليص الجمركي';
  @override
  String get clearanceQuotesConfirmAwardContent => 'هل أنت متأكد من رغبتك في اعتماد وترسية هذا العرض وتثبيته في منظومة تكاليف الشحنة؟';
  @override
  String get clearanceQuotesConfirmAwardBtn => 'نعم، اعتماد العرض';
  @override
  String get clearanceQuotesAwardSuccessSnackbar => 'تم اعتماد وترسية عرض التخليص الجمركي بنجاح';
  @override
  String get clearanceQuotesConfirmDeleteQuoteTitle => 'تأكيد الحذف';
  @override
  String get clearanceQuotesConfirmDeleteQuoteContent => 'هل تريد حذف هذا العرض من المقارنة؟';
  @override
  String get clearanceQuotesErrorLoadingRfqs => 'خطأ في تحميل عروض التخليص:';
  @override
  String get clearanceQuotesErrorLoadingPriceList => 'خطأ في تحميل قوائم الأسعار:';
  @override
  String get kgUnit => 'كجم';
  @override
  String get cbmUnit => 'م³';
  @override
  String get egpCurrency => 'جنيه';
  @override
  String get searchPlaceholder => 'ابحث هنا...';

  // ── Screen 55: Clearance Quotations Export Toolbar & i18n ───────────────
  @override
  String get clearanceQuotesExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get clearanceQuotesExportExcelBtn => 'تصدير إكسيل';
  @override
  String get clearanceQuotesPrintPdfBtn => 'طباعة تقرير بي دي إف';
  @override
  String get clearanceQuotesCopyDossierBtn => 'نسخ ملخص المقايسات';
  @override
  String get clearanceQuotesCopiedDossierSuccess => 'تم نسخ ملخص مقايسات التخليص إلى الحافظة بنجاح';
  @override
  String get clearanceQuotesCopiedTsvSuccess => 'تم نسخ جدول مقايسات التخليص كجدول نصوص إلى الحافظة';
  @override
  String get clearanceQuotesCopiedExcelSuccess => 'تم تصدير ملف إكسيل لمقايسات التخليص بنجاح';
  @override
  String get clearanceQuotesExportTsvDialogTitle => 'تصدير جدول عروض التخليص الجمركي';
  @override
  String get clearanceQuotesExportExcelDialogTitle => 'تصدير إكسيل لعروض التخليص الجمركي';
  @override
  String get clearanceQuotesExportPdfDialogTitle => 'طباعة تقرير عروض التخليص الجمركي';
  @override
  String get clearanceQuotesDossierTitle => 'ملخص تقييم عروض التخليص الجمركي';
  @override
  String get clearanceQuotesCopyRowSuccess => 'تم نسخ بيانات السطر بنجاح';
  @override
  String get clearanceQuotesCopySummarySuccess => 'تم نسخ ملخص العرض بنجاح';
  @override
  String get clearanceQuotesTsvHeaderRfqCode => 'كود الطلب';
  @override
  String get clearanceQuotesTsvHeaderTitle => 'عنوان طلب العرض';
  @override
  String get clearanceQuotesTsvHeaderPort => 'ميناء التخليص';
  @override
  String get clearanceQuotesTsvHeaderShipmentType => 'نوع الشحنة';
  @override
  String get clearanceQuotesTsvHeaderContainers => 'عدد الحاويات';
  @override
  String get clearanceQuotesTsvHeaderWeight => 'الوزن القائم';
  @override
  String get clearanceQuotesTsvHeaderCbm => 'الحجم التكعيبي';
  @override
  String get clearanceQuotesTsvHeaderBroker => 'المخلص الجمركي';
  @override
  String get clearanceQuotesTsvHeaderClearanceFee => 'أتعاب التخليص';
  @override
  String get clearanceQuotesTsvHeaderInlandTransport => 'النقل الداخلي';
  @override
  String get clearanceQuotesTsvHeaderInspectionFee => 'الفحص والعرض';
  @override
  String get clearanceQuotesTsvHeaderPortExpenses => 'رسوم الموانئ';
  @override
  String get clearanceQuotesTsvHeaderMiscFee => 'نثريات';
  @override
  String get clearanceQuotesTsvHeaderTotal => 'الإجمالي التقديري';
  @override
  String get clearanceQuotesTsvHeaderDays => 'مدة الإنجاز';
  @override
  String get clearanceQuotesTsvHeaderStatus => 'الحالة';
  @override
  String get clearanceQuotesTsvHeaderPriceServiceType => 'نوع الخدمة';
  @override
  String get clearanceQuotesTsvHeaderPriceContainerType => 'نوع الحاوية';
  @override
  String get clearanceQuotesTsvHeaderPriceStandardRate => 'السعر المعياري';
  @override
  String get clearanceQuotesTsvHeaderPriceNotes => 'ملاحظات';
  @override
  String get clearanceQuotesManagePriceListBtn => 'إنشاء وإدارة قائمة أسعار المخلص الشاملة المؤرخة';
  @override
  String get clearanceQuotesPasteClipboardBtn => 'لصق من الحافظة';
  @override
  String get clearanceQuotesSampleAccBtn => 'تجربة مقايسة شركة الإسكندرية للأعمال الجمركية (٣٠,٩٠٠ جنيه)';
  @override
  String get clearanceQuotesSampleStandardBtn => 'تجربة مقايسة نموذجية';
  @override
  String get clearanceQuotesClearInputTooltip => 'تفريغ النص';
  @override
  String get clearanceQuotesOcrUploadingState => 'جاري رفع الملف وقراءة المقايسة بالماسح الضوئي...';
  @override
  String get clearanceQuotesOcrStep1 => 'المرحلة الأولى من أربعة: رفع الملف';
  @override
  String get clearanceQuotesOcrDialogTitle => 'استخراج مقايسة التخليص';
  @override
  String clearanceQuotesOcrProgressState(dynamic percent) => 'جاري رفع ومعالجة الملف ($percent%)...';
  @override
  String get clearanceQuotesOcrStep2 => 'المرحلة الثانية من أربعة: معالجة الملف';
  @override
  String get clearanceQuotesOcrStep4State => 'جاري استخراج أتعاب ومصروفات مقايسة التخليص والنقل...';
  @override
  String get clearanceQuotesSelectedContainerLabel => 'الحاوية المحددة:';
  @override
  String get clearanceQuotesSaveAsPriceListBtn => 'تكويد وحفظ كقائمة أسعار للمخلص';
  @override
  String get clearanceQuotesRateOptionsTitle => 'خيارات التسعير حسب الحاوية والوزن (حدد الخيار المطلوب):';
  @override
  String get clearanceQuotesBreakdownClearanceFee => 'أتعاب تخليص';
  @override
  String get clearanceQuotesBreakdownInlandFee => 'نقل داخلي';
  @override
  String get clearanceQuotesBreakdownInspectionFee => 'فحص وهيئة';
  @override
  String get clearanceQuotesBreakdownPortExpenses => 'رسوم موانئ';
  @override
  String get clearanceQuotesBreakdownEstimatedTotal => 'الإجمالي التقديري';
  @override
  String clearanceQuotesExpensesCatalogCount(dynamic count) => 'عرض جدول البنود التفصيلية والخدمات المستخرجة ($count بند)';

  // ── Authentication & Login Screen ──────────────────────────────────────────
  @override
  String get loginScreenTitle => 'تسجيل الدخول إلى المنظومة';
  @override
  String get loginScreenSubtitle => 'منظومة سرور لإدارة سلاسل الإمداد والاستيراد والتخليص الجمركي';
  @override
  String get loginUsernameLabel => 'اسم المستخدم أو البريد الإلكتروني';
  @override
  String get loginUsernameHint => 'اسم المستخدم...';
  @override
  String get loginUsernameRequired => 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني';
  @override
  String get loginPasswordLabel => 'كلمة المرور';
  @override
  String get loginPasswordRequired => 'يرجى إدخال كلمة المرور';
  @override
  String get loginButtonLabel => 'تسجيل الدخول إلى النظام';
  @override
  String get loginAuthenticating => 'جاري تسجيل الدخول والتحقق...';
  @override
  String get loginQuickDemoAccess => 'الدخول السريع بحسابات النظام التجريبية:';
  @override
  String get loginInvalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة';
  @override
  String get loginRoleAdmin => 'مسؤول النظام';
  @override
  String get loginRoleManager => 'مدير العمليات';
  @override
  String get loginRoleSpecialist => 'أخصائي لوجستي';
  @override
  String get loginCopyUsernameTooltip => 'نسخ اسم المستخدم';
  @override
  String get loginUsernameCopied => 'تم نسخ اسم المستخدم بنجاح';
  @override
  String get loginCopyPasswordTooltip => 'نسخ كلمة المرور';
  @override
  String get loginPasswordCopied => 'تم نسخ كلمة المرور بنجاح';
  @override
  String get loginDemoCredentialsCopied => 'تم نسخ بيانات الاعتماد التجريبية بنجاح';
  @override
  String get loginDemoCredentialsTooltip => 'نسخ بيانات الحساب التجريبي';

  // ── Forced password change (first login) ──
  @override
  String get forcePwdTitle => 'تغيير كلمة المرور مطلوب';
  @override
  String get forcePwdSubtitle => 'لحماية حسابك، يجب تعيين كلمة مرور جديدة عند أول تسجيل دخول قبل متابعة استخدام النظام.';
  @override
  String get forcePwdAccountLabel => 'الحساب';
  @override
  String get forcePwdCurrentLabel => 'كلمة المرور الحالية';
  @override
  String get forcePwdNewLabel => 'كلمة المرور الجديدة';
  @override
  String get forcePwdConfirmLabel => 'تأكيد كلمة المرور الجديدة';
  @override
  String get forcePwdPolicyHint => 'استخدم 8 أحرف على الأقل، ويُفضَّل المزج بين الحروف والأرقام والرموز.';
  @override
  String get forcePwdCurrentRequired => 'يرجى إدخال كلمة المرور الحالية';
  @override
  String get forcePwdNewRequired => 'يرجى إدخال كلمة المرور الجديدة';
  @override
  String get forcePwdConfirmRequired => 'يرجى تأكيد كلمة المرور الجديدة';
  @override
  String get forcePwdTooShort => 'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف';
  @override
  String get forcePwdSameAsCurrent => 'كلمة المرور الجديدة يجب أن تختلف عن الحالية';
  @override
  String get forcePwdMismatch => 'كلمتا المرور غير متطابقتين';
  @override
  String get forcePwdSubmit => 'تغيير كلمة المرور والمتابعة';
  @override
  String get forcePwdSuccess => 'تم تغيير كلمة المرور بنجاح';
  @override
  String get forcePwdFailed => 'تعذر تغيير كلمة المرور. حاول مرة أخرى.';
  @override
  String get forcePwdShowPassword => 'إظهار كلمة المرور';
  @override
  String get forcePwdHidePassword => 'إخفاء كلمة المرور';

  // ── Shipping Scenarios & Cargo Stacking ────────────────────────────────────
  @override
  String get multiLayerStacking => 'رص متعدد الطبقات';
  @override
  String get floorPlacementZ0 => 'رص أرضي مستوى 0';
  @override
  String mixedStackingCargoDesc(int nonStack, int stack) =>
      '$nonStack غير قابل للرص + $stack قابل للرص';
  @override
  String get containerCountPill => 'عدد الحاويات';
  @override
  String get spaceAndVolumeUtilPill => 'استغلال المساحة والحجم';
  @override
  String get weightUtilPill => 'استغلال الوزن';
  @override
  String containerCountUnit(int count) => '$count حاوية';

  // ── Smart Invoice & Packing Extractor ──────────────────────────────────────
  @override
  String get smartInvoiceExtractProgressTitle => 'مستخرج بيانات الفواتير وقوائم التعبئة الذكي';
  @override
  String ocrStepProgressLabel(int step, int total, String desc) => 'المرحلة $step من $total: $desc';
  @override
  String get ocrStep1Reading => 'قراءة';
  @override
  String get ocrStep2Upload => 'رفع';
  @override
  String get ocrStep3Ocr => 'تعرف ضوئي';
  @override
  String get ocrStep4Fields => 'استخراج الحقول';
  @override
  String get cancelAndCloseExtractor => 'إلغاء العملية وإغلاق الأداة';
  @override
  String get ocrAnalyzingText => 'جاري تحليل النصوص، أرقام البنود، والأسعار...';
  @override
  String get ocrSendingDoc => 'جاري إرسال المستند ومعالجة الصفحات...';
  @override
  String get ocrExtractingFields => 'جاري استخراج بنود الفاتورة وكشف التعبئة وتنسيق البيانات...';
  @override
  String get ocrCompleteSuccess => 'اكتملت المعالجة بنجاح 100%';
  @override
  String get ocrCompleteSuccessDesc => 'تم استخراج كافة البيانات بنجاح وجاري عرض المعاينة!';
  @override
  String get closeAndCancelExtractionTooltip => 'إغلاق وإلغاء الاستخراج';
  @override
  String get addManualFieldBtn => 'إضافة بيان / حقل إضافي يدوياً';
  @override
  String get populateFormBtn => 'تعبئة النموذج';
  @override
  String get verifyPartiesInDb => 'التحقق من تسجيل الأطراف في قاعدة البيانات';
  @override
  String get partyUnconfirmed => 'غير مؤكد';
  @override
  String get partyConfirmed => 'مؤكد';
  @override
  String get registerPartyAction => 'سجّل +';
  @override
  String get missingFieldsWarning => 'الحقول التالية لم تُستخرج:';
  @override
  String get editFieldValueTitle => 'تعديل قيمة الحقل';
  @override
  String get updatedValueLabel => 'القيمة المحدثة';
  @override
  String get enterCorrectValueHint => 'أدخل القيمة الصحيحة...';
  @override
  String get saveEditBtn => 'حفظ التعديل';
  @override
  String get callSmartNafezaDiffBtn => 'استدعاء أداة نافذة الذكية لتسجيل البند';
  @override
  String get fullExtraction => 'استخراج مكتمل';
  @override
  String get partialExtraction => 'استخراج جزئي';
  @override
  String get extractionFailedStatus => 'فشل الاستخراج';
  @override
  String get extractionResultHeader => 'نتيجة استخراج البيانات';
  @override
  String get extractionConfidenceLabel => 'نسبة الثقة';
  @override
  String get extractedFieldsTitle => 'البيانات المستخرجة';
  @override
  String get supplier => 'المورد';

  // ── Extracted Field Labels Dictionary ───────────────────────────────────────
  @override
  String get fieldSupplierAddress => 'عنوان المورد';
  @override
  String get fieldSupplierPhone => 'هاتف المورد';
  @override
  String get fieldSupplierTaxId => 'الرقم الضريبي للمورد';
  @override
  String get fieldSupplierCountry => 'دولة المورد';
  @override
  String get fieldSupplierCity => 'مدينة المورد';
  @override
  String get fieldSupplierEmail => 'البريد الإلكتروني للمورد';
  @override
  String get fieldCustomerName => 'الشركة المستوردة';
  @override
  String get fieldCustomerAddress => 'عنوان المستورد';
  @override
  String get fieldCustomerTaxId => 'الرقم الضريبي للمستورد';
  @override
  String get fieldInvoiceNumber => 'رقم الفاتورة';
  @override
  String get fieldInvoiceDate => 'تاريخ الفاتورة';
  @override
  String get fieldInvoiceValue => 'قيمة الفاتورة';
  @override
  String get fieldPoNumber => 'رقم أمر الشراء';
  @override
  String get fieldIncoterm => 'شرط الشحن والتسليم';
  @override
  String get fieldCurrency => 'العملة';
  @override
  String get fieldExchangeRate => 'سعر الصرف';
  @override
  String get fieldTotalAmount => 'إجمالي المبلغ';
  @override
  String get fieldPaymentTerms => 'شروط الدفع';
  @override
  String get fieldPolPort => 'ميناء الشحن';
  @override
  String get fieldPodPort => 'ميناء التفريغ والوصول';
  @override
  String get fieldAcidNumber => 'رقم القيد الجمركي ACID';
  @override
  String get fieldBlNumber => 'رقم بوليصة الشحن';
  @override
  String get fieldContainerNumbers => 'أرقام الحاويات';
  @override
  String get fieldGrossWeight => 'الوزن القائم';
  @override
  String get fieldNetWeight => 'الوزن الصافي';
  @override
  String get fieldTotalCbm => 'إجمالي الحجم CBM';
  @override
  String get fieldPackagesCount => 'عدد الطرود';
  @override
  String get fieldCommodityDescription => 'وصف البضاعة';
  @override
  String get fieldOriginCountry => 'بلد المنشأ';
  @override
  String get fieldCustomsValueEgp => 'القيمة الجمركية';
  @override
  String get fieldImportDuty => 'ضريبة الوارد';
  @override
  String get fieldVatAmount => 'ضريبة القيمة المضافة';
  @override
  String get fieldTotalTaxes => 'إجمالي الضرائب';
  @override
  String get fieldCertificateNumber => 'رقم الشهادة';
  @override
  String get fieldIssueDate => 'تاريخ الإصدار';
  @override
  String get fieldCarrierName => 'الناقل الملاحي أو الجوي';
  @override
  String get fieldFreightRate => 'سعر النولون';
  @override
  String get fieldTransitDays => 'أيام العبور';
  @override
  String get fieldValidityDate => 'تاريخ الصلاحية';
  @override
  String get fieldBookingNumber => 'رقم الحجز';
  @override
  String get fieldSiCutoff => 'موعد إغلاق التعليمات';
  @override
  String get fieldAmount => 'المبلغ';
  @override
  String get fieldBankName => 'اسم البنك';
  @override
  String get fieldSwiftCode => 'كود السويفت';
  @override
  String get fieldInspectionResult => 'نتيجة الفحص';

  // ── Purchase Order Details & View Modal ────────────────────────────────────
  @override
  String poViewDialogTitle(String poNumber, String? version) =>
      version != null && version.isNotEmpty
          ? 'أمر الشراء والفاتورة المبدئية: $poNumber ($version)'
          : 'أمر الشراء والفاتورة المبدئية: $poNumber';
  @override
  String get poLineItemsBreakdown => 'بنود الفاتورة المبدئية والأكواد الجمركية';
  @override
  String get descriptionAndHsCode => 'الوصف والبند الجمركي';
  @override
  String get qtyUom => 'الكمية / الوحدة';
  @override
  String get volumeCbmPackingList => 'حجم CBM (بيان التعبئة)';
  @override
  String itemOriginLabel(String origin) => 'المنشأ: $origin';
  @override
  String hsMismatchWarning(String duty, String vat) =>
      'بند جمركي (جمارك: $duty / ق.م: $vat) - عدم تطابق';
  @override
  String get exchangeRateLabel => 'سعر الصرف';
  @override
  String get itemCode => 'كود الصنف';
  @override
  String get mainDescription => 'الوصف الرئيسي';
  @override
  String get unitPrice => 'سعر الوحدة';
  @override
  String get lineTotal => 'الإجمالي';

  // ── Edit Purchase Order & Packing List & 3D Simulator ──────────────────────
  @override
  String editPurchaseOrderTitle(String poNumber) => 'تعديل أمر الشراء ($poNumber)';
  @override
  String poLineItemsTabCount(int count) => 'بنود الفاتورة ($count)';
  @override
  String poPackingListTabCount(int count) => 'بيان التعبئة والطرود ($count)';
  @override
  String get packingListReaderBanner => 'أداة قراءة واستخراج بيان التعبئة والوزن';
  @override
  String get packingListReaderBannerDesc =>
      'قم برفع ملف بيان التعبئة لاستخراج أعداد الطرود، الأوزان القائمة والصافية، والأحجام تلقائياً';
  @override
  String get explicitDimensionsPath => 'مسار الأبعاد الصريحة (L × W × H)';
  @override
  String get cbmDirectPathAndPalletLayout => 'مسار الحجم المباشر ومخطط البالتات';
  @override
  String get packingListEntriesSection => 'بيان التعبئة والطرود والأبعاد *';
  @override
  String get autoFillFromInvoice => 'تعبئة تلقائية من الفاتورة';
  @override
  String get simulateAndPack3d => 'محاكاة ورص الحاويات 3D';
  @override
  String get addPackingEntryBtn => 'إضافة بند تعبئة';
  @override
  String get noPackingEntriesYet => 'لم يتم إضافة بنود تعبئة بعد';
  @override
  String get noPackingEntriesYetDesc =>
      'انقر فوق "تعبئة تلقائية من الفاتورة" لإنشاء قائمة التعبئة آلياً أو "إضافة بند تعبئة"';
  @override
  String pkgCardNumber(int num) => 'طرد #$num';
  @override
  String get hsCodeSearchFieldLabel => 'البند الجمركي (بحث 🔍) *';
  @override
  String get selectTariffItemHint => 'اختر بند جمركي';
  @override
  String get itemNameOrDescHint => 'اسم أو وصف الصنف';
  @override
  String get packageTypeFieldLabel => 'نوع الطرد';
  @override
  String get unitFieldLabel => 'الوحدة';
  @override
  String get qtyPcsFieldLabel => 'الكمية (قطع)';
  @override
  String get qtyPkgFieldLabel => 'عدد الطرود';
  @override
  String lengthFieldLabel(String unit) => 'الطول ($unit)';
  @override
  String widthFieldLabel(String unit) => 'العرض ($unit)';
  @override
  String heightFieldLabel(String unit) => 'الارتفاع ($unit)';
  @override
  String get weightUnitFieldLabel => 'وحدة الوزن';
  @override
  String netWeightFieldLabel(String unit) => 'الوزن الصافي ($unit)';
  @override
  String grossWeightFieldLabel(String unit) => 'الوزن القائم ($unit)';
  @override
  String get stackingInstructionsLabel => 'تعليمات الرص *';
  @override
  String get totalVolumePill => 'إجمالي الحجم';
  @override
  String get totalGrossWeightPill => 'إجمالي الوزن القائم';
  @override
  String get airChargeablePill => 'الوزن الحجمي للشحن الجوي';
  @override
  String autoFillSuccessNotice(int count) =>
      'تمت التعبئة التلقائية لـ $count طرد من بنود الفاتورة المبدئية بنجاح!';
  @override
  String get enterPackingOrPalletsNotice =>
      'يرجى إدخال أصناف قائمة التعبئة أو البالتات أولاً للمحاكاة';
  @override
  String get containerLoadPlan3dTitle => 'مخطط ومحاكاة رص الحاويات 3D';
  @override
  String get containerLoadPlan3dSubtitle =>
      'محاكاة خوارزمية الرص ثلاثية الأبعاد للحاويات البحرية بناءً على قائمة التعبئة وأبعاد الطرود';
  @override
  String get stackingSimulationModeLabel => 'نمط الرص بالمحاكاة:';
  @override
  String get projectionLabel => 'المسقط:';
  @override
  String get simulationModeActualMixed => '⚖️ الرص الفعلي';
  @override
  String get simulationModeStackable => '📦 قابل للرص';
  @override
  String get simulationModeFloorOnly => '🚫 أرضي فقط';
  @override
  String get topViewProjection => '🔝 مسقط علوي';
  @override
  String get sideViewProjection => '🔲 مسقط جانبي';
  @override
  String requiredContainersSummary(String fleet) => 'الحاويات المطلوبة: $fleet';
  @override
  String totalPackagesSummary(int total, int stackable, int floor) =>
      'عدد الطرود: $total طرد ($stackable قابل للرص | $floor أرضي)';
  @override
  String totalWeightSummary(String wt) => 'إجمالي الوزن: $wt كجم';
  @override
  String totalVolumeSummary(String vol) => 'إجمالي الحجم: $vol م³';
  @override
  String get packingFailureTitle =>
      'فشل الرص: تجاوز أبعاد الطرد أو الوزن الأبعاد القياسية المسموح بها داخل الحاوية';
  @override
  String get itemCodeLabel => 'كود الصنف *';
  @override
  String get fieldRequired => 'حقل مطلوب';
  @override
  String get fieldCurrentStage => 'المرحلة الحالية';
  @override
  String get searchFieldHint => 'ابحث برقم الملف أو الكود أو اسم الشركة...';

  // ── Master Palletization Plan Localizations ─────────────────────────────────
  @override
  String get masterPalletizationPlanTitle =>
      'لوحة مخطط وحدات الشحن والبالتات (Master Palletization Plan)';
  @override
  String totalPalletsPill(int count) => 'إجمالي البالتات: $count بالتة';
  @override
  String palletsVolumePill(String vol) => 'حجم البالتات: $vol م³';
  @override
  String get addPalletRowBtn => 'إضافة سطر بالتات';
  @override
  String simulateAndPackPallets3dBtn(int count) => 'محاكاة ورص الحاويات 3D ($count بالتة)';
  @override
  String get clickToAddPalletsPrompt =>
      'اضغط هنا لإضافة أسطر البالتات وتوزيع الشحنة عليها';
  @override
  String palletRowHeader(int index) => 'سطر بالتات #$index';
  @override
  String get palletStackableBadge => 'قابل للرص 📦';
  @override
  String get palletFloorOnlyBadge => 'غير قابل للرص (أرضي فقط) 🚫';
  @override
  String palletRowSummary(String vol, String wt) =>
      'حجم السطر: $vol م³ | إجمالي الوزن: $wt كجم';
  @override
  String get palletTypeAndSizeLabel => 'نوع ومقاس البالتة';
  @override
  String get palletCountFieldLabel => 'عدد البالتات *';
  @override
  String get palletStackingInstructionsLabel => 'تعليمات رص البالتة *';
  @override
  String get palletGrossWeightLabel => 'وزن البالتة Gross (كجم)';
  @override
  String get deletePalletRowTooltip => 'حذف سطر البالتات';
  @override
  String get customPalletOption => 'Custom Pallet (أبعاد مخصصة)';

  // ── 3D Container Cards & Items Table ──────────────────────────────────────
  @override
  String containerCardHeader(int index, String code, int pkgsCount, String spacePct, String payloadPct) =>
      'حاوية #$index: $code — ($pkgsCount طرد) — استغلال المساحة: $spacePct% | استغلال الحمولة: $payloadPct%';
  @override
  String internalDimensionsLabel(String l, String w, String h) =>
      'أبعاد داخلية: $l × $w × $h سم';
  @override
  String placedPackagesTableTitle(int count) =>
      '📋 تفاصيل ومواقع الطرود المرصوصة داخل الحاوية ($count طرد)';
  @override
  String get thPackageCode => 'كود الطرد / الصنف';
  @override
  String get thDimensions => 'الأبعاد (L×W×H سم)';
  @override
  String get thWeight => 'الوزن (كجم)';
  @override
  String get thCoordinates => 'إحداثيات الموضع (X, Y, Z سم)';
  @override
  String get thStacking => 'الرص';
  @override
  String get noSuitableContainersFound => 'لا توجد حاويات مناسبة';

  // ── Standardized Stage Stop & Resume Buttons ────────────────────────────────
  @override
  String get stopShipmentAtThisStageBtn => 'إيقاف الشحنة عند هذه المرحلة';
  @override
  String get shipmentOnHoldPrefix => 'متوقفة:';
  @override
  String get shipmentClosedArchived => 'الشحنة مغلقة بالأرشيف';
  @override
  String get selectFileToHoldTitle => 'اختيار ملف الشحنة للإيقاف عند هذه المرحلة';
  @override
  String get selectFileToHoldLabel => 'اختر ملف الشحنة المراد إيقافها *';
  @override
  String get selectFileToHoldHint => 'ابحث برقم الملف أو الكود أو اسم الشركة...';
  @override
  String get continueToHoldReasonBtn => 'متابعة وإدخال سبب الإيقاف';
  @override
  String holdShipmentStageBannerTitle(String code, String stage) =>
      '⚠️ تنبيه: هذه الشحنة ($code) متوقفة ومعلقة عند مرحلة: [$stage]';
  @override
  String get holdDialogReasonLabel => 'سبب إيقاف وتعليق الشحنة';
  @override
  String get holdDialogReasonHint => 'اكتب سبب الإيقاف أو اختر من الأسباب بالأعلى...';
  @override
  String get confirmHoldActionBtn => 'تأكيد إيقاف وتجميد الشحنة عند هذه المرحلة';
  @override
  String holdSuccessNotification(String code, String stage) =>
      '⚠️ تم إيقاف وتجميد الشحنة ($code) بنجاح عند مرحلة: $stage';

  // ── Purchase Order Comprehensive Report Preview ───────────────────────────
  @override
  String get poReportPreviewTitle =>
      'معاينة تقرير أمر الشراء وقائمة التعبئة المعتمدة';
  @override
  String get poReportPreviewSubtitle =>
      'استعراض تفصيلي شامل ومطابقة نهائية قبل الحفظ — Sorour Logistics ERP';
  @override
  String get poReport3dSimulation => 'محاكاة الرص 3D';
  @override
  String get poReportCopyText => 'نسخ نص التقرير';
  @override
  String get poReportClosePreview => 'إغلاق المعاينة';
  @override
  String get poReportHeaderDocumentTitle =>
      'أمر الشراء ومواصفات التعبئة المعتمدة';
  @override
  String get poReportPoNumber => 'رقم أمر الشراء';
  @override
  String get poReportPiNumber => 'الفاتورة المبدئية PI';
  @override
  String get poReportAcidNumber => 'رقم القيد الجمركي ACID';
  @override
  String get poReportOrderDate => 'تاريخ الطلب';
  @override
  String get poReportExchangeRate => 'سعر الصرف';
  @override
  String get poReportIncoterms => 'شروط التسليم الدولية';
  @override
  String get poReportOrigin => 'بلد المنشأ';
  @override
  String get poReportBuyer => 'الشركة المستوردة';
  @override
  String get poReportTaxId => 'السجل الضريبي';
  @override
  String get poReportImportFile => 'ملف الشحنة';
  @override
  String get poReportSeller => 'المورد الأجنبي';
  @override
  String get poReportSupplierCountry => 'دولة المورد';
  @override
  String get poReportPaymentTerms => 'شروط السداد';
  @override
  String get poReportTotalInvoice => 'إجمالي الفاتورة';
  @override
  String get poReportTotalPkgsAndPcs => 'عدد الطرود والقطع';
  @override
  String get poReportGrossWeight => 'الوزن القائم';
  @override
  String get poReportNetWeight => 'الوزن الصافي';
  @override
  String get poReportVolumeCbm => 'الحجم CBM';
  @override
  String get poReportPalletPlan => 'مخطط البالتات';
  @override
  String get poReportRecommendedContainer => 'الحاوية المقترحة';
  @override
  String get poReportSec1InvoiceItems =>
      '1. جدول بنود الفاتورة التجارية (Commercial Invoice Line Items)';
  @override
  String get poReportSec2PackingList =>
      '2. بيان قائمة التعبئة والطرود والأبعاد (Detailed Packing List)';
  @override
  String get poReportSec3PalletPlan =>
      '3. لوحة مخطط البالتات ووحدات الشحن (Master Palletization Plan)';
  @override
  String get poReportSec4Notes =>
      '4. الملاحظات والشروط الإضافية (Additional Notes & Terms)';
  @override
  String get poReportColItemCode => 'كود الصنف';
  @override
  String get poReportColDescription => 'البيان والوصف';
  @override
  String get poReportColHsCode => 'بند التعريفة (HS Code)';
  @override
  String get poReportColQtyUnit => 'الكمية / الوحدة';
  @override
  String get poReportColUnitPrice => 'سعر الوحدة';
  @override
  String get poReportColTotalAmount => 'الإجمالي (Total)';
  @override
  String get poReportColPkgType => 'نوع التعبئة';
  @override
  String get poReportColDimensions => 'الأبعاد (سم)';
  @override
  String get poReportColStackable => 'الرص';
  @override
  String get poReportStackableYes => '📦 نعم';
  @override
  String get poReportStackableNo => '🚫 أرضي';
  @override
  String get poReportGrandTotal => 'الإجمالي الكلي';
  @override
  String get poReportTotalPacking => 'إجمالي التعبئة';
  @override
  String get poReportTotalPallets => 'إجمالي البالتات';
  @override
  String get poReportReadyForApproval => 'جاهز للاعتماد';
  @override
  String get poReportCloseAndEdit => 'إغلاق والعودة للتعديل';
  @override
  String get poReportSaveAndApprove => 'حفظ واعتماد أمر الشراء';
  @override
  String get poReportCopiedToClipboard =>
      '📋 تم نسخ نص التقرير بالكامل للحافظة بنجاح!';
  @override
  String poReportItemsCountUnit(int count) => '$count بنود';
  @override
  String poReportPackagesCountUnit(int count) => '$count طرد';
  @override
  String poReportPiecesCountUnit(int count) => '$count قطعة';
  @override
  String poReportPalletsCountUnit(int count) => '$count بالتات';
  @override
  String poReportRowsCountUnit(int count) => '$count أسطر';
  @override
  String get poReportDirectVolume => 'حجم مباشر';
  @override
  String get poReportLanguageToggleTooltip =>
      'تغيير لغة التقرير (عربي / English)';
  @override
  String get poReportSwitchLanguageBtn => 'English';
  @override
  String get savePurchaseOrderBtn => 'حفظ أمر الشراء';
  @override
  String get savePoEditsBtn => 'حفظ تعديلات أمر الشراء';
  @override
  String get previewPoReportBtn => 'معاينة تقرير أمر الشراء';

  // ── Marine & Cargo Insurance (CargoInsuranceScreen) ───────────────────────
  @override
  String get insuranceScreenTitle => 'شهادات التأمين على البضائع المشحونة';
  @override
  String get insuranceTabCertificatesRegistry => 'سجل شهادات التأمين';
  @override
  String get insuranceTabNewCertificate => 'إصدار وثيقة جديدة';
  @override
  String get insuranceAiExtractorBtn => 'تكويد شركة تأمين بالذكاء الاصطناعي ✨';
  @override
  String get insuranceSmartUploadBtn => 'رفع واستخراج وثيقة التأمين الذكي';
  @override
  String insuranceExtractedSnackbar(String ref) => '✅ تم استخراج مستند الشحن والتأمين: $ref';
  @override
  String get insuranceExtractedDone => 'مكتمل';
  @override
  String get insuranceRefreshTooltip => 'تحديث البيانات';

  @override
  String insuranceFetchError(String err) => 'حدث خطأ أثناء جلب وثائق التأمين: $err';
  @override
  String get insuranceRetryBtn => 'إعادة المحاولة';

  @override
  String get insuranceKpiTotalPolicies => 'إجمالي الوثائق';
  @override
  String get insuranceKpiIssuedValid => 'وثائق معتمدة';
  @override
  String get insuranceKpiTotalInsured => 'إجمالي القيمة المؤمنة';
  @override
  String get insuranceKpiTotalPremiums => 'إجمالي الأقساط';
  @override
  String get insuranceRefreshRegistryBtn => 'تحديث السجل';
  @override
  String get insuranceNewCertificateBtn => 'إصدار وثيقة تأمين جديدة';

  @override
  String get insuranceSearchHint => 'بحث برقم الوثيقة، رقم البوليصة، المستورد، شركة التأمين، الميناء...';
  @override
  String get insuranceFilterAll => 'الكل';
  @override
  String get insuranceFilterIssued => 'معتمدة';
  @override
  String get insuranceFilterDraft => 'مسودة';
  @override
  String get insuranceFilterCancelled => 'ملغاة';
  @override
  String get insuranceShowDeleted => 'عرض المحذوف';
  @override
  String get insuranceHideDeleted => 'إخفاء المحذوف';

  @override
  String get insuranceNoMatchingFound => 'لم يتم العثور على وثائق تطابق البحث';
  @override
  String get insuranceNoDataFound => 'لا توجد وثائق تأمين مسجلة حالياً';
  @override
  String get insuranceEmptyHint => 'اضغط على "إصدار وثيقة تأمين جديدة" لحساب وتوليد شهادة التأمين البحري أو الجوي';

  @override
  String get insuranceColCertCode => 'كود الوثيقة';
  @override
  String get insuranceColIssueDate => 'تاريخ الإصدار';
  @override
  String get insuranceColPolicyFile => 'رقم البوليصة وملف الشحنة';
  @override
  String get insuranceColInsuredEntity => 'المؤمن له (المستورد)';
  @override
  String get insuranceColInsuranceCo => 'شركة التأمين';
  @override
  String get insuranceColTransportRoute => 'وسيلة النقل وخط السير';
  @override
  String get insuranceColInsuredValue => 'القيمة المؤمنة (110%)';
  @override
  String get insuranceColCoverageClause => 'بند التغطية';
  @override
  String get insuranceColGrossPremium => 'إجمالي القسط المستحق';
  @override
  String get insuranceColStatus => 'الحالة';
  @override
  String get insuranceColActions => 'الإجراءات';

  @override
  String get insuranceStatusIssuedBadge => 'معتمدة';
  @override
  String get insuranceStatusCancelledBadge => 'ملغاة';
  @override
  String get insuranceStatusDraftBadge => 'مسودة';

  @override
  String get insuranceViewTooltip => 'عرض الشهادة الرسمية';
  @override
  String get insuranceEditTooltip => 'تعديل الوثيقة';
  @override
  String get insurancePrintTooltip => 'طباعة شهادة التأمين';
  @override
  String get insuranceDeleteTooltip => 'حذف الوثيقة';
  @override
  String get insuranceIssueCertificateTooltip => 'اعتماد وإصدار الوثيقة';
  @override
  String get insuranceConfirmIssueTitle => 'اعتماد وثيقة التأمين';
  @override
  String insuranceConfirmIssueMsg(String code) => 'هل أنت متأكد من اعتماد وإصدار وثيقة التأمين $code رسمياً؟';
  @override
  String get insuranceConfirmIssueBtn => 'تأكيد الاعتماد';
  @override
  String get insuranceIssueSuccessMsg => '✅ تم اعتماد وإصدار الوثيقة بنجاح!';
  @override
  String get insuranceConfirmDeleteTitle => 'حذف الوثيقة';
  @override
  String get insuranceConfirmDeleteMsg => 'هل تريد حذف هذا السجل نهائياً؟';
  @override
  String get insuranceDeleteBtn => 'حذف';

  @override
  String get insuranceDialogNewTitle => 'إصدار شهادة تأمين البضائع المشحونة';
  @override
  String insuranceDialogEditTitle(String code) => 'تعديل وثيقة التأمين $code';
  @override
  String get insuranceDialogSubtitle => 'حساب القيمة المؤمنة وقسط التأمين طبقاً لشروط معهد المكتتبين بلندن';
  @override
  String get insuranceFieldLinkImportFile => 'ربط ملف الشحنة الاستيرادية *';
  @override
  String get insuranceFieldLinkImportFileHint => 'اختر ملف الشحنة لاستدعاء البيانات تلقائياً...';
  @override
  String get insuranceFieldInsuredEntity => 'المؤمن له (المستورد) *';
  @override
  String get insuranceFieldInsuredEntityRequired => 'اسم المستورد مطلوب';
  @override
  String get insuranceFieldPolicyType => 'نوع وثيقة التأمين *';
  @override
  String get insuranceFieldPolicyTypeHint => 'اختر نوع الوثيقة...';
  @override
  String get insurancePolicyTypeSpecific => 'وثيقة محددة لشحنة واحدة';
  @override
  String get insurancePolicyTypeOpen => 'وثيقة تأمين مفتوحة سنوية';
  @override
  String get insuranceFieldInsuranceCompany => 'شركة التأمين المصدرة';
  @override
  String get insuranceFieldPolicyNumber => 'رقم وثيقة التأمين';
  @override
  String get insuranceSecVoyageDetails => 'بيانات الشحن والرحلة وخط السير';
  @override
  String get insuranceFieldTransportMode => 'وسيلة النقل *';
  @override
  String get insuranceFieldTransportModeHint => 'اختر وسيلة النقل...';
  @override
  String get insuranceTransportModeOcean => 'شحن بحري';
  @override
  String get insuranceTransportModeAir => 'شحن جوي';
  @override
  String get insuranceTransportModeRoad => 'شحن بري';
  @override
  String get insuranceFieldCarrier => 'الخط الملاحي أو الناقل';
  @override
  String get insuranceFieldVesselFlight => 'اسم السفينة أو الرحلة';
  @override
  String get insuranceFieldPol => 'ميناء الشحن والتصدير *';
  @override
  String get insuranceFieldPod => 'ميناء الوصول والتفريغ *';
  @override
  String get insuranceFieldBlTracking => 'رقم بوليصة الشحن والتتبع';
  @override
  String get insuranceFieldInvoiceValue => 'قيمة فاتورة البضاعة فوب *';
  @override
  String get insuranceFieldFreightCost => 'تكلفة النولون أو الشحن';
  @override
  String get insuranceFieldCurrency => 'العملة *';
  @override
  String get insuranceFieldCurrencyHint => 'اختر العملة...';
  @override
  String get insuranceCurrUsd => 'دولار أمريكي';
  @override
  String get insuranceCurrEur => 'يورو أوروبي';
  @override
  String get insuranceCurrEgp => 'جنيه مصري';
  @override
  String get insuranceCurrCny => 'يوان صيني';
  @override
  String get insuranceCurrGbp => 'جنيه إسترليني';
  @override
  String get insuranceSecCoverageClauses => 'شروط التغطية التأمينية وملاحق المخاطر الإضافية';
  @override
  String get insuranceFieldCoverageClause => 'بند التغطية (شروط المعهد) *';
  @override
  String get insuranceFieldCoverageClauseHint => 'اختر بند التغطية...';
  @override
  String get insuranceClauseIccA => 'شروط المعهد (أ) — أخطار شاملة معهد المكتتبين (0.25%)';
  @override
  String get insuranceClauseAirAllRisks => 'شروط المعهد (جوي) — تأمين جوي شامل لكافة الأخطار (0.20%)';
  @override
  String get insuranceClauseIccB => 'شروط المعهد (ب) — أخطار متوسطة محددة معهد المكتتبين (0.15%)';
  @override
  String get insuranceClauseIccC => 'شروط المعهد (ج) — الحد الأدنى للأخطار والحوادث الجسيمة (0.10%)';
  @override
  String get insuranceWarAndStrikesTitle => 'تضمين ملحق أخطار الحروب والإضرابات (+0.05%)';
  @override
  String get insuranceWarAndStrikesSubtitle => 'ملحق إلزامي للاعتمادات المستندية والتخليص الجمركي للشحنات';
  @override
  String get insuranceSecBreakdownTitle => 'محاكاة وحساب قسط التأمين الفوري';
  @override
  String get insuranceBreakdownCifBase => 'قيمة البضاعة سيف شاملة النولون:';
  @override
  String get insuranceBreakdownInsuredValue => 'القيمة المؤمنة الإجمالية (110%):';
  @override
  String insuranceBreakdownBasePremium(String rate) => 'قسط التأمين الأساسي ($rate%):';
  @override
  String get insuranceBreakdownWarStrikes => 'ملحق الحرب والإضرابات (0.05%):';
  @override
  String get insuranceBreakdownNetPremium => 'صافي القسط بعد الحد الأدنى:';
  @override
  String get insuranceBreakdownIssuanceFee => 'رسوم إصدار ودمغات إدارية:';
  @override
  String get insuranceBreakdownTaxes => 'الضرائب والدمغات (5%):';
  @override
  String get insuranceBreakdownTotalPayable => 'إجمالي قسط التأمين المستحق:';
  @override
  String get insuranceSecCargoSpecs => 'وصف البضاعة والطرود المشحونة';
  @override
  String get insuranceFieldGoodsDesc => 'الوصف الدقيق للبضاعة';
  @override
  String get insuranceFieldGoodsDescHint => 'مثال: خطوط إنتاج وقطع غيار صناعية...';
  @override
  String get insuranceFieldPackagesCount => 'عدد الطرود';
  @override
  String get insuranceFieldGrossWeight => 'الوزن القائم (كجم)';
  @override
  String get insuranceSavingState => 'جاري حفظ الوثيقة...';
  @override
  String get insuranceSaveDraftBtn => 'حفظ وإصدار مسودة الوثيقة';
  @override
  String get insuranceCreatedSuccessMsg => '✅ تم إنشاء وثيقة التأمين بنجاح!';
  @override
  String get insuranceUpdatedSuccessMsg => '✅ تم تحديث وثيقة التأمين بنجاح!';
  @override
  String insuranceSaveErrorMsg(String err) => '❌ فشل حفظ الوثيقة: $err';

  @override
  String get insurancePreviewCertificateHeader => 'شهادة التأمين الرسمية على البضائع المشحونة';
  @override
  String get insurancePreviewOfficialIssuedBadge => 'معتمدة رسمياً';
  @override
  String get insurancePreviewDraftBadge => 'مسودة وثيقة';
  @override
  String get insurancePreviewSecInsuredDetails => '1. بيانات المؤمن له والوثيقة';
  @override
  String get insurancePreviewInsuredLabel => 'المؤمن له (المستورد):';
  @override
  String get insurancePreviewCompanyLabel => 'شركة التأمين:';
  @override
  String get insurancePreviewPolicyNoLabel => 'رقم الوثيقة:';
  @override
  String get insurancePreviewPolicyTypeLabel => 'نوع الوثيقة:';
  @override
  String get insurancePreviewSecRouteDetails => '2. خط السير وبيانات الناقل';
  @override
  String get insurancePreviewTransportModeLabel => 'وسيلة النقل:';
  @override
  String get insurancePreviewVesselFlightLabel => 'السفينة أو الرحلة:';
  @override
  @override
  String get insurancePreviewPolLabel => 'ميناء الشحن والتصدير:';
  @override
  String get insurancePreviewPodLabel => 'ميناء الوصول والتفريغ:';
  @override
  String get insurancePreviewTrackingLabel => 'رقم التتبع وبوليصة الشحن:';
  @override
  String get insurancePreviewSecValuation => '3. القيمة التأمينية والأساس';
  @override
  String get insurancePreviewInvoiceFobLabel => 'الفاتورة التجارية فوب:';
  @override
  String get insurancePreviewFreightLabel => 'النولون والشحن:';
  @override
  String get insurancePreviewCifBaseLabel => 'قيمة البضاعة سيف:';
  @override
  String get insurancePreviewInsuredSumLabel => 'المبلغ المؤمن عليه (110%):';
  @override
  String get insurancePreviewSecPremium => '4. تفاصيل واحتساب القسط';
  @override
  String get insurancePreviewCoverageClauseLabel => 'بند التغطية:';
  @override
  String get insurancePreviewBasePremiumLabel => 'القسط الأساسي:';
  @override
  String get insurancePreviewWarStrikesLabel => 'ملحق أخطار الحروب:';
  @override
  String get insurancePreviewFeesTaxesLabel => 'الرسوم والدمغات والضرائب:';
  @override
  String get insurancePreviewTotalGrossPremiumLabel => 'إجمالي قسط التأمين النهائي:';
  @override
  String get insurancePreviewSecCargoSpecs => '5. تفاصيل البضاعة والشروط القانونية';
  @override
  String get insurancePreviewDescPrefix => 'الوصف:';
  @override
  String get insurancePreviewPackagesPrefix => 'الطرود والوزن:';
  @override
  String get insurancePreviewGrossWtPrefix => 'الوزن الإجمالي:';
  @override
  String get insurancePreviewSurveyAgentPrefix => 'وكيل المعاينة وتسوية التعويضات:';
  @override
  String get insurancePreviewClaimsPayablePrefix => 'مكان سداد التعويضات:';
  @override
  String get insurancePreviewLegalDisclaimer => 'وثيقة رسمية معتمدة للتخليص الجمركي والاعتمادات المستندية نموذج 4';
  @override
  String get insurancePreviewPrintBtn => 'طباعة وتصدير المستند';
  @override
  String get insurancePreviewPrintReadySnack => '🖨️ جاهز للإرسال والطباعة الرسمية';

  // Export & Copy Data (Cargo Insurance)
  @override
  String get insuranceExportTsvBtn => 'تصدير جدول البيانات';
  @override
  String get insuranceExportExcelBtn => 'تصدير أكسيل';
  @override
  String get insurancePrintPdfBtn => 'طباعة تقرير بي دي إف';
  @override
  String get insuranceCopyDossierBtn => 'نسخ الملف الشامل';
  @override
  String get insuranceCopiedTsvSuccess => 'تم نسخ بيانات وثائق التأمين بنجاح';
  @override
  String get insuranceCopiedExcelSuccess => 'تم تصدير ملف إكسيل لوثائق التأمين بنجاح';
  @override
  String get insuranceCopiedDossierSuccess => 'تم نسخ الملف الشامل لوثائق التأمين للحافظة';
  @override
  String get insuranceCopyRowSummaryBtn => 'نسخ ملخص الوثيقة';
  @override
  String get insuranceCopyRowSummarySuccess => 'تم نسخ ملخص وثيقة التأمين للحافظة';
  @override
  String get insuranceCopyFieldTooltip => 'نسخ القيمة';
  @override
  String get insuranceSearchCopied => 'تم نسخ نص البحث للحافظة';
  @override
  String insuranceCopyBadgeSuccess(String label, String value) => 'تم نسخ $label ($value) للحافظة';
  @override
  String get insurancePdfTitle => 'سجل شهادات ووثائق التأمين البحري والجوي للبضائع';
  @override
  String get insurancePdfSubtitle => 'تقرير معتمد لشهادات التأمين الصادرة ومطابقة شروط التغطية والمبالغ المؤمنة';
  @override
  String get insuranceDossierHeader => 'ملف توثيق شهادات التأمين على البضائع المشحونة';
  @override
  String get insuranceDossierKpiSummary => 'مؤشرات الأداء والقيم المؤمنة';
  @override
  String get insuranceDossierRecordsDetails => 'تفاصيل شهادات ووثائق التأمين المسجلة';
  @override
  String get insuranceDossierFooter => 'نظام إدارة الاستيراد واللوجستيات — سجل التأمين الرسمي';

  // ─── HS Code Search & Customs Explorer Screen ──────────────────────────────
  @override
  String get hsExplorerTitle => 'محرك البحث الجمركي الشامل وتاريخ البند';
  @override
  String get hsExplorerSubtitle => 'استعلام لحظي عن بنود التعريفة الجمركية المصرية، الضرائب، الاتفاقيات التفضيلية، الاشتراطات الرقابية وسجل التعديلات.';
  @override
  String get hsSearchPlaceholder => 'ابحث برقم البند أو الوصف أو التصنيف أو كود المنشور...';
  @override
  String get hsQuickSearchExamples => 'أمثلة سريعة للبحث:';
  @override
  String get hsMatchingResultsHeader => 'نتائج البنود المطابقة';
  @override
  String hsItemsCount(int count) => '$count بند';
  @override
  String hsNoMatchingItemFound(String query) => 'لا يوجد بند يطابق "$query"';
  @override
  String hsDutyRateTag(dynamic rate) => 'وارد: $rate%';
  @override
  String get hsSelectFromListPrompt => 'اختر بنداً جمركياً من القائمة لمعاينة تفاصيله الشاملة وسجل تحديثاته';
  @override
  String hsCategoryPrefix(String cat) => 'التصنيف: $cat';
  @override
  String hsEffectiveFromPrefix(String from) => 'ساري من: $from';
  @override
  String hsEffectiveToPrefix(String to) => 'إلى $to';
  @override
  String get hsEffectiveActiveRecord => '(سجل معتمد)';
  @override
  String get hsDiffHistoryAction => 'تحليل الاختلافات والتاريخ ➔';
  @override
  String get hsTabTaxRates => 'الضرائب والرسوم';
  @override
  String get hsTabAgreements => 'الاتفاقيات التفضيلية';
  @override
  String get hsTabRegulatory => 'الاشتراطات الرقابية';
  @override
  String get hsTabHistory => 'سجل التحديثات والتاريخ';
  @override
  String get hsTabQuickCalculator => 'حاسبة فورية للبند';
  @override
  String get hsTaxRatesSectionHeader => 'تفاصيل نسب الضرائب والرسوم المقررة قانوناً:';
  @override
  String get hsTaxImportDutyTitle => 'ضريبة الوارد';
  @override
  String get hsTaxImportDutySub => 'نسبة من وعاء القيمة الجمركية الشاملة (سيف)';
  @override
  String get hsTaxVatTitle => 'ضريبة القيمة المضافة';
  @override
  String get hsTaxVatSub => 'نسبة من الوعاء الضريبي الشامل';
  @override
  String get hsTaxScheduleTitle => 'ضريبة الجدول';
  @override
  String get hsTaxScheduleSub => 'ضريبة إضافية حسب بند التعريفة';
  @override
  String get hsTaxDevFeeTitle => 'رسم التنمية';
  @override
  String get hsTaxDevFeeSub => 'رسم تنمية الموارد المالية';
  @override
  String get hsTaxImportFeeTitle => 'رسم الوارد';
  @override
  String get hsTaxImportFeeSub => 'رسم وارد نوعي أو ثابت إن وجد';
  @override
  String get hsTaxServiceFeeTitle => 'رسوم الخدمات الجمركية';
  @override
  String get hsTaxServiceFeeSub => 'خدمات وفحص جمركي';
  @override
  String get hsEgyptianCalculationRule => 'قاعدة الاحتساب الجمركي المصري: يتم تطبيق ضريبة الوارد أولاً على إجمالي القيمة الجمركية الشاملة (سيف = الفاتورة ومصاريف الشحن والتأمين)، ثم حساب الوعاء الضريبي لضريبة القيمة المضافة = (القيمة الجمركية ومبلغ ضريبة الوارد وأي رسوم إضافية).';
  @override
  String get hsNoAgreementsFound => 'لا توجد اتفاقيات تفضيلية مسجلة لهذا البند (يطبق النظام الأساسي العام).';
  @override
  String get hsDefaultAgreementName => 'اتفاقية تفضيلية';
  @override
  String hsRequiredDocPrefix(String doc) => 'المستند المطلوب: $doc';
  @override
  String hsConditionsPrefix(String note) => 'الشروط: $note';
  @override
  String get hsFullExemptionBadge => 'إعفاء كامل (0%)';
  @override
  String hsReducedRateBadge(dynamic rate) => 'فئة مخفضة ($rate%)';
  @override
  String get hsRegulatorySectionHeader => 'الاشتراطات والموافقات الرقابية المسبقة للإفراج:';
  @override
  String get hsReqAcidSystem => 'نظام القيد والتسجيل المسبق للشحنات (نافذة)';
  @override
  String get hsReqCertificateOfOrigin => 'شهادة المنشأ الرسمية المعتمدة';
  @override
  String get hsReqQualityInspection => 'فحص المطابقة النوعي';
  @override
  String hsRegulatoryAuthorityPrefix(String auth) => 'الجهة الرقابية المعنية بالإفراج: $auth';
  @override
  String get hsDecreesAndNotesHeader => 'القرارات والمنشورات الرقابية المقيدة للبند:';
  @override
  String hsHistorySummaryTitle(String code) => 'سجل التعديلات والإصدارات التاريخية للبند الجمركي ($code)';
  @override
  String hsHistoryMultipleVersionsDesc(int count) => 'يحتوي هذا البند على ($count) إصدارات تاريخية مسجلة بفترات سريان مختلفة.';
  @override
  String get hsHistorySingleVersionDesc => 'البند معتمد بإصداره الأساسي الساري حالياً، ومسجل بنظام الحماية التاريخية من التعديل العشوائي.';
  @override
  String hsVersionsCountTag(int count) => '$count إصدارات';
  @override
  String get hsTimelineSectionTitle => 'جدول الفترات وسريان الإصدارات:';
  @override
  String get hsNoHistoricalVersions => 'لا توجد سجلات إصدارات سابقة مسجلة.';
  @override
  String get hsActiveLiveVersionBadge => 'الإصدار الحالي الساري';
  @override
  String get hsArchivedSnapshotBadge => 'إصدار تاريخي سابق';
  @override
  String hsRegistrationDatePrefix(String date) => 'تاريخ التسجيل: $date';
  @override
  String hsValidityPeriodPrefix(String from, String to) => 'فترة السريان والتطبيق: من $from حتى $to';
  @override
  String hsApprovedDescPrefix(String desc) => 'الوصف المعتمد: $desc';
  @override
  String hsLinkedAgreementsTag(dynamic count) => 'الاتفاقيات المربوطة: $count';
  @override
  String get hsVersionDiffsSummaryHeader => 'ملخص التغيرات بين الإصدارات التاريخية:';
  @override
  String hsDiffTitle(String older, String newer) => 'التعديل التاريخي: من إصدار ($older) ➔ إلى إصدار ($newer)';
  @override
  String hsDiffDutyChanged(dynamic oldRate, dynamic newRate) => 'ضريبة الوارد: تغيرت من $oldRate% إلى $newRate%';
  @override
  String hsDiffVatChanged(dynamic oldRate, dynamic newRate) => 'ضريبة القيمة المضافة: تغيرت من $oldRate% إلى $newRate%';
  @override
  String hsDiffScheduleChanged(dynamic oldRate, dynamic newRate) => 'ضريبة الجدول: تغيرت من $oldRate% إلى $newRate%';
  @override
  String hsDiffAgreementsChanged(dynamic oldAg, dynamic newAg) => 'الاتفاقيات التفضيلية: تغير عدد الاتفاقيات من $oldAg إلى $newAg اتفاقية';
  @override
  String get hsDiffMetadataChanged => 'تحديث بيانات وصفية وجهات رقابية واشتراطات مستندية للبند';
  @override
  String get hsAuditTrailSectionTitle => 'سجل تدقيق العمليات والتغييرات:';
  @override
  String get hsNoAuditLogsFound => 'لم تسجل عمليات تدقيق مباشرة بعد (البيانات منشأة آلياً).';
  @override
  String hsAuditPerformedBy(String by, String date) => 'بواسطة: $by • التاريخ: $date';
  @override
  String get hsCalculatorSectionHeader => 'احتساب فوري للرسوم الجمركية والضرائب لهذا البند:';
  @override
  String get hsCifValueLabel => 'القيمة الجمركية الشاملة (سيف) بالدولار';
  @override
  String get hsFreightValueLabel => 'قيمة النولون البحري أو الجوي بالدولار';
  @override
  String get hsOriginCountryLabel => 'بلد المنشأ والاتفاقية التفضيلية';
  @override
  String get hsOriginItalyEur1 => 'إيطاليا (الشراكة المصرية الأوروبية)';
  @override
  String get hsOriginGermanyEur1 => 'ألمانيا (الشراكة المصرية الأوروبية)';
  @override
  String get hsOriginChinaGeneral => 'الصين (النظام الأساسي العام)';
  @override
  String get hsOriginTurkeyFta => 'تركيا (اتفاقية التجارة الحرة)';
  @override
  String get hsOriginBrazilMercosur => 'البرازيل (اتفاقية الميركسور)';
  @override
  String get hsOriginSerbiaFta => 'صربيا (اتفاقية التجارة الحرة)';
  @override
  String get hsOriginUkPartnership => 'المملكة المتحدة (اتفاقية الشراكة)';
  @override
  String get hsCalculateDutyBtn => 'احسب الرسوم';
  @override
  String hsTotalTaxesAndFeesDue(String amount) => 'إجمالي الضرائب والرسوم المستحقة: $amount جنيه مصري';
  @override
  String hsNotePrefix(String note) => 'الملاحظة: $note';
  @override
  String hsImportDutyBreakdown(dynamic rate, String amount) => 'ضريبة الوارد ($rate%): $amount ج.م';
  @override
  String hsVatBreakdown(dynamic rate, String amount) => 'ضريبة القيمة المضافة ($rate%): $amount ج.م';
  @override
  String hsScheduleBreakdown(String amount) => 'ضريبة الجدول: $amount ج.م';
  @override
  String hsServiceFeeBreakdown(String amount) => 'رسوم الخدمات: $amount ج.م';
  @override
  String get hsDatePresentOngoing => 'الآن (مستمر)';
  @override
  String get hsDateToday => 'اليوم';
  @override
  String get hsDateInitial => 'البداية';
  @override
  String get hsActionExecuted => 'تم تنفيذ العملية';

  // Screen 45 Additions: Quick queries, Copy & Exports
  @override
  String get hsQuickQueryAc => 'تكييف';
  @override
  String get hsQuickQueryPlastics => 'لدائن';
  @override
  String get hsQuickQueryMeat => 'لحوم';
  @override
  String get hsQuickQueryWheat => 'قمح';

  @override
  String get hsExplorerExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get hsExplorerExportTsvSuccess => 'تم نسخ بيانات البنود المنسقة إلى الحافظة بنجاح';
  @override
  String get hsExplorerExportExcelBtn => 'تصدير إكسيل';
  @override
  String get hsExplorerExportPdfBtn => 'طباعة وحفظ التقرير الجمركي';

  @override
  String get hsExplorerCopyHsCodeTooltip => 'نسخ كود البند الجمركي';
  @override
  String get hsExplorerCopySummaryBtn => 'نسخ البطاقة الشاملة للبند';
  @override
  String get hsExplorerCopySummarySuccess => 'تم نسخ بطاقة البند الجمركي والضرائب بنجاح';
  @override
  String get hsExplorerCopyDutyBreakdownBtn => 'نسخ جدول احتساب الرسوم';
  @override
  String get hsExplorerCopyDutyBreakdownSuccess => 'تم نسخ تفاصيل احتساب الرسوم الجمركية والضرائب إلى الحافظة بنجاح';
  @override
  String get hsExplorerCopyCardRateTooltip => 'انقر لنسخ النسبة';

  @override
  String get hsExplorerTsvHeaderHsCode => 'كود البند الجمركي';
  @override
  String get hsExplorerTsvHeaderDescription => 'وصف البند';
  @override
  String get hsExplorerTsvHeaderCategory => 'التصنيف';
  @override
  String get hsExplorerTsvHeaderDutyRate => 'ضريبة الوارد %';
  @override
  String get hsExplorerTsvHeaderVatRate => 'ضريبة القيمة المضافة %';
  @override
  String get hsExplorerTsvHeaderScheduleRate => 'ضريبة الجدول %';
  @override
  String get hsExplorerTsvHeaderDevFeeRate => 'رسم التنمية %';
  @override
  String get hsExplorerTsvHeaderImportFeeRate => 'رسم الوارد %';
  @override
  String get hsExplorerTsvHeaderServiceFeeRate => 'رسوم الخدمات %';
  @override
  String get hsExplorerTsvHeaderRegulatoryAuthority => 'الجهة الرقابية';
  @override
  String get hsExplorerTsvHeaderAcidRequired => 'يتطلب تسجيل مسبق';
  @override
  String get hsExplorerTsvHeaderCooRequired => 'يتطلب شهادة منشأ';
  @override
  String get hsExplorerTsvHeaderInspectionRequired => 'يتطلب فحص نوعي';
  @override
  String get hsExplorerTsvHeaderStatus => 'الحالة';

  // ─── Screen 46: SWIFT Message Reconciliation ──────────────────────────────
  @override
  String get swiftScreenTitle => 'مركز مطابقة وتأكيد السويفت البنكي';
  @override
  String get swiftScreenSubtitle => 'محرك الاستخراج الذكي والمطابقة الفورية لبيانات السويفت وإشعارات التحويل';
  @override
  String get swiftLiveSyncActiveBadge => 'التحديث التلقائي لملفات الشحنة مفعل';
  @override
  String get swiftTotalRequestsMetric => 'إجمالي طلبات السداد';
  @override
  String get swiftPendingSwiftMetric => 'بانتظار السويفت';
  @override
  String get swiftMatchedSwiftMetric => 'سويفت مطابق بالكامل';
  @override
  String get swiftVariancesMetric => 'فروقات (عجز / زيادة)';
  @override
  String get swiftAvgProcessingTimeMetric => 'متوسط مدة التنفيذ';
  @override
  String swiftDaysCount(dynamic days) => '$days يوم';

  @override
  String get swiftExtractorHeader => 'محرك الاستخراج الذكي والمطابقة الفورية لبيانات السويفت';
  @override
  String get swiftLoadSampleBtn => 'تحميل نموذج سويفت تجريبي';
  @override
  String get swiftCollapseToolTooltip => 'طي الأداة';
  @override
  String get swiftExpandToolTooltip => 'توسيع الأداة';
  @override
  String get swiftExtractedDocLabel => 'المستند المستخرج:';
  @override
  String get swiftDocTypePrefix => 'النوع:';
  @override
  String get swiftDocSizePrefix => 'الحجم:';
  @override
  String get swiftDocumentDefaultType => 'مستند';
  @override
  String get swiftRawTextPlaceholder => 'الصق نص رسالة السويفت أو إشعار التحويل البنكي هنا...';
  @override
  String get swiftExtractFromTextBtn => 'استخراج فوري من النص';
  @override
  String get swiftUploadFileBtn => 'رفع مستند سويفت';
  @override
  String get swiftExtractingState => 'جاري الاستخراج...';
  @override
  String get swiftMatchingMatrixTitle => 'مصفوفة المطابقة مع طلب السداد المستهدف';
  @override
  String swiftConfidenceScoreTag(dynamic score) => 'نسبة التطابق: $score%';
  @override
  String get swiftExecuteReconcileBtn => 'اعتماد ومطابقة السويفت المكتشف آلياً';
  @override
  String get swiftTargetPaymentLabel => 'طلب السداد المستهدف للمطابقة:';
  @override
  String get swiftExtractedRefPrefix => 'رقم السويفت:';
  @override
  String get swiftExtractedAmountPrefix => 'المبلغ المستخرج:';
  @override
  String get swiftExtractedDatePrefix => 'تاريخ الاستلام:';
  @override
  String get swiftExtractedSenderPrefix => 'المرسل:';
  @override
  String get swiftExtractedReceiverPrefix => 'المستفيد:';

  @override
  String swiftFilterAll(int count) => 'الكل ($count)';
  @override
  String swiftFilterPending(int count) => 'بانتظار السويفت ($count)';
  @override
  String swiftFilterMatched(int count) => 'مطابق ($count)';
  @override
  String swiftFilterVariances(int count) => 'فروقات ($count)';
  @override
  String swiftTableTitle(int count) => 'سجل طلبات السداد ومطابقة السويفت ($count)';
  @override
  String get swiftSearchPlaceholder => 'بحث بكود الطلب، ملف الشحنة، المورد، رقم السويفت...';
  @override
  String get swiftNoMatchingRecords => 'لا توجد طلبات سداد تطابق معايير البحث الحالية.';
  @override
  String get swiftColPaymentCode => 'كود الطلب / الملف';
  @override
  String get swiftColBeneficiaryBank => 'المورد المستفيد والبنك';
  @override
  String get swiftColRequestDate => 'تاريخ تقديم الطلب';
  @override
  String get swiftColSwiftDate => 'تاريخ استلام السويفت';
  @override
  String get swiftColProcessingTime => 'مدة التنفيذ';
  @override
  String get swiftColRequestedAmount => 'المبلغ المطلوب';
  @override
  String get swiftColTransferredAmount => 'المبلغ المنفذ بالسويفت';
  @override
  String get swiftColVarianceStatus => 'حالة المطابقة والفارق';
  @override
  String get swiftChargesLabel => 'رسوم التحويل (71A)';
  @override
  String get swiftColSwiftRef => 'رقم السويفت البنكي';
  @override
  String get swiftColActions => 'العمليات';

  @override
  String get swiftBadgeMatchedFull => 'مطابق تماماً';
  @override
  String swiftBadgeDeficit(String amount, String ccy) => 'عجز ($amount $ccy)';
  @override
  String swiftBadgeSurplus(String amount, String ccy) => 'زيادة (+$amount $ccy)';
  @override
  String get swiftBadgePending => 'بانتظار السويفت';
  @override
  String get swiftStatusUnregistered => 'غير مسجل';
  @override
  String get swiftStatusPendingWait => 'معلق';
  @override
  String get swiftWaitingAmountEntry => 'بانتظار إدخال المبلغ';
  @override
  String swiftExecutionDaysTag(dynamic days) => '$days يوم';
  @override
  String swiftExecutionInstantTag(dynamic days) => 'تنفيذ فوري ($days أيام)';
  @override
  String swiftExecutionReasonableTag(dynamic days) => 'مدة معقولة ($days أيام)';
  @override
  String swiftExecutionDelayedTag(dynamic days) => 'تأخير ($days أيام)';

  @override
  String get swiftRegisterBtn => 'تسجيل السويفت';
  @override
  String get swiftEditBtn => 'تعديل السويفت';
  @override
  String get swiftDetailsBtn => 'عرض التفاصيل';
  @override
  String get swiftCloseBtn => 'إغلاق';
  @override
  String get swiftCancelBtn => 'إلغاء';
  @override
  String get swiftRefreshBtn => 'تحديث البيانات';
  @override
  String swiftReconcileDialogTitle(String code) => 'تسجيل ومطابقة السويفت البنكي: $code';
  @override
  String swiftDetailsDialogTitle(String code) => 'تفاصيل السويفت البنكي: $code';
  @override
  String get swiftRequestTitleLabel => 'عنوان الطلب:';
  @override
  String get swiftBeneficiaryLabel => 'المورد المستفيد:';
  @override
  String get swiftBankLabel => 'البنك:';
  @override
  String get swiftAccountLabel => 'الحساب:';
  @override
  String get swiftRequestDateLabel => 'تاريخ تقديم الطلب';
  @override
  String get swiftRequestedAmountLabel => 'المبلغ المطلوب';
  @override
  String get swiftTransferredAmountLabel => 'المبلغ المنفذ بالسويفت';
  @override
  String get swiftVarianceLabel => 'الفارق';
  @override
  String get swiftReceiptDateLabel => 'تاريخ استلام السويفت من البنك *';
  @override
  String get swiftCurrencyLabel => 'العملة *';
  @override
  String get swiftReconciliationNotesLabel => 'ملاحظات المطابقة والفروقات البنكية (إن وجدت)';
  @override
  String get swiftSyncShipmentNotice => 'سيتم تلقائياً تحديث رقم السويفت في ملف الاستيراد المربوط بمجرد الحفظ والاعتماد.';
  @override
  String get swiftSaveAndSyncBtn => 'حفظ واعتماد السويفت وتحديث ملف الشحنة';
  @override
  String get swiftProcessingTimeLabel => 'مدة التنفيذ';
  @override
  String swiftDaysBetweenDates(dynamic days) => 'مدة التنفيذ: $days يوم ما بين تاريخ الطلب وتاريخ السويفت';
  @override
  String get swiftSampleMT103Chip => 'نموذج تجريبي';
  @override
  String get swiftPasteAndExtractChip => 'لصق واستخراج';
  @override
  String get swiftUploadDocChip => 'رفع مستند';
  @override
  String get swiftEnterSwiftRefError => 'يرجى إدخال رقم السويفت';
  @override
  String get swiftEnterAmountError => 'يرجى إدخال المبلغ';
  @override
  String get swiftAmountGreaterThanZeroError => 'المبلغ يجب أن يكون أكبر من 0';
  @override
  String get swiftCurrencyRequiredError => 'العملة مطلوبة';

  @override
  String get swiftFileReadErrorSnack => 'تعذر قراءة بيانات الملف المحدد';
  @override
  String swiftExtractSuccessSnack(String filename, String type) => 'تم استخراج بيانات السويفت بنجاح من ملف "$filename" ($type)';
  @override
  String swiftExtractErrorSnack(String error) => 'تعذر استخراج السويفت من الملف: $error';
  @override
  String get swiftEmptyInputErrorSnack => 'يرجى لصق أو إدخال نص رسالة السويفت أو إشعار البنك أولاً';
  @override
  String get swiftParseSuccessSnack => 'تم استخراج بيانات السويفت وتحديد طلب السداد المطابق بنجاح';
  @override
  String swiftParseErrorSnack(String error) => 'تعذر تحليل السويفت: $error';
  @override
  String swiftConnectionErrorSnack(String error) => 'خطأ في الاتصال: $error';
  @override
  String swiftReconcileSuccessSnack(String swiftRef, String paymentCode) => 'تم تأكيد مطابقة السويفت ($swiftRef) واعتماد سداد الطلب ($paymentCode) وتحديث ملف الاستيراد بنجاح!';
  @override
  String swiftReconcileErrorSnack(String error) => 'خطأ أثناء تأكيد المطابقة: $error';
  @override
  String swiftReconcileMissingFields(String fields) =>
      'الحقول التالية مطلوبة لإتمام المطابقة الذكية للسويفت: $fields';
  @override
  String get swiftBatchNotConfirmed =>
      'لا يمكن مطابقة حزمة السويفت قبل مراجعتها وتأكيدها';
  @override
  String get swiftFieldRef => 'الرقم المرجعي للسويفت';
  @override
  String get swiftFieldValueDate => 'تاريخ الاستحقاق';
  @override
  String get swiftFieldAmount => 'المبلغ';
  @override
  String get swiftFieldCurrency => 'العملة';

  @override
  String get swiftExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get swiftExportTsvSuccess => 'تم نسخ بيانات المطابقة إلى الحافظة بنجاح';
  @override
  String get swiftExportExcelBtn => 'تصدير إكسيل';
  @override
  String get swiftExportPdfBtn => 'طباعة وحفظ التقرير';
  @override
  String get swiftCopySummaryBtn => 'نسخ بطاقة المطابقة';
  @override
  String get swiftCopySummarySuccess => 'تم نسخ تفاصيل مطابقة السويفت إلى الحافظة بنجاح';
  @override
  String get swiftCopyFieldTooltip => 'انقر للنسخ';
  @override
  String get swiftPrintSlipBtn => 'طباعة إشعار السويفت';

  @override
  String get swiftTsvHeaderPaymentCode => 'كود طلب السداد';
  @override
  String get swiftTsvHeaderImportFile => 'ملف الشحنة';
  @override
  String get swiftTsvHeaderBeneficiary => 'المستفيد';
  @override
  String get swiftTsvHeaderBank => 'البنك';
  @override
  String get swiftTsvHeaderRequestDate => 'تاريخ الطلب';
  @override
  String get swiftTsvHeaderSwiftReceiptDate => 'تاريخ استلام السويفت';
  @override
  String get swiftTsvHeaderProcessingDays => 'مدة التنفيذ بالأيام';
  @override
  String get swiftTsvHeaderRequestedAmount => 'المبلغ المطلوب';
  @override
  String get swiftTsvHeaderTransferredAmount => 'المبلغ المنفذ';
  @override
  String get swiftTsvHeaderVariance => 'الفارق';
  @override
  String get swiftTsvHeaderSwiftRef => 'رقم السويفت';
  @override
  String get swiftTsvHeaderStatus => 'حالة المطابقة';

  @override
  String get swiftCopyBtn => 'نسخ';
  @override
  String get swiftAutoSyncNotice => 'التحديث التلقائي لملفات الشحنة مفعل';
  @override
  String get swiftNoMatchingPayments => 'لا توجد طلبات سداد تطابق معايير البحث الحالية';
  @override
  String get swiftPendingSwiftBadge => 'بانتظار إشعار التحويل البنكي';
  @override
  String get swiftUnspecifiedBank => 'بنك غير محدد';
  @override
  String get swiftProcessingPending => 'قيد الانتظار';
  @override
  String get swiftUnregistered => 'غير مسجل';
  @override
  String get swiftCopyDossierBtn => 'نسخ ملف السداد وإشعار التحويل';

  // Dynamic Report Builder
  @override
  String get dynReportBuilderTitle => 'مُنشئ التقارير الديناميكية والمخصصة';
  @override
  String get dynReportBuilderSubtitle => 'تخصيص وتوليد تقارير الشحنات والعمليات وتصديرها بصيغ Excel و PDF';
  @override
  String dynCustomizeColumnsBtn(int visible, int total) => 'تخصيص الأعمدة ($visible/$total)';
  @override
  String dynExportExcelBtn(int count) => 'تصدير Excel [$count]';
  @override
  String dynExportPdfBtn(int count) => 'تصدير PDF [$count]';
  @override
  String get dynFilterModeLabel => 'وسيلة النقل';
  @override
  String get dynFilterPriorityLabel => 'الأولوية';
  @override
  String get dynSearchPlaceholder => 'بحث ديناميكي برقم الملف أو الشركة أو المورد...';
  @override
  String get dynModeAll => 'الكل';
  @override
  String get dynModeSeaFcl => 'بحري FCL';
  @override
  String get dynModeSeaLcl => 'بحري LCL';
  @override
  String get dynModeAir => 'شحن جوي';
  @override
  String get dynModeCourier => 'بريد سريع';
  @override
  String get dynModeLand => 'نقل بري';
  @override
  String get dynModeMultimodal => 'متعدد الوسائط';
  @override
  String get dynPriorityAll => 'الكل';
  @override
  String get dynPriorityHigh => 'مرتفعة';
  @override
  String get dynPriorityCritical => 'حرجة جداً';
  @override
  String get dynPriorityMedium => 'متوسطة';
  @override
  String get dynColumnPickerTitle => 'مُخصص الأعمدة الديناميكية';
  @override
  String get dynApplyColumnsBtn => 'تطبيق اختيار الأعمدة';
  @override
  String get dynExportCsvTitle => 'تصدير التقرير الديناميكي (Excel CSV)';
  @override
  String get dynExportCsvGeneratedMsg => 'تم توليد كود التقرير المخصص بنجاح، يمكنك نسخه لاستخدامه في Excel:';
  @override
  String dynFetchReportError(String err) => 'خطأ في جلب بيانات التقرير: $err';
  @override
  String get dynNoMatchingShipments => 'لا توجد شحنات مطابقة لفلاتر التقرير الديناميكي.';
  @override
  String get dynPdfReportTitle => 'نظام سرور للخدمات اللوجستية — تقرير الشحنات الديناميكي';
  @override
  String get dynPdfConfidential => 'سرور للخدمات اللوجستية — سري ومخصص للاستخدام الداخلي';
  @override
  String dynPdfGenerated(String date, int count) => 'تاريخ التوليد: $date | عدد السجلات: $count';
  @override
  String get dynColImportFileCode => 'كود الملف';
  @override
  String get dynColCompanyName => 'الشركة المستوردة';
  @override
  String get dynColSupplierName => 'المورد الأجنبي';
  @override
  String get dynColBrokerName => 'المخلص الجمركي';
  @override
  String get dynColAcidNumber => 'رقم ACID';
  @override
  String get dynColForm4No => 'رقم نموذج 4';
  @override
  String get dynColForm46No => 'إقرار 46 جمارك';
  @override
  String get dynColShipmentMode => 'وسيلة النقل';
  @override
  String get dynColIncotermCode => 'الشرط التجاري';
  @override
  String get dynColPriority => 'الأولوية';
  @override
  String get dynColEstimatedCost => 'القيمة التقديرية';
  @override
  String get dynColRequiredEta => 'تاريخ الوصول المتوقع';
  @override
  String get dynColCurrentStage => 'المرحلة الحالية';
  @override
  String get dynColProgressPercent => 'نسبة الإنجاز %';
  @override
  String get dynColOwner => 'المسؤول';
  @override
  String get dynColStatus => 'حالة الملف';
  @override
  String get dynTemplatePresetLabel => 'قالب التقرير';
  @override
  String get dynTemplateCustom => 'تخصيص حر (ديناميكي)';
  @override
  String get dynTemplateEco => 'قالب شركة إيكو (ECO Radar)';
  @override
  String get dynTemplateScas => 'قالب شركة سكاس (SCAS Tracker)';
  @override
  String dynLastUpdatedLabel(String timestamp) => 'آخر تحديث: $timestamp';
  @override
  String get dynSearchColumnsPlaceholder => 'بحث في الأعمدة...';
  @override
  String get dynSelectAll => 'تحديد الكل';
  @override
  String get dynDeselectAll => 'إلغاء التحديد';
  @override
  String get dynCatFileAndProject => 'بيانات الملف والمشروع والشركة';
  @override
  String get dynCatCommercialAndPo => 'الفواتير وأوامر الشراء والشروط المالية';
  @override
  String get dynCatShippingAndLogistics => 'الشحن واللوجستيات والموانئ';
  @override
  String get dynCatPackagesAndCbm => 'الطرود والأوزان والحجم بالمتر المكعب';
  @override
  String get dynCatCustomsAndNafeza => 'الجمارك ونافذة وCargoX';
  @override
  String get dynCatBankingAndSwift => 'العمليات البنكية ونموذج 4 والسويفت';
  @override
  String get dynCatScasTracking => 'متتبع عمليات وتنسيق SCAS (16 عموداً)';
  @override
  String get dynCatEcoTracking => 'رادار ومستندات ECO Associates (15 عموداً)';
  @override
  String get dynColCustomFileNumber => 'رقم ملف العميل';
  @override
  String get dynColProjectNames => 'اسم المشروع';
  @override
  String get dynColNextAction => 'الإجراء التالي';
  @override
  String get dynColNotes => 'ملاحظات التشغيل';
  @override
  String get dynColFileOpeningDate => 'تاريخ فتح الملف / التحرك';
  @override
  String get dynColPoNumber => 'رقم أمر الشراء';
  @override
  String get dynColPiNumber => 'رقم الفاتورة المبدئية';
  @override
  String get dynColPiValue => 'قيمة الفاتورة المبدئية';
  @override
  String get dynColShippingLine => 'شركة / خط الشحن';
  @override
  String get dynColPortOfLoading => 'ميناء الشحن';
  @override
  String get dynColPortOfDischarge => 'ميناء التفريغ';
  @override
  String get dynColCargoReadyDate => 'تاريخ جاهزية البضاعة';
  @override
  String get dynColTargetFreeDays => 'أيام السماح المجانية';
  @override
  String get dynColTotalPackages => 'إجمالي الطرود';
  @override
  String get dynColGrossWeightKg => 'الوزن الإجمالي (كجم)';
  @override
  String get dynColTotalCbm => 'الحجم التكعيبي بالمتر المكعب';
  @override
  String get dynColAcidIssueDate => 'تاريخ إصدار ACID';
  @override
  String get dynColAcidExpiryDate => 'تاريخ انتهاء ACID';
  @override
  String get dynColCustomsReleaseStatus => 'حالة الإفراج الجمركي';
  @override
  String get dynColCustomsReleasedAt => 'تاريخ الإفراج الجمركي';
  @override
  String get dynColForm4ReceivedDate => 'تاريخ ورود نموذج 4';
  @override
  String get dynColSwiftNo => 'رقم السويفت البنكي';
  @override
  String get dynColSwiftDate => 'تاريخ السويفت';
  @override
  String get dynColSwiftAmount => 'قيمة السويفت';
  @override
  String get dynColUpdatedAt => 'تاريخ آخر تحديث';
  @override
  String get dynColEcoBroker => 'Custom Broker Name';
  @override
  String get dynColEcoShipmentNo => 'Shipment No';
  @override
  String get dynColEcoSupplier => 'Supp. Name';
  @override
  String get dynColEcoProject => 'Project Name';
  @override
  String get dynColEcoPiValue => 'PI Value';
  @override
  String get dynColEcoShippingDate => 'Shipping Date';
  @override
  String get dynColEcoArrivalPort => 'Arrival Port';
  @override
  String get dynColEcoArrivalWarehouse => 'Arrival Warehouse';
  @override
  String get dynColEcoSara => 'المسئول عن المشروع';
  @override
  String get dynColEcoMaro => 'مالك المشروع';
  @override
  String get dynColEcoReadyToPickUp => 'Ready to Pick Up Date';
  @override
  String get dynColEcoLatestUpdate => 'Latest Update for Pending Shipment';
  @override
  String get dynColEcoSwiftDate => 'تاريخ السويفت';
  @override
  String get dynColEcoSwiftAmount => 'قيمة السويفت';
  @override
  String get dynColEcoShippingCompany => 'شركة الشحن';
  @override
  String get dynColEcoAcid => 'ACID';
  @override
  String get dynColScasProjectFileAcid => 'Project';
  @override
  String get dynColScasExFactory => 'EX Factory';
  @override
  String get dynColScasOrderToOrigin => 'Order to Origin for Pick Up';
  @override
  String get dynColScasPickUpDate => 'Pick Up Date from Gind';
  @override
  String get dynColScasDeparturePort => 'Departure Date from Port (ETD)';
  @override
  String get dynColScasArrivalAlexPort => 'Arrival Date to Alex Port (ETA)';
  @override
  String get dynColScasOrigInvoice => 'Original Commercial Invoice';
  @override
  String get dynColScasOrigPackingList => 'Original Packing List';
  @override
  String get dynColScasOrigCoo => 'Original Certificate of Origin';
  @override
  String get dynColScasOrigBl => 'Original Bill of Lading';
  @override
  String get dynColScasOrigInsurance => 'Original Insurance Certificate';
  @override
  String get dynColScasInsertNafeza => 'Insert on Nafeza';
  @override
  String get dynColScasBankForm4 => 'Bank Name (Form 4)';
  @override
  String get dynColScasDeclare3A => 'Declare to 3A';
  @override
  String get dynColScasMaterialReceived => 'Material Received';
  @override
  String get dynRefreshTooltip => 'تحديث البيانات والوقت';
  @override
  String get dynCustomizeColumnsGenericBtn => 'تخصيص أعمدة التقرير';
  @override
  String get dynCopyTsvBtn => 'نسخ كجدول بيانات';
  @override
  String dynTsvCopiedMsg(int count) => 'تم نسخ بيانات $count شحنة إلى الحافظة بنجاح';
  @override
  String get dynCopyRowTooltip => 'نسخ ملخص الشحنة بالكامل';
  @override
  String get dynExportExcelDialogTitle => 'تصدير التقرير بصيغة جدول بيانات';
  @override
  String get dynExportPdfDialogTitle => 'تصدير التقرير بصيغة ملف بي دي إف';
  @override
  String dynActiveColumnsCount(int count) => 'الأعمدة: $count';
  @override
  String get dynColumnPickerSubtitle => 'اختر الحقول المطلوب إدراجها بالتقرير، أو استخدم القوالب الجاهزة';
  @override
  String get dynCustomsReleased => 'مفرج عنه';
  @override
  String get dynCustomsUnderClearance => 'قيد التخليص';
  @override
  String dynDaysCount(int count) => '$count يوم';
  @override
  String dynGrossWeightKg(String weight) => '$weight كجم';
  @override
  String dynTotalCbm(String cbm) => '$cbm م³';
  @override
  String get dynStatusPending => 'قيد الانتظار';
  @override
  String get dynStatusDone => 'تم الإنجاز';
  @override
  String get dynStatusReceived => 'تم الاستلام';
  @override
  String get dynCellOriginOk => 'شهادة المنشأ معتمدة';
  @override
  String get dynCellExpressBl => 'بوليصة شحن سريعة';
  @override
  String get dynCellOriginCovered => 'مشمول في بلد المنشأ';
  @override
  String get dynCellIssuedReceived => 'تم الاستلام والإصدار';
  @override
  String get dynCellPendingAcid => 'في انتظار القيد الجمركي المسبق';
  @override
  String get dynCellPendingBank => 'في انتظار البنك';
  @override
  String get dynCellPending46 => 'في انتظار إقرار 46';
  @override
  String get dynCellDeliveredWarehouse => 'تم التسليم بالمستودع';
  @override
  String get dynCellInClearancePort => 'قيد التخليص بالميناء';
  @override
  String dynRecordsCount(int count) => '$count سجل';

  // ── Screen 68: Comprehensive Import File Report ───────────────────────────
  @override
  String get compReportScreenTitle => 'تقرير ملف الاستيراد الشامل والمدمج';
  @override
  String get compReportAddUpdateBtn => 'إضافة تحديث';
  @override
  String get compReportSelectFileLabel => 'اختر ملف الاستيراد لعرض التقرير الشامل';
  @override
  String get compReportEmptyStatePrompt => 'اختر ملف استيراد من القائمة أعلاه\nلعرض التقرير الشامل والمدمج';
  @override
  String compReportPercentCompleted(String percent) => '$percent% مكتمل';
  @override
  String get compReportCompletedPhases => 'مراحل مكتملة';
  @override
  String get compReportRemainingPhases => 'مراحل متبقية';
  @override
  String get compReportPipelineTitle => 'خط سير مراحل الشحنة التشغيلي (10 مراحل)';
  @override
  String compReportStoppedAtPhase(String phase) => 'تم إيقاف الشحنة عند: $phase';
  @override
  String get compReportSecBasicInfo => 'بيانات ملف الاستيراد الأساسية';
  @override
  String get compReportColFileCode => 'كود الملف';
  @override
  String get compReportColCustomsFileNo => 'رقم الملف الجمركي';
  @override
  String get compReportColImportCompany => 'الشركة المستوردة';
  @override
  String get compReportColSupplier => 'المورد الأجنبي';
  @override
  String get compReportColBroker => 'المخلص الجمركي';
  @override
  String get compReportColPoNumber => 'رقم أمر الشراء';
  @override
  String get compReportColPiNumber => 'رقم الفاتورة المبدئية';
  @override
  String get compReportColShipmentMode => 'وسيلة الشحن';
  @override
  String get compReportColIncoterm => 'شرط التجارة الدولي';
  @override
  String get compReportColCategory => 'فئة الشحنة';
  @override
  String get compReportColScenario => 'السيناريو المختار';
  @override
  String get compReportColRequiredEta => 'تاريخ الوصول المتوقع';
  @override
  String get compReportColOwner => 'المسئول التشغيلي';
  @override
  String get compReportColCreatedAt => 'تاريخ الإنشاء';
  @override
  String get compReportColUpdatedAt => 'آخر تحديث';
  @override
  String get compReportSecDocs => 'المستندات الرسمية والوثائق الجمركية';
  @override
  String get compReportAcidNumber => 'رقم التسجيل المسبق للشحنات نافذة';
  @override
  String get compReportBankForm4 => 'رقم نموذج 4 البنكي';
  @override
  String get compReportSwiftNumber => 'رقم التحويل البنكي سويفت';
  @override
  String get compReportForm46Number => 'رقم إقرار 46 الجمركي';
  @override
  String compReportSecInvoices(int count) => 'الفواتير التجارية المرتبطة ($count فاتورة)';
  @override
  String get compReportNoInvoices => 'لا توجد فواتير مسجلة';
  @override
  String compReportSecPackingLists(int count) => 'قوائم التعبئة والشحن ($count قائمة)';
  @override
  String get compReportNoPackingLists => 'لا توجد بيانات قوائم التعبئة';
  @override
  String get compReportTotalPackages => 'الطرود الإجمالية';
  @override
  String get compReportTotalWeight => 'الوزن الإجمالي';
  @override
  String get compReportTotalCbm => 'الحجم الإجمالي بالمتر المكعب';
  @override
  String compReportPackagesUnit(dynamic count) => '$count طرد';
  @override
  String compReportPiecesUnit(dynamic count) => '$count قطعة';
  @override
  String get compReportSecStatus => 'الحالة التشغيلية والمرحلة الحالية';
  @override
  String compReportPriorityPrefix(String priority) => 'الأولوية: $priority';
  @override
  String get compReportStatusLabel => 'الحالة';
  @override
  String get compReportCurrentStageLabel => 'المرحلة الحالية';
  @override
  String get compReportCurrentModuleLabel => 'المعالجة الحالية';
  @override
  String get compReportNextActionLabel => 'الإجراء التالي المطلوب';
  @override
  String get compReportTotalProgressLabel => 'نسبة الإنجاز الكلية:';
  @override
  String get compReportSecFinancial => 'الملخص المالي';
  @override
  String get compReportTotalInvoicesVal => 'قيمة الفواتير الإجمالية';
  @override
  String get compReportEstimatedCostVal => 'التكلفة التقديرية الشاملة';
  @override
  String get compReportEstimatedVariance => 'الفرق التقديري';
  @override
  String get compReportSecNotes => 'الملاحظات العامة';
  @override
  String get compReportNoNotes => 'لا توجد ملاحظات عامة مسجلة.';
  @override
  String compReportSecTimeline(int count) => 'سجل التحديثات والمتابعة التشغيلية اليومية ($count تحديث)';
  @override
  String get compReportNoTimelineLogs => 'لا توجد تحديثات تشغيلية مسجلة على هذه الشحنة حتى الآن.';
  @override
  String compReportByPrefix(String user) => 'بواسطة: $user';
  @override
  String compReportAlertPriorityPrefix(String priority) => 'درجة الأولوية: $priority';
  @override
  String get compReportSecClearance => 'بيانات التخليص الجمركي (المرحلة 7)';
  @override
  String get compReportNoClearanceData => 'لا توجد بيانات تخليص جمركي';
  @override
  String compReportDeclarationChip(String no) => 'إقرار: $no';
  @override
  String compReportReleasePermitChip(String no) => 'تصريح إفراج: $no';
  @override
  String get compReportDutyImport => 'ضريبة الوارد';
  @override
  String get compReportDutyVat => 'القيمة المضافة';
  @override
  String get compReportDutySchedule => 'ضريبة الجدول';
  @override
  String get compReportDutyInspection => 'رسوم العرض';
  @override
  String get compReportDutyTotal => 'الإجمالي';
  @override
  String compReportPaymentDate(String date) => 'تاريخ السداد: $date';
  @override
  String compReportReleaseDate(String date) => 'تاريخ الإفراج: $date';
  @override
  String get compReportSecWarehouse => 'استلام المخازن وإذن الإضافة (المرحلة 8)';
  @override
  String get compReportNoWarehouseData => 'لا توجد بيانات استلام مخازن';
  @override
  String compReportGrnChip(String code) => 'إذن إضافة: $code';
  @override
  String compReportArrivalDatetime(String date) => 'وصول: $date';
  @override
  String compReportInspectorPrefix(String name) => 'المفتش: $name';
  @override
  String get compReportQtyInvoiced => 'الكمية المفوترة';
  @override
  String get compReportQtyAccepted => 'المقبول';
  @override
  String get compReportQtyShortage => 'العجز';
  @override
  String get compReportQtyDamaged => 'التالف';
  @override
  String get compReportTableColCode => 'الكود';
  @override
  String get compReportTableColItem => 'الصنف';
  @override
  String get compReportTableColInvoiced => 'فواتير';
  @override
  String get compReportTableColAccepted => 'مقبول';
  @override
  String get compReportTableColShortage => 'عجز';
  @override
  String get compReportTableColDamaged => 'تالف';
  @override
  String get compReportPhase1Name => 'التخطيط والجدوى والنولون';
  @override
  String get compReportPhase2Name => 'الموافقة والاعتماد المالي';
  @override
  String get compReportPhase3Name => 'المستندات والتسجيل المسبق ونموذج 4';
  @override
  String get compReportPhase4Name => 'حجز الشحن والناقل';
  @override
  String get compReportPhase5Name => 'الشحن الفعلي والتتبع الرقمي';
  @override
  String get compReportPhase6Name => 'إقرار 46 والتعريفة الجمركية';
  @override
  String get compReportPhase7Name => 'التخليص الجمركي وسداد الرسوم';
  @override
  String get compReportPhase8Name => 'استلام البضاعة وإذن الإضافة بالمخازن';
  @override
  String get compReportPhase9Name => 'تسوية تكلفة الوصول الشاملة';
  @override
  String get compReportPhase10Name => 'إغلاق الملف والأرشفة التاريخية';
  @override
  String get compReportCategoryCostAdjustment => 'تعديل تكلفة مرحلة';
  @override
  String get compReportCategoryFutureAlert => 'تنبيه مرحلة مستقبلية';
  @override
  String get compReportCategoryDailyCheckIn => 'تسجيل متابعة يومي';
  @override
  String get compReportCategoryGeneralUpdate => 'تحديث تشغيلي عام';
  @override
  String get compReportExportTsvBtn => 'تصدير نصي مفصول';
  @override
  String get compReportExportExcelBtn => 'تصدير إكسيل';
  @override
  String get compReportPrintPdfBtn => 'طباعة وحفظ المستند';
  @override
  String get compReportCopyDossierBtn => 'نسخ الملف الشامل';
  @override
  String get compReportCopyDossierSuccess => 'تم نسخ الملف الشامل للشحنة إلى الحافظة بنجاح';
  @override
  String get compReportExportTsvDialogTitle => 'تصدير التقرير الشامل بصيغة نصية مفصولة';
  @override
  String get compReportExportExcelDialogTitle => 'تصدير ملف الشحنة الشامل إلى جدول إكسيل';
  @override
  String get compReportPrintPdfDialogTitle => 'طباعة أو حفظ التقرير الشامل لملف الاستيراد';
  @override
  String get compReportDossierHeader => 'نظام سرور لإدارة سلاسل الإمداد — التقرير الشامل لملف الاستيراد';
  @override
  String compReportPhaseLabel(int index) => 'المرحلة $index';
  @override
  String compReportCopyValueTooltip(String field) => 'نسخ $field إلى الحافظة';
  @override
  String get compReportCurrencyUsd => 'دولار أمريكي';
  @override
  String get compReportTsvColSection => 'القسم';
  @override
  String get compReportTsvColField => 'البيان';
  @override
  String get compReportTsvColValue => 'القيمة';
  @override
  String get compReportTsvColDetails => 'التفاصيل والملاحظات';

  // ── Users Management & RBAC Screen ──────────────────────────────────────────
  @override
  String get usersMgmtTitle => 'إدارة المستخدمين والصلاحيات';
  @override
  String usersMgmtSubtitle(int count) => 'التحكم في حسابات المستخدمين — $count مستخدم مسجل';
  @override
  String get usersMgmtRefreshTooltip => 'تحديث قائمة المستخدمين';
  @override
  String get usersMgmtNewUserBtn => 'مستخدم جديد';
  @override
  String get usersMgmtReadOnlyNotice => 'عرض فقط — صلاحية مدير النظام مطلوبة للتعديل';
  @override
  String get usersMgmtStatAll => 'الكل';
  @override
  String get usersMgmtStatActive => 'نشط';
  @override
  String get usersMgmtStatAdmin => 'مدير نظام';
  @override
  String get usersMgmtStatManager => 'مدير عمليات';
  @override
  String get usersMgmtStatOperator => 'أخصائي';
  @override
  String get usersMgmtSearchHint => 'بحث بالاسم، اسم المستخدم، أو البريد...';
  @override
  String get usersMgmtColFullName => 'الاسم الكامل';
  @override
  String get usersMgmtColUsername => 'اسم المستخدم';
  @override
  String get usersMgmtColEmail => 'البريد الإلكتروني';
  @override
  String get usersMgmtColRole => 'الدور والصلاحية';
  @override
  String get usersMgmtColStatus => 'الحالة';
  @override
  String get usersMgmtColCreatedAt => 'تاريخ الإنشاء';
  @override
  String get usersMgmtColActions => 'الإجراءات';
  @override
  String get usersMgmtSelfBadge => '(أنت)';
  @override
  String get usersMgmtStatusActive => 'نشط';
  @override
  String get usersMgmtStatusInactive => 'معطّل';
  @override
  String get usersMgmtRoleAdminLabel => 'مدير نظام';
  @override
  String get usersMgmtRoleManagerLabel => 'مدير عمليات';
  @override
  String get usersMgmtRoleOperatorLabel => 'أخصائي';
  @override
  String get usersMgmtActionEditTooltip => 'تعديل بيانات المستخدم';
  @override
  String get usersMgmtActionDeactivateTooltip => 'تعطيل الحساب';
  @override
  String get usersMgmtActionActivateTooltip => 'تفعيل الحساب';
  @override
  String get usersMgmtNoResults => 'لا توجد نتائج مطابقة للبحث أو الفلتر';
  @override
  String get usersMgmtNoResultsHint => 'جرّب تغيير خيارات التصفية أو مسح عبارة البحث';
  @override
  String get usersMgmtRetryBtn => 'إعادة المحاولة';
  @override
  String get usersMgmtDialogEditTitle => 'تعديل بيانات المستخدم';
  @override
  String get usersMgmtDialogNewTitle => 'إضافة مستخدم جديد';
  @override
  String get usersMgmtFieldFullName => 'الاسم الكامل *';
  @override
  String get usersMgmtFieldFullNameHint => 'مثال: أحمد محمد سرور';
  @override
  String get usersMgmtFieldFullNameRequired => 'يرجى إدخال الاسم الكامل';
  @override
  String get usersMgmtFieldUsername => 'اسم المستخدم *';
  @override
  String get usersMgmtFieldUsernameHint => 'مثال: ahmed_sorour';
  @override
  String get usersMgmtFieldUsernameHelper => 'لا يمكن تعديل اسم المستخدم بعد الإنشاء';
  @override
  String get usersMgmtFieldUsernameRequired => 'اسم المستخدم مطلوب';
  @override
  String get usersMgmtFieldUsernameMinLength => 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
  @override
  String get usersMgmtFieldUsernameNoSpaces => 'اسم المستخدم يجب ألا يحتوي على مسافات';
  @override
  String get usersMgmtFieldEmail => 'البريد الإلكتروني *';
  @override
  String get usersMgmtFieldEmailHint => 'مثال: ahmed@company.com';
  @override
  String get usersMgmtFieldEmailRequired => 'البريد الإلكتروني مطلوب';
  @override
  String get usersMgmtFieldEmailInvalid => 'يرجى إدخال بريد إلكتروني صالح';
  @override
  String get usersMgmtFieldRole => 'الدور والصلاحيات *';
  @override
  String get usersMgmtRoleAdminOption => 'مدير نظام — صلاحيات كاملة وإدارة المستخدمين';
  @override
  String get usersMgmtRoleManagerOption => 'مدير عمليات — اعتماد القرارات والتقارير المتقدمة';
  @override
  String get usersMgmtRoleOperatorOption => 'أخصائي استيراد — إدخال البيانات ومتابعة العمليات';
  @override
  String get usersMgmtFieldRoleRequired => 'يرجى اختيار الدور والصلاحية';
  @override
  String get usersMgmtFieldPasswordNew => 'كلمة مرور جديدة (اتركها فارغة لعدم التغيير)';
  @override
  String get usersMgmtFieldPassword => 'كلمة المرور *';
  @override
  String get usersMgmtFieldPasswordRequired => 'كلمة المرور مطلوبة';
  @override
  String get usersMgmtFieldPasswordMinLength => 'كلمة المرور يجب ألا تقل عن 6 أحرف';
  @override
  String get usersMgmtBtnCancel => 'إلغاء';
  @override
  String get usersMgmtBtnSave => 'حفظ التعديلات';
  @override
  String get usersMgmtBtnCreate => 'إنشاء المستخدم';
  @override
  String get usersMgmtSuccessUpdated => 'تم تعديل بيانات المستخدم بنجاح';
  @override
  String get usersMgmtSuccessCreated => 'تم إنشاء المستخدم بنجاح';
  @override
  String get usersMgmtConfirmActivateTitle => 'تفعيل حساب المستخدم';
  @override
  String get usersMgmtConfirmDeactivateTitle => 'تعطيل حساب المستخدم';
  @override
  String get usersMgmtConfirmActivatePrompt => 'هل تريد تفعيل حساب هذا المستخدم وتمكينه من الدخول للنظام؟';
  @override
  String get usersMgmtConfirmDeactivatePrompt => 'هل تريد تعطيل حساب هذا المستخدم؟ لن يتمكن من تسجيل الدخول بعد التعطيل.';
  @override
  String get usersMgmtBtnActivate => 'تفعيل';
  @override
  String get usersMgmtBtnDeactivate => 'تعطيل';
  @override
  String get usersMgmtSuccessActivated => 'تم تفعيل حساب المستخدم بنجاح';
  @override
  String get usersMgmtSuccessDeactivated => 'تم تعطيل حساب المستخدم بنجاح';
  @override
  String get usersMgmtRoleAdminDescTitle => 'مدير النظام — صلاحيات كاملة';
  @override
  String get usersMgmtRoleAdminPerm1 => 'إدارة المستخدمين وصلاحياتهم وتعيين الأدوار';
  @override
  String get usersMgmtRoleAdminPerm2 => 'الوصول غير المقيد لجميع شاشات وأدوات النظام';
  @override
  String get usersMgmtRoleAdminPerm3 => 'تعديل البيانات المرجعية والجداول الأساسية';
  @override
  String get usersMgmtRoleAdminPerm4 => 'مزامنة وترحيل قواعد البيانات الإنتاجية';
  @override
  String get usersMgmtRoleAdminPerm5 => 'مراجعة سجلات التدقيق والرقابة الكاملة';
  @override
  String get usersMgmtRoleManagerDescTitle => 'مدير العمليات — صلاحيات متقدمة';
  @override
  String get usersMgmtRoleManagerPerm1 => 'الوصول لجميع ملفات الاستيراد وأوامر الشراء والشحنات';
  @override
  String get usersMgmtRoleManagerPerm2 => 'اعتماد الميزانيات والقرارات والترسيات التشغيلية';
  @override
  String get usersMgmtRoleManagerPerm3 => 'عرض واستخراج كافة التقارير التحليلية والمالية';
  @override
  String get usersMgmtRoleManagerPerm4 => 'الاطلاع على البيانات المرجعية الأساسية';
  @override
  String get usersMgmtRoleManagerPerm5 => 'لا يملك صلاحية إدارة المستخدمين أو تعديل الهيكل';
  @override
  String get usersMgmtRoleOperatorDescTitle => 'أخصائي استيراد — صلاحيات تشغيلية';
  @override
  String get usersMgmtRoleOperatorPerm1 => 'إنشاء وتحديث ملفات الاستيراد والشحنات';
  @override
  String get usersMgmtRoleOperatorPerm2 => 'إدخال ومطابقة الفواتير وبيانات التعبئة ومسودات المستندات';
  @override
  String get usersMgmtRoleOperatorPerm3 => 'متابعة مراحل الكشف والتخليص الجمركي واستلام المخازن';
  @override
  String get usersMgmtRoleOperatorPerm4 => 'عرض التقارير التشغيلية المخصصة للمهام المسندة';
  @override
  String get usersMgmtRoleOperatorPerm5 => 'لا يملك صلاحية تعديل البيانات المرجعية أو الحسابات';

  // ── Users Management: Permissions Assignment Dialog (Phase 4 RBAC) ──────────
  @override
  String get usersMgmtPermDialogTitle => 'إدارة صلاحيات المستخدم';
  @override
  String get usersMgmtPermRoleLabel => 'الدور المُعيَّن:';
  @override
  String get usersMgmtPermNoRole => '— بدون دور مُعيَّن —';
  @override
  String usersMgmtPermRolePermCount(int count) => '$count صلاحية من الدور';
  @override
  String get usersMgmtPermLegendGranted => 'ممنوحة صراحةً';
  @override
  String get usersMgmtPermLegendRevoked => 'مسحوبة صراحةً';
  @override
  String get usersMgmtPermLegendInherited => 'موروثة من الدور';
  @override
  String usersMgmtPermOverrideSummary(int grants, int revocations) =>
      '$grants منح مباشر · $revocations سحب مباشر';
  @override
  String get usersMgmtPermSaveBtn => 'حفظ الصلاحيات';
  @override
  String get usersMgmtPermSavedSuccess => 'تم حفظ صلاحيات المستخدم بنجاح.';
  @override
  String get usersMgmtPermLoadError => 'فشل تحميل صلاحيات المستخدم. حاول مرة أخرى.';
  @override
  String get usersMgmtActionPermissionsTooltip => 'إدارة الصلاحيات';

  // ── Screen 66: Export Toolbar, Copy Feedback & Permissions Detail ───────────
  @override
  String get usersMgmtPermBadgeGrant => '+ منح';
  @override
  String get usersMgmtPermBadgeRevoke => '− سحب';
  @override
  String get usersMgmtPermBadgeRole => 'الدور الأساسي';
  @override
  String get usersMgmtPermTooltipGrant => 'منح هذه الصلاحية بشكل صريح ومباشر';
  @override
  String get usersMgmtPermTooltipRevoke => 'سحب هذه الصلاحية بشكل صريح ومباشر';
  @override
  String get usersMgmtPermTooltipRevertGrant => 'إلغاء المنح المباشر والرجوع لصلاحيات الدور الأساسي';
  @override
  String get usersMgmtPermTooltipRevertRevoke => 'إلغاء السحب المباشر والرجوع لصلاحيات الدور الأساسي';
  @override
  String get usersMgmtExportTsvBtn => 'تصدير جدول';
  @override
  String get usersMgmtExportExcelBtn => 'تصدير إكسيل';
  @override
  String get usersMgmtPrintPdfBtn => 'طباعة تقرير بي دي إف';
  @override
  String get usersMgmtCopyDossierBtn => 'نسخ الحافظة الشاملة';
  @override
  String get usersMgmtCopiedTsvSuccess => 'تم نسخ بيانات المستخدمين بترميز الجداول بنجاح';
  @override
  String get usersMgmtCopiedExcelSuccess => 'تم تصدير ملف إكسيل للمستخدمين بنجاح';
  @override
  String get usersMgmtCopiedDossierSuccess => 'تم نسخ الحافظة الشاملة للمستخدمين إلى الحافظة بنجاح';
  @override
  String get usersMgmtCopyRowSummaryBtn => 'نسخ ملخص السطر';
  @override
  String get usersMgmtCopyRowSummarySuccess => 'تم نسخ ملخص المستخدم بنجاح';
  @override
  String usersMgmtCopyBadgeSuccess(String label, String value) => 'تم نسخ $label: $value بنجاح';
  @override
  String get usersMgmtSearchCopied => 'تم نسخ عبارة البحث بنجاح';
  @override
  String usersMgmtCopyFieldTooltip(String field) => 'نسخ $field';
  @override
  String get usersMgmtPdfTitle => 'تقرير إدارة المستخدمين والصلاحيات والتحكم في الوصول';
  @override
  String get usersMgmtPdfSubtitle => 'سجل الحسابات المعتمدة والأدوار الوظيفية وسياسات الأمان بالنظام';
  @override
  String get usersMgmtDossierHeader => '=== حافظة إدارة المستخدمين والصلاحيات (منظومة سرور للخدمات اللوجستية) ===';
  @override
  String get usersMgmtDossierKpiSummary => '--- ملخص إحصائيات الحسابات والأدوار ---';
  @override
  String get usersMgmtDossierRecordsDetails => '--- بيان تفاصيل حسابات المستخدمين ---';
  @override
  String get usersMgmtDossierFooter => '=== نهاية تقرير المستخدمين المعتمد — نظام سرور الرقمي ===';

  // ── Screen: Smart Tasks & Reminder Engine ──────────────────────────────────
  @override
  String get smartTasksTitle => 'إدارة المهام الذكية ومحرك التذكيرات';
  @override
  String get smartTasksNewTaskBtn => 'إضافة مهمة جديدة';
  @override
  String get smartTasksFilterType => 'نوع المهمة';
  @override
  String get smartTasksTypeAll => 'كافة الأنواع';
  @override
  String get smartTasksTypeSystem => 'آلية';
  @override
  String get smartTasksTypeManual => 'يدوية';
  @override
  String get smartTasksFilterPriority => 'الأولوية';
  @override
  String get smartTasksPriorityAll => 'كافة الأولويات';
  @override
  String get smartTasksPriorityLow => 'منخفضة';
  @override
  String get smartTasksPriorityMedium => 'متوسطة';
  @override
  String get smartTasksPriorityHigh => 'عالية';
  @override
  String get smartTasksPriorityCritical => 'حرجة';
  @override
  String get smartTasksFilterStatus => 'الحالة';
  @override
  String get smartTasksStatusAll => 'كافة الحالات';
  @override
  String get smartTasksStatusPending => 'قيد الانتظار';
  @override
  String get smartTasksStatusInProgress => 'قيد التنفيذ';
  @override
  String get smartTasksStatusCompleted => 'مكتملة';
  @override
  String get smartTasksStatusCancelled => 'ملغاة';
  @override
  String get smartTasksResetFiltersTooltip => 'إعادة ضبط الفلاتر';
  @override
  String get smartTasksTableTitle => 'جدول المهام الذكية والتنبيهات التشغيلية';
  @override
  String get smartTasksColCode => 'كود المهمة';
  @override
  String get smartTasksColType => 'نوع المهمة';
  @override
  String get smartTasksColTitle => 'عنوان وتفاصيل المهمة';
  @override
  String get smartTasksColShipment => 'الشحنة المرتبطة';
  @override
  String get smartTasksColPriority => 'الأولوية';
  @override
  String get smartTasksColReminder => 'محرك التذكير';
  @override
  String get smartTasksColDueDate => 'تاريخ الاستحقاق';
  @override
  String get smartTasksColStatus => 'الحالة';
  @override
  String get smartTasksColActions => 'الإجراءات';
  @override
  String get smartTasksGeneralBadge => 'عام';
  @override
  String get smartTasksActionCompleteTooltip => 'إكمال المهمة';
  @override
  String get smartTasksActionEditTooltip => 'تعديل المهمة';
  @override
  String get smartTasksActionDeleteTooltip => 'حذف المهمة';
  @override
  String smartTasksBulkCompleteBtn(int count) => 'إكمال $count مهمة';
  @override
  String smartTasksBulkCompleteSuccess(int count) => 'تم إكمال $count مهمة بنجاح';
  @override
  String smartTasksFetchError(String err) => 'خطأ في جلب المهام: $err';
  @override
  String get smartTasksEmptyMessage => 'لا توجد مهام أو تذكيرات مطابقة للفلاتر الحالية';
  @override
  String get smartTaskDialogEditTitle => 'تعديل المهمة والتذكير';
  @override
  String get smartTaskDialogNewTitle => 'إضافة مهمة جديدة وتذكير';
  @override
  String get smartTaskFieldTitle => 'عنوان المهمة والتذكير *';
  @override
  String get smartTaskFieldTitleRequired => 'عنوان المهمة مطلوب';
  @override
  String get smartTaskFieldLinkShipment => 'ربط بملف الاستيراد أو الشحنة (اختياري)';
  @override
  String get smartTaskFieldPriority => 'مستوى الأولوية';
  @override
  String get smartTaskFieldReminderType => 'نوع محرك التذكير';
  @override
  String get smartTaskFieldDueDate => 'تاريخ الإنجاز المطلوب';
  @override
  String get smartTaskFieldReminderDate => 'تاريخ التنبيه والتذكير';
  @override
  String get smartTaskFieldDescription => 'وصف المهمة والمتطلبات';
  @override
  String get smartTaskFieldNotes => 'ملاحظات تشغيلية إضافية';
  @override
  String get smartTaskBtnCancel => 'إلغاء';
  @override
  String get smartTaskBtnUpdate => 'تحديث المهمة';
  @override
  String get smartTaskBtnSave => 'حفظ المهمة والتذكير';
  @override
  String get smartTaskSuccessUpdated => 'تم تحديث بيانات المهمة بنجاح';
  @override
  String get smartTaskSuccessCreated => 'تم حفظ وإضافة التذكير بنجاح';
  @override
  String smartTaskSubmitError(String err) => 'خطأ أثناء حفظ المهمة: $err';
  @override
  String smartTaskPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 'حرجة';
      case 'high':
        return 'عالية';
      case 'medium':
        return 'متوسطة';
      case 'low':
        return 'منخفضة';
      default:
        return priority;
    }
  }
  @override
  String smartTaskStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'in progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }
  @override
  String smartTaskReminderTypeLabel(String type) {
    switch (type) {
      case 'General Reminder':
        return 'تذكير عام';
      case 'Supplier Follow-up':
        return 'متابعة المورد';
      case 'Bank Form 4':
        return 'نموذج 4 البنكي';
      case 'Shipping Line':
        return 'الخط الملاحي';
      case 'Customs Broker':
        return 'المخلص الجمركي';
      case 'Document Review':
        return 'مراجعة المستندات';
      case 'ETA Arrival':
        return 'موعد وصول الشحنة';
      default:
        return type;
    }
  }
  @override
  String get smartTasksExportTsvBtn => 'نسخ جدول نصوص';
  @override
  String get smartTasksExportTsvSuccess => 'تم نسخ بيانات المهام الذكية إلى الحافظة بنجاح';
  @override
  String get smartTasksExportPdfBtn => 'طباعة تقرير المهام';
  @override
  String get smartTasksExportExcelBtn => 'تصدير إكسيل';
  @override
  String get smartTaskCopySummaryBtn => 'نسخ ملخص المهمة';
  @override
  String get smartTaskCopySummarySuccess => 'تم نسخ ملخص المهمة إلى الحافظة';
  @override
  String get smartTaskPrintPdfTooltip => 'طباعة بطاقة المهمة';
  @override
  String get smartTaskShareWhatsappTooltip => 'مشاركة عبر واتساب';
  @override
  String get smartTaskCodeBadgeLabel => 'كود المهمة: انقر للنسخ';
  @override
  String get smartTaskImportFileBadgeLabel => 'كود الشحنة: انقر للنسخ';
  @override
  String get smartTaskCopyFieldTooltip => 'نسخ الحقل إلى الحافظة';
  @override
  String get smartTasksTsvHeaderCode => 'كود المهمة';
  @override
  String get smartTasksTsvHeaderType => 'نوع المهمة';
  @override
  String get smartTasksTsvHeaderTitle => 'عنوان المهمة';
  @override
  String get smartTasksTsvHeaderShipment => 'الشحنة المرتبطة';
  @override
  String get smartTasksTsvHeaderPriority => 'الأولوية';
  @override
  String get smartTasksTsvHeaderReminder => 'محرك التذكير';
  @override
  String get smartTasksTsvHeaderDueDate => 'تاريخ الاستحقاق';
  @override
  String get smartTasksTsvHeaderStatus => 'الحالة';
  @override
  String get smartTasksTsvHeaderAssignedUser => 'المستخدم المسؤول';
  @override
  String get smartTasksTsvHeaderDescription => 'الوصف والمتطلبات';

  // ── Screen 42: Operational & Daily Shipment Updates Engine ─────────────────
  @override
  String get shipmentUpdateEngineTitle => 'محرك تحديث الشحنات التشغيلي واليومي';
  @override
  String get shipmentUpdateRefreshTooltip => 'تحديث البيانات';
  @override
  String shipmentUpdateErrorLoadingShipments(String err) => 'خطأ في تحميل الشحنات: $err';
  @override
  String get shipmentUpdateNoShipmentsRegistered => 'لا توجد شحنات مسجلة بالنظام حتى الآن.';
  @override
  String get shipmentUpdateSelectShipmentPrompt => 'اختر الشحنة لتشغيل محرك التحديث والفحص المرحلي';
  @override
  String shipmentUpdateDropdownLabel(String fileCode, String supplier, String stage) =>
      '$fileCode | المورد: $supplier | المرحلة الحالية: $stage';
  @override
  String get shipmentUpdateComprehensiveDailyCheckinBtn => 'تحديث يومي شامل عن الشحنة';
  @override
  String shipmentUpdatePipelineTitle(String fileCode) =>
      'المخطط التفاعلي لمراحل الشحنة ($fileCode) — اضغط على أي مرحلة للتحديث:';
  @override
  String shipmentUpdateCurrentStage(String stage) => 'المرحلة الحالية: $stage';
  @override
  String get shipmentUpdatePhase1Name => 'المرحلة الأولى: التخطيط والجدوى';
  @override
  String get shipmentUpdatePhase2Name => 'المرحلة الثانية: الاعتماد المالي';
  @override
  String get shipmentUpdatePhase3Name => 'المرحلة الثالثة: المستندات والقيد المسبق';
  @override
  String get shipmentUpdatePhase4Name => 'المرحلة الرابعة: حجز الشحن والناقل';
  @override
  String get shipmentUpdatePhase5Name => 'المرحلة الخامسة: الشحن والتتبع الإلكتروني';
  @override
  String get shipmentUpdatePhase6Name => 'المرحلة السادسة: إقرار 46 والتعريفة';
  @override
  String get shipmentUpdatePhase7Name => 'المرحلة السابعة: التخليص وسداد الرسوم';
  @override
  String get shipmentUpdatePhase8Name => 'المرحلة الثامنة: استلام المخازن وإذن الإضافة';
  @override
  String get shipmentUpdatePhase9Name => 'المرحلة التاسعة: تسوية تكلفة الوصول';
  @override
  String get shipmentUpdatePhase10Name => 'المرحلة العاشرة: إغلاق الملف والأرشفة';
  @override
  String get shipmentUpdateStatusCompleted => 'مكتملة';
  @override
  String get shipmentUpdateStatusCurrent => 'جارية';
  @override
  String get shipmentUpdateStatusFuture => 'مستقبلية';
  @override
  String shipmentUpdateCountBadge(int count) => 'التحديثات: $count سجلات';
  @override
  String get shipmentUpdateCustomsSecTitle => 'سجل ونتائج دراسة الاستشارة الجمركية والفحص المستندي';
  @override
  String shipmentUpdateCustomsStudiesCount(int count) => '$count دراسة مسجلة ومحفوظة';
  @override
  String get shipmentUpdateCustomsNoStudies => 'لا توجد دراسة مسجلة';
  @override
  String get shipmentUpdateCustomsEmptyPrompt =>
      'لم يتم حفظ دراسة استشارة جمركية بعد لملف هذه الشحنة. يمكنك فتح "مركز الاستشارة الجمركية" لإنشاء ومزامنة بنود التعريفة وقائمة المستندات.';
  @override
  String shipmentUpdateBrokerPrefix(String broker) => 'المستخلص: $broker';
  @override
  String get shipmentUpdateMetricEstDuties => '💰 الرسوم التقديرية';
  @override
  String get shipmentUpdateMetricApprovedDocs => '📄 المستندات المعتمدة';
  @override
  String shipmentUpdateMetricDocsRatio(int approved, int total) => '$approved من $total مستند';
  @override
  String get shipmentUpdateMetricBlockingIssues => '🚫 عوائق التخليص المعطلة';
  @override
  String shipmentUpdateMetricBlockingCount(int count) => '$count عائق معطل';
  @override
  String get shipmentUpdateMetricZeroBlocking => '0 عوائق (جاهز)';
  @override
  String get shipmentUpdateMetricReadinessRate => 'نسبة الجاهزية:';
  @override
  String get shipmentUpdateBtnPrintPdf => 'طباعة التقرير (بي دي إف)';
  @override
  String get shipmentUpdateBtnViewChecklist => 'استعراض قائمة الفحص';
  @override
  String get shipmentUpdateBtnEditDocs => 'تعديل ومراجعة المستندات';
  @override
  String get shipmentUpdateBtnRecordDailyUpdate => 'تسجيل تحديث يومي';
  @override
  String shipmentUpdateConsultDialogEditTitle(String code) => '✏️ تعديل ومراجعة دراسة الاستشارة: $code';
  @override
  String shipmentUpdateConsultDialogViewTitle(String code) => 'تفاصيل دراسة الاستشارة الجمركية: $code';
  @override
  String get shipmentUpdateConsultPrintTooltip => 'طباعة تقرير الاستشارة الجمركية (بي دي إف)';
  @override
  String get shipmentUpdateConsultSwitchViewTooltip => 'التبديل إلى وضع العرض';
  @override
  String get shipmentUpdateConsultSwitchEditTooltip => 'التبديل إلى وضع التعديل';
  @override
  String shipmentUpdateConsultBrokerPrefix(String broker) => 'المستخلص: $broker';
  @override
  String shipmentUpdateConsultEstDuties(String amount) => 'الرسوم التقديرية: $amount جنيه';
  @override
  String get shipmentUpdateConsultOverallStatusLabel => 'الحالة العامة: ';
  @override
  String shipmentUpdateConsultStatus(String status) => 'الحالة: $status';
  @override
  String get shipmentUpdateConsultReadinessRateLabel => 'نسبة الجاهزية';
  @override
  String get shipmentUpdateConsultTotalDocsLabel => 'إجمالي المستندات';
  @override
  String get shipmentUpdateConsultApprovedLabel => 'المعتمد';
  @override
  String get shipmentUpdateConsultBlockingLabel => 'عوائق التخليص';
  @override
  String get shipmentUpdateConsultChecklistSectionTitle => 'قائمة فحص المستندات والاشتراطات الجمركية المربوطة بالشحنة:';
  @override
  String get shipmentUpdateConsultEditModeBanner => '⚡ وضع التعديل التفاعلي مفعل — اضغط لتحديث حالة أي مستند';
  @override
  String get shipmentUpdateConsultColDocType => 'نوع المستند والبنود';
  @override
  String get shipmentUpdateConsultColResponsibleParty => 'الجهة المسؤولة';
  @override
  String get shipmentUpdateConsultColStatus => 'الحالة';
  @override
  String get shipmentUpdateConsultColRemarks => 'ملاحظات والاشتراطات';
  @override
  String get shipmentUpdateConsultBlockingTooltip => 'عائق معطل للشحن/التخليص الجمركي';
  @override
  String shipmentUpdateConsultHsCodesPrefix(String hs) => 'بنود: $hs';
  @override
  String get shipmentUpdateConsultSaveBtn => '💾 حفظ التعديلات';
  @override
  String get shipmentUpdateConsultSavingBtn => 'جاري الحفظ...';
  @override
  String get shipmentUpdateConsultCloseBtn => 'إغلاق';
  @override
  String shipmentUpdateConsultSaveSuccess(String code) => '✅ تم حفظ وتحديث دراسة الاستشارة الجمركية $code بنجاح!';
  @override
  String shipmentUpdateConsultSaveError(String err) => 'خطأ في حفظ التعديلات: $err';
  @override
  String shipmentUpdateLogsFetchError(String err) => 'خطأ في جلب سجل التحديثات: $err';
  @override
  String get shipmentUpdateLogsEmptyMessage => 'لا توجد تحديثات تشغيلية مسجلة لهذه الشحنة حتى الآن.';
  @override
  String get shipmentUpdateColActions => '⚡ العمليات';
  @override
  String get shipmentUpdateColCode => 'كود التحديث';
  @override
  String get shipmentUpdateColDate => 'التاريخ';
  @override
  String get shipmentUpdateColType => 'نوع التحديث';
  @override
  String get shipmentUpdateColTargetStage => 'المرحلة المستهدفة';
  @override
  String get shipmentUpdateColNotes => 'ملاحظة وتفاصيل التحديث التشغيلي واليومي';
  @override
  String get shipmentUpdateColCostAdjustment => 'تعديل التكلفة';
  @override
  String get shipmentUpdateColAssignedUser => 'المسؤول';
  @override
  String get shipmentUpdateBadgeDaily => 'تحديث يومي';
  @override
  String get shipmentUpdateBadgeCostAdj => 'تعديل تكلفة';
  @override
  String get shipmentUpdateBadgeFollowUp => 'متابعة مرحلية';
  @override
  String get shipmentUpdateBadgeFutureAlert => 'تنبيه مرحلي';
  @override
  String get shipmentUpdateActionViewTooltip => 'عرض تفاصيل التحديث';
  @override
  String get shipmentUpdateActionEditTooltip => 'تعديل التحديث';
  @override
  String get shipmentUpdateActionPrintTooltip => 'طباعة سجل التحديث';
  @override
  String get shipmentUpdateActionDeleteTooltip => 'حذف سجل التحديث';
  @override
  String shipmentUpdateViewDialogTitle(String code) => 'تفاصيل التحديث: $code';
  @override
  String shipmentUpdateViewStage(String stage) => 'المرحلة: $stage';
  @override
  String shipmentUpdateViewDate(String date) => 'التاريخ: $date';
  @override
  String shipmentUpdateViewUser(String user) => 'المسؤول: $user';
  @override
  String get shipmentUpdateViewNotes => 'الملاحظات:';
  @override
  String get shipmentUpdateViewCloseBtn => 'إغلاق';
  @override
  String shipmentUpdatePrintSnackBar(String code, String stage) => 'طباعة سجل التحديث التشغيلي: $code ($stage)';
  @override
  String get shipmentUpdateDeleteConfirmTitle => 'تأكيد الحذف';
  @override
  String shipmentUpdateDeleteConfirmMsg(String code) => 'هل أنت متأكد من حذف سجل التحديث $code؟';
  @override
  String get shipmentUpdateDeleteCancelBtn => 'إلغاء';
  @override
  String get shipmentUpdateDeleteConfirmBtn => 'تأكيد الحذف';
  @override
  String get shipmentUpdateDialogTitle => 'محرك تحديث الشحنات التشغيلي واليومي';
  @override
  String get shipmentUpdateFieldShipmentLabel => 'اختر الشحنة المراد تحديثها *';
  @override
  String get shipmentUpdateFieldShipmentRequired => 'يرجى اختيار الشحنة المراد تسجيل التحديث عليها';
  @override
  String get shipmentUpdateFieldCategoryLabel => 'نوع التحديث *';
  @override
  String get shipmentUpdateCatOptFollowUp => '1. متابعة وملاحظات مرحلية';
  @override
  String get shipmentUpdateCatOptCostAdjustment => '2. تعديل بيانات / تكلفة مرحلة';
  @override
  String get shipmentUpdateCatOptFutureAlert => '3. فتح/تنبيه لمرحلة قادمة';
  @override
  String get shipmentUpdateCatOptDailyCheckin => '4. تحديث يومي عن الشحنة';
  @override
  String get shipmentUpdateFieldTargetStageLabel => 'المرحلة المستهدفة *';
  @override
  String get shipmentUpdateFieldCostItemLabel => 'بند التكلفة / البيان المعدل';
  @override
  String get shipmentUpdateFieldPrevCostLabel => 'التكلفة السابقة';
  @override
  String get shipmentUpdateFieldNewCostLabel => 'التكلفة الجديدة';
  @override
  String get shipmentUpdateFieldAlertPriorityLabel => 'مستوى أولوية التنبيه *';
  @override
  String get shipmentUpdatePriorityLow => 'منخفض';
  @override
  String get shipmentUpdatePriorityNormal => 'عادي';
  @override
  String get shipmentUpdatePriorityHigh => 'عالي';
  @override
  String get shipmentUpdatePriorityCritical => 'حرج';
  @override
  String get shipmentUpdateFieldDateLabel => 'تاريخ التحديث *';
  @override
  String get shipmentUpdateFieldNotesLabel => 'ملاحظة وتفاصيل التحديث *';
  @override
  String get shipmentUpdateFieldNotesHint => 'اكتب تفاصيل التحديث اليومي أو الملاحظة التشغيلية...';
  @override
  String get shipmentUpdateFieldNotesRequired => 'يرجى كتابة ملاحظة أو تفاصيل التحديث';
  @override
  String get shipmentUpdateBtnCancel => 'إلغاء';
  @override
  String get shipmentUpdateBtnSaveUpdate => 'حفظ وتسجيل التحديث';
  @override
  String get shipmentUpdateSuccessSaved => 'تم تسجيل التحديث التشغيلي والمتابعة اليومية بنجاح';
  @override
  String shipmentUpdateErrorSaving(String err) => 'خطأ أثناء حفظ التحديث: $err';
  @override
  String get shipmentUpdatesExportTsvBtn => 'تصدير جدول نصوص';
  @override
  String get shipmentUpdatesExportTsvSuccess => 'تم نسخ سجلات التحديثات بصيغة جدول نصوص إلى الحافظة بنجاح';
  @override
  String get shipmentUpdatesExportExcelBtn => 'تصدير إكسيل';
  @override
  String get shipmentUpdatesExportPdfBtn => 'طباعة بي دي إف';
  @override
  String get shipmentUpdateCopySummaryBtn => 'نسخ ملخص التحديث';
  @override
  String get shipmentUpdateCopySummarySuccess => 'تم نسخ ملخص التحديث التشغيلي إلى الحافظة بنجاح';
  @override
  String get shipmentUpdateCodeBadgeLabel => 'تم نسخ كود التحديث إلى الحافظة';
  @override
  String get shipmentUpdateConsultCodeBadgeLabel => 'تم نسخ كود الاستشارة الجمركية إلى الحافظة';
  @override
  String get shipmentUpdateCopyFieldTooltip => 'نسخ القيمة إلى الحافظة';
  @override
  String get shipmentUpdatesTsvHeaderCode => 'كود التحديث';
  @override
  String get shipmentUpdatesTsvHeaderDate => 'التاريخ';
  @override
  String get shipmentUpdatesTsvHeaderCategory => 'نوع التحديث';
  @override
  String get shipmentUpdatesTsvHeaderPhase => 'المرحلة المستهدفة';
  @override
  String get shipmentUpdatesTsvHeaderNotes => 'ملاحظات وتفاصيل التحديث';
  @override
  String get shipmentUpdatesTsvHeaderCostItem => 'بند التكلفة المعدل';
  @override
  String get shipmentUpdatesTsvHeaderPrevCost => 'التكلفة السابقة';
  @override
  String get shipmentUpdatesTsvHeaderNewCost => 'التكلفة الجديدة';
  @override
  String get shipmentUpdatesTsvHeaderPriority => 'مستوى الأولوية';
  @override
  String get shipmentUpdatesTsvHeaderAssignedUser => 'المستخدم المسؤول';
  @override
  String get shipmentUpdatesTsvHeaderStatus => 'حالة المرحلة';
  @override
  String get shipmentUpdateConsultStatusInProgress => 'قيد التنفيذ';
  @override
  String get shipmentUpdateConsultStatusClearanceReady => 'جاهز للتخليص';
  @override
  String get shipmentUpdateConsultStatusBlocked => 'معلق لوجود مانع';
  @override
  String get shipmentUpdateConsultStatusActionRequired => 'يتطلب إجراء';
  @override
  String get shipmentUpdateConsultStatusCompleted => 'مكتمل';
  @override
  String get shipmentUpdateDocStatusApproved => 'معتمد';
  @override
  String get shipmentUpdateDocStatusPending => 'قيد الانتظار';
  @override
  String get shipmentUpdateDocStatusReceived => 'مستلم';
  @override
  String get shipmentUpdateDocStatusVerified => 'تم التحقق';
  @override
  String get shipmentUpdateDocStatusRejected => 'مرفوض';
  @override
  String get shipmentUpdateCostLabel => 'التكلفة';
  @override
  String get shipmentUpdateCostCurrencyUsd => 'دولار';

  // Error Details Dialog & Diagnostic Formatter
  @override
  String get errorDefaultSummary => 'حدث خطأ أثناء معالجة الطلب';
  @override
  String get errorDialogDefaultSubtitle => 'يرجى مراجعة الأخطاء وتصحيحها لتتمكن من استكمال العملية بنجاح:';
  @override
  String get errorServerResponseField => 'استجابة الخادم';
  @override
  String get errorServerResponseRecommendation => 'يرجى مراجعة وتصحيح البيانات وفقاً لإرشادات الخادم.';
  @override
  String get errorValidationSummary => 'يوجد أخطاء في التحقق من صحة البيانات المدخلة:';
  @override
  String get errorUnspecifiedField => 'حقل غير محدد';
  @override
  String get errorInvalidValue => 'قيمة غير صالحة';
  @override
  String get errorStandardRecommendation => 'يرجى إدخال قيمة صحيحة ومطابقة للشروط.';
  @override
  String get errorFieldRequiredMsg => 'هذا الحقل إلزامي ولا يمكن تركه فارغاً.';
  @override
  String get errorFieldRequiredRec => 'قم بتعبئة هذا الحقل قبل حفظ البيانات.';
  @override
  String get errorValidDateMsg => 'صيغة التاريخ غير صالحة.';
  @override
  String get errorValidDateRec => 'تأكد من صيغة التاريخ بالتنسيق: YYYY-MM-DD.';
  @override
  String get errorMinLengthMsg => 'القيمة المدخلة قصيرة جداً.';
  @override
  String get errorMinLengthRec => 'أدخل نصاً واضحاً ومكتملاً.';
  @override
  String get errorConnectionSummary => 'تعذر الاتصال بالخادم الخلفي';
  @override
  String get errorConnectionPointUnavailable => 'خادم النظام الخلفي غير متاح حالياً أو متوقف.';
  @override
  String errorConnectionPointTarget(String targetUri) => 'العنوان المستهدف: $targetUri';
  @override
  String get errorConnectionPointCors => 'إذا كنت تعمل عبر المتصفح، تأكد من تشغيل السيرفر وعدم حظر طلبات الشبكة.';
  @override
  String get errorConnectionFieldName => 'اتصال الخادم';
  @override
  String errorConnectionIssueDesc(String targetUri, String errorDetail) => 'تعذر الوصول إلى $targetUri ($errorDetail)';
  @override
  String get errorConnectionRecommendation => 'تأكد من تشغيل خادم النظام وعمل تحديث للصفحة.';
  @override
  String get errorTimeoutSummary => 'انتهت مهلة استجابة الخادم.';
  @override
  String get errorTimeoutPoint => 'استغرق الخادم وقتاً أطول من المعتاد، يرجى إعادة المحاولة.';
  @override
  String get errorTimeoutFieldName => 'مهلة الاتصال';
  @override
  String get errorTimeoutIssueDesc => 'انتهت المهلة المحددة للطلب دون تلقي رد من الخادم.';
  @override
  String get errorTimeoutRecommendation => 'تحقق من سرعة الاتصال بالشبكة وأعد المحاولة.';
  @override
  String get errorConnectionBannerHint => '💡 الخادم الخلفي غير متاح حالياً. يرجى التأكد من تشغيل السيرفر المحلي وإعادة المحاولة.';
  @override
  String errorTableSectionTitle(int count) => '📋 جدول الأخطاء وعوائق الاستكمال المطلوب تصحيحها ($count):';
  @override
  String get errorColFieldCondition => 'الحقل أو الشرط';
  @override
  String get errorColDescription => 'وصف الخطأ';
  @override
  String get errorColAction => 'الإجراء المقترح للتصحيح';
  @override
  String get errorBtnHideTechnicalLog => 'إخفاء السجل التقني المفصل';
  @override
  String get errorBtnShowTechnicalLog => 'عرض السجل التقني المفصل للمطورين';
  @override
  String get errorBtnCopyReport => 'نسخ تقرير الفحص';
  @override
  String get errorReportHeader => '=== تقرير فحص ومعالجة أخطاء Sorour Logistics ERP ===';
  @override
  String get errorReportDateTime => 'التاريخ والوقت:';
  @override
  String get errorReportTitle => 'العنوان:';
  @override
  String get errorReportSummary => 'الملخص:';
  @override
  String get errorReportType => 'نوع الخطأ:';
  @override
  String get errorReportTypeConnection => 'خطأ في الاتصال بالخادم';
  @override
  String get errorReportTypeValidation => 'خطأ في التحقق من البيانات أو استجابة الخادم';
  @override
  String errorReportIssues(int count) => 'الأخطاء والنواقص ($count):';
  @override
  String get errorReportRawLog => 'السجل التقني الكامل:';
  @override
  String get errorReportCopiedSnackBar => '📋 تم نسخ تقرير الفحص التشخيصي إلى الحافظة!';
  @override
  String get errorBtnRetrying => 'جارٍ إعادة المحاولة...';
  @override
  String get errorBtnRetryNow => 'إعادة المحاولة الآن';
  @override
  String errorRetryFailedSnackBar(String err) => '❌ فشلت إعادة المحاولة: $err';
  @override
  String get errorBtnFixAndClose => 'فهمت، سأقوم بمعالجة الأخطاء';
  @override
  String errorFieldName(String key) {
    switch (key) {
      case 'importer_name':
        return 'اسم الشركة المستوردة';
      case 'importer_tax_id':
        return 'الرقم الضريبي للمستورد';
      case 'importer_address':
        return 'عنوان المستورد';
      case 'exporter_name':
        return 'اسم المورد أو المصدر';
      case 'exporter_reg_type':
        return 'نوع تسجيل المصدر';
      case 'exporter_reg_id':
        return 'المعرف الضريبي أو السجل للمصدر';
      case 'exporter_country':
        return 'دولة المورد';
      case 'exporter_country_code':
        return 'رمز الدولة';
      case 'exporter_address':
        return 'عنوان المصدر بالخارج';
      case 'exporter_phone':
        return 'هاتف المصدر';
      case 'cargox_id':
        return 'معرف كارجو إكس للمصدر';
      case 'proforma_invoice_no':
        return 'رقم الفاتورة المبدئية';
      case 'proforma_invoice_date':
        return 'تاريخ الفاتورة المبدئية';
      case 'invoice_date':
        return 'تاريخ الفاتورة';
      case 'invoice_type':
        return 'نوع الفاتورة';
      case 'po_number':
        return 'رقم أمر الشراء';
      case 'po_date':
        return 'تاريخ أمر الشراء';
      case 'pol_name':
        return 'ميناء الشحن';
      case 'pod_name':
        return 'ميناء الوصول';
      case 'customs_broker_name':
        return 'اسم المخلص الجمركي';
      case 'customs_broker_id':
        return 'المخلص الجمركي المعني';
      case 'customs_broker_phone':
        return 'هاتف المخلص الجمركي';
      case 'requested_date':
        return 'تاريخ الطلب';
      case 'acid_number':
        return 'رقم القيد الجمركي المبدئي نافذة';
      case 'generated_date':
        return 'تاريخ إصدار الرقم الجمركي';
      case 'expiry_date':
        return 'تاريخ انتهاء الصلاحية';
      case 'items':
        return 'بنود وعروض الشحن';
      case 'cargo_ready_date':
        return 'تاريخ جاهزية البضاعة';
      case 'title':
        return 'موضوع أو عنوان الاستشارة';
      case 'consultation_title':
        return 'عنوان الاستشارة الجمركية';
      case 'amount':
        return 'المبلغ أو القيمة المالية';
      case 'currency':
        return 'العملة';
      default:
        return key;
    }
  }

  // Regulatory Requirements - Per-HS-Code & Adaptive Banners
  @override String get decree43WarningNotRegistered => 'تنبيه قرار ٤٣: المصنع الأجنبي غير مقيد بالقائمة البيضاء (GOEIC)';
  @override String get decree43WarningNotRegisteredDesc => 'الصنف يخضع للقرار ٤٣ لسنة ٢٠١٦. شحن البضاعة بدون قيد قد يعرضها لعدم الإفراج أو إعادة التصدير فور الوصول.';
  @override String get decree43OptionRequestJustification => 'طلب سبب الاعتماد / الاستثناء';
  @override String get decree43OptionCreateDashboardTask => 'تثبيت الملحوظة وإنشاء مهمة بالداش بورد';
  @override String get decree43JustificationDialogTitle => 'تسجيل سبب الاعتماد والاستثناء (قرار ٤٣)';
  @override String get decree43JustificationDialogDesc => 'يرجى تحديد أو إدخال السند القانوني لاعتماد استيراد هذا البند دون قيد المصنع بالقائمة البيضاء:';
  @override String get decree43JustificationReasonProductionInput => 'مستلزم إنتاج لمصنع مرخص بموجب سجل صناعي (معفى من القرار ٤٣)';
  @override String get decree43JustificationReasonPrivateUse => 'استيراد بغرض الاستخدام الخاص للمنشأة ولا يطرح للتداول التجاري';
  @override String get decree43JustificationReasonSpareParts => 'قطع غيار ومكونات صيانة لخط إنتاج قائم';
  @override String get decree43JustificationReasonMinisterialExemption => 'موافقة استثنائية معتمدة من وزير التجارة والصناعة';
  @override String get decree43JustificationReasonCustom => 'مبرر استثناء قانوني آخر (مخصص)...';
  @override String get decree43JustificationSavedBadge => 'معتمد بمبرر استثناء';
  @override String get decree43TaskCreatedBadge => 'تم إنشاء مهمة بالداش بورد [أولوية حرجة]';
  @override String get decree43TaskCreatedSuccessSnack => 'تم إنشاء مهمة عاجلة بنجاح لمتابعة قيد المصنع بلوحة التحكم التشغيلية';
  @override String get adaptivePillarMandatoryRequirements => 'الاشتراطات الإلزامية:';
  @override String get adaptivePillarComplianceAlert => 'التنبيهات وحالة الامتثال:';
  @override String get adaptivePillarLegalExemptions => 'الإعفاءات والاستثناءات النظامية:';
  @override String get hsCodeSequenceNavTitle => 'التسلسل الرقابي لبنود التعريفة بالشحنة (HS Codes Compliance Sequence)';
  @override String get hsCodeFulfillmentStatus => 'نسبة استيفاء البند:';
  @override String get hsCodeFullyCompliantChip => 'مكتمل ٥/٥';
  @override String get hsCodePendingPillarsChip => 'قيد الاستيفاء';

  // ── Freight Booking Cost Savings & Comparison ──────────────────────────────
  @override String get freightBookingOriginalQuotedPrice => 'السعر المعروض قبل التعديل';
  @override String get freightBookingExecutedPrice => 'السعر المنفذ بالبوكينج';
  @override String get freightBookingCostSavingsTitle => 'وفورات حجز الشحن المحققة';
  @override String get freightBookingCostIncreaseTitle => 'زيادة في تكلفة الشحن';
  @override String get freightBookingCostSavingsBadge => 'توفير في المصروفات';
  @override String get freightBookingCostIncreaseBadge => 'زيادة في التكلفة';
  @override String get freightBookingPriceDiffLabel => 'فرق السعر للوحدة';
  @override String freightBookingSavingsFormulaDetails(String diff, String qty, String unit, String total) =>
      'حاصل ضرب الفرق ($diff) × $qty $unit = $total';
  @override String get freightBookingNoPriceVariance => 'السعر مطابق تماماً لعرض الأسعار';

  // ── Universal Copy & Clipboard Helpers ─────────────────────────────────────
  @override String get copyValue => 'نسخ القيمة';
  @override String get copyRow => 'نسخ بيانات السطر';
  @override String get copyTable => 'نسخ الجدول بالكامل';
  @override String get copiedToClipboardGeneric => 'تم النسخ إلى الحافظة بنجاح';
  @override String get copyTooltip => 'انقر للنسخ إلى الحافظة';

  // ── Screen 0: Operational Dashboard Enhancements ───────────────────────────
  @override String get badgeNew => 'جديد';
  @override String pendingRegRequirementsCount(int count) => '$count متطلب رقابي معلق';

  // ── Freight Studies — Extended Keys (Arabic) ────────────────────────────────
  // AI Extractor
  @override String get freightExtractorTitle => 'استخراج وقراءة عروض أسعار الشحن والنولون (Freight Quotation AI) ⚡';
  @override String get collapseExtractor => 'طي الأداة';
  @override String get expandExtractor => 'توسيع الأداة';
  @override String get pasteQuoteText => 'لصق نص العرض';
  @override String get clearField => 'تفريغ';
  @override String get sampleQuoteBtn => 'نموذج تجريبي';
  @override String get uploadQuoteDocument => 'رفع مستند عرض السعر 📄';
  @override String get extractQuotesBtn => 'استخراج وتحليل عروض السعر ⚡';
  // Extracted results
  @override String extractedQuotesBanner(int count) => 'تم استخراج $count عرض/عروض أسعار بنجاح! راجع العروض أدناه ثم أضفها لدراسة المفاضلة:';
  @override String addAllQuotes(int count) => '🚀 إضافة كافة العروض ($count)';
  @override String get attachedFileChip => 'الملف:';
  @override String get originPortChip => 'ميناء الشحن:';
  @override String get destinationPortChip => 'ميناء الوصول:';
  @override String get localExpensesChip => 'المصاريف المحلية:';
  @override String get directRoute => 'مباشر';
  @override String get transitRoute => 'ترانزيت';
  @override String get totalLabel => 'الإجمالي:';
  @override String get transitDaysLabel => 'ترانزيت';
  @override String get freeTimeDaysLabel => 'سماح';
  @override String get addThisQuoteBtn => '+ إضافة هذا العرض للسيناريو';
  // Snackbars
  @override String sessionLoadedMsg(String code) => '📂 تم استدعاء وتحميل كافة بيانات الجلسة ($code) للتعديل وإعادة التفعيل!';
  @override String freightQuotesAddedMsg(int count) => '✨ تمت إضافة $count عرض/عروض أسعار بنجاح لدراسة ومقارنة الشحن!';
  @override String get noValidQuotesError => 'لم يتم العثور على أية عروض أسعار صالحة في النص/المستند المدخل.';
  @override String extractedAndAddedMsg(int count) => '🚀 تم استخراج وإضافة $count عروض أسعار للمفاضلة في السيناريو بنجاح!';
  @override String get cancelEditModeMsg => '🔄 تم إلغاء وضع التعديل وتصفير الحقول لبدء دراسة جديدة.';
  // Metric cards
  @override String avgDaysFromReadiness(int days) => 'خلال $days يوم من الجاهزية';
  // Container count chip
  @override String totalContainersCount(int total, int ft40, int ft20) =>
      'إجمالي عدد الحاويات المطبقة = $total (40ft: $ft40 | 20ft: $ft20)';
  // Comparison table
  @override String get excludedFromAvg => 'مستبعد 🚫';
  @override String get includedInAvg => 'محتسب ✅';
  // Filter strip
  @override String polToPodLeadTimeStrip(String pol, String pod, int lead, int wh) =>
      '📍 POL: $pol ➔ POD: $pod | Lead Time: ${lead}d | WH Days: ${wh}d';
  // Search hints
  @override String get forwarderSearchHint => 'ابحث عن شركة / وكيل الشحن...';
  @override String get shippingLineSearchHint => 'ابحث عن الخط الملاحي...';
  @override String get addNewLineTooltip => 'تكويد خط ملاحي جديد بالذكاء الاصطناعي';
  // Clearance fee summary label
  @override String get clearanceFeeSummaryLabel => 'تخليص:';
  // Validation snackbars
  @override String get completeRequiredDataMsg => '⚠️ يرجى التأكد من استكمال كافة البيانات الإلزامية مثل عنوان الدراسة!';
  @override String shippingLineRequiredMsg(int index) => '⚠️ خيار الشحن #$index: يرجى اختيار الخط الملاحي (Shipping Line)!';
  @override String datesRequiredMsg(int index, String provider) => '⚠️ خيار الشحن #$index ($provider): يرجى تحديد التواريخ بشكل صحيح!';
  @override String sailingBeforeCrdError(int index, String provider, String sailing, String crd) =>
      '⚠️ خيار الشحن #$index ($provider): تاريخ الإبحار ($sailing) لا يمكن أن يكون قبل تاريخ جاهزية البضاعة (CRD: $crd)!';
  @override String etaAfterSailingError(int index, String provider, String eta, String sailing) =>
      '⚠️ خيار الشحن #$index ($provider): تاريخ الوصول (ETA: $eta) يجب أن يكون بعد تاريخ الإبحار ($sailing)!';
  @override String negativeDaysError(int index, String provider) =>
      '⚠️ خيار الشحن #$index ($provider): أيام التأخير المتوقعة لا يمكن أن تكون سالبة!';
  @override String duplicateQuoteError(int index, String provider) =>
      '⚠️ خيار الشحن #$index ($provider): مكرر! يوجد خيار آخر بنفس شركة وكيل الشحن والخط الملاحي والرحلة وتاريخ الإبحار.';
  @override String get saveFailed => 'فشلت عملية حفظ الدراسة والنتائج';
  @override String get saveFailedTitle => '❌ تعذر حفظ دراسة وتقييم خيارات الشحن';
  // Save success dialog
  @override String get saveSuccessReportTitle => '🏆 تقرير نتائج دراسة الشحن والعروض المحفوظة';
  @override String get studyCodeLabel => 'رمز دراسة الشحن:';
  @override String get studyTitleDetailLabel => 'عنوان الدراسة:';
  @override String get crdAndPickupLabel => 'تاريخ جاهزية الشحنة | مكان الاستلام:';
  @override String get comparativeReportLabel => '📊 التقرير المقارن للخطوط والرحلات المقيمة:';
  @override String get carrierLineCol => 'الناقل / الخط الملاحي';
  @override String get portArrivalCol => 'الوصول للميناء';
  @override String get totalDaysCol => 'إجمالي الأيام';
  @override String get whDateCol => 'موعد المخزن المتوقع';
  @override String get totalQuoteCol => 'إجمالي قيمة العرض';
  @override String recommendedBadge(String provider) => '🟢 موصى به';
  @override String get excludedBadge => '🚫 مستبعد';
  @override String get normalBadge => 'عادي';
  @override String get recommendedLineContractLabel => 'الخط الملاحي الموصى به رسميًا للربط والتعاقد:';
  @override String get copySummaryBtn => 'نسخ ملخص النتائج';
  @override String get saveDoneBtn => 'موافق (تم الحفظ)';
  @override String get summaryNotCopied => '📋 تم نسخ ملخص النتائج للحافظة!';
  // Container comparison dialog
  @override String get containerDualMatrixTitle => '🚚 مقارنة حالة الرص القابل وغير القابل للرص';
  @override String totalCbmAndWeight(String cbm, String weight) =>
      'إجمالي CBM الشحنة: $cbm m³ | إجمالي الوزن: $weight kg';
  @override String get containerTypeCol => 'نوع الحاوية الموصى بها';
  @override String get containersRequiredCol => 'عدد الحاويات المطلوبة';
  @override String get spaceUtilizationLabel => 'نسبة استغلال حجم الحاوية';
  // Visual load plan dialog
  @override String get visualLoadPlanTitle => 'مخطط ومحاكاة رص الحاويات التفاعلي';
  @override String requiredFleetLabel(String fleet, int count) => 'الأسطول المطلوب: $fleet ($count حاوية)';
  @override String get selectStackingScenarioLabel => '🔄 اختر سيناريو الرص للمعاينة:';
  @override String get totalPackagesMetricLabel => '📦 إجمالي الطرود';
  @override String get totalWeightMetricLabel => '⚖️ إجمالي الوزن';
  @override String get totalVolumeMetricLabel => '📐 إجمالي الحجم';
  @override String get stackableMetricLabel => '✅ يقبل الرص';
  @override String get nonStackableMetricLabel => '🚫 لا يقبل الرص';
  @override String get containerCol => 'الحاوية';
  @override String get itemsAndPackagesCol => 'الأصناف والطرود';
  @override String get loadedWeightCol => 'الوزن المحمّل';
  @override String get safetyDistributionCol => 'توزيع الرص والسلامة';
  @override String loadingFailedStatus(String ids) => 'فشل التحميل (طرود كبيرة الحجم/الوزن)';
  @override String nonStackableFloorCount(int count) => 'تحتوي على $count طرد غير قابل للرص مثبت على الأرضية';
  @override String multiLayerCompliant(String percent) => 'رص متعدد الطبقات متوافق ($percent%)';
  @override String get failedStackLabel => 'فشل الرص';
  @override String itemsExceedCapacity(String ids) => 'الأصناف التالية تفوق سعة حاويات الشحن: $ids';
  @override String containerLayoutTitle(int index, String name, String code) => 'مخطط الحاوية #$index: $name ($code)';
  @override String get woodenFloorPalletsLabel => '🪵 طبالي خشبية أرضية';
  @override String internalDimsLabel(String l, String w, String h) => 'الأبعاد الداخلية: $l x $w x $h cm';
  @override String get closePlanBtn => 'إغلاق المخطط';
  // Default study title
  @override String defaultStudyTitle(String date) => 'دراسة تقييم خيارات الشحن ($date)';
  // Independent study
  @override String get independentStudy => 'مستقل';
  // Options count chip
  @override String optionsCount(int count) => '$count خيار';
  // Avg transit days in registry table
  @override String avgTransitDays(String days) => '$days يوم';
  // Clearance cost compact line
  @override String clearanceCostSummary(String amount, String currency) => 'تخليص: $amount $currency';

  // ── Customs Consultation & Calculator Workspace (Screens 6 & 7) ─────────
  @override String get invoiceCurrencyLabel => 'عملة البضاعة أو الفاتورة';
  @override String get customsFxRateLabel => 'سعر الصرف الجمركي للبضاعة بالجنيه';
  @override String get freightDataHeader => 'بيانات النولون البحري والجوي';
  @override String get fetchHighestFreightFromStudy => 'جلب أعلى نولون من دراسة الشحن';
  @override String get foreignFreightAmountLabel => 'قيمة النولون بالعملة الأجنبية';
  @override String get freightCurrencyLabel => 'عملة النولون';
  @override String get freightFxRateLabel => 'سعر صرف عملة النولون بالجنيه';
  @override String get estimatedCustomsInsuranceRateLabel => 'نسبة التأمين التقديري الجمركي:';
  @override String get standardCustomsInsuranceRate => '0.5% (القياسي للجمارك)';
  @override String get customInsuranceRate => 'مخصص';
  @override String autoCalculatedCandFInsuranceHelper(String option) => 'محسوب تلقائياً من (تكلفة ونولون × $option)';
  @override String get declaredCifBaseLabel => 'إجمالي القيمة المقر عنها للأغراض الجمركية (وعاء سيف):';
  @override String cifFormulaBreakdown(String fob, String cur, String freight, String cAndF, String insurance) =>
      'قيمة البضاعة فوب ($fob $cur) + النولون ($freight ج.م) = تكلفة ونولون ($cAndF ج.م) + التأمين ($insurance ج.م)';
  @override String tariffDetailsTableTitle(int count, String type) => 'جدول تفاصيل التعريفة الجمركية ($count $type)';
  @override String get groupedHsCodeItems => 'بند تعريفة مجمع';
  @override String get detailedItems => 'بند تفصيلي';
  @override String get groupByHsCodeOption => '✓ مجمع حسب بند التعريفة';
  @override String get detailedItemViewOption => 'عرض تفصيلي لكل بند';
  @override String valueInCurrencyCol(String cur) => 'القيمة بالعملة ($cur)';
  @override String linkedPurchaseOrdersSummary(int count, String total) => 'أوامر الشراء المرتبطة: $count أمر شراء$total';
  @override String approvedInvoicesSummary(int count, String total) => 'الفواتير المعتمدة: $count فواتير$total';
  @override String projectNamedSummary(String name) => 'المشروع: $name';
  @override String freightAutoFetchedDetailsToast(String amount, String currency, String rate, String freightEgp) =>
      '🚢 تم استدعاء النولون تلقائياً من سيناريوهات الشحن: $amount $currency × $rate = $freightEgp ج.م';
  @override String get noPoItemsFoundForFileToast => '⚠️ لم يتم العثور على بنود أوامر شراء مرتبطة بهذا الملف لاحتساب شروطها';
  @override String recalculatedTaxesAppliedToast(String amount) =>
      '💾 تم اعتماد وتطبيق قيمة الرسوم الجمركية والضرائب الجديدة ($amount ج.م). يمكنك الآن حفظ أو تحديث الدراسة الجمركية.';

  // Regulatory Documents & Authorities
  @override String get acidShipmentDoc => 'قيد رقم التسجيل المسبق للشحنة الكاملة (نافذة وكارجو إكس)';
  @override String acidShipmentDocRemarks(String hsCodes) => 'يشمل بنود: $hsCodes — رقم القيد الجمركي المبدئي إلزامي لإصدار بوليصة الشحن.';
  @override String get cooShipmentDoc => 'شهادة المنشأ الموثقة للشحنة الكاملة';
  @override String cooShipmentDocRemarks(String hsCodes) => 'يشمل بنود: $hsCodes — شهادة منشأ واحدة لكامل الشحنة، تصدر من الغرفة التجارية وتُوثق بالسفارة المصرية.';
  @override String get goeicShipmentDoc => 'عرض وفحص هيئة الرقابة على الصادرات والواردات للشحنة الكاملة';
  @override String get goeicAgencyName => 'هيئة الرقابة على الصادرات والواردات';
  @override String goeicShipmentDocRemarks(String hsCodes) => 'يشمل بنود: $hsCodes — فحص ظاهري وسحب عينات معمل لكامل الشحنة.';
  @override String priorAuthorityApprovalDoc(String authority) => 'موافقة $authority الفنية المسبقة';
  @override String priorAuthorityApprovalRemarks(String hsCodes, String note) => 'يشمل بنود: $hsCodes — $note';
  @override String get defaultPriorApprovalNote => 'يتطلب موافقة فنية مسبقة واستخراج تصريح الإفراج الجمركي.';

  // Standard Checklist Items & Remarks
  @override String get proformaInvoiceDoc => 'الفاتورة المبدئية';
  @override String get packingListDoc => 'بيان التعبئة';
  @override String get certificateOfOriginDoc => 'شهادة المنشأ';
  @override String get goeicInspectionDoc => 'فحص هيئة الرقابة على الصادرات والواردات';
  @override String get ntraApprovalDoc => 'موافقة الجهاز القومي لتنظيم الاتصالات';
  @override String get proformaInvoiceApprovedRemark => 'الفاتورة المبدئية معتمدة ومطابقة للبند الجمركي.';
  @override String get packingListUpdatedRemark => 'محدثة بإجمالي الأوزان والأحجام والطرود.';
  @override String get embassyLegalizationRemark => 'مطلوب توثيق السفارة والغرفة التجارية.';
  @override String get visualLabInspectionRemark => 'يتطلب فحص ظاهري وعينات المعمل فور الوصول.';
  @override String get wirelessModuleRemark => 'تنطبق في حال وجود وحدات تحكم لاسلكية.';

  // Checklist Parties & Statuses
  @override String get partySupplierExporter => 'المورد المعتمد';
  @override String get partyImporterTeam => 'فريق المستورد';

  // Screen 22: Smart Invoice vs B/L Matcher (invoice_bl_matcher_tab.dart)
  @override String get invoiceBlMatcherTitle => 'أداة الاستخراج الذكي والمطابقة الفورية';
  @override String get invoiceBlMatcherSubtitle => 'استخراج الحقول المستهدفة ومطابقة الفاتورة النهائية مع البوليصة ومنع أي تعارض جمركي أو بنكي.';
  @override String get invoiceBlMatcherLinkImportFile => 'ربط بملف استيراد';
  @override String get invoiceBlMatcherSelectFileHint => 'اختر ملف الشحنة للمزامنة...';
  @override String get invoiceBlMatcherAddPackingListButton => '+ إضافة كشف التعبئة كملف إضافي';
  @override String get invoiceBlMatcherRemovePackingList => 'إلغاء وإخفاء كشف التعبئة';
  @override String get invoiceBlMatcherInvoiceBoxTitle => '1. الفاتورة التجارية النهائية';
  @override String get invoiceBlMatcherPackingBoxTitle => '2. كشف التعبئة النهائي';
  @override String get invoiceBlMatcherBlBoxTitle => '3. مسودة بوليصة الشحن';
  @override String get invoiceBlMatcherChangeFile => 'تغيير الملف';
  @override String get invoiceBlMatcherUploadFile => 'رفع ملف';
  @override String invoiceBlMatcherUploadedFile(String fileName) => 'الملف المرفوع: $fileName';
  @override String get invoiceBlMatcherInvoicePlaceholder => 'الصق نص الفاتورة هنا أو اضغط رفع ملف تجاري...';
  @override String get invoiceBlMatcherPackingPlaceholder => 'الصق نص كشف التعبئة هنا أو اضغط رفع كشف التعبئة...';
  @override String get invoiceBlMatcherBlPlaceholder => 'الصق مسودة البوليصة هنا أو اضغط رفع ملف الخط الملاحي...';
  @override String invoiceBlMatcherInvoiceFilesLoaded(int count, String names) => '[تم تحميل $count ملفات للفاتورة: $names — سيتم استخراج ومطابقة كافة البيانات آلياً]';
  @override String invoiceBlMatcherPackingFilesLoaded(int count, String names) => '[تم تحميل $count ملفات لكشف التعبئة: $names — سيتم استخراج الأوزان والأحجام والطرود آلياً]';
  @override String invoiceBlMatcherBlFilesLoaded(int count, String names) => '[تم تحميل $count ملفات للبوليصة: $names — سيتم استخراج ومطابقة محتواها آلياً]';
  @override String invoiceBlMatcherFilesSelectedSuccess(int count, String names) => 'تم اختيار $count ملف بنجاح ($names)';
  @override String invoiceBlMatcherFileReadError(dynamic error) => 'تعذر قراءة الملف: $error';
  @override String get invoiceBlMatcherExecuteMatchButton => 'تنفيذ الاستخراج الذكي والمطابقة الفورية';
  @override String get invoiceBlMatcherLoadSampleButton => 'تحميل نموذج تجريبي حقيقي';
  @override String get invoiceBlMatcherResetButton => 'إعادة تعيين';
  @override String get invoiceBlMatcherSampleLoadedSuccess => 'تم تحميل بيانات العينات الفعلية بنجاح';
  @override String get invoiceBlMatcherValidationRequired => 'يرجى إدخال أو رفع نصوص ومستندات الفاتورة أو كشف التعبئة أو بوليصة الشحن للمطابقة';
  @override String get invoiceBlMatcherAnalyzingProgress => 'جاري التحليل واستخراج الحقول المطابقة بالذكاء الاصطناعي...';
  @override String invoiceBlMatcherMatchCompletedSuccess(dynamic score) => 'اكتملت المطابقة الذكية بنجاح! نسبة التطابق: $score%';
  @override String get invoiceBlMatcherMatchErrorTitle => 'خطأ في المطابقة الذكية';
  @override String get invoiceBlMatcherStatusSafeTitle => 'مستندات متطابقة وجاهزة للاعتماد';
  @override String get invoiceBlMatcherStatusCriticalTitle => 'تم اكتشاف اختلافات حرجة تمنع الاعتماد';
  @override String invoiceBlMatcherMatchScore(dynamic score) => 'نسبة المطابقة: $score%';
  @override String get invoiceBlMatcherStatusSafeDesc => 'كافة الحقول الجمركية والمصرفية مطابقة بنسبة آمنة. يمكنك مزامنة البيانات مباشرة مع ملف الشحنة.';
  @override String invoiceBlMatcherStatusCriticalDesc(int count) => 'توجد $count فوارق حرجة تمنع الإفراج الجمركي أو مطابقة نموذج 4. يجب تعديل البوليصة أو الفاتورة قبل الاعتماد.';
  @override String invoiceBlMatcherCriticalCount(int count) => 'فوارق حرجة: $count';
  @override String invoiceBlMatcherWarningCount(int count) => 'تنبيهات ثانوية: $count';
  @override String get invoiceBlMatcherMatrixTitle => 'مصفوفة المطابقة التفصيلية (10 بنود فحص جمركية ومصرفية)';
  @override String get invoiceBlMatcherColCheckItem => 'بند الفحص والمطابقة';
  @override String get invoiceBlMatcherColInvoiceValue => 'القيمة بالفاتورة النهائية';
  @override String get invoiceBlMatcherColBlValue => 'القيمة بمسودة البوليصة';
  @override String get invoiceBlMatcherColMatchStatus => 'حالة المطابقة';
  @override String get invoiceBlMatcherColActionRequired => 'النتيجة والإجراء المطلوب';
  @override String get invoiceBlMatcherStatusMatch => 'مطابق';
  @override String get invoiceBlMatcherStatusMinor => 'فارق طفيف';
  @override String get invoiceBlMatcherStatusMismatch => 'غير مطابق';
  @override String get invoiceBlMatcherExtractedInvoiceTitle => 'البيانات المستخرجة من الفاتورة';
  @override String get invoiceBlMatcherExtractedBlTitle => 'البيانات المستخرجة من مسودة البوليصة';
  @override String get invoiceBlMatcherCorrectionLetterTitle => 'خطاب طلب التعديل التلقائي للخط الملاحي';
  @override String get invoiceBlMatcherCopyLetterButton => 'نسخ الخطاب';
  @override String get invoiceBlMatcherLetterCopiedSuccess => 'تم نسخ خطاب التعديل إلى الحافظة بنجاح';
  @override String get invoiceBlMatcherSyncFooterTitle => 'اعتماد النتائج ومزامنة بيانات الفاتورة والبوليصة مع ملف الاستيراد';
  @override String get invoiceBlMatcherSyncFooterDesc => 'سيتم تحديث رقم البوليصة، رقم الفاتورة، القيمة الإجمالية، والحاويات في ملف الشحنة المحدد.';
  @override String get invoiceBlMatcherSyncFooterNoFile => 'يرجى اختيار ملف شحنة من القائمة بالأعلى للمزامنة.';
  @override String get invoiceBlMatcherExportReportButton => 'تصدير تقرير المطابقة';
  @override String get invoiceBlMatcherCertifySyncButton => 'اعتماد ومزامنة مع ملف الشحنة';
  @override String get invoiceBlMatcherSelectFileFirstWarning => 'يرجى اختيار ملف شحنة وإجراء المطابقة أولاً للمزامنة';
  @override String get invoiceBlMatcherSyncSuccess => 'تمت المزامنة والاعتماد بنجاح';
  @override String get invoiceBlMatcherSyncFailedTitle => 'فشل مزامنة البيانات';
  @override String get invoiceBlMatcherReportDialogTitle => 'تقرير المطابقة الذكية';
  @override String invoiceBlMatcherReportMatchRatio(dynamic score) => 'نسبة التطابق: $score%';
  @override String get invoiceBlMatcherReportSafeStatus => 'آمن للاعتماد';
  @override String get invoiceBlMatcherReportUnsafeStatus => 'يوجد فوارق حرجة';
  @override String get invoiceBlMatcherCopyReportButton => 'نسخ التقرير';
  @override String get invoiceBlMatcherReportCopiedSuccess => 'تم نسخ التقرير إلى الحافظة بنجاح';
  @override String get invoiceBlMatcherCloseButton => 'إغلاق';

  // Screen 22: Smart Invoice & B/L Extractor Dialog (smart_invoice_bl_extractor_dialog.dart)
  @override String get smartExtractorDialogTitle => 'استخلاص الفواتير وبوالص الشحن بالذكاء الاصطناعي';
  @override String get smartExtractorDialogSubtitle => 'استخراج ذكي لبيانات الفواتير والبوالص البحرية والجوية مع التدقيق والمطابقة الجمركية المسبقة';
  @override String get smartExtractorTabInvoice => 'الفاتورة التجارية';
  @override String get smartExtractorTabBl => 'بوليصة الشحن';
  @override String get smartExtractorTabAudit => 'رادار المطابقة الجمركية';
  @override String get smartExtractorInvoiceCardTitle => '1. إدخال أو رفع الفاتورة التجارية';
  @override String get smartExtractorInvoiceCardHint => 'الصق نص الفاتورة هنا، أو اختر ملف الفاتورة...';
  @override String get smartExtractorPickFileButton => 'اختيار ملف';
  @override String get smartExtractorExtractInvoiceButton => 'استخلاص الفاتورة بالذكاء الاصطناعي';
  @override String get smartExtractorExtractedInvoiceTitle => 'البيانات المستخلصة من الفاتورة:';
  @override String smartExtractorCurrency(String currency) => 'العملة: $currency';
  @override String get smartExtractorFieldInvoiceNo => 'رقم الفاتورة';
  @override String get smartExtractorFieldInvoiceDate => 'تاريخ الفاتورة';
  @override String get smartExtractorFieldAcidNo => 'رقم القيد الجمركي المبدئي';
  @override String get smartExtractorFieldImporterTaxId => 'البطاقة الضريبية للمستورد';
  @override String get smartExtractorFieldSupplier => 'المورد المعتمد';
  @override String get smartExtractorFieldImporter => 'المستورد المصري';
  @override String get smartExtractorFieldIncoterms => 'شرط التعاقد الدولي';
  @override String get smartExtractorFieldTotalAmount => 'إجمالي القيمة';
  @override String get smartExtractorFieldTotalGrossWeight => 'الوزن القائم الإجمالي';
  @override String get smartExtractorFieldPorts => 'موانئ الشحن والتفريغ';
  @override String smartExtractorItemsTableTitle(int count) => 'جدول الأصناف والبنود المستخلصة ($count صنف):';
  @override String get smartExtractorNoItemsFound => 'لم يتم العثور على جدول تفصيلي للأصناف في المستند';
  @override String get smartExtractorColItemDescription => 'بيان الصنف';
  @override String get smartExtractorColQuantity => 'الكمية';
  @override String get smartExtractorColUnit => 'الوحدة';
  @override String get smartExtractorColUnitPrice => 'سعر الوحدة';
  @override String get smartExtractorColTotalPrice => 'إجمالي السعر';
  @override String get smartExtractorApplySectionTitle => 'ربط وتطبيق في ملف استيرادي:';
  @override String get smartExtractorSelectFileLabel => 'اختر الملف الاستيرادي';
  @override String get smartExtractorSearchFileHint => 'ابحث برقم الملف أو الشركة...';
  @override String get smartExtractorApplyInvoiceButton => 'تطبيق في ملف الاستيراد';
  @override String smartExtractorFetchFilesError(dynamic error) => 'خطأ في جلب الملفات: $error';
  @override String get smartExtractorBlCardTitle => '2. إدخال أو رفع بوليصة الشحن';
  @override String get smartExtractorBlCardHint => 'الصق نص البوليصة هنا، أو اختر ملف البوليصة...';
  @override String get smartExtractorExtractBlButton => 'استخلاص بوليصة الشحن والحاويات';
  @override String get smartExtractorOceanBlTitle => 'بوليصة شحن بحري';
  @override String get smartExtractorAirWaybillTitle => 'بوليصة شحن جوي';
  @override String get smartExtractorPaymentPrepaid => 'نولون مدفوع مقدماً';
  @override String get smartExtractorPaymentCollect => 'نولون يُحصل عند الوصول';
  @override String get smartExtractorFieldBlNo => 'رقم البوليصة';
  @override String get smartExtractorFieldCarrier => 'الناقل والخط الملاحي';
  @override String get smartExtractorFieldFlightNo => 'رقم الرحلة الجوية';
  @override String get smartExtractorFieldVesselVoyage => 'السفينة ورقم الرحلة';
  @override String get smartExtractorFieldPol => 'ميناء الشحن';
  @override String get smartExtractorFieldPod => 'ميناء التفريغ';
  @override String get smartExtractorFieldTotalCbm => 'الحجم الكلي بالقدم المكعب';
  @override String get smartExtractorFieldPackagesCount => 'عدد الطرود';
  @override String get smartExtractorFieldShipper => 'الشاحن المعتمد';
  @override String get smartExtractorFieldConsignee => 'المرسل إليه';
  @override String smartExtractorContainersTableTitle(int count) => 'قائمة الحاويات والأختام المستخلصة ($count حاوية):';
  @override String get smartExtractorNoContainersFound => 'لا توجد حاويات محددة أو أن الشحنة شحن جوي';
  @override String get smartExtractorColContainerNo => 'رقم الحاوية';
  @override String get smartExtractorColSealNo => 'رقم السيل الرصاصي';
  @override String get smartExtractorColContainerType => 'نوع ومقاس الحاوية';
  @override String get smartExtractorColGrossWeightKg => 'الوزن القائم (كجم)';
  @override String get smartExtractorApplyBlSectionTitle => 'تطبيق البوليصة في تتبع الشحن والحاويات:';
  @override String get smartExtractorApplyBlButton => 'تطبيق في حركة الشحن الحالية';
  @override String get smartExtractorAuditCardTitle => 'رادار التدقيق الجمركي المتقاطع';
  @override String get smartExtractorAuditCardSubtitle => 'مقارنة الفاتورة مع البوليصة للتحقق من تطابق رقم القيد الجمركي المبدئي والأوزان وشروط النولون والموانئ تفادياً لأي غرامات.';
  @override String get smartExtractorRunAuditButton => 'تشغيل الفحص الآن';
  @override String smartExtractorMatchRatio(dynamic score) => 'نسبة التطابق: $score%';
  @override String get smartExtractorAuditMatrixTitle => 'مصفوفة الفحص والتدقيق المتقاطع (10 نقاط):';
  @override String get smartExtractorColCheckItem => 'بند الفحص';
  @override String get smartExtractorColInvoiceValue => 'القيمة بالفاتورة';
  @override String get smartExtractorColBlValue => 'القيمة بالبوليصة';
  @override String get smartExtractorColStatus => 'الحالة';
  @override String get smartExtractorColDetailsGuidance => 'التفاصيل والتوجيه';
  @override String get smartExtractorNoticeCardTitle => 'خطاب التعديل الرسمي للخط الملاحي والمورد';
  @override String get smartExtractorNoticeCardSubtitle => 'صيغة جاهزة لمطالبة الخط الملاحي بتعديل مسودة البوليصة فوراً.';
  @override String get smartExtractorCopyEnglishNoticeButton => 'نسخ الصيغة الإنجليزية';
  @override String get smartExtractorCopyArabicNoticeButton => 'نسخ الصيغة العربية';
  @override String smartExtractorPickFileError(dynamic error) => 'فشل اختيار الملف: $error';
  @override String get smartExtractorRequireInvoiceInput => 'يرجى اختيار ملف الفاتورة أو لصق نصها أولاً';
  @override String get smartExtractorInvoiceExtractedSuccess => 'تم استخلاص بيانات الفاتورة بنجاح بنسبة دقة عالية';
  @override String smartExtractorExtractInvoiceError(dynamic error) => 'خطأ أثناء استخلاص الفاتورة: $error';
  @override String get smartExtractorRequireBlInput => 'يرجى اختيار ملف البوليصة أو لصق نصها أولاً';
  @override String get smartExtractorBlExtractedSuccess => 'تم استخلاص بوليصة الشحن والحاويات بنجاح';
  @override String smartExtractorExtractBlError(dynamic error) => 'خطأ أثناء استخلاص البوليصة: $error';
  @override String get smartExtractorRequireBothDocsForAudit => 'يرجى استخلاص الفاتورة والبوليصة أولاً لإجراء المطابقة';
  @override String get smartExtractorAuditSuccess => 'تم اكتمال تدقيق المطابقة الجمركية بنجاح';
  @override String smartExtractorAuditError(dynamic error) => 'خطأ أثناء تدقيق المطابقة: $error';
  @override String get smartExtractorSelectFileWarning => 'يرجى تحديد الملف الاستيرادي المستهدف أولاً';
  @override String get smartExtractorInvoiceAppliedSuccess => 'تم ربط بيانات الفاتورة بالملف بنجاح';
  @override String smartExtractorApplyInvoiceError(dynamic error) => 'فشل تطبيق بيانات الفاتورة: $error';
  @override String get smartExtractorBlAppliedSuccess => 'تم تطبيق بيانات البوليصة بنجاح';
  @override String smartExtractorApplyBlError(dynamic error) => 'فشل تطبيق بيانات البوليصة: $error';
  @override String get smartExtractorNoticeEnCopied => 'تم نسخ صيغة الخطاب بالإنجليزية إلى الحافظة بنجاح';
  @override String get smartExtractorNoticeArCopied => 'تم نسخ صيغة الخطاب بالعربية إلى الحافظة بنجاح';
  @override String get smartExtractorAuditPass => 'مطابق';
  @override String get smartExtractorAuditWarning => 'تنبيه';
  @override String get smartExtractorAuditCritical => 'فارق حرج';
  @override String get smartExtractorAuditCompliant => 'مستندات متطابقة ومطابقة للاشتراطات';
  @override String get smartExtractorAuditWarningsDetected => 'توجد تنبيهات طفيفة يرجى مراجعتها';
  @override String get smartExtractorAuditCriticalMismatch => 'توجد فوارق حرجة تمنع الإفراج الجمركي';

  // ── What-If & FX Crisis Simulator ─────────────────────────────────────────
  @override String get whatIfDialogTitle => 'محاكي مخاطر الشحن وتغيرات أسعار الصرف والأزمات';
  @override String get whatIfDialogSubtitle => 'دراسة السيناريوهات الطارئة لتغيرات سعر الدولار الجمركي، التفاف السفن حول إفريقيا، وتراكم غرامات الميناء';
  @override String get whatIfSimulatorTab => 'محاكي السيناريوهات الحية';
  @override String get whatIfExposureTab => 'رادار الانكشاف المالي بالعملات الأجنبية';
  @override String get whatIfShipmentAndCurrencyInputs => '1. تحديد مدخلات الشحنة والعملة:';
  @override String get whatIfInvoiceValue => 'قيمة الفاتورة';
  @override String get whatIfFreightCost => 'تكلفة النولون البحري/الجوي';
  @override String get whatIfFxShockSimulation => '2. محاكاة صدمة سعر الصرف:';
  @override String get whatIfBaseRate => 'السعر الأساسي:';
  @override String get whatIfSimulatedRate => 'المحاكى:';
  @override String get whatIfShippingRouteRisk => '3. مسار الشحن ومخاطر الملاحة:';
  @override String get whatIfRouteRedSea => 'مسار البحر الأحمر وقناة السويس (طبيعي)';
  @override String get whatIfRouteCape => 'التفاف رأس الرجاء الصالح (+18 يوم / +25% نولون)';
  @override String get whatIfPortDelay => 'تأخير الميناء:';
  @override String get whatIfDaysUnit => 'يوم';
  @override String get whatIfContainersCount => 'الحاويات';
  @override String get whatIfContainerUnit => 'حاوية';
  @override String get whatIfRunSimulationNow => 'تشغيل المحاكاة الآن';
  @override String get whatIfSelectShipmentPlaceholder => 'اختر الشحنة للمحاكاة (اختياري)';
  @override String get whatIfSearchShipmentHint => 'ابحث برقم الملف أو الشركة...';
  @override String get whatIfPlaceholderTitle => 'جاهز لمحاكاة صدمات أسعار الصرف والأزمات اللوجستية';
  @override String get whatIfPlaceholderDescription => 'اضبط المتغيرات على الجانب الأيسر واضغط "تشغيل المحاكاة" لرؤية الأثر الفوري على الوعاء الضريبي، تكلفة الوصول الشاملة، غرامات الأرضيات، ومخاطر انتهاء صلاحية القيد المسبق للشحنات.';
  @override String get whatIfRiskLevel => 'مستوى المخاطر المالي والتشغيلي:';
  @override String get whatIfSaveScenario => 'حفظ السيناريو في سجل القرارات';
  @override String get whatIfCopyScenarioSummary => 'نسخ ملخص المحاكاة';
  @override String get whatIfScenarioCopied => 'تم نسخ ملخص سيناريو المحاكاة بنجاح';
  @override String get whatIfBaselineLandedCost => 'تكلفة الوصول الشاملة الأساسية:';
  @override String get whatIfSimulatedLandedCost => 'التكلفة بعد تطبيق المحاكاة:';
  @override String get whatIfCustomsTaxVariance => 'فارق الجمارك والضرائب (بالجنيه):';
  @override String get whatIfShippingDemurrage => 'غرامات التوكيل (بالدولار):';
  @override String get whatIfPortStorage => 'أرضيات الميناء (بالجنيه):';
  @override String get whatIfAcidExpiryCheck => 'فحص صلاحية القيد الجمركي المسبق (180 يوماً):';
  @override String get whatIfStrategicRecommendations => 'التوصيات الاستراتيجية والتحوط المالي:';
  @override String get whatIfRefreshExposure => 'تحديث بيانات الانكشاف المالي';
  @override String get whatIfTotalUsdObligations => 'إجمالي الالتزامات بالدولار';
  @override String get whatIfTotalEurObligations => 'إجمالي الالتزامات باليورو';
  @override String get whatIfCurrentEgpValue => 'القيمة الحالية بالجنيه';
  @override String get whatIfValueAtRisk10 => 'القيمة المعرضة للمخاطر 10%';
  @override String get whatIfTreasuryGuidance => 'ملاحظات وإرشادات إدارة الخزانة والتحوط:';
  @override String get whatIfOpenShipmentsExposed => 'تفاصيل الشحنات المفتوحة المعرضة لتقلبات الصرف:';
  @override String get whatIfColShipmentCode => 'رقم الشحنة';
  @override String get whatIfColSupplier => 'المورد الأجنبي';
  @override String get whatIfColCurrency => 'العملة';
  @override String get whatIfColPendingAmount => 'المبلغ المعلق';
  @override String get whatIfColCurrentEgp => 'المعادل الحالي (بالجنيه)';
  @override String get whatIfColScenarioPlus10 => 'في سيناريو +10%';
  @override String get whatIfColScenarioPlus25 => 'في سيناريو +25%';

  // ── Freight RFQ Dialog ───────────────────────────────────────────────────
  @override String get freightRfqRecipient => 'المرسل إليه:';
  @override String get freightRfqSelectLineHint => 'اختر خط ملاحي / وكيل...';
  @override String get freightRfqTypePersonHint => 'أو اكتب اسم الشخص / الوكيل (مثال: Marian, Raafat)...';
  @override String get freightRfqUpdateTextTooltip => 'تحديث النص';
  @override String get freightRfqUpdateBtn => 'تحديث';
  @override String get freightRfqCopySubjectTooltip => 'نسخ عنوان الإيميل';
  @override String get freightRfqWhatsappFeatures => 'مميزات رسالة الواتساب:';
  @override String get freightRfqWhatsappFeature1 => 'منسقة بالرموز والمحاذاة التامة.';
  @override String get freightRfqWhatsappFeature2 => 'تشمل الحجم الإجمالي والأوزان وعنوان التحميل.';
  @override String get freightRfqWhatsappFeature3 => 'توضح فترة السماح المطلوبة (21 Days FT).';
  @override String get freightRfqWhatsappFeature4 => 'جاهزة للمشاركة الفورية مع مندوبي ووكلاء الشحن.';
  @override String get freightRfqCopyWhatsappBtn => 'نسخ رسالة الواتساب بالكامل';
  @override String get freightRfqPickupLocation => 'عنوان الاستلام والتحميل:';
  @override String get freightRfqSupplierLabel => 'المورد:';
  @override String get freightRfqPackagesBreakdownTitle => 'تفاصيل الطرود وأبعاد البالتات:';
  @override String get freightRfqPrintPdfBtn => 'طباعة / حفظ مستند PDF الرسمي';
  @override String get freightRfqCopyEmailBtn => 'نسخ نص الإيميل بالكامل';
  @override String get freightRfqCloseDismissBtn => 'إغلاق وتراجع ✕';

  // ── Master Screens AI Extraction & Tools ─────────────────────────────────
  @override String get aiCodeCompanyBtn => 'تكويد الشركة بالذكاء الاصطناعي ✨';
  @override String get aiCodePartnerBtn => 'تكويد شريك بالذكاء الاصطناعي ✨';
  @override String aiCodeCategoryPartner(String category) => 'تكويد $category بالذكاء الاصطناعي ✨';
  @override String get syncOfficialCustomsRatesBtn => 'مزامنة أسعار الصرف الجمركية';
  @override String get whatIfSimulatorBtn => 'محاكي صدمات الصرف والأزمات';
  @override String get syncRatesSuccess => 'تم تحديث أسعار الصرف الجمركية الرسمية بنجاح ✅';
  @override String syncRatesFailed(String error) => 'فشل مزامنة أسعار الصرف الجمركية: $error';

  // ── Screen 56: Customs Tax & Declaration 46 Review Workspace ───────────────
  @override String get customsTaxExportTsvBtn => 'تصدير جدول الحساب مفصول بمسافات جدولية';
  @override String get customsTaxExportExcelBtn => 'تصدير جدول الحساب إكسيل';
  @override String get customsTaxPrintPdfBtn => 'طباعة أو حفظ تقرير الحساب الجمركي';
  @override String get customsTaxCopyDossierBtn => 'نسخ ملف الحساب الجمركي للحافظة';
  @override String get customsTaxCopiedDossierSuccess => 'تم نسخ ملخص الحساب والضرائب الجمركية بالكامل إلى الحافظة بنجاح';
  @override String get customsTaxCopiedTsvSuccess => 'تم نسخ جدول الضرائب بصيغة مسافات جدولية بنجاح';
  @override String get customsTaxCopiedExcelSuccess => 'تم نسخ بيانات الضرائب والرسوم بصيغة جدولية إكسيل بنجاح';
  @override String get customsTaxExportTsvDialogTitle => 'تصدير جدول الحساب مفصول بمسافات جدولية';
  @override String get customsTaxExportExcelDialogTitle => 'تصدير جدول الحساب كملف إكسيل';
  @override String get customsTaxExportPdfDialogTitle => 'طباعة أو تصدير تقرير الضرائب الجمركية';
  @override String get customsTaxDossierTitle => 'ملف المراجعة والتقدير الجمركي الشامل';
  @override String get customsTaxCopyRowSuccess => 'تم نسخ بيانات البند الجمركي المحددة إلى الحافظة';
  @override String get customsTaxCopySummarySuccess => 'تم نسخ ملخص الضرائب والرسوم الجمركية إلى الحافظة';
  @override String get customsTaxTsvHeaderHsCode => 'بند التعريفة الجمركية';
  @override String get customsTaxTsvHeaderDescription => 'وصف الصنف';
  @override String get customsTaxTsvHeaderOrigin => 'بلد المنشأ';
  @override String get customsTaxTsvHeaderQty => 'الكمية';
  @override String get customsTaxTsvHeaderUnit => 'الوحدة';
  @override String get customsTaxTsvHeaderForeignPrice => 'السعر بالعملة الأجنبية';
  @override String get customsTaxTsvHeaderFobEgp => 'قيمة البضاعة بالجنيه المصري';
  @override String get customsTaxTsvHeaderFreightEgp => 'النولون بالجنيه المصري';
  @override String get customsTaxTsvHeaderInsuranceEgp => 'التأمين بالجنيه المصري';
  @override String get customsTaxTsvHeaderCifEgp => 'القيمة الجمركية الشاملة بالجنيه';
  @override String get customsTaxTsvHeaderDutyRate => 'نسبة ضريبة الوارد';
  @override String get customsTaxTsvHeaderDutyAmount => 'مبلغ ضريبة الوارد';
  @override String get customsTaxTsvHeaderVatRate => 'نسبة ضريبة القيمة المضافة';
  @override String get customsTaxTsvHeaderVatAmount => 'مبلغ ضريبة القيمة المضافة';
  @override String get customsTaxTsvHeaderScheduleTax => 'ضريبة الجدول ورسم التنمية';
  @override String get customsTaxTsvHeaderCustomsFees => 'رسوم الخدمات والرسوم الأساسية';
  @override String get customsTaxTsvHeaderTotalTaxes => 'إجمالي الضرائب والرسوم المستحقة';
  @override String get customsTaxTsvHeaderRegulatoryConditions => 'الاشتراطات والموافقات الرقابية المسبقة';
  @override String get customsTaxLogTsvHeaderCode => 'كود الجلسة';
  @override String get customsTaxLogTsvHeaderFile => 'ملف الشحنة';
  @override String get customsTaxLogTsvHeaderTitle => 'عنوان الدراسة';
  @override String get customsTaxLogTsvHeaderBroker => 'المستخلص الجمركي';
  @override String get customsTaxLogTsvHeaderEstimatedDuties => 'الرسوم التقديرية';
  @override String get customsTaxLogTsvHeaderReadiness => 'نسبة الجاهزية';
  @override String get customsTaxLogTsvHeaderStatus => 'الحالة';
  @override String get customsTaxLogTsvHeaderCreatedDate => 'تاريخ الإنشاء';

  // ── Standalone Extraction Tools & Dual Extraction ───────────────────────
  @override String get dualExtractionEngineTitle => 'محرك الاستخلاص المزدوج للوثائق';
  @override String get dualExtractionCommercialInvoice => 'الفاتورة التجارية الجمركية';
  @override String get dualExtractionPackingList => 'قائمة التعبئة الجمركية';
  @override String get dualExtractionInvoiceModeTitle => 'نمط استخراج الفاتورة';
  @override String get dualExtractionGroupingTitle => 'تجميع بنود الفاتورة';
  @override String get dualExtractionPlModeTitle => 'نمط استخراج قائمة التعبئة';
  @override String get dualExtractionStructureTitle => 'هيكل الطرود والكراتين';
  @override String get dualExtractionIncludePallets => 'إدراج بيانات البالتات والطرود';
  @override String get dualExtractionPalletDataTitle => 'بيانات البالتات والطرود';
  @override String get dualExtractionAddPalletBtn => 'إضافة بالتة';
  @override String get dualExtractionNoPallets => 'لا توجد بالتات مضافة بعد';
  @override String get dualExtractionPreviewResults => 'معاينة نتائج الاستخلاص المزدوج';
  @override String get dualExtractionDownloadZip => 'تحميل الملف المضغوط';
  @override String get dualExtractionAdoptCustomsTrack => 'اعتماد كمسار جمركي';
  @override String get dualExtractionTrackCreatedSuccess => 'تم إنشاء المسار الجمركي المزدوج بنجاح';
  @override String get dualExtractionCopySummaryTooltip => 'نسخ ملخص الاستخلاص المزدوج';
  @override String get dualExtractionSummaryCopied => 'تم نسخ ملخص الاستخلاص المزدوج بنجاح';
  @override String get smartUploadCopyAllTooltip => 'نسخ كافة البيانات المستخرجة';
  @override String get smartUploadCopyAllSuccess => 'تم نسخ كافة البيانات المستخرجة بنجاح';

  // ── Screen 67: Lifecycle Steps Risk Classification & Skip Policy Governance ──
  @override String get stepConfigTitle => 'إعدادات تصنيف مخاطر المراحل وحوكمة التخطي';
  @override String get stepConfigSubtitle => 'إدارة ديناميكية مركزية لسياسات تخطي المراحل وإسناد المراجع المعلقة دون تعديل الكود';
  @override String get stepConfigAccessDeniedTitle => 'صلاحية غير كافية — مقصورة على مسؤول الإدارة';
  @override String get stepConfigAccessDeniedDesc => 'وفقاً لمعايير الحوكمة والرقابة التشغيلية، يحظر على المستخدمين التشغيليين تعديل سياسات وقواعد تخطي المراحل. هذه الشاشة متاحة حصرياً للمدير المعتمد.';
  @override String get adminOnlyFeatureMessage => 'هذه الخاصية متاحة لمدير النظام فقط.';
  @override String get stepConfigDemoSwitchBtn => 'التبديل لدور المدير تجريبياً';
  @override String get stepConfigRefreshTooltip => 'تحديث البيانات';
  @override String get stepConfigSearchHint => 'بحث بكود الخطوة أو الاسم أو السياسة...';
  @override String get stepConfigPhaseAll => 'الكل (25 خطوة)';
  @override String stepConfigPhaseLabel(int phase) => 'المرحلة $phase';
  @override String get stepConfigEmptySearch => 'لا توجد خطوات مطابقة لمعايير البحث الحالية.';
  @override String get stepConfigColPhaseCode => 'المرحلة والكود';
  @override String get stepConfigColStepName => 'اسم الخطوة';
  @override String get stepConfigColSkipPolicy => 'سياسة التخطي';
  @override String get stepConfigColApproverRoles => 'الأدوار المعتمدة';
  @override String get stepConfigColPendingRef => 'مرجع معلق';
  @override String get stepConfigColReasonCategories => 'أسباب التخطي';
  @override String get stepConfigColLastModified => 'آخر تعديل';
  @override String get stepConfigColActions => 'الإجراءات';
  @override String get stepConfigPolicyBlocked => 'محظورة نهائياً';
  @override String get stepConfigPolicySingleApproval => 'موافقة أحادية معتمدة';
  @override String get stepConfigPolicyDualApproval => 'موافقة ثنائية مشددة';
  @override String get stepConfigPendingRefAllowed => 'مسموح';
  @override String get stepConfigPendingRefBlocked => 'غير متاح';
  @override String stepConfigReasonCategoriesCount(int count) => '$count فئات';
  @override String get stepConfigEditTooltip => 'تعديل السياسة والتصنيف';
  @override String get stepConfigAuditTooltip => 'سجل تدقيق التغييرات الرقابية';
  @override String get stepConfigCopyRowTooltip => 'نسخ ملخص الخطوة';
  @override String get stepConfigCopyRowSuccess => 'تم نسخ ملخص إعدادات الخطوة بنجاح';
  @override String stepConfigCopyBadgeSuccess(String label, String value) => 'تم نسخ $label: $value';
  @override String get stepConfigSearchCopied => 'تم نسخ نص البحث إلى الحافظة';
  @override String get stepConfigExportTsvBtn => 'تصدير جدول';
  @override String get stepConfigExportExcelBtn => 'تصدير إكسيل';
  @override String get stepConfigPrintPdfBtn => 'تقرير بي دي إف';
  @override String get stepConfigCopyDossierBtn => 'نسخ ملف الحافظة';
  @override String get stepConfigCopiedTsvSuccess => 'تم تصدير ونسخ جدول الإعدادات بنجاح';
  @override String get stepConfigCopiedExcelSuccess => 'تم تصدير ملف الإكسيل بنجاح';
  @override String get stepConfigCopiedDossierSuccess => 'تم نسخ ملف حوكمة المراحل إلى الحافظة بنجاح';
  @override String get stepConfigPdfTitle => 'تقرير حوكمة سياسات تخطي وتصنيف مراحل الشحنة';
  @override String get stepConfigPdfSubtitle => 'سجل معايير المخاطر والاعتمادات المسبقة لمنظومة الاستيراد';
  @override String get stepConfigDossierHeader => '=== ملف حوكمة سياسات تخطي مراحل الشحنة ===';
  @override String get stepConfigDossierKpiSummary => '--- المؤشرات العامة للحوكمة ---';
  @override String get stepConfigDossierRecordsDetails => '--- تفاصيل سياسات المراحل الـ 25 ---';
  @override String get stepConfigDossierFooter => '=== نهاية التقرير المعتمد من إدارة الاستيراد ===';
  @override String stepConfigEditDialogTitle(String code) => 'تعديل سياسة الخطوة: $code';
  @override String get stepConfigSkipPolicyLabel => 'سياسة وقابلية التخطي:';
  @override String get stepConfigPolicyItemBlocked => 'محظورة من التخطي نهائياً';
  @override String get stepConfigPolicyItemSingleApproval => 'موافقة أحادية معتمدة للمدير أو من ينوب عنه';
  @override String get stepConfigPolicyItemDualApproval => 'موافقة ثنائية مشددة للمدير ورئيس الامتثال';
  @override String get stepConfigPendingRefToggleTitle => 'تسجيل مرجع معلق مبكر';
  @override String get stepConfigPendingRefToggleSubtitle => 'السماح بتسجيل رقم مرجعي مبكراً مع بقاء الخطوة غير مكتملة امتثالياً';
  @override String get stepConfigApproverRolesTitle => 'الأدوار المخولة باعتماد التخطي:';
  @override String get stepConfigApproverRolesSubtitle => 'دور المدير هو الدور الاحتياطي الافتراضي المعتمد دائماً';
  @override String get stepConfigJustificationTitle => 'السبب التبريري للتعديل (إلزامي للتوثيق الرقابي):';
  @override String get stepConfigJustificationHint => 'مثال: تم السماح بالتخطي لشحنات التوريد المباشر بموجب اعتماد الإدارة العامة...';
  @override String get stepConfigJustificationValidator => 'يجب إدخال سبب تبريري لا يقل عن 5 أحرف لتوثيق التغيير';
  @override String get stepConfigCancelBtn => 'إلغاء';
  @override String get stepConfigSaveBtn => 'حفظ التعديل وتوثيق السجل';
  @override String stepConfigSaveSuccess(String code) => 'تم تعديل سياسة المرحلة $code بنجاح';
  @override String stepConfigAuditDialogTitle(String code) => 'سجل تدقيق تغييرات السياسة: $code';
  @override String get stepConfigAuditEmpty => 'لا توجد تعديلات سابقة مسجلة على هذه الخطوة';
  @override String stepConfigAuditBy(String user) => 'بواسطة: $user';
  @override String get stepConfigAuditPolicyChange => 'تغيير السياسة:';
  @override String get stepConfigAuditJustification => 'التبرير:';
  @override String get stepConfigAuditCloseBtn => 'إغلاق';

  // ─── AI Assistant Overlay & Lifecycle Navigator ─────────────────────────────
  @override String get aiAssistantTitle => 'مساعد الاستيراد الذكي';
  @override String get aiAssistantGreetingTitle => 'مرحباً';
  @override String get aiAssistantGreetingBody => 'هنا للمساعدة في العمليات والرد على الاستفسارات.';
  @override String get aiAssistantOnlineStatus => 'مساعد الاستيراد متصل';
  @override String get aiAssistantCloseTooltip => 'إغلاق المساعد الذكي';
  @override String get aiAssistantOpenTooltip => 'مساعد الاستيراد الذكي';
  @override String get aiAssistantMyShipmentsTooltip => 'شحناتي (مسار الشحنة التفاعلي)';
  @override String get aiAssistantClearChatTooltip => 'مسح المحادثة';
  @override String get aiAssistantApiKeySettingsTooltip => 'إعدادات مفتاح التشغيل';
  @override String get aiAssistantExpandTooltip => 'تكبير وتوسيع نافذة المحادثة';
  @override String get aiAssistantRestoreTooltip => 'استعادة الحجم الطبيعي';
  @override String get aiAssistantCopyTranscriptTooltip => 'نسخ سجل المحادثة بالكامل';
  @override String get aiAssistantTranscriptCopied => 'تم نسخ سجل المحادثة بالكامل إلى الحافظة بنجاح';
  @override String get aiAssistantNoMessagesToCopy => 'لا توجد رسائل في المحادثة لنسخها';
  @override String get aiAssistantInputHint => 'اسألني عن الاستيراد، الجمارك، الشحن، المهام...';
  @override String get aiAssistantSendTooltip => 'إرسال';
  @override String get aiAssistantPasteTooltip => 'لصق من الحافظة';
  @override String get aiAssistantCopyMessageSuccess => 'تم النسخ بنجاح';
  @override String get aiAssistantUserMessageCopied => 'تم نسخ رسالتك بنجاح';
  @override String get aiAssistantAssistantMessageCopied => 'تم نسخ رد المساعد بنجاح';
  @override String get aiAssistantCopyNotificationTooltip => 'نسخ الإشعار';
  @override String get aiAssistantNotificationCopied => 'تم نسخ الإشعار بنجاح';
  @override String get aiAssistantRetry => 'إعادة المحاولة';
  @override String get aiAssistantQuickSuggestionsTitle => 'اقتراحات سريعة مصنفة';
  @override String get aiAssistantActivateTitle => 'تفعيل المساعد الذكي';
  @override String get aiAssistantActivateDesc => 'أدخل مفتاح التشغيل الخاص بك لبدء المحادثة مع مساعد الاستيراد الذكي.';
  @override String get aiAssistantEnterApiKey => 'إدخال مفتاح التشغيل';
  @override String get aiAssistantGetApiKeyLabel => 'احصل على مفتاح التشغيل مجاناً (اضغط للفتح)';
  @override String get aiAssistantApiKeyDialogTitle => 'مفتاح المساعد الذكي';
  @override String get aiAssistantApiKeyFieldLabel => 'مفتاح التشغيل';
  @override String get aiAssistantApiKeyActiveStatus => 'مفتاح التشغيل نشط ومثبت';
  @override String get aiAssistantDisableKey => 'تعطيل المفتاح';
  @override String get aiAssistantSaveAndActivate => 'حفظ وتفعيل';
  @override String get aiAssistantClearContextTooltip => 'مسح سياق الشحنة النشطة';
  @override String get aiAssistantViewDataShortcut => 'عرض البيانات';
  @override String get aiAssistantUpdateDataShortcut => 'تحديث البيانات';
  @override String get aiAssistantAskAboutStepShortcut => 'اسأل عن المرحلة';
  @override String get aiAssistantCopiedUrlSuccess => 'تم نسخ الرابط إلى الحافظة وفتح المتصفح';
  @override String get aiAssistantOpenLink => 'فتح الرابط';
  @override String get aiAssistantCancel => 'إلغاء';
  @override String get aiLifecycleTitle => 'مخطط مسار الشحنة:';
  @override String get aiLifecycleCloseTooltip => 'إغلاق المخطط';
  @override String get aiLifecycleCopySummaryTooltip => 'نسخ ملخص مسار الشحنة';
  @override String get aiLifecycleSummaryCopied => 'تم نسخ ملخص مسار الشحنة إلى الحافظة';
  @override String get aiLifecycleNoShipments => 'لا توجد شحنات مسجلة حالياً';
  @override String get aiLifecycleStartNewShipment => 'ابدأ شحنة جديدة';
  @override String get aiLifecycleAllCompleted => 'اكتملت جميع مراحل الشحنة بنجاح (100%).';
  @override String aiLifecycleCompletionRate(String icon, int percent, int completed, int total) =>
      'نسبة الإنجاز: $icon $percent% ($completed من $total خطوات)';
  @override String get aiLifecycleStatusOverdue => 'متأخرة';
  @override String get aiLifecycleStatusCompleted => 'مكتملة';
  @override String get aiLifecycleStatusActive => 'حالية';
  @override String get aiLifecycleStatusUpcoming => 'قادمة';
  @override String get aiLifecycleHideStages => 'إخفاء باقي المراحل';
  @override String aiLifecycleShowAllStages(int count) => 'عرض كل المراحل (+$count)';
  @override String aiLifecycleActionsFor(String stepName) => 'إجراءات مرحلة: $stepName';
  @override String get aiLifecycleActionView => 'عرض البيانات';
  @override String get aiLifecycleActionUpdate => 'تحديث';
  @override String get aiLifecycleActionAsk => 'اسأل';
  @override String get aiLifecycleActionSkip => 'تخطي';
  @override String get aiLifecycleCopyFileCodeTooltip => 'نسخ رقم الملف';
  @override String get aiLifecycleFileCodeCopied => 'تم نسخ رقم الملف إلى الحافظة';

  // ── INT-DATA-015: Free Freight & Demurrage Connector ────────────────
  @override String get freightDataConnectorDialogTitle => 'موصل بيانات الشحن البحري والغرامات الخارجي المجاني';
  @override String get freightDataConnectorDialogSubtitle => 'مؤشر أسعار الشحن الأسبوعي وقواعد غرامات الخطوط الملاحية وتعريفات أرضيات الموانئ المصرية';
  @override String get freightDataTabOverview => 'نظرة عامة ومراقبة الحصة';
  @override String get freightDataTabSimulator => 'محاكي الغرامات والأرضيات المزدوج';
  @override String get freightDataTabPortTariffs => 'تعريفات أرضيات الموانئ المصرية';
  @override String get freightDataShaqFreightSection => 'مؤشر شحن الحاويات الأسبوعي المجاني';
  @override String get freightDataShaqFreightDesc => 'مكتبة مجانية مفتوحة المصدر لجلب مؤشرات نولون الحاويات الأسبوعية الفورية للخطوط العالمية والبحر المتوسط دون أي تكلفة اشتراك.';
  @override String get freightDataShippingRatesSection => 'موصل قواعد غرامات التوكيلات الملاحية';
  @override String get freightDataShippingRatesDesc => 'تجميع فترات السماح وشرائح غرامات الحاويات للخطوط الملاحية الكبرى مع حماية الحصة الشهرية المجانية.';
  @override String get freightDataPortDecreesSection => 'سجل قرارات وتعريفات أرضيات هيئات الموانئ المصرية';
  @override String get freightDataPortDecreesDesc => 'القرارات الوزارية التاريخية والنشطة المنظمة لأرضيات ساحات الموانئ بالجنيه المصري مع دعم التقييم الزمني بحسب تاريخ التفريغ.';
  @override String get freightDataStatusActive => 'نشط ومتصل';
  @override String get freightDataMonthlyQuota => 'الحصة الشهرية للطلبات';
  @override String get freightDataQuotaUsed => 'الطلبات المستخدمة';
  @override String get freightDataQuotaRemaining => 'الطلبات المتبقية';
  @override String get freightDataSyncSfxNow => 'تحديث مؤشر النولون الآن';
  @override String get freightDataSyncSfxSuccess => 'تم تحديث مؤشر أسعار النولون الأسبوعي بنجاح';
  @override String get freightDataRefreshStatus => 'تحديث حالة الموصل';
  @override String get freightDataTrackedRoutesCount => 'الخطوط الملاحية المتابعة';
  @override String get freightDataTrackedLinesCount => 'الخطوط الملاحية المسجلة';
  @override String get freightDataActiveDecreesCount => 'القرارات الوزارية المسجلة';
  @override String get freightDataLastSyncDate => 'تاريخ آخر تحديث';
  @override String get freightDataNeverSynced => 'لم يتم التحديث بعد';
  @override String get freightDataSimShippingLine => 'الخط الملاحي';
  @override String get freightDataSimPortAuthority => 'هيئة الميناء';
  @override String get freightDataSimContainerType => 'نوع الحاوية';
  @override String get freightDataSimDischargeDate => 'تاريخ التفريغ';
  @override String get freightDataSimClearanceDate => 'تاريخ الاحتساب أو الإفراج';
  @override String get freightDataSimDaysInPort => 'إجمالي الأيام بالميناء';
  @override String get freightDataSimFxRate => 'سعر الصرف الرسمي للدولار مقابل الجنيه';
  @override String get freightDataSimCalculateBtn => 'احتساب الغرامات والأرضيات لحظيا';
  @override String get freightDataCarrierDetentionTitle => 'غرامات تأخير الحاويات للتوكيل الملاحي بالدولار';
  @override String get freightDataPortStorageTitle => 'أرضيات ساحة الميناء بالجنيه المصري';
  @override String get freightDataAppliedDecree => 'القرار الوزاري المطبق';
  @override String get freightDataFreeDaysLabel => 'مهلة السماح المجانية';
  @override String get freightDataChargeableDaysLabel => 'الأيام الخاضعة للغرامة';
  @override String get freightDataConsolidatedSummary => 'الملخص المالي الموحد للغرامات والأرضيات';
  @override String get freightDataTotalDetentionUsd => 'إجمالي غرامة التوكيل بالدولار';
  @override String get freightDataTotalStorageEgp => 'إجمالي أرضيات الميناء بالجنيه';
  @override String get freightDataConsolidatedEgp => 'الإجمالي المعادل بالجنيه المصري';
  @override String get freightDataConsolidatedUsd => 'الإجمالي المعادل بالدولار الأمريكي';
  @override String get freightDataCopySimulationDossier => 'نسخ تقرير الحساب المزدوج كاملا للحافظة';
  @override String get freightDataSimulationDossierCopied => 'تم نسخ ملف الحساب المزدوج للغرامات والأرضيات إلى الحافظة بنجاح';
  @override String get freightDataAddTariffDecreeBtn => 'إضافة قرار وزاري لتعريفة الميناء';
  @override String get freightDataTariffVersionCol => 'رقم القرار أو الإصدار';
  @override String get freightDataEffectiveFromCol => 'تاريخ السريان من';
  @override String get freightDataEffectiveToCol => 'تاريخ السريان إلى';
  @override String get freightDataActiveOngoing => 'سار حتى الآن';
  @override String get freightDataSourceDocCol => 'المستند المرجعي الرسمي';
  @override String get freightDataRateSlabsSummary => 'شرائح وفئات الاحتساب';
  @override String get freightDataCopySlabRateTooltip => 'نسخ قيمة الفئة';
  @override String get freightDataLaunchConnectorTooltip => 'موصل بيانات الشحن البحري والغرامات المجاني';
  @override String get freightDataQuotaGuardAlert => 'حماية الحصة: الحد الأقصى عشر طلبات شهريا لضمان توفر الرصيد المجاني';
  @override String get freightDataDayUnit => 'أيام';
  @override String get freightDataPerDayUnit => 'يوم';
  @override String get freightDataCopyStatusSummary => 'نسخ ملخص الحالة كاملا';
  @override String get freightDataTotalLabel => 'الإجمالي';
  @override String get freightDataNoDecreesFound => 'لا توجد تعريفات مسجلة حاليا';

  // ── AI Quotation & Completeness Validation Layer (AI-EXTRACT-VALIDATE-001) ──
  @override String get quotationValidationBannerSafeTitle => 'استخراج موثوق ومكتمل بنسبة عالية';
  @override String get quotationValidationBannerWarningTitle => 'تنبيه: احتمال وجود بنود لم تستخرج';
  @override String get quotationValidationBannerCriticalTitle => 'تحذير حرج: اكتشاف فجوة نقص في بنود المقايسة';
  @override String quotationValidationExpectedCount(dynamic count) => 'البنود المتوقعة: $count';
  @override String quotationValidationExtractedCount(dynamic count) => 'البنود المستخرجة: $count';
  @override String quotationValidationGapPercentage(dynamic percent) => 'نسبة الفجوة: $percent٪';
  @override String get quotationValidationMultiValueBadge => 'خلية متعددة';
  @override String get quotationValidationMultiValueTooltip => 'مستخرج من خلية تحتوي أكثر من قيمة، تأكد من صحة الفصل';
  @override String get quotationValidationRangeBadge => 'نطاق سعري';
  @override String quotationValidationRangeTooltip(dynamic min, dynamic max) => 'سعر تقديري بنطاق أدنى وأقصى: من $min إلى $max جنيه';
  @override String get quotationValidationOutsideTableBadge => 'خارج الجدول';
  @override String get quotationValidationOutsideTableTooltip => 'بند شرطي مستخرج من نص الشروط خارج بنية الجدول';
  @override String get quotationValidationConfirmTitle => 'تأكيد اعتماد المقايسة مع وجود فجوة استخراج';
  @override String quotationValidationConfirmMessage(dynamic expected, dynamic extracted, dynamic gap) => 'اكتشف النظام $expected نمطا سعريا في المستند بينما تم استخراج $extracted بندا فقط بفجوة نقص $gap٪. هل ترغب في الاستمرار واعتماد البيانات الحالية على مسؤوليتك؟';
  @override String get quotationValidationProceedBtn => 'متابعة الاعتماد على مسؤوليتي';
  @override String get quotationValidationReviewBtn => 'العودة للمراجعة والتدقيق';
  @override String get quotationValidationCopyReportBtn => 'نسخ تقرير فحص واكتمال الاستخراج';
  @override String get quotationValidationReportCopiedToast => 'تم نسخ تقرير تدقيق اكتمال الاستخراج إلى الحافظة بنجاح';

  // ── Clearance Expense Types Catalog Exports ──
  @override String get expenseCatalogExportPdfBtn => 'تصدير تقرير بي دي إف';
  @override String get expenseCatalogExportExcelBtn => 'تصدير إكسيل';
  @override String get expenseCatalogExportTsvBtn => 'تصدير جدول نصوص';
  @override String get expenseCatalogCopyDossierBtn => 'نسخ ملف الحافظة الشامل';
  @override String get expenseCatalogDossierCopiedToast => 'تم نسخ بيانات دليل المصروفات إلى الحافظة بنجاح';
  @override String get expenseCatalogPdfReportTitle => 'دليل أنواع ومصروفات التخليص الجمركي';
  @override String get expenseCatalogPdfReportSubtitle => 'بيان معتمد بأنواع المصروفات وأكوادها وفئاتها ووحدات الحساب الرسمية';
  @override String expenseCatalogTotalCountLabel(dynamic count) => 'إجمالي أنواع المصروفات: $count';
  @override String expenseCatalogActiveCountLabel(dynamic count) => 'المصروفات السارية: $count';
  @override String get editExpenseTypeDialogTitle => 'تعديل بند المصروف';
  @override String get confirmDeleteExpenseTypeTitle => 'تأكيد حذف المصروف';
  @override String confirmDeleteExpenseTypeMsg(dynamic name, dynamic code) => 'هل أنت متأكد من حذف وتعطيل بند المصروف ($name) بالكود المرجعي ($code)؟';
  @override String get expenseTypeUpdatedToast => 'تم تحديث بند المصروف بنجاح';
  @override String get expenseTypeDeletedToast => 'تم حذف بند المصروف بنجاح';
  @override String get copyExpenseRowSummaryTooltip => 'نسخ ملخص البند';
  @override String get editExpenseTooltip => 'تعديل بيانات المصروف';
  @override String get deleteExpenseTooltip => 'حذف وتعطيل المصروف';

  // ── Universal Clone Engine (UX-CLONE-011) ──
  @override String get cloneRowTooltip => 'استنساخ السطر (كنترول + د)';
  @override String cloneEntityDialogTitle(dynamic entityType) => 'استنساخ $entityType — مراجعة وتأكيد البيانات';
  @override String get cloneEntityDialogSubtitle => 'مراجعة الحقول المنقولة والمصفرة إجبارياً قبل إنشاء السجل الجديد';
  @override String cloneSourceReferenceLabel(dynamic code) => 'الكيان الأصلي: $code';
  @override String get cloneNewCodeLabel => 'الكود المرجعي الجديد المطلوب:';
  @override String get cloneNewCodeRequiredError => 'يرجى إدخال كود فريد للكيان المستنسخ';
  @override String get cloneCopiedFieldsHeader => 'البيانات المنقولة تلقائياً (نسخ متطابق)';
  @override String get cloneResetFieldsHeader => 'البيانات المصفرة إجبارياً (لا تُنقل مطلقاً)';
  @override String get cloneFieldStatusDraftBadge => 'الحالة: تعود تلقائياً إلى مسودة';
  @override String get cloneFieldCustomsClearedReset => 'حالة الإفراج الجمركي: ملغاة (غير مفرج عنه)';
  @override String get cloneFieldFinancialReset => 'أرقام أذون الصرف ونموذج 4 والرقم المبدئي: مصفرة';
  @override String get cloneCopyInvoicesCheckbox => 'نسخ بيانات بنود الفواتير وقوائم التعبئة التقديرية';
  @override String get cloneCopyAttachmentsCheckbox => 'نسخ المرفقات والملفات الرقمية المرفوعة (غير محبذ افتراضياً)';
  @override String get cloneConfirmAndCreateBtn => 'تأكيد الاستنساخ وإنشاء السجل';
  @override String clonedFromBadge(dynamic code) => 'مستنسخ من: $code';
  @override String clonedSuccessfullyToast(dynamic code) => 'تم استنساخ الكيان بنجاح بالكود الجديد ($code)';
  @override String get clonePriceListDialogTitle => 'استنساخ لائحة أسعار مخلص جمركي';
  @override String get cloneImportFileDialogTitle => 'استنساخ ملف شحنة استيراد';
  @override String get cloneConsultationDialogTitle => 'استنساخ دراسة استشارية جمركية';
  @override String get clonePriceListActionTooltip => 'استنساخ اللائحة بالكامل';
  @override String get cloneRowActionTooltip => 'استنساخ السطر الحالي';
  @override String get clonePurchaseOrderDialogTitle => 'استنساخ أمر الشراء';
  @override String get searchAndClonePoBtn => 'بحث واستنساخ أمر شراء';
  @override String get searchAndClonePoDialogTitle => 'بحث واستنساخ أمر شراء';
  @override String get searchAndClonePoSubtitle => 'اختر أمر الشراء المراد استنساخه مع تصفير الشحنات والتخصيصات';
  @override String get searchByPoOrSupplierOrItemHint => 'ابحث برقم أمر الشراء، المرجع، المورد، الشركة، المشروع...';
  @override String get noMatchingPosFound => 'لم يتم العثور على أي أوامر شراء مطابقة';
  @override String clonePoSuccess(dynamic code) => 'تم استنساخ أمر الشراء $code بنجاح';
  @override String clonePoError(dynamic error) => 'فشل استنساخ أمر الشراء: $error';
  @override String get cloneRowItemTooltip => 'تكرار / استنساخ البند (Ctrl + D)';
  @override String get clonePackingItemTooltip => 'تكرار / استنساخ طرد التعبئة';
  @override String get lineItemClonedSuccess => 'تم تكرار البند بنجاح';
  @override String get packingItemClonedSuccess => 'تم تكرار طرد التعبئة بنجاح';
  @override String get cloneFieldAllocationsReset => 'تصفير تخصيصات الشحن الجزئي';
  @override String get cloneFieldShipmentUnlinked => 'فك الارتباط بملف الاستيراد السابق';
  @override String get searchAndCloneCbmBtn => 'بحث واستنساخ دراسة CBM';
  @override String get cloneCbmDialogTitle => 'استنساخ دراسة حساب الحجم CBM';
  @override String get searchAndCloneCbmDialogTitle => 'بحث واستنساخ دراسة حساب الحجم';
  @override String get searchAndCloneCbmSubtitle => 'ابحث عن دراسة سابقة واستنسخ مواصفات الطرود كقالب جديد';
  @override String get searchByCalcCodeOrTitleHint => 'ابحث بكود الدراسة، العنوان، ملاحظات البضاعة، أو وسيلة الشحن...';
  @override String get noMatchingCalcsFound => 'لم يتم العثور على أي دراسات حساب حجم مطابقة';
  @override String cloneCbmSuccess(dynamic code) => 'تم استنساخ دراسة CBM بنجاح كمسودة جديدة باسم [$code]';
  @override String cloneCbmError(dynamic error) => 'فشل استنساخ دراسة CBM: $error';
  @override String get cloneQuickItemTooltip => 'استنساخ هذا الطرد (Ctrl + D)';
  @override String get cargoItemClonedSuccess => 'تم استنساخ الطرد وتحديث الحسابات آلياً';
  @override String get cloneFieldCalcCodeGenerated => 'توليد كود دراسة جديد آلياً';
  @override String get cloneFieldImportFileReset => 'فك الارتباط بملف الاستيراد';
  @override String get cloneFieldPoReset => 'فك الارتباط بأمر الشراء';

  // ── Screen 4 Shipping Scenarios Clone & Responsive Keys ─────────────────────
  @override String get searchAndCloneStudyBtn => 'بحث واستنساخ دراسة شحن';
  @override String get cloneStudyDialogTitle => 'استنساخ دراسة وسيناريوهات الشحن';
  @override String get searchAndCloneStudyDialogTitle => 'بحث واستنساخ دراسة شحن سابقة';
  @override String get searchAndCloneStudySubtitle => 'ابحث عن دراسة سابقة واستنسخ عروض أسعار النواقل كمسودة جديدة';
  @override String get searchByStudyCodeOrTitleHint => 'ابحث بكود الدراسة، العنوان، الناقل، أو اسم المشروع...';
  @override String get noMatchingStudiesFound => 'لم يتم العثور على أي دراسات شحن مطابقة';
  @override String cloneStudySuccess(dynamic code) => 'تم استنساخ دراسة الشحن [$code] بنجاح كمسودة جديدة';
  @override String cloneStudyError(dynamic error) => 'فشل استنساخ دراسة الشحن: $error';
  @override String get cloneCarrierOptionTooltip => 'استنساخ خيار الناقل (Ctrl + D)';
  @override String get carrierOptionClonedSuccess => 'تم استنساخ خيار الناقل وتحديث المقارنة آلياً';
  @override String get cloneFieldStudyCodeGenerated => 'توليد كود دراسة جديد آلياً';
  @override String get cloneFieldSelectionReset => 'إلغاء ترسية وتحديد الناقل للبدء من جديد';
  @override String get carrierOptionHeader => 'خيار الناقل';

  // ── Screen 6 Customs Consultation Clone & Responsive Keys ─────────────────────
  @override String get searchAndCloneConsultationBtn => 'بحث واستنساخ استشارة';
  @override String get searchAndCloneConsultationDialogTitle => 'بحث واستنساخ استشارة جمركية سابقة';
  @override String get searchAndCloneConsultationSubtitle => 'اختر استشارة سابقة لاستنساخ بنود التعريفة والمستندات في مسودة جديدة';
  @override String get searchByConsultationCodeOrTitleHint => 'ابحث برقم الاستشارة، العنوان، أو المخلص الجمركي...';
  @override String get noMatchingConsultationsFound => 'لم يتم العثور على أي استشارة جمركية مطابقة';
  @override String cloneConsultationSuccess(dynamic code) => 'تم استنساخ الاستشارة الجمركية [$code] بنجاح كمسودة جديدة';
  @override String cloneConsultationError(dynamic error) => 'فشل استنساخ الاستشارة الجمركية: $error';
  @override String get cloneChecklistItemTooltip => 'استنساخ بند المستند الإجرائي (Ctrl + D)';
  @override String get checklistItemClonedSuccess => 'تم استنساخ بند المستند الإجرائي بنجاح';
  @override String get cloneFieldConsultationCodeGenerated => 'توليد كود استشارة جديد آلياً';
  @override String get cloneFieldChecklistReset => 'إعادة ضبط حالة المستندات الإجرائية إلى قيد الانتظار';
  @override String get cloneConsultationTooltip => 'استنساخ هذه الاستشارة الجمركية كمسودة جديدة';
  @override String get searchAndCloneConsultationTooltip => 'البحث في الاستشارات السابقة واستنساخها كدراسة جديدة';

  // ── Screen 8 Financial Approval (Payment Requests) Clone & Responsive Keys ───
  @override String get searchAndClonePaymentRequestBtn => 'بحث واستنساخ طلب سداد';
  @override String get searchAndClonePaymentRequestDialogTitle => 'البحث واستنساخ من طلبات السداد السابقة';
  @override String get searchAndClonePaymentRequestSubtitle => 'اختر طلب سداد معتمد أو سابق لاستنساخ بياناته البنكية والمورد';
  @override String get searchByPaymentCodeOrSupplierHint => 'البحث برقم طلب السداد، اسم المورد، أو ملف الاستيراد...';
  @override String get noMatchingPaymentRequestsFound => 'لا توجد طلبات سداد مطابقة للبحث';
  @override String clonePaymentRequestSuccess(dynamic code) => 'تم استنساخ طلب السداد بنجاح [$code] كمسودة جديدة';
  @override String clonePaymentRequestError(dynamic error) => 'فشل استنساخ طلب السداد: $error';
  @override String get clonePaymentRequestTooltip => 'استنساخ طلب السداد المالي كمسودة جديدة';
  @override String get searchAndClonePaymentTooltip => 'بحث واستنساخ من طلبات السداد السابقة';
  @override String get clonePaymentRequestDialogTitle => 'استنساخ طلب السداد المالي';
  @override String get cloneFieldPaymentCodeGenerated => 'توليد كود طلب سداد جديد تلقائياً';
  @override String get cloneFieldBankingDetailsCopied => 'نسخ بيانات الحساب البنكي والسويفت للمورد';
  @override String get cloneFieldPaymentStatusReset => 'إعادة الحالة تلقائياً إلى مسودة Draft';
  @override String get cloneFieldSwiftReceiptReset => 'تصفير إيصالات السداد وبيانات التحويل المنفذ';
  @override String get clonePoAllocationTooltip => 'استنساخ تخصيص أمر الشراء';
  @override String get poAllocationClonedSuccess => 'تم استنساخ أمر الشراء بنجاح';

  // ── Screen 9 Financial Approval (Import Budget) Clone & Responsive Keys ───
  @override String get searchAndCloneBudgetBtn => 'بحث واستنساخ اعتماد ميزانية';
  @override String get searchAndCloneBudgetDialogTitle => 'البحث واستنساخ من الميزانيات الاستيرادية السابقة';
  @override String get searchAndCloneBudgetSubtitle => 'اختر ميزانية معتمدة أو سابقة لاستنساخ هيكل التكاليف ومعدلات الصرف';
  @override String get searchByBudgetCodeOrTitleHint => 'البحث برقم الميزانية، العنوان، أو كود ملف الاستيراد...';
  @override String get noMatchingBudgetsFound => 'لا توجد ميزانيات مطابقة للبحث';
  @override String cloneBudgetSuccess(dynamic code) => 'تم استنساخ الميزانية الاستيرادية بنجاح ($code) كمسودة جديدة';
  @override String cloneBudgetError(dynamic error) => 'فشل استنساخ الميزانية الاستيرادية: $error';
  @override String get cloneBudgetTooltip => 'استنساخ الميزانية الاستيرادية';
  @override String get searchAndCloneBudgetTooltip => 'بحث واستنساخ اعتماد ميزانية استيرادية';
  @override String get cloneBudgetDialogTitle => 'استنساخ الميزانية الاستيرادية';
  @override String get cloneFieldBudgetCodeGenerated => 'توليد كود ميزانية جديد تلقائياً';
  @override String get cloneFieldBudgetStatusReset => 'إعادة الحالة تلقائياً إلى قيد المراجعة / مسودة';
  @override String get cloneFieldCertificationsReset => 'تصفير بيانات الاعتماد والمصادقة وتاريخها';
  @override String get cloneFieldExchangeRatesCopied => 'نسخ هيكل تقديرات التكاليف ومعدلات الصرف';

  // ── Import Files Search, Clone & Dialogs Hardening ─────────────────────────
  @override String get searchAndCloneImportFileBtn => 'بحث واستنساخ شحنة';
  @override String get searchAndCloneImportFileDialogTitle => 'بحث واستنساخ ملف شحنة';
  @override String get searchAndCloneImportFileSubtitle => 'اختر الشحنة المراد استنساخها مع تصفير ACID وحالة الجمارك تلقائياً';
  @override String get searchAndCloneImportFileHint => 'ابحث برقم الملف، اسم الشركة، المورد، أو أمر الشراء...';
  @override String resultsWithCount(dynamic count) => 'النتائج ($count)';
  @override String get noMatchingShipmentsFound => 'لم يتم العثور على أي شحنات مطابقة';
  @override String get cloneFieldAcidReset => 'تصفير رقم وتاريخ ACID المسبق';
  @override String get portsOfLoadingAndDischarge => 'الموانئ (الشحن ← التفريغ)';
  @override String get smartChecklistTooltip => 'قائمة التحقق التشغيلية الذكية للشحنة';
  @override String get moreToolsTooltip => 'أدوات إضافية';
  @override String confirmDeleteImportFilePrompt(dynamic code) => 'هل أنت متأكد من حذف ملف الاستيراد $code؟';
  @override String get cloneBtn => 'استنساخ';
  @override String get selectCompanyValidation => 'يرجى اختيار الشركة المستوردة المصرية';
  @override String get selectSupplierValidation => 'يرجى اختيار المورد الأجنبي';
  @override String get ownerFieldRequired => 'مسؤول المشروع مطلوب';
  @override String get ownerFieldHint => 'اسم الشخص أو مسؤول المتابعة للمشروع';
  @override String get containerStackableTab => '📦 1. قابل للرص';
  @override String get containerNonStackableTab => '🚫 2. غير قابل للرص';
  @override String get containerMixedTab => '🔀 3. مزيج يقبل ولا يقبل';
  @override String get woodenFloorPallets => '🪵 طبالي خشبية أرضية';
  @override String get internalDimensionsPrefix => 'الأبعاد الداخلية:';
  @override String get containerOptionsAnalysisTitle => 'تحليل خيارات الحاويات وسيناريوهات التحميل';
  @override String get closeDiagramBtn => 'إغلاق المخطط';
  @override String get approvedRecommendationPrefix => 'التوصية المعتمدة:';
  @override String get oversizedItemsWarning => 'الأصناف التالية تفوق سعة حاويات الشحن:';
  @override String get failedToFetchRfqData => 'فشل جلب بيانات طلب الأسعار من الخادم.';
  @override String get generatingRfqTemplatesLoading => 'جاري تجميع تفاصيل الشحنة وتوليد نماذج الأسعار...';

  // ── KB-GUIDE-012 Smart Shipment Experience Guide & Reference Card ───────────
  @override String get experienceGuideTitle => 'دليل خبرة المنتج والشحنة الذكي';
  @override String get smartReferenceCardTitle => 'المرجع الذكي المختصر للشحنة';
  @override String get addGuideEntryBtn => 'إضافة ملاحظة للدليل';
  @override String get manageGuideEntriesBtn => 'إدارة دليل الخبرة المؤسسية';
  @override String get guideCriticalAlertTitle => 'تنبيه إلزامي حرج من واقع دليل الخبرة';
  @override String get guideWarningAlertTitle => 'تحذير إجرائي من دليل الخبرة';
  @override String get guideMandatoryPortAlert => 'ميناء الوصول الإلزامي المقيد:';
  @override String get guideRequiredDocsAlert => 'المستندات الإلزامية المطلوبة مسبقا:';
  @override String get guideAutoApplyPortBtn => 'تطبيق الميناء الإلزامي تلقائيا';
  @override String get guideAddSuggestedNoteBtn => 'إدراج التوجيه في ملاحظات الملف';
  @override String get guideAppliedPortSuccess => 'تم تحديد ميناء الوصول الإلزامي بنجاح';
  @override String get guideNoteInsertedSuccess => 'تم إدراج توجيه الخبرة في ملاحظات الملف بنجاح';
  @override String get refCardProductSection => 'بيانات الصنف والكمية';
  @override String get refCardRouteSection => 'مسار الشحن والناقل';
  @override String get refCardDatesSection => 'التواريخ الحرجة وفترات السماح';
  @override String get refCardDocsSection => 'جاهزية المستندات الجمركية';
  @override String get refCardCostSection => 'مقارنة التكلفة التقديرية والفعلية';
  @override String get refCardMatchedGuideSection => 'توجيهات دليل الخبرة المطابقة';
  @override String get refCardHsCodeLabel => 'بند التعريفة الجمركية:';
  @override String get refCardCategoryLabel => 'تصنيف الصنف:';
  @override String get refCardTotalCbmLabel => 'إجمالي الحجم بالمتر المكعب:';
  @override String get refCardGrossWeightLabel => 'الوزن الإجمالي بالكيلوجرام:';
  @override String get refCardPackagesCountLabel => 'إجمالي عدد الطرود:';
  @override String get refCardPolLabel => 'ميناء الشحن:';
  @override String get refCardPodLabel => 'ميناء الوصول والتفريغ:';
  @override String get refCardCarrierLabel => 'الخط الملاحي والناقل:';
  @override String get refCardFreeDaysLabel => 'أيام السماح للحاويات:';
  @override String get refCardEstCostLabel => 'التكلفة التقديرية:';
  @override String get refCardActualCostLabel => 'التكلفة الفعلية المفوتورة:';
  @override String get refCardVarianceLabel => 'فروق التكلفة:';
  @override String get refCardDocsCompleteBadge => 'المستندات مكتملة بالكامل';
  @override String get refCardDocsPendingBadge => 'مستندات معلقة ومطلوبة';
  @override String get refCardCooAttachedBadge => 'شهادة المنشأ مرفقة ومصدقة';
  @override String get refCardCooMissingBadge => 'شهادة المنشأ غير مرفقة (مطلوبة إجباريا)';
  @override String get guideEntryTitleLabel => 'عنوان الملاحظة والتوجيه';
  @override String get guideEntryContentLabel => 'تفاصيل الخبرة والاشتراطات الإلزامية';
  @override String get guideEntryTypeLabel => 'نوع التوجيه';
  @override String get guideSeverityLabel => 'مستوى الأهمية والخطورة';
  @override String get guideScopesHeader => 'نطاقات التطبيق والربط التلقائي';
  @override String get guideAddScopeBtn => 'إضافة نطاق تطابق';
  @override String get guideEntrySavedSuccess => 'تم حفظ توجيه الخبرة الجديد في الذاكرة المؤسسية بنجاح';
  @override String get guideEntryDeleteConfirm => 'هل أنت متأكد من حذف هذا التوجيه من دليل الخبرة؟';
  @override String get copyReferenceCardTooltip => 'نسخ بيانات المرجع المختصر للشحنة إلى الحافظة';
  @override String get referenceCardCopiedSuccess => 'تم نسخ بيانات المرجع الذكي للشحنة بنجاح';
  @override String get guideHsCode => 'بند التعريفة الجمركية';
  @override String get guideMatchButton => 'فحص توجيهات الخبرة لهذا الصنف';
  @override String get guideProductCategory => 'تصنيف الصنف';
  @override String get guideMatchResultLabel => 'توجيهات الخبرة المتطابقة';

  // ── KB-INQ-013 Smart Shipment Inquiry, History & Cloning Screen ────────────
  @override String get inqScreenTitle => 'استعلام وسجل الشحنات والتكاليف التاريخية';
  @override String get inqFilterPanelTitle => 'شريط الفلاتر والبحث المتقدم';
  @override String get inqSupplier => 'المورد الأجنبي';
  @override String get inqAllSuppliers => 'جميع الموردين الأجانب';
  @override String get inqImporter => 'الشركة المستوردة';
  @override String get inqAllImporters => 'جميع الشركات المستوردة';
  @override String get inqHsCodeOrProduct => 'بند التعريفة الجمركية أو كود أو وصف الصنف';
  @override String get inqHsCodeHint => 'ابحث برقم البند أو اسم الصنف أو الكود';
  @override String get inqIncoterm => 'شرط التسليم';
  @override String get inqAllIncoterms => 'جميع الشروط التجارية';
  @override String get inqPortOfLoading => 'ميناء الشحن';
  @override String get inqPortOfDischarge => 'ميناء الوصول';
  @override String get inqShippingMode => 'أسلوب الشحن والحاوية';
  @override String get inqAllShippingModes => 'جميع أساليب الشحن';
  @override String get inqCarrier => 'الخط الملاحي أو شركة الشحن';
  @override String get inqDateRange => 'نطاق التاريخ';
  @override String get inqAllDates => 'كافة الفترات';
  @override String get inqSearchBtn => 'بحث';
  @override String get inqResetBtn => 'إعادة ضبط';
  @override String get inqAdvancedFilters => 'فلاتر إضافية ولوجستية';
  @override String get inqHideAdvancedFilters => 'إخفاء الفلاتر الإضافية';
  @override String get inqExportPrintBtn => 'طباعة أو تصدير التقرير';
  @override String get inqExportExcelBtn => 'تصدير إكسيل';
  @override String get inqExportPdfBtn => 'طباعة تقرير رسمي';
  @override String get inqSaveFilterPreset => 'حفظ الفلتر كبحث مفضل';
  @override String get inqPresetSaved => 'تم حفظ معايير الفلترة المفضلة بنجاح';
  @override String get inqColShipmentName => 'اسم الشحنة';
  @override String get inqColSupplier => 'المورد الأجنبي';
  @override String get inqColImporter => 'الشركة المستوردة';
  @override String get inqColItemAndHs => 'الصنف وبند التعريفة';
  @override String get inqColRoute => 'مسار الشحن';
  @override String get inqColShippingMode => 'أسلوب الشحن والحاوية';
  @override String get inqColIncoterm => 'شرط الشحن';
  @override String get inqColFreightCost => 'سعر النولون';
  @override String get inqColActions => 'الإجراءات';
  @override String get inqActionClone => 'استنساخ ذكي';
  @override String get inqActionDetails => 'عرض التفاصيل';
  @override String get inqTotalMatchingShipments => 'إجمالي الشحنات المطابقة';
  @override String get inqAverageFreightCost => 'متوسط سعر النولون';
  @override String get inqTotalIncurredCost => 'إجمالي التكاليف المسجلة';
  @override String get inqCloneDialogTitle => 'الاستنساخ الذكي للشحنة';
  @override String get inqCloneSuccessHeader => 'تم استنساخ بيانات الشحنة كقالب بنجاح، يُرجى مراجعة التواريخ والأسعار الجديدة قبل الحفظ';
  @override String get inqCloneCopiedDataTitle => 'البيانات المنسوخة تلقائياً';
  @override String get inqCloneClearedDataTitle => 'بيانات تتطلب إدخالاً جديداً';
  @override String get inqCloneLastRecordedCost => 'آخر سعر مسجل';
  @override String get inqCloneNewShipmentName => 'اسم العملية أو الشحنة الجديدة';
  @override String get inqCloneNewFileCode => 'كود ملف الاستيراد الجديد';
  @override String get inqCloneNewInvoiceNumber => 'رقم الفاتورة المبدئية أو النهائية';
  @override String get inqCloneNewFreightCost => 'سعر النولون الجديد';
  @override String get inqCloneConfirmBtn => 'تأكيد واستنساخ الشحنة';
  @override String get inqCloneOpenFormBtn => 'فتح النموذج للتعديل الشامل';
  @override String get inqReportTitle => 'سجل حركة الشحن والتكاليف التاريخية';
  @override String get inqReportGeneratedAt => 'تاريخ ووقت استخراج التقرير';
  @override String get inqReportGeneratedBy => 'المستخدم';

  // ── Screen 68: Smart Shipment Inquiry Additions ────────────────────────────
  @override String get inqSubtitle => 'استعلام تفصيلي شامل وسجل أسعار النولون التاريخية والاستنساخ الذكي للشحنات المتكررة';
  @override String get inqLiveRefreshTooltip => 'تحديث البيانات حيا من السيرفر';
  @override String get inqLoadError => 'خطأ في تحميل الشحنات: ';
  @override String get inqAllRegisteredShipments => 'جميع الشحنات المسجلة';
  @override String get inqSearchPrefix => 'بحث: ';
  @override String get inqOperatorManagerDefault => 'مدير العمليات';
  @override String get inqExportTsvBtn => 'تصدير جدول بتاب';
  @override String get inqCopyDossierTooltip => 'نسخ ملخص الحافظة النصي بالكامل';
  @override String get inqResultsTableTitle => '١. جدول استعلام وسجل الشحنات والتكاليف التاريخية';
  @override String inqShowingMatchingCount(int count) => 'عرض $count شحنة مطابقة';
  @override String get inqEmptyShipmentsTitle => 'لا توجد شحنات مطابقة لمعايير البحث الحالية';
  @override String get inqCopyCodeTooltip => 'نسخ كود الشحنة';
  @override String get inqCopyRowTooltip => 'نسخ ملخص الصف';
  @override String get inqCopiedCodeSuccess => 'تم نسخ كود الشحنة إلى الحافظة';
  @override String get inqCopiedRowSuccess => 'تم نسخ ملخص الصف إلى الحافظة';
  @override String get inqCopiedDossierSuccess => 'تم نسخ ملخص استعلام الشحنات إلى الحافظة';
  @override String get inqCopiedTsvSuccess => 'تم تصدير ملف الجدول بنجاح';
  @override String get inqCopiedExcelSuccess => 'تم تصدير ملف إكسيل بنجاح';
  @override String get inqCurrencyUsd => 'دولار أمريكي';
  @override String get inqCurrencyEur => 'يورو';
  @override String get inqCurrencyEgp => 'جنيه مصري';
  @override String get inqIncotermExw => 'تسليم المصنع';
  @override String get inqIncotermFob => 'على ظهر السفينة';
  @override String get inqIncotermCfr => 'أجرة النقل مدفوعة';
  @override String get inqIncotermCif => 'أجرة النقل والتأمين مدفوعين';
  @override String get inqIncotermCip => 'أجرة النقل والتأمين مدفوعين إلى';
  @override String get inqIncotermDpu => 'مكان التسليم مفرغ';
  @override String get inqIncotermDap => 'التسليم في المكان';
  @override String get inqIncotermDdp => 'تسليم مع دفع الرسوم';
  @override String get inqModeSeaFcl => 'بحري كلي';
  @override String get inqModeSeaLcl => 'بحري جزئي مشترك';
  @override String get inqModeAir => 'شحن جوي';
  @override String get inqModeLand => 'نقل بري';
  @override String get inqAllModes => 'جميع أساليب الشحن';
  @override String inqCloneDialogSubtitle(String code) => 'استنساخ الشحنة $code كقالب تشغيلي';
  @override String inqCloneSuccessBanner(String code) => 'تم استنساخ بيانات الشحنة $code بنجاح، يرجى مراجعة التواريخ والأسعار الجديدة قبل الحفظ';
  @override String get inqCloneCopyInvoicesLabel => 'نسخ بنود الفاتورة كأصناف مبدئية';
  @override String get inqCloneCopyPackingListsLabel => 'نسخ أوزان وأحجام قائمة التعبئة';
  @override String get inqCloneValidationName => 'يرجى إدخال اسم الشحنة الجديدة';
  @override String get inqCloneValidationCode => 'يرجى إدخال كود الشحنة الجديد';
  @override String get inqCloneInvoiceHint => 'رقم الفاتورة الجديد اختياري الآن';
  @override String get inqCloneNotesLabel => 'ملاحظات وتوجيهات الشحنة';
  @override String inqCloneSuccessToast(String code) => 'تم استنساخ الشحنة بنجاح برقم: $code';
  @override String inqCloneTemplateDefaultNote(String code) => 'مستنسخة كقالب من الشحنة: $code';
  @override String get inqCloneNewShipmentSuffix => '(نسخة جديدة)';
  @override String get inqExportTsvDialogTitle => 'تصدير جدول استعلام الشحنات';
  @override String get inqExportExcelDialogTitle => 'تصدير بيانات الاستعلام إلى إكسيل';
  @override String get inqExportPdfDialogTitle => 'تقرير وسجل حركة الشحن والتكاليف التاريخية';
  @override String get inqPdfSystemBranding => 'منظومة إدارة الاستيراد واللوجستيات المتقدمة — شركة سرور للوجستيات';
  @override String get inqPdfOfficialBadge => 'سجل تاريخي رسمي';
  @override String get inqPdfFilterCriteria => 'معايير البحث المستخدمة: ';
  @override String inqPdfPageOf(int page, int total) => 'صفحة $page من $total';
  @override String get inqTsvHeaderFileCode => 'كود الملف';
  @override String get inqTsvHeaderCurrency => 'العملة';
  @override String get inqTsvHeaderDate => 'التاريخ';
  @override String get inqDossierCriteria => 'معايير البحث: ';
  @override String inqDossierKpiSummary(int count, String total, String avg) => '$count شحنة مطابقة | إجمالي التكلفة: $total | متوسط النولون: $avg';
  @override String get inqDossierRowSupplier => 'المورد';
  @override String get inqDossierRowImporter => 'المستورد';
  @override String get inqDossierRowItemAndHs => 'الصنف وبند التعريفة';
  @override String get inqDossierRowRoute => 'المسار';
  @override String get inqDossierRowShippingMode => 'أسلوب الشحن';
  @override String get inqDossierRowIncoterm => 'شرط التسليم';
  @override String get inqDossierRowFreight => 'النولون';

  // ── UX-SEARCH-013: Advanced Search & Unified Shipment Reference ──────────
  @override String get inqInsightModeRoute => 'المسار المعتاد';
  @override String get inqInsightModeShippingMode => 'طريقة الشحن المعتادة';
  @override String get inqInsightLatestFreight => 'آخر سعر نولون';
  @override String get inqInsightLatestFreightNote => 'أحدث شحنة مسجلة للتفاوض';
  @override String get inqInsightAvgLandedCost => 'متوسط التكلفة النهائية';
  @override String get inqInsightMatchingCount => 'عدد الشحنات المطابقة';
  @override String get inqInsightBarTitle => 'شريط الملخص الذكي ومؤشرات الشحن';
  @override String get inqColFinalCost => 'التكلفة النهائية';
  @override String get inqColStatus => 'الحالة';
  @override String get inqColDate => 'التاريخ';
  @override String get inqPrintRowTooltip => 'طباعة ملخص هذا الصف فقط';
  @override String get inqFilterStatus => 'حالة الشحنة';
  @override String get inqAllStatuses => 'كل الحالات';
  @override String get inqStatusDraft => 'مسودة';
  @override String get inqStatusInProgress => 'جارية';
  @override String get inqStatusCompleted => 'مكتملة';
  @override String get inqStatusClosed => 'مغلقة';
  @override String get inqStatusDelayed => 'متأخرة';
  @override String get inqPrintSingleSummaryTitle => 'بطاقة ملخص الشحنة المرجعية';
  @override String get inqPdfSingleShipmentHeader => 'بيان ملخص الشحنة المرجعية المستعلم عنها';

  @override String get themeToggleTooltip => 'تبديل المظهر الداكن والنهاري';
  @override String get darkMode => 'الوضع الداكن';
  @override String get lightMode => 'الوضع النهاري';
  @override String get systemMode => 'حسب إعدادات النظام';

  // ── Desktop Command Palette ──
  @override String get commandPaletteTitle => 'لوحة الأوامر والبحث الشامل للمشغل المحترف';
  @override String get commandPaletteSearchHint => 'ابحث عن شاشة أو إجراء سريع أو ملف شحنة أو مورد أو بند تعريفة...';
  @override String get commandPaletteCategoryScreens => 'الشاشات ومراحل دورة العمل';
  @override String get commandPaletteCategoryActions => 'الإجراءات والأدوات السريعة';
  @override String get commandPaletteCategoryRecords => 'السجلات والبيانات التشغيلية';
  @override String get commandPaletteNoResults => 'لا توجد نتائج مطابقة لبحثك';
  @override String get commandPaletteKeyboardNavHint => 'استخدم الأسهم للتنقل، وزر الإدخال للفتح، وزر الهروب للإغلاق';
  @override String get commandPaletteShortcutTooltip => 'لوحة الأوامر والبحث الشامل الفوري';
  @override String get commandPaletteOpenScreenAction => 'فتح الشاشة في مساحة العمل';
  @override String get commandPaletteQuickAction => 'تشغيل فوري للأداة';

  // ── Desktop Shortcuts & Power-User Suite ──
  @override String get keyboardShortcutsTitle => 'دليل اختصارات لوحة المفاتيح';
  @override String get keyboardShortcutsSubtitle => 'مرجع الاختصارات السريعة للمشغل المحترف لزيادة الإنتاجية';
  @override String get shortcutsCategoryNavigation => 'التنقل ومساحة العمل';
  @override String get shortcutsCategoryOperations => 'العمليات والبيانات';
  @override String get shortcutsCategoryProductivity => 'المساعدة والإنتاجية';
  @override String get shortcutCommandPalette => 'فتح لوحة الأوامر والبحث الشامل';
  @override String get shortcutNextTab => 'الانتقال إلى التبويب التالي في مساحة العمل';
  @override String get shortcutPreviousTab => 'الانتقال إلى التبويب السابق في مساحة العمل';
  @override String get shortcutCloseTab => 'إغلاق التبويب النشط الحالي';
  @override String get shortcutToggleFullscreen => 'تبديل وضع ملء الشاشة أو الاستعادة';
  @override String get shortcutEscape => 'إغلاق النوافذ المنبثقة والقوائم';
  @override String get shortcutSave => 'حفظ فوري للبيانات أو الجلسة النشطة';
  @override String get shortcutNewRecord => 'فتح نموذج إضافة سجل جديد للشاشة الحالية';
  @override String get shortcutCloneRow => 'استنساخ الصف أو البند المحدد وإدراجه';
  @override String get shortcutSearchTable => 'التركيز السريع على حقل البحث في الجدول';
  @override String get shortcutShowHelp => 'عرض دليل اختصارات لوحة المفاتيح';
  @override String get fullscreenEnabledToast => 'تم تفعيل وضع ملء الشاشة';
  @override String get fullscreenDisabledToast => 'تم الخروج من وضع ملء الشاشة';

  // ── Unsaved Changes Guard ──
  @override String get unsavedChangesTitle => 'تنبيه تعديلات غير محفوظة';
  @override String get unsavedChangesMessage => 'توجد تعديلات لم يتم حفظها بعد في هذه الشاشة. هل تريد تجاهل التغييرات والمتابعة أم البقاء للحفظ؟';
  @override String get unsavedChangesDiscardBtn => 'تجاهل التعديلات والمتابعة';
  @override String get unsavedChangesSaveBtn => 'حفظ التعديلات أولاً';
  @override String get unsavedChangesCancelBtn => 'البقاء في الشاشة';
  @override String get unsavedChangesBadgeTooltip => 'توجد تعديلات غير محفوظة في هذا التبويب';

  // ── Enterprise Multi-Pane Layout ──
  @override String get multiPaneSelectPrompt => 'حدد عنصرا من القائمة الجانبية لمعاينة التفاصيل الكاملة والوثائق المرتبطة';
  @override String get multiPaneCollapseSidebar => 'طي القائمة الجانبية';
  @override String get multiPaneExpandSidebar => 'إظهار القائمة الجانبية';
  @override String get multiPaneBackToList => 'العودة إلى القائمة';
  @override String get multiPaneSidebarTitle => 'قائمة العناصر';
  @override String get multiPaneDetailsTitle => 'لوحة التفاصيل المعمقة';

  // ── PO Balance & Partial Shipments Ledger ──
  @override String get poBalanceLedgerTitle => 'ميزان أمر الشراء والشحنات الجزئية (PO Balance & Partial Shipments Ledger)';
  @override String poBalanceSubTitle(String poCode, String fulfillment) => 'أمر الشراء: $poCode  •  نسبة استيفاء التوريد: $fulfillment%';
  @override String get poBalanceFullyShipped => '✅ تم استيفاء شحن كامل أمر الشراء (100%)';
  @override String get poBalancePartialInProgress => '⏳ جاري استكمال شحن الدفعات الجزئية';
  @override String get poBalanceTotalOrderedQty => 'إجمالي الكميات المطلوبة';
  @override String get poBalanceActuallyShippedQty => 'الكميات المشحونة فعلياً';
  @override String get poBalanceRemainingQty => 'الرصيد المتبقي للتوريد';
  @override String get poBalanceUnit => 'وحدة';
  @override String poBalanceValue(String val) => 'القيمة: $val';
  @override String get poBalanceLineItemsTitle => '📋 تفصيل ميزان بنود أمر الشراء (Line Items Balance):';
  @override String get poBalanceColItemCode => 'كود البند';
  @override String get poBalanceColDescription => 'الوصف';
  @override String get poBalanceColOrderedQty => 'الكمية المطلوبة';
  @override String get poBalanceColShippedQty => 'المشحون';
  @override String get poBalanceColRemaining => 'المتبقي';
  @override String get poBalanceColStatus => 'الحالة';
  @override String get poBalanceStatusCompleted => 'مكتمل ✅';
  @override String get poBalanceStatusPartial => 'متبقي جزئي ⏳';
  @override String get poBalanceLoading => 'جاري احتساب ميزان الشحن...';
  @override String poBalanceLoadError(String err) => 'تعذر تحميل ميزان أمر الشراء: $err';

  // ── Container Demurrage Radar (TR-02) ──
  @override String get demurrageRadarCardTitle => 'رادار مراقبة فترات السماح وتفادي غرامات الحاويات (TR-02)';
  @override String get demurrageRadarCardSubtitle => 'متابعة حية لفترات السماح المجانية للخطوط الملاحية وأرضيات الموانئ لمنع الغرامات';
  @override String get demurrageRadarRefreshTooltip => 'تحديث الرادار';
  @override String get demurrageRadarOpenScreenBtn => 'فتح شاشة الغرامات';
  @override String get demurrageRadarSafeBadge => 'آمن داخل السماح';
  @override String get demurrageRadarWarningBadge => 'تحذير 72 ساعة';
  @override String get demurrageRadarActiveFinesBadge => 'غرامات سارية';
  @override String get demurrageRadarReturnedBadge => 'تم الإرجاع';
  @override String demurrageRadarExposureBanner(String usd, String egp, String total) =>
      'إجمالي الغرامات الجارية: \$$usd غرامات خطوط + $egp ج.م أرضيات (التعرض التقديري: $total ج.م)';
  @override String get demurrageRadarEmptyState =>
      'لا توجد حاويات قيد التتبع حالياً — كافة الشحنات مستقرة داخل فترات السماح.';
  @override String get demurrageRadarCarrierFreeDays => 'سماح الخط الملاحي:';
  @override String demurrageRadarDaysCount(int consumed, int total) => '$consumed / $total يوم';
  @override String get demurrageRadarStatusSafe => 'آمن';
  @override String get demurrageRadarStatusWarning => 'تحذير';
  @override String get demurrageRadarStatusCritical => 'متأخر';
  @override String get demurrageRadarStatusReturned => 'مسترجع';
  @override String get demurrageRadarButtonLabel => 'رادار الغرامات (TR-02)';

  // Screen Photos Localization Fixes
  @override String get smartEmailCheckInboxBtn => 'فحص الصندوق الآن';
  @override String get smartEmailSettingsBtn => 'إعدادات البريد';
  @override String get invoiceBlMatchTabInspect => '⚡ فحص ومطابقة الفاتورة والبوليصة';
  @override String get invoiceBlMatchTabHistory => '📋 سجل جلسات المطابقة السابقة';
  @override String get invoiceBlMatchNewSessionBtn => 'بدء جلسة فحص ومطابقة جديدة';
  @override String get cooSaveDraftSessionBtn => 'حفظ مسودة مؤقتة للجلسة';
  @override String get cooChinaRecommendationAlert => 'بلد المنشأ جمهورية الصين الشعبية — تم اختيار شهادة منشأ الصين (CCPIT) تلقائياً.';
  @override String get cooChinaGeneralExemptionNote => 'المنشأ: China - تخضع الشحنة لضريبة الوارد العامة المقررة بجدول التعريفة الجمركية المصرية وضريبة القيمة المضافة 14%.';
  @override String get cooEuRecommendationAlert => 'بلد المنشأ ضمن دول الاتحاد الأوروبي (27 دولة) — تم اختيار شهادة الحركة EUR.1 تلقائياً للاستفادة من الإعفاء الجمركي التفضيلى الكامل.';
  @override String get cooAgadirGaftaRecommendationAlert => 'بلد المنشأ عضو في اتفاقية أغادير ومنطقة التجارة الحرة العربية (GAFTA) معاً — لا يتم الاختيار تلقائياً، يرجى اختيار نوع الشهادة يدوياً وقت الاستيراد.';

  // ── Backend startup (local backend.exe launch) ──
  @override String get backendStartupStarting => 'جاري تشغيل النظام…';
  @override String get backendStartupStartingHint => 'أول تشغيل بعد التحديث قد يستغرق حتى دقيقة أثناء أخذ نسخة احتياطية من قاعدة البيانات وترقيتها.';
  @override String get backendStartupFailedTitle => 'لم يتم تشغيل النظام';
  @override String get backendStartupFailedMessage => 'الخادم المحلي لم يستجب في الوقت المحدد. اضغط إعادة المحاولة؛ وإذا استمرت المشكلة أعد تشغيل الجهاز أو تواصل مع مسؤول النظام.';
  @override String backendStartupPortInUseMessage(String port) => 'برنامج آخر يستخدم المنفذ $port، لذلك لا يمكن تشغيل خادم النظام. أغلق هذا البرنامج (أو غيّر المنفذ الخاص به) ثم اضغط إعادة المحاولة.';

  // ── In-app updates (app_update) ──
  @override String updateAvailableBanner(String version) => 'يتوفر تحديث جديد للنظام: الإصدار $version';
  @override String updateMandatoryBanner(String version) => 'تحديث إلزامي مطلوب: الإصدار $version. يجب تثبيته لمتابعة العمل.';
  @override String get updateWhatsNew => 'ما الجديد في هذا الإصدار';
  @override String updateSize(String mb) => '$mb ميجابايت';
  @override String get updateInstallNow => 'تثبيت الآن';
  @override String get updateRemindLater => 'ذكّرني لاحقاً';
  @override String updateDownloading(String done, String total) => 'جاري التنزيل… $done من $total ميجابايت';
  @override String get updateVerifying => 'جاري التحقق من البصمة الرقمية للتحديث…';
  @override String get updateBackingUp => 'جاري أخذ نسخة احتياطية من قاعدة البيانات…';
  @override String get updateInstalling => 'جاري تثبيت التحديث، سيُعاد تشغيل البرنامج تلقائياً';
  @override String get updateCancel => 'إلغاء التنزيل';
  @override String updateSucceeded(String version) => 'تم تحديث النظام بنجاح إلى الإصدار $version';
  @override String get updateFailed => 'فشل التحديث';
  @override String get updateRollback => 'التراجع إلى الإصدار السابق';
  @override String updateRollbackWarning(String backupTime) => 'سيتم استرجاع قاعدة البيانات من النسخة الاحتياطية المأخوذة في $backupTime. كل البيانات التي تم إدخالها بعد هذا التوقيت ستُفقد نهائياً.';
  @override String get updateFromFile => 'تحديث من ملف (USB)';
  @override String updateCheckOffline(String lastChecked) => 'تعذّر الاتصال بخادم التحديثات. آخر فحص ناجح: $lastChecked';
  @override String get updateDevModeDisabled => 'التحديث التلقائي غير متاح في وضع التطوير';
  @override String updateDialogTitle(String version) => 'تحديث النظام إلى الإصدار $version';
  @override String get updateDownloadNow => 'تنزيل التحديث';
  @override String get updateReadyToInstall => 'تم تنزيل التحديث والتحقق منه، وهو جاهز للتثبيت. سيتم أخذ نسخة احتياطية من قاعدة البيانات قبل التثبيت.';
  @override String get updateMandatoryNotice => 'هذا التحديث إلزامي (إصلاح أمني أو تغيير في قاعدة البيانات) ولا يمكن تأجيله.';
  @override String get updateAdminOnlyNotice => 'تثبيت التحديثات متاح لمدير النظام فقط. برجاء التواصل مع المدير.';
  @override String get updateSignOut => 'تسجيل الخروج';
  @override String get updateViewDetails => 'عرض التفاصيل';
  @override String get updateRestartingHint => 'لا تغلق الجهاز أثناء التثبيت.';
  @override String get updateRollbackTitle => 'تأكيد التراجع عن التحديث';
  @override String get updateRollbackConfirmCheck => 'أفهم أن البيانات المُدخلة بعد النسخة الاحتياطية ستُفقد';
  @override String get updateRollbackConfirmBtn => 'تأكيد التراجع';
  @override String get updateRollbackNoBackup => 'لا توجد نسخة احتياطية سابقة للتحديث متاحة للتراجع';
  @override String get updatePickManifest => 'اختر ملف الإصدار (manifest.json)';
  @override String get updatePickInstaller => 'اختر ملف التثبيت (.exe)';
  @override String get updateStagedFromFile => 'تم التحقق من ملفات التحديث وهي جاهزة للتثبيت';
  @override String get updateSectionTitle => 'تحديثات البرنامج';
  @override String get updateCheckNow => 'فحص التحديثات';
  @override String updateUpToDate(String version) => 'النظام محدّث (الإصدار $version)';
  @override String get updateInvalidSignature => 'تم رفض ملف الإصدار على الخادم لأن توقيعه غير صالح';
  @override String get updateNeverChecked => 'لم يتم الفحص بعد';
  @override String get updateRetry => 'إعادة المحاولة';
  @override String get updateClose => 'إغلاق';
  @override String get updateFailedRollbackHint => 'لم يكتمل فحص ما بعد التحديث. يمكن لمدير النظام التراجع إلى الإصدار السابق.';
  @override String updateCurrentVersion(String version) => 'الإصدار الحالي: $version';
  @override String get updateNoPermission => 'ليس لديك صلاحية تثبيت تحديثات النظام (مطلوب صلاحية مدير النظام)';
  @override String updateRollbackSucceeded(String version) => 'تم التراجع بنجاح إلى الإصدار $version واسترجاع قاعدة البيانات من النسخة الاحتياطية';
  @override String get updateRollbackFailed => 'فشل التراجع عن التحديث';
  @override String updatePreparingRollbackCopy(String done, String total) => 'جاري تجهيز نسخة التراجع… $done من $total ميجابايت';
  @override String get updatePreparingRollbackCopyShort => 'جاري تجهيز نسخة التراجع…';
  @override String updatePillAvailable(String version) => 'تحديث $version';
  @override String updatePillMandatory(String version) => 'إلزامي $version';
  @override String updatePillDownloading(String percent) => 'تنزيل $percent%';
  @override String get updatePillWorking => 'جاري تجهيز التحديث…';
  @override String get updatePillReady => 'تثبيت';
  @override String updateReadySnack(String version) => 'التحديث $version جاهز للتثبيت';
  @override String updateReadyBanner(String version) => 'تم تنزيل التحديث $version وهو جاهز للتثبيت';
  @override String get updateAdminRequiredTooltip => 'يجب أن يقوم مدير النظام بتثبيت هذا التحديث';
  @override String get updateAboutSectionTitle => 'التحديثات';

  // Domain enum labels (T3 codes, docs/plans/single-language-storage-plan.md).
  static const Map<String, String> _domainEnumLabels = {
    'release_type.FINAL_GREEN': 'إفراج نهائي وبات',
    'release_type.UNDER_BOND': 'إفراج مؤقت تحت التحفظ',
    'release_type.TEMPORARY_ADMISSION': 'إفراج برسم السماح المؤقت',
    'release_type.POST_TESTING_CONFORMING': 'إفراج قطعي بعد استيفاء العينات',
    'payment_method.SADAD_EFINANCE': 'سداد إلكتروني (إي فاينانس)',
    'payment_method.BANK_TRANSFER': 'تحويل بنكي',
    'payment_method.CBE_DIRECT': 'خصم مباشر من البنك المركزي',
    'payment_method.CASHIER_DEPOSIT': 'إيداع بخزينة الجمرك',
    'duty_bank.NBE': 'البنك الأهلي المصري',
    'duty_bank.BM': 'بنك مصر',
    'duty_bank.CIB': 'البنك التجاري الدولي',
    'duty_bank.BDC': 'بنك القاهرة',
    'duty_bank.QNB': 'بنك قطر الوطني الأهلي',
    'duty_bank.CBE': 'البنك المركزي المصري',
    'duty_bank.MTS_CASHIER': 'خزينة مصلحة الجمارك',
    'duty_bank.OTHER': 'أخرى',
    'expense_category.BROKER_FEES': 'أتعاب التخليص الجمركي',
    'expense_category.PORT_DUES_WHARFAGE': 'نولون ورسوم الميناء والرصيف',
    'expense_category.STEVEDORING_HANDLING': 'مصاريف العتالة والشحن والتفريغ',
    'expense_category.INSPECTION_WEIGHING': 'رسوم الفحص والوزن والمعاينة',
    'expense_category.LABORATORY_TESTING': 'مصاريف التحاليل والمعامل',
    'expense_category.STORAGE_DEMURRAGE': 'رسوم الأرضيات وغرامات التأخير',
    'expense_category.OTHER_CLEARANCE': 'مصاريف تخليص أخرى',
    'truck_type.FLATBED': 'تريلا مسطح',
    'truck_type.SIDE_DROP': 'تريلا جوانب',
    'truck_type.CURTAINSIDER': 'تريلا ستارة',
    'truck_type.CONTAINER_CHASSIS': 'شاسيه حاوية 20/40 قدم',
    'truck_type.BOX_TRUCK': 'جامبو مغلق',
    'truck_type.REEFER': 'شاحنة مبردة',
    'truck_type.LOW_BED': 'لوبد ثقيل للطرود الضخمة',
    'regulatory_body.GOEIC': 'الهيئة العامة للرقابة على الصادرات والواردات',
    'regulatory_body.NFSA': 'الهيئة القومية لسلامة الغذاء',
    'regulatory_body.NTRA': 'الجهاز القومي لتنظيم الاتصالات',
    'regulatory_body.CHEMISTRY_DEPT': 'مصلحة الكيمياء',
    'regulatory_body.QUARANTINE': 'الحجر الزراعي / البيطري',
    'regulatory_body.AGRICULTURAL_QUARANTINE': 'الحجر الزراعي',
    'regulatory_body.VETERINARY_QUARANTINE': 'الحجر البيطري',
    'regulatory_body.EDA': 'هيئة الدواء المصرية',
    'regulatory_body.INDUSTRIAL_CONTROL': 'مصلحة الرقابة الصناعية',
    'regulatory_body.ATOMIC_ENERGY': 'الوقاية الإشعاعية وهيئة الطاقة الذرية',
    'regulatory_body.WEIGHTS_MEASURES': 'مصلحة الموازين والدمغة',
    'inspection_yard.ALEXANDRIA_BERTH_42': 'ساحة الفحص المشترك - ميناء الإسكندرية (رصيف 42)',
    'inspection_yard.DEKHEILA': 'ساحة الفحص المشترك - ميناء الدخيلة',
    'inspection_yard.AIN_SOKHNA': 'ساحة الفحص والكشف المشترك - ميناء العين السخنة',
    'inspection_yard.DAMIETTA': 'ساحة المعاينة والكشف - ميناء دمياط البحري',
    'inspection_yard.WEST_PORT_SAID': 'ساحة المعاينة والفحص - ميناء غرب بورسعيد',
    'inspection_yard.EAST_PORT_SAID': 'ساحة الفحص الجمركي - ميناء شرق بورسعيد',
    'inspection_yard.OCTOBER_DRY_PORT': 'ساحة الفحص المشترك بالميناء الجاف بمدينة 6 أكتوبر',
    'inspection_yard.TENTH_RAMADAN_DRY_PORT': 'ساحة الفحص بالميناء الجاف بمدينة العاشر من رمضان',
    'inspection_yard.CAIRO_AIRPORT_CARGO': 'قرية البضائع - مطار القاهرة الدولي',
    'inspection_yard.ADABIYA': 'ساحة الفحص المشترك - ميناء الأدبية بالسويس',
    'depot.ALEXANDRIA_CARRIER_DEPOT': 'مستودع الإسكندرية للحاويات الفارغة',
    'depot.DEKHEILA_YARD': 'ساحة حاويات الدخيلة',
    'depot.SOKHNA_LOGISTICS_DEPOT': 'مستودع السخنة اللوجستي',
    'depot.PORT_SAID_WEST_DEPOT': 'مستودع غرب بورسعيد',
    'depot.DAMIETTA_EMPTY_YARD': 'ساحة دمياط للحاويات الفارغة',
    'depot.SOKHNA_DP_WORLD_YARD': 'ساحة موانئ دبي العالمية بالسخنة',
    'service_category.CLEARANCE_FEE': 'أتعاب التخليص الجمركي',
    'service_category.INLAND_TRANSPORT': 'النقل الداخلي',
    'service_category.INSPECTION_FEE': 'مصاريف الفحص والعرض',
    'service_category.PORT_CHARGES': 'رسوم ومصاريف الموانئ',
    'currency.EGP': 'جنيه',
    'broker_expense_category.CLEARANCE_FEES': 'أتعاب ومصاريف تخليص',
    'broker_expense_category.PROCEDURES_APPROVALS': 'إجراءات وموافقات وفحص',
    'broker_expense_category.INLAND_TRANSPORT': 'نقل بري وشاحنات',
    'broker_expense_category.PORT_HANDLING': 'موانئ وتعتيق وتفريغ',
    'broker_expense_category.OTHER_FEES': 'مصاريف أخرى',
    'broker_unit.FIXED': 'مبلغ ثابت',
    'broker_unit.PER_CONTAINER': 'لكل حاوية',
    'broker_unit.PER_INVOICE': 'لكل فاتورة',
    'broker_unit.PER_SHIPMENT': 'لكل شحنة',
    'broker_unit.PER_DECLARATION': 'لكل إقرار',
    'broker_unit.PER_BL': 'لكل بوليصة شحن',
    'broker_unit.PER_TON': 'لكل طن',
    'broker_unit.PER_VEHICLE': 'لكل سيارة',
    'broker_unit.PER_DAY': 'لكل يوم',
    'broker_unit.PER_NIGHT': 'لكل ليلة',
    'broker_unit.PER_INSPECTION': 'لكل عرض',
    'broker_unit.PER_EXTRA_TON': 'لكل طن إضافي',
    'broker_unit.PER_CONTAINER_20FT': 'لكل حاوية 20 قدم',
    'broker_unit.PER_CONTAINER_40FT': 'لكل حاوية 40 قدم',
    'broker_unit.PER_TRUCK': 'لكل شاحنة',
    'broker_unit.PER_TRIP': 'لكل نقلة',
    'broker_unit.PER_SAMPLE': 'لكل عينة',
    'broker_unit.PER_CASE': 'لكل حالة',
    'broker_unit.PER_TRAILER': 'لكل تريلا',
    'broker_unit.RANGE': 'نطاق سعري',
    'broker_expense_category.OFFICIAL_RECEIPTS': 'إيصالات رسمية للميناء والخط الملاحي',
    'hold_reason.OTHER': 'سبب آخر',
    'hold_reason.AWAITING_SUPPLIER_APPROVAL': 'في انتظار رد وموافقة المورد الخارجي',
    'hold_reason.DRAFT_BL_AMENDMENT': 'طلب تعديل على مسودة بوليصة الشحن',
    'hold_reason.AWAITING_BANK_FORM4': 'في انتظار موافقة البنك وإصدار نموذج 4',
    'hold_reason.PENDING_REGULATORY_APPROVAL': 'استيفاء موافقة جهة العرض والرقابة',
    'hold_reason.BOOKING_DELAYED': 'تأخير الحجز وتأكيد الخط الملاحي',
    'hold_reason.TARIFF_VALUATION_REVIEW': 'مراجعة وتدقيق أسعار بنود التعريفة الجمركية',
    'hold_reason.ADDITIONAL_INSPECTION': 'طلب فحص ومعاينة إضافية للبضاعة',
    'hold_reason.ADMIN_HOLD': 'تعليق إداري مؤقت للشحنة',
    'skip_reason_category.CLIENT_AGREEMENT': 'العميل يتولى الإجراء حسب الاتفاقية',
    'skip_reason_category.NOT_APPLICABLE_TO_MODE': 'لا تنطبق على نمط الشحن',
    'skip_reason_category.REGULATORY_EXEMPTION': 'إعفاء رسمي أو رقابي',
    'skip_reason_category.OTHER': 'أخرى',
    'customs_channel.GREEN': 'المسار الأخضر',
    'customs_channel.RED': 'المسار الأحمر',
    'customs_channel.YELLOW': 'المسار الأصفر',
    'inspection_result.CONFORMING': 'مطابق',
    'inspection_result.DISCREPANCY': 'غير مطابق / به اختلاف',
    'inspection_result.SHORTAGE': 'عجز',
    'inspection_result.SURPLUS': 'زيادة',
    'requirement_status.APPLIED': 'تم التقديم',
    'requirement_status.APPROVED': 'معتمد',
    'requirement_status.COMPLETED': 'مكتمل',
    'requirement_status.EXPIRED': 'منتهي الصلاحية',
    'requirement_status.IN_PROGRESS': 'قيد التنفيذ',
    'requirement_status.NOT_REQUIRED': 'غير مطلوب',
    'requirement_status.OBTAINED': 'تم الاستخراج',
    'requirement_status.PENDING': 'معلق',
    'requirement_status.RECEIVED': 'تم الاستلام',
    'requirement_status.REJECTED': 'مرفوض',
    'requirement_status.VERIFIED': 'تم التحقق',
    'warehouse_inspection_verdict.ACCEPTED_FULL': 'مقبول بالكامل',
    'warehouse_inspection_verdict.ACCEPTED_WITH_DISCREPANCY': 'مقبول مع وجود فروقات',
    'warehouse_inspection_verdict.DAMAGE_CLAIM_PENDING': 'مطالبة تلف قيد المتابعة',
    'warehouse_inspection_verdict.PENDING': 'قيد الفحص',
    'warehouse_inspection_verdict.REJECTED_QUARANTINED': 'مرفوض / تحت الحجز',
    'db_health_verdict.CRITICAL': 'حرجة',
    'db_health_verdict.DEGRADED': 'متدهورة',
    'db_health_verdict.HEALTHY': 'سليمة',
    'alert_severity.CRITICAL': 'حرج',
    'alert_severity.HIGH': 'مرتفع',
    'alert_severity.INFO': 'معلومة',
    'alert_severity.WARNING': 'تحذير',
    'landed_cost_variance_status.ON_BUDGET': 'مطابق للميزانية',
    'landed_cost_variance_status.OVER_BUDGET': 'فوق الميزانية',
    'landed_cost_variance_status.UNDER_BUDGET': 'تحت الميزانية',
    'customs_category.AUTOMOTIVE': 'سيارات ومركبات',
    'customs_category.AUTOMOTIVE_SPARE_PARTS': 'قطع غيار سيارات',
    'customs_category.ELECTRONICS': 'إلكترونيات',
    'customs_category.FOOD_AGRICULTURAL': 'أغذية ومنتجات زراعية',
    'customs_category.GENERAL_GOODS': 'أصناف عامة',
    'customs_category.INDUSTRIAL_MACHINERY': 'آلات صناعية',
    'customs_category.MACHINERY_EQUIPMENT': 'آلات وأجهزة وتجهيزات',
    'customs_category.PHARMACEUTICALS': 'أدوية ومستحضرات دوائية',
    'customs_category.PLASTICS_POLYMERS': 'بلاستيك وبوليمرات',
    'customs_category.RAW_MATERIALS_METALS': 'مواد خام ومعادن',
    'customs_category.TELECOMMUNICATIONS': 'اتصالات',
    'customs_category.TEXTILES': 'منسوجات',
    'draft_bl_field.SHIPPER': 'المصدر والشاحن',
    'draft_bl_field.CONSIGNEE': 'المستورد والمرسل إليه',
    'draft_bl_field.NOTIFY_PARTY': 'جهة الإخطار الرسمية',
    'draft_bl_field.VESSEL_NAME': 'اسم السفينة الناقلة',
    'draft_bl_field.VOYAGE_NUMBER': 'رقم الرحلة البحرية',
    'draft_bl_field.POL': 'ميناء الشحن',
    'draft_bl_field.POD': 'ميناء التفريغ',
    'draft_bl_field.FREIGHT_TERMS': 'شروط نولون الشحن',
    'draft_bl_field.PLACE_OF_DELIVERY': 'مكان التسليم النهائي',
    'draft_bl_field.BOOKING_NO': 'رقم حجز الشحن',
    'draft_bl_field.ACID_NUMBER': 'رقم القيد الجمركي المبدئي',
    'draft_bl_field.IMPORTER_TAX_ID': 'البطاقة الضريبية للمستورد',
    'draft_bl_field.SHIPPER_REG_ID': 'رقم تسجيل المصدر الأجنبي',
    'draft_bl_field.SHIPPING_MODE': 'نمط وسيلة الشحن',
    'draft_bl_field.CONTAINER_SUMMARY': 'بيان الحاويات والأختام الجمركية',
    'draft_bl_field.GOODS_DESCRIPTION': 'بيان التعبئة والوصف التجاري',
    'draft_bl_field.TOTAL_GROSS_WEIGHT_KG': 'الوزن الإجمالي القائم',
    'draft_bl_field.TOTAL_NET_WEIGHT_KG': 'الوزن الصافي',
    'draft_bl_field.CBM': 'الحجم الإجمالي بالمتر المكعب',
    'draft_bl_field.QTY_PKG': 'إجمالي عدد الطرود',
    'value_placeholder.NOT_EXTRACTED': 'لم يتم الاستخراج',
    'value_placeholder.NOT_IN_BL': 'غير موجود بالبوليصة',
    'value_placeholder.NOT_IN_DOCUMENT': 'غير متوفر بالمستند',
    'value_placeholder.NOT_IN_INVOICE': 'غير مذكور بالفاتورة',
    'value_placeholder.NOT_IN_PACKING_LIST': 'غير مدرج بالباكينج',
    'value_placeholder.NOT_SET': 'غير محدد بالسستم',
    'value_placeholder.NOT_SPECIFIED': 'غير محدد',
    'value_placeholder.OPTIONAL_NOT_INCLUDED': 'اختياري / غير مدرج',
    'measure_unit.CBM': 'م³',
    'measure_unit.KG': 'كجم',
    'measure_unit.PACKAGES': 'طرد',
    'measure_unit.PACKAGES_PALLETS': 'طرد/بالتة',
    'measure_unit.GRM': 'جرام (GRM)',
    'measure_unit.SET': 'طقم (SET)',
    'measure_unit.STN': 'طن قصير (STN)',
    'po_status.DRAFT': 'مسودة',
    'po_status.APPROVED': 'معتمد',
    'po_status.PARTIALLY_SHIPPED': 'مشحون جزئيا',
    'po_status.FULLY_SHIPPED': 'مشحون بالكامل',
    'po_status.CLOSED': 'مغلق',
    'po_status.CANCELLED': 'ملغي',
    'shipment_mode.AIR': 'شحن جوي',
    'shipment_mode.SEA': 'شحن بحري',
    'shipping_method.AIR': 'شحن جوي',
    'shipping_method.FCL': 'حاوية كاملة (FCL)',
    'shipping_method.LCL': 'شحن بحري تجميعي (LCL)',
    'container_type.C20_ST': "حاوية 20 قدم عادية (20' ST)",
    'container_type.C40_HC': "حاوية 40 قدم عالية (40' HC)",
    'container_type.C40_ST': "حاوية 40 قدم عادية (40' ST)",
    'container_type.LCL': 'حاوية شحن تجميعي (LCL)',
    'stage.ARCHIVED_CLOSED': 'تم الإغلاق والأرشفة',
    'stage.ARRIVED_AT_WAREHOUSE': 'وصلت المخزن',
    'stage.CLOSED_EARLY': 'مغلق مبكراً',
    'stage.CLOSURE_IN_PROGRESS': 'جاري إغلاق الملف',
    'stage.CUSTOMS_BROKER_AUTHORIZED': 'تفويض المخلص الجمركي',
    'stage.CUSTOMS_DUTY_ASSESSED': 'احتساب الرسوم الجمركية والمطالبة',
    'stage.CUSTOMS_INSPECTION_COMPLETED': 'تم الكشف وسحب العينات',
    'stage.CUSTOMS_RELEASED': 'تم الإفراج الجمركي النهائي وبدء النقل',
    'stage.DELIVERY_ORDER_PAID': 'سداد إذن التسليم الملاحي',
    'stage.DISCREPANCY_PROTOCOL_FILED': 'تم تحرير محضر الفروقات',
    'stage.DRAFT': 'مسودة',
    'stage.DUTY_PAID': 'تم سداد الرسوم الجمركية بسداد',
    'stage.GOODS_RECEIVED': 'تم استلام البضاعة',
    'stage.INLAND_TRANSPORT_BOOKED': 'تم حجز النقل الداخلي',
    'stage.IN_TRANSIT_TO_WAREHOUSE': 'الشحنة في الطريق للمخزن',
    'stage.LAB_APPROVED_RELEASED': 'معتمد معملياً ومفرج عنه نهائياً',
    'stage.LAB_REJECTED': 'مرفوض معملياً',
    'stage.LANDED_COST_CALCULATED': 'تم احتساب تكلفة الوصول',
    'stage.PHASE_1': 'المرحلة الأولى: التخطيط والدراسات المسبقة',
    'stage.PHASE_2': 'المرحلة الثانية: بداية الشحنة',
    'stage.PHASE_3': 'المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي',
    'stage.PHASE_4': 'المرحلة الرابعة: التوثيق الرقمي والاعتماد البنكي',
    'stage.PHASE_5': 'المرحلة الخامسة: عمليات الميناء والتخليص الجمركي',
    'stage.PHASE_6': 'المرحلة السادسة: الاستلام المخزني والتسوية المالية',
    'stage.QC_PASSED': 'اجتاز فحص الجودة - جاهز لتكلفة الوصول',
    'stage.QUARANTINED_UNDER_INSPECTION': 'محجوز تحت الفحص',
    'stage.REOPENED': 'أعيد فتحه',
    'stage.UNDER_BOND_QUARANTINE': 'سحب على عهدة',
    'stage.UNDER_CUSTOMS_CLEARANCE': 'تحت التخليص والكشف 46',
  };

  // ── Phase-1 UI strings: po ──────────────────────────────────────
  @override String get poImportedSuccessfully => 'تم الاستيراد بنجاح';
  @override String get poPOTableCopiedToClipboard => 'تم نسخ بيانات أوامر الشراء بنجاح';
  @override String get poCopyTableTSV => 'نسخ جدول البيانات';
  @override String get poDownloadTemplate => 'تنزيل نموذج إكسل';
  @override String get poImportExcel => 'استيراد من إكسل';
  @override String get poExportPurchaseOrdersExcel => 'تصدير أوامر الشراء إكسيل';
  @override String get poExportPurchaseOrdersPDF => 'تصدير أوامر الشراء PDF';
  @override String get poDownloadPurchaseOrdersTemplate => 'تنزيل نموذج أوامر الشراء';
  @override String get poInvoiceDate => 'تاريخ الفاتورة';
  @override String get poQtyUnit => 'وحدة كمية البنود';
  @override String get poTotalQtyPKG => 'إجمالي عدد الطرود';
  @override String get poQtyPKG => 'عدد الطرود';
  @override String get poPackageType => 'نوع التغليف';
  @override String get poNetWt => 'الصافي (كجم)';
  @override String get poGrossWt => 'القائم (كجم)';
  @override String get poCopyRowForExcelTSV => 'نسخ بيانات السطر لإكسيل';
  @override String get poPOLineItemsSummaryByHS => '📊 ملخص بنود أمر الشراء حسب البند الجمركي';
  @override String get poNetWtKg => 'الصافي (كجم)';
  @override String get poGrossWtKg => 'القائم (كجم)';
  @override String get poDutyVAT => 'نسب الرسوم';
  @override String get poRegulatoryConditionsTradeAgreementsByHS => '🛡️ بطاقات الامتثال والاتفاقيات الجمركية للبند الجمركي (Regulatory Conditions & Trade Agreements)';
  @override String get poInvoicePackingReconciliationDiscrepanciesFound => 'حالة مطابقة الفاتورة والباكينج: يوجد اختلافات في الكميات أو البنود الجمركية';
  @override String get poApprovedJustification => 'المبرر المعتمد:';
  @override String get poPerfectMatchAllProformaInvoiceLine => 'مطابقة تامة: جميع بنود الفاتورة المبدئية متطابقة بالكامل مع بيان التعبئة في الأكواد الجمركية والكميات.';
  @override String get poPackingListValidationErrors => 'أخطاء مطابقة قائمة التعبئة';
  @override String get poPackingListValidationPassedAllWeights => 'تم التحقق من قائمة التعبئة بنجاح — كافة الأوزان والكميات مطابقة';
  @override String po3DContainerLoadSimulationAvailableFor(Object? po, Object? toInt) => 'محاكاة ورص الحاويات 3D متاحة لـ $po صنف ($toInt طرد)';
  @override String get poPurchaseOrderProformaInvoiceDetails => '=== بيانات أمر الشراء / الفاتورة المبدئية ===';
  @override String get poPOReferenceName => 'اسم / مرجع أمر الشراء';
  @override String get poInternalPOCode => 'الرقم الداخلي للنظام';
  @override String get poProformaInvoice => 'رقم الفاتورة المبدئية';
  @override String get poProjectCostCenter => 'المشروع ومركز التكلفة';
  @override String get poIncoterms => 'الشرط التجاري';
  @override String get poFXRate => 'سعر الصرف';
  @override String get poExchangeRateRequired => 'سعر الصرف مطلوب ويجب أن يكون أكبر من الصفر';
  @override String get poExchangeRateHelper => '⚡ يستدعى آلياً حسب تاريخ الفاتورة والعملة';
  @override String poNoExchangeRateForDate(String code, String date) => 'لا يوجد سعر صرف للعملة $code بتاريخ $date';
  @override String get poPaymentTerms => 'شروط الدفع';
  @override String get poTotalCBM => 'إجمالي الحجم CBM';
  @override String get poGrossNetWeight => 'الوزن القائم / الصافي';
  @override String get poPOLineItemsHSCodes => '--- بنود أمر الشراء والأكواد الجمركية ---';
  @override String get poPackingListItems => '--- بيان التعبئة الرسمي ---';
  @override String get poPODetailsCopiedToClipboard => 'تم نسخ كافة بيانات أمر الشراء للحافظة بنجاح ✅';
  @override String get poCBM => 'الحجم CBM';
  @override String get poQtyPcs => 'الكمية (قطع)';
  @override String get poPackingListSummaryByHSCode => '📊 ملخص بيان التعبئة حسب البند الجمركي';
  @override String get poPackingListSummaryByPackageType => '📊 ملخص قائمة التعبئة حسب نوع التغليف';
  @override String get poPurchaseOrder => 'أمر شراء';
  @override String get poInternalPOCode2 => 'الرقم الداخلي';
  @override String get poTotalCBM2 => 'إجمالي CBM';
  @override String get poTotalNetWeight => 'الوزن الصافي الإجمالي';
  @override String get poTotalQtyPKG2 => 'إجمالي الطرود';
  @override String get poPurchaseOrderItemsSpecification => 'بيان بنود أمر الشراء';
  @override String get poNoPackingListOrPalletData => 'لا توجد بيانات تعبئة أو بالتات متاحة للمحاكاة';
  @override String get poPleaseAddPackingListOrPallet => 'يرجى استكمال بنود بيان التعبئة أو البالتات في أمر الشراء لتشغيل مخطط ومحاكاة رص الحاويات 3D';
  @override String get poEditPOAddPackingList => 'تعديل أمر الشراء وإضافة بيان التعبئة';
  @override String get poNoSuitableContainers => 'لا توجد حاويات مناسبة';
  @override String get poDownloadSimulationViewsPNG => 'تنزيل صور المحاكاة (PNG)';
  @override String get poDownloadLoadingPlanPDF => 'تنزيل مخطط التحميل (PDF)';
  @override String get poBothViews => '🖼️ العرضان معاً';
  @override String poDetailedPlacementCoordinatesPkgs(Object? res) => '📐 تفاصيل الرص الإحداثي ($res طرد)';
  @override String poGroupedItemsItemsTotalPkgs(Object? res, Object? res2) => '📊 الأصناف المرصوصة مجمعة ($res صنف | إجمالي $res2 طرد)';
  @override String get poGroupByItems => 'عرض مجمع حسب الأصناف';
  @override String get poDetailedCoordinates => 'عرض تفصيلي بالإحداثيات';
  @override String get poItemCode => 'الصنف / البند';
  @override String get poPkgType => 'نوع الطرد';
  @override String get poDimsCm => 'الأبعاد (سم)';
  @override String get poGrossWt2 => 'إجمالي الوزن';
  @override String get poCBM2 => 'الحجم';
  @override String get poStack => 'الرص';
  @override String get poYes => '📦 نعم';
  @override String get poFloor => '🚫 أرضي';
  @override String get poDownloadSimulationImagePNG => 'تنزيل صور المحاكاة (PNG)';
  @override String get poProject => 'المشروع';
  @override String get poCurrencyIncoterm => 'العملة والشرط';
  @override String get poResetDeliveryAndOrderDates => 'تصفير تواريخ الشحن والاستلام';


  // ── Phase-1 UI strings: po ──────────────────────────────────────
  @override String get poInvoiceLineItemClonedSuccessfully => 'تم استنساخ سطر الفاتورة بنجاح';
  @override String get poPackingListItemClonedSuccessfully => 'تم استنساخ طرد الباكينج ليست بنجاح';
  @override String get poRestoreUnsavedDraft => 'استعادة مسودة غير محفوظة';
  @override String poAnAutosavedDraftExistsForThis(Object? savedAt) => 'توجد مسودة غير محفوظة تم حفظها تلقائياً لهذه الشاشة ($savedAt).\nهل ترغب في استعادة البيانات غير المحفوظة؟';
  @override String get poDiscardDraft => 'تجاهل وحذف المسودة';
  @override String get poRestoreDraft => 'استعادة المسودة';
  @override String get poDefault => '-- الافتراضي --';
  @override String get poDraftSaved => 'مسودة محفوظة';
  @override String get poSmartExtractPIPL => '🚀 استخلاص ذكي للمستندات';


  // ── Phase-1 UI strings: po ──────────────────────────────────────
  @override String get poSummaryByPackageType => 'ملخص نوع التغليف';
  @override String get poUnregistered => '⚠️ غير مسجل';


  // ── Phase-1 UI strings: cbm ──────────────────────────────────────
  @override String get cbmNoPackageLinesToExport => 'لا توجد طرود للتصدير';
  @override String get cbmStackable => 'قابل للتراص';
  @override String get cbmGrossWtUnitKg => 'الوزن القائم للوحدة (كجم)';
  @override String get cbmTotalCBM => 'الحجم الإجمالي بالمتر المكعب';
  @override String get cbmVolumetricWtKg => 'الوزن الحجمي (كجم)';
  @override String get cbmChargeableWtKg => 'الوزن الخاضع للشحن (كجم)';
  @override String get cbmPackageMeasurements => 'بيان أبعاد وأوزان الطرود';
  @override String get cbmDimensions => 'الأبعاد';
  @override String get cbmVolWt => 'الحجمي';
  @override String get cbmChargeable => 'الخاضع للشحن';
  @override String get cbmCBMCalculator => 'حساب الحجم CBM';
  @override String get cbmPackageMeasurementsSpecification => 'بيان أبعاد وحجوم الطرود';
  @override String get cbmShipmentMode => 'طريقة الشحن';
  @override String get cbmAir => 'جوي';
  @override String get cbmSea => 'بحري';
  @override String get cbmPackageLines => 'إجمالي السطور';
  @override String get cbmNoPackageLinesToCopy => 'لا توجد طرود للنسخ';
  @override String get cbmPackagesTableCopiedToClipboard => 'تم نسخ بيانات الطرود كجدول بنجاح';


  // ── Phase-1 UI strings: cbm ──────────────────────────────────────
  @override String get cbmNoCalculationsToExport => 'لا توجد دراسات حجم للتصدير';
  @override String get cbmCalcCode => 'كود الدراسة';
  @override String get cbmShippingStrategy => 'طريقة الشحن';
  @override String get cbmCBMRegistry => 'سجل دراسات الحجم CBM';
  @override String get cbmCode => 'كود الدراسة';
  @override String get cbmFile => 'الملف';
  @override String get cbmVolWt2 => 'حجمي (كجم)';
  @override String get cbmGrossWt => 'قائم (كجم)';
  @override String get cbmMode => 'الشحن';
  @override String get cbmCBMVolumetricWeightRegistry => 'سجل دراسات الحجم والأوزان CBM';
  @override String get cbmNoCalculationsToCopy => 'لا توجد دراسات حجم للنسخ';
  @override String get cbmCBMCalculationsTableCopiedToClipboard => 'تم نسخ بيانات دراسات الحجم كجدول بنجاح';


  // ── Phase-1 UI strings: ss ──────────────────────────────────────
  @override String get ssCarrier => 'ناقل';
  @override String get ssQuote => 'عرض';


  // ── Phase-1 UI strings: ss ──────────────────────────────────────
  @override String get ssInactive => 'معطل';


  // ── Phase-1 UI strings: cc ──────────────────────────────────────
  @override String get ccCustomsBroker => 'مكتب تخليص';
  @override String ccCostLinkageAlertThisImportFile(Object? budgetCode) => '⚠️ تنبيه ترابط التكاليف: ملف الاستيراد هذا مرتبط بميزانية تقديرية ($budgetCode). تم تحديث مصاريف التخليص الجمركي والرسوم، يُرجى مراجعة وتحديث اعتماد الميزانية لمطابقة التكاليف الحية.';
  @override String get ccOK => 'حسناً';
  @override String get ccExemption => 'إعفاء';
  @override String get ccACID => 'تسجيل مسبق';
  @override String get ccCOO => 'شهادة منشأ';
  @override String get ccGOEIC => 'رقابة صادرات';
  @override String get ccHSCode => '⚠️ بند جمركي';


  // ── Phase-1 UI strings: cc ──────────────────────────────────────
  @override String get ccExpenseItemNameCopied => 'تم نسخ اسم البند';


  // ── Phase-1 UI strings: cc ──────────────────────────────────────
  @override String get ccTargetPort => 'ميناء التخليص';
  @override String get ccItemsCount => 'عدد بنود الأسعار';
  @override String get ccEffectiveFrom => 'تاريخ السريان';
  @override String get ccIncrementVersionNumber => 'تحديث رقم الإصدار تلقائياً (الإصدار الجديد)';
  @override String get ccGenerateUniqueNewReferenceCode => 'توليد كود مرجعي فريد غير مكرر';
  @override String get ccCodeRequired => 'يرجى إدخال الكود';
  @override String get ccArabicNameRequired => 'يرجى إدخال الاسم العربي';
  @override String get ccCloneClearanceExpenseItem => 'استنساخ بند المصروف المرجعي';


  // ── Phase-1 UI strings: cc ──────────────────────────────────────
  @override String get ccCopyQuoteItems => 'نسخ بنود الأسعار';
  @override String get ccCopiedAllQuoteItemsToClipboard => 'تم نسخ جميع بنود الأسعار إلى الحافظة';


  // ── Phase-1 UI strings: cc ──────────────────────────────────────
  @override String get ccClearanceFees => 'أتعاب تخليص';
  @override String get ccProceduresApprovals => 'إجراءات وموافقات';
  @override String get ccInlandTransport => 'نقل داخلي';
  @override String get ccPortHandling => 'موانئ ومناولة';
  @override String get ccFixedAmount => 'مبلغ مقطوع';
  @override String get ccPerContainer => 'لكل حاوية';
  @override String get ccPerInvoice => 'لكل فاتورة';
  @override String get ccPerTon => 'لكل طن';
  @override String get ccPerTruck => 'لكل شاحنة';
  @override String get ccPerDay => 'لكل يوم';
  @override String get ccPerNight => 'لكل ليلة';
  @override String get ccPerInspection => 'لكل كشف';
  @override String get ccPerShipment => 'لكل شحنة';
  @override String get ccPerDeclaration => 'لكل شهادة إفراج';
  @override String get ccPerBillOfLading => 'لكل بوليصة شحن';
  @override String get ccPerSample => 'لكل عينة';
  @override String get ccPerCertificate => 'لكل شهادة';
  @override String get ccClientPaidExpenses => 'مصاريف مؤداة بمعرفة العميل';
  @override String get ccGeneralOtherFees => 'مصاريف ورسوم إضافية عامة';
  @override String get ccStorageDemurrage => 'أرضيات وحراسات وتخزين';
  @override String get ccLaborHandling => 'عمالة وتعتيق وكلارك ومناولة';
  @override String get ccCommissionsTips => 'عمولات ونثريات وإكراميات';
  @override String get ccExceptionalClearanceFee => 'أتعاب تخليص إضافية استثنائية';
  @override String get ccInlandTransportCustom => 'نقل داخلي أو شاحنة إضافية';
  @override String get ccAdditionalApprovals => 'إجراءات وموافقات إضافية';
  @override String get ccPortTerminalExpenses => 'رسوم ومصاريف موانئ ومحطات';
  @override String get ccNewCustomReferenceCode => '➕ كود مرجعي مخصص جديد...';
  @override String get ccEnterCustomCodeManually => 'إدخال كود يدوي جديد';
  @override String get ccRowClonedSuccessfullyCtrlD => '✨ تم استنساخ السطر بنجاح (كنترول + د)';
  @override String get ccCustomsBroker2 => 'مستخلص جمركي';
  @override String get ccServerConnectionFailed => 'فشل الاتصال بالخادم';
  @override String get ccFailedToSave => 'تعذر الحفظ';


  // ── Backend contract wiring (round 2) ──────────────────────────────────────
  @override String get apiNoPermission => 'ليس لديك صلاحية لتنفيذ هذا الإجراء. تواصل مع مدير النظام لمنحك الصلاحية.';
  @override String get tariffMissingBadge => 'التعريفة غير متوفرة';
  @override String get tariffMissingLineHint => 'لا يوجد بند جمركي أو تعريفة سارية بتاريخ التقدير، لذلك البند مستبعد من إجماليات الضرائب.';
  @override String tariffMissingLinesWarning(int count) => '$count بند بدون تعريفة جمركية سارية، وهي مستبعدة من إجماليات الضرائب. أضف أو حدّث التعريفة ثم أعد الاحتساب.';


  // ── Backend contract wiring (round 3) ──────────────────────────────────────
  @override String get poCreateErrorPrefix => 'خطأ في إدخال أمر الشراء';
  @override String get poUpdateErrorPrefix => 'خطأ في تحديث أمر الشراء';
  @override String get poAuditCreatedBy => 'أنشئ بواسطة';
  @override String get poAuditUpdatedBy => 'آخر تعديل بواسطة';


  // ── Backend contract wiring (round 3b) ──────────────────────────────────────
  @override String get openExistingRecord => 'فتح السجل القائم';


  // ── Round 4 ──────────────────────────────────────
  @override String poExtractionKeptAllocatedLines(String codes) => 'تم الإبقاء على بنود لها شحنات مسجلة ولم ترد في البيانات المستخلصة: $codes. لا يمكن حذفها.';


  // ── Round 5 ──────────────────────────────────────
  @override String get ccRateSourceManual => 'يدوي';
  @override String get ccRateSourceTable => 'جدول الأسعار';
  @override String get ccPreliminaryRateLabel => 'السعر الأولي';
  @override String get ccFinalRateLabel => 'السعر النهائي';

  @override
  String? domainEnumLabel(String type, String code) =>
      _domainEnumLabels['$type.$code'] ?? DomainEnums.supplementalLabel(type, code, arabic: true);

  // === review phase02 keys (append below this line) ===
  @override String faFxRateMissing(String currency) => 'لا يوجد سعر صرف مسجل للعملة $currency. أدخل السعر يدويًا قبل الحفظ.';
  @override String get faExchangeRateInvalid => 'أدخل سعر صرف أكبر من صفر';
  @override String get faReviewSyncBudgetLiveCosts => 'مراجعة وتحديث الميزانية بالتكاليف الحية';
  @override String get faUpstreamVarianceTitle => 'تنبيه عدم تطابق التكاليف مع المراحل السابقة (Live Cost Variance Detected)';
  @override String get faUpstreamVarianceBody => 'تم تعديل تكاليف في المراحل التشغيلية السابقة (دراسة التخليص / النولون / الفاتورة) وتختلف عن أرقام الميزانية الحالية:';
  @override String get faVarianceClearance => 'مصاريف التخليص والنقل الداخلي';
  @override String get faVarianceFreight => 'نولون الشحن التقديري';
  @override String get faVarianceDuties => 'الجمارك والضرائب';
  @override String get faVarianceInvoice => 'قيمة الفاتورة';
  @override String get faPrefilledLiveCosts => 'تم ملء الحقول بأحدث التكاليف الحية من المراحل السابقة بنجاح';
  @override String get faSyncBudgetLiveNow => 'مزامنة الميزانية مع التكاليف الحية الآن';
  @override String get faFillLiveCosts => 'ملء الحقول بالتكاليف الحية';
  @override String get faSyncLiveCosts => 'مزامنة التكاليف الحية';
  @override String get faMismatch => 'غير متطابق';
  @override String get faBeneficiarySwift57a => 'سويفت المستفيد (:57A):';
  @override String get faMatchedSenderBank => 'طابق بنك التحويل';
  @override String faSwiftUpdatedTo(String swift) => 'تم تحديث سويفت طلب السداد إلى $swift بنجاح!';
  @override String faUpdateFailed(String error) => 'فشل التحديث: $error';
  @override String faUpdateSwiftTo(String swift) => 'تحديث سويفت طلب السداد إلى $swift (انقر هنا)';
  @override String get faRemittingBankEg => 'بنك التحويل (مصر):';
  @override String get faRemittingBankInEgypt => 'بنك التحويل في مصر';
  @override String get faIssuingBank => 'البنك المنفذ';
  @override String get faDataHumanVerified => 'البيانات مدققة ومؤكدة بشرياً';
  @override String get faAdvanceAmountInvalid => 'يرجى إدخال قيمة دفعة مقدمة صالحة أكبر من الصفر';
  @override String faSmartTaskGenerated(String code) => ' وتم توليد المهمة الذكية $code';
  @override String faIssuePaymentFailed(String error) => 'فشل إصدار طلب السداد: $error';
  @override String get faAdvancePaymentTitle => 'طلب سداد الدفعة المقدمة للمورد (FN-01)';
  @override String faAdvanceSubtitle(String supplier) => 'المورد الأجنبي: $supplier | المرحلة: STEP_04 (اعتمادات الميزانية وسداد الموردين)';
  @override String get faAdvanceLoadingPo => 'جاري جلب بيانات أمر الشراء وحسابات المورد...';
  @override String get faPoFobTotal => 'إجمالي أمر الشراء (PO FOB Total):';
  @override String get faApprovedExchangeRate => 'سعر صرف العملة المعتمد:';
  @override String get faAdvancePercentageLabel => 'نسبة الدفعة المقدمة المطلوبة (Advance Percentage):';
  @override String get faCommon => 'شائع';
  @override String faCustomPercent(String percent) => 'مخصص ($percent%)';
  @override String faAdvanceAmountLabel(String currency) => 'قيمة الدفعة المقدمة ($currency) *';
  @override String get faEnterPaymentAmount => 'يرجى إدخال قيمة الدفعة';
  @override String get faAmountGreaterThanZero => 'القيمة يجب أن تكون أكبر من الصفر';
  @override String get faExchangeRateEgpLabel => 'سعر الصرف بالجنيه المصري *';
  @override String get faEquivalentInEgp => 'المعادل بالجنيه المصري: ';
  @override String get faCurrencyEgpShort => 'ج.م';
  @override String get faPaymentTitleLabel => 'عنوان طلب السداد *';
  @override String get faBeneficiaryBankDetails => 'بيانات الحساب البنكي للمورد المستفيد (Beneficiary Bank):';
  @override String get faBeneficiaryNameLabel => 'اسم المستفيد *';
  @override String get faBankNameLabel => 'اسم البنك *';
  @override String get faSwiftBicLabel => 'كود السويفت البنكي *';
  @override String get faAccountIbanLabel => 'رقم الحساب أو الآيبان *';
  @override String get faRequestedDueDateLabel => 'تاريخ الاستحقاق المطلوب *';
  @override String get faNotesForFinance => 'ملاحظات وتوجيهات إضافية للمالية';
  @override String get faAdvanceConfirmNote => 'عند التأكيد، سيتم إنشاء طلب السداد بحالة (Pending Approval) وإرسال إشعار فوري لمسؤول المالية (Finance Officer) وتوليد مهمة ذكية (Smart Task)، مع ترقية ملف الشحنة آلياً للمرحلة STEP_04.';
  @override String get faIssuingNotifying => 'جاري الإصدار والإخطار...';
  @override String get faIssueAndNotify => 'إصدار طلب السداد وإخطار المالية';
  @override String get faSwiftFieldUpdated => 'تم تحديث الحقل بنجاح وتسجيله في سجل التدقيق';
  @override String faSwiftFieldSaveFailed(String error) => 'فشل حفظ الحقل: $error';
  @override String get faSwiftFieldReExtracted => 'تمت إعادة استخلاص الحقل من النص الأصلي بنجاح';
  @override String faSwiftReExtractFailed(String error) => 'فشل إعادة الاستخلاص: $error';
  @override String get faSwiftConfirmedOpened => 'تم تأكيد صحة بيانات السويفت بنجاح وفتح المطابقة المالية!';
  @override String faSwiftConfirmFailed(String error) => 'فشل تأكيد المراجعة: $error';
  @override String get faSwiftReviewTitle => 'شاشة مراجعة وتدقيق نتائج استخلاص SWIFT';
  @override String get faSwiftReviewApprovedBanner => 'تم اعتماد وتدقيق البيانات المستخرجة بنجاح - مصفوفة المطابقة المالية مفتوحة';
  @override String get faSwiftHumanReviewRequired => 'تدقيق بشري إلزامي: لا تنتقل أي قيمة إلى مرحلة المطابقة دون تأكيد المستخدم الصريح';
  @override String get faSwiftHumanApproved => 'معتمد بشرياً';
  @override String get faSwiftPendingReview => 'بانتظار المراجعة والاعتماد';
  @override String get faSwiftMandatoryOnly => 'الإلزامية فقط (5)';
  @override String get faSwiftCopyRaw => 'نسخ المصدر الخام';
  @override String get faSwiftRawSource => 'النص المستخرج من السويفت';
  @override String faSwiftHighlightedField(String field) => 'تظليل الحقل: $field';
  @override String get faSwiftColField => 'الحقل والرمز البنكي';
  @override String get faSwiftColValue => 'القيمة المستخرجة / التدقيق اليدوي';
  @override String get faSwiftColConfidence => 'نسبة الثقة';
  @override String get faSwiftColAction => 'إجراء';
  @override String get faSwiftMandatoryMark => '* إلزامي';
  @override String get faSwiftManuallyEdited => 'معدل يدويًا';
  @override String get faSwiftSaveEdit => 'حفظ التعديل';
  @override String get faSwiftCopyValue => 'نسخ القيمة';
  @override String get faSwiftReExtractField => 'إعادة استخلاص الحقل من الأصل';
  @override String get faSwiftEmptyMandatoryBlocks => 'حقل إلزامي فارغ - يمنع التأكيد';
  @override String get faSwiftStatusEmpty => 'فارغ';
  @override String get faSwiftStatusTrusted => 'موثوق';
  @override String get faSwiftStatusReviewed => 'مدقق';
  @override String get faSwiftOptional => 'اختياري';
  @override String get faSwiftAllMandatoryOk => 'جميع الحقول الإلزامية الخمسة مكتملة ومحققة لقواعد التحقق المالي.';
  @override String get faSwiftMatchingBlocked => 'حظر المطابقة: الحقول الإلزامية التالية غير مكتملة أو فارغة، يُرجى تصحيحها أولاً:';
  @override String get faSwiftCancelReview => 'إلغاء المراجعة';
  @override String get faSwiftApprovedGoMatch => 'تم الاعتماد • الانتقال إلى المطابقة';
  @override String get faSwiftConfirmAndMatch => 'تأكيد صحة البيانات والانتقال إلى المطابقة';
  @override String faAdvanceIssued(String code, String taskInfo) => 'تم إصدار طلب سداد الدفعة المقدمة ($code)$taskInfo وإخطار قسم المالية ومتابعة ملف الاستيراد (STEP_04)';
  @override String get faSuccessWord => 'بنجاح';
  @override String faVarianceTotal(String signedDiff, String updatedBudget) => 'إجمالي الفارق المتراكم في الميزانية: $signedDiff ج.م (الميزانية المحدثة ستكون: $updatedBudget ج.م)';
  @override String faVarianceChipLine(String budget, String live, String diff) => 'بالميزانية: $budget ج.م ➔ الحي: $live ج.م [$diff ج.م]';
  @override String faPercentFromPo(String amount, String currency) => 'حساب النسبة من أمر الشراء ($amount $currency):';
  @override String get faApprovedMatchingMatrix => 'مصفوفة المطابقة المالية المعتمدة';
  @override String faLoadFailed(String error) => 'تعذر تحميل البيانات: $error';
  @override String get faTitleMinLength => 'العنوان يجب ألا يقل عن 3 أحرف';
  @override String get faPaymentTypeAdvance => 'دفعة مقدمة';
  @override String get faPaymentTypeAgainstBl => 'مقابل بوليصة الشحن';
  @override String get faPaymentTypeLetterOfCredit => 'اعتماد مستندي (L/C)';
  @override String get faPaymentTypeDocumentaryCollection => 'تحصيل مستندي (CAD)';
  @override String get faPaymentTypeFinalSettlement => 'التسوية النهائية';
  // === end review phase02 keys ===

  // === review phase03 keys (append below this line) ===
  @override String get idocAConfirmNotMatchedTitle => 'تنبيه: عدم اكتمال شروط المطابقة';
  @override String get idocAConfirmNotMatchedBody => 'تحتوي نتائج الفحص على فروقات حرجة أو تحذيرات غير مطابقة. اكتب مبرر الاعتماد النهائي للمتابعة.';
  @override String get idocAJustificationLabel => 'مبرر الاعتماد رغم الفروقات';
  @override String get idocAJustificationRequired => 'المبرر مطلوب';
  @override String get idocAReviewDiffs => 'مراجعة الفروقات';
  @override String get idocAConfirmFinal => 'تأكيد الاعتماد النهائي';
  @override String idocADraftSaved(String code) => 'تم حفظ مسودة الجلسة ($code) في سجل الجلسات';
  @override String idocASessionApproved(String code) => 'تم اعتماد الجلسة ($code)';
  @override String get idocADraftSaveFailed => 'فشل حفظ المسودة';
  @override String get idocAFinalApprovalFailed => 'فشل الاعتماد النهائي للجلسة';
  @override String get idocASessionNotesTab => 'ملاحظات الجلسة';
  @override String get idocADeleteSessionFailed => 'تعذر حذف الجلسة';
  @override String get idocADraftBlConfirmTitle => 'تأكيد حفظ المراجعة للاعتماد';
  @override String idocADraftBlConfirmBody(int count) => 'توجد فروقات حرجة ($count) مسجلة في فحص البوليصة. هل تريد حفظ المراجعة وإرسالها للاعتماد المزدوج؟';
  @override String get idocADraftBlConfirmAction => 'حفظ للاعتماد';
  @override String idocADraftBlSaved(String code) => 'تم حفظ مسودة مراجعة البوليصة ($code)';
  @override String idocADraftBlSavedForApproval(String code) => 'تم حفظ مراجعة البوليصة ($code) وهي بانتظار الاعتماد المزدوج';
  @override String get idocADraftBlSaveFailed => 'تعذر حفظ مراجعة البوليصة';
  @override String get idocAChecklistSaveFailed => 'لم يتم حفظ تعديل قائمة المراجعة';
  @override String get idocATemplateDemurrageExtension => 'طلب مد فترة سماح غرامات التأخير';
  @override String get idocATemplateBankDelegation => 'تفويض بنكي لاستلام المستندات والبوالص';
  @override String get idocATemplateBankForm4 => 'طلب استخراج نموذج 4 جمركي';
  @override String get idocATemplateBrokerMandate => 'تفويض وتوكيل رسمي للمخلص الجمركي';
  @override String idocADocumentsCount(Object? a0) => '$a0 وثيقة';
  @override String get idocAACID => 'الرقم المبدئي';
  @override String idocAActiveSessionUnderReview(Object? a0) => 'جلسة نشطة قيد الفحص: $a0';
  @override String idocAAllCount(Object? a0) => 'الكل ($a0)';
  @override String get idocAAllImportFiles => 'جميع ملفات الشحن';
  @override String get idocAAllShipmentsAndFiles => 'كافة الشحنات والملفات';
  @override String get idocAApprovalCode => 'كود الاعتماد';
  @override String get idocAApprovalsMatrixTitle => 'مصفوفة اعتماد المستندات';
  @override String get idocAApproveSaveFinalEmoji => '✅ اعتماد وحفظ نهائي وتحديث الموافقة الجمركية';
  @override String get idocAApprovedSessions => 'الجلسات المعتمدة';
  @override String idocAAreYouSureYouWantTo(Object? a0) => 'هل أنت متأكد من رغبتك في حذف مسودة الجلسة ($a0)؟';
  @override String idocAAreYouSureYouWantToAlt(Object? a0) => 'هل أنت متأكد من حذف مسودة الجلسة ($a0)؟ لن يؤثر ذلك على بيانات الشحنة الأصلية.';
  @override String get idocAAutomatedMatchingOf20CriticalFields => 'مطابقة آلية لـ 20 حقلاً حرجاً مع أمر الشراء والفاتورة التجارية ومنع غرامات التعديل الجمركي';
  @override String get idocAAverageMatch => 'متوسط التطابق';
  @override String get idocABLData => 'بيانات البوليصة';
  @override String idocABlNumberCreated(Object? a0, Object? a1) => 'رقم البوليصة: $a0  |  تاريخ الإنشاء: $a1';
  @override String get idocABillOfLadingBLReview => 'سجل جلسات مراجعة وتدقيق بوالص الشحن (B/L)';
  @override String get idocABillOfLadingExtracts => 'مستخرجات بوليصة الشحن';
  @override String get idocABroker => 'المخلص';
  @override String get idocABrokerReviewer => 'المخلص الجمركي';
  @override String get idocABrokerStatus => 'اعتماد المخلص';
  @override String get idocACBM => 'الحجم (م³)';
  @override String get idocACBMAlt => 'الحجم';
  @override String get idocACertified => 'معتمدة نهائية';
  @override String get idocAClearSelection => 'إلغاء التحديد';
  @override String get idocACloneAsANewDraft => 'استنساخ كمسودة جديدة';
  @override String get idocACloneSessionAsANewDraft => 'استنساخ الجلسة كمسودة جديدة';
  @override String get idocACode => 'الكود';
  @override String get idocACodeAlt => 'كود الجلسة';
  @override String get idocAColSystemValueInvoice => 'قيمة النظام\n(الفاتورة)';
  @override String get idocAColSystemValuePacking => 'قيمة النظام\n(قائمة التعبئة)';
  @override String get idocAColUploadedValueInvoice => 'القيمة المرفوعة\n(الفاتورة)';
  @override String get idocAColUploadedValuePacking => 'القيمة المرفوعة\n(قائمة التعبئة)';
  @override String get idocACommercial => 'التجاري';
  @override String get idocACommercialInvoiceAndBillOfLading => 'سجل جلسات مطابقة الفاتورة التجارية وبوليصة الشحن';
  @override String get idocACommercialInvoiceAndBillOfLadingAlt => 'مصفوفة مطابقة الفاتورة التجارية وبوليصة الشحن';
  @override String get idocACommercialInvoiceExtracts => 'مستخرجات الفاتورة التجارية';
  @override String get idocACommercialReviewer => 'المراجع التجاري';
  @override String get idocACommercialStatus => 'الاعتماد التجاري';
  @override String get idocAComprehensiveRegistryOfTemporaryAndFinally => 'سجل شامل لجلسات مسودات البوليصة المؤقتة والمعتمدة نهائياً مع تتبع الفروقات والموافقات';
  @override String get idocAConfirmDeletion => 'تأكيد الحذف';
  @override String get idocAConfirmDraftDeletion => 'تأكيد حذف المسودة';
  @override String get idocAConfirmDraftSessionDeletion => 'تأكيد حذف مسودة الجلسة';
  @override String get idocAContainers => 'الحاويات';
  @override String get idocACopyAsTSV => 'نسخ كـ TSV';
  @override String get idocACopyCode => 'نسخ الكود';
  @override String get idocACopyRowDataAsTSV => 'نسخ بيانات السطر كـ TSV';
  @override String get idocACopySessionMatrixTSV => 'نسخ مصفوفة الجلسة (TSV)';
  @override String get idocACopyTSV => 'نسخ TSV';
  @override String get idocACopyTableAsTSV => 'نسخ الجدول كـ TSV';
  @override String get idocACopyTableTSV => 'نسخ جدول البيانات';
  @override String get idocACopyTicketsAsTSV => 'نسخ التذاكر كـ TSV';
  @override String get idocACriticalDelay => 'تأخير حرج';
  @override String get idocACustomsDocumentApprovalsReport => 'تقرير ومصفوفة اعتماد المستندات الجمركية';
  @override String get idocADeleteDraft => 'حذف المسودة';
  @override String get idocADescription => 'الوصف';
  @override String get idocADetailsAndSourcesOfDisagreement => 'التفاصيل ومصادر الاختلاف';
  @override String idocADisagreementBetween(Object? a0) => 'اختلاف بين: $a0';
  @override String get idocADiscrepancies => 'الفروقات';
  @override String get idocADispatchDate => 'تاريخ الإرسال';
  @override String get idocADoc => 'المستند';
  @override String idocADocsCompletenessLabel(Object? a0) => 'استكمال المستندات (DC-04): $a0%';
  @override String get idocADocumentType => 'نوع المستند';
  @override String get idocADraft => 'مسودة مؤقتة';
  @override String get idocADraftBLRegistry => 'سجل بوالص الشحن المبدئية';
  @override String get idocADraftBillOfLadingReviewAnd => 'مراجعة مسودة بوليصة الشحن والاعتماد المزدوج (SH-02)';
  @override String get idocADraftDeletedSuccessfully => 'تم حذف المسودة بنجاح';
  @override String get idocADraftSessionDeletedSuccessfully => 'تم حذف مسودة الجلسة بنجاح';
  @override String idocAExistingSessionBody(Object? a0, Object? a1, Object? a2) => 'هذا الملف الاستيرادي لديه بالفعل جلسة مسجلة ($a0)، آخر تحديث بواسطة $a1 في $a2.';
  @override String idocAExistingSessionUpdateBody(Object? a0, Object? a1, Object? a2, Object? a3) => 'هذا الملف الاستيرادي لديه بالفعل جلسة مسجلة ($a0)، آخر تحديث بواسطة $a1 في $a2.\n\nهل ترغب في تحديث الجلسة الحالية ($a3) بالبيانات الجديدة؟';
  @override String get idocAExpected => 'القيمة المتوقعة';
  @override String get idocAExpectedAlt => 'المتوقع';
  @override String get idocAExportExcel => 'تصدير كملف إكسل';
  @override String get idocAExtractedPackingList => 'كشف التعبئة المستخرج';
  @override String get idocAExtractionFailed => 'تعذر القراءة';
  @override String idocAFailedToLoadTheSessionsRegistry(Object? a0) => 'حدث خطأ أثناء تحميل سجل الجلسات: $a0';
  @override String get idocAFile => 'ملف الشحنة';
  @override String get idocAFileAlt => 'الشحنة';
  @override String get idocAFilterByImportFile => 'تصفية حسب ملف الشحنة';
  @override String get idocAFinalApprovalOfDocuments => 'اعتماد نهائي للمستندات';
  @override String idocAFinalApprovedCount(Object? a0) => 'معتمدة نهائية ($a0)';
  @override String get idocAFinalPackages => 'العبوات النهائية';
  @override String get idocAFinalPkgs => 'العبوات النهائية';
  @override String get idocAFinalQty => 'الكمية النهائية';
  @override String get idocAFinalQtyAlt => 'الكمية';
  @override String get idocAFinalTotal => 'الإجمالي النهائي';
  @override String get idocAFinalUnitPrice => 'السعر النهائي';
  @override String get idocAFinallyApprovedSessions => 'جلسات معتمدة نهائياً';
  @override String get idocAFooterDiscrepancyBrand => 'Sorour Logistics ERP — مركز التباينات';
  @override String get idocAFooterDocsBrand => 'Sorour Logistics ERP — إدارة الوثائق الاستيرادية';
  @override String get idocAFooterInspectionBrand => 'Sorour Logistics ERP — نظام فحص ومطابقة الوثائق الجمركية';
  @override String get idocAFooterMatchingBrand => 'Sorour Logistics ERP — إدارة الوثائق والمطابقة المستندية الجمركية';
  @override String get idocAFound => 'القيمة الفعلية';
  @override String get idocAFoundAlt => 'الفعلي';
  @override String get idocAFullAuditLog => 'سجل التدقيق الكامل';
  @override String get idocAFumigationCertificate => 'شهادة التبخير والصحة النباتية';
  @override String get idocAGrossWeightKg => 'الوزن القائم (كجم)';
  @override String get idocAGrossWt => 'الوزن القائم';
  @override String get idocAHSCode => 'بند التعريفة';
  @override String get idocAImportFile => 'ملف الشحنة';
  @override String idocAImportFileCreated(Object? a0, Object? a1) => 'ملف الشحنة: $a0  |  تاريخ الإنشاء: $a1';
  @override String get idocAImportFileImporter => 'ملف الشحنة / المستورد';
  @override String get idocAInTransit => 'في الطريق';
  @override String get idocAInTransitAlt => 'في الطريق';
  @override String get idocAInvoice => 'الفاتورة';
  @override String get idocAInvoiceData => 'بيانات الفاتورة';
  @override String get idocAInvoiceItems => 'بنود الفاتورة التجارية';
  @override String get idocAInvoiceItemsReconciliation => 'بنود الفاتورة التجارية المعتمدة';
  @override String get idocAInvoicePackingList => 'رقم الفاتورة / قائمة التعبئة';
  @override String get idocAIssueCategory => 'تصنيف المشكلة';
  @override String idocAIssueDate(Object? a0) => 'تاريخ الإصدار: $a0';
  @override String idocAItemClonedSuccessfully(Object? a0) => 'تم استنساخ البند $a0 بنجاح';
  @override String get idocAItemCode => 'كود الصنف';
  @override String idocAItemsCount(Object? a0) => '$a0 بند';
  @override String idocALastModifiedByOn(Object? a0, Object? a1) => 'آخر تعديل بواسطة: $a0 في $a1';
  @override String get idocALinkedDocuments => 'المستندات المرتبطة';
  @override String get idocALoadingMatchingSessionsRegistry => 'جاري تحميل سجل جلسات المطابقة...';
  @override String get idocAMaerskMSCAgency => 'توكيل ميرسك / إم إس سي';
  @override String get idocAMatchScore => 'نسبة التطابق';
  @override String get idocAMatchStatus => 'حالة التطابق';
  @override String idocAMissingDocsWarning(Object? a0) => '⚠️ نواقص مستندية: $a0';
  @override String get idocANameOfTheAuthorizedReceiver => 'اسم المفوض بالاستلام';
  @override String get idocANetWeightKg => 'الوزن الصافي (كجم)';
  @override String get idocANetWt => 'الصافي';
  @override String get idocANewInspectionSession => 'جلسة فحص جديدة';
  @override String get idocANoCourierPackagesMatchTheSearch => 'لا توجد طرود كورير مسجلة مطابقة لمعايير البحث';
  @override String get idocANoCustomsDeclarationsMatchTheSearch => 'لا توجد إقرارات جمركية مطابقة للبحث';
  @override String get idocANoMatchingSessionsFoundForThe => 'لا توجد جلسات مطابقة مسجلة مطابقة لمعايير البحث';
  @override String get idocANoSavedMatchingMatrixForThis => 'لا توجد مصفوفة مطابقة محفوظة لهذه الجلسة';
  @override String get idocANoSavedMatrixItems => 'لا توجد بنود مصفوفة محفوظة';
  @override String get idocANoticeAReconciliationSessionIsAlready => 'تنبيه: جلسة مطابقة مسجلة مسبقاً';
  @override String get idocANoticeASessionIsAlreadyRegistered => 'تنبيه: جلسة مسجلة مسبقاً';
  @override String get idocAOpenAndContinueTheCurrentSession => 'فتح ومتابعة الجلسة الحالية';
  @override String get idocAOperations => 'العمليات';
  @override String get idocAOverallStatus => 'الحالة العامة';
  @override String get idocAPODNumber => 'رقم الـ POD';
  @override String get idocAPOPackages => 'عبوات أمر الشراء';
  @override String get idocAPOPkgs => 'عبوات PO';
  @override String get idocAPOQty => 'كمية أمر الشراء';
  @override String get idocAPOQtyAlt => 'كمية PO';
  @override String get idocAPOReconciliationSessions => 'سجل جلسات مطابقة الفاتورة وقائمة التعبئة';
  @override String get idocAPOReconciliationSessionsAlt => 'جلسات مطابقة الفاتورة وقائمة التعبئة';
  @override String get idocAPOUnitPrice => 'سعر أمر الشراء';
  @override String idocAPackageClonedSuccessfully(Object? a0) => 'تم استنساخ طرد $a0 بنجاح';
  @override String get idocAPackageType => 'نوع الطرد';
  @override String get idocAPackages => 'الطرود';
  @override String get idocAPackagesVariance => 'فارق العبوات';
  @override String get idocAPackagesWeight => 'الطرود والوزن';
  @override String get idocAPackingList => 'كشف التعبئة';
  @override String get idocAPackingListAlt => 'كشف التعبئة';
  @override String get idocAPackingListItems => 'بنود قائمة التعبئة';
  @override String get idocAPackingListReconciliation => 'بنود قائمة التعبئة والأوزان';
  @override String get idocAPriceVariance => 'فارق السعر';
  @override String get idocAPrintPDF => 'طباعة PDF';
  @override String get idocAPrintPDFReport => 'طباعة تقرير PDF';
  @override String get idocAQtyVariance => 'فارق الكمية';
  @override String get idocAReceiptAndDocumentationOfOriginalBank => 'استلام وتوثيق أصول المستندات البنكية (SH-04)';
  @override String get idocAReceiptAndVisualInspectionNotes => 'ملاحظات الاستلام والفحص الظاهري';
  @override String get idocAReceiptDateAndTime => 'تاريخ ووقت الاستلام';
  @override String get idocAReceiptStatus => 'حالة الاستلام';
  @override String get idocAReceived => 'تم الاستلام';
  @override String get idocAReceivedBy => 'المستلم';
  @override String get idocARectificationTickets => 'سجل تذاكر الاستدراك';
  @override String get idocARectificationTicketsReport => 'سجل تذاكر واستفسارات استدراك المستندات';
  @override String get idocARef => 'المرجع';
  @override String get idocARefNumber => 'الرقم المرجعي';
  @override String get idocARestoreAndLoadInTheInspection => 'استعادة وتحميل في شاشة الفحص';
  @override String get idocARestoreAndLoadInTheReview => 'استعادة وتحميل في أداة المراجعة';
  @override String get idocARestoreAndLoadTheSessionIn => 'استعادة وتحميل الجلسة لشاشة الفحص';
  @override String get idocARestoreAndLoadTheSessionInAlt => 'استعادة وتحميل الجلسة في أداة الفحص';
  @override String get idocAReviewAndComparisonMatrix => 'مصفوفة الفحص والمقارنة:';
  @override String get idocARowActions => 'إجراءات السطر';
  @override String idocARowCopiedTsv(Object? a0) => 'تم نسخ بيانات البند ($a0) كـ TSV';
  @override String get idocASaveSessionDraftEmoji => '💾 حفظ مؤقت للجلسة';
  @override String get idocASaveTempDraft => 'حفظ مسودة مؤقتة';
  @override String get idocASavedDate => 'تاريخ الحفظ';
  @override String get idocASearchBySessionCodeImportFile => 'بحث بكود الجلسة، ملف الشحنة، أو الملاحظات...';
  @override String get idocASearchByWaybillCourierOrShipment => 'بحث برقم البوليصة أو الكورير أو الشحنة...';
  @override String idocASessionDataClonedAsDraft(Object? a0) => 'تم استنساخ بيانات الجلسة ($a0) كمسودة جديدة في شاشة الفحص';
  @override String get idocASessionCode => 'كود الجلسة';
  @override String get idocASessionCodeAlt => 'كود الجلسة';
  @override String get idocASessionCodeCopiedToTheClipboard => 'تم نسخ كود الجلسة إلى الحافظة';
  @override String get idocASessionDate => 'تاريخ الجلسة';
  @override String idocASessionDetailsTitle(Object? a0) => 'تفاصيل الجلسة: $a0';
  @override String get idocASessionNotes => 'ملاحظات الجلسة:';
  @override String idocASessionRestoredInspection(Object? a0) => 'تم استرجاع وتحميل بيانات الجلسة $a0 إلى شاشة الفحص بنجاح';
  @override String idocASessionRestoredReview(Object? a0) => 'تم استرجاع وتحميل بيانات الجلسة ($a0) إلى أداة المراجعة بنجاح';
  @override String get idocASessionTitleAndNotes => 'عنوان وملاحظات الجلسة';
  @override String get idocASessionType => 'نوع الجلسة';
  @override String get idocASessionTypeAlt => 'نوع الجلسة';
  @override String get idocASeverity => 'درجة الخطورة';
  @override String get idocASeverityAlt => 'الخطورة';
  @override String get idocAShippingCompany => 'شركة الشحن';
  @override String get idocAStage5SailingAndCargoXCourier => 'المرحلة الخامسة: الإبحار و CargoX — تتبع الكورير، مطابقة أصول الفواتير والبوالص ونموذج 4، وتوثيق الاستلام للتخليص الجمركي';
  @override String get idocAStandardField => 'الحقل المعياري';
  @override String get idocAStandardItem => 'البند المعياري';
  @override String get idocASystemData => 'بيانات النظام';
  @override String get idocASystemValue => 'بيانات النظام';
  @override String get idocATemporaryDrafts => 'المسودات المؤقتة';
  @override String idocATemporaryDraftsCount(Object? a0) => 'مسودات مؤقتة ($a0)';
  @override String get idocATemporaryDraftsBeingEdited => 'مسودات مؤقتة قيد التعديل';
  @override String get idocATicketCode => 'كود التذكرة';
  @override String get idocATotal => 'الإجمالي الكلي';
  @override String get idocATotalAlt => 'الإجمالي';
  @override String get idocATotalBLSessions => 'إجمالي جلسات البوليصة';
  @override String get idocATotalDocs => 'إجمالي المستندات';
  @override String get idocATotalSessions => 'إجمالي الجلسات';
  @override String get idocATotalTickets => 'إجمالي التذاكر';
  @override String get idocATotalValue => 'القيمة الإجمالية';
  @override String get idocATrackTheCourierDirectlyOnThe => 'تتبع الكورير مباشرة على موقع الشركة';
  @override String get idocATransitTime => 'مدة الشحن';
  @override String get idocAUnitPrice => 'السعر';
  @override String get idocAValue => 'القيمة';
  @override String get idocAValueInTheDraftBL => 'القيمة بمسودة البوليصة';
  @override String get idocAValueRecordedInTheSystem => 'القيمة المسجلة بالسيستم';
  @override String get idocAVariance => 'الفارق';
  @override String get idocAViewSessionDetailsAndMatrix => 'عرض تفاصيل ومصفوفة الجلسة';
  @override String get idocAVolumeCBM => 'الحجم بالمتر المكعب';
  @override String get idocAWarning => 'اقتراب المهلة';
  @override String get idocAWaybillNumberAWB => 'رقم بوليصة الشحن الجوي';
  @override String get idocAYouCanOpenAndContinueThe => 'يمكنك فتح ومتابعة الجلسة القائمة وتعديل بنودها مباشرة دون إنشاء جلسة جديدة، أو إلغاء التحديد لاختيار ملف آخر.';
  @override String idocAApprovedCount(Object? a0) => 'معتمدة ($a0)';
  @override String get idocABLValue => 'القيمة بالبوليصة';
  @override String get idocABookingNumber => 'رقم الحجز (Booking)';
  @override String get idocABy => 'بواسطة';
  @override String get idocACheckItem => 'بند الفحص';
  @override String get idocACloneNoteBlNumber => 'رقم مسودة البوليصة: يتم تصفيره إلى كود مسودة مؤقت (DRAFT-BL-2026-)';
  @override String get idocACloneNoteBroker => 'اعتماد المخلص الجمركي: يعاد إلى قيد الانتظار (Pending) وتفريغ الملاحظات';
  @override String get idocACloneNoteBrokerStatus => 'حالة اعتماد المخلص الجمركي: إعادة تعيين إلى قيد الانتظار (Pending)';
  @override String get idocACloneNoteCommercial => 'حالة الاعتماد التجاري: إعادة تعيين إلى قيد الانتظار (Pending)';
  @override String get idocACloneNoteImporter => 'اعتماد المستورد: يعاد إلى قيد الانتظار (Pending) وتفريغ الملاحظات';
  @override String get idocACloneNoteOverall => 'الحالة العامة: إعادة تعيين إلى مسودة قيد التدقيق (Draft)';
  @override String get idocACloneNoteReviewId => 'معرف جلسة المراجعة السابقة: تم فك الارتباط وبدء جلسة جديدة';
  @override String get idocACloneNoteSignature => 'تفريغ توقيع ومعتمد الجلسة وتاريخ الاعتماد لبدء جلسة مستقلة';
  @override String get idocACloneNoteSignatures => 'تفريغ توقيعات وملاحظات المراجعين بالكامل لبدء اعتماد مستقل';
  @override String get idocACloneNoteSnapshot => 'لقطة بيانات النظام: يتم تحديثها ومطابقتها مع ملف الشحنة المختار';
  @override String get idocACreatedAt => 'تاريخ الإنشاء';
  @override String get idocADefaultSessionTitle => 'جلسة فحص مطابقة';
  @override String get idocADetailsAndAction => 'التفاصيل والإجراء';
  @override String get idocADetailsAndRequiredAction => 'التفاصيل والإجراء المطلوب';
  @override String get idocADiffInvoiceBl => 'فاتورة ≠ بوليصة';
  @override String get idocADiffInvoicePacking => 'فاتورة ≠ تعبئة';
  @override String get idocADiffPackingBl => 'تعبئة ≠ بوليصة';
  @override String get idocADiffSystemBl => 'سستم ≠ بوليصة';
  @override String get idocADiffSystemInvoice => 'سستم ≠ فاتورة';
  @override String get idocADiffSystemPacking => 'سستم ≠ تعبئة';
  @override String idocADiscrepancyCount(Object? a0) => '$a0 فارق';
  @override String get idocADocumentsReviewer => 'مراجع المستندات';
  @override String get idocADraft3 => 'مسودة';
  @override String get idocADraftBillOfLadingDraftB => 'مسودة بوليصة الشحن (Draft B/L Review)';
  @override String idocADraftsCount(Object? a0) => '$a0 مسودة';
  @override String get idocAExtractedDataInvoiceBL => 'البيانات المستخرجة (فاتورة / بوليصة)';
  @override String get idocAExtractionFailed3 => 'تعذر القراءة';
  @override String get idocAFinalInvoiceNumber => 'رقم الفاتورة النهائية';
  @override String get idocAFreightTerms => 'شروط النولون';
  @override String get idocAFullyMatched => 'متطابق بالكامل';
  @override String get idocAInvoiceAndBLMatchingSessions => 'سجل جلسات مطابقة الفاتورة والبوليصة';
  @override String get idocAInvoiceNumber => 'رقم الفاتورة';
  @override String get idocAInvoiceValue => 'القيمة بالفاتورة';
  @override String get idocAMatched => 'متطابق';
  @override String get idocAMatchingAndVerificationMatrix => 'مصفوفة المطابقة والتحقق';
  @override String get idocAMatchingMatrixCopiedToTheClipboard => 'تم نسخ مصفوفة المطابقة كـ TSV إلى الحافظة بنجاح';
  @override String get idocAMatchingSessionsTableCopiedToThe => 'تم نسخ جدول جلسات المطابقة كـ TSV إلى الحافظة بنجاح';
  @override String get idocAMaterialVariance => 'فارق جوهري';
  @override String get idocAMinorVariance => 'فارق طفيف';
  @override String get idocANotMatched => 'غير متطابق';
  @override String get idocANotSpecified => 'غير محدد';
  @override String get idocAPackingListNumber => 'رقم قائمة التعبئة';
  @override String get idocAPortOfLoadingArrival => 'ميناء الشحن / الوصول';
  @override String get idocAResponsibleUser => 'المستخدم المسؤول';
  @override String get idocASaveDateAndTime => 'تاريخ ووقت الحفظ';
  @override String idocASavedApprovedStatus(Object? a0) => 'محفوظة/معتمدة ($a0)';
  @override String get idocASessionStatus => 'حالة الجلسة';
  @override String idocASessionsCount(Object? a0) => '$a0 جلسة';
  @override String get idocAShippingLine => 'الخط الملاحي';
  @override String idocATemporaryDraftsCount3(Object? a0) => 'مسودة مؤقتة ($a0)';
  @override String get idocATitle => 'العنوان';
  @override String get idocATotalPackages => 'إجمالي الطرود';
  @override String get idocATotalVolume => 'الحجم الكلي';
  @override String get idocATotalWeight => 'إجمالي الوزن';
  @override String get idocAVesselVoyage => 'اسم السفينة / الرحلة';
  @override String get idocABlNotApplied => 'لم يتم تطبيق بيانات البوليصة';
  @override String idocAMatrixNotChecked(int count) => 'لم يتم فحص $count بند';
  // === end review phase03 keys ===

  // === review phase03_ui_b keys (append below this line) ===
  @override String get idocBMissing => 'غير متوفر';
  @override String get idocBAcidRequired => 'رقم ACID مطلوب';
  @override String get idocBExportBlockedAcid => 'تم إيقاف العملية: ملف الاستيراد لا يحتوي على رقم ACID. أدخل رقم ACID أولاً.';
  @override String get idocBExportBlockedHsCode => 'تم إيقاف التصدير: بند التعريفة (HS Code) غير موجود في بيانات الشهادة.';
  @override String get idocBExportBlockedOrigin => 'تم إيقاف التصدير: بلد المنشأ غير موجود في بيانات الشهادة.';
  @override String get idocBMissingTariff => 'نسب التعريفة الجمركية لبند التعريفة';
  @override String get idocBMissingFxRate => 'سعر الصرف الجمركي';
  @override String get idocBMissingFob => 'قيمة FOB';
  @override String idocBFigureMissingBanner(String items) => 'تعذر احتساب الرسوم والضرائب. بيانات ناقصة: $items. لا يتم التقدير تلقائياً؛ أضف البيانات الناقصة في البيانات الأساسية.';
  @override String get idocBFreightInsuranceNote => 'تقدير: يستخدم آخر سعر صرف جمركي وليس سعر تاريخ الإقرار، والقيمة الجمركية تشمل FOB فقط (النولون والتأمين غير مسجلين لهذا الملف).';
  @override String get idocBMissingFobMixedCurrency => 'قيمة FOB (فواتير الملف بعملات مختلفة)';
  @override String get idocBInspectionFieldsRequired => 'رقم الشهادة والجهة الرقابية مطلوبان قبل الحفظ.';
  @override String get idocBFieldRequired => 'هذا الحقل مطلوب';
  @override String get idocBScheduleTaxLabel => 'ضريبة الجدول';
  @override String get idocBImportFeeLabel => 'رسم الاستيراد';
  @override String get idocBFigureItemHeader => 'البند';
  @override String get idocBFigureAmountHeader => 'المبلغ (ج.م)';
  @override String idocBRateCaption(String rate) => 'النسبة: $rate%';
  @override String get idocBExemptionApplied => 'إعفاء مُطبَّق';
  @override String get idocBExemptionNone => 'بدون إعفاء';
  @override String get idocBFobEgpLabel => 'قيمة FOB (ج.م)';
  @override String get idocBNotRecorded => 'غير مسجل';
  @override String get idocBNoDeclarations => 'لا توجد إقرارات للعرض. أضف ملف استيراد أو غيّر البحث.';
  @override String get idocBCloneDecl46Entity => 'إقرار جمركي مبدئي شهادة 46 (Customs Declaration 46)';
  @override String get idocBCloneFieldImportFile => 'ملف الشحنة';
  @override String get idocBCloneFieldSupplier => 'المورد الأجنبي';
  @override String get idocBCloneFieldCompany => 'الشركة المستوردة';
  @override String get idocBCloneFieldHsCode => 'بند التعريفة الجمركية';
  @override String get idocBCloneFieldCif => 'القيمة للأغراض الجمركية CIF';
  @override String get idocBCloneFieldTotalDuties => 'إجمالي الضرائب والرسوم المقدرة';
  @override String get idocBCloneFieldExemption => 'موقف الإعفاء والاتفاقية';
  @override String get idocBCloneReset1 => 'رقم الإقرار الجمركي: يتم تصفيره وتعيينه كمسودة جديدة';
  @override String get idocBCloneReset2 => 'تاريخ القيد المبدئي: يعاد ضبطه تلقائياً إلى تاريخ اليوم';
  @override String get idocBCloneReset3 => 'حالة الشهادة والإفراج: تعاد إلى قيد الإعداد المبدئي (مسودة)';
  @override String get idocBCloneReset4 => 'أرقام السداد الإلكتروني وإيصالات نافذة: تم فك الارتباط';
  @override String idocBCloneDeclNote(String no) => '(مستنسخ كمسودة من الإقرار $no)';
  @override String get idocBAcidCloneEntity => 'طلب التسجيل المسبق للشحنات';
  @override String get idocBAcidCloneFieldImporter => 'المستورد';
  @override String get idocBAcidCloneFieldExporter => 'المصدر الأجنبي';
  @override String get idocBAcidCloneFieldCountry => 'بلد التصدير';
  @override String get idocBAcidCloneFieldProforma => 'رقم الفاتورة المبدئية';
  @override String get idocBAcidCloneFieldPorts => 'الموانئ';
  @override String get idocBAcidCloneReset1 => 'رقم ACID: يتم تصفيره إلى مسودة جديدة';
  @override String get idocBAcidCloneReset2 => 'حالة الإفراج الجمركي: ملغاة';
  @override String get idocBAcidCloneReset3 => 'تاريخ الطلب: يعاد ضبطه إلى تاريخ اليوم';
  @override String get idocBAcidCloneReset4 => 'معرف الجلسة السابق: تم فك الارتباط';
  @override String get idocBAcidReportTitle => 'تقرير مطابقة والتحقق الجمركي لبيانات ACID';
  @override String get idocBAcidReportOverallStatus => 'حالة المطابقة الإجمالية';
  @override String get idocBAcidReportFullyMatched => 'مطابق بالكامل';
  @override String get idocBAcidReportDiscrepancies => 'يوجد تعارض';
  @override String get idocBAcidReportMatchPercentage => 'نسبة المطابقة';
  @override String get idocBAcidReportRequested => 'المطلوب في أمر الشراء';
  @override String get idocBAcidReportGenerated => 'الفعلي الصادر من نافذة';
  @override String get idocBAcidReportOverride => 'مبرر التجاوز والاعتماد';
  @override String get idocBAcidRegistryStage => 'سجل أرقام ACID';
  @override String get idocBAcidExpiryStage => 'متتبع صلاحية ACID';
  @override String idocBLegalCompliantMessage(String eta, String window) => 'جميع المستندات القانونية (ACID، البطاقة الاستيرادية، السجل التجاري، البطاقة الضريبية) سارية وصالحة لما بعد موعد وصول الشحنة ($eta) بـ 30 يوماً على الأقل ($window).';
  @override String get idocBLegalCriticalTitle => 'تحذير قانوني وإجرائي حرج (تجاوز هامش الأمان: الوصول + 30 يوماً)';
  @override String idocBLegalEta(String eta) => 'تاريخ الوصول: $eta';
  @override String idocBLegalDocExpires(String doc, String date, String days) => '$doc: تنتهي في $date (متبقي $days يوم)';
  @override String get idocBCopyTable => 'نسخ الجدول';
  @override String get idocBExportExcel => 'تصدير Excel';
  @override String get idocBExportPdf => 'تصدير PDF';
  @override String get idocBNotExtracted => 'لم يتم الاستخراج';
  @override String get idocBMatched => 'متطابق';
  @override String get idocBFilterByFile => 'تصفية حسب ملف الشحنة';
  @override String get idocBSearchFileHint => 'بحث عن ملف شحنة...';
  @override String get idocBAllFiles => 'جميع الملفات الشحنية';
  @override String get idocBSessionTypeCol => 'نوع الجلسة';
  @override String get idocBSessionDraft => 'مسودة مؤقتة';
  @override String get idocBSessionCertified => 'معتمدة نهائية';
  @override String get idocBSessionDraftShort => 'مسودة مؤقتة';
  @override String get idocBSessionCertifiedShort => 'معتمدة نهائية';
  @override String get idocBConfirmDelete => 'تأكيد الحذف';
  @override String get idocBCooCloneEntity => 'مسودة شهادة المنشأ و EUR.1';
  @override String get idocBCooCloneFieldType => 'نوع الشهادة';
  @override String get idocBCooCloneFieldExporter => 'المصدر';
  @override String get idocBCooCloneFieldImporter => 'المستورد';
  @override String get idocBCooCloneFieldOrigin => 'بلد المنشأ';
  @override String get idocBCooCloneFieldDestination => 'بلد المقصد';
  @override String get idocBCooCloneFieldInvoice => 'رقم الفاتورة';
  @override String get idocBCooCloneReset1 => 'رقم شهادة المنشأ: يتم تصفيره إلى كود مسودة مؤقت جديد';
  @override String get idocBCooCloneReset2 => 'معرف جلسة المراجعة السابقة: تم فك الارتباط وبدء جلسة جديدة فارغة';
  @override String get idocBCooCloneReset3 => 'اعتمادات وملاحظات الفحص الجمركي: تعاد إلى حالة المسودة لتجنب تكرار الاعتماد القديم';
  @override String get idocBCooCloneReset4 => 'لقطة بيانات النظام: يتم تحديثها ومطابقتها مع ملف الشحنة المختار';
  @override String get idocBCooSavedDraft => 'تم حفظ مسودة جلسة مراجعة شهادة المنشأ بنجاح';
  @override String get idocBCooCertified => 'تم اعتماد جلسة مراجعة شهادة المنشأ وتحديث الموافقة الجمركية بنجاح';
  @override String get idocBCooSaveDraftBtn => 'حفظ مسودة مؤقتة';
  @override String get idocBCooCertifyBtn => 'اعتماد نهائي وتحديث الموافقة الجمركية';
  @override String get idocBCooSaveDraftAsBtn => 'حفظ كمسودة مؤقتة';
  @override String get idocBCooRegistrySubtitle => 'سجل جلسات فحص ومطابقة شهادات المنشأ و EUR.1 وحالات الاعتماد الجمركي';
  @override String get idocBCooKpiTotal => 'إجمالي الجلسات';
  @override String get idocBCooKpiCertified => 'جلسات معتمدة';
  @override String get idocBCooKpiDrafts => 'مسودات قيد المراجعة';
  @override String get idocBCooFilterStatus => 'تصفية الحالة:';
  @override String idocBCooFilterAll(int n) => 'الكل ($n)';
  @override String idocBCooFilterCertified(int n) => 'معتمدة فقط ($n)';
  @override String idocBCooFilterDrafts(int n) => 'مسودات فقط ($n)';
  @override String get idocBCooRestoreTooltip => 'استعادة وتحميل الجلسة في أداة الفحص';
  @override String get idocBCooDeleteDraftTooltip => 'حذف المسودة';
  @override String idocBCooRestored(String code) => 'تم استرجاع وتحميل بيانات الجلسة ($code) بنجاح';
  @override String get idocBCooDeleteTitle => 'تأكيد حذف مسودة شهادة المنشأ';
  @override String idocBCooDeleteConfirm(String code) => 'هل أنت متأكد من حذف مسودة الجلسة ($code)؟ لن يؤثر ذلك على بيانات الشحنة الأصلية.';
  @override String get idocBCooDeleted => 'تم حذف مسودة الجلسة بنجاح';
  @override String idocBCooCertLine(String no, String date) => 'رقم الشهادة: $no  |  تاريخ الإنشاء: $date';
  @override String get idocBCooRestoreBtn => 'استعادة وتحميل في أداة المراجعة';
  @override String get idocBCooRegistryStage => 'سجل شهادات المنشأ المبدئية';
  @override String get idocBBankCloneEntity => 'طلب وتوثيق نموذج 4 البنكي';
  @override String get idocBBankCloneFieldBank => 'البنك المعتمد';
  @override String get idocBBankCloneFieldAmount => 'قيمة الاعتماد';
  @override String get idocBBankCloneFieldNotes => 'ملاحظات وتوجيهات';
  @override String get idocBBankCloneReset1 => 'كود المستند البنكي: يتم تصفيره إلى مسودة جديدة';
  @override String get idocBBankCloneReset2 => 'تاريخ طلب النموذج: يعاد ضبطه إلى تاريخ اليوم';
  @override String get idocBBankCloneReset3 => 'حالة التوثيق والاعتماد: تعاد إلى قيد المعالجة';
  @override String get idocBBankCloneReset4 => 'معرف السجل السابق: تم فك الارتباط';
  @override String idocBBankReceiptTitle(String docType) => 'توثيق استلام $docType البنكي (DC-03)';
  @override String idocBBankReceiptIntro(String bank) => 'سجل رقم المستند البنكي الصادر من بنك ($bank) لربطه تلقائياً بملف الشحنة وترقية دورة الحياة إلى مرحلة الإقرار الجمركي 46.';
  @override String idocBBankReceiptNumLabel(String docType) => 'رقم $docType / رقم الاعتماد المعتمد *';
  @override String get idocBBankReceiptNumHint => 'مثال: F4-EG-2026-990011 أو LC-7788';
  @override String get idocBBankReceiptNumRequired => 'يرجى إدخال رقم المستند الصادر من البنك';
  @override String get idocBBankReceiptDateLabel => 'تاريخ الاستلام / الاعتماد *';
  @override String get idocBBankReceiptDateRequired => 'يرجى تحديد تاريخ الاستلام';
  @override String get idocBBankReceiptNotesLabel => 'ملاحظات التوثيق والفرع (اختياري)';
  @override String get idocBBankEndorsing => 'جاري التوثيق...';
  @override String get idocBBankEndorseAndLink => 'توثيق وربط بالشحنة';
  @override String get idocBBankEndorsedSuccess => 'تم توثيق وربط المستند البنكي بالشحنة وترقية دورة الحياة بنجاح.';
  @override String get idocBBankEndorseError => 'خطأ في توثيق المستند البنكي';
  @override String get idocBBankDocTypeLabel => 'نوع المعاملة / المستند البنكي *';
  @override String get idocBBankDocTypeHint => 'اختر نوع المعاملة';
  @override String get idocBBankTypeForm4 => 'نموذج 4 (مستندات تحصيل / دفعة مقدمة)';
  @override String get idocBBankTypeLc => 'اعتماد مستندي (L/C)';
  @override String get idocBBankTypeForm9 => 'نموذج 9 (إفراج دون تحويل)';
  @override String get idocBBankRefLabel => 'رقم المرجع البنكي / رقم الاعتماد (إن وجد)';
  @override String get idocBBankRefHint => 'اتركه فارغاً إذا كان قيد الطلب، أو اكتب: F4-2026-009 / LC-9988';
  @override String get idocBBankColDocType => 'نوع المعاملة';
  @override String get idocBBankColReference => 'رقم المرجع / الاعتماد';
  @override String get idocBBankEndorseTooltip => 'توثيق استلام نموذج 4 / الاعتماد (DC-03)';
  @override String get idocBBankRegistryStage => 'سجل النماذج البنكية';
  // === end review phase03_ui_b keys ===

  // === review phase04_05 keys (append below this line) ===
  @override String get dualClockStatusLast3Days => 'آخر 3 أيام سماح';
  @override String get dualClockStatusCritical72h => 'أقل من 72 ساعة قبل بدء غرامات الأرضيات';
  @override String dualClockHoursUntilPenalties(int hours) => 'متبقي $hours ساعة قبل بدء غرامات الأرضيات';
  @override String get dualClockTotalAccruedLabel => 'الإجمالي المستحق';
  @override String demCountdownSafe(int days, String date) => 'فترة السماح سارية: متبقي $days يوم بدون غرامات (حتى $date).';
  @override String demCountdownWarning(int days, String date) => 'تحذير: متبقي $days يوم فقط قبل بدء غرامات الأرضيات ($date).';
  @override String demCountdownDemurrage(int days) => 'بدأت غرامات الأرضيات: تجاوز $days يوم.';
  @override String demCountdownDetention(int days) => 'بدأت غرامات تأخير الحاويات الفارغة: تجاوز $days يوم.';
  @override String demCountdownExpired(int demDays, int detDays) => 'انتهت فترة السماح: تجاوز $demDays يوم أرضيات و$detDays يوم تأخير حاويات.';
  @override String emptyReturnRecordedSuccess(int returned, int total) => 'تم تسجيل إرجاع الحاويات الفارغة ($returned من $total).';
  @override String get freeDaysDocumentFailed => 'فشل في توثيق فترات السماح';
  @override String get emptyReturnRecordFailed => 'فشل تسجيل إرجاع الحاوية الفارغة';
  @override String get shipmentUpdateStageNameCustomsConsultation => 'استشارة جمركية';
  @override String get shipmentUpdateBtnSavePdf => 'حفظ PDF';
  @override String insuranceLoadedOfTotal(int loaded, int total) => 'تم تحميل $loaded من $total شهادة';
  @override String get insuranceLoadMoreBtn => 'تحميل المزيد';
  @override String listLoadedOfTotal(int loaded, int total) => 'تم تحميل $loaded من $total سجل';
  @override String get listLoadMoreBtn => 'تحميل المزيد';
  @override String get insuranceExportStageName => 'تأمين الشحنات';
  @override String get insuranceExportRegistryTag => 'السجل';
  @override String get fdaDialogTitle => 'توثيق اتفاقية فترات السماح المجانية (BK-02)';
  @override String get fdaIntro => 'وثّق فترات السماح المتفق عليها مع الخط الملاحي، وتُغذّي رادار الأرضيات وتأخير الحاويات تلقائياً.';
  @override String get fdaSectionAgreement => 'بيانات الاتفاقية';
  @override String get fdaLinkedImportFile => 'ملف الاستيراد المرتبط';
  @override String fdaCurrentFreeDays(int days) => 'فترات السماح الحالية: $days يوم';
  @override String get fdaSelectImportFile => 'يرجى اختيار ملف الاستيراد';
  @override String get fdaCarrier => 'الخط الملاحي';
  @override String get fdaAgreementDate => 'تاريخ الاتفاقية';
  @override String get fdaSectionFreeDays => 'فترات السماح المتفق عليها بالملحق';
  @override String get fdaPortDemurrage => 'أرضيات الحاويات بالميناء';
  @override String get fdaDetention => 'فترة استخدام الحاوية خارج الميناء';
  @override String get fdaPortStorage => 'فترة سماح ساحة الميناء';
  @override String fdaDaysCount(int days) => '$days يوم';
  @override String fdaDaysPlus(int days) => '+$days يوم';
  @override String get fdaEnterValidNumber => 'أدخل عدداً صحيحاً';
  @override String get fdaSectionReference => 'المرجع والملاحظات';
  @override String get fdaClauseRef => 'مرجع بند الاتفاقية / ملحق الحجز';
  @override String get fdaClauseRefHint => 'مثال: MSC-FREE-2026-0042 بند 4.2';
  @override String get fdaNotes => 'ملاحظات الاتفاقية';
  @override String get fdaNotesHint => 'مثال: تم التفاوض وتثبيت 21 يوماً لحاويات الخط';
  @override String get fdaSavingsTitle => 'تحليل الوفر المالي وتغذية رادار الغرامات';
  @override String fdaEstimatedSavings(String amount) => 'وفر متوقع: $amount / حاوية';
  @override String get fdaExtraDemDays => 'أيام إضافية Demurrage';
  @override String get fdaExtraDetDays => 'أيام إضافية Detention';
  @override String get fdaTotalProtected => 'مجموع الأيام المحمية';
  @override String fdaAboveTariff(int days) => 'فوق التعرفة القياسية ($days يوم)';
  @override String get fdaSafePeriod => 'فترة آمنة قبل بدء الغرامات';
  @override String get fdaOperationalNote => 'ملاحظة تشغيلية: بمجرد اعتماد هذه الاتفاقية، يتم تلقائياً تحديث ملف الاستيراد وحجز الشحن وإعادة ضبط عدادات الرادار لكافة الحاويات المسجلة.';
  @override String get fdaConfirmBtn => 'توثيق واعتماد فترات السماح (BK-02)';
  @override String get fdaSubmitting => 'جاري التوثيق...';
  @override String get fdaSuccess => 'تم توثيق فترات السماح وتحديث رادار الغرامات بنجاح';
  @override String fdaSuccessWithDays(int days) => 'تم توثيق فترات السماح ($days يوم) وتحديث رادار الغرامات بنجاح';
  @override String get lgxYes => 'نعم';
  @override String get lgxNo => 'لا';
  @override String get demHeaderFreeDaysBtn => 'فترات السماح (BK-02)';
  @override String get demReturnContainersBtn => 'إرجاع الحاويات (TR-05)';
  @override String get demReturnedEirBtn => 'تم الإرجاع (EIR)';
  @override String get demDaysSinceDischarge => 'أيام منذ التفريغ';
  @override String get demEnterFxHint => 'أدخل سعر الصرف لتشغيل المحاكاة';
  @override String get erTitle => 'تأكيد إرجاع الحاويات الفارغة للخط (EIR) — (TR-05)';
  @override String get erSubtitle => 'إصدار إيصال استلام الحاوية وإيقاف عدادات غرامات التأخير ونقل الملف للمرحلة الختامية';
  @override String get erSelectFileSnack => 'يرجى اختيار ملف الشحنة المراد إرجاع حاوياتها';
  @override String get erNoImportFiles => 'لا توجد ملفات استيراد مسجلة';
  @override String get erTargetFile => 'ملف الاستيراد المستهدف';
  @override String erContainerChip(String number) => 'الحاوية: $number';
  @override String get erFileHint => 'اختر ملف الاستيراد لتسليم حاوياته...';
  @override String get erDetailImporter => 'المستورد';
  @override String get erDetailSupplier => 'المورد';
  @override String get erDetailInland => 'حالة النقل الداخلي';
  @override String get erFilesLoadFailed => 'تعذر جلب ملفات الاستيراد';
  @override String get erRadarImpactTitle => 'أثر تسليم الحاوية الفارغة على رادار الغرامات ودورة الحياة:';
  @override String get erRadarImpactBody => '1. إيقاف احتساب عداد غرامات التأخير (Detention) فورياً.\n2. تحويل حالة الحاوية في رادار الغرامات إلى "RETURNED_SAFE" (تم الإرجاع بسلام).\n3. ترقية نسبة إنجاز الشحنة إلى 98% ونقل الملف رسمياً للمرحلة التاسعة: تكلفة الوصول والتسوية الختامية (CLO-01).';
  @override String get erSectionHandover => 'بيانات التسليم';
  @override String get erEirLabel => 'رقم إيصال استلام الحاوية';
  @override String get erRegenerate => 'توليد جديد';
  @override String get erEirValidation => 'يرجى إدخال رقم إيصال EIR صحيح (3 أحرف على الأقل)';
  @override String get erReturnDate => 'تاريخ الإرجاع الفعلي';
  @override String get erDepotLabel => 'مستودع ومحطة إرجاع الحاويات';
  @override String get erDepotHint => 'اختر ساحة ومستودع الخط الملاحي...';
  @override String get erConditionTitle => 'حالة سلامة الحاوية عند التسليم الفعلي';
  @override String get erCondSound => 'سليمة ونظيفة (Sound & Clean)';
  @override String get erCondSoundSub => 'خالية من أي تلفيات أو أضرار';
  @override String get erCondMinor => 'تلفيات طفيفة';
  @override String get erCondMinorSub => 'خدوش أو انحناءات طفيفة';
  @override String get erCondRepair => 'تتطلب إصلاحاً';
  @override String get erCondRepairSub => 'تلفيات بالأرضية أو الباب';
  @override String get erDamageNotes => 'ملاحظات وتفاصيل التلفيات بالمعاينة';
  @override String get erDamageNotesHint => 'مثال: انحناء بسيط بالقائم الأيمن والباب';
  @override String get erDamageFee => 'غرامة الإصلاح بالدولار';
  @override String get erSectionTransport => 'النقل والملاحظات';
  @override String get erDriver => 'اسم سائق شاحنة الإرجاع (اختياري)';
  @override String get erTruckPlate => 'رقم لوحة الشاحنة (اختياري)';
  @override String get erExtraNotes => 'ملاحظات إضافية على تسليم الحاوية الفارغة';
  @override String get erSubmitting => 'جاري إثبات التسليم...';
  @override String get erConfirmBtn => 'تأكيد الإرجاع واستلام إيصال EIR';
  @override String get dualClockExpiryLabel => 'ينتهي السماح في';
  @override String get cshDryContainer => 'حاوية نمطية قياسية';
  @override String get cshHighCubeContainer => 'حاوية مرتفعة السعة';
  @override String get cshSuperHighCubeContainer => 'حاوية فائقة السعة';
  @override String get cshReeferContainer => 'حاوية مبردة';
  @override String get cshCloneEntityType => 'شحنة وتخصيص حاويات';
  @override String get cshCloneFieldShipmentType => 'نوع الشحن';
  @override String get cshCloneFieldContainers => 'تخصيص الحاويات';
  @override String get cshCloneFieldVgm => 'إجمالي الوزن المعتمد';
  @override String get cshCloneFieldCfs => 'مستودع الشحن التجميعي';
  @override String get cshCloneReset1 => 'معرف الشحنة (Shipping ID): يتم تفريغه لتوليد سجل جديد';
  @override String get cshCloneReset2 => 'كود الشحنة (Shipping Code): يعاد تعيينه كمسودة (DRAFT)';
  @override String get cshCloneReset3 => 'ملف الاستيراد: يتطلب إعادة الربط بملف استيراد جديد أو قيد التجهيز';
  @override String get cshCloneReset4 => 'حالة تتبع الحاويات: تعاد للبدء المبدئي (ASSIGNED / Cargo Ready)';
  @override String get cshCloneReset5 => 'سجل المهل وتواريخ التحميل (48h SLA): تعاد للتهيئة والتوقيت الجديد';
  @override String cshWeightKg(String value) => '$value كجم';
  @override String get cshLclConsolidation => 'تجميع LCL';
  @override String get cshStandard40hc => 'حاوية 40HC قياسية';
  @override String get cshColCode => 'كود الشحنة';
  @override String get cshColImportFile => 'ملف الاستيراد';
  @override String get cshColCompany => 'الشركة المستوردة';
  @override String get cshColShipType => 'نوع الشحن';
  @override String get cshColContainersSeals => 'الحاويات وأرقام الأقفال';
  @override String get cshColContainers => 'الحاويات المخصصة';
  @override String get cshColTotalVgm => 'إجمالي الوزن المعتمد';
  @override String get cshColStatus => 'الحالة';
  @override String get cshColGateIn => 'دخول بوابة الميناء';
  @override String get cshColSla => 'موقف مهلة 48h SLA';
  @override String get cshColOp => 'الحالة التشغيلية';
  @override String get cshColContainersShort => 'الحاويات';
  @override String get cshColWeightShort => 'إجمالي الوزن';
  @override String get cshColGateInShort => 'دخول الميناء';
  @override String get cshColSlaShort => 'مهلة 48h';
  @override String get cshStateActive => 'نشط';
  @override String get cshStateDeleted => 'محذوف';
  @override String get cshPdfTitle => 'سجل تخصيص الحاويات ومتابعة الشحن';
  @override String get cshPdfSubtitle => 'Sorour Logistics ERP — سجل تخصيص الحاويات ومتابعة الشحن';
  @override String get cshPdfMetaTotal => 'إجمالي السجلات';
  @override String get cshPdfMetaFcl => 'شحنات FCL';
  @override String get cshPdfMetaLcl => 'شحنات LCL';
  @override String get cshSmartSimTooltip => 'المحاكاة الذكية: توليد تواريخ ومحطات دورة التحميل والـ VGM ودخول الميناء تلقائياً في النموذج';
  @override String get cshSmartSimBtn => '⚡ محاكاة تشغيلية ذكية ⚡';
  @override String get cshSmartSimDone => 'تمت المحاكاة الذكية واستيفاء دورة التحميل ودخول الميناء بنجاح! اضغط على "حفظ واعتماد إنهاء المرحلة" للتأكيد والترحيل.';
  @override String get cshSaveCompleteBtn => 'حفظ واعتماد إنهاء المرحلة (STEP-07)';
  @override String get cshUpdateCompleteBtn => 'تحديث واعتماد إنهاء المرحلة (STEP-07)';
  @override String cshContainerDuplicated(String type) => 'تم تكرار الحاوية بنجاح ($type)';
  @override String get cshMetricRecords => 'الشحنات';
  @override String get cshAll => 'الكل';
  @override String get cshCloneSearchHint => 'ابحث برقم الشحنة، الحاوية، القفل، أو ملف الاستيراد...';
  @override String get cshCloneTypeLabel => 'نوع الشحن: ';
  @override String get cshCloneStatusLabel => 'الحالة: ';
  @override String get cshCloneNoMatches => 'لا توجد شحنات سابقة مطابقة لمعايير البحث';
  @override String cshCloneFileLine(String file, String company) => 'ملف: $file | $company';
  @override String cshCloneContainersLine(String list) => 'الحاويات: $list';
  @override String get cshCloneBtn => 'استنساخ';
  @override String insPolicyShort(String number) => 'وثيقة: $number';
  @override String get insPendingOnDemand => 'قيد الإصدار / عند الطلب';
  @override String insVoyage(String voyage) => 'رحلة: $voyage';
  @override String get insGeneralCargo => 'بضائع تجارية عامة';
  @override String get insPackagesDefault => 'طرود';
  @override String get insKgUnit => 'كجم';
  @override String get insClaimsDefault => 'القاهرة، مصر';
  @override String insInCurrency(String currency) => 'بعملة $currency';
  @override String get demFxRateRequired => 'أدخل سعر صرف الدولار مقابل الجنيه';
  @override String get demFxRateMissingHint => 'لا يوجد سعر تجاري للدولار مسجل في العملات. أدخل السعر يدوياً.';
  @override String get demFxRateFromCurrencies => 'آخر سعر تجاري من شاشة العملات';
  @override String demFdaAboveFileDays(int days) => 'أعلى من أيام السماح الحالية للملف ($days)';
  @override String get demFdaNoBaseline => 'لا يوجد أساس مسجل';
  @override String get demFdaNoTariffNote => 'لا يتم تقدير التوفير المالي: لا توجد تعريفة للخط الملاحي لهذا الحساب.';
  @override String get cshCargoMetricsMissing => 'بيانات الحمولة غير متوفرة (لا يوجد حجم أو وزن في أوامر الشراء / قوائم التعبئة المرتبطة). لا يتم احتساب توصية الحاويات.';
  @override String get suMetricTotalUpdates => 'التحديثات';
  @override String get suMetricCompletedPhases => 'المراحل المكتملة';
  @override String get suSectionShipment => 'الشحنة وتصنيف التحديث';
  @override String get suSectionDetails => 'تفاصيل التحديث';
  @override String get fbkMetricBookings => 'الحجوزات';
  @override String get fbkMetricDelayed => 'تأخر الإبحار';
  @override String fbkFilterShipmentChip(String code) => 'تصفية: شحنة $code';
  @override String get fbkInactiveBadge => 'غير نشط';
  @override String get fbkTipCopyRow => 'نسخ الصف';
  @override String get fbkTipConfirmBooking => 'تأكيد الحجز ومواعيد الإبحار (BK-01)';
  @override String get fbkTipConfirmDeparture => 'تأكيد الإبحار الفعلي وإصدار بوليصة الشحن (SH-01)';
  @override String get fbkTipUpdateBl => 'تحديث بوليصة الشحن والإبحار (SH-01)';
  @override String get fbkTipReviewDraftBl => 'مراجعة مسودة البوليصة والاعتماد المزدوج (SH-02)';
  @override String get fbkStatusTipConfirmed => 'الحجز مؤكد — انقر لتأكيد الإبحار وبوليصة الشحن (SH-01)';
  @override String fbkStatusTipSailed(String bl) => 'أبحرت الشحنة (B/L: $bl) — انقر لتحديث البيانات';
  @override String get fbkStatusTipPending => 'انقر لتأكيد الحجز وتثبيت المواعيد (BK-01)';
  @override String get fbkCloneEntityType => 'حجز شحن بحري / جوي';
  @override String get fbkCloneReset1 => 'رقم تأكيد الحجز (Confirmation No): يتم تفريغه للمسودة الجديدة';
  @override String get fbkCloneReset2 => 'اسم السفينة ورقم الرحلة (Vessel & Voyage): يتطلب إعادة تأكيد';
  @override String get fbkCloneReset3 => 'تاريخ المغادرة الفعلي (ATD): غير محدد للمسودة الجديدة';
  @override String get fbkCloneReset4 => 'حالة الحجز: تعاد إلى مسودة قيد الإعداد (Draft)';
  @override String get fbkSectionFile => 'الملف ورقم التأكيد';
  @override String get fbkSectionCarrierRoute => 'الناقل والمسار';
  @override String get fbkSectionSchedule => 'مواعيد الإبحار والوصول';
  @override String get fbkSectionTerms => 'الأيام المجانية والحالة';
  @override String get fbkSectionVessel => 'السفينة والرحلة';
  @override String get fbkSectionEquipment => 'الحاويات المطلوبة';
  @override String get fbkSelectHint => 'اختر...';
  @override String get fbkSelectDate => 'اختر التاريخ';
  @override String get fbkValidatorImportFile => 'اختر ملف الشحنة الاستيرادية';
  @override String get fbkValidatorShippingLine => 'اختر الخط الملاحي';
  @override String get fbkValidatorPol => 'اختر ميناء التحميل';
  @override String get fbkValidatorPod => 'اختر ميناء الوصول';
  @override String get fbkValidatorEtd => 'حدد تاريخ المغادرة المتوقع';
  @override String get fbkValidatorEta => 'حدد تاريخ الوصول المتوقع';
  @override String get fbkValidatorFreeDays => 'أدخل عدد أيام صحيح (صفر أو أكثر)';
  @override String get fbkEquipmentNote => 'تخصيص الحاويات التفصيلي وأرقام السيل وأوزان VGM والفحص تتم في مرحلة متابعة وتجهيز التحميل.';
  @override String get fbkAuditLogBtn => 'سجل التدقيق';
  @override String fbkAuditEntityTitle(String code) => 'حجز الشحن $code';
  @override String get fbkDupOwner => 'المستخدم المسؤول';
  @override String get fbkDupLastUpdated => 'آخر تحديث';
  @override String get fbkNotesOptional => 'ملاحظات وتوجيهات الحجز (اختياري)';
  @override String get fbkDaysSuffix => 'يوم';
  @override String get fbkConfirmTitle => 'تأكيد حجز الشحن والناقل (BK-01)';
  @override String get fbkConfirmInfo => 'تأكيد الحجز برقم التأكيد الفعلي (Booking No) ينقل ملف الشحنة تلقائياً إلى STEP_07 ويُغلق مهام BK-01 ويُنشئ مهمة متابعة فترات السماح (BK-02).';
  @override String get fbkConfirmNoLabel => 'رقم تأكيد الحجز (Booking No / Booking Confirmation) *';
  @override String get fbkConfirmNoValidator => 'يرجى إدخال رقم تأكيد الحجز من الخط الملاحي';
  @override String get fbkConfirmFreeDaysLabel => 'أيام السماح المجانية المتفق عليها (Free Demurrage Days) *';
  @override String get fbkConfirmFreeDaysRequired => 'يرجى تحديد أيام السماح';
  @override String get fbkConfirmBtn => 'تأكيد الحجز وتثبيته (BK-01)';
  @override String get fbkConfirmSuccess => 'تم تأكيد حجز الشحن بنجاح (BK-01) وترقية المرحلة إلى STEP_07 وتغذية رادار فترات السماح';
  @override String fbkConfirmError(String error) => 'تعذر تأكيد الحجز: $error';
  @override String get fbkDepTitle => 'تأكيد الإبحار الفعلي وإصدار بوليصة الشحن (SH-01)';
  @override String get fbkDepNotLinked => 'غير مرتبط';
  @override String fbkDepCarrier(String name) => 'الخط الملاحي: $name';
  @override String fbkDepRoute(String pol, String pod) => 'المسار: $pol ➔ $pod';
  @override String fbkDepDelayed(int days) => 'تأخر إبحار: $days يوم';
  @override String get fbkDepOnSchedule => 'إبحار وفق الجدول المحدد';
  @override String get fbkDepSectionBl => 'بوليصة الشحن والمواعيد الفعلية';
  @override String get fbkDepBolLabel => 'رقم بوليصة الشحن (Bill of Lading No / Master B/L) *';
  @override String get fbkDepBolRequired => 'يرجى إدخال رقم بوليصة الشحن B/L';
  @override String get fbkDepBolShort => 'رقم البوليصة يجب ألا يقل عن 3 أحرف/أرقام';
  @override String get fbkDepAtdLabel => 'تاريخ الإبحار الفعلي (ATD) *';
  @override String get fbkDepRevisedEtaLabel => 'موعد الوصول المحدث';
  @override String get fbkDepAuto => 'تلقائي';
  @override String get fbkDepSobLabel => 'تاريخ الشحن على ظهر السفينة';
  @override String fbkDepSobSameAsAtd(String date) => 'نفس تاريخ الإبحار الفعلي ($date)';
  @override String get fbkDepNotesLabel => 'ملاحظات خط الملاحة ومحطات الترانزيت (اختياري)';
  @override String fbkDepNotesHint(int days) => 'مثال: الشحنة أبحرت مباشرة، الترانزيت المتوقع $days يوم بدون تأخير...';
  @override String get fbkDepAutoTitle => 'المعالجة الآلية الفورية عند الحفظ';
  @override String get fbkDepAutoBody => '• تحويل حالة الشحنة إلى In-Transit / On Water بنسبة إنجاز 60%+\n• تحديث رادار غرامات الحاويات (Demurrage) برقم بوليصة الشحن\n• إغلاق مهام الإبحار وإطلاق مهمة (SH-02): المراجعة المزدوجة لمسودة البوليصة\n• بث إشعار تشغيلي رسمي لغرفة العمليات بموعد الوصول المحدث';
  @override String get fbkDepBtn => 'تأكيد الإبحار وإصدار البوليصة';
  @override String get fbkDepBtnBusy => 'جاري توثيق الإبحار...';
  @override String fbkDepSuccess(String bl) => 'تم تأكيد الإبحار الفعلي بنجاح وتسجيل بوليصة الشحن رقم ($bl) وانتقال الشحنة لحالة In-Transit';
  @override String fbkDepError(String error) => 'تعذر تأكيد الإبحار: $error';
  @override String get fbkStatusCancelled => 'ملغي';
  @override String get fbkMixedCurrencyError => 'يجب أن تستخدم كافة بنود التكلفة عملة واحدة حتى تتوفر ميزة تحويل العملات';
  @override String get demPushNeedsLinkedFile => 'لا يمكن الترحيل للتسوية المالية: يجب ربط ملف استيراد أولاً';
  @override String get demPushConfirmTitle => 'تأكيد الترحيل للتسوية المالية';
  @override String get demPushConfirmMessage => 'هل أنت متأكد من ترحيل مصاريف الأرضيات وغرامات التأخير إلى ملف التسوية المالية؟';
  @override String get demPushConfirmFileCode => 'ملف الاستيراد';
  @override String get demPushConfirmDemurrageFx => 'إجمالي غرامات التأخير';
  @override String get demPushConfirmDetentionFx => 'إجمالي غرامات الحاويات';
  @override String get demPushConfirmStorageEgp => 'إجمالي رسوم التخزين';
  @override String get demPushConfirmRate => 'سعر الصرف';
  @override String get demPushConfirmTotalEgp => 'إجمالي تكلفة التسوية';
  @override String get demPushConfirmBtn => 'تأكيد والترحيل';
  // === end review phase04_05 keys ===

  // === review phase06_07 keys (append below this line) ===
  @override String get ccBondReleaseDateLabel => 'تاريخ الإفراج المؤقت';
  @override String get ccTestCompletionDateLabel => 'تاريخ اكتمال الفحص المعملي';
  @override String get ccCustomsFxRateHint => 'أدخل سعر الصرف الجمركي المعتمد';
  @override String get ccVatAmountLabel => 'قيمة ضريبة القيمة المضافة (تُدخل يدوياً)';
  @override String get ccVatCheckboxLabel => 'الفاتورة تتضمن ضريبة القيمة المضافة';
  @override String get ccWhtAmountLabel => 'مبلغ ضريبة الخصم المقتطعة (يُدخل يدوياً)';
  @override String ccLoadInvoicesError(String error) => 'تعذر تحميل فواتير التخليص: $error';
  @override String get ccStageBrokerAuth => 'تفويض المخلص (CS-01)';
  @override String get ccStageDeliveryOrder => 'سداد إذن التسليم (CS-02)';
  @override String get ccStageDeclaration46 => 'قيد إقرار 46 (CS-03)';
  @override String get ccStageInspection => 'الكشف والمعاينة (CL-01)';
  @override String get ccStageAssessment => 'حساب الرسوم (CL-02)';
  @override String get ccStageDutyPayment => 'سداد الرسوم (CL-03)';
  @override String get ccStageRelease => 'إذن الإفراج (CL-04)';
  @override String get ccStageInvoices => 'فواتير التخليص (CL-05)';
  @override String get ccNoImportFiles => 'لا توجد ملفات شحنات مسجلة';
  @override String get ccRecordFileNotFound => 'لم يتم العثور على ملف الشحنة المرتبط';
  @override String get ccExpensesTooltip => 'فواتير ومصاريف التخليص (CL-05)';
  @override String get ccMetricAssessed => 'محتسبة';
  @override String get ccMetricPaid => 'مسددة';
  @override String get ccMetricOutstanding => 'مستحقة';
  @override String get ccMetricReleased => 'تم الإفراج';
  @override String get ccCloneEntityType => 'بيان تخليص ومعاينة جمركية';
  @override String get ccCloneFieldOffice => 'الجمرك / المركز';
  @override String get ccCloneFieldChannel => 'المسار الجمركي';
  @override String get ccCloneFieldImportDuty => 'ضريبة الوارد';
  @override String get ccCloneFieldVat => 'ضريبة القيمة المضافة';
  @override String get ccCloneFieldScheduleTax => 'ضريبة الجدول';
  @override String get ccCloneFieldWht => 'ضريبة الخصم والإضافة';
  @override String get ccCloneFieldLabFees => 'رسوم الفحص المعملي';
  @override String get ccCloneFieldTotalDuty => 'إجمالي الرسوم الجمركية';
  @override String get ccCloneFieldFreeDays => 'فترة السماح بالميناء';
  @override String ccCloneDaysValue(int days) => '$days يوم';
  @override String get ccCloneReset1 => 'معرف التخليص الجمركي: يتم تفريغه لتوليد سجل بيان جمركي جديد';
  @override String get ccCloneReset2 => 'كود المعاملة: يعاد تعيينه كمسودة (CLR-DRAFT)';
  @override String get ccCloneReset3 => 'رقم 46 ك.م وإذن التسليم: يتم تفريغهم لحين القيد والتسليم الفعلي للبيان الجديد';
  @override String get ccCloneReset4 => 'حالة السداد وإيصال البنك: يعاد ضبطها إلى "غير مسدد" ومسح الإيصالات السابقة';
  @override String get ccCloneReset5 => 'تصريح وتاريخ الإفراج الجمركي: يتم تفريغهما لحين إنهاء إجراءات الإفراج';
  @override String get ccCloneReset6 => 'حالة المعاملة: تعاد للبدء المبدئي (قيد المعاينة والفحص)';
  @override String get ccExportRegistryTitle => 'سجل الميناء والتخليص الجمركي والمعاينة والمطابقة';
  @override String get ccExportRegistrySubtitle => 'Sorour Logistics ERP - سجل الميناء والتخليص الجمركي والمعاينة والمطابقة';
  @override String get ccExportMetaTotal => 'إجمالي السجلات';
  @override String get ccExportMetaPaid => 'مسدد ومدقق';
  @override String get ccExportMetaRelease => 'الإفراج النهائي';
  @override String get ccPayingBankLabel => 'البنك المسدد من خلاله (اختياري)';
  @override String get ccPaymentDateLabel => 'تاريخ السداد';
  @override String get ccReleaseDateLabel => 'تاريخ الإفراج';
  @override String get ccFormSectionDeclaration => 'بيانات البيان الجمركي';
  @override String get ccFormSectionDuties => 'الرسوم والضرائب';
  @override String ccqRfqTitleForBroker(String broker) => 'طلب تخليص جمركي - $broker';
  @override String ccqCodedItemsBadge(int count) => '$count بند مكوّد';
  @override String ccqUncodedItemsBadge(int count) => '$count بحاجة لتكويد';
  @override String get ccqMetricRfqs => 'طلبات التسعير';
  @override String get ccqMetricPriceItems => 'بنود الأسعار';
  @override String get ccSampleDefaultAuthority => 'الهيئة العامة للرقابة على الصادرات والواردات';
  @override String get ccSampleDefaultTestType => 'فحص ظاهري ومطابقة معملية';
  @override String get ccDutyDialogTitle => 'سداد الرسوم والضرائب الجمركية عبر سداد / E-Finance (CL-03)';
  @override String ccDutyChipDecl(String value) => 'إقرار 46: $value';
  @override String ccDutyChipClaim(String value) => 'مطالبة: $value';
  @override String get ccDutyAssessedTotalLabel => 'إجمالي الرسوم المعتمدة بمطالبة نافذة MTS';
  @override String get ccDutyAwaitingAssessment => 'في انتظار الاحتساب المالي';
  @override String get ccDutyStageBadge => 'مرحلة السداد المالي (CL-03)';
  @override String get ccDutyPaymentSection => 'بيانات السداد الإلكتروني والبنكي';
  @override String get ccDutySadadLabel => 'رقم سداد الإلكتروني';
  @override String get ccDutySadadHint => 'مثال: SADAD-2026-0042';
  @override String get ccDutyAutoGenerate => 'توليد تلقائي';
  @override String get ccDutySadadRequired => 'رقم سداد إلزامي';
  @override String get ccDutySadadTooShort => 'رقم سداد يجب ألا يقل عن 3 أحرف';
  @override String get ccDutyReceiptLabel => 'رقم إشعار / إيصال السداد البنكي';
  @override String get ccDutyReceiptHint => 'مثال: REC-EFIN-998877';
  @override String get ccDutyReceiptRequired => 'رقم الإيصال إلزامي';
  @override String get ccDutyAmountLabel => 'المبلغ المسدد فعلياً (ج.م)';
  @override String get ccDutyAmountRequired => 'المبلغ المسدد إلزامي';
  @override String get ccDutyAmountInvalid => 'يجب إدخال قيمة صحيحة أكبر من 0';
  @override String get ccDutyDateLabel => 'تاريخ السداد';
  @override String get ccDutyMethodLabel => 'طريقة السداد';
  @override String get ccDutyBankLabel => 'البنك المسدد من خلاله';
  @override String get ccDutyBankRequired => 'يرجى اختيار البنك القائم بالسداد';
  @override String get ccDutyAttachmentsSection => 'المرفقات والملاحظات الرقابية';
  @override String get ccDutyReceiptFileLabel => 'رابط أو مرجع إيصال السداد الإلكتروني';
  @override String get ccDutyReceiptFileHint => 'مثال: /uploads/receipts/sadad_rec_2026_01.pdf';
  @override String get ccDutyNotesLabel => 'ملاحظات السداد والتحقق المالي';
  @override String get ccDutyNotesHint => 'أي ملاحظات إضافية بخصوص إشعار السداد أو الخصم البنكي...';
  @override String get ccDutyConfirm => 'تأكيد وتسجيل سداد الرسوم (CL-03)';
  @override String get ccDutyConfirming => 'جاري الاعتماد...';
  @override String ccDutySuccess(String sadad, String amount) => 'تم تسجيل سداد الرسوم الجمركية بنجاح برقم سداد ($sadad) ومبلغ ($amount ج.م). تم الانتقال للمرحلة التالية: إذن الإفراج النهائي (CL-04).';
  @override String ccDutyError(String error) => 'حدث خطأ أثناء تسجيل سداد الرسوم: $error';
  @override String get ccCurrencyShort => 'ج.م';
  @override String get ccAssessTitle => 'احتساب الرسوم والضرائب الجمركية النهائية (CL-02)';
  @override String get ccAssessSubtitle => 'Final Customs Duty & Tax Assessment — مطابقة المطالبة الجمركية بنظام نافذة MTS';
  @override String ccAssessFileChip(String code) => 'ملف #$code';
  @override String get ccAssessClaimSection => 'بيانات المطالبة الجمركية بنظام نافذة MTS';
  @override String get ccAssessClaimNoLabel => 'رقم المطالبة الجمركية بنظام نافذة *';
  @override String get ccAssessClaimNoHint => 'مثال: CLM-MTS-2026-998822';
  @override String get ccAssessClaimNoRequired => 'يرجى إدخال رقم المطالبة الجمركية';
  @override String get ccAssessClaimNoTooShort => 'رقم المطالبة يجب ألا يقل عن 3 أحرف';
  @override String get ccAssessClaimDateLabel => 'تاريخ المطالبة الجمركية *';
  @override String get ccAssessCifLabel => 'القيمة المقبولة جمركياً (CIF Base بالجنيه) *';
  @override String get ccAssessCifRequired => 'القيمة الجمركية CIF مطلوبة';
  @override String get ccAssessPositiveValue => 'يرجى إدخال قيمة صحيحة أكبر من 0';
  @override String get ccAssessFxLabel => 'سعر الصرف الجمركي الرسمي *';
  @override String get ccAssessFxRequired => 'سعر الصرف مطلوب';
  @override String get ccAssessFxPositive => 'سعر الصرف يجب أن يكون أكبر من 0';
  @override String get ccAssessBreakdownSection => 'تفصيل بنود الرسوم والضرائب الجمركية (HS Code Duty Breakdown)';
  @override String get ccAssessImportDuty => 'ضريبة الوارد الجمركية *';
  @override String get ccAssessImportDutyRequired => 'ضريبة الوارد مطلوبة';
  @override String get ccAssessInvalidValue => 'قيمة غير صالحة';
  @override String get ccAssessVat => 'ضريبة القيمة المضافة *';
  @override String get ccAssessVatRequired => 'ضريبة القيمة المضافة مطلوبة';
  @override String get ccAssessScheduleTax => 'ضريبة الجدول';
  @override String get ccAssessDevFee => 'رسم التنمية';
  @override String get ccAssessServiceFees => 'رسوم الخدمات الجمركية وأ.ت.ص';
  @override String get ccAssessWht => 'ضريبة الخصم والإضافة';
  @override String get ccAssessLabFees => 'رسوم التحاليل والمعامل';
  @override String get ccAssessNotesSection => 'ملاحظات وتوجيهات التثمين والاحتساب النهائي';
  @override String get ccAssessNotesHint => 'ملاحظات وتوجيهات مأمور التعريفة أو أي بنود استثنائية...';
  @override String get ccPreviousNotesLabel => 'الملاحظات السابقة';
  @override String get ccStepNotesLabel => 'ملاحظات هذه المرحلة';
  @override String ccAssessTotalDue(String amount) => 'الإجمالي المستحق بالسداد: $amount ج.م';
  @override String get ccAssessConfirm => 'اعتماد واحتساب الرسوم (CL-02)';
  @override String ccAssessSuccess(String claim, String total) => 'تم احتساب واعتماد الرسوم الجمركية بمطالبة #$claim بإجمالي ($total ج.م). تم الانتقال للمرحلة التالية: سداد الرسوم بسداد (CL-03).';
  @override String ccAssessError(String error) => 'حدث خطأ أثناء اعتماد الرسوم الجمركية: $error';
  @override String get ccAssessVarianceTitle => 'مطابقة الرسوم الفعلية مع التقديرية';
  @override String get ccAssessBadgeInitial => 'تثمين أولي (بدون تقدير سابق)';
  @override String ccAssessBadgeSaving(String pct) => 'وفر بالرسوم (-$pct%)';
  @override String ccAssessBadgeMinor(String pct) => 'انحراف طفيف (+$pct%)';
  @override String ccAssessBadgeMajor(String pct) => 'انحراف ملحوظ (+$pct%)';
  @override String get ccAssessEstimatedTile => 'الرسوم التقديرية المبدئية';
  @override String get ccAssessNotSet => 'غير محددة';
  @override String get ccAssessActualTile => 'إجمالي المطالبة الفعلية';
  @override String get ccAssessVarianceTile => 'قيمة الانحراف الجمركي';
  @override String get ccAssessVarianceReason => 'سبب انحراف الرسوم الفعلية عن التقديرية';
  @override String get ccAssessVarianceReasonHint => 'مثال: تعديل مأمور التعريفة لبند HS Code أو زيادة تقييم CIF';
  @override String get ccRelTitle => 'صدور إذن الإفراج الجمركي الأخضر وبدء النقل (CL-04)';
  @override String ccRelChipFile(String name) => 'ملف: $name';
  @override String ccRelChipDecl(String value) => 'شهادة 46: $value';
  @override String get ccRelSumDecl => 'رقم الإقرار (شهادة 46)';
  @override String get ccRelSumSadad => 'رقم سداد الرسوم';
  @override String get ccRelSumPaid => 'الرسوم المسددة';
  @override String get ccRelSumPort => 'ميناء الوصول';
  @override String get ccRelPermitSection => 'بيانات إذن الإفراج الجمركي الأخضر';
  @override String get ccRelPermitNoLabel => 'رقم إذن الإفراج الأخضر *';
  @override String get ccRelPermitNoHint => 'مثال: REL-2026-0004';
  @override String get ccRelPermitAuto => 'توليد رقم إذن تلقائي';
  @override String get ccRelPermitRequired => 'رقم إذن الإفراج إلزامي';
  @override String get ccRelPermitTooShort => 'الرقم قصير جداً';
  @override String get ccRelDateLabel => 'تاريخ صدور الإفراج *';
  @override String get ccRelOfficerLabel => 'اسم مأمور الجمرك / المفرج';
  @override String get ccRelOfficerHint => 'اسم المفتش أو مأمور الإفراج';
  @override String get ccRelTypeLabel => 'نوع الإفراج الجمركي';
  @override String get ccRelGateSection => 'تصريح خروج البوابة وإجراءات النقل الداخلي (Port Gate-Out & Transport)';
  @override String get ccRelGatePassLabel => 'رقم تصريح الخروج من بوابة الميناء';
  @override String get ccRelGatePassHint => 'مثال: GP-2026-0004';
  @override String get ccRelGatePassAuto => 'توليد رقم تصريح تلقائي';
  @override String get ccRelGateOutDateLabel => 'تاريخ الخروج من الميناء';
  @override String get ccRelNotSet => 'غير محدد';
  @override String get ccRelDemurrageLabel => 'رسوم الأرضيات وغرامات التأخير إن وجدت (ج.م)';
  @override String get ccRelAmountInvalid => 'أدخل مبلغاً صحيحاً';
  @override String get ccRelDocUrlLabel => 'رابط ملف إذن الإفراج (PDF / صورة)';
  @override String get ccRelDispatchTitle => 'تصريح مغادرة ونقل الشحنة';
  @override String get ccRelDispatchDesc => 'تأكيد جاهزية الحاوية للشحن الداخلي وبدء توجيه أسطول النقل للمستودعات';
  @override String get ccRelTransportLabel => 'تعليمات النقل والتوجيه لمخازن الشركة';
  @override String get ccRelTransportHint => 'تحديد موقع التعتيق، تعليمات السلامة الجمركية، وجهة التسليم...';
  @override String get ccRelNotesLabel => 'ملاحظات وتوجيهات إضافية';
  @override String get ccRelNotesHint => 'أية توجيهات للمخلص الجمركي أو إدارة العمليات...';
  @override String get ccRelConfirm => 'إصدار إذن الإفراج النهائي وتفويض النقل';
  @override String get ccRelConfirming => 'جاري إصدار الإفراج...';
  @override String ccRelSuccess(String permit) => 'تم صدور إذن الإفراج الجمركي الأخضر برقم ($permit) وتفويض النقل بنجاح! تم تنشيط مهام النقل للمخازن (TR-01 & TR-02).';
  @override String ccRelError(String error) => 'حدث خطأ أثناء إصدار إذن الإفراج: $error';
  @override String get ccInsTitle => 'تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة (CL-01)';
  @override String get ccInsChipStage => 'المرحلة السابعة: التخليص والإفراج الجمركي';
  @override String ccInsChipFile(String code, String company) => 'ملف الشحنة: $code ($company)';
  @override String get ccInsBadgeDecl => 'رقم الإقرار الجمركي 46';
  @override String get ccInsBadgeDeclFallback => 'مسجل بنموذج 46';
  @override String get ccInsBadgeChannel => 'المسار الجمركي المحدد';
  @override String get ccInsBadgeChannelValue => 'المسار الأحمر الفعلي';
  @override String get ccInsBadgeDate => 'تاريخ القيد الجمركي';
  @override String get ccInsSection1 => 'أولاً: بيانات الكشف والمعاينة الميدانية بالميناء';
  @override String get ccInsYardLabel => 'ساحة / رصيف المعاينة والكشف بالميناء *';
  @override String get ccInsYardHint => 'اختر ساحة الفحص...';
  @override String get ccInsYardRequired => 'يرجى تحديد ساحة المعاينة';
  @override String get ccInsResultRequired => 'يرجى تحديد نتيجة المعاينة والفحص';
  @override String get ccInsBodiesRequired => 'يرجى تحديد جهة رقابية واحدة على الأقل عند سحب العينات';
  @override String get ccInsSamplingNoRequired => 'رقم محضر سحب العينات إلزامي ولا يقل عن ثلاثة أحرف';
  @override String get ccInsDateLabel => 'تاريخ المعاينة الفنية *';
  @override String get ccInsTypeLabel => 'نوع وطريقة الكشف والمعاينة:';
  @override String get ccInsType1 => 'كشف فعلي وسحب عينات';
  @override String get ccInsType2 => 'تفريغ وكشف كلي 100%';
  @override String get ccInsType3 => 'كشف عشوائي للطرود';
  @override String get ccInsType4 => 'فحص بالأشعة X-Ray';
  @override String get ccInsType5 => 'مطابقة مستندية';
  @override String get ccInsInspectorLabel => 'اسم المفتش / رئيس لجنة الفحص الجمركي المشترك';
  @override String get ccInsInspectorHint => 'مثال: م. إبراهيم خليل - رئيس لجنة الفحص المشترك';
  @override String get ccInsResultLabel => 'نتيجة الكشف والمعاينة الميدانية *';
  @override String get ccInsResConforming => 'مطابقة تامة';
  @override String get ccInsResConformingDesc => 'الأصناف مطابقة للمستندات والوزن والمواصفات القياسية';
  @override String get ccInsResShortage => 'وجود عجز';
  @override String get ccInsResShortageDesc => 'كميات أو طرود أقل من المصرح بها بالفاتورة';
  @override String get ccInsResSurplus => 'وجود زيادة';
  @override String get ccInsResSurplusDesc => 'كميات أو أصناف إضافية غير مدرجة بالفاتورة';
  @override String get ccInsResDiscrepancy => 'اختلاف في البند أو المنشأ';
  @override String get ccInsResDiscrepancyDesc => 'تباين في المنشأ أو مواصفات الصنف عن الإقرار 46';
  @override String get ccInsSection2 => 'ثانياً: سحب العينات والرقابة على الصادرات والواردات (GOEIC)';
  @override String get ccInsSampleSwitchTitle => 'تم سحب عينات للفحص والتحليل المعملي للجهات الرقابية';
  @override String get ccInsSampleSwitchOn => 'سيتم تدوين رقم محضر سحب العينات وتحديد جهات الفحص المعملي ومتابعة تقرير GOEIC';
  @override String get ccInsSampleSwitchOff => 'لم يتم سحب عينات (اكتفاء بالمعاينة الظاهرية ومطابقة المستندات)';
  @override String get ccInsSampleRecordLabel => 'رقم محضر سحب العينات الرسمي *';
  @override String get ccInsSampleRecordHint => 'مثال: رقم محضر السحب...';
  @override String get ccInsSampleRecordNew => 'توليد رقم محضر جديد';
  @override String get ccInsSampleRecordRequired => 'رقم محضر سحب العينات مطلوب (3 أحرف على الأقل)';
  @override String get ccInsSampleDateLabel => 'تاريخ سحب العينات *';
  @override String get ccInsBodiesLabel => 'الجهات الرقابية الساحبة للعينات والفاحصة معملياً:';
  @override String get ccInsGoeicLabel => 'رقم شهادة فحص الرقابة على الصادرات والواردات';
  @override String get ccInsGoeicHint => 'مثال: GOEIC-2026-INSP-9922';
  @override String get ccInsLabFeesLabel => 'رسوم ومصاريف التحليل المعملي';
  @override String get ccInsTestStatusLabel => 'حالة فحص العينات المعملية:';
  @override String get ccInsStatusTesting => 'عينات تحت الفحص المعملي';
  @override String get ccInsStatusApproved => 'مطابقة ومعتمدة رقابياً';
  @override String get ccInsStatusRejected => 'غير مطابقة (مرفوضة)';
  @override String get ccInsSection3 => 'ثالثاً: ملاحظات وتوصيات لجنة المعاينة والفحص';
  @override String get ccInsNotesLabel => 'ملاحظات الكشف والمعاينة والتثمين';
  @override String get ccInsNotesHint => 'أدخل أي ملاحظات فنية حول حالة الطرود، سلامة الأختام الملاحية، توصيات لجنة الكشف، أو متطلبات الفحص المعملي...';
  @override String get ccInsFooterNote => 'اعتماد الكشف والمعاينة سيرفع نسبة تقدم الملف إلى 88% ويولد مهمة احتساب الرسوم (CL-02).';
  @override String get ccInsConfirm => 'حفظ واعتماد الكشف وسحب العينات (CL-01)';
  @override String get ccInsConfirming => 'جاري الحفظ والاعتماد...';
  @override String ccInsSuccess(String result) => 'تم تسجيل الكشف والمعاينة وسحب العينات بنجاح! نتيجة الفحص ($result). تم الانتقال للمرحلة التالية: احتساب الرسوم والضرائب الجمركية النهائية (CL-02).';
  @override String ccInsError(String error) => 'حدث خطأ أثناء تسجيل الكشف وسحب العينات: $error';
  @override String get ccBrkTitle => 'تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)';
  @override String ccBrkSupplierChip(String name) => 'المورد: $name';
  @override String get ccBrkInfo => 'توليد تفويض المخلص إلكترونياً واعتماده عبر منصة نافذة، مع رفع تقدم الشحنة لـ 80% وجدولة مهمة سداد إذن التسليم الملاحي (CS-02).';
  @override String get ccBrkSelectBroker => 'يرجى اختيار المخلص الجمركي المعتمد';
  @override String ccBrkSuccess(String number) => 'تم تعيين وتفويض المخلص الجمركي بنجاح برقم ($number)';
  @override String ccBrkFail(String error) => 'فشل تفويض المخلص الجمركي: $error';
  @override String get ccBrkLicense => 'رخصة:';
  @override String get ccBrkPorts => 'موانئ:';
  @override String get ccBrkBrokerLabel => 'المخلص الجمركي المعين *';
  @override String get ccBrkBrokerHint => 'اختر المخلص الجمركي المعتمد...';
  @override String get ccBrkBrokerSearchHint => 'ابحث باسم المخلص أو رقم الرخصة أو الميناء...';
  @override String ccBrkLoadError(String error) => 'خطأ في تحميل قائمة المخلصين: $error';
  @override String get ccBrkNoLabel => 'رقم التفويض الإلكتروني (Nafeza / MTS Code) *';
  @override String get ccBrkNoHint => 'مثال: DEL-2026-ALEX-01 أو MTS-AUTH-...';
  @override String get ccBrkCopyTooltip => 'نسخ رقم التفويض';
  @override String get ccBrkCopied => 'تم نسخ رقم التفويض إلى الحافظة';
  @override String get ccBrkGenerateTooltip => 'توليد رقم تفويض آلي جديد';
  @override String get ccBrkNoRequired => 'رقم التفويض الإلكتروني إلزامي';
  @override String get ccBrkNoTooShort => 'رقم التفويض يجب ألا يقل عن 3 أحرف';
  @override String get ccBrkDateLabel => 'تاريخ التفويض الإلكتروني';
  @override String get ccBrkOfficeLabel => 'الميناء الجمركي المعني';
  @override String get ccBrkMandateTitle => 'توليد خطاب تفويض جمركي رسمي (Customs Broker Mandate Letter)';
  @override String get ccBrkMandateDesc => 'إنشاء خطاب التوكيل والتفويض تلقائياً باسم مدير عام جمارك الميناء لحفظه في أرشيف الخطابات الرسمية.';
  @override String get ccBrkNotesLabel => 'ملاحظات وتوجيهات للمستخلص (اختياري)';
  @override String get ccBrkNotesHint => 'مثال: سداد إذن التسليم فور الوصول، متابعة لجنة الفحص المشترك GOEIC...';
  @override String get ccBrkConfirm => 'اعتماد وتفويض المخلص (CS-01)';
  @override String get ccBrkConfirming => 'جاري الاعتماد والتفويض...';
  @override String get ccDoTitle => 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)';
  @override String ccDoChipShipment(String code, String company) => 'الشحنة: $code — $company';
  @override String get ccDoStageTitle => 'المرحلة السادسة: الإعداد الجمركي (46)';
  @override String get ccDoStageDesc => 'تسجيل سداد مصاريف التوكيل واستلام إذن التسليم (D/O) يرفع تقدم الشحنة لـ 83% ويُتيح فتح وقيد الإقرار الجمركي 46 ك.م.';
  @override String get ccDoFileNoChip => 'رقم الملف:';
  @override String get ccDoSupplierChip => 'المورد:';
  @override String get ccDoPortChip => 'ميناء الوصول:';
  @override String get ccDoFreeDaysChip => 'فترة السماح:';
  @override String ccDoDays(int days) => '$days يوم';
  @override String get ccDoSection => 'بيانات التوكيل الملاحي وإذن التسليم';
  @override String ccDoPartnersError(String error) => 'خطأ في تحميل الشركاء: $error';
  @override String get ccDoAgentLabel => 'التوكيل الملاحي / الخط الناقل *';
  @override String get ccDoAgentHint => 'ابحث واختر التوكيل أو الخط الملاحي...';
  @override String get ccDoAgentSearchHint => 'ابحث باسم التوكيل أو الكود أو الخط...';
  @override String get ccDoNumberLabel => 'رقم إذن التسليم الملاحي *';
  @override String get ccDoNumberHint => 'مثال: DO-MAEU-2026-8819';
  @override String get ccDoNumberRequired => 'يرجى إدخال رقم إذن التسليم الملاحي';
  @override String get ccDoNumberTooShort => 'رقم إذن التسليم يجب ألا يقل عن 3 أحرف/أرقام';
  @override String get ccDoGenerateTooltip => 'توليد رقم إذن تسليم تلقائي';
  @override String get ccDoGenerate => 'توليد';
  @override String get ccDoFeesLabel => 'مصاريف التوكيل الملاحي *';
  @override String get ccDoFeesRequired => 'يرجى إدخال قيمة مصاريف التوكيل';
  @override String get ccDoFeesInvalid => 'يرجى إدخال مبلغ صحيح';
  @override String get ccDoFeesInvalidSnack => 'يرجى إدخال قيمة صحيحة لرسوم التوكيل الملاحي';
  @override String get ccDoCurrencyLabel => 'العملة';
  @override String get ccDoPaymentRefLabel => 'رقم إيصال أو مرجع سداد مصاريف التوكيل *';
  @override String get ccDoPaymentRefHint => 'مثال: RCPT-TXN-2026-9912 أو رقم التحويل البنكي';
  @override String get ccDoPaymentRefRequired => 'يرجى إدخال رقم إيصال أو مرجع السداد';
  @override String get ccDoPaymentRefTooShort => 'مرجع السداد يجب ألا يقل عن حرفين/رقمين';
  @override String get ccDoDateLabel => 'تاريخ استلام الإذن *';
  @override String get ccDoExpiryLabel => 'تاريخ انتهاء الصلاحية *';
  @override String get ccDoFileUrlLabel => 'رابط أو مسار صورة إذن التسليم المرفوع (اختياري)';
  @override String get ccDoNotesLabel => 'ملاحظات وتوجيهات الكشف الجمركي (اختياري)';
  @override String get ccDoNotesHint => 'سداد غرامات التأخير إن وجدت، تنسيق النقل الداخلي مع المخلص...';
  @override String get ccDoConfirm => 'سداد واعتماد إذن التسليم (CS-02)';
  @override String get ccDoConfirming => 'جاري الحفظ والاعتماد...';
  @override String ccDoSuccess(String number) => 'تم تسجيل سداد مصاريف التوكيل واستلام إذن التسليم ($number) بنجاح!';
  @override String ccDoError(String error) => 'فشل في حفظ إذن التسليم: $error';
  @override String get ccDecTitle => 'قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)';
  @override String get ccDecSubtitle => 'المرحلة السادسة: الإعداد الجمركي 46 — ربط الإقرار وتحديد المسار وجهات العرض الرقابية';
  @override String get ccDecBannerFile => 'الملف الاستيرادي';
  @override String get ccDecBannerCompany => 'الشركة المستوردة';
  @override String get ccDecBannerSupplier => 'المورد الأجنبي';
  @override String get ccDecBannerPort => 'ميناء الوصول';
  @override String get ccDecBannerAcid => 'رقم ACID';
  @override String get ccDecBannerDo => 'إذن التسليم D/O';
  @override String get ccDecBannerBroker => 'المخلص الجمركي';
  @override String get ccDecSection1 => 'بيانات الإقرار الجمركي ونموذج 46 ك.م';
  @override String get ccDecNoLabel => 'رقم الإقرار الجمركي 46 ك.م *';
  @override String get ccDecNoHelper => 'صيغة 10 أرقام مميكنة على منظومة نافذة';
  @override String get ccDecNoRequired => 'رقم الإقرار الجمركي مطلوب';
  @override String get ccDecGenerateTooltip => 'توليد رقم إقرار جمركي تجريبي مميكن';
  @override String get ccDecGenerate => 'توليد آلي';
  @override String get ccDecDateLabel => 'تاريخ قيد الإقرار *';
  @override String get ccDecSection2 => 'المجمع / الميناء الجمركي المختص';
  @override String get ccDecOfficeLabel => 'المجمع الجمركي المنفذ للإقرار *';
  @override String get ccDecOfficeHint => 'اختر أو ابحث عن المجمع الجمركي...';
  @override String get ccDecOffice0 => 'جمارك ميناء الإسكندرية البحري';
  @override String get ccDecOffice1 => 'جمارك ميناء الدخيلة البحري';
  @override String get ccDecOffice2 => 'جمارك ميناء غرب / شرق بورسعيد';
  @override String get ccDecOffice3 => 'جمارك ميناء دمياط البحري';
  @override String get ccDecOffice4 => 'جمارك ميناء العين السخنة';
  @override String get ccDecOffice5 => 'جمارك قرية البضائع - مطار القاهرة الدولي';
  @override String get ccDecOffice6 => 'جمارك الميناء الجاف بمدينة 6 أكتوبر';
  @override String get ccDecOffice7 => 'جمارك الميناء الجاف بمدينة العاشر من رمضان';
  @override String get ccDecOffice8 => 'جمارك ميناء الأدبية بالسويس';
  @override String get ccDecSection3 => 'المسار الجمركي المعتمد';
  @override String get ccDecSection3Desc => 'يتم تحديد المسار الجمركي بواسطة خوارزمية إدارة المخاطر بمنظومة نافذة أو مأمور الحركة:';
  @override String get ccDecChRed => 'المسار الأحمر';
  @override String get ccDecChRedDesc => 'كشف ومعاينة فعلية كاملة وسحب عينات';
  @override String get ccDecChYellow => 'المسار الأصفر';
  @override String get ccDecChYellowDesc => 'مراجعة وتدقيق مستندي وفحص ورقي';
  @override String get ccDecChGreen => 'المسار الأخضر';
  @override String get ccDecChGreenDesc => 'إفراج فوري ومراجعة لاحقة (مشغل اقتصادي)';
  @override String get ccDecBodiesSection => 'جهات العرض والرقابة المختصة';
  @override String get ccDecTariffSection => 'بنود التعريفة';
  @override String get ccDecTariffLabel => 'عدد بنود التعريفة *';
  @override String get ccDecTariffMin => 'بند 1 على الأقل';
  @override String get ccDecSection5 => 'بيانات إضافية وملاحظات الكشف والمعاينة';
  @override String get ccDecMtsLabel => 'رقم شهادة منصة نافذة MTS الرقمية (إن وجد)';
  @override String get ccDecMtsHelper => 'رقم شهادة الإرسال الإلكتروني الصادرة من النافذة الموحدة';
  @override String get ccDecNotesLabel => 'ملاحظات الكشف والتثمين الأولية';
  @override String get ccDecNotesHint => 'أي اشتراطات أو توجيهات خاصة بالكشف أو المعاينة الجمركية...';
  @override String get ccDecFooterNote => 'تسجيل الإقرار يرفع نسبة إنجاز الشحنة إلى 86% وينقلها للمرحلة السابعة (التخليص الجمركي والكشف CL-01).';
  @override String get ccDecConfirm => 'تأكيد وقيد نموذج 46 ك.م';
  @override String get ccDecConfirming => 'جاري القيد والتسجيل...';
  @override String ccDecSuccess(String number, String channel) => 'تم قيد الإقرار الجمركي ونموذج 46 ك.م بنجاح! رقم الإقرار ($number) على المسار ($channel). المرحلة التالية: تسجيل الكشف والمعاينة وسحب العينات (CL-01).';
  @override String ccDecError(String error) => 'حدث خطأ أثناء قيد الإقرار 46: $error';
  @override String get ccExpTitle => 'تسجيل فواتير المخلص ومصاريف التخليص والميناء (CL-05)';
  @override String ccExpChipFile(String code, String supplier, String declaration) => 'ملف الشحنة: $code — $supplier ($declaration)';
  @override String get ccExpSupplierFallback => 'المورد';
  @override String get ccExpDeclPending => 'بانتظار البيان';
  @override String get ccExpKpiNet => 'إجمالي صافي الفواتير';
  @override String ccExpInvoicesCount(int count) => '$count فاتورة مسجلة';
  @override String get ccExpKpiBroker => 'أتعاب التخليص الجمركي';
  @override String get ccExpKpiBrokerSub => 'Clearance Fees';
  @override String get ccExpKpiPort => 'نولون ورسوم الميناء';
  @override String get ccExpKpiPortSub => 'Port Dues & Wharfage';
  @override String get ccExpKpiHandling => 'العتالة والشحن والتفريغ';
  @override String get ccExpKpiHandlingSub => 'Handling & Stevedoring';
  @override String ccExpListTitle(int count) => 'قائمة فواتير ومصروفات التخليص ($count)';
  @override String get ccExpAddBtn => 'إضافة فاتورة جديدة';
  @override String get ccExpCancelAdd => 'إلغاء الإضافة';
  @override String get ccExpFormTitle => 'تسجيل فاتورة مصروفات جديدة';
  @override String get ccExpFormNote => 'سيتم الترحيل آلياً لمحرك التكلفة Landed Cost';
  @override String get ccExpProviderLabel => 'اسم المخلص / مقدم الخدمة *';
  @override String get ccExpProviderHint => 'مثال: شركة الصفا للتخليص الجمركي';
  @override String get ccExpProviderRequired => 'يرجى إدخال اسم مقدم الخدمة أو المخلص';
  @override String get ccExpNumberLabel => 'رقم الفاتورة *';
  @override String get ccExpNumberHint => 'مثال: INV-2026-9901';
  @override String get ccExpNumberRequired => 'يرجى إدخال رقم الفاتورة';
  @override String get ccExpDateLabel => 'تاريخ الفاتورة';
  @override String get ccExpCategoryLabel => 'بند المصروف / نوع التكلفة *';
  @override String get ccExpAllocationLabel => 'قاعدة توزيع التكلفة *';
  @override String get ccExpAllocEqual => 'بالتساوي';
  @override String get ccExpAllocValue => 'حسب القيمة الإجمالية';
  @override String get ccExpAllocWeight => 'حسب الوزن القائم';
  @override String get ccExpAllocVolume => 'حسب الحجم بالمتر المكعب';
  @override String get ccExpAmountLabel => 'مبلغ الفاتورة الأساسي (ج.م) *';
  @override String get ccExpAmountRequired => 'يرجى إدخال مبلغ الفاتورة';
  @override String get ccExpAmountPositive => 'أدخل مبلغاً أكبر من صفر';
  @override String get ccExpWhtCheckbox => 'خصم ضريبة الأرباح (WHT)';
  @override String get ccExpNotesLabel => 'ملاحظات وتفاصيل إضافية عن الفاتورة';
  @override String get ccExpNotesHint => 'أي تفاصيل عن أتعاب الشحن والتفريغ أو رقم إيصال الميناء...';
  @override String get ccExpSave => 'حفظ الفاتورة';
  @override String get ccExpSaving => 'جاري الحفظ...';
  @override String ccExpSaved(String category) => 'تم تسجيل فاتورة $category بنجاح وترحيلها لتكلفة البضاعة (Landed Cost)';
  @override String ccExpSaveFail(String error) => 'فشل تسجيل الفاتورة: $error';
  @override String get ccExpDeleteTitle => 'تأكيد حذف الفاتورة';
  @override String ccExpDeleteContent(String number, String provider) => 'هل أنت متأكد من حذف فاتورة "$number" الخاصة بـ "$provider"؟\nسيتم تحديث إجمالي تكاليف التخليص تلقائياً.';
  @override String get ccExpDeleteConfirm => 'تأكيد الحذف';
  @override String get ccExpDeleted => 'تم حذف الفاتورة بنجاح وتحديث إجماليات التخليص';
  @override String ccExpDeleteFail(String error) => 'تعذر حذف الفاتورة: $error';
  @override String get ccExpDeleteTooltip => 'حذف الفاتورة';
  @override String get ccExpEmptyTitle => 'لا توجد فواتير تخليص مسجلة حتى الآن';
  @override String get ccExpEmptyHint => 'اضغط على زر "إضافة فاتورة جديدة" لتسجيل فواتير المخلص الجمركي ونولون الميناء ومصاريف التعتيق والتحاليل.';
  @override String ccExpInvoiceNo(String number) => 'فاتورة #$number';
  @override String ccExpBreakdown(String base, String vat, String wht) => 'أساسي: $base | ض.م: +$vat | خ.أ: -$wht';
  @override String get ccExpInfoProvider => 'المورد / المخلص';
  @override String get ccExpInfoDate => 'التاريخ';
  @override String get ccExpInfoAllocation => 'التوزيع';
  @override String get ccExpInfoNotes => 'ملاحظات';
  @override String get ccExpAllocEqualShort => 'بالتساوي';
  @override String get ccExpFooterNote => 'المصاريف تُرحَّل تلقائياً إلى كشف حساب تكلفة الشحنة (Landed Cost Engine)';
  @override String get ccCloneSearchHint => 'ابحث برقم البيان، 46 ك.م، إذن التسليم، أو الجمرك...';
  @override String get ccCloneChannelLabel => 'المسار: ';
  @override String get ccCloneStatusLabel => 'الحالة: ';
  @override String get ccCloneAll => 'الكل';
  @override String get ccCloneRed => 'أحمر';
  @override String get ccCloneGreen => 'أخضر';
  @override String get ccCloneYellow => 'أصفر';
  @override String get ccCloneDuties => 'الرسوم';
  @override String get ccCloneBtn => 'استنساخ';
  @override String get customsDeclMinLength => 'رقم الإقرار الجمركي يجب ألا يقل عن 3 أحرف أو أرقام';
  @override String get customsDeclChannelLabel => 'المسار الجمركي';
  @override String get customsDeclPickDateTooltip => 'اختيار تاريخ قيد الإقرار';
  @override String get customsDeclMetricEstimatedDuties => 'إجمالي الرسوم التقديرية';
  @override String get customsDeclColTariffEstimate => 'الرسوم التقديرية';
  @override String get customsDeclRegistryEmptyMessage => 'لا توجد إقرارات جمركية مسجلة حتى الآن';
  @override String get customsDeclExportSubtitle => 'نظام سرور لإدارة الاستيراد — متابعة التخليص الجمركي';
  @override String get customsDeclExportMetaTotal => 'إجمالي الإقرارات';
  @override String get customsDeclExportMetaGeneratedAt => 'تاريخ التقرير';
  @override String customsDeclExportSubtitleWithFile(String declNo, String fileCode) => 'إقرار جمركي 46: $declNo — ملف الشحنة: $fileCode';
  // === end review phase06_07 keys ===

  // === review phase08_10 keys (append below this line) ===
  @override String get settlementCurrencyLabel => 'العملة *';
  @override String get settlementCurrencySearchHint => 'ابحث عن العملة...';
  @override String get settlementCurrencyRequired => 'اختر عملة الفاتورة';
  @override String get settlementGrossWeightLabel => 'الوزن القائم (كجم)';
  @override String get settlementCbmLabel => 'الحجم (متر مكعب)';
  @override String get settlementFieldRequired => 'هذا الحقل مطلوب';
  @override String get settlementPositiveNumberRequired => 'أدخل رقما أكبر من صفر';
  @override String get settlementNonNegativeNumberRequired => 'أدخل رقما صحيحا (صفر أو أكثر)';
  @override String get settlementExchangeRateRequired => 'أدخل سعر الصرف للعملة الأجنبية';
  @override String get settlementCloneTargetFileLabel => 'ملف الاستيراد للتسوية الجديدة *';
  @override String get settlementCloneTargetFileMustDiffer => 'اختر ملف استيراد مختلفا: لكل ملف تسوية نشطة واحدة';
  @override String get settlementCloneHint => 'يتم نسخ فواتير المصاريف وبنود الأصناف. اختر ملف الاستيراد الذي تتبعه التسوية الجديدة. الكود والإجماليات والحالة يولدها النظام.';
  @override String get settlementStageOdooCsv => 'قيد تكلفة الوصول لـ Odoo';
  @override String get settlementStageOdooExcel => 'سند محاسبي لتكلفة الوصول';
  @override String get settlementStageComparison => 'مقارنة تكلفة الوصول';
  @override String get settlementExportFailed => 'فشل التصدير';
  @override String get wrItemCodeLabel => 'كود الصنف';
  @override String get wrItemCodeRequired => 'كود الصنف مطلوب';
  @override String get wrQtyInvalid => 'أدخل عدداً صحيحاً (صفر أو أكثر)';
  @override String wrLineUnbalanced(int received, int invoiced) => 'المستلم $received (مقبول + عجز + تالف) لا يطابق الكمية بالفاتورة $invoiced';
  @override String get wrLineUnbalancedShort => 'الكميات غير متوازنة';
  @override String wrLineExcess(int excess) => 'استلام بالزيادة: $excess فوق الكمية بالفاتورة';
  @override String get wrNoLinesHint => 'لا توجد بنود بعد. اختر ملف الاستيراد لتحميل بنود أمر الشراء، أو أضف البنود المستلمة.';
  @override String get wrNoLinesValidator => 'أضف بنداً مستلماً واحداً على الأقل';
  @override String get wrRemoveLineTooltip => 'حذف البند';
  @override String get wrColItemName => 'اسم الصنف';
  @override String get wrColInvoiced => 'الفاتورة';
  @override String get wrColAccepted => 'المقبول';
  @override String get wrColShortage => 'العجز';
  @override String get wrColDamaged => 'التالف';
  @override String get wrLineStatusDiscrepancy => 'يوجد فروقات';
  @override String get wrLineStatusClean => 'مطابق وسليم';
  @override String get wrClaimRefRequired => 'أدخل رقم مرجع المطالبة';
  @override String get wrInspectionProtocolBtn => 'محضر الفحص (TR-04)';
  @override String get wrInlandBookBtn => 'حجز وتنسيق النقل (TR-01)';
  @override String get wrNoFilesForBooking => 'لا توجد ملفات استيراد متاحة لحجز النقل';
  @override String get wrFilterQuarantineOnly => 'حجر مخزني فقط';
  @override String get wrQuarantineZoneBadge => 'منطقة حجر';
  @override String wrCloneRecordSummary(int accepted, int shortage, int damaged) => 'أصناف: $accepted مقبول / $shortage عجز / $damaged تالف';
  @override String get wrPdfRegistryTitle => 'سجل أذون الإضافة والاستلام المخزني (GRN)';
  @override String get wrPdfRegistrySubtitle => 'سجل أذون الاستلام والفحص المخزني';
  @override String get wrCloneEntityType => 'إذن إضافة واستلام مخزني (GRN)';
  @override String get wrCloneItemCount => 'عدد الأصناف';
  @override String get wrCloneResetReceivingId => 'معرف الاستلام: يتم تفريغه لتوليد إذن استلام جديد';
  @override String get wrCloneResetGrnCode => 'كود الإذن: يصدر الخادم كوداً جديداً';
  @override String get wrCloneResetArrival => 'تاريخ ووقت الوصول: يعاد ضبطه على الوقت الحالي';
  @override String get wrCloneResetStatus => 'الحالة: يحددها الخادم عند الحفظ';
  @override String get wrCloneResetQuarantine => 'منطقة الحجر: يعاد ضبطها إلى غير محجور';
  @override String get wrCloneResetDiscrepancy => 'الفروقات: تعاد إلى لا توجد ومسح الملاحظات';
  @override String get wrCloneResetInsuranceClaim => 'مطالبة التأمين: يتم فك الربط ومسح رقم المطالبة';
  @override String get wrInspTitle => 'محضر الفحص الفني ومطابقة العجز والتالف (TR-04)';
  @override String wrInspSubtitle(String grn, String file) => 'إذن الإضافة: $grn | الشحنة: $file';
  @override String get wrInspExportBtn => 'تصدير المحضر Excel';
  @override String get wrInspMetricRate => 'نسبة الفروقات';
  @override String get wrInspItemsHeader => 'مطابقة بنود وأصناف الشحنة:';
  @override String get wrInspCommitteeLabel => 'لجنة الفحص الفني والاستلام';
  @override String get wrInspCommitteeHint => 'اختياري. تُستخدم اللجنة القياسية عند تركه فارغاً.';
  @override String get wrInspVerdictLabel => 'قرار ونتيجة الفحص *';
  @override String get wrInspVerdictRequired => 'اختر قرار الفحص';
  @override String get wrInspVerdictFull => 'قبول كامل ومطابق (سليم)';
  @override String get wrInspVerdictDiscrepancy => 'قبول مع إثبات عجز/تالف';
  @override String get wrInspVerdictRejected => 'رفض وحجز في منطقة الحجر';
  @override String get wrInspFullBlockedHint => 'القبول الكامل غير متاح مع وجود عجز أو تالف مسجل.';
  @override String get wrInspRootCauseLabel => 'السبب الجذري للفروقات والتلفيات';
  @override String get wrRootCauseNone => 'سليم - لا توجد تلفيات أو عجز';
  @override String get wrRootCausePort => 'سوء مناولة وتفريغ بالميناء';
  @override String get wrRootCauseInland => 'اهتزازات وسوء نقل بري للشاحنة';
  @override String get wrRootCausePackaging => 'سوء تعبئة وتغليف من المورد';
  @override String get wrRootCauseWater => 'تسريب مياه ورطوبة بالحاوية';
  @override String get wrRootCauseFactory => 'عجز مصنعي في الشحن من المصنع';
  @override String get wrRootCauseOther => 'أسباب أخرى / قيد التحقيق';
  @override String get wrInspNotesLabel => 'ملاحظات الفحص ومحضر المعاينة الفنية *';
  @override String get wrInspNotesRequired => 'يرجى تدوين الملاحظات الفنية';
  @override String get wrInspClaimsHeader => 'إجراءات المطالبات والتعويضات والعزل:';
  @override String get wrInspInsuranceClaim => 'رفع مطالبة تأمين بحري/نقل';
  @override String get wrInspSupplierCredit => 'طلب إشعار دائن من المورد';
  @override String get wrInspQuarantine => 'عزل الأصناف التالفة في منطقة الحجر';
  @override String get wrInspInsuranceRef => 'رقم مرجع مطالبة التأمين';
  @override String get wrInspSupplierRef => 'رقم إشعار خصم/مطالبة المورد';
  @override String get wrInspClaimAmount => 'قيمة التعويض التقديرية';
  @override String get wrInspClaimCurrency => 'العملة';
  @override String get wrInspCurrencySearch => 'بحث عن عملة...';
  @override String get wrInspCertifyBtn => 'اعتماد محضر الفحص الفني (TR-04)';
  @override String wrInspSuccess(String grn) => 'تم اعتماد محضر الفحص الفني والمطابقة بنجاح ($grn)';
  @override String get inlandDialogTitle => 'تنسيق وحجز سيارات وسائقي النقل الداخلي (TR-01)';
  @override String inlandDialogFileLine(String file, String company) => 'الملف: $file  |  المستورد: $company';
  @override String get inlandStatusArrived => 'تم الوصول للمخزن';
  @override String get inlandStatusInTransit => 'في الطريق (خرج من الميناء)';
  @override String get inlandStatusConfirmed => 'تم تأكيد الحجز';
  @override String get inlandStatusNotBooked => 'غير محجوز';
  @override String get inlandCloseTooltip => 'إغلاق';
  @override String get inlandKpiStatus => 'حالة النقل الداخلي';
  @override String get inlandKpiWaybill => 'بوليصة النقل الداخلي';
  @override String get inlandKpiTruckDriver => 'الشاحنة والسائق';
  @override String get inlandKpiFare => 'نولون النقل بالجنيه المصري';
  @override String get inlandNotSet => 'غير محدد';
  @override String get inlandWaybillPending => 'لم يتم إنشاؤها بعد';
  @override String get inlandCurrencySuffix => 'ج.م';
  @override String inlandCurrentBookingTitle(String code) => 'بيانات حجز النقل الحالية ($code)';
  @override String get inlandHideForm => 'إخفاء نموذج التعديل';
  @override String get inlandEditOrRebook => 'تعديل أو حجز شاحنة أخرى';
  @override String get inlandInfoCarrier => 'شركة النقل:';
  @override String get inlandInfoWaybill => 'رقم البوليصة:';
  @override String get inlandInfoTruckType => 'نوع الشاحنة:';
  @override String get inlandInfoPlate => 'لوحة الشاحنة:';
  @override String get inlandInfoDriver => 'السائق:';
  @override String get inlandInfoContainers => 'الحاويات:';
  @override String get inlandInfoPickup => 'مكان الاستلام:';
  @override String get inlandInfoDestination => 'المخزن المستلم:';
  @override String get inlandInfoPlannedDeparture => 'المغادرة المخططة:';
  @override String get inlandInfoExpectedArrival => 'الوصول المتوقع:';
  @override String get inlandInfoActualDeparture => 'المغادرة الفعلية:';
  @override String get inlandInfoActualArrival => 'الوصول الفعلي:';
  @override String get inlandGateOutTitle => 'تأكيد خروج الشاحنة من بوابة الميناء';
  @override String get inlandGateOutDesc => 'تسجيل توقيت المغادرة الفعلي وبدء تتبع الرحلة وتحويل الحالة إلى "في الطريق"';
  @override String get inlandGateOutBtn => 'تأكيد خروج البوابة';
  @override String get inlandArrivalTitle => 'تأكيد وصول واستلام الشاحنة بالمخزن';
  @override String get inlandArrivalDesc => 'تسجيل وصول الشاحنة لرصيف المخزن وإتاحة استلام الأصناف';
  @override String get inlandArrivalBtn => 'تأكيد وصول المخزن';
  @override String get inlandArrivedMsg => 'تم وصول الشاحنة بالمخزن، وتم ربط مهمة الاستلام والفحص (TR-03).';
  @override String get inlandNotesOptionalLabel => 'ملاحظات (اختياري)';
  @override String get inlandFormTitle => 'نموذج حجز وتنسيق النقل الداخلي';
  @override String get inlandWaybillLabel => 'رقم بوليصة النقل الداخلي *';
  @override String get inlandWaybillRequired => 'يرجى إدخال رقم البوليصة';
  @override String get inlandCarrierLabel => 'اسم شركة النقل / الناقل *';
  @override String get inlandCarrierRequired => 'يرجى إدخال اسم شركة النقل';
  @override String get inlandPlateLabel => 'رقم لوحة الشاحنة / السيارة *';
  @override String get inlandPlateHint => 'رقم اللوحة كما هو مكتوب';
  @override String get inlandPlateInvalid => 'رقم اللوحة لا يقل عن 3 أحرف/أرقام';
  @override String get inlandTruckTypeLabel => 'نوع الشاحنة والمقطورة *';
  @override String get inlandTruckTypeHint => 'اختر نوع الشاحنة';
  @override String get inlandTruckTypeRequired => 'يرجى اختيار نوع الشاحنة';
  @override String get inlandDriverLabel => 'اسم السائق الثلاثي *';
  @override String get inlandDriverInvalid => 'يرجى إدخال اسم السائق صحيحاً';
  @override String get inlandPhoneLabel => 'رقم هاتف السائق *';
  @override String get inlandPhoneInvalid => 'رقم الهاتف غير صالح';
  @override String get inlandNationalIdLabel => 'الرقم القومي للسائق';
  @override String get inlandNationalIdHint => '14 رقم (اختياري)';
  @override String get inlandPickupLabel => 'مكان وميناء الاستلام *';
  @override String get inlandPickupRequired => 'يرجى تحديد مكان الاستلام';
  @override String get inlandWarehouseLabel => 'المخزن المستلم (الوجهة) *';
  @override String get inlandWarehouseRequired => 'يرجى تحديد المخزن المستلم';
  @override String get inlandContainersLabel => 'أرقام الحاويات المنقولة';
  @override String get inlandFareLabel => 'نولون النقل بالجنيه المصري *';
  @override String get inlandFareRequired => 'يرجى إدخال تكلفة النقل';
  @override String get inlandFareInvalid => 'المبلغ يجب أن يكون أكبر من 0';
  @override String get inlandDepartureDate => 'تاريخ المغادرة المخططة';
  @override String get inlandDepartureTime => 'وقت المغادرة المخططة';
  @override String get inlandEtaDate => 'تاريخ الوصول المتوقع للمخزن';
  @override String get inlandEtaTime => 'وقت الوصول المتوقع للمخزن';
  @override String get inlandEtaBeforeDeparture => 'يجب أن يكون الوصول المتوقع بعد المغادرة المخططة';
  @override String get inlandSelectCarrierHint => 'اختر شركة النقل / الناقل من دليل الشركاء';
  @override String get inlandSelectPickupLocationHint => 'اختر ميناء أو موقع الاستلام من المواقع المعتمدة';
  @override String get inlandGatePassNoLabel => 'رقم تصريح البوابة الجمركية';
  @override String get inlandGatePassNoHint => 'رقم تصريح خروج الدائرة الجمركية (اختياري)';
  @override String get inlandSealIntactSwitch => 'حالة السيل الجمركي: سليم ومطابق';
  @override String get inlandSealNumberLabel => 'رقم السيل الجمركي *';
  @override String get inlandSealNumberHint => 'أدخل رقم السيل الجمركي';
  @override String get inlandSealNumberRequiredWhenBroken => 'يرجى إدخال رقم السيل الجمركي عند عدم سلامة السيل أو تلفه';
  @override String get inlandNotesLabel => 'ملاحظات وتوجيهات السائق والشحن';
  @override String get inlandNotesHint => 'تعليمات المناولة، السائق المساعد، مسار السير...';
  @override String get inlandSubmitBtn => 'حفظ وتأكيد حجز النقل الداخلي';
  @override String get inlandFooterNote => 'تحديث فوري لنسبة إنجاز الملف ومزامنة شاشة تتبع الشحنات والمخزن';
  @override String get inlandCloseBtn => 'إغلاق النافذة';
  @override String inlandBookedSnack(String code) => 'تم حجز وتأكيد النقل الداخلي بنجاح برقم ($code)';
  @override String inlandGateOutSnack(String code) => 'تم تأكيد خروج الشاحنة من بوابة الميناء ($code)';
  @override String inlandArrivalSnack(String code) => 'تم تأكيد وصول الشاحنة للمخزن ($code)';
  @override String get inlandLoadErrorTitle => 'تعذر تحميل بيانات حجز النقل';
  @override String get inlandRetryBtn => 'إعادة المحاولة';
  @override String get closureDialogTitle => 'الإغلاق الرسمي والأرشفة الرقمية (CLO-04)';
  @override String closureDialogSubtitle(String file, String supplier, String status) => 'رمز الملف: $file | المورد: $supplier | حالة الملف: $status';
  @override String get closureCloseTooltip => 'إغلاق النافذة';
  @override String get closureLoadingPillars => 'جاري فحص وتدقيق ركائز الإغلاق الستة...';
  @override String closurePrecheckFailed(String error) => 'فشل جلب نتائج الفحص والتدقيق المسبق: $error';
  @override String get closureRetryBtn => 'إعادة المحاولة';
  @override String get closureCannotCloseSnack => 'لا يمكن إتمام الإغلاق الرسمي لوجود متطلبات معلقة!';
  @override String closureOfficialSuccess(String file, String code) => 'تم إغلاق الملف $file رسمياً بموجب الشهادة $code.';
  @override String get closureExportCertificateBtn => 'تصدير الشهادة (TXT)';
  @override String get closureLessonBtn => 'نعم، وثّق درساً مستفاداً';
  @override String get closureLessonPrompt => 'هل واجهتك عقبات تشغيلية، تأخيرات، أو دروس مستفادة ترغب في توثيقها في بنك المعرفة؟';
  @override String get closureDoneBtn => 'تم';
  @override String get closureBlockingTitle => 'متطلبات إغلاق إلزامية معلقة (يجب استيفاؤها أولاً):';
  @override String get closureWarningsTitle => 'تنبيهات تدقيقية قبل الأرشفة الرقمية:';
  @override String get closurePillarsHeader => 'ركائز التدقيق الختامي المعتمدة (6 ركائز)';
  @override String get closurePillarCustoms => 'الإفراج الجمركي';
  @override String get closurePillarWarehouse => 'إضافة المخزن (GRN)';
  @override String get closurePillarLandedCost => 'تسوية التكلفة الفعلية';
  @override String get closurePillarDossier => 'تصدير الملف الشامل';
  @override String get closurePillarContainers => 'تسليم الحاويات (EIR)';
  @override String get closurePillarTasks => 'إغلاق المهام';
  @override String get closureCertPreviewLabel => 'معاينة شهادة الإغلاق الرقمية:';
  @override String closureLandedCostLine(String cost, String factor) => 'تكلفة الوصول الفعلية المعتمدة: $cost EGP  |  معامل الوصول: ${factor}x';
  @override String get closureExportAfterCloseHint => 'يمكن تصدير الشهادة بعد إتمام الإغلاق الرسمي.';
  @override String get closureArchivalSectionTitle => 'بيانات التوثيق والمدقق المسؤول:';
  @override String get closureAuditorLabel => 'اسم المدقق / المسؤول المعتمد *';
  @override String get closureAuditorRequired => 'يرجى إدخال اسم المدقق';
  @override String get closureArchiveLocationLabel => 'موقع وخزينة الأرشفة الرقمية *';
  @override String get closureArchiveLocationRequired => 'يرجى تحديد موقع الأرشفة';
  @override String get closureNotesLabel => 'ملاحظات الأرشفة والتدقيق الختامي (اختياري)';
  @override String get closureSubmittingLabel => 'جاري إغلاق الملف وأرشفته...';
  @override String get closureConfirmBtn => 'اعتماد الإغلاق الرسمي والأرشفة الرقمية';
  @override String get closureUnavailableBtn => 'الإغلاق غير متاح (متطلبات معلقة)';
  @override String get closureCertTitle => 'شهادة الإغلاق الرسمي والأرشفة الرقمية المكتملة';
  @override String get closureCertNumber => 'رقم الشهادة المعتمد';
  @override String get closureCertIssuedAt => 'تاريخ وتوقيت الإصدار';
  @override String get closureCertFileCode => 'رمز ملف الاستيراد';
  @override String get closureCertCompany => 'الشركة المستوردة';
  @override String get closureCertSupplier => 'المورد الأجنبي';
  @override String get closureCertAuditor => 'مدقق الإغلاق المعتمد';
  @override String get closureCertLocation => 'موقع ومسار الأرشفة الرقمية';
  @override String get closureCertPillarsHeader => 'ركائز التدقيق الختامي:';
  @override String get closureCertOk => 'مستوفى';
  @override String get closureCertNotOk => 'غير مستوفى';
  @override String get closureCertTotalCost => 'إجمالي التكلفة الفعلية';
  @override String get closureCertMarkup => 'معامل تكلفة الوصول';
  @override String get closureCertNotesHeader => 'ملاحظات الأرشفة والتدقيق:';
  @override String get closureCertNoNotes => 'لا توجد ملاحظات إضافية';
  @override String get closureCertStatusLine => 'حالة الملف';
  @override String get closureCertSaveTitle => 'حفظ شهادة الإغلاق والأرشفة الرقمية';
  @override String get closureFormClonedSuffix => 'مسودة مستنسخة';
  @override String get closureFormServerChecklistNote => 'الحالات التالية يقيّمها النظام ولا يمكن تعديلها يدوياً.';
  @override String get closureFormSelectFileFirst => 'اختر ملف الاستيراد لعرض قائمة التحقق من الإغلاق.';
  @override String get closureFormPrecheckMissing => 'لم يتم تحميل فحص الإغلاق بعد';
  @override String get closureStatusDraft => 'مسودة قيد الاستيفاء';
  @override String get closureArchivedBadge => 'مغلق ومؤرشف';
  @override String get closureFilterAll => 'الكل';
  @override String get closureFilterClosed => 'مؤرشف نهائياً';
  @override String get closureCloneToDraft => 'استنساخ لمسودة';
  @override String closureVerifiedConditions(int count) => 'الشروط المستوفاة: $count / 5';
  @override String get closureCloneEntityType => 'شهادة إغلاق وأرشفة ملف استيراد';
  @override String get closureCloneSourceArchived => 'مغلق ومؤرشف';
  @override String get closureCloneSourceDraft => 'مسودة';
  @override String get closureCloneFieldFileId => 'رقم ملف الاستيراد';
  @override String get closureCloneFieldAuditor => 'المحاسب / المراجع';
  @override String get closureCloneFieldVault => 'مستودع الأرشيف الرقمي';
  @override String get closureCloneFieldConditions => 'حالة الشروط المستوفاة';
  @override String get closureCloneFieldNotes => 'ملاحظات الأرشفة';
  @override String get closureCloneReset1 => 'معرف الإغلاق: يتم تصفيره لإنشاء سجل أرشفة جديد';
  @override String get closureCloneReset2 => 'كود الشهادة: يصدر الخادم كوداً جديداً';
  @override String get closureCloneReset3 => 'حالة الإغلاق: يعاد ضبطها إلى مسودة قيد الاستيفاء';
  @override String get closureCloneReset4 => 'تاريخ الإغلاق والمراجع: يعاد ضبطهما على اللحظة الحالية والمستخدم الحالي';
  @override String get settlementClose => 'إغلاق';
  @override String get settlementCancel => 'إلغاء';
  @override String get settlementRetry => 'إعادة المحاولة';
  @override String get settlementNotAvailable => 'غير متاح';
  @override String get settlementScreenTitle => 'التسوية المالية وتكلفة البند النهائي';
  @override String get settlementTabRegistry => 'سجل تسويات تكلفة الوصول وتوليد القيود';
  @override String get settlementTabComparison => 'مقارنة التكلفة التقديرية والفعلية';
  @override String get settlementTabNew => 'احتساب وتسوية تكلفة شحنة جديدة';
  @override String get settlementClo01Btn => 'تسوية الفواتير (CLO-01)';
  @override String get settlementClo02Btn => 'التكلفة الفعلية (CLO-02)';
  @override String get settlementSelectShipmentForInvoices => 'يرجى اختيار شحنة أولاً لتجميع فواتيرها';
  @override String get settlementSelectShipmentForActual => 'يرجى اختيار شحنة أولاً لاحتساب تكلفتها الفعلية';
  @override String get settlementExportOdooBtn => 'تصدير قيد اليومية للنظام المالي (Odoo / ERP)';
  @override String get settlementSectionExpenses => 'فواتير المصاريف اللوجستية والجمركية المسجلة';
  @override String get settlementSectionItems => 'تكلفة الوصول للوحدة وتوزيع المصاريف على الأصناف';
  @override String get settlementRegistryEmptyAction => 'ابدأ بتسجيل تسوية جديدة';
  @override String get settlementExpColCode => 'كود التسوية';
  @override String get settlementExpColFile => 'ملف الشحنة';
  @override String get settlementExpColAccountant => 'المحاسب المسؤول';
  @override String get settlementExpColStatus => 'الحالة';
  @override String get settlementExpColFob => 'إجمالي الفاتورة';
  @override String get settlementExpColExpenses => 'إجمالي المصاريف';
  @override String get settlementExpColLanded => 'تكلفة الوصول الشاملة';
  @override String get settlementExpColMarkup => 'معامل التكلفة';
  @override String get settlementPdfTitle => 'سجل تسويات تكلفة الوصول وتوزيع المصاريف';
  @override String get settlementPdfSubtitle => 'Sorour Logistics ERP — سجل تسويات تكلفة الوصول وتوزيع المصاريف';
  @override String get settlementPdfMetaTotal => 'إجمالي التسويات';
  @override String settlementBreakdownTitle(String code) => 'تقرير تفاصيل تكلفة الوصول وتوزيع المصاريف — $code';
  @override String get settlementBreakdownExpensesSection => 'فواتير المصاريف اللوجستية والجمركية';
  @override String get settlementBreakdownItemsSection => 'جدول تكلفة الوصول للأصناف وتوزيع المصاريف';
  @override String get settlementClo01Title => 'تجميع وتسوية الفواتير الختامية للملف (CLO-01: Multi-Party Invoices Aggregation)';
  @override String settlementClo01Subtitle(String code) => 'المرحلة 9: تكلفة الوصول وإغلاق الملف | الشحنة: $code';
  @override String get settlementClo01Loading => 'جاري المسح والتجميع الآلي لكافة فواتير الشحنة من الـ 8 موديولات...';
  @override String get settlementClo01StatusSettled => 'الفواتير معتمدة ومسواة';
  @override String get settlementClo01StatusPending => 'بانتظار الاعتماد المالي';
  @override String get settlementClo01KpiTotal => 'إجمالي فواتير ومصروفات الشحنة';
  @override String settlementClo01KpiTotalSub(int count) => '$count فاتورة مسجلة';
  @override String get settlementClo01KpiPaid => 'إجمالي المبالغ المسددة';
  @override String get settlementClo01KpiPaidSub => 'سدادات مؤكدة بالسندات';
  @override String get settlementClo01KpiRemaining => 'المتبقي المطلوب سداده';
  @override String get settlementClo01KpiRemainingSubDue => 'مستحقات غير مسددة';
  @override String get settlementClo01KpiRemainingSubNone => 'لا توجد متأخرات';
  @override String get settlementClo01KpiWht => 'ضريبة الخصم (أ.ت.ص - WHT)';
  @override String get settlementClo01KpiWhtSub => 'نموذج 41 (1%)';
  @override String get settlementClo01KpiReady => 'نسبة مطابقة السداد';
  @override String get settlementClo01KpiReadySub => 'جاهزية التسوية';
  @override String get settlementClo01WarningsTitle => 'تنبيهات الفواتير والمستحقات المتبقية قبل إغلاق الملف:';
  @override String settlementClo01PartyAll(int count) => 'كافة الجهات ($count)';
  @override String get settlementClo01PartySupplier => 'المورد الأجنبي';
  @override String get settlementClo01PartyCarrier => 'الشحن والتوكيل';
  @override String get settlementClo01PartyInsurance => 'التأمين البحري';
  @override String get settlementClo01PartyCustoms => 'مصلحة الجمارك';
  @override String get settlementClo01PartyBroker => 'المخلص والميناء';
  @override String get settlementClo01PartyTransport => 'النقل الداخلي';
  @override String get settlementClo01PartyDemurrage => 'غرامات التأخير';
  @override String get settlementClo01NoInvoices => 'لا توجد فواتير مسجلة ضمن هذه الجهة';
  @override String get settlementClo01ColInvoice => 'رقم الفاتورة / المرجع';
  @override String get settlementClo01ColParty => 'الجهة والدائن';
  @override String get settlementClo01ColCategory => 'نوع المصروف';
  @override String get settlementClo01ColOriginal => 'القيمة الأصلية';
  @override String get settlementClo01ColTotal => 'الإجمالي (ج.م)';
  @override String get settlementClo01ColPaid => 'المسدد (ج.م)';
  @override String get settlementClo01ColRemaining => 'المتبقي (ج.م)';
  @override String get settlementClo01ColPayStatus => 'حالة السداد';
  @override String get settlementClo01ColSource => 'المصدر';
  @override String get settlementClo01PaidFull => 'مسدد بالكامل';
  @override String get settlementClo01PaidPartial => 'سداد جزئي';
  @override String get settlementClo01Unpaid => 'غير مسدد';
  @override String get settlementClo01SignOffTitle => 'بيانات اعتماد ومطابقة التسوية المالية (Audit Sign-Off):';
  @override String get settlementClo01SettledByLabel => 'المحاسب المسؤول / أخصائي التكاليف *';
  @override String get settlementClo01NotesLabel => 'ملاحظات الاعتماد المالي الختامي';
  @override String get settlementClo01Confirm => 'اعتماد تسوية الفواتير وتصعيد الملف (CLO-01)';
  @override String get settlementClo01Confirming => 'جاري الاعتماد...';
  @override String get settlementClo02Title => 'محرك احتساب تكلفة الوصول الفعلية والانحراف (CLO-02)';
  @override String settlementClo02Subtitle(String code) => 'ملف استيرادي: $code | تسوية فواتير الموردين والجمارك والنولون ومقارنة محاكاة PL-08';
  @override String get settlementClo02Loading => 'جاري احتساب تكلفة الوصول الفعلية ومطابقة الانحرافات...';
  @override String get settlementClo02ErrorTitle => 'تعذر احتساب تكلفة الوصول الفعلية للشحنة';
  @override String get settlementClo02KpiFob => 'إجمالي البضاعة FOB';
  @override String settlementClo02KpiFobSub(String currency, String rate) => '$currency (سعر الصرف $rate)';
  @override String get settlementClo02KpiExpenses => 'المصاريف الفعلية المسددة';
  @override String get settlementClo02KpiExpensesSub => 'نولون، جمارك، تخليص، ونقل';
  @override String get settlementClo02KpiLanded => 'تكلفة الوصول الشاملة الفعلية';
  @override String settlementClo02KpiLandedSub(String estimated) => 'التقديري: $estimated';
  @override String get settlementClo02KpiMarkup => 'معامل التضخيم الفعلي';
  @override String get settlementClo02KpiMarkupSub => 'نسبة التكلفة الكلية إلى FOB';
  @override String get settlementClo02KpiVariance => 'الانحراف المالي الشامل';
  @override String settlementClo02KpiVarianceSub(String amount, String status) => '$amount ($status)';
  @override String get settlementClo02AllocationLabel => 'قاعدة توزيع المصاريف المشتركة:';
  @override String settlementClo02Counts(int items, int expenses) => 'عدد بنود الأصناف: $items | بنود المصروفات: $expenses';
  @override String settlementClo02TabExpenses(int count) => 'مقارنة بنود المصروفات والانحرافات ($count)';
  @override String settlementClo02TabItems(int count) => 'تكلفة وصول الأصناف للوحدة ($count)';
  @override String get settlementClo02NoExpenses => 'لا توجد بنود مصروفات مسجلة للشحنة';
  @override String get settlementClo02NoItems => 'لا توجد بنود أصناف مسجلة في أوامر شراء هذه الشحنة';
  @override String get settlementClo02ColExpense => 'بند المصروف';
  @override String get settlementClo02ColEstimated => 'التقديري (PL-08)';
  @override String get settlementClo02ColActual => 'الفعلي (CLO-01)';
  @override String get settlementClo02ColVariance => 'الانحراف (ج.م)';
  @override String get settlementClo02ColPct => 'النسبة (%)';
  @override String get settlementClo02ColStatus => 'الحالة';
  @override String get settlementClo02ColInvoices => 'الفواتير';
  @override String get settlementClo02ColSource => 'المصدر والملاحظات';
  @override String get settlementClo02StatusSaving => 'توفير';
  @override String get settlementClo02StatusOver => 'زيادة';
  @override String get settlementClo02StatusMatched => 'مطابق';
  @override String get settlementClo02ColItemCode => 'كود الصنف';
  @override String get settlementClo02ColItemName => 'اسم الصنف';
  @override String get settlementClo02ColHs => 'بند التعريفة HS';
  @override String get settlementClo02ColQty => 'الكمية';
  @override String get settlementClo02ColFobPrice => 'سعر FOB';
  @override String get settlementClo02ColFobTotal => 'إجمالي FOB (ج.م)';
  @override String get settlementClo02ColAllocated => 'المصاريف الموزعة';
  @override String get settlementClo02ColItemTotal => 'إجمالي تكلفة الصنف';
  @override String get settlementClo02ColUnitActual => 'تكلفة الوحدة الفعلية';
  @override String get settlementClo02ColUnitEstimated => 'تكلفة الوحدة التقديرية';
  @override String get settlementClo02ColUnitVariance => 'انحراف الوحدة';
  @override String get settlementClo02ColMarkup => 'معامل الزيادة';
  @override String get settlementClo02ApprovedByLabel => 'المسؤول المالي المعتمد';
  @override String get settlementClo02NotesLabel => 'ملاحظات الاعتماد المالي الختامي (اختياري)';
  @override String get settlementClo02ApproveRequired => 'يرجى تحديد اسم المسؤول المالي المعتمد للتكلفة الفعلية';
  @override String get settlementClo02Approve => 'اعتماد تكلفة الوصول الفعلية للشحنة (CLO-02)';
  @override String get settlementClo02Approving => 'جاري الاعتماد وحفظ التكاليف...';
  @override String get settlementEstTitle => 'محاكاة تكلفة الوصول التقديرية للوحدة قبل الشحن';
  @override String settlementEstSubtitle(String file, String currency, String fx, String incoterm) => 'الملف: $file | العملة: $currency | الصرف: $fx ج.م | شرط الشحن: $incoterm';
  @override String get settlementEstSubtitleLoading => 'جاري تحميل المعطيات اللوجستية والجمركية...';
  @override String get settlementEstLoading => 'جاري حساب وتوزيع تكلفة الوصول التقديرية بالربط مع محرك الجمارك...';
  @override String settlementEstError(String message) => 'خطأ في عملية المحاكاة: $message';
  @override String get settlementEstTabItems => 'تحليل بنود البضاعة وتكلفة الوحدة';
  @override String get settlementEstTabExpenses => 'قائمة المصاريف والنفقات التقديرية';
  @override String get settlementEstKpiFob => 'إجمالي البضاعة FOB';
  @override String get settlementEstKpiFreightIns => 'النولون والتأمين';
  @override String settlementEstKpiFreightSub(String value) => 'نولون: $value';
  @override String get settlementEstKpiCustoms => 'الجمارك والضرائب';
  @override String get settlementEstKpiCustomsSub => 'بند التعريفة MD-008';
  @override String get settlementEstKpiPort => 'الموانئ والتخليص والنقل';
  @override String get settlementEstKpiPortSub => 'لوجستيات وموانئ';
  @override String get settlementEstKpiLanded => 'تكلفة الوصول الشاملة';
  @override String get settlementEstKpiMarkup => 'معامل الزيادة الإجمالي';
  @override String get settlementEstOverridesTitle => 'تعديل معايير ومصاريف المحاكاة (Parameters & Cost Overrides)';
  @override String get settlementEstOverridesSubtitle => 'يمكنك تعديل أسعار الصرف، نولون الشحن، التأمين، التخليص، وتفضيل التوزيع وإعادة الحساب فورياً';
  @override String get settlementEstFxLabel => 'سعر الصرف ج.م';
  @override String get settlementEstFxHint => 'مثال: 50.5';
  @override String get settlementEstFreightLabel => 'نولون الشحن بالجنيه المصري';
  @override String get settlementEstFreightHint => 'تعديل النولون';
  @override String get settlementEstInsuranceLabel => 'التأمين البحري بالجنيه المصري';
  @override String get settlementEstInsuranceHint => 'تعديل التأمين';
  @override String get settlementEstClearanceLabel => 'أتعاب التخليص بالجنيه المصري';
  @override String get settlementEstPortLabel => 'مصاريف الموانئ بالجنيه المصري';
  @override String get settlementEstTransportLabel => 'النقل الداخلي بالجنيه المصري';
  @override String get settlementEstBankLabel => 'مصاريف بنكية بالجنيه المصري';
  @override String get settlementEstOtherLabel => 'مصاريف أخرى بالجنيه المصري';
  @override String get settlementEstResetDefaults => 'استعادة القيم الافتراضية';
  @override String get settlementEstRecalculate => 'إعادة الحساب والتوزيع';
  @override String get settlementEstColNo => 'م';
  @override String get settlementEstColItemCode => 'كود الصنف';
  @override String get settlementEstColItemName => 'اسم الصنف والوصف';
  @override String get settlementEstColHs => 'البند الجمركي';
  @override String get settlementEstColQty => 'الكمية';
  @override String get settlementEstColFobUnit => 'سعر FOB للوحدة';
  @override String get settlementEstColFobTotal => 'إجمالي FOB ج.م';
  @override String get settlementEstColDuty => 'ضريبة الوارد ج.م';
  @override String get settlementEstColVat => 'الضرائب والقيمة المضافة';
  @override String get settlementEstColFreight => 'نولون ولوجستيات';
  @override String get settlementEstColTotalLanded => 'إجمالي التكلفة ج.م';
  @override String get settlementEstColUnitLanded => 'تكلفة الوحدة ج.م';
  @override String get settlementEstColUnitLandedFc => 'تكلفة الوحدة أجنبي';
  @override String get settlementEstColMarkup => 'معامل الزيادة';
  @override String get settlementEstColMarkupPct => 'نسبة الزيادة';
  @override String get settlementEstColExpCategory => 'فئة المصروف';
  @override String get settlementEstColDescription => 'البيان والوصف';
  @override String get settlementEstColAmountEgp => 'القيمة بالجنيه المصري';
  @override String get settlementEstColAmountFc => 'القيمة بالعملة الأجنبية';
  @override String get settlementEstColSource => 'مصدر الاحتساب';
  @override String get settlementEstColAllocRule => 'طريقة التوزيع على البنود';
  @override String get settlementEstNoItems => 'لا توجد بنود متاحة للمحاكاة';
  @override String get settlementEstNoExpenses => 'لا توجد مصاريف مفصلة';
  @override String get settlementEstExportBtn => 'تصدير تقرير Excel/CSV';
  @override String get settlementEstCopyTsvBtn => 'نسخ جدول النتائج';
  @override String get settlementEstCopySuccess => 'تم نسخ بيانات التكلفة التقديرية للحافظة بنجاح';
  @override String get settlementEstCsvHeader => 'م,كود الصنف,اسم الصنف,البند الجمركي,الكمية,سعر الوحدة أجنبي,سعر الوحدة ج.م,إجمالي FOB ج.م,ضريبة الوارد ج.م,الضرائب والقيمة المضافة ج.م,النولون ج.م,الموانئ والتخليص ج.م,النقل الداخلي ج.م,إجمالي تكلفة الوصول ج.م,تكلفة الوحدة ج.م,تكلفة الوحدة أجنبي,معامل الزيادة,نسبة الزيادة %';
  @override String settlementOdooTsvTitle(String code) => 'قيود اليومية المحاسبية للنظام المالي — تسوية $code';
  @override String get settlementOdooLblImporter => 'المستورد';
  @override String get settlementOdooLblSupplier => 'المورد';
  @override String get settlementOdooLblImportFile => 'ملف الاستيراد';
  @override String get settlementOdooLblDate => 'التاريخ';
  @override String get settlementOdooLblTotalDebitCredit => 'إجمالي المدين والدائن';
  @override String get settlementFilterAll => 'الكل';
  @override String get settlementCmpCopiedFileCode => 'تم نسخ كود ملف الشحنة';
  @override String settlementCmpCopiedIncoterm(String incoterm) => 'تم نسخ شرط الشحن الدولي: $incoterm';
  @override String get settlementCmpSelectFilePrompt => 'اختر ملف الاستيراد لمقارنة التكلفة التقديرية بالفعلية';
  @override String get settlementCmpFileLabel => 'اختر ملف الاستيراد لمقارنة التكلفة التقديرية بالفعلية';
  @override String get wrHubTitle => "مركز الاستلام والمخازن والبضاعة بالطريق";
  @override String get wrHubTabGit => "رصيد ومطابقة البضاعة في الطريق";
  @override String get wrHubTabGrn => "استلام المخازن وأذون الإضافة";
  @override String get wrHubTabReport => "تقرير ومطابقة الشحنات المستلمة";
  @override String get wrGrnMetricTotal => "أذون الإضافة";
  @override String get wrGrnMetricPending => "بانتظار العد";
  @override String get wrGrnMetricReceived => "مستلمة";
  @override String get wrGrnMetricDiscrepancy => "بها فروقات";
  @override String get wrGrnQuantitiesSection => "مطابقة الكميات";
  @override String get wrGrnDetailsSection => "بيانات الاستلام";
  @override String get closureMetricRecords => "الشهادات";
  @override String get closureMetricArchived => "مؤرشفة";
  @override String get closureMetricDraft => "مسودات";
  @override String get closureMetricStoppedFiles => "ملفات متوقفة";
  @override String closureChecklistProgress(String done, String total) => "$done من $total شروط مستوفاة";
  @override String get closureRecordsSection => "شهادات الإغلاق";
  @override String get settlementRegistryLoading => 'جاري تحميل تسويات تكلفة الوصول...';
  @override String get settlementCmpVarianceLabel => 'الانحراف عن التقديري';
  @override String settlementMsgLineNoHs(String item, String line) => 'البند $item (سطر $line) بدون بند جمركي وتم استبعاده من تقدير الجمارك';
  @override String settlementMsgPaymentStatusUnknown(String invoice, String party) => 'حالة سداد الفاتورة $invoice للجهة $party غير محددة';
  @override String settlementMsgEstimateUnavailable(String reason) => 'التكلفة التقديرية غير متاحة ($reason)';
  @override String settlementMsgUnpaidInvoice(String party, String amount, String invoice) => 'مستحق غير مسدد لصالح $party: $amount (فاتورة $invoice)';
  @override String settlementMsgWhtRateMissing(String taxCode, String date, String invoice) => 'لا توجد نسبة ضريبة خصم $taxCode سارية بتاريخ $date (فاتورة $invoice)';
  @override String settlementReconciliationNote(String amount) => 'فرق التسوية بين الإجمالي ومجموع الأصناف: $amount';
  @override String get settlementEstKpiDuty => 'ضريبة الوارد';
  @override String get settlementEstKpiVatFees => 'القيمة المضافة والرسوم';
  @override String get fbkQuoteEquipmentMismatch40ft =>
      'المعدات المخصصة لا تتطابق مع أحجام الحاويات المسعرة (عرض السعر يتضمن 40 قدم، ولكن لم يتم تخصيص أي حاوية 40/45 قدم). يرجى تعديل المعدات أو إعادة تطبيق عرض السعر.';
  @override String get fbkQuoteEquipmentMismatch20ft =>
      'المعدات المخصصة لا تتطابق مع أحجام الحاويات المسعرة (عرض السعر يتضمن 20 قدم، ولكن لم يتم تخصيص أي حاوية 20 قدم). يرجى تعديل المعدات أو إعادة تطبيق عرض السعر.';
  @override String get fbkQuoteEquipmentMismatchBoth =>
      'المعدات المخصصة لا تتطابق مع أحجام الحاويات المسعرة (عرض السعر يتضمن 40 و20 قدم، ولكن الحاويات المطابقة غير موجودة). يرجى تعديل المعدات أو إعادة تطبيق عرض السعر.';
  @override String get customsFxRateRequired => 'سعر الصرف الجمركي مطلوب لاحتساب الرسوم والضرائب.';
  @override String get addPoLinesWithHsToEstimateDuties => 'يرجى إضافة بنود أوامر الشراء مصحوبة بالبنود الجمركية (HS Codes) لاحتساب الرسوم والضرائب بدقة.';
  @override String get customsMissingTariffBlockSave => 'تعذر الحفظ: بعض البنود لا تحتوي على تعريفة جمركية. يرجى تعيين التعريفة الجمركية أولاً.';
  @override String get missingTariffLinesWarning => 'بنود بدون تعريفة جمركية';

  // === Session 3 (Logistics, Warehouse & Transport) keys ===
  @override String get settlementPickFileTitle => 'اختيار ملف الاستيراد';
  @override String get settlementPickFileContinue => 'متابعة';
  @override String get settlementPickFileField => 'ملف الاستيراد';
  @override String get inlandEditBookingBtn => 'تعديل الحجز';
  @override String get inlandSaveChangesBtn => 'حفظ التعديلات';
  @override String get inlandUpdatedSnack => 'تم تحديث حجز النقل الداخلي بنجاح';
  @override String get wrPickFileForBookingTitle => 'اختيار ملف الشحن للنقل الداخلي';
  @override String get fbkStatusAmended => 'معدل';
  @override String get fbkEditBlTitle => 'تعديل بوليصة الشحن وتاريخ الوصول المتوقع';
  @override String get fbkCodeAssignedOnSave => 'يُحدد الكود تلقائياً عند الحفظ';
  @override String get fbkCloneResetFile => 'ملف الاستيراد (مطلوب اختياره مجدداً)';
  @override String get fbkCloneResetDates => 'تواريخ الشحن والوصول (مطلوب تحديدها)';
  @override String get fbkStageName => 'حجز الشحن البحري';
  @override String get fbkCancelBookingTitle => 'إلغاء حجز الشحن';
  @override String get fbkCancelBookingConfirm => 'هل أنت متأكد من رغبتك في إلغاء حجز الشحن هذا؟';
  @override String get fbkCancelBookingSuccess => 'تم إلغاء حجز الشحن بنجاح.';
  @override String get fbkWarehouseExpectedDaysRequired => 'عدد أيام التخزين المتوقعة مطلوبة.';
  @override String get fbkWarehouseExpectedDaysInvalid => 'يجب إدخال عدد صحيح أكبر من أو يساوي الصفر.';
  @override String get fbkActionCancel => 'إلغاء الحجز';
  @override String get fbkPrintPdfTitle => 'وثيقة حجز الشحن';
  @override String get fbkSavePdfBtn => 'حفظ بصيغة PDF';
  
  // === Master Items & Catalog Integration (MD-ITEM-001) ===
  @override String get masterItemsCatalog => 'كاتالوج الأصناف والسلع';
  @override String get masterItemsCatalogSubtitle => 'إدارة وتوحيد الأصناف والسلع الاستيرادية والربط مع الموردين';
  @override String get itemPriceTrendsRadar => 'رادار اتجاه الأسعار ومقارنة الصفقات';
  @override String get itemPriceTrendsSubtitle => 'تحليل اتجاهات أسعار الشراء وتكلفة الوصول الفعلية عبر الصفقات';
  @override String get masterItemSearchHint => 'ابحث بكود الصنف أو الوصف بالعربية أو الإنجليزية...';
  @override String get masterItemSelectPlaceholder => 'اختر صنفاً من الكاتالوج أو أدخل كود جديد...';
  @override String get masterItemNoResults => 'لا توجد أصناف مطابقة في الكاتالوج';
  @override String get masterItemAutoFilled => 'تم ملء بيانات الصنف تلقائياً من الكاتالوج';
  @override String get masterItemHsCode => 'بند التعريفة الجمركية';
  @override String get masterItemDefaultUom => 'وحدة القياس الافتراضية';
  @override String get masterItemCbm => 'الحجم الافتراضي للوحدة';
  @override String get masterItemGrossWeight => 'الوزن القائم للوحدة';
  @override String get masterItemNetWeight => 'الوزن الصافي للوحدة';
  @override String get masterItemLinked => 'صنف مربوط بالكاتالوج';
  @override String get masterItemCustomManual => 'إدخال يدوي مخصص';
  @override String get poLineItemDialogTitleAdd => 'إضافة بند جديد لأمر الشراء';
  @override String get poLineItemDialogTitleEdit => 'تعديل بند أمر الشراء';
  @override String get poAddFromCatalog => 'إضافة صنف من الكاتالوج';
  @override String get poEditLineItemWithCatalog => 'تعديل البند من الكاتالوج';
  @override String get poLineItemCatalogAutoFillHint => 'اختر صنفاً من الكاتالوج لملء كود الجمارك والوزن والحجم تلقائياً';

    // ── Operational Pillars Advanced Widgets ───────────────────────────────────
  @override String get cargoXPreAcidHeader => 'فحص منصة كارجو إكس قبل القيد الجمركي المسبق';
  @override String get cargoXPreAcidSubtitle => 'التحقق من حساب المصدر الأجنبي المعتمد على البلوكتشين قبل استخراج رقم نافذة لمنع الرفض الجمركي';
  @override String get cargoXPlatformIdLabel => 'معرف منصة كارجو إكس';
  @override String get cargoXExporterStatusLabel => 'حالة اعتماد المصدر الأجنبي';
  @override String get cargoXStatusVerified => 'معتمد ومطابق للبلوكتشين';
  @override String get cargoXStatusPending => 'قيد التحقق والمراجعة';
  @override String get cargoXStatusNotRegistered => 'غير مسجل على المنظومة';
  @override String get cargoXChecklistBlockchainActive => 'تسجيل المصدر الأجنبي نشط وموثق على البلوكتشين';
  @override String get cargoXChecklistAccountAuthorized => 'تفويض المستورد وربط الشركة متاح في المنصة';
  @override String get cargoXChecklistEnvelopeReady => 'جاهزية إرسال المظروف الإلكتروني الرقمي';
  @override String get cargoXVerifyAccountBtn => 'التحقق الفوري من الحساب';
  @override String get cargoXCopyIdTooltip => 'نسخ معرف منصة كارجو إكس';
  @override String get cargoXIdCopiedSuccess => 'تم نسخ معرف منصة كارجو إكس بنجاح';
  @override String get cargoXUnverifiedWarning => 'تحذير رقابي حاسم: المصدر الأجنبي غير مسجل أو غير مفعل على المنظومة. استخراج رقم نافذة في هذه الحالة سيؤدي إلى رفض المعاملة وتعليق الشحنة في الميناء.';

  @override String get shelfLifeEosHeader => 'فحص الصلاحية والمواصفات القياسية المصرية';
  @override String get shelfLifeEosSubtitle => 'التحقق المشروط من نسبة الصلاحية المتبقية والمواصفات القياسية المصرية والوسم باللغة العربية';
  @override String get shelfLifeSubjectCheckbox => 'الصنف خاضع لاشتراطات مدة الصلاحية والمواصفات القياسية المصرية';
  @override String get shelfLifeEosSpecLabel => 'رقم المواصفة القياسية المصرية';
  @override String get shelfLifeProductionDateLabel => 'تاريخ الإنتاج';
  @override String get shelfLifeExpiryDateLabel => 'تاريخ انتهاء الصلاحية';
  @override String get shelfLifeBatchNumberLabel => 'رقم التشغيلة وتاريخ التعبئة';
  @override String get shelfLifeRemainingRatioLabel => 'نسبة الصلاحية المتبقية عند الوصول';
  @override String get shelfLifeCompliantBadge => 'مستوفٍ لنسبة الصلاحية القانونية';
  @override String get shelfLifeCriticalWarningBadge => 'خطر رقابي: الصلاحية المتبقية أقل من النسبة القانونية';
  @override String get shelfLifeArabicLabelCheckbox => 'توثيق بطاقة البيان والبيانات الإلزامية باللغة العربية على العبوات';
  @override String get shelfLifeEosCertStatusLabel => 'حالة مطابقة المواصفة القياسية';
  @override String get shelfLifeCopyBatchTooltip => 'نسخ رقم التشغيلة';
  @override String get shelfLifeBatchCopiedSuccess => 'تم نسخ رقم التشغيلة بنجاح';
  @override String get shelfLifeEtaArrivalHint => 'تاريخ الوصول المتوقع للميناء';

  @override String get testingLabsTrackHeader => 'مسار المعامل والتحاليل الرقابية';
  @override String get testingLabsTrackSubtitle => 'إدارة وتوثيق سحب العينات ونتائج الفحص المعملي والإفراج تحت التحفظ';
  @override String get testingLabAssignedLabel => 'المعمل الرقابي المختص';
  @override String get testingLabSamplingRecordLabel => 'رقم محضر وإيصال سحب العينات';
  @override String get testingLabSamplingDateLabel => 'تاريخ سحب العينات';
  @override String get testingLabSamplesCountLabel => 'عدد العينات المسحوبة للتحليل';
  @override String get testingLabFeesLabel => 'رسوم الفحص والتحاليل المعملية';
  @override String get testingLabResultStatusLabel => 'نتيجة الفحص والتحليل المعملي';
  @override String get testingLabResultConforming => 'مطابق للمواصفات القياسية';
  @override String get testingLabResultPending => 'قيد الفحص والتحليل بالمعامل';
  @override String get testingLabResultNonConforming => 'غير مطابق للمواصفات القياسية';
  @override String get testingLabUnderBondReleaseCheck => 'إفراج مؤقت تحت التحفظ ونقل البضاعة لمخزن المستورد لحين صدور النتيجة';
  @override String get testingLabCertificateNoLabel => 'رقم شهادة الفحص وتقرير المعمل';
  @override String get testingLabCopyRecordTooltip => 'نسخ رقم محضر سحب العينات';
  @override String get testingLabRecordCopiedSuccess => 'تم نسخ رقم محضر سحب العينات بنجاح';

  @override String get hazardousMaterialsHeader => 'بيانات المواد الخطرة والتصنيف البحري';
  @override String get hazardousMaterialsSubtitle => 'الامتثال لاشتراطات المنظمة البحرية الدولية وتصاريح الحماية المدنية والتداول بالميناء';
  @override String get hazardousSubjectCheckbox => 'الشحنة تحتوي على مواد أو بضائع مصنفة خطرة';
  @override String get hazardousUnNumberLabel => 'رقم الأمم المتحدة للمواد الخطرة';
  @override String get hazardousImdgClassLabel => 'فئة الخطورة البحرية';
  @override String get hazardousPackingGroupLabel => 'مجموعة التعبئة والتغليف';
  @override String get hazardousFlashPointLabel => 'درجة الوميض المئوية';
  @override String get hazardousMsdsStatusLabel => 'حالة صحيفة بيانات سلامة المادة';
  @override String get hazardousCivilProtectionLabel => 'رقم تصريح الحماية المدنية والسلامة';
  @override String get hazardousPortHandlingLabel => 'نمط التداول والتفريغ بالميناء';
  @override String get hazardousHandlingDirectDischarge => 'صرف مباشر على السيارات دون تخزين';
  @override String get hazardousHandlingHazardousYard => 'تخزين بساحة البضائع الخطرة بالميناء';
  @override String get hazardousEmergencyPhoneLabel => 'رقم طوارئ الاستجابة السريعة على مدار الساعة';
  @override String get hazardousCopyUnTooltip => 'نسخ رقم الأمم المتحدة';
  @override String get hazardousUnCopiedSuccess => 'تم نسخ رقم الأمم المتحدة بنجاح';
  @override String get hazardousHighRiskWarning => 'تنبيه أمني ولوجستي: البضائع الخطرة تتطلب موافقة أمن الموانئ والدفاع المدني قبل وصول السفينة بـ ٤٨ ساعة، وتخضع لغرامات أرضيات مضاعفة في حالة التأخير.';

  // ── Session 4: Governance & Enterprise Registry ────────────────────────────
  @override String get makerCheckerDialogTitle => 'حوكمة الصلاحيات والاعتماد المزدوج';
  @override String get makerCheckerDialogSubtitle => 'مراجعة وتقييم متطلبات الاستيراد وتطبيق الاعتماد الرقابي أو الاستثناء التنفيذي';
  @override String get makerSectionTitle => 'بيانات المُعِدّ ومؤشرات التقييم';
  @override String get makerAssessedByLabel => 'المُعِدّ المسؤول';
  @override String get makerRiskLevelLabel => 'مستوى المخاطر التشغيلية';
  @override String get makerOverallStatusLabel => 'الحالة التشغيلية العامة';
  @override String get makerDateLabel => 'تاريخ التقييم';
  @override String get checkerSectionTitle => 'قرار المعتمد والرقابة الإدارية';
  @override String get checkerReviewerNameLabel => 'اسم المعتمد أو المراقب';
  @override String get checkerDecisionLabel => 'قرار المراجعة الرقابية';
  @override String get checkerDecisionApprove => 'اعتماد مطابق ومصرح للشحن';
  @override String get checkerDecisionOverride => 'استثناء تنفيذي معتمد';
  @override String get checkerDecisionReject => 'رفض وإعادة للدراسة';
  @override String get checkerNotesLabel => 'توجيهات وملاحظات المعتمد';
  @override String get checkerNotesHint => 'أدخل الملاحظات والتوجيهات الرقابية إن وجدت...';
  @override String get checkerOverrideReasonLabel => 'سند ومبرر الاستثناء التنفيذي الإلزامي';
  @override String get checkerOverrideReasonHint => 'أدخل السند القانوني أو الموافقة الوزارية الاستثنائية...';
  @override String get checkerApproveBtn => 'تأكيد وحفظ القرار الرقابي';
  @override String get checkerCancelBtn => 'إلغاء';
  @override String get checkerStatusApprovedBadge => 'معتمد رقابياً';
  @override String get checkerStatusPendingBadge => 'بانتظار الاعتماد';
  @override String get checkerStatusOverriddenBadge => 'استثناء تنفيذي';
  @override String get checkerSuccessSnack => 'تم تسجيل وحفظ قرار الاعتماد المزدوج بنجاح';
  @override String get checkerErrorSnack => 'حدث خطأ أثناء حفظ القرار الرقابي';

  // Enterprise Table Columns
  @override String get colAssessmentCode => 'كود التقييم';
  @override String get colHsCodeAndCommodity => 'البند الجمركي والسلعة';
  @override String get colShipmentValue => 'قيمة الشحنة';
  @override String get colCompliancePillars => 'الركائز الرقابية';
  @override String get colRiskLevel => 'المخاطر';
  @override String get colStatus => 'الحالة';
  @override String get colGovernance => 'الحوكمة';
  @override String get colActions => 'الإجراءات';
  @override String get copyAssessmentCodeTooltip => 'نسخ كود التقييم';
  @override String get copyAcidNumberTooltip => 'نسخ رقم القيد الجمركي المسبق';
  @override String get governanceActionTooltip => 'حوكمة الصلاحيات والاعتماد المزدوج';
  @override String get advancedOperationalPillarsAccordionTitle => 'الركائز التشغيلية المتقدمة (كارجو إكس، الصلاحية والمواصفات، المعامل والفحص، المواد الخطرة)';

// === end review phase08_10 keys ===
}




















