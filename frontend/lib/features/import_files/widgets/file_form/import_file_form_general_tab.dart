import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../projects/models/project_model.dart';
import '../../../projects/providers/projects_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/import_file_model.dart';
import '../import_file_form_dialog.dart';

/// 🚢 Tab 1: General & Commercial Information for [ImportFileFormDialog].
///
/// Houses file identification, importing company, supplier, commercial references
/// (PO/PI), multiple invoices & packing lists, linked projects, currency, estimated costs,
/// responsible owner, and operational notes.
class ImportFileFormGeneralTab extends ConsumerStatefulWidget {
  final ImportFileFormDialogState dialog;

  const ImportFileFormGeneralTab({super.key, required this.dialog});

  @override
  ConsumerState<ImportFileFormGeneralTab> createState() => _ImportFileFormGeneralTabState();
}

class _ImportFileFormGeneralTabState extends ConsumerState<ImportFileFormGeneralTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dialog = widget.dialog;
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final companies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final projects = (ref.watch(projectsProvider).valueOrNull ?? [])
        .where((p) => dialog.selectedCompanyId == null || p.companyId == dialog.selectedCompanyId)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Custom File ID & Importing Company ──────────────────
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: dialog.customFileIdController,
                  decoration: InputDecoration(
                    labelText: '${l.importFileIdLabel} *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: isArabic ? 'نسخ رقم الملف' : 'Copy File No',
                      onPressed: () => CopyHelper.copy(context, dialog.customFileIdController.text),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.importFileIdLabel : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdownField<int?>(
                  value: dialog.selectedCompanyId,
                  labelText: '${l.importingCompany} *',
                  searchHintText: l.searchByShipmentOrCompany,
                  items: companies
                      .map((c) => SearchableDropdownItem<int?>(
                            value: c.companyId,
                            label: c.importerName,
                            subtitle: c.vatId,
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final comp = companies.firstWhere((c) => c.companyId == val);
                      dialog.setState(() {
                        dialog.selectedCompanyId = val;
                        dialog.companyName = comp.importerName;
                        dialog.selectedProjectIds.clear();
                      });
                      dialog.markDirty();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Row 2: Supplier, PO No, PI No ──────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SearchableDropdownField<int?>(
                  value: dialog.selectedSupplierId,
                  labelText: '${l.foreignSupplier} *',
                  searchHintText: l.searchByShipmentOrCompany,
                  items: suppliers
                      .map((s) => SearchableDropdownItem<int?>(
                            value: s.supplierId,
                            label: s.companyName,
                            subtitle: s.foreignExporterCountry,
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final sup = suppliers.firstWhere((s) => s.supplierId == val);
                      dialog.setState(() {
                        dialog.selectedSupplierId = val;
                        dialog.supplierName = sup.companyName;
                        final fullAddr = [sup.address, sup.foreignExporterCountry].where((s) => s.isNotEmpty).join(', ');
                        dialog.pickupAddressController.text = fullAddr.isNotEmpty ? fullAddr : sup.address;
                      });
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: dialog.poNoController,
                  decoration: InputDecoration(
                    labelText: '${l.purchaseOrder} *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: isArabic ? 'نسخ أمر الشراء' : 'Copy PO No',
                      onPressed: () => CopyHelper.copy(context, dialog.poNoController.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: dialog.piNoController,
                  decoration: InputDecoration(
                    labelText: '${l.poInvoiceLabel} *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: isArabic ? 'نسخ الفاتورة المبدئية' : 'Copy PI No',
                      onPressed: () => CopyHelper.copy(context, dialog.piNoController.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Multi Invoices & Packing Lists Bar ─────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${l.invoicesCountAndNumbers} (${dialog.invoices.length} ${l.invoicesUnit} | ${dialog.packingLists.length} ${l.packingListsUnit})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        dialog.setState(() {
                          dialog.invoices.add(
                            InvoiceItemModel(invoiceNo: 'PI-${890 + dialog.invoices.length}', amount: 12000, currency: 'USD'),
                          );
                        });
                        dialog.markDirty();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('+ ${l.poInvoiceLabel}'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        dialog.setState(() {
                          dialog.packingLists.add(
                            PackingListItemModel(plNo: 'PL-${890 + dialog.packingLists.length}', totalPackages: 30, cbm: 20),
                          );
                        });
                        dialog.markDirty();
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('+ ${l.packingListsUnit}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Multi-Project Selection Container ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.4) : Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${l.multiProjectsTitle}: ${dialog.selectedProjectIds.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ],
                ),
                if (dialog.selectedProjectIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: dialog.selectedProjectIds.map((pid) {
                      final pj = projects.firstWhere(
                        (p) => p.projectId == pid,
                        orElse: () => ProjectModel(
                          projectId: pid,
                          projectCode: 'PRJ-$pid',
                          projectName: 'Project #$pid',
                          projectOwner: '',
                          companyId: 0,
                          companyIds: [],
                          supplierId: 0,
                          incotermId: 0,
                          importType: 'FOB',
                          priority: 'High',
                          shipmentCategory: 'New Purchase',
                          allowMultiShipment: false,
                          allowMultiCompany: false,
                          status: 'Active',
                        ),
                      );
                      return InputChip(
                        label: Text('${pj.projectName} (${pj.projectCode})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: true,
                        selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.red),
                        onDeleted: () {
                          dialog.setState(() {
                            dialog.selectedProjectIds.remove(pid);
                          });
                          dialog.markDirty();
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                SearchableDropdownField<int?>(
                  value: null,
                  labelText: '+ ${l.multiProjectsTitle}',
                  searchHintText: l.searchByShipmentOrCompany,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: '-- ${l.multiProjectsTitle} --'),
                    ...projects.map((p) => SearchableDropdownItem<int?>(
                          value: p.projectId,
                          label: '${p.projectName} (${p.projectCode})',
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null && !dialog.selectedProjectIds.contains(val)) {
                      dialog.setState(() {
                        dialog.selectedProjectIds.add(val);
                        final proj = projects.where((p) => p.projectId == val).firstOrNull;
                        if (proj != null && proj.projectOwner.isNotEmpty && dialog.ownerController.text.trim().isEmpty) {
                          dialog.ownerController.text = proj.projectOwner;
                        }
                      });
                      dialog.markDirty();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Currency, Estimated Cost, Responsible Person ──────────────
          Row(
            children: [
              SizedBox(
                width: 140,
                child: SearchableDropdownField<String>(
                  value: currencies.any((c) => c.currencyCode == dialog.estimatedCostCurrency)
                      ? dialog.estimatedCostCurrency
                      : (dialog.estimatedCostCurrency.isNotEmpty ? dialog.estimatedCostCurrency : 'USD'),
                  labelText: '${l.currency} *',
                  items: (currencies.isNotEmpty
                          ? currencies.map((c) => c.currencyCode).toList()
                          : ['USD', 'EUR', 'EGP', 'CNY', 'GBP', 'SAR', 'AED'])
                      .map((code) => SearchableDropdownItem<String>(value: code, label: code))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      dialog.setState(() => dialog.estimatedCostCurrency = v);
                      dialog.markDirty();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: dialog.estimatedCostController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l.totalCostMetric} (${dialog.estimatedCostCurrency}) *',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.totalCostMetric : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: dialog.ownerController,
                  decoration: InputDecoration(
                    labelText: '${l.owner} *',
                    hintText: l.ownerFieldHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.ownerFieldRequired : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Notes ──────────────────────────────────────────────────────
          TextFormField(
            controller: dialog.notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.notes,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: isArabic ? 'نسخ الملاحظات' : 'Copy Notes',
                onPressed: () => CopyHelper.copy(context, dialog.notesController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
