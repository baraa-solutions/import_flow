# منظومة كارجو إكس والمانيفست الرقمي (CargoX Blockchain & ACI Hub)
![](../screenshots/34-cargox-hub-main.png)

## الغرض والمستخدمين والمرحلة (BP/MD)
مركز التبادل الإلكتروني للمستندات من خلال منصة CargoX (بلوك تشين) ومنظومة ACI / نافذة. الشاشة بتعمل 4 حاجات:
1. **الفاتورة المعيارية:** بتولّد نموذج Excel موحد بنطاقات مسمّاة (named ranges) يتبعت للمورد، وبعدين ترفع الملف بعد ما المورد يملاه وتستخرجه، وتطابقه مع بيانات السستم، وتطلع الفروق الجمركية قبل إرسال المظروف.
2. **تجهيز المظروف:** بتنشئ مظروف CargoX للشحنة (ACID، ورقم البوليصة، والمستورد، والمورد، ومعرّف المورد على CargoX، والمستندات المرفقة) وتوقّعه.
3. **تتبع البلوك تشين:** بتتابع المظاريف، وتتحقق من اتساق الـ ACID، وتختم المظروف وتحوّله للجمارك.
4. **المانيفست الرقمي:** بتعرض المانيفست الرقمي (ACI) للمظروف وتصدّره.

- **المستخدمين:** موظف التوثيق، والمخلص.
- **المرحلة:** المرحلة 4 (`stageCode: 'PHASE-4: STEP_11'`، `cargox_hub_screen.dart:401`، ودي بتظهر بس لو الشاشة شغالة لوحدها).
- **الكود:** `BP-024` (Electronic Document Exchange - CargoX Integration) و `BP-025` (Link Shipping Documents to ETMS & Tracking).

## طريقة الوصول والصلاحية
- **الوصول:** التاب الرأسي التاني "CargoX Blockchain & ACI Hub" جوه الشاشة الأم (والتاب الأول "Original Docs Collection & Courier" متشرح في `33-original-docs-cargox.md`). كتاب متضمّن (`isEmbedded: true`) جوه "أصول المستندات ومنظومة CargoX الرقمية" (شاشة 33). الـ sidebar index 54 بيفتح عليها على طول. وكمان بتظهر جوه `CargoXHubDialog` (`cargox/widgets/cargox_hub_dialog.dart`).
- **الصلاحية:** أي مستخدم عامل login (`modules/cargox/router.py:22`). الختم والتحويل للجمارك (`POST /envelopes/{id}/seal-and-transfer`، `router.py:85`) من غير RBAC.

## مكونات الشاشة
في الوضع المتضمّن الشاشة `Column`، وفوقها شريط segmented للأربع تابات الداخلية: "منظومة كارجو إكس والبلوك تشين: الفاتورة المعيارية | تجهيز المظروف | تتبع البلوك تشين | المانيفست الرقمي". وجوه تاب الفاتورة المعيارية فيه قايمة رأسية تانية (`standard_invoice_hub_tab.dart`).

### الحقول
**تاب الفاتورة المعيارية** (`34-cargox-hub-tab-1-standard-commercial-invoice.png`):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| اختيار ملف الشحنة الاستيرادية * | `SearchableDropdownField` (الـ hint: "ابحث برقم الملف، رقم القيد الجمركي، اسم المورد أو الشركة...") | نعم | — | `GET /import-files`. في الصورة **فاضي** |

**تاب تجهيز المظروف** (من الكود، `_buildCreateEnvelopeTab`، `:443`، ومتصورش):

| الحقل | النوع | إلزامي | التحقق | مصدر البيانات |
|---|---|---|---|---|
| رقم ACID | `TextFormField` | نعم | لازم 19 رقم بالظبط (`cargoxAcidValidationDigits`، `:542-545`) | من الملف |
| رقم البوليصة | `TextFormField` | — | — | من الملف أو الحجز |
| الشركة المستوردة | `TextFormField` **نص حر** | نعم | غير فاضي (`:569-573`) | من الملف، ومش dropdown |
| المورد الأجنبي | `TextFormField` **نص حر** | نعم | غير فاضي (`:581-585`) | من الملف، ومش dropdown |
| معرّف المورد على CargoX | `TextFormField` | نعم | غير فاضي | من المورد |
| المستندات المرفقة | قايمة افتراضية (Commercial Invoice، Packing List، B/L، COO/EUR.1) (`_initDefaultAttachedDocs`، `:118`) | — | — | ثابتة، أو من الملف (`:277-301`) |

### الأزرار والإجراءات
| الزرار | بيعمل إيه | endpoint | الصلاحية |
|---|---|---|---|
| تحديث (في تاب الفاتورة) | `_refreshData` (`:155`) | `GET /cargox/envelopes`، `/import-files` | — |
| تحميل نموذج إكسيل الموحد | بيولّد النموذج | `GET /api/v1/cargox/standard-invoice/generate/{fileId}` (أو `generate-zip` / `generate-dual-zip`) | — |
| رفع وقراءة فاتورة المورد | استخراج | `POST /cargox/standard-invoice/extract/{fileId}` أو `extract-dual`، وبعدها `POST /cargox/standard-invoice/compare/{fileId}` | — |
| القايمة الداخلية: بيانات الفاتورة المستخرجة / مصفوفة المطابقة والفروق / الاعتماد والتحكم الجمركي / سجل الفواتير المعيارية / المسارات الجمركية | عروض جوه `standard_invoice_hub_tab.dart` | `/cargox/standard-invoice/session*`، و `/cargox/customs-track/*` | — |
| استخلاص وتدقيق المستندات الذكي | `SmartInvoiceBLExtractorDialog` | `/smart-upload` | — |
| إضافة مستند للمظروف | `_showAddDocumentDialog` (`:808`) | — | — |
| استعادة المستندات الافتراضية | `_initDefaultAttachedDocs` | — | — |
| توليد وتوقيع المظروف / حفظ كمسودة | `_submitCreateEnvelope` (`:857`) | `POST /api/v1/cargox/envelopes` | أي مستخدم |
| فحص الـ ACID (في كارت المظروف) | `_runAcidVerification` (`:1350`) | `POST /cargox/envelopes/{id}/verify-acid` | — |
| ختم وتحويل للجمارك | `_sealAndTransfer` (`:1398`)، وقبله تأكيد | `POST /cargox/envelopes/{id}/seal-and-transfer` | أي مستخدم |
| المانيفست الرقمي | `_viewManifest` (`:1447`) | `GET /cargox/envelopes/{id}/digital-manifest` | — |
| TSV / "تصدير إكسيل مظاريف الشحنات" / "طباعة تقرير المظاريف" / نسخ الملف الكامل | `CargoXExportService` (`:985-1040`) | Client، ومنه لـ `FileSaveHelper` | — |
| حذف / استرجاع مظروف | — | `DELETE /cargox/envelopes/{id}`، `POST .../restore` | أي مستخدم |

### الجداول
- **بطاقات مؤشرات المظاريف وكروت المظاريف** (`_buildMetricCard`، `_buildEnvelopeCard`، `:1072-1300`): رقم المظروف، والـ ACID، ورقم البوليصة، والحالة، والـ tx hash، وإيصال الجمارك. متصورش.
- **سجل الفواتير المعيارية / المسارات الجمركية:** جوه `standard_invoice_hub_tab.dart`. متصورش مليان لأن الملف مش متختار. الحالة الفاضية ظاهرة: "لم يتم رفع وقراءة ملف فاتورة المورد بعد."

### التابات
1. **الفاتورة المعيارية:** `34-cargox-hub-main.png` / `34-cargox-hub-tab-1-standard-commercial-invoice.png`.
2. **تجهيز المظروف:** مفيش صورة. الـ harness دوّر على الـ label الطويل "تجهيز وتوليد المظروف" بس اللي ظاهر فعلاً في الواجهة "تجهيز المظروف" (`capture-manifest.json` issues). يعني ده فرق في التسمية بين الـ inventory والواجهة، مش عيب في التطبيق.
3. **تتبع البلوك تشين:** مفيش صورة، لنفس السبب (الـ label المتوقع كان "مركز تتبع أظرف البلوك تشين").
4. **المانيفست الرقمي:** `34-cargox-hub-tab-4-aci-digital-manifest-viewer.png`. حالة فاضية: "يرجى اختيار مظروف من مركز التتبع لعرض المانيفست الرقمي الخاص به".

### الـ Dialogs
- **إضافة مستند للمظروف** (`_showAddDocumentDialog`، `:808`، متصورش): نوع المستند، ورقم المستند، واسم الملف (القيمة الافتراضية `'Analysis_Report.pdf'`، `:811`). كلهم `TextField` من غير أي تحقق (`:823`). والأزرار: إلغاء، وإضافة.
- **تأكيد الختم والتحويل** (`:1398-1425`)، و `SmartInvoiceBLExtractorDialog`: متصوروش.
- مفيش dialog إضافة على مستوى الشاشة (`capture-manifest.json`: "no add/create button found")، فمفيش صورة validation.

### التصدير والطباعة
- المظاريف: TSV، و "إكسيل" (وده في الحقيقة CSV: `saveEnvelopesCsvToFile`)، و PDF، ونسخ الملف الكامل. كله عن طريق `CargoXExportService` وبعده `FileSaveHelper`.
- الفاتورة المعيارية: تنزيل نموذج Excel و ZIP (الـ backend)، و `customs-track/{id}/export-excel` و `export-packing-list-excel`.

## ملاحظات المراجعة
| الخطورة | الملاحظة | الدليل: صورة أو ملف:سطر | الاقتراح |
|---|---|---|---|
| High | تكامل CargoX محاكاة كاملة، لكن الواجهة بتقدمه على إنه حقيقي. `transfer_envelope_to_customs` دايماً بيرجع `TRANSFERRED_TO_EGYPTIAN_CUSTOMS` وإيصال عشوائي، وكمان tx hash عشوائي (`uuid4`)، ومن غير أي استدعاء شبكة، وده في كل الـ modes. المستخدم بيشوف SnackBar نجاح (`cargoxSealSuccessSnackbar`) فيه رسالة الـ backend "…successfully transferred to Egyptian Customs"، والمستندات ما اتبعتتش فعلاً | `modules/integrations/cargox_client.py:14-16`، `:51-67`، `modules/cargox/service.py:190-218` | علامة "وضع تجريبي / MOCK" واضحة في الواجهة، ومنع "ختم وتحويل" في الإنتاج لحد ما التكامل الحقيقي يتنفذ |
| Medium | الشركة المستوردة والمورد الأجنبي في فورم المظروف `TextFormField` نص حر بدل `SearchableDropdownField` مربوط بالـ Master Data | `cargox_hub_screen.dart:566-586` | `SearchableDropdownField` على `/import-companies` و `/suppliers` |
| Medium | dialog إضافة مستند كل حقوله نص حر من غير validation، واسم الملف الافتراضي `Analysis_Report.pdf`، فممكن يضيف مستند فاضي أو باسم غلط | `cargox_hub_screen.dart:808-850` | `Form` و validators، ونوع المستند من قايمة |
| Medium | ملف الشحنة مش متختار في تاب الفاتورة المعيارية (الـ dropdown فاضي)، مع إن الشاشة الأم بتحدد أول ملف | `34-cargox-hub-main.png` | التأكد إن `initialImportFileId` بيوصل (`didUpdateWidget`، `:86`) |
| Medium | 3 مستويات تنقل متداخلة: تابات رأسية في الشاشة الأم، وفوقها segmented بـ 4 تابات، وجواهم قايمة رأسية بـ 5 عناصر. ده بيصعّب الوصول وبيخلي المساحة ضيقة | `34-cargox-hub-main.png` | دمج المستويات، أو تحويل الفاتورة المعيارية لشاشة لوحدها |
| Low | زرار "تصدير إكسيل مظاريف الشحنات" بيحفظ CSV مش xlsx | `cargox_hub_screen.dart:1004-1009` (`saveEnvelopesCsvToFile`) | label صحيح، أو تصدير xlsx |
| Low | token افتراضي مكتوب في الكود `"CARGOX_DEMO_TOKEN_2026"` كـ fallback لـ `CARGOX_API_TOKEN` | `modules/integrations/cargox_client.py:16` | يفشل بشكل صريح لو المتغير مش موجود في غير وضع MOCK |
| Low | مخالفات UI: 16 `ElevatedButton`، و 51 `Colors.xxx` (منهم `Colors.purple` لزرار PDF) | `cargox_hub_screen.dart:1018` | `AppButton` و `AppTheme` |
| Low | الـ header بتاع الشاشة الأم بالإنجليزي ومكسور على سطرين، ونص الـ label والـ hint راكبين على بعض في dropdown الملف. ده من مشكلة الـ locale المعروفة ومن `SearchableDropdownField` | `34-cargox-hub-main.png` | — |
| Low | console (ويب بس): `Refused to set unsafe header "Accept-Encoding"` | `runtime-errors.json` ← `34-cargox-hub` | — |
