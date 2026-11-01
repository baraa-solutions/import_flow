import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../financial_ui.dart';

class SwiftOcrInputSection extends StatelessWidget {
  final TextEditingController rawSwiftTextController;
  final bool isExtracting;
  final bool isDark;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback onExtractFromText;
  final VoidCallback? onPasteAndExtract;
  final VoidCallback? onReset;

  const SwiftOcrInputSection({
    super.key,
    required this.rawSwiftTextController,
    required this.isExtracting,
    required this.isDark,
    required this.onPickAndExtractFile,
    required this.onExtractFromText,
    this.onPasteAndExtract,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final textArea = TextField(
          controller: rawSwiftTextController,
          maxLines: 5,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
          decoration: InputDecoration(
            hintText: l10n.swiftRawTextPlaceholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: l10n.swiftCopyFieldTooltip,
              onPressed: () => CopyHelper.copy(
                context,
                rawSwiftTextController.text,
              ),
            ),
          ),
        );

        final actionButtons = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinancialUi.fit(AppButton(
              label: l10n.swiftUploadFileBtn,
              variant: AppButtonVariant.primary,
              icon: Icons.upload_file,
              isLoading: isExtracting,
              onPressed: isExtracting ? null : onPickAndExtractFile,
            )),
            const SizedBox(height: 8),
            FinancialUi.fit(AppButton(
              label: l10n.swiftExtractFromTextBtn,
              variant: AppButtonVariant.primary,
              icon: Icons.bolt,
              isLoading: isExtracting,
              onPressed: isExtracting ? null : onExtractFromText,
            )),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FinancialUi.fit(AppButton(
                  label: l10n.swiftPasteAndExtractChip,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  icon: Icons.paste,
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data != null && data.text != null && data.text!.isNotEmpty) {
                      rawSwiftTextController.text = data.text!;
                      if (onPasteAndExtract != null) {
                        onPasteAndExtract!();
                      } else {
                        onExtractFromText();
                      }
                    }
                  },
                )),
                if (onReset != null)
                  FinancialUi.fit(AppButton(
                    label: l10n.swiftCancelBtn,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: Icons.clear,
                    onPressed: onReset,
                  )),
              ],
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textArea,
              const SizedBox(height: 10),
              actionButtons,
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textArea),
              const SizedBox(width: 14),
              SizedBox(width: 220, child: actionButtons),
            ],
          );
        }
      },
    );
  }
}
