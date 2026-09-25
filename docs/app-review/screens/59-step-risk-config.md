# إعدادات تصنيف مخاطر المراحل وحوكمة التخطي (Step Risk & Skip Config)
![](../screenshots/59-step-risk-config-main.png)

> التصوير اتعمل على **Flutter Web (release)** بمستخدم ADMIN. الإعدادات اللي ظاهرة هي القيم الافتراضية من الـ seed (كل الخطوات "محظورة نهائياً"، والمعتمد Manager).

## الغرض والمستخدمين والمرحلة (BP/MD)
- **الغرض:** تحديد سياسة التخطي لكل خطوة من الـ 25 خطوة في دورة الحياة (Addendum Section 10):
  - **سياسة التخطي:** محظورة نهائياً (blocked)، أو موافقة واحدة (single_approval)، أو موافقة مزدوجة (dual_approval).
  - **الأدوار المعتمدة** للموافقة على التخطي.
  - **مرجع معلق:** هل الخطوة ينفع تتقفل برقم مرجعي هيتسجّل بعدين.
  - **أسباب التخطي:** فئات الأسباب المسموحة (4 فئات).
  - ولكل تعديل **سجل تدقيق رقابي**.
- **المستخدمين:** المدير والإدارة العليا (Governance).
- **المرحلة:** حوكمة لكل المراحل (P1–P6). مالهاش BP code مباشر.

## طريقة الوصول والصلاحية
- **Sidebar:** "لوحة القيادة والتقارير والرقابة" ← "إعدادات تصنيف مخاطر المراحل وحوكمة التخطي" (index 67). بتظهر بس لو `user.canManageStepConfig` (ADMIN أو MANAGER، `home_screen.dart:1020`).
- لو مستخدم ملوش صلاحية فتح الشاشة، بتظهر رسالة "غير مصرح"، وفي وضع debug بس زرار تبديل لدور Manager تجريبي (`step_config_management_screen.dart:112`، محمي بـ `kDebugMode`).
- **الباك إند:** `PUT /lifecycle-board/step-configs/{code}` بيتحقق في الـ service إن الدور MANAGER أو GENERAL_MANAGER أو ADMIN (`modules/lifecycle_board/service.py:851-856`). والقراءة لأي مستخدم مسجّل.

## مكونات الشاشة

### الحقول
**الشاشة:**
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| بحث بكود الخطوة أو الاسم أو السياسة | TextField | لا | — | فلترة محلية |
| فلتر المرحلة: الكل (25 خطوة)، المرحلة 1 … المرحلة 6 | FilterChips | — | — | `notifier.setFilterPhase` (`:286-298`) |

**Dialog "تعديل السياسة والتصنيف"** (`_showEditDialog`):
| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| سياسة التخطي | `DropdownButtonFormField<String>`: blocked / single_approval / dual_approval | نعم | — | ثابت (`:886-910`) |
| تسمح بمرجع معلق | `SwitchListTile` | — | — | `supports_pending_reference` |
| الأدوار المعتمدة للتخطي | FilterChips: `Manager`، `ADMIN`، `ComplianceHead` | — | — | **قائمة ثابتة في الكود** (`:961`) |
| مبرر التعديل (Justification) | TextFormField | نعم | validator `stepConfigJustificationValidator` (`:1025-1030`) | يدوي، وبيتسجّل في سجل التدقيق |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تحديث البيانات (🔄) | إعادة تحميل | `GET /api/v1/lifecycle-board/step-configs` | مسجّل |
| تصدير جدول / تصدير إكسيل / تقرير بي دي إف / نسخ ملف الحافظة | `StepConfigExportService.saveTsvToFile` و `saveCsvToFile` و `printOrSavePdf` و `copyDossierToClipboard` (`:311-355`) | — | الكل |
| ⧉ نسخ ملخص الخطوة | `toRowSummary` (`:514`) | — | الكل |
| ✎ تعديل السياسة والتصنيف | dialog التعديل. "حفظ" **فيه loading** (`state.isSaving`، `:1046-1056`) | `PUT /api/v1/lifecycle-board/step-configs/{stepCode}` | MANAGER/GENERAL_MANAGER/ADMIN |
| ⟲ سجل تدقيق التغييرات الرقابية | `_showAuditDialog` | `GET /api/v1/lifecycle-board/step-configs/{stepCode}/audit-logs` | مسجّل |
| شارة كود الخطوة (STEP_01…) | نسخ الكود | — | الكل |

- **الهيدر:** أيقونة، والعنوان، والوصف "إدارة ديناميكية مركزية لسياسات تخطي المراحل وإسناد المراجع المعلقة دون تعديل الكود"، وزرار تحديث بس.

### الجداول
| العمود | المعنى |
|---|---|
| الإجراءات | نسخ / تعديل / سجل التدقيق |
| المرحلة والكود | P1..P6 + STEP_XX |
| اسم الخطوة | Freight Studies، Customs Studies، … |
| سياسة التخطي | Badge: محظورة نهائياً / موافقة واحدة / موافقة مزدوجة |
| الأدوار المعتمدة | مثلاً Manager |
| مرجع معلق | متاح / غير متاح |
| أسباب التخطي | عدد الفئات (4 فئات) |
| آخر تعديل | المستخدم (SYSTEM) والتاريخ |

- **الفلاتر:** المرحلة، والبحث.
- **الترتيب:** حسب ترتيب الخطوات.

### التابات
مفيش تابات.

### الـ Dialogs
"تعديل السياسة والتصنيف" و "سجل تدقيق التغييرات الرقابية". **ما اتصوروش**: الـ harness ما لقاش زرار إضافة (`capture-manifest.json`: "no add/create button found").

### التصدير والطباعة
TSV و CSV و PDF ونسخ Dossier. الحفظ عن طريق `FileSaveHelper.saveText` (`step_config_export_service.dart`).

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| Medium | الأدوار المعتمدة للتخطي قائمة ثابتة في الكود (`Manager`، `ADMIN`، `ComplianceHead`)، و `ComplianceHead` مش موجود كدور في موديول الصلاحيات، فمفيش مستخدم هيقدر يتعمد بيه (الـ service بيعمل `upper()` للاتنين، فاختلاف حالة الأحرف Manager/ADMIN مش مشكلة) | `step_config_management_screen.dart:961`؛ `modules/lifecycle_board/service.py:1053-1054` | هات الأدوار من `GET /auth/roles` |
| Low | أسماء الخطوات والدور "Manager" بالإنجليزي وسط واجهة عربية. الأسماء جاية من الباك إند من غير ترجمة | `59-step-risk-config-main.png` | اعرض الاسم عن طريق `DisplayNameResolver.resolveStepName` مع لغة `localeProvider` |
| Low | Chip "المرحلة 6" مش ظاهر في مقاس 1600px (الـ chips في `SingleChildScrollView` أفقي من غير أي مؤشر scroll)، فالمستخدم ممكن يفتكر إن فيه 5 مراحل بس | `59-step-risk-config-main.png`؛ `step_config_management_screen.dart:280-298` | `Wrap` بدل scroll أفقي، أو scrollbar ظاهر |
| Low | 55 لون `Color(0x..)` ثابت و 14 زرار Material مباشر، وسياسة التخطي `DropdownButtonFormField` | `step_config_management_screen.dart` (مثلاً `:106`)؛ `:886` | `AppTheme` و `AppButton` و `SearchableDropdownField` |
| Low | الهيدر مخصص ومفيهوش "العودة للداش بورد" | `59-step-risk-config-main.png` | `PageHeader` + `BackToDashboardButton` |
