import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_tariff_model.dart';
import '../../providers/customs_tariff_provider.dart';
import '../../../../core/constants/upload_file_types.dart';

class CustomsTariffExportHelper {
  const CustomsTariffExportHelper._();

  static String buildTariffRowSummary(AppLocalizations l10n, CustomsTariffModel t) {
    final b = StringBuffer();
    b.writeln('📋 ${l10n.customsTariffScreenTitle}');
    b.writeln('${l10n.tariffCodeBadgeLabel}${t.hsCode}');
    b.writeln('${l10n.tariffTsvHeaderDescription}: ${t.hsDescription}');
    if (t.customsCategory != null && t.customsCategory!.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderCategory}: ${t.categoryLabel(l10n)}');
    }
    b.writeln('${l10n.taxRatesBreakdownSection}:');
    b.writeln('  • ${l10n.tariffTsvHeaderDutyRate}: ${t.customsDutyRate}%');
    b.writeln('  • ${l10n.tariffTsvHeaderVatRate}: ${t.vatRate}%');
    if (t.scheduleTaxRate > 0) {
      b.writeln('  • ${l10n.tariffTsvHeaderScheduleTax}: ${t.scheduleTaxRate}%');
    }
    if (t.developmentFeeRate > 0) {
      b.writeln('  • ${l10n.tariffTsvHeaderDevFee}: ${t.developmentFeeRate}%');
    }
    if (t.regulatoryAuthority != null && t.regulatoryAuthority!.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderAuthority}: ${t.regulatoryAuthority}');
    }
    final reqs = <String>[];
    if (t.requiresAcid) reqs.add('ACID');
    if (t.requiresCoo) reqs.add('COO');
    if (t.requiresInspection) reqs.add('INSP');
    if (reqs.isNotEmpty) {
      b.writeln('${l10n.tariffTsvHeaderRequirements}: ${reqs.join(", ")}');
    }
    b.writeln('${l10n.tariffTsvHeaderStatus}: ${t.isActive ? l10n.statusActive : l10n.statusInactive}');
    return b.toString().trim();
  }

  static void copySingleTariffSummary(BuildContext context, CustomsTariffModel tariff) {
    final l10n = context.l10n;
    final summary = buildTariffRowSummary(l10n, tariff);
    CopyHelper.copy(context, summary, customMessage: l10n.tariffCopySummarySuccess);
  }

  static void copyTariffsTsv(BuildContext context, List<CustomsTariffModel> tariffs) {
    final l10n = context.l10n;
    final headers = [
      l10n.tariffTsvHeaderHsCode,
      l10n.tariffTsvHeaderDescription,
      l10n.tariffTsvHeaderCategory,
      l10n.tariffTsvHeaderDutyRate,
      l10n.tariffTsvHeaderVatRate,
      l10n.tariffTsvHeaderScheduleTax,
      l10n.tariffTsvHeaderDevFee,
      l10n.tariffTsvHeaderImportFee,
      l10n.tariffTsvHeaderAuthority,
      l10n.tariffTsvHeaderRequirements,
      l10n.tariffTsvHeaderStatus,
    ];
    final rows = tariffs.map((t) {
      final reqs = <String>[];
      if (t.requiresAcid) reqs.add('ACID');
      if (t.requiresCoo) reqs.add('COO');
      if (t.requiresInspection) reqs.add('INSP');
      return [
        t.hsCode,
        t.hsDescription,
        t.categoryLabel(l10n) ?? '',
        '${t.customsDutyRate}%',
        '${t.vatRate}%',
        '${t.scheduleTaxRate}%',
        '${t.developmentFeeRate}%',
        '${t.importFeeRate}%',
        t.regulatoryAuthority ?? '',
        reqs.join(', '),
        t.isActive ? l10n.statusActive : l10n.statusInactive,
      ];
    });
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.customsTariffExportTsvSuccess);
  }

  static Future<void> handleExcelImport(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: UploadFileTypes.tariffCsvImport,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLoadingState(),
                        const SizedBox(height: 16),
                        Text(l10n.importingTariffDataset),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final summary = await ref
              .read(customsTariffProvider.notifier)
              .uploadExcelTariffs(file.bytes!, file.name);

          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            final imported = summary?['imported'] ?? 0;
            final updated = summary?['updated'] ?? 0;
            final total = summary?['total_processed'] ?? 0;

            await AppConfirmDialog.show(
              context,
              title: l10n.importCompletedTitle,
              message: l10n.importSummaryContent(total, imported, updated),
              confirmLabel: l10n.ok,
              confirmVariant: AppButtonVariant.primary,
              icon: Icons.check_circle,
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.importFailedSnack(e.toString()),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }
}
