import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/supplier_model.dart';
import '../../providers/suppliers_provider.dart';

class SupplierFormSubmitHelper {
  static Future<bool> submit({
    required BuildContext context,
    required WidgetRef ref,
    required SupplierModel? supplierToEdit,
    required SupplierModel supplier,
  }) async {
    final l10n = context.l10n;
    final isEditing = supplierToEdit != null;

    String? errorMessage;
    if (isEditing && supplierToEdit.supplierId != null) {
      final List<FieldChangeItem> changes = [];
      if (FieldChangeItem.isDifferent(supplierToEdit.companyName, supplier.companyName)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCompanyName, oldValue: supplierToEdit.companyName, newValue: supplier.companyName));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.supplierType, supplier.supplierType)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierType, oldValue: supplierToEdit.supplierType, newValue: supplier.supplierType));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.registrationType, supplier.registrationType)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierRegType, oldValue: supplierToEdit.registrationType, newValue: supplier.registrationType));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.hasWipo, supplier.hasWipo)) {
        changes.add(FieldChangeItem(fieldName: 'WIPO Madrid', oldValue: supplierToEdit.hasWipo ? 'نعم' : 'لا', newValue: supplier.hasWipo ? 'نعم' : 'لا'));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.hasIso9001, supplier.hasIso9001)) {
        changes.add(FieldChangeItem(fieldName: 'ISO 9001', oldValue: supplierToEdit.hasIso9001 ? 'نعم' : 'لا', newValue: supplier.hasIso9001 ? 'نعم' : 'لا'));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterId, supplier.foreignExporterId)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffForeignExporterId, oldValue: supplierToEdit.foreignExporterId, newValue: supplier.foreignExporterId));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.cargoxPlatformId, supplier.cargoxPlatformId)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffCargoXId, oldValue: supplierToEdit.cargoxPlatformId ?? '', newValue: supplier.cargoxPlatformId ?? ''));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.foreignExporterCountry, supplier.foreignExporterCountry)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierCountry, oldValue: supplierToEdit.foreignExporterCountry, newValue: supplier.foreignExporterCountry));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.email, supplier.email)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierEmail, oldValue: supplierToEdit.email, newValue: supplier.email));
      }
      if (FieldChangeItem.isDifferent(supplierToEdit.phone, supplier.phone)) {
        changes.add(FieldChangeItem(fieldName: l10n.diffSupplierPhone, oldValue: supplierToEdit.phone, newValue: supplier.phone));
      }

      if (changes.isNotEmpty) {
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: l10n.diffConfirmSupplierTitle,
          itemReference: '${supplierToEdit.supplierCode} (${supplierToEdit.companyName})',
          changes: changes,
        );
        if (!confirmed) return false;
      }

      errorMessage = await ref.read(suppliersProvider.notifier).updateSupplier(supplierToEdit.supplierId!, supplier);
    } else {
      errorMessage = await ref.read(suppliersProvider.notifier).createSupplier(supplier);
    }

    if (errorMessage == null) {
      if (context.mounted) {
        Navigator.pop(context);
      }
      return true;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.crimson,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}
