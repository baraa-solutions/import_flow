# 📦 ImportFlow ERP — Domain Business Rules

> قواعد Business Domain الخاصة بـ ImportFlow — تُحمَّل تلقائيًا مع `CORE_RULES.md`.
> للتفاصيل الكاملة: `AGENTS.md` | للـ UI: `UI_SCREEN_STANDARDS.md`

---

## 1. 🔄 Import File Lifecycle — مراحل ملف الاستيراد

```
Draft → Quotation → Purchase Order → Shipment
→ Documents → Customs → Clearance → Landed Cost → Closed
```

**القواعد:**
- ✅ يُسمح بالإنشاء التدريجي — لا يجب إدخال كل البيانات دفعة واحدة
- ✅ كل Stage لها Validation Rules خاصة بها فقط
- ❌ لا يجوز الانتقال لـ Stage جديدة إذا لم تتحقق شروطها
- ❌ لا تُطبَّق قواعد Closing عند Draft

---

## 2. 🧮 Customs Calculation Engine — محرك الحساب الجمركي

> **القاعدة الأساسية:** كل HS Code له نسب مختلفة. لا افتراضات.

### بنود الحساب (كلها مصدرها HS Code):
```
1. Import Duty      = CIF × Duty Rate%
2. VAT              = VAT Base × VAT Rate%   (≠ 14% دائماً)
3. Schedule Tax     = CIF × Schedule Rate%   (إن وجدت)
4. Import Fee       = ثابت أو نسبة (إن وجد)
5. Customs Service Fees
6. Basic Fees
7. Development Fee
```

### تسلسل الحساب (إلزامي):
```
Step 1: CIF = FOB + Freight + Insurance
Step 2: Import Duty = CIF × Duty Rate% (من HS Code)
Step 3: VAT Base = CIF + Import Duty   (freight/insurance are already inside CIF; development, service and basic fees are NOT in the VAT base - engine: modules/customs_tariff/service.py)
Step 4: VAT = VAT Base × VAT Rate% (من HS Code)
Step 5: Schedule Tax = CIF × Schedule Rate% (من HS Code، إن وجدت)
Step 6: Customs Service Fees (من جدول الرسوم)
Step 7: Total = كل ما سبق
```

### قواعد حرجة:
```text
❌ Hard-Code أي نسبة ضريبية (VAT ≠ 14% دائماً)
❌ افتراض أن كل البنود تنطبق على كل شحنة
✅ كل HS Code يحدد أي بنود تنطبق وبأي نسب
✅ حفظ تاريخ سريان كل قاعدة (effective_from / effective_to)
✅ استخدام سعر صرف الجمارك الرسمي في تاريخ الإقرار
✅ حفظ تفاصيل كل بند منفصلاً (لا مجرد رقم إجمالي)
```

---

## 3. 💰 Landed Cost Engine — تكلفة الوصول الشاملة

```
Landed Cost =
  Purchase Cost (FOB/CIF)
+ Freight (النولون)
+ Insurance (التأمين)
+ Import Duty
+ VAT
+ Schedule Tax
+ Development Fee
+ Customs Service Fees
+ Basic Fees
+ Clearance Fees (أتعاب التخليص)
+ Local Transport
+ Other Import Costs
```

- ✅ يجب حفظ تفاصيل كل مكون — لا رقم إجمالي فقط
- ✅ CBM يدعم: mm / cm / m / kg / lb مع توحيد داخلي قبل الحساب

---

## 4. 🗑️ Soft Delete — الحذف المنطقي

```python
# لا حذف نهائي للبيانات المهمة
is_active   → False (للتعطيل)
deleted_at  → timestamp
deleted_by  → user_id

# استبعاد المحذوفين من الاستعلامات العادية:
.filter(Model.is_active == True)
# أو
.filter(Model.deleted_at == None)
```

---

## 5. 🔐 Data Integrity — مستويان من الحماية

```
Application Level: Duplicate detection + Business validation
Database Level:    UNIQUE constraints + Foreign Keys + Indexes
```

**مثال:**
```python
# Application
if supplier_exists(company_name, country_id):
    raise DuplicateError(...)

# Database
UNIQUE(company_name, country_id)  # في Alembic migration
```

---

## 6. 🔗 External Integrations — طبقة مستقلة

```
integrations/
├── cargox/
├── nafeza/
└── shipping/
```
- ✅ Business Logic مستقل عن API خارجي
- ❌ لا تربط Business Logic مباشرة بـ API key أو endpoint خارجي

---

## 7. 📦 Cargo Measurement

```python
# وحدات مدعومة: mm, cm, m, kg, lb
# دايمًا وحّد الوحدات داخلياً قبل الحساب
CBM = (L_cm × W_cm × H_cm) / 1_000_000
Volumetric Weight = CBM × 167  # Air freight
Chargeable Weight = max(Actual Weight, Volumetric Weight)
```

---

## 8. 🏗️ Master Data Rules

```text
✅ استخدم FK بدلاً من نص حر
✅ Unique constraints في DB + Application check
✅ كل Entity = Primary Key + Business Code

❌ country = "Italy"   →  ✅ country_id = 39
❌ supplier_id = 17    →  ✅ supplier_code = "SUP-000017"
```

---

## 9. 📦 Production Build — حزمة الإنتاج النظيفة

عند إنشاء Production Release:
```text
✅ احتفظ بـ (Reference Data فقط):
   - Ports & Transport Locations
   - Customs Tariff & HS Codes & Fee Codes
   - Incoterms 2020 & Cost Items
   - Currencies & Exchange Rates
   - Core Users & RBAC Roles
   - Package Types & Units of Measure

❌ امسح (Operational Data):
   - Import Companies, Suppliers, Projects
   - Import Files, Purchase Orders, Shipments
   - Invoices, Reports, Notifications, Change Logs
```
