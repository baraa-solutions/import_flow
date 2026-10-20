import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum CustomsExpenseGroup {
  lclFees(
    key: 'lcl_fees',
    titleAr: 'أتعاب تخليص LCL',
    titleEn: 'LCL Clearance Fees',
    icon: Icons.receipt_long_rounded,
    badgeColor: AppTheme.cobalt,
  ),
  lclExpenses(
    key: 'lcl_expenses',
    titleAr: 'مصاريف تخليص LCL',
    titleEn: 'LCL Clearance Expenses',
    icon: Icons.inventory_2_outlined,
    badgeColor: AppTheme.cobalt,
  ),
  fcl20(
    key: 'fcl20',
    titleAr: 'أتعاب ومصاريف تخليص FCL 20 قدم',
    titleEn: '20ft FCL Fees & Expenses',
    icon: Icons.view_in_ar_rounded,
    badgeColor: AppTheme.emerald,
  ),
  fcl40(
    key: 'fcl40',
    titleAr: 'أتعاب ومصاريف تخليص FCL 40 قدم',
    titleEn: '40ft FCL Fees & Expenses',
    icon: Icons.view_agenda_outlined,
    badgeColor: AppTheme.emerald,
  ),
  portStorageForeign(
    key: 'port_storage_foreign',
    titleAr: 'مصاريف الأرضيات والتخزين والموانئ (بالدولار/العملات الأجنبية)',
    titleEn: 'Port, Demurrage & Storage Expenses (Foreign Currency)',
    icon: Icons.warehouse_rounded,
    badgeColor: AppTheme.orange,
  ),
  regulatoryApprovals(
    key: 'regulatory_approvals',
    titleAr: 'إجراءات وموافقات جهات العرض (واردات، إيباك، كيمياء، أمن عام...)',
    titleEn: 'Regulatory Approvals & Inspection Procedures',
    icon: Icons.verified_user_rounded,
    badgeColor: AppTheme.charcoal,
  ),
  inlandTransport(
    key: 'inland_transport',
    titleAr: 'النولون والنقل الداخلي',
    titleEn: 'Inland Transport & Freight',
    icon: Icons.local_shipping_rounded,
    badgeColor: AppTheme.orange,
  ),
  other(
    key: 'other',
    titleAr: 'بنود ورسوم إضافية',
    titleEn: 'Other & Additional Fees',
    icon: Icons.more_horiz_rounded,
    badgeColor: AppTheme.textMuted,
  );

  final String key;
  final String titleAr;
  final String titleEn;
  final IconData icon;
  final Color badgeColor;

  const CustomsExpenseGroup({
    required this.key,
    required this.titleAr,
    required this.titleEn,
    required this.icon,
    required this.badgeColor,
  });

  String localizedTitle(bool isArabic) => isArabic ? titleAr : titleEn;

  static CustomsExpenseGroup classify({
    required String name,
    String? category,
    String? currency,
    String? code,
  }) {
    final lowerName = name.toLowerCase().trim();
    final lowerCode = (code ?? '').toUpperCase().trim();
    final cleanCategory = (category ?? '').split('(').first.trim();

    // 1. Port, Demurrage & Storage (Foreign Currency or explicitly Storage/Port)
    final isForeign = currency != null && currency.trim().toUpperCase() != 'EGP';
    final hasStorageKeywords = lowerName.contains('أرضيات') ||
        lowerName.contains('ارضيات') ||
        lowerName.contains('حراسة') ||
        lowerName.contains('حراسات') ||
        lowerName.contains('تخزين') ||
        lowerName.contains('غرامات') ||
        lowerName.contains('تأخير') ||
        lowerName.contains('demurrage') ||
        lowerName.contains('storage') ||
        lowerName.contains('detention');

    if (isForeign ||
        hasStorageKeywords ||
        lowerCode.startsWith('OTHER-STORAGE') ||
        lowerCode.contains('STORAGE') ||
        lowerCode.contains('DEMURRAGE')) {
      return CustomsExpenseGroup.portStorageForeign;
    }

    // 2. Inland Transport
    final hasTransportKeywords = cleanCategory == 'Inland Transport' ||
        lowerCode.startsWith('INL-') ||
        lowerName.contains('نقل') ||
        lowerName.contains('شاحنة') ||
        lowerName.contains('شاحنه') ||
        lowerName.contains('تريلا') ||
        lowerName.contains('دبابة') ||
        lowerName.contains('دبابه') ||
        lowerName.contains('جامبو') ||
        lowerName.contains('فرداني') ||
        lowerName.contains('بياتة') ||
        lowerName.contains('بياته') ||
        lowerName.contains('نولون') ||
        lowerName.contains('مشوار');

    if (hasTransportKeywords) {
      return CustomsExpenseGroup.inlandTransport;
    }

    // 3. LCL Clearance Fees
    final isLcl = lowerName.contains('lcl') || lowerCode.contains('LCL');
    if (isLcl &&
        (lowerCode == 'CLR-LCL-INV' ||
            lowerName.contains('أتعاب') ||
            lowerName.contains('اتعاب') ||
            lowerName.contains('فاتورة') ||
            lowerName.contains('فاتوره'))) {
      return CustomsExpenseGroup.lclFees;
    }

    // 4. LCL Clearance Expenses
    if (isLcl ||
        lowerCode == 'CLR-LCL-TON' ||
        lowerCode == 'CLR-LCL-TON-EXTRA' ||
        (lowerName.contains('طن') &&
            !lowerName.contains('حاوية') &&
            !lowerName.contains('حاويه') &&
            !lowerName.contains('سيارة'))) {
      return CustomsExpenseGroup.lclExpenses;
    }

    // 5. 20ft FCL Fees & Expenses
    final is20 = (lowerName.contains('20') || lowerCode.contains('FCL20')) &&
        !lowerName.contains('40');
    if (is20 &&
        (cleanCategory == 'Clearance Fees' ||
            lowerName.contains('تخليص') ||
            lowerName.contains('حاوية') ||
            lowerName.contains('حاويه') ||
            lowerCode.startsWith('CLR-FCL20'))) {
      return CustomsExpenseGroup.fcl20;
    }

    // 6. 40ft FCL Fees & Expenses
    final is40 = lowerName.contains('40') || lowerCode.contains('FCL40');
    if (is40 &&
        (cleanCategory == 'Clearance Fees' ||
            lowerName.contains('تخليص') ||
            lowerName.contains('حاوية') ||
            lowerName.contains('حاويه') ||
            lowerCode.startsWith('CLR-FCL40'))) {
      return CustomsExpenseGroup.fcl40;
    }

    // 7. Regulatory Approvals & Procedures
    final hasApprovalKeywords = cleanCategory == 'Procedures & Approvals' ||
        lowerCode.startsWith('PROC-') ||
        lowerName.contains('واردات') ||
        lowerName.contains('إيباك') ||
        lowerName.contains('ايباك') ||
        lowerName.contains('إيلاك') ||
        lowerName.contains('ايلاك') ||
        lowerName.contains('كيمياء') ||
        lowerName.contains('أمن عام') ||
        lowerName.contains('امن عام') ||
        lowerName.contains('acid') ||
        lowerName.contains('زراعة') ||
        lowerName.contains('زراعه') ||
        lowerName.contains('إكس راي') ||
        lowerName.contains('اكس راي') ||
        lowerName.contains('x-ray') ||
        lowerName.contains('إشعاع') ||
        lowerName.contains('اشعاع') ||
        lowerName.contains('مفرقعات') ||
        lowerName.contains('مطافئ') ||
        lowerName.contains('مطافى') ||
        lowerName.contains('دمغة') ||
        lowerName.contains('دمغات') ||
        lowerName.contains('موازين') ||
        lowerName.contains('تأمين') ||
        lowerName.contains('تامين') ||
        lowerName.contains('تحفظ') ||
        lowerName.contains('سيل') ||
        lowerName.contains('ترصيص') ||
        lowerName.contains('غسيل') ||
        lowerName.contains('اتفاقيات') ||
        lowerName.contains('بريد') ||
        lowerName.contains('إفراج نهائي') ||
        lowerName.contains('افراج نهائي') ||
        lowerName.contains('فحص');

    if (hasApprovalKeywords) {
      return CustomsExpenseGroup.regulatoryApprovals;
    }

    // 8. Port handling non-foreign
    if (cleanCategory == 'Port & Handling' ||
        lowerName.contains('ميناء') ||
        lowerName.contains('رصيف') ||
        lowerName.contains('تعتيق') ||
        lowerName.contains('كلارك')) {
      return CustomsExpenseGroup.portStorageForeign;
    }

    // Fallback
    if (cleanCategory == 'Clearance Fees') {
      return CustomsExpenseGroup.lclFees;
    }

    return CustomsExpenseGroup.other;
  }
}
