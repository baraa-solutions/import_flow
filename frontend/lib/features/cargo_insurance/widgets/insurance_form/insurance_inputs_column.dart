import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import 'insurance_form_controllers.dart';

class InsuranceInputsColumn extends StatelessWidget {
  final InsuranceFormControllers controllers;
  final int? selectedImportFileId;
  final List<ImportFileModel> importFiles;
  final ValueChanged<ImportFileModel?> onImportFileSelected;
  final VoidCallback onLiveCalc;
  final VoidCallback onStateChanged;

  const InsuranceInputsColumn({
    super.key,
    required this.controllers,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onImportFileSelected,
    required this.onLiveCalc,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Linked Import File
        SearchableDropdownField<int>(
          value: selectedImportFileId,
          labelText: l.insuranceFieldLinkImportFile,
          hintText: l.insuranceFieldLinkImportFileHint,
          items: importFiles
              .map((f) => SearchableDropdownItem(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.companyName} (${f.incotermCode} - ${f.shipmentMode})',
                  ))
              .toList(),
          onChanged: (val) {
            final selected = importFiles.firstWhere((f) => f.importFileId == val);
            onImportFileSelected(selected);
          },
        ),
        const SizedBox(height: 12),

        // 2. Insured Entity & Policy Type
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: controllers.insuredEntityCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInsuredEntity,
                  prefixIcon: const Icon(Icons.person_pin_rounded, size: 18),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.insuranceFieldInsuredEntityRequired : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: controllers.policyType,
                labelText: l.insuranceFieldPolicyType,
                hintText: l.insuranceFieldPolicyTypeHint,
                items: [
                  SearchableDropdownItem(
                    value: 'SPECIFIC',
                    label: l.insurancePolicyTypeSpecific,
                  ),
                  SearchableDropdownItem(
                    value: 'OPEN_DECLARATION',
                    label: l.insurancePolicyTypeOpen,
                  ),
                ],
                onChanged: (v) {
                  controllers.policyType = v ?? 'SPECIFIC';
                  onStateChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3. Insurance Provider & Policy Number
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.insuranceCompanyCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInsuranceCompany,
                  prefixIcon: const Icon(Icons.assured_workload_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: controllers.policyNoCtrl,
                decoration: InputDecoration(
                  labelText: l.insuranceFieldPolicyNumber,
                  prefixIcon: const Icon(Icons.confirmation_number_rounded, size: 18),
                  hintText: 'POL-2026-XXXX',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. Voyage & Transport Details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.insuranceSecVoyageDetails,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField<String>(
                      value: controllers.transportMode,
                      labelText: l.insuranceFieldTransportMode,
                      hintText: l.insuranceFieldTransportModeHint,
                      items: [
                        SearchableDropdownItem(
                          value: 'OCEAN',
                          label: l.insuranceTransportModeOcean,
                        ),
                        SearchableDropdownItem(
                          value: 'AIR',
                          label: l.insuranceTransportModeAir,
                        ),
                        SearchableDropdownItem(
                          value: 'ROAD',
                          label: l.insuranceTransportModeRoad,
                        ),
                      ],
                      onChanged: (v) {
                        controllers.transportMode = v ?? 'OCEAN';
                        if (controllers.transportMode == 'AIR') controllers.coverageClause = 'AIR_ALL_RISKS';
                        if (controllers.transportMode == 'OCEAN' && controllers.coverageClause == 'AIR_ALL_RISKS') {
                          controllers.coverageClause = 'ICC_A';
                        }
                        onStateChanged();
                        onLiveCalc();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controllers.carrierCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldCarrier,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controllers.vesselFlightCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldVesselFlight,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controllers.polCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldPol,
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.required : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controllers.podCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldPod,
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? l.required : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controllers.trackingRefCtrl,
                      decoration: InputDecoration(
                        labelText: l.insuranceFieldBlTracking,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Financial Inputs (Invoice + Freight + Currency)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: controllers.invoiceValueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.insuranceFieldInvoiceValue,
                  prefixIcon: const Icon(Icons.receipt_rounded, size: 18),
                ),
                onChanged: (_) => onLiveCalc(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: controllers.freightCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.insuranceFieldFreightCost,
                  prefixIcon: const Icon(Icons.directions_boat_rounded, size: 18),
                ),
                onChanged: (_) => onLiveCalc(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SearchableDropdownField<String>(
                value: controllers.currency,
                labelText: l.insuranceFieldCurrency,
                hintText: l.insuranceFieldCurrencyHint,
                items: [
                  SearchableDropdownItem(value: 'USD', label: l.insuranceCurrUsd),
                  SearchableDropdownItem(value: 'EUR', label: l.insuranceCurrEur),
                  SearchableDropdownItem(value: 'EGP', label: l.insuranceCurrEgp),
                  SearchableDropdownItem(value: 'CNY', label: l.insuranceCurrCny),
                  SearchableDropdownItem(value: 'GBP', label: l.insuranceCurrGbp),
                ],
                onChanged: (v) {
                  controllers.currency = v ?? 'USD';
                  onStateChanged();
                  onLiveCalc();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 6. Coverage Clauses & War/Strikes Toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.1).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.insuranceSecCoverageClauses,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
              ),
              const SizedBox(height: 8),
              SearchableDropdownField<String>(
                value: controllers.coverageClause,
                labelText: l.insuranceFieldCoverageClause,
                hintText: l.insuranceFieldCoverageClauseHint,
                items: [
                  SearchableDropdownItem(
                    value: 'ICC_A',
                    label: l.insuranceClauseIccA,
                  ),
                  SearchableDropdownItem(
                    value: 'AIR_ALL_RISKS',
                    label: l.insuranceClauseAirAllRisks,
                  ),
                  SearchableDropdownItem(
                    value: 'ICC_B',
                    label: l.insuranceClauseIccB,
                  ),
                  SearchableDropdownItem(
                    value: 'ICC_C',
                    label: l.insuranceClauseIccC,
                  ),
                ],
                onChanged: (v) {
                  controllers.coverageClause = v ?? 'ICC_A';
                  onStateChanged();
                  onLiveCalc();
                },
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  controllers.includeWarAndStrikes = !controllers.includeWarAndStrikes;
                  onStateChanged();
                  onLiveCalc();
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: controllers.includeWarAndStrikes,
                      activeColor: AppTheme.emerald,
                      onChanged: (v) {
                        controllers.includeWarAndStrikes = v ?? true;
                        onStateChanged();
                        onLiveCalc();
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.insuranceWarAndStrikesTitle,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l.insuranceWarAndStrikesSubtitle,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
