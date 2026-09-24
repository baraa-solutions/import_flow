# مركز مراقبة وصحة النظام (System Observability & Health)

> **مفيش صورة للشاشة دي.** التصوير فشل (`capture-manifest.json`: `status: failed`)، والسبب: "sidebar item clicked but the main area did not change". الـ harness ضغط على العنصر في القائمة والمنطقة الرئيسية ما اتغيرتش، لأن الشاشة **مش ممكن توصلها في التطبيق وهو شغال** (راجع أول ملاحظة). كل الشرح هنا من الكود: `frontend/lib/features/system_observability/screens/system_observability_screen.dart`.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** مركز مراقبة تشغيلي للنظام:
  - **المؤشرات الحيوية والأداء:** حالة السيرفر (ONLINE/OFFLINE)، ومؤشرات الطلبات والأخطاء وزمن الاستجابة، وأكتر الـ endpoints استخداماً، وصحة قاعدة البيانات (WAL).
  - **رادار العمليات اللوجستية:** مؤشرات domain (شحنات متأخرة، ومستندات ناقصة، ...).
  - **سجل المرور والاستعلامات:** آخر 30 طلب وأبطأ الاستعلامات.
  - **الفحص العميق وحزم الدعم:** فحص عميق لقاعدة البيانات، وتصدير حزمة دعم ZIP، وتصدير لوج العميل.
- **المستخدمين:** مسؤول النظام والدعم الفني.
- **المرحلة:** إدارة نظام. مالهاش BP/MD.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "مركز مراقبة وصحة النظام" (index 69). بيظهر لـ ADMIN/MANAGER (`home_screen.dart:1023-1024`)، **بس الضغط عليه مالوش أي أثر** (`navigation_provider.dart:102` و `:188`). ومش موجود في لوحة الأوامر.
- **Scaffold:** `Scaffold` بهيدر مخصص وتحته TabBar أفقي بـ 4 تابات (`:273-276`).
- **الباك إند** (`modules/system_observability/router.py`): `metrics` و `database` و `domain-radar` و `recent-traffic` لأي مستخدم مسجّل. أما `health/deep` و `export-bundle` و `alerts/test-trigger` و `daily-report/generate` و `alerts/reset-cooldown` فـ `require_admin` (`:59` و `:79` و `:125` و `:164` و `:188`).

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| تحديث تلقائي (5s) | Switch | — | — | `autoRefreshObservabilityProvider` + `Timer.periodic(5s)` (`:41-49`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تحديث الآن | invalidate للمؤشرات والقاعدة والرادار والمرور (`:217`) | `GET /api/v1/system/observability/metrics`، و `/database`، و `/domain-radar`، و `/recent-traffic?limit=30` | مسجّل |
| اختبار التنبيه (Toast) | بيبعت تنبيه تجريبي (`:228`) | `POST /api/v1/system/observability/alerts/test-trigger?channel=TOAST` | ADMIN |
| تصدير حزمة الدعم (ZIP) | بينزّل الحزمة وبيحفظها بـ `FileSaveHelper.exportAndSaveFile`. **فيه loading** (`_isExporting`، `:239`) | `GET /api/v1/system/observability/export-bundle` | ADMIN |
| تشغيل الفحص العميق (تاب 4) | `deepHealthProbeProvider.runProbe()` (`:992`) | `GET /api/v1/system/health/deep` | ADMIN |
| تصدير لوج العميل (.log) (تاب 4) | لوج التشخيص المحلي ← `FileSaveHelper.exportAndSaveFile` (`:91-100` و `:1162`) | — | الكل |

> ملحوظة: الـ exception `Cannot use "ref" after the widget was disposed` اللي في `runtime-errors.json` تحت bucket الشاشة دي اتسجل وقت الضغط على عنصر القائمة، والشاشة نفسها ما اترسمتش، فهو مش من كود الشاشة دي (متسجّل كملاحظة في الشاشة 49).

### الجداول
- **تاب 1:** كروت KPI، وقائمة أكتر الـ endpoints (المسار و "N reqs")، وإجمالي الأخطاء.
- **تاب 3:** جدول آخر الطلبات (المسار، والـ method، والحالة، والزمن)، وقائمة الاستعلامات البطيئة بالـ ms.
- مفيش فلاتر ولا ترتيب.

### التابات
مفيش صور. التابات حسب الكود (`:273-276`):
1. **المؤشرات الحيوية والأداء** (`_buildLivePulseTab`، `:340`)
2. **رادار العمليات اللوجستية** (`_buildDomainRadarTab`، `:554`)
3. **سجل المرور والاستعلامات** (`_buildTrafficTelemetryTab`، `:750`)
4. **الفحص العميق وحزم الدعم** (`_buildDeepHealthTab`، `:947`)

### الـ Dialogs
مفيش dialogs.

### التصدير والطباعة
- حزمة دعم ZIP من السيرفر (ADMIN).
- لوج العميل `.log` (`stageName: 'Desktop Client'`).
- الاتنين بيعدّوا على `FileSaveHelper.exportAndSaveFile` (ده متوافق مع Task I).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | الشاشة **مش ممكن توصلها**: عنصر القائمة بينادي index 69، و `selectNavigationIndex` بيرفض أي index ≥ `_totalScreens` (68). التصوير فشل بسبب كده | `capture-manifest.json` (nn 60: failed)؛ `navigation_provider.dart:102` و `:188`؛ `home_screen.dart:1024` | خلّي `_totalScreens` يساوي طول `_screens` (70)، وضيف الشاشة للوحة الأوامر |
| Medium | "تصدير لوج العميل" بيحوّل النص لـ bytes بـ `logText.codeUnits` (UTF-16 code units). أي حرف عربي (> 255) هيتقطع ويتكتب غلط في الملف | `system_observability_screen.dart:92-93` | استخدم `utf8.encode(logText)` |
| Medium | الشاشة كلها نصوص hard-coded من غير l10n (0 استخدام لـ `context.l10n`): عناوين التابات، والأزرار، ورسائل الخطأ. وفيها رسالة إنجليزي `'Failed to export bundle: ...'` في واجهة عربية | `system_observability_screen.dart:81` و `:219` و `:230` و `:248` و `:273-276`؛ `inventory.json` (notes) | انقل النصوص لملفات l10n |
| Low | TabBar أفقي بـ 4 تابات، ودي anti-pattern في الـ standard ("TabBar أفقي عند عدد tabs ≥ 4") | `system_observability_screen.dart:273-276`؛ `.agents/skills/ui-screen-standards/SKILL.md` (Anti-Patterns) | تابات رأسية، أو تقسيم الشاشة |
| Low | حالة "التحديث التلقائي" محفوظة في provider عام، بس الـ Timer بيتعمل بس لما تضغط الـ Switch. لو خرجت من الشاشة ورجعت، الـ Switch هيظهر شغال والـ Timer مش شغال | `system_observability_screen.dart:29-49` | في `initState`، لو الـ provider `true`، ابدأ الـ Timer |
| Low | رسالة نجاح اختبار التنبيه ثابتة "تم إرسال إشعار اختباري بنجاح إلى نظام ويندوز!" واسم ملف اللوج "Desktop Client" مهما كانت المنصة، فعلى الويب الرسالة بتقول حاجة محصلتش | `system_observability_screen.dart:97` و `:114` | نص محايد حسب المنصة |
