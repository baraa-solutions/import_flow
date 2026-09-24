# مركز إدارة التحديثات والنسخ الاحتياطي (Production Sync Hub)
![](../screenshots/57-production-sync-main.png)

> التصوير اتعمل على **Flutter Web (release)**. على الويب الشاشة بتستخدم `LocalProcessSyncServiceWebImpl` بدل تنفيذ الديسكتوب (`dart:io` و Process)، وكل حاجة بتعدّي على الـ API. وأي فرق سببه الويب متعلّم عليه تحت.
>
> **تنبيه عن التصوير:** الـ harness ملقاش زرار "إضافة"، فضغط "إنشاء نقطة استرجاع فورية" مرتين. الصورتين `57-production-sync-dialog-add.png` و `57-production-sync-dialog-add-validation.png` **مش dialogs**، دول نتيجة الضغطتين: اتعملت نسختين حقيقيتين `sorour_logistics_manual_dev_20260924_130504.db` و `..._130507.db` في مجلد `backups/` في جذر الـ worktree، ومصدرهم `sorour_logistics.db` الحقيقية في الجذر، **مش** القاعدة الـ scratch (راجع أول ملاحظة). النسخ دي قراءة بس، والقاعدة الحقيقية ما اتعدّلتش (تاريخ آخر تعديل ليها 05:12). بس الباك إند بيحتفظ بأحدث 50 نسخة بس، فممكن يكون مسح نسخ قديمة من `backups/`.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** إدارة إصدار النظام وقاعدة البيانات:
  - **تاب 1 (إدارة التحديثات ونقاط الاسترجاع):** يعرض الإصدار (v2.0.3 Build 205)، ويفحص التحديثات وينزّل المثبّت، ويعمل نقطة استرجاع فورية، ويعرض أرشيف النسخ الاحتياطية مع استعادة أي نسخة.
  - **تاب 2 (أدوات المطور والمقارنة المباشرة):** مقارنة قاعدة التطوير بقاعدة الإنتاج، والمزامنة للإنتاج، وسحب الإنتاج للتطوير، وبناء وتجميع الإنتاج، وسجل تنفيذ مباشر (console).
- **المستخدمين:** مسؤول النظام والمطوّر.
- **المرحلة:** إدارة نظام. مالهاش BP/MD.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "مركز مزامنة وتحديث الإنتاج" (index 59). وكمان من dialog معلومات الإصدار ← `ProductionSyncHubDialog`.
- **Scaffold:** `Scaffold` بهيدر مخصص وتحته TabBar أفقي بتابين.
- **الصلاحية:** الـ router `Depends(get_current_user)`. و `compare` و `sync-to-prod` و `pull-to-dev` و `backup` و `backups` و `restore` كلها `require_admin` (`modules/production_sync/router.py:66-139`). أما `version-info` و `check-updates` فمفتوحين لأي مستخدم مسجّل.
- **عند الفتح:** بيعمل invalidate للإصدار والنسخ، ويعمل مقارنة صامتة، وفحص تحديثات (`production_sync_screen.dart:40-56`).

## مكونات الشاشة

- **شريط الإصدار (فوق التابين):** شارة `v2.0.3 (Build 205)` بزرار نسخ، ورسالة الحالة "النظام محدث ومستقر بأحدث إصدار مثبت." بعلامة صح خضرا، وزرار "فحص التحديثات".
- **كارت "محرك الترقية التراكمي الآمن لهيكل البيانات"** (تاب 1): أيقونة درع ووصف إن النظام بياخد نقطة أمان تلقائي قبل كل ترقية، وجنبه زرار "إنشاء نقطة استرجاع فورية".
- **كونسول تاب 2:** عنوان "سجل التنفيذ المباشر للأوامر" وأيقونتين (نسخ السجل، ومسح الشاشة).

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث في الجداول... (تاب 2) | TextField | لا | — | فلترة محلية لنتيجة المقارنة |
| فلاتر النتيجة: توجد تعديلات فقط / جميع الجداول (109) / متطابقة | Chips | — | — | نتيجة `GET /production-sync/compare` |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| أيقونات الهيدر: تصدير جدول نصوص، تصدير إكسيل، تقرير تشخيصي PDF، نسخ التقرير الشامل (`production_sync_screen.dart:251-310`) | تصدير فروقات الجداول أو النسخ، وتقرير تشخيصي | — | الكل |
| تحديث حالة النظام (🔄) | `_refreshLocalData` | `GET /version-info`، و `GET /backups` | ADMIN لقائمة النسخ |
| العودة للداش بورد | index 0 | — | الكل |
| فحص التحديثات | فحص إصدار أحدث | `GET /api/v1/production-sync/check-updates` | أي مستخدم |
| تنزيل وتثبيت الآن / تشغيل المثبّت / إلغاء | تنزيل المثبّت وتشغيله. **ديسكتوب بس** (`:522-580`)، وفيه dialog تأكيد (`:734`) | `GET /installer-info` | — |
| إنشاء نقطة استرجاع فورية | نسخة من قاعدة التطوير. **فيه loading** (`_isRunning`، `:856-857`) | `POST /api/v1/production-sync/backup?target=dev` | ADMIN |
| أرشيف النسخ: تصدير TSV / CSV / تحديث القائمة | `saveBackupsTsvToFile/CsvToFile` (`:897-912`) | — | الكل |
| استعادة (في كل صف) | dialog تأكيد (`:103-136`)، وبعدها استعادة. الهدف بيتحدد من الـ tag: لو فيه `dev` يبقى dev، غير كده **prod** (`:140`) | `POST /api/v1/production-sync/restore` | ADMIN |
| مزامنة لقاعدة الإنتاج (تاب 2) | نسخة أمان للاتنين، وبعدها ترقية غير هدّامة من dev لـ prod (`:1080-1095`) | `POST /api/v1/production-sync/sync-to-prod` | ADMIN |
| فحص ومقارنة الجداول / فحص التغيرات الآن | مقارنة عدد الصفوف والأعمدة | `GET /api/v1/production-sync/compare` | ADMIN |
| سحب الإنتاج للتطوير | بيكتب بيانات prod فوق dev (`preserve_target_user_data=False`، `service.py:495`) | `POST /api/v1/production-sync/pull-to-dev` | ADMIN |
| بناء وتجميع الإنتاج بالكامل | `fullBuildAndSync`. على الديسكتوب بيشغّل build محلي (`:1150-1170`) | ديسكتوب: Process، ويب: API | ADMIN |
| نسخ ملخص الصف / نسخ السجل / مسح الشاشة | حافظة و console | — | الكل |

### الجداول
- **أرشيف النسخ الاحتياطية** (تاب 1): اسم الملف، وتاريخ الإنشاء، والحجم (KB)، والنوع (نسخة يدوية / ترقية تلقائية آمنة)، و Badge البيئة (التطوير / الإنتاج / backup)، ونسخ، واستعادة. الترتيب: الأحدث الأول. العنوان بيوضح العدد "(50 نسخة محفوظة)".
- **التغيرات الجاهزة للتحديث** (تاب 2): اسم الجدول، و Dev: N ← Prod: M، والفرق (مثلاً "-1 في بيئة الإنتاج")، ونسخ.
- **كروت القاعدتين:** المسار، والحجم، وآخر تعديل.

### التابات
**تاب 1: إدارة التحديثات ونقاط الاسترجاع** (نفس الصورة الرئيسية):

![](../screenshots/57-production-sync-tab-1-updates-safety-backups.png)

وقت الفتح الأرشيف بيقول "(0 نسخة محفوظة)" و"لا توجد نسخ احتياطية سابقة في المجلد المخصص"، مع إن فيه 50 نسخة (ظهروا بعد أول عملية، زي ما باين في الصورتين اللي بعد الضغط).

**تاب 2: أدوات المطور والمقارنة المباشرة:**

![](../screenshots/57-production-sync-tab-2-dev-tools-live-diff.png)

فيه كارت قاعدة التطوير وكارت قاعدة الإنتاج، و4 أزرار عمليات، وجدول الفروقات (هنا `_test_sync_tbl`: Dev 0 / Prod 1)، والـ console: "إجمالي الجداول (109) | متطابقة (108) | بحاجة لتحديث (1)".

### الـ Dialogs
- **تأكيد الاستعادة** (`:103-136`) و **تأكيد تنزيل التحديث** (`:734-798`). **ما اتصورش** أي واحد فيهم.
- الصورتين دول **مش dialogs**. دول الشاشة بعد "إنشاء نقطة استرجاع فورية" مرة ومرتين (SnackBar أخضر: "اكتملت عملية [إنشاء نقطة استرجاع فورية] بنجاح!"):

![](../screenshots/57-production-sync-dialog-add.png)

![](../screenshots/57-production-sync-dialog-add-validation.png)

### فرق المنصة (مش ملاحظة)
التحديث الذاتي (تنزيل المثبّت وتشغيله وقفل التطبيق)، والعمليات المحلية (Process و `dart:io`)، و"بناء وتجميع الإنتاج" المحلي كلها ديسكتوب بس (`production_sync_screen.dart:522-580`). على الويب بتتحول لنداءات API عن طريق `local_process_sync_web.dart`.

### التصدير والطباعة
TSV و CSV لفروقات الجداول وللنسخ الاحتياطية (`ProductionSyncExportService.saveTableDiff*` و `saveBackups*`، عن طريق `FileSaveHelper.saveText`)، و PDF تشخيصي (`Printing.layoutPdf`)، ونسخ Dossier للحافظة.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Critical | موديول المزامنة **بيتجاهل `DATABASE_PATH`**. قاعدة التطوير دايماً `<root>/sorour_logistics.db`، والإنتاج `dist/Sorour_Logistics_Standalone/sorour_logistics.db`. يعني حتى والباك إند شغال على قاعدة scratch أو test، "نقطة استرجاع" و "مزامنة" و "سحب" و "استعادة" بيتعاملوا مع القواعد الحقيقية. وده اللي حصل فعلاً أثناء المراجعة: اتعمل نسختين من القاعدة الحقيقية في `backups/` | `modules/production_sync/service.py:33-66`؛ `57-production-sync-dialog-add.png`؛ `backups/sorour_logistics_manual_dev_20260924_130504.db` | اقرا مسار التطوير من نفس الإعداد اللي بيستخدمه `database.database` (`DATABASE_PATH`)، ووقّف المزامنة والاستعادة لو المسار مش متظبط صراحة |
| High | "مزامنة لقاعدة الإنتاج" و "سحب الإنتاج للتطوير" و "بناء وتجميع الإنتاج" بيشتغلوا **من غير dialog تأكيد**. و"سحب الإنتاج للتطوير" بيكتب فوق بيانات التطوير (`preserve_target_user_data=False`). الاستعادة وتنزيل التحديث بس اللي عليهم تأكيد | `production_sync_screen.dart:1080-1170` (مفيش `showDialog`، التأكيد موجود في `:103` و `:734` بس)؛ `modules/production_sync/service.py:495` | ضيف تأكيد صريح فيه المصدر والهدف وعدد الجداول المتأثرة |
| Medium | على الويب، مسارات القاعدتين والحجم **ثابتين في الكود**: مسار من جهاز تاني (`C:\Users\Hp\Desktop\ImportFlow\...`) و "2452 كيلوبايت"، والـ mtime "متصل بالسيرفر". المعلومات دي مش حقيقية ومضللة | `57-production-sync-tab-2-dev-tools-live-diff.png`؛ `frontend/lib/features/production_sync/services/local_process_sync_web.dart:17-47` | اعرض `devStats/prodStats` اللي راجعة من `GET /compare` بس، ولو مش متاحة اكتب "غير معروف" |
| Medium (ويب) | الأرشيف بيظهر "0 نسخة" وقت الفتح، مع إن فيه 50 نسخة. على الويب `listBackups()` بيرجّع `_cachedBackups` الفاضية لحد ما تحصل أي عملية | `57-production-sync-main.png` مقابل `57-production-sync-dialog-add.png`؛ `local_process_sync_web.dart:50-60`؛ `production_sync_screen.dart:67-70` | اعرض `backupsListProvider` (`GET /backups`) مباشرة |
| Medium | Badge "متطابق تماماً" ظاهر في نفس الوقت اللي الجدول والـ console بيقولوا فيه إن فيه جدول محتاج تحديث. السبب إن الـ badge بيبص على `totalNewRecords > 0` بس، فأي فرق بالسالب (زيادة في الإنتاج زي `_test_sync_tbl`) بيتعرض "متطابق" | `57-production-sync-tab-2-dev-tools-live-diff.png`؛ `features/production_sync/widgets/sync_progress_and_diff_widget.dart:131-143` | اربط الـ badge بعدد الجداول المختلفة (`changedTables`) مش بعدد السجلات الجديدة بس |
| Medium | الاستعادة: لو اسم الملف مش في `backups/`، الباك إند بيقبل **أي مسار مطلق** على السيرفر (`alt_path = Path(filename)`) وبينسخه فوق القاعدة. والواجهة بتحدد الهدف من الـ tag: أي نسخة مش `dev` (زي "backup" و "auto_pre_upgrade") بتتسترجع على **الإنتاج** | `modules/production_sync/service.py:553-563`؛ `production_sync_screen.dart:140` | اقبل أسماء ملفات من `backups/` بس، وخلّي المستخدم يختار الهدف صراحة في dialog التأكيد |
| Medium | `_cleanup_old_backups` بيمسح نهائياً أي نسخة بعد أحدث 50، من غير ما يبلّغ المستخدم ولا يسجّل. الضغط كذا مرة على "نقطة استرجاع" ممكن يضيّع نسخ ترقية قديمة مهمة | `modules/production_sync/service.py:124-139` | استثني نسخ `auto_pre_upgrade` و `prod_before_sync`، أو اعرض تحذير |
| Low | جدول اختبار `_test_sync_tbl` موجود في قاعدة الإنتاج (Prod: 1) | `57-production-sync-tab-2-dev-tools-live-diff.png` | نضّف جداول الاختبار من الإنتاج |
| Low | 27 سطر فيه زرار Material مباشر (`ElevatedButton/OutlinedButton/TextButton`) وحوالي 50 استخدام لـ `Colors.*` بدل `AppButton`/`AppTheme` | `production_sync_screen.dart` (مثلاً `:1080-1084`) | توحيد حسب UI_SCREEN_STANDARDS |
