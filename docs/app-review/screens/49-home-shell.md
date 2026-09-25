# الواجهة الرئيسية والقائمة الجانبية (Home Shell & Sidebar)
![](../screenshots/49-home-shell-main.png)

> التصوير اتعمل على **Flutter Web (release)** مش Windows desktop. الصورة اتاخدت بعد ما الـ harness فتح شاشات كتير، عشان كده شريط التابات مليان والشاشة المعروضة في المنطقة الرئيسية هي شاشة "الإغلاق المالي والإداري" (مش جزء من الـ shell نفسه).

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** الإطار الأساسي للتطبيق بعد الدخول. فيه:
  - **القائمة الجانبية (Sidebar)** بعشر مجموعات (Hubs) قابلة للطي: البيانات والجداول الأساسية، وتخطيط الشحنة وأوامر الشراء، والمراحل من 1 لـ 6، والاستعلامات، ولوحة القيادة والتقارير والرقابة.
  - **الشريط العلوي (Unified Top Bar):** اسم ImportFlow، و breadcrumb، وساعة عالمية، وزرار الأوامر (Ctrl+K)، ومساعد الاستيراد الذكي، والبريد، واللغة، والثيم، والإعدادات، وكثافة العرض (مريح)، ووضع التركيز، ودليل الاختصارات، وملء الشاشة، ومؤشر 24H LIVE.
  - **شريط تابات العمل (Workspace Tabs):** كل شاشة بتتفتح في تاب، وممكن تتقفل بـ ✕ أو Ctrl+W.
  - **منطقة المحتوى:** `IndexedStack` فيه 70 خانة شاشة (indices 0-69) (`home_screen.dart:400`).
  - **ذيل الـ Sidebar:** اسم المستخدم ودوره (Review Admin / ADMIN)، ورقم الإصدار (v2.0.3 Build 205)، والبورت (28080).
- **المستخدمين:** كل المستخدمين بعد الدخول.
- **المرحلة:** مالهاش BP/MD. هي اللي بتوصّل لكل شاشات الدورة.

## طريقة الوصول والصلاحية
- بتظهر من `AuthGate` بعد نجاح الدخول.
- **الصلاحية:** أي مستخدم مسجّل. بعض عناصر القائمة بتظهر حسب الدور:
  - "إدارة المستخدمين والصلاحيات" و "مركز مراقبة وصحة النظام": `user == null || user.isAdmin || user.isManager` (`home_screen.dart:1017` و `:1023`).
  - "إعدادات تصنيف مخاطر المراحل": `user.canManageStepConfig` (`home_screen.dart:1020`).
  - "إعدادات ربط البريد (IMAP/SMTP)": `EmailSettingsDialog.canAccess(user)` (`home_screen.dart:1006`).
- **اختصارات الكيبورد** (`home_screen.dart:309-341`): Ctrl/Cmd+K لوحة الأوامر، و Ctrl+Tab و Ctrl+Shift+Tab للتنقل بين التابات، و Ctrl+W لقفل التاب، و Ctrl+Shift+F وضع التركيز، و Esc، و F11 ملء الشاشة، و F1 أو Ctrl+/ دليل الاختصارات.

## مكونات الشاشة

### الحقول
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث سريع... (أعلى الـ Sidebar) | TextField | لا | مفيش. بيفلتر عناصر القائمة وبيفتح المجموعات اللي فيها نتيجة | محلي (`_searchQuery` في `home_screen.dart:797-806`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| إخفاء القائمة لتوسيع الشاشة («) | بيطوي الـ Sidebar لـ rail أيقونات | — | الكل |
| Home (breadcrumb) | رجوع للوحة التحكم | — | الكل |
| الساعة (Egypt 13:01) | قائمة ساعات عالمية وساعات العمل | — | الكل |
| الأوامر Ctrl+K | بيفتح `CommandPaletteDialog` | — | الكل |
| مساعد الاستيراد الذكي (أيقونة حمرا) | بيفتح مساعد الـ AI | `ai_assistant_provider` | الكل |
| المستمع الذكي للبريد وإشعارات الوصول | بيفتح `SmartEmailListenerDialog` | `/api/v1/smart-email/*` | الكل |
| إعدادات ربط البريد (IMAP/SMTP) | بيفتح `EmailSettingsDialog` | `/api/v1/smart-email/*` | ADMIN (الباك إند بيرجّع 403 لغيره) |
| EN / تغيير اللغة | بيبدّل عربي/إنجليزي | — | الكل |
| تبديل المظهر الداكن والنهاري | ثيم | — | الكل |
| الإعدادات الأساسية للنظام | `SystemSettingsDialog` | `/api/v1/system/*` | الكل |
| كثافة عرض الجدول (مريح) | بتغيّر `displayDensityProvider` لكل الجداول | — | الكل |
| وضع التركيز / دليل الاختصارات / ملء الشاشة | UI بس. ملء الشاشة بيستخدم `windowManager` على ويندوز بس (`home_screen.dart:237`) | — | الكل |
| إشعارات النظام (الجرس) | لوحة الإشعارات | `/api/v1/notifications` | الكل |
| عناصر القائمة الجانبية | `selectNavigationIndex(ref, index)` وفتح تاب | حسب الشاشة | حسب الشاشة |
| قائمة المستخدم (⋮ جنب الاسم) | خيارات المستخدم، ومنها معلومات الإصدار (`_showSystemInfoDialog` في `home_screen.dart:1360`) وتسجيل الخروج | `POST /api/v1/auth/logout` | الكل |
| v2.0.3 (Build 205) في ذيل الـ Sidebar | زرار بيفتح نفس dialog معلومات الإصدار (`home_screen.dart:1099`) | — | الكل |
| خيارات النوافذ والتبويبات (… آخر شريط التابات) | قائمة بباقي التابات المفتوحة وخيارات قفلها | — | الكل |
| معلومات الإصدار ← مركز المزامنة والتحديث | بيفتح `ProductionSyncHubDialog` (`home_screen.dart:1451`) | `/api/v1/production-sync/*` | ADMIN للعمليات |

### الجداول
مفيش جداول في الـ shell نفسه.

### التابات
شريط **Workspace Tabs** (مش TabBar ثابت): كل شاشة بتتفتح بتضيف تاب فيه أيقونتها واسمها و ✕. وفي الآخر زرار "…" لباقي التابات. الصورة الرئيسية بتوضح 6 تابات مفتوحة.

### الـ Dialogs
Dialogs بتتفتح من الـ shell (من `inventory.json`). **ما اتصورتش** لأن الـ harness بيصوّر dialog الإضافة بس:
- `CommandPaletteDialog` (Ctrl+K)، و `KeyboardShortcutsDialog` (F1)، و `ProductionSyncHubDialog`، و `SmartEmailListenerDialog`، و `EmailSettingsDialog`، و `SystemSettingsDialog`، و dialog معلومات الإصدار (inline).

### التصدير والطباعة
مفيش في الـ shell. بس كل شاشات التصدير بتعدّي على `FileSaveHelper` (راجع الملاحظة تحت عن سلوك الإلغاء على الويب).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | عنصر القائمة "مركز مراقبة وصحة النظام" بينادي `selectNavigationIndex(69)`، والدالة بترجع من غير ما تعمل حاجة لأن `_totalScreens = 68`، فالشاشة مش ممكن توصلها (راجع الشاشة 60). وبرضه index 68 (`ShipmentInquiryScreen`) برّه الحد | `navigation_provider.dart:102` و `:188`؛ `home_screen.dart:225-229` و `:1024`؛ `capture-manifest.json` (الشاشة 60: failed) | خلّي `_totalScreens` يتحسب من طول `_screens` (70) بدل رقم ثابت، وضيف test بيقارن الاتنين |
| Medium | خانة "بحث سريع..." في الـ Sidebar بتترسم مستطيل أبيض مصمت، والـ hint (`Colors.white` بشفافية 0.4) والنص المكتوب (`Colors.white`) مش باينين. الـ hint موجود في جرد العناصر بس مش ظاهر في الصورة، يعني الغالب إن `inputDecorationTheme` بتاع الثيم بيعمل `filled` بلون أبيض فوق الخلفية | `49-home-shell-main.png`؛ `elements/49-home-shell-main.json` (field "بحث سريع...")؛ `home_screen.dart:797-806` | حدّد `filled: true, fillColor: Colors.white.withOpacity(0.08)` صراحةً في الـ `InputDecoration`، أو استخدم لون نص غامق |
| Medium | "مركز مزامنة وتحديث الإنتاج" ظاهر في القائمة لكل الأدوار، مع إن الباك إند بيطلب `require_admin` لكل العمليات المهمة. أي OPERATOR هيفتحه ويشوف أخطاء 403 | `home_screen.dart:1015`؛ `modules/production_sync/router.py:66-139` | اخفي العنصر لغير ADMIN زي "إدارة المستخدمين" |
| Medium | Exception وقت التنقل: `Bad state: Cannot use "ref" after the widget was disposed` اتسجلت مرتين: مرة وهو خارج من الشاشة 31 (الـ entry اللي في bucket الشاشة 49 عليها `screen: 31-shipment-draft-docs-matrix`)، ومرة لما اتضغط عنصر الشاشة 60. الـ stack من release build متضغط فمش واضح أنهي widget بالظبط | `runtime-errors.json` (`by_screen["49-home-shell"]` و `["60-system-observability"]`) | دوّر على callbacks async بتستخدم `ref` بعد `await` من غير `if (!mounted) return` |
| Medium | عام لكل شاشات التصدير: على الويب، لو المستخدم ضغط "إلغاء" في نافذة الحفظ (AbortError)، `FileSaveHelper.saveBytes` بيعمل **تحميل تلقائي** بالـ `<a download>` بدل ما يلغي. ده ضد قاعدة Task I (الإلغاء لازم يبقى آمن ومن غير حفظ) | `frontend/lib/core/services/file_save_helper.dart:263-275` | فرّق بين AbortError (متعملش حاجة) و SecurityError (ساعتها اعمل fallback) |
| Low | الـ breadcrumb بيظهر "Home" بالإنجليزي، والـ tooltip "Synchronized with 24-Hour Universal Live Time"، مع إن الكود فيه نسخة عربية (`isArabic ? 'الرئيسية' : 'Home'`). السبب إن `isArabic` بتتحسب من `Directionality.of(context)`، ودي بتتأثر بمشكلة الـ locale المعروفة (`locale: ar` من غير `supportedLocales`) | `49-home-shell-main.png`؛ `core/widgets/unified_top_bar.dart:23` و `:99` و `:166` | صلّح `supportedLocales` في `main.dart`، واحسب اللغة من `localeProvider` مش من الاتجاه |
| Low | عناصر ADMIN/MANAGER بتظهر لو `user == null` (الشرط `user == null \|\| user.isAdmin`) | `home_screen.dart:1017` و `:1023` | خلّي الشرط `user != null && (user.isAdmin \|\| user.isManager)` |
| Low | أزرار الثيم واللغة والبريد والإعدادات متكررة مرتين: مرة في رأس الـ Sidebar ومرة في الشريط العلوي | `elements/49-home-shell-main.json` (مثلاً "تبديل المظهر الداكن والنهاري" مرتين) | سيب نسخة واحدة (الشريط العلوي) |
| Low | على الويب بس: كل request بيطلع في الكونسول `Refused to set unsafe header "Accept-Encoding"`، لأن الـ Dio client بيحط الـ header يدوي، والمتصفح بيمنعه. مش bug على الديسكتوب | `core/network/api_client.dart:27`؛ `runtime-errors.json` (موجودة في كل الشاشات) | اشيل الـ header لما يكون `kIsWeb` |
| Low | زرار "ملء الشاشة" شغال على Windows بس (`if (!kIsWeb && Platform.isWindows)`). على الويب الضغط عليه مابيعملش حاجة ومفيش أي رسالة للمستخدم | `home_screen.dart:235-252` | على الويب اخفي الزرار أو استخدم Fullscreen API بتاع المتصفح |
