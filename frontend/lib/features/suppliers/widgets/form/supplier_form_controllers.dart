import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/supplier_model.dart';

class SupplierFormControllers {
  final TextEditingController nameCtrl;
  String selectedSupplierType;
  String selectedRegType;
  final TextEditingController expIdCtrl;
  final TextEditingController cargoxPlatformIdCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController countryCodeCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController secondaryEmailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController mobileCtrl;
  final TextEditingController faxCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController swiftCodeCtrl;
  final TextEditingController accountNumberCtrl;
  final TextEditingController ibanCtrl;
  final TextEditingController brandsCtrl;
  final TextEditingController notesCtrl;

  bool hasIso;
  bool registeredDecree43;
  bool whiteListRegistered;

  bool hasWipo;
  final TextEditingController wipoCtrl;
  bool hasEuipo;
  final TextEditingController euipoCtrl;
  bool hasGlobalBrand;
  final TextEditingController globalBrandCtrl;
  bool hasIso9001;
  final TextEditingController iso9001Ctrl;

  SupplierFormControllers._({
    required this.nameCtrl,
    required this.selectedSupplierType,
    required this.selectedRegType,
    required this.expIdCtrl,
    required this.cargoxPlatformIdCtrl,
    required this.countryCtrl,
    required this.countryCodeCtrl,
    required this.addressCtrl,
    required this.emailCtrl,
    required this.secondaryEmailCtrl,
    required this.phoneCtrl,
    required this.mobileCtrl,
    required this.faxCtrl,
    required this.websiteCtrl,
    required this.bankNameCtrl,
    required this.swiftCodeCtrl,
    required this.accountNumberCtrl,
    required this.ibanCtrl,
    required this.brandsCtrl,
    required this.notesCtrl,
    required this.hasIso,
    required this.registeredDecree43,
    required this.whiteListRegistered,
    required this.hasWipo,
    required this.wipoCtrl,
    required this.hasEuipo,
    required this.euipoCtrl,
    required this.hasGlobalBrand,
    required this.globalBrandCtrl,
    required this.hasIso9001,
    required this.iso9001Ctrl,
  });

  factory SupplierFormControllers.fromSupplier(SupplierModel? s) {
    return SupplierFormControllers._(
      nameCtrl: TextEditingController(text: s?.companyName ?? ''),
      selectedSupplierType: s?.supplierType ?? 'Manufacturer',
      selectedRegType: s?.registrationType ?? 'Factory Registration',
      expIdCtrl: TextEditingController(text: s?.foreignExporterId ?? ''),
      cargoxPlatformIdCtrl: TextEditingController(text: s?.cargoxPlatformId ?? ''),
      countryCtrl: TextEditingController(text: s?.foreignExporterCountry ?? ''),
      countryCodeCtrl: TextEditingController(text: s?.foreignExporterCountryCode ?? ''),
      addressCtrl: TextEditingController(text: s?.address ?? ''),
      emailCtrl: TextEditingController(text: s?.email ?? ''),
      secondaryEmailCtrl: TextEditingController(text: s?.secondaryEmail ?? ''),
      phoneCtrl: TextEditingController(text: s?.phone ?? ''),
      mobileCtrl: TextEditingController(text: s?.mobile ?? ''),
      faxCtrl: TextEditingController(text: s?.fax ?? ''),
      websiteCtrl: TextEditingController(text: s?.website ?? ''),
      bankNameCtrl: TextEditingController(text: s?.bankName ?? ''),
      swiftCodeCtrl: TextEditingController(text: s?.swiftCode ?? ''),
      accountNumberCtrl: TextEditingController(text: s?.accountNumber ?? ''),
      ibanCtrl: TextEditingController(text: s?.iban ?? ''),
      brandsCtrl: TextEditingController(text: s?.brands ?? ''),
      notesCtrl: TextEditingController(text: s?.notes ?? ''),
      hasIso: s?.hasIso ?? false,
      registeredDecree43: s?.registeredDecree43 ?? false,
      whiteListRegistered: s?.whiteListRegistered ?? false,
      hasWipo: s?.hasWipo ?? false,
      wipoCtrl: TextEditingController(text: s?.wipoNumber ?? ''),
      hasEuipo: s?.hasEuipo ?? false,
      euipoCtrl: TextEditingController(text: s?.euipoNumber ?? ''),
      hasGlobalBrand: s?.hasGlobalBrand ?? false,
      globalBrandCtrl: TextEditingController(text: s?.globalBrandNumber ?? ''),
      hasIso9001: s?.hasIso9001 ?? false,
      iso9001Ctrl: TextEditingController(text: s?.iso9001Number ?? ''),
    );
  }

  void dispose() {
    nameCtrl.dispose();
    expIdCtrl.dispose();
    cargoxPlatformIdCtrl.dispose();
    countryCtrl.dispose();
    countryCodeCtrl.dispose();
    addressCtrl.dispose();
    emailCtrl.dispose();
    secondaryEmailCtrl.dispose();
    phoneCtrl.dispose();
    mobileCtrl.dispose();
    faxCtrl.dispose();
    websiteCtrl.dispose();
    bankNameCtrl.dispose();
    swiftCodeCtrl.dispose();
    accountNumberCtrl.dispose();
    ibanCtrl.dispose();
    brandsCtrl.dispose();
    notesCtrl.dispose();
    wipoCtrl.dispose();
    euipoCtrl.dispose();
    globalBrandCtrl.dispose();
    iso9001Ctrl.dispose();
  }

  Widget buildCopySuffix(BuildContext context, TextEditingController ctrl) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (_, val, __) {
        if (val.text.trim().isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
          tooltip: context.l10n.suppliersCopyFieldTooltip,
          splashRadius: 16,
          onPressed: () => CopyHelper.copy(context, val.text),
        );
      },
    );
  }

  SupplierModel buildSupplierModel(SupplierModel? supplierToEdit) {
    return SupplierModel(
      supplierId: supplierToEdit?.supplierId,
      supplierCode: supplierToEdit?.supplierCode ?? '',
      companyName: nameCtrl.text.trim(),
      supplierType: selectedSupplierType,
      registrationType: selectedRegType,
      foreignExporterId: expIdCtrl.text.trim(),
      cargoxPlatformId: cargoxPlatformIdCtrl.text.trim().isEmpty ? null : cargoxPlatformIdCtrl.text.trim(),
      foreignExporterCountry: countryCtrl.text.trim(),
      foreignExporterCountryCode: countryCodeCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
      fax: faxCtrl.text.trim().isEmpty ? null : faxCtrl.text.trim(),
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      secondaryEmail: secondaryEmailCtrl.text.trim().isEmpty ? null : secondaryEmailCtrl.text.trim(),
      website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
      bankName: bankNameCtrl.text.trim().isEmpty ? null : bankNameCtrl.text.trim(),
      swiftCode: swiftCodeCtrl.text.trim().isEmpty ? null : swiftCodeCtrl.text.trim(),
      accountNumber: accountNumberCtrl.text.trim().isEmpty ? null : accountNumberCtrl.text.trim(),
      iban: ibanCtrl.text.trim().isEmpty ? null : ibanCtrl.text.trim(),
      hasIso: hasIso,
      registeredDecree43: registeredDecree43,
      whiteListRegistered: whiteListRegistered,
      hasWipo: hasWipo,
      wipoNumber: hasWipo && wipoCtrl.text.trim().isNotEmpty ? wipoCtrl.text.trim() : null,
      hasEuipo: hasEuipo,
      euipoNumber: hasEuipo && euipoCtrl.text.trim().isNotEmpty ? euipoCtrl.text.trim() : null,
      hasGlobalBrand: hasGlobalBrand,
      globalBrandNumber: hasGlobalBrand && globalBrandCtrl.text.trim().isNotEmpty ? globalBrandCtrl.text.trim() : null,
      hasIso9001: hasIso9001,
      iso9001Number: hasIso9001 && iso9001Ctrl.text.trim().isNotEmpty ? iso9001Ctrl.text.trim() : null,
      brands: brandsCtrl.text.trim().isEmpty ? null : brandsCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      isActive: supplierToEdit?.isActive ?? true,
    );
  }
}
