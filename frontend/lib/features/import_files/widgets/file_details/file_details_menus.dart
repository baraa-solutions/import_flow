// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';

/// 📋 Menus for Models & Simulations and Shipment Documents
class FileDetailsMenus {
  static Widget buildModelsAndSimulationsMenu({
    required BuildContext context,
    required ImportFileModel file,
    required bool isAr,
    required bool isDark,
    required void Function(String action) onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: isAr ? 'نماذج ومحاكاة الشحنة' : 'Models & Simulations',
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        _buildMenuItem(
          value: 'customs_sim',
          icon: Icons.calculate_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'المحاكاة الجمركية' : 'Customs Simulation',
          subtitle: isAr ? 'حساب الرسوم والضرائب التقديرية' : 'Estimated duties & taxes',
        ),
        _buildMenuItem(
          value: 'landed_cost_sim',
          icon: Icons.analytics_outlined,
          iconColor: AppTheme.emerald,
          title: isAr ? 'محاكاة تكلفة الوصول (Landed Cost)' : 'Landed Cost Simulation',
          subtitle: isAr ? 'تقدير تكلفة الوحدة والمصاريف' : 'Unit cost estimation',
        ),
        _buildMenuItem(
          value: 'fn01_advance',
          icon: Icons.payments_outlined,
          iconColor: AppTheme.orange,
          title: isAr ? 'طلب دفعة المورد (FN-01)' : 'Supplier Advance (FN-01)',
          subtitle: isAr ? 'إجراءات الاعتماد البنكي والدفعة' : 'Advance payment workflow',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'cs02_delivery_order',
          icon: Icons.directions_boat_filled_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'سداد إذن التسليم (CS-02)' : 'Delivery Order Payment (CS-02)',
          subtitle: isAr ? 'تسوية رسوم ومصاريف التوكيل الملاحي' : 'Shipping line fees',
        ),
        _buildMenuItem(
          value: 'cl02_duty_assessment',
          icon: Icons.calculate_outlined,
          iconColor: Colors.deepPurple,
          title: isAr ? 'احتساب الرسوم (CL-02)' : 'Duty Assessment (CL-02)',
          subtitle: isAr ? 'تقييم التعريفة الجمركية والقيمة' : 'Tariff & tax valuation',
        ),
        _buildMenuItem(
          value: 'cl03_duty_payment',
          icon: Icons.receipt_long_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'سداد الرسوم الجمركية (CL-03)' : 'Customs Duty Payment (CL-03)',
          subtitle: isAr ? 'سداد فواتير الجمارك والضرائب' : 'Customs tax payment',
        ),
        _buildMenuItem(
          value: 'cl05_clearance_invoices',
          icon: Icons.receipt_long_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'فواتير التخليص (CL-05)' : 'Clearance Invoices (CL-05)',
          subtitle: isAr ? 'مصاريف المخلص والجهات الرقابية' : 'Brokerage expenses',
        ),
        _buildMenuItem(
          value: 'lsi_partner_invoices',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'فواتير الشركاء اللوجستيين' : 'Logistics Invoices',
          subtitle: isAr ? 'مركز فواتير ومطالبات الشركاء' : 'Partner billing hub',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'clo01_settlement',
          icon: Icons.fact_check_outlined,
          iconColor: AppTheme.emerald,
          title: isAr ? 'تسوية الفواتير (CLO-01)' : 'Invoice Settlement (CLO-01)',
          subtitle: isAr ? 'المطابقة النهائية والتسوية المحاسبية' : 'Final matching & settlement',
        ),
        _buildMenuItem(
          value: 'clo02_actual_landed',
          icon: Icons.account_balance_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'التكلفة الفعلية (CLO-02)' : 'Actual Landed Cost (CLO-02)',
          subtitle: isAr ? 'حساب تكلفة الوصول النهائية الفردية' : 'Realized landed cost per unit',
        ),
        _buildMenuItem(
          value: 'audit_timeline_radar',
          icon: Icons.history_toggle_off_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'رادار ومحضر التتبع الزمني' : 'Audit Timeline Radar',
          subtitle: isAr ? 'سجل المحطات والمدد التشغيلية' : 'Full timeline stations SLA',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
            const SizedBox(width: 6),
            Text(
              isAr ? 'نماذج ومحاكاة ▾' : 'Models & Sim ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildShipmentDocumentsMenu({
    required BuildContext context,
    required ImportFileModel file,
    required bool isAr,
    required bool isDark,
    required void Function(String action) onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: isAr ? 'مستندات وإجراءات الشحنة' : 'Shipment Documents',
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        _buildMenuItem(
          value: 'dc01_acid',
          icon: Icons.verified_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'نافذة ورقم ACID (DC-01)' : 'Nafeza & ACID (DC-01)',
          subtitle: isAr ? 'إصدار وتتبع أرقام القيد الجمركي' : 'ACID issuance & tracking',
        ),
        _buildMenuItem(
          value: 'dc03_bank',
          icon: Icons.account_balance_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'المستندات البنكية ونموذج 4 (DC-03)' : 'Bank Documents (DC-03)',
          subtitle: isAr ? 'نموذج 4 البنكي والتحويلات' : 'Form 4 & SWIFT bank docs',
        ),
        _buildMenuItem(
          value: 'dc04_matrix',
          icon: Icons.fact_check_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'مصفوفة المستندات (DC-04)' : 'Document Matrix (DC-04)',
          subtitle: isAr ? 'مسودات الفواتير والباكينج ليست' : 'Drafts & document audit',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'bk01_booking',
          icon: Icons.directions_boat_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'حجز الشحن الملاحي (BK-01)' : 'Freight Booking (BK-01)',
          subtitle: isAr ? 'تأكيد الحجز وتخصيص الحاويات' : 'Booking & container allocation',
        ),
        _buildMenuItem(
          value: 'bk02_free_days',
          icon: Icons.verified_user_outlined,
          iconColor: AppTheme.emerald,
          title: isAr ? 'فترات السماح (BK-02)' : 'Free Days Agreement (BK-02)',
          subtitle: isAr ? 'أيام السماح وفترات غرامات التأخير' : 'Demurrage free time agreements',
        ),
        _buildMenuItem(
          value: 'sh01_sailing',
          icon: Icons.sailing_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'تأكيد الإبحار (SH-01)' : 'Sailing Confirmation (SH-01)',
          subtitle: isAr ? 'تسجيل تاريخ الإبحار الفعلي والـ ETA' : 'Departure & ETA updates',
        ),
        _buildMenuItem(
          value: 'sh02_draft_bl',
          icon: Icons.fact_check_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'مراجعة مسودة البوليصة (SH-02)' : 'Draft B/L Review (SH-02)',
          subtitle: isAr ? 'مطابقة بيانات البوليصة قبل الإصدار' : 'B/L data verification',
        ),
        _buildMenuItem(
          value: 'sh03_cargox',
          icon: Icons.cloud_upload_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'مستندات CargoX (SH-03)' : 'CargoX Documents (SH-03)',
          subtitle: isAr ? 'الرفع الرقمي عبر البلوكشين' : 'Blockchain document transfer',
        ),
        _buildMenuItem(
          value: 'sh04_original_docs',
          icon: Icons.markunread_mailbox_rounded,
          iconColor: AppTheme.orange,
          title: isAr ? 'تتبع أصول المستندات (SH-04)' : 'Original Docs Tracking (SH-04)',
          subtitle: isAr ? 'استلام ومتابعة البريد السريع' : 'Courier & original doc tracking',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'cs01_broker_auth',
          icon: Icons.assignment_ind_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'تفويض المخلص الجمركي (CS-01)' : 'Broker Authorization (CS-01)',
          subtitle: isAr ? 'خطاب تفويض ووكالة التخليص' : 'Broker delegation & power of attorney',
        ),
        _buildMenuItem(
          value: 'cs03_declaration_46',
          icon: Icons.description_rounded,
          iconColor: AppTheme.orange,
          title: isAr ? 'قيد إقرار 46 جمرك (CS-03)' : 'Customs Declaration 46 (CS-03)',
          subtitle: isAr ? 'رقم الشهادة الجمركية وقيد البيان' : 'Customs entry number',
        ),
        _buildMenuItem(
          value: 'cl01_inspection',
          icon: Icons.biotech_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'الكشف والمعاينة وسحب العينات (CL-01)' : 'Inspection & Sampling (CL-01)',
          subtitle: isAr ? 'محاضر الفحص ومعامل الرقابة' : 'Physical inspection records',
        ),
        _buildMenuItem(
          value: 'cl04_final_release',
          icon: Icons.verified_outlined,
          iconColor: AppTheme.emerald,
          title: isAr ? 'إذن الإفراج الجمركي (CL-04)' : 'Customs Final Release (CL-04)',
          subtitle: isAr ? 'الإفراج النهائي وخروج الحاويات' : 'Customs out-of-charge release',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'tr01_inland_transport',
          icon: Icons.local_shipping_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'النقل الداخلي (TR-01)' : 'Inland Transport (TR-01)',
          subtitle: isAr ? 'أوامر التحميل وحركة الشاحنات' : 'Trucking & gate dispatch',
        ),
        _buildMenuItem(
          value: 'tr02_demurrage_radar',
          icon: Icons.radar_rounded,
          iconColor: AppTheme.crimson,
          title: isAr ? 'رادار غرامات الحاويات (TR-02)' : 'Demurrage & Detention Radar',
          subtitle: isAr ? 'تتبع فترات السماح وتفادي الغرامات' : 'Container free-time tracking',
        ),
        _buildMenuItem(
          value: 'tr03_warehouse_receiving',
          icon: Icons.warehouse_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'استلام المخازن (TR-03)' : 'Warehouse Receiving (TR-03)',
          subtitle: isAr ? 'وصول الشحنة وإذن الاستلام' : 'GRN receiving & check-in',
        ),
        _buildMenuItem(
          value: 'tr04_warehouse_inspection',
          icon: Icons.fact_check_rounded,
          iconColor: AppTheme.orange,
          title: isAr ? 'محضر الفحص المخزني (TR-04)' : 'Warehouse Inspection (TR-04)',
          subtitle: isAr ? 'فحص الجودة والمطابقة والكميات' : 'QC & shortage inspection report',
        ),
        _buildMenuItem(
          value: 'tr05_empty_return',
          icon: Icons.assignment_turned_in_rounded,
          iconColor: AppTheme.charcoal,
          title: isAr ? 'إرجاع الحاويات الفارغة (TR-05)' : 'Empty Container Return (TR-05)',
          subtitle: isAr ? 'إيصالات EIR وساحات الإرجاع' : 'EIR slips & depot return',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'clo03_dossier',
          icon: Icons.assignment_turned_in_rounded,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'الملف الشامل (CLO-03)' : 'Comprehensive Dossier (CLO-03)',
          subtitle: isAr ? 'تصدير وأرشفة ملف الشحنة' : 'Full export archive',
        ),
        _buildMenuItem(
          value: 'clo04_official_closure',
          icon: Icons.verified_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'الإغلاق الرسمي للملف (CLO-04)' : 'Official Closure (CLO-04)',
          subtitle: isAr ? 'الأرشفة النهائية وإغلاق الملف' : 'Final archival & closure',
        ),
        _buildMenuItem(
          value: 'smart_checklist',
          icon: Icons.playlist_add_check_circle,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'قائمة التحقق الذكية' : 'Smart Checklist',
          subtitle: isAr ? 'مراجعة متطلبات ومستندات الملف' : 'Interactive readiness check',
        ),
        _buildMenuItem(
          value: 'add_kb_note',
          icon: Icons.psychology_outlined,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'توثيق درس مستفاد (KB Note)' : 'Add Knowledge Note',
          subtitle: isAr ? 'تسجيل ملاحظة في بنك المعرفة' : 'Document institutional learning',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_shared_outlined, size: 16, color: isDark ? Colors.tealAccent : AppTheme.cobalt),
            const SizedBox(width: 6),
            Text(
              isAr ? 'مستندات الشحنة ▾' : 'Shipment Docs ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
