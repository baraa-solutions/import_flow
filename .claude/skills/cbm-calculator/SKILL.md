---
name: cbm-calculator
description: Calculate CBM (Cubic Meters), Volumetric Weight, Air Chargeable Weight, Container Recommendations, 3D Bin Packing with 90-degree pallet auto-rotation, explicit failure diagnostics, and Purchase Order Packing List integrations for shipments in ImportFlow ERP.
---

# Cargo Measurement Engine Skill (BP-004)

Use this skill when implementing, calculating, or testing cargo measurements, 3D container allocation, 90-degree pallet auto-rotation, and Purchase Order Packing List integrations in ImportFlow ERP.

## Core Calculation Rules

### 1. Unit Normalization
Convert all input dimensions and weights before performing calculations:
- `mm` -> `cm`: `/ 10`
- `m` -> `cm`: `* 100`
- `lb` -> `kg`: `* 0.45359237`

### 2. Standard Formulas
- **Cargo Volume (CBM):**
  $$\text{CBM} = \frac{\text{Length (cm)} \times \text{Width (cm)} \times \text{Height (cm)}}{1,000,000} \times \text{Quantity}$$
- **Air Volumetric Weight (kg):**
  $$\text{Air Volumetric Wt} = \frac{\text{Length (cm)} \times \text{Width (cm)} \times \text{Height (cm)}}{6,000} \times \text{Quantity}$$
- **Air Chargeable Weight (kg):**
  $$\text{Chargeable Weight} = \max(\text{Total Gross Weight (kg)}, \text{Total Air Volumetric Weight (kg)})$$

### 3. Advanced 3D Extreme-Point Bin Packing & 90° Auto-Rotation Rules
- **Automatic 90-Degree Horizontal Rotation:**
  - If entered cargo `Width` > Container Internal Width (e.g., $350 \text{ cm} > 235 \text{ cm}$), BUT `Length` $\le$ Container Internal Width ($220 \text{ cm} \le 235 \text{ cm}$) and `Width` $\le$ Container Internal Length ($350 \text{ cm} \le 1203 \text{ cm}$), the algorithm automatically swaps Length & Width ($90^\circ$ rotation) to fit the cargo.
- **Explicit Failure Diagnostics:**
  - If both `Length` and `Width` exceed max container internal width (e.g., $250 \times 250 \text{ cm}$ vs $235 \text{ cm}$ max width), packing is rejected and reports an explicit Arabic diagnostic error:
    `فشل الرص: تجاوز الطول والعرض الأبعاد القياسية للحاوية (أبعاد الطرد: 250 × 250 سم - أقصى عرض مسموح للحاوية 235 سم)`
  - Height violations report: `ارتفاع الطرد يتجاوز الارتفاع الداخلي للحاوية`.
  - Weight violations report: `إجمالي وزن الحمولة يتجاوز الوزن المسموح للحاوية`.

### 4. Shipping Method & Container Recommendation Rules
- **Air Freight:** Total CBM $\le 1.5 \text{ m}^3$ and Gross Weight $\le 300 \text{ kg}$.
- **LCL Ocean Freight:** Total CBM $\le 15.0 \text{ m}^3$.
- **FCL Ocean Freight:** Total CBM $> 15.0 \text{ m}^3$:
  - `20FT Standard Container (20' ST)`: Volume up to $33.0 \text{ m}^3$.
  - `40FT Standard Container (40' ST)`: Volume up to $67.0 \text{ m}^3$.
  - `40FT High Cube Container (40' HC)`: Volume up to $76.0 \text{ m}^3$.
  - Multi-container allocation: $\lceil \text{Total CBM} / 76.0 \rceil \times \text{40' HC Containers}$.

### 5. Purchase Order Packing List Integration
- Interactive 3D Container Load Planner available inside `Edit Purchase Order` dialog (`Packing List` tab).
- Live calculation of line CBM, Air Chargeable Weight, and Gross Weight.
- Automatic verification of PO items vs Packing List quantities.
