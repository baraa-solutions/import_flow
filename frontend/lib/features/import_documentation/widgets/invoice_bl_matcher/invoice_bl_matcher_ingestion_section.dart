import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../idoc_ui.dart';

/// Ingestion section for Commercial Invoice, Packing List, and Bill of Lading.
///
/// Provides file upload buttons, text area inputs, and collapsible packing list support.
class InvoiceBlMatcherIngestionSection extends StatelessWidget {
  final TextEditingController invoiceTextCtrl;
  final TextEditingController blTextCtrl;
  final TextEditingController packingTextCtrl;
  final String? invoiceFileName;
  final String? blFileName;
  final String? packingFileName;
  final bool showPackingList;
  final VoidCallback onAddPackingList;
  final VoidCallback onRemovePackingList;
  final Future<void> Function(String docType) onPickFile;

  const InvoiceBlMatcherIngestionSection({
    super.key,
    required this.invoiceTextCtrl,
    required this.blTextCtrl,
    required this.packingTextCtrl,
    required this.invoiceFileName,
    required this.blFileName,
    required this.packingFileName,
    required this.showPackingList,
    required this.onAddPackingList,
    required this.onRemovePackingList,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showPackingList)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IdocUi.fit(AppButton(
                  label: l.invoiceBlMatcherAddPackingListButton,
                  icon: Icons.post_add,
                  variant: AppButtonVariant.secondary,
                  onPressed: onAddPackingList,
                )),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isVeryWide = constraints.maxWidth > 1050;
            final isWide = constraints.maxWidth > 750;

            final invoiceBox = _buildDocumentInputBox(
              context: context,
              title: l.invoiceBlMatcherInvoiceBoxTitle,
              icon: Icons.receipt_long,
              color: AppTheme.cobalt,
              controller: invoiceTextCtrl,
              fileName: invoiceFileName,
              docType: 'invoice',
              placeholder: l.invoiceBlMatcherInvoicePlaceholder,
            );

            final packingBox = _buildDocumentInputBox(
              context: context,
              title: l.invoiceBlMatcherPackingBoxTitle,
              icon: Icons.inventory_2,
              color: AppTheme.orange,
              controller: packingTextCtrl,
              fileName: packingFileName,
              docType: 'packing',
              placeholder: l.invoiceBlMatcherPackingPlaceholder,
              onRemove: onRemovePackingList,
            );

            final blBox = _buildDocumentInputBox(
              context: context,
              title: l.invoiceBlMatcherBlBoxTitle,
              icon: Icons.directions_boat,
              color: AppTheme.emerald,
              controller: blTextCtrl,
              fileName: blFileName,
              docType: 'bl',
              placeholder: l.invoiceBlMatcherBlPlaceholder,
            );

            if (showPackingList) {
              if (isVeryWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: invoiceBox),
                    const SizedBox(width: 14),
                    Expanded(child: packingBox),
                    const SizedBox(width: 14),
                    Expanded(child: blBox),
                  ],
                );
              } else if (isWide) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: invoiceBox),
                        const SizedBox(width: 14),
                        Expanded(child: packingBox),
                      ],
                    ),
                    const SizedBox(height: 14),
                    blBox,
                  ],
                );
              } else {
                return Column(
                  children: [
                    invoiceBox,
                    const SizedBox(height: 14),
                    packingBox,
                    const SizedBox(height: 14),
                    blBox,
                  ],
                );
              }
            }

            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: invoiceBox,
                ),
                SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: blBox,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentInputBox({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String? fileName,
    required String docType,
    required String placeholder,
    VoidCallback? onRemove,
  }) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IdocUi.fit(AppButton(
                label: fileName != null ? l.invoiceBlMatcherChangeFile : l.invoiceBlMatcherUploadFile,
                icon: Icons.upload_file,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => onPickFile(docType),
              )),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.crimson),
                  tooltip: l.invoiceBlMatcherRemovePackingList,
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ],
          ),
          if (fileName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.invoiceBlMatcherUploadedFile(fileName),
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 11),
              filled: true,
              fillColor: AppTheme.surfaceAltOf(context),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
