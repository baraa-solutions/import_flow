import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../container_tracking_provider.dart';

/// Container Tracking Table displaying individual units and operational parameters.
class ContainerTrackerTable extends ConsumerWidget {
  final List<ContainerUnitData> containers;
  final VoidCallback onRefresh;
  final ValueChanged<ContainerUnitData> onSelectTimeline;
  final ValueChanged<ContainerUnitData> onSelectDemurrage;

  const ContainerTrackerTable({
    super.key,
    required this.containers,
    required this.onRefresh,
    required this.onSelectTimeline,
    required this.onSelectDemurrage,
  });

  String _statusArabic(String status) {
    switch (status) {
      case 'ON_VESSEL':
        return 'على متن السفينة';
      case 'DISCHARGED':
        return 'تم التفريغ بالميناء';
      case 'GATE_OUT_HELD':
        return 'خروج تحت التحفظ';
      case 'RETURNED_EMPTY':
        return 'تم إرجاع الحاوية الفارغة';
      case 'DAMAGED':
        return 'حاوية متضررة';
      default:
        return status;
    }
  }

  AppSeverity _statusSeverity(String status) {
    switch (status) {
      case 'RETURNED_EMPTY':
        return AppSeverity.success;
      case 'GATE_OUT_HELD':
      case 'DISCHARGED':
        return AppSeverity.warning;
      case 'DAMAGED':
        return AppSeverity.danger;
      default:
        return AppSeverity.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (containers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.border),
              const SizedBox(height: 12),
              const Text(
                'لا توجد حاويات مسجلة لهذه الشحنة حالياً',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'تحديث البيانات',
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('رقم الحاوية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('نوع الحاوية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('رقم الختم', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الحالة التشغيلية', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الوزن القائم', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('تاريخ التفريغ', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('غرامات متراكمة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: containers.map((container) {
                final demurrage = container.latestDemurrageTotal;
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            container.containerNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 15, color: AppTheme.textSecondary),
                            tooltip: 'نسخ رقم الحاوية',
                            onPressed: () => CopyHelper.copy(context, container.containerNumber),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(container.isoType)),
                    DataCell(Text(container.sealNumber ?? '—')),
                    DataCell(
                      AppStatusBadge(
                        label: _statusArabic(container.status),
                        severity: _statusSeverity(container.status),
                      ),
                    ),
                    DataCell(
                      Text(
                        container.grossWeight != null ? '${container.grossWeight!.toStringAsFixed(0)} كجم' : '—',
                      ),
                    ),
                    DataCell(
                      Text(
                        container.dischargeDate != null
                            ? '${container.dischargeDate!.year}-${container.dischargeDate!.month.toString().padLeft(2, '0')}-${container.dischargeDate!.day.toString().padLeft(2, '0')}'
                            : '—',
                      ),
                    ),
                    DataCell(
                      Text(
                        demurrage > 0 ? '${demurrage.toStringAsFixed(2)} دولار' : 'لا توجد غرامة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: demurrage > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.timeline, color: AppTheme.cobalt, size: 20),
                            tooltip: 'عرض المسار الزمني',
                            onPressed: () => onSelectTimeline(container),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_money, color: AppTheme.orange, size: 20),
                            tooltip: 'احتساب الغرامات وفترة السماح',
                            onPressed: () => onSelectDemurrage(container),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
