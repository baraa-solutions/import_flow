# Product & Domain Specification: Logistics Service Invoices & Payments (LSI)
## نظام فواتير ومدفوعات مقدمي الخدمات اللوجستية (الشحن، التخليص، الفحص، التأمين البحري)

---

## 1. نظرة عامة والهدف التشغيلي (Overview & Purpose)

يمثل نظام **Logistics Service Invoices & Payments (LSI)** الحلقة المالية والتشغيلية المفقودة بين التعاقد مع مقدمي الخدمات اللوجستية الخارجية (External Service Providers) وبين محرك تكلفة الوصول الفعلية (**Landed Cost Engine**).

### الشركاء المشمولون بالمنظومة:
1. **شركات ووكلاء الشحن (Freight Forwarders / Shipping Lines):**
   - احتساب وتدقيق 21 بنداً قياسياً لعروض أسعار الشحن.
   - قفل الحاويات ضد التكرار برقم البوليصة (Container-to-B/L Duplicate Lock).
2. **المخلصون الجمركيون (Customs Brokers):**
   - قائمة مصروفات التخليص الجمركي المعتمدة.
   - عهدة المخلص الذكية كدفعة مقدمة (Clearance Advance Custody) مع التسوية التلقائية للفائض أو العجز.
3. **شركات الفحص والمعاينة (Inspection & Quality Agencies):**
   - مخصص فحص الشحنة التقديري (Inspection Reserve Estimator) وتدقيق الفاتورة الفعلية.
4. **شركات التأمين البحري (Marine Cargo Insurance):**
   - إصدار وثائق التأمين وفقاً للقواعد واللوائح المصرية المعتمدة ($CIF + 10\%$, الدمغة النسبية $0.1\%$, رسم رقابة الهيئة العامة للرقابة المالية $12\%$).
   - توليد فاتورة سداد فورية بضغطة زر واحدة.
   - دورة حياة مطالبات التأمين والتعويضات الحادثة (Insurance Claims Workflow).

---

## 2. بنود ومصروفات شركات الشحن الـ 21 (Freight Forwarder 21 Quotation Items)

يتم تقسيم بنود فاتورة شركة الشحن إلى ثلاثة قطاعات رئيسية:

### أ. نولون الشحن البحري / الجوي الأساسي (Ocean & Air Freight):
1. `EXP-FRT-001`: Basic Ocean / Air Freight Rate (النولون الأساسي)
2. `EXP-FRT-002`: Bunker Adjustment Factor - BAF (علاوة تغيير أسعار الوقود)
3. `EXP-FRT-003`: Currency Adjustment Factor - CAF (علاوة تقلبات العملة)
4. `EXP-FRT-004`: Peak Season Surcharge - PSS (رسوم مواسم الذروة)
5. `EXP-FRT-005`: Low Sulphur Surcharge - LSS (رسوم وقود منخفض الكبريت)
6. `EXP-FRT-006`: War Risk / Security Surcharge (رسوم مخاطر الحرب والملاحة)
7. `EXP-FRT-007`: Emergency Bunker Surcharge - EBS (علاوة وقود طوارئ)

### ب. مصاريف الميناء ورسوم التوكيل الملاحي بالوجهة (Destination & Local Port Charges):
8. `EXP-FRT-008`: Terminal Handling Charges at Destination - THCD (رسوم تداول الحاويات بميناء الوصول)
9. `EXP-FRT-009`: Delivery Order Fee - D/O (رسوم إصدار إذن التسليم)
10. `EXP-FRT-010`: Port Authority & Harbor Dues (رسوم هيئة الميناء ورسو السفينة)
11. `EXP-FRT-011`: Container Cleaning & Washing Fee (رسوم غسيل وتطهير الحاويات)
12. `EXP-FRT-012`: Equipment Management Fee - EMF (رسوم إدارة وتجهيز المعدات)
13. `EXP-FRT-013`: Gate / EDI Processing Fee (رسوم البوابة والإرسال الإلكتروني)
14. `EXP-FRT-014`: Container Inspection Fee (رسوم كشف ومعاينة الحاوية بالميناء)

### ج. مصاريف بلد المنشأ والتوثيق (Origin & Documentation Charges):
15. `EXP-FRT-015`: Bill of Lading Issuance Fee (رسوم إصدار بوليصة الشحن الأصلية)
16. `EXP-FRT-016`: Telex / Sea Waybill Express Release Fee (رسوم إذن التلكس للتسليم السريع)
17. `EXP-FRT-017`: AMS / ACI / Nafeza Electronic Filing Fee (رسوم تسجيل البيانات الجمركية المسبقة)
18. `EXP-FRT-018`: Origin Documentation & Legalization Fee (رسوم توثيق وتصديق مستندات بلد المنشأ)
19. `EXP-FRT-019`: Terminal Handling Charges at Origin - THCO (رسوم تداول الحاويات بميناء الشحن)
20. `EXP-FRT-020`: Export Customs Clearance Fee at Origin (رسوم التخليص الجمركي للصادر ببلد المنشأ)
21. `EXP-FRT-021`: Cargo Insurance Coordination Fee (رسوم خدمات وتنسيق التأمين البحري)

---

## 3. قواعد العمل والضوابط الفنية (Business Rules & Validations)

### 3.1 قفل الحاويات بالبوليصة ضد ازدواجية الفوترة (Container-to-B/L Lock)
- يتم تخزين الحاويات المفوتورة في جدول `logistics_invoice_containers`.
- يُمنع إصدار أكثر من فاتورة لنفس الحاوية تحت نفس رقم البوليصة لنفس الشريك الخدمي (`partner_id + bl_number + container_number` كقيد فريد).
- يُلزم النظام إدخال أرقام الحاويات والسيل المطابقة لما هو وارد في البوليصة وقائمة التعبئة الرسمية.

### 3.2 عهدة المخلص الذكية كدفعة مقدمة (Clearance Advance Custody)
- يتم صرف عهدة مالية للمخلص الجمركي قبل وصول الشحنة لتغطية مصروفات الميناء والجمارك.
- يتم تسجيل العهدة كدفعة مقدمة (`ClearanceAdvancePayment`) مرتبطة بالشحنة ورقم البوليصة.
- فور استلام الفاتورة التفصيلية الفعلية للمخلص، يتم عمل تسوية (`ClearanceAdvanceSettlement`):
  - **حالة الفائض (Surplus):** يبقى رصيد دائن بالعهدة يُرد للشركة أو يُسوى مع شحنة قادمة.
  - **حالة العجز (Deficit):** يتم استخراج إذن صرف تكميلي أو فاتورة مستحقة بالمتبقي.

### 3.3 محددات التأمين البحري وفقاً للقانون المصري (Egyptian Marine Insurance Regulations)
تخضع وثائق التأمين البحري للضوابط التالية:
1. **القيمة التأمينية الإجمالية (Insured Value):**
   $$\text{Insured Value (FX)} = \text{CIF Value} \times 1.10$$
   (أي قيمة الشحنة CIF مضافاً إليها 10% هامش ربح تجاري ومصاريف متوقعة).
2. **القسط الأساسي (Base Premium):**
   $$\text{Base Premium (EGP)} = \text{Insured Value} \times \left(\frac{\text{Premium Rate}}{100}\right) \times \text{Exchange Rate}$$
3. **الدمغة النسبية (Proportional Stamp Duty):**
   $$\text{Stamp Duty (EGP)} = \text{Base Premium (EGP)} \times 0.001 \quad (0.1\%)$$
4. **رسم رقابة الهيئة العامة للرقابة المالية (FRA Supervisory Fee):**
   $$\text{Supervisory Fee (EGP)} = \text{Base Premium (EGP)} \times 0.12 \quad (12\%)$$
5. **الصافي المستحق للسداد (Net Premium):**
   $$\text{Net Premium} = \text{Base Premium} + \text{Stamp Duty} + \text{Supervisory Fee}$$
6. **دورة حياة المطالبات (Claims Workflow):**
   $$\text{filed} \longrightarrow \text{under\_inspection} \longrightarrow \text{accepted} \longrightarrow \text{reimbursed / rejected}$$

### 3.4 تعدد العملات وسعر صرف البنك المركزي المصري (Multi-Currency & CBE Rate)
- تقبل الفواتير كافة العملات الأجنبية الرئيسية (USD, EUR, GBP, EGP).
- عند سداد الفاتورة أو إصدار إذن الدفع، يتم السداد بالجنيه المصري (EGP) وفقاً لسعر الصرف التجاري المعلن من البنك المركزي المصري في تاريخ الصرف الفعلي.
- يتم تثبيت تاريخ سعر الصرف المعتمد في كل حركة سداد لمنع الفروق المحاسبية.

### 3.5 أذون الصرف والإقفال مقابل أرقام الفواتير (Payment Vouchers & Knock-Offs)
- لا يجوز صرف دفعات عشوائية دون ربطها بفواتير مفتوحة.
- يتم إقفال الدفعة كلياً أو جزئياً (`InvoiceKnockoff`) مقابل أرقام فواتير محددة حتى تصفير المتبقي.
- يدعم النظام الإقفال التلقائي بنظام الأقدم فالأحدث (FIFO Auto-Allocation) أو التوزيع اليدوي المخصص.

### 3.6 كشف حساب الشريك، تعمير الديون، وإقرار نموذج 41 ضرائب الخصم
- **كشف الحساب (Partner Ledger):** قيد مزدوج مدين/دائن مع رصيد تراكمي مستمر (Running Balance).
- **أعمار الديون (Debt Aging):** تقسيم المستحقات إلى شرائح زمنية:
  - حتى 30 يوماً
  - من 31 إلى 60 يوماً
  - من 61 إلى 90 يوماً
  - أكثر من 90 يوماً
- **إقرار نموذج 41 خصم وتحصيل تحت حساب الضريبة (WHT Form 41):**
  - تجميع شهري وربعي لضريبة الخصم المقتطعة من فواتير الموردين والشركاء (1% توريدات / 3% استشارات وخدمات تخليص).
