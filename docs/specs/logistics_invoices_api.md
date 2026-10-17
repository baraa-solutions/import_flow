# REST API Reference: Logistics Service Invoices & Payments (LSI)
## توثيق الواجهات البرمجية (Endpoints, Payloads & Responses)

Prefix: `/api/v1/logistics-invoices`  
Tag: `Logistics Service Invoices & Payments`  
Auth: Bearer JWT Token (`Depends(get_current_user)`)

---

## 1. فواتير الخدمات اللوجستية (Service Invoices)

### `POST /api/v1/logistics-invoices`
- **الوصف:** إنشاء مسودة فاتورة خدمة لمقدم خدمة لوجستية (شحن، تخليص، فحص، تأمين).
- **الصلاحية المطلوبة:** `financial_approval.manage`
- **كود النجاح:** `201 Created`
- **نموذج الطلب (Request Body):** `LogisticsInvoiceCreate`
  ```json
  {
    "shipment_id": 1,
    "bl_number": "MSCU98765432",
    "partner_id": 1,
    "partner_type": "freight",
    "partner_name": "MSC Mediterranean Shipping Co.",
    "invoice_number": "INV-MSC-2026-001",
    "invoice_date": "2026-10-10T10:00:00Z",
    "currency": "USD",
    "total_amount_fx": 2500.0,
    "exchange_rate": 48.50,
    "total_amount_egp": 121250.0,
    "vat_included": true,
    "vat_amount": 16975.0,
    "wht_deducted": true,
    "wht_amount": 1212.5,
    "net_payable_egp": 137012.5,
    "lines": [...],
    "containers": [
      { "container_number": "MSCU1112223", "seal_number": "SL-001" }
    ]
  }
  ```
- **نموذج الاستجابة (Response):** `LogisticsInvoiceResponse`

---

### `GET /api/v1/logistics-invoices`
- **الوصف:** استرجاع قائمة الفواتير مع دعم الفلاتر والصفحات.
- **الصلاحية المطلوبة:** `financial_approval.view`
- **البارامترات (Query Parameters):**
  - `shipment_id` (int, optional)
  - `partner_id` (int, optional)
  - `partner_type` (string, optional: `freight`, `clearance`, `inspection`, `insurance`)
  - `status` (string, optional: `DRAFT`, `SUBMITTED`, `APPROVED`, `CANCELLED`)
  - `payment_status` (string, optional: `UNPAID`, `PARTIALLY_PAID`, `FULLY_PAID`)
  - `skip` (int, default: 0)
  - `limit` (int, default: 100)

---

### `GET /api/v1/logistics-invoices/{id}`
- **الوصف:** استرجاع تفاصيل فاتورة محددة بالمعرّف مع البنود والحاويات المرتبطة.
- **الصلاحية المطلوبة:** `financial_approval.view`
- **نموذج الاستجابة:** `LogisticsInvoiceResponse`

---

### `PATCH /api/v1/logistics-invoices/{id}`
- **الوصف:** تحديث بيانات مسودة الفاتورة (لا يمكن التعديل بعد الاعتماد أو الإلغاء).
- **الصلاحية المطلوبة:** `financial_approval.manage`

---

### `POST /api/v1/logistics-invoices/{id}/submit`
- **الوصف:** تقديم الفاتورة للمراجعة والاعتماد المالي (`status: SUBMITTED`).
- **الصلاحية المطلوبة:** `financial_approval.manage`

---

### `POST /api/v1/logistics-invoices/{id}/approve`
- **الوصف:** اعتماد الفاتورة رسمياً وتثبيت قيمتها وإتاحتها للسداد وتغذية تكلفة الوصول (`status: APPROVED`).
- **الصلاحية المطلوبة:** `financial_approval.approve`

---

### `POST /api/v1/logistics-invoices/{id}/cancel`
- **الوصف:** إلغاء الفاتورة وفك قفل الحاويات المرتبطة بها (`status: CANCELLED`).
- **الصلاحية المطلوبة:** `financial_approval.manage`

---

### `GET /api/v1/logistics-invoices/prefill-lines`
- **الوصف:** استرجاع البنود القياسية المهيئة مسبقاً وفقاً لنوع الشريك (21 بنداً للشحن، بنود قائمة التخليص).
- **البارامترات:** `shipment_id` (int), `partner_type` (str)
- **نموذج الاستجابة:** `PrefillLinesResponse`

---

### `GET /api/v1/logistics-invoices/container-lock-status`
- **الوصف:** فحص حالة الحاويات المرتبطة برقم البوليصة والتأكد مما إذا كانت مفوترة مسبقاً.
- **البارامترات:** `shipment_id` (int), `bl_number` (str)
- **نموذج الاستجابة:** `ContainerLockStatusResponse`

---

### `GET /api/v1/logistics-invoices/{id}/three-way-match`
- **الوصف:** تقرير المطابقة الثلاثية بين الفاتورة الفعلية وعرض الأسعار المسجل للشحنة مع بيان الانحرافات.
- **نموذج الاستجابة:** `ThreeWayMatchResponse`

---

## 2. وثائق ومطالبات التأمين البحري (Marine Insurance)

### `GET /api/v1/logistics-invoices/insurance/preview`
- **الوصف:** احتساب القيمة التأمينية التقديرية وقسط التأمين والدمغات ورسم الرقابة طبقاً للقانون المصري ($CIF + 10\%$).
- **البارامترات:** `shipment_id` (int), `premium_rate` (float, default: 0.35), `coverage_type` (str)
- **نموذج الاستجابة:** `InsurancePreviewResponse`

---

### `POST /api/v1/logistics-invoices/insurance/policies`
- **الوصف:** إصدار وثيقة تأمين بحري جديدة للشحنة.
- **الصلاحية المطلوبة:** `cargo_insurance.manage`
- **كود النجاح:** `201 Created`
- **نموذج الاستجابة:** `InsurancePolicyResponse`

---

### `POST /api/v1/logistics-invoices/insurance/policies/{id}/generate-invoice`
- **الوصف:** توليد فاتورة خدمة لوجستية تلقائياً من وثيقة التأمين بضغطة زر واحدة.
- **الصلاحية المطلوبة:** `cargo_insurance.manage`

---

### `POST /api/v1/logistics-invoices/insurance/policies/{id}/claim`
- **الوصف:** قيد وتسجيل مطالبة تأمينية جديدة بخصوص حادث أو تلفيات بالشحنة.
- **الصلاحية المطلوبة:** `cargo_insurance.manage`

---

### `PATCH /api/v1/logistics-invoices/insurance/policies/{id}/claim-status`
- **الوصف:** تحديث حالة المطالبة التأمينية (`filed → under_inspection → accepted → reimbursed / rejected`).
- **الصلاحية المطلوبة:** `cargo_insurance.manage`
- **نموذج الطلب:** `InsurancePolicyClaimStatusUpdate`

---

## 3. العهدة الذكية للمخلص الجمركي (Clearance Advances)

### `POST /api/v1/logistics-invoices/advances`
- **الوصف:** صرف عهدة مالية مقدمة للمخلص الجمركي مرتبطة بالشحنة ورقم البوليصة.
- **الصلاحية المطلوبة:** `financial_approval.manage`
- **كود النجاح:** `201 Created`
- **نموذج الاستجابة:** `ClearanceAdvancePaymentResponse`

---

### `POST /api/v1/logistics-invoices/advances/{id}/settle`
- **الوصف:** تسوية عهدة المخلص مقابل فاتورة تخليص جمركي فعلية مستلمة مع تسوية الفائض أو العجز.
- **الصلاحية المطلوبة:** `financial_approval.manage`
- **نموذج الطلب:** `ClearanceAdvanceSettlementCreate`
- **نموذج الاستجابة:** `ClearanceAdvanceSettlementResponse`

---

### `GET /api/v1/logistics-invoices/advances`
- **الوصف:** استرجاع سجل العهد النقدية ومتابعة المتبقي غير المسوى.
- **البارامترات:** `shipment_id` (int, opt), `partner_id` (int, opt), `status` (str, opt)

---

## 4. أذون الصرف والإقفال (Payment Vouchers & Knock-Offs)

### `POST /api/v1/logistics-invoices/payments`
- **الوصف:** إصدار إذن صرف وسداد لمقدم الخدمة مع تخصيص السداد مقابل فواتير محددة (Knock-off).
- **الصلاحية المطلوبة:** `financial_approval.approve`
- **كود النجاح:** `201 Created`
- **نموذج الطلب:** `LogisticsPaymentVoucherCreate`
- **نموذج الاستجابة:** `LogisticsPaymentVoucherResponse`

---

### `GET /api/v1/logistics-invoices/payments`
- **الوصف:** استرجاع سجل أذون الدفع والسداد للشركاء اللوجستيين.
- **البارامترات:** `partner_id` (int, opt), `shipment_id` (int, opt), `status` (str, opt)

---

## 5. كشف الحساب والتقارير المالية والضريبية (Ledger & Reports)

### `GET /api/v1/logistics-invoices/partners/{partner_id}/balance-card`
- **الوصف:** بطاقة رصيد الشريك اللحظية متضمنة إجمالي المفوتر، المسدد، والمستحق، مع جدول تعمير الديون (Aging).
- **نموذج الاستجابة:** `PartnerBalanceCardResponse`

---

### `GET /api/v1/logistics-invoices/partners/{partner_id}/ledger`
- **الوصف:** كشف حساب تفصيلي للشريك بنظام القيد المزدوج (مدين فواتير / دائن مدفوعات) والرصيد التراكمي.
- **البارامترات:** `from_date` (date, opt), `to_date` (date, opt)
- **نموذج الاستجابة:** `PartnerLedgerResponse`

---

### `GET /api/v1/logistics-invoices/reports/wht-form41`
- **الوصف:** تقرير إقرار نموذج 41 خصم وتحصيل تحت حساب الضريبة مجمع شهرياً وسنوياً.
- **البارامترات:** `year` (int, required), `month` (int, optional)
- **نموذج الاستجابة:** `WhtForm41ReportResponse`
