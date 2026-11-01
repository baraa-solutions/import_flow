import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Banner naming the import file the form is linked to (file code, company,
/// supplier, ACID and the shipping record code) with an optional "start new".
class ShippingLinkedFileBanner extends StatelessWidget {
  const ShippingLinkedFileBanner({
    super.key,
    required this.fileLabel,
    required this.companyName,
    required this.supplierName,
    this.acidNumber,
    this.recordCode,
    this.onCancelEdit,
    this.copyAll,
  });

  final String fileLabel;
  final String companyName;
  final String supplierName;
  final String? acidNumber;
  final String? recordCode;
  final VoidCallback? onCancelEdit;

  /// When set a copy icon puts the whole summary on the clipboard.
  final VoidCallback? copyAll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final primary = AppTheme.textPrimaryOf(context);
    final base = TextStyle(color: primary, fontSize: 13);
    final fg = AppTheme.severityForegroundOf(context, AppSeverity.info);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_special, color: fg, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text('${l.cargoShippingLinkedFileBannerPrefix} ', style: base.copyWith(fontWeight: FontWeight.bold)),
                CopyableText(
                  fileLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 13),
                  tooltip: l.cargoShippingCopyFieldTooltip,
                ),
                Text(' - $companyName | ${l.cargoShippingSupplierLabel} ', style: base),
                CopyableText(
                  supplierName,
                  style: base.copyWith(fontWeight: FontWeight.bold),
                  tooltip: l.cargoShippingCopyFieldTooltip,
                ),
                if (acidNumber != null) ...[
                  Text(' | ${l.cargoShippingAcidPrefix}: ', style: base),
                  CopyableText(
                    acidNumber!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.severityForegroundOf(context, AppSeverity.success),
                      fontSize: 13,
                    ),
                    tooltip: l.cargoShippingCopyFieldTooltip,
                  ),
                ],
                if (recordCode != null) ...[
                  Text(' | ${l.cargoShippingCodeLabel} ', style: base),
                  CopyableText(
                    recordCode!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                      fontSize: 13,
                    ),
                    tooltip: l.cargoShippingCopyFieldTooltip,
                  ),
                ],
              ],
            ),
          ),
          if (copyAll != null)
            IconButton(
              tooltip: l.cargoShippingCopyFieldTooltip,
              icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
              onPressed: copyAll,
            ),
          if (onCancelEdit != null)
            AppButton(
              label: l.cargoShippingCancelStartNew,
              icon: Icons.close,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: onCancelEdit,
            ),
        ],
      ),
    );
  }
}
