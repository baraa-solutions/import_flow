import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierDetailsHeader extends StatelessWidget {
  final SupplierModel supplier;

  const SupplierDetailsHeader({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = supplier.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.flight_takeoff_rounded, color: AppTheme.orange, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        supplier.supplierCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        supplier.companyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.suppliersCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(context, supplier.companyName),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.supplierCopySummaryBtn,
                      child: InkWell(
                        onTap: () {
                          final summary = '''
[${supplier.supplierCode}] ${supplier.companyName}
${l10n.supplierTsvHeaderType}: ${supplier.supplierType} | ${l10n.supplierTsvHeaderRegType}: ${supplier.registrationType}
${l10n.supplierTsvHeaderForeignExporterId}: ${supplier.foreignExporterId} | ${l10n.supplierTsvHeaderCargoxId}: ${supplier.cargoxPlatformId ?? '-'}
${l10n.supplierTsvHeaderCountry}: ${supplier.foreignExporterCountry} (${supplier.foreignExporterCountryCode})
${l10n.supplierTsvHeaderAddress}: ${supplier.address}
${l10n.supplierTsvHeaderPhone}: ${supplier.phone ?? '-'} | ${l10n.supplierTsvHeaderEmail}: ${supplier.email ?? '-'}
${l10n.supplierTsvHeaderBankName}: ${supplier.bankName ?? '-'} | ${l10n.supplierTsvHeaderSwiftCode}: ${supplier.swiftCode ?? '-'}
${l10n.supplierTsvHeaderIban}: ${supplier.iban ?? '-'}
${l10n.supplierTsvHeaderStatus}: ${supplier.isActive ? l10n.statusActive : l10n.statusInactive}
${l10n.supplierTsvHeaderBrands}: ${supplier.brands ?? '-'}
WIPO Madrid: ${supplier.hasWipo ? (supplier.wipoNumber ?? 'Yes') : 'No'} | EUIPO: ${supplier.hasEuipo ? (supplier.euipoNumber ?? 'Yes') : 'No'}
Global Brand: ${supplier.hasGlobalBrand ? (supplier.globalBrandNumber ?? 'Yes') : 'No'} | ISO 9001: ${supplier.hasIso9001 ? (supplier.iso9001Number ?? 'Yes') : 'No'}
'''.trim();
                          CopyHelper.copy(context, summary, customMessage: l10n.supplierCopySummarySuccess);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.copy_all_rounded, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isActive ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? AppTheme.emerald : AppTheme.crimson,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isActive ? l10n.statusActive : l10n.statusInactive,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  l10n.supplierProfileSubtitle,
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
            tooltip: l10n.close,
          ),
        ],
      ),
    );
  }
}
