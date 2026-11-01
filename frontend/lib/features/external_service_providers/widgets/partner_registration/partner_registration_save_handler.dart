import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/change_diff_dialog.dart';
import '../../models/partner_model.dart';
import '../../providers/partners_provider.dart';

class PartnerRegistrationSaveHandler {
  PartnerRegistrationSaveHandler._();

  static Future<String?> save({
    required BuildContext context,
    required WidgetRef ref,
    required PartnerModel? partnerToEdit,
    required Set<String> selectedCategories,
    required String name,
    required String taxId,
    required String reg,
    required String license,
    required String authorizedPorts,
    required String transportLicense,
    required String fleetTypes,
    required String coverageAreas,
    required String insuranceLicense,
    required String insuranceCoverage,
    required String scac,
    required String defaultFreeDays,
    required String paymentTerms,
    required String creditLimit,
    required String tracking,
    required String fiata,
    required String shippingModes,
    required String supportedCurrencies,
    required String accreditation,
    required String inspectionScope,
    required String swift,
    required String bankCode,
    required String branch,
    required String phone,
    required String mobile,
    required String fax,
    required String email,
    required String secondaryEmail,
    required String website,
    required String address,
    required String country,
  }) async {
    final l10n = context.l10n;

    final isBank = selectedCategories.contains('Bank');
    final isShippingLine = selectedCategories.contains('Shipping Line');
    final isCustomsBroker = selectedCategories.contains('Customs Broker');
    final isFreightForwarder = selectedCategories.contains('Freight Forwarder');
    final isInspectionAgency = selectedCategories.contains('Inspection Agency');
    final isInlandTransport = selectedCategories.contains('Inland Transport');
    final isInsuranceCompany = selectedCategories.contains('Insurance Company');

    final partnerTypeJoined = selectedCategories.join(', ');
    final isEditing = partnerToEdit != null;

    final partner = PartnerModel(
      providerId: partnerToEdit?.providerId,
      partnerCode: partnerToEdit?.partnerCode ?? '',
      partnerName: name.trim(),
      partnerType: partnerTypeJoined,
      taxId: taxId.trim().isEmpty ? null : taxId.trim(),
      commercialRegister: reg.trim().isEmpty ? null : reg.trim(),
      clearanceLicenseNumber: isCustomsBroker
          ? (license.trim().isEmpty ? null : license.trim())
          : null,
      authorizedPorts: isCustomsBroker
          ? (authorizedPorts.trim().isEmpty ? null : authorizedPorts.trim())
          : null,
      transportLicenseNumber: isInlandTransport
          ? (transportLicense.trim().isEmpty ? null : transportLicense.trim())
          : null,
      fleetTypes: isInlandTransport
          ? (fleetTypes.trim().isEmpty ? null : fleetTypes.trim())
          : null,
      coverageAreas: isInlandTransport
          ? (coverageAreas.trim().isEmpty ? null : coverageAreas.trim())
          : null,
      insuranceLicenseNumber: isInsuranceCompany
          ? (insuranceLicense.trim().isEmpty ? null : insuranceLicense.trim())
          : null,
      insuranceCoverageTypes: isInsuranceCompany
          ? (insuranceCoverage.trim().isEmpty ? null : insuranceCoverage.trim())
          : null,
      scacCode: isShippingLine
          ? (scac.trim().isEmpty ? null : scac.trim())
          : null,
      trackingUrl: tracking.trim().isEmpty ? null : tracking.trim(),
      defaultFreeDays: (isShippingLine || isFreightForwarder)
          ? int.tryParse(defaultFreeDays.trim())
          : null,
      paymentTerms:
          paymentTerms.trim().isEmpty ? null : paymentTerms.trim(),
      creditLimit: double.tryParse(creditLimit.trim()) ??
          (partnerToEdit?.creditLimit ?? 0.0),
      fiataId: isFreightForwarder
          ? (fiata.trim().isEmpty ? null : fiata.trim())
          : null,
      shippingModes: isFreightForwarder
          ? (shippingModes.trim().isEmpty ? null : shippingModes.trim())
          : null,
      supportedCurrencies: isFreightForwarder
          ? (supportedCurrencies.trim().isEmpty
              ? null
              : supportedCurrencies.trim())
          : null,
      inspectionAccreditationNumber: isInspectionAgency
          ? (accreditation.trim().isEmpty ? null : accreditation.trim())
          : null,
      inspectionScope: isInspectionAgency
          ? (inspectionScope.trim().isEmpty ? null : inspectionScope.trim())
          : null,
      swiftCode:
          isBank ? (swift.trim().isEmpty ? null : swift.trim()) : null,
      bankCode: isBank ? (bankCode.trim().isEmpty ? null : bankCode.trim()) : null,
      branchName: isBank ? (branch.trim().isEmpty ? null : branch.trim()) : null,
      email: email.trim().isEmpty ? null : email.trim(),
      secondaryEmail:
          secondaryEmail.trim().isEmpty ? null : secondaryEmail.trim(),
      phone: phone.trim().isEmpty ? null : phone.trim(),
      mobile: mobile.trim().isEmpty ? null : mobile.trim(),
      fax: fax.trim().isEmpty ? null : fax.trim(),
      website: website.trim().isEmpty ? null : website.trim(),
      address: address.trim().isEmpty ? null : address.trim(),
      country: country.trim(),
      isActive: partnerToEdit?.isActive ?? true,
    );

    if (isEditing && partnerToEdit.providerId != null) {
      final List<FieldChangeItem> changes = [];
      if (FieldChangeItem.isDifferent(
          partnerToEdit.partnerName, partner.partnerName)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerName,
            oldValue: partnerToEdit.partnerName,
            newValue: partner.partnerName));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.partnerType, partner.partnerType)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerType,
            oldValue: partnerToEdit.partnerType,
            newValue: partner.partnerType));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.fiataId, partner.fiataId)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.fiataLicenseLabel,
            oldValue: partnerToEdit.fiataId ?? '—',
            newValue: partner.fiataId ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.shippingModes, partner.shippingModes)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.shippingModesLabel,
            oldValue: partnerToEdit.shippingModes ?? '—',
            newValue: partner.shippingModes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.supportedCurrencies, partner.supportedCurrencies)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.supportedCurrenciesLabel,
            oldValue: partnerToEdit.supportedCurrencies ?? '—',
            newValue: partner.supportedCurrencies ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.inspectionAccreditationNumber,
          partner.inspectionAccreditationNumber)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.inspectionAccreditationNumLabel,
            oldValue: partnerToEdit.inspectionAccreditationNumber ?? '—',
            newValue: partner.inspectionAccreditationNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.inspectionScope, partner.inspectionScope)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.inspectionScopeLabel,
            oldValue: partnerToEdit.inspectionScope ?? '—',
            newValue: partner.inspectionScope ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.clearanceLicenseNumber,
          partner.clearanceLicenseNumber)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.customsClearanceLicenseNumLabel,
            oldValue: partnerToEdit.clearanceLicenseNumber ?? '—',
            newValue: partner.clearanceLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.authorizedPorts, partner.authorizedPorts)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.authorizedPortsLabel,
            oldValue: partnerToEdit.authorizedPorts ?? '—',
            newValue: partner.authorizedPorts ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.transportLicenseNumber,
          partner.transportLicenseNumber)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.transportLicenseNumLabel,
            oldValue: partnerToEdit.transportLicenseNumber ?? '—',
            newValue: partner.transportLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.fleetTypes, partner.fleetTypes)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.fleetTypesLabel,
            oldValue: partnerToEdit.fleetTypes ?? '—',
            newValue: partner.fleetTypes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.coverageAreas, partner.coverageAreas)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.coverageAreasLabel,
            oldValue: partnerToEdit.coverageAreas ?? '—',
            newValue: partner.coverageAreas ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.insuranceLicenseNumber,
          partner.insuranceLicenseNumber)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.insuranceLicenseNumLabel,
            oldValue: partnerToEdit.insuranceLicenseNumber ?? '—',
            newValue: partner.insuranceLicenseNumber ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.insuranceCoverageTypes,
          partner.insuranceCoverageTypes)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.insuranceCoverageTypesLabel,
            oldValue: partnerToEdit.insuranceCoverageTypes ?? '—',
            newValue: partner.insuranceCoverageTypes ?? '—'));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.email, partner.email)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerEmail,
            oldValue: partnerToEdit.email,
            newValue: partner.email));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.phone, partner.phone)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerPhone,
            oldValue: partnerToEdit.phone,
            newValue: partner.phone));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.address, partner.address)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerAddress,
            oldValue: partnerToEdit.address,
            newValue: partner.address));
      }
      if (FieldChangeItem.isDifferent(
          partnerToEdit.country, partner.country)) {
        changes.add(FieldChangeItem(
            fieldName: l10n.diffPartnerCountry,
            oldValue: partnerToEdit.country,
            newValue: partner.country));
      }

      if (changes.isNotEmpty) {
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: l10n.diffConfirmPartnerTitle,
          itemReference:
              '${partnerToEdit.partnerCode} (${partnerToEdit.partnerName})',
          changes: changes,
        );
        if (!confirmed) {
          return 'cancelled';
        }
      }

      return await ref
          .read(partnersProvider.notifier)
          .updatePartner(partnerToEdit.providerId!, partner);
    } else {
      return await ref.read(partnersProvider.notifier).createPartner(partner);
    }
  }
}
