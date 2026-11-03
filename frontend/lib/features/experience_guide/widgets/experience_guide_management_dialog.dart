import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/guide_entry_model.dart';
import '../providers/experience_guide_provider.dart';
import 'add_guide_entry_dialog.dart';
import '../../../core/widgets/widgets.dart';

class ExperienceGuideManagementDialog extends ConsumerStatefulWidget {
  const ExperienceGuideManagementDialog({super.key});

  @override
  ConsumerState<ExperienceGuideManagementDialog> createState() =>
      _ExperienceGuideManagementDialogState();
}

class _ExperienceGuideManagementDialogState
    extends ConsumerState<ExperienceGuideManagementDialog> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedScopeType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(experienceGuideProvider.notifier).fetchEntries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    ref.read(experienceGuideProvider.notifier).fetchEntries(
          search: _searchController.text.trim().isNotEmpty
              ? _searchController.text.trim()
              : null,
          scopeType: _selectedScopeType,
        );
  }

  Future<void> _confirmDelete(GuideEntryModel entry) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(l10n.guideEntryDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.flatCrimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(experienceGuideProvider.notifier).deleteEntry(entry.entryId);
    }
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddGuideEntryDialog(
        onSuccess: () {
          ref.read(experienceGuideProvider.notifier).fetchEntries();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entriesAsync = ref.watch(experienceGuideProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu_book_outlined, color: AppTheme.flatCobalt, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.experienceGuideTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.flatCharcoal,
                            ),
                          ),
                          const Text(
                            'الذاكرة المؤسسية والاشتراطات التلقائية للشحنات والأصناف',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.addGuideEntryBtn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.flatCobalt,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openAddDialog,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Filter Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'البحث في العناوين والمحتوى...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onFilterChanged();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _onFilterChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: SearchableDropdownField<String?>(
                      value: _selectedScopeType,
                      labelText: 'تصفية حسب نوع النطاق',
                      decoration: InputDecoration(
                        labelText: 'تصفية حسب نوع النطاق',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        SearchableDropdownItem<String?>(value: null, label: 'جميع النطاقات'),
                        SearchableDropdownItem<String?>(value: 'hs_code', label: 'بند التعريفة'),
                        SearchableDropdownItem<String?>(value: 'destination_port', label: 'ميناء الوصول'),
                        SearchableDropdownItem<String?>(value: 'product_category', label: 'تصنيف الصنف'),
                        SearchableDropdownItem<String?>(value: 'supplier', label: 'المورد'),
                        SearchableDropdownItem<String?>(value: 'shipping_line', label: 'الخط الملاحي'),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedScopeType = val);
                        _onFilterChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Entries List
              Expanded(
                child: entriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('خطأ في تحميل الدليل: $err')),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('لا توجد توجيهات تطابق شروط البحث في دليل الخبرة'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addGuideEntryBtn),
                              onPressed: _openAddDialog,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final entry = entries[index];
                        final isCritical = entry.severity == 'critical';
                        final isWarning = entry.severity == 'warning';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCritical
                                  ? AppTheme.flatCrimson.withValues(alpha: 0.3)
                                  : (isWarning
                                      ? AppTheme.flatOrange.withValues(alpha: 0.3)
                                      : Colors.grey.shade300),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCritical
                                          ? AppTheme.flatCrimson
                                          : (isWarning ? AppTheme.flatOrange : AppTheme.flatCobalt),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCritical ? 'حرج وإلزامي' : (isWarning ? 'تحذير هام' : 'استرشادي'),
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.entryType,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.localizedTitle(l10n),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.flatCharcoal),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.flatCrimson, size: 20),
                                    tooltip: 'حذف التوجيه',
                                    onPressed: () => _confirmDelete(entry),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.localizedContent(l10n),
                                style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.flatCharcoal),
                              ),
                              const SizedBox(height: 10),

                              // Scopes Chips
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: entry.scopes.map((s) {
                                  return Chip(
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    label: Text(
                                      '${s.scopeType}: ${s.scopeValue}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: const Color(0xFFF0F4F8),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
