// Templates of the backend system messages (docs/system_message_codes.json) in Arabic.
// Keep in sync with the contract: test/system_message_catalog_parity_test.dart checks every
// code, part and param. Placeholders are `{param}`; formatting is done by SystemMessageRenderer.

// ignore_for_file: lines_longer_than_80_chars

const Map<String, Map<String, String>> systemMessageCatalogAr = {
  'ALERT_ACID_EXPIRY_RADAR': {
    'title': 'أرقام ACID تقترب من انتهاء الصلاحية',
    'body': 'يوجد عدد {count} رقم ACID ستنتهي صلاحيتها خلال 7 أيام أو أقل ({acid_numbers}). يرجى سرعة استكمال الإجراءات الجمركية.',
  },
  'ALERT_BACKUP_OVERDUE': {
    'title': 'نسخة احتياطية متأخرة أو مفقودة',
    'body': 'مر {hours} ساعة منذ آخر نسخة احتياطية صالحة (>26h). يرجى مراجعة مسار النسخ الاحتياطية وتشغيل سكربت النسخ فوراً.',
  },
  'ALERT_DB_HEALTH_DEGRADED': {
    'title': 'فحص صحة قاعدة البيانات غير سليم',
    'body': 'تقرير الفحص العميق أظهر حالة غير سليمة ({verdict_enum_db_health_verdict}). المشاكل المرصودة: {issues}.',
  },
  'ALERT_DEMURRAGE_RISK': {
    'title': 'خطر غرامات أرضيات وتأخير حاويات',
    'body': 'يوجد عدد {count} حاوية قاربت فترة سماحها المجانية على النفاد (<48h) أو مستحقة للغرامة ({container_numbers}).',
  },
  'ALERT_DISK_CRITICAL': {
    'title': 'مساحة التخزين حرجة للغاية',
    'body': 'المساحة المتبقية على القرص أقل من 2 جيجابايت ({free_gb} GB). خطر تعطل قاعدة البيانات!',
  },
  'ALERT_DISK_LOW': {
    'title': 'انخفاض مساحة التخزين',
    'body': 'المساحة المتبقية على القرص أقل من 5 جيجابايت ({free_gb} GB). يرجى تفريغ الملفات المؤقتة واللوجز.',
  },
  'ALERT_DISPATCHED': {
    'title': '[{severity_enum_alert_severity}] {alert_title}',
    'body': '{alert_message} (الإجراء: راجع تبويب {target_tab})',
  },
  'ALERT_OFFSITE_BACKUP_OVERDUE': {
    'title': 'النسخ الاحتياطي السحابي الخارجي متأخر',
    'body': 'مر {hours} ساعة دون مزامنة نسخة احتياطية جديدة في مجلد Google Drive (>26h). يرجى التحقق من برنامج المزامنة.',
  },
  'ALERT_SLOW_QUERY_SPIKE': {
    'title': 'ارتفاع غير طبيعي في الاستعلامات البطيئة',
    'body': 'تم تسجيل {count} استعلام بطيء (>150ms). يرجى فحص شاشة المراقبة.',
  },
  'ALERT_STUCK_SHIPMENTS': {
    'title': 'شحنات معلقة بلا تقدم',
    'body': 'يوجد عدد {count} ملف استيراد معلق في نفس المرحلة دون تحديث لأكثر من 10 أيام ({import_file_codes}).',
  },

  'CC_BROKER_AUTHORIZED': {
    'title': 'تم تفويض المخلص الجمركي إلكترونياً — {broker_name}',
    'body': 'تم اعتماد وتفويض المخلص الجمركي ({broker_name}) للشحنة ({import_file_code}) برقم تفويض ({delegation_no}). الملف جاهز لسداد إذن التسليم والبدء في الإقرار الجمركي 46 ك.م.',
    'note': 'تم تعيين وتفويض المخلص الجمركي ({broker_name}) برقم تفويض ({delegation_no}). انتقال الملف إلى مرحلة إقرار 46 ك.م.',
  },
  'CC_CLEARANCE_INVOICE_RECORDED': {
    'title': 'تسجيل فاتورة تخليص ومصاريف موانئ (CL-05)',
    'body': 'تم تسجيل فاتورة {expense_category_enum_clearance_expense_category} برقم ({invoice_number}) بمبلغ {net_amount} ج.م للمقدم {provider_name} للشحنة {import_file_code}.',
  },
  'CC_DECLARATION_46_REGISTERED': {
    'title': 'تم قيد الإقرار الجمركي 46 ك.م — {import_file_code}',
    'body': 'تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({declaration_no}) على ({channel_enum_customs_channel}) للشحنة ({import_file_code}) بمكتب جمارك ({customs_office}). الملف قيد الكشف والمعاينة وسحب العينات (CL-01).',
    'note': 'تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({declaration_no}) على ({channel_enum_customs_channel}). انتقال الشحنة إلى الكشف والمعاينة وسحب العينات.',
  },
  'CC_DELIVERY_ORDER_PAID': {
    'title': 'تم سداد إذن التسليم واستلام D/O — {import_file_code}',
    'body': 'تم تسجيل سداد مصاريف التوكيل الملاحي ({shipping_agent_name}) واستلام إذن التسليم ({do_number}) للشحنة ({import_file_code}). تنتهي الصلاحية في ({expiry_date}). الملف جاهز لقيد نموذج 46 ك.م.',
    'note': 'تم سداد مصاريف التوكيل الملاحي واستلام إذن التسليم ({do_number}). جاهز لقيد 46 ك.م.',
  },
  'CC_DUTIES_ASSESSED': {
    'title': 'تم احتساب الرسوم والضرائب الجمركية — {import_file_code}',
    'body': 'تم تثمين واعتماد المطالبة الجمركية رقم ({claim_no}) للشحنة ({import_file_code}) بإجمالي مستحق ({total_amount} ج.م). جاهز للسداد عبر منظومة سداد (CL-03).',
    'note': 'تم احتساب الرسوم والضرائب الجمركية بمطالبة نافذة #{claim_no} بإجمالي ({total_amount} ج.م). جاهز للسداد عبر سداد.',
  },
  'CC_DUTIES_PAID': {
    'title': 'تم سداد الرسوم الجمركية — {import_file_code}',
    'body': 'تم تأكيد سداد الرسوم الجمركية للشحنة ({import_file_code}) بمبلغ ({paid_amount} ج.م) عبر منظومة سداد ({sadad_no}) وإيصال #{receipt_no}. جاهز لصدور أمر الإفراج الجمركي الأخضر (CL-04).',
    'note': 'تم سداد الرسوم الجمركية بنجاح برقم سداد {sadad_no} وإيصال {receipt_no}. بانتظار صدور إذن الإفراج النهائي.',
  },
  'CC_DUTIES_PAID_BANK': {
    'note': 'تم سداد الرسوم الجمركية برقم إيصال ({receipt_no}) لدى {bank_enum_duty_bank}. بانتظار صدور إذن الإفراج النهائي.',
  },
  'CC_INSPECTION_RECORDED': {
    'title': 'تم تسجيل الكشف والمعاينة وسحب العينات — {import_file_code}',
    'body': 'تم تسجيل محضر الكشف والمعاينة الميدانية للشحنة ({import_file_code}) بنتيجة ({inspection_result_enum_inspection_result}) في ({inspection_yard_enum_inspection_yard}). محضر سحب العينات: ({sampling_record_no}). جاهز لاحتساب الرسوم النهائية (CL-02).',
    'note': 'تم إنجاز الكشف والمعاينة بنتيجة ({inspection_result_enum_inspection_result}). محضر سحب العينات: ({sampling_record_no}). انتقال الشحنة لاحتساب الرسوم الجمركية.',
  },
  'CC_RECORD_OPENED': {
    'note': 'تم فتح سجل التخليص الجمركي ({clearance_code}) وانتقال الملف إلى مرحلة قيد ومطابقة الإقرار الجمركي 46.',
  },
  'CC_RELEASE_ISSUED': {
    'title': 'صدور إذن الإفراج الجمركي الأخضر — {import_file_code}',
    'body': 'صدر إذن الإفراج الجمركي الأخضر النهائي برقم ({permit_no}) للشحنة ({import_file_code}). تم الترخيص بالصرف والتحميل على سيارات النقل الداخلي (TR-01).',
    'note': 'صدر أمر الإفراج النهائي الأخضر برقم ({permit_no}). تم ترخيص الصرف والنقل إلى مرحلة النقل والمخازن.',
  },
  'CC_RELEASE_ISSUED_TO_DEMURRAGE': {
    'note': 'صدر أمر الإفراج النهائي برقم ({permit_no}). تم نقل الملف إلى مرحلة إدارة الغرامات وفترات السماح.',
  },
  'CC_TASK_DECLARATION_46': {
    'title': 'قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03) — {import_file_code}',
    'body': 'تم سداد مصاريف التوكيل الملاحي واستلام إذن التسليم (D/O: {do_number}) بصلاحية حتى {expiry_date}. يرجى سرعة قيد وتثبيت الإقرار الجمركي ونموذج 46 ك.م عبر نافذة MTS للبدء في إجراءات الكشف والتثمين.',
  },
  'CC_TASK_DELIVERY_ORDER_PAYMENT': {
    'title': 'سداد إذن التسليم الملاحي واستلام D/O (CS-02) — {import_file_code}',
    'body': 'تم تعيين وتفويض المخلص الجمركي ({broker_name}) برقم تفويض ({delegation_no}). يرجى سداد مصاريف التوكيل الملاحي واستلام إذن التسليم (Delivery Order) لبدء الكشف والمعاينة وقيد الإقرار 46.',
  },
  'CC_TASK_DUTY_ASSESSMENT': {
    'title': 'احتساب الرسوم والضرائب الجمركية النهائية (CL-02) — {import_file_code}',
    'body': 'تم تسجيل الكشف والمعاينة وسحب العينات للشحنة ({import_file_code}) بنجاح بنتيجة ({inspection_result_enum_inspection_result}). يرجى مراجعة المطالبة الجمركية واحتساب الرسوم والضرائب الجمركية النهائية (ضريبة الوارد، القيمة المضافة، رسم التنمية، رسوم الخدمات).',
  },
  'CC_TASK_DUTY_PAYMENT': {
    'title': 'تسجيل سداد الرسوم الجمركية عبر سداد / E-Finance (CL-03) — {import_file_code}',
    'body': 'صدرت المطالبة الجمركية رقم ({claim_no}) بإجمالي رسوم ({total_amount} ج.م) للشحنة ({import_file_code}). يرجى إصدار أمر التحويل والسداد عبر منظومة سداد وتوثيق إيصال السداد البنكي.',
  },
  'CC_TASK_FREE_TIME_MONITOR': {
    'title': 'مراقبة فترات السماح وتفادي غرامات الأرضيات والتأخير (TR-02) — {import_file_code}',
    'body': 'متابعة خروج الحاويات من الميناء وتفريغها بالمخزن قبل انتهاء فترات السماح ({free_days} يوم) لتفادي غرامات الخط الملاحي.',
  },
  'CC_TASK_INLAND_TRANSPORT': {
    'title': 'تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) — {import_file_code}',
    'body': 'تم صدور إذن الإفراج النهائي الأخضر برقم ({permit_no}). يرجى تأكيد وحجز شاحنات النقل وتوثيق أرقام السيارات والسائقين لنقل الشحنة من الميناء إلى المستودع.',
  },
  'CC_TASK_INSPECTION': {
    'title': 'تسجيل الكشف والمعاينة وسحب العينات (CL-01) — {import_file_code}',
    'body': 'تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({declaration_no}) على ({channel_enum_customs_channel}) بمكتب جمارك ({customs_office}). يرجى البدء في إجراءات المعاينة الميدانية وسحب العينات لجهات العرض المحددة.',
  },
  'CC_TASK_RELEASE': {
    'title': 'صدور أمر الإفراج الجمركي الأخضر وبدء إجراءات النقل (CL-04) — {import_file_code}',
    'body': 'تم سداد الرسوم الجمركية بمبلغ ({paid_amount} ج.م) بنجاح عبر سداد برقم ({sadad_no}) للشحنة ({import_file_code}). يرجى استخراج إذن الإفراج النهائي الأخضر وتنسيق خروج الحاويات.',
  },

  'CGX_ENVELOPE_SEALED': {
    'title': 'تم اعتماد وختم مظروف CargoX وتحويله للجمارك — {envelope_code}',
    'body': 'تم إغلاق وتوثيق مظروف CargoX رقم ({envelope_code}) بالرقم التعريفي ACID ({acid_number}) والتوقيع الإلكتروني بنجاح وتحويل المستندات لمصلحة الجمارك المصرية (إيصال: {receipt_no}).',
    'note': 'تم إغلاق مظروف CargoX ({envelope_code}) وتحويله رسمياً لمصلحة الجمارك المصرية. الانتقال إلى مرحلة تحصيل أصول المستندات.',
  },
  'CGX_TASK_COLLECT_ORIGINALS': {
    'title': 'استلام وتوثيق أصول المستندات البنكية للشحنة (SH-04) — {import_file_code}',
    'body': 'تم إغلاق وختم مظروف CargoX ({envelope_code}) وإرساله للجمارك (إيصال: {receipt_no}). يرجى استلام وتوثيق أصول المستندات البنكية لتجهيز الإقرار 46 ك.م.',
  },

  'CLO_DOSSIER_EXPORTED': {
    'title': 'تم تصدير التقرير والملف الشامل للشحنة {import_file_code}',
    'body': 'قام {exported_by} بتصدير واعتماد الملف الشامل للشحنة {import_file_code} بصيغة {export_format}. أصبحت الشحنة جاهزة للإغلاق الرسمي والأرشفة الرقمية (CLO-04).',
    'note': 'تم تصدير الملف الشامل ({export_format}) بواسطة {exported_by}.',
  },
  'CLO_FILE_CLOSED': {
    'title': 'تم الإغلاق الرسمي والأرشفة الرقمية: {import_file_code}',
    'body': 'تم إغلاق الملف الاستيرادي {import_file_code} رسمياً بنجاح بنسبة إنجاز 100%، وتم إصدار شهادة الإغلاق {closure_code} وحفظه في {archive_location}.',
    'note': 'تم الإغلاق النهائي للملف الاستيرادي وأرشفته (الكود: {closure_code}) بواسطة {auditor_name}.',
  },
  'CLO_TASK_OFFICIAL_CLOSURE': {
    'title': 'الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)',
    'body': 'تم تصدير واعتماد الملف الشامل للشحنة {import_file_code} بنجاح بصيغة {export_format}. المطلوب الآن استكمال قائمة التحقق النهائية وإصدار شهادة الإغلاق والأرشفة الرقمية.',
  },

  'DAILY_REPORT_FAILED': {
    'title': 'فشل توليد التقرير اليومي لمنظومة المراقبة',
    'body': 'فشل توليد تقرير المراقبة اليومي الآلي: {error}',
  },
  'DAILY_REPORT_READY': {
    'title': 'تقرير المراقبة اليومي — {report_date}',
  },

  'DD_CHARGES_POSTED': {
    'note': 'تم ترحيل غرامات وفترات سماح الحاويات ({tracking_code}) إلى التسوية المالية. الانتقال إلى مرحلة استلام المخزن.',
  },
  'DD_EMPTY_CONTAINERS_RETURNED': {
    'title': 'إرجاع الحاويات الفارغة بسلام — {import_file_code}',
    'body': 'تم تأكيد إرجاع {container_count} حاوية بموجب إيصال EIR #{eir_number} إلى {depot_enum_empty_container_depot} وإيقاف عدادات الغرامات. الشحنة جاهزة للتسوية النهائية.',
    'note': 'تم إرجاع الحاويات الفارغة بموجب إيصال EIR #{eir_number} وإيقاف عدادات الغرامات بالكامل.',
  },
  'DD_FREE_DAYS_RECORDED': {
    'title': 'تم توثيق فترات السماح المجانية ({demurrage_free_days} يوم) (BK-02)',
    'body': 'تم تسجيل وتثبيت فترات السماح المجانية للشحنة ({import_file_code}) بنجاح. أيام سماح الأرضيات: {demurrage_free_days} يوم، أيام سماح الحاوية الفارغة: {detention_free_days} يوم. المرجع: {agreement_reference}. تم تحديث رادار الغرامات تلقائياً وتوفير متوقع: {estimated_saving_amount} دولار.',
  },
  'DD_TASK_SETTLE_FINAL_INVOICES': {
    'title': 'تجميع وتسوية الفواتير الختامية وتكلفة الوصول (CLO-01)',
    'body': 'تم استلام إيصال EIR #{eir_number} وإغلاق ملف الخط الملاحي بسلام. يرجى تجميع فواتير المورد، النولون، المخلص، والنقل، واحتساب تكلفة الوصول النهائية للشحنة.',
  },

  'DOC_ACID_REGISTERED': {
    'title': 'تم قيد وتدقيق رقم ACID: {acid_number}',
    'body': 'تم قيد وتدقيق الرقم التعريفي المبدئي (ACID: {acid_number}) بنجاح للشحنة ({import_file_code}). صلاحية الرقم حتى {expiry_date}. تم نقل الشحنة إلى مرحلة حجز النولون (STEP_06).',
    'note': 'تم قيد وتدقيق الرقم التعريفي المبدئي بنجاح (ACID: {acid_number}) للشحنة ({import_file_code}).',
  },
  'DOC_BANK_DOCUMENT_RECORDED': {
    'title': 'اعتماد وتوثيق {doc_type}: {reference_no}',
    'body': 'تم توثيق واعتماد {doc_type} برقم ({reference_no}) عبر بنك {bank_name} للشحنة ({import_file_code}). تم نقل الشحنة إلى مرحلة الإجراءات الجمركية ونموذج 46 (STEP_13).',
    'note': 'تم استلام وتوثيق المستند البنكي ({doc_type}) برقم ({reference_no}) للشحنة ({import_file_code}).',
  },
  'DOC_COO_APPROVED': {
    'note': 'اكتمال واعتماد شهادة المنشأ ({certificate_type} - {certificate_number}) وتحديث الموافقة الجمركية بنجاح.',
  },
  'DOC_CUSTOMS_APPROVAL_GRANTED': {
    'note': 'اعتماد الموافقة الجمركية على الأوراق والمستندات رسمياً بالجلسة ({session_code}) ونقل الشحنة إلى المرحلة الرابعة (منصة CargoX وتحصيل الأصول).',
  },
  'DOC_DRAFT_BLOCKING_FIELD_EMPTY': {
    'reason': 'حقل حرج فارغ: {field_enum_draft_bl_field}',
  },
  'DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH': {
    'reason': 'اختلاف حرج في {field_enum_draft_bl_field}',
  },
  'DOC_DRAFT_BL_REVIEWED': {
    'title': 'اكتمال المراجعة المزدوجة لمسودة بوليصة الشحن: {import_file_code} (SH-02)',
    'body': 'تمت مطابقة واعتماد مسودة بوليصة الشحن ({draft_bl_number}) لملف الشحنة ({import_file_code}) بنجاح والتأكد من تطابقها الكامل مع أمر الشراء والفاتورة التجارية. تم تجهيز الملف لمرحلة CargoX (SH-03).',
    'note': 'اكتمال واعتماد مراجعة مسودة بوليصة الشحن ({draft_bl_number}) وتحديث الموافقة الجمركية بنجاح (SH-02).',
  },
  'DOC_INSPECTION_REVIEW_APPROVED': {
    'note': 'تم اعتماد مراجعة مسودة شهادة الفحص والتفتيش ({review_code}). الانتقال إلى مرحلة الاعتماد الجمركي النهائي للأوراق.',
  },
  'DOC_INSPECTION_REVIEW_UPDATED': {
    'note': 'تم تحديث واعتماد مراجعة شهادة الفحص ({review_code}). الانتقال إلى مرحلة الاعتماد الجمركي للأوراق.',
  },
  'DOC_INVOICE_BL_MATCH_DONE': {
    'note': 'اكتمال المطابقة الذكية بين الفاتورة ({invoice_number}) والبوليصة ({draft_bl_number}) وتحديث مصفوفة الموافقة الجمركية للمستندات.',
  },
  'DOC_PO_RECONCILIATION_DONE': {
    'note': 'تم إتمام مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء ({session_code}). الانتقال إلى مراجعة مسودة بوليصة الشحن.',
  },
  'DOC_PO_RECONCILIATION_UPDATED': {
    'note': 'تم تحديث واعتماد مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء ({session_code}). الانتقال إلى مسودة بوليصة الشحن.',
  },
  'DOC_TASK_CARGOX_TRANSFER': {
    'title': 'منصة النقل الرقمي CargoX واعتماد الملفات: {import_file_code} (SH-03)',
    'body': 'تمت المراجعة المزدوجة واعتماد مسودة بوليصة الشحن ({draft_bl_number}) بنجاح والتأكد من مطابقتها التامة مع أمر الشراء والفاتورة لمنع غرامات التعديل الجمركي. يجب الآن قيام المصدر برفع حزمة المستندات واعتماد المظروف الرقمي (Envelope ID) عبر منصة CargoX لربطه بنافذة.',
  },
  'DOC_TASK_DECLARATION_46': {
    'title': 'قيد الإقرار الجمركي ونموذج 46 ك.م: {import_file_code} (CS-03)',
    'body': 'تم اعتماد وتوثيق المستند البنكي ({doc_type}) برقم المرجع ({reference_no}) من بنك ({bank_name}). يرجى استكمال تقديم نموذج 46 ك.م وبدء إجراءات الكشف والمطابقة الجمركية عبر نافذة.',
  },
  'DOC_TASK_FREIGHT_BOOKING': {
    'title': 'تأكيد حجز النولون وتحديد الخط الملاحي: {import_file_code} (BK-01)',
    'body': 'تم إصدار وتدقيق رقم الـ ACID ({acid_number}). يجب تأكيد حجز النولون (Booking No) مع الخط الملاحي أو وكيل الشحن وتحديد مواعيد الإبحار المتوقعة (ETD) والوصول (ETA) وتثبيت فترات السماح (Free Days).',
  },

  'EMAIL_PARSE_MATCHED': {
    'note': 'تم مطابقة الإيميل بنجاح استناداً إلى [{reference}] مع الشحنة [{import_file_code}] وتوليد مهمة المتابعة/السداد رقم #{task_code}.',
  },
  'EMAIL_PARSE_NO_REFERENCE': {
    'note': 'تم استلام الإيميل ولم يُعثر على رقم بوليصة أو ACID أو أمر شراء أو مشروع لشحنة مسجلة.',
  },
  'EMAIL_PARSE_UNMATCHED_ACID': {
    'note': 'تم استخراج رقم ACID [{acid_number}] ولكن لم يتم العثور على شحنة نشطة مسجلة به.',
  },
  'EMAIL_PARSE_UNMATCHED_BL': {
    'note': 'تم استخراج البوليصة [{bl_number}] ولكن لم يتم العثور على شحنة نشطة مسجلة بهذا الرقم.',
  },
  'EMAIL_PARSE_UNMATCHED_PO': {
    'note': 'تم استخراج أمر الشراء [{po_number}] ولم يتم العثور على شحنة نشطة مرتبطة به.',
  },
  'EMAIL_SYNC_EMPTY': {
    'body': 'تم فحص الصندوق ولا توجد رسائل جديدة.',
  },
  'EMAIL_SYNC_ERROR': {
    'body': 'خطأ أثناء جلب الإيميلات من الخادم: {error}',
  },
  'EMAIL_SYNC_ERROR_OUTLOOK': {
    'body': 'خطأ أثناء جلب الرسائل من تطبيق Microsoft Outlook: {error}',
  },
  'EMAIL_SYNC_SUMMARY': {
    'body': 'تم فحص {count} إيميل، ومطابقة {matched_count} شحنة، وتوليد {tasks_count} مهمة سداد.',
  },
  'EMAIL_SYNC_SUMMARY_OUTLOOK': {
    'body': 'تم فحص {count} إيميل من تطبيق Microsoft Outlook، ومطابقة {matched_count} شحنة، وتوليد {tasks_count} مهمة سداد.',
  },
  'EMAIL_TASK_APPROVED': {
    'title': 'سداد مصاريف إذن التسليم ({import_file_code})',
    'body': 'تم الاعتماد والتوجيه عبر مراجعة البريد الذكي.',
    'note': 'تم الاعتماد والتوجيه بواسطة المستخدم: {user_name}',
  },
  'EMAIL_TASK_AUTO_GENERATED': {
    'note': 'تم التوليد التلقائي عبر المستمع الذكي للإيميلات استناداً إلى: {reference}',
  },
  'EMAIL_TASK_DELIVERY_ORDER_PAYMENT': {
    'title': 'سداد مصاريف إذن التسليم ({import_file_code})',
    'body': 'تم رصد إشعار وصول / متابعة بريدية رسمية مرتبطة بـ [{reference}]. مطلوب المتابعة الفورية مع التوكيل الملاحي لسداد مصاريف إذن التسليم والعوائد المينائية قبل وصول السفينة المتوقع بتاريخ {eta_date} لتفادي أي غرامات تأخير أو أرضيات.',
    'note': 'تم التوليد التلقائي عبر المستمع الذكي للإيميلات استناداً إلى: {reference}',
  },

  'FA_ADVANCE_PAYMENT_REQUESTED': {
    'note': 'تم إصدار طلب سداد الدفعة المقدمة للمورد ({payment_code}) بمبلغ {requested_amount} {currency_code}',
  },
  'FA_APPROVED_BUDGET_VARIANCE': {
    'title': 'تنبيه فارق مالي بميزانية معتمدة: {import_file_code}',
    'body': 'تم تعديل تكاليف في المصدر لميزانية معتمدة ({budget_code}) للشحنة ({import_file_code}) بواسطة {modified_by}. الفارق يتطلب مراجعة واعتماد إصدار جديد للميزانية (Budget Revision).',
  },
  'FA_BUDGET_APPROVED': {
    'title': 'تم اعتماد الميزانية التقديرية: {budget_code}',
    'body': 'تم اعتماد الميزانية التقديرية ({budget_code}) بإجمالي {total_amount} ج.م من قبل {approved_by}.',
  },
  'FA_BUDGET_APPROVED_FILE': {
    'title': 'تم اعتماد الميزانية التقديرية: {budget_code}',
    'body': 'تم اعتماد الميزانية التقديرية ({budget_code}) للملف ({import_file_code}) بإجمالي {total_amount} ج.م من قبل {approved_by}.',
  },
  'FA_BUDGET_NEEDS_REVALIDATION': {
    'title': 'ميزانية تحتاج إعادة تحقق: {import_file_code}',
    'body': "تم تعديل تكاليف في مرحلة سابقة بواسطة {modified_by} للشحنة ({import_file_code}). تم إيقاف دورة الاعتماد وتحويل الميزانية ({budget_code}) إلى 'تحتاج إعادة تحقق'.",
  },
  'FA_PAYMENT_REQUEST_APPROVED': {
    'title': 'تمت الموافقة على طلب الصرف: {payment_code}',
    'body': 'تمت الموافقة على طلب الصرف رقم ({payment_code}) بمبلغ {requested_amount} {currency_code} لصالح المورد ({supplier_name}). الطلب جاهز للتنفيذ والتحويل البنكي.',
  },
  'FA_PAYMENT_REQUEST_APPROVED_FILE': {
    'title': 'تمت الموافقة على طلب الصرف: {payment_code}',
    'body': 'تمت الموافقة على طلب الصرف رقم ({payment_code}) للملف ({import_file_code}) بمبلغ {requested_amount} {currency_code} لصالح المورد ({supplier_name}). الطلب جاهز للتنفيذ والتحويل البنكي.',
  },
  'FA_PAYMENT_REQUEST_CREATED': {
    'title': 'طلب سداد دفعة مقدمة للمورد: {payment_code}',
    'body': 'تم إصدار طلب سداد دفعة مقدمة للمورد ({supplier_name}) بمبلغ {requested_amount} {currency_code} ({requested_egp_amount} ج.م) للشحنة ({import_file_code}). يستحق في {due_date}. يتطلب المراجعة والاعتماد وسداد السويفت البنكي.',
  },
  'FA_PAYMENT_REQUEST_CREATED_GENERIC': {
    'title': 'طلب سداد مالي جديد: {payment_code}',
    'body': 'تم إصدار طلب سداد مالي للمورد ({supplier_name}) بمبلغ {requested_amount} {currency_code} ({requested_egp_amount} ج.م). يستحق في {due_date}.',
  },
  'FA_SWIFT_PAID': {
    'title': 'تم سداد الدفعة وحوالة السويفت - جاهز لطلب ACID ({import_file_code})',
    'body': 'تم تأكيد سداد التحويل البنكي وحوالة السويفت رقم ({swift_ref}) بمبلغ ({paid_amount} {currency_code}) للملف الاستيرادي ({import_file_code}). تم فتح مرحلة استخراج ACID عبر نافذة.',
    'note': 'تم سداد الحوالة البنكية وسويفت MT103 رقم {swift_ref} بمبلغ {paid_amount} {currency_code}',
  },
  'FA_TASK_ISSUE_ACID': {
    'title': '[{import_file_code}] — استخراج الرقم التعريفي المبدئي للشحنة ACID عبر نافذة',
    'body': 'تم تحويل السويفت البنكي بنجاح برقم {swift_ref}. المطلوب الآن استخراج الرقم المبدئي ACID للشحنة ({import_file_code}) عبر منصة نافذة ورفع المستندات الأولية.',
  },
  'FA_TASK_SUPPLIER_PAYMENT': {
    'title': 'سداد الدفعة المقدمة للمورد وحساب السويفت: {supplier_name} ({payment_code})',
    'body': 'سداد دفعة المورد بمبلغ {requested_amount} {currency_code} ({requested_egp_amount} ج.م) المستحقة في {due_date} للشحنة ({import_file_code}) ومطابقة إشعار التحويل البنكي MT103/SWIFT.',
  },
  'FA_TASK_SUPPLIER_PAYMENT_GENERIC': {
    'title': 'سداد مستحقات المورد: {supplier_name} ({payment_code})',
    'body': 'سداد دفعة المورد بمبلغ {requested_amount} {currency_code} ({requested_egp_amount} ج.م) المستحقة في {due_date} للشحنة ({import_file_code}) ومطابقة إشعار التحويل البنكي MT103/SWIFT.',
  },

  'FB_BOOKING_CONFIRMED': {
    'title': 'تم تأكيد حجز الشحن (Booking: {booking_no})',
    'body': 'تم تأكيد حجز الشحن برقم ({booking_no}) للشحنة ({import_file_code}) بنجاح. الخط الملاحي: {shipping_line_name}، السفينة: {vessel_name}، ETD: {etd_date}، ETA: {eta_date}. فترة السماح: {demurrage_free_days} يوم.',
  },
  'FB_SAILING_CONFIRMED': {
    'title': 'تم تأكيد إبحار الشحنة وبوليصة الشحن (B/L: {bl_number})',
    'body': 'أبحرت الشحنة ({import_file_code}) بنجاح بتاريخ ({atd_date}). الباخرة: {vessel_name}، الرحلة: {voyage_number}. رقم بوليصة الشحن: ({bl_number}). موعد الوصول المتوقع المحدث (ETA): {eta_date}.',
    'note': 'تم تأكيد إبحار الشحنة الفعلي بتاريخ {atd_date} وإصدار بوليصة الشحن B/L: {bl_number}',
  },
  'FB_TASK_DRAFT_BL_REVIEW': {
    'title': 'المراجعة المزدوجة لمسودة بوليصة الشحن ومطابقتها مع أمر الشراء: {import_file_code} (SH-02)',
    'body': 'تم تأكيد إبحار الشحنة الفعلي وتسجيل رقم بوليصة الشحن ({bl_number}) على الباخرة ({vessel_name}) برحلة ({voyage_number}). يجب إجراء المطابقة الفورية بين بيانات البوليصة (Shipper, Consignee, Notify, Goods, Net/Gross Wt) وبين أمر الشراء والفاتورة التجارية لتفادي غرامات التعديل الجمركي.',
  },
  'FB_TASK_FREE_DAYS': {
    'title': 'تسجيل وتثبيت فترات السماح المجانية للحاويات: {import_file_code} (BK-02)',
    'body': 'تم تأكيد حجز الشحن برقم ({booking_no}) على الخط الملاحي ({shipping_line_name}) والسفينة ({vessel_name}). يجب توثيق وتأكيد أيام السماح المجانية المتفق عليها ({demurrage_free_days} يوم) لتغذية رادار احتساب غرامات التأخير.',
  },

  'FS_INVOICES_SETTLED': {
    'title': 'تم اعتماد تسوية فواتير الشحنة {import_file_code}',
    'body': 'قام {settled_by} باعتماد ومطابقة كافة فواتير ومصروفات الشحنة {import_file_code} بعدد {invoice_count} فاتورة وبإجمالي {total_amount} ج.م، تمهيداً لاحتساب تكلفة الوصول (CLO-02).',
  },
  'FS_LANDED_COST_APPROVED': {
    'title': 'تم اعتماد تكلفة الوصول الفعلية للشحنة {import_file_code}',
    'body': 'قام {approved_by} باعتماد تكلفة الوصول الفعلية للشحنة {import_file_code} بإجمالي {total_amount} ج.م (معامل زيادة {markup_factor}x، انحراف {variance_pct}% - {variance_status_enum_landed_cost_variance_status}).',
    'note': 'تم اعتماد تكلفة الوصول الفعلية والانحراف ({settlement_code}).',
  },
  'FS_SETTLEMENT_CREATED': {
    'note': 'تم إنشاء سجل التسوية المالية وحساب تكلفة الوصول الشاملة ({settlement_code}).',
  },
  'FS_TASK_CALCULATE_LANDED_COST': {
    'title': 'احتساب تكلفة الوصول الفعلية وتوزيعها على الأصناف (CLO-02)',
    'body': 'تم الانتهاء من تجميع ومطابقة فواتير ومصروفات الشحنة {import_file_code} بعدد {invoice_count} فاتورة وبإجمالي {total_amount} ج.م. يرجى تشغيل محرك تكلفة الوصول وتوزيع التكاليف على الأصناف.',
  },
  'FS_TASK_EXPORT_DOSSIER': {
    'title': 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
    'body': 'تم اعتماد تكلفة الوصول الفعلية للشحنة {import_file_code} بإجمالي {total_amount} ج.م وانحراف {variance_pct}%. يرجى تصدير الملف الشامل وحزمة المستندات.',
  },

  'GUIDE_HS_LAB_INSPECTION': {
    'title': 'فحص معملي وعرض رقابي إلزامي للبند الجمركي {hs_code}',
    'body': 'البند الجمركي {hs_code} ({product_category}) يخضع بشكل نمطي لمسار الكشف الأحمر وسحب العينات لصالح ({regulatory_bodies_enum_regulatory_body}) بنسبة 100% عبر {shipment_count} شحنات سابقة. يجب تجهيز الفواتير الأصلية المعتمدة وشهادات التحليل والمطابقة مسبقاً لتفادي غرامات الحاويات.',
    'evidence': 'خضعت جميع الشحنات السابقة للبند {hs_code} ({shipment_count} شحنة) للفحص المعملي ومسار الكشف الأحمر.',
    'reason': 'تكرار تحويل البند الجمركي {hs_code} إلى المسار الأحمر وسحب العينات في الشحنات السابقة.',
  },
  'GUIDE_PORT_COST_VARIANCE': {
    'title': 'ارتفاع تكلفة التخليص الفعلية عن التقديرات بميناء {port_name} (+{avg_variance_pct}%)',
    'body': 'تُشير الحسابات الختامية للشحنات المفرغة في {port_name} إلى زيادة فعلية في التكلفة النهائية (Landed Cost) عن الموازنة التقديرية بمتوسط +{avg_variance_pct}% عبر {shipment_count} شحنات. يُوصى بمراجعة بنود غرامات الأرضيات والمصاريف الإدارية المينائية مسبقاً.',
    'evidence': 'تجاوزت {shipment_count} شحنات سابقة بميناء {port_name} التكلفة التقديرية بمتوسط زيادة +{avg_variance_pct}%.',
    'reason': 'تكرار انحراف التكاليف الإجمالية الفعلية بالزيادة في ميناء {port_name}.',
  },
  'GUIDE_SEASONAL_CONGESTION': {
    'title': 'تأثيرات الازدحام الموسمي للشحنات خلال شهر {month}',
    'body': 'تشهد الشحنات المفتوحة خلال شهر {month} بطئاً عاماً في سلاسل الإمداد بسبب الإجازات الرسمية أو ذروة الشحن البحري العالمي. يُنصح بالبدء المبكر في استخراج ACID وحجز المساحات الملاحية قبل موعد الشحن بـ 3 أسابيع على الأقل.',
    'evidence': 'تسجيل حركة استيرادية مكثفة وتأخيرات موسمية في {shipment_count} شحنة خلال هذا الشهر.',
    'reason': 'تكرار بطء التوريد والترانزيت في دورة شهر {month} السنوية.',
  },
  'GUIDE_SUPPLIER_DELAY': {
    'title': 'تأخيرات متكررة في تسليم المورد {supplier_name} (+{avg_delay_days} يوم)',
    'body': 'يُلاحظ من واقع تحليل بيانات الشحنات السابقة أن المورد {supplier_name} يتأخر في جاهزية البضاعة بمتوسط +{avg_delay_days} يوم عن التاريخ التعاقدي (نسبة التكرار {frequency_pct}% عبر {delayed_count} من أصل {total_shipment_count} شحنات). يُوصى بإضافة هامش زمني للجدول الزمني وأخذ ذلك في الاعتبار عند إصدار ACID.',
    'evidence': 'تم رصد تأخير في {delayed_count} شحنة من إجمالي {total_shipment_count} شحنة بمتوسط تأخير قدره {avg_delay_days} يوم.',
    'reason': 'تكرار تأخر المورد {supplier_name} في استيفاء مواعيد التوريد التعاقدية في أكثر من شحنة.',
  },
  'GUIDE_SUPPLIER_DOC_ERRORS': {
    'title': 'أخطاء مستندية متكررة من المورد {supplier_name} ({category})',
    'body': 'تم تسجيل {mismatch_count} بطاقات عدم تطابق مستندي تخص المورد {supplier_name}، أبرزها ({category}). يجب إلزام المورد بتدقيق مسودات الشحن ومطابقة الأوزان والأوصاف قبل إصدار بوليصة الشحن النهائية.',
    'evidence': 'تسجيل {mismatch_count} حالات عدم تطابق مستندي سابقة في شحنات المورد، تتركز معظمها في {category}.',
    'reason': 'تكرار إصدار مستندات بها اختلافات من المورد {supplier_name}.',
  },
  'GUIDE_TRANSIT_DEVIATION': {
    'title': 'انحراف زمن الإبحار للخط {carrier_name} إلى {port_name} (+{avg_extra_days} يوم)',
    'body': 'يُظهر الرصد الإحصائي أن رحلات الخط الملاحي {carrier_name} المتجهة إلى {port_name} تسجل زيادة فعلية عن زمن الترانزيت المجدول بمتوسط +{avg_extra_days} يوم عبر {delayed_count} شحنات. يُنصح باشتراط فترة سماح كافية (Free Time >= 21 days) لتجنب غرامات التأخير.',
    'evidence': 'تأخرت {delayed_count} شحنة من أصل {total_shipment_count} بمعدل تأخير إضافي قدره {avg_extra_days} يوم مقارنة بزمن الترانزيت التعاقدي.',
    'reason': 'تكرار تجاوز الخط الملاحي {carrier_name} لأزمنة الترانزيت المجدولة على ميناء {port_name}.',
  },

  'LC_CLOSURE_STEP_RESERVED': {
    'note': 'المرحلة STEP_21 مخصصة لمنظومة إغلاق الملفات ولا يمكن إكمالها مباشرة عبر HTTP.',
  },
  'LC_FILE_NOT_ACTIVE': {
    'note': 'ملف الاستيراد {import_file_code} في حالة {status} ولا يمكن تحريك مراحله على اللوحة.',
  },
  'LC_FILE_NOT_FOUND': {
    'note': 'ملف الاستيراد {import_file_code} غير موجود أو غير نشط.',
  },
  'LC_FILE_REF_REQUIRED': {
    'note': 'يلزم تحديد معرف ملف الاستيراد أو كود الملف.',
  },

  'LC_FILE_ON_HOLD': {
    'note': 'تم إيقاف الشحنة عند مرحلة [{phase_id}]: {reason}',
  },
  'LC_FILE_ON_HOLD_CODED': {
    'note': 'تم إيقاف الشحنة عند مرحلة [{phase_id}]: {reason_enum_hold_reason}',
  },
  'LC_FILE_ON_HOLD_CODED_WITH_NOTES': {
    'note': 'تم إيقاف الشحنة عند مرحلة [{phase_id}]: {reason_enum_hold_reason} | {notes}',
  },
  'LC_FILE_ON_HOLD_WITH_NOTES': {
    'note': 'تم إيقاف الشحنة عند مرحلة [{phase_id}]: {reason} | {notes}',
  },
  'LC_FILE_RESUMED': {
    'note': 'تم استئناف العمل: {notes}',
  },
  'LC_FILE_RESUMED_DEFAULT': {
    'note': 'تم استئناف العمل: استئناف تشغيل الشحنة',
  },
  'LC_INITIAL_ACTIVITY': {
    'note': 'تهيئة أولية لنشاط الشحنة',
  },
  'LC_MULTI_STAGE_ACTIVATED': {
    'note': 'تفعيل مرحلي متزامن',
  },
  'LC_PENDING_REFERENCE': {
    'note': 'مرجع معلق: {reference_number} — {reason}',
  },
  'LC_STARTING_POINT_SET': {
    'note': 'نقطة البداية المحددة للشحنة: {step_code}',
  },
  'LC_STEP_ACTIVATED': {
    'note': 'تم التفعيل بعد إكمال {completed_step_code}',
  },
  'LC_STEP_ACTIVATED_AFTER_SKIP': {
    'note': 'تم التفعيل بعد تخطي {skipped_step_code}',
  },
  'LC_STEP_AUTO_CLOSED_PRIOR': {
    'note': 'تم الإكمال التلقائي عند إنجاز {completed_step_code}',
  },
  'LC_STEP_AUTO_COMPLETED': {
    'note': 'تم الاستيفاء التلقائي عند الانتقال إلى {target_step_code}',
  },
  'LC_STEP_BYPASSED_FOR_LATER_START': {
    'note': 'تم تجاوزها واكتمالها لبدء الشحنة مباشرة من مرحلة لاحقة',
  },
  'LC_STEP_COMPLETED': {
    'note': 'تم إنجاز {step_code} بنجاح',
  },
  'LC_STEP_NOT_ACTIVE': {
    'note': 'المرحلة {step_code} ليست قيد التنفيذ حالياً على ملف الاستيراد {import_file_code}.',
  },
  'LC_STEP_ALREADY_COMPLETED': {
    'note': 'المرحلة {step_code} مكتملة أو تم تخطيها بالفعل لملف الشحنة {import_file_code}.',
  },
  'LC_STEP_SEQUENCE_INVALID': {
    'note': 'لا يمكن تفعيل المرحلة {step_code} قبل الوصول إليها في مسار الشحنة لغير المسؤولين.',
  },
  'LC_TARGET_STEP_INVALID': {
    'note': 'لا يمكن الانتقال مباشرة إلى الخطوة {step_code} بدون صلاحيات المسؤول.',
  },
  'LC_STEP_ON_HOLD': {
    'note': 'معلقة مؤقتاً: {reason}',
  },
  'LC_STEP_ON_HOLD_CODED': {
    'note': 'معلقة مؤقتاً: {reason_enum_hold_reason}',
  },
  'LC_STEP_RESUMED': {
    'note': 'تم الاستئناف: {notes}',
  },
  'LC_STEP_RESUMED_DEFAULT': {
    'note': 'تم الاستئناف: استئناف تشغيل الشحنة',
  },
  'LC_STEP_SKIPPED': {
    'note': 'تم تخطي المرحلة: {reason}',
  },
  'LC_SYNC_BOOKING_CONFIRMED': {
    'note': 'تم تأكيد حجز الشحن {booking_code}',
  },
  'LC_SYNC_BOOKING_CONFIRMED_DETAILS': {
    'note': 'تم تأكيد حجز الشحن {booking_code} برقم تأكيد {confirmation_no} على الباخرة {vessel_name}',
  },
  'LC_SYNC_BOOKING_PENDING': {
    'note': 'طلب حجز الشحن {booking_code} قيد المتابعة والتأكيد مع الخط الملاحي',
  },
  'LC_SYNC_BUDGET_APPROVED': {
    'note': 'تم اعتماد الميزانية التقديرية للشحنة بنجاح',
  },
  'LC_SYNC_BUDGET_UNDER_REVIEW': {
    'note': 'تم إعداد الميزانية التقديرية وهي قيد المراجعة والاعتماد المالي',
  },
  'LC_SYNC_CARGO_ALLOCATION_DONE': {
    'note': 'تم إتمام وتدقيق بيانات تخصيص الحاويات وأوزان VGM لسجل الشحن {cargo_shipping_code} ({container_count} حاوية/طرد)',
  },
  'LC_SYNC_CARGO_ALLOCATION_DRAFT': {
    'note': 'سجل تخصيص الحاويات والشحن {cargo_shipping_code} قيد الإعداد والتدقيق (مسودة)',
  },
  'LC_SYNC_CUSTOMS_STUDY_DONE': {
    'note': 'تم إنجاز وتوثيق الاستشارة الجمركية والتعريفة',
  },
  'LC_SYNC_FREIGHT_STUDIES_DONE': {
    'note': 'تم إنجاز دراسات النولون والشحن والانتقال للدراسات الجمركية',
  },
  'LC_TASK_NEXT_STEP': {
    'title': '[{import_file_code}] — {step_code}',
    'body': 'تم إكمال {completed_step_code} للشحنة {import_file_code} والانتقال إلى {step_code} ضمن {phase_id}. الإجراء المطلوب: متابعة واستيفاء متطلبات المرحلة.',
    'note': 'توليد آلي بعد إكمال {completed_step_code}',
  },
  'LC_TASK_NEXT_STEP_SKIPPED': {
    'title': '[{import_file_code}] — {step_code}',
    'body': 'تم تخطي {completed_step_code} للشحنة {import_file_code} والانتقال إلى {step_code} ضمن {phase_id}. الإجراء المطلوب: متابعة واستيفاء متطلبات المرحلة.',
    'note': 'توليد آلي بعد تخطي {completed_step_code}',
  },

  'NA_ARCHIVE_IMPORT_FILE': {
    'action': 'أرشفة الملف الاستيرادي',
  },
  'NA_AUDIT_COO_PREFERENTIAL': {
    'action': 'تدقيق شهادة المنشأ وقواعد الاتفاقيات التفضيلية',
  },
  'NA_AUDIT_DRAFT_BL_INVOICES': {
    'action': 'تدقيق مسودة البوليصة والفواتير التجارية',
  },
  'NA_AUDIT_INSPECTION_CERTIFICATES': {
    'action': 'تدقيق شهادات الفحص قبل الشحن والمطابقة',
  },
  'NA_AUDIT_INVOICE_PACKING_VS_PO': {
    'action': 'تدقيق الفاتورة التجارية وقائمة التعبئة مقابل أمر الشراء',
  },
  'NA_AUDIT_LANDED_COST_CLOSURE': {
    'action': 'تدقيق تفاصيل تكلفة الوصول وإصدار شهادة الإغلاق',
  },
  'NA_AWAIT_LAB_APPROVAL_BEFORE_PRODUCTION': {
    'action': 'بانتظار اعتماد نتيجة المعامل قبل الإنتاج',
  },
  'NA_CLO_CALCULATE_LANDED_COST': {
    'action': 'احتساب تكلفة الوصول الفعلية وتوزيعها على الأصناف (CLO-02)',
  },
  'NA_CLO_CALCULATE_LANDED_COST_AND_SETTLE': {
    'action': 'احتساب تكلفة الوصول الفعلية والانحراف (CLO-02) والتسوية النهائية (CLO-01)',
  },
  'NA_CLO_COMPLETE_CHECKLIST': {
    'action': 'استكمال باقي مهام قائمة تحقق الإغلاق',
  },
  'NA_CLO_EXPORT_DOSSIER': {
    'action': 'إصدار وتصدير التقرير والملف الشامل PDF/Excel (CLO-03)',
  },
  'NA_CLO_OFFICIAL_CLOSURE': {
    'action': 'الإغلاق الرسمي والأرشفة الرقمية للملف (CLO-04)',
  },
  'NA_CLO_SETTLE_FINAL_INVOICES': {
    'action': 'تجميع وتسوية الفواتير الختامية للملف (CLO-01)',
  },
  'NA_CL_ASSESS_FINAL_DUTIES': {
    'action': 'احتساب الرسوم والضرائب الجمركية النهائية (CL-02)',
  },
  'NA_CL_AWAIT_LAB_RESULTS': {
    'action': 'بانتظار نتيجة المعامل',
  },
  'NA_CL_ISSUE_GREEN_RELEASE': {
    'action': 'صدور أمر الإفراج الجمركي الأخضر (CL-04)',
  },
  'NA_CL_RECORD_DUTY_PAYMENT': {
    'action': 'تسجيل سداد الرسوم الجمركية بسداد (CL-03)',
  },
  'NA_CL_RECORD_INSPECTION': {
    'action': 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
  },
  'NA_CL_RE_EXPORT_OR_DISPOSAL': {
    'action': 'إعادة تصدير أو إعدام',
  },
  'NA_COLLECT_ORIGINALS_FORM4': {
    'action': 'تحصيل أصول المستندات وإنهاء نموذج 4',
  },
  'NA_COMPLETE_CLONED_FILE': {
    'action': 'إكمال بيانات الشحنة المستنسخة وفتح إجراءات ACID',
  },
  'NA_CONFIRM_ACID_PROCEED_BOOKING': {
    'action': 'تأكيد رقم ACID والانتقال لحجز النولون',
  },
  'NA_CONFIRM_BOOKING_REVIEW_DRAFT_BL': {
    'action': 'تأكيد الحجز مع الخط الملاحي ومراجعة مسودة البوليصة',
  },
  'NA_CREATE_PAYMENT_REQUEST_FORM4': {
    'action': 'إنشاء طلب السداد (BP-012) واستخراج نموذج 4',
  },
  'NA_CS01_ASSIGN_BROKER': {
    'action': 'تعيين المخلص الجمركي وإصدار التفويض الإلكتروني (CS-01)',
  },
  'NA_CS_PAY_DELIVERY_ORDER': {
    'action': 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)',
  },
  'NA_CS_REGISTER_DECLARATION_46': {
    'action': 'قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)',
  },
  'NA_CUSTOMS_INSPECTION_DUTY_SETTLEMENT': {
    'action': 'الكشف الجمركي وسداد الرسوم',
  },
  'NA_EVALUATE_SCENARIOS_REQUEST_QUOTES': {
    'action': 'تقييم سيناريوهات الشحن (BP-007) وطلب عروض أسعار النولون (BP-008)',
  },
  'NA_FILE_ARCHIVED_READ_ONLY': {
    'action': 'الملف مؤرشف — حالة تاريخية للقراءة فقط',
  },
  'NA_FILE_CLOSED': {
    'action': 'تم إغلاق الملف الاستيرادي بنجاح',
  },
  'NA_FILE_CLOSED_EARLY': {
    'action': 'تم إغلاق الملف مبكراً عند {phase_id}',
  },
  'NA_FILE_CLOSED_EARLY_GENERIC': {
    'action': 'تم إغلاق الملف مبكراً',
  },
  'NA_FILE_FULLY_CLOSED_ARCHIVED': {
    'action': 'تم إغلاق الملف وأرشفته بالكامل',
  },
  'NA_FOLLOW_COMPENSATION_LANDED_COST': {
    'action': 'متابعة تعويض التأمين/المورد (CLO-01) واحتساب تكلفة الوصول (CLO-02)',
  },
  'NA_FOLLOW_LAB_RESULTS_WARRANTY_CLAIMS': {
    'action': 'متابعة نتائج المعامل ومطالبات الضمان مع المورد',
  },
  'NA_FOLLOW_UP_STEP': {
    'action': 'متابعة وتنفيذ {step_code}',
  },
  'NA_INSPECT_CARGO_SETTLE_TAXES': {
    'action': 'معاينة البضاعة وسداد الضرائب الجمركية',
  },
  'NA_INSPECT_GOODS_SETTLE_LANDED_COST': {
    'action': 'فحص البضاعة المستلمة وتسوية تكلفة الوصول',
  },
  'NA_ISSUE_ADVANCE_PAYMENT_REQUEST_ACID': {
    'action': 'صرف الدفعة المقدمة وطلب رقم ACID',
  },
  'NA_OBTAIN_CUSTOMS_APPROVAL_DRAFTS': {
    'action': 'الحصول على الموافقة الجمركية على مسودات المستندات',
  },
  'NA_PAY_DUTIES_RELEASE_CARGO': {
    'action': 'سداد الرسوم الجمركية والإفراج عن البضاعة من الميناء',
  },
  'NA_PENDING_REGULATORY_REQUIREMENTS': {
    'action': 'استيفاء {count} متطلبات رقابية معلقة ({requirements})',
  },
  'NA_PREPARE_FINANCIAL_APPROVAL': {
    'action': 'إعداد طلب الاعتماد المالي',
  },
  'NA_REGISTER_DECLARATION_46': {
    'action': 'قيد الإقرار الجمركي 46 ك.م',
  },
  'NA_RESUME_OPERATIONS': {
    'action': 'استئناف العمل عند {phase_id}',
  },
  'NA_RESUME_OPERATIONS_GENERIC': {
    'action': 'استئناف العمل',
  },
  'NA_REVIEW_DRAFT_BL_WITH_CARRIER': {
    'action': 'مراجعة مسودة البوليصة مع الخط الملاحي وإصدار التعديلات',
  },
  'NA_REVIEW_REGULATORY_REQUIREMENTS': {
    'action': 'مراجعة اشتراطات ومتطلبات الاستيراد الرقابية',
  },
  'NA_REVIEW_SETTLEMENT_AND_CLOSE': {
    'action': 'مراجعة التسوية النهائية وإغلاق الملف',
  },
  'NA_SH04_COLLECT_ORIGINALS': {
    'action': 'استلام وتوثيق أصول المستندات البنكية (SH-04)',
  },
  'NA_STEP03_REVIEW_REGULATORY_APPROVALS': {
    'action': 'مراجعة اشتراطات ومتطلبات الاستيراد للشحنة والموافقات الرقابية',
  },
  'NA_STEP04_APPROVE_ADVANCE_PAYMENT': {
    'action': 'مراجعة واعتماد سداد الدفعة المقدمة للمورد وتجهيز السويفت البنكي',
  },
  'NA_STEP04_APPROVE_BUDGET_SUPPLIER_PAYMENT': {
    'action': 'مراجعة واعتماد الميزانية التقديرية وسداد دفعة المورد',
  },
  'NA_STEP04_COMPLETE_PAYMENT_REQUEST_ACID': {
    'action': 'استكمال سداد المورد وطلب رقم ACID (STEP_05)',
  },
  'NA_STEP04_REVIEW_BUDGET_SUPPLIER_TRANSFER': {
    'action': 'مراجعة اعتمادات الميزانية والتحويل البنكي للمورد',
  },
  'NA_STEP05_REQUEST_ACID': {
    'action': 'طلب واستخراج رقم القيد الجمركي المبدئي (ACID) عبر منظومة نافذة',
  },
  'NA_STEP06_CONFIRM_BOOKING': {
    'action': 'تأكيد حجز الشحن مع الخط الملاحي أو وكيل الشحن الفائز',
  },
  'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION': {
    'action': 'متابعة تأكيد حجز الشحن واستلام إشعار التأكيد (Booking Confirmation)',
  },
  'NA_STEP06_FOLLOW_BOOKING_CONFIRMATION_REF': {
    'action': 'متابعة تأكيد حجز الشحن واستلام إشعار التأكيد (Booking: {booking_no})',
  },
  'NA_STEP07_AUDIT_ALLOCATION_VGM': {
    'action': 'تدقيق بيانات تخصيص الحاويات وأوزان VGM ومراجعة مسودات مستندات الشحن',
  },
  'NA_STEP07_COMPLETE_CONTAINERS_VGM': {
    'action': 'استكمال أرقام الحاويات والأختام وأوزان VGM',
  },
  'NA_STEP07_FOLLOW_LOADING_PLAN': {
    'action': 'متابعة خطة التحميل وتوزيع الحاويات وشهادات VGM للشحنة (Booking: {booking_no})',
  },
  'NA_STEP08BL_MATCH_BL_PO_INVOICE': {
    'action': 'مراجعة وتدقيق بيانات البوليصة ومطابقتها مع أمر الشراء والفاتورة',
  },
  'NA_STEP08BL_REVIEW_DRAFT_BL': {
    'action': 'مراجعة وتدقيق مسودة بوليصة الشحن ومطابقتها مع الفاتورة (SH-02)',
  },
  'NA_STEP08COO_REVIEW_COO': {
    'action': 'مراجعة مسودة شهادة المنشأ والاتفاقيات التفضيلية',
  },
  'NA_STEP08PO_RECONCILE_INVOICE_PACKING_PO': {
    'action': 'مراجعة وتدقيق بنود الفاتورة والباكينج ومطابقة أمر الشراء',
  },
  'NA_STEP09_CARGOX_ENVELOPE': {
    'action': 'رفع واعتماد المظروف الرقمي وختم الوثائق عبر CargoX (SH-03)',
  },
  'NA_STEP09_FINAL_DOCS_APPROVAL': {
    'action': 'تدقيق ومراجعة الاعتماد الجمركي النهائي للأوراق',
  },
  'NA_STEP10_UPLOAD_APPROVED_TO_CARGOX': {
    'action': 'رفع المسودات المعتمدة وشهادات الفحص على منصة CargoX الرقمية',
  },
  'NA_SUBMIT_DOCS_BANK_FORM4': {
    'action': 'تقديم المستندات للبنك لاستخراج نموذج 4',
  },
  'NA_TRACK_DEMURRAGE_FREE_TIME': {
    'action': 'متابعة غرامات الحاويات وانتهاء فترات السماح',
  },
  'NA_TRACK_LAB_RESULTS': {
    'action': 'متابعة نتائج تحليل العينات بالجهات الرقابية والمعامل',
  },
  'NA_TR_BOOK_INLAND_TRANSPORT': {
    'action': 'تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01)',
  },
  'NA_TR_BOOK_INLAND_TRANSPORT_MONITOR_FREE_TIME': {
    'action': 'تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) ومراقبة فترات السماح (TR-02)',
  },
  'NA_TR_CHECK_SEALS_ISSUE_GRN': {
    'action': 'التحقق من سلامة الأختام وإصدار إذن الإضافة GRN (TR-03)',
  },
  'NA_TR_FOLLOW_DISPATCH_FREE_TIME_RECEIVING': {
    'action': 'متابعة الصرف (TR-01) ورادار فترات السماح (TR-02) والاستلام المخزني (TR-03)',
  },
  'NA_TR_INSPECTION_DISCREPANCY_LANDED_COST': {
    'action': 'الفحص الفني ومحضر العجز والتلف (TR-04) وتكلفة الوصول (CLO-02)',
  },
  'NA_TR_RECEIVE_TRUCK_ISSUE_GRN': {
    'action': 'استلام الشاحنة وتفريغ الحاويات وإصدار إذن الإضافة GRN (TR-03)',
  },
  'NA_UPLOAD_CARGOX_PREPARE_DECLARATION_46': {
    'action': 'رفع المستندات الرقمية على CargoX وتجهيز الإقرار 46',
  },
  'NA_UPLOAD_DOCS_TO_CARGOX': {
    'action': 'رفع المستندات الرقمية على CargoX',
  },
  'NA_VALUATION_INSPECTION_SAMPLING': {
    'action': 'التثمين الجمركي والكشف وسحب العينات',
  },
  'NA_VERIFY_INVOICE_BL_MATCH': {
    'action': 'التحقق من تطابق البيانات بين الفاتورة والبوليصة',
  },
  'NA_VERIFY_QUANTITIES_DISCREPANCIES': {
    'action': 'التحقق من كميات البضاعة وتسوية الفروقات',
  },
  'NA_WAREHOUSE_READY_FOR_DISPATCH': {
    'action': 'مخزون المستودع جاهز للصرف',
  },

  'NOTIF_ACID_REQUEST_EXPIRY': {
    'title': 'تنبيه قرب انتهاء الرقم المبدئي ACID: {acid_number}',
    'body': 'رقم الـ ACID ({acid_number}) للشحنة متبقي عليه {days_left} أيام فقط قبل الشحن وتنتهي صلاحيته في {expiry_date}.',
  },
  'NOTIF_BUDGET_OVERRUN': {
    'title': 'تنبيه تجاوز ميزانية الشحنة: {import_file_code}',
    'body': 'المصروفات الفعلية المسجلة للشحنة {import_file_code} تجاوزت الميزانية التقديرية بنسبة {overrun_pct}% (الفعلي: {actual_amount} ج.م مقابل التقديري: {estimated_amount} ج.م). يرجى مراجعة الفروقات.',
  },
  'NOTIF_CARGOX_UPLOAD_DELAY': {
    'title': 'تنبيه تأخر رفع مستندات CargoX: {import_file_code}',
    'body': 'الشحنة {import_file_code} متوقع وصولها خلال {days_left} يوماً (ETA: {eta_date}) ولم يقم المورد {supplier_name} برفع أو اعتماد مظروف المستندات على CargoX. يرجى المتابعة العاجلة.',
  },
  'NOTIF_COMPANY_IMPORTER_ID_EXPIRY': {
    'title': 'تنبيه انتهاء البطاقة الاستيرادية: {company_name}',
    'body': 'البطاقة الاستيرادية (رقم {importer_id}) متبقي عليها {days_left} يوماً وتنتهي في {expiry_date}. يرجى التجديد فوراً.',
  },
  'NOTIF_COMPANY_REGISTRATION_EXPIRY': {
    'title': 'تنبيه انتهاء السجل التجاري: {company_name}',
    'body': 'السجل التجاري (رقم {registration_number}) متبقي عليه {days_left} يوماً وينتهي في {expiry_date}.',
  },
  'NOTIF_CUSTOMS_FX_DROP': {
    'title': 'تنبيه انخفاض سعر الدولار الجمركي',
    'body': 'تم رصد انخفاض في سعر الصرف الجمركي للدولار بنسبة {change_pct}% (السعر الحالي: {current_rate} ج.م مقارنة بـ {previous_rate} ج.م). يرجى تحديث دراسات الرسوم الجمركية للشحنات الجارية.',
  },
  'NOTIF_CUSTOMS_FX_RISE': {
    'title': 'تنبيه ارتفاع سعر الدولار الجمركي',
    'body': 'تم رصد ارتفاع في سعر الصرف الجمركي للدولار بنسبة {change_pct}% (السعر الحالي: {current_rate} ج.م مقارنة بـ {previous_rate} ج.م). يرجى تحديث دراسات الرسوم الجمركية للشحنات الجارية.',
  },
  'NOTIF_CUSTOMS_FX_VOLATILITY': {
    'title': 'تنبيه تقلب سعر الدولار الجمركي',
    'body': 'تم رصد تغير في سعر الصرف الجمركي للدولار بنسبة {change_pct}% (السعر الحالي: {current_rate} ج.م مقارنة بـ {previous_rate} ج.م). يرجى تحديث دراسات الرسوم الجمركية للشحنات الجارية.',
  },
  'NOTIF_DEMURRAGE_ACTIVE': {
    'title': 'غرامات أرضيات نشطة: {import_file_code}',
    'body': 'شحنة {import_file_code} تتراكم عليها غرامات أرضيات بقيمة {fx_amount} دولار ({egp_amount} ج.م). يُرجى التدخل الفوري للتخليص والسحب.',
  },
  'NOTIF_DEMURRAGE_WARNING': {
    'title': 'تحذير أرضيات: {import_file_code}',
    'body': 'شحنة {import_file_code} متبقي لها {days_left} يوم قبل انتهاء فترة السماح وبدء احتساب الغرامات. الرجاء التعجيل في إجراءات التخليص.',
  },
  'NOTIF_DETENTION_RETURN_DEADLINE': {
    'title': 'تحذير مهلة إرجاع الحاويات الفارغة (Detention): {tracking_code}',
    'body': 'متبقي {days_left} يوماً على انتهاء فترة سماح الحاويات الفارغة للخط الملاحي {carrier_name} (بوليصة {bl_number}). يرجى إرجاع الحاويات لتفادي غرامات التأخير بالدولار.',
  },
  'NOTIF_DOCUMENT_SHORTAGE': {
    'title': 'نقص مستندي: {import_file_code}',
    'body': 'شحنة {import_file_code} وصلت أو قاربت الوصول لكن اكتمال المستندات {readiness_pct}% فقط ({verified_count}/7 مستندات). يُرجى استكمال الملف المستندي فوراً.',
  },
  'NOTIF_ETA_WITHOUT_CLEARANCE': {
    'title': 'ETA وشيك بدون تخليص: {import_file_code}',
    'body': 'شحنة {import_file_code} ستصل خلال {hours} ساعة ولم يُفتح لها ملف تخليص جمركي بعد. يُرجى المباشرة فوراً في إجراءات إقرار 46 ك.م.',
  },
  'NOTIF_FORM4_DELAY': {
    'title': 'تنبيه تأخر صدور نموذج 4 البنكي: {bank_name}',
    'body': 'طلب نموذج 4 مع بنك {bank_name} معلق منذ {pending_days} يوماً (مرجع: {bank_doc_code}). يرجى مراجعة البنك لتسريع الاعتماد قبل وصول البضاعة.',
  },
  'NOTIF_IMPORT_FILE_ACID_EXPIRY': {
    'title': 'تنبيه قرب انتهاء صلاحية ACID للشحنة: {import_file_code}',
    'body': 'رقم القيد الجمركي ({acid_number}) للشحنة ({import_file_code}) متبقي عليه {days_left} يوماً وينتهي في {expiry_date}. يرجى التمديد عبر نافذة لتفادي حظر الإفراج.',
  },
  'NOTIF_ORIGINALS_COLLECTION_DELAY': {
    'title': 'تنبيه تأخر استلام أصول المستندات: {import_file_code}',
    'body': 'البوليصة وأصول المستندات للشحنة {import_file_code} لم يتم استلامها بالكامل بينما موعد وصول الباخرة متبقي عليه {days_left} يوماً (ETA: {eta_date}). يرجى مراجعة تتبع شركة الشحن السريع.',
  },
  'NOTIF_REGULATORY_PENDING': {
    'title': 'تنبيه متطلبات رقابية وفحص مسبق: {import_file_code}',
    'body': 'الشحنة {import_file_code} تحتوي على أصناف (بند تعريفي: {hs_code}) تتطلب شهادة فحص مسبق أو موافقة رقابية ({authority_enum_regulatory_body}) ما زالت معلقة.',
  },

  'ODC_ORIGINALS_RECEIVED': {
    'title': 'تم استلام وتوثيق أصول المستندات البنكية — {collection_code}',
    'body': 'تم استلام وتوثيق كافة أصول المستندات البنكية للشحنة ({import_file_code}) بنسبة {completion_pct}% (الكود: {collection_code}). الملف جاهز للتخليص الجمركي.',
    'note': 'تم استلام وتوثيق أصول المستندات البنكية بالكامل (الكود: {collection_code}). الانتقال إلى نموذج 4 البنكي والتجهيز الجمركي.',
  },
  'ODC_TASK_ASSIGN_BROKER': {
    'title': 'تعيين المخلص الجمركي وإصدار التفويض الإلكتروني (CS-01) — {import_file_code}',
    'body': 'تم استلام وتوثيق أصول المستندات البنكية للشحنة ({import_file_code}) (جلسة {collection_code}). يرجى تعيين المخلص الجمركي وإصدار التفويض الإلكتروني للبدء في الإقرار 46.',
  },

  'REQ_TASK_COA': {
    'title': '[{import_file_code}] [ACID: {acid_number}] توفير شهادة التحليل والمطابقة المعملية (COA)',
    'body': 'استلام تقرير الاختبار الكيميائي/الميكانيكي من الشركة المصنعة',
  },
  'REQ_TASK_COO': {
    'title': '[{import_file_code}] [ACID: {acid_number}] استخراج وتدقيق شهادة المنشأ الأصلية',
    'body': 'يجب استلام وتدقيق شهادة المنشأ الأصلية لتطبيق المعاملة التفضيلية والإفراج الجمركي - الحالة الحالية: {status_enum_requirement_status}',
  },
  'REQ_TASK_COO_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] استخراج وتدقيق شهادة المنشأ ({certificate_type})',
    'body': 'يجب استلام وتدقيق شهادة المنشأ للبند {hs_code} لتطبيق الإعفاء/التخفيض الجمركي - الحالة: {status_enum_requirement_status}',
  },
  'REQ_TASK_DECREE43': {
    'title': '[{import_file_code}] [ACID: {acid_number}] التحقق من تسجيل المصنع/المورد الأجنبي لدى GOEIC (قرار 43)',
    'body': 'البضاعة خاضعة للقرار الوزاري 43 لسنة 2016؛ يجب التحقق من قيد المصنع بالقائمة البيضاء لدى GOEIC قبل الشحن',
  },
  'REQ_TASK_DECREE43_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] المورد يحتاج تسجيل مصنع بالقائمة البيضاء (قرار 43/2016)',
    'body': 'بند التعريفة {hs_code} يخضع للقرار الوزاري 43 لسنة 2016 والمورد غير مقيد بالقائمة البيضاء لدى GOEIC، ويلزم تسجيل المصنع أو استيفاء إعفاء معتمد قبل الشحن.',
  },
  'REQ_TASK_HALAL': {
    'title': '[{import_file_code}] [ACID: {acid_number}] توفير شهادة الحلال الرسمية',
    'body': 'توفير شهادة الحلال الصادرة من مركز معتمد من IS EG Halal',
  },
  'REQ_TASK_INSPECTION': {
    'title': '[{import_file_code}] [ACID: {acid_number}] إصدار شهادة الفحص قبل الشحن ({authority_enum_regulatory_body})',
    'body': 'الصنف يخضع للفحص الفني الإلزامي قبل الشحن في بلد المنشأ بواسطة {authority_enum_regulatory_body}',
  },
  'REQ_TASK_INSPECTION_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] إصدار شهادة الفحص قبل الشحن ({authority_enum_regulatory_body})',
    'body': 'البند {hs_code} يخضع للفحص الفني الإلزامي قبل الشحن بواسطة {authority_enum_regulatory_body}',
  },
  'REQ_TASK_MSDS': {
    'title': '[{import_file_code}] [ACID: {acid_number}] توفير صحيفة بيانات سلامة المادة (MSDS) معتمدة ومحدثة',
    'body': 'توفير صحيفة MSDS للصنف لتحديد اشتراطات السلامة والتداول بالميناء والتخزين',
  },
  'REQ_TASK_PERMIT': {
    'title': '[{import_file_code}] [ACID: {acid_number}] استخراج الموافقة الاستيرادية المسبقة ({authority_enum_regulatory_body})',
    'body': 'يجب استخراج إذن/موافقة استيراد رسمية من {authority_enum_regulatory_body} قبل الشحن',
  },
  'REQ_TASK_PERMIT_HS': {
    'title': '[{import_file_code}] [{hs_code}] [ACID: {acid_number}] استخراج الموافقة الاستيرادية المسبقة ({authority_enum_regulatory_body})',
    'body': 'يجب استخراج إذن استيراد للبند {hs_code} من {authority_enum_regulatory_body} قبل الشحن',
  },

  'TASK_AUTO_PHASE_FOLLOW_UP': {
    'title': '{import_file_code} — {task_enum_phase_follow_up_task}',
    'body': 'مهمة توليد آلي من النظام للمتابعة: {task_enum_phase_follow_up_task}',
    'note': 'توليد تلقائي للشحنة {import_file_code}',
  },

  'TR_BOOKING_CONFIRMED': {
    'title': 'تم حجز سيارات النقل الداخلي (TR-01)',
    'body': 'تم حجز الشاحنة {truck_plate_number} لنقل الشحنة {import_file_code} من {pickup_location} إلى {destination_warehouse}. السائق: {driver_name} ({driver_phone}).',
  },
  'TR_TASK_TRACK_ARRIVAL_GRN': {
    'title': 'متابعة وصول الشاحنة للمستودع وإصدار إذن الإضافة GRN (TR-03)',
  },
  'TR_SEAL_BROKEN': {
    'title': 'إبلاغ عن كسر الختم الجمركي للشاحنة {truck_plate_number}',
    'body': 'وصلت الشاحنة {truck_plate_number} بختم جمركي مكسور/تالف ({seal_number}).',
    'note': 'تم الإبلاغ عن كسر الختم الجمركي {seal_number} عند الوصول.',
  },

  'WH_GRN_ISSUED': {
    'title': 'تم إصدار إذن الإضافة المخزني ({grn_code})',
    'body': 'وصلت بضاعة الشحنة {import_file_code} إلى {warehouse_name} وتم إصدار إذن الإضافة {grn_code}.',
    'note': 'تم استلام البضاعة في {warehouse_name} وإصدار إذن الإضافة {grn_code}.',
  },
  'WH_INSPECTION_PROTOCOL_APPROVED': {
    'title': 'محضر فحص المخزن ({protocol_no})',
    'body': 'اعتمدت {committee} محضر الفحص للشحنة {import_file_code}. القرار: {verdict_enum_warehouse_inspection_verdict} (المقبول: {accepted_qty}، العجز: {shortage_qty}، التالف: {damaged_qty}).',
  },
  'WH_INSPECTION_PROTOCOL_APPROVED_CLAIMS': {
    'title': 'محضر فحص المخزن ({protocol_no})',
    'body': 'اعتمدت {committee} محضر الفحص للشحنة {import_file_code}. القرار: {verdict_enum_warehouse_inspection_verdict} (المقبول: {accepted_qty}، العجز: {shortage_qty}، التالف: {damaged_qty}). مطالبة التأمين: {insurance_claim_ref}. إشعار مديونية المورد: {supplier_claim_ref}.',
  },
  'WH_TASK_INSPECTION_DISCREPANCY': {
    'title': 'الفحص الفني ومطابقة العجز والتلف (TR-04) — {grn_code}',
    'body': 'مطابقة كميات إذن الإضافة {grn_code} مع الفاتورة وتسجيل أي عجز أو تلف للشحنة {import_file_code}.',
  },
  'DOC_CHK_ACID_MATCH': {
    'note': 'رقم ACID مطابق تماماً',
  },
  'DOC_CHK_ACID_MISMATCH': {
    'note': 'رقم ACID في الفاتورة يختلف عن رقم ACID المسجل بالسستم!',
  },
  'DOC_CHK_AMOUNT_MATCH': {
    'note': 'القيمة الإجمالية والعملة متطابقة تماماً',
  },
  'DOC_CHK_AMOUNT_VARIANCE': {
    'note': 'فارق القيمة: {variance_amount} {currency} ({variance_pct}%)',
  },
  'DOC_CHK_CBM_MATCH': {
    'note': 'الحجم الإجمالي متطابق',
  },
  'DOC_CHK_CBM_VARIANCE': {
    'note': 'فارق الحجم: {difference_qty} م³ ({difference_pct}%)',
  },
  'DOC_CHK_CURRENCY_MISMATCH': {
    'note': 'اختلاف في العملة: مسجل بالسستم ({system_currency}) والمستخرج بالمستند ({document_currency})',
  },
  'DOC_CHK_GROSS_WEIGHT_MATCH': {
    'note': 'الوزن القائم متطابق',
  },
  'DOC_CHK_GROSS_WEIGHT_VARIANCE': {
    'note': 'فارق الوزن: {difference_qty} كجم ({difference_pct}%)',
  },
  'DOC_CHK_HS_CODE_MATCH': {
    'note': 'البند الجمركي مطابق',
  },
  'DOC_CHK_HS_CODE_MISMATCH': {
    'note': 'البند الجمركي المستخرج ({document_value}) يختلف عن المسجل ({system_value})',
  },
  'DOC_CHK_IMPORTER_MATCH': {
    'note': 'اسم المستورد مطابق',
  },
  'DOC_CHK_IMPORTER_MISMATCH': {
    'note': 'اسم المستورد المستخرج ({document_value}) يختلف عن المسجل ({system_value})',
  },
  'DOC_CHK_INVOICE_NO_MATCH': {
    'note': 'رقم الفاتورة مطابق تماماً لأمر الشراء والمنظومة',
  },
  'DOC_CHK_INVOICE_NO_MISMATCH': {
    'note': 'رقم الفاتورة بالمستند ({document_value}) يختلف عن رقم الفاتورة بالسستم ({system_value})!',
  },
  'DOC_CHK_NET_WEIGHT_MATCH': {
    'note': 'الوزن الصافي متطابق',
  },
  'DOC_CHK_NET_WEIGHT_VARIANCE': {
    'note': 'فارق الوزن الصافي: {difference_qty} كجم ({difference_pct}%)',
  },
  'DOC_CHK_PACKAGES_MATCH': {
    'note': 'عدد الطرود متطابق',
  },
  'DOC_CHK_PACKAGES_VARIANCE': {
    'note': 'فارق عدد الطرود: {difference_count} طرد',
  },
  'DOC_CHK_SUPPLIER_MATCH': {
    'note': 'اسم المورد مطابق',
  },
  'DOC_CHK_SUPPLIER_MISMATCH': {
    'note': 'اسم المورد المستخرج ({document_value}) يختلف عن المسجل بالسستم ({system_value})',
  },
  'DOC_CHK_TAX_ID_MATCH': {
    'note': 'الرقم الضريبي مطابق',
  },
  'DOC_CHK_TAX_ID_MISMATCH': {
    'note': 'اختلاف في الرقم الضريبي للمستورد.',
  },
  'DOC_COO_SIMILARITY': {
    'note': 'نسبة التشابه: {match_pct}%',
  },
  'DOC_COO_VALUE_NOT_FOUND': {
    'note': 'لم يتم العثور على القيمة في مسودة شهادة المنشأ',
  },
  'DOC_DRAFT_APPROVED_VALUE_MISMATCH': {
    'note': 'عدم تطابق! القيمة المعتمدة: \'{system_value}\' | قيمة المسودة: \'{draft_value}\'.',
  },
  'DOC_DRAFT_FIELD_MISSING': {
    'note': 'الحقل مطلوب ولم يتم استخراجه أو إدخاله في بيانات درافت البوليصة.',
  },
  'DOC_DRAFT_FUZZY_MATCH': {
    'note': 'مطابقة ذكية ممتازة بنسبة {match_pct}%.',
  },
  'DOC_DRAFT_NUMERIC_MATCH': {
    'note': 'مطابقة رقمية ممتازة (فرق {diff_pct}% ضمن نسبة السماح {tolerance_pct}%).',
  },
  'DOC_DRAFT_NUMERIC_UNVERIFIABLE': {
    'note': 'تعذر التحقق الرقمي من القيمة: {draft_value}',
  },
  'DOC_DRAFT_NUMERIC_VARIANCE': {
    'note': 'فرق أوزان يتجاوز نسبة السماح ({diff_pct}%). النظام: {system_qty} | الدرافت: {draft_qty}.',
  },
  'DOC_DRAFT_TEXT_MATCH': {
    'note': 'مطابقة نصية تامة 100%.',
  },
  'DOC_DRAFT_VALUE_FROM_DRAFT': {
    'note': 'تم استخراج القيمة من الدرافت ({draft_value}).',
  },
  'DOC_DRAFT_VALUE_MISMATCH': {
    'note': 'عدم تطابق! قيمة النظام: \'{system_value}\' | قيمة الدرافت: \'{draft_value}\'.',
  },
  'DOC_IBL_ACID_MATCH': {
    'note': 'رقم ACID الجمركي مطابق بنسبة 100%',
  },
  'DOC_IBL_ACID_MISMATCH': {
    'note': 'عدم تطابق رقم ACID يمنع الإفراج الجمركي ويوقف الشحنة فوراً.',
  },
  'DOC_IBL_ACID_NOT_EXTRACTED': {
    'note': 'لم يتم استخراج رقم ACID من الفاتورة أو البوليصة.',
  },
  'DOC_IBL_CONSIGNEE_MATCH': {
    'note': 'اسم المستورد متطابق قانونياً',
  },
  'DOC_IBL_CONSIGNEE_MISMATCH': {
    'note': 'اسم المستورد غير متطابق بين الفاتورة والبوليصة.',
  },
  'DOC_IBL_CONSIGNEE_NOT_EXTRACTED': {
    'note': 'تعذر استخراج اسم المستورد/المرسل إليه.',
  },
  'DOC_IBL_CONTAINERS_MATCH': {
    'note': 'أرقام الحاويات مطابقة تماماً',
  },
  'DOC_IBL_CONTAINERS_MISMATCH': {
    'note': 'عدم تطابق في أرقام الحاويات المسجلة بالفاتورة مع البوليصة.',
  },
  'DOC_IBL_GROSS_WEIGHT_EXCEEDS': {
    'note': 'فارق الوزن القائم يتجاوز نسبة التسامح المسموحة جمركياً.',
  },
  'DOC_IBL_GROSS_WEIGHT_MATCH': {
    'note': 'الوزن القائم متطابق وضمن النطاق المسموح به (<= {tolerance_pct}%)',
  },
  'DOC_IBL_INCOTERMS_COHERENT': {
    'note': 'شرط التسليم {incoterm} متوافق مع سداد النولون ({freight_terms})',
  },
  'DOC_IBL_NET_WEIGHT_MATCH': {
    'note': 'الوزن الصافي متطابق',
  },
  'DOC_IBL_NET_WEIGHT_VARIANCE': {
    'note': 'يوجد فارق في الوزن الصافي بين الفاتورة ومسودة البوليصة.',
  },
  'DOC_IBL_PACKAGES_MATCH': {
    'note': 'عدد الطرود والبالتات متطابق تماماً',
  },
  'DOC_IBL_PACKAGES_MISMATCH': {
    'note': 'اختلاف في عدد الطرود أو وحدة التعبئة (كرتونة vs بالتة).',
  },
  'DOC_IBL_SEALS_CHECK': {
    'note': 'يرجى التأكد من رقم الرصاص الملاحي المثبت على الحاوية.',
  },
  'DOC_IBL_SEALS_MATCH': {
    'note': 'أرقام الرصاص الملاحي متطابقة',
  },
  'DOC_IBL_SHIPPER_MATCH': {
    'note': 'اسم المصدر متطابق في الفاتورة وبوليصة الشحن',
  },
  'DOC_IBL_SHIPPER_MISMATCH': {
    'note': 'اختلاف في اسم المصدر أو الشاحن بين الفاتورة والبوليصة.',
  },
  'DOC_IBL_SHIPPER_NOT_EXTRACTED': {
    'note': 'تعذر استخراج اسم الشاحن/المصدر.',
  },
  'DOC_IBL_TAX_ID_MATCH': {
    'note': 'رقم التسجيل الضريبي للمستورد مطابق',
  },
  'DOC_IBL_TAX_ID_MISMATCH': {
    'note': 'عدم تطابق البطاقة الضريبية يمنع مطابقة نافذة ونموذج 4.',
  },
  'DOC_IBL_TAX_ID_NOT_EXTRACTED': {
    'note': 'لم يتم استخراج البطاقة الضريبية للمستورد من المستندات.',
  },
  'DOC_INSPECTION_MATCH_RATE': {
    'note': 'نسبة التطابق: {match_pct}%',
  },
  'DOC_INSPECTION_OPTIONAL_NOT_INCLUDED': {
    'note': 'حقل غير إلزامي لم يتم تضمينه في مسودة الفحص',
  },
  'DOC_INSPECTION_VALUE_NOT_FOUND': {
    'note': 'لم يتم العثور على القيمة في مسودة شهادة الفحص المرفوعة',
  },
  'DOC_TOL_CONTAINERS_EXACT': {
    'note': '0% (مطابقة تامة لأرقام الحاويات)',
  },
  'DOC_TOL_EXACT': {
    'note': '0% (مطابقة حتمية تامة)',
  },
  'DOC_TOL_PACKAGES_EXACT': {
    'note': '0% (مطابقة عدد الطرود)',
  },
  'DOC_TOL_SEAL_MATCH': {
    'note': 'مطابقة رقم الرصاص',
  },
  'DOC_TOL_SIMILARITY': {
    'note': 'نسبة التشابه: {match_pct}%',
  },
  'DOC_TOL_TERMS_COHERENCE': {
    'note': 'توافق الشروط التجارية',
  },
  'DOC_TOL_WEIGHT_DIFFERENCE': {
    'note': 'الفرق: {difference_qty} كجم ({difference_pct}%)',
  },
  'CUSTOMS_FX_RATE_MISSING': {
    'note': 'لا يوجد سعر صرف جمركي للعملة {currency} بتاريخ {on_date}.',
  },
  'IR_ASSESSMENT_EXISTS': {
    'note': 'يوجد بالفعل تقييم متطلبات استيرادية نشط ({assessment_code}) لهذا الملف الاستيرادي.',
  },
  'OVER_SHIPPED': {
    'note': 'شحنة زائدة: تم شحن {shipped_qty} مقابل {ordered_qty} مطلوبة في أمر الشراء {po_number} البند {item_code}',
  },
  'PO_PL_DIMENSIONS_MISSING': {
    'note': 'البند رقم {line_num} ({item_code}): أبعاد الطرد غير مسجلة أو صفر؛ لا يمكن حساب الحجم (CBM) بدقة.',
  },
  'PO_PL_GROSS_BELOW_NET': {
    'note': 'البند رقم {line_num} ({item_code}): الوزن القائم للوحدة ({gross_qty} كجم) لا يمكن أن يقل عن الوزن الصافي ({net_qty} كجم).',
  },
  'PO_PL_HS_MISSING_IN_INVOICE': {
    'note': 'البند الجمركي \'{hs_code}\' موجود في قائمة التعبئة وغير موجود في الفاتورة التجارية.',
  },
  'PO_PL_HS_MISSING_IN_PACKING': {
    'note': 'البند الجمركي \'{hs_code}\' موجود في الفاتورة التجارية وغير موجود في قائمة التعبئة.',
  },
  'PO_PL_HS_QTY_MISMATCH': {
    'note': 'البند الجمركي \'{hs_code}\': كمية قائمة التعبئة ({packing_qty}) تختلف عن كمية الفاتورة ({invoice_qty}) [الفرق: {signed_difference}].',
  },
  'PO_PL_NEGATIVE_WEIGHT': {
    'note': 'البند رقم {line_num} ({item_code}): أوزان الوحدة لا يمكن أن تكون سالبة.',
  },
  'PO_PL_NO_ITEMS': {
    'note': 'لا توجد بنود قائمة تعبئة مسجلة لأمر الشراء هذا.',
  },
  'PO_PL_TOTAL_QTY_MISMATCH': {
    'note': 'عدم تطابق الكمية الإجمالية: إجمالي قطع قائمة التعبئة ({packing_qty}) يختلف عن إجمالي قطع الفاتورة ({invoice_qty}) [الفرق: {signed_difference}].',
  },
  'PREFILL_LINE_NO_HS': {
    'note': 'أمر الشراء {po_number} البند {item_code} بدون بند جمركي (HS Code) وتم تخطيه.',
  },
  'PREFILL_NO_HS': {
    'note': 'لم يتم العثور على بند جمركي (HS Code) للملف الاستيرادي {import_file_code}: أضف البند الجمركي في بنود أمر الشراء أو في الدراسة.',
  },
  'PO_ITEMS_ALLOCATED': {
    'note': 'بنود أمر الشراء {item_ids} لها شحنات مسجلة ولا يمكن حذفها؛ أرسل رقم البند (item_id) لتعديلها.',
  },
  'PO_NUMBER_TAKEN': {
    'note': 'رقم أمر الشراء {po_number} مستخدم بالفعل، يرجى إعادة المحاولة.',
  },
  'SCENARIO_SESSION_EXISTS': {
    'note': 'توجد بالفعل دراسة سيناريوهات شحن نشطة ({session_code}) لهذا الملف الاستيرادي.',
  },
  'CONSULTATION_EXISTS': {
    'note': 'توجد بالفعل دراسة جمركية نشطة ({consultation_code}) لهذا الملف الاستيرادي.',
  },
  'CUSTOMS_MIXED_CURRENCY': {
    'note': 'أوامر الشراء في هذا الملف الاستيرادي بعملات مختلفة ({currencies}): إعادة الاحتساب تحتاج عملة واحدة لكل جانب.',
  },
  'FA_FX_RATE_MISSING': {
    'note': 'لا يوجد سعر صرف مسجل للعملة {currency_code}. أضفه من شاشة العملات.',
  },
  'FA_CURRENCY_MISSING': {
    'note': 'لا توجد عملة مسجلة لمبلغ {source}. حدد العملة أولاً.',
  },
  'FA_SWIFT_CURRENCY_MISMATCH': {
    'note': 'عملة السويفت {swift_currency} لا تطابق عملة طلب الدفع {currency_code}.',
  },
  'FA_SWIFT_REF_ALREADY_USED': {
    'note': 'مرجع السويفت {swift_ref} مستخدم بالفعل في طلب الدفع {payment_code}.',
  },
  'FA_SWIFT_BATCH_ALREADY_RECONCILED': {
    'note': 'دفعة السويفت {batch_code} تمت مطابقتها بالفعل مع طلب الدفع {payment_code}.',
  },
  'FA_SWIFT_BATCH_STATUS_INVALID': {
    'note': 'هذا الإجراء غير مسموح على دفعة السويفت {batch_code} وهي في حالة {status}.',
  },
  'FA_PAYMENT_STATUS_INVALID': {
    'note': 'طلب الدفع {payment_code} في حالة {status}: الإجراء {action} غير مسموح.',
  },
  'FA_PAYMENT_LOCKED': {
    'note': 'لا يمكن تعديل أو حذف طلب دفع معتمد أو مدفوع ({payment_code}، {status}).',
  },
  'FA_BUDGET_LOCKED': {
    'note': 'لا يمكن تعديل موازنة معتمدة أو تم استبدالها ({budget_code}، {status}): قم بمزامنتها لإنشاء مراجعة جديدة.',
  },
  'FA_BUDGET_STATUS_INVALID': {
    'note': 'لا يمكن اعتماد الموازنة {budget_code} وهي في حالة {status}.',
  },
  'FA_PAYMENT_DUPLICATE_TYPE': {
    'note': 'يوجد بالفعل طلب دفع مفتوح من نوع {payment_type} لهذا الملف ({payment_code}).',
  },
  'FA_BUDGET_DUPLICATE_FILE': {
    'note': 'توجد بالفعل موازنة للملف الاستيرادي {import_file_code}. عدّلها بدلاً من إنشاء موازنة جديدة.',
  },
  'FA_BUDGET_HARD_BLOCK': {
    'note': 'انحراف التكلفة بنسبة {variance_percentage}% في {field_name} يتجاوز الحد المسموح (حظر إلزامي): قم بمزامنة التكاليف أو اكتب مبرراً مكتوباً.',
  },
  'FA_BUDGET_SOD_DENIED': {
    'note': 'فصل المهام: المستخدم الذي عدّل التكاليف المصدرية لا يمكنه مزامنة الموازنة المعتمدة.',
  },
  'FA_BUDGET_SYNC_REVISION_CREATED': {
    'note': 'تم إنشاء مراجعة الموازنة {budget_code}، وتمت أرشفة النسخة المعتمدة كنسخة مستبدلة.',
  },
  'FA_BUDGET_SYNC_DONE': {
    'note': 'تمت مزامنة الموازنة {budget_code} مع التكاليف الفعلية؛ الحالة {status}.',
  },
  'FA_SWIFT_BATCH_CONFIRMED': {
    'note': 'تم تأكيد بيانات السويفت للدفعة {batch_code}؛ وأصبحت المطابقة متاحة.',
  },
  'FA_SWIFT_FILE_TOO_LARGE': {
    'note': 'حجم ملف السويفت يتجاوز الحد المسموح ({max_mb} ميجابايت).',
  },
  'FA_SWIFT_FILE_INVALID_BASE64': {
    'note': 'محتوى الملف المرفوع ليس بصيغة Base64 صحيحة.',
  },
  'FA_CODE_GENERATION_CONFLICT': {
    'note': 'الرقم المرجعي {reference_code} مستخدم بالفعل. يرجى إعادة المحاولة.',
  },
  'DOC_ACID_TRACKER_STATUS': {
    'note': 'حالة ACID: {status} (متبقي {days} يوم).',
  },
  'DOC_LEGAL_DOC_EXPIRED': {
    'note': '{doc_kind} رقم {doc_number} انتهت صلاحيته بتاريخ {expiry_date}: الشحن والإفراج الجمركي محظوران.',
  },
  'DOC_LEGAL_DOC_CRITICAL_BREACH': {
    'note': '{doc_kind} رقم {doc_number} تنتهي صلاحيته بتاريخ {expiry_date}، أي قبل أقل من 30 يوماً من تاريخ الوصول المتوقع {eta_date}.',
  },
  'DOC_LEGAL_DOC_EXPIRING_SOON': {
    'note': '{doc_kind} رقم {doc_number} تنتهي صلاحيته بتاريخ {expiry_date} (متبقي {days} يوم).',
  },
  'DOC_LEGAL_DOC_VALID': {
    'note': '{doc_kind} رقم {doc_number} ساري حتى {expiry_date}.',
  },
  'DOC_LEGAL_ACID_MISSING': {
    'note': 'لم يتم تسجيل تاريخ صلاحية ACID لهذه الشحنة بعد.',
  },
  'DOC_LEGAL_BANNER': {
    'note': 'تحذير حرج لسلامة الشحنة (تاريخ الوصول المتوقع + هامش 30 يوماً): يوجد عدد {critical_count} مستند يحتاج إلى إجراء.',
  },
  'DOC_INVOICE_BL_SYNCED': {
    'note': 'تمت مطابقة واعتماد الفاتورة {invoice_number} وبوليصة الشحن {draft_bl_number} ومزامنتهما مع الملف الاستيرادي والموافقات الجمركية.',
  },
  'ODC_COURIER_NOT_FOUND': {
    'note': 'شحنة البريد السريع {courier_no} غير مسجلة في جلسة المستندات الأصلية لهذا الملف. أضفها إلى الجلسة أولاً.',
  },
  'ODC_SESSION_NOT_FOUND': {
    'note': 'لا توجد جلسة تجميع مستندات أصلية للملف الاستيرادي {import_file_id}.',
  },
  'DCA_SESSION_FINAL_LOCKED': {
    'note': 'جلسة الاعتماد الجمركي {session_code} تم اعتمادها نهائياً ولا يمكن تعديلها.',
  },
  'DCA_SESSION_NOT_READY': {
    'note': 'لا يمكن اعتماد الجلسة: لم يتم تحديد حالات المستندات ({missing_statuses})؛ عدد تذاكر التصحيح المفتوحة: {open_tickets_count}.',
  },
  'DCA_TICKET_CLOSED': {
    'note': 'تذكرة التصحيح {ticket_code} مغلقة بالفعل ({status}).',
  },
  'DCA_SAME_REVIEWER': {
    'note': '{reviewer} قام بالفعل بالتوقيع على مستوى المراجعة الآخر في {approval_code}: المراجعة التجارية والمراجعة الجمركية تتطلبان مستخدمين مختلفين.',
  },
  'SDU_ACID_INVALID': {
    'note': 'رقم ACID المستخرج {acid_number} غير صحيح: يجب أن يتكون من 19 رقماً.',
  },
  'SDU_ACID_CONFLICT': {
    'note': 'رقم ACID المستخرج {acid_number} يختلف عن الرقم المسجل في الملف {import_file_code} ({current_acid_number}).',
  },
  'SDU_FILE_CLOSED': {
    'note': 'الملف الاستيرادي {import_file_code} في حالة {status}: لا يمكن تطبيق البيانات المستخرجة عليه.',
  },
  'SDU_INVOICE_APPLIED': {
    'note': 'تم تطبيق بيانات الفاتورة {invoice_no} على الملف {import_file_code}.',
  },
  'SDU_BL_APPLIED': {
    'note': 'تم تطبيق بيانات بوليصة الشحن على الشحنة {cargo_shipping_code} (عدد الحاويات: {containers_applied}).',
  },
  'SDU_EXTRACTED_ONLY': {
    'note': 'تم استخراج البيانات وهي جاهزة للاستخدام في ملف جديد.',
  },
  'SDU_NO_SHIPPING_RECORD': {
    'note': 'الملف الاستيرادي {import_file_code} ليس له سجل شحن نشط: أنشئه قبل تطبيق بيانات بوليصة الشحن.',
  },
  'XCHK_ACID_MISMATCH': {
    'note': 'عدم تطابق رقم ACID بين الفاتورة التجارية وبوليصة الشحن',
  },
  'XCHK_TAX_ID_MISMATCH': {
    'note': 'عدم تطابق الرقم الضريبي للمستورد المصري بين الفاتورة وبوليصة الشحن',
  },
  'XCHK_SHIPPER_MISMATCH': {
    'note': 'اسم الشاحن / المصدّر مختلف (نسبة التشابه {similarity_pct}%)',
  },
  'XCHK_CONSIGNEE_MISMATCH': {
    'note': 'اسم المستلم / المستورد مختلف (نسبة التشابه {similarity_pct}%)',
  },
  'XCHK_WEIGHT_OVER': {
    'note': 'فرق الوزن القائم {diff_kg} كجم ({variance_pct}%) يتجاوز الحد المسموح ({tolerance_pct}%)',
  },
  'XCHK_WEIGHT_MINOR': {
    'note': 'فرق بسيط في الوزن القائم قدره {diff_kg} كجم ({variance_pct}%) ضمن الحد المقبول',
  },
  'XCHK_PORTS_MISMATCH': {
    'note': 'ميناء الشحن أو ميناء التفريغ غير متطابق بالكامل',
  },
  'XCHK_INCOTERM_PREPAID_CONFLICT': {
    'note': 'تعارض في شروط الشحن: شرط الفاتورة {incoterm} بينما بوليصة الشحن نولون مدفوع مقدماً (Freight Prepaid)',
  },
  'XCHK_INCOTERM_COLLECT_CONFLICT': {
    'note': 'تعارض في شروط الشحن: شرط الفاتورة {incoterm} يشمل النولون بينما بوليصة الشحن نولون عند الوصول (Freight Collect)',
  },
  'XCHK_PACKAGES_MISMATCH': {
    'note': 'عدد الطرود مختلف بين الفاتورة ({invoice_packages}) وبوليصة الشحن ({bl_packages})',
  },
  'DD_SETTLEMENT_STALE': {
    'note': 'تمت إعادة احتساب غرامات التأخير للتتبع {tracking_code} لكن تسوية تكلفة الوصول الخاصة به مقفلة؛ لم يتم إعادة ترحيلها.',
  },
  'CC_RELEASE_RECORD_FILE_MISMATCH': {
    'note': 'سجل التخليص {clearance_id} لا يتبع الملف الاستيرادي {import_file_id}.',
  },
  'CC_DUTY_NOT_ASSESSED': {
    'note': 'لا يمكن تسجيل سداد الرسوم الجمركية قبل التقدير النهائي للرسوم (CL-02).',
  },
  'CC_DUTY_UNDERPAID': {
    'note': 'المبلغ المسدد {paid_amount} جنيه أقل من الرسوم الجمركية المقدرة {assessed_amount} جنيه.',
  },
  'CC_DUTY_NOT_PAID': {
    'note': 'لا يمكن إصدار الإفراج النهائي قبل سداد الرسوم الجمركية (CL-03).',
  },
  'CC_DUTY_PAID_AMOUNT_REQUIRED': {
    'note': 'مبلغ الرسوم الجمركية المسدد مطلوب ويجب أن يكون أكبر من صفر.',
  },
  'CC_ASSESS_REQUIRES_DECLARATION_46': {
    'note': 'لا يمكن تقدير الرسوم النهائية قبل تسجيل الإقرار الجمركي 46 (CS-03).',
  },
  'CC_UPDATE_NULL_NOT_ALLOWED': {
    'note': 'لا يمكن مسح هذه الحقول: {fields}.',
  },
  'CC_RESTORE_DUPLICATE_ACTIVE': {
    'note': 'لا يمكن الاستعادة: يوجد سجل تخليص نشط آخر ({clearance_code}) لهذا الملف.',
  },
  'CC_UNDER_BOND_NOT_ALLOWED': {
    'note': 'تم رفض الإفراج تحت الضمان: الشحنة مفرج عنها تحت الضمان بالفعل أو تم الإفراج النهائي عنها ({clearance_status}).',
  },
  'CC_INVOICE_FX_RATE_REQUIRED': {
    'note': 'سعر الصرف مطلوب للفاتورة بعملة {currency}.',
  },
  'CC_INVOICE_RECORD_FILE_MISMATCH': {
    'note': 'سجل التخليص {customs_clearance_id} لا يتبع الملف الاستيرادي {import_file_id}.',
  },
  'CC_ACID_EXPIRY_INVALID': {
    'note': 'تاريخ انتهاء ACID المسجل في الملف الاستيرادي {import_file_id} غير صحيح.',
  },
  'CC_REFERENCE_CODE_CONFLICT': {
    'note': 'تعذر إنشاء رقم مرجعي فريد بسبب عمليات حفظ متزامنة؛ يرجى إعادة المحاولة.',
  },
  'CC_RELEASE_QUARANTINE_LOCKED': {
    'note': 'لا يمكن إصدار الإفراج النهائي طالما {clearance_code} تحت قفل الحجر المعملي.',
  },
  'CC_LAB_RESULT_ALREADY_FINAL': {
    'note': 'تم تسجيل نتيجة المعمل ورفع الحجر بالفعل، أو تم الإفراج النهائي عن الشحنة ({clearance_status}).',
  },
  'CC_ASSESSED_COMPONENTS_LOCKED': {
    'note': 'لا يمكن تعديل مكونات الرسوم بعد التقدير ({fields})؛ أعد تقدير الرسوم النهائية (CL-02).',
  },
  'CC_SETTLEMENT_LOCKED': {
    'note': 'لا يمكن تعديل فواتير التخليص بعد اعتماد تسوية تكلفة الوصول ({settlement_code}).',
  },
  'CCQ_RFQ_STATUS_INVALID': {
    'note': 'حالة طلب عروض الأسعار \'{status}\' غير مسموحة؛ الترسية تتم من خلال إجراء الترسية فقط.',
  },
  'CCQ_RFQ_CANCELLED': {
    'note': 'طلب عروض الأسعار {rfq_code} ملغي ولا يمكن ترسيته.',
  },
  'CCQ_QUOTE_EXPIRED': {
    'note': 'انتهت صلاحية عرض السعر بتاريخ {validity_date}.',
  },
  'CCQ_AWARDED_QUOTE_DELETE': {
    'note': 'لا يمكن حذف عرض السعر الذي تمت ترسيته.',
  },
  'CCQ_PRICE_LIST_DATE_RANGE': {
    'note': 'بداية الصلاحية {effective_from} بعد نهايتها {effective_to}.',
  },
  'WR_GRN_EXISTS': {
    'note': 'يوجد بالفعل إذن إضافة مخزنية (GRN) نشط ({grn_code}) لهذا الملف الاستيرادي.',
  },
  'WR_GRN_LINE_UNBALANCED': {
    'note': 'البند {item_code}: المقبول {accepted_qty} + العجز {shortage_qty} + التالف {damaged_qty} يجب أن يساوي الكمية المفوترة {invoiced_qty}.',
  },
  'WR_VERDICT_INVALID': {
    'note': 'قرار الفحص \'{verdict}\' غير معروف.',
  },
  'WR_VERDICT_INCONSISTENT': {
    'note': 'لا يمكن قبول الشحنة بالكامل مع وجود عجز {shortage_qty} وتالف {damaged_qty}.',
  },
  'WR_VERDICT_INCONSISTENT_EXPECTED': {
    'note': 'قرار الفحص {verdict} لا يتوافق مع نتيجة الفحص (المتوقع {expected_verdict}).',
  },
  'WR_STATUS_INVALID': {
    'note': 'حالة إذن الإضافة المخزنية \'{status}\' غير معروفة.',
  },
  'WR_DISCREPANCY_TYPE_INVALID': {
    'note': 'نوع الفرق \'{discrepancy_type}\' غير معروف.',
  },
  'WR_CLAIM_CURRENCY_INVALID': {
    'note': 'رمز عملة المطالبة \'{currency_code}\' غير صالح أو غير نشط.',
  },
  'WR_FIELD_NOT_EDITABLE': {
    'note': 'لا يمكن تعديل الحقل \'{field_name}\' مباشرة.',
  },
  'WR_STATUS_CHANGE_NOT_ALLOWED': {
    'note': 'لا يمكن تغيير حالة إذن الاستلام من \'{current_status}\' إلى \'{target_status}\'.',
  },
  'WR_CUSTOMS_NOT_RELEASED': {
    'note': 'لا يمكن إنشاء إذن استلام للملف {import_file_code}: يلزم وجود إفراج جمركي أو إذن إفراج تحت التحفظ.',
  },
  'WR_GRN_LOCKED': {
    'note': 'إذن الاستلام {grn_code} مقفل (محضر فحص معتمد أو مطالبات أو حظر جمركي نشط) ولا يمكن حذفه.',
  },
  'WR_DATE_IN_FUTURE': {
    'note': 'تاريخ الفحص لا يمكن أن يكون في المستقبل (أكثر من 24 ساعة).',
  },
  'IT_BOOKING_EXISTS': {
    'note': 'يوجد بالفعل حجز نقل داخلي نشط ({transport_code}) لبوليصة النقل {waybill_number} في هذا الملف.',
  },
  'IT_CARRIER_INVALID': {
    'note': 'شركة النقل رقم {carrier_id} غير موجودة أو غير نشطة.',
  },
  'IT_TRUCK_TYPE_INVALID': {
    'note': 'نوع الشاحنة \'{truck_type}\' غير صالح.',
  },
  'IT_SEAL_REQUIRED': {
    'note': 'رقم الختم مطلوب عند الإبلاغ عن كسر أو تلف الختم.',
  },
  'IT_DATE_IN_FUTURE': {
    'note': 'موعد {field_name} لا يمكن أن يكون في المستقبل بأكثر من 24 ساعة.',
  },
  'IT_STATUS_INVALID': {
    'note': 'حالة النقل الداخلي \'{status}\' غير معروفة.',
  },
  'IT_TRANSITION_NOT_ALLOWED': {
    'note': 'لا يمكن تسجيل {action} بينما الحجز في حالة \'{current_status}\'.',
  },
  'FC_ALREADY_CLOSED': {
    'note': 'الملف الاستيرادي {import_file_code} مغلق بالفعل. أعد فتحه أولاً.',
  },
  'LIST_SORT_FIELD_INVALID': {
    'note': 'حقل الترتيب \'{field}\' غير معروف. الحقول المسموح بها: {allowed}.',
  },
  'CURRENCY_NOT_FOUND': {
    'note': 'العملة الكود \'{currency}\' غير مسجلة في النظام.',
  },
  'CURRENCY_RATE_MISSING': {
    'note': 'لا يوجد سعر صرف مسجل للعملة \'{currency}\' من نوع \'{rate_type}\' بتاريخ {as_of_date}.',
  },
  'CT_CUSTOMS_RATE_MISSING': {
    'note': 'لا يوجد سعر صرف جمركي مسجل للعملة \'{currency}\' بتاريخ {on_date}.',
  },
  'CT_AGREEMENT_DATA_INVALID': {
    'note': 'بيانات اتفاقية التجارة التفضيلية غير صحيحة ({reason}).',
  },
  'IMPORT_FILE_CLOSED': {
    'note': 'ملف الشحنة {import_file_code} مغلق نهائياً ولا يمكن تعديل بياناته. يلزم إعادة فتحه أولاً.',
  },
  'FC_CLOSURE_BLOCKED': {
    'note': 'لا يمكن إغلاق الملف: الشروط التالية غير مستوفاة: {blocking}.',
  },
  'FC_EXPORT_BLOCKED': {
    'note': 'لا يمكن تصدير واعتماد الملف الشامل: الشروط التالية غير مستوفاة: {blocking}.',
  },
  'FC_CLOSED_RECORD_LOCKED': {
    'note': 'سجل الإغلاق {closure_code} يتبع ملفاً مغلقاً: أعد فتح الملف أولاً.',
  },
  'FC_CLOSURE_EXISTS': {
    'note': 'لا يمكن الاستعادة: يوجد سجل إغلاق نشط آخر ({closure_code}) لهذا الملف.',
  },
  'FC_STATUS_INVALID': {
    'note': 'يمكن إعادة سجل الإغلاق إلى حالة مسودة فقط.',
  },
  'CURRENCY_CODE_UNKNOWN': {
    'note': 'رمز العملة غير معروف أو غير نشط \'{currency_code}\'.',
  },
  'SETTLEMENT_FX_RATE_MISSING': {
    'note': 'لا يوجد سعر صرف للعملة {currency} بتاريخ {on_date}. سجّل السعر قبل احتساب التسوية.',
  },
  'SETTLEMENT_NOT_EDITABLE': {
    'note': 'التسوية {settlement_code} في حالة {status} ولا يمكن تعديلها أو إعادة احتسابها.',
  },
  'SETTLEMENT_COST_ALREADY_APPROVED': {
    'note': 'تكلفة الوصول الفعلية للملف الاستيرادي {import_file_code} معتمدة بالفعل ({status}).',
  },
  'SETTLEMENT_DUPLICATE_ACTIVE': {
    'note': 'لا يمكن الاستعادة: توجد تسوية نشطة أخرى ({settlement_code}) لهذا الملف الاستيرادي.',
  },
  'INVOICES_ALREADY_SETTLED': {
    'note': 'فواتير الملف {import_file_code} تمت تسويتها بالفعل ({status}).',
  },
  'JOURNAL_UNBALANCED': {
    'note': 'قيد اليومية غير متوازن بفارق {difference} جنيه ولا يمكن تصديره.',
  },
  'SETTLEMENT_LINE_NO_HS': {
    'note': 'البند {item_code} ليس له بند جمركي (HS Code): تم استبعاده من التقدير الجمركي.',
  },
  'SETTLEMENT_LINE_ZERO_VALUE': {
    'note': 'البند {item_code} ليس له قيمة: تم استبعاده من التقدير الجمركي.',
  },
  'SETTLEMENT_PO_NOT_ALLOCATED': {
    'note': 'أمر الشراء {po_number} مخصص لشحنات أخرى وليس له حصة في هذا الملف.',
  },
  'PAYMENT_STATUS_UNKNOWN': {
    'note': 'الفاتورة {invoice_no} مسددة جزئياً لكن المبلغ المسدد غير معروف: تم احتسابها كغير مسددة.',
  },
  'ESTIMATE_UNAVAILABLE': {
    'note': 'تكلفة الوصول التقديرية غير متاحة ({reason})؛ يتم احتساب الانحرافات مقابل صفر.',
  },
  'SETTLEMENT_UNPAID_INVOICE': {
    'note': 'رصيد غير مسدد لـ {party_name}: {amount} جنيه (الفاتورة {invoice_no}).',
  },
  'WHT_RATE_MISSING_WARNING': {
    'note': 'لا توجد نسبة ضريبة خصم من المنبع ({tax_code}) سارية بتاريخ {on_date}: لا يوجد خصم على الفاتورة {invoice_no}.',
  },
  'WHT_RATE_NOT_CONFIGURED': {
    'note': 'لا توجد نسبة ضريبة خصم من المنبع ({tax_code}) سارية بتاريخ {on_date} لفاتورة التخليص {invoice_code}: قم بضبط النسبة أو أدخل المبلغ المخصوم في الفاتورة.',
  },
  'RECALC_NO_VARIANCE': {
    'note': 'لا توجد انحرافات: جميع التكاليف مطابقة للمصادر الحية.',
  },
  'RECALC_SOFT_VARIANCE': {
    'note': 'تم رصد انحرافات في التكلفة أقل من {threshold}%. يمكنك المزامنة مع تحذير.',
  },
  'RECALC_HARD_BLOCK': {
    'note': 'تم رصد انحراف أعلى من {threshold}%. يلزم تقديم مبرر مكتوب.',
  },
  'RECALC_APPLIED': {
    'note': 'تم تطبيق إعادة الاحتساب ({action_taken}).',
  },
  'RECALC_RATE_MISSING': {
    'note': 'تعذرت مقارنة بعض البنود: لا يوجد سعر صرف لعملتها ({fields}).',
  },
  'CT_SIMULATION_NO_LINES': {
    'note': 'لا توجد أصناف بها بند جمركي وقيمة لاحتساب الرسوم التقديرية.',
  },
  'CT_SIMULATION_NO_BROKER': {
    'note': 'لا يوجد مخلص جمركي معين لملف الاستيراد؛ لم يتم إنشاء جلسة استشارة جمركية.',
  },
};
