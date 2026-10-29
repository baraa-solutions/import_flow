import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/localization/app_localizations.dart';

import '../../../core/services/master_data_export_service.dart';

import '../../../core/services/display_name_resolver.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/utils/import_file_po_linker.dart';

import '../../../core/widgets/widgets.dart';

import '../../import_files/models/import_file_model.dart';

import '../../import_files/providers/import_files_provider.dart';

import '../../projects/providers/projects_provider.dart';

import '../../purchase_orders/providers/purchase_orders_provider.dart';



import '../models/dynamic_report_models.dart';

import '../widgets/dynamic_report_column_picker_sheet.dart';

import '../widgets/dynamic_report_filter_toolbar.dart';



class DynamicReportBuilderScreen extends ConsumerStatefulWidget {

  const DynamicReportBuilderScreen({super.key});



  static const List<String> kEcoPresetColumnIds = [

    'scasProjectFileAcid',

    'scasExFactory',

    'scasOrderToOrigin',

    'scasPickUpDate',

    'scasDeparturePort',

    'scasArrivalAlexPort',

    'scasOrigInvoice',

    'scasOrigPackingList',

    'scasOrigCoo',

    'scasOrigBl',

    'scasOrigInsurance',

    'scasInsertNafeza',

    'scasBankForm4',

    'scasDeclare3A',

    'scasMaterialReceived',

  ];



  static const List<String> kScasPresetColumnIds = [

    'ecoBroker',

    'ecoShipmentNo',

    'ecoSupplier',

    'ecoProject',

    'ecoPiValue',

    'ecoShippingDate',

    'ecoArrivalPort',

    'ecoArrivalWarehouse',

    'ecoSara',

    'ecoMaro',

    'ecoReadyToPickUp',

    'ecoLatestUpdate',

    'ecoSwiftDate',

    'ecoSwiftAmount',

    'ecoShippingCompany',

    'ecoAcid',

  ];



  @override

  ConsumerState<DynamicReportBuilderScreen> createState() => _DynamicReportBuilderScreenState();

}



class _DynamicReportBuilderScreenState extends ConsumerState<DynamicReportBuilderScreen> {

  ReportTemplateMode _templateMode = ReportTemplateMode.eco;

  DateTime _lastUpdatedAt = DateTime.now();



  late final List<DynamicReportColumn> _masterColumns;



  String _filterMode = 'All';

  String _filterPriority = 'All';

  final String _filterStatus = 'All';

  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();



  @override

  void initState() {

    super.initState();

    _masterColumns = _buildMasterColumnCatalog();

    _refreshData();

  }



  @override

  void dispose() {

    _searchController.dispose();

    super.dispose();

  }



  void _refreshData() {

    setState(() {

      _lastUpdatedAt = DateTime.now();

    });

    Future.microtask(() {

      if (!ref.read(importFilesProvider).isLoading) {

        ref.read(importFilesProvider.notifier).fetchImportFiles();

      }

      if (!ref.read(projectsProvider).isLoading) {

        ref.read(projectsProvider.notifier).fetchProjects();

      }

      if (!ref.read(purchaseOrdersProvider).isLoading) {

        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();

      }

    });

  }



  String _formatDateTime(DateTime dt) {

    final y = dt.year.toString().padLeft(4, '0');

    final m = dt.month.toString().padLeft(2, '0');

    final d = dt.day.toString().padLeft(2, '0');

    final h = dt.hour.toString().padLeft(2, '0');

    final min = dt.minute.toString().padLeft(2, '0');

    final s = dt.second.toString().padLeft(2, '0');

    return '$y-$m-$d $h:$min:$s';

  }



  List<DynamicReportColumn> _buildMasterColumnCatalog() {

    return [

      // File & Project

      DynamicReportColumn(id: 'importFileCode', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'customFileNumber', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'companyName', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'supplierName', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'brokerName', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'projectNames', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'owner', categoryId: 'file_project', isVisible: false),

      DynamicReportColumn(id: 'status', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'currentStage', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'progressPercent', categoryId: 'file_project', isVisible: true),

      DynamicReportColumn(id: 'priority', categoryId: 'file_project', isVisible: false),

      DynamicReportColumn(id: 'nextAction', categoryId: 'file_project', isVisible: false),

      DynamicReportColumn(id: 'fileOpeningDate', categoryId: 'file_project', isVisible: false),

      DynamicReportColumn(id: 'notes', categoryId: 'file_project', isVisible: false),

      DynamicReportColumn(id: 'updatedAt', categoryId: 'file_project', isVisible: false),



      // Commercial & PO

      DynamicReportColumn(id: 'poNumber', categoryId: 'commercial_po', isVisible: false),

      DynamicReportColumn(id: 'piNumber', categoryId: 'commercial_po', isVisible: false),

      DynamicReportColumn(id: 'piValue', categoryId: 'commercial_po', isVisible: true),

      DynamicReportColumn(id: 'incotermCode', categoryId: 'commercial_po', isVisible: true),

      DynamicReportColumn(id: 'estimatedCost', categoryId: 'commercial_po', isVisible: false),



      // Shipping & Logistics

      DynamicReportColumn(id: 'shipmentMode', categoryId: 'shipping_logistics', isVisible: true),

      DynamicReportColumn(id: 'shippingLine', categoryId: 'shipping_logistics', isVisible: false),

      DynamicReportColumn(id: 'portOfLoading', categoryId: 'shipping_logistics', isVisible: false),

      DynamicReportColumn(id: 'portOfDischarge', categoryId: 'shipping_logistics', isVisible: false),

      DynamicReportColumn(id: 'cargoReadyDate', categoryId: 'shipping_logistics', isVisible: false),

      DynamicReportColumn(id: 'requiredEta', categoryId: 'shipping_logistics', isVisible: true),

      DynamicReportColumn(id: 'targetFreeDays', categoryId: 'shipping_logistics', isVisible: false),



      // Packages & CBM

      DynamicReportColumn(id: 'totalPackages', categoryId: 'packages_cbm', isVisible: false),

      DynamicReportColumn(id: 'grossWeightKg', categoryId: 'packages_cbm', isVisible: false),

      DynamicReportColumn(id: 'totalCbm', categoryId: 'packages_cbm', isVisible: false),



      // Customs & Nafeza

      DynamicReportColumn(id: 'acidNumber', categoryId: 'customs_nafeza', isVisible: true),

      DynamicReportColumn(id: 'acidIssueDate', categoryId: 'customs_nafeza', isVisible: false),

      DynamicReportColumn(id: 'acidExpiryDate', categoryId: 'customs_nafeza', isVisible: false),

      DynamicReportColumn(id: 'form46No', categoryId: 'customs_nafeza', isVisible: false),

      DynamicReportColumn(id: 'customsReleaseStatus', categoryId: 'customs_nafeza', isVisible: false),

      DynamicReportColumn(id: 'customsReleasedAt', categoryId: 'customs_nafeza', isVisible: false),



      // Banking & Swift

      DynamicReportColumn(id: 'form4No', categoryId: 'banking_swift', isVisible: true),

      DynamicReportColumn(id: 'form4ReceivedDate', categoryId: 'banking_swift', isVisible: false),

      DynamicReportColumn(id: 'swiftNo', categoryId: 'banking_swift', isVisible: false),

      DynamicReportColumn(id: 'swiftDate', categoryId: 'banking_swift', isVisible: false),

      DynamicReportColumn(id: 'swiftAmount', categoryId: 'banking_swift', isVisible: false),



      // ECO Radar (Milestone & Document Tracking - 15 Columns)

      DynamicReportColumn(id: 'scasProjectFileAcid', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasExFactory', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrderToOrigin', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasPickUpDate', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasDeparturePort', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasArrivalAlexPort', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrigInvoice', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrigPackingList', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrigCoo', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrigBl', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasOrigInsurance', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasInsertNafeza', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasBankForm4', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasDeclare3A', categoryId: 'eco_radar', isVisible: false),

      DynamicReportColumn(id: 'scasMaterialReceived', categoryId: 'eco_radar', isVisible: false),



      // SCAS Tracker (Operational & Swift Tracking - 16 Columns)

      DynamicReportColumn(id: 'ecoBroker', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoShipmentNo', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoSupplier', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoProject', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoPiValue', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoShippingDate', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoArrivalPort', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoArrivalWarehouse', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoSara', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoMaro', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoReadyToPickUp', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoLatestUpdate', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoSwiftDate', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoSwiftAmount', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoShippingCompany', categoryId: 'scas_tracker', isVisible: false),

      DynamicReportColumn(id: 'ecoAcid', categoryId: 'scas_tracker', isVisible: false),

    ];

  }



  List<DynamicReportColumn> _getActiveColumns() {

    switch (_templateMode) {

      case ReportTemplateMode.eco:

        return DynamicReportBuilderScreen.kEcoPresetColumnIds.map((id) => DynamicReportColumn(id: id, categoryId: 'eco_radar', isVisible: true)).toList();

      case ReportTemplateMode.scas:

        return DynamicReportBuilderScreen.kScasPresetColumnIds.map((id) => DynamicReportColumn(id: id, categoryId: 'scas_tracker', isVisible: true)).toList();

      case ReportTemplateMode.custom:

        return _masterColumns.where((c) => c.isVisible).toList();

    }

  }



  String _getCategoryTitle(BuildContext context, String catId) {

    final l = context.l10n;

    switch (catId) {

      case 'file_project': return l.dynCatFileAndProject;

      case 'commercial_po': return l.dynCatCommercialAndPo;

      case 'shipping_logistics': return l.dynCatShippingAndLogistics;

      case 'packages_cbm': return l.dynCatPackagesAndCbm;

      case 'customs_nafeza': return l.dynCatCustomsAndNafeza;

      case 'banking_swift': return l.dynCatBankingAndSwift;

      case 'scas_tracker': return l.dynCatScasTracking;

      case 'eco_radar': return l.dynCatEcoTracking;

      default: return catId;

    }

  }



  String _getColumnLabel(BuildContext context, String colId) {

    final l = context.l10n;

    switch (colId) {

      case 'importFileCode': return l.dynColImportFileCode;

      case 'customFileNumber': return l.dynColCustomFileNumber;

      case 'companyName': return l.dynColCompanyName;

      case 'supplierName': return l.dynColSupplierName;

      case 'brokerName': return l.dynColBrokerName;

      case 'projectNames': return l.dynColProjectNames;

      case 'owner': return l.dynColOwner;

      case 'status': return l.dynColStatus;

      case 'currentStage': return l.dynColCurrentStage;

      case 'progressPercent': return l.dynColProgressPercent;

      case 'priority': return l.dynColPriority;

      case 'nextAction': return l.dynColNextAction;

      case 'fileOpeningDate': return l.dynColFileOpeningDate;

      case 'notes': return l.dynColNotes;

      case 'updatedAt': return l.dynColUpdatedAt;

      case 'poNumber': return l.dynColPoNumber;

      case 'piNumber': return l.dynColPiNumber;

      case 'piValue': return l.dynColPiValue;

      case 'incotermCode': return l.dynColIncotermCode;

      case 'estimatedCost': return l.dynColEstimatedCost;

      case 'shipmentMode': return l.dynColShipmentMode;

      case 'shippingLine': return l.dynColShippingLine;

      case 'portOfLoading': return l.dynColPortOfLoading;

      case 'portOfDischarge': return l.dynColPortOfDischarge;

      case 'cargoReadyDate': return l.dynColCargoReadyDate;

      case 'requiredEta': return l.dynColRequiredEta;

      case 'targetFreeDays': return l.dynColTargetFreeDays;

      case 'totalPackages': return l.dynColTotalPackages;

      case 'grossWeightKg': return l.dynColGrossWeightKg;

      case 'totalCbm': return l.dynColTotalCbm;

      case 'acidNumber': return l.dynColAcidNumber;

      case 'acidIssueDate': return l.dynColAcidIssueDate;

      case 'acidExpiryDate': return l.dynColAcidExpiryDate;

      case 'form46No': return l.dynColForm46No;

      case 'customsReleaseStatus': return l.dynColCustomsReleaseStatus;

      case 'customsReleasedAt': return l.dynColCustomsReleasedAt;

      case 'form4No': return l.dynColForm4No;

      case 'form4ReceivedDate': return l.dynColForm4ReceivedDate;

      case 'swiftNo': return l.dynColSwiftNo;

      case 'swiftDate': return l.dynColSwiftDate;

      case 'swiftAmount': return l.dynColSwiftAmount;

      case 'ecoBroker': return l.dynColEcoBroker;

      case 'ecoShipmentNo': return l.dynColEcoShipmentNo;

      case 'ecoSupplier': return l.dynColEcoSupplier;

      case 'ecoProject': return l.dynColEcoProject;

      case 'ecoPiValue': return l.dynColEcoPiValue;

      case 'ecoShippingDate': return l.dynColEcoShippingDate;

      case 'ecoArrivalPort': return l.dynColEcoArrivalPort;

      case 'ecoArrivalWarehouse': return l.dynColEcoArrivalWarehouse;

      case 'ecoSara': return l.dynColEcoSara;

      case 'ecoMaro': return l.dynColEcoMaro;

      case 'ecoReadyToPickUp': return l.dynColEcoReadyToPickUp;

      case 'ecoLatestUpdate': return l.dynColEcoLatestUpdate;

      case 'ecoSwiftDate': return l.dynColEcoSwiftDate;

      case 'ecoSwiftAmount': return l.dynColEcoSwiftAmount;

      case 'ecoShippingCompany': return l.dynColEcoShippingCompany;

      case 'ecoAcid': return l.dynColEcoAcid;

      case 'scasProjectFileAcid': return l.dynColScasProjectFileAcid;

      case 'scasExFactory': return l.dynColScasExFactory;

      case 'scasOrderToOrigin': return l.dynColScasOrderToOrigin;

      case 'scasPickUpDate': return l.dynColScasPickUpDate;

      case 'scasDeparturePort': return l.dynColScasDeparturePort;

      case 'scasArrivalAlexPort': return l.dynColScasArrivalAlexPort;

      case 'scasOrigInvoice': return l.dynColScasOrigInvoice;

      case 'scasOrigPackingList': return l.dynColScasOrigPackingList;

      case 'scasOrigCoo': return l.dynColScasOrigCoo;

      case 'scasOrigBl': return l.dynColScasOrigBl;

      case 'scasOrigInsurance': return l.dynColScasOrigInsurance;

      case 'scasInsertNafeza': return l.dynColScasInsertNafeza;

      case 'scasBankForm4': return l.dynColScasBankForm4;

      case 'scasDeclare3A': return l.dynColScasDeclare3A;

      case 'scasMaterialReceived': return l.dynColScasMaterialReceived;

      default: return colId;

    }

  }



  String _getTemplateTitle(BuildContext context) {

    final l = context.l10n;

    switch (_templateMode) {

      case ReportTemplateMode.eco: return l.dynTemplateEco;

      case ReportTemplateMode.scas: return l.dynTemplateScas;

      case ReportTemplateMode.custom: return l.dynTemplateCustom;

    }

  }



  List<ImportFileModel> _filterFiles(List<ImportFileModel> files) {

    return files.where((f) {

      if (_filterMode != 'All' && f.shipmentMode != _filterMode) return false;

      if (_filterPriority != 'All' && f.priority != _filterPriority) return false;

      if (_filterStatus != 'All' && f.status != _filterStatus) return false;



      // Filter by Template Mode

      if (_templateMode == ReportTemplateMode.eco) {

        final comp = f.companyName.toLowerCase();

        final proj = (f.projectNames ?? '').toLowerCase();

        final owner = f.owner.toLowerCase();

        final notes = (f.notes ?? '').toLowerCase();

        final isEco = comp.contains('eco') || comp.contains('إيكو') || comp.contains('ايكو') ||

                      proj.contains('eco') || proj.contains('إيكو') || proj.contains('ايكو') ||

                      owner.contains('eco') || owner.contains('إيكو') || owner.contains('ايكو') ||

                      notes.contains('eco') || notes.contains('إيكو') || notes.contains('ايكو');

        if (!isEco) return false;

      } else if (_templateMode == ReportTemplateMode.scas) {

        final comp = f.companyName.toLowerCase();

        final proj = (f.projectNames ?? '').toLowerCase();

        final owner = f.owner.toLowerCase();

        final notes = (f.notes ?? '').toLowerCase();

        final isScasOrArchi = comp.contains('scas') || comp.contains('سكاس') ||

                              comp.contains('archi') || comp.contains('أركي') || comp.contains('اركي') ||

                              proj.contains('scas') || proj.contains('سكاس') ||

                              proj.contains('archi') || proj.contains('أركي') || proj.contains('اركي') ||

                              owner.contains('scas') || owner.contains('archi') ||

                              notes.contains('scas') || notes.contains('archi');

        if (!isScasOrArchi) return false;

      }



      if (_searchQuery.isNotEmpty) {

        final q = _searchQuery.toLowerCase();

        final matchCode = f.importFileCode.toLowerCase().contains(q) || (f.customFileNumber?.toLowerCase().contains(q) ?? false);

        final matchComp = f.companyName.toLowerCase().contains(q);

        final matchSup = f.supplierName.toLowerCase().contains(q);

        final matchProj = f.projectNames?.toLowerCase().contains(q) ?? false;

        final matchAcid = f.acidNumber?.toLowerCase().contains(q) ?? false;

        final matchBroker = f.brokerName?.toLowerCase().contains(q) ?? false;

        if (!matchCode && !matchComp && !matchSup && !matchProj && !matchAcid && !matchBroker) return false;

      }

      return true;

    }).toList();

  }



  String _getCellValue(ImportFileModel file, String colId) {

    final l = context.l10n;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    switch (colId) {

      // File & Project

      case 'importFileCode':

        return file.displayName;

      case 'customFileNumber':

        return file.displayName;

      case 'companyName':

        return file.companyName;

      case 'supplierName':

        return file.supplierName;

      case 'brokerName':

        return file.brokerName ?? '-';

      case 'projectNames':

        return file.projectNames ?? '-';

      case 'owner':

        return file.owner;

      case 'status':

        return file.status;

      case 'currentStage':

        return DisplayNameResolver.resolveStepName(file.currentStage, isArabic: isAr);

      case 'progressPercent':

        return '${file.progressPercent.toInt()}%';

      case 'priority':

        return file.priority;

      case 'nextAction':

        return file.displayNextAction(context.l10n);

      case 'fileOpeningDate':

        return file.fileOpeningDate ?? '-';

      case 'notes':

        return file.notes ?? '-';

      case 'updatedAt':

        return file.updatedAt.length >= 16 ? file.updatedAt.substring(0, 16) : file.updatedAt;



      // Commercial & PO

      case 'poNumber':

        if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {

          return file.poNumber!.trim();

        }

        final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;

        final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);

        if (linkedPOs.isNotEmpty) {

          return linkedPOs.map((p) => (p.poReference != null && p.poReference!.trim().isNotEmpty && p.poReference != file.customFileNumber && p.poReference != file.importFileCode) ? p.poReference! : p.poNumber).join(', ');

        }

        return (file.poIds != null && file.poIds!.isNotEmpty ? file.poIds!.join(', ') : '-');

      case 'piNumber':

        if (file.piNumber != null && file.piNumber!.trim().isNotEmpty) {

          return file.piNumber!.trim();

        }

        return file.invoicesData.isNotEmpty ? file.invoicesData.first.invoiceNo : '-';

      case 'piValue':

        return file.invoicesData.isNotEmpty

            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'

            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';

      case 'incotermCode':

        return file.incotermCode;

      case 'estimatedCost':

        return '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';



      // Shipping & Logistics

      case 'shipmentMode':

        return file.shipmentMode;

      case 'shippingLine':

        return file.selectedScenario ?? (file.shippingInstructionsNotes ?? '-');

      case 'portOfLoading':

        return file.portOfLoading ?? '-';

      case 'portOfDischarge':

        return file.portOfDischarge ?? '-';

      case 'cargoReadyDate':

        return file.cargoReadyDate ?? '-';

      case 'requiredEta':

        return file.requiredEta ?? '-';

      case 'targetFreeDays':

        return file.targetFreeDays != null ? l.dynDaysCount(file.targetFreeDays!) : '-';



      // Packages & CBM

      case 'totalPackages':

        return file.packingListsData.isNotEmpty

            ? file.packingListsData.fold<int>(0, (sum, p) => sum + p.totalPackages).toString()

            : '-';

      case 'grossWeightKg':

        return file.packingListsData.isNotEmpty

            ? l.dynGrossWeightKg(file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.grossWeightKg).toStringAsFixed(1))

            : '-';

      case 'totalCbm':

        return file.packingListsData.isNotEmpty

            ? l.dynTotalCbm(file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.cbm).toStringAsFixed(2))

            : '-';



      // Customs & Nafeza

      case 'acidNumber':

        return file.acidNumber ?? '-';

      case 'acidIssueDate':

        return file.acidIssueDate ?? '-';

      case 'acidExpiryDate':

        return file.acidExpiryDate ?? '-';

      case 'form46No':

        return file.form46No ?? '-';

      case 'customsReleaseStatus':

        return file.isCustomsReleased ? l.dynCustomsReleased : (file.status == 'Under Clearance' ? l.dynCustomsUnderClearance : file.status);

      case 'customsReleasedAt':

        return file.customsReleasedAt ?? '-';



      // Banking & Swift

      case 'form4No':

        return file.form4No ?? '-';

      case 'form4ReceivedDate':

        return file.form4ReceivedDate ?? '-';

      case 'swiftNo':

        return file.swiftNo ?? '-';

      case 'swiftDate':

        return file.swiftNo != null ? (file.form4ReceivedDate ?? file.fileOpeningDate ?? '-') : '-';

      case 'swiftAmount':

        return file.swiftNo != null

            ? (file.invoicesData.isNotEmpty

                ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'

                : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}')

            : '-';



      // ECO Specific

      case 'ecoBroker':

        return file.brokerName ?? '-';

      case 'ecoShipmentNo':

        return file.displayName;

      case 'ecoSupplier':

        return file.supplierName;

      case 'ecoProject':

        return file.projectNames ?? '-';

      case 'ecoPiValue':

        return file.invoicesData.isNotEmpty

            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'

            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';

      case 'ecoShippingDate':

        return file.cargoReadyDate != null ? '${file.cargoReadyDate} ${file.portOfLoading ?? ""}'.trim() : (file.portOfLoading ?? '-');

      case 'ecoArrivalPort':

        return file.requiredEta != null ? '${file.requiredEta} ${file.portOfDischarge ?? ""}'.trim() : (file.portOfDischarge ?? '-');

      case 'ecoArrivalWarehouse':

        return file.customsReleasedAt ?? (file.updatedAt.length >= 10 ? file.updatedAt.substring(0, 10) : '-');

      case 'ecoSara':

        // المسئول عن المشروع (Project In-Charge from shipment file)

        if (file.owner.isNotEmpty && file.owner != file.companyName) {

          return file.owner;

        }

        if (file.projectIds.isNotEmpty) {

          final projectsState = ref.read(projectsProvider);

          final pList = projectsState.value ?? [];

          for (final pid in file.projectIds) {

            final proj = pList.where((p) => p.projectId == pid).firstOrNull;

            if (proj != null && proj.projectOwner.isNotEmpty) {

              return proj.projectOwner;

            }

          }

        }

        return file.owner.isNotEmpty ? file.owner : '-';

      case 'ecoMaro':

        // مالك المشروع (Project Owner from shipment file)

        if (file.companyName.isNotEmpty) {

          return file.companyName;

        }

        return file.projectNames ?? '-';

      case 'ecoReadyToPickUp':

        return file.cargoReadyDate ?? '-';

      case 'ecoLatestUpdate':

        return file.currentStage;

      case 'ecoSwiftDate':

        return file.swiftNo != null ? (file.form4ReceivedDate ?? '-') : '-';

      case 'ecoSwiftAmount':

        return file.swiftNo != null

            ? (file.invoicesData.isNotEmpty

                ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'

                : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}')

            : '-';

      case 'ecoShippingCompany':

        return file.selectedScenario ?? file.shipmentMode;

      case 'ecoAcid':

        return file.acidNumber != null ? file.acidNumber! : '-';



      // ECO Radar / Document & Milestone Specific

      case 'scasProjectFileAcid':

        final proj = file.projectNames != null ? '${isAr ? "المشروع" : "Project"}: ${file.projectNames}' : (file.companyName.isNotEmpty ? '${isAr ? "المشروع" : "Project"}: ${file.companyName}' : (isAr ? "المشروع: عام" : "Project: General"));

        final fCode = '${isAr ? "الملف" : "File"}: ${file.displayName}';

        final acid = file.acidNumber != null ? '${isAr ? "القيد الجمركي" : "ACID"}: ${file.acidNumber}' : (isAr ? "القيد الجمركي: -" : "ACID: -");

        return '$proj\n$fCode\n$acid'.trim();

      case 'scasExFactory':

        final dateVal = file.cargoReadyDate ?? file.fileOpeningDate ?? '-';

        final valStr = file.invoicesData.isNotEmpty

            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'

            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';

        return '$dateVal\n$valStr';

      case 'scasOrderToOrigin':

        final stage = file.currentStage.toLowerCase();

        return (stage.contains('feasibility') || stage.contains('planning')) ? l.dynStatusPending : l.dynStatusDone;

      case 'scasPickUpDate':

        return file.cargoReadyDate ?? file.fileOpeningDate ?? '-';

      case 'scasDeparturePort':

        return file.fileOpeningDate ?? '-';

      case 'scasArrivalAlexPort':

        return file.requiredEta ?? '-';

      case 'scasOrigInvoice':

        return file.invoicesData.isNotEmpty

            ? '${l.dynStatusReceived}\n${file.invoicesData.first.date ?? file.invoicesData.first.invoiceNo}'

            : l.dynStatusReceived;

      case 'scasOrigPackingList':

        return file.packingListsData.isNotEmpty

            ? '${l.dynStatusReceived}\n${file.packingListsData.first.date ?? file.packingListsData.first.plNo}'

            : l.dynStatusReceived;

      case 'scasOrigCoo':

        return file.supplierName.isNotEmpty ? '${l.dynStatusReceived}\n${l.dynCellOriginOk}' : l.dynStatusReceived;

      case 'scasOrigBl':

        return file.selectedScenario != null && file.selectedScenario!.isNotEmpty

            ? '${l.dynStatusReceived}\n${file.selectedScenario}'

            : '${l.dynStatusReceived} ${l.dynCellExpressBl}';

      case 'scasOrigInsurance':

        final inc = file.incotermCode.toUpperCase();

        return (inc == 'CIF' || inc == 'CIP') ? l.dynCellOriginCovered : l.dynCellIssuedReceived;

      case 'scasInsertNafeza':

        return file.acidNumber != null ? '${l.dynStatusDone}\n(${file.acidIssueDate ?? (isAr ? "سارٍ" : "Active")})' : l.dynCellPendingAcid;

      case 'scasBankForm4':

        return file.form4No != null ? '${l.dynStatusReceived}\n${isAr ? "رقم" : "No"}: ${file.form4No}' : l.dynCellPendingBank;

      case 'scasDeclare3A':

        return file.form46No != null ? '${l.dynStatusDone}\n${isAr ? "رقم" : "No"}: ${file.form46No}' : l.dynCellPending46;

      case 'scasMaterialReceived':

        return file.isCustomsReleased

            ? '${l.dynCellDeliveredWarehouse}\n(${file.customsReleasedAt ?? l.dynCustomsReleased})'

            : (file.status == 'Under Clearance' ? l.dynCellInClearancePort : file.status);



      default:

        return '-';

    }

  }



  String _buildRowSummary(ImportFileModel file, List<DynamicReportColumn> cols) {

    final buffer = StringBuffer();

    buffer.writeln('${file.displayName} — ${file.companyName}');

    for (final col in cols) {

      final label = _getColumnLabel(context, col.id);

      final val = _getCellValue(file, col.id).replaceAll('\n', ' ');

      buffer.writeln('$label: $val');

    }

    return buffer.toString().trim();

  }



  Future<void> _exportToCSV(List<ImportFileModel> files) async {

    final l = context.l10n;

    final visibleCols = _getActiveColumns();

    final columnLabels = {for (var c in visibleCols) c.id: _getColumnLabel(context, c.id)};

    final timestampStr = _formatDateTime(_lastUpdatedAt);



    await MasterDataExportService.exportDynamicReportToExcel(

      context: context,

      files: files,

      visibleColumnIds: visibleCols.map((c) => c.id).toList(),

      columnLabels: columnLabels,

      cellValueGetter: (f, colId) => _getCellValue(f, colId),

      templateTitle: _getTemplateTitle(context),

      timestamp: timestampStr,

      dialogTitle: l.dynExportExcelDialogTitle,

      fileNamePrefix: 'Reports_${_templateMode.name.toUpperCase()}',

    );

  }



  Future<void> _exportToPDF(List<ImportFileModel> files) async {

    final l = context.l10n;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final visibleCols = _getActiveColumns();

    final columnLabels = {for (var c in visibleCols) c.id: _getColumnLabel(context, c.id)};

    final timestampStr = _formatDateTime(_lastUpdatedAt);



    await MasterDataExportService.printOrSaveDynamicReportPdf(

      context: context,

      files: files,

      visibleColumnIds: visibleCols.map((c) => c.id).toList(),

      columnLabels: columnLabels,

      cellValueGetter: (f, colId) => _getCellValue(f, colId),

      templateTitle: _getTemplateTitle(context),

      timestamp: timestampStr,

      isAr: isAr,

      reportTitle: l.dynPdfReportTitle,

      confidentialText: l.dynPdfConfidential,

      dialogTitle: l.dynExportPdfDialogTitle,

      fileNamePrefix: 'Reports_${_templateMode.name.toUpperCase()}',

    );

  }



  Future<void> _copyDataToClipboard(List<ImportFileModel> files) async {

    final l = context.l10n;

    final visibleCols = _getActiveColumns();

    final headers = visibleCols.map((c) => _getColumnLabel(context, c.id)).join('\t');

    final rows = files.map((f) {

      return visibleCols.map((c) => _getCellValue(f, c.id).replaceAll('\n', ' / ')).join('\t');

    }).join('\n');



    final content = '$headers\n$rows';

    await CopyHelper.copy(

      context,

      content,

      customMessage: l.dynTsvCopiedMsg(files.length),

    );

  }



  void _showColumnPicker() {

    DynamicReportColumnPickerSheet.show(

      context: context,

      masterColumns: _masterColumns,

      getColumnLabel: _getColumnLabel,

      getCategoryTitle: _getCategoryTitle,

      onApply: () => setState(() => _templateMode = ReportTemplateMode.custom),

      onStateChanged: () => setState(() {}),

    );

  }



  @override

  Widget build(BuildContext context) {

    final l = context.l10n;

    final importFilesState = ref.watch(importFilesProvider);

    ref.watch(purchaseOrdersProvider);

    final activeCols = _getActiveColumns();

    final timestampFormatted = _formatDateTime(_lastUpdatedAt);



    return Scaffold(

      backgroundColor: Colors.grey.shade100,

      appBar: PageHeader(

        icon: Icons.assessment,

        iconColor: AppTheme.cobalt,

        title: l.dynReportBuilderTitle,

        subtitle: l.dynLastUpdatedLabel(timestampFormatted),

        actions: [

          IconButton(

            icon: const Icon(Icons.refresh, color: Colors.white),

            tooltip: l.dynRefreshTooltip,

            onPressed: _refreshData,

          ),

          const BackToDashboardButton(),

        ],

      ),

      body: SelectionArea(

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // Template Selector and Action Toolbar Panel

              importFilesState.when(

                loading: () => const SizedBox.shrink(),

                error: (_, __) => const SizedBox.shrink(),

                data: (files) {

                  final filtered = _filterFiles(files);

                  return DynamicReportFilterToolbar(

                    templateMode: _templateMode,

                    onTemplateModeChanged: (mode) => setState(() => _templateMode = mode),

                    onCustomizeColumns: _showColumnPicker,

                    activeColumnCount: activeCols.length,

                    masterColumnCount: _masterColumns.length,

                    searchController: _searchController,

                    onSearchChanged: (v) => setState(() => _searchQuery = v.trim()),

                    filterMode: _filterMode,

                    onFilterModeChanged: (v) => setState(() => _filterMode = v),

                    filterPriority: _filterPriority,

                    onFilterPriorityChanged: (v) => setState(() => _filterPriority = v),

                    onExportCsv: () => _exportToCSV(filtered),

                    onExportPdf: () => _exportToPDF(filtered),

                    onCopyTsv: () => _copyDataToClipboard(filtered),

                    filteredCount: filtered.length,

                  );

                },

              ),              const SizedBox(height: 12),



              // Live Table Preview

              Expanded(

                child: importFilesState.when(

                  loading: () => const AppLoadingState(),

                  error: (err, _) => AppErrorState(

                    error: err,

                    onRetry: _refreshData,

                  ),

                  data: (files) {

                    final filtered = _filterFiles(files);

                    return EnterpriseDataTable<ImportFileModel>(

                      key: ValueKey('${_templateMode.name}_${activeCols.length}'),

                      data: filtered,

                      isScrollable: true,

                      showHeaderToolbar: false,

                      emptyMessage: l.dynNoMatchingShipments,

                      columns: activeCols.map((col) {

                        final isFirstCol = col.id == activeCols.first.id;

                        final isCode = col.id == 'importFileCode' ||

                            col.id == 'ecoShipmentNo' ||

                            col.id == 'acidNumber' ||

                            col.id == 'form4No';

                        final isStatus = col.id == 'status' || col.id == 'currentStage';



                        return EnterpriseColumn<ImportFileModel>(

                          id: col.id,

                          title: _getColumnLabel(context, col.id),

                          exportValue: (file) => _getCellValue(file, col.id),

                          searchValue: (file) => _getCellValue(file, col.id),

                          cellBuilder: (context, file, index) {

                            final textVal = _getCellValue(file, col.id);

                            final rowSummary = _buildRowSummary(file, activeCols);



                            return CopyableTableCell(

                              value: textVal,

                              rowSummary: rowSummary,

                              child: Padding(

                                padding: const EdgeInsets.symmetric(vertical: 4),

                                child: Row(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    if (isFirstCol) ...[

                                      InkWell(

                                        onTap: () => CopyHelper.copy(context, rowSummary, customMessage: l.copiedToClipboardGeneric),

                                        borderRadius: BorderRadius.circular(4),

                                        child: Tooltip(

                                          message: l.dynCopyRowTooltip,

                                          child: Padding(

                                            padding: const EdgeInsets.all(2),

                                            child: Icon(Icons.table_rows_rounded, size: 13, color: AppTheme.emerald.withValues(alpha: 0.85)),

                                          ),

                                        ),

                                      ),

                                      const SizedBox(width: 6),

                                    ],

                                    Flexible(

                                      child: Text(

                                        textVal,

                                        style: TextStyle(

                                          fontWeight: isCode ? FontWeight.bold : FontWeight.normal,

                                          color: isCode

                                              ? AppTheme.cobalt

                                              : (isStatus ? AppTheme.charcoal : Colors.grey.shade900),

                                        ),

                                        overflow: TextOverflow.ellipsis,

                                      ),

                                    ),

                                    if (isCode && textVal != '-' && textVal.isNotEmpty) ...[

                                      const SizedBox(width: 4),

                                      InkWell(

                                        onTap: () => CopyHelper.copy(context, textVal),

                                        borderRadius: BorderRadius.circular(4),

                                        child: Tooltip(

                                          message: l.copyValue,

                                          child: Padding(

                                            padding: const EdgeInsets.all(2),

                                            child: Icon(Icons.copy_rounded, size: 13, color: AppTheme.cobalt.withValues(alpha: 0.7)),

                                          ),

                                        ),

                                      ),

                                    ],

                                  ],

                                ),

                              ),

                            );

                          },

                        );

                      }).toList(),

                    );

                  },

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



