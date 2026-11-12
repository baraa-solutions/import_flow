# محرك تقييم الفوب الصافي الموحد وسياسة تثبيت سعر الصرف (Trello qJZNzixC)

`modules/financial_settlement/fob_valuation_service.py` هو المصدر الوحيد لقيمة البضاعة (Net FOB) في ملف الشحنة.
كل المستهلكين (تسوية الفواتير CLO-01، تكلفة الوصول الفعلية CLO-02، المحاكاة التقديرية PL-08، الوعاء الجمركي) بيقروا قيمة البضاعة منه.

## الفوب الصافي

لكل فاتورة تجارية في `import_files.invoices_data` (بعملة الفاتورة):

```text
gross_amount (amount)          إجمالي الفاتورة قبل الخصم
- discount_amount              خصم تجاري من المورد
- financing_markup_amount      فوائد / هامش تمويل المورد (آجل) مضمن في السعر
= net_fob_foreign              قيمة البضاعة: هي الوحيدة اللي بتدخل صف "Commercial Goods" والوعاء الجمركي

payable_foreign = net_fob_foreign + financing_markup_amount   (اللي بيتدفع للمورد فعلاً)
```

الحقلين `discount_amount` و`financing_markup_amount` اختياريين (الافتراضي صفر، فالملفات القديمة ما بتتغيرش).
هامش التمويل تكلفة على المستورد: بيظهر في التسوية كصف مستقل `Supplier Financing Markup` (بند Other & Admin في تكلفة الوصول)، لكنه **مستبعد** من قيمة الفوب ومن الوعاء الجمركي والضريبي.
خصم أو هامش سالب، أو أكبر من إجمالي الفاتورة → 422 `FOB_NET_VALUE_INVALID`.

## سياسة تثبيت سعر الصرف (FX Anchor Policy)

| الرقم | السعر المطبق |
|---|---|
| قيمة البضاعة المحاسبية / تكلفة الوصول | سعر الحدث المالي لمسار الدفع الحصري (`payment_term`) |
| الوعاء الجمركي | سعر الجمارك الساري في تاريخ الإقرار 46 (`form46_date`، PR #211) × الفوب الصافي |
| الحساب المفتوح قبل السداد | إعادة تقييم Mark-to-Market بسعر اليوم التجاري: **غير محقق**، للعرض واللقطة فقط |

مصدر السعر لكل عملة بالترتيب:
1. حجوزات العملة (`fx_hedging_and_variance`) لأداة التمويل النشطة للملف، بسعر **الحجز** (`booking_rate`):
   LC → `LC_MARGIN_COVER`، CAD → `CAD_DOCUMENT_PAYMENT`.
2. طلبات الصرف المسددة (`paid_amount_egp / swift_transferred_amount`): ADVANCE_PAYMENT → `SWIFT_REMITTANCE`،
   OPEN_ACCOUNT → `OPEN_ACCOUNT_SETTLEMENT`.
3. الجزء اللي ما يغطيهوش حدث مالي: سعر الفاتورة المخزن (`INVOICE_RATE`)، وإلا السعر التجاري في تاريخ الفاتورة (`COMMERCIAL_RATE`). الفاتورة المغطاة جزئياً مصدرها `MIXED`.

التغطية بتتوزع على الفواتير بترتيبها، والسعر المثبت هو المتوسط المرجح للأحداث.

**ليه سعر الحجز؟** صف "Realized FX Variance" (PR #212) = `settlement_total - booking_total`. لما البضاعة تتقيم بسعر الحجز يبقى:
`البضاعة + فرق العملة = البضاعة بسعر التسوية` بالظبط. قبل كده البضاعة كانت بسعر الفاتورة، فالفرق بين سعر الفاتورة وسعر الحجز كان بيضيع أو بيتحسب مرتين.

مثال: فاتورة 10,000 دولار بسعر مخزن 48، حجز الاعتماد 50، التسوية 52:
`البضاعة 500,000 + فرق العملة 20,000 = 520,000 = 10,000 × 52`.

## ضمان عدم الازدواج (Zero Double Counting)

- فاتورة متسجلة مرتين (نفس الرقم ونفس العملة) بتتحسب مرة واحدة، مع رسالة `FOB_DUPLICATE_INVOICE_IGNORED`.
- قيمة البضاعة موجودة في صف `Commercial Goods` واحد لكل فاتورة. مدفوعات المورد (SWIFT) بتسدد الصف ده بس، وعمرها ما بتضاف كتكلفة.
- `ensure_no_fob_double_count` بتراجع دفتر التسوية مقابل التقييم (مجموع البضاعة ومجموع الهامش). أي اختلاف → 409 `FOB_DOUBLE_COUNT_DETECTED`.
- CLO-02 بيعتبر صف بضاعة **بس** الصف اللي `category == "Commercial Goods"` و`source_module == "Commercial Invoice"`. قبل كده أي مصروف كلمة "goods" أو "commercial" في وصفه كان بيتحسب فوب.
- `fx_difference_egp` (ACC2-T07) لسه للعرض بس، وبقى داخل صف البضاعة نفسه (الجزء المسدد بقى بخصم البنك الفعلي).

## اللقطة المحفوظة (import_files)

`fob_currency`، `fob_foreign_amount`، `fob_exchange_rate`، `fob_total_egp`، `financing_markup_amount`، `financing_markup_egp`،
`fob_rate_source`، `fob_rate_date`، `fob_customs_exchange_rate`، `fob_customs_value_egp`، `fob_unrealized_fx_egp`، `fob_valued_at`، `fob_valued_by`.
Alembic `c4e8a2f6b1d9`، فيها CHECK إن القيم مش سالبة والسعر أكبر من صفر.
في الملف متعدد العملات، العملة والمبلغ الأجنبي والسعر بيبقوا NULL، و`fob_total_egp` هو مجموع الجنيه.

اللقطة بتتكتب عند: اعتماد تسوية الفواتير (CLO-01)، واعتماد تكلفة الوصول (CLO-02)، و`POST /revalue`.

## API

- `GET /api/v1/financial-settlement/fob-valuation/{import_file_id}`: التقييم بس، من غير حفظ (`financial_settlement.view`).
- `POST /api/v1/financial-settlement/fob-valuation/{import_file_id}/revalue`: بيقيّم ويحفظ اللقطة، ومنها إعادة تقييم الحساب المفتوح (`financial_settlement.calculate`).
