import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../idoc_ui.dart';

/// Dropzone and text input card for uploading or pasting documents to be extracted.
class SmartExtractorDropzone extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController textController;
  final PlatformFile? pickedFile;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onExtract;
  final bool isLoading;
  final String extractButtonLabel;

  const SmartExtractorDropzone({
    super.key,
    required this.title,
    required this.hint,
    required this.textController,
    required this.pickedFile,
    required this.onPickFile,
    required this.onClearFile,
    required this.onExtract,
    required this.isLoading,
    required this.extractButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IdocUi.fit(AppButton(
                  label: pickedFile != null ? pickedFile!.name : l.smartExtractorPickFileButton,
                  icon: Icons.upload_file,
                  variant: AppButtonVariant.secondary,
                  onPressed: onPickFile,
                )),
                if (pickedFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.crimson, size: 20),
                    onPressed: onClearFile,
                  ),
                IdocUi.fit(AppButton(
                  label: extractButtonLabel,
                  icon: Icons.auto_awesome,
                  variant: AppButtonVariant.primary,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : onExtract,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
