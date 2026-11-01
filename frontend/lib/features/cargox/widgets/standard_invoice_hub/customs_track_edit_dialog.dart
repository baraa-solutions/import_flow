import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/cargox_model.dart';
import '../../providers/cargox_provider.dart';

/// Edit dialog for updating customs track status and declaration notes.
class CustomsTrackEditDialog extends ConsumerStatefulWidget {
  final CustomsInvoiceTrackModel track;
  final int? importFileId;
  final ValueChanged<List<CustomsInvoiceTrackModel>> onTracksUpdated;

  const CustomsTrackEditDialog({
    super.key,
    required this.track,
    required this.importFileId,
    required this.onTracksUpdated,
  });

  static void show({
    required BuildContext context,
    required CustomsInvoiceTrackModel track,
    required int? importFileId,
    required ValueChanged<List<CustomsInvoiceTrackModel>> onTracksUpdated,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => CustomsTrackEditDialog(
        track: track,
        importFileId: importFileId,
        onTracksUpdated: onTracksUpdated,
      ),
    );
  }

  @override
  ConsumerState<CustomsTrackEditDialog> createState() => _CustomsTrackEditDialogState();
}

class _CustomsTrackEditDialogState extends ConsumerState<CustomsTrackEditDialog> {
  late String _selectedStatus;
  late final TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.track.status;
    _notesCtrl = TextEditingController(text: widget.track.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final nav = Navigator.of(context);

    try {
      final notifier = ref.read(standardInvoiceSessionsProvider.notifier);
      await notifier.updateCustomsTrack(widget.track.trackId, {
        'status': _selectedStatus,
        'notes': _notesCtrl.text.trim(),
      });
      if (widget.importFileId != null) {
        final updated = await notifier.fetchCustomsTracks(widget.importFileId!);
        widget.onTracksUpdated(updated);
      }
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.customsTrackUpdateSuccessToast), backgroundColor: AppTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.cargoxSaveTrackError(e)), backgroundColor: AppTheme.crimson),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.orange),
            const SizedBox(width: 8),
            Text(l10n.customsTrackEditDialogTitle(widget.track.trackCode), style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchableDropdownField<String>(
                value: _selectedStatus,
                labelText: l10n.customsTrackCustomsStatus,
                items: [
                  SearchableDropdownItem<String>(value: 'DRAFT', label: l10n.standardInvoiceStatusDraft),
                  SearchableDropdownItem<String>(value: 'APPROVED', label: l10n.standardInvoiceStatusApproved),
                  SearchableDropdownItem<String>(value: 'SEALED', label: l10n.customsTrackStatusSealed),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              const SizedBox(height: 14),
              Text(l10n.customsTrackNotesAndDeclaration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: l10n.customsTrackNotesHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: l10n.cancel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: l10n.customsTrackSaveBtn,
            variant: AppButtonVariant.success,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}
