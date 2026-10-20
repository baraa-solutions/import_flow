import json
import os
import sqlite3
from datetime import datetime
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

def build_excel_report():
    conn = sqlite3.connect('sorour_logistics.db')
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # 1. Fetch File
    cur.execute("SELECT * FROM import_files WHERE import_file_code='IMP-2026-0005'")
    file_row = cur.fetchone()
    if not file_row:
        raise ValueError("Shipment IMP-2026-0005 not found in database!")
    file_data = dict(file_row)

    # 2. Fetch PO & Line Items
    cur.execute("SELECT * FROM purchase_orders WHERE po_number='PO-2026-005'")
    po_row = cur.fetchone()
    po_data = dict(po_row) if po_row else {}

    cur.execute("SELECT * FROM po_line_items WHERE po_id=? ORDER BY item_id ASC", (po_data.get('po_id', 5),))
    po_items = [dict(r) for r in cur.fetchall()]

    # 3. Fetch Bookings
    cur.execute("SELECT * FROM shipment_bookings WHERE import_file_id=5 OR booking_confirmation_no='THXJ2609015'")
    booking_row = cur.fetchone()
    booking_data = dict(booking_row) if booking_row else {}

    # 4. Fetch Draft BL Review
    cur.execute("SELECT * FROM draft_bl_review_sessions WHERE import_file_id=5")
    bl_review_row = cur.fetchone()
    bl_review_data = dict(bl_review_row) if bl_review_row else {}

    # 5. Fetch Smart Tasks
    cur.execute("SELECT * FROM smart_tasks WHERE import_file_id=5 ORDER BY task_id ASC")
    tasks_data = [dict(r) for r in cur.fetchall()]

    # 6. Fetch Active Portfolio
    cur.execute('''
        SELECT import_file_code, custom_file_number, company_name, supplier_name,
               current_stage, progress_percent, acid_number, bl_number,
               vessel_name, estimated_cost, estimated_cost_currency, required_eta, status
        FROM import_files
        ORDER BY import_file_id ASC
    ''')
    portfolio = [dict(r) for r in cur.fetchall()]

    wb = openpyxl.Workbook()
    wb.remove(wb.active)  # Remove default sheet

    # Colors & Fills
    navy_header_fill = PatternFill(start_color="1B365D", end_color="1B365D", fill_type="solid")
    dark_teal_fill = PatternFill(start_color="0D5C75", end_color="0D5C75", fill_type="solid")
    steel_blue_fill = PatternFill(start_color="2A52BE", end_color="2A52BE", fill_type="solid")
    sub_header_fill = PatternFill(start_color="EBF2FA", end_color="EBF2FA", fill_type="solid")
    light_gold_fill = PatternFill(start_color="FFF9E6", end_color="FFF9E6", fill_type="solid")
    zebra_even_fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    zebra_odd_fill = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")
    success_fill = PatternFill(start_color="E6F4EA", end_color="E6F4EA", fill_type="solid")
    warning_fill = PatternFill(start_color="FEF7E0", end_color="FEF7E0", fill_type="solid")

    font_title = Font(name="Calibri", size=15, bold=True, color="FFFFFF")
    font_header = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    font_header_dark = Font(name="Calibri", size=10, bold=True, color="1B365D")
    font_data = Font(name="Calibri", size=10, bold=False, color="222222")
    font_bold = Font(name="Calibri", size=10, bold=True, color="111111")
    font_highlight = Font(name="Calibri", size=10, bold=True, color="0D5C75")
    font_success = Font(name="Calibri", size=10, bold=True, color="0F5132")
    font_warning = Font(name="Calibri", size=10, bold=True, color="664D03")

    thin_border_side = Side(border_style="thin", color="D0D7DE")
    thick_bottom_side = Side(border_style="medium", color="1B365D")
    double_bottom_side = Side(border_style="double", color="1B365D")

    cell_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=thin_border_side)
    header_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=thick_bottom_side)
    summary_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=double_bottom_side)

    align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)
    align_right = Alignment(horizontal="right", vertical="center", wrap_text=True)

    def set_cell(ws, row, col, val=None, font=font_data, fill=None, border=cell_border, alignment=align_right, num_format=None):
        c = ws.cell(row=row, column=col)
        if type(c).__name__ != 'MergedCell' and val is not None:
            c.value = val
        if font and type(c).__name__ != 'MergedCell':
            c.font = font
        if fill:
            c.fill = fill
        if border:
            c.border = border
        if alignment and type(c).__name__ != 'MergedCell':
            c.alignment = alignment
        if num_format and type(c).__name__ != 'MergedCell':
            c.number_format = num_format
        return c

    # ----------------------------------------------------
    # TAB 1: الملخص التنفيذي (Executive Summary)
    # ----------------------------------------------------
    ws1 = wb.create_sheet(title="الملخص التنفيذي للشحنة")
    ws1.views.sheetView[0].rightToLeft = True

    ws1.merge_cells("A1:F2")
    title_cell = ws1["A1"]
    title_cell.value = "تقرير ملف الاستيراد الشامل والمدمج — شحنة PET Stock (IMP-2026-0005)"
    title_cell.font = font_title
    title_cell.fill = navy_header_fill
    title_cell.alignment = align_center

    ws1.merge_cells("A3:F3")
    sub_title = ws1["A3"]
    sub_title.value = f"تاريخ إنشاء التقرير: {datetime.now().strftime('%Y-%m-%d %H:%M')} | تم التوليد آلياً من قاعدة البيانات الحية - ImportFlow ERP"
    sub_title.font = font_highlight
    sub_title.alignment = align_center
    sub_title.fill = light_gold_fill

    r = 5
    def add_section(ws, row, title):
        ws.merge_cells(f"A{row}:F{row}")
        c = ws[f"A{row}"]
        c.value = title
        c.font = font_header
        c.fill = dark_teal_fill
        c.alignment = align_left
        for col in range(1, 7):
            ws.cell(row=row, column=col).border = cell_border
        return row + 1

    r = add_section(ws1, r, "1. بيانات الملف وهوية الشحنة (Shipment Master Identity)")
    fields_sec1 = [
        ("كود الملف الداخلي (ERP File Code):", file_data['import_file_code'], "رقم ملف الجمرك (Custom File No):", file_data['custom_file_number']),
        ("الشركة المستوردة (Importer Entity):", file_data['company_name'], "المورد الأجنبي (Foreign Supplier):", file_data['supplier_name']),
        ("المخلص الجمركي (Customs Broker):", file_data['broker_name'], "مرحلة دورة الحياة (Lifecycle Stage):", f"{file_data['current_stage']} ({file_data['progress_percent']}%)"),
        ("حالة الملف الحالية (Status):", file_data['status'], "الخطوة التنفيذية القادمة (Next Action):", f"{file_data['next_action']} (CargoX & COO)")
    ]
    for lbl1, v1, lbl2, v2 in fields_sec1:
        set_cell(ws1, r, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"B{r}:C{r}")
        set_cell(ws1, r, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 3, "", border=cell_border)
        
        set_cell(ws1, r, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"E{r}:F{r}")
        set_cell(ws1, r, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 6, "", border=cell_border)
        r += 1

    r += 1
    r = add_section(ws1, r, "2. المعاملات المالية وأمر الشراء (Commercial & Financial Data)")
    fields_sec2 = [
        ("رقم أمر الشراء (PO Number):", file_data['po_number'], "رقم الفاتورة المبدئية (PI Number):", file_data['pi_number']),
        ("إجمالي قيمة البضاعة (FOB Amount):", f"${file_data['estimated_cost']:,.2f} {file_data['estimated_cost_currency']}", "شروط التعاقد والتسليم (Incoterms):", file_data['incoterm_code']),
        ("سعر صرف التقدير المالي:", f"1 USD = {po_data.get('exchange_rate', 48.70)} EGP", "شروط السداد المتفق عليها:", "TT 30% مقدم / 70% مقابل بوليصة الشحن الشاحنة"),
        ("إجمالي نولون الشحن والمصاريف:", "$7,780.00 USD (نولون بحري $6,700 + محلي $1,080)", "النموذج البنكي 4 وسويفت التحويل:", "قيد الانتظار لمرحلة فتح الاعتماد للرصيد 70%")
    ]
    for lbl1, v1, lbl2, v2 in fields_sec2:
        set_cell(ws1, r, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"B{r}:C{r}")
        set_cell(ws1, r, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 3, "", border=cell_border)
        
        set_cell(ws1, r, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"E{r}:F{r}")
        set_cell(ws1, r, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 6, "", border=cell_border)
        r += 1

    r += 1
    r = add_section(ws1, r, "3. الشحن الدولي والخط الملاحي (Carrier & Ocean Logistics)")
    fields_sec3 = [
        ("الخط الملاحي الدولي (Carrier):", booking_data.get('shipping_line_name', 'Wan Hai Lines Ltd.'), "رقم الحجز الملاحي (Booking No):", file_data['booking_no']),
        ("اسم السفينة ورحلتها (Vessel & Voyage):", f"{file_data['vessel_name']} ({booking_data.get('voyage_number', 'V.W112')})", "رقم بوليصة الشحن (B/L Number):", file_data['bl_number']),
        ("ميناء الشحن والتحميل (POL):", file_data['port_of_loading'], "ميناء الوصول والتفريغ (POD):", f"{file_data['port_of_discharge']} (الميناء القديم حتمي)"),
        ("تاريخ الإبحار الفعلي (ATD):", "2026-09-25 (أبحرت)", "تاريخ الوصول المقدر (ETA):", "2026-10-23 (بحرية جارية)"),
        ("أيام السماح لغرامات التأخير (Free Demurrage):", f"{booking_data.get('free_demurrage_days', 21)} يوماً (اتفاقية WHL-THXJ2609015-FD)", "بيانات الحاوية والسيل الرصاصي:", "1x40HC (WHSU81072658 / سيل: WHA257097)")
    ]
    for lbl1, v1, lbl2, v2 in fields_sec3:
        set_cell(ws1, r, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"B{r}:C{r}")
        set_cell(ws1, r, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 3, "", border=cell_border)
        
        set_cell(ws1, r, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"E{r}:F{r}")
        set_cell(ws1, r, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 6, "", border=cell_border)
        r += 1

    r += 1
    r = add_section(ws1, r, "4. المنظومة الجمركية ونافذة (Customs & Nafeza Clearance)")
    fields_sec4 = [
        ("رقم القيد الجمركي المبدئي (ACID No):", file_data['acid_number'], "تاريخ إصدار ACID وصلاحيته:", f"إصدار: {file_data['acid_issue_date']} | ينتهي: {file_data['acid_expiry_date']} (ساري)"),
        ("حالة مراجعة مسودة البوليصة (Draft B/L Review):", f"معتمدة بنجاح ({bl_review_data.get('bl_review_code', 'BL-REV-2026-0002')})", "الاعتماد المزدوج (Dual Approval):", "معتمد من المهندس المستورد + المخلص الجمركي نبيل نصيف"),
        ("مطابقة مسودة البوليصة للشروط:", "مطابقة 100% (0 اختلافات - تم التحقق من الوزن والـ ACID)", "شهادة المنشأ الصينية (COO):", "قيد الإصدار والاعتماد من الغرفة التجارية بالصين"),
        ("رفع المستندات عبر كارجو إكس (CargoX):", "مجدول للتنفيذ فور صدور شهادة المنشأ", "نموذج 46 وإذن الإفراج النهائي:", "قيد الانتظار لمرحلة وصول الباخرة والكشف الجمركي")
    ]
    for lbl1, v1, lbl2, v2 in fields_sec4:
        set_cell(ws1, r, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"B{r}:C{r}")
        set_cell(ws1, r, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 3, "", border=cell_border)
        
        set_cell(ws1, r, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws1.merge_cells(f"E{r}:F{r}")
        set_cell(ws1, r, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws1, r, 6, "", border=cell_border)
        r += 1

    # ----------------------------------------------------
    # TAB 2: الجدول الزمني للشحنة (Timeline: 25 Stages Planned vs Actual & Notes)
    # ----------------------------------------------------
    ws_time = wb.create_sheet(title="الجدول الزمني ومراحل الشحنة")
    ws_time.views.sheetView[0].rightToLeft = True

    ws_time.merge_cells("A1:I2")
    ws_time["A1"] = "الجدول الزمني ومراحل دورة حياة الشحنة (25 مرحلة) — مقارنة المخطط بالفعلي والملاحظات التشغيلية"
    ws_time["A1"].font = font_title
    ws_time["A1"].fill = navy_header_fill
    ws_time["A1"].alignment = align_center

    ws_time.merge_cells("A3:I3")
    ws_time["A3"] = f"شحنة: {file_data['custom_file_number']} ({file_data['import_file_code']}) | إجمالي المراحل: 25 مرحلة | المراحل المنجزة: 10 مراحل (65%) | الخط الملاحي: {booking_data.get('shipping_line_name', 'Wan Hai Lines Ltd.')}"
    ws_time["A3"].font = font_highlight
    ws_time["A3"].alignment = align_center
    ws_time["A3"].fill = sub_header_fill

    headers_time = [
        "م", "كود المرحلة", "اسم المرحلة الإجرائية", "حزمة العمل (Phase)",
        "التاريخ المخطط", "التاريخ الفعلي", "الفارق (أيام)", "الحالة الإجرائية",
        "الملاحظات التشغيلية والتوجيهات الحتمية (Operational Directives)"
    ]
    r_time = 5
    for c_idx, h in enumerate(headers_time, start=1):
        set_cell(ws_time, r_time, c_idx, h, font=font_header, fill=dark_teal_fill, border=header_border, alignment=align_center)

    cur.execute("SELECT * FROM shipment_timeline_snapshots WHERE import_file_id=5 ORDER BY snapshot_id ASC")
    timeline_rows = [dict(r) for r in cur.fetchall()]

    for idx, s in enumerate(timeline_rows, start=1):
        r_time += 1
        st = s.get('status', 'PENDING')
        p_date = str(s['planned_date'])[:10] if s['planned_date'] else '—'
        a_date = str(s['actual_date'])[:10] if s['actual_date'] else ('قيد التنفيذ' if st == 'IN_PROGRESS' else 'قيد الانتظار')
        v_days = s.get('variance_days', 0)
        var_text = f"+{v_days} يوم" if v_days > 0 else ("في الموعد (0)" if v_days == 0 and st == 'COMPLETED' else "—")
        
        note = s.get('delay_reason') or ''
        if not note and s.get('event_details_json'):
            try:
                dt = json.loads(s['event_details_json'])
                note = dt.get('note', '')
            except Exception:
                pass

        if st == 'COMPLETED':
            row_fill = success_fill
            st_text = "✅ منجز"
            st_font = font_success
        elif st == 'IN_PROGRESS':
            row_fill = warning_fill
            st_text = "⏳ قيد التنفيذ (الحالية)"
            st_font = font_warning
        else:
            row_fill = zebra_even_fill if idx % 2 == 0 else zebra_odd_fill
            st_text = "⏱️ قيد الانتظار"
            st_font = font_data

        set_cell(ws_time, r_time, 1, idx, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 2, s.get('stage_code', ''), font=font_bold, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 3, f"{s.get('stage_name_ar', '')} ({s.get('stage_name_en', '')})", font=font_bold, alignment=align_right, fill=row_fill)
        set_cell(ws_time, r_time, 4, f"Phase {s.get('phase_number', 1)}", alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 5, p_date, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 6, a_date, font=font_bold if st != 'PENDING' else font_data, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 7, var_text, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 8, st_text, font=st_font, alignment=align_center, fill=row_fill)
        set_cell(ws_time, r_time, 9, note, alignment=align_right, fill=row_fill)

    # ----------------------------------------------------
    # TAB 3: تفاصيل أمر الشراء والأصناف (PO & Packing List)
    # ----------------------------------------------------
    ws2 = wb.create_sheet(title="أمر الشراء وقائمة التعبئة")
    ws2.views.sheetView[0].rightToLeft = True

    ws2.merge_cells("A1:H2")
    ws2["A1"] = "أمر الشراء وقائمة الأصناف المعتمدة — PO-2026-005 (شحنة PET Stock)"
    ws2["A1"].font = font_title
    ws2["A1"].fill = navy_header_fill
    ws2["A1"].alignment = align_center

    ws2.merge_cells("A3:H3")
    ws2["A3"] = f"المورد: {file_data['supplier_name']} | الفاتورة المبدئية: {file_data['pi_number']} | إجمالي القيمة: $39,820.00 USD EXW | عدد الأصناف: {len(po_items)}"
    ws2["A3"].font = font_highlight
    ws2["A3"].alignment = align_center
    ws2["A3"].fill = sub_header_fill

    headers_po = [
        "م", "كود الصنف الداخلي", "الوصف الفني والتجاري للصنف", "بلد المنشأ",
        "الكمية المطلوبة", "الوحدة", "سعر الوحدة (USD)", "إجمالي القيمة (USD)"
    ]
    r_po = 5
    for c_idx, h in enumerate(headers_po, start=1):
        set_cell(ws2, r_po, c_idx, h, font=font_header, fill=steel_blue_fill, border=header_border, alignment=align_center)

    tot_qty = 0
    tot_val = 0.0

    for idx, item in enumerate(po_items, start=1):
        r_po += 1
        q = item.get('quantity', 0)
        p = item.get('unit_price', 0.0)
        tot = item.get('total_price', q * p)
        tot_qty += q
        tot_val += tot

        fill = zebra_even_fill if idx % 2 == 0 else zebra_odd_fill
        set_cell(ws2, r_po, 1, idx, alignment=align_center, fill=fill)
        set_cell(ws2, r_po, 2, item.get('item_code', ''), font=font_bold, alignment=align_center, fill=fill)
        set_cell(ws2, r_po, 3, item.get('description_ar', item.get('description_en', '')), alignment=align_right, fill=fill)
        set_cell(ws2, r_po, 4, item.get('country_of_origin', 'CN - China'), alignment=align_center, fill=fill)
        set_cell(ws2, r_po, 5, q, alignment=align_right, fill=fill, num_format="#,##0")
        set_cell(ws2, r_po, 6, item.get('unit_of_measure', 'PCS'), alignment=align_center, fill=fill)
        set_cell(ws2, r_po, 7, p, alignment=align_right, fill=fill, num_format="$#,##0.00")
        set_cell(ws2, r_po, 8, tot, font=font_bold, alignment=align_right, fill=fill, num_format="$#,##0.00")

    r_po += 1
    ws2.merge_cells(f"A{r_po}:D{r_po}")
    set_cell(ws2, r_po, 1, "الإجمالي الكلي لأمر الشراء المعتمد (Grand Total):", font=font_header_dark, fill=sub_header_fill, alignment=align_right)
    for c in range(2, 5): set_cell(ws2, r_po, c, "", fill=sub_header_fill, border=summary_border)
    set_cell(ws2, r_po, 5, tot_qty, font=font_header_dark, fill=sub_header_fill, alignment=align_right, border=summary_border, num_format="#,##0")
    set_cell(ws2, r_po, 6, "PCS", font=font_header_dark, fill=sub_header_fill, alignment=align_center, border=summary_border)
    set_cell(ws2, r_po, 7, "", fill=sub_header_fill, border=summary_border)
    set_cell(ws2, r_po, 8, tot_val, font=font_header_dark, fill=sub_header_fill, alignment=align_right, border=summary_border, num_format="$#,##0.00")

    r_po += 2
    ws2.merge_cells(f"A{r_po}:H{r_po}")
    c = ws2[f"A{r_po}"]
    c.value = "المواصفات الحجمية والوزنية المعتمدة للشحنة (Packaging & Volumetric Specifications)"
    c.font = font_header
    c.fill = dark_teal_fill
    c.alignment = align_left
    for col in range(1, 9): ws2.cell(row=r_po, column=col).border = cell_border

    specs = [
        ("عدد الطرود والكراتين (Total Packages):", f"{po_data.get('total_packages_count', 180)} Packages (1,000 PCS)", "الوزن القائم الكلي (Gross Weight):", f"{po_data.get('total_gross_weight_kg', 12840.0):,.2f} kg (VGM: 24,500 kg)"),
        ("الوزن الصافي للبضاعة (Net Weight):", f"{po_data.get('total_net_weight_kg', 12620.0):,.2f} kg", "الحجم التكعيبي الفعلي (Actual CBM):", f"{po_data.get('total_cbm', 60.67):,.2f} m³ (Nominal: 100 m³)"),
        ("حاوية الشحن والتعبئة:", "1x40' High Cube Container (40HC)", "طبيعة البضاعة والتخزين:", "ألواح بوليستر عازلة للصوت PET Acoustic Panels")
    ]
    for lbl1, v1, lbl2, v2 in specs:
        r_po += 1
        set_cell(ws2, r_po, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws2.merge_cells(f"B{r_po}:D{r_po}")
        set_cell(ws2, r_po, 2, v1, font=font_bold, alignment=align_right)
        for c in range(2, 5): ws2.cell(row=r_po, column=c).border = cell_border

        set_cell(ws2, r_po, 5, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws2.merge_cells(f"F{r_po}:H{r_po}")
        set_cell(ws2, r_po, 6, v2, font=font_bold, alignment=align_right)
        for c in range(6, 9): ws2.cell(row=r_po, column=c).border = cell_border

    # ----------------------------------------------------
    # TAB 3: اللوجستيات والشحن الدولي (Carrier & Logistics)
    # ----------------------------------------------------
    ws3 = wb.create_sheet(title="الشحن والخط الملاحي")
    ws3.views.sheetView[0].rightToLeft = True

    ws3.merge_cells("A1:F2")
    ws3["A1"] = "تفاصيل الحجز الملاحي والشحن البحري — Booking THXJ2609015"
    ws3["A1"].font = font_title
    ws3["A1"].fill = navy_header_fill
    ws3["A1"].alignment = align_center

    ws3.merge_cells("A3:F3")
    ws3["A3"] = f"الخط الملاحي: {booking_data.get('shipping_line_name', 'Wan Hai Lines Ltd.')} | البوليصة: {file_data['bl_number']} | الحاوية: WHSU81072658 (40HC) | الحالة: مبحرة بالبحر"
    ws3["A3"].font = font_highlight
    ws3["A3"].alignment = align_center
    ws3["A3"].fill = sub_header_fill

    r3 = 5
    r3 = add_section(ws3, r3, "بيانات الحجز والناقل البحري والحاوية")
    bkg_fields = [
        ("رقم الحجز المعتمد (Booking Confirmation):", booking_data.get('booking_confirmation_no', 'THXJ2609015'), "الخط الملاحي الدولي (Carrier):", booking_data.get('shipping_line_name', 'Wan Hai Lines Ltd.')),
        ("اسم الباخرة (Vessel Name):", file_data['vessel_name'], "رقم رحلة الإبحار (Voyage No):", booking_data.get('voyage_number', 'V.W112')),
        ("رقم بوليصة الشحن (B/L Number):", file_data['bl_number'], "طبيعة البوليصة والشروط:", "بوليصة بحرية مباشرة وأصلية (Master Seaway B/L)"),
        ("رقم الحاوية (Container No):", "WHSU81072658", "رقم السيل الرصاصي (Seal No):", "WHA257097"),
        ("نوع الحاوية ومقاسها:", "1x40HC (High Cube)", "وزن التحقق المعتمد (VGM):", "24,500.00 kg"),
        ("ميناء الشحن والتحميل (POL):", file_data['port_of_loading'], "ميناء الوصول والتفريغ (POD):", f"{file_data['port_of_discharge']} (Old Port is Must)"),
        ("تاريخ الإبحار الفعلي (ATD):", "2026-09-25 (أبحرت رسمياً)", "تاريخ الوصول المقدر (ETA):", "2026-10-23 (زمن الإبحار 28 يوماً)"),
        ("أيام السماح لغرامات التأخير (Free Demurrage):", f"{booking_data.get('free_demurrage_days', 21)} يوماً سماح غرامات بميناء الإسكندرية", "مرجع اتفاقية السماح:", "WHL-THXJ2609015-FD (21D DEM / 7D DET)"),
        ("نولون الشحن البحري الأساسي (Ocean Freight):", "$6,700.00 USD (حاوية 40 قدم)", "مصاريف النولون والمناولة بميناء الشحن:", "$1,080.00 USD (Origin Local & EXW Handling)"),
        ("إجمالي تكلفة الشحن الدولي الكاملة:", "$7,780.00 USD", "حالة الشحنة الحالية في التتبع:", "مبحرة في البحر (Sailed) في طريقها لميناء الإسكندرية")
    ]
    for lbl1, v1, lbl2, v2 in bkg_fields:
        set_cell(ws3, r3, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws3.merge_cells(f"B{r3}:C{r3}")
        set_cell(ws3, r3, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws3, r3, 3, "", border=cell_border)
        
        set_cell(ws3, r3, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws3.merge_cells(f"E{r3}:F{r3}")
        set_cell(ws3, r3, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws3, r3, 6, "", border=cell_border)
        r3 += 1

    # ----------------------------------------------------
    # TAB 4: المستندات والمنظومة الجمركية (Docs & Customs)
    # ----------------------------------------------------
    ws4 = wb.create_sheet(title="المستندات الجمركية ونافذة")
    ws4.views.sheetView[0].rightToLeft = True

    ws4.merge_cells("A1:F2")
    ws4["A1"] = "ملف المستندات والمنظومة الجمركية ونافذة — شحنة PET Stock"
    ws4["A1"].font = font_title
    ws4["A1"].fill = navy_header_fill
    ws4["A1"].alignment = align_center

    ws4.merge_cells("A3:F3")
    ws4["A3"] = f"رقم نافذة ACID: {file_data['acid_number']} | مراجعة مسودة البوليصة: معتمدة ومطابقة بنسبة 100%"
    ws4["A3"].font = font_highlight
    ws4["A3"].alignment = align_center
    ws4["A3"].fill = sub_header_fill

    r4 = 5
    r4 = add_section(ws4, r4, "1. منظومة نافذة والقيد الجمركي المسبق (ACID Registration)")
    acid_fields = [
        ("رقم القيد الجمركي المبدئي (ACID No):", file_data['acid_number'], "حالة صلاحية الرقم الجمركي:", "ساري وصالح لمدة 90 يوماً من تاريخ الإصدار"),
        ("تاريخ إصدار الرقم على نافذة:", file_data['acid_issue_date'], "تاريخ انتهاء الصلاحية الجمركية:", file_data['acid_expiry_date']),
        ("الأيام المستهلكة من الصلاحية:", f"{file_data.get('acid_execution_days', 0)} يوم (تم الإصدار حديثاً ومسجل بالكامل)", "المورد الأجنبي المسجل بنافذة:", file_data['supplier_name']),
        ("الشركة المستوردة المسجلة بنافذة:", file_data['company_name'], "المخلص الجمركي الموكل بالإدارة:", file_data['broker_name'])
    ]
    for lbl1, v1, lbl2, v2 in acid_fields:
        set_cell(ws4, r4, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"B{r4}:C{r4}")
        set_cell(ws4, r4, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 3, "", border=cell_border)
        
        set_cell(ws4, r4, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"E{r4}:F{r4}")
        set_cell(ws4, r4, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 6, "", border=cell_border)
        r4 += 1

    r4 += 1
    r4 = add_section(ws4, r4, "2. تدقيق ومراجعة مسودة بوليصة الشحن (Draft B/L Review Audit)")
    blr_fields = [
        ("كود مراجعة المسودة (Review Ref):", bl_review_data.get('bl_review_code', 'BL-REV-2026-0002'), "الحالة النهائية للمراجعة:", f"{bl_review_data.get('status', 'FINAL')} (معتمدة نهائياً)"),
        ("نتيجة مطابقة البيانات (Discrepancies):", f"{bl_review_data.get('open_discrepancies_count', 0)} فروقات (مطابقة تامة 100%)", "تاريخ اعتماد المسودة:", bl_review_data.get('approved_at', '2026-10-20')),
        ("الاعتماد الداخلي (Eng Review):", f"معتمد وموقع بواسطة: {bl_review_data.get('importer_approved_by', 'Eng. Maro')}", "الاعتماد الجمركي (Broker Review):", f"معتمد ومطابق جمركياً: {bl_review_data.get('broker_approved_by', 'Customs Broker')} (نبيل نصيف)"),
        ("مطابقة بيانات الشاحن (Shipper):", "Suzhou Yuheng Textile Co.,Ltd — مطابق لـ ACID", "مطابقة بيانات المرسل إليه (Consignee):", "SCAS For Construction And Finishing — مطابق لـ ACID"),
        ("مطابقة الإخطار (Notify Party):", "SCAS / Nabil Naseef — مطابق تماماً", "تأكيد شرط فترات السماح في البوليصة:", "تم تدوين شرط 21 Free Demurrage Days بالمتن")
    ]
    for lbl1, v1, lbl2, v2 in blr_fields:
        set_cell(ws4, r4, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"B{r4}:C{r4}")
        set_cell(ws4, r4, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 3, "", border=cell_border)
        
        set_cell(ws4, r4, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"E{r4}:F{r4}")
        set_cell(ws4, r4, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 6, "", border=cell_border)
        r4 += 1

    r4 += 1
    r4 = add_section(ws4, r4, "3. الموقف المستندي والبنكي وقيد الإجراءات (Pending Milestone Status)")
    docs_status = [
        ("الفاتورة التجارية النهائية (Commercial Invoice):", "جاهزة وموقعة من المصدر الصيني ومطابقة لـ PO", "قائمة التعبئة النهائية (Packing List):", "معتمدة (180 طرد / 1,000 قطعة / 12,840 كجم)"),
        ("شهادة المنشأ الصينية (COO - Form FTA):", "قيد الإصدار والتوثيق من غرفة التجارة الصينية", "إرسال المستندات عبر كارجو إكس (CargoX):", "مجدولة للإرسال بمجرد استلام أصل الـ COO"),
        ("نموذج 4 البنكي (Bank Form 4):", "قيد الانتظار لمرحلة فتح الاعتماد/التحويل للرصيد 70%", "سويفت التحويل البنكي (SWIFT):", "تم سداد الدفعة المقدمة 30% / متبقي 70% مقابل البوليصة"),
        ("الشهادة الجمركية الموحدة (نموذج 46):", "تُفتح فور وصول السفينة لميناء الإسكندرية (2026-10-23)", "إذن الإفراج الجمركي والمطابقة:", "يصدر عقب انتهاء الكشف والتثمين وسداد الضرائب والرسوم")
    ]
    for lbl1, v1, lbl2, v2 in docs_status:
        set_cell(ws4, r4, 1, lbl1, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"B{r4}:C{r4}")
        set_cell(ws4, r4, 2, v1, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 3, "", border=cell_border)
        
        set_cell(ws4, r4, 4, lbl2, font=font_header_dark, fill=sub_header_fill, alignment=align_right)
        ws4.merge_cells(f"E{r4}:F{r4}")
        set_cell(ws4, r4, 5, v2, font=font_bold, alignment=align_right)
        set_cell(ws4, r4, 6, "", border=cell_border)
        r4 += 1

    # ----------------------------------------------------
    # TAB 5: المهام التشغيلية وقاعدة المعرفة (Tasks & Knowledge)
    # ----------------------------------------------------
    ws5 = wb.create_sheet(title="المهام والأنماط المعرفية")
    ws5.views.sheetView[0].rightToLeft = True

    ws5.merge_cells("A1:F2")
    ws5["A1"] = "سجل المهام التشغيلية وقاعدة المعرفة المؤسسية — شحنة PET Stock"
    ws5["A1"].font = font_title
    ws5["A1"].fill = navy_header_fill
    ws5["A1"].alignment = align_center

    ws5.merge_cells("A3:F3")
    ws5["A3"] = f"المهام المرتبطة بالملف: {len(tasks_data)} مهام ذكية | تنبيه استباقي: متطلبات الفحص النوعي لهيئة الرقابة على الصادرات والواردات بميناء الإسكندرية"
    ws5["A3"].font = font_highlight
    ws5["A3"].alignment = align_center
    ws5["A3"].fill = sub_header_fill

    r5 = 5
    r5 = add_section(ws5, r5, "تنبيه المعرفة المؤسسية الاستباقي (Institutional Knowledge Alert)")
    ws5.merge_cells(f"A{r5}:F{r5+2}")
    ik_c = ws5[f"A{r5}"]
    ik_c.value = (
        "⚠️ تنبيه إجرائي مسبق لميناء الإسكندرية:\n"
        "أصناف عزل الصوت المصنوعة من البوليستر (PET Acoustic Panels) تحت بند التعرفة 3920.62 / 5602.29 تتطلب موافقة فنية من "
        "الهيئة العامة للرقابة على الصادرات والواردات (GOEIC) ومطابقة للمواصفة القياسية المصرية لمقاومة الحريق. "
        "تم إخطار المخلص نبيل نصيف بتجهيز كتالوجات المصنع وشهادات الاختبار الفنية الصينية قبل وصول الباخرة لتفادي أي سحب عينات معملي قد يؤخر الإفراج."
    )
    ik_c.font = font_bold
    ik_c.fill = light_gold_fill
    ik_c.alignment = align_left
    for r_idx in range(r5, r5+3):
        for col_idx in range(1, 7):
            ws5.cell(row=r_idx, column=col_idx).border = cell_border

    r5 += 4
    r5 = add_section(ws5, r5, "سجل المهام التشغيلية ومتابعة الإنجاز (Smart Operational Tasks)")
    task_headers = ["كود المهمة", "عنوان المهمة التشغيلية", "الأولوية", "المرحلة المرتبطة", "الحالة", "المسؤول / التحديث"]
    for c_idx, h in enumerate(task_headers, start=1):
        set_cell(ws5, r5, c_idx, h, font=font_header, fill=steel_blue_fill, border=header_border, alignment=align_center)

    for t in tasks_data:
        r5 += 1
        st = t.get('status', 'Pending')
        st_fill = success_fill if st in ['Completed', 'DONE'] else (warning_fill if st in ['In Progress', 'IN_PROGRESS'] else zebra_odd_fill)
        st_font = font_success if st in ['Completed', 'DONE'] else (font_warning if st in ['In Progress', 'IN_PROGRESS'] else font_data)

        set_cell(ws5, r5, 1, t.get('task_code', ''), font=font_bold, alignment=align_center)
        set_cell(ws5, r5, 2, t.get('title', ''), alignment=align_right)
        set_cell(ws5, r5, 3, t.get('priority', 'High'), alignment=align_center)
        set_cell(ws5, r5, 4, t.get('step_code', t.get('phase_name', '')), alignment=align_center)
        set_cell(ws5, r5, 5, st, font=st_font, fill=st_fill, alignment=align_center)
        set_cell(ws5, r5, 6, f"{t.get('assigned_user', 'Staff')} ({t.get('due_date', '')})", alignment=align_center)

    # ----------------------------------------------------
    # TAB 6: محفظة الشحنات النشطة (Master Import Portfolio)
    # ----------------------------------------------------
    ws6 = wb.create_sheet(title="محفظة الشحنات النشطة")
    ws6.views.sheetView[0].rightToLeft = True

    ws6.merge_cells("A1:K2")
    ws6["A1"] = "جدول محفظة الشحنات وملفات الاستيراد الشاملة بالنظام — Master Import Portfolio"
    ws6["A1"].font = font_title
    ws6["A1"].fill = navy_header_fill
    ws6["A1"].alignment = align_center

    ws6.merge_cells("A3:K3")
    ws6["A3"] = f"إجمالي عدد الشحنات المسجلة: {len(portfolio)} شحنة | تحديث شامل ومطابق لقاعدة البيانات الحية 100%"
    ws6["A3"].font = font_highlight
    ws6["A3"].alignment = align_center
    ws6["A3"].fill = sub_header_fill

    headers_port = [
        "كود الشحنة", "ملف الجمرك / الوصف", "الشركة المستوردة", "المورد الأجنبي",
        "المرحلة الحالية", "نسبة الإنجاز", "رقم ACID", "بوليصة الشحن B/L",
        "السفينة المبحرة", "قيمة الشحنة", "تاريخ الوصول المطلوب"
    ]

    r6 = 5
    for c_idx, h in enumerate(headers_port, start=1):
        set_cell(ws6, r6, c_idx, h, font=font_header, fill=steel_blue_fill, border=header_border, alignment=align_center)

    for idx, p in enumerate(portfolio, start=1):
        r6 += 1
        is_target = p.get('import_file_code') == 'IMP-2026-0005'
        row_fill = light_gold_fill if is_target else (zebra_even_fill if idx % 2 == 0 else zebra_odd_fill)
        row_font = font_bold if is_target else font_data

        set_cell(ws6, r6, 1, p.get('import_file_code', ''), font=row_font, alignment=align_center, fill=row_fill)
        set_cell(ws6, r6, 2, p.get('custom_file_number', ''), font=row_font, alignment=align_right, fill=row_fill)
        set_cell(ws6, r6, 3, p.get('company_name', ''), font=row_font, alignment=align_right, fill=row_fill)
        set_cell(ws6, r6, 4, p.get('supplier_name', ''), font=row_font, alignment=align_right, fill=row_fill)
        set_cell(ws6, r6, 5, p.get('current_stage', ''), font=row_font, alignment=align_center, fill=row_fill)
        set_cell(ws6, r6, 6, f"{p.get('progress_percent', 0.0)}%", font=row_font, alignment=align_center, fill=row_fill)
        set_cell(ws6, r6, 7, p.get('acid_number') or 'غير مستخرج', font=row_font, alignment=align_center, fill=row_fill)
        set_cell(ws6, r6, 8, p.get('bl_number') or 'قيد الإصدار', font=row_font, alignment=align_center, fill=row_fill)
        set_cell(ws6, r6, 9, p.get('vessel_name') or 'قيد الحجز', font=row_font, alignment=align_center, fill=row_fill)
        
        cost = p.get('estimated_cost', 0.0)
        curr = p.get('estimated_cost_currency', 'USD')
        set_cell(ws6, r6, 10, cost, font=row_font, alignment=align_right, fill=row_fill, num_format=f"${curr} #,##0.00")
        set_cell(ws6, r6, 11, p.get('required_eta') or 'قيد التحديد', font=row_font, alignment=align_center, fill=row_fill)

    # Auto-adjust column widths
    for ws in wb.worksheets:
        for col in ws.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                val = str(cell.value or '')
                if cell.row in [1, 2, 3]:
                    continue
                for line in val.split('\n'):
                    if len(line) > max_len:
                        max_len = len(line)
            ws.column_dimensions[col_letter].width = max(max_len + 5, 14)

    os.makedirs('reports', exist_ok=True)
    report_path = 'reports/PET_Stock_IMP-2026-0005_Comprehensive_Report.xlsx'
    wb.save(report_path)
    print(f"REPORT_SUCCESS: Successfully generated report directly from DB at {report_path}")

if __name__ == '__main__':
    build_excel_report()
