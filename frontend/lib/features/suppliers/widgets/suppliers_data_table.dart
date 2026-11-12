import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/supplier_model.dart';
import 'suppliers_filter_toolbar.dart';

/// جدول وقائمة الموردين الموحدة
class SuppliersDataTable extends StatelessWidget {
  final List<SupplierModel> suppliers;
  final void Function(SupplierModel supplier) onView;
  final void Function(SupplierModel supplier) onEdit;
  final void Function(SupplierModel supplier) onPrint;
  final void Function(SupplierModel supplier) onToggleActive;
  final void Function(SupplierModel supplier) onHistory;
  final void Function(SupplierModel supplier)? onRouteIntelligence;
  final void Function(SupplierModel supplier)? onScorecard;
  final void Function(SupplierModel supplier)? onLedger;
  final void Function(SupplierModel supplier)? onGoeicVerification;

  const SuppliersDataTable({
    super.key,
    required this.suppliers,
    required this.onView,
    required this.onEdit,
    required this.onPrint,
    required this.onToggleActive,
    required this.onHistory,
    this.onRouteIntelligence,
    this.onScorecard,
    this.onLedger,
    this.onGoeicVerification,
  });

  Widget _buildSupplierRow(BuildContext context, SupplierModel supplier) {
    final l10n = context.l10n;
    final isActive = supplier.isActive;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        RowContextMenuHelper.showContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          codeToCopy: supplier.supplierCode,
          onView: () => onView(supplier),
          onEdit: () => onEdit(supplier),
          onHistory: () => onHistory(supplier),
          isActive: isActive,
          onToggleActive: () => onToggleActive(supplier),
        );
      },
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              // Standard 4-Action Row Pill: View, Edit, Print, Delete
              RowActionsPill(
                onView: () => onView(supplier),
                onEdit: () => onEdit(supplier),
                onPrint: () => onPrint(supplier),
                onDelete: () => onToggleActive(supplier),
                deleteTooltip: isActive ? l10n.deactivateSupplierTooltip : l10n.activateSupplierTooltip,
              ),
              const SizedBox(width: 4),
              // Quick Copy Supplier Summary Button
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 20),
                tooltip: l10n.supplierCopySummaryBtn,
                onPressed: () => CopyHelper.copy(
                  context,
                  SuppliersFilterToolbar.buildSupplierSummary(context, supplier),
                  customMessage: l10n.supplierCopySummarySuccess,
                ),
              ),
              // AI Route Intelligence & GOEIC Compliance Buttons
              if (supplier.supplierId != null) ...[
                if (onRouteIntelligence != null)
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 20),
                    tooltip: l10n.routeIntelligenceBtnTooltip,
                    onPressed: () => onRouteIntelligence!(supplier),
                  ),
                if (onScorecard != null)
                  IconButton(
                    icon: const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 20),
                    tooltip: l10n.supplierScorecardBtnTooltip,
                    onPressed: () => onScorecard!(supplier),
                  ),
                if (onLedger != null)
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.charcoal, size: 20),
                    tooltip: l10n.supplierLedgerBtnTooltip,
                    onPressed: () => onLedger!(supplier),
                  ),
                if (onGoeicVerification != null)
                  IconButton(
                    icon: const Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 20),
                    tooltip: l10n.goeicVerificationBtnTooltip,
                    onPressed: () => onGoeicVerification!(supplier),
                  ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 8),
              // Icon Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.cobalt : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.factory, color: isActive ? AppTheme.cobalt : Colors.grey),
              ),
              const SizedBox(width: 16),

              // Supplier Code & Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Tooltip(
                          message: l10n.supplierCodeBadgeLabel,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => CopyHelper.copy(context, supplier.supplierCode),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.charcoal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    supplier.supplierCode,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded, size: 11, color: AppTheme.charcoal),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            supplier.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                          tooltip: l10n.suppliersCopyFieldTooltip,
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => CopyHelper.copy(context, supplier.companyName),
                        ),
                        const SizedBox(width: 8),
                        AppStatusBadge(
                          label: isActive ? l10n.statusActive : l10n.statusInactive,
                          severity: isActive ? AppSeverity.success : AppSeverity.danger,
                          size: AppStatusBadgeSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.supplierRowMeta(supplier.foreignExporterId, supplier.cargoxPlatformId, supplier.address, supplier.brands),
                      style: TextStyle(fontSize: 13, color: AppTheme.textMutedOf(context)),
                    ),
                    if (supplier.soonestCertificateExpiry != null) ...[
                      const SizedBox(height: 4),
                      CertificateExpiryBadge(
                        key: ValueKey('supplierCertExpiry_${supplier.supplierId}'),
                        expiry: supplier.soonestCertificateExpiry,
                        isArabic: Localizations.localeOf(context).languageCode == 'ar',
                        prefix: Localizations.localeOf(context).languageCode == 'ar' ? 'الشهادات' : 'Certificates',
                      ),
                    ],
                  ],
                ),
              ),

              // Country & Code Badge
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            supplier.foreignExporterCountryCode.toUpperCase(),
                            style: const TextStyle(color: AppTheme.orange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(supplier.foreignExporterCountry, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.supplierTypeAndReg(
                        SuppliersFilterToolbar.getSupplierTypeLabel(context, supplier.supplierType),
                        SuppliersFilterToolbar.getRegTypeLabel(context, supplier.registrationType),
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOf(context)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.isDark(context) ? Colors.black26 : const Color(0x0A000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _buildSupplierRow(context, suppliers[index]);
          },
        ),
      ),
    );
  }
}
