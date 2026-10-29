import '../../../core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../providers/customs_clearance_quotations_provider.dart';

Widget _copySuffix(BuildContext ctx, AppLocalizations l10n, TextEditingController c, {double size = 16}) =>
    IconButton(
      icon: Icon(Icons.copy_rounded, size: size),
      tooltip: l10n.copy,
      onPressed: () => CopyHelper.copy(ctx, c.text),
    );

InputDecoration _dec(String label, {Widget? suffix, Widget? prefix}) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: suffix,
      prefixIcon: prefix,
    );

/// Footer of every quotation dialog: neutral cancel + one primary action with
/// an in-button spinner (no repeat taps while saving).
List<Widget> _actions(
  BuildContext ctx,
  AppLocalizations l10n, {
  required String confirmLabel,
  required bool busy,
  required VoidCallback onConfirm,
  AppButtonVariant variant = AppButtonVariant.primary,
}) =>
    [
      AppButton(
        label: l10n.cancel,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.small,
        onPressed: busy ? null : () => Navigator.pop(ctx),
      ),
      AppButton(
        label: confirmLabel,
        variant: variant,
        size: AppButtonSize.small,
        isLoading: busy,
        onPressed: busy ? null : onConfirm,
      ),
    ];

/// Runs [action]; on failure shows the backend error (ApiErrorText) and keeps
/// the dialog open. Returns true when it succeeded.
Future<bool> _guarded(
  BuildContext ctx,
  AppLocalizations l10n,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(ctx);
  try {
    await action();
    return true;
  } catch (e) {
    if (!ctx.mounted) return false;
    messenger.showSnackBar(
      AppTheme.snackBar(
        ctx,
        '${l10n.errorPrefix}: ${ApiErrorText.of(l10n, e)}',
        severity: AppSeverity.danger,
      ),
    );
    return false;
  }
}

List<PartnerModel> _brokers(WidgetRef ref) =>
    ref.read(partnersProvider).value?.where((p) => p.partnerType == 'Customs Broker' || p.partnerType == 'Freight Forwarder').toList() ?? [];

// =============================================================================
// Create RFQ
// =============================================================================
Future<void> showCreateRfqDialog(
  BuildContext context,
  WidgetRef ref, {
  String? initialBrokerName,
  String? initialPortName,
}) async {
  final l10n = context.l10n;
  final formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController(
    text: initialBrokerName != null
        ? l10n.ccqRfqTitleForBroker(initialBrokerName)
        : l10n.clearanceQuotesDialogCreateRfqTitle,
  );
  final commodityCtrl = TextEditingController();
  final hsCodeCtrl = TextEditingController();
  final grossWeightCtrl = TextEditingController();
  final cbmCtrl = TextEditingController();
  int containersCount = 1;
  String shipmentType = 'Ocean FCL (40HQ)';
  String portName = initialPortName ?? 'Alexandria Port';
  int? selectedImportFileId;
  bool busy = false;

  final importFiles = ref.read(importFilesProvider).value ?? [];
  final locations = ref.read(transportLocationsProvider).value ?? [];

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: Row(
          children: [
            const Icon(Icons.add_task_rounded, color: AppTheme.emerald),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.clearanceQuotesDialogCreateRfqTitle)),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 600.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: _dec(
                        l10n.clearanceQuotesFieldRfqTitle,
                        prefix: const Icon(Icons.title_rounded),
                        suffix: _copySuffix(ctx, l10n, titleCtrl, size: 18),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l10n.clearanceQuotesFieldRfqTitleRequired : null,
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<int>(
                      value: selectedImportFileId,
                      labelText: l10n.clearanceQuotesFieldLinkImportFile,
                      searchHintText: l10n.searchPlaceholder,
                      items: importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName}',
                              ))
                          .toList(),
                      onChanged: (val) {
                        setDState(() {
                          selectedImportFileId = val;
                          final match = importFiles.where((f) => f.importFileId == val).firstOrNull;
                          if (match != null &&
                              match.portOfDischarge != null &&
                              match.portOfDischarge!.isNotEmpty) {
                            portName = match.portOfDischarge!;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: portName,
                      labelText: l10n.clearanceQuotesFieldClearancePort,
                      searchHintText: l10n.searchPlaceholder,
                      items: locations
                          .map((l) => SearchableDropdownItem<String>(value: l.locationName, label: l.locationName))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDState(() => portName = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: shipmentType,
                            labelText: l10n.clearanceQuotesFieldShipmentType,
                            items: const [
                              SearchableDropdownItem(value: 'Ocean FCL (40HQ)', label: 'Ocean FCL (40HQ)'),
                              SearchableDropdownItem(value: 'Ocean FCL (20GP)', label: 'Ocean FCL (20GP)'),
                              SearchableDropdownItem(value: 'Ocean LCL', label: 'Ocean LCL'),
                              SearchableDropdownItem(value: 'Air Freight', label: 'Air Freight'),
                            ],
                            onChanged: (v) {
                              if (v != null) setDState(() => shipmentType = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: containersCount.toString(),
                            decoration: _dec(l10n.clearanceQuotesFieldContainersCount),
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            onChanged: (v) => containersCount = int.tryParse(v) ?? 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: grossWeightCtrl,
                            decoration: _dec(l10n.clearanceQuotesFieldGrossWeightKg,
                                suffix: _copySuffix(ctx, l10n, grossWeightCtrl, size: 18)),
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: cbmCtrl,
                            decoration: _dec(l10n.clearanceQuotesFieldCbm,
                                suffix: _copySuffix(ctx, l10n, cbmCtrl, size: 18)),
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: _actions(
          ctx,
          l10n,
          confirmLabel: l10n.clearanceQuotesSubmitCreateRfqBtn,
          variant: AppButtonVariant.success,
          busy: busy,
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            final newRfq = CustomsClearanceRFQModel(
              rfqId: 0,
              rfqCode: '',
              title: titleCtrl.text.trim(),
              portName: portName,
              importFileId: selectedImportFileId,
              commodityDescription: commodityCtrl.text.trim().isNotEmpty ? commodityCtrl.text.trim() : null,
              hsCode: hsCodeCtrl.text.trim().isNotEmpty ? hsCodeCtrl.text.trim() : null,
              shipmentType: shipmentType,
              containersCount: containersCount,
              packagesCount: 0,
              grossWeightKg: double.tryParse(grossWeightCtrl.text) ?? 0.0,
              cbm: double.tryParse(cbmCtrl.text) ?? 0.0,
              status: 'Draft',
              lowestClearanceCost: 0.0,
              fastestTurnaroundDays: 0,
              createdAt: '',
            );
            setDState(() => busy = true);
            final ok = await _guarded(
              ctx,
              l10n,
              () => ref.read(customsClearanceQuotationsProvider.notifier).createRFQ(newRfq),
            );
            if (ctx.mounted) {
              if (ok) {
                Navigator.pop(ctx);
              } else {
                setDState(() => busy = false);
              }
            }
          },
        ),
      ),
    ),
  );
}

// =============================================================================
// Add quotation to an RFQ
// =============================================================================
Future<void> showAddQuotationDialog(
  BuildContext context,
  WidgetRef ref,
  int rfqId, {
  Map<String, dynamic>? prefill,
}) async {
  final l10n = context.l10n;
  final formKey = GlobalKey<FormState>();
  final partners = _brokers(ref);

  // FE-05: no silent default provider; a partner must be picked (validator below).
  int? selectedProviderId = prefill?['provider_id'];
  String selectedProviderName = prefill?['provider_name'] ?? '';

  final clearanceFeeCtrl = TextEditingController(text: prefill?['clearance_fee']?.toString() ?? '');
  final inlandFeeCtrl = TextEditingController(text: prefill?['inland_transport_fee']?.toString() ?? '');
  final inspectionFeeCtrl = TextEditingController(text: prefill?['inspection_fee']?.toString() ?? '');
  final portExpCtrl = TextEditingController(text: prefill?['port_expenses']?.toString() ?? '');
  final miscCtrl = TextEditingController(text: prefill?['miscellaneous_fee']?.toString() ?? '');
  final daysCtrl = TextEditingController(text: prefill?['transit_clearance_days']?.toString() ?? '');
  final remarksCtrl = TextEditingController(text: prefill?['notes']?.toString() ?? '');
  bool busy = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDState) {
        final total = (double.tryParse(clearanceFeeCtrl.text) ?? 0.0) +
            (double.tryParse(inlandFeeCtrl.text) ?? 0.0) +
            (double.tryParse(inspectionFeeCtrl.text) ?? 0.0) +
            (double.tryParse(portExpCtrl.text) ?? 0.0) +
            (double.tryParse(miscCtrl.text) ?? 0.0);

        Widget feeField(TextEditingController c, String label, {bool live = true}) => TextFormField(
              controller: c,
              decoration: _dec(label, suffix: _copySuffix(ctx, l10n, c)),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: live ? (_) => setDState(() {}) : null,
            );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppTheme.cobalt),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.clearanceQuotesDialogAddQuoteTitle)),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 580.0),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SearchableDropdownField<int>(
                        key: const Key('quotationProviderDropdown'),
                        value: selectedProviderId,
                        isRequired: true,
                        validator: (v) => v == null ? l10n.requiredField : null,
                        labelText: l10n.clearanceQuotesFieldCustomsBroker,
                        searchHintText: l10n.searchPlaceholder,
                        items: partners
                            .map((p) => SearchableDropdownItem<int>(
                                  value: p.partnerId!,
                                  label: '${p.partnerName} (${p.partnerType})',
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDState(() {
                              selectedProviderId = val;
                              final match = partners.where((p) => p.partnerId == val).firstOrNull;
                              if (match != null) selectedProviderName = match.partnerName;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: feeField(clearanceFeeCtrl, l10n.clearanceQuotesFieldClearanceFeeEgp)),
                        const SizedBox(width: 10),
                        Expanded(child: feeField(inlandFeeCtrl, l10n.clearanceQuotesFieldInlandFeeEgp)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: feeField(inspectionFeeCtrl, l10n.clearanceQuotesFieldInspectionFeeEgp)),
                        const SizedBox(width: 10),
                        Expanded(child: feeField(portExpCtrl, l10n.clearanceQuotesFieldPortExpEgp)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: feeField(miscCtrl, l10n.clearanceQuotesFieldMiscFeeEgp)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: feeField(daysCtrl, l10n.clearanceQuotesFieldEstimatedDays, live: false)),
                      ]),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => CopyHelper.copy(ctx, '${CcFormat.money(total)} ${l10n.egpCurrency}'),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Container(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.severityBackgroundOf(ctx, AppSeverity.success),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.emerald),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    const Icon(Icons.copy_rounded, size: 16, color: AppTheme.successForeground),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        l10n.clearanceQuotesTotalEstimatedQuoteLabel,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              CcMoneyText(total, fontSize: 16, color: AppTheme.successForeground),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: _actions(
            ctx,
            l10n,
            confirmLabel: l10n.clearanceQuotesSubmitSaveQuoteBtn,
            busy: busy,
            onConfirm: () async {
              if (!formKey.currentState!.validate() || selectedProviderId == null) return;
              final quote = CustomsClearanceQuotationItemModel(
                providerId: selectedProviderId!,
                providerName: selectedProviderName,
                clearanceFee: double.tryParse(clearanceFeeCtrl.text) ?? 0.0,
                inlandTransportFee: double.tryParse(inlandFeeCtrl.text) ?? 0.0,
                inspectionFee: double.tryParse(inspectionFeeCtrl.text) ?? 0.0,
                portExpenses: double.tryParse(portExpCtrl.text) ?? 0.0,
                miscellaneousFee: double.tryParse(miscCtrl.text) ?? 0.0,
                totalCost: total,
                estimatedTurnaroundDays: int.tryParse(daysCtrl.text) ?? 0,
                remarks: remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
              );
              setDState(() => busy = true);
              final ok = await _guarded(
                ctx,
                l10n,
                () => ref.read(customsClearanceQuotationsProvider.notifier).addQuotation(rfqId, quote),
              );
              if (ctx.mounted) {
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  setDState(() => busy = false);
                }
              }
            },
          ),
        );
      },
    ),
  );
}

// =============================================================================
// Add price-list item
// =============================================================================
Future<void> showAddPriceItemDialog(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final formKey = GlobalKey<FormState>();
  final partners = _brokers(ref);
  final locations = ref.read(transportLocationsProvider).value ?? [];

  int? selectedProviderId; // FE-05: no silent default provider
  String selectedProviderName = '';
  String portName = locations.isNotEmpty ? locations.first.locationName : 'Alexandria Port';
  String category = 'CLEARANCE_FEE'; // DomainEnumType.clearanceServiceCategory code
  String containerType = '40HQ';
  final priceCtrl = TextEditingController(text: '3500');
  final notesCtrl = TextEditingController();
  bool busy = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: Row(
          children: [
            const Icon(Icons.price_change_rounded, color: AppTheme.emerald),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.clearanceQuotesDialogAddPriceItemTitle)),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: (MediaQuery.of(ctx).size.width - 48).clamp(320.0, 500.0),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableDropdownField<int>(
                      key: const Key('priceItemProviderDropdown'),
                      value: selectedProviderId,
                      isRequired: true,
                      validator: (v) => v == null ? l10n.requiredField : null,
                      labelText: l10n.clearanceQuotesFieldCustomsBroker,
                      searchHintText: l10n.searchPlaceholder,
                      items: partners
                          .map((p) => SearchableDropdownItem<int>(value: p.partnerId!, label: p.partnerName))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDState(() {
                            selectedProviderId = val;
                            final m = partners.where((p) => p.partnerId == val).firstOrNull;
                            if (m != null) selectedProviderName = m.partnerName;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: portName,
                      labelText: l10n.clearanceQuotesFieldClearancePort,
                      searchHintText: l10n.searchPlaceholder,
                      items: locations
                          .map((l) => SearchableDropdownItem<String>(value: l.locationName, label: l.locationName))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDState(() => portName = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l10n.clearanceQuotesFieldServiceCategory,
                      items: [
                        for (final code in DomainEnums.codesOf(DomainEnumType.clearanceServiceCategory))
                          SearchableDropdownItem(
                            value: code,
                            label: DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, code),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: containerType,
                            labelText: l10n.clearanceQuotesColPriceContainerType,
                            items: const [
                              SearchableDropdownItem(value: '40HQ', label: '40HQ'),
                              SearchableDropdownItem(value: '40GP', label: '40GP'),
                              SearchableDropdownItem(value: '20GP', label: '20GP'),
                              SearchableDropdownItem(value: 'LCL', label: 'LCL'),
                              SearchableDropdownItem(value: 'Air', label: 'Air'),
                            ],
                            onChanged: (val) {
                              if (val != null) setDState(() => containerType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            decoration: _dec(l10n.clearanceQuotesFieldStandardPriceEgp,
                                suffix: _copySuffix(ctx, l10n, priceCtrl)),
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? l10n.clearanceQuotesFieldStandardPriceRequired
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: _actions(
          ctx,
          l10n,
          confirmLabel: l10n.clearanceQuotesSubmitSavePriceItemBtn,
          variant: AppButtonVariant.success,
          busy: busy,
          onConfirm: () async {
            if (!formKey.currentState!.validate() || selectedProviderId == null) return;
            final newItem = ClearancePriceListItemModel(
              priceItemId: 0,
              providerId: selectedProviderId!,
              providerName: selectedProviderName,
              portName: portName,
              serviceCategory: category,
              containerType: containerType,
              unitPrice: double.tryParse(priceCtrl.text) ?? 0.0,
              currency: 'EGP',
              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
            );
            setDState(() => busy = true);
            final ok = await _guarded(
              ctx,
              l10n,
              () => ref.read(clearancePriceListProvider.notifier).createPriceItem(newItem),
            );
            if (ctx.mounted) {
              if (ok) {
                Navigator.pop(ctx);
              } else {
                setDState(() => busy = false);
              }
            }
          },
        ),
      ),
    ),
  );
}

// =============================================================================
// Confirmations
// =============================================================================

/// Confirms and awards a quotation; shows the success / backend-error snackbar.
Future<void> confirmAwardQuotation(BuildContext context, WidgetRef ref, int rfqId, int quotationId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final confirm = await AppConfirmDialog.show(
    context,
    title: l10n.clearanceQuotesConfirmAwardTitle,
    message: l10n.clearanceQuotesConfirmAwardContent,
    confirmLabel: l10n.clearanceQuotesConfirmAwardBtn,
    cancelLabel: l10n.cancel,
    confirmVariant: AppButtonVariant.success,
    icon: Icons.verified_rounded,
  );

  if (confirm != true) return;
  try {
    await ref.read(customsClearanceQuotationsProvider.notifier).awardQuotation(rfqId, quotationId);
    if (!context.mounted) return;
    messenger.showSnackBar(
      AppTheme.snackBar(
        context,
        l10n.clearanceQuotesAwardSuccessSnackbar,
        severity: AppSeverity.success,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      AppTheme.snackBar(
        context,
        '${l10n.errorPrefix}: ${ApiErrorText.of(l10n, e)}',
        severity: AppSeverity.danger,
      ),
    );
  }
}

/// Confirms and deletes a quotation (backend errors are shown, not swallowed).
Future<void> confirmDeleteQuotation(BuildContext context, WidgetRef ref, int quotationId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final confirm = await AppConfirmDialog.showDelete(
    context,
    title: l10n.clearanceQuotesConfirmDeleteQuoteTitle,
    message: l10n.clearanceQuotesConfirmDeleteQuoteContent,
  );

  if (confirm != true) return;
  try {
    await ref.read(customsClearanceQuotationsProvider.notifier).deleteQuotation(quotationId);
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      AppTheme.snackBar(
        context,
        '${l10n.errorPrefix}: ${ApiErrorText.of(l10n, e)}',
        severity: AppSeverity.danger,
      ),
    );
  }
}
