import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/system_parameter_model.dart';
import '../providers/system_parameters_provider.dart';

class SystemParametersTab extends ConsumerStatefulWidget {
  const SystemParametersTab({super.key});

  @override
  ConsumerState<SystemParametersTab> createState() => _SystemParametersTabState();
}

class _SystemParametersTabState extends ConsumerState<SystemParametersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditDialog(BuildContext context, SystemParameterModel param, bool isArabic, bool isDark) {
    final valueController = TextEditingController(text: param.paramValue);
    final justificationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogBg = isDark ? const Color(0xFF1E2631) : Colors.white;
          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'تعديل معامل النظام' : 'Update System Parameter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF253140) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              param.paramKey,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.cobalt,
                              ),
                            ),
                            if (param.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                param.description!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isArabic ? 'القيمة الجديدة' : 'New Value',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: valueController,
                        decoration: InputDecoration(
                          hintText: isArabic ? 'أدخل القيمة الجديدة' : 'Enter new value',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? (isArabic ? 'القيمة مطلوبة' : 'Value is required')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isArabic ? 'مبرر التعديل التجاري (إلزامي للتدقيق)' : 'Business Justification (Required)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: justificationController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'سبب تغيير هذه القيمة (5 أحرف على الأقل)'
                              : 'Reason for changing this parameter (min 5 chars)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 5) {
                            return isArabic
                                ? 'يجب إدخال مبرر لا يقل عن 5 أحرف'
                                : 'Justification must be at least 5 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        final success = await ref
                            .read(systemParametersProvider.notifier)
                            .updateParameter(
                              key: param.paramKey,
                              value: valueController.text.trim(),
                              justification: justificationController.text.trim(),
                            );
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'تم حفظ معامل النظام بنجاح'
                                    : 'System parameter updated successfully',
                              ),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                        } else {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'فشل تحديث المعامل (تأكد من صلاحيات المشرف)'
                                    : 'Failed to update parameter (Admin role required)',
                              ),
                              backgroundColor: AppTheme.crimson,
                            ),
                          );
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isArabic ? 'حفظ التعديل' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(systemParametersProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    final filtered = state.parameters.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final keyMatch = p.paramKey.toLowerCase().contains(q);
      final descMatch = (p.description ?? '').toLowerCase().contains(q);
      final valMatch = p.paramValue.toLowerCase().contains(q);
      return keyMatch || descMatch || valMatch;
    }).toList();

    return SelectionArea(
      child: Column(
        children: [
          // Toolbar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: isArabic
                          ? 'بحث باسم المعامل أو الوصف...'
                          : 'Search by parameter key or description...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isArabic ? 'تحديث المعاملات' : 'Refresh parameters',
                onPressed: () => ref.read(systemParametersProvider.notifier).fetchParameters(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.crimson, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              isArabic ? 'خطأ في جلب معاملات النظام' : 'Error loading parameters',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.errorMessage!,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              isArabic ? 'لا توجد معاملات مطابقة للبحث' : 'No matching parameters found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final param = filtered[index];
                              return Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.settings_suggest_rounded,
                                          color: AppTheme.cobalt,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () => CopyHelper.copy(context, param.paramKey),
                                                    child: Text(
                                                      param.paramKey,
                                                      style: const TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppTheme.charcoal,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    param.paramValue,
                                                    style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppTheme.cobalt,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (param.description != null && param.description!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                param.description!,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: isDark
                                                      ? AppTheme.darkTextSecondary
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                            if (param.updatedBy != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '${isArabic ? 'آخر تحديث بواسطة:' : 'Updated by:'} ${param.updatedBy}',
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: isArabic ? 'تعديل المعامل' : 'Edit parameter',
                                        color: AppTheme.cobalt,
                                        onPressed: () => _showEditDialog(context, param, isArabic, isDark),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
