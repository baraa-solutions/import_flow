import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import 'consultation_calc_cif_box.dart';
import 'consultation_calc_freight_section.dart';
import 'consultation_calc_insurance_section.dart';
import 'consultation_calc_shipment_badges.dart';
import 'consultation_calc_valuation_params.dart';

/// Card for Shipment Overview, Incoterms, Ports, Currency Picker, and Valuation Reference Values.
class ConsultationCalcHeaderCard extends StatelessWidget {
  final bool isTaxReviewMode;
  final TextEditingController titleController;
  final int? selectedBrokerId;
  final ValueChanged<PartnerModel?> onBrokerChanged;
  final List<PartnerModel> brokersList;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final List<ImportFileModel> importFiles;
  final List<PurchaseOrderModel> allPOs;
  final List<CurrencyModel> currenciesList;
  final String customsCurrency;
  final ValueChanged<String> onCustomsCurrencyChanged;
  final TextEditingController exchangeRateController;
  final VoidCallback onExchangeRateChanged;
  final DateTime studyDate;
  final ValueChanged<DateTime> onStudyDateChanged;

  // Ocean / Air Freight
  final TextEditingController freightForeignController;
  final String freightCurrency;
  final ValueChanged<String> onFreightCurrencyChanged;
  final TextEditingController freightExchangeRateController;
  final TextEditingController freightEgpController;
  final VoidCallback onRecalculateFreightEgp;
  final VoidCallback? onAutoFetchFreightFromScenarios;

  // Marine Insurance
  final String insuranceOption;
  final ValueChanged<String> onInsuranceOptionChanged;
  final TextEditingController insuranceEgpController;

  // CIF Totals
  final double totalFobForeign;
  final double totalCandFEgp;
  final double totalFreightEgp;
  final double totalInsuranceEgp;
  final double totalCifEgp;
  final double totalCifForeign;
  final double? exchangeRate;
  final String? editingConsultationCode;
  final bool isCustomsCalculatorExpanded;
  final VoidCallback onToggleExpanded;

  const ConsultationCalcHeaderCard({
    super.key,
    required this.isTaxReviewMode,
    required this.titleController,
    required this.selectedBrokerId,
    required this.onBrokerChanged,
    required this.brokersList,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.importFiles,
    required this.allPOs,
    required this.currenciesList,
    required this.customsCurrency,
    required this.onCustomsCurrencyChanged,
    required this.exchangeRateController,
    required this.onExchangeRateChanged,
    required this.studyDate,
    required this.onStudyDateChanged,
    required this.freightForeignController,
    required this.freightCurrency,
    required this.onFreightCurrencyChanged,
    required this.freightExchangeRateController,
    required this.freightEgpController,
    required this.onRecalculateFreightEgp,
    this.onAutoFetchFreightFromScenarios,
    required this.insuranceOption,
    required this.onInsuranceOptionChanged,
    required this.insuranceEgpController,
    required this.totalFobForeign,
    required this.totalCandFEgp,
    required this.totalFreightEgp,
    required this.totalInsuranceEgp,
    required this.totalCifEgp,
    required this.totalCifForeign,
    required this.exchangeRate,
    this.editingConsultationCode,
    required this.isCustomsCalculatorExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selFile = selectedImportFileId != null
        ? importFiles
            .where((f) => f.importFileId == selectedImportFileId)
            .firstOrNull
        : null;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title & expand toggle
              Row(
                children: [
                  const Icon(Icons.hub_outlined,
                      color: AppTheme.cobalt, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTaxReviewMode
                              ? l.taxReviewWorkspaceTab
                              : l.customsWorkspaceTab,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          l.customsCalculationEngineSub,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (editingConsultationCode != null)
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                  IconButton(
                    icon: Icon(
                      isCustomsCalculatorExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal,
                    ),
                    tooltip: l.view,
                    onPressed: onToggleExpanded,
                  ),
                ],
              ),
              const Divider(height: 20),

              // Title and Customs Broker Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  final titleField = TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: '${l.titleField} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.requiredField
                        : null,
                  );

                  final brokerField = !isTaxReviewMode
                      ? SearchableDropdownField<int?>(
                          value: selectedBrokerId,
                          labelText: '${l.customsBrokerLabel} *',
                          searchHintText:
                              '${l.search} ${l.customsBrokerLabel}...',
                          items: brokersList
                              .map((b) => SearchableDropdownItem<int?>(
                                    value: b.providerId,
                                    label: b.partnerName,
                                    subtitle: b.contactPerson,
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final b = brokersList
                                  .where(
                                      (element) => element.providerId == val)
                                  .firstOrNull;
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

              // Import File Selection
              SearchableDropdownField<int?>(
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
                        subtitle:
                            '${f.companyName} | ${l.customsBrokerLabel}: ${f.brokerName ?? ""} | ${f.invoicesData.length} Invoices',
                      )),
                ],
                onChanged: onImportFileChanged,
              ),

              // Shipment Overview Badges (Incoterms, Ports)
              if (selFile != null) ...[
                const SizedBox(height: 10),
                ConsultationCalcShipmentBadges(file: selFile),
              ],

              if (isCustomsCalculatorExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Currency, FX Rate, Study Date
                ConsultationCalcValuationParams(
                  currenciesList: currenciesList,
                  customsCurrency: customsCurrency,
                  onCustomsCurrencyChanged: onCustomsCurrencyChanged,
                  exchangeRateController: exchangeRateController,
                  onExchangeRateChanged: onExchangeRateChanged,
                  studyDate: studyDate,
                  onStudyDateChanged: onStudyDateChanged,
                ),
                const SizedBox(height: 12),

                // Delegated Freight Valuation Section
                ConsultationCalcFreightSection(
                  freightForeignController: freightForeignController,
                  freightCurrency: freightCurrency,
                  onFreightCurrencyChanged: onFreightCurrencyChanged,
                  freightExchangeRateController: freightExchangeRateController,
                  freightEgpController: freightEgpController,
                  onRecalculateFreightEgp: onRecalculateFreightEgp,
                  selectedImportFileId: selectedImportFileId,
                  onAutoFetchFreightFromScenarios:
                      onAutoFetchFreightFromScenarios,
                  currenciesList: currenciesList,
                ),
                const SizedBox(height: 12),

                // Delegated Marine Insurance Valuation Section
                ConsultationCalcInsuranceSection(
                  insuranceOption: insuranceOption,
                  onInsuranceOptionChanged: onInsuranceOptionChanged,
                  insuranceEgpController: insuranceEgpController,
                ),
                const SizedBox(height: 14),

                // Delegated Declared CIF Base Box
                ConsultationCalcCifBox(
                  totalFobForeign: totalFobForeign,
                  customsCurrency: customsCurrency,
                  totalFreightEgp: totalFreightEgp,
                  totalCandFEgp: totalCandFEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  totalCifEgp: totalCifEgp,
                  totalCifForeign: totalCifForeign,
                  exchangeRate: exchangeRate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
