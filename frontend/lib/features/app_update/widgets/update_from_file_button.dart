import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../providers/app_update_providers.dart';
import 'update_feedback.dart';

/// Signature of a single-file open dialog; injectable for tests.
typedef UpdateFilePicker = Future<String?> Function({
  required String dialogTitle,
  required List<String> extensions,
});

Future<String?> pickUpdateFile({required String dialogTitle, required List<String> extensions}) async {
  final result = await FilePicker.pickFiles(
    dialogTitle: dialogTitle,
    type: FileType.custom,
    allowedExtensions: extensions,
    lockParentWindow: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.single.path;
}

/// "Update from file (USB)" (plan §4.6): the user picks `manifest.json` and
/// the installer `.exe` with the OS open dialog; the backend verifies the
/// signature + hash and stages them (`POST /stage-local`). Nothing is exported,
/// so this uses an open dialog, not FileSaveHelper.
class UpdateFromFileButton extends ConsumerStatefulWidget {
  const UpdateFromFileButton({super.key, this.picker = pickUpdateFile});

  final UpdateFilePicker picker;

  @override
  ConsumerState<UpdateFromFileButton> createState() => _UpdateFromFileButtonState();
}

class _UpdateFromFileButtonState extends ConsumerState<UpdateFromFileButton> {
  bool _busy = false;

  Future<void> _stage() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final manifest = await widget.picker(dialogTitle: l.updatePickManifest, extensions: const ['json']);
      if (manifest == null) return;
      final installer = await widget.picker(dialogTitle: l.updatePickInstaller, extensions: const ['exe']);
      if (installer == null) return;
      await ref
          .read(updateStatusProvider.notifier)
          .stageLocal(manifestPath: manifest, installerPath: installer);
      if (mounted) showUpdateSnackBar(context, l.updateStagedFromFile);
    } catch (e) {
      if (mounted) showUpdateErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: context.l10n.updateFromFile,
      variant: AppButtonVariant.ghost,
      icon: Icons.usb_rounded,
      size: AppButtonSize.small,
      isLoading: _busy,
      onPressed: _stage,
    );
  }
}
