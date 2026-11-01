import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/customs_clearance_model.dart';
import '../../providers/customs_clearance_provider.dart';
import '../customs_ui.dart';
import 'clearance_dialog_actions.dart';

/// Fallback final-release dialog. Posts to `/customs-clearance/{id}/complete-release`;
/// the release date is optional for the backend (defaults to now) but offered here.
class ClearanceFinalReleaseFallbackDialog extends ConsumerStatefulWidget {
  const ClearanceFinalReleaseFallbackDialog({super.key, required this.record});

  final CustomsClearanceModel record;

  @override
  ConsumerState<ClearanceFinalReleaseFallbackDialog> createState() =>
      _ClearanceFinalReleaseFallbackDialogState();
}

class _ClearanceFinalReleaseFallbackDialogState
    extends ConsumerState<ClearanceFinalReleaseFallbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _releaseNoCtrl = TextEditingController();
  late DateTime _releaseDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _releaseNoCtrl.text = widget.record.releasePermitNo ?? '';
    final stored = widget.record.releaseDate != null ? DateTime.tryParse(widget.record.releaseDate!) : null;
    _releaseDate = stored ?? DateTime.now();
  }

  @override
  void dispose() {
    _releaseNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successBar = AppTheme.snackBar(context, l.customsClearanceReleaseSuccess, severity: AppSeverity.success);
    try {
      await ref.read(customsClearanceProvider.notifier).completeRelease(
        widget.record.customsClearanceId,
        {
          'release_permit_no': _releaseNoCtrl.text.trim(),
          'release_date': DateTime(_releaseDate.year, _releaseDate.month, _releaseDate.day).toIso8601String(),
        },
      );
      navigator.pop();
      messenger.showSnackBar(successBar);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          l.customsClearanceReleaseError(ApiErrorText.of(l, e)),
          severity: AppSeverity.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user, color: AppTheme.wcagCobalt),
          const SizedBox(width: 10),
          Expanded(child: Text(l.customsClearanceFinalReleaseDialogTitle)),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 500.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.customsClearanceFinalReleaseDialogDesc,
                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _releaseNoCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.customsClearanceReleasePermitInput,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: ccCopyIcon(context, _releaseNoCtrl),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.ccRelPermitRequired;
                    if (v.trim().length < 3) return l.ccRelPermitTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CcDateField(
                  key: const Key('ccReleaseDateField'),
                  label: l.ccReleaseDateLabel,
                  value: _releaseDate,
                  onChanged: (d) => setState(() => _releaseDate = d),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: ccDialogActions(
        context: context,
        confirmLabel: l.customsClearanceConfirmReleaseBtn,
        isLoading: _isLoading,
        onConfirm: _isLoading ? null : () => _submit(l),
      ),
    );
  }
}
