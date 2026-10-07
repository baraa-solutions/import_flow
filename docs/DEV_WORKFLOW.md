# 🛠️ Sorour Logistics ERP — Developer & Operator Dual-Track Workflow

> **دليل مسار العمل اليومي والتطوير المزدوج (Dual-Track Workflow)**  
> يوثق هذا الدليل بوضوح تام الفرق بين **مسار التطوير السريع اليومي (Track 1)** و**مسار إصدار حزم الإنتاج الرسمية (Track 2)** لمنع أي تداخل أو إهدار للوقت أثناء العمل اليومي والتجربة الحية.

---

## 🧭 نظرة عامة (Overview)

بما أن المطور الحالي هو نفسه المستخدم الفعلي للنظام على جهاز واحد وببيانات تشغيلية حقيقية:
- **Track 1 (Fast Iteration):** هو المسار الافتراضي للعمل اليومي، وإصلاح الأخطاء اللحظية، وتجربة الميزات الجديدة في ثوانٍ معدودة عبر Hot Reload دون أي بناء أو مثبتات.
- **Track 2 (Formal Release):** يُستخدم **فقط** عند الوصول لمحطة استقرار معتمدة (Milestone Checkpoint) أو عند الرغبة في تسليم حزمة تثبيت لمستخدم ثانٍ في المستقبل.

---

## ⚡ Track 1 — Fast Iteration (Dev Mode)

هذا هو المسار اليومي الافتراضي لتطوير وتجربة النظام فوراً على البيانات الحقيقية.

### 🛡️ قاعدة الأمان الإلزامية قبل بدء العمل (Non-Negotiable Safety Habit)
> **تنبيه حرج:** بما أن مسار التطوير يعمل مباشرة على قاعدة البيانات الحقيقية، **يجب أخذ نسخة احتياطية فورية قبل بدء أي جلسة تعديل تمس منطق العمل (Business Logic) أو عمليات الكتابة:**
> ```cmd
> python scripts/daily_backup.py --test
> ```
> *(يستغرق الأمر **0.05 ثانية فقط**، وينشئ نسخة احتياطية فورية مؤرخة مع التحقق من سلامة البيانات في مجلد `backups/`)*.

### 🚀 التشغيل المباشر بنقرة واحدة (1-Click Dev Launcher)
يمكنك تشغيل كل شيء آلياً (النسخ الاحتياطي + الخادم + الفلاتر مع Hot Reload) مباشرة عبر تشغيل:
```cmd
Launch_Track1_Dev.bat
```

---

### 1. تشغيل الباك إند يدوياً (Manual Backend Server)
يتم تشغيل الخادم مباشرة باستخدام بايثون متصلاً بقاعدة البيانات الحقيقية `sorour_logistics.db`:

```cmd
python main.py
```
أو مع التحديث التلقائي اللحظي عند حفظ أي ملف بايثون:
```cmd
python -m uvicorn main:app --host 127.0.0.1 --port 28080 --reload
```

- **زمن البدء/إعادة التشغيل:** ~2–4 ثوانٍ فقط.
- **في حال كان المنفذ 28080 مشغولاً:** لا تقتل أي عملية عليه (`taskkill`) — قد يكون هو نسخة الإنتاج المثبتة.
  شغّل نسخة التطوير على منفذ آخر (انظر القسم التالي).

### 1.1 التطوير على نفس جهاز الإنتاج (Dev beside the installed app)
النسخة المثبتة تعمل دائماً على `127.0.0.1:28080` بقاعدة بياناتها داخل مجلد التثبيت. نسخة التطوير يجب أن تنفصل عنها تماماً:

| البند | الإنتاج (لا يتغير) | التطوير |
|---|---|---|
| المجلد | `%LOCALAPPDATA%\Programs\Sorour Logistics\` | clone منفصل (مثال `D:\dev\import_flow`) |
| قاعدة البيانات | `sorour_logistics.db` في مجلد التثبيت | `DATABASE_PATH` في `.env` = مسار كامل داخل مجلد التطوير (أو نسخة من الباك أب) |
| منفذ الباك إند | `28080` | `PORT` (مثال `28090`) |
| الواجهة | تتصل بـ `28080` | `--dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:28090` |

```cmd
set PORT=28090
python main.py
```
```cmd
cd frontend
flutter run -d windows --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:28090
```
- اضبط `PORT` في الطرفية (`set PORT=...`) وليس في `.env`: السكريبتات و `backend_runner` يقرؤونه من الطرفية فقط.
- القيمة غير الصحيحة لـ `PORT` (ليست رقماً بين 1 و 65535) توقف التشغيل برسالة واضحة بدلاً من الرجوع لـ 28080.
- سكريبتات `Launch_Track1_Dev.bat` و `run.bat` و `Launch_ImportFlow_Desktop.bat` و `Launch_SorourLogistics_Live.bat` تقرأ `PORT`
  (الفحص المشترك في `scripts\check_backend_port.bat`) وتمرره لـ `flutter run` كـ `IMPORTFLOW_SERVER_URL`، ولا تقتل أي عملية
  على المنفذ: إذا كان المنفذ يرد كباك إند النظام تعيد استخدامه (وعلى جهاز الإنتاج مع `PORT` غير محدد = باك إند الإنتاج نفسه،
  لذلك اضبط `set PORT=28090` أولاً)، وإذا كان مشغولاً بشيء لا يرد تتوقف وتطلب منفذاً آخر.
- مع `PORT` غير 28080 تتجاهل السكريبتات ملف `frontend.exe` المبني (Release) لأنه يتصل دائماً بـ 28080، وتستخدم `flutter run`.
- وضع الويب / LAN في `run.bat` يعمل على 28080 فقط ويرفض التشغيل مع أي `PORT` آخر؛ للتطوير على جهاز الإنتاج استخدم وضع سطح المكتب.
- واجهة التطوير بدون `IMPORTFLOW_SERVER_URL` تتصل بـ 28080، وعند إغلاقها ترسل `/shutdown` إليه — أي تُغلق باك إند الإنتاج. لا تشغّلها بدون الـ define على جهاز الإنتاج.
- النسخة المثبتة ونسخة التطوير تتشاركان إعدادات Windows (SharedPreferences و secure storage) لنفس مستخدم Windows؛ يُفضَّل التطوير من مستخدم Windows منفصل.
- ممنوع على جهاز الإنتاج: شاشة / endpoints الـ `production_sync`، تشغيل `seed.py` / `reset_clean_production_db.py` / `clean_and_isolate_databases.py` من مجلد التثبيت، تثبيت أي Setup مبني محلياً، وأي تعديل داخل مجلد التثبيت.

---

### 2. تشغيل الواجهة الأمامية (Frontend in Dev Mode)
يتم تشغيل تطبيق Flutter مباشرة في وضع التطوير (Debug/Dev Mode) متصلاً بنفس الباك إند الحقيقي:

#### أ. تشغيل على سطح المكتب (Windows Desktop — الخيار المفضل):
```cmd
cd frontend
flutter run -d windows
```

#### ب. تشغيل على المتصفح (Web / Chrome):
```cmd
cd frontend
flutter run -d chrome --web-port 3000
```

---

### ⌨️ اختصارات التحديث الفوري أثناء تشغيل التطبيق (Hot Reload / Hot Restart):
أثناء تشغيل `flutter run` في الطرفية (Terminal):
- اضغط **`r`** : تنفيذ **Hot Reload** لحظي (أقل من ثانية واحدة) لتطبيق تعديلات واجهات الـ Widgets والألوان والترتيب فوراً دون إغلاق الشاشة أو فقدان الحالة.
- اضغط **`R`** : تنفيذ **Hot Restart** كامل (1–2 ثانية) لإعادة تشغيل منطق التطبيق و State من البداية.
- اضغط **`q`** : إيقاف التطبيق والخروج النظيف.

---

### ❌ ما يُحظر فعله في Track 1:
- ❌ لا تقم بتشغيل `package_production.py`.
- ❌ لا تقم بتوليد معالج تثبيت Inno Setup (`.exe`).
- ❌ لا تقم برفع أرقام الإصدارات أو تعديل `version.json`.
- ❌ لا تقم برفع أي ملفات إلى GitHub Releases.

---

## 📦 Track 2 — Formal Release (Production Packaging)

يُستخدم هذا المسار **فقط** في الحالات التالية:
1. عند الرغبة في أخذ نقطة حفظ رسمية (Milestone Checkpoint) للإصدار بعد استقرار وتأكيد ميزات Track 1.
2. عند إعطاء البرنامج لمستخدم آخر (Multi-user rollout) عبر مثبت ويندوز رسمي (`Setup.exe`).

### طريقة التشغيل الموحدة:
أمر واحد فقط يقوم بكافة مهام التجميع وحفظ البيانات:
```cmd
python package_production.py --preserve-data --compile-all
```

### ماذا يفعل هذا الأمر آلياً؟
1. يرفع رقم الإصدار ورقم البناء تسلسلياً (`version.json` و `pubspec.yaml` و `api_constants.dart` و `importflow_setup.iss`).
2. يعيد تجميع ملف الباك إند التنفيذي المستقل `dist_backend/backend.exe` عبر PyInstaller.
3. يعيد تجميع واجهة الفلاتر التنفيذية للديسكتوب (`flutter build windows --release`).
4. يحافظ بنسبة **100%** على قاعدة البيانات التشغيلية الحقيقية وسجلاتها (`--preserve-data`).
5. يولد مثبت التثبيت الرسمي `dist/releases/Sorour_Logistics_Setup_v*.exe`.
6. يولد النسخة المحمولة `dist/releases/Sorour_Logistics_v*_Windows_Portable.zip`.

---

## ⚖️ المقارنة السريعة بين المسارين (Track 1 vs Track 2)

| المقارنة | Track 1: التطوير والتجربة السريعة (Dev Mode) | Track 2: الإصدار الإنتاجي الرسمي (Formal Release) |
|---|---|---|
| **الهدف** | الاستخدام اليومي للمطور/المستخدم نفسه وحل المشاكل فوراً | تجهيز حزمة نهائية لمستخدم آخر أو حفظ محطة استقرار |
| **طريقة التشغيل** | `flutter run -d windows` + `python main.py` | `Sorour_Logistics_Setup_v*.exe` أو `Launch_Sorour_Logistics.vbs` |
| **زمن تطبيق التعديل** | **ثانية واحدة** (Hot Reload `r`) | 3–5 دقائق (Full Compilation & Packaging) |
| **البيانات المستخدمة** | البيانات التشغيلية الحقيقية المباشرة | البيانات التشغيلية المحفوظة مع الحزمة |
| **المثبت و GitHub** | لا يوجد أي مثبت ولا علاقة بـ GitHub | توليد Setup Installer ومزامنة `version.json` |
| **قاعدة الأمان** | تشغيل `python scripts/daily_backup.py --test` قبل التعديل | نسخ احتياطي مؤرخ آلي يسبق التجميع |
