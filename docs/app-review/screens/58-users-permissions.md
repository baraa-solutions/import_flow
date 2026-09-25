# إدارة المستخدمين والصلاحيات (Users & Permissions)
![](../screenshots/58-users-permissions-main.png)

> التصوير اتعمل على **Flutter Web (release)** على قاعدة scratch فيها 4 مستخدمين من الـ seed + مستخدم المراجعة (Review Admin).

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** إدارة حسابات المستخدمين: إضافة، وتعديل البيانات والدور وكلمة المرور، وتفعيل وتعطيل الحساب، وإدارة الصلاحيات التفصيلية لكل مستخدم (دور RBAC + صلاحيات إضافية أو ممنوعة).
- **المستخدمين:** مسؤول النظام (ADMIN)، ومدير العمليات (MANAGER) للعرض.
- **المرحلة:** إدارة نظام. مالهاش BP/MD.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "إدارة المستخدمين والصلاحيات" (index 66). بتظهر لـ ADMIN أو MANAGER بس (`home_screen.dart:1017`).
- **Scaffold:** `Scaffold` بهيدر مخصص (أيقونة، وعنوان، و"التحكم في حسابات المستخدمين — 5 مستخدم مسجل"، وتحديث، و"مستخدم جديد").
- **الصلاحية في الباك إند** (`modules/auth/router.py`):
  - `GET /auth/users`، و `/auth/roles`، و `/auth/permissions`، و `/auth/users/{id}/permissions`: صلاحية `users.view`.
  - `POST /auth/register`، و `PATCH /auth/users/{id}`، و `PATCH /auth/users/{id}/toggle-status`، و `PUT /auth/users/{id}/permissions`: صلاحية `users.manage`.
- **في الواجهة:** أزرار الصف بتظهر للـ ADMIN بس (`isAdmin`). وزرار التعطيل مش بيظهر في صف المستخدم الحالي (`isSelf`، `users_management_screen.dart:1226` و `:1273`).
- **تحميل البيانات:** `initState` بيجيب المستخدمين والأدوار (`:28-31`).

## مكونات الشاشة

### الحقول
**الشاشة:**
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بالاسم، اسم المستخدم، أو البريد | TextField | لا | — | فلترة محلية |
| فلتر الدور (الكل / مدير نظام / مدير عمليات / أخصائي) | Chips | — | — | محلي |
| Chips العدادات (الكل 5، نشط 5، مدير نظام 2، مدير عمليات 1، أخصائي 2) | Chips عرض وفلترة | — | — | محسوبة من القائمة |

**Dialog "إضافة مستخدم جديد" / تعديل** (`_showUserDialog`، `users_management_screen.dart:83`):
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| الاسم الكامل * | TextFormField | نعم | مش فاضي ← "يرجى إدخال الاسم الكامل" (`:137`) | يدوي |
| اسم المستخدم * | TextFormField | نعم | مش فاضي، و 3 حروف على الأقل (`:167-170`) | يدوي |
| البريد الإلكتروني * | TextFormField | نعم | مش فاضي، وفيه `@` و `.` (`:200-203`) | يدوي |
| الدور والصلاحيات * | `DropdownButtonFormField<String>`: ADMIN / MANAGER / OPERATOR (افتراضي أخصائي استيراد) | نعم | مش null (`:242`) | **قائمة ثابتة في الكود** (`:209-243`) |
| كلمة المرور * (عند الإضافة) / كلمة مرور جديدة (عند التعديل) | TextFormField مخفي | عند الإضافة بس | مطلوبة في الإضافة، و 6 حروف على الأقل (`:261-264`) | يدوي |
| كارت وصف الدور | عرض | — | — | `_RoleDescriptionCard(role)` |

**Dialog إدارة الصلاحيات** (`_showUserPermissionsDialog`، `:450`): اختيار دور RBAC بـ `DropdownButtonFormField<int?>` (`:605`، من `/auth/roles`)، وشبكة صلاحيات لكل موديول (منح / منع)، و"حفظ الصلاحيات" **فيه loading** (`isSaving`، `:799-848`).

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| مستخدم جديد | بيفتح dialog الإضافة (`:1042`) | — | ADMIN (في الواجهة) |
| إنشاء المستخدم / حفظ التعديلات | **فيه loading** (spinner، `:340`) | `POST /api/v1/auth/register` / `PATCH /api/v1/auth/users/{id}` | `users.manage` |
| تحديث قائمة المستخدمين (🔄) | إعادة تحميل | `GET /api/v1/auth/users` | `users.view` |
| تصدير جدول / تصدير إكسيل / طباعة تقرير بي دي إف / نسخ الحافظة الشاملة | `UsersManagementExportService.saveUsersTsvToFile` و `saveUsersCsvToFile` و `printOrSaveUsersPdf` و `copyDossierToClipboard` (`:936-981`) | — | الكل |
| ✏️ تعديل بيانات المستخدم | dialog التعديل | `PATCH /api/v1/auth/users/{id}` | `users.manage` |
| 🛡 إدارة الصلاحيات | dialog الصلاحيات | `GET/PUT /api/v1/auth/users/{id}/permissions`، و `GET /auth/roles`، و `GET /auth/permissions` | `users.view` / `users.manage` |
| ⊘ تعطيل الحساب / تفعيل | dialog تأكيد (`_showToggleConfirmDialog`، `:364`) | `PATCH /api/v1/auth/users/{id}/toggle-status` | `users.manage` |
| ⧉ نسخ ملخص السطر | `toRowSummary` للحافظة (`:1228`) | — | الكل |

### الجداول
| العمود | المعنى |
|---|---|
| الإجراءات | تعديل / صلاحيات / تعطيل / نسخ |
| الاسم الكامل | مع أفاتار بلون الدور، و"(أنت)" للمستخدم الحالي |
| اسم المستخدم | @username + نسخ |
| البريد الإلكتروني | + نسخ |
| الدور والصلاحية | Badge: مدير نظام / مدير عمليات / أخصائي |
| الحالة | نشط / معطّل |
| تاريخ الإنشاء | DD/MM/YYYY |

- **الفلاتر:** الدور، والبحث. صف الـ Chips الأول (العدادات) للعرض، والصف التاني (الكل / مدير نظام / مدير عمليات / أخصائي) هو فلتر الدور.
- **في الـ dialog:** تحت الحقول كارت وصف الدور (مثلاً "أخصائي استيراد — صلاحيات تشغيلية" وتحته 5 نقاط بالصلاحيات)، وبيتغير مع اختيار الدور.
- **الترتيب:** حسب الباك إند.

### التابات
مفيش تابات.

### الـ Dialogs
**إضافة مستخدم جديد:**

![](../screenshots/58-users-permissions-dialog-add.png)

**أخطاء الـ validation (إنشاء والفورم فاضي):** "يرجى إدخال الاسم الكامل"، و"اسم المستخدم مطلوب"، و"البريد الإلكتروني مطلوب"، و"كلمة المرور مطلوبة". الدور عنده قيمة افتراضية.

![](../screenshots/58-users-permissions-dialog-add-validation.png)

Dialogs إدارة الصلاحيات وتأكيد التعطيل **ما اتصوروش**.

### التصدير والطباعة
TSV و CSV (زرار "تصدير إكسيل" بيطلع CSV) و PDF ونسخ Dossier. الحفظ عن طريق `FileSaveHelper.saveText` (`users_management_export_service.dart:144` و `:164`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | الباك إند مش بيفرض أي طول أدنى لكلمة المرور (`password: str`). شرط الـ 6 حروف في الواجهة بس، فأي API client يقدر يعمل مستخدم بباسورد حرف واحد | `modules/auth/schemas.py:15` و `:24`؛ `users_management_screen.dart:263` | `Field(min_length=8)` + validator للتعقيد في الـ schema |
| Medium | الدور في dialog الإضافة قائمة ثابتة (ADMIN/MANAGER/OPERATOR) بـ `DropdownButtonFormField`، مع إن فيه جدول أدوار RBAC (`GET /auth/roles`) والباك إند بيعترف بأدوار زي `GENERAL_MANAGER`. ودور الـ RBAC في dialog الصلاحيات برضه `DropdownButtonFormField` مع إنه بيانات مرجعية | `users_management_screen.dart:209-243` و `:605`؛ `modules/lifecycle_board/service.py:852` | هات الأدوار من `/auth/roles` واستخدم `SearchableDropdownField` |
| Low | Badge "الدور والصلاحية" بيتمد جوه عمود "الحالة" وبيلزق في Badge "نشط" | `58-users-permissions-main.png` | حدد عرض العمود أو استخدم `Flexible` مع `maxWidth` |
| Low | التحقق من الإيميل ضعيف (`contains('@') && contains('.')`) | `users_management_screen.dart:202` | Regex بسيط، أو `EmailStr` في الباك إند |
| Low | الهيدر مخصص ومفيهوش "العودة للداش بورد" (Type B) | `58-users-permissions-main.png` | استخدم `PageHeader` + `BackToDashboardButton` |
| Low | زرار التأكيد في dialog التعطيل/التفعيل بيقفل الـ dialog الأول (`Navigator.pop`) وبعدين ينادي `toggleUserStatus`، فمفيش أي مؤشر تحميل لحد ما الـ SnackBar يظهر | `users_management_screen.dart:420-442` | ضيف `isLoading` واقفل الزرار أثناء الطلب |
| Low | 20 سطر فيه زرار Material مباشر وحوالي 68 استخدام لـ `Colors.*` | `users_management_screen.dart` | `AppButton` و `AppTheme` |
