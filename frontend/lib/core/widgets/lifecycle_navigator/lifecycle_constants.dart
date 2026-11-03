import '../../../features/smart_tasks/models/smart_task_model.dart';

class LifecycleConstants {
  LifecycleConstants._();

  static const List<Map<String, String>> kLifecycleSteps = [
    {
      'id': '1',
      'nameAr': 'الجدوى والنولون',
      'nameEn': 'Feasibility & Freight',
      'screen': 'شاشة عروض الأسعار والجدوى',
    },
    {
      'id': '2',
      'nameAr': 'الموافقة المالية',
      'nameEn': 'Financial Approval',
      'screen': 'شاشة أوامر الشراء والاعتماد',
    },
    {
      'id': '3',
      'nameAr': 'المستندات ونافذة',
      'nameEn': 'Documents & ACID',
      'screen': 'شاشة متابعة منظومة نافذة والإفراج',
    },
    {
      'id': '4',
      'nameAr': 'حجز الشحن',
      'nameEn': 'Freight Booking',
      'screen': 'شاشة حجز الشحن والناقل',
    },
    {
      'id': '5',
      'nameAr': 'تخصيص الحاويات',
      'nameEn': 'Container Allocation',
      'screen': 'شاشة شحن وتجهيز البضاعة (المرحلة 5)',
    },
    {
      'id': '6',
      'nameAr': 'إقرار 46 جمرك',
      'nameEn': 'Customs Dec. 46',
      'screen': 'شاشة التخليص الجمركي وإقرار 46',
    },
    {
      'id': '7',
      'nameAr': 'التخليص والسداد',
      'nameEn': 'Clearance & Duty',
      'screen': 'شاشة سداد الرسوم والضرائب الجمركية',
    },
    {
      'id': '8',
      'nameAr': 'استلام المخازن',
      'nameEn': 'Warehouse Delivery',
      'screen': 'شاشة فحص البضاعة واستلام المخزن',
    },
    {
      'id': '9',
      'nameAr': 'التسوية الشاملة',
      'nameEn': 'Reconciliation',
      'screen': 'شاشة تكلفة الوصول والتسوية المالية',
    },
    {
      'id': '10',
      'nameAr': 'إغلاق والأرشفة',
      'nameEn': 'Archive & Closure',
      'screen': 'شاشة إغلاق ملف الشحنة والأرشفة',
    },
  ];

  static int? detectStepForTask(SmartTaskModel task) {
    final text =
        '${task.phaseName ?? ''} ${task.title} ${task.description ?? ''}'
            .toLowerCase();
    for (int i = 1; i <= 10; i++) {
      if (text.contains('phase $i') ||
          text.contains('phase$i') ||
          text.contains('مرحلة $i') ||
          text.contains('خطوة $i')) {
        return i;
      }
    }
    for (final s in kLifecycleSteps) {
      final sId = int.tryParse(s['id']!) ?? 0;
      final ar = s['nameAr']!.toLowerCase();
      final en = s['nameEn']!.toLowerCase();
      if (ar.split(' ').any((w) => w.length > 3 && text.contains(w)) ||
          en.split(' ').any((w) => w.length > 3 && text.contains(w))) {
        return sId;
      }
    }
    return null;
  }
}
