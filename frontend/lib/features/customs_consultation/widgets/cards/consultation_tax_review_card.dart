import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../../external_service_providers/providers/partners_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';

/// Card for Session Setup, Linked Import File / POs, and Tax Base Review.
class ConsultationTaxReviewCard extends ConsumerWidget {
  final bool isTaxReviewMode;
  final TextEditingController titleController;
  final int? selectedBrokerId;
  final ValueChanged<PartnerModel?> onBrokerChanged;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final TextEditingController estimatedDutiesController;
  final String? editingConsultationCode;
  final String customsCurrency;

  const ConsultationTaxReviewCard({
    super.key,
    required this.isTaxReviewMode,
    required this.titleController,
    required this.selectedBrokerId,
    required this.onBrokerChanged,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.estimatedDutiesController,
    required this.customsCurrency,
    this.editingConsultationCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = l.financialSettlementCurrencyEgp;

    final partnersState = ref.watch(partnersProvider);
    final partnersList = partnersState.valueOrNull ?? [];
    final brokersList = partnersList
        .where((p) => p.partnerType.contains('Customs') || p.partnerType.contains('Broker'))
        .toList();

    final List<CurrencyModel> currenciesList = ref.watch(currenciesProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    isTaxReviewMode
                        ? l.taxReviewWorkspaceTab
                        : l.customsWorkspaceTab,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  if (editingConsultationCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${l.statusCol}: $editingConsultationCode',
                        style: const TextStyle(
                          color: AppTheme.wcagOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  final titleField = TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: '${l.titleField} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.requiredField : null,
                  );
                  final brokerField = !isTaxReviewMode
                      ? SearchableDropdownField<int?>(
                          value: selectedBrokerId,
                          labelText: '${l.customsBrokerLabel} *',
                          searchHintText: '${l.search} ${l.customsBrokerLabel}...',
                          items: brokersList
                              .map((b) => SearchableDropdownItem<int?>(
                                    value: b.providerId,
                                    label: b.partnerName,
                                    subtitle: b.contactPerson,
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final b = brokersList.where((element) => element.providerId == val).firstOrNull;
                              onBrokerChanged(b);
                            } else {
                              onBrokerChanged(null);
                            }
                          },
                          validator: (v) => v == null ? l.requiredField : null,
                        )
                      : null;

                  if (isNarrow) {
                    return Column(
                      children: [
                        titleField,
                        if (brokerField != null) ...[
                          const SizedBox(height: 12),
                          brokerField,
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: titleField),
                      if (brokerField != null) ...[
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: brokerField),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  final importFileField = SearchableDropdownField<int?>(
                    value: selectedImportFileId,
                    labelText: l.linkImportFile,
                    searchHintText: '${l.search} ${l.linkImportFile}...',
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: '-- ${l.allFiles} --',
                      ),
                      ...importFiles.map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName}',
                            subtitle: '${f.companyName} | ${l.customsBrokerLabel}: ${f.brokerName ?? ""} | ${f.invoicesData.length} Invoices',
                          )),
                    ],
                    onChanged: onImportFileChanged,
                  );
                  final dutiesField = TextFormField(
                    controller: estimatedDutiesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${l.totalTaxesAndDutiesCol} ($egpLabel)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calculate, color: AppTheme.cobalt),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: l.copyTooltip,
                        onPressed: () {
                          if (estimatedDutiesController.text.isNotEmpty) {
                            CopyHelper.copy(context, estimatedDutiesController.text);
                          }
                        },
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        importFileField,
                        const SizedBox(height: 12),
                        dutiesField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: importFileField),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: dutiesField),
                    ],
                  );
                },
              ),
              if (selectedImportFileId != null) ...[
                Builder(builder: (context) {
                  final selFile = importFiles
                      .where((f) => f.importFileId == selectedImportFileId)
                      .firstOrNull;
                  if (selFile == null) return const SizedBox.shrink();

                  final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
                  final matchingPOs = allPOs.where((p) =>
                      (p.importFileId != null && p.importFileId == selFile.importFileId) ||
                      (selFile.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == selFile.importFileCode) ||
                      (selFile.poIds != null && p.poId != null && selFile.poIds!.contains(p.poId))).toList();

                  // Group PO totals by currency
                  final Map<String, double> poTotalsByCur = {};
                  for (final po in matchingPOs) {
                    final cur = po.currencyCode?.isNotEmpty == true
                        ? po.currencyCode!
                        : (currenciesList.where((c) => c.currencyId == po.currencyId).firstOrNull?.currencyCode ?? customsCurrency);
                    poTotalsByCur[cur] = (poTotalsByCur[cur] ?? 0.0) + po.totalAmountFob;
                  }
                  final poSummaryText = poTotalsByCur.entries
                      .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
                      .join(' + ');

                  // Group Invoices totals by currency
                  final invCount = selFile.invoicesData.length;
                  final Map<String, double> invTotalsByCur = {};
                  for (final inv in selFile.invoicesData) {
                    final cur = inv.currency.isNotEmpty ? inv.currency : customsCurrency;
                    invTotalsByCur[cur] = (invTotalsByCur[cur] ?? 0.0) + inv.amount;
                  }
                  final invSummaryText = invTotalsByCur.entries
                      .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
                      .join(' + ');

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // 1. Purchase Orders Summary
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_cart, size: 16, color: AppTheme.emerald),
                                const SizedBox(width: 6),
                                Text(
                                  l.linkedPurchaseOrdersSummary(
                                    matchingPOs.length,
                                    poSummaryText.isNotEmpty ? " — ($poSummaryText)" : "",
                                  ),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                ),
                              ],
                            ),
                            // 2. Invoices Summary
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long, size: 16, color: AppTheme.cobalt),
                                const SizedBox(width: 6),
                                Text(
                                  l.approvedInvoicesSummary(
                                    invCount,
                                    invSummaryText.isNotEmpty
                                        ? " — ($invSummaryText)"
                                        : (invCount > 0 ? " — (${invTotalsByCur.values.fold(0.0, (s, a) => s + a).toStringAsFixed(2)} $customsCurrency)" : ""),
                                  ),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                ),
                              ],
                            ),
                            if (selFile.projectNames != null && selFile.projectNames!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.business, size: 16, color: AppTheme.charcoal),
                                  const SizedBox(width: 6),
                                  CopyableText(l.projectNamedSummary(selFile.projectNames!), style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
                                ],
                              ),
                          ],
                        ),
                        if (matchingPOs.length > 1) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: matchingPOs.map((po) {
                              final cur = po.currencyCode ?? customsCurrency;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.cloudWhite),
                                ),
                                child: Text(
                                  '${po.displayName} (${po.poNumber}): ${po.totalAmountFob.toStringAsFixed(2)} $cur',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
