import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Reusable action panel container with icon, description, notes field, and action button.
class InlandActionPanel extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String description;
  final TextEditingController notesController;
  final Widget? extraContent;
  final Widget button;

  const InlandActionPanel({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
    required this.notesController,
    this.extraContent,
    required this.button,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(description, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
              button,
            ],
          ),
          if (extraContent != null) ...[
            const SizedBox(height: 10),
            extraContent!,
          ],
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: l10n.inlandNotesOptionalLabel,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action panel for recording port Gate-Out.
class InlandGateOutAction extends StatelessWidget {
  final TextEditingController gatePassNoController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final VoidCallback onGateOut;

  const InlandGateOutAction({
    super.key,
    required this.gatePassNoController,
    required this.notesController,
    required this.isSubmitting,
    required this.onGateOut,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InlandActionPanel(
      color: AppTheme.cobalt,
      icon: Icons.departure_board,
      title: l10n.inlandGateOutTitle,
      description: l10n.inlandGateOutDesc,
      notesController: notesController,
      extraContent: TextField(
        key: const Key('inlandGatePassNoField'),
        controller: gatePassNoController,
        decoration: InputDecoration(
          labelText: l10n.inlandGatePassNoLabel,
          hintText: l10n.inlandGatePassNoHint,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.confirmation_num_outlined),
        ),
      ),
      button: AppButton(
        key: const Key('inlandGateOutBtn'),
        label: l10n.inlandGateOutBtn,
        icon: Icons.exit_to_app,
        isLoading: isSubmitting,
        onPressed: isSubmitting ? null : onGateOut,
      ),
    );
  }
}

/// Action panel for recording Warehouse Arrival.
class InlandWarehouseArrivalAction extends StatelessWidget {
  final TextEditingController sealNumberController;
  final TextEditingController notesController;
  final bool sealIntact;
  final ValueChanged<bool> onSealIntactChanged;
  final bool isSubmitting;
  final VoidCallback onArrival;

  const InlandWarehouseArrivalAction({
    super.key,
    required this.sealNumberController,
    required this.notesController,
    required this.sealIntact,
    required this.onSealIntactChanged,
    required this.isSubmitting,
    required this.onArrival,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InlandActionPanel(
      color: AppTheme.emerald,
      icon: Icons.warehouse_rounded,
      title: l10n.inlandArrivalTitle,
      description: l10n.inlandArrivalDesc,
      notesController: notesController,
      extraContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('inlandSealIntactSwitch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inlandSealIntactSwitch, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: sealIntact,
              onChanged: onSealIntactChanged,
              activeThumbColor: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('inlandSealNumberField'),
            controller: sealNumberController,
            decoration: InputDecoration(
              labelText: sealIntact
                  ? '${l10n.inlandSealNumberLabel.replaceAll(' *', '')} (${l10n.inlandNotesOptionalLabel})'
                  : l10n.inlandSealNumberLabel,
              hintText: l10n.inlandSealNumberHint,
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.security),
            ),
          ),
        ],
      ),
      button: AppButton(
        key: const Key('inlandWarehouseArrivalBtn'),
        label: l10n.inlandArrivalBtn,
        variant: AppButtonVariant.success,
        icon: Icons.done_all,
        isLoading: isSubmitting,
        onPressed: isSubmitting ? null : onArrival,
      ),
    );
  }
}

/// Banner indicating arrival is completed.
class InlandArrivedBanner extends StatelessWidget {
  const InlandArrivedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.emerald),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.inlandArrivedMsg,
              style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog footer bar with sync message and Close action button.
class InlandTransportDialogFooter extends StatelessWidget {
  final VoidCallback onClose;

  const InlandTransportDialogFooter({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXl)),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_alt, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.inlandFooterNote,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: l10n.inlandCloseBtn,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
