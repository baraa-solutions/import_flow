import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/change_diff_dialog.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../projects/providers/projects_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../providers/import_files_provider.dart';
import '../import_file_form_dialog.dart';

/// 🚢 Modular Submitter for [ImportFileFormDialog].
///
/// Handles field validation, payload assembly, change-diff confirmation dialog,
/// backend API persistence, and cache invalidation.
class ImportFileFormSubmitter {
  static Map<String, dynamic> buildPayload({
    required ImportFileFormDialogState state,
    required String selectedOwner,
    required String selectedPjNames,
  }) {
    return {
      'custom_file_number': state.customFileIdController.text.trim().isEmpty ? null : state.customFileIdController.text.trim(),
      'company_id': state.selectedCompanyId,
      'company_name': state.companyName,
      'supplier_id': state.selectedSupplierId,
      'supplier_name': state.supplierName,
      'broker_id': state.selectedBrokerId,
      'broker_name': state.brokerName.isEmpty ? null : state.brokerName,
      'po_number': state.poNoController.text.trim().isEmpty ? null : state.poNoController.text.trim(),
      'pi_number': state.piNoController.text.trim().isEmpty ? null : state.piNoController.text.trim(),
      'invoices_data': state.invoices.map((i) => i.toJson()).toList(),
      'packing_lists_data': state.packingLists.map((p) => p.toJson()).toList(),
      'project_ids': state.selectedProjectIds,
      'project_names': selectedPjNames.isNotEmpty ? selectedPjNames : null,
      'shipment_mode': state.shipmentMode,
      'incoterm_code': state.incotermCode,
      'priority': state.priority,
      'shipment_category': state.shipmentCategory,
      'required_eta': state.requiredEta.toString().substring(0, 10),
      'file_opening_date': state.fileOpeningDate.toString().substring(0, 10),
      'selected_scenario': state.selectedScenarioController.text.trim().isEmpty ? null : state.selectedScenarioController.text.trim(),
      'pickup_address': state.pickupAddressController.text.trim().isEmpty ? null : state.pickupAddressController.text.trim(),
      'port_of_loading': state.polController.text.trim().isEmpty ? null : state.polController.text.trim(),
      'port_of_discharge': state.podController.text.trim().isEmpty ? 'El Dekheila Port (non TMT)' : state.podController.text.trim(),
      'cargo_ready_date': state.cargoReadyDate.toString().substring(0, 10),
      'target_free_days': int.tryParse(state.targetFreeDaysController.text.trim()) ?? 21,
      'service_type_preference': state.serviceTypePreference,
      'shipping_instructions_notes': state.shippingInstructionsNotesController.text.trim().isEmpty ? null : state.shippingInstructionsNotesController.text.trim(),
      'form4_no': state.form4Controller.text.trim().isEmpty ? null : state.form4Controller.text.trim(),
      'swift_no': state.swiftController.text.trim().isEmpty ? null : state.swiftController.text.trim(),
      'form46_no': state.form46Controller.text.trim().isEmpty ? null : state.form46Controller.text.trim(),
      'estimated_cost': double.tryParse(state.estimatedCostController.text.trim()) ?? 0.0,
      'estimated_cost_currency': state.estimatedCostCurrency,
      'initial_starting_step': state.initialStartingStep,
      'status': state.status,
      'owner': selectedOwner,
      'notes': state.notesController.text.trim().isEmpty ? null : state.notesController.text.trim(),
      'hs_code': state.hsCodeController.text.trim().isEmpty ? null : state.hsCodeController.text.trim(),
      'product_category': state.productCategoryController.text.trim().isEmpty ? null : state.productCategoryController.text.trim(),
    };
  }

  static Future<bool> submit({
    required BuildContext context,
    required WidgetRef ref,
    required ImportFileFormDialogState state,
  }) async {
    if (!state.formKey.currentState!.validate()) {
      state.tabController.animateTo(0);
      return false;
    }

    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final projects = ref.read(projectsProvider).valueOrNull ?? [];

    if (state.selectedCompanyId != null && companies.any((c) => c.companyId == state.selectedCompanyId)) {
      state.companyName = companies.firstWhere((c) => c.companyId == state.selectedCompanyId).importerName;
    }
    if (state.selectedSupplierId != null && suppliers.any((s) => s.supplierId == state.selectedSupplierId)) {
      state.supplierName = suppliers.firstWhere((s) => s.supplierId == state.selectedSupplierId).companyName;
    }
    if (state.selectedBrokerId != null && partners.any((p) => p.providerId == state.selectedBrokerId)) {
      state.brokerName = partners.firstWhere((p) => p.providerId == state.selectedBrokerId).partnerName;
    }

    final l = context.l10n;

    if (state.companyName.isEmpty) {
      state.tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, '❌ ${l.selectCompanyValidation}', severity: AppSeverity.danger));
      return false;
    }
    if (state.supplierName.isEmpty) {
      state.tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, '❌ ${l.selectSupplierValidation}', severity: AppSeverity.danger));
      return false;
    }

    final selectedOwner = state.ownerController.text.trim().isNotEmpty
        ? state.ownerController.text.trim()
        : (state.companyName.isNotEmpty ? state.companyName : l.owner);

    final selectedPjNames = projects
        .where((p) => state.selectedProjectIds.contains(p.projectId))
        .map((p) => p.projectName)
        .join(', ');

    try {
      final payload = buildPayload(
        state: state,
        selectedOwner: selectedOwner,
        selectedPjNames: selectedPjNames,
      );

      if (state.widget.fileToEdit == null) {
        await ref.read(importFilesProvider.notifier).createImportFile(payload);
      } else {
        final oldFile = state.widget.fileToEdit!;
        final List<FieldChangeItem> changes = [];
        void checkDiff(String name, dynamic oldVal, dynamic newVal) {
          if (FieldChangeItem.isDifferent(oldVal, newVal)) {
            changes.add(FieldChangeItem(fieldName: name, oldValue: oldVal?.toString() ?? '—', newValue: newVal?.toString() ?? '—'));
          }
        }

        checkDiff(l.importFileIdLabel, oldFile.customFileNumber, payload['custom_file_number']);
        if (FieldChangeItem.isDifferent(oldFile.companyId, payload['company_id'])) {
          final oldComp = companies.where((c) => c.companyId == oldFile.companyId).firstOrNull?.importerName ?? oldFile.companyName;
          final newComp = companies.where((c) => c.companyId == payload['company_id']).firstOrNull?.importerName ?? state.companyName;
          changes.add(FieldChangeItem(fieldName: l.importingCompany, oldValue: oldComp, newValue: newComp));
        }
        if (FieldChangeItem.isDifferent(oldFile.supplierId, payload['supplier_id'])) {
          final oldSup = suppliers.where((s) => s.supplierId == oldFile.supplierId).firstOrNull?.companyName ?? oldFile.supplierName;
          final newSup = suppliers.where((s) => s.supplierId == payload['supplier_id']).firstOrNull?.companyName ?? state.supplierName;
          changes.add(FieldChangeItem(fieldName: l.foreignSupplier, oldValue: oldSup, newValue: newSup));
        }
        checkDiff(l.responsiblePersonLabel, oldFile.owner, payload['owner']);
        checkDiff(l.purchaseOrder, oldFile.poNumber, payload['po_number']);
        checkDiff(l.proformaInvoiceNoLabel, oldFile.piNumber, payload['pi_number']);
        if (FieldChangeItem.isDifferent(oldFile.estimatedCost, payload['estimated_cost'])) {
          changes.add(FieldChangeItem(
            fieldName: l.dynColEstimatedCost,
            oldValue: '${oldFile.estimatedCost} ${oldFile.estimatedCostCurrency}',
            newValue: '${payload['estimated_cost']} ${payload['estimated_cost_currency']}',
          ));
        }
        checkDiff(l.status, oldFile.status, payload['status']);
        checkDiff(l.notesInstructions, oldFile.notes, payload['notes']);

        if (changes.isNotEmpty) {
          if (!context.mounted) return false;
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: l.importFileReviewChangesTitle,
            itemReference: oldFile.customFileNumber ?? oldFile.importFileCode,
            changes: changes,
          );
          if (!confirmed) {
            return false;
          }
        }

        await ref.read(importFilesProvider.notifier).updateImportFile(state.widget.fileToEdit!.importFileId, payload);
      }

      ref.read(paginatedImportFilesProvider.notifier).fetchPage(
        ref.read(paginatedImportFilesProvider).page,
      );
      await ref.read(importFilesProvider.notifier).fetchImportFiles();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, '✅ ${l.importFileSavedSuccess}', severity: AppSeverity.success));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, '❌ $e', severity: AppSeverity.danger));
      }
      return false;
    }
  }
}
