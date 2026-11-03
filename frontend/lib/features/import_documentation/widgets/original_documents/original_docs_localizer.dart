import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';

/// Central localization and formatting helper for Original Documents Collection.
/// Strictly enforces Pure View Separation & Anti-Stacking rules (no bilingual parentheses).
class OriginalDocsLocalizer {
  static String formatDateTime(DateTime dt) {
    final str = dt.toIso8601String();
    if (str.length >= 16) {
      return str.substring(0, 16).replaceAll('T', ' ');
    }
    return str;
  }

  static String getDocCategoryLabel(BuildContext context, String category) {
    final l = context.l10n;
    switch (category) {
      case 'Commercial':
        return l.docCatCommercial;
      case 'Certificate':
        return l.docCatCertificate;
      case 'Shipping':
        return l.docCatShipping;
      case 'Egypt Import':
        return l.docCatEgyptImport;
      case 'Banking':
        return l.docCatBanking;
      case 'Regulatory':
        return l.docCatRegulatory;
      case 'Other':
        return l.docCatOther;
      default:
        return category;
    }
  }

  static String getCourierCompanyLabel(BuildContext context, String company) {
    final l = context.l10n;
    switch (company) {
      case 'DHL':
        return l.courierCompanyDhl;
      case 'FedEx':
        return l.courierCompanyFedex;
      case 'Aramex':
        return l.courierCompanyAramex;
      case 'UPS':
        return l.courierCompanyUps;
      case 'Naqel':
        return l.courierCompanyNaqel;
      case 'SMSA':
        return l.courierCompanySmsa;
      case 'Hand Delivery':
        return l.courierCompanyHandDelivery;
      case 'Other':
        return l.courierCompanyOther;
      default:
        return company;
    }
  }

  static String getResponsiblePartyLabel(BuildContext context, String party) {
    final l = context.l10n;
    switch (party) {
      case 'Supplier':
        return l.partySupplier;
      case 'Freight Forwarder':
        return l.partyFreightForwarder;
      case 'Customs Broker':
        return l.partyCustomsBroker;
      case 'Bank':
        return l.partyBank;
      case 'Importer':
        return l.partyImporter;
      case 'Carrier':
      case 'Shipping Line':
        return l.partyCarrier;
      default:
        return party;
    }
  }

  static String getStatusLabel(BuildContext context, String status) {
    final l = context.l10n;
    switch (status) {
      case 'Verified':
        return l.statusBadgeVerified;
      case 'Received':
        return l.statusBadgeReceived;
      case 'In Transit':
        return l.statusBadgeInTransit;
      case 'Discrepant':
        return l.statusBadgeDiscrepant;
      case 'DRAFT':
        return l.filterStatusDraft;
      case 'PARTIALLY_RECEIVED':
        return l.filterStatusPartiallyReceived;
      case 'FULLY_RECEIVED':
        return l.filterStatusFullyReceived;
      case 'FULLY_VERIFIED':
        return l.filterStatusFullyVerified;
      case 'Pending':
      default:
        return l.statusBadgePending;
    }
  }

  static String getRegistryStatusFilterLabel(BuildContext context, String filter) {
    final l = context.l10n;
    switch (filter) {
      case 'All':
        return l.filterStatusAll;
      case 'DRAFT':
        return l.filterStatusDraft;
      case 'PARTIALLY_RECEIVED':
        return l.filterStatusPartiallyReceived;
      case 'FULLY_RECEIVED':
        return l.filterStatusFullyReceived;
      case 'FULLY_VERIFIED':
        return l.filterStatusFullyVerified;
      default:
        return filter;
    }
  }

  static String getRequirementLabel(BuildContext context, String req) {
    final l = context.l10n;
    switch (req) {
      case 'Yes':
        return l.reqBadgeYes;
      case 'Conditional':
        return l.reqBadgeConditional;
      case 'No':
      default:
        return l.reqBadgeNo;
    }
  }

  static Widget buildRequiredBadge(BuildContext context, String req) {
    final l = context.l10n;
    Color bg = AppTheme.borderOf(context);
    Color fg = AppTheme.textPrimaryOf(context);
    String label = l.reqBadgeNo;
    if (req == 'Yes') {
      bg = AppTheme.severityBackgroundOf(context, AppSeverity.danger);
      fg = AppTheme.severityForegroundOf(context, AppSeverity.danger);
      label = l.reqBadgeYes;
    } else if (req == 'Conditional') {
      bg = AppTheme.severityBackgroundOf(context, AppSeverity.warning);
      fg = AppTheme.severityForegroundOf(context, AppSeverity.warning);
      label = l.reqBadgeConditional;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  static Widget buildStatusBadge(BuildContext context, String status) {
    return AppStatusBadge.fromStatus(
      status: status,
      label: getStatusLabel(context, status),
    );
  }
}
