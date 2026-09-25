# لوحة Streamlit القديمة (غير مستخدمة) (Streamlit Board (orphan))

> **مفيش صورة للشاشة دي.** الـ harness عدّاها (`capture-manifest.json`: `status: skipped`، والسبب "Not instantiated anywhere in frontend/lib"). الكلاس `StreamlitBoardScreen` مش مستخدم في أي مكان في `frontend/lib`: مش في `_screens` بتاعة `home_screen.dart`، ولا في القائمة، ولا في لوحة الأوامر. كل الشرح هنا من الكود: `frontend/lib/features/streamlit_board/screens/streamlit_board_screen.dart`.

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض (تاريخياً):** launcher للوحة دورة حياة الشحنات القديمة المكتوبة بـ Streamlit (`streamlit_app.py` في جذر المشروع). الشاشة كانت بتشغّل سيرفر Streamlit محلي على البورت 8501، وبتفحص إنه شغال، وبتفتحه في المتصفح.
- **البديل الحالي:** لوحة المراحل الـ native (الشاشة 51، index 48). وبانر لوحة التحكم اللي اسمه `_buildStreamlitLauncherBanner` بقى بيفتح اللوحة الـ native (`operational_dashboard_screen.dart:2338`).
- **المستخدمين:** مفيش حالياً.
- **المرحلة:** مالهاش BP/MD.

## طريقة الوصول والصلاحية
- **مش ممكن توصلها** من التطبيق (orphan).
- **الصلاحية:** مش منطبقة. الشاشة مش بتنادي API الباك إند، بتكلم `http://localhost:8501` مباشرة.

## مكونات الشاشة

### الحقول
مفيش حقول إدخال.

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تشغيل السيرفر | `Process.start('python', ['-m','streamlit','run','streamlit_app.py','--server.port','8501'], workingDirectory: '..', detached)` (`streamlit_board_screen.dart:54-70`) | — (عملية محلية) | — |
| فحص الحالة | `HttpClient.getUrl('http://localhost:8501')` (`:31-40`) | `http://localhost:8501` | — |
| فتح في المتصفح | `cmd /c start` على ويندوز، و `open` على ماك، و `xdg-open` على لينكس (`:85-92`) | — | — |

وفيه شارة حالة ONLINE (Port 8501) / OFFLINE (`:206`)، وعنوان "Streamlit Lifecycle Pipeline Engine".

على الويب كل الوظائف متقفلة (`if (kIsWeb) return;` في `:31` و `:54` و `:85`) لأنها معتمدة على `dart:io` (فرق منصة، مش ملاحظة). اسم دالة البانر في لوحة التحكم متسجّل كملاحظة في الشاشة 50.

### الجداول
مفيش.

### التابات
مفيش.

### الـ Dialogs
مفيش. الأخطاء بتظهر SnackBar (`:97`).

### التصدير والطباعة
مفيش.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Low | كود ميت: الشاشة مش متوصلة بأي مكان، وفيها تشغيل عمليات محلية (`Process.start` لـ python في `..` بشكل detached). لو حد رجّعها للقائمة بالغلط، هتشغّل عملية بايثون من مسار نسبي غير مضمون | `streamlit_board_screen.dart:1` و `:62-68`؛ `capture-manifest.json` (nn 61: skipped) | احذف `features/streamlit_board/` (وراجع هل `streamlit_app.py` لسه محتاجينه) |
| Low | نصوص hard-coded بالعربي والإنجليزي من غير l10n (مثلاً "جاري تشغيل خادم Streamlit..." و "Streamlit Lifecycle Pipeline Engine") | `streamlit_board_screen.dart:57` و `:186` | لو الشاشة هتفضل، انقل النصوص لـ l10n |
