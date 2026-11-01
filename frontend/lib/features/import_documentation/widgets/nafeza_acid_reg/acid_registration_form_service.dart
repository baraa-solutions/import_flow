import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../experience_guide/models/guide_entry_model.dart';
import '../../../experience_guide/providers/experience_guide_provider.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';

class AcidPopulatedState {
  final int? selectedImporterId;
  final int? selectedSupplierId;
  final String exporterRegType;
  final int? selectedBrokerId;
  final int? selectedPoId;
  final int? editingAcidSessionId;
  final String? editingAcidCode;

  const AcidPopulatedState({
    required this.selectedImporterId,
    required this.selectedSupplierId,
    required this.exporterRegType,
    required this.selectedBrokerId,
    required this.selectedPoId,
    required this.editingAcidSessionId,
    required this.editingAcidCode,
  });
}

class AcidRegistrationFormService {
  static void applyClonedSession({
    required AcidRegistrationModel session,
    required TextEditingController acidNumberCtrl,
    required TextEditingController importerNameCtrl,
    required TextEditingController importerTaxIdCtrl,
    required TextEditingController importerAddressCtrl,
    required TextEditingController exporterNameCtrl,
    required TextEditingController exporterCountryCtrl,
    required TextEditingController exporterCountryCodeCtrl,
    required TextEditingController exporterAddressCtrl,
    required TextEditingController exporterPhoneCtrl,
    required TextEditingController cargoxIdCtrl,
    required TextEditingController exporterRegIdCtrl,
    required TextEditingController poNoCtrl,
    required TextEditingController proformaNoCtrl,
    required TextEditingController proformaDateCtrl,
    required TextEditingController polCtrl,
    required TextEditingController podCtrl,
    required TextEditingController brokerNameCtrl,
    required TextEditingController brokerPhoneCtrl,
    required TextEditingController requestedDateCtrl,
  }) {
    acidNumberCtrl.text = 'ACID-EG-2026-';
    importerNameCtrl.text = session.importerName;
    importerTaxIdCtrl.text = session.importerTaxId;
    importerAddressCtrl.text = session.importerAddress ?? '';
    exporterNameCtrl.text = session.exporterName;
    exporterCountryCtrl.text = session.exporterCountry;
    exporterCountryCodeCtrl.text = session.exporterCountryCode ?? '';
    exporterAddressCtrl.text = session.exporterAddress ?? '';
    exporterPhoneCtrl.text = session.exporterPhone ?? '';
    cargoxIdCtrl.text = session.cargoxId ?? '';
    exporterRegIdCtrl.text = session.exporterRegId;
    poNoCtrl.text = session.poNumber ?? '';
    proformaNoCtrl.text = '${session.proformaInvoiceNo}${TableRowCloneHelper.copySuffix}';
    proformaDateCtrl.text = session.proformaInvoiceDate ?? DateTime.now().toString().substring(0, 10);
    polCtrl.text = session.polName;
    podCtrl.text = session.podName;
    brokerNameCtrl.text = session.customsBrokerName ?? '';
    brokerPhoneCtrl.text = session.customsBrokerPhone ?? '';
    requestedDateCtrl.text = DateTime.now().toString().substring(0, 10);
  }

  static AcidPopulatedState populateFromImportFile({
    required int fileId,
    required WidgetRef ref,
    required TextEditingController acidNumberCtrl,
    required TextEditingController importerNameCtrl,
    required TextEditingController importerTaxIdCtrl,
    required TextEditingController importerAddressCtrl,
    required TextEditingController exporterNameCtrl,
    required TextEditingController exporterCountryCtrl,
    required TextEditingController exporterCountryCodeCtrl,
    required TextEditingController exporterAddressCtrl,
    required TextEditingController exporterPhoneCtrl,
    required TextEditingController cargoxIdCtrl,
    required TextEditingController exporterRegIdCtrl,
    required TextEditingController poNoCtrl,
    required TextEditingController poDateCtrl,
    required TextEditingController proformaNoCtrl,
    required TextEditingController polCtrl,
    required TextEditingController podCtrl,
    required TextEditingController brokerNameCtrl,
    required TextEditingController brokerPhoneCtrl,
  }) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) {
      return const AcidPopulatedState(
        selectedImporterId: null,
        selectedSupplierId: null,
        exporterRegType: 'VAT Number',
        selectedBrokerId: null,
        selectedPoId: null,
        editingAcidSessionId: null,
        editingAcidCode: null,
      );
    }

    int? editingAcidSessionId;
    String? editingAcidCode;
    final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    final existingSession = sessions.where((s) => s.importFileId == fileId && s.isActive).firstOrNull;
    if (existingSession != null) {
      editingAcidSessionId = existingSession.acidId;
      editingAcidCode = existingSession.acidCode;
      if (existingSession.acidNumber.isNotEmpty && existingSession.acidNumber != 'PENDING') {
        acidNumberCtrl.text = existingSession.acidNumber;
      }
    }

    int? selectedImporterId;
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final matchedComp = companies.where((c) => c.companyId == file.companyId).firstOrNull;
    if (matchedComp != null) {
      selectedImporterId = matchedComp.companyId;
      importerNameCtrl.text = matchedComp.importerName;
      importerTaxIdCtrl.text = matchedComp.vatId;
      importerAddressCtrl.text = matchedComp.address;
    } else {
      importerNameCtrl.text = file.companyName;
    }

    int? selectedSupplierId;
    String exporterRegType = 'Company Registration Number';
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final matchedSupp = suppliers.where((s) => s.supplierId == file.supplierId).firstOrNull;
    if (matchedSupp != null) {
      selectedSupplierId = matchedSupp.supplierId;
      exporterNameCtrl.text = matchedSupp.companyName;
      exporterCountryCtrl.text = matchedSupp.foreignExporterCountry;
      exporterCountryCodeCtrl.text = matchedSupp.foreignExporterCountryCode;
      exporterAddressCtrl.text = matchedSupp.address;
      exporterPhoneCtrl.text = matchedSupp.phone ?? '';
      cargoxIdCtrl.text = matchedSupp.cargoxPlatformId ?? '';
      exporterRegIdCtrl.text = matchedSupp.foreignExporterId;
      exporterRegType = matchedSupp.registrationType.isNotEmpty ? matchedSupp.registrationType : 'Company Registration Number';
    } else {
      exporterNameCtrl.text = file.supplierName;
    }

    int? selectedBrokerId;
    final partners = ref.read(partnersProvider).valueOrNull ?? [];
    final matchedBroker = partners.where((p) => p.providerId == file.brokerId).firstOrNull;
    if (matchedBroker != null) {
      selectedBrokerId = matchedBroker.providerId;
      brokerNameCtrl.text = matchedBroker.partnerName;
      brokerPhoneCtrl.text = matchedBroker.phone ?? '';
    }

    int? selectedPoId;
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final matchedPo = pos.where((p) => p.importFileId == fileId).firstOrNull;
    if (matchedPo != null) {
      selectedPoId = matchedPo.poId;
      poDateCtrl.text = matchedPo.orderDate != null ? matchedPo.orderDate!.toIso8601String().substring(0, 10) : '';
    } else {
      poDateCtrl.text = '';
    }

    if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      poNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null) {
      poNoCtrl.text = (matchedPo.poReference != null && matchedPo.poReference!.trim().isNotEmpty)
          ? matchedPo.poReference!.trim()
          : matchedPo.poNumber;
    } else {
      poNoCtrl.text = '';
    }

    if (file.piNumber != null && file.piNumber!.trim().isNotEmpty) {
      proformaNoCtrl.text = file.piNumber!.trim();
    } else if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
      proformaNoCtrl.text = file.poNumber!.trim();
    } else if (matchedPo != null && matchedPo.proformaInvoiceNumber != null && matchedPo.proformaInvoiceNumber!.isNotEmpty) {
      proformaNoCtrl.text = matchedPo.proformaInvoiceNumber!;
    } else {
      proformaNoCtrl.text = '';
    }

    if (polCtrl.text.isEmpty || polCtrl.text == 'Shanghai Port (CNSHA)') {
      polCtrl.text = 'CHANGSHU';
    }
    if (podCtrl.text.isEmpty || podCtrl.text == 'Alexandria Port (EG ALX)') {
      podCtrl.text = 'Alexandria';
    }

    return AcidPopulatedState(
      selectedImporterId: selectedImporterId,
      selectedSupplierId: selectedSupplierId,
      exporterRegType: exporterRegType,
      selectedBrokerId: selectedBrokerId,
      selectedPoId: selectedPoId,
      editingAcidSessionId: editingAcidSessionId,
      editingAcidCode: editingAcidCode,
    );
  }

  static Future<GuideMatchResultModel?> loadAcidGuide({
    required int fileId,
    required WidgetRef ref,
  }) async {
    try {
      final files = ref.read(importFilesProvider).valueOrNull ?? [];
      final file = files.where((f) => f.importFileId == fileId).firstOrNull;
      if (file == null) return null;

      return await ref.read(experienceGuideProvider.notifier).matchImportFile(file);
    } catch (_) {
      return null;
    }
  }

  static Future<int?> submitAcidRequest({
    required BuildContext context,
    required WidgetRef ref,
    required int selectedImportFileId,
    required int? editingAcidSessionId,
    required String? editingAcidCode,
    required Map<String, dynamic> payload,
    required void Function(int sessionId, String acidCode)? onSaved,
  }) async {
    final l = context.l10n;
    try {
      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == selectedImportFileId && s.isActive).firstOrNull;
      final targetAcidId = editingAcidSessionId ?? existing?.acidId;

      if (targetAcidId != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(targetAcidId, payload);
        if (context.mounted) {
          final acidCode = existing?.acidCode ?? editingAcidCode ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.acidRequestUpdatedSuccess(acidCode), severity: AppSeverity.success),
          );
          onSaved?.call(targetAcidId, acidCode);
        }
        return targetAcidId;
      } else {
        final created = await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.acidRequestSavedSuccess, severity: AppSeverity.success),
          );
          if (created != null) {
            onSaved?.call(created.acidId, created.acidCode);
            return created.acidId;
          }
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        showErrorDetailsDialog(context, title: l.errorSavingAcid, error: e);
      }
      return null;
    }
  }
}
