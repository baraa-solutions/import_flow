import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../freight_booking_ui.dart';

/// Leading action buttons inside the dialog footer (Live reload, Clear/New, Save Draft).
class BookingFormActionsBar extends StatelessWidget {
  final bool isEdit;
  final bool isSaving;
  final VoidCallback onLiveReload;
  final VoidCallback onClearNew;
  final VoidCallback onSaveDraft;

  const BookingFormActionsBar({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.onLiveReload,
    required this.onClearNew,
    required this.onSaveDraft,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return FbkButtonWrap(
      buttons: [
        AppButton(
          label: l.freightBookingBtnLiveReload,
          icon: Icons.refresh,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: isSaving ? null : onLiveReload,
        ),
        if (!isEdit)
          AppButton(
            key: const Key('fbkFormClearBtn'),
            label: l.freightBookingBtnClearNew,
            icon: Icons.cleaning_services_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: isSaving ? null : onClearNew,
          ),
        AppButton(
          key: const Key('fbkFormSaveDraftBtn'),
          label: l.freightBookingBtnSaveDraft,
          icon: Icons.save_outlined,
          variant: AppButtonVariant.saveDraft,
          size: AppButtonSize.small,
          onPressed: isSaving ? null : onSaveDraft,
        ),
      ],
    );
  }
}
