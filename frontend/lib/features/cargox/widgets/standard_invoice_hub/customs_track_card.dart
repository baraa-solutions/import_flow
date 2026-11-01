import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/cargox_model.dart';
import 'customs_track_details_dialog.dart';
import 'customs_track_edit_dialog.dart';
import 'customs_track_pdf_preview_dialog.dart';
import 'invoice_hub_formatters.dart';

/// Presentation card representing a single approved customs track
/// with metric stats and contextual actions (details, print, exports, edit, delete).
class CustomsTrackCard extends StatelessWidget {
  final CustomsInvoiceTrackModel track;
  final int? importFileId;
  final ValueChanged<List<CustomsInvoiceTrackModel>> onTracksUpdated;
  final ValueChanged<CustomsInvoiceTrackModel> onDownloadExcel;
  final ValueChanged<CustomsInvoiceTrackModel> onDownloadPackingList;
  final ValueChanged<CustomsInvoiceTrackModel> onDelete;

  const CustomsTrackCard({
    super.key,
    required this.track,
    required this.importFileId,
    required this.onTracksUpdated,
    required this.onDownloadExcel,
    required this.onDownloadPackingList,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.gavel, color: AppTheme.emerald, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.trackCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isAr ? "تاريخ الاعتماد:" : "Approved at:"} ${formatInvoiceHubDateTime(track.createdAt)} | ${isAr ? "النمط:" : "Mode:"} ${track.extractionMode}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              AppStatusBadge.fromStatus(
                status: track.status,
                label: resolveInvoiceHubStatusLabel(context, track.status),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  isAr ? 'إجمالي القيمة الجمركية' : 'Customs Total Amount',
                  '${track.customsTotalAmount.toStringAsFixed(2)} USD',
                  Icons.attach_money,
                  AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStat(
                  isAr ? 'إجمالي الوزن القائم' : 'Gross Weight',
                  '${track.customsGrossWeight.toStringAsFixed(1)} ${isAr ? "كجم" : "kg"}',
                  Icons.scale,
                  AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStat(
                  isAr ? 'إجمالي الوزن الصافي' : 'Net Weight',
                  '${track.customsNetWeight.toStringAsFixed(1)} ${isAr ? "كجم" : "kg"}',
                  Icons.monitor_weight_outlined,
                  AppTheme.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStat(
                  isAr ? 'عدد بنود التعريفة' : 'Tariff Items Count',
                  '${track.lineItemsCount} ${isAr ? "بند" : "items"}',
                  Icons.format_list_numbered,
                  Colors.purple,
                ),
              ),
            ],
          ),
          if (track.notes != null && track.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '${isAr ? "ملاحظات:" : "Notes:"} ${track.notes}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: isAr ? 'مشاهدة وتفاصيل البنود' : 'View Line Items',
                icon: Icons.remove_red_eye_outlined,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () => CustomsTrackDetailsDialog.show(context, track),
              ),
              AppButton(
                label: isAr ? 'معاينة وطباعة المستندات' : 'Print & PDF Preview',
                icon: Icons.picture_as_pdf,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () => CustomsTrackPdfPreviewDialog.show(context, track),
              ),
              AppButton(
                label: isAr ? 'إكسل الفاتورة' : 'Invoice Excel',
                icon: Icons.download,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => onDownloadExcel(track),
              ),
              AppButton(
                label: isAr ? 'إكسل قائمة التعبئة' : 'Packing List Excel',
                icon: Icons.inventory_2_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => onDownloadPackingList(track),
              ),
              AppButton(
                label: isAr ? 'تعديل' : 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.warning,
                size: AppButtonSize.small,
                onPressed: () => CustomsTrackEditDialog.show(
                  context: context,
                  track: track,
                  importFileId: importFileId,
                  onTracksUpdated: onTracksUpdated,
                ),
              ),
              IconButton(
                onPressed: () => onDelete(track),
                icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                tooltip: l10n.customsTrackDeleteDialogTitle,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.crimson.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
