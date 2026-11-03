import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';

/// شريط أدوات الفلترة والبحث والإجراءات السريعة للموردين
class SuppliersFilterToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddSupplier;
  final VoidCallback onExtractAi;
  final VoidCallback onCopyTsv;
  final VoidCallback onRefresh;

  const SuppliersFilterToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddSupplier,
    required this.onExtractAi,
    required this.onCopyTsv,
    required this.onRefresh,
  });

  static String getSupplierTypeLabel(BuildContext context, String type) {
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

  static String getRegTypeLabel(BuildContext context, String type) {
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

  static void copySuppliersTsv(BuildContext context, List<SupplierModel> suppliers) {
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
      'Mobile',
      'Fax',
      l10n.supplierTsvHeaderEmail,
      'Secondary Email',
      'Website',
      l10n.supplierTsvHeaderBankName,
      l10n.supplierTsvHeaderSwiftCode,
      l10n.supplierTsvHeaderIban,
      'WIPO Madrid',
      'EUIPO',
      'Global Brand',
      'ISO 9001',
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
        getSupplierTypeLabel(context, s.supplierType),
        getRegTypeLabel(context, s.registrationType),
        s.foreignExporterId,
        s.cargoxPlatformId ?? '',
        s.foreignExporterCountry,
        s.foreignExporterCountryCode,
        s.address,
        s.phone ?? '',
        s.mobile ?? '',
        s.fax ?? '',
        s.email ?? '',
        s.secondaryEmail ?? '',
        s.website ?? '',
        s.bankName ?? '',
        s.swiftCode ?? '',
        s.iban ?? '',
        s.hasWipo ? (s.wipoNumber ?? 'Yes') : 'No',
        s.hasEuipo ? (s.euipoNumber ?? 'Yes') : 'No',
        s.hasGlobalBrand ? (s.globalBrandNumber ?? 'Yes') : 'No',
        s.hasIso9001 ? (s.iso9001Number ?? 'Yes') : 'No',
        s.isActive ? l10n.statusActive : l10n.statusInactive,
        s.brands ?? '',
        s.notes ?? '',
      ];
      buffer.writeln(row.map((cell) => cell.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t'));
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.suppliersExportTsvSuccess);
  }

  static String buildSupplierSummary(BuildContext context, SupplierModel s) {
    final l10n = context.l10n;
    return '''
[${s.supplierCode}] ${s.companyName}
${l10n.supplierTsvHeaderType}: ${getSupplierTypeLabel(context, s.supplierType)} | ${l10n.supplierTsvHeaderRegType}: ${getRegTypeLabel(context, s.registrationType)}
${l10n.supplierTsvHeaderForeignExporterId}: ${s.foreignExporterId} | ${l10n.supplierTsvHeaderCargoxId}: ${s.cargoxPlatformId ?? '-'}
${l10n.supplierTsvHeaderCountry}: ${s.foreignExporterCountry} (${s.foreignExporterCountryCode})
${l10n.supplierTsvHeaderAddress}: ${s.address}
${l10n.supplierTsvHeaderPhone}: ${s.phone ?? s.mobile ?? '-'} | ${l10n.supplierTsvHeaderEmail}: ${s.email ?? '-'}
${l10n.supplierTsvHeaderBankName}: ${s.bankName ?? '-'} | ${l10n.supplierTsvHeaderSwiftCode}: ${s.swiftCode ?? '-'}
${l10n.supplierTsvHeaderIban}: ${s.iban ?? '-'}
${l10n.supplierTsvHeaderStatus}: ${s.isActive ? l10n.statusActive : l10n.statusInactive}
${l10n.supplierTsvHeaderBrands}: ${s.brands ?? '-'}
WIPO Madrid: ${s.hasWipo ? (s.wipoNumber ?? 'Yes') : 'No'} | EUIPO: ${s.hasEuipo ? (s.euipoNumber ?? 'Yes') : 'No'}
Global Brand: ${s.hasGlobalBrand ? (s.globalBrandNumber ?? 'Yes') : 'No'} | ISO 9001: ${s.hasIso9001 ? (s.iso9001Number ?? 'Yes') : 'No'}
'''.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInactive = ref.watch(showInactiveSuppliersProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final suppliersList = suppliersAsync.valueOrNull ?? [];

    return ActionToolbar(
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
          onPressed: onAddSupplier,
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
          onPressed: onExtractAi,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: suppliersList.isNotEmpty,
      ),
      onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
        context: context,
        ref: ref,
        actionValue: val,
        moduleEndpoint: 'suppliers',
        entityNameAr: 'الموردين الأجانب',
        entityNameEn: 'Foreign Suppliers',
        entityFilePrefix: 'Foreign_Suppliers',
        onImportSuccess: onRefresh,
        onCopyTsv: onCopyTsv,
      ),
      searchController: searchController,
      searchHint: l10n.searchSuppliersHint,
      onSearchChanged: onSearchChanged,
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
                activeThumbColor: AppTheme.cobalt,
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
          onPressed: onRefresh,
        ),
        if (suppliersList.isNotEmpty)
          IconButton(
            icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
            tooltip: l10n.suppliersExportTsvBtn,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: density.buttonHeight,
              minHeight: density.buttonHeight,
            ),
            onPressed: onCopyTsv,
          ),
      ],
    );
  }
}
