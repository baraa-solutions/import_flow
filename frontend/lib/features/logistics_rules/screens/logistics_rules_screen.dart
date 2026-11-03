import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../providers/logistics_rules_provider.dart';
import '../widgets/logistics_rule_form_dialog.dart';
import '../widgets/logistics_rules_export_dialog.dart';
import '../widgets/logistics_rules_table.dart';

/// Screen displaying and managing dynamic operational logistics rules.
/// Pure Orchestrator adhering to Parallel UI Decomposition standards (≤ 120 lines).
class LogisticsRulesScreen extends ConsumerWidget {
  const LogisticsRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(logisticsRulesProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: AppBar(
          title: const Text(
            'سجل القواعد والضوابط التشغيلية والقانونية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.ghost,
              onPressed: () => ref.invalidate(logisticsRulesProvider),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'قائمة الأسئلة الميدانية',
              icon: Icons.assignment_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                final rules = rulesAsync.value ?? [];
                showDialog(
                  context: context,
                  builder: (_) => LogisticsRulesExportDialog(rules: rules),
                );
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'إضافة قاعدة جديدة',
              icon: Icons.add,
              variant: AppButtonVariant.primary,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const LogisticsRuleFormDialog(),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.crimson),
                const SizedBox(height: 12),
                Text('حدث خطأ في تحميل القواعد: $err'),
                const SizedBox(height: 16),
                AppButton(
                  label: 'إعادة المحاولة',
                  variant: AppButtonVariant.primary,
                  onPressed: () => ref.invalidate(logisticsRulesProvider),
                ),
              ],
            ),
          ),
          data: (rules) => rules.isEmpty
              ? const Center(child: Text('لا توجد قواعد تشغيلية مسجلة'))
              : LogisticsRulesTable(rules: rules),
        ),
      ),
    );
  }
}
