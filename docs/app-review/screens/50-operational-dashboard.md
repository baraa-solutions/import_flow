# لوحة التحكم ومساحة العمليات (Operational Dashboard)
![](../screenshots/50-operational-dashboard-main.png)

> التصوير اتعمل على **Flutter Web (release)**. الصورة بتغطي الجزء العلوي بس (الكروت والرادار وبانر لوحة المراحل وأدوات التكويد الذكي). باقي الشاشة (التنبيهات، والتحديثات اليومية، وملخص المراحل، وشريط الفلاتر، وكروت الشحنات) موصوف من الكود.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** الشاشة اللي بتفتح أول ما تدخل (index 0). بتجمع صورة تشغيلية لكل الشحنات: مؤشرات أداء، ورادار غرامات الحاويات، وملخص دورة المراحل (6 مراحل / 25 خطوة)، وقائمة كروت الشحنات مع فلترة، ومنها تسجّل تحديث يومي أو تتخطى خطوة أو تقفل شحنة.
- **المستخدمين:** مدير العمليات، ومسؤولي الاستيراد، والإدارة العليا.
- **المرحلة:** شاشة متابعة عابرة للمراحل (Type C). الأكواد المرتبطة من `inventory.json`: **BP-001** (Receive Purchase Order، بداية الملف) و **BP-040** (Close Import File، من زرار إغلاق الشحنة).

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "لوحة التحكم ومؤشرات الأداء" (index 0). وهي كمان الشاشة الافتراضية بعد الدخول.
- **Scaffold:** `Scaffold` + `PageHeader` (مطابق لـ Type C)، وفيه زرار تحديث في الهيدر (`operational_dashboard_screen.dart:176-195`).
- **الصلاحية:** أي مستخدم مسجّل. الـ routers محمية بـ `Depends(get_current_user)` على مستوى الـ router (`modules/import_files/router.py:31`)، ومفيش RBAC code.
- **تحميل البيانات:** في `initState` بيعمل invalidate لـ 4 providers وبعدين fetch (`operational_dashboard_screen.dart:124-132`).

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| الأولوية | ToggleButtons (الكل / حرجة / عالية / متوسطة / منخفضة) | لا | — | ثابت (`_priorities`)، و `notifier.setPriority` |
| المخلص الجمركي | `SearchableDropdownField<String>` | لا | — | الكل + أسماء المخلصين من البيانات (`operational_dashboard_screen.dart:355-362`) |
| بحث سريع | TextField بـ debounce | لا | — | `notifier.setSearchQuery` ← `GET /api/v1/import-files/operational-dashboard` |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تحديث (الهيدر) | invalidate وإعادة تحميل الداشبورد والمهام والتحديثات | `GET /api/v1/import-files/operational-dashboard`، و `GET /api/v1/lifecycle-board/summary`، و `GET /api/v1/smart-tasks` | الكل |
| 9 كروت مؤشرات (مهام اليوم، المهام المعلقة، الشحنات القادمة، شحنات هذا الأسبوع، تعديلات موعد الوصول، معلق للسداد، بانتظار نموذج 4، متطلبات معلقة، تنبيهات عالية الأولوية) | كل كارت بيفتح `DashboardCardDrillDownDialog` بالسجلات بتاعته (`operational_dashboard_screen.dart:1473-1625`) | بيانات الداشبورد والمهام | الكل |
| تحديث الرادار / فتح شاشة الغرامات | بيحدّث رادار الغرامات (TR-02)، أو بيفتح شاشة الأرضيات والغرامات | `/api/v1/demurrage-detention/*` | الكل |
| فتح لوحة المراحل التفاعلية | `selectNavigationIndex(48)` | — | الكل |
| تكويد مورد أجنبي / شركة مستوردة / شريك أو مخلص / بنك معتمد (ذكي) | `UniversalEntityExtractorDialog` بالنوع المناسب (`operational_dashboard_screen.dart:2123-2141`) | endpoints الاستخراج بالـ AI والحفظ | الكل |
| أزرار "إنشاء جديد" السريعة (مشروع، ملف استيراد، شركة، مورد، شريك/بنك، تعريفة، موقع، عملة، سعر صرف) | بتنقلك للشاشة المناسبة بس (`operational_dashboard_screen.dart:2171-2227`) | — | الكل |
| إعادة ضبط الفلاتر | بيرجّع الأولوية والمخلص والبحث للافتراضي | إعادة تحميل الداشبورد | الكل |
| تسجيل تحديث يومي (في كارت الشحنة) | `ShipmentUpdateDialog` | `POST /api/v1/shipment-updates` | الكل |
| تخطي الخطوة (في كارت الشحنة) | `SkipStepDialogHelper.show` | `POST /api/v1/lifecycle-board/stages/skip` (فيه فحص دور في الـ service) | MANAGER/GENERAL_MANAGER/ADMIN أو حسب إعداد الخطوة |
| إغلاق وإيقاف الشحنة (في كارت الشحنة) | `CloseShipmentDialog`، وبعدها إعادة تحميل (`operational_dashboard_screen.dart:917-926`) | `POST /api/v1/import-files/{id}/close-shipment` | الكل |
| إنهاء مهمة مرتبطة | `updateTask(status: Completed)` | `PUT /api/v1/smart-tasks/{taskId}` | الكل |
| إضافة تحديث (كارت التحديثات اليومية) | `ShipmentUpdateDialog` | `POST /api/v1/shipment-updates` | الكل |

### مكونات العرض (من الصورة)
- **كروت المؤشرات:** كل كارت فيه عنوان، ورقم ملوّن ووحدة ("مهام" / "شحنة")، وسطر وصف (مثلاً "متوقع وصولها القادم"، "موافقات مالية معلقة (المرحلة 2)")، وأيقونة فتح صغيرة. الـ tooltip بتاع الكارت "اضغط للاطلاع على كافة السجلات والتفاصيل".
- **رادار الغرامات (TR-02):** عنوان "رادار مراقبة فترات السماح وتفادي غرامات الحاويات (TR-02)" ووصف، و 4 عدّادات: "آمن داخل السماح"، و "تحذير 72 ساعة"، و "غرامات سارية"، و "تم الإرجاع". ولو مفيش حاويات بتظهر رسالة "لا توجد حاويات قيد التتبع حالياً — كافة الشحنات مستقرة داخل فترات السماح." (الحالة اللي في الصورة).
- **بانر لوحة المراحل:** شارة "جديد"، وعنوان "لوحة تتبع ومراحل الشحنات التفاعلية"، ووصف (6 مراحل كبرى / 25 خطوة)، وزرار "فتح لوحة المراحل التفاعلية".
- **أداة التكويد الذكي:** عنوان "أداة التكويد والاستخراج الذكي بالذكاء الاصطناعي:" و 4 أزرار ملوّنة، وتحتها عنوان "روابط الاختصارات السريعة لإنشاء وإدخال السجلات:" (باقي القسم تحت حدود الصورة).

### الجداول
مفيش DataTable. البيانات بتظهر كـ **كروت شحنات** في `SliverList` (`operational_dashboard_screen.dart:614`). كل كارت فيه: كود/اسم الشحنة، والشركة ← المورد، والمرحلة الحالية والخطوة التشغيلية، والمخلص، وأمر الشراء، ونسبة التقدم، والمسار الحالي والتالي، وحالة الإغلاق لو مقفولة، والمهام المفتوحة المرتبطة.
- **الفلاتر:** الأولوية، والمخلص الجمركي، والبحث، والمرحلة (من ملخص المراحل). وفوق القائمة سطر بعدد الشحنات المطابقة وآخر تحديث.
- **الترتيب:** بالترتيب اللي بيرجع من الباك إند.

### التابات
مفيش تابات.

### الـ Dialogs
Dialogs من `inventory.json`: `DashboardCardDrillDownDialog`، و `UniversalEntityExtractorDialog`، و `CloseShipmentDialog`، و `ShipmentUpdateDialog`. **ما اتصورتش**: الـ harness ما لقاش زرار إضافة في الشاشة (`capture-manifest.json`: "no add/create button found").

### التصدير والطباعة
فوق قائمة الشحنات (بتتقفل لو القائمة فاضية):
- **تصدير جدول نصوص (TSV)** ← `OperationalDashboardExportService.exportTsv` (`operational_dashboard_screen.dart:479`).
- **تصدير Excel** ← `exportCsv` (`:497`)، يعني الملف الناتج **CSV** مش xlsx.
- **طباعة PDF** ← `printPdf` (`:515`)، عن طريق `Printing.layoutPdf`.
- **نسخ الملف الشامل** ← `copyDossier` (`:534`) للحافظة.
- الحفظ بيعدّي على `FileSaveHelper.saveBytes` (`operational_dashboard_export_service.dart:157` و `:215`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | أزرار "إنشاء مشروع/ملف/شركة/... جديد" بتنقلك للشاشة بس ومبتفتحش فورم الإضافة، فالـ label مضلل. و"عملة جديدة" و"سعر صرف جديد" الاتنين بيروحوا لنفس الـ index 38 | `operational_dashboard_screen.dart:2171-2227` | افتح dialog الإضافة مباشرة (مثلاً باراميتر `openCreate: true`)، أو غيّر الـ label لـ "فتح شاشة ..." |
| Low | زرار "تصدير Excel" بينادي `exportCsv` وبيطلع CSV | `operational_dashboard_screen.dart:497` | سمّيه "تصدير CSV" أو اعمل xlsx حقيقي |
| Low | مخالفة UI_SCREEN_STANDARDS: 41 سطر فيه `ElevatedButton/OutlinedButton/TextButton` ومفيش ولا `AppButton`، وحوالي 147 استخدام لـ `Colors.*` و 13 `Color(0x..)` | `operational_dashboard_screen.dart` (مثلاً `:188` `Colors.white`) | انقل الأزرار لـ `AppButton` والألوان لـ `AppTheme` |
| Low | `initState` بيعمل `ref.invalidate` وبعدها `fetchDashboard()`/`fetchTasks()` على طول، فممكن الـ request يتبعت مرتين | `operational_dashboard_screen.dart:127-132` | اكتفي بواحد من الاتنين |
| Low | الدالة اسمها `_buildStreamlitLauncherBanner` مع إنها بتفتح لوحة المراحل الـ native (index 48). ده اسم من أيام Streamlit وممكن يلخبط اللي بيقرا الكود | `operational_dashboard_screen.dart:2270` و `:2338` | غيّر الاسم لـ `_buildLifecycleBoardBanner` |
