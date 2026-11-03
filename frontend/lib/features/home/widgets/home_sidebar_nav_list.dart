import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../auth/models/user_model.dart';
import '../../smart_tasks/widgets/email_settings_dialog.dart';
import '../../smart_tasks/widgets/smart_email_listener_dialog.dart';

class HomeSidebarNavList extends ConsumerWidget {
  final String searchQuery;
  final int selectedIndex;
  final UserModel? user;

  const HomeSidebarNavList({
    super.key,
    required this.searchQuery,
    required this.selectedIndex,
    required this.user,
  });

  Widget _buildHubTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String titleEn,
    required String titleAr,
    required Color color,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final isSearching = searchQuery.isNotEmpty;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final title = isArabic ? titleAr : titleEn;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        hoverColor: const Color(0x0AFFFFFF),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Material(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(6),
          child: ExpansionTile(
            key: isSearching ? UniqueKey() : null,
            initiallyExpanded: isSearching ? true : initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            childrenPadding: const EdgeInsets.only(bottom: 2),
            leading: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            iconColor: color,
            collapsedIconColor: Colors.white54,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(WidgetRef ref, IconData icon, String titleEn, String titleAr, int index) {
    if (searchQuery.isNotEmpty &&
        !titleEn.toLowerCase().contains(searchQuery) &&
        !titleAr.toLowerCase().contains(searchQuery)) {
      return const SizedBox.shrink();
    }

    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final density = ref.watch(displayDensityProvider);
    final title = isArabic ? titleAr : titleEn;
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: isSelected
            ? const BorderDirectional(start: BorderSide(color: AppTheme.cobalt, width: 3))
            : null,
      ),
      child: Material(
        color: isSelected ? AppTheme.cobaltMedium : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => selectNavigationIndex(ref, index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: density == DisplayDensityMode.ultraCompact ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: density == DisplayDensityMode.ultraCompact ? 13.0 : 14.0,
                  color: isSelected ? AppTheme.cobalt : const Color(0xCCECF0F1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.cloudWhite,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: density.sidebarNavFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenuItem({
    required WidgetRef ref,
    required IconData icon,
    required String titleEn,
    required String titleAr,
    required VoidCallback onTap,
    Color? color,
  }) {
    if (searchQuery.isNotEmpty &&
        !titleEn.toLowerCase().contains(searchQuery) &&
        !titleAr.toLowerCase().contains(searchQuery)) {
      return const SizedBox.shrink();
    }

    final density = ref.watch(displayDensityProvider);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final title = isArabic ? titleAr : titleEn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: density == DisplayDensityMode.ultraCompact ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: density == DisplayDensityMode.ultraCompact ? 13.0 : 14.0,
                  color: color ?? const Color(0xCCECF0F1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color ?? AppTheme.cloudWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: density.sidebarNavFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.storage_outlined,
          titleEn: 'Master Data & Tables',
          titleAr: 'البيانات والجداول الأساسية',
          color: Colors.teal,
          children: [
            _buildMenuItem(ref, Icons.domain_outlined, 'Import Companies', 'الشركات المستوردة', 32),
            _buildMenuItem(ref, Icons.business_outlined, 'Foreign Suppliers', 'دليل الموردين الأجانب', 33),
            _buildMenuItem(ref, Icons.category_outlined, 'Master Items Catalog', 'كاتالوج الأصناف والسلع', 76),
            _buildMenuItem(ref, Icons.trending_up_outlined, 'Item Price Trends Radar', 'رادار اتجاه الأسعار ومقارنة الصفقات', 77),
            _buildMenuItem(ref, Icons.account_balance_outlined, 'Partners & Banks', 'الشركاء والبنوك ومقدمو الخدمات', 34),
            _buildMenuItem(ref, Icons.assignment_outlined, 'Projects & Cost Centers', 'المشاريع ومراكز التكلفة', 31),
            _buildMenuItem(ref, Icons.location_on_outlined, 'Ports & Locations', 'الموانئ والمنافذ الجمركية', 37),
            _buildMenuItem(ref, Icons.handshake_outlined, 'Incoterms Rules', 'الشروط التجارية الدولية', 35),
            _buildMenuItem(ref, Icons.description_outlined, 'Customs Tariff & HS Explorer', 'جدول ومستكشف التعريفة الجمركية', 36),
            _buildMenuItem(ref, Icons.currency_exchange_outlined, 'Currencies & Rates', 'العملات وأسعار الصرف', 38),
            _buildMenuItem(ref, Icons.receipt_long_outlined, 'Expense Catalog & Codes', 'كتالوج المصروفات الجمركية القياسي', 72),
            _buildMenuItem(ref, Icons.rule_outlined, 'Regulatory Requirements Matrix', 'مصفوفة المتطلبات الرقابية', 78),
            _buildMenuItem(ref, Icons.policy_outlined, 'Preferential Trade Agreements', 'الاتفاقيات التفضيلية وشهادات المنشأ', 84),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.folder_special_outlined,
          titleEn: 'Shipment Planning',
          titleAr: 'تخطيط الشحنة وأوامر الشراء',
          color: Colors.cyan,
          children: [
            _buildMenuItem(ref, Icons.folder_special_outlined, 'Import Files', 'ملفات الشحنات الاستيرادية', 1),
            _buildMenuItem(ref, Icons.shopping_cart_outlined, 'Purchase Orders & Origin', 'أوامر الشراء وإثبات المنشأ', 2),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.analytics_outlined,
          titleEn: '1. Pre-Planning & Studies',
          titleAr: 'المرحلة 1: التخطيط والدراسات المسبقة',
          color: Colors.amber.shade800,
          children: [
            _buildMenuItem(ref, Icons.analytics_outlined, 'Freight Studies & Saved Log', 'دراسة النولون والجدول الزمني والسجلات المحفوظة', 4),
            _buildMenuItem(ref, Icons.gavel_outlined, 'Customs Studies & Clearance RFQ', 'الدراسات الجمركية وعروض التخليص ومراجعة الضرائب', 6),
            _buildMenuItem(ref, Icons.verified_outlined, 'Import Regulatory Requirements', 'متطلبات واشتراطات الاستيراد للشحنة', 43),
            _buildMenuItem(ref, Icons.rate_review_outlined, 'Pre-Shipment Inspection & Vendor Rating', 'فحص ما قبل الشحن وتقييم أداء الموردين', 87),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.app_registration_outlined,
          titleEn: '2. Shipment Initiation',
          titleAr: 'المرحلة 2: بداية الشحنة والتسجيل المسبق',
          color: AppTheme.cobalt,
          children: [
            _buildMenuItem(ref, Icons.account_balance_wallet_outlined, 'Finance Approvals & Budget', 'اعتمادات الميزانية وسداد الموردين', 8),
            _buildMenuItem(ref, Icons.receipt_long_outlined, 'Logistics Invoices & Payments', 'فواتير ومدفوعات الخدمات اللوجستية', 70),
            _buildMenuItem(ref, Icons.account_balance_outlined, 'Trade Finance & Letters of Credit', 'اعتمادات وتمويل الاستيراد وفروق العملة', 79),
            _buildMenuItem(ref, Icons.qr_code_2_outlined, 'ACID Operations', 'الرقم التعريفي المبدئي للشحنة ACID', 11),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.assignment_turned_in_outlined,
          titleEn: '3. Booking & Doc Prep',
          titleAr: 'المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي',
          color: Colors.teal,
          children: [
            _buildMenuItem(ref, Icons.bookmark_added_outlined, 'Freight Booking', 'حجز النولون وتأكيد الخط الملاحي', 25),
            _buildMenuItem(ref, Icons.directions_boat_outlined, 'Cargo Shipping & Tracking', 'حركة وتتبع الشحن وتوزيع الحاويات', 26),
            _buildMenuItem(ref, Icons.call_split_outlined, 'Split Shipments & Allocations', 'تجزئة الشحنات وتوزيع بنود أوامر الشراء', 81),
            _buildMenuItem(ref, Icons.flight_takeoff_outlined, 'Multimodal Freight Operations', 'عمليات الشحن متعدد الوسائط', 82),
            _buildMenuItem(ref, Icons.warning_amber_rounded, 'Logistics Exceptions & Disputes', 'استثناءات الشحن ونزاعات التثمين الجمركي', 85),
            _buildMenuItem(ref, Icons.shield_outlined, 'Cargo Insurance', 'شهادات ووثائق التأمين على البضائع', 65),
            _buildMenuItem(ref, Icons.fact_check_outlined, '1. PO & Packing Reconciliation', '1. مطابقة الفاتورة والباكينج مع أمر الشراء', 21),
            _buildMenuItem(ref, Icons.assignment_turned_in_outlined, '2. Draft B/L Review & Approval', '2. مراجعة واعتماد مسودة بوليصة الشحن', 18),
            _buildMenuItem(ref, Icons.auto_awesome, '3. Smart Invoice vs B/L Match', '3. المطابقة الذكية بين الفاتورة والبوليصة', 22),
            _buildMenuItem(ref, Icons.flag_circle_outlined, '4. Draft COO & EUR.1 Review', '4. مسودة شهادة المنشأ و EUR.1', 19),
            _buildMenuItem(ref, Icons.security_outlined, '5. Inspection Review (COC)', '5. شهادات الفحص والتفتيش والمطابقة', 53),
            _buildMenuItem(ref, Icons.verified_user_outlined, '6. Docs Customs Approval Hub', '6. مركز اعتماد المستندات وتعديلات المورد', 20),
            _buildMenuItem(ref, Icons.document_scanner_outlined, 'AI Document Extraction Hub', 'مركز الاستخراج والتدقيق الذكي للمستندات', 75),
            _buildMenuItem(ref, Icons.inventory_2_outlined, 'Central Docs & Rectifications Hub', 'الأرشيف المركزي لمستندات وتعديلات الشحنة', 51),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.verified_user_outlined,
          titleEn: '4. Digital & Banking',
          titleAr: 'المرحلة 4: التوثيق الرقمي والاعتماد البنكي',
          color: AppTheme.crimson,
          children: [
            _buildMenuItem(ref, Icons.cloud_upload_outlined, 'Original Docs & CargoX Hub', 'أصول المستندات ومنظومة CargoX الرقمية', 54),
            _buildMenuItem(ref, Icons.account_balance_outlined, 'Bank Form 4', 'النموذج الإحصائي والتحويل البنكي نموذج 4', 16),
            _buildMenuItem(ref, Icons.mark_email_read_outlined, 'Formal Letters Drafting', 'محرر ومولد الخطابات الرسمية المعتمدة', 73),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.anchor_outlined,
          titleEn: '5. Port & Clearance',
          titleAr: 'المرحلة 5: الميناء والتخليص الجمركي',
          color: Colors.purple,
          children: [
            _buildMenuItem(ref, Icons.description_outlined, 'Customs Declaration 46', 'شهادة الإجراءات الجمركية إقرار 46 ك.م', 23),
            _buildMenuItem(ref, Icons.fact_check_outlined, 'Customs Clearance Hub', 'متابعة التخليص والكشف والعينات والرسوم', 27),
            _buildMenuItem(ref, Icons.account_balance_wallet_outlined, 'Customs Special Regimes', 'النظم الجمركية المعلقة والمناطق الحرة', 83),
            _buildMenuItem(ref, Icons.shield_outlined, 'Customs Custody Release', 'الإفراج تحت التحفظ وتعهدات البضائع', 74),
            _buildMenuItem(ref, Icons.timer_outlined, 'Demurrage & Detention', 'تتبع غرامات الأرضيات وحراسات الحاويات', 44),
            _buildMenuItem(ref, Icons.inventory_2_outlined, 'Container Lifecycle & Demurrage', 'دورة حياة الحاويات الفردية وغرامات التأخير', 80),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.inventory_outlined,
          titleEn: '6. Inbound & Closure',
          titleAr: 'المرحلة 6: الاستلام المخزني والتسوية المالية',
          color: AppTheme.emerald,
          children: [
            _buildMenuItem(ref, Icons.warehouse_outlined, 'Inbound & Warehouse Hub', 'مركز الاستلام والمخازن والبضاعة بالطريق', 28),
            _buildMenuItem(ref, Icons.savings_outlined, 'Deposits & Guarantees Recovery', 'استرداد تأمينات الحاويات والضمانات البنكية', 86),
            _buildMenuItem(ref, Icons.price_check_outlined, 'Landed Cost & Settlement Hub', 'تكلفة الوصول والتسوية المالية ومقارنة الفروق', 29),
            _buildMenuItem(ref, Icons.task_alt_outlined, 'Import File Final Closure', 'الإغلاق المالي والإداري لملف الاستيراد', 30),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.manage_search_outlined,
          titleEn: 'Inquiries',
          titleAr: 'استعلامات',
          color: Colors.indigoAccent,
          children: [
            _buildMenuItem(ref, Icons.travel_explore_rounded, 'Shipment History & Inquiry', 'استعلام وسجل الشحنات والتكاليف التاريخية', 68),
            _buildMenuItem(ref, Icons.request_quote_outlined, 'Freight RFQ & Quotations Comparison', 'طلب ومقارنة عروض النولون والترسية', 49),
            _buildMenuItem(ref, Icons.calculate_outlined, 'Cargo Measurement Engine', 'حاسبة الأحجام وتوزيع الحاويات', 3),
          ],
        ),
        _buildHubTile(
          context: context,
          ref: ref,
          icon: Icons.analytics_outlined,
          titleEn: 'Dashboard & Reports',
          titleAr: 'لوحة القيادة والتقارير والرقابة',
          color: Colors.blueGrey,
          children: [
            _buildMenuItem(ref, Icons.dashboard_customize_outlined, 'Operational Dashboard', 'لوحة التحكم ومؤشرات الأداء', 0),
            _buildMenuItem(ref, Icons.view_kanban_outlined, 'Lifecycle Operations Board', 'لوحة تتبع ومراحل الشحنات التفاعلية', 48),
            _buildMenuItem(ref, Icons.summarize_outlined, 'Master Shipment Report', 'تقرير الشحنة الشامل المدمج', 47),
            _buildMenuItem(ref, Icons.radar_outlined, 'SOON - Live Vessel Tracking Radar', 'SOON - رادار التتبع الحي لخطوط الملاحة والسفن', 71),
            _buildMenuItem(ref, Icons.assessment_outlined, 'Dynamic Report Builder', 'مُنشئ التقارير المخصصة', 41),
            _buildMenuItem(ref, Icons.published_with_changes_outlined, 'Quick Update Engine', 'محرك التحديث السريع', 42),
            _buildMenuItem(ref, Icons.task_alt_outlined, 'Smart Tasks & Alerts', 'المهام والتنبيهات الذكية', 40),
            _buildActionMenuItem(
              ref: ref,
              icon: Icons.mark_email_read_outlined,
              titleEn: 'Smart Email & Inbox Listener',
              titleAr: 'المستمع الذكي للبريد وإشعارات الوصول',
              color: AppTheme.cobalt,
              onTap: () => SmartEmailListenerDialog.show(context),
            ),
            if (EmailSettingsDialog.canAccess(user))
              _buildActionMenuItem(
                ref: ref,
                icon: Icons.settings_suggest_rounded,
                titleEn: 'Email Server Settings (IMAP/SMTP)',
                titleAr: 'إعدادات ربط البريد (IMAP/SMTP)',
                color: Colors.cyanAccent.shade700,
                onTap: () => EmailSettingsDialog.show(context),
              ),
            _buildMenuItem(ref, Icons.history_edu_outlined, 'System Audit Logs', 'سجل التدقيق والرقابة', 39),
            _buildMenuItem(ref, Icons.sync_alt_rounded, 'Production Sync Hub', 'مركز مزامنة وتحديث الإنتاج', 59),
            if (user == null || user!.isAdmin || user!.isManager)
              _buildMenuItem(ref, Icons.manage_accounts_rounded, 'Users & Permissions', 'إدارة المستخدمين والصلاحيات', 66),
            if (user != null && user!.canManageStepConfig)
              _buildMenuItem(ref, Icons.admin_panel_settings_rounded, 'Step Risk & Skip Config', 'إعدادات تصنيف مخاطر المراحل وحوكمة التخطي', 67),
            if (user == null || user!.isAdmin || user!.isManager)
              _buildMenuItem(ref, Icons.monitor_heart_outlined, 'System Observability & Health', 'مركز مراقبة وصحة النظام', 69),
          ],
        ),
      ],
    );
  }
}
