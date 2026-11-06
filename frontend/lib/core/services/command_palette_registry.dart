import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../localization/app_localizations_ar.dart';
import '../localization/locale_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/workspace_tabs_provider.dart';
import '../theme/theme_provider.dart';
import '../../features/demurrage_detention/widgets/freight_data_monitor_dialog.dart';
import '../../features/smart_tasks/widgets/smart_email_listener_dialog.dart';
import '../../features/smart_tasks/widgets/email_settings_dialog.dart';
import '../../features/production_sync/widgets/production_sync_hub_dialog.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../widgets/system_settings_dialog.dart';

enum CommandPaletteCategory {
  screens,
  actions,
  records,
}

class CommandPaletteItem {
  final String id;
  final String title;
  final String subtitle;
  final CommandPaletteCategory category;
  final IconData icon;
  final List<String> keywords;
  final String? badge;
  final int? routeIndex;
  final void Function(BuildContext context, WidgetRef ref)? onSelect;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.keywords,
    this.badge,
    this.routeIndex,
    this.onSelect,
  });
}

class CommandPaletteRegistry {
  static List<CommandPaletteItem> getItems(BuildContext context, WidgetRef ref) {
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        AppLocalizations.of(context) is AppLocalizationsAr;
    final List<CommandPaletteItem> items = [];

    // ── Helper to add screen destination ──
    void addScreen({
      required String id,
      required String titleAr,
      required String titleEn,
      required String subtitleAr,
      required String subtitleEn,
      required IconData icon,
      required int routeIndex,
      required List<String> keywords,
      String? badge,
    }) {
      items.add(
        CommandPaletteItem(
          id: id,
          title: isArabic ? titleAr : titleEn,
          subtitle: isArabic ? subtitleAr : subtitleEn,
          category: CommandPaletteCategory.screens,
          icon: icon,
          badge: badge,
          routeIndex: routeIndex,
          keywords: [...keywords, titleAr, titleEn, id],
          onSelect: (ctx, r) {
            r.read(navigationIndexProvider.notifier).state = routeIndex;
            final tabTitle = isArabic ? titleAr : titleEn;
            r.read(workspaceTabsProvider.notifier).openTab(
                  id: 'tab_$routeIndex',
                  title: tabTitle,
                  icon: icon,
                  routeIndex: routeIndex,
                );
          },
        ),
      );
    }

    // ── 1. SCREENS & WORKFLOW STAGES (35+ screens) ──
    addScreen(
      id: 'screen_dashboard',
      titleAr: 'لوحة التحكم التشغيلية',
      titleEn: 'Operational Dashboard',
      subtitleAr: 'المؤشرات العامة والشحنات القادمة والتنبيهات المباشرة',
      subtitleEn: 'Executive metrics, upcoming shipments & alerts',
      icon: Icons.dashboard_customize_outlined,
      routeIndex: 0,
      badge: isArabic ? 'رئيسي' : 'Main',
      keywords: ['dashboard', 'home', 'kpi', 'لوحة', 'مؤشرات', 'رئيسية'],
    );

    addScreen(
      id: 'screen_import_files',
      titleAr: 'ملفات الشحنات والاستيراد',
      titleEn: 'Import Files',
      subtitleAr: 'إدارة وتتبع كافة الشحنات وملفات الاستيراد المفتوحة',
      subtitleEn: 'Manage all import shipments and ongoing files',
      icon: Icons.folder_open_rounded,
      routeIndex: 1,
      badge: 'IMP',
      keywords: ['files', 'shipments', 'ملفات', 'شحنات', 'استيراد'],
    );

    addScreen(
      id: 'screen_purchase_orders',
      titleAr: 'أوامر الشراء والتوريد',
      titleEn: 'Purchase Orders (PO)',
      subtitleAr: 'أوامر الشراء، بنود الفواتير، وقوائم التعبئة المبدئية',
      subtitleEn: 'Line items, supplier commitments & packing',
      icon: Icons.shopping_cart_outlined,
      routeIndex: 2,
      badge: 'PO',
      keywords: ['po', 'orders', 'شراء', 'توريد', 'أوامر'],
    );

    addScreen(
      id: 'screen_cbm_calc',
      titleAr: 'حاسبة وتراصف الحاويات CBM',
      titleEn: 'CBM Calculator & 3D Packing',
      subtitleAr: 'حساب الحجم والوزن الحجمي وتراصف البالتات ثلاثي الأبعاد',
      subtitleEn: 'Volumetric weight, CBM & 3D container packing',
      icon: Icons.view_in_ar_rounded,
      routeIndex: 3,
      badge: 'CBM 3D',
      keywords: ['cbm', 'packing', 'volume', 'حجم', 'تراصف', 'حاويات'],
    );

    addScreen(
      id: 'screen_shipping_scenarios',
      titleAr: 'سيناريوهات الشحن ودراسة النولون',
      titleEn: 'Shipping Scenarios & Freight Studies',
      subtitleAr: 'مقارنة مسارات الشحن البحري والجوي والتكلفة التقديرية',
      subtitleEn: 'Multi-modal route comparisons and initial estimates',
      icon: Icons.alt_route_rounded,
      routeIndex: 4,
      keywords: ['scenarios', 'routes', 'مسارات', 'نولون', 'دراسة'],
    );

    addScreen(
      id: 'screen_customs_consultation',
      titleAr: 'الاستشارات الجمركية وبنود التعريفة',
      titleEn: 'Customs Consultation & Tariff Review',
      subtitleAr: 'فحص بنود التعريفة الجمركية والضرائب وتحديد الاشتراطات',
      subtitleEn: 'HS code tax rates and import compliance rules',
      icon: Icons.gavel_rounded,
      routeIndex: 6,
      badge: 'HS Codes',
      keywords: ['customs', 'tariff', 'hs', 'ضرائب', 'جمارك', 'تعريفة'],
    );

    addScreen(
      id: 'screen_financial_approval',
      titleAr: 'الموافقات المالية واعتماد الميزانية',
      titleEn: 'Financial Approvals & Budgets',
      subtitleAr: 'اعتماد بنود التكلفة وتخصيص الميزانيات التقديرية للشحنات',
      subtitleEn: 'Budget requests, cost center approvals & allocations',
      icon: Icons.account_balance_wallet_outlined,
      routeIndex: 8,
      badge: isArabic ? 'مالية' : 'Finance',
      keywords: ['finance', 'budget', 'ميزانية', 'اعتماد', 'مالي'],
    );

    addScreen(
      id: 'screen_nafeza_acid',
      titleAr: 'منظومة نافذة وأرقام ACID',
      titleEn: 'Nafeza ACID System & Pre-Shipment',
      subtitleAr: 'إصدار ومتابعة أرقام القيد المسبق للشحنات والتنبيهات',
      subtitleEn: '19-digit ACID generation, compliance & countdown',
      icon: Icons.qr_code_2_rounded,
      routeIndex: 11,
      badge: 'ACID',
      keywords: ['acid', 'nafeza', 'نافذة', 'شحن مسبق', 'تسجيل'],
    );

    addScreen(
      id: 'screen_bank_form4',
      titleAr: 'نموذج 4 البنكي والتظهيرات',
      titleEn: 'Bank Form 4 & Endorsements',
      subtitleAr: 'متابعة التحويلات البنكية وإصدار نموذج 4 الجمركي',
      subtitleEn: 'Bank transfer proof & Form 4 customs clearances',
      icon: Icons.account_balance_outlined,
      routeIndex: 16,
      badge: isArabic ? 'نموذج 4' : 'Form 4',
      keywords: ['form4', 'bank', 'بنك', 'نموذج 4', 'تظهير'],
    );

    addScreen(
      id: 'screen_step08_po',
      titleAr: 'مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء',
      titleEn: 'PO & Packing Reconciliation (STEP_08_PO)',
      subtitleAr: 'المطابقة الثلاثية الذكية بين الفاتورة والباكنج وأمر الشراء',
      subtitleEn: '3-way reconciliation across commercial invoice & PO',
      icon: Icons.receipt_long_rounded,
      routeIndex: 21,
      badge: 'STEP-08-PO',
      keywords: ['reconciliation', 'packing', 'فاتورة', 'باكنج', 'مطابقة'],
    );

    addScreen(
      id: 'screen_step08_bl',
      titleAr: 'مراجعة واعتماد مسودة بوليصة الشحن (B/L)',
      titleEn: 'Draft B/L Review & Approval (STEP_08_BL)',
      subtitleAr: 'مراجعة نصوص البوليصة ومطابقة بيانات الشاحن والمستلم والـ ACID',
      subtitleEn: 'Draft Bill of Lading inspection, matrix & certifications',
      icon: Icons.directions_boat_filled_outlined,
      routeIndex: 18,
      badge: 'STEP-08-BL',
      keywords: ['bl', 'bill of lading', 'بوليصة', 'شحن', 'مسودة'],
    );

    addScreen(
      id: 'screen_step08_match',
      titleAr: 'المطابقة الذكية بين الفاتورة والبوليصة',
      titleEn: 'Smart Invoice vs B/L Match (STEP_08_MATCH)',
      subtitleAr: 'الفحص الآلي ومصفوفة المقارنة وتحديث الموافقة الجمركية',
      subtitleEn: 'Automated discrepancy detector & customs approval sync',
      icon: Icons.compare_arrows_rounded,
      routeIndex: 22,
      badge: 'STEP-08-MATCH',
      keywords: ['matching', 'invoice bl', 'مطابقة', 'فحص', 'فروقات'],
    );

    addScreen(
      id: 'screen_step08_coo',
      titleAr: 'مسودة شهادة المنشأ و EUR.1',
      titleEn: 'Draft COO & EUR.1 Review (STEP_08_COO)',
      subtitleAr: 'مراجعة واعتماد شهادات المنشأ والاتفاقيات التفضيلية',
      subtitleEn: 'Certificate of origin review & preferential trade treaties',
      icon: Icons.verified_user_outlined,
      routeIndex: 19,
      badge: 'STEP-08-COO',
      keywords: ['coo', 'origin', 'eur1', 'منشأ', 'شهادة منشأ'],
    );

    addScreen(
      id: 'screen_step08_coc',
      titleAr: 'شهادات الفحص والتفتيش والمطابقة (COC)',
      titleEn: 'Inspection Review & COC (STEP_08_COC)',
      subtitleAr: 'شهادات المطابقة النوعية وفحص ما قبل الشحن',
      subtitleEn: 'Certificate of conformity and pre-shipment inspection',
      icon: Icons.fact_check_outlined,
      routeIndex: 53,
      badge: 'STEP-08-COC',
      keywords: ['coc', 'inspection', 'فحص', 'تفتيش', 'مطابقة'],
    );

    addScreen(
      id: 'screen_step09_approval',
      titleAr: 'مركز اعتماد المستندات الجمركية وتعديلات المورد',
      titleEn: 'Docs Customs Approval & Rectifications Hub',
      subtitleAr: 'اعتماد مستندات الشحن للتخليص وتتبع طلبات التعديل',
      subtitleEn: 'Official document clearances and supplier amendment tracking',
      icon: Icons.assignment_turned_in_rounded,
      routeIndex: 20,
      badge: 'STEP-09',
      keywords: ['customs approval', 'rectifications', 'اعتماد', 'موافقة'],
    );

    addScreen(
      id: 'screen_customs_dec46',
      titleAr: 'الإقرار الجمركي المبدئي والنهائي 46',
      titleEn: 'Customs Declaration 46 (Form 46)',
      subtitleAr: 'رقم الإقرار 46، تاريخ القيد، والمطابقة مع سداد الرسوم',
      subtitleEn: 'Customs release declaration 46 & registration log',
      icon: Icons.description_outlined,
      routeIndex: 23,
      badge: isArabic ? 'إقرار 46' : 'Form 46',
      keywords: ['declaration 46', 'form 46', 'إقرار', '46', 'جمارك'],
    );

    addScreen(
      id: 'screen_freight_booking',
      titleAr: 'حجز الفراغات الملاحية وبوالص الشحن',
      titleEn: 'Freight Booking Management',
      subtitleAr: 'تأكيد الحجز الملاحي، أرقام البوالص، وتاريخ الإبحار والوصول',
      subtitleEn: 'Ocean freight booking confirmations, ETD & ETA logs',
      icon: Icons.sailing_rounded,
      routeIndex: 25,
      keywords: ['booking', 'freight', 'حجز', 'فراغ', 'بوليصة'],
    );

    addScreen(
      id: 'screen_cargo_shipping',
      titleAr: 'الشحن البحري وتتبع الحاويات بالموانئ',
      titleEn: 'Cargo Shipping & Container Tracking',
      subtitleAr: 'أرقام الحاويات، الأختام الملاحية، ومحطات التتبع الخمسة',
      subtitleEn: 'Container tracking milestones, seals & gate-in logs',
      icon: Icons.local_shipping_outlined,
      routeIndex: 26,
      badge: isArabic ? 'حاويات' : 'Containers',
      keywords: ['containers', 'shipping', 'حاويات', 'شحن', 'تتبع'],
    );

    addScreen(
      id: 'screen_customs_clearance',
      titleAr: 'التخليص الجمركي بميناء الوصول',
      titleEn: 'Port Customs Clearance Followup',
      subtitleAr: 'الكشف والتثمين، الفحص النوعي، وسداد الضرائب والرسوم',
      subtitleEn: 'Port customs physical inspection, samples & tax payment',
      icon: Icons.how_to_reg_outlined,
      routeIndex: 27,
      keywords: ['clearance', 'تخليص', 'جمركي', 'إفراج', 'كشف'],
    );

    addScreen(
      id: 'screen_warehouse_receiving',
      titleAr: 'الاستلام المخزني وأذون الإضافة (GRN)',
      titleEn: 'Warehouse Receiving & Goods Receipt (GRN)',
      subtitleAr: 'وصول البضاعة للمخزن، محضر الاستلام، ومطابقة الكميات',
      subtitleEn: 'Goods received notes (GRN) & discrepancy resolution',
      icon: Icons.warehouse_rounded,
      routeIndex: 28,
      badge: 'GRN',
      keywords: ['warehouse', 'grn', 'مخزن', 'استلام', 'إذن إضافة'],
    );

    addScreen(
      id: 'screen_git_ledger',
      titleAr: 'سجل البضاعة بالطريق والمخزون المتحرك (GIT)',
      titleEn: 'Goods In Transit (GIT) Inventory Ledger',
      subtitleAr: 'حصر البضائع المشحونة التي لم تصل للمخازن بعد ومتابعتها',
      subtitleEn: 'Live ledger of floating inventory and shipments at sea',
      icon: Icons.move_to_inbox_rounded,
      routeIndex: 57, // Inbound hub, tab 0 = GIT ledger (63 is the import requirements matrix)
      badge: 'GIT',
      keywords: ['git', 'transit', 'بضاعة بالطريق', 'مخزون متحرك'],
    );

    addScreen(
      id: 'screen_landed_cost',
      titleAr: 'التكلفة الاستيرادية الشاملة والتسوية',
      titleEn: 'Financial Settlement & Landed Cost Engine',
      subtitleAr: 'حساب التكلفة الفعلية الشاملة للوحدة ومقارنتها بالتقديري',
      subtitleEn: 'Actual landed cost breakdown, variance & final settlement',
      icon: Icons.monetization_on_outlined,
      routeIndex: 29,
      badge: 'Landed Cost',
      keywords: ['landed cost', 'settlement', 'تكلفة', 'تسوية', 'تكلفة فعلية'],
    );

    addScreen(
      id: 'screen_file_closure',
      titleAr: 'الإغلاق النهائي لملف الاستيراد',
      titleEn: 'Import File Final Closure & Archiving',
      subtitleAr: 'التدقيق النهائي لكافة المراحل وإصدار شهادة الإغلاق',
      subtitleEn: 'Final multi-stage audit and official closure certificate',
      icon: Icons.check_circle_outline_rounded,
      routeIndex: 30,
      badge: isArabic ? 'إغلاق' : 'Closure',
      keywords: ['closure', 'archive', 'إغلاق', 'أرشفة', 'شهادة'],
    );

    addScreen(
      id: 'screen_demurrage_radar',
      titleAr: 'متابعة غرامات التوكيل وأرضيات الموانئ',
      titleEn: 'Demurrage & Detention Radar',
      subtitleAr: 'عداد غرامات الحاويات بالدولار وأرضيات الموانئ بالجنيه',
      subtitleEn: 'Dual radar for carrier detention (USD) & port storage (EGP)',
      icon: Icons.timer_outlined,
      routeIndex: 44,
      badge: isArabic ? 'غرامات' : 'Demurrage',
      keywords: ['demurrage', 'detention', 'غرامات', 'أرضيات', 'توكيل'],
    );

    addScreen(
      id: 'screen_lifecycle_board',
      titleAr: 'لوحة دورة حياة الشحنات والمراحل',
      titleEn: 'Shipment Central Lifecycle Board',
      subtitleAr: 'استعراض المسار التفاعلي للمراحل الـ 25 لكافة الشحنات',
      subtitleEn: 'Interactive 25-step visual lifecycle board for shipments',
      icon: Icons.route_rounded,
      routeIndex: 48,
      badge: isArabic ? 'المسار' : 'Lifecycle',
      keywords: ['lifecycle', 'steps', 'board', 'دورة حياة', 'مراحل'],
    );

    addScreen(
      id: 'screen_freight_quotes_comp',
      titleAr: 'مقارنة ومفاضلة عروض أسعار النولون',
      titleEn: 'Freight Quotations Benchmark & Comparison',
      subtitleAr: 'استخراج العروض والمفاضلة الذكية وتحديد العرض الفائز',
      subtitleEn: 'AI quotation benchmark, ranking & award decisions',
      icon: Icons.price_check_rounded,
      routeIndex: 49,
      badge: 'RFQ Benchmark',
      keywords: ['rfq', 'quotations', 'نولون', 'عروض أسعار', 'مقارنة'],
    );

    addScreen(
      id: 'screen_central_archive',
      titleAr: 'الأرشيف الرقمي المركزي للمستندات',
      titleEn: 'Central Digital Documents Archive',
      subtitleAr: 'مستودع الوثائق الرسمية والشهادات والفواتير الأصلية',
      subtitleEn: 'Digital repository for official shipping dossiers & bills',
      icon: Icons.source_outlined,
      routeIndex: 51,
      badge: isArabic ? 'أرشيف' : 'Archive',
      keywords: ['archive', 'documents', 'أرشيف', 'مستندات', 'وثائق'],
    );

    addScreen(
      id: 'screen_marine_insurance',
      titleAr: 'وثائق التأمين البحري على الشحنات',
      titleEn: 'Cargo Marine Insurance Policies',
      subtitleAr: 'إصدار وتتبع بوالص التأمين البحري والتغطيات التأمينية',
      subtitleEn: 'Marine insurance certificates, Institute Cargo Clauses',
      icon: Icons.security_rounded,
      routeIndex: 65,
      badge: isArabic ? 'تأمين' : 'Insurance',
      keywords: ['insurance', 'marine', 'تأمين', 'بحري', 'بوليصة تأمين'],
    );

    addScreen(
      id: 'screen_smart_inquiry',
      titleAr: 'الاستعلام الذكي عن الشحنات وسجل الأسعار',
      titleEn: 'Smart Shipment Inquiry, History & Cloning',
      subtitleAr: 'البحث الشامل وسجل أسعار النولون واستنساخ الشحنات المتكررة',
      subtitleEn: 'Multi-criteria shipment finder, freight history & clone',
      icon: Icons.manage_search_rounded,
      routeIndex: 68,
      badge: 'Inquiry',
      keywords: ['inquiry', 'search', 'clone', 'استعلام', 'بحث', 'استنساخ'],
    );

    addScreen(
      id: 'screen_logistics_invoices',
      titleAr: 'فواتير ومدفوعات الخدمات اللوجستية',
      titleEn: 'Logistics Invoices & Payments',
      subtitleAr: 'فواتير الخدمات وسندات الصرف والعُهد وتأمين البضائع',
      subtitleEn: 'Service invoices, payment vouchers, advances & cargo insurance',
      icon: Icons.receipt_long_outlined,
      routeIndex: 70,
      keywords: ['invoice', 'payment', 'advance', 'فواتير', 'سندات صرف', 'عهد'],
    );

    addScreen(
      id: 'screen_expense_catalog',
      titleAr: 'كتالوج المصروفات الجمركية القياسي',
      titleEn: 'Expense Catalog & Codes',
      subtitleAr: 'أكواد المصروفات الموحدة وربطها بالمخلصين',
      subtitleEn: 'Standard coded expenses and broker mappings',
      icon: Icons.receipt_long_outlined,
      routeIndex: 72,
      keywords: ['expense', 'catalog', 'مصروفات', 'كتالوج'],
    );

    addScreen(
      id: 'screen_formal_letters',
      titleAr: 'محرر ومولد الخطابات الرسمية المعتمدة',
      titleEn: 'Formal Letters Drafting',
      subtitleAr: 'توليد الخطابات الرسمية للجمارك والجهات والبنوك',
      subtitleEn: 'Official letters to customs, agencies and banks',
      icon: Icons.mark_email_read_outlined,
      routeIndex: 73,
      keywords: ['letter', 'خطاب', 'خطابات'],
    );

    addScreen(
      id: 'screen_custody_release',
      titleAr: 'الإفراج تحت التحفظ وتعهدات البضائع',
      titleEn: 'Customs Custody Release',
      subtitleAr: 'الإفراج المؤقت تحت التحفظ ومتابعة التعهدات',
      subtitleEn: 'Under-bond custody release and undertakings',
      icon: Icons.shield_outlined,
      routeIndex: 74,
      keywords: ['custody', 'release', 'تحفظ', 'إفراج', 'تعهد'],
    );

    addScreen(
      id: 'screen_smart_upload_hub',
      titleAr: 'مركز الاستخراج والتدقيق الذكي للمستندات',
      titleEn: 'AI Document Extraction Hub',
      subtitleAr: 'رفع المستندات واستخراج بياناتها ومطابقتها',
      subtitleEn: 'Upload documents, extract data and cross-check',
      icon: Icons.document_scanner_outlined,
      routeIndex: 75,
      keywords: ['upload', 'extract', 'رفع', 'استخراج', 'مستندات'],
    );

    addScreen(
      id: 'screen_master_items',
      titleAr: 'كاتالوج الأصناف والسلع',
      titleEn: 'Master Items Catalog',
      subtitleAr: 'الأصناف الموحدة وبنود التعريفة وأسعار الموردين',
      subtitleEn: 'Unified items, HS codes and supplier prices',
      icon: Icons.category_outlined,
      routeIndex: 76,
      keywords: ['items', 'catalog', 'أصناف', 'سلع'],
    );

    addScreen(
      id: 'screen_item_price_trends',
      titleAr: 'رادار اتجاه الأسعار ومقارنة الصفقات',
      titleEn: 'Item Price Trends Radar',
      subtitleAr: 'تاريخ أسعار الأصناف ومقارنة الصفقات بين الموردين',
      subtitleEn: 'Item price history and supplier deal comparison',
      icon: Icons.trending_up_outlined,
      routeIndex: 77,
      keywords: ['price', 'trend', 'أسعار', 'اتجاه'],
    );

    addScreen(
      id: 'screen_regulatory_matrix',
      titleAr: 'مصفوفة المتطلبات الرقابية',
      titleEn: 'Regulatory Requirements Matrix',
      subtitleAr: 'المتطلبات الرقابية والجهات المختصة لكل بند',
      subtitleEn: 'Regulatory requirements and authorities per item',
      icon: Icons.rule_outlined,
      routeIndex: 78,
      keywords: ['regulatory', 'matrix', 'رقابية', 'متطلبات'],
    );

    addScreen(
      id: 'screen_trade_finance',
      titleAr: 'اعتمادات وتمويل الاستيراد وفروق العملة',
      titleEn: 'Trade Finance & Letters of Credit',
      subtitleAr: 'الاعتمادات المستندية والتمويل وفروق العملة',
      subtitleEn: 'Letters of credit, import finance and FX differences',
      icon: Icons.account_balance_outlined,
      routeIndex: 79,
      keywords: ['lc', 'letter of credit', 'finance', 'اعتماد', 'تمويل'],
    );

    addScreen(
      id: 'screen_container_lifecycle',
      titleAr: 'دورة حياة الحاويات الفردية وغرامات التأخير',
      titleEn: 'Container Lifecycle & Demurrage',
      subtitleAr: 'تتبع كل حاوية وغرامات الأرضيات والتأخير',
      subtitleEn: 'Per-container tracking, demurrage and detention',
      icon: Icons.inventory_2_outlined,
      routeIndex: 80,
      keywords: ['container', 'demurrage', 'حاوية', 'أرضيات', 'غرامات'],
    );

    addScreen(
      id: 'screen_split_shipments',
      titleAr: 'تجزئة الشحنات وتوزيع بنود أوامر الشراء',
      titleEn: 'Split Shipments & Allocations',
      subtitleAr: 'توزيع بنود أوامر الشراء على البوالص الجزئية',
      subtitleEn: 'Allocate PO lines across partial bills of lading',
      icon: Icons.call_split_outlined,
      routeIndex: 81,
      keywords: ['split', 'partial', 'allocation', 'تجزئة', 'جزئية'],
    );

    addScreen(
      id: 'screen_multimodal_freight',
      titleAr: 'عمليات الشحن متعدد الوسائط',
      titleEn: 'Multimodal Freight Operations',
      subtitleAr: 'الشحن الجوي والمجمّع والرورو والصب',
      subtitleEn: 'Air, LCL, Ro-Ro and bulk freight',
      icon: Icons.flight_takeoff_outlined,
      routeIndex: 82,
      keywords: ['multimodal', 'air', 'lcl', 'جوي', 'متعدد الوسائط'],
    );

    addScreen(
      id: 'screen_customs_regimes',
      titleAr: 'النظم الجمركية المعلقة والمناطق الحرة',
      titleEn: 'Customs Special Regimes',
      subtitleAr: 'الدروباك والمناطق الحرة والإدخال المؤقت',
      subtitleEn: 'Drawback, free zones and temporary admission',
      icon: Icons.account_balance_wallet_outlined,
      routeIndex: 83,
      keywords: ['regime', 'free zone', 'drawback', 'مناطق حرة', 'سماح مؤقت'],
    );

    addScreen(
      id: 'screen_trade_agreements',
      titleAr: 'الاتفاقيات التفضيلية وشهادات المنشأ',
      titleEn: 'Preferential Trade Agreements',
      subtitleAr: 'الاتفاقيات التجارية والتحقق من شهادات المنشأ',
      subtitleEn: 'Trade agreements and origin certificate checks',
      icon: Icons.policy_outlined,
      routeIndex: 84,
      keywords: ['agreement', 'origin', 'اتفاقية', 'منشأ'],
    );

    addScreen(
      id: 'screen_logistics_exceptions',
      titleAr: 'استثناءات الشحن ونزاعات التثمين الجمركي',
      titleEn: 'Logistics Exceptions & Disputes',
      subtitleAr: 'تأجيل الشحن ونزاعات التثمين والتظلمات',
      subtitleEn: 'Roll-overs, valuation disputes and appeals',
      icon: Icons.warning_amber_rounded,
      routeIndex: 85,
      keywords: ['exception', 'dispute', 'استثناء', 'نزاع', 'تثمين'],
    );

    addScreen(
      id: 'screen_deposits_recovery',
      titleAr: 'استرداد تأمينات الحاويات والضمانات البنكية',
      titleEn: 'Deposits & Guarantees Recovery',
      subtitleAr: 'استرداد تأمينات الحاويات وخطابات الضمان',
      subtitleEn: 'Container deposits and bank guarantee recovery',
      icon: Icons.savings_outlined,
      routeIndex: 86,
      keywords: ['deposit', 'guarantee', 'تأمين', 'ضمان', 'استرداد'],
    );

    addScreen(
      id: 'screen_vendor_quality',
      titleAr: 'فحص ما قبل الشحن وتقييم أداء الموردين',
      titleEn: 'Pre-Shipment Inspection & Vendor Rating',
      subtitleAr: 'فحص البضاعة قبل الشحن وتقييم الموردين',
      subtitleEn: 'Pre-shipment inspection and vendor scorecards',
      icon: Icons.rate_review_outlined,
      routeIndex: 87,
      keywords: ['psi', 'inspection', 'vendor', 'فحص', 'موردين'],
    );

    // ── Master Data Screens ──
    addScreen(
      id: 'screen_master_companies',
      titleAr: 'الشركات المستوردة والبطاقات الاستيرادية',
      titleEn: 'Importing Companies & Tax Cards',
      subtitleAr: 'الشركات المصرية والبطاقات الاستيرادية والسجلات',
      subtitleEn: 'Egyptian importing entities and regulatory cards',
      icon: Icons.apartment_rounded,
      routeIndex: 32,
      badge: 'Master',
      keywords: ['companies', 'importers', 'شركات', 'مستوردين'],
    );

    addScreen(
      id: 'screen_master_suppliers',
      titleAr: 'الموردون الأجانب والشركاء الدوليون',
      titleEn: 'Foreign Suppliers & Manufacturers',
      subtitleAr: 'بيانات المصانع والموردين في الخارج وسجل التعاملات',
      subtitleEn: 'International manufacturers and vendor directory',
      icon: Icons.business_rounded,
      routeIndex: 33,
      badge: 'Master',
      keywords: ['suppliers', 'vendors', 'موردين', 'مصانع', 'أجانب'],
    );

    addScreen(
      id: 'screen_master_partners',
      titleAr: 'شركات الشحن، التوكيلات، المستخلصين، والبنوك',
      titleEn: 'Partners, Shipping Lines & Clearance Brokers',
      subtitleAr: 'سجل وكلاء الشحن والمستخلصين الجمركيين والبنوك المعتمدة',
      subtitleEn: 'External service providers, freight forwarders & banks',
      icon: Icons.handshake_outlined,
      routeIndex: 34,
      badge: 'Master',
      keywords: ['partners', 'brokers', 'banks', 'توكيلات', 'مستخلصين', 'بنوك'],
    );

    addScreen(
      id: 'screen_master_ports',
      titleAr: 'الموانئ والمواقع اللوجستية العالمية والمحلية',
      titleEn: 'Ports & Transport Locations',
      subtitleAr: 'الموانئ البحرية والجوية والجافة والمنافذ الحدودية',
      subtitleEn: 'Airports, seaports, dry ports and boundary customs outlets',
      icon: Icons.anchor_rounded,
      routeIndex: 37,
      badge: 'Master',
      keywords: ['ports', 'locations', 'موانئ', 'مطارات', 'منافذ'],
    );

    addScreen(
      id: 'screen_master_tariff',
      titleAr: 'جدول التعريفة الجمركية المصرية (HS Codes)',
      titleEn: 'Customs Tariff Schedule (MD-008)',
      subtitleAr: 'البنود الجمركية وفئات الضرائب والرسوم والاتفاقيات',
      subtitleEn: 'Egyptian customs tariff schedule and duty percentages',
      icon: Icons.table_chart_outlined,
      routeIndex: 36,
      badge: 'Master',
      keywords: ['tariff', 'hs code', 'تعريفة', 'بنود', 'ضرائب'],
    );

    addScreen(
      id: 'screen_master_currencies',
      titleAr: 'العملات وأسعار الصرف الرسمية',
      titleEn: 'Currencies & Official Exchange Rates',
      subtitleAr: 'أسعار صرف العملات بالبنك المركزي والجمارك المصرية',
      subtitleEn: 'Daily foreign currencies and customs official exchange rates',
      icon: Icons.currency_exchange_rounded,
      routeIndex: 38,
      badge: 'Master',
      keywords: ['currencies', 'exchange', 'عملات', 'صرف', 'دولار', 'يورو'],
    );

    addScreen(
      id: 'screen_master_incoterms',
      titleAr: 'الشروط التجارية الدولية (Incoterms 2020)',
      titleEn: 'International Commercial Terms (Incoterms)',
      subtitleAr: 'مصفوفة المسؤوليات والمخاطر ومصاريف الشحن',
      subtitleEn: 'Incoterms rules, cost matrix & freight responsibilities',
      icon: Icons.rule_folder_outlined,
      routeIndex: 35,
      badge: 'Master',
      keywords: ['incoterms', 'fob', 'cif', 'إنكوتيرمز', 'شروط التسليم'],
    );

    addScreen(
      id: 'screen_audit_logs',
      titleAr: 'سجل تدقيق وتغييرات النظام (Audit Trail)',
      titleEn: 'System Audit Trail & Security Logs',
      subtitleAr: 'سجل كافة العمليات والتعديلات المنفذة على النظام وتوقيتاتها',
      subtitleEn: 'Comprehensive log of all user activities and data changes',
      icon: Icons.history_rounded,
      routeIndex: 39,
      badge: isArabic ? 'أمان' : 'Security',
      keywords: ['audit', 'logs', 'سجل', 'تغييرات', 'تدقيق', 'أمان'],
    );

    addScreen(
      id: 'screen_users_management',
      titleAr: 'إدارة المستخدمين والصلاحيات (RBAC)',
      titleEn: 'Users Management & RBAC Roles',
      subtitleAr: 'تحديد صلاحيات المشغلين والمدراء وحسابات الوصول',
      subtitleEn: 'Role-based access control and operator credentials',
      icon: Icons.manage_accounts_outlined,
      routeIndex: 66,
      badge: 'Admin',
      keywords: ['users', 'roles', 'rbac', 'مستخدمين', 'صلاحيات'],
    );

    // ── 2. QUICK ACTIONS & UTILITIES ──
    items.add(
      CommandPaletteItem(
        id: 'action_freight_data_connector',
        title: isArabic ? 'موصل بيانات الشحن البحري والغرامات المجاني' : 'Free Freight & Demurrage Data Connector',
        subtitle: isArabic ? 'مزامنة مؤشر النولون SFX وفحص غرامات الحاويات وأرضيات الموانئ' : 'Sync SFX index & calculate dual demurrage',
        category: CommandPaletteCategory.actions,
        icon: Icons.cloud_sync_outlined,
        badge: 'Free Tool',
        keywords: ['freight data', 'shaq', 'shippingrates', 'نولون', 'غرامات', 'موصل'],
        onSelect: (ctx, r) => showFreightDataMonitorDialog(ctx, r),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_toggle_theme',
        title: isArabic ? 'تبديل مظهر النظام (داكن / نهاري)' : 'Toggle System Theme (Dark / Light)',
        subtitle: isArabic ? 'التحويل الفوري بين الوضع الليلي والوضع النهاري' : 'Switch theme appearance between Dark and Light mode',
        category: CommandPaletteCategory.actions,
        icon: Icons.brightness_6_rounded,
        badge: isArabic ? 'واجهة' : 'UI',
        keywords: ['theme', 'dark', 'light', 'مظهر', 'داكن', 'نهاري', 'ثيم'],
        onSelect: (ctx, r) => r.read(themeModeProvider.notifier).toggleTheme(),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_toggle_language',
        title: isArabic ? 'تبديل لغة الواجهة (العربية / English)' : 'Toggle Interface Language (Arabic / English)',
        subtitle: isArabic ? 'التبديل الفوري بين اللغة العربية والإنجليزية' : 'Switch between Arabic and English localization',
        category: CommandPaletteCategory.actions,
        icon: Icons.language_rounded,
        badge: isArabic ? 'لغة' : 'Lang',
        keywords: ['language', 'arabic', 'english', 'لغة', 'عربي', 'إنجليزي'],
        onSelect: (ctx, r) => r.read(localeProvider.notifier).toggleLocale(),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_smart_email_listener',
        title: isArabic ? 'المستمع الذكي للبريد وإشعارات الوصول' : 'Smart Email & Arrival Notice Listener',
        subtitle: isArabic ? 'فحص رسائل التوكيلات الملاحية واستخراج بيانات الوصول' : 'Auto-listen to carrier emails and arrival notices',
        category: CommandPaletteCategory.actions,
        icon: Icons.mark_email_read_outlined,
        badge: 'AI Mail',
        keywords: ['email', 'mail', 'arrival', 'بريد', 'إشعار وصول'],
        onSelect: (ctx, r) => SmartEmailListenerDialog.show(ctx),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_email_settings',
        title: isArabic ? 'إعدادات ربط البريد الإلكتروني (IMAP / SMTP)' : 'Email Server Configuration (IMAP / SMTP)',
        subtitle: isArabic ? 'تكوين خوادم الربط الآلي للبريد الوارد والصادر' : 'Configure email host, port, credentials & encryption',
        category: CommandPaletteCategory.actions,
        icon: Icons.settings_suggest_rounded,
        badge: 'Email',
        keywords: ['smtp', 'imap', 'settings', 'إعدادات البريد'],
        onSelect: (ctx, r) => EmailSettingsDialog.show(ctx),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_production_sync',
        title: isArabic ? 'مركز حالة الإنتاج والنسخ الاحتياطية' : 'Production Status & Backups Hub',
        subtitle: isArabic ? 'مقارنة قواعد البيانات (قراءة فقط) وعرض النسخ الاحتياطية' : 'Compare databases (read-only) & view backups',
        category: CommandPaletteCategory.actions,
        icon: Icons.cloud_done_rounded,
        badge: 'Status',
        keywords: ['production', 'sync', 'backup', 'compare', 'إنتاج', 'مزامنة', 'نسخ احتياطي'],
        onSelect: (ctx, r) => showDialog(
          context: ctx,
          builder: (_) => const ProductionSyncHubDialog(),
        ),
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_system_settings',
        title: isArabic ? 'الإعدادات الأساسية للنظام (اللغة، المظهر، الكثافة)' : 'Basic System Settings (Language, Theme, Density)',
        subtitle: isArabic ? 'تخصيص لغة الواجهة، وضع المظهر، كثافة عرض الجداول، وتشخيص البيئة' : 'Configure interface language, appearance theme, display density, and diagnostics',
        category: CommandPaletteCategory.actions,
        icon: Icons.tune_rounded,
        badge: isArabic ? 'إعدادات' : 'Config',
        keywords: ['settings', 'preferences', 'language', 'theme', 'density', 'إعدادات', 'خيارات', 'لغة', 'مظهر', 'كثافة'],
        onSelect: (ctx, r) => SystemSettingsDialog.show(ctx),
      ),
    );

    // ── 3. OPERATIONAL RECORDS (Active Import Files) ──
    try {
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      for (final f in files.take(20)) {
        final code = f.importFileCode;
        final importer = f.companyName;
        final supplier = f.supplierName;
        items.add(
          CommandPaletteItem(
            id: 'file_${f.importFileId}',
            title: isArabic ? 'شحنة: ${f.primaryNameWithCode}' : 'Shipment: ${f.primaryNameWithCode}',
            subtitle: isArabic
                ? 'المستورد: $importer │ المورد: $supplier'
                : 'Importer: $importer │ Supplier: $supplier',
            category: CommandPaletteCategory.records,
            icon: Icons.inventory_2_outlined,
            badge: f.status,
            keywords: [code, importer, supplier, 'شحنة', 'ملف', 'shipment', 'imp'],
            onSelect: (ctx, r) {
              r.read(navigationIndexProvider.notifier).state = 1;
              r.read(workspaceTabsProvider.notifier).openTab(
                    id: 'tab_1',
                    title: isArabic ? 'ملفات الشحنات' : 'Import Files',
                    icon: Icons.folder_open_rounded,
                    routeIndex: 1,
                  );
            },
          ),
        );
      }
    } catch (_) {
      // Gracefully ignore if provider not ready
    }

    return items;
  }
}
