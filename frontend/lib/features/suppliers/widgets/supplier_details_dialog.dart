import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import 'details_dialog/supplier_details_action_toolbar.dart';
import 'details_dialog/supplier_details_banking_section.dart';
import 'details_dialog/supplier_details_compliance_section.dart';
import 'details_dialog/supplier_details_contact_certs_section.dart';
import 'details_dialog/supplier_details_header.dart';

class SupplierDetailsDialog extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback? onEdit;

  const SupplierDetailsDialog({
    super.key,
    required this.supplier,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    SupplierModel supplier, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SupplierDetailsDialog(supplier: supplier, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 780),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header Banner
              SupplierDetailsHeader(supplier: supplier),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SupplierDetailsComplianceSection(supplier: supplier),
                      const SizedBox(height: 18),
                      SupplierDetailsBankingSection(supplier: supplier),
                      const SizedBox(height: 18),
                      SupplierDetailsContactCertsSection(supplier: supplier),
                    ],
                  ),
                ),
              ),

              // Action Toolbar
              SupplierDetailsActionToolbar(supplier: supplier, onEdit: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}
