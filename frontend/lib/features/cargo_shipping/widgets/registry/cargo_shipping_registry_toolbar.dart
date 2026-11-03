import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/cargo_shipping_model.dart';

class CargoShippingRegistryToolbar extends StatelessWidget {
  final List<CargoShippingModel> allRecords;
  final VoidCallback onCreateNewRecord;
  final VoidCallback onSearchAndClone;
  final VoidCallback onCopyTableTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String?> onStatusFilterChanged;
  final String slaFilter;
  final ValueChanged<String?> onSlaFilterChanged;
  final String activeFilter;
  final ValueChanged<String?> onActiveFilterChanged;

  const CargoShippingRegistryToolbar({
    super.key,
    required this.allRecords,
    required this.onCreateNewRecord,
    required this.onSearchAndClone,
    required this.onCopyTableTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.slaFilter,
    required this.onSlaFilterChanged,
    required this.activeFilter,
    required this.onActiveFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final breachedCount = allRecords
        .where((r) => r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricCardStrip(
          padding: EdgeInsets.zero,
          metrics: [
            MetricCardData(
              title: l.cshMetricRecords,
              value: '${allRecords.length}',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.cobalt,
            ),
            MetricCardData(
              title: l.cshPdfMetaFcl,
              value: '${allRecords.where((r) => r.shipmentType == 'FCL').length}',
              icon: Icons.view_in_ar_outlined,
              color: AppTheme.emerald,
            ),
            MetricCardData(
              title: l.cshPdfMetaLcl,
              value: '${allRecords.where((r) => r.shipmentType == 'LCL').length}',
              icon: Icons.warehouse_outlined,
              color: AppTheme.orange,
            ),
            MetricCardData(
              title: l.cargoShippingMetricSlaBreached,
              value: '$breachedCount',
              icon: Icons.alarm_off,
              color: breachedCount > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsetsDirectional.all(12),
          decoration: AppTheme.toolbarDecorationOf(context),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CcUi.fit(AppButton(
                key: const Key('createShippingBtn'),
                label: l.cargoShippingCreateNewRecord,
                icon: Icons.add_task,
                size: AppButtonSize.small,
                onPressed: onCreateNewRecord,
              )),
              CcUi.fit(AppButton(
                key: const Key('searchAndCloneShippingBtn'),
                label: l.searchAndCloneCargoShippingBtn,
                icon: Icons.copy_all_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onSearchAndClone,
              )),
              CcUi.fit(AppButton(
                key: const Key('copyShippingTableTsvBtn'),
                label: l.customsDeclExportTsvButton,
                icon: Icons.copy,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: onCopyTableTsv,
              )),
              CcUi.fit(AppButton(
                key: const Key('exportShippingExcelBtn'),
                label: l.exportCargoShippingExcelTooltip,
                icon: Icons.table_chart,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: onExportExcel,
              )),
              CcUi.fit(AppButton(
                key: const Key('exportShippingPdfBtn'),
                label: l.exportCargoShippingPdfTooltip,
                icon: Icons.picture_as_pdf,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
                onPressed: onExportPdf,
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsetsDirectional.all(12),
          decoration: AppTheme.cardDecorationOf(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final searchField = AppSearchField(
                controller: searchController,
                hint: context.l10n.cargoShippingRegistrySearchHint,
              );

              final statusDropdown = SearchableDropdownField<String>(
                labelText: context.l10n.cargoShippingStatusFilterLabel,
                value: statusFilter,
                items: [
                  SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingStatusAll),
                  SearchableDropdownItem(value: 'Cargo Ready', label: context.l10n.cargoShippingStatusCargoReady),
                  SearchableDropdownItem(value: 'Completed', label: context.l10n.cargoShippingStatusCompleted),
                ],
                onChanged: onStatusFilterChanged,
              );

              final slaDropdown = SearchableDropdownField<String>(
                labelText: context.l10n.cargoShippingSlaFilterLabel,
                value: slaFilter,
                items: [
                  SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingSlaAll),
                  SearchableDropdownItem(value: 'OnTime', label: context.l10n.cargoShippingSlaOnTimeFilter),
                  SearchableDropdownItem(value: 'Breached', label: context.l10n.cargoShippingSlaBreachedFilter),
                ],
                onChanged: onSlaFilterChanged,
              );

              final activeDropdown = SearchableDropdownField<String>(
                labelText: context.l10n.cargoShippingActiveFilterLabel,
                value: activeFilter,
                items: [
                  SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingActiveAll),
                  SearchableDropdownItem(value: 'Active', label: context.l10n.cargoShippingActiveOnly),
                  SearchableDropdownItem(value: 'Deleted', label: context.l10n.cargoShippingDeletedOnly),
                ],
                onChanged: onActiveFilterChanged,
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: statusDropdown),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: slaDropdown),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: activeDropdown),
                  ],
                );
              } else {
                final halfWidth = (constraints.maxWidth - 10) / 2;
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: halfWidth.clamp(140.0, 300.0), child: statusDropdown),
                        SizedBox(width: halfWidth.clamp(140.0, 300.0), child: slaDropdown),
                        SizedBox(width: constraints.maxWidth, child: activeDropdown),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
