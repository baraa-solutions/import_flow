import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/page_header.dart';
import '../providers/regulatory_matrix_provider.dart';
import '../widgets/hs_regulatory_rule_table.dart';
import '../widgets/regulatory_agency_selector_card.dart';

/// الشاشة التنسيقية لإدارة مصفوفة المتطلبات والجهات الرقابية الاستباقية (Type B)
class RegulatoryMatrixScreen extends ConsumerWidget {
  const RegulatoryMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirementsAsync = ref.watch(regulatoryMatrixListProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          title: 'مصفوفة المتطلبات والجهات الرقابية الاستباقية',
          subtitle: 'ربط البنود الجمركية بجهات العرض وتحديد توقيتات الفحص والمستندات الإلزامية',
          icon: Icons.policy_outlined,
          actions: [
            AppButton(
              label: 'تحديث البيانات',
              icon: Icons.refresh,
              variant: AppButtonVariant.ghost,
              onPressed: () => ref.invalidate(regulatoryMatrixListProvider),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MasterDataToolbarWidget(
                moduleEndpoint: '/api/v1/regulatory-matrix',
                title: 'المتطلبات الرقابية للبنوك الجمركية',
                onRefreshNeeded: () => ref.invalidate(regulatoryMatrixListProvider),
              ),
              const SizedBox(height: 12),
              const RegulatoryAgencySelectorCard(),
              const SizedBox(height: 12),
              Expanded(
                child: requirementsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                        const SizedBox(height: 12),
                        Text(
                          'تعذر تحميل بيانات المصفوفة الرقابية: $error',
                          style: const TextStyle(color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'إعادة المحاولة',
                          variant: AppButtonVariant.primary,
                          onPressed: () => ref.invalidate(regulatoryMatrixListProvider),
                        ),
                      ],
                    ),
                  ),
                  data: (items) => HsRegulatoryRuleTable(
                    requirements: items,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
