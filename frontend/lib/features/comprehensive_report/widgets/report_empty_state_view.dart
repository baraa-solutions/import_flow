import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Empty state placeholder view when no shipment file is selected in the Comprehensive Report.
class ReportEmptyState extends StatelessWidget {
  final VoidCallback? onSelectFile;

  const ReportEmptyState({
    super.key,
    this.onSelectFile,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: AppTheme.charcoal.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_outlined,
                  size: 38,
                  color: AppTheme.cobalt,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.compReportEmptyStatePrompt,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'يرجى اختيار رقم الشحنة أو كود الملف من القائمة المنسدلة أعلاه لبدء استعراض التقرير الشامل والمستندات.'
                    : 'Please select an import file from the dropdown above to load the comprehensive operational dossier.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  buildBadge(Icons.inventory_2_outlined, isAr ? 'أوامر الشراء والتوريد' : 'Purchase Orders'),
                  buildBadge(Icons.directions_boat_outlined, isAr ? 'الحاويات والتتبع' : 'Containers & ETA'),
                  buildBadge(Icons.gavel_outlined, isAr ? 'الإفراج الجمركي والمطابقة' : 'Customs Clearance'),
                  buildBadge(Icons.receipt_long_outlined, isAr ? 'التكلفة والمصروفات' : 'Landed Cost'),
                ],
              ),
              if (onSelectFile != null) ...[
                const SizedBox(height: 24),
                AppButton(
                  label: isAr ? 'اختيار ملف استيراد' : 'Select Import File',
                  icon: Icons.search,
                  onPressed: onSelectFile,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.cobalt),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
