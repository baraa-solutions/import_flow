import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../incoterms/providers/incoterms_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/project_model.dart';
import '../providers/projects_provider.dart';
import 'projects_screen/projects_helpers.dart';

/// Modal dialog for creating or editing a Project & Cost Center record.
class ProjectFormDialog extends ConsumerStatefulWidget {
  final ProjectModel? project;

  const ProjectFormDialog({
    super.key,
    this.project,
  });

  /// Shows the project form dialog after verifying master prerequisites.
  static Future<void> show(
    BuildContext context, {
    WidgetRef? ref,
    ProjectModel? project,
  }) async {
    final l10n = context.l10n;
    if (ref != null) {
      final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
      final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];

      if (companies.isEmpty || suppliers.isEmpty || incoterms.isEmpty) {
        AppTheme.snackBar(
          context,
          l10n.projectPrerequisitesMissing,
          severity: AppSeverity.warning,
        );
        return;
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProjectFormDialog(project: project),
    );
  }

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _targetEndDateCtrl;
  late final TextEditingController _notesCtrl;

  late Set<int> _selectedCompanyIds;
  late int _selectedSupplierId;
  late int _selectedIncotermId;
  late String _selectedImportType;
  late String _selectedPriority;
  late String _selectedStatus;
  late bool _allowMultiShipment;
  late bool _allowMultiCompany;
  late String _selectedCurrency;
  late Set<String> _selectedCategories;
  bool _isSubmitting = false;

  final List<String> _availableCategories = const [
    'FCL Container',
    'LCL Breakbulk',
    'Air Freight',
    'Bulk Cargo',
    'Multimodal',
    'Courier',
  ];

  late final List<String> _availableCurrencies;

  @override
  void initState() {
    super.initState();
    final p = widget.project;

    _nameCtrl = TextEditingController(text: p?.projectName ?? '');
    _ownerCtrl = TextEditingController(text: p?.projectOwner ?? '');
    _budgetCtrl = TextEditingController(text: p?.totalBudgetUsd?.toString() ?? '');
    _targetEndDateCtrl = TextEditingController(text: p?.targetEndDate ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');

    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];

    _selectedCompanyIds = p != null && p.companyIds.isNotEmpty
        ? p.companyIds.toSet()
        : (companies.isNotEmpty && companies.first.companyId != null
            ? {companies.first.companyId!}
            : <int>{});

    _selectedSupplierId =
        p?.supplierId ?? (suppliers.isNotEmpty ? (suppliers.first.supplierId ?? 0) : 0);
    _selectedIncotermId =
        p?.incotermId ?? (incoterms.isNotEmpty ? incoterms.first.incotermId : 0);
    _selectedImportType = p?.importType ?? 'Direct Commercial';
    _selectedPriority = p?.priority ?? 'Medium';
    _selectedStatus = p?.status ?? 'Open';
    _allowMultiShipment = p?.allowMultiShipment ?? true;
    _allowMultiCompany = p?.allowMultiCompany ?? true;

    _selectedCurrency = p?.budgetCurrency ?? 'USD';
    _availableCurrencies = ['USD', 'EUR', 'EGP', 'GBP', 'CNY', 'AED', 'SAR', 'JPY'];
    if (!_availableCurrencies.contains(_selectedCurrency)) {
      _availableCurrencies.insert(0, _selectedCurrency);
    }

    _selectedCategories = p != null && p.shipmentCategory.isNotEmpty
        ? p.shipmentCategory
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
        : {'FCL Container'};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _budgetCtrl.dispose();
    _targetEndDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCompanyIds.isEmpty) {
      AppTheme.snackBar(
        context,
        l10n.selectAtLeastOneCompanyError,
        severity: AppSeverity.warning,
      );
      return;
    }
    if (_selectedCategories.isEmpty) {
      AppTheme.snackBar(
        context,
        l10n.selectAtLeastOneCategoryError,
        severity: AppSeverity.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final budget = double.tryParse(_budgetCtrl.text.trim());
      final categoryString = _selectedCategories.join(', ');
      final companyIdsList = _selectedCompanyIds.toList();

      if (widget.project == null) {
        final newModel = ProjectModel(
          projectCode: '',
          projectName: _nameCtrl.text.trim(),
          projectOwner: _ownerCtrl.text.trim(),
          companyId: companyIdsList.first,
          companyIds: companyIdsList,
          supplierId: _selectedSupplierId,
          incotermId: _selectedIncotermId,
          importType: _selectedImportType,
          priority: _selectedPriority,
          shipmentCategory: categoryString,
          allowMultiShipment: _allowMultiShipment,
          allowMultiCompany: _allowMultiCompany,
          totalBudgetUsd: budget,
          budgetCurrency: _selectedCurrency,
          targetEndDate: _targetEndDateCtrl.text.trim().isEmpty
              ? null
              : _targetEndDateCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        final ok = await ref.read(projectsProvider.notifier).createProject(newModel);
        if (ok && mounted) Navigator.pop(context);
      } else {
        final updateData = {
          'project_name': _nameCtrl.text.trim(),
          'project_owner': _ownerCtrl.text.trim(),
          'company_id': companyIdsList.first,
          'company_ids': companyIdsList,
          'supplier_id': _selectedSupplierId,
          'incoterm_id': _selectedIncotermId,
          'import_type': _selectedImportType,
          'priority': _selectedPriority,
          'shipment_category': categoryString,
          'allow_multi_shipment': _allowMultiShipment,
          'allow_multi_company': _allowMultiCompany,
          'total_budget_usd': budget,
          'budget_currency': _selectedCurrency,
          'target_end_date': _targetEndDateCtrl.text.trim().isEmpty
              ? null
              : _targetEndDateCtrl.text.trim(),
          'status': _selectedStatus,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        };
        final ok = await ref
            .read(projectsProvider.notifier)
            .updateProject(widget.project!.projectId!, updateData);
        if (ok && mounted) Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final companies = ref.watch(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.watch(incotermsProvider).valueOrNull ?? [];

    final title = widget.project == null
        ? l10n.createProjectDialogTitle
        : l10n.editProjectDialogTitle(widget.project!.projectCode);

    return SelectionArea(
      child: AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 650,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.projectNameLabel,
                      hintText: l10n.projectNameHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.projectsCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _nameCtrl.text),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.requiredField : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ownerCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.projectOwnerLabelField,
                      hintText: l10n.projectOwnerHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.projectsCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _ownerCtrl.text),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.requiredField : null,
                  ),
                  const SizedBox(height: 14),

                  // Multi-Select Importing Companies
                  Text(
                    l10n.importingCompaniesFieldLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: companies.map((c) {
                        final isSelected = c.companyId != null &&
                            _selectedCompanyIds.contains(c.companyId);
                        return FilterChip(
                          label: Text(c.importerName),
                          selected: isSelected,
                          selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                          checkmarkColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (bool selected) {
                            if (c.companyId == null) return;
                            setState(() {
                              if (selected) {
                                _selectedCompanyIds.add(c.companyId!);
                              } else {
                                if (_selectedCompanyIds.length > 1) {
                                  _selectedCompanyIds.remove(c.companyId);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Supplier & Incoterm
                  Row(
                    children: [
                      Expanded(
                        child: SearchableDropdownField<int?>(
                          value: _selectedSupplierId,
                          labelText: l10n.primarySupplierLabel,
                          items: suppliers
                              .map((s) => SearchableDropdownItem<int?>(
                                    value: s.supplierId,
                                    label: s.companyName,
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedSupplierId = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownField<int?>(
                          value: _selectedIncotermId,
                          labelText: l10n.defaultIncotermLabel,
                          items: incoterms
                              .map((i) => SearchableDropdownItem<int?>(
                                    value: i.incotermId,
                                    label: '${i.incotermCode} (${i.incotermName})',
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedIncotermId = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Import Type & Priority
                  Row(
                    children: [
                      Expanded(
                        child: SearchableDropdownField<String>(
                          value: _selectedImportType,
                          labelText: l10n.importTypeLabel,
                          items: [
                            'Direct Commercial',
                            'Free Zone',
                            'Temporary Release',
                            'Drawback',
                            'Project Equipment',
                          ]
                              .map((t) => SearchableDropdownItem<String>(
                                    value: t,
                                    label: ProjectsHelpers.getImportTypeLabel(context, t),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _selectedImportType = v ?? 'Direct Commercial'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownField<String>(
                          value: _selectedPriority,
                          labelText: l10n.priorityLabel,
                          items: ['Low', 'Medium', 'High', 'Urgent']
                              .map((p) => SearchableDropdownItem<String>(
                                    value: p,
                                    label: ProjectsHelpers.getPriorityLabel(context, p),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPriority = v ?? 'Medium'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SearchableDropdownField<String>(
                    value: _selectedStatus,
                    labelText: l10n.projectStatusLabel,
                    items: ['Open', 'Closed', 'On Hold']
                        .map((s) => SearchableDropdownItem<String>(
                              value: s,
                              label: ProjectsHelpers.getStatusLabel(context, s),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v ?? 'Open'),
                  ),
                  const SizedBox(height: 14),

                  // Multi-Select Shipment Categories
                  Text(
                    l10n.allowedShipmentCategoriesLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _availableCategories.map((cat) {
                        final isSelected = _selectedCategories.contains(cat);
                        return FilterChip(
                          label: Text(ProjectsHelpers.getCategoryLabel(context, cat)),
                          selected: isSelected,
                          selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                          checkmarkColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(cat);
                              } else {
                                if (_selectedCategories.length > 1) {
                                  _selectedCategories.remove(cat);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Budget Amount, Currency, and Target Date
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _budgetCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.estTotalBudgetUsdLabel,
                            hintText: l10n.estTotalBudgetUsdHint,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: l10n.projectsCopyFieldTooltip,
                              onPressed: () =>
                                  CopyHelper.copy(context, _budgetCtrl.text),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: SearchableDropdownField<String>(
                          value: _selectedCurrency,
                          labelText: l10n.budgetCurrencyLabel,
                          items: _availableCurrencies
                              .map((c) => SearchableDropdownItem<String>(
                                    value: c,
                                    label: c,
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedCurrency = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDatePickerField(
                          label: l10n.targetEndDateLabel,
                          hint: l10n.targetEndDateHint,
                          value: DateTime.tryParse(_targetEndDateCtrl.text),
                          onChanged: (d) {
                            setState(() {
                              _targetEndDateCtrl.text =
                                  d != null ? AppDatePickerField.format(d) : '';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Capabilities Checkboxes (Multi-Shipment & Multi-Company)
                  CheckboxListTile(
                    title: Text(l10n.allowMultiShipmentTitle),
                    subtitle: Text(l10n.allowMultiShipmentSubtitle),
                    value: _allowMultiShipment,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) =>
                        setState(() => _allowMultiShipment = val ?? true),
                  ),
                  CheckboxListTile(
                    title: Text(l10n.allowMultiCompanyTitle),
                    subtitle: Text(l10n.allowMultiCompanySubtitle),
                    value: _allowMultiCompany,
                    activeColor: AppTheme.cobalt,
                    onChanged: (val) =>
                        setState(() => _allowMultiCompany = val ?? true),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.projectNotesLabel,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l10n.projectsCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _notesCtrl.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: widget.project == null
                ? l10n.createProjectSubmitBtn
                : l10n.saveChangesSubmitBtn,
            variant: AppButtonVariant.primary,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
