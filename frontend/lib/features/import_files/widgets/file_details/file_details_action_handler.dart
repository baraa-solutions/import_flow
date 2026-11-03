// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';
import '../../../customs_tariff/widgets/duty_calculator_dialog.dart';
import '../../../financial_settlement/widgets/estimated_landed_cost_dialog.dart';
import '../../../financial_approval/widgets/supplier_advance_payment_dialog.dart';
import '../../../customs_clearance/widgets/delivery_order_payment_dialog.dart';
import '../../../customs_clearance/widgets/final_duty_assessment_dialog.dart';
import '../../../customs_clearance/widgets/customs_duty_payment_dialog.dart';
import '../../../customs_clearance/widgets/clearance_expenses_dialog.dart';
import '../../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../../../financial_settlement/widgets/final_settlement_invoices_dialog.dart';
import '../../../financial_settlement/widgets/actual_landed_cost_dialog.dart';
import '../../../comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';
import '../../../import_documentation/screens/nafeza_acid_screen.dart';
import '../../../import_documentation/screens/bank_form4_screen.dart';
import '../../../import_documentation/screens/shipment_draft_docs_screen.dart';
import '../../../freight_booking/screens/freight_booking_screen.dart';
import '../../../freight_booking/models/freight_booking_model.dart';
import '../../../freight_booking/providers/freight_booking_provider.dart';
import '../../../freight_booking/widgets/departure_confirmation_dialog.dart';
import '../../../demurrage_detention/widgets/free_days_agreement_dialog.dart';
import '../../../import_documentation/widgets/draft_bl_review_dialog.dart';
import '../../../cargox/widgets/cargox_hub_dialog.dart';
import '../../../import_documentation/widgets/original_documents_collection_dialog.dart';
import '../../../customs_clearance/widgets/customs_broker_authorization_dialog.dart';
import '../../../customs_clearance/widgets/customs_declaration_46_dialog.dart';
import '../../../customs_clearance/widgets/customs_inspection_sampling_dialog.dart';
import '../../../customs_clearance/widgets/customs_final_release_dialog.dart';
import '../../../inland_transport/widgets/inland_transport_dialog.dart';
import '../../../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../../../warehouse_receiving/screens/warehouse_receiving_screen.dart';
import '../../../warehouse_receiving/widgets/warehouse_inspection_dialog.dart';
import '../../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../../warehouse_receiving/providers/warehouse_receiving_provider.dart';
import '../../../demurrage_detention/widgets/empty_container_return_dialog.dart';
import '../../../comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart';
import '../../../file_closure/widgets/official_file_closure_dialog.dart';
import '../../../smart_checklists/widgets/smart_checklist_dialog.dart';
import '../../../experience_guide/widgets/add_guide_entry_dialog.dart';
import 'file_details_menus.dart';

/// Centralized action handler for Import File actions and simulations.
class FileDetailsActionHandler {
  static void handleSimulationAction(
    BuildContext context,
    WidgetRef ref,
    ImportFileModel file,
    String action,
  ) {
    switch (action) {
      case 'customs_sim':
        showDutyCalculatorDialog(context, ref, initialImportFileId: file.importFileId);
        break;
      case 'fn01_advance':
        showSupplierAdvancePaymentDialog(
          context,
          ref,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
          fileTitle: file.displayName,
          supplierId: file.supplierId,
          supplierName: file.supplierName,
          projectId: file.projectIds.isNotEmpty ? file.projectIds.first : null,
          totalAmountForeign: file.estimatedCost > 0 ? file.estimatedCost : null,
          currency: file.estimatedCostCurrency.isNotEmpty ? file.estimatedCostCurrency : 'USD',
        );
        break;
      case 'landed_cost_sim':
        showEstimatedLandedCostDialog(context, ref, importFileId: file.importFileId);
        break;
      case 'cs02_delivery_order':
        DeliveryOrderPaymentDialog.show(context, file);
        break;
      case 'cl02_duty_assessment':
        FinalDutyAssessmentDialog.show(context, file);
        break;
      case 'cl03_duty_payment':
        CustomsDutyPaymentDialog.show(context, file);
        break;
      case 'cl05_clearance_invoices':
        ClearanceExpensesDialog.show(context, file);
        break;
      case 'lsi_partner_invoices':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => LogisticsInvoicesScreen(
              initialShipmentId: file.importFileId,
              initialBlNumber: null,
            ),
          ),
        );
        break;
      case 'clo01_settlement':
        FinalSettlementInvoicesDialog.show(
          context,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
        );
        break;
      case 'clo02_actual_landed':
        ActualLandedCostDialog.show(
          context,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
        );
        break;
      case 'audit_timeline_radar':
        showShipmentAuditTimelineDialog(context, importFileId: file.importFileId);
        break;
      default:
        break;
    }
  }

  static void handleDocumentAction(
    BuildContext context,
    WidgetRef ref,
    ImportFileModel file,
    String action, {
    VoidCallback? onGuideReload,
  }) {
    switch (action) {
      case 'dc01_acid':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NafezaAcidScreen(
              initialImportFileId: file.importFileId,
              initialSubTab: (file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING') ? 3 : 0,
            ),
          ),
        );
        break;
      case 'dc03_bank':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BankForm4Screen(
              initialImportFileId: file.importFileId,
              initialSubTab: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING') ? 1 : 0,
            ),
          ),
        );
        break;
      case 'dc04_matrix':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShipmentDraftDocsScreen(
              initialImportFileId: file.importFileId,
              initialSubTab: 0,
            ),
          ),
        );
        break;
      case 'bk01_booking':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FreightBookingScreen(
              initialImportFileId: file.importFileId,
            ),
          ),
        );
        break;
      case 'bk02_free_days':
        FreeDaysAgreementDialog.show(
          context,
          initialImportFileId: file.importFileId,
          initialDemurrageDays: file.targetFreeDays,
        );
        break;
      case 'sh01_sailing':
        final bookings = ref.read(freightBookingProvider).value ?? [];
        final linkedBooking = bookings.firstWhere(
          (b) => b.importFileId == file.importFileId,
          orElse: () => ShipmentBookingModel(
            bookingId: 0,
            bookingCode: 'NEW-BKG',
            importFileId: file.importFileId,
            importFileCode: file.importFileCode,
            createdAt: '',
            updatedAt: '',
          ),
        );
        if (linkedBooking.bookingId > 0) {
          DepartureConfirmationDialog.show(context, linkedBooking);
        } else {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              isAr ? 'يرجى إنشاء وتأكيد حجز الشحن (BK-01) أولاً من شاشة حجز الشحن لتسجيل الإبحار' : 'Please create and confirm freight booking (BK-01) first to record departure',
              severity: AppSeverity.warning,
            ),
          );
        }
        break;
      case 'sh02_draft_bl':
        DraftBLReviewDialog.show(context, file);
        break;
      case 'sh03_cargox':
        CargoXHubDialog.show(context, file);
        break;
      case 'sh04_original_docs':
        OriginalDocumentsCollectionDialog.show(context, file);
        break;
      case 'cs01_broker_auth':
        CustomsBrokerAuthorizationDialog.show(context, file);
        break;
      case 'cs03_declaration_46':
        CustomsDeclaration46Dialog.show(context, file);
        break;
      case 'cl01_inspection':
        CustomsInspectionSamplingDialog.show(context, file);
        break;
      case 'cl04_final_release':
        CustomsFinalReleaseDialog.show(context, file);
        break;
      case 'tr01_inland_transport':
        InlandTransportDialog.show(context, file);
        break;
      case 'tr02_demurrage_radar':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const DemurrageDetentionScreen(),
          ),
        );
        break;
      case 'tr03_warehouse_receiving':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const WarehouseReceivingScreen(),
          ),
        );
        break;
      case 'tr04_warehouse_inspection':
        final recs = ref.read(warehouseReceivingProvider).valueOrNull ?? [];
        final matching = recs.where((r) => r.importFileId == file.importFileId).toList();
        final calculatedQty = file.packingListsData.isNotEmpty
            ? file.packingListsData.fold<int>(0, (sum, pl) => sum + pl.totalPackages)
            : 100;
        final targetRec = matching.isNotEmpty
            ? matching.first
            : WarehouseReceivingModel(
                receivingId: file.importFileId,
                grnCode: 'GRN-',
                importFileId: file.importFileId,
                warehouseName: 'Main Warehouse - Cairo',
                arrivalDatetime: DateTime.now().toIso8601String(),
                totalInvoicedQty: calculatedQty > 0 ? calculatedQty : 100,
                totalAcceptedQty: calculatedQty > 0 ? calculatedQty : 100,
                totalShortageQty: 0,
                totalDamagedQty: 0,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );
        WarehouseInspectionDialog.show(context, record: targetRec, importFileCode: file.importFileCode);
        break;
      case 'tr05_empty_return':
        EmptyContainerReturnDialog.show(
          context,
          initialImportFileId: file.importFileId,
          initialEirNumber: file.emptyContainersEirNumbers,
          initialDepotName: file.emptyContainersDepotName,
        );
        break;
      case 'clo03_dossier':
        ComprehensiveDossierExportDialog.show(
          context,
          file: file,
        );
        break;
      case 'clo04_official_closure':
        OfficialFileClosureDialog.show(
          context,
          file: file,
        );
        break;
      case 'smart_checklist':
        SmartChecklistDialog.show(context, file);
        break;
      case 'add_kb_note':
        showDialog(
          context: context,
          builder: (ctx) => AddGuideEntryDialog(
            initialSupplier: file.supplierName,
            initialHsCode: file.hsCode,
            initialCategory: file.productCategory,
            initialDestinationPort: file.portOfDischarge,
            initialIncoterm: file.incotermCode,
            initialImportFileReference: file.importFileCode,
            onSuccess: () => onGuideReload?.call(),
          ),
        );
        break;
      default:
        break;
    }
  }

  static Widget buildModelsAndSimulationsMenu({
    required BuildContext context,
    required ImportFileModel file,
    required bool isAr,
    required bool isDark,
    required void Function(String action) onSelected,
  }) {
    return FileDetailsMenus.buildModelsAndSimulationsMenu(
      context: context,
      file: file,
      isAr: isAr,
      isDark: isDark,
      onSelected: onSelected,
    );
  }

  static Widget buildShipmentDocumentsMenu({
    required BuildContext context,
    required ImportFileModel file,
    required bool isAr,
    required bool isDark,
    required void Function(String action) onSelected,
  }) {
    return FileDetailsMenus.buildShipmentDocumentsMenu(
      context: context,
      file: file,
      isAr: isAr,
      isDark: isDark,
      onSelected: onSelected,
    );
  }
}
