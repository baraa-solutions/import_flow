import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Table displaying container and seal assignments for Maritime Draft B/L:
/// - Container numbers
/// - ISO container types (e.g., 20'GP, 40'HC)
/// - Seal numbers
/// - Tare and gross weights
/// - VGM (Verified Gross Mass) status indicator
class DraftBlContainerSealTable extends StatelessWidget {
  final String? containerSummary;
  final List<dynamic>? containers;
  final double? totalGrossWeight;
  final double? totalNetWeight;

  const DraftBlContainerSealTable({
    super.key,
    this.containerSummary,
    this.containers,
    this.totalGrossWeight,
    this.totalNetWeight,
  });

  List<_ContainerRowData> _buildRows() {
    final list = <_ContainerRowData>[];

    if (containers != null && containers!.isNotEmpty) {
      for (final c in containers!) {
        if (c is Map) {
          list.add(_ContainerRowData(
            containerNo: (c['container_no'] ?? c['number'] ?? '').toString().trim(),
            isoType: (c['iso_type'] ?? c['type'] ?? "40'HC").toString().trim(),
            sealNo: (c['seal_no'] ?? c['seal'] ?? '').toString().trim(),
            tareWeightKg: (c['tare_weight_kg'] as num?)?.toDouble() ?? 3800.0,
            grossWeightKg: (c['gross_weight_kg'] as num?)?.toDouble() ?? (totalGrossWeight ?? 0.0),
            isVgmVerified: c['vgm_verified'] == true || c['vgm_status'] == 'VERIFIED',
          ));
        }
      }
    }

    // Fallback: If no structured container list, parse or synthesize from containerSummary
    if (list.isEmpty && containerSummary != null && containerSummary!.trim().isNotEmpty) {
      final summary = containerSummary!.trim();
      final parts = summary.split(RegExp(r'[,;\n]'));
      for (final p in parts) {
        final line = p.trim();
        if (line.isEmpty) continue;

        String cNo = line;
        String sNo = '';
        if (line.toLowerCase().contains('seal:')) {
          final sSplit = line.split(RegExp(r'seal:', caseSensitive: false));
          cNo = sSplit[0].replaceAll('/', '').trim();
          sNo = sSplit.length > 1 ? sSplit[1].trim() : '';
        } else if (line.contains('/')) {
          final slashSplit = line.split('/');
          cNo = slashSplit[0].trim();
          sNo = slashSplit.length > 1 ? slashSplit[1].trim() : '';
        }

        list.add(_ContainerRowData(
          containerNo: cNo.isNotEmpty ? cNo : summary,
          isoType: "40'HC",
          sealNo: sNo,
          tareWeightKg: 3800.0,
          grossWeightKg: totalGrossWeight ?? 0.0,
          isVgmVerified: true,
        ));
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _buildRows();

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppTheme.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title & total count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.draftBlSummaryContainers,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${rows.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (containerSummary != null && containerSummary!.isNotEmpty)
                    AppButton(
                      label: l.copy,
                      icon: Icons.copy,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: () => CopyHelper.copy(context, containerSummary!),
                    ),
                ],
              ),
              const Divider(height: 18),

              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      l.unspecified,
                      style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
                    columns: [
                      DataColumn(label: Text(l.containerIndexTitle(1, '').replaceAll(RegExp(r'[0-9#]'), '').trim().isNotEmpty ? l.containerIndexTitle(1, '').replaceAll(RegExp(r'[0-9#]'), '').trim() : 'Container', style: const TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('ISO Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Seal No', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(l.draftBlSummaryGrossWeight, style: const TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('VGM Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: rows.map((r) {
                      return DataRow(
                        cells: [
                          // Container Number
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_boat_outlined, size: 16, color: AppTheme.cobalt),
                                const SizedBox(width: 6),
                                CopyableText(
                                  r.containerNo.isNotEmpty ? r.containerNo : l.unspecified,
                                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // ISO Type
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.isoType,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                              ),
                            ),
                          ),
                          // Seal Number
                          DataCell(
                            Text(
                              r.sealNo.isNotEmpty ? r.sealNo : l.unspecified,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: r.sealNo.isNotEmpty ? AppTheme.textPrimaryOf(context) : AppTheme.textMutedOf(context),
                              ),
                            ),
                          ),
                          // Gross Weight
                          DataCell(
                            Text(
                              r.grossWeightKg > 0 ? '${r.grossWeightKg.toStringAsFixed(1)} kg' : l.unspecified,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          // VGM Status
                          DataCell(
                            AppStatusBadge(
                              label: r.isVgmVerified ? 'VGM Certified' : 'VGM Pending',
                              severity: r.isVgmVerified ? AppSeverity.success : AppSeverity.warning,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                          // Copy Action
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.copy, size: 15, color: AppTheme.cobalt),
                              tooltip: l.copy,
                              onPressed: () => CopyHelper.copy(
                                context,
                                '${r.containerNo} / Seal: ${r.sealNo}',
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContainerRowData {
  final String containerNo;
  final String isoType;
  final String sealNo;
  final double tareWeightKg;
  final double grossWeightKg;
  final bool isVgmVerified;

  const _ContainerRowData({
    required this.containerNo,
    required this.isoType,
    required this.sealNo,
    required this.tareWeightKg,
    required this.grossWeightKg,
    required this.isVgmVerified,
  });
}
