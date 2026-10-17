import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/change_diff_dialog.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/row_context_menu.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';
import '../widgets/supplier_details_dialog.dart';
import '../widgets/route_intelligence_dialog.dart';
import '../widgets/supplier_scorecard_dialog.dart';
import '../widgets/goeic_verification_dialog.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    });
  }

  void _copySuppliersTsv(List<SupplierModel> suppliers) {
    final l10n = context.l10n;
    final headers = [
      l10n.supplierTsvHeaderCode,
      l10n.supplierTsvHeaderName,
      l10n.supplierTsvHeaderType,
      l10n.supplierTsvHeaderRegType,
      l10n.supplierTsvHeaderForeignExporterId,
      l10n.supplierTsvHeaderCargoxId,
      l10n.supplierTsvHeaderCountry,
      l10n.supplierTsvHeaderCountryCode,
      l10n.supplierTsvHeaderAddress,
      l10n.supplierTsvHeaderPhone,
      l10n.supplierTsvHeaderEmail,
      l10n.supplierTsvHeaderBankName,
      l10n.supplierTsvHeaderSwiftCode,
      l10n.supplierTsvHeaderIban,
      l10n.supplierTsvHeaderStatus,
      l10n.supplierTsvHeaderBrands,
      l10n.supplierTsvHeaderNotes,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));

    for (final s in suppliers) {
      final row = [
        s.supplierCode,
        s.companyName,
        _getSupplierTypeLabel(context, s.supplierType),
        _getRegTypeLabel(context, s.registrationType),
        s.foreignExporterId,
        s.cargoxPlatformId ?? '',
        s.foreignExporterCountry,
        s.foreignExporterCountryCode,
        s.address,
        s.phone ?? '',
        s.email ?? '',
        s.bankName ?? '',
        s.swiftCode ?? '',
        s.iban ?? '',
        s.isActive ? l10n.statusActive : l10n.statusInactive,
        s.brands ?? '',
        s.notes ?? '',
      ];
      buffer.writeln(row.map((cell) => cell.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t'));
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.suppliersExportTsvSuccess);
  }

  String _buildSupplierSummary(SupplierModel s) {
    final l10n = context.l10n;
    return '''
[${s.supplierCode}] ${s.companyName}
${l10n.supplierTsvHeaderType}: ${_getSupplierTypeLabel(context, s.supplierType)} | ${l10n.supplierTsvHeaderRegType}: ${_getRegTypeLabel(context, s.registrationType)}
${l10n.supplierTsvHeaderForeignExporterId}: ${s.foreignExporterId} | ${l10n.supplierTsvHeaderCargoxId}: ${s.cargoxPlatformId ?? '-'}
${l10n.supplierTsvHeaderCountry}: ${s.foreignExporterCountry} (${s.foreignExporterCountryCode})
${l10n.supplierTsvHeaderAddress}: ${s.address}
${l10n.supplierTsvHeaderPhone}: ${s.phone ?? '-'} | ${l10n.supplierTsvHeaderEmail}: ${s.email ?? '-'}
${l10n.supplierTsvHeaderBankName}: ${s.bankName ?? '-'} | ${l10n.supplierTsvHeaderSwiftCode}: ${s.swiftCode ?? '-'}
${l10n.supplierTsvHeaderIban}: ${s.iban ?? '-'}
${l10n.supplierTsvHeaderStatus}: ${s.isActive ? l10n.statusActive : l10n.statusInactive}
${l10n.supplierTsvHeaderBrands}: ${s.brands ?? '-'}
'''.trim();
  }

  String _getSupplierTypeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'Manufacturer':
        return l10n.supplierTypeManufacturer;
      case 'Foreign Supplier / Trader':
        return l10n.supplierTypeTrader;
      case 'Authorized Agent / Distributor':
        return l10n.supplierTypeAgent;
      case 'Exporter':
        return l10n.supplierTypeExporter;
      default:
        return type;
    }
  }

  String _getRegTypeLabel(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'Factory Registration':
        return l10n.regTypeFactory;
      case 'Foreign Exporter Number (Nafeza)':
        return l10n.regTypeNafezaExporter;
      case 'Company Registration Number':
        return l10n.regTypeCompanyReg;
      case 'VAT Number':
        return l10n.regTypeVat;
      case 'Tax Number':
        return l10n.regTypeTax;
      case 'Commercial Register':
        return l10n.regTypeCommercial;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suppliersAsync = ref.watch(suppliersProvider);
    final showInactive = ref.watch(showInactiveSuppliersProvider);

    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.local_shipping_outlined,
        title: l10n.suppliersScreenTitle,
        subtitle: l10n.suppliersScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActionToolbar(
                primaryActions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.add, size: density.buttonIconSize),
                    label: Text(
                      l10n.addForeignSupplierBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showSupplierDialog(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.auto_awesome_rounded, size: density.buttonIconSize),
                    label: Text(
                      l10n.aiExtractorAndCodingBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => UniversalEntityExtractorDialog.showSupplierExtractor(
                      context,
                      onSaved: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                    ),
                  ),
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: suppliersAsync.valueOrNull != null && suppliersAsync.valueOrNull!.isNotEmpty,
                ),
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'export_excel':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'suppliers',
                        actionEndpoint: 'export-excel',
                        defaultFileName: 'Foreign_Suppliers_Report.xlsx',
                        dialogTitle: 'تصدير الموردين الأجانب إكسيل',
                      );
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'suppliers',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Foreign_Suppliers_Report.pdf',
                        dialogTitle: 'تصدير الموردين الأجانب PDF',
                      );
                      break;
                    case 'copy_tsv':
                      if (suppliersAsync.valueOrNull != null) {
                        _copySuppliersTsv(suppliersAsync.valueOrNull!);
                      }
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'suppliers',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Foreign_Suppliers_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج الموردين الأجانب',
                      );
                      break;
                    case 'import_excel':
                      MasterDataActionHelper.importExcel(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'suppliers',
                        onImportSuccess: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchSuppliersHint,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                filters: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.showInactiveSuppliersLabel,
                        style: TextStyle(
                          fontSize: density.buttonFontSize - 1,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: showInactive,
                          activeColor: AppTheme.cobalt,
                          onChanged: (val) {
                            ref.read(showInactiveSuppliersProvider.notifier).state = val;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                  ),
                  if (suppliersAsync.valueOrNull != null && suppliersAsync.valueOrNull!.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.suppliersExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copySuppliersTsv(suppliersAsync.valueOrNull!),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Data Table Content
            Expanded(
              child: suppliersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.cobalt)),
                error: (err, stack) => Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.crimson),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            l10n.suppliersFetchError(err.toString()),
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retryConnectionBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            ref.read(suppliersProvider.notifier).fetchSuppliers();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                data: (suppliers) {
                  final filtered = suppliers.where((s) {
                    final q = _searchQuery;
                    return q.isEmpty ||
                        s.companyName.toLowerCase().contains(q) ||
                        s.supplierCode.toLowerCase().contains(q) ||
                        s.foreignExporterId.toLowerCase().contains(q) ||
                        s.foreignExporterCountry.toLowerCase().contains(q) ||
                        (s.brands?.toLowerCase().contains(q) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(l10n.noSuppliersFound, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final supplier = filtered[index];
                        return _buildSupplierRow(supplier);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSupplierRow(SupplierModel supplier) {
    final l10n = context.l10n;
    final isActive = supplier.isActive;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        RowContextMenuHelper.showContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          codeToCopy: supplier.supplierCode,
          onView: () => SupplierDetailsDialog.show(
            context,
            supplier,
            onEdit: () => _showSupplierDialog(context, supplierToEdit: supplier),
          ),
          onEdit: () => _showSupplierDialog(context, supplierToEdit: supplier),
          onHistory: () => RowHistoryDialog.show(
            context,
            entityType: 'Supplier',
            entityId: supplier.supplierId!,
            entityTitle: supplier.companyName,
          ),
          isActive: isActive,
          onToggleActive: () async {
            if (supplier.supplierId != null) {
              await ref.read(suppliersProvider.notifier).toggleActiveStatus(supplier.supplierId!, isActive);
            }
          },
        );
      },
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              // Standard 4-Action Row Pill: View, Edit, Print, Delete
              RowActionsPill(

                onView: () => SupplierDetailsDialog.show(
                  context,
                  supplier,
                  onEdit: () => _showSupplierDialog(context, supplierToEdit: supplier),
                ),
                onEdit: () => _showSupplierDialog(context, supplierToEdit: supplier),
                onPrint: () => MasterDataExportService.printOrSaveSupplierPdf(supplier),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.confirmActionTitle),
                      content: Text(isActive
                          ? l10n.confirmDeactivateSupplier(supplier.companyName)
                          : l10n.confirmActivateSupplier(supplier.companyName)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.emerald),
                          child: Text(isActive ? l10n.deactivateBtn : l10n.activateBtn, style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && supplier.supplierId != null) {
                    ref.read(suppliersProvider.notifier).toggleActiveStatus(supplier.supplierId!, isActive);
                  }
                },
                deleteTooltip: isActive ? l10n.deactivateSupplierTooltip : l10n.activateSupplierTooltip,
              ),
              const SizedBox(width: 4),
              // Quick Copy Supplier Summary Button
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 20),
                tooltip: l10n.supplierCopySummaryBtn,
                onPressed: () => CopyHelper.copy(
                  context,
                  _buildSupplierSummary(supplier),
                  customMessage: l10n.supplierCopySummarySuccess,
                ),
              ),
              // AI Route Intelligence & GOEIC Compliance Buttons
              if (supplier.supplierId != null) ...[
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 20),
                  tooltip: l10n.routeIntelligenceBtnTooltip,
                  onPressed: () => showRouteIntelligenceDialog(
                    context,
                    ref,
                    supplierId: supplier.supplierId!,
                    supplierName: supplier.companyName,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 20),
                  tooltip: l10n.supplierScorecardBtnTooltip,
                  onPressed: () => showSupplierScorecardDialog(
                    context,
                    ref,
                    supplierId: supplier.supplierId!,
                    supplierName: supplier.companyName,
                    country: supplier.foreignExporterCountry,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 20),
                  tooltip: l10n.goeicVerificationBtnTooltip,
                  onPressed: () => showGOEICVerificationDialog(
                    context,
                    ref,
                    supplierId: supplier.supplierId!,
                    supplierName: supplier.companyName,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 8),
              // Icon Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.cobalt : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.factory, color: isActive ? AppTheme.cobalt : Colors.grey),
              ),
              const SizedBox(width: 16),

              // Supplier Code & Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Tooltip(
                          message: l10n.supplierCodeBadgeLabel,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => CopyHelper.copy(context, supplier.supplierCode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.charcoal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    supplier.supplierCode,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded, size: 11, color: AppTheme.charcoal),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            supplier.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                          tooltip: l10n.suppliersCopyFieldTooltip,
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => CopyHelper.copy(context, supplier.companyName),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? l10n.statusActive : l10n.statusInactive,
                            style: TextStyle(
                              color: isActive ? AppTheme.emerald : AppTheme.crimson,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.supplierRowMeta(supplier.foreignExporterId, supplier.cargoxPlatformId, supplier.address, supplier.brands),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Country & Code Badge
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            supplier.foreignExporterCountryCode.toUpperCase(),
                            style: const TextStyle(color: AppTheme.orange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(supplier.foreignExporterCountry, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.supplierTypeAndReg(_getSupplierTypeLabel(context, supplier.supplierType), _getRegTypeLabel(context, supplier.registrationType)),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, {SupplierModel? supplierToEdit}) {
    final l10n = context.l10n;
    final isEditing = supplierToEdit != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(text: supplierToEdit?.companyName ?? '');
    String selectedSupplierType = supplierToEdit?.supplierType ?? 'Manufacturer';
    String selectedRegType = supplierToEdit?.registrationType ?? 'Factory Registration';

    final supplierTypeOptions = [
      'Manufacturer',
      'Foreign Supplier / Trader',
      'Authorized Agent / Distributor',
      'Exporter',
    ];

    final regTypeOptions = [
      'Factory Registration',
      'Foreign Exporter Number (Nafeza)',
      'Company Registration Number',
      'VAT Number',
      'Tax Number',
      'Commercial Register',
    ];

    final expIdCtrl = TextEditingController(text: supplierToEdit?.foreignExporterId ?? '');
    final cargoxPlatformIdCtrl = TextEditingController(text: supplierToEdit?.cargoxPlatformId ?? '');
    final countryCtrl = TextEditingController(text: supplierToEdit?.foreignExporterCountry ?? '');
    final countryCodeCtrl = TextEditingController(text: supplierToEdit?.foreignExporterCountryCode ?? '');
    final addressCtrl = TextEditingController(text: supplierToEdit?.address ?? '');
    final phoneCtrl = TextEditingController(text: supplierToEdit?.phone ?? '');
    final mobileCtrl = TextEditingController(text: supplierToEdit?.mobile ?? '');
    final faxCtrl = TextEditingController(text: supplierToEdit?.fax ?? '');
    final emailCtrl = TextEditingController(text: supplierToEdit?.email ?? '');
    final secondaryEmailCtrl = TextEditingController(text: supplierToEdit?.secondaryEmail ?? '');
    final websiteCtrl = TextEditingController(text: supplierToEdit?.website ?? '');
    final bankNameCtrl = TextEditingController(text: supplierToEdit?.bankName ?? '');
    final swiftCodeCtrl = TextEditingController(text: supplierToEdit?.swiftCode ?? '');
    final accountNumberCtrl = TextEditingController(text: supplierToEdit?.accountNumber ?? '');
    final ibanCtrl = TextEditingController(text: supplierToEdit?.iban ?? '');
    final brandsCtrl = TextEditingController(text: supplierToEdit?.brands ?? '');
    final notesCtrl = TextEditingController(text: supplierToEdit?.notes ?? '');

    bool hasIso = supplierToEdit?.hasIso ?? false;
    bool registeredDecree43 = supplierToEdit?.registeredDecree43 ?? false;
    bool whiteListRegistered = supplierToEdit?.whiteListRegistered ?? false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildCopySuffix(TextEditingController ctrl) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: ctrl,
                builder: (_, val, __) {
                  if (val.text.trim().isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                    tooltip: l10n.suppliersCopyFieldTooltip,
                    splashRadius: 16,
                    onPressed: () => CopyHelper.copy(dialogCtx, val.text),
                  );
                },
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SelectionArea(
                child: SizedBox(
                width: 650,
                height: MediaQuery.of(context).size.height * 0.9,
                child: Column(
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: const BoxDecoration(
                        color: AppTheme.charcoal,
                        borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(isEditing ? Icons.edit : Icons.public, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                isEditing ? l10n.editSupplierDialogTitle : l10n.addSupplierDialogTitle,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            tooltip: l10n.closeDialogTooltip,
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                    ),

                    // Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextField(
                                controller: nameCtrl,
                                suffixIcon: buildCopySuffix(nameCtrl),
                                label: l10n.supplierCompanyNameLabel,
                                icon: Icons.business,
                                isRequired: true,
                                hint: l10n.supplierCompanyNameHint,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  // Supplier Type Dropdown
                                  Expanded(
                                    child: SearchableDropdownField<String>(
                                      value: supplierTypeOptions.contains(selectedSupplierType) ? selectedSupplierType : supplierTypeOptions.first,
                                      labelText: l10n.supplierTypeLabel,
                                      items: supplierTypeOptions
                                          .map((type) => SearchableDropdownItem<String>(
                                                value: type,
                                                label: _getSupplierTypeLabel(context, type),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedSupplierType = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Registration Type Dropdown
                                  Expanded(
                                    child: SearchableDropdownField<String>(
                                      value: regTypeOptions.contains(selectedRegType) ? selectedRegType : regTypeOptions.first,
                                      labelText: l10n.supplierRegTypeLabel,
                                      items: regTypeOptions
                                          .map((type) => SearchableDropdownItem<String>(
                                                value: type,
                                                label: _getRegTypeLabel(context, type),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedRegType = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: expIdCtrl,
                                      suffixIcon: buildCopySuffix(expIdCtrl),
                                      label: l10n.supplierForeignExporterIdLabel,
                                      icon: Icons.badge,
                                      isRequired: true,
                                      hint: l10n.foreignExporterIdHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: cargoxPlatformIdCtrl,
                                      suffixIcon: buildCopySuffix(cargoxPlatformIdCtrl),
                                      label: l10n.cargoxIdLabel,
                                      icon: Icons.verified_user_outlined,
                                      hint: l10n.cargoxIdHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: countryCtrl,
                                      suffixIcon: buildCopySuffix(countryCtrl),
                                      label: l10n.supplierCountryLabel,
                                      icon: Icons.flag,
                                      isRequired: true,
                                      hint: l10n.supplierCountryHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: countryCodeCtrl,
                                      suffixIcon: buildCopySuffix(countryCodeCtrl),
                                      label: l10n.supplierCountryCodeLabel,
                                      icon: Icons.code,
                                      isRequired: true,
                                      hint: l10n.supplierCountryCodeHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: addressCtrl,
                                suffixIcon: buildCopySuffix(addressCtrl),
                                label: l10n.supplierAddressLabel,
                                icon: Icons.location_on,
                                isRequired: true,
                                hint: l10n.supplierAddressHint,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: emailCtrl,
                                      suffixIcon: buildCopySuffix(emailCtrl),
                                      label: l10n.supplierEmailLabel,
                                      icon: Icons.email,
                                      hint: l10n.supplierEmailHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: secondaryEmailCtrl,
                                      suffixIcon: buildCopySuffix(secondaryEmailCtrl),
                                      label: l10n.supplierSecondaryEmailLabel,
                                      icon: Icons.mark_email_read_outlined,
                                      hint: l10n.supplierSecondaryEmailHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: phoneCtrl,
                                      suffixIcon: buildCopySuffix(phoneCtrl),
                                      label: l10n.supplierPhoneLabel,
                                      icon: Icons.phone,
                                      hint: l10n.supplierPhoneHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: mobileCtrl,
                                      suffixIcon: buildCopySuffix(mobileCtrl),
                                      label: l10n.supplierMobileLabel,
                                      icon: Icons.smartphone,
                                      hint: l10n.supplierMobileHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: faxCtrl,
                                      suffixIcon: buildCopySuffix(faxCtrl),
                                      label: l10n.supplierFaxLabel,
                                      icon: Icons.print,
                                      hint: l10n.supplierFaxHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: websiteCtrl,
                                suffixIcon: buildCopySuffix(websiteCtrl),
                                label: l10n.supplierWebsiteLabel,
                                icon: Icons.language,
                                hint: l10n.supplierWebsiteHint,
                              ),
                              const SizedBox(height: 16),
                              // Beneficiary Bank & SWIFT Information
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance, size: 16, color: AppTheme.charcoal),
                                        const SizedBox(width: 6),
                                        Text(l10n.beneficiaryBankDetailsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    CustomTextField(
                                      controller: bankNameCtrl,
                                      suffixIcon: buildCopySuffix(bankNameCtrl),
                                      label: l10n.beneficiaryBankNameLabel,
                                      icon: Icons.business,
                                      hint: l10n.beneficiaryBankNameHint,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomTextField(
                                            controller: swiftCodeCtrl,
                                            textDirection: TextDirection.ltr,
                                            suffixIcon: buildCopySuffix(swiftCodeCtrl),
                                            label: l10n.beneficiarySwiftCodeLabel,
                                            icon: Icons.code,
                                            hint: l10n.beneficiarySwiftCodeHint,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: CustomTextField(
                                            controller: accountNumberCtrl,
                                            suffixIcon: buildCopySuffix(accountNumberCtrl),
                                            label: l10n.beneficiaryAccountNumberLabel,
                                            icon: Icons.numbers,
                                            hint: l10n.beneficiaryAccountNumberHint,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    CustomTextField(
                                      controller: ibanCtrl,
                                      textDirection: TextDirection.ltr,
                                      suffixIcon: buildCopySuffix(ibanCtrl),
                                      label: l10n.beneficiaryIbanLabel,
                                      icon: Icons.credit_card,
                                      hint: l10n.beneficiaryIbanHint,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Compliance Flags Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.complianceAndCertsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(l10n.isoCertifiedCheck),
                                      value: hasIso,
                                      activeColor: AppTheme.cobalt,
                                      onChanged: (val) => setDialogState(() => hasIso = val ?? false),
                                    ),
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(l10n.decree43Check),
                                      value: registeredDecree43,
                                      activeColor: AppTheme.cobalt,
                                      onChanged: (val) => setDialogState(() => registeredDecree43 = val ?? false),
                                    ),
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(l10n.whiteListCheck),
                                      value: whiteListRegistered,
                                      activeColor: AppTheme.emerald,
                                      onChanged: (val) => setDialogState(() => whiteListRegistered = val ?? false),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: brandsCtrl,
                                suffixIcon: buildCopySuffix(brandsCtrl),
                                label: l10n.brandsProductLinesLabel,
                                icon: Icons.branding_watermark,
                                hint: l10n.brandsProductLinesHint,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: notesCtrl,
                                suffixIcon: buildCopySuffix(notesCtrl),
                                label: l10n.supplierNotesLabel,
                                icon: Icons.notes,
                                hint: l10n.supplierNotesHint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Dialog Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadiusDirectional.only(bottomStart: Radius.circular(16), bottomEnd: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.crimson,
                              side: BorderSide(color: Colors.red.shade300),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                            label: Text(l10n.cancelAndCloseBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(isEditing ? l10n.updateSupplierBtn : l10n.saveSupplierBtn),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              final supplier = SupplierModel(
                                supplierId: supplierToEdit?.supplierId,
                                supplierCode: supplierToEdit?.supplierCode ?? '',
                                companyName: nameCtrl.text.trim(),
                                supplierType: selectedSupplierType,
                                registrationType: selectedRegType,
                                foreignExporterId: expIdCtrl.text.trim(),
                                cargoxPlatformId: cargoxPlatformIdCtrl.text.trim().isEmpty ? null : cargoxPlatformIdCtrl.text.trim(),
                                foreignExporterCountry: countryCtrl.text.trim(),
                                foreignExporterCountryCode: countryCodeCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                                fax: faxCtrl.text.trim().isEmpty ? null : faxCtrl.text.trim(),
                                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                secondaryEmail: secondaryEmailCtrl.text.trim().isEmpty ? null : secondaryEmailCtrl.text.trim(),
                                website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
                                bankName: bankNameCtrl.text.trim().isEmpty ? null : bankNameCtrl.text.trim(),
                                swiftCode: swiftCodeCtrl.text.trim().isEmpty ? null : swiftCodeCtrl.text.trim(),
                                accountNumber: accountNumberCtrl.text.trim().isEmpty ? null : accountNumberCtrl.text.trim(),
                                iban: ibanCtrl.text.trim().isEmpty ? null : ibanCtrl.text.trim(),
                                hasIso: hasIso,
                                registeredDecree43: registeredDecree43,
                                whiteListRegistered: whiteListRegistered,
                                brands: brandsCtrl.text.trim().isEmpty ? null : brandsCtrl.text.trim(),
                                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                isActive: supplierToEdit?.isActive ?? true,
                              );


                              String? errorMessage;
                              if (isEditing && supplierToEdit.supplierId != null) {
                                final List<FieldChangeItem> changes = [];
                                if (FieldChangeItem.isDifferent(supplierToEdit.companyName, supplier.companyName)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCompanyName, oldValue: supplierToEdit.companyName, newValue: supplier.companyName));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.supplierType, supplier.supplierType)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierType, oldValue: supplierToEdit.supplierType, newValue: supplier.supplierType));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.registrationType, supplier.registrationType)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierRegType, oldValue: supplierToEdit.registrationType, newValue: supplier.registrationType));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterId, supplier.foreignExporterId)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffForeignExporterId, oldValue: supplierToEdit.foreignExporterId, newValue: supplier.foreignExporterId));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.cargoxPlatformId, supplier.cargoxPlatformId)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffCargoXId, oldValue: supplierToEdit.cargoxPlatformId ?? '', newValue: supplier.cargoxPlatformId ?? ''));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterCountry, supplier.foreignExporterCountry)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCountry, oldValue: supplierToEdit.foreignExporterCountry, newValue: supplier.foreignExporterCountry));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.email, supplier.email)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierEmail, oldValue: supplierToEdit.email, newValue: supplier.email));
                                }
                                if (FieldChangeItem.isDifferent(supplierToEdit.phone, supplier.phone)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffSupplierPhone, oldValue: supplierToEdit.phone, newValue: supplier.phone));
                                }

                                if (changes.isNotEmpty) {
                                  final confirmed = await showChangeDiffConfirmationDialog(
                                    context,
                                    title: l10n.diffConfirmSupplierTitle,
                                    itemReference: '${supplierToEdit.supplierCode} (${supplierToEdit.companyName})',
                                    changes: changes,
                                  );
                                  if (!confirmed) return;
                                }

                                errorMessage = await ref.read(suppliersProvider.notifier).updateSupplier(supplierToEdit.supplierId!, supplier);
                              } else {
                                errorMessage = await ref.read(suppliersProvider.notifier).createSupplier(supplier);
                              }

                              if (errorMessage == null) {
                                if (context.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      backgroundColor: AppTheme.crimson,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      },
    );
  }
}
