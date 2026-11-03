import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../projects/models/project_model.dart';
import '../models/purchase_order_model.dart';
import '../services/po_export_helper.dart';

class PoFilterToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewPO;
  final VoidCallback onSearchAndClone;
  final VoidCallback onRefresh;
  final int? selectedProjectId;
  final String? selectedStatus;
  final ValueChanged<int?> onProjectFilterChanged;
  final ValueChanged<String?> onStatusFilterChanged;
  final List<ProjectModel> projectsList;
  final List<PurchaseOrderModel> orders;

  const PoFilterToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onNewPO,
    required this.onSearchAndClone,
    required this.onRefresh,
    required this.selectedProjectId,
    required this.selectedStatus,
    required this.onProjectFilterChanged,
    required this.onStatusFilterChanged,
    required this.projectsList,
    required this.orders,
  });

  void _copyPOTableTsv(BuildContext context, List<PurchaseOrderModel> orders) {
    final l = context.l10n;
    final headers = buildPoExportHeaders(l);
    final rows = buildPoExportRows(orders, l);

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.poPOTableCopiedToClipboard,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final density = ref.watch(displayDensityProvider);

    return ActionToolbar(
      primaryActions: [
        AppButton(
          label: l.newPurchaseOrder,
          icon: Icons.add_shopping_cart,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: onNewPO,
        ),
        AppButton(
          label: l.searchAndClonePoBtn,
          icon: Icons.control_point_duplicate_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onSearchAndClone,
        ),
      ],
      moreActionItems: [
        PopupMenuItem(
          value: 'export_excel',
          child: Row(
            children: [
              const Icon(Icons.table_view_rounded, color: AppTheme.wcagEmerald, size: 16),
              const SizedBox(width: 8),
              Text(l.exportExcel, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_pdf',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson, size: 16),
              const SizedBox(width: 8),
              Text(l.exportPdf, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_tsv',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
              const SizedBox(width: 8),
              Text(context.l10n.poCopyTableTSV, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      ],
      onMoreActionSelected: (val) {
        final headers = buildPoExportHeaders(l);
        final rows = buildPoExportRows(orders, l);
        final selectedProject = selectedProjectId == null
            ? null
            : projectsList.where((p) => p.projectId == selectedProjectId).firstOrNull;
        final projectCodeOrAll = selectedProject?.projectCode ?? l.allProjects;

        switch (val) {
          case 'export_excel':
            TableExportService.exportTableToExcel(
              context: context,
              headers: headers,
              rows: rows,
              stageName: l.purchaseOrdersTitle,
              importFileNameOrCode: projectCodeOrAll,
            );
            break;
          case 'export_pdf':
            TableExportService.exportTableToPdf(
              context: context,
              headers: headers,
              rows: rows,
              stageName: l.purchaseOrdersTitle,
              importFileNameOrCode: projectCodeOrAll,
            );
            break;
          case 'copy_tsv':
            _copyPOTableTsv(context, orders);
            break;
        }
      },
      searchController: searchController,
      searchHint: l.searchByPoHint,
      onSearchChanged: onSearchChanged,
      filters: [
        SizedBox(
          width: 140,
          height: density.buttonHeight,
          child: SearchableDropdownField<int?>(
            value: selectedProjectId,
            labelText: '',
            decoration: InputDecoration(
              hintText: l.filterByProject,
              hintStyle: TextStyle(fontSize: density.buttonFontSize - 1),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
            ),
            items: [
              SearchableDropdownItem<int?>(value: null, label: l.allProjects),
              ...projectsList.map((p) => SearchableDropdownItem<int?>(
                    value: p.projectId,
                    label: '${p.projectCode} - ${p.projectName}',
                  )),
            ],
            onChanged: onProjectFilterChanged,
          ),
        ),
        SizedBox(
          width: 120,
          height: density.buttonHeight,
          child: SearchableDropdownField<String?>(
            value: selectedStatus,
            labelText: '',
            decoration: InputDecoration(
              hintText: l.filterByStatus,
              hintStyle: TextStyle(fontSize: density.buttonFontSize - 1),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
              ),
            ),
            items: [
              SearchableDropdownItem<String?>(value: null, label: l.allStatuses),
              for (final code in DomainEnums.codesOf(DomainEnumType.poStatus))
                SearchableDropdownItem<String?>(value: code, label: DomainEnums.label(l, DomainEnumType.poStatus, code)),
            ],
            onChanged: onStatusFilterChanged,
          ),
        ),
      ],
      quickDataActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.wcagCobalt, size: density.buttonIconSize + 2),
          tooltip: l.liveReload,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: density.buttonHeight, minHeight: density.buttonHeight),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
