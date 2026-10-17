import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/cargo_shipping_model.dart';

/// Display helpers shared by the cargo-shipping widgets.
class ShippingFormat {
  ShippingFormat._();

  /// `2026-08-16 | 1:56 PM` (date only for plain dates, a hint when empty).
  static String dateTime(String? raw, BuildContext ctx) {
    if (raw == null || raw.trim().isEmpty) return ctx.l10n.cargoShippingClickToSetDateTime;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    if (!raw.contains('T') && !raw.contains(':')) return datePart;
    final ml = MaterialLocalizations.of(ctx);
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? ml.postMeridiemAbbreviation : ml.anteMeridiemAbbreviation;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$datePart | $hour:$minute $ampm';
  }

  static AppSeverity statusSeverity(String status) {
    switch (status) {
      case 'Completed':
        return AppSeverity.success;
      case 'Cargo Ready':
        return AppSeverity.info;
      default:
        return AppSeverity.info;
    }
  }
}

/// Two-step switcher of the loading form (container assignment / 48h tracking).
class ShippingStepSwitcher extends StatelessWidget {
  const ShippingStepSwitcher({
    super.key,
    required this.selectedIndex,
    required this.titles,
    required this.icons,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<String> titles;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(5),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          for (var i = 0; i < titles.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _tile(context, i)),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final selected = selectedIndex == i;
    final fg = selected ? AppTheme.white : AppTheme.textPrimaryOf(context);
    return InkWell(
      onTap: () => onSelected(i),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[i], size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                titles[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five-node milestone progress line: reached nodes are emerald, the labels sit
/// under the nodes so nothing overflows on narrow windows.
class ShippingMilestoneTimeline extends StatelessWidget {
  const ShippingMilestoneTimeline({super.key, required this.stepIndex, required this.labels});

  final int stepIndex;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final border = AppTheme.borderOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (i <= stepIndex - 1 ? AppTheme.emerald : border),
                      ),
                    ),
                    _node(context, i),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == labels.length - 1 ? Colors.transparent : (i < stepIndex - 1 ? AppTheme.emerald : border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (i + 1) <= stepIndex ? FontWeight.bold : FontWeight.normal,
                      color: (i + 1) <= stepIndex ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _node(BuildContext context, int i) {
    final reached = (i + 1) <= stepIndex;
    return CircleAvatar(
      radius: 11,
      backgroundColor: reached ? AppTheme.emerald : AppTheme.borderOf(context),
      child: reached
          ? const Icon(Icons.check, size: 13, color: AppTheme.white)
          : Text('${i + 1}', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// One milestone date-time slot: tinted when set, with Pick / Set now / clear.
class ShippingMilestoneBox extends StatelessWidget {
  const ShippingMilestoneBox({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
    required this.valueText,
    required this.onPick,
    required this.onSetNow,
    required this.onClear,
    this.noteText,
  });

  final String stepNumber;
  final String stepTitle;
  final String? valueText;
  final String? noteText;
  final VoidCallback onPick;
  final VoidCallback onSetNow;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasValue = valueText != null && valueText!.trim().isNotEmpty;
    final hasNote = noteText != null && noteText!.trim().isNotEmpty;
    final okFg = AppTheme.severityForegroundOf(context, AppSeverity.success);
    final warnFg = AppTheme.severityForegroundOf(context, AppSeverity.warning);

    return Container(
      padding: const EdgeInsetsDirectional.all(8),
      decoration: BoxDecoration(
        color: hasValue ? AppTheme.severityBackgroundOf(context, AppSeverity.success) : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: hasValue ? okFg.withValues(alpha: 0.6) : AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$stepNumber. $stepTitle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: hasValue ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
              if (hasValue)
                InkWell(
                  onTap: onClear,
                  child: Icon(Icons.cancel, size: 15, color: AppTheme.textMutedOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: hasValue ? okFg.withValues(alpha: 0.5) : AppTheme.borderOf(context)),
              ),
              child: Row(
                children: [
                  Icon(hasValue ? Icons.check_circle : Icons.schedule, size: 14, color: hasValue ? okFg : AppTheme.cobalt),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LtrText(
                      ShippingFormat.dateTime(valueText, context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                        color: hasValue ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: l.cargoShippingCopyFieldTooltip,
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          ShippingFormat.dateTime(valueText, context),
                          customMessage: l.cargoShippingSlaCopyMilestoneSuccess,
                        ),
                        child: Icon(Icons.copy, size: 12, color: okFg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasNote) ...[
            const SizedBox(height: 6),
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(context, noteText!),
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: warnFg.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt, size: 12, color: warnFg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          noteText!,
                          style: TextStyle(fontSize: 10.5, color: warnFg, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: CcUi.fit(AppButton(
                  label: l.cargoShippingPickBtn,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: onPick,
                )),
              ),
              const SizedBox(width: 4),
              CcUi.fit(AppButton(
                label: l.cargoShippingSetNowBtn,
                variant: AppButtonVariant.saveDraft,
                size: AppButtonSize.small,
                onPressed: onSetNow,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of the saved-shipments registry: file / company title, code and
/// type chips, supplier + containers line, status chips and the row actions.
class ShippingRegistryRow extends StatelessWidget {
  const ShippingRegistryRow({
    super.key,
    required this.rec,
    required this.displayName,
    required this.supplierName,
    required this.onOpen,
    required this.onCopyRow,
    required this.onClone,
    required this.onRestore,
    required this.onDelete,
  });

  final CargoShippingModel rec;
  final String displayName;
  final String supplierName;
  final VoidCallback onOpen;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasBreach =
        rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);
    final gatedCount = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
    final statusLabel = rec.status == 'Completed'
        ? l.cargoShippingStatusCompleted
        : (rec.status == 'Cargo Ready' ? l.cargoShippingStatusCargoReady : rec.status);
    final accent = hasBreach
        ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
        : (rec.isActive ? AppTheme.cobalt : AppTheme.textMutedOf(context));

    return InkWell(
      onTap: onOpen,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: rec.isActive ? AppTheme.cobalt.withValues(alpha: 0.12) : AppTheme.borderOf(context),
                  child: Icon(
                    rec.isActive ? Icons.folder_special : Icons.delete_outline,
                    color: rec.isActive ? AppTheme.cobalt : AppTheme.textMutedOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _details(context, l, statusLabel, gatedCount, hasBreach)),
                const SizedBox(width: 8),
                _actions(context, l),
              ],
            ),
          ),
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, AppLocalizations l, String statusLabel, int gatedCount, bool hasBreach) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              displayName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
            ),
            AppStatusBadge(label: rec.cargoShippingCode, severity: AppSeverity.info, size: AppStatusBadgeSize.small),
            AppStatusBadge(
              label: rec.shipmentType,
              severity: rec.shipmentType == 'FCL' ? AppSeverity.info : AppSeverity.warning,
              size: AppStatusBadgeSize.small,
            ),
            if (!rec.isActive)
              AppStatusBadge(label: l.cargoShippingSoftDeletedBadge, severity: AppSeverity.danger, icon: Icons.delete_outline, size: AppStatusBadgeSize.small),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${supplierName.isNotEmpty ? "${l.cargoShippingSupplierLabel} $supplierName | " : ""}${l.cargoShippingContainersHeader} ${rec.containersLoadingData.map((c) => "${c.containerNo} (${c.sealNo})").join(", ")}',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            AppStatusBadge(
              label: '${l.status}: $statusLabel',
              severity: ShippingFormat.statusSeverity(rec.status),
              size: AppStatusBadgeSize.small,
            ),
            if (rec.shipmentType == 'FCL')
              AppStatusBadge(
                label: l.cargoShippingGatedCountBadge(gatedCount, rec.containersLoadingData.length),
                severity: AppSeverity.success,
                icon: Icons.login,
                size: AppStatusBadgeSize.small,
              ),
            if (hasBreach)
              AppStatusBadge(label: l.cargoShippingSlaBreached, severity: AppSeverity.danger, icon: Icons.alarm_off, size: AppStatusBadgeSize.small)
            else
              AppStatusBadge(label: l.cargoShippingSlaOnTime, severity: AppSeverity.success, icon: Icons.alarm_on, size: AppStatusBadgeSize.small),
          ],
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('copyShippingRowBtn_${rec.cargoShippingCode}'),
          icon: const Icon(Icons.copy, color: AppTheme.cobalt),
          tooltip: l.copyCargoShippingRowSuccess,
          onPressed: onCopyRow,
        ),
        IconButton(
          key: Key('cloneShippingRowBtn_${rec.cargoShippingCode}'),
          icon: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt),
          tooltip: l.cloneCargoShippingTooltip,
          onPressed: onClone,
        ),
        IconButton(
          key: Key('editShippingBtn_${rec.cargoShippingCode}'),
          icon: const Icon(Icons.edit, color: AppTheme.cobalt),
          tooltip: l.cargoShippingEditTooltip,
          onPressed: onOpen,
        ),
        if (!rec.isActive)
          IconButton(
            icon: const Icon(Icons.restore_from_trash, color: AppTheme.emerald),
            tooltip: l.cargoShippingRestoreTooltip,
            onPressed: onRestore,
          ),
        if (rec.isActive)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
            tooltip: l.delete,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

/// Frame of the search-and-clone pickers: charcoal header (icon, title,
/// subtitle, close) over a padded body that scrolls inside its own children.
class ShippingDialogFrame extends StatelessWidget {
  const ShippingDialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.maxWidth = 920,
    this.accent = AppTheme.cobalt,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final double maxWidth;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = (screen.width - 32).clamp(360.0, maxWidth);
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: screen.height * 0.9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppTheme.charcoal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.white),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: onDark)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: onDark),
                    tooltip: context.l10n.close,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header of one tracked unit (FCL container / LCL consolidation): copyable
/// title, tracking-status chip, SLA-breach chip and the quick-save action.
class ShippingTrackingHeader extends StatelessWidget {
  const ShippingTrackingHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.copyText,
    required this.copyMessage,
    required this.statusLabel,
    required this.statusSeverity,
    required this.quickSaveLabel,
    required this.onQuickSave,
    this.breached = false,
  });

  final IconData icon;
  final String title;
  final String copyText;
  final String? copyMessage;
  final String statusLabel;
  final AppSeverity statusSeverity;
  final bool breached;
  final String quickSaveLabel;
  final VoidCallback onQuickSave;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.cobalt, size: 20),
            const SizedBox(width: 8),
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(context, copyText, customMessage: copyMessage),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 13, color: AppTheme.textMutedOf(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: l.cargoShippingCopyFieldTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => CopyHelper.copy(
                  context,
                  statusLabel,
                  customMessage: '${l.cargoShippingSlaTsvHeaderTrackingStatus}: $statusLabel',
                ),
                child: AppStatusBadge(label: statusLabel, severity: statusSeverity, size: AppStatusBadgeSize.small),
              ),
            ),
            if (breached) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: l.cargoShippingCopyFieldTooltip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () => CopyHelper.copy(context, l.cargoShippingSlaBreachedBadge),
                  child: AppStatusBadge(
                    label: l.cargoShippingSlaBreachedBadge,
                    severity: AppSeverity.danger,
                    icon: Icons.alarm_off,
                    size: AppStatusBadgeSize.small,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            CcUi.fit(AppButton(
              label: quickSaveLabel,
              icon: Icons.save,
              variant: AppButtonVariant.saveDraft,
              size: AppButtonSize.small,
              onPressed: onQuickSave,
            )),
          ],
        ),
      ],
    );
  }
}

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
