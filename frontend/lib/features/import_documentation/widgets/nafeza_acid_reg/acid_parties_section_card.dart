import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

class AcidPartiesSectionCard extends StatelessWidget {
  final List<dynamic> importCompanies;
  final List<dynamic> suppliers;
  final int? selectedImporterId;
  final TextEditingController importerTaxIdCtrl;
  final TextEditingController importerAddressCtrl;
  final ValueChanged<int?> onImporterChanged;
  final int? selectedSupplierId;
  final TextEditingController exporterRegIdCtrl;
  final String exporterRegType;
  final TextEditingController exporterCountryCtrl;
  final TextEditingController cargoxIdCtrl;
  final ValueChanged<int?> onSupplierChanged;
  final ValueChanged<String?> onRegTypeChanged;
  final bool isMobile;

  const AcidPartiesSectionCard({
    super.key,
    required this.importCompanies,
    required this.suppliers,
    required this.selectedImporterId,
    required this.importerTaxIdCtrl,
    required this.importerAddressCtrl,
    required this.onImporterChanged,
    required this.selectedSupplierId,
    required this.exporterRegIdCtrl,
    required this.exporterRegType,
    required this.exporterCountryCtrl,
    required this.cargoxIdCtrl,
    required this.onSupplierChanged,
    required this.onRegTypeChanged,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.importerAndExporterSection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const Divider(height: 24),
          if (isMobile) ...[
            _buildImporterSection(context, l),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _buildExporterSection(context, l),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildImporterSection(context, l)),
                const SizedBox(width: 24),
                Expanded(child: _buildExporterSection(context, l)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImporterSection(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.importerSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: l.importerSectionTitle,
          hintText: l.searchFileOrSupplierHint,
          value: selectedImporterId,
          isRequired: true,
          items: importCompanies.map((c) => SearchableDropdownItem<int>(
            value: c.companyId ?? 0,
            label: '${c.importerName} (${c.importerId})',
          )).toList(),
          onChanged: onImporterChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: importerTaxIdCtrl,
          decoration: InputDecoration(
            labelText: '${l.importerTaxIdLabel} *',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? l.importerTaxIdLabel : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: importerAddressCtrl,
          decoration: InputDecoration(
            labelText: l.importerAddressLabel,
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildExporterSection(BuildContext context, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.foreignExporterSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        SearchableDropdownField<int>(
          labelText: l.foreignExporterSectionTitle,
          hintText: l.searchFileOrSupplierHint,
          value: selectedSupplierId,
          isRequired: true,
          items: suppliers.map((s) => SearchableDropdownItem<int>(
            value: s.supplierId ?? 0,
            label: '${s.companyName} (${s.foreignExporterCountry})',
          )).toList(),
          onChanged: onSupplierChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: exporterRegIdCtrl,
                decoration: InputDecoration(
                  labelText: '${l.foreignExporterIdLabel} *',
                  helperText: exporterRegType,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.foreignExporterIdLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SearchableDropdownField<String>(
                value: exporterRegType,
                labelText: l.regTypeLabel,
                items: [
                  SearchableDropdownItem(value: 'VAT Number', label: l.vatRegType),
                  SearchableDropdownItem(value: 'Commercial Register', label: l.crRegType),
                  SearchableDropdownItem(value: 'Tax ID', label: l.taxIdRegType),
                  SearchableDropdownItem(value: 'DUNS Number', label: l.dunsRegType),
                ],
                onChanged: onRegTypeChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: exporterCountryCtrl,
                decoration: InputDecoration(
                  labelText: '${l.countryOfOriginExportLabel} *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? l.countryOfOriginExportLabel : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: cargoxIdCtrl,
                decoration: InputDecoration(
                  labelText: l.cargoxPlatformIdLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
