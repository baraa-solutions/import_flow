import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/regulatory_matrix_provider.dart';

class RegulatoryAgencySelectorCard extends ConsumerWidget {
  const RegulatoryAgencySelectorCard({super.key});

  static const List<Map<String, String>> _agencies = [
    {
      'code': '',
      'name': 'جميع الجهات الرقابية',
      'icon': 'account_balance',
    },
    {
      'code': 'NFSA',
      'name': 'الهيئة القومية لسلامة الغذاء',
      'icon': 'restaurant',
    },
    {
      'code': 'GOEIC',
      'name': 'الهيئة العامة للرقابة على الصادرات والواردات',
      'icon': 'verified_user',
    },
    {
      'code': 'QUARANTINE',
      'name': 'الحجر الزراعي والبيطري',
      'icon': 'eco',
    },
    {
      'code': 'NTRA',
      'name': 'الجهاز القومي لتنظيم الاتصالات',
      'icon': 'cell_tower',
    },
    {
      'code': 'EOS',
      'name': 'الهيئة المصرية العامة للمواصفات والجودة',
      'icon': 'fact_check',
    },
    {
      'code': 'EDA',
      'name': 'هيئة الدواء المصرية',
      'icon': 'medication',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAgency = ref.watch(regulatoryAgencyFilterProvider) ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 20, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Text(
                'تصفية حسب جهة العرض الرقابية',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _agencies.map((agency) {
                final isSelected = selectedAgency == agency['code'];
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(agency['name']!),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.charcoal,
                    ),
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: AppTheme.cobalt,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppTheme.cobalt : AppTheme.border,
                    ),
                    onSelected: (selected) {
                      final code = agency['code']!;
                      ref.read(regulatoryAgencyFilterProvider.notifier).state =
                          code.isEmpty ? null : code;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
