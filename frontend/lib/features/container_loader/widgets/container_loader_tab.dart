import '../../../core/widgets/searchable_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/container_loader_provider.dart';

class ContainerLoaderTab extends ConsumerStatefulWidget {
  const ContainerLoaderTab({super.key});

  @override
  ConsumerState<ContainerLoaderTab> createState() => _ContainerLoaderTabState();
}

class _PackageItemInput {
  double length;
  double width;
  double height;
  int qty;
  double weightKg;
  bool stackable;
  String unit;

  _PackageItemInput({
    this.length = 120,
    this.width = 80,
    this.height = 100,
    this.qty = 20,
    this.weightKg = 250,
    this.stackable = true,
    this.unit = 'cm',
  });
}

class _ContainerLoaderTabState extends ConsumerState<ContainerLoaderTab> {
  final List<_PackageItemInput> _items = [
    _PackageItemInput(length: 120, width: 80, height: 100, qty: 20, weightKg: 250, stackable: true, unit: 'cm'),
  ];

  bool _isEvaluating = false;

  void _addItem() {
    setState(() {
      _items.add(_PackageItemInput());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'FIT':
        return AppTheme.emerald;
      case 'OVERWEIGHT':
      case 'DOOR_BLOCKED':
      case 'DIMENSION_EXCEEDED':
      case 'FLOOR_EXCEEDED':
        return AppTheme.crimson;
      default:
        return Colors.orange;
    }
  }

  String _statusLabelAr(String status) {
    switch (status.toUpperCase()) {
      case 'FIT':
        return 'مطابق للتحميل ✅';
      case 'OVERWEIGHT':
        return 'تجاوز أقصى حمولة وزنية ❌';
      case 'DOOR_BLOCKED':
        return 'أبعاد الطرد تتجاوز فتحة الباب ❌';
      case 'DIMENSION_EXCEEDED':
        return 'أبعاد الطرد تتجاوز الحاوية ❌';
      case 'FLOOR_EXCEEDED':
        return 'تجاوز المساحة الأرضية ❌';
      case 'CEILING_TOO_TIGHT':
        return 'ارتفاع السقف غير كافٍ ⚠️';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(containerLoaderProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Pane: Packages Inputs & Actions (Width: 480)
            SizedBox(
              width: 480,
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_rounded, color: AppTheme.cobalt, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'أبعاد وأوزان طرود الشحنة' : 'Cargo Package Specifications',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppTheme.cobalt, size: 22),
                            tooltip: isArabic ? 'إضافة طرد جديد' : 'Add package',
                            onPressed: _addItem,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // List of package rows
                      Expanded(
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF253140) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${isArabic ? "بند الطرد" : "Package"} #${index + 1}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      if (_items.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _removeItem(index),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.length.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'الطول' : 'Length',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.length = double.tryParse(v) ?? item.length,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.width.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'العرض' : 'Width',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.width = double.tryParse(v) ?? item.width,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.height.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'الارتفاع' : 'Height',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.height = double.tryParse(v) ?? item.height,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 85,
                                        child: SearchableDropdownField<String>(
                                          value: item.unit,
                                          isDense: true,
                                          items: ['cm', 'mm', 'm']
                                              .map((u) => SearchableDropdownItem<String>(value: u, label: u))
                                              .toList(),
                                          onChanged: (v) => setState(() => item.unit = v ?? item.unit),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.qty.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'العدد' : 'Qty',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.qty = int.tryParse(v) ?? item.qty,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: item.weightKg.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: isArabic ? 'الوزن/وحدة (كجم)' : 'Weight (kg)',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) => item.weightKg = double.tryParse(v) ?? item.weightKg,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: item.stackable,
                                            activeColor: AppTheme.cobalt,
                                            onChanged: (v) => setState(() => item.stackable = v ?? false),
                                          ),
                                          Text(isArabic ? 'رص رأسي' : 'Stackable', style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Evaluate Button
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isEvaluating
                              ? null
                              : () async {
                                  setState(() => _isEvaluating = true);
                                  final req = {
                                    'packages': _items
                                        .map((it) => {
                                              'length': it.length,
                                              'width': it.width,
                                              'height': it.height,
                                              'qty': it.qty,
                                              'weight_kg': it.weightKg,
                                              'stackable': it.stackable,
                                              'unit': it.unit,
                                            })
                                        .toList(),
                                  };
                                  await ref
                                      .read(containerLoaderProvider.notifier)
                                      .evaluateLoading(req);
                                  setState(() => _isEvaluating = false);
                                },
                          icon: _isEvaluating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.calculate_rounded, size: 20),
                          label: Text(
                            isArabic
                                ? 'تشغيل محاكاة وتحسين تحميل الحاويات'
                                : 'Run Container Loading Evaluation',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right Pane: Evaluation Result & Container Options Comparison (Expanded)
            Expanded(
              child: state.evaluationResult == null
                  ? Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.view_in_ar_rounded, size: 54, color: AppTheme.cobalt),
                            const SizedBox(height: 12),
                            Text(
                              isArabic
                                  ? 'أدخل أبعاد الطرود واضغط "تشغيل محاكاة وتحسين تحميل الحاويات"'
                                  : 'Enter package dimensions and click "Run Container Loading Evaluation"',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (state.specs.isNotEmpty) ...[
                              Text(
                                isArabic ? 'مواصفات الحاويات القياسية المدعومة:' : 'Supported standard containers:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: state.specs
                                    .map((s) => Chip(
                                          label: Text('${s.code} (${s.totalCbmCapacity} CBM / ${(s.maxPayloadKg / 1000).toStringAsFixed(1)} T)'),
                                          backgroundColor: AppTheme.cobalt.withValues(alpha: 0.08),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recommended Container Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.emerald),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 36),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${isArabic ? "الحاوية الموصى بها:" : "Recommended Container:"} ${state.evaluationResult!.recommendedContainerName} (${state.evaluationResult!.recommendedContainer})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${isArabic ? "العدد المطلوب:" : "Required Count:"} ${state.evaluationResult!.recommendedCount} ${isArabic ? "حاوية" : "containers"} | ${isArabic ? "إجمالي الحجم:" : "Total CBM:"} ${state.evaluationResult!.totalCbm.toStringAsFixed(2)} CBM | ${isArabic ? "إجمالي الوزن:" : "Total Weight:"} ${(state.evaluationResult!.totalWeightKg / 1000).toStringAsFixed(2)} T',
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Utilization Progress Meters
                          Row(
                            children: [
                              _buildUtilizationCard(
                                label: isArabic ? 'استغلال الحجم CBM' : 'Volume Utilization',
                                pct: state.evaluationResult!.volumeUtilizationPct,
                                color: AppTheme.cobalt,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              _buildUtilizationCard(
                                label: isArabic ? 'استغلال الوزن كجم' : 'Weight Utilization',
                                pct: state.evaluationResult!.weightUtilizationPct,
                                color: Colors.orange,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              _buildUtilizationCard(
                                label: isArabic ? 'إشغال الأرضية م2' : 'Floor Utilization',
                                pct: state.evaluationResult!.floorUtilizationPct,
                                color: AppTheme.emerald,
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Detailed All Options Grid
                          Text(
                            isArabic ? 'مقارنة خيارات الحاويات وتشخيص الملاءمة:' : 'All Container Options Diagnostics:',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 8),

                          ...state.evaluationResult!.allOptions.map((opt) {
                            return Card(
                              elevation: 0.5,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: opt.containerCode == state.evaluationResult!.recommendedContainer
                                      ? AppTheme.emerald
                                      : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                  width: opt.containerCode == state.evaluationResult!.recommendedContainer ? 1.5 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${opt.containerName} (${opt.containerCode})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _statusColor(opt.status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _statusLabelAr(opt.status),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: _statusColor(opt.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        Text(
                                          '${isArabic ? "الحاويات المطلوبة:" : "Count:"} ${opt.requiredCount}',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                        Text(
                                          '${isArabic ? "نسبة الحجم:" : "Vol:"} ${opt.volumeUtilizationPct.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                        Text(
                                          '${isArabic ? "نسبة الوزن:" : "Weight:"} ${opt.weightUtilizationPct.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                        Text(
                                          '${isArabic ? "إشغال الأرضية:" : "Floor:"} ${opt.floorUtilizationPct.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                    if (opt.reasonsAr.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      ...opt.reasonsAr.map(
                                        (r) => Text(
                                          '• $r',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilizationCard({
    required String label,
    required double pct,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2631) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}
