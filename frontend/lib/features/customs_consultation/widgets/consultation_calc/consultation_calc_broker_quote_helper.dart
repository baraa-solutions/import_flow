import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/localization/stored_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';
import '../../../customs_clearance_quotations/providers/customs_clearance_quotations_provider.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';
import '../broker_quotation_comparison_table.dart';

/// Helper for Broker price list loading and quotation comparison dialogues.
class ConsultationCalcBrokerQuoteHelper {
  /// Loads the active price list for a broker or falls back to master expense catalog.
  static Future<void> loadBrokerPriceList({
    required WidgetRef ref,
    required int brokerId,
    required List<CustomsBrokerQuoteItemModel> quoteItems,
    required void Function({
      required int? priceListId,
      required String? priceListTitle,
    }) onPriceListLoaded,
    required void Function(bool isLoading) setLoading,
    bool preserveExisting = false,
  }) async {
    if (preserveExisting && quoteItems.isNotEmpty) return;

    setLoading(true);
    try {
      final activePl = await ref
          .read(brokerPriceListsProvider.notifier)
          .getActivePriceListForBroker(brokerId);

      if (activePl != null && activePl.items.isNotEmpty) {
        quoteItems.clear();
        for (final itm in activePl.items) {
          final isApplicable = itm.standardPrice > 0;
          quoteItems.add(CustomsBrokerQuoteItemModel(
            expenseTypeId: itm.expenseTypeId,
            expenseName: itm.expenseName,
            category: itm.category,
            unitType: itm.unitType,
            unitPrice: itm.standardPrice,
            currency: itm.currency,
            qty: 1.0,
            isApplicable: isApplicable,
            totalAmount: isApplicable ? (itm.standardPrice * 1.0) : 0.0,
            notes: itm.notes,
          ));
        }
        onPriceListLoaded(
          priceListId: activePl.priceListId,
          priceListTitle: activePl.title,
        );
      } else {
        final catalog =
            ref.read(clearanceExpenseTypesProvider).valueOrNull ?? [];
        quoteItems.clear();
        for (final exp in catalog) {
          quoteItems.add(CustomsBrokerQuoteItemModel(
            expenseTypeId: exp.expenseId,
            expenseName: exp.nameAr,
            category: DomainEnums.isCode(
                    DomainEnumType.brokerExpenseCategory, exp.category)
                ? DomainEnums.englishLabel(
                    DomainEnumType.brokerExpenseCategory, exp.category)
                : exp.category,
            unitType: DomainEnums.isCode(
                    DomainEnumType.brokerUnit, exp.defaultUnit)
                ? DomainEnums.englishLabel(
                    DomainEnumType.brokerUnit, exp.defaultUnit)
                : exp.defaultUnit,
            unitPrice: 0.0,
            currency: exp.defaultCurrency,
            qty: 1.0,
            isApplicable: false,
            totalAmount: 0.0,
          ));
        }
        onPriceListLoaded(
          priceListId: null,
          priceListTitle: storedText.customPriceListNoRegisteredTitle,
        );
      }
    } catch (e) {
      debugPrint('Error loading broker price list: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Opens the dialog to compare quotation submissions across multiple clearance brokers.
  static void openBrokerQuotationComparisonDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int? selectedImportFileId,
    required int? selectedBrokerId,
    required void Function(int brokerId) onBrokerSelected,
  }) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl ||
        Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final rfqsState = ref.read(customsClearanceQuotationsProvider);
    final rfqs = rfqsState.valueOrNull ?? [];

    List<CustomsClearanceQuotationItemModel> comparisonQuotes = [];
    String? rfqCode;
    String? rfqTitle;

    if (selectedImportFileId != null) {
      final matchingRfqs =
          rfqs.where((r) => r.importFileId == selectedImportFileId).toList();
      if (matchingRfqs.isNotEmpty) {
        final rfq = matchingRfqs.first;
        comparisonQuotes = rfq.quotations;
        rfqCode = rfq.rfqCode;
        rfqTitle = rfq.title;
      }
    }

    if (comparisonQuotes.isEmpty) {
      for (final rfq in rfqs) {
        comparisonQuotes.addAll(rfq.quotations);
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1000, maxHeight: 700),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: BrokerQuotationComparisonTable(
                          quotations: comparisonQuotes,
                          rfqCode: rfqCode,
                          rfqTitle: rfqTitle,
                          selectedBrokerId: selectedBrokerId,
                          onSelectQuote: (quote) {
                            onBrokerSelected(quote.providerId);
                            Navigator.of(dialogCtx).pop();
                            AppTheme.snackBar(
                              context,
                              '✅ ${l.clearanceQuotesAwardedBannerPrefix}: ${quote.providerName}',
                              severity: AppSeverity.success,
                            );
                          },
                          onAward: (quotationId) async {
                            final matchingRfq = rfqs.firstWhere(
                              (r) => r.quotations
                                  .any((q) => q.quotationId == quotationId),
                              orElse: () => rfqs.first,
                            );
                            try {
                              await ref
                                  .read(
                                      customsClearanceQuotationsProvider.notifier)
                                  .awardQuotation(
                                      matchingRfq.rfqId, quotationId);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }
                              if (context.mounted) {
                                AppTheme.snackBar(
                                  context,
                                  '✅ ${l.clearanceQuotesStatusAwarded}',
                                  severity: AppSeverity.success,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppTheme.snackBar(
                                  context,
                                  '❌ ${ApiErrorText.of(context.l10n, e)}',
                                  severity: AppSeverity.danger,
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppButton(
                          label: l.close,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
