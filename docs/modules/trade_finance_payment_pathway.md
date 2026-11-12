# مسار الدفع الحصري للشحنة (Exclusive Payment Pathway)

> Trello: [UQdbFB3O](https://trello.com/c/UQdbFB3O). الكود: `modules/trade_finance/payment_pathway.py`.

## القاعدة

كل ملف استيراد له **مسار دفع رئيسي واحد** محفوظ في `import_files.payment_term`:

| Code | المسار | أداة التمويل المسموحة | أنواع طلبات الصرف المسموحة |
|---|---|---|---|
| `ADVANCE_PAYMENT` | دفعة مقدمة / سويفت (MT103) | `ADVANCE_PAYMENT` | `ADVANCE_PAYMENT`, `AGAINST_BL`, `FINAL_SETTLEMENT` |
| `LC` | اعتماد مستندي (MT700) | `LC` | `LETTER_OF_CREDIT`, `FINAL_SETTLEMENT` |
| `CAD` | تحصيل مستندي (D/P, D/A) | `CAD` | `DOCUMENTARY_COLLECTION`, `FINAL_SETTLEMENT` |
| `OPEN_ACCOUNT` | حساب مفتوح / دفع آجل | `OPEN_ACCOUNT` | `FINAL_SETTLEMENT` |

## كيف يتحدد المسار (GP-001: إدخال تدريجي)

1. صراحةً من شاشة ملف الاستيراد.
2. بالوراثة من أوامر الشراء المرتبطة (`purchase_orders.payment_terms`) لو كلها تشير لنفس المسار.
3. تلقائياً عند أول أداة تمويل أو أول طلب صرف يحدد مساراً (`FINAL_SETTLEMENT` وحده لا يحدد مساراً).

## الحماية

**على مستوى التطبيق:**
- `PAYMENT_PATHWAY_CONFLICT` (409): أداة تمويل أو طلب صرف من مسار مختلف عن مسار الملف.
- `PAYMENT_INSTRUMENT_ALREADY_OPEN` (409): يوجد أداة تمويل رئيسية نشطة (غير ملغاة) للملف بالفعل.
- `PAYMENT_PATHWAY_LOCKED` (409): محاولة تغيير مسار الملف مع وجود تمويل قائم على المسار الحالي.

**على مستوى قاعدة البيانات** (migration `a7c1e9d3f5b2`):
- `ck_import_files_payment_term`: القيم المسموحة فقط أو `NULL`.
- `uq_finance_instrument_active_per_file`: unique index جزئي على `import_finance_instruments(import_file_id)` للأدوات النشطة غير الملغاة.
  لو قاعدة البيانات فيها ملفات بأكثر من أداة نشطة وقت الترقية، الـ index لا يُنشأ وتُطبع أرقام الملفات، ويستمر الحارس البرمجي في منع أي تعارض جديد.

## ملاحظة عن "الازدواج في تكلفة البضاعة"

التسوية الحالية (`financial_settlement/actual_settlement_service.py`) تحسب قيمة البضاعة من `invoices_data`، والمدفوع من طلبات الصرف بحد أقصى قيمة الفاتورة، ولا تجمع مبالغ الاعتمادات. يعني الازدواج الحسابي الموصوف في الكارت لا يحدث حالياً في الـ Landed Cost. الخطر الفعلي كان تشغيلياً ومصرفياً: فتح اعتماد وتحويل سويفت لنفس الفاتورة. وده اللي القاعدة دي بتمنعه.

## خارج النطاق (مهام لاحقة)

- واجهة Flutter: اختيار المسار في ملف الاستيراد، وتعطيل التبويبات غير المتوافقة في شاشات Finance Approvals و Trade Finance.
- سير عمل CAD (البنك المحصّل، D/P و D/A، الإفراج عن المستندات) و Open Account (تواريخ الاستحقاق).
- ربط المسار بنموذج 4 البنكي.
