import 'app_localizations.dart';

/// English localization — default language for Sorour Logistics ERP.
class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  // ── Navigation / Sidebar ─────────────────────────────────────────────────
  @override String get appTitle => 'Sorour Logistics';
  @override String get appSubtitle => 'Import Management ERP';
  @override String get masterData => 'Master Data & Tables';
  @override String get masterDataSub => 'Reference data and registries';
  @override String get shipmentPlanning => 'Shipment Planning';
  @override String get shipmentPlanningSub => 'Files, POs & calculations';
  @override String get phase1 => '1. Pre-Planning & Studies';
  @override String get phase1Sub => 'Freight & customs feasibility';
  @override String get phase2 => '2. Shipment Initiation';
  @override String get phase2Sub => 'Budget approvals & ACID';
  @override String get phase3 => '3. Booking & Doc Prep';
  @override String get phase3Sub => 'Freight booking & document review';
  @override String get phase4 => '4. Digital & Banking';
  @override String get phase4Sub => 'CargoX, originals & bank forms';
  @override String get phase5 => '5. Port & Clearance';
  @override String get phase5Sub => 'Customs declaration & clearance';
  @override String get phase6 => '6. Inbound & Closure';
  @override String get phase6Sub => 'Warehouse, landed cost & closure';
  @override String get dashboardAndReports => 'Dashboard & Reports';
  @override String get dashboardAndReportsSub => 'KPIs, audit & reporting hub';

  // ── Sidebar Menu Items ────────────────────────────────────────────────────
  @override String get importCompanies => 'Import Companies';
  @override String get foreignSuppliers => 'Foreign Suppliers';
  @override String get partnersAndBanks => 'Partners & Banks';
  @override String get projectsAndCostCenters => 'Projects & Cost Centers';
  @override String get portsAndLocations => 'Ports & Locations';
  @override String get incotermsRules => 'Incoterms Rules';
  @override String get customsTariffSchedule => 'Customs Tariff Schedule';
  @override String get currenciesAndRates => 'Currencies & Rates';
  @override String get importFiles => 'Import Files';
  @override String get purchaseOrders => 'Purchase Orders & Origin';
  @override String get cbmCalculator => 'CBM & Container Loading';
  @override String get freightStudies => 'Freight Studies';
  @override String get freightQuotations => 'Freight Quotations Comparison';
  @override String get customsStudies => 'Customs Studies';
  @override String get clearanceQuotations => 'Clearance Quotations & Extractor';
  @override String get importRequirements => 'Import Regulatory Requirements';
  @override String get financeApprovals => 'Finance Approvals & Budget';
  @override String get acidOperations => 'ACID Operations';
  @override String get freightBooking => 'Freight Booking';
  @override String get freightAllocations => 'Freight Allocations (VGM)';
  @override String get cargoShippingTracking => 'Cargo Shipping Tracking';
  @override String get packingReconciliation => 'PO & Packing Reconciliation';
  @override String get draftDocsReview => 'Draft Docs Review (B/L)';
  @override String get draftCOO => 'Draft COO / EUR.1';
  @override String get draftInspection => 'Draft Inspection / COC';
  @override String get docsCustomsApproval => 'Docs Customs Approval';
  @override String get centralDocsHub => 'Central Docs & Rectifications Hub';
  @override String get customsDutyEstimator => 'Customs Duty Estimator';
  @override String get cargoXBlockchain => 'CargoX Blockchain & ACI Hub';
  @override String get originalsCollection => 'Originals Collection';
  @override String get bankForm4 => 'Bank Form 4';
  @override String get customsDeclaration46 => 'Customs Declaration 46';
  @override String get customsClearanceFollowup => 'Customs Clearance Follow-up';
  @override String get drawingSamples => 'Drawing Samples / Shortage';
  @override String get discrepancyDamage => 'Discrepancy / Damage';
  @override String get finalCustomsPayment => 'Final Customs Payment';
  @override String get demurrageDetention => 'Demurrage & Detention';
  @override String get goodsInTransit => 'Goods In Transit (GIT) Ledger';
  @override String get warehouseReceiving => 'Warehouse Receiving GRN';
  @override String get receivedShipmentsReport => 'Received Shipments Report';
  @override String get landedCostSettlement => 'Landed Cost Settlement';
  @override String get landedCostComparison => 'Landed Cost Comparison';
  @override String get importFileFinalClosure => 'Import File Final Closure';
  @override String get operationalDashboard => 'Operational Dashboard';
  @override String get lifecycleBoard => 'Lifecycle Operations Board';
  @override String get masterShipmentReport => 'Master Shipment Report';
  @override String get dynamicReportBuilder => 'Dynamic Report Builder';
  @override String get quickUpdateEngine => 'Quick Update Engine';
  @override String get smartTasksAndAlerts => 'Smart Tasks & Alerts';
  @override String get systemAuditLogs => 'System Audit Logs';
  @override String get productionSyncHub => 'Production Sync Hub';
  @override String get swiftReconciliation => 'SWIFT Reconciliation';
  @override String get cargoInsurance => 'Marine Cargo Insurance';
  @override String get userManagement => 'User Management & Permissions';
  @override String get tabOptionsTooltip => 'Window & Tab Options';
  @override String get closeOtherTabs => 'Close Other Tabs';
  @override String get closeAllTabs => 'Close All Additional Tabs';

  // ── Buttons ───────────────────────────────────────────────────────────────
  @override String get save => 'Save';
  @override String get saveDraft => 'Save Draft';
  @override String get saveAndConfirm => 'Save & Confirm';
  @override String get updateRecord => 'Update Record';
  @override String get cancel => 'Cancel';
  @override String get close => 'Close';
  @override String get resetForm => 'Clear Form';
  @override String get refresh => 'Refresh';
  @override String get liveRefresh => 'Live Refresh';
  @override String get edit => 'Edit';
  @override String get delete => 'Delete';
  @override String get viewDetails => 'View Details';
  @override String get print => 'Print / Export';
  @override String get exportExcel => 'Export Excel';
  @override String get exportPdf => 'Export PDF';
  @override String get importExcel => 'Import Excel';
  @override String get downloadTemplate => 'Download Template';
  @override String get uploading => 'Uploading...';
  @override String get backToDashboard => 'Back to Dashboard';

  // ── Common Messages ───────────────────────────────────────────────────────
  @override String get connectionError => 'Server Connection Error';
  @override String get connectionErrorDetail =>
      'Could not connect to the backend server. Make sure it is running then press Retry.';
  @override String get retryConnection => 'Retry Connection';
  @override String get loading => 'Loading...';
  @override String get saving => 'Saving...';
  @override String get noData => 'No data available';
  @override String get search => 'Search';
  @override String get searchHint => 'Quick search...';
  @override String get clearSearch => 'Clear';
  @override String get ok => 'OK';
  @override String get confirm => 'Confirm';
  @override String get warning => 'Warning';
  @override String get error => 'Error';
  @override String get success => 'Success';
  @override String get importSuccessful => 'Import Successful';
  @override String get approved => 'Approved';
  @override String get pending => 'Pending';
  @override String get statusPending => 'Pending';
  @override String get rejected => 'Rejected';
  @override String get importWithAlerts => 'Import Completed with Alerts';
  @override String get alertsErrors => 'Alerts / Errors:';
  @override String get preparingExport => 'Preparing document export...';
  @override String get dataActionsTitle => 'Data Actions & Export/Import';

  // ── System Info ───────────────────────────────────────────────────────────
  @override String get systemVersion => 'System Version';
  @override String get buildId => 'Build ID';
  @override String get backendEngine => 'Backend Engine';
  @override String get database => 'Database';
  @override String get operatingMode => 'Operating Mode';
  @override String get licenseAndRights => 'License & Rights';
  @override String get systemInfo => 'System Info';
  @override String get syncHub => 'Sync Hub';
  @override String get expandSidebar => 'Expand Sidebar';
  @override String get collapseSidebar => 'Collapse Sidebar';
  @override String get userOptions => 'User Options';
  @override String get logout => 'Logout';
  @override String get versionBadge => 'v1.0.2 (Build 2026.08)';

  // ── Tooltips ─────────────────────────────────────────────────────────────
  @override String get viewDetailsTooltip => 'View Details';
  @override String get editTooltip => 'Edit Record';
  @override String get printTooltip => 'Print / Export PDF';
  @override String get deleteTooltip => 'Delete / Deactivate';
  @override String get syncHubTooltip => 'Production Sync Hub';
  @override String get systemInfoTooltip => 'System Version & Info';
  @override String get backToDashboardTooltip => 'Back to Dashboard';
  @override String get languageToggleTooltip => 'Switch Language (AR / EN)';

  // ── Role Switcher ─────────────────────────────────────────────────────────
  @override String get switchAsAdmin => 'Switch as: Admin 🔴';
  @override String get switchAsManager => 'Switch as: Manager 🔵';
  @override String get switchAsSpecialist => 'Switch as: Specialist 🟢';
  @override String get productionSyncTitle => 'Production Sync & Deployment';

  // ── Sidebar Search ────────────────────────────────────────────────────────
  @override String get quickSearch => 'Quick Search...';

  // ── Operational Dashboard ───────────────────────────────────────────────────
  @override String get operationalDashboardTitle => 'Operational Workspace Dashboard';
  @override String get priority => 'Priority:';
  @override String get priorityAll => 'All';
  @override String get priorityLow => 'Low';
  @override String get priorityMedium => 'Medium';
  @override String get priorityHigh => 'High';
  @override String get priorityCritical => 'Critical';
  @override String get customsBrokerLabel => 'Customs Broker:';
  @override String get allBrokers => 'All Brokers';
  @override String get quickSearchLabel => 'Quick Search:';
  @override String get dashboardSearchHint => 'Shipment code, PO, supplier...';
  @override String get resetFilters => 'Reset Filters';
  @override String get clearFilter => 'Clear Filter';
  @override String get serverConnectionError => 'Could not connect to backend server';
  @override String get serverConnectionHint => 'Please ensure the backend server is running or click retry.';
  @override String get matchingShipments => 'Matching Shipments';
  @override String get lastUpdated => 'Last Updated';
  @override String get noMatchingShipments => 'No Matching Shipments';
  @override String get noMatchingShipmentsDesc => 'No shipments found matching the current filter criteria.';
  @override String get clearFiltersShowAll => 'Clear Filters & Show All';
  @override String get currentPhase => 'Current Phase';
  @override String get operationalStep => 'Operational Step';
  @override String get unassigned => 'Unassigned';
  @override String get closedShipment => 'Closed Shipment';
  @override String get recordDailyUpdate => 'Record Daily Update';
  @override String get closeStopShipment => 'Close & Stop Shipment';
  @override String get nextStepAction => '🎯 Next Step & Target Action:';
  @override String get responsiblePerson => 'Responsible';
  @override String get executeStepNow => 'Execute Step Now';
  @override String get openShipmentTasks => 'Open TO-DO Tasks for Shipment';
  @override String get manageAllTasks => 'Manage All Tasks';
  @override String get taskCompletedSuccessfully => '✅ Task completed successfully';
  @override String get riskAlertsCenter => 'Operational Risk & Escalation Center:';
  @override String get dailyCheckinsLog => 'Daily Check-ins & Live Operations Log:';
  @override String get addDailyUpdate => 'Add Daily Update';
  @override String get noDailyUpdates => 'No daily check-ins recorded today.';
  @override String get aiSmartExtractorTitle => 'AI Master Data Smart Extractor:';
  @override String get smartExtractSupplier => 'Smart Foreign Supplier 🌍';
  @override String get smartExtractCompany => 'Smart Import Company 🏢';
  @override String get smartExtractPartner => 'Smart Partner / Broker 🤝';
  @override String get smartExtractBank => 'Smart Approved Bank 🏦';
  @override String get quickShortcutsTitle => 'Quick Create & Register Shortcuts:';
  @override String get createNewProject => 'Create New Project';
  @override String get createNewImportFile => 'Create Import File';
  @override String get createNewImportCompany => 'Create Import Company';
  @override String get createNewSupplier => 'Create Foreign Supplier';
  @override String get createNewPartnerBank => 'Create Partner / Bank';
  @override String get createNewCustomsTariff => 'Add Customs Tariff';
  @override String get createNewLocation => 'Add Ports & Locations';
  @override String get createNewCurrency => 'Add New Currency';
  @override String get createNewExchangeRate => 'Update Exchange Rate';
  @override String get interactiveOperationsBoardTitle => 'Interactive 6-Phase Operations Board';
  @override String get interactiveOperationsBoardDesc => 'Comprehensive visual board (6 Major Phases — 25 Operational Steps) supporting live multi-phase tracking and instant shipment movement.';
  @override String get openInteractiveBoard => 'Open Interactive Board';
  @override String get lifecycleBoardSummaryTitle => 'Shipment Operations Lifecycle Summary (25 Steps)';
  @override String get lifecycleBoardSummaryDesc => 'Live tracking of shipment files across 6 major phases and 25 detailed operational steps.';
  @override String get fullOperationsBoardButton => 'Full Operations Board (25 Steps) ↗️';
  @override String get shipmentCountUnit => 'Shipments';
  @override String get tasksCountUnit => 'Tasks';
  @override String get kpiTodaysTasks => "Today's Tasks";
  @override String get kpiTodaysTasksSub => 'Tasks to execute today';
  @override String get kpiPendingTasks => 'Pending Tasks';
  @override String get kpiPendingTasksSub => 'Incomplete tasks requiring action';
  @override String get kpiUpcomingShipments => 'Upcoming Shipments';
  @override String get kpiUpcomingShipmentsSub => 'Expected future arrivals';
  @override String get kpiArrivingThisWeek => 'Arriving This Week';
  @override String get kpiArrivingThisWeekSub => 'Vessel arrivals this week';
  @override String get kpiEtaChanges => 'ETA Changes';
  @override String get kpiEtaChangesSub => 'Arrival schedule updated';
  @override String get kpiWaitingPayment => 'Waiting For Payment';
  @override String get kpiWaitingPaymentSub => 'Pending financial approvals (Phase 2)';
  @override String get kpiWaitingForm4 => 'Waiting For Form 4';
  @override String get kpiWaitingForm4Sub => 'Bank Form 4 procedures pending';
  @override String get kpiPendingRequirements => 'Pending Requirements';
  @override String get kpiPendingRequirementsSub => 'Incomplete documents & approvals';
  @override String get kpiHighPriorityAlerts => 'High Priority Alerts';
  @override String get kpiHighPriorityAlertsSub => 'High / Critical priority alerts';
  @override String get retry => 'Retry';
  @override String get purchaseOrder => 'Purchase Order:';

  // ── Task E: Drill-down Dialog & KPI Cards ──────────────────────────────────
  @override String get drillDownDialogTitle => 'Details & Records';
  @override String get drillDownItemsCountSuffix => 'items';
  @override String get drillDownSearchHint => 'Search records by name, reference, owner...';
  @override String get drillDownCopyAllBtn => 'Copy All Records';
  @override String get drillDownCopiedAllToast => 'All records copied to clipboard successfully';
  @override String get drillDownCopiedItemToast => 'Record copied to clipboard';
  @override String get drillDownEmptyTitle => 'No Records Found';
  @override String get drillDownEmptyDesc => 'There are currently no items matching this category. Any upcoming items will automatically appear here.';
  @override String get drillDownLabelWhat => 'Action / Requirement';
  @override String get drillDownLabelWho => 'Responsible Party';
  @override String get drillDownLabelWhen => 'Due Date / Timeline';
  @override String get drillDownLabelStatus => 'Status';
  @override String get drillDownLabelNextAction => 'Next Action';
  @override String get drillDownDataGapBadge => 'Data Gap';
  @override String get drillDownTimeDataGap => 'Exact due time (HH:mm) is not stored in database (date only).';
  @override String get drillDownPendingReasonDataGap => 'Pending reason code is not formally defined in DB; derived from notes or overdue state.';
  @override String get drillDownEtaChangeDataGap => 'Initial scheduled ETA on record; historical change log and change reasons are not yet tracked.';
  @override String get drillDownPaymentDeadlineDataGap => 'Bank payment deadline is not tracked independently from cargo ready date.';
  @override String get drillDownActionFocusShipment => 'Focus Shipment';
  @override String get drillDownActionCompleteTask => 'Mark Done';
  @override String get drillDownActionDailyUpdate => 'Daily Update';
  @override String get drillDownCloseBtn => 'Close';
  @override String get drillDownCardClickHint => 'Click to drill down into records';

  // ── Operational Dashboard Exports, Pathways & Steps ────────────────────────
  @override String get operationalExportTsvBtn => 'Export Operations (TSV)';
  @override String get operationalExportExcelBtn => 'Export Excel (CSV)';
  @override String get operationalExportPdfBtn => 'Print Operations (PDF)';
  @override String get operationalCopyDossierBtn => 'Copy Dossier';
  @override String get operationalExportTsvDialogTitle => 'Save Operations Workspace Table (TSV)';
  @override String get operationalExportExcelDialogTitle => 'Save Operations Workspace Excel (CSV)';
  @override String get operationalReportTitle => 'Operational Workspace & Shipments Report';
  @override String get operationalPdfSystemBranding => 'Sorour Logistics & Import Management ERP System';
  @override String get operationalPdfOfficialBadge => 'Official Document';
  @override String get operationalPdfFilterCriteria => 'Filter Criteria: ';
  @override String get operationalReportGeneratedAt => 'Generated At';
  @override String get operationalReportGeneratedBy => 'User';
  @override String get operationalDossierCriteria => 'Filter Criteria: ';
  @override String get operationalCopiedTsvSuccess => 'TSV file exported successfully';
  @override String get operationalCopiedExcelSuccess => 'CSV file exported successfully';
  @override String get operationalCopiedDossierSuccess => 'Operations dossier copied to clipboard successfully';
  @override String get operationalTsvHeaderShipmentName => 'Shipment Name';
  @override String get operationalTsvHeaderFileCode => 'Import File Code';
  @override String get operationalTsvHeaderCustomFileNo => 'Customs File No';
  @override String get operationalTsvHeaderImporter => 'Importing Company';
  @override String get operationalTsvHeaderSupplier => 'Foreign Supplier';
  @override String get operationalTsvHeaderPriority => 'Priority';
  @override String get operationalTsvHeaderCurrentPhase => 'Current Phase';
  @override String get operationalTsvHeaderOperationalStep => 'Operational Step';
  @override String get operationalTsvHeaderBroker => 'Customs Broker';
  @override String get operationalTsvHeaderPoNumber => 'PO Number';
  @override String get operationalTsvHeaderProgress => 'Progress %';
  @override String get operationalTsvHeaderNextAction => 'Next Action';
  @override String get operationalTsvHeaderStatus => 'Status';
  @override String operationalPdfPageOf(int page, int total) => 'Page $page of $total';

  @override String get pathwayPrevFilePlanning => 'Prev: File Planning';
  @override String get pathwayPrevFreightStudies => 'Prev: Freight Studies';
  @override String get pathwayCurrent => 'Current';
  @override String get pathwayNext => 'Next Step';
  @override String get pathwayNextImportReqs => 'Review Import Requirements & Regulatory Approvals';

  @override String get nextStepDefaultTitle => 'Follow up operational procedures';
  @override String get nextStepDefaultDesc => 'Complete requirements for current phase';
  @override String get responsibleImportTeam => 'Import Team';
  @override String get nextStepImportReqsTitle => 'Next Step: Import Regulatory Requirements (STEP_03)';
  @override String get nextStepImportReqsDesc => 'Review regulatory requirements and prior approvals for shipment HS codes';
  @override String get responsibleImportSpecialist => 'Import Specialist';
  @override String get nextStepCustomsConsultTitle => 'Next Step: Customs Consultation & Tariff (STEP_02)';
  @override String get nextStepCustomsConsultDesc => 'Review HS codes, calculate estimated taxes and assign customs broker';
  @override String get nextStepFinanceApprovalTitle => 'P2: Financial Approval & Payment';
  @override String get nextStepFinanceApprovalDesc => 'Review budget, issue payment request and bank transfer to supplier';
  @override String get responsibleFinanceDept => 'Finance Department';
  @override String get nextStepNafezaAcidTitle => 'P3: Nafeza ACID & CargoX Docs';
  @override String get nextStepNafezaAcidDesc => 'Register shipment on Nafeza and obtain 19-digit ACID number';
  @override String get responsibleNafezaSpecialist => 'Nafeza Specialist';
  @override String get nextStepFreightBookingTitle => 'P4: Freight Booking & Container Alloc.';
  @override String get nextStepFreightBookingDesc => 'Confirm vessel booking with carrier, issue draft B/L and confirm shipment';
  @override String get nextStepTransitTrackingTitle => 'P5: Transit Tracking & CargoX';
  @override String get nextStepTransitTrackingDesc => 'Monitor vessel transit, tracking ETA and receiving shipper documents';
  @override String get responsibleShippingCarrier => 'Shipping Carrier';
  @override String get nextStepArrivalNoticeTitle => 'P6: Arrival Notice & Declaration 46';
  @override String get nextStepArrivalNoticeDesc => 'Receive arrival notice and assign broker for customs inspection file';
  @override String get nextStepDutyPaymentTitle => 'P7: Inspection & Duty Payment';
  @override String get nextStepDutyPaymentDesc => 'Follow up customs inspection, sampling and duty/tax payment';
  @override String get nextStepInlandTransportTitle => 'P8: Inland Transport & GRN';
  @override String get nextStepInlandTransportDesc => 'Coordinate inland transport, receive goods in warehouse and verify quantities';
  @override String get responsibleWarehouseCustodian => 'Warehouse Custodian';
  @override String get nextStepLandedCostTitle => 'P9: Landed Cost Settlement';
  @override String get nextStepLandedCostDesc => 'Aggregate all invoices, freight and customs fees to calculate true landed cost';
  @override String get responsibleFinanceAuditing => 'Finance & Auditing';
  @override String get nextStepClosureTitle => 'P10: File Archive & Final Closure';
  @override String get nextStepClosureDesc => 'Verify completion of all documents and invoices, and permanently archive file';
  @override String get responsibleImportManager => 'Import Manager';

  // ── Screen 1: Import Files & Shipments ────────────────────────────────────
  @override String get importFilesManagementTitle => 'Import Files & Shipments Management';
  @override String get uploadImportDocument => 'Upload Import Document (PDF / Word / Excel)';
  @override String get addNewImportFile => 'Add New Import File';
  @override String get editImportFile => 'Edit & Update Import File';
  @override String get generateComprehensiveReport => 'Generate Master Shipment Report';
  @override String get searchByShipmentOrCompany => 'Search by shipment code or company...';
  @override String get statusAll => 'All Statuses';
  @override String get statusOpen => 'Open';
  @override String get statusInProgress => 'In Progress';
  @override String get statusClosed => 'Closed';
  @override String get importFileIdLabel => 'Import File No';
  @override String get importingCompany => 'Importing Company';
  @override String get foreignSupplier => 'Foreign Supplier';
  @override String get status => 'Status';
  @override String get actions => 'Actions';
  @override String get smartInvoiceBlExtractorButton => 'Smart Invoice & B/L Extractor';
  @override String get whatIfSimulatorButton => 'What-If & Hedging Simulator';
  @override String get colIncoterms => 'Incoterms';
  @override String get colPort => 'Port';
  @override String get colWarehouse => 'Warehouse';
  @override String get colDirectTransit => 'Direct / Transit';
  @override String get colPickupDate => 'Pickup Date';
  @override String get colDocDate => 'Doc Date';
  @override String get colSwift => 'SWIFT';
  @override String get colCarrier => 'Carrier / Line';
  @override String get colAcid => 'ACID';
  @override String get colForm4 => 'Bank Form 4';
  @override String get colForm46 => 'Declaration 46';
  @override String get saveComprehensiveReportDialogTitle => 'Save Comprehensive Import Files Report (Excel / CSV)';
  @override String get poNumberShortPrefix => 'PO: ';
  @override String get piNumberShortPrefix => 'PI: ';
  @override String get importFileReviewChangesTitle => 'Review & Confirm Import File Changes';
  @override String get importFileSavedSuccess => 'Import file saved and updated successfully!';
  @override String get notesInstructions => 'Notes & Instructions';
  @override String get poInvoiceLabel => 'PO / Proforma Invoice';
  @override String get transportModeIncoterm => 'Mode / Incoterms';
  @override String get priorityType => 'Priority';
  @override String get targetEta => 'Target ETA';
  @override String get currentPhaseStage => 'Current Phase';
  @override String get progressPercentLabel => 'Progress %';
  @override String get nextActionLabel => 'Next Action';
  @override String get responsiblePersonLabel => 'Assignee / Owner';
  @override String get stopShipmentTooltip => 'Stop & Archive Shipment at this stage';
  @override String get reopenShipmentTooltip => 'Reopen & Reactivate Closed Shipment';
  @override String get freightRfqTooltip => 'Request Freight Quotations (RFQ)';
  @override String get printFileHistoryTooltip => 'Print Master Shipment File & Operational History';
  @override String get noImportFilesFound => 'No import files registered in the system. Click to add a new file.';
  @override String get confirmDeleteImportFileTitle => 'Confirm Deletion';
  @override String get confirmDeleteImportFileMessage => 'Are you sure you want to delete import file #';
  @override String get evaluateMasterReportTitle => 'Generate & Evaluate Master Shipment Report';
  @override String get selectShipmentForReport => 'Select shipment / import file to generate the consolidated report:';
  @override String get allShipmentFiles => 'All Shipment Files';
  @override String get shipmentNoPrefix => 'Shipment No:';
  @override String get createAndDisplayReport => 'Generate & View Report';
  @override String get masterImportReportTitle => 'Consolidated Master Import Report';
  @override String get filteredForShipment => 'Filtered for Shipment #:';
  @override String get printReport => 'Print Report';
  @override String get filterReportByShipment => 'Filter report by shipment #:';
  @override String get totalFilesMetric => 'Total Files';
  @override String get openFilesMetric => 'Open Files';
  @override String get inProgressMetric => 'In Progress';
  @override String get totalCostMetric => 'Total Cost';
  @override String get operationalTrackingMatrixSection => '1. Operational Tracking Matrix';
  @override String get cargoAndLinkedPosSection => '2. Cargo Volumes & Linked Purchase Orders Breakdown';
  @override String get invoicesCountAndNumbers => 'Invoice Numbers & Count';
  @override String get invoicesUnit => 'Invoices';
  @override String get totalCbmFromPackingList => 'Total CBM from Packing Lists';
  @override String get cbmSumDescription => 'Total CBM across all packing lists';
  @override String get totalGrossWeightFromPl => 'Total Gross Weight';
  @override String get grossWeightSumDescription => 'Total gross weight across all packing lists';
  @override String get linkedPurchaseOrdersTitle => 'Linked Purchase Orders';
  @override String get posUnit => 'POs';
  @override String get packingListsUnit => 'Packing Lists';
  @override String get noLinkedPosForFile => 'No purchase orders linked to this file yet.';
  @override String get paymentTermsLabel => 'Payment Terms';
  @override String get packingListItemsCol => 'Packing Lists';
  @override String get weightCbmCol => 'Weight / CBM';
  @override String get palletsShippingPlan => 'Pallets (Shipping Plan)';
  @override String get packingItemsCount => 'Packing Items';
  @override String get visualLoadPlannerTitle => 'Visual Container Load Planner & Simulation';
  @override String get containerLoadPlanButton => 'Container Load Plan';
  @override String get exportReportExcelPdf => 'Export Report (Excel / PDF)';
  @override String get reportCopiedToClipboard => 'Report prepared and copied to clipboard successfully! Ready for printing';
  @override String get csvExportSuccess => 'Master import summary report exported to CSV successfully!';
  @override String get sideViewTitle => 'Side View';
  @override String get topViewTitle => 'Top View';
  @override String get internalDimensions => 'Internal';
  @override String get containerLoadFailed => 'Load Failed (Oversized packages/weight)';
  @override String get containerOverfilled => 'Length full (Aisle clearance restricts side placement)';
  @override String get containerEmpty => 'Underutilized space';
  @override String get containerGoodUtil => 'Good space utilization';
  @override String get allStackableChip => 'All Stackable';
  @override String get allNonStackableChip => 'All Non-Stackable';
  @override String get mixedStackingChip => 'Mixed Stacking';
  @override String get containerSpecType => 'Container Spec';
  @override String get requiredCount => 'Required Qty';
  @override String get effectiveCapacityCbm => 'Effective CBM';
  @override String get spaceUtilizationPercent => 'Space Util %';
  @override String get weightUtilizationPercent => 'Weight Util %';
  @override String get acidStatusTitle => 'ACID Status & Expiry';
  @override String get customsReleasedBadge => 'Customs Released (Alerts Exempt)';
  @override String get underClearanceBadge => 'Under Clearance';
  @override String get cargoStackingScenariosTitle => 'Cargo Stacking Scenarios';
  @override String get scenariosMatrixButton => 'Scenarios Matrix';
  @override String get scenarioAllStackableTitle => 'Scenario 1: All Stackable Cargo';
  @override String get scenarioAllNonStackableTitle => 'Scenario 2: All Non-Stackable Cargo';
  @override String get scenarioMixedStackingTitle => 'Scenario 3: Mixed Stacking Cargo';
  @override String get saveContainerImageTooltip => 'Save Container Image (PNG)';
  @override String get exportContainerExcelTooltip => 'Export Planner Table (Excel)';
  @override String get exportContainerPdfTooltip => 'Export Simulation Report (PDF)';
  @override String get saveContainerImageDialogTitle => 'Save Container Plan Image PNG';
  @override String get exportContainerExcelDialogTitle => 'Export Container Simulation Excel';
  @override String get exportContainerPdfDialogTitle => 'Export Container Simulation Report PDF';
  @override String get containerImageCaptureError => 'Could not capture container plan from screen.';
  @override String get containerExportError => 'Error exporting file: ';
  @override String get closePlannerBtn => 'Close Planner';
  @override String get savedShippingStudiesTitle => 'Saved Shipping Evaluation Studies';
  @override String get date => 'Date';
  @override String get shipmentCategoryLabel => 'Shipment Category';
  @override String get fileOpeningDateLabel => 'File Opening Date';
  @override String get logisticsAndPortsDetails => 'Logistics & Freight RFQ Details';
  @override String get portOfLoadingLabel => 'Port of Loading (POL)';
  @override String get portOfDischargeLabel => 'Port of Discharge (POD)';
  @override String get cargoReadyDateLabel => 'Cargo Ready Date (CRD)';
  @override String get targetFreeDaysLabel => 'Target Free Days (FT)';
  @override String get serviceTypePreferenceLabel => 'Service Preference';
  @override String get pickupAddressLabel => 'Pickup / Factory Address';
  @override String get shippingInstructionsLabel => 'Special Shipping Instructions';
  @override String get multiProjectsTitle => 'Multi-Project Assignment';
  @override String get notes => 'Notes & Instructions';
  @override String get liveReload => 'Live Reload';
  @override String get clearAndReset => 'Clear & Reset';
  @override String get customsClearanceBroker => 'Customs Broker';
  @override String get freightRfqTitle => 'Freight RFQ Generator';
  @override String get emailDraftTab => 'Official Email Draft';
  @override String get whatsappTemplateTab => 'WhatsApp Template';
  @override String get shipmentSpecsTab => 'Shipment Specs';
  @override String get grossWeightMetric => 'Gross Weight';
  @override String get netWeightMetric => 'Net Weight';
  @override String get commodityTitle => 'Commodity';
  @override String get closeShipmentTitle => 'Stop & Close Shipment';
  @override String get reason => 'Reason & Notes';
  @override String get cbmVolumeMetric => 'Total Volume (CBM)';
  @override String get currency => 'Currency';
  @override String get owner => 'Owner';
  @override String get purchaseOrdersTitle => 'Purchase Orders & Proforma Invoices';
  @override String get purchaseOrdersSubtitle => 'Phase 1: Manage & Record Purchase Orders, Proforma Invoices, CBM & Weight Calculations';
  @override String get smartInvoiceExtract => 'Smart Invoice & Packing Extractor';
  @override String get newPurchaseOrder => 'New Purchase Order';
  @override String get editPurchaseOrder => 'Edit Purchase Order';
  @override String get totalOrdersMetric => 'Total POs';
  @override String get totalFobMetric => 'Total PI/PO Amount';
  @override String get totalCargoCbmMetric => 'Total Cargo CBM';
  @override String get totalGrossWeightMetric => 'Total Gross Weight';
  @override String get searchByPoHint => 'Search by PO Number, PI Number, or Notes...';
  @override String get filterByProject => 'Filter by Project';
  @override String get allProjects => 'All Projects';
  @override String get filterByStatus => 'Filter by Status';
  @override String get allStatuses => 'All Statuses';
  @override String get showInactive => 'Show Inactive';
  @override String get poReferenceCol => 'PO Reference';
  @override String get invoiceDateCol => 'Invoice Date';
  @override String get importFileCol => 'Import File';
  @override String get piNumberCol => 'PI Number';
  @override String get countryOfOriginCol => 'Country of Origin';
  @override String get actionsCol => 'Actions';
  @override String get poLineItemsTab => 'PO Line Items';
  @override String get reviewPackingListTab => 'Review Packing List';
  @override String get palletizationPlanTitle => 'Master Palletization Plan';
  @override String get totalPalletsMetric => 'Total Pallets';
  @override String get palletSimulation3D => '3D Container Packing Simulation';
  @override String get palletTypeCol => 'Pallet Type & Size';
  @override String get palletCountCol => 'Pallet Count';
  @override String get palletDimensionsCol => 'Dimensions (L × W × H)';
  @override String get palletWeightCol => 'Pallet Weight (Gross)';
  @override String get palletTotalWeightCol => 'Total Weight';
  @override String get palletVolumeCol => 'Line Volume CBM';
  @override String get palletStackingInstructionsCol => 'Stacking Instructions';
  @override String get stackable => 'Stackable';
  @override String get nonStackable => 'Non-Stackable (Floor Only)';
  @override String get discrepancyWarningTitle => 'Alert: Discrepancy Between Invoice & Packing List';
  @override String get discrepancyJustificationLabel => 'Discrepancy Justification Reason';
  @override String get backToEdit => 'Back to Edit';
  @override String get continueAndSave => 'Continue & Save PO';
  @override String get summaryByHsCodeReport => 'Packing List Summary By HS Code';
  @override String get hsCode => 'HS Code';
  @override String get quantityMetric => 'Quantity';
  @override String get requiredField => 'This field is required';
  @override String get saveChanges => 'Save Changes';
  @override String get noDataFound => 'No data found';
  @override String get statusDraft => 'Draft';
  @override String get statusPoApproved => 'Approved';
  @override String get statusInTransit => 'In Transit';
  @override String confirmDeactivatePo(String name) => 'Are you sure you want to deactivate purchase order ($name)?';
  @override String confirmRestorePo(String name) => 'Are you sure you want to restore purchase order ($name)?';
  @override String get deactivatePoTooltip => 'Deactivate Purchase Order';
  @override String get restorePoTooltip => 'Restore Purchase Order';
  @override String get poBalanceLedgerTooltip => 'PO Balance Ledger & Partial Shipments';
  @override String printPoAndPackingList(String name, String code) => 'Print Purchase Order & Packing List: $name ($code)';
  @override String get cbmAndGrossWeightCol => 'CBM & Gross Weight';
  @override String get masterPalletPlanTitle => 'Master Palletization Plan';
  @override String palletCountWithUnit(int count) => '$count Pallets';
  @override String palletCbmWithUnit(String cbm) => 'Pallet Volume: $cbm m³';
  @override String simulateAndLoad3d(int count) => '3D Container Packing Simulation ($count Pallets)';
  @override String get qtyPcsCol => 'Qty PCS';
  @override String get qtyPkgCol => 'Qty PKG';
  @override String get dimensionsCmCol => 'Dimensions (cm)';
  @override String get netWeightCol => 'Net Wt (kg)';
  @override String get grossWeightCol => 'Gross Wt (kg)';
  @override String get totalNetWeightCol => 'Total Net Weight (kg)';
  @override String get totalGrossWeightCol => 'Total Gross Weight (kg)';
  @override String get noCargoOrPalletToSimulate => 'No packing list items or pallets to simulate';
  @override String get noSuitableContainers => 'No suitable containers found';
  @override String containerLoadPlanTitle(String name, String code) => '3D Container Load & Stacking Plan — $name ($code)';
  @override String containerLoadPlanMetrics(String volume, String weight, String fleet) => 'Cargo Volume: $volume m³ | Weight: $weight kg | Required Fleet: $fleet';
  @override String get topView => 'Top View';
  @override String get sideView => 'Side View';
  @override String containerIndexTitle(int index, String name) => 'Container #$index: $name';
  @override String packagesOrPalletsCount(int count) => '$count Packages / Pallets';
  @override String get copyAllData => 'Copy All Data';
  @override String get copyAllPoDataSuccess => 'All PO details and line items copied to clipboard successfully (ready to paste in Excel/Word)';

  // ── CBM Calculator ───────────────────────────────────────────────────────
  @override String get cbmCalculatorTitle => 'Cargo Measurement Engine';
  @override String get cbmCalculatorSubtitle => 'Calculate CBM volume, air chargeable weight, and container load recommendations';
  @override String get quickOperationalCalculatorTab => 'Quick Operational Calculator';
  @override String get savedCalculationsRegistryTab => 'Saved Calculations History Log';
  @override String get activeEditSessionBanner => 'Editing Saved Session';
  @override String get activeEditSessionHint => 'Modifying cargo packages and dimensions. You can save changes to this session or save as new.';
  @override String get saveChangesInSession => 'Save Changes in Session';
  @override String get newBlankSession => 'New Blank Session';
  @override String get totalCbmVolumeMetric => 'Total CBM Volume';
  @override String get airChargeableWtMetric => 'Air Chargeable Wt';
  @override String get volumetricWeight => 'Volumetric Weight';
  @override String get recommendedShippingMetric => 'Recommended Shipping';
  @override String get cargoStackingInstructions => 'Cargo Stacking Instructions:';
  @override String get stackableOption => 'Stackable';
  @override String get nonStackableOption => 'Non-Stackable';
  @override String get allStackableOption => 'All Stackable';
  @override String get allNonStackableOption => 'All Non-Stackable';
  @override String get mixedStackingOption => 'Mixed Stacking';
  @override String get compareContainersMatrix => 'Compare Containers Matrix';
  @override String get visualLoadPlanSimulator => 'Visual Container Load Plan';
  @override String get packageMeasurementsTitle => 'Cargo Package Measurements & Dimensions';
  @override String get airFreightMode => 'Air Freight';
  @override String get seaFreightMode => 'Sea Freight';
  @override String get addPackageLine => 'Add Package Line';
  @override String get saveCalculationSession => 'Save Calculation Session';
  @override String get saveAsNewSession => 'Save as New Session';
  @override String get unitCol => 'Unit';
  @override String get qtyCol => 'Qty';
  @override String get lengthCol => 'Length';
  @override String get widthCol => 'Width';
  @override String get heightCol => 'Height';
  @override String get stackingCol => 'Stacking';
  @override String get grossWtPerUnitCol => 'Gross Wt/Unit (kg)';
  @override String get calculatedOutputsCol => 'Calculated Outputs';
  @override String get deleteRowTooltip => 'Delete Row';
  @override String get packageTypeCol => 'Package Type';
  @override String get calculationSessionTitle => 'Calculation Session Title';
  @override String get notesAndCargoRemarks => 'Notes & Cargo Remarks';
  @override String get containerOptionsAnalysis => 'Container Options & Loading Scenarios Analysis';
  @override String get totalShipmentSummary => 'Total Shipment';
  @override String get approvedRecommendation => 'Approved Recommendation';
  @override String get containerSpecCol => 'Container Spec';
  @override String get requiredCountCol => 'Required Count';
  @override String get spaceUtilizationCol => 'Space Utilization %';
  @override String get weightUtilizationCol => 'Weight Utilization %';
  @override String get recommendationCol => 'Recommendation';
  @override String get bestOptionBadge => 'Best Option';
  @override String get viableAlternative => 'Viable Alternative';
  @override String get chooseStackingScenario => 'Choose Stacking Scenario for Preview:';
  @override String get smartHybridOption => '🌟 Smart Hybrid (Flat + On-Edge)';
  @override String get flatOnlyOption => '📦 Flat Only';
  @override String get onEdgeOption => '📐 On-Edge Only';
  @override String get smartHybridSavingsMessage => '💡 Smart Insight: Hybrid Stacking saves extra container(s) by packing residual side channels!';
  @override String get orientationPreferenceLabel => 'Preferred Stacking Orientation:';
  @override String get requiredFleet => 'Required Fleet:';
  @override String get containerPlanTitle => 'Container Layout Plan';
  @override String get closePlan => 'Close Plan';
  @override String get totalCalculationsMetric => 'Total Calculations';
  @override String get activeSessionsMetric => 'Active Sessions';
  @override String get totalGrossWeightRegistryMetric => 'Total Gross Weight';
  @override String get refreshRegistry => 'Refresh Registry';
  @override String get searchCalculationsHint => 'Search by calculation code, title, import file, or notes...';
  @override String get calcCodeCol => 'Calc Code';
  @override String get shippingStrategyCol => 'Shipping Strategy';
  @override String get recommendedContainerCol => 'Recommended Container';
  @override String get linkPoProjectCol => 'Linked PO / Project';
  @override String get confirmSoftDelete => 'Confirm Soft Delete';
  @override String get confirmDeleteCalcMessage => 'Are you sure you want to delete this calculation session? It can be restored later.';
  @override String get operationFailed => 'Operation Failed';
  @override String get operationSuccessful => 'Operation Completed Successfully';
  @override String get showDeleted => 'Show Deleted';
  @override String get hideDeleted => 'Hide Deleted';
  @override String get restore => 'Restore';
  @override String cbmSessionDetailsTitle(String code) => 'Cargo Measurement Session Details ($code)';
  @override String get cbmSessionActiveBadge => 'Active Session';
  @override String get cbmSessionCancelledBadge => 'Cancelled Session';
  @override String cbmSessionLinkedPo(String po) => 'Linked PO: $po';
  @override String cbmSessionImportFile(String file) => 'Import File: $file';
  @override String get cbmSessionStandalone => 'Standalone Session';
  @override String cbmCargoNotes(String notes) => 'Cargo Notes: $notes';
  @override String cbmCreationDate(String date) => 'Created: $date';
  @override String cbmStrategy(String strategy) => 'Strategy: $strategy';
  @override String get cbmStandardMetricsTitle => 'Standard Metrics & Shipping Constraints:';
  @override String get cbmContainerComparisonTitle => 'Container Scenarios Comparison:';
  @override String get cbmScenarioApprovedStackable => 'Approved: Stackable Scenario';
  @override String get cbmScenarioApprovedNonStackable => 'Approved: Non-Stackable Scenario';
  @override String get cbmScenarioHypothesisCol => 'Scenario / Hypothesis';
  @override String get cbmScenarioStackableCol => 'Stackable Scenario';
  @override String get cbmScenarioNonStackableCol => 'Non-Stackable Scenario';
  @override String get cbmRequiredContainerCount => 'Required Container & Count';
  @override String get cbmSpaceUtilizationPercent => 'Space Utilization %';
  @override String get cbmReopenInCalcBtn => 'Reopen & Edit in Calculator';
  @override String get cbmEditMetadataBtn => 'Edit Metadata';
  @override String get cbmLinkToPoProjectBtn => 'Link to PO / Project';
  @override String get cbmPrintExportReportBtn => 'Print / Export Report';
  @override String cbmEditMetadataDialogTitle(String code) => 'Edit Session Details: $code';
  @override String get cbmMetadataTitleLabel => 'Calculation Title *';
  @override String get cbmMetadataNotesLabel => 'Notes & Cargo Remarks';
  @override String get cbmMetadataSavedSuccess => 'Calculation metadata updated successfully.';
  @override String cbmPrintableReportTitle(String code) => 'Printable Cargo Measurement Report ($code)';
  @override String get cbmPrintDownloadCsvBtn => 'Download CSV Data';
  @override String get cbmPrintReportBtn => 'Print Report';
  @override String cbmLinkPoDialogTitle(String code) => 'Link Calculation ($code) to Shipment / PO';
  @override String get cbmLinkSelectPoLabel => 'Select Purchase Order (PO)';
  @override String get cbmLinkSelectPoSearchHint => 'Search Purchase Order...';
  @override String get cbmLinkSelectProjectLabel => 'Select Project';
  @override String get cbmLinkSelectProjectSearchHint => 'Search Project...';
  @override String get cbmLinkSavedSuccess => 'Calculation record linked successfully.';
  @override String get cbmVisualPlannerTitle => 'Visual Container Load Planner';
  @override String get cbmFloorAreaUtilization => 'Floor Area Utilization';
  @override String get cbmWoodenPalletsFloor => 'Wooden Floor Pallets';
  @override String get cbmInternalDimensionsLabel => 'Internal Dimensions:';
  @override String get cbmPackageDimensionsCol => 'Dimensions L x W x H (cm)';
  @override String get cbmStackingAccepts => '📦 Stackable';
  @override String get cbmStackingRejects => '🚫 Non-Stackable';
  @override String get cbmNotLinked => 'Not Linked';
  @override String get cbmDownloadCsvTitle => 'Save Cargo Measurement Report (CSV / Excel)';
  @override String cbmSendingReportToScreen(String code) => 'Sending report $code to interactive print screen...';
  @override String get cbmRowLineCbm => 'CBM';
  @override String get cbmRowLineGross => 'Gross';
  @override String get cbmRowLineAirVol => 'Air Vol';
  @override String get copyAllCbmDataSuccess => 'All CBM session data copied to clipboard.';

  // ── Freight Studies (Shipping Scenarios) ───────────────────────────────────
  @override String get freightStudiesTitle => 'Freight Shipping Scenarios & Carrier Evaluation';
  @override String get scenariosEvaluatorTab => 'Scenarios Evaluator';
  @override String get savedEvaluationsLogTab => 'Saved Evaluations Log';
  @override String get extractFreightQuotes => 'Extract Freight Quotes';
  @override String get activeEditStudyBanner => 'Editing Saved Study';
  @override String get activeEditStudyHint => 'Modifying carrier quotes and parameters. Changes will be updated in the same study.';
  @override String get cancelEditAndStartNew => 'Cancel & Start New';
  @override String get avgWarehouseArrivalMetric => 'Avg Warehouse Arrival';
  @override String get earliestLineMetric => 'Earliest Carrier Line';
  @override String get latestLineMetric => 'Latest Carrier Line';
  @override String get recommendedLineMetric => 'Officially Recommended Line';
  @override String get studySetupAndParameters => 'Study Setup & Parameters';
  @override String get studyTitleLabel => 'Study Title';
  @override String get crdLabel => 'Cargo Ready Date (CRD)';
  @override String get avgForm4DaysLabel => 'Avg Form 4 Days';
  @override String get avgClearanceDaysLabel => 'Avg Clearance Days';
  @override String get cargoStackingType => 'Cargo Stacking';
  @override String get shippingCarrierOptions => 'Shipping Carrier Options & Quotes';
  @override String get addNewShippingOption => 'Add Shipping Option';
  @override String get freightForwarderCol => 'Freight Forwarder / Carrier';
  @override String get shippingLineCol => 'Shipping Line';
  @override String get vesselNameCol => 'Vessel Name';
  @override String get voyageCol => 'Voyage #';
  @override String get portOfLoadingCol => 'Port of Loading (POL)';
  @override String get portOfDischargeCol => 'Port of Discharge (POD)';
  @override String get sailingDateCol => 'Sailing Date (ETD)';
  @override String get estimatedArrivalDateCol => 'Estimated Arrival (ETA)';
  @override String get expectedDelayCol => 'Expected Delay (Days)';
  @override String get riskLevelCol => 'Risk Level';
  @override String get freeTimeDaysCol => 'Free Time (Days)';
  @override String get quoteCurrencyCol => 'Quote Currency';
  @override String get quoteDetails => 'Freight Quote Details';
  @override String get hideQuote => 'Hide Quote';
  @override String get totalQuoteValue => 'Total Quote Value';
  @override String get container40ftItem => 'Container 40ft Freight';
  @override String get container20ftItem => 'Container 20ft Freight';
  @override String get lclCbmItem => 'LCL CBM Freight';
  @override String get expressCourierItem => 'Express Courier';
  @override String get eurAtrItem => 'EUR.1 / ATR Certificate';
  @override String get solasVgmItem => 'SOLAS / VGM Fees';
  @override String get vgmNotificationItem => 'VGM Notification Fee';
  @override String get telexReleaseItem => 'Telex Release';
  @override String get insuranceItem => 'Marine Insurance';
  @override String get bookingCancellationItem => 'Booking Cancellation Fee';
  @override String get ics2FilingFeeItem => 'ICS2 Filing Fee';
  @override String get documentFeesItem => 'Document Fees';
  @override String get waiverLetterFeeItem => 'Waiver Letter Fee';
  @override String get othersFeeItem => 'Other Fees';
  @override String get dthcItem => 'Destination THC (DTHC)';
  @override String get storagePerWeekItem => 'Storage (First Week)';
  @override String get extraDayStorageItem => 'Storage (Extra Days)';
  @override String get clearanceBrokerFeeItem => 'Customs Broker Fee';
  @override String get inspectionFeeItem => 'Inspection & Regulatory Approvals';
  @override String get inlandTransportFeeItem => 'Inland Transport to Factory';
  @override String get portClearanceExpensesItem => 'Port, Demurrage & Clearance Expenses';
  @override String get suggestedSuffix => 'Suggested';
  @override String get applicable => 'Applicable';
  @override String get notApplicable => 'Not Applicable';
  @override String get itemPriceCol => 'Item Price';
  @override String get sideBySideComparison => 'Shipping Scenarios Comparison Matrix';
  @override String get saveAndSubmitStudy => 'Save Study & Results';
  @override String get saveDraftContinueLater => 'Save Draft';
  @override String get clearAndStartNew => 'Clear & Start New';
  @override String get totalStudiesMetric => 'Total Studies';
  @override String get avgTransitMetric => 'Avg Transit';
  @override String get withRecommendationMetric => 'With Recommendation';
  @override String get searchStudiesHint => 'Search by study code, title, or notes...';
  @override String get studyCodeCol => 'Study Code';
  @override String get optionsCountCol => 'Options Count';
  @override String get confirmDeleteStudyMessage => 'Are you sure you want to delete this study? It can be restored later from Show Deleted.';
  @override String get quantity => 'Quantity';
  @override String get activeStatus => 'Active';
  @override String get noResultsFound => 'No matching results found';
  @override String get linkImportFile => 'Link Import File';
  @override String get titleField => 'Title';
  @override String get linkPurchaseOrder => 'Link Purchase Order';
  @override String get linkProject => 'Link Project';
  @override String get confirmDelete => 'Confirm Delete';
  @override String get view => 'View';
  @override String get statusCol => 'Status';

  // ── Screen 6: Customs Studies & Consultations ──────────────────────────
  @override String get customsStudiesTitle => 'Customs Consultation & Tax Review Workspace';
  @override String get customsWorkspaceTab => 'Customs Workspace';
  @override String get consultationsLogTab => 'Consultations Log';
  @override String get brokerPriceListsTab => 'Broker Price Lists & Catalog';
  @override String get clearanceQuotesTab => 'Clearance Quotes & AI Extractor';
  @override String get taxReviewWorkspaceTab => 'Customs Duty Workspace';
  @override String get taxReviewLogTab => 'Tax Review Log';
  @override String get customsDutyReviewTitle => 'Customs Duty Review & Tax Calculation Workspace';
  @override String get customsInspectionReadiness => 'Customs Inspection Readiness';
  @override String get itemsAndDocsCount => 'Items & Documents Count';
  @override String get blockingIssuesCount => 'Clearance Blocking Issues';
  @override String get clearanceReadyStatus => 'Clearance Ready';
  @override String get avgReadinessMetric => 'Avg Readiness';
  @override String get openBlockingIssues => 'Open Blockers';
  @override String get searchConsultationsHint => 'Search by code, title, or broker...';
  @override String get statusFilterLabel => 'Status Filter';
  @override String get customsCalculationEngine => 'Customs Duty & Tax Calculation Engine';
  @override String get customsCalculationEngineSub => 'Auto-populates HS codes, CIF values, and regulatory requirements from linked POs and calculates Duties, VAT, and Development Fee.';
  @override String get fetchReconciledFinalInvoice => 'Fetch Final Reconciled Invoice & Packing List Items';
  @override String get syncHsRequirementsToChecklist => 'Sync HS Code Rules to Checklist';
  @override String get customsExchangeRate => 'Customs Exchange Rate';
  @override String get studyDateLabel => 'Customs Study Date';
  @override String get freightEgpLabel => 'Ocean/Air Freight';
  @override String get insuranceEgpLabel => 'Marine Insurance';
  @override String get customsTariffItemCol => 'HS Tariff Code';
  @override String get itemDescriptionAndOriginCol => 'Item Description & Origin';
  @override String get quantityAndUnitCol => 'Qty & Unit';
  @override String get fobEgpCol => 'FOB Value';
  @override String get cifEgpCol => 'CIF Base Value';
  @override String get customsDutyCol => 'Customs Duty';
  @override String get vatCol => 'VAT';
  @override String get otherTaxesCol => 'Schedule / Dev / Service';
  @override String get totalTaxesAndDutiesCol => 'Total Duties & Taxes';
  @override String get regulatoryRequirementsCol => 'Regulatory Requirements';
  @override String get customsChecklistTitle => 'Customs Documents & Regulatory Checklist';
  @override String get addNewChecklistItem => 'Add Checklist Item';
  @override String get responsiblePartyLabel => 'Responsible Party';
  @override String get blockingConditionTooltip => 'Blocking Item';
  @override String get nonBlockingConditionTooltip => 'Non-blocking Item';
  @override String get applyAndLinkFinancialEstimate => 'Apply & Link Financial Estimate';
  @override String get smartClearanceQuoteExtractor => 'Smart AI Clearance Quote Extractor';
  @override String get saveCustomsStudy => 'Save Customs Study';
  @override String get saveTaxReviewSession => 'Save Tax Review Session';
  @override String get saveConsultationChanges => 'Save Consultation Changes';
  @override String get consultationDetailsTitle => 'Customs Consultation & Review Details';
  @override String get blockingIssuesTitle => 'Open Customs Blocking Issues & Requirements';
  @override String get nafezaDeclarationBreakdown => 'Nafeza Customs Declaration & Fee Breakdown';
  @override String get categoryCol => 'Category';
  @override String get totalExpenses => 'Total Expenses';
  @override String get export => 'Export';
  @override String get allFiles => 'All Files';
  @override String get requiredDocCheckbox => 'Required Document';
  @override String get blockingShipmentCheckbox => 'Blocks Shipment & Release';
  @override String get responsibleCustomsBroker => 'Customs Broker';
  @override String get responsibleSupplierExporter => 'Supplier / Exporter';
  @override String get responsibleImporterTeam => 'Importer Team';
  @override String get responsibleFreightForwarder => 'Freight Forwarder';
  @override String get validationIssuesTitle => 'Consultation Validation Warnings';
  @override String get validationIssuesDesc => 'Please complete the following required fields to save the study.';
  @override String get validationTitleRequired => 'Customs Consultation Title';
  @override String get validationTitleRequiredDesc => 'Required field cannot be empty.';
  @override String get validationTitleRequiredRec => 'Please provide a clear and concise title for the customs consultation.';
  @override String get validationBrokerRequired => 'Customs Broker';
  @override String get validationBrokerRequiredDesc => 'No customs broker selected for this study.';
  @override String get validationBrokerRequiredRec => 'Please select a customs broker from the dropdown.';
  @override String get validationChecklistRequired => 'Customs Checklist & Documents';
  @override String get validationChecklistRequiredDesc => 'The checklist is completely empty.';
  @override String get validationChecklistRequiredRec => 'Please add at least one document or requirement in the checklist.';
  @override String get consultationReviewChangesTitle => 'Review and Confirm Consultation Modifications';
  @override String get sectionGeneralInfo => 'General Study Information';
  @override String get sectionBrokerInfo => 'Customs Broker';
  @override String get sectionFinancialEstimates => 'Financial Estimates';
  @override String get sectionOperationalLink => 'Operational Linkage';
  @override String get sectionChecklistDocs => 'Document Checklist';
  @override String get totalDocsCountLabel => 'Total Documents & Requirements';
  @override String docsCountSuffix(dynamic count) => '$count documents';
  @override String get activeEditBannerDesc => 'Modify inspection items, documents, and fees, then click "Save Changes" to update this study or "Save as New Copy" to create a separate study.';
  @override String activeEditBannerTitle(dynamic code) => 'Active Edit Mode: You are editing customs consultation ($code)';
  @override String get saveEditsBtn => 'Save Changes';
  @override String get saveAsNewCopyBtn => 'Save as New Copy';
  @override String get cancelEditTooltip => 'Cancel editing and return as a new blank study';
  @override String get convertedToNewSessionToast => 'Session converted to a new separate study. Click "Save" to persist.';
  @override String get defaultStudyTitleClearance => 'Preliminary customs consultation & inspection study';
  @override String get defaultStudyTitleTaxReview => 'Shipment customs duty & tax review calculation';
  @override String get varianceCol => 'Variance';
  @override String get preliminaryPoLabel => 'Preliminary:';
  @override String get recalculatedLabel => 'Recalculated:';
  @override String get varianceLabel => 'Variance:';
  @override String get originPrefix => 'Origin:';
  @override String get applyRecalculatedDutiesTitle => 'Adopt and Apply Recalculated Duties & Taxes';
  @override String applyRecalculatedDutiesSuccess(dynamic amount) => 'Successfully applied recalculated duties and taxes ($amount EGP). You can now save or update the consultation.';
  @override String get selectImportFileFirstWarning => 'Please select an import shipment file first to fetch the final invoice.';
  @override String recalculationSuccessMsg(dynamic num) => 'Successfully fetched reconciled invoice & packing list items ($num) and recalculated duties.';
  @override String get recalculationFallbackMsg => 'Duties calculated based on preliminary PO items (no reconciled final invoice found yet).';
  @override String recalculationErrorMsg(dynamic err) => 'Failed to fetch and recalculate items: $err';
  @override String get applyAllQuoteItems => 'Apply All';
  @override String get disableAllQuoteItems => 'Disable All';
  @override String get addCustomExpenseRow => 'Add Custom Expense';
  @override String get quoteItemApplicable => 'Applied';
  @override String get quoteItemNotApplicable => 'Not Applied';
  @override String get quoteItemPrice => 'Item Price';
  @override String get quoteItemQuantity => 'Quantity';
  @override String get quoteItemCurrency => 'Currency';
  @override String get selectBrokerFirstMsg => 'Please select a customs broker to view and apply their approved price list.';
  @override String get filterByBroker => 'Filter by Broker';
  @override String get searchBrokerHint => 'Search broker...';
  @override String get createBrokerPriceListBtn => 'Create New Broker Price List';
  @override String get noBrokerPriceListsFound => 'No price lists found for selected brokers.';
  @override String get addPriceListNowBtn => 'Add Price List Now';
  @override String get activePriceListStatus => 'Active';
  @override String get archivedPriceListStatus => 'Archived';
  @override String get editPricesAndItemsBtn => 'Edit Prices & Items';
  @override String get archivePriceListTooltip => 'Archive Price List';
  @override String get confirmArchivePriceListTitle => 'Confirm Price List Archival';
  @override String confirmArchivePriceListMsg(dynamic title) => 'Are you sure you want to archive price list "$title"?';
  @override String get archiveBtn => 'Archive';
  @override String get priceListNotesHeader => 'Notes & Terms:';
  @override String get expenseItemNameCol => 'Expense Item Name';
  @override String get expenseCategoryCol => 'Category';
  @override String get expenseUnitCol => 'Unit';
  @override String get standardPriceCol => 'Approved Standard Price';
  @override String get priceRangeAndNotesCol => 'Price Range / Notes';
  @override String get searchExpenseCatalogHint => 'Search expense catalog...';
  @override String get addNewExpenseTypeBtn => 'Add New Expense Type';
  @override String get expenseCodeCol => 'Code';
  @override String get expenseNameArCol => 'Expense Name (Arabic)';
  @override String get expenseNameEnCol => 'Expense Name (English)';
  @override String get calculationUnitCol => 'Calculation Unit';
  @override String get defaultCurrencyCol => 'Default Currency';
  @override String get newExpenseTypeDialogTitle => 'Add New Expense Type to Catalog';
  @override String get expenseCodeField => 'Expense Code (e.g. EXP-CLR-050)';
  @override String get expenseNameArField => 'Expense Name in Arabic *';
  @override String get expenseNameEnField => 'Expense Name in English (Optional)';
  @override String get defaultCalculationUnitField => 'Default Calculation Unit';
  @override String get saveExpenseBtn => 'Save Expense';
  @override String get noBrokersRegistered => 'No customs brokers registered in partners.';
  @override String editPriceListTitle(dynamic title) => 'Edit & Update Broker Price List: $title';
  @override String get createPriceListTitle => 'Create New Customs Broker Price List';
  @override String get priceListTitleField => 'Price List Title *';
  @override String get targetPortField => 'Target Port';
  @override String get effectiveDateField => 'Effective Date';
  @override String get generalTermsAndNotesField => 'General Notes & Conditions';
  @override String get filterCategoryLabel => 'Filter Category';
  @override String get allCategoriesItem => 'All Categories';
  @override String get fillStandardRatesBtn => 'Fill with Standard Benchmark Rates';
  @override String get zeroOutRatesBtn => 'Reset All to Zero';
  @override String get standardRatesFilledToast => 'Egyptian standard benchmark rates filled successfully!';
  @override String get approvedPriceField => 'Approved Standard Price *';
  @override String get notesPriceRangeField => 'Notes / Price Range';
  @override String totalExpensesCountSummary(dynamic total, dynamic priced) => 'Total price list items: $total items ($priced priced items)';
  @override String get savePriceListEditsBtn => 'Save Price List Changes';
  @override String get createAndSavePriceListBtn => 'Create & Save Price List';
  @override String get priceListTitleRequired => 'Please provide a price list title.';
  @override String get selectBrokerRequired => 'Please select a customs broker';
  @override String get priceListUpdatedSuccess => 'Price list updated successfully!';
  @override String get priceListCreatedSuccess => 'Broker price list created successfully!';
  @override String get customsExpenseCodingTitle => 'Reference Customs Expense Coding';
  @override String get linkAsAliasTab => '🔗 Link as Alias to Approved Code';
  @override String get registerNewCatalogCodeTab => '➕ Register New Code in Catalog';
  @override String get approvedCatalogItemLabel => 'Approved Catalog Item *';
  @override String get searchApprovedCatalogHint => 'Search approved catalog items...';
  @override String get documentAliasLabel => 'Name or Alias in Document *';
  @override String get documentAliasHint => 'e.g. Port discharge fees / Tolls / Exceptional fees';
  @override String get referenceItemCodeLabel => 'Reference Item Code *';
  @override String get searchReferenceCodeHint => 'Search or select reference code...';
  @override String get officialCategoryLabel => 'Official Category *';
  @override String get canonicalArabicNameLabel => 'Official Arabic Name *';
  @override String get canonicalEnglishNameOptionalLabel => 'English Name (Optional)';
  @override String get unitTypeLabel => 'Unit Type *';
  @override String get approvedPriceLabel => 'Approved Rate *';
  @override String get itemNotesAndConditionsLabel => 'Item Notes & Conditions';
  @override String get saveAndMapAliasBtn => 'Save & Map Alias';
  @override String get registerCodeInCatalogBtn => 'Register Code in Catalog';
  @override String itemCodedSuccessfullyToast(dynamic alias, dynamic code) => '✨ "$alias" successfully mapped to reference code $code';
  @override String itemRegisteredInCatalogToast(dynamic code) => '✨ New reference code $code registered in catalog successfully';
  @override String get needsCodingBadge => 'Needs Coding';
  @override String get customItemBadge => 'Custom Item';
  @override String get deleteCustomItemTooltip => 'Delete Custom Item';
  @override String get addCustomItemOrAliasBtn => '➕ Code New Item or Link Alias';
  @override String get smartFileExtractionBtn => '✨ Smart File Extraction';
  @override String get fillApprovedArabicNameRequired => 'Please enter the official Arabic item name';
  @override String get selectReferenceCodeRequired => 'Please select or enter the reference item code';
  @override String get pleaseEnterItemPrice => 'Please enter a rate';
  @override String get invalidItemPrice => 'Invalid price rate';
  @override String get selectDateTooltip => 'Select Date';
  @override String get showArchivedChip => 'Show Archived';
  @override String get hideArchivedChip => 'Hide Archived';
  @override String get restoreConsultationTitle => 'Restore Customs Consultation';
  @override String restoreConsultationMsg(dynamic code, dynamic title) => 'Do you want to restore and activate customs consultation "$code - $title"?';
  @override String get restoreAndActivateBtn => 'Restore & Activate';
  @override String restoreConsultationSuccess(dynamic code) => 'Successfully restored consultation ($code)';
  @override String get deleteConsultationTitle => 'Confirm Consultation Deletion';
  @override String deleteConsultationMsg(dynamic code, dynamic title) => 'Are you sure you want to delete customs consultation "$code - $title"?\n\nIt will be archived and can be restored later.';
  @override String get deleteAndArchiveBtn => 'Delete & Archive';
  @override String deleteConsultationSuccess(dynamic code) => 'Successfully deleted and archived consultation ($code)';
  @override String get restoreDeletedTooltip => 'Restore deleted study';
  @override String get deleteStudyTooltip => 'Delete study (soft delete)';
  @override String blockingIssuesBadge(dynamic count) => '$count blocking';
  @override String approvedDocsCountBadge(dynamic approved, dynamic total) => '$approved/$total approved documents';
  @override String get agreementEur1 => 'EU-Egypt Association Agreement (EUR.1)';
  @override String get agreementEur1Doc => 'Original EUR.1 Movement Certificate or Invoice Declaration';
  @override String agreementEur1Exemption(dynamic rate) => 'Full import duty exemption (0% instead of $rate%) under EU-Egypt Association Agreement.';
  @override String get agreementMercosur => 'Mercosur Free Trade Agreement';
  @override String get agreementMercosurDoc => 'Original Mercosur Certificate of Origin complying with origin rules';
  @override String agreementMercosurExemption(dynamic rate) => 'Full import duty exemption (0% instead of $rate%) under Mercosur FTA.';
  @override String get agreementGafta => 'Greater Arab Free Trade Area (GAFTA)';
  @override String get agreementGaftaDoc => 'Unified Arab Certificate of Origin certified by Chamber of Commerce and Customs';
  @override String agreementGaftaExemption(dynamic rate) => 'Full import duty exemption (0% instead of $rate%) under GAFTA Agreement.';
  @override String get agreementTurkey => 'Turkey Free Trade Agreement';
  @override String get agreementTurkeyDoc => 'Official Turkish EUR.1 Movement Certificate';
  @override String agreementTurkeyExemption(dynamic rate) => 'Full import duty exemption for industrial goods (0% instead of $rate%) under Egypt-Turkey FTA.';
  @override String get agreementUk => 'UK-Egypt Association Agreement';
  @override String get agreementUkDoc => 'UK Origin Declaration on Invoice or EUR.1 Certificate';
  @override String agreementUkExemption(dynamic rate) => 'Full import duty exemption (0% instead of $rate%) under UK-Egypt Association Agreement.';
  @override String get nafezaCalculationFlat => 'Flat';
  @override String get nafezaCalculationReference => 'Reference';
  @override String get nafezaCalculationDerived => 'Derived';
  @override String get nafezaCollectionPrefix => 'Collection of';
  @override String get statusClearanceReady => 'Clearance Ready';
  @override String get statusBlocked => 'Blocked';
  @override String get statusActionRequired => 'Action Required';
  @override String get statusPendingReview => 'Pending Review';
  @override String get statusApproved => 'Approved';
  @override String get statusRejected => 'Rejected';
  @override String get statusVerified => 'Verified';
  @override String get statusReceived => 'Received';
  @override String get freightAutoFetchedToast => 'Freight auto-fetched from shipping scenarios';
  @override String get noPoItemsForHsSync => 'No purchase order items found to sync HS requirements';
  @override String hsRequirementsSyncedToast(dynamic count, dynamic addedCount) => 'Synced requirements for $count HS items — added $addedCount documents to checklist';
  @override String get acidReqChecklistDoc => 'Pre-registration ACID Filing for shipment (Nafeza)';
  @override String get cooReqChecklistDoc => 'Certified Certificate of Origin for full shipment';
  @override String get goeicReqChecklistDoc => 'GOEIC Inspection filing for full shipment';
  @override String authorityApprovalChecklistDoc(dynamic authority) => 'Prior regulatory approval from $authority';
  @override String brokerQuoteExtractedToast(dynamic broker) => 'Successfully extracted and applied clearance quote items ($broker)';
  @override String activeEditModeBannerTitle(dynamic code) => 'Active Edit Mode: You are modifying customs consultation study #($code)';
  @override String get activeEditModeBannerSub => 'Modify inspection data, documents, and fees, then click "Save Changes" to update this study, or "Save as New Copy" to create a separate study.';
  @override String get saveAsNewCopy => 'Save as New Copy';
  @override String get modifiedCopySuffix => 'Modified Copy';
  @override String get convertedToNewStudyToast => 'Session converted to a new separate study. Click "Save Customs Study" to save.';
  @override String get defaultTaxReviewSessionTitle => 'Customs Duty & Tax Assessment for Shipment';
  @override String get defaultCustomsConsultationTitle => 'Preliminary Customs Review for Production Line & Equipment';
  @override String get selectImportFileFirstToast => 'Please select an import file first to fetch the final invoice.';
  @override String get defaultCustomsBrokerName => 'Clearance Office';
  @override String get defaultImportItemDescription => 'Imported Item';
  @override String get customPriceListNoRegisteredTitle => 'Custom Price List (No approved registered price list found)';
  @override String get customsStudyValidationAlertsTitle => 'Study Validation Alerts';
  @override String get completeRequiredDataErrorMsg => 'Please complete the following required fields to save the study successfully.';
  @override String get consultationTitleFieldValidation => 'Customs Consultation Title';
  @override String get consultationTitleFieldIssue => 'Required field cannot be left blank.';
  @override String get consultationTitleFieldRec => 'Please enter a clear and concise title for the customs consultation.';
  @override String get customsBrokerFieldValidation => 'Designated Customs Broker';
  @override String get customsBrokerFieldIssue => 'No customs broker assigned for this file review.';
  @override String get customsBrokerFieldRec => 'Please select a customs broker from the dropdown.';
  @override String get checklistFieldValidation => 'Customs Checklist & Documents';
  @override String get checklistFieldIssue => 'Document checklist is completely empty.';
  @override String get checklistFieldRec => 'Please add at least one document or requirement to the checklist.';
  @override String get reviewCustomsStudyDiffTitle => 'Review & Confirm Customs Study Changes';
  @override String get diffSectionGeneralData => 'General Study Data';
  @override String get diffSectionCustomsBroker => 'Customs Broker';
  @override String get diffSectionFinancialEstimates => 'Financial Estimates';
  @override String get diffSectionOperationalLink => 'Operational Link';
  @override String get diffSectionChecklist => 'Document Checklist';
  @override String get diffFieldEstimatedDuties => 'Estimated Duties & Taxes';
  @override String get diffFieldLinkedImportFile => 'Linked Import File';
  @override String get diffFieldTotalChecklistDocs => 'Total Documents & Requirements';
  @override String get customsStudySavedSuccess => 'Customs duty and tax review saved successfully!';
  @override String get customsStudyUpdatedSuccess => 'Customs duty review updated successfully!';
  @override String get unableToSaveCustomsStudy => 'Unable to save customs consultation';

  // ── Screen 57: Original Documents Collection & Courier ──────────────────
  @override String get originalDocsAndCargoXScaffoldTitle => 'Original Docs Collection & CargoX Hub — Phase 4';
  @override String get originalDocsCollectionTabTitle => 'Original Docs Collection & Courier';
  @override String get cargoxBlockchainTabTitle => 'CargoX Blockchain & ACI Hub';
  @override String get refreshDataTooltip => 'Refresh Data';
  @override String get originalDocsHubTitle => 'Original Documents Collection & Courier Hub';
  @override String get originalDocsHubSubtitle => 'Automatic retrieval of required documents from central archive, multi-courier package tracking (DHL / FedEx), and physical paper original verification.';
  @override String savedSessionBadge(dynamic code) => 'Saved Session: $code';
  @override String get selectImportFileLabel => 'Select Import File';
  @override String errorFetchingImportFiles(dynamic err) => 'Error fetching import files: $err';
  @override String errorFetchingArchiveData(dynamic err) => 'Error fetching archive data: $err';
  @override String get statTotalRequiredDocs => 'Total Required Documents';
  @override String get statReceivedOriginals => 'Physical Originals Received';
  @override String get statVerifiedDocs => 'Verified & Audited';
  @override String get statPendingDocs => 'Pending Verification';
  @override String get statReadinessRate => 'Completion & Readiness';
  @override String get courierDispatchPackagesHeader => 'Courier Dispatch Packages & AWBs:';
  @override String get addCourierAwbBtn => 'Add Courier AWB';
  @override String get noCouriersRegisteredMsg => 'No courier AWBs recorded yet. Click Add Courier to insert an express shipment.';
  @override String get courierTrackingNoField => 'Courier AWB / Tracking No';
  @override String get courierCompanyField => 'Courier Company';
  @override String get dispatchDateField => 'Dispatch Date (YYYY-MM-DD)';
  @override String get isReceivedCheckbox => 'Received';
  @override String get receivedByNameField => 'Received By';
  @override String get deleteCourierTooltip => 'Delete Courier Package';
  @override String get physicalDocsVerificationMatrixHeader => 'Physical Documents Verification Matrix:';
  @override String get addCustomDocBtn => 'Add Custom Document';
  @override String get defaultNewCustomDocName => 'New Additional Document';
  @override String get selectCourierPlaceholder => 'Select Courier';
  @override String get colCourierNo => 'Courier AWB';
  @override String get colDocCategory => 'Document Category';
  @override String get colDocName => 'Document Name';
  @override String get colRequirement => 'Requirement';
  @override String get colResponsibleParty => 'Responsible Party';
  @override String get colPhysicalReceived => 'Physical Received';
  @override String get colReceivedDate => 'Received Date';
  @override String get colVerified => 'Verified & Audited';
  @override String get colAuditor => 'Audited By';
  @override String get colDocStatus => 'Status';
  @override String get colRemarks => 'Remarks';
  @override String get colAction => 'Action';
  @override String get hintAuditor => 'Auditor';
  @override String get hintRemarks => 'Remarks...';
  @override String get reqBadgeYes => 'Yes';
  @override String get reqBadgeConditional => 'Conditional';
  @override String get reqBadgeNo => 'Optional';
  @override String get statusBadgeVerified => 'Verified';
  @override String get statusBadgeReceived => 'Received';
  @override String get statusBadgeInTransit => 'In Transit';
  @override String get statusBadgeDiscrepant => 'Discrepant';
  @override String get statusBadgePending => 'Pending';
  @override String get saveDraftSessionBtn => 'Save Draft';
  @override String get completeCollectionBtn => 'Complete Collection';
  @override String get unverifiedMandatoryDocsWarning => 'Mandatory documents remain unverified. Please enter an approval justification before final confirmation.';
  @override String sessionSavedSuccess(dynamic code) => 'Original documents collection session saved successfully [$code]';
  @override String sessionSaveError(dynamic err) => 'Error saving session: $err';
  @override String excelExportSuccess(dynamic bytes) => 'Excel file generated and exported successfully ($bytes bytes)';
  @override String excelExportError(dynamic err) => 'Error exporting Excel: $err';
  @override String get collectionRegistryHeader => 'Physical Documents Collection Registry:';
  @override String get searchRegistryHint => 'Search by code or shipment...';
  @override String get filterStatusAll => 'All Statuses';
  @override String get filterStatusDraft => 'Draft';
  @override String get filterStatusPartiallyReceived => 'Partially Received';
  @override String get filterStatusFullyReceived => 'Fully Received';
  @override String get filterStatusFullyVerified => 'Fully Verified';
  @override String get noRegisteredSessionsFound => 'No collection sessions registered yet.';
  @override String errorFetchingRegistry(dynamic err) => 'Error fetching registry: $err';
  @override String get colSessionCode => 'Session Code';
  @override String get colImportFile => 'Import File';
  @override String get colAcidNumber => 'ACID Number';
  @override String get colSupplierName => 'Foreign Supplier';
  @override String get colTotalDocs => 'Total Documents';
  @override String get colReceivedDocs => 'Received';
  @override String get colVerifiedDocs => 'Audited';
  @override String get colCompletionPercentage => 'Completion %';
  @override String get colUpdatedAt => 'Updated At';
  @override String get docCatCommercial => 'Commercial';
  @override String get docCatCertificate => 'Certificates';
  @override String get docCatShipping => 'Shipping';
  @override String get docCatEgyptImport => 'Egypt Import';
  @override String get docCatBanking => 'Banking';
  @override String get docCatRegulatory => 'Regulatory';
  @override String get docCatOther => 'Other';
  @override String get courierCompanyHandDelivery => 'Hand Delivery';
  @override String get courierCompanyOther => 'Other';
  @override String get partySupplier => 'Foreign Supplier';
  @override String get partyFreightForwarder => 'Freight Forwarder';
  @override String get partyCustomsBroker => 'Customs Broker';
  @override String get partyBank => 'Bank';
  @override String get partyImporter => 'Importer Company';
  @override String get partyCarrier => 'Shipping Line';
  @override String get sessionNotesLabel => 'General Collection Session Notes';
  @override String get overrideReasonLabel => 'Discrepancy / Incomplete Documents Override Justification';
  @override String get courierCompanyDhl => 'DHL';
  @override String get courierCompanyFedex => 'FedEx';
  @override String get courierCompanyAramex => 'Aramex';
  @override String get courierCompanyUps => 'UPS';
  @override String get courierCompanyNaqel => 'Naqel Express';
  @override String get courierCompanySmsa => 'SMSA Express';
  @override String get originalDocsExportTsvBtn => 'Export TSV';
  @override String get originalDocsExportExcelBtn => 'Export Excel';
  @override String get originalDocsPrintPdfBtn => 'Print PDF';
  @override String get originalDocsCopyDossierBtn => 'Copy Dossier';
  @override String get originalDocsCopiedDossierSuccess => 'Original documents collection dossier copied to clipboard successfully';
  @override String get originalDocsCopiedTsvSuccess => 'Documents table TSV exported and copied successfully';
  @override String get originalDocsCopiedExcelSuccess => 'Documents Excel exported successfully';
  @override String get originalDocsExportTsvDialogTitle => 'Export Documents Collection TSV';
  @override String get originalDocsExportExcelDialogTitle => 'Export Documents Collection Excel';
  @override String get originalDocsExportPdfDialogTitle => 'Print Original Documents Collection Statement';
  @override String get originalDocsDossierTitle => 'Original Documents Collection & Courier Tracking Dossier';
  @override String get originalDocsCopyRowSuccess => 'Row data copied to clipboard successfully';
  @override String get originalDocsTsvHeaderCourierNo => 'Courier No';
  @override String get originalDocsTsvHeaderDocCategory => 'Document Category';
  @override String get originalDocsTsvHeaderDocName => 'Document Name';
  @override String get originalDocsTsvHeaderRequirement => 'Requirement';
  @override String get originalDocsTsvHeaderResponsibleParty => 'Responsible Party';
  @override String get originalDocsTsvHeaderPhysicalReceived => 'Physical Received';
  @override String get originalDocsTsvHeaderReceivedDate => 'Received Date';
  @override String get originalDocsTsvHeaderVerified => 'Verified';
  @override String get originalDocsTsvHeaderAuditor => 'Auditor';
  @override String get originalDocsTsvHeaderStatus => 'Status';
  @override String get originalDocsTsvHeaderRemarks => 'Remarks';
  @override String get originalDocsRegistryDossierTitle => 'Original Documents Collection Sessions Registry';
  @override String get originalDocsRegistryTsvHeaderCode => 'Session Code';
  @override String get originalDocsRegistryTsvHeaderFile => 'Import File';
  @override String get originalDocsRegistryTsvHeaderAcid => 'ACID Number';
  @override String get originalDocsRegistryTsvHeaderSupplier => 'Foreign Supplier';
  @override String get originalDocsRegistryTsvHeaderTotalDocs => 'Total Docs';
  @override String get originalDocsRegistryTsvHeaderReceivedDocs => 'Received Docs';
  @override String get originalDocsRegistryTsvHeaderVerifiedDocs => 'Audited Docs';
  @override String get originalDocsRegistryTsvHeaderCompletion => 'Completion %';
  @override String get originalDocsRegistryTsvHeaderStatus => 'Status';
  @override String get originalDocsRegistryTsvHeaderUpdatedAt => 'Updated At';
  @override String get originalDocsRegistryCopiedSuccess => 'Sessions registry dossier copied to clipboard successfully';
  @override String get originalDocsLoadSessionTooltip => 'Open & Load Session';
  @override String get courierAlertsHeader => 'Courier SLA Alerts & Receipt Tracking';
  @override String courierAlertCriticalCount(dynamic count) => '$count delayed couriers exceeded SLA limit';
  @override String courierAlertWarningCount(dynamic count) => '$count couriers approaching SLA deadline';
  @override String get courierTrackingRegistryTab => 'Courier Tracking & Delivery Proof Registry';
  @override String get sessionsRegistryTab => 'Sessions & Documents Registry';
  @override String get confirmCourierDeliveryBtn => 'Confirm & Record Delivery Receipt';
  @override String get courierDeliveryProofDialogTitle => 'Record Courier Delivery Proof (POD)';
  @override String get courierReceiptDateLabel => 'Actual Receipt Date';
  @override String get courierReceiptTimeLabel => 'Receipt Time (HH:mm)';
  @override String get courierReceivedByLabel => 'Received By';
  @override String get courierPodRefLabel => 'POD Reference / Delivery Note';
  @override String get markAssociatedDocsReceivedLabel => 'Auto-mark associated documents as "Received"';
  @override String get courierReceiptRecordedSuccess => 'Courier receipt proof recorded successfully';
  @override String daysInTransitLabel(dynamic days) => '$days days in transit';
  @override String get filterStatusInTransit => 'In Transit';
  @override String get filterStatusDelivered => 'Delivered';

  // ── Screen 59: Production Sync Screen & Hub ───────────────────────────────
  @override String get prodSyncScreenTitle => 'Production Sync Hub';
  @override String get prodSyncScreenSubtitle => 'Direct in-app database synchronization and updates tool';
  @override String get prodSyncHubDialogTitle => 'Production Sync & Backup Hub';
  @override String get prodSyncHubDialogSubtitle => 'Schema upgrade, backups management & restore — without affecting operational data';
  @override String get prodSyncTabCompareTables => 'Database Sync & Tables';
  @override String get prodSyncTabSchemaUpgrade => 'Schema Upgrade';
  @override String get prodSyncTabSafetyBackups => 'Safety Backups & Restore';
  @override String get prodSyncDevDbTitle => 'Development Database (Dev DB)';
  @override String get prodSyncDevDbSubtitle => 'Active database file in current workspace';
  @override String get prodSyncDevDbUpgradeSub => 'Source of new features and schema upgrades';
  @override String get prodSyncProdDbTitle => 'Production Database (Prod DB)';
  @override String get prodSyncProdDbSubtitle => 'Bundled database in standalone package';
  @override String get prodSyncProdDbUpgradeSub => 'Target — 100% operational data protected';
  @override String prodSyncDbSize(dynamic size) => 'Size: $size KB';
  @override String prodSyncDbTablesCount(dynamic count) => 'Tables: $count';
  @override String prodSyncDbRecordsCount(dynamic count) => 'Records: $count';
  @override String prodSyncFullySynchronizedTitle(dynamic matched) => 'Databases are fully synchronized 100% ($matched matching tables)';
  @override String get prodSyncFullySynchronizedSub => 'Production is running on the latest version fully compatible with development.';
  @override String prodSyncDifferencesDetectedTitle(dynamic differing) => 'Data differences detected ($differing tables with pending updates)';
  @override String get prodSyncDifferencesDetectedSub => 'You can synchronize and update the production database with one click without reinstalling.';
  @override String prodSyncUpgradeReadyTitle(dynamic count) => 'New features ready for upgrade ($count tables)';
  @override String get prodSyncUpgradeReadySub => 'Click "Upgrade Production" to add new features only — your data is fully protected.';
  @override String get prodSyncSafetyGuaranteeTitle => 'Full Operational Data Safety Guarantee';
  @override String get prodSyncSafetyGuaranteeBody => 'Upgrade only adds new tables & columns • Never deletes records • Preserves suppliers, companies, POs, and shipment files • Automatic safety backup taken before start';
  @override String get prodSyncSyncNowBtn => 'Sync & Update Production Now';
  @override String get prodSyncUpgradeBtn => 'Upgrade Production (Schema Upgrade)';
  @override String get prodSyncPullFromProdBtn => 'Pull from Production (Pull)';
  @override String get prodSyncCreateSnapshotBtn => 'Create Snapshot Backup';
  @override String get prodSyncCreateDevSnapshotBtn => 'Backup Dev DB Now';
  @override String prodSyncTablesMatchHeader(dynamic filtered, dynamic total) => 'System Tables Inspection ($filtered / $total tables)';
  @override String prodSyncTablesUpgradeHeader(dynamic filtered, dynamic total) => 'Table Details ($filtered / $total) — Different tables will receive new columns only';
  @override String get prodSyncSearchTablesHint => 'Search tables...';
  @override String prodSyncDevRecordsCount(dynamic count) => 'Dev: $count records';
  @override String prodSyncProdRecordsCount(dynamic count) => 'Prod: $count records';
  @override String get prodSyncTableStatusUpdated => 'Updated ✓';
  @override String get prodSyncBackupsSectionHeader => 'Archived Database Safety Snapshots';
  @override String get prodSyncBackupsSectionSub => 'Encrypted backups are saved in backups/ directory before any sync operation to guarantee 100% data safety';
  @override String get prodSyncBackupsDialogSub => 'You can restore any snapshot — a current safety backup is automatically taken before restore';
  @override String get prodSyncNoBackupsFound => 'No backup snapshots saved yet';
  @override String get prodSyncNoBackupsDialogSub => 'Backups are created automatically before every upgrade and upon system exit';
  @override String get prodSyncRestoreToProdBtn => 'Restore → Prod';
  @override String get prodSyncRestoreToDevBtn => 'Restore → Dev';
  @override String prodSyncBackupCreatedAt(dynamic date) => 'Created: $date';
  @override String prodSyncBackupSize(dynamic size) => 'Size: $size KB';
  @override String prodSyncBackupTag(dynamic tag) => 'Type: $tag';
  @override String get prodSyncConfirmUpgradeTitle => 'Confirm Production Upgrade';
  @override String get prodSyncConfirmUpgradeWhatHappens => 'What will happen:\n• Automatic safety backup taken before start\n• New tables added (if any)\n• New columns added to each existing table\n• New reference master data merged (INSERT OR IGNORE)';
  @override String get prodSyncConfirmUpgradeWhatWontHappen => 'What will never happen:\n• Operational data (suppliers, companies, POs, shipments) will remain untouched\n• No records in production will be deleted\n• No manually entered operational data will be modified';
  @override String get prodSyncConfirmUpgradeSubmitBtn => 'Confirm Upgrade';
  @override String get prodSyncConfirmRestoreTitle => 'Confirm Restore';
  @override String prodSyncConfirmRestoreMsg(dynamic target) => 'The following backup snapshot will be restored to $target database:';
  @override String get prodSyncConfirmRestoreWarning => 'A safety snapshot of the current state will be taken before restore, then the database will be replaced with the selected backup.';
  @override String get prodSyncConfirmRestoreSubmitBtn => 'Confirm Restore';
  @override String get prodSyncTargetProdLabel => 'Production (Prod)';
  @override String get prodSyncTargetDevLabel => 'Development (Dev)';
  @override String prodSyncBackupCreatedSuccess(dynamic filename) => 'Backup created successfully: $filename';
  @override String prodSyncSyncError(dynamic err) => 'Sync failed: $err';
  @override String prodSyncPullError(dynamic err) => 'Pull failed: $err';
  @override String prodSyncRestoreError(dynamic err) => 'Restore failed: $err';
  @override String get prodSyncComparingDatabasesProgress => 'Checking and comparing databases...';
  @override String prodSyncErrorFetchingComparison(dynamic err) => 'Error fetching comparison data: $err';
  @override String get prodSyncExportTsvBtn => 'Export TSV';
  @override String get prodSyncExportExcelBtn => 'Export Excel';
  @override String get prodSyncExportPdfBtn => 'Diagnostics Report (PDF)';
  @override String get prodSyncCopyDossierBtn => 'Copy Sync Dossier';
  @override String get prodSyncCopyDossierSuccess => 'Production sync dossier copied to clipboard successfully';
  @override String get prodSyncExportTsvSuccess => 'Table data copied to clipboard successfully';
  @override String get prodSyncExportExcelSuccess => 'Excel spreadsheet exported successfully';
  @override String get prodSyncCopyRowSummaryBtn => 'Copy Row Details';
  @override String get prodSyncCopyRowSummarySuccess => 'Table summary copied to clipboard';
  @override String get prodSyncCopyFieldTooltip => 'Copy value';
  @override String get prodSyncVersionBadgeLabel => 'Version';
  @override String get prodSyncDevDbPathBadge => 'Dev DB Path';
  @override String get prodSyncProdDbPathBadge => 'Prod DB Path';
  @override String get prodSyncBackupTagBadge => 'Backup Type';
  @override String get prodSyncBackupFilenameBadge => 'Backup Filename';
  @override String get prodSyncTsvHeaderTableName => 'Table Name';
  @override String get prodSyncTsvHeaderDevCount => 'Dev Records';
  @override String get prodSyncTsvHeaderProdCount => 'Prod Records';
  @override String get prodSyncTsvHeaderDiff => 'Diff';
  @override String get prodSyncTsvHeaderStatus => 'Match Status';
  @override String get prodSyncTsvHeaderBackupFile => 'Backup File';
  @override String get prodSyncTsvHeaderBackupTag => 'Backup Type';
  @override String get prodSyncTsvHeaderBackupSize => 'Size (KB)';
  @override String get prodSyncTsvHeaderBackupDate => 'Created Date';
  @override String get prodSyncScreenHeaderTitle => 'System Updates & Backups Hub';
  @override String get prodSyncScreenHeaderSubtitle => 'Automated safe database upgrade, recovery snapshots, and cloud version checking';
  @override String get prodSyncRefreshSystemStatusTooltip => 'Refresh System Status';
  @override String get prodSyncTabUpdatesAndBackups => 'Updates & Safety Backups';
  @override String get prodSyncTabDevToolsAndDiff => 'Dev Tools & Live Diff';
  @override String get prodSyncSystemUpToDateMsg => 'System is up to date and running the latest version.';
  @override String get prodSyncCheckingCloudUpdates => 'Checking for cloud updates...';
  @override String get prodSyncOfflineModeMsg => 'System is operating in standalone offline mode.';
  @override String prodSyncInstallVersionNow(dynamic version) => 'Install v$version Now';
  @override String get prodSyncLaunchInstallerNow => 'Launch Installer Now';
  @override String get prodSyncInstallingStatus => 'Installing...';
  @override String get prodSyncCheckUpdatesBtn => 'Check for Updates';
  @override String get prodSyncCancelBtn => 'Cancel';
  @override String prodSyncDownloadingProgress(dynamic percent, dynamic downloaded, dynamic total) => 'Downloading update... $percent% ($downloaded of $total MB)';
  @override String get prodSyncAutoCloseNotice => 'The application will close automatically once the download finishes to apply the update.';
  @override String get prodSyncDownloadCompleteNotice => 'Update downloaded successfully! Click Launch Installer Now to install.';
  @override String get prodSyncDownloadFailedFallback => 'Download failed. Please try again.';
  @override String get prodSyncRetryBtn => 'Retry';
  @override String prodSyncWhatsNewInVersion(dynamic version) => 'New features in version $version:';
  @override String prodSyncInstallConfirmTitle(dynamic version) => 'Install Version $version';
  @override String prodSyncInstallConfirmDesc(dynamic size) => 'Will download ($size) and install the new version automatically.';
  @override String get prodSyncInstallSafeNotice1 => 'No data will be lost — database is fully protected';
  @override String get prodSyncInstallSafeNotice2 => 'Application will close automatically during installation';
  @override String get prodSyncInstallSafeNotice3 => 'Installation takes approximately 10 seconds';
  @override String get prodSyncLaterBtn => 'Later';
  @override String get prodSyncDownloadAndInstallNowBtn => 'Download & Install Now';
  @override String get prodSyncSchemaEngineTitle => 'In-Place Schema Upgrade Engine';
  @override String get prodSyncSchemaEngineDesc => 'The system automatically takes a safety snapshot before each upgrade, adding new tables and columns without touching operational data.';
  @override String get prodSyncCreateInstantBackupBtn => 'Create Instant Recovery Point';
  @override String prodSyncBackupsArchiveHeader(dynamic count) => 'Safety Backups & Recovery Archive ($count saved)';
  @override String get prodSyncRefreshListTooltip => 'Refresh List';
  @override String get prodSyncNoBackupsInFolder => 'No previous backups found in directory.';
  @override String get prodSyncAutoPreUpgradeTag => 'Auto Pre-Upgrade';
  @override String get prodSyncManualBackupTag => 'Manual Backup';
  @override String get prodSyncRestoreActionBtn => 'Restore';
  @override String get prodSyncCompareTablesBtn => 'Inspect & Compare Tables';
  @override String get prodSyncDbNotFoundNotice => 'File not found yet (will be created upon first sync)';
  @override String prodSyncDbLastModified(dynamic date) => 'Last modified: $date';
  @override String prodSyncDbSizeLabel(dynamic size) => 'Size: $size KB';
  @override String get prodSyncConfirmRestoreTitleDialog => 'Confirm Backup Restore';
  @override String prodSyncConfirmRestoreMsgDialog(dynamic name) => 'Are you sure you want to restore this backup: $name?';
  @override String get prodSyncConfirmRestoreSafeNotice => 'The system will automatically create an immediate safety backup of current state before restoring to guarantee zero data loss.';
  @override String get prodSyncCancelAction => 'Cancel';
  @override String get prodSyncRestoreNowAction => 'Restore Now';
  @override String prodSyncActionStarting(dynamic name) => 'Starting operation: $name...';
  @override String prodSyncActionSuccess(dynamic name) => 'Operation [$name] completed successfully!';
  @override String prodSyncActionFailed(dynamic name) => 'Operation [$name] finished with errors. Check the log.';
  @override String prodSyncActionUnexpectedErr(dynamic err) => 'Unexpected error: $err';
  @override String prodSyncDiffStatusNewRecords(dynamic count) => '+$count new records to add';
  @override String get prodSyncDiffStatusNewTable => 'Entirely New Table';
  @override String prodSyncDiffStatusProdSurplus(dynamic count) => '$count in Production';
  @override String get prodSyncDiffStatusMatched => 'Fully Matched';
  @override String get prodSyncDiffFilterModified => 'Modified Only';
  @override String prodSyncDiffFilterAll(dynamic count) => 'All Tables ($count)';
  @override String get prodSyncDiffFilterMatched => 'Matched';
  @override String get prodSyncDiffPanelTitle => 'Database Changes Ready for Production';
  @override String get prodSyncDiffPanelSubtitle => 'Detailed breakdown of table differences with new or modified records';
  @override String get prodSyncDiffCheckBtn => 'Check Changes Now';
  @override String get prodSyncDiffEmptyInstruction => 'Click "Check Changes Now" or "Compare Tables" to inspect exact updates';
  @override String get prodSyncDiffAllMatchedSuccess => 'No differences found — all tables are 100% matched with production!';
  @override String get prodSyncDiffNoSearchResults => 'No tables match the current search filter.';
  @override String get prodSyncTerminalTitle => 'Production Sync Live Terminal';
  @override String get prodSyncTerminalReadyMsg => 'Ready. Select an operation from above to begin.';
  @override String get prodSyncTerminalRunningMsg => 'Executing...';
  @override String get prodSyncTerminalCopyTooltip => 'Copy Terminal Log';
  @override String get prodSyncTerminalClearTooltip => 'Clear Terminal';
  @override String get prodSyncTerminalCopiedToast => 'Full terminal output log copied to clipboard';
  @override String prodSyncProgressTablesCount(dynamic current, dynamic total, dynamic synced) => 'Tables: $current of $total | Total records synced: $synced';

  // ── Screen 63: Goods In Transit (GIT) Ledger ─────────────────────────────
  @override String get gitLedgerTabTitle => 'Goods In Transit (GIT) Ledger';
  @override String get gitLedgerScaffoldTitle => 'Goods In Transit (GIT) Inventory Ledger';
  @override String gitErrorFetchingData(dynamic err) => 'Error fetching goods in transit data: $err';
  @override String get gitInfoBannerTitle => 'Goods In Transit Ledger - Detailed by PO';
  @override String get gitInfoBannerSubtitle => 'This ledger tracks in-transit inventory from certified invoices and packing lists. Quantities are deducted automatically upon warehouse receiving confirmation.';
  @override String get gitExportExcelBtn => 'Export Excel';
  @override String get gitExportSuccessMsg => 'Goods in transit ledger exported successfully';
  @override String get gitKpiInTransitShipments => 'In-Transit Shipments';
  @override String gitKpiShipmentsValue(dynamic count) => '$count shipments';
  @override String get gitKpiPurchaseOrders => 'Purchase Orders';
  @override String gitKpiPurchaseOrdersValue(dynamic count) => '$count POs';
  @override String get gitKpiInvoicedQuantity => 'Total Invoiced Qty';
  @override String gitKpiQuantityValue(dynamic qty) => '$qty units';
  @override String get gitKpiPackagesCount => 'Total Packages & Cartons';
  @override String gitKpiPackagesValue(dynamic count) => '$count pkgs';
  @override String get gitKpiActiveContainers => 'Active Containers';
  @override String gitKpiContainersValue(dynamic count) => '$count containers';
  @override String get gitSearchHint => 'Search file code, PO number, item code or description...';
  @override String get gitFilterAll => 'All Goods';
  @override String get gitFilterInTransitOnly => 'In-Transit Only (Active Balance)';
  @override String get gitFilterDeliveredOnly => 'Delivered to Warehouse Only';
  @override String get gitRefreshTooltip => 'Refresh Ledger';
  @override String get gitTableSectionHeader => 'Goods In Transit Inventory Breakdown by PO';
  @override String get gitNoDataFound => 'No in-transit goods matching search criteria.';
  @override String get gitColFileCode => 'Import File Code';
  @override String get gitColPoNumber => 'PO Number';
  @override String get gitColItemCode => 'Item Code';
  @override String get gitColItemName => 'Item Description';
  @override String get gitColInvoicedQty => 'Invoiced Qty';
  @override String get gitColPackagesCount => 'Packages & Cartons';
  @override String get gitColContainers => 'Containers & Types';
  @override String get gitColCertifiedDate => 'Certified Date';
  @override String get gitColLedgerStatus => 'Ledger Status';
  @override String get gitStatusDeliveredToWarehouse => 'Delivered to Warehouse';
  @override String get gitStatusInTransit => 'In Transit (GIT)';
  @override String get gitExportTsvBtn => 'Export TSV';
  @override String get gitPrintPdfBtn => 'Print PDF';
  @override String get gitCopyDossierBtn => 'Copy Dossier';
  @override String get gitCopiedTsvSuccess => 'Goods in transit TSV data copied and exported successfully';
  @override String get gitCopiedExcelSuccess => 'Goods in transit ledger exported to Excel successfully';
  @override String get gitCopiedDossierSuccess => 'Full goods in transit dossier copied to clipboard';
  @override String get gitCopyRowSummaryBtn => 'Copy Item Summary';
  @override String get gitCopyRowSummarySuccess => 'Goods in transit item summary copied to clipboard';
  @override String get gitCopyFieldTooltip => 'Copy value';
  @override String get gitPdfTitle => 'Goods In Transit (GIT) Inventory Ledger Report';
  @override String get gitPdfSubtitle => 'Comprehensive Tracking of In-Transit Shipments and Customs Matching';
  @override String get gitDossierHeader => 'Goods In Transit Ledger & Matching Dossier';
  @override String get gitDossierKpiSummary => 'Ledger KPI Summary';
  @override String get gitDossierRecordsDetails => 'Goods In Transit Line Items Breakdown';
  @override String get gitDossierFooter => 'End of Goods In Transit Dossier — Verified by ImportFlow ERP';
  @override String get gitPackageTypeCol => 'Package Type';
  @override String get gitContainerTypeCol => 'Container Type';
  @override String get gitColActions => 'Actions';

  // ── Screen 64: Warehouse Received Shipments Detailed Report ───────────────
  @override String get whReportTabTitle => 'Received Shipments Detailed Report';
  @override String get whReportScaffoldTitle => 'Warehouse Received Shipments & Audit Report';
  @override String whReportErrorFetchingData(dynamic err) => 'Error fetching received shipments report: $err';
  @override String get whReportInfoBannerTitle => 'Received Shipments Detailed Audit';
  @override String get whReportInfoBannerSubtitle => 'Comprehensive breakdown of all warehouse-received shipments detailed by PO, reconciling invoiced quantities against actual received, shortages, damages, and drawn samples.';
  @override String get whReportExportExcelBtn => 'Export Excel';
  @override String get whReportExportSuccessMsg => 'Received shipments report exported successfully';
  @override String get whReportKpiInvoicedQty => 'Total Invoiced Qty';
  @override String get whReportKpiReceivedQty => 'Actual Received at Warehouse';
  @override String get whReportKpiDamagedQty => 'Total Damaged Qty';
  @override String get whReportKpiShortageQty => 'Total Shortage Qty';
  @override String get whReportKpiSamplesQty => 'Drawn Inspection Samples';
  @override String get whReportKpiVarianceQty => 'Net Quantity Variance';
  @override String whReportUnitsValue(dynamic count) => '$count units';
  @override String get whReportSearchHint => 'Search by file code, PO number, item code or description...';
  @override String get whReportTableSectionHeader => 'Received Items Breakdown by PO';
  @override String get whReportNoDataFound => 'No received shipments matching search criteria.';
  @override String get whReportColImportFile => 'Import File';
  @override String get whReportColPoNumber => 'Purchase Order (PO)';
  @override String get whReportColContainerAndTruck => 'Containers & Truck';
  @override String get whReportColItemAndDescription => 'Item & Description';
  @override String get whReportColInvoicedQty => 'Invoiced Qty';
  @override String get whReportColShortageQty => 'Shortage Qty';
  @override String get whReportColDamagedQty => 'Damaged Qty';
  @override String get whReportColSamplesQty => 'Drawn Samples';
  @override String get whReportColReceivedQty => 'Warehouse Received';
  @override String get whReportColVarianceQty => 'Variance';
  @override String get whReportColReceiptStatus => 'Receipt Status';
  @override String get whReportStatusApprovedAndReceived => 'Approved & Received';
  @override String get whReportExportTsvBtn => 'Export TSV';
  @override String get whReportPrintPdfBtn => 'Print PDF Report';
  @override String get whReportCopyDossierBtn => 'Copy Comprehensive Dossier';
  @override String get whReportCopiedTsvSuccess => 'Received shipments report copied to clipboard as TSV successfully';
  @override String get whReportCopiedExcelSuccess => 'Received shipments report copied to clipboard as Excel CSV successfully';
  @override String get whReportCopiedDossierSuccess => 'Received shipments comprehensive dossier copied to clipboard successfully';
  @override String get whReportCopyRowSummaryBtn => 'Copy Row Summary';
  @override String get whReportCopyRowSummarySuccess => 'Row summary copied to clipboard successfully';
  @override String get whReportCopyFieldTooltip => 'Copy value to clipboard';
  @override String get whReportSearchCopied => 'Search query copied to clipboard';
  @override String get whReportColActions => 'Actions';
  @override String get whReportColWarehouse => 'Warehouse';
  @override String get whReportColArrivalDate => 'Arrival Date';
  @override String whReportCopyBadgeSuccess(String label, String value) => 'Copied $label ($value) to clipboard';
  @override String get whReportPdfTitle => 'Warehouse Received Shipments & Audit Detailed Report';
  @override String get whReportPdfSubtitle => 'Comprehensive breakdown of shipments and POs reconciling actual quantities with invoiced, shortages, and damages';
  @override String get whReportDossierHeader => 'Warehouse Received Shipments & Reconciliation Detailed Dossier';
  @override String get whReportDossierKpiSummary => 'Warehouse Operational KPI Summary';
  @override String get whReportDossierRecordsDetails => 'Detailed Received Shipments & Items Records';
  @override String get whReportDossierFooter => 'End of Report - Sorour Logistics Import & Warehouse Management';

  // ── Screen 8: Financial Approvals & Budgets ─────────────────────────────
  @override String get financialApprovalsTitle => 'Financial Approvals & Budget Management';
  @override String get paymentRequestsTab => 'Supplier Payment Requests';
  @override String get importBudgetApprovalTab => 'Import Budget Approval';
  @override String get savedBudgetsRegistryTab => 'Saved Budgets Registry';
  @override String get paymentRequestsRegistryTab => 'Payment Requests Log';
  @override String get swiftReconciliationTab => 'SWIFT MT103 Reconciliation';
  @override String get createPaymentRequestTitle => 'Issue Supplier Payment Request';
  @override String get editPaymentRequestTitle => 'Edit Payment Request';
  @override String get activeEditModeBanner => 'Active Edit Mode';
  @override String get cancelEdit => 'Cancel Edit';
  @override String get paymentTitleLabel => 'Payment Request Title';
  @override String get paymentTypeLabel => 'Payment Type / Terms';
  @override String get requestedAmountLabel => 'Requested Amount';
  @override String get beneficiarySupplierLabel => 'Beneficiary Supplier';
  @override String get selectSupplierFromMasterData => 'Select Supplier from Master Data';
  @override String get beneficiaryBankDetails => 'Beneficiary Bank Details';
  @override String get bankNameLabel => 'Bank Name';
  @override String get swiftCodeLabel => 'SWIFT Code';
  @override String get ibanAccountLabel => 'IBAN / Account Number';
  @override String get requestDateLabel => 'Request Date';
  @override String get dueDateLabel => 'Due Date';
  @override String get paymentNotesLabel => 'Payment Request Notes';
  @override String get issuePaymentRequestButton => 'Issue Payment Request to Finance';
  @override String get savePaymentChangesButton => 'Save Payment Request Changes';
  @override String get importBudgetSetupTitle => 'Import File Comprehensive Budget Approval';
  @override String get budgetTitleLabel => 'Budget Title';
  @override String get estimatedInvoiceValue => 'Estimated Invoice Value';
  @override String get estimatedFreightCost => 'Estimated Freight Cost';
  @override String get customsAndVatEstimate => 'Customs & VAT Estimate';
  @override String get clearanceAndTransportEstimate => 'Clearance & Inland Transport';
  @override String get budgetApprovalNotes => 'Budget Approval Instructions & Notes';
  @override String get approveAndCertifyBudget => 'Approve & Certify Budget';
  @override String get saveBudgetChanges => 'Save Budget Changes';
  @override String get totalBudgetEgp => 'Total Approved Budget';
  @override String get consolidatedBudgetSummary => 'Multi-Currency Budget Allocation Report';
  @override String get totalBudgetsMetric => 'Total Budgets';
  @override String get approvedBudgetsMetric => 'Approved Budgets';
  @override String get pendingBudgetsMetric => 'Pending / Draft';
  @override String get totalValueEgpMetric => 'Total Value';
  @override String get searchBudgetsHint => 'Search by budget code, title, or shipment...';
  @override String get searchPaymentsHint => 'Search by request code, supplier, or file...';
  @override String get paymentRequestsLogTitle => 'Supplier Payments & Transfers Registry';
  @override String get noMatchingPayments => 'No payment requests match search and filters.';
  @override String get noMatchingBudgets => 'No budgets match search and filters.';
  @override String get swiftExtractorTitle => 'SWIFT MT103 Bank Transfer Extractor & Matcher';
  @override String get swiftUploadDocument => 'Upload SWIFT Document';
  @override String get swiftPasteText => 'Paste SWIFT Raw Text';
  @override String get swiftMatchedSuccess => 'Matched with Payment Request Successfully';
  @override String get swiftExecuteReconciliation => 'Execute Financial Reconciliation';
  @override String get paymentCodeCol => 'Payment Code';
  @override String get bankSwiftCol => 'Bank / SWIFT';
  @override String get equivalentEgpCol => 'Equivalent (EGP)';
  @override String get requestDueDateCol => 'Request / Due Date';
  @override String get draftStatus => 'Draft';
  @override String get paidStatus => 'Paid';
  @override String get reconciledStatus => 'Reconciled';
  @override String get importFile => 'Import File';
  @override String get notLinked => 'Not Linked';
  @override String get currencyCol => 'Currency';
  @override String get exchangeRateCol => 'Exchange Rate';
  @override String get poNumberCol => 'PO Number';
  @override String get projectNameCol => 'Project Name';
  @override String get invoiceAmount => 'Invoice Amount';
  @override String get reset => 'Reset';
  @override String get budgetApprovalTab => 'Budget Approval';
  @override String get savedBudgetsTab => 'Saved Budgets';
  @override String get paymentRequestsLogTab => 'Payment Registry';
  @override String get paymentRequestHeader => 'Issue Supplier Payment Request';
  @override String get paymentRequestSub => 'Generate financial transfer request to finance department';
  @override String get duplicatePaymentRequestTitle => 'Duplicate Payment Request Already Saved';
  @override String duplicatePaymentRequestMessage(String code, String title) => '⚠️ A previous payment request has already been saved for this import file ($code - $title).\n\nPer policy, duplicate requests cannot be created; please review or edit the existing request.';
  @override String get cancelSelection => 'Cancel Selection';
  @override String get viewAndEditPaymentRequest => 'View & Edit Current Payment Request';
  @override String get duplicateBudgetTitle => 'Budget Approval Already Saved';
  @override String duplicateBudgetMessage(String code, String title) => '⚠️ A budget has already been approved for this import file ($code - $title).\n\nPer policy, duplicate budget approvals cannot be created; please review or edit the existing budget.';
  @override String get viewAndPrintBudget => 'View & Print Current Budget';
  @override String paymentRequestUpdatedSuccess(String code) => '✅ Payment request ($code) updated successfully';
  @override String paymentRequestCreatedSuccess(String code) => '✅ Payment request ($code) issued successfully';
  @override String get savePaymentFailedTitle => 'Failed to Save Payment Request';
  @override String paymentLoadedForEditMsg(String code) => '✏️ Payment request ($code) loaded for editing';
  @override String budgetLoadedForEditMsg(String code) => '✏️ Budget ($code) loaded into form for editing';
  @override String get confirmDeletePaymentTitle => 'Confirm Payment Request Deletion';
  @override String confirmDeletePaymentMessage(String code, String title) => 'Are you sure you want to delete payment request ($code - $title)?\n\nThe record will be archived and can be restored later.';
  @override String paymentDeletedSuccess(String code) => '🗑️ Payment request ($code) deleted successfully';
  @override String deleteErrorMsg(String error) => '❌ Error during deletion: $error';
  @override String budgetUpdatedSuccess(String code) => '✅ Import budget ($code) updated successfully';
  @override String budgetCreatedSuccess(String code) => '✅ Import budget ($code) approved and saved';
  @override String get saveBudgetFailedTitle => 'Failed to Approve and Save Import Budget';
  @override String get swiftPaymentPrefix => 'SWIFT Wire Transfer Payment';
  @override String get orderingCustomerPrefix => 'Ordering Customer / Remitter';
  @override String get paymentDetailsPrefix => 'Details';
  @override String swiftDataExtractedSuccess(String filename) => filename.isNotEmpty ? '📄 SWIFT data extracted successfully from "$filename" and form populated ⚡' : '⚡ SWIFT bank data extracted and form populated successfully!';
  @override String get emptyTextError => 'Empty text';
  @override String get swiftTextParseError => '⚠️ Unable to parse SWIFT data from text. Please verify the text contains wire transfer details.';
  @override String swiftFileExtractError(String err) => '❌ Failed to extract data from file: $err';
  @override String paymentRequestDetailsTitle(String code) => 'Payment Request: $code';
  @override String beneficiarySupplierDetails(String supplier) => 'Beneficiary Supplier: $supplier';
  @override String get foreignAmountMetric => 'Foreign Currency Amount';
  @override String get exportAndShareOptionsTitle => 'Export, Print & Direct Sharing Options:';
  @override String get paymentDataCopied => '📋 Payment request data copied to clipboard successfully';
  @override String get extractAndMatchSwiftBtn => 'Extract & Match SWIFT ⚡';
  @override String get swiftReferenceInputLabel => 'SWIFT Copy / Transfer Reference *';
  @override String get approvePaymentAction => 'Approve Request';
  @override String get markAsPaidAction => 'Confirm Payment & Mark as Paid';
  @override String get sendPaymentWhatsAppTitle => 'Send Payment Details via WhatsApp';
  @override String get whatsAppNumberLabel => 'WhatsApp Number with Country Code (Optional - e.g. 201001234567)';
  @override String get whatsAppNumberHint => 'Leave blank to select contact directly in WhatsApp';
  @override String get messagePreviewLabel => 'Message Preview:';
  @override String get openWhatsAppBtn => 'Open in WhatsApp 🚀';
  @override String get sendPaymentEmailTitle => 'Send Payment Request via Email';
  @override String get recipientEmailLabel => 'Recipient Email Address';
  @override String emailSubjectLabel(String subject) => 'Subject: $subject';
  @override String get openEmailClientBtn => 'Open Email Client 📧';
  @override String budgetDetailsTitle(String code) => 'Budget Approval: $code';
  @override String get budgetReportCopied => '📋 Budget report copied to clipboard successfully';
  @override String get sendBudgetWhatsAppTitle => 'Share Budget Approval via WhatsApp';
  @override String get sendBudgetEmailTitle => 'Send Budget Report via Email';
  @override String get approveNewBudgetAction => 'Approve New Budget';
  @override String budgetCodeCopied(String code) => '📋 Budget code ($code) copied to clipboard';
  @override String get approvedByLabel => 'Approved by:';
  @override String get printOfficialPdf => 'Print Official PDF';
  @override String get importCostItemCol => 'Import Cost Item';
  @override String get amountInCurrencyCol => 'Value in Currency';
  @override String get commercialInvoiceItem => 'Commercial Invoice Value';
  @override String get freightItem => 'International Freight';
  @override String get customsAndVatItem => 'Customs Duties & VAT';
  @override String get clearanceAndInlandTransportItem => 'Clearance & Inland Transport Fees';
  @override String get totalApprovedBudgetItem => 'Total Certified Budget';
  @override String get notesAndInstructionsLabel => 'Notes & Instructions:';
  @override String get confirmDeleteBudgetTitle => 'Confirm Budget Deletion';
  @override String confirmDeleteBudgetMessage(String code, String title) => 'Are you sure you want to delete budget ($code - $title)?';
  @override String budgetDeletedSuccess(String code) => '🗑️ Budget ($code) deleted successfully';
  @override String get noBudgetsPlaceholderMessage => 'Create a new import budget or adjust search filters';
  @override String get approveNewBudgetNow => 'Approve New Budget Now ➕';
  @override String get paymentSummaryCopied => '📋 Payment request data copied successfully';
  @override String get budgetSummaryCopied => '📋 Budget approval summary copied to clipboard successfully';
  @override String get editInForm => 'Edit in Form';
  @override String get openMailClient => 'Open Mail Client';
  @override String get sendNow => 'Send Now';
  @override String get customsAuthority => 'Customs Authority';

  // ── Screen 11: Nafeza ACID Operations ───────────────────────────────────
  @override String get nafezaAcidTitle => 'Nafeza Advance Cargo Information (ACID)';
  @override String get searchAndCloneAcidBtn => 'Search & Clone ACID';
  @override String get searchAndCloneAcidDialogTitle => 'Search & Clone Previous ACID Request';
  @override String get searchAcidHint => 'Search by ACID number, file, supplier, or invoice...';
  @override String get noAcidsFound => 'No matching ACID requests found';
  @override String get cloneAcidSuccess => 'ACID request cloned successfully and ready for review';
  @override String get acidClonedResetNotice => 'Notice: ACID number and release status were reset automatically';
  @override String get importFromPreviousAcidSessionBtn => 'Import from Previous Session';
  @override String get rawTextImportedSuccess => 'Nafeza notice text successfully imported from previous session';
  @override String get cloneAcidRecordTooltip => 'Clone ACID record into new draft';
  @override String get copyDiscrepancyReportBtn => 'Copy Discrepancy Report';
  @override String get discrepancyReportCopiedSuccess => 'Customs discrepancy report copied to clipboard successfully';
  @override String get emptyComparisonHint => 'Select an import file and click "Run Comparison & Verification" to check ACID data against PO and invoice.';
  @override String get acidRequestTab => 'ACID Request Form';
  @override String get smartMtsParserTab => 'MTS Smart AI Parser';
  @override String get discrepancyMatrixTab => 'Discrepancy Matrix';
  @override String get acidRegistryTab => 'ACID Issuance Registry';
  @override String get expiryTrackerTab => 'Expiry & Release Tracker';
  @override String get acidInfoBanner => 'Register and request initial Egyptian Customs ACID number via Nafeza (MTS) portal. Select an import file to auto-populate importer and exporter details.';
  @override String get selectImportFileAcidLabel => 'Select Import File for ACID';
  @override String get searchFileOrSupplierHint => 'Search by file number, supplier, or company...';
  @override String get importerAndExporterSection => '1. Importer & Foreign Exporter Parties';
  @override String get importerSectionTitle => 'Importer Company';
  @override String get importerTaxIdLabel => 'Importer Tax ID';
  @override String get importerAddressLabel => 'Registered Importer Address';
  @override String get foreignExporterSectionTitle => 'Foreign Exporter';
  @override String get foreignExporterIdLabel => 'Foreign Exporter Reg / Tax ID';
  @override String get regTypeLabel => 'Registration Type';
  @override String get countryOfOriginExportLabel => 'Country of Origin / Export';
  @override String get cargoxPlatformIdLabel => 'CargoX Platform ID';
  @override String get proformaPortsBrokerSection => '2. Proforma Invoice, Ports & Customs Broker';
  @override String get proformaInvoiceNoLabel => 'Proforma Invoice No.';
  @override String get proformaInvoiceDateLabel => 'Invoice Date';
  @override String get invoiceTypeLabel => 'Presented Invoice Type';
  @override String get customsBrokerResponsibleLabel => 'Responsible Customs Broker';
  @override String get brokerPhoneLabel => 'Broker Phone Number';
  @override String get acidRequestDateLabel => 'ACID Request Date';
  @override String get saveAcidRequestButton => 'Save ACID Request & Send for Matching';
  @override String get updateAcidRequestButton => 'Update & Save ACID Request';
  @override String get goToSmartParserButton => 'Go to MTS Smart Parser';
  @override String get brokerDispatchMessageTitle => 'ACID Issuance Request Message for Customs Broker';
  @override String get brokerDispatchMessageSub => 'Message automatically generated with shipment details for instant dispatch to customs broker via WhatsApp or Email.';
  @override String get copyArabicWhatsApp => 'Copy Arabic (WhatsApp)';
  @override String get copyEnglishRequest => 'Copy English';
  @override String get emailTemplateButton => 'Email Template';
  @override String get smartParserInfoBanner => 'MTS Smart Parser: Paste raw text from Nafeza email/notification. The system will extract ACID number, validity, exporter, and importer details automatically.';
  @override String get linkImportFileResult => 'Link to Import File';
  @override String get pasteRawMtsTextTitle => 'Paste Raw Nafeza MTS Text Here';
  @override String get loadSampleMtsTextButton => 'Load Sample Nafeza Text';
  @override String get pasteFromClipboardButton => 'Paste from Clipboard';
  @override String get runSmartParserButton => 'Run Smart Parser & Extract Data';
  @override String get clearTextButton => 'Clear Text';
  @override String get parsedMtsSuccessTitle => 'Data Extracted Successfully from Nafeza Text';
  @override String get parsedMtsNoAcidTitle => 'Extraction Results (No ACID Number Found)';
  @override String get goToVerificationButton => 'Proceed to Discrepancy Verification';
  @override String get saveAndCertifyAcidButton => 'Save & Certify ACID for Shipment';
  @override String get saveTempDraftButton => 'Save as Draft';
  @override String get editExtractedDataButton => 'Edit Extracted Data';
  @override String get codeSupplierButton => 'Code / Update Supplier';
  @override String get acidNumberCol => 'ACID Number';
  @override String get issueDateCol => 'Issue Date';
  @override String get expiryDateCol => 'Expiry Date';
  @override String get foreignExporterCol => 'Foreign Exporter';
  @override String get importerCompanyCol => 'Importer Company';
  @override String get actionCol => 'Actions';
  @override String get daysRemainingCol => 'Days Remaining';
  @override String get validityStatusCol => 'Validity Status';
  @override String get runDiscrepancyMatrixButton => 'Run Instant Discrepancy Matrix';
  @override String get perfectMatchTitle => '100% Customs Match (No Discrepancies)';
  @override String get discrepancyFoundTitle => 'Discrepancies found in key customs fields!';
  @override String get customsFieldCol => 'Customs Field';
  @override String get requestedValueCol => 'Requested Value (System)';
  @override String get generatedValueCol => 'Generated Value (Nafeza)';
  @override String get matchingStatusCol => 'Match Status';
  @override String get discrepancyOverrideJustificationLabel => 'Discrepancy Override Justification';
  @override String get verifyAndCertifyAcidButton => 'Certify & Link ACID to Shipment';
  @override String get searchAcidRegistryHint => 'Search ACID registry by ACID number, supplier, file...';
  @override String get newAcidRequestButton => 'New ACID Request';
  @override String get totalAcidsCard => 'Total ACID Numbers';
  @override String get validAcidsCard => 'Valid (> 14 Days)';
  @override String get expiringSoonAcidsCard => 'Expiring Soon (≤ 14 Days)';
  @override String get expiredAcidsCard => 'Expired';
  @override String get searchExpiryTrackerHint => 'Search Expiry & Customs Release Tracker...';
  @override String get validStatusBadge => 'Valid & Active';
  @override String get expiringSoonStatusBadge => 'Expiring Soon';
  @override String get expiredStatusBadge => 'Expired';
  @override String get matchedStatus => 'Matched';
  @override String get discrepancyStatus => 'Discrepant';
  @override String get issuedAndValidStatus => 'Issued & Valid';
  @override String get tempDraftStatus => 'Draft';
  @override String get underReviewStatus => 'Under Review';
  @override String get commercialInvoiceLabel => 'Commercial Invoice';
  @override String get proformaInvoiceLabel => 'Proforma Invoice';
  @override String acidSessionDeletedSuccess(String code) => 'ACID ($code) deleted successfully';
  @override String acidSessionLoadedForEdit(String code) => 'ACID request ($code) opened for full edit';
  @override String get mtsExtractedDataUpdated => 'MTS Extracted Data Updated';
  @override String get errorSavingDraft => 'Error saving ACID draft';
  @override String get errorSavingAcid => 'Error saving ACID request';
  @override String get errorDeletingAcid => 'Error deleting ACID session';
  @override String get errorCustomsComparison => 'Error in customs comparison';
  @override String get errorCertifyingAcid => 'Error certifying ACID number';
  @override String get errorParsingMts => 'Error parsing Nafeza text';
  @override String get errorCodingSupplier => 'Error coding supplier';
  @override String get foreignSupplierNotInData => 'Foreign exporter name not found in Nafeza data';
  @override String supplierCodedSuccess(String name) => 'Foreign supplier ($name) coded and updated successfully';
  @override String acidRequestUpdatedSuccess(String code) => 'ACID request ($code) updated successfully';
  @override String get acidRequestSavedSuccess => 'ACID request registered and saved successfully';
  @override String get acidCertifiedSuccess => 'ACID number certified and confirmed successfully ✅';
  @override String get mtsNoticeDisclaimerAlertTitle => 'Warning: Email Disclaimer Text Only';
  @override String get mtsNoticeDisclaimerAlertContent => 'The pasted text contains only the legal email confidentiality disclaimer:\n\n«MTS EMAIL NOTICE This Electronic Mail...»\n\nIt does not contain ACID registration details (ACID number, validity date, exporter, and importer).\n\n👉 Please copy the main email body from the top, or click the button below to test a sample notice.';
  @override String get mtsNoticeNoAcidAlertTitle => 'No ACID Number Found in Pasted Text';
  @override String get mtsNoticeNoAcidAlertContent => 'The pasted text is missing the upper header lines from the Nafeza notice (which contain the 19-digit ACID number and validity dates).\n\n📌 To test immediately and view the full extraction table, click "Load Sample Nafeza Notice".';
  @override String get loadSampleMtsAndExtract => 'Load Sample Notice & Extract Now';
  @override String get loadSampleMtsAndTest => 'Load Sample Nafeza Notice & Test Now';
  @override String acidExtractedSuccess(String acid) => '✅ ACID Number: $acid and shipment data extracted successfully!';
  @override String get selectImportFileFirst => 'Please select import file first';
  @override String get pasteMtsTextFirst => 'Please paste Nafeza text first';
  @override String get selectImportFileToVerify => 'Please select import file to verify';
  @override String get whatsAppMessageCopied => '✅ WhatsApp Message Copied';
  @override String get acidRequestCopied => '✅ ACID Request Message Copied';
  @override String get emailTemplateCopied => '✅ Email Template Copied';
  @override String get discrepancyOverrideReasonHint => 'Discrepancy override reason...';
  @override String get mtsNotificationHint => 'MTS Notification [ACID: 19 digits]...';
  @override String get vatRegType => 'VAT Number';
  @override String get crRegType => 'Commercial Register (CR)';
  @override String get taxIdRegType => 'Tax ID';
  @override String get dunsRegType => 'DUNS Number';
  @override String get companyRegNumberType => 'Company Registration Number';
  @override String get foreignExporterNafezaType => 'Foreign Exporter Number (Nafeza)';
  @override String get factoryRegType => 'Factory Registration';
  @override String get poLabelPrefix => 'PO';

  // ── Screen 16: Bank Form 4 ──────────────────────────────────────────────
  @override String get bankForm4Title => 'Bank Form 4 & Financial Endorsement';
  @override String get form4RequestTab => 'Form 4 Request & Checklist';
  @override String get bankForm4RegistryTab => 'Bank Form 4 Registry';
  @override String bankForm4EditingBanner(String code) => 'You are currently editing banking document: $code';
  @override String get cancelEditNewForm4 => 'Cancel edit and start new request';
  @override String get selectImportFileForm4Label => 'Select Import File for Form 4 Issuance';
  @override String get bankApplicationDetailsSection => 'Bank Application & Endorsement Details';
  @override String get issuingBankLabel => 'Issuing Bank';
  @override String get selectBankHint => 'Select bank...';
  @override String get bankAmountLabel => 'Endorsement Amount';
  @override String get transferCurrencyLabel => 'Transfer Currency';
  @override String get selectCurrencyHint => 'Select currency...';
  @override String get bankRequestDateLabel => 'Bank Submission Date';
  @override String get bankNotesLabel => 'Special Instructions & Bank Notes';
  @override String get form4ChecklistSectionTitle => 'Required Attachments Checklist for Bank';
  @override String get form4ItemProformaInvoice => 'Proforma Invoice';
  @override String get form4ItemPackingList => 'Packing List';
  @override String get form4ItemCertificateOfOrigin => 'Certificate of Origin';
  @override String get form4ItemBillOfLading => 'Bill of Lading Draft';
  @override String get form4ItemAcidNotice => 'Nafeza ACID Notice';
  @override String get form4ItemMarineInsurance => 'Marine Insurance Certificate';
  @override String get form4ItemBankApplication => 'Signed & Stamped Bank Application';
  @override String get form4ItemAdminFeeReceipt => 'Admin Fee Payment Receipt';
  @override String get saveForm4Button => 'Save & Register Form 4 Request';
  @override String get updateForm4Button => 'Update Form 4';
  @override String get goToBankRegistryButton => 'Go to Bank Form 4 Registry';
  @override String get searchBankRegistryHint => 'Search bank registry by code, bank, import file...';
  @override String get newForm4RequestButton => 'New Form 4 Request';
  @override String get documentCodeCol => 'Document Code';
  @override String get certifiedBankCol => 'Certified Bank';
  @override String get amountAndCurrencyCol => 'Amount & Currency';
  @override String get requestDateCol => 'Submission Date';
  @override String get endorsementStatusCol => 'Endorsement Status';
  @override String get endorsedStatusBadge => 'Endorsed & Certified';
  @override String get bankProcessingStatusBadge => 'Under Bank Processing';
  @override String get form4SavedSuccess => 'Bank Form 4 saved successfully';
  @override String get form4SaveError => 'Error saving Bank Form 4';
  @override String get searchAndCloneBankForm4Btn => 'Clone From Previous Form 4';
  @override String get searchAndCloneBankForm4DialogTitle => 'Search & Clone Previous Bank Form 4';
  @override String get searchBankForm4Hint => 'Search by doc code, bank, shipment code, or amount...';
  @override String get noBankForm4Found => 'No matching bank form 4 records found';
  @override String get cloneBankForm4Success => 'Bank Form 4 data cloned successfully with mandatory reset invariants';
  @override String get bankForm4ClonedResetNotice => 'Form code will be reset to draft, request date reset, and unlinked from previous record';
  @override String get cloneBankForm4RecordTooltip => 'Clone Bank Form 4 Record';

  // ── Screen 18: Draft B/L Review ──────────────────────────────────────────
  @override String get draftBlStage0ReviewSheet => '1. Review Sheet & Checklist';
  @override String get draftBlStage1RevisionReport => '2. Revision Report & Carrier Letter';
  @override String get draftBlStage2VersionBranching => '3. Version Branching & History';
  @override String get draftBlStage3DualApproval => '4. Dual Approval Workspace';
  @override String get draftBlStage4FinalRegistry => '5. Final Certified Registry';
  @override String get draftBlReviewSheetTitle => 'Draft B/L Document Review Sheet';
  @override String get draftBlReviewSheetSub => 'The system automatically retrieves all shipment reference data from booking and packing list, comparing directly with shipping line draft.';
  @override String draftBlMismatchesFound(int count) => '$count Discrepancies Found';
  @override String get draftBlPerfectMatchReady => '100% Match Ready for Approval';
  @override String get draftBlSelectImportFileLabel => 'Import Shipment File *';
  @override String get draftBlRefreshAndCompare => 'Refresh & Compare Data';
  @override String get draftBlSmartExtractorTitle => '📥 Smart Extractor for Draft B/L Documents';
  @override String get draftBlSmartExtractorSub => 'Upload draft file directly from shipping line or paste draft text for instant extraction and matching';
  @override String get draftBlUploadAndExtractButton => '📁 Upload & Extract Draft File (PDF, Word, Excel)';
  @override String get draftBlExtractingFileProgress => 'Reading & extracting file data...';
  @override String draftBlFileExtractedSuccess(String filename, String sizeKb) => 'Extracted: $filename ($sizeKb KB)';
  @override String get draftBlReuploadTooltip => 'Re-upload another file';
  @override String get draftBlExtractedBlNumberLabel => 'Extracted B/L Number:';
  @override String get draftBlCopyBlNumberTooltip => 'Copy B/L Number';
  @override String draftBlCopiedBlNumberSnackbar(String blNumber) => '✔ Copied B/L Number ($blNumber) to clipboard';
  @override String get draftBlEditBlNumberTitle => 'Edit Bill of Lading Number';
  @override String get draftBlSafetyAlertTitle => '⚠️ Safety Alert: Extracted document contains incomplete critical fields requiring manual confirmation';
  @override String get draftBlSafetyAlertSub => 'Please review and confirm critical fields in the table below to avoid approval based on incomplete data.';
  @override String get draftBlSmartExtractionComplete => '✅ Smart extraction complete: all critical fields 100% verified.';
  @override String get draftBlPasteRawTextTitle => 'Or Paste Draft Text or Email Content Manually:';
  @override String get draftBlPasteRawTextHint => 'Paste text copied from draft B/L or email here...';
  @override String get draftBlExtractFromTextButton => '⚡ Extract & Match from Text';
  @override String get draftBlReferenceVisualSheetTitle => '1. System Reference Bill of Lading Sheet';
  @override String get draftBlReferenceVisualSheetSub => 'Reference data registered in system from supplier/importer master data, booking, and packing list';
  @override String get draftBlExtractedVisualSheetTitle => '5. Extracted Shipping Line Draft B/L Sheet';
  @override String get draftBlExtractedVisualSheetSub => 'Live verification and compliance check against Egyptian Customs Nafeza (ACID) standards';
  @override String get draftBlSwitchToGridView => 'Switch to Detailed Grid View';
  @override String get draftBlSwitchToVisualBl => 'View as Visual B/L Sheet';
  @override String get draftBlAutoSummaryTitle => '1. Auto-Generated Shipment Reference Summary';
  @override String get draftBlAutoSummarySub => 'Reference data registered in system from supplier/importer master records, booking, and packing list.';
  @override String get draftBlSummaryShipper => 'Shipper';
  @override String get draftBlSummaryConsignee => 'Consignee';
  @override String get draftBlSummaryNotifyParty => 'Notify Party';
  @override String get draftBlSummaryVesselVoyage => 'Vessel & Voyage';
  @override String get draftBlSummaryPorts => 'Ports (POL, POD)';
  @override String get draftBlSummaryFreightTerms => 'Freight Terms';
  @override String get draftBlSummaryBookingNo => 'Booking Reference';
  @override String get draftBlSummaryAcidNo => 'ACID Number';
  @override String get draftBlSummaryImporterTaxId => 'Importer Tax ID';
  @override String get draftBlSummaryShipperReg => 'Shipper Reg ID';
  @override String get draftBlSummaryContainers => 'Containers & Seals';
  @override String get draftBlSummaryGrossWeight => 'Gross Weight';
  @override String get draftBlSummaryNetWeight => 'Net Weight';
  @override String get draftBlSummaryCbm => 'Measurement (CBM)';
  @override String get draftBlSummaryPackages => 'Packages & Goods Description';
  @override String get draftBlChecklistSectionTitle => '2. Review & Verification Checklist';
  @override String get draftBlChecklistSectionSub => 'Direct field-by-field matching table between system data and draft values with status, action, and responsible party.';
  @override String get draftBlSaveSessionButton => 'Save Review Session';
  @override String get draftBlRevisionReportCarrierButton => 'Carrier Revision Report ➔';
  @override String get draftBlSelectFileToStartChecklist => 'Please select import file to begin automated verification';
  @override String get draftBlChecklistColField => 'Field Name';
  @override String get draftBlChecklistColSystemValue => 'System Value';
  @override String get draftBlChecklistColDraftValue => 'Draft Value';
  @override String get draftBlChecklistColStatus => 'Status';
  @override String get draftBlChecklistColRequiredAction => 'Required Action or Correction';
  @override String get draftBlChecklistColResponsibleParty => 'Responsible Party';
  @override String get draftBlChecklistColReasonNotes => 'Reason & Notes';
  @override String get draftBlStatusCorrect => 'Correct';
  @override String get draftBlStatusIncorrect => 'Incorrect';
  @override String get draftBlStatusNA => 'N/A';
  @override String get draftBlPartyShippingLine => 'Shipping Line';
  @override String get draftBlPartySupplier => 'Supplier';
  @override String get draftBlPartyImporter => 'Importer';
  @override String get draftBlPartyCustomsBroker => 'Customs Broker';
  @override String get draftBlCopySystemValueTooltip => 'Copy system value to draft & confirm match';
  @override String get draftBlEnterDraftValueHint => 'Enter draft value...';
  @override String get draftBlMatchedHint => 'Matched';
  @override String get draftBlEnterCorrectionHint => 'Enter required correction...';
  @override String get draftBlEnterReasonHint => 'Reason or Notes...';
  @override String get draftBlSelectFileToViewRevision => '⚠️ Please select import file first to view revision report and carrier letter';
  @override String get draftBlBackToSelectFile => 'Back to Select File';
  @override String get draftBlRevisionReportTitle => 'Required Amendments Report';
  @override String get draftBlRevisionReportSub => 'This report lists only mismatched items requiring amendment from shipping line or supplier.';
  @override String get draftBlProceedToVersionHistory => 'Proceed to Version History (Stage 3)';
  @override String get draftBlNoAmendmentsNeeded => 'Great! No amendments required. All draft items match system records perfectly.';
  @override String get draftBlRevisionColItem => 'Item';
  @override String get draftBlRevisionColRequiredAction => 'Required Action';
  @override String get draftBlRevisionColResponsible => 'Responsible Party';
  @override String get draftBlRevisionColReason => 'Reason';
  @override String get draftBlCarrierRequestLetterTitle => 'Official Carrier Amendment Request Letter';
  @override String get draftBlCopyLetterButton => 'Copy Letter';
  @override String get draftBlLetterCopiedSnackbar => '✔ Carrier amendment letter copied to clipboard';
  @override String get draftBlSelectFileToViewVersions => '⚠️ Please select import file first to view version management';
  @override String get draftBlVersionBranchingTitle => 'Version Branching & Locking';
  @override String get draftBlVersionBranchingSub => 'When receiving a revised draft (v2, v3), the system locks previously matched items and only re-opens items with remarks.';
  @override String get draftBlProceedToDualApproval => 'Proceed to Dual Approval (Stage 4)';
  @override String draftBlActiveVersionBanner(String version, String stage, int lockedCount) => 'Active Version: $version ($stage) | Locked Items: $lockedCount';
  @override String get draftBlSelectFileToCompleteApproval => '⚠️ Please select import file first to complete dual approval';
  @override String get draftBlApprovalBlockedTitle => '🚨 Approval Blocked: Critical discrepancies prevent B/L approval';
  @override String get draftBlImporterApprovalTitle => '1. Import Manager Approval';
  @override String get draftBlImporterApproverNameLabel => 'Import Manager Name *';
  @override String get draftBlImporterNotesLabel => 'Import Notes & Directives';
  @override String get draftBlApproveAndAcceptButton => 'Approve & Accept';
  @override String get draftBlRejectDraftButton => 'Reject Draft';
  @override String get draftBlBrokerApprovalTitle => '2. Customs Broker Approval';
  @override String get draftBlBrokerApproverNameLabel => 'Certified Broker Name *';
  @override String get draftBlBrokerNotesLabel => 'Clearance Notes & Nafeza Match';
  @override String get draftBlBrokerApproveButton => 'Customs Approval & Accept';
  @override String get draftBlFinalRegistryTitle => 'Final Certified B/L Registry';
  @override String get draftBlFinalRegistrySub => 'Certified versions here are locked and serve as governing document for original B/L issuance and customs release.';
  @override String get draftBlRefreshRegistry => 'Refresh Registry';
  @override String get draftBlSearchRegistryHint => 'Search by B/L number, session ID, shipping line, or stage...';
  @override String get draftBlNoRegistriesFound => 'No matching results found';
  @override String get draftBlNoRegistriesYet => 'No draft B/L review sessions recorded yet';
  @override String get draftBlTryDifferentSearch => 'Try searching with another B/L number';
  @override String get draftBlExtractNewDraftHint => 'Extract and approve a new draft B/L from the first tab';
  @override String get draftBlRegistryColSessionId => 'Session ID';
  @override String get draftBlRegistryColBlNumber => 'B/L Number';
  @override String get draftBlRegistryColShippingLine => 'Shipping Line';
  @override String get draftBlRegistryColVesselVoyage => 'Vessel & Voyage';
  @override String get draftBlRegistryColStage => 'Stage';
  @override String get draftBlRegistryColImporterApproval => 'Importer Approval';
  @override String get draftBlRegistryColBrokerApproval => 'Broker Approval';
  @override String get draftBlRegistryColStatus => 'Status';
  @override String get draftBlRegistryColActions => 'Actions';
  @override String get draftBlViewBlTooltip => 'View B/L';
  @override String get draftBlPrintBlTooltip => 'Print B/L';
  @override String get draftBlDownloadPdfTooltip => 'Download PDF';
  @override String get draftBlPrintButton => 'Print B/L';
  @override String get draftBlDownloadPdfButton => 'Download PDF';
  @override String get draftBlDownloadExcelButton => 'Download Excel';
  @override String get draftBlSessionSavedSuccess => '✔ Draft B/L review session saved successfully';
  @override String get draftBlSessionSaveError => 'Error saving review session';
  @override String draftBlComparisonMismatch(int count) => '⚠️ Draft extracted and compared: $count discrepancies require correction';
  @override String get draftBlComparisonMatchSuccess => '✔ Matched successfully: Draft B/L perfectly matches system data';
  @override String draftBlComparisonError(dynamic e) => 'Error during comparison: $e';
  @override String get draftBlFileReadError => 'Unable to read selected file data';
  @override String draftBlExtractedWithCritical(String fileName) => '⚠️ Extracted from ($fileName) with critical fields requiring manual confirmation';
  @override String draftBlExtractedSuccess(String fileName) => '✅ Draft data extracted successfully from ($fileName) and review fields populated';
  @override String draftBlExtractionError(dynamic e) => 'Error occurred while extracting file: $e';
  @override String get draftBlDualApprovalCompleted => '🎉 Dual Approval completed and Draft B/L finalized as approved';
  @override String get draftBlRevisionRequiredAlert => '⚠️ Draft rejected and returned to Revision Required stage';
  @override String draftBlRoleApprovalRegistered(String role) => '✔ $role approval registered successfully, awaiting secondary approval';
  @override String draftBlApprovalError(dynamic e) => 'Error during approval: $e';
  @override String get draftBlPdfExportSuccess => '✔ Bill of Lading exported to PDF successfully';
  @override String draftBlPdfExportError(dynamic e) => 'Error exporting PDF: $e';
  @override String draftBlPrintError(dynamic e) => 'Error sending print command: $e';
  @override String get searchFileOrShipmentHint => 'Search by file number or shipment code...';
  @override String get searchFileOrCompanyHint => 'Search by file number or company name...';
  @override String get unspecified => 'Unspecified';
  @override String get draftBlNoLetterGeneratedYet => 'No letter generated currently.';
  @override String get draftBlRegistryUpdatedSuccess => 'Final approved registry updated successfully';
  @override String draftBlPreviewSessionSnack(int id, String blNo) => 'Previewing Session #$id: $blNo';
  @override String get searchAndCloneDraftBlBtn => 'Clone Previous Draft B/L';
  @override String get searchAndCloneDraftBlDialogTitle => 'Search & Clone Draft B/L Review';
  @override String get searchDraftBlHint => 'Search by B/L number, shipping line, vessel, or review code...';
  @override String get noDraftBlFound => 'No matching draft B/L reviews found';
  @override String get cloneDraftBlSuccess => 'Draft B/L data cloned and reset successfully';
  @override String get draftBlClonedResetNotice => 'Notice: B/L number was reset, session ID unlinked, and dual approvals reset to Pending.';
  @override String get cloneDraftBlRecordTooltip => 'Clone this draft B/L';

  // ── Screen 19: Draft COO / EUR.1 Review ──────────────────────────────────
  @override String get cooStage1Requirements => '1. COO & EUR.1 Requirements';
  @override String get cooStage2DraftInput => '2. Draft Input & Extraction';
  @override String get cooStage3DiscrepancyMatrix => '3. Comparison Matrix & Discrepancies';
  @override String get cooStage4Registry => '4. COO Review Registry';
  @override String get cooDecisionEngineTitle => 'Customs COO Decision Engine';
  @override String get cooDecisionEngineSub => 'Intelligent certificate type routing based on invoice country of origin and international trade agreements';
  @override String get cooRecheckAgreementButton => 'Re-check Agreement';
  @override String cooInvoiceOriginBadge(String origin) => '🌍 Invoice Origin Country: $origin';
  @override String get cooManualChoiceRequiredBadge => '⚠️ Manual Selection Required (Multiple Agreements)';
  @override String cooApprovedCertBadge(String cert) => '✔ Approved Certificate: $cert';
  @override String cooExistingReviewBanner(String code, String status) => 'ℹ️ An existing study is registered for this file [Session: $code - Status: $status]. Updating this existing review prevents duplicate entries.';
  @override String get cooReviewRegistryButton => 'Review Registry';
  @override String get cooGenerateDraftHeader => 'Generate & Retrieve Official Draft Certificate of Origin';
  @override String get cooSelectImportFileLabel => 'Select Import File *';
  @override String get cooSearchFileHint => 'Search file number...';
  @override String get cooCertTypeLabel => 'Certificate Type *';
  @override String get cooSelectCertTypeHint => 'Select certificate type...';
  @override String get cooCertTypeEur1 => 'EUR.1 (Egypt-EU Agreement - Revised Rules)';
  @override String get cooCertTypeChina => 'China Certificate of Origin (CCPIT, China-Egypt)';
  @override String get cooCertTypeStandard => 'Standard Certificate of Origin (Standard COO)';
  @override String get cooCertTypeFormA => 'Form A - Generalized System of Preferences (GSP)';
  @override String get cooCertTypeAgadir => 'Agadir Agreement Certificate';
  @override String get cooCertTypeGafta => 'Greater Arab Free Trade Area (GAFTA) Certificate';
  @override String get cooOpenVisualPreviewButton => '⚡ Open Visual Preview & Export';
  @override String get cooNextDraftInputButton => 'Next: Draft Input';
  @override String get cooOfficialDraftPreviewTitle => 'Official Draft Certificate Preview';
  @override String get cooAutoFillFieldsButton => 'Apply & Auto-fill Fields';
  @override String get cooDraftFilledSuccess => '✔ Official draft data filled successfully';
  @override String cooGenerateDraftError(String e) => 'Error generating draft: $e';
  @override String get cooDraftInputTitle => 'Draft Certificate of Origin Input & Extraction';
  @override String get cooRunComparisonButton => 'Run Comparison';
  @override String get cooLinkedImportFileLabel => 'Select Linked Import File *';
  @override String get cooSelectFileWarning => '⚠️ Please select an import file first to extract data and compare against system records.';
  @override String get cooDraftCertNumberLabel => 'Draft Certificate Number *';
  @override String get cooOriginCountryLabel => 'Country of Origin *';
  @override String get cooDestinationCountryLabel => 'Destination Country *';
  @override String get cooExporterNameLabel => 'Exporter or Shipper Name *';
  @override String get cooExporterRegIdLabel => 'Exporter Foreign Reg ID or Tax Code';
  @override String get cooImporterNameLabel => 'Importer or Consignee Name *';
  @override String get cooInvoiceNumberLabel => 'Invoice Number *';
  @override String get cooSmartUploadButtonLabel => 'Smart Upload & AI COO Extractor (PDF, Word, Excel)';
  @override String get cooRawTextSectionTitle => 'Raw Draft Certificate Text (OCR):';
  @override String get cooSmartExtractFromTextButton => '⚡ Smart Extract & Fill from Text';
  @override String get cooRawTextHint => 'Paste full raw certificate text here (such as CCPIT or EUR.1 texts)...';
  @override String get cooPasteTextOrUploadWarning => 'Please paste certificate text or upload a file first';
  @override String get cooAiExtractSuccess => '✔ Certificate data extracted and matched by AI successfully';
  @override String cooExtractError(String e) => 'Error during extraction: $e';
  @override String get cooSelectFileFirstForComparison => 'Please select an import file first';
  @override String cooComparisonError(String e) => 'Error during comparison: $e';
  @override String get cooSelectFileToViewMatrix => '⚠️ Please select an import file first to view the comparison matrix';
  @override String get cooBackToSelectFile => 'Back to File Selection';
  @override String get cooRunComparisonPreviousStep => 'Please run comparison in the previous step to review the discrepancy matrix';
  @override String get cooBackToRunComparison => 'Back to Run Comparison';
  @override String get cooCriticalMismatchAlert => '🚨 Critical discrepancies found in Certificate of Origin';
  @override String get cooMinorDiscrepancyAlert => '⚠️ Minor discrepancies found in certificate';
  @override String get cooPerfectMatchSuccess => '✔ Certificate of Origin matches 100%';
  @override String get cooExportPdfButton => 'Export PDF';
  @override String get cooExportExcelButton => 'Export Excel';
  @override String get cooSaveToRegistryButton => 'Save to Registry';
  @override String get cooExportingPdfReportSnackbar => 'Exporting COO comparison report...';
  @override String get cooExcelCopiedSnackbar => '📊 Comparison data copied and exported to Excel successfully';
  @override String get cooMatrixColField => 'Field';
  @override String get cooMatrixColSystemValue => 'System Value';
  @override String get cooMatrixColDraftValue => 'Draft Value';
  @override String get cooMatrixColStatus => 'Match Status';
  @override String get cooMatrixColDetails => 'Details';
  @override String get cooOverrideReasonTitle => 'Approval & Justification Reason for Discrepancies (Mandatory for saving):';
  @override String get cooOverrideReasonSub => 'When discrepancies exist in the COO, recording the approval justification is mandatory (e.g. producer authorization addendum or registered trade name), or return to edit and notify supplier.';
  @override String get cooOverrideReasonLabel => 'Approval Justification Reason *';
  @override String get cooOverrideReasonHint => 'Write justification for accepting discrepancies before saving...';
  @override String get cooSaveWithJustificationButton => '✔ Approve & Save with Justification';
  @override String get cooReturnToEditAndNotifySupplierButton => '↩ Back to Edit Draft & Contact Supplier';
  @override String get cooMustProvideJustificationSnackbar => '⚠️ Approval justification is required before saving discrepancies, or click [Back to Edit Draft & Contact Supplier].';
  @override String get cooSessionSavedSuccess => '✔ COO review session saved successfully in registry';
  @override String cooSaveError(String e) => 'Error saving: $e';
  @override String get cooRegistryTitle => 'COO & EUR.1 Review Registry';
  @override String get cooReviewNewDraftButton => 'Review New Draft';
  @override String get cooNoReviewsYet => 'No recorded reviews yet';
  @override String get cooRegistryColCode => 'Session Code';
  @override String get cooRegistryColType => 'Type';
  @override String get cooRegistryColNumber => 'Certificate No.';
  @override String get cooRegistryColExporter => 'Exporter';
  @override String get cooRegistryColStatus => 'Status';
  @override String get cooRegistryColDate => 'Created Date';
  @override String get cooRegistryColActions => 'Actions';
  @override String get cooEditSessionTooltip => 'Edit Session';
  @override String get cooViewDetailsTooltip => 'View Details';
  @override String get cooDownloadPdfTooltip => 'Download PDF';
  @override String get cooDeleteSessionTooltip => 'Delete Session';
  @override String cooLoadedSessionForEditSnackbar(String code) => 'Loaded session data ($code) for editing';
  @override String cooDetailsDialogTitle(String code) => 'COO Review Session Details: $code';
  @override String get cooDetailsCertTypeAndNumber => 'Certificate Type & Number';
  @override String get cooDetailsExporterAndImporter => 'Exporter & Importer';
  @override String get cooDetailsOriginAndDestination => 'Origin & Destination Country';
  @override String get cooDetailsOverrideReason => 'Approval Justification Reason';
  @override String get cooDetailsMatrixTitle => 'Discrepancy & Comparison Matrix:';
  @override String get cooDeleteDialogTitle => 'Confirm Delete COO Review Session';
  @override String cooDeleteDialogContent(String code, String cert) => 'Are you sure you want to delete review session ($code) for certificate ($cert)?';
  @override String get cooDeleteSuccessSnackbar => '✔ Review session deleted successfully';
  @override String cooDeleteErrorSnackbar(String e) => 'Error deleting: $e';
  @override String cooVisualPreviewTitle(String type) => 'Official Draft Certificate Preview: $type';
  @override String get cooVisualRefreshTooltip => 'Live refresh retrieved data';
  @override String get cooVisualCopyButton => 'Copy Data';
  @override String get cooVisualCopiedSnackbar => 'Certificate data copied to clipboard';
  @override String get cooVisualExcelButton => 'Export Excel';
  @override String get cooVisualExcelReadySnackbar => 'Excel data generated successfully';
  @override String get cooVisualPrintPdfButton => 'Print & Export PDF';
  @override String get cooCustomsClearanceNote => 'Customs Note: During the customs clearance process in Egypt, Box 11 must contain the exporter\'s signature and stamp, and Box 12 must contain the official stamp of the certifying authority (Customs stamp and Chamber of Commerce stamp) or an electronic verification QR Code or Barcode in the case of electronic certificates.';
  @override String cooExcelSavedSuccess(String path) => '✅ Excel file saved successfully at: $path';
  @override String get cooDetailsExporterLabel => 'Exporter';
  @override String get cooDetailsImporterLabel => 'Importer';
  @override String get searchAndCloneCooBtn => 'Search & Clone Draft COO';
  @override String get searchAndCloneCooDialogTitle => 'Search & Clone Draft Certificate of Origin & EUR.1';
  @override String get searchCooHint => 'Search by cert number, exporter, importer, or type...';
  @override String get noCooReviewsFound => 'No certificate of origin reviews match search';
  @override String get cloneCooSuccess => 'Draft certificate of origin cloned successfully';
  @override String get cooClonedResetNotice => 'COO cloned with reset certificate number and refreshed system snapshot';
  @override String get cloneCooRecordTooltip => 'Clone Draft COO';
  @override String get cooRegistrySearchHint => 'Search COO registry...';

  // ── Screen 20: Customs Docs Approval (CustomsDocumentApprovalTab) ─────────
  @override String get customsApprovalSelectFileForMatrixWarning => 'Please select an import file first to run matrix check.';
  @override String customsApprovalMatrixCheckCompleted(String compliance) => 'Automated AI cross-check completed: $compliance';
  @override String customsApprovalMatrixCheckFailed(String error) => 'Matrix check failed: $error';
  @override String get customsApprovalSelectFileWarning => 'Please select an import file first.';
  @override String get customsApprovalStandardListGeneratedSuccess => 'Standard document approval checklist generated successfully.';
  @override String customsApprovalGenerateFailed(String error) => 'Error during generation: $error';
  @override String get customsApprovalSelectFileForTicketWarning => 'Please select an import file to link ticket.';
  @override String get customsApprovalImportFileLabel => 'Import File';
  @override String get customsApprovalSearchFileHint => 'Search by file number or company name...';
  @override String get customsApprovalRunAiMatrixButton => 'AI Matrix Audit';
  @override String get customsApprovalAutoGenerateStandardListButton => 'Generate Standard List';
  @override String get customsApprovalRaiseTicketButton => 'Issue Supplier Ticket';
  @override String get customsApprovalFilterAll => 'All';
  @override String get customsApprovalFilterPending => 'Pending';
  @override String get customsApprovalFilterApproved => 'Approved';
  @override String get customsApprovalFilterRejected => 'Rejected';
  @override String get customsApprovalFilterDiscrepancy => 'Discrepancy';
  @override String get customsApprovalTabDualSignoff => 'Dual-Tier Sign-off & Matrix Audit';
  @override String get customsApprovalTabCentralArchive => 'Central Archive & Rectifications Hub';
  @override String customsApprovalMatrixComplianceResult(String compliance, int passed, int total) => 'Cross-Check Compliance Result: $compliance ($passed of $total matched)';
  @override String customsApprovalMatrixRecommendations(String recs) => 'Customs Recommendations: $recs';
  @override String customsApprovalMatrixOpenTicketsCount(int count) => 'Open Tickets: $count';
  @override String get customsApprovalDualTierHeader => 'Dual-Tier Document Approval Matrix';
  @override String get customsApprovalNoDocuments => 'No registered documents. Click "Generate Standard List" to start.';
  @override String customsApprovalError(String error) => 'Error: $error';
  @override String customsApprovalDocRef(String ref) => 'Ref: $ref';
  @override String customsApprovalCommercialReviewStatus(String status) => 'Commercial Review: $status';
  @override String customsApprovalBrokerReviewStatus(String status) => 'Customs Broker Sign-off: $status';
  @override String get customsApprovalTicketsHeader => 'Discrepancy & Query Tickets Log';
  @override String get customsApprovalNewTicketButton => 'New Ticket';
  @override String get customsApprovalNoTickets => 'No open discrepancy tickets. All documents are fully aligned.';
  @override String customsApprovalTicketExpectedVsFound(String expected, String found) => 'Expected: $expected ➔ Found in Draft: $found';
  @override String get customsApprovalResolveTicketButton => 'Record Supplier Response and Close Ticket';
  @override String customsApprovalCommercialDialogTitle(String docType) => 'Commercial Review: $docType';
  @override String get customsApprovalCommercialReviewerLabel => 'Commercial Reviewer Name *';
  @override String get customsApprovalRequiredField => 'Field is required';
  @override String get customsApprovalCommercialDecisionLabel => 'Review Decision *';
  @override String get customsApprovalSelectDecisionHint => 'Select decision...';
  @override String get customsApprovalDecisionCommercialApproved => 'Approved Commercial';
  @override String get customsApprovalDecisionCommercialUnderReview => 'Under Review';
  @override String get customsApprovalDecisionCommercialRejected => 'Rejected with Errors';
  @override String get customsApprovalCommercialNotesLabel => 'Commercial Review Notes';
  @override String get customsApprovalSaveApprovalButton => 'Save Approval';
  @override String customsApprovalBrokerDialogTitle(String docType) => 'Customs Broker Sign-off: $docType';
  @override String get customsApprovalBrokerOfficeLabel => 'Customs Brokerage Firm *';
  @override String get customsApprovalBrokerReviewerNameLabel => 'Legal Reviewer or Broker Name *';
  @override String get customsApprovalBrokerDecisionLabel => 'Customs Clearance Decision *';
  @override String get customsApprovalDecisionBrokerApproved => 'Approved for Clearance';
  @override String get customsApprovalDecisionBrokerConditionallyApproved => 'Conditionally Approved';
  @override String get customsApprovalDecisionBrokerRejected => 'Rejected by Broker';
  @override String get customsApprovalBrokerNotesLabel => 'Clearance Notes & Undertakings';
  @override String get customsApprovalBrokerSaveStampButton => 'Official Approval & Seal';
  @override String get customsApprovalRaiseTicketDialogTitle => 'Issue Supplier Rectification Ticket';
  @override String get customsApprovalIssueCategoryLabel => 'Issue Category *';
  @override String get customsApprovalSelectCategoryHint => 'Select category...';
  @override String get customsApprovalCatHsMismatch => 'HS Code Mismatch';
  @override String get customsApprovalCatWeightDiscrepancy => 'Weight Discrepancy';
  @override String get customsApprovalCatCbmDiscrepancy => 'CBM Discrepancy';
  @override String get customsApprovalCatValueMismatch => 'Value or Currency Mismatch';
  @override String get customsApprovalCatMissingAcid => 'Missing ACID';
  @override String get customsApprovalCatIncotermConflict => 'Incoterm Conflict';
  @override String get customsApprovalCatOther => 'Other';
  @override String get customsApprovalSeverityLabel => 'Severity Level *';
  @override String get customsApprovalSelectSeverityHint => 'Select severity...';
  @override String get customsApprovalSevCritical => 'Critical (Blocks Shipment and Clearance)';
  @override String get customsApprovalSevMajor => 'Major (Requires Draft Revision)';
  @override String get customsApprovalSevMinor => 'Minor (Notice Only)';
  @override String get customsApprovalIssueDescLabel => 'Detailed Discrepancy Description *';
  @override String get customsApprovalIssueDescMinLength => 'Description must be at least 5 characters';
  @override String get customsApprovalExpectedValueLabel => 'Expected Correct Value';
  @override String get customsApprovalFoundValueLabel => 'Found Value in Draft';
  @override String get customsApprovalSupplierActionLabel => 'Required Supplier Action';
  @override String get customsApprovalCreateTicketSubmitButton => 'Issue Ticket';
  @override String customsApprovalResolveTicketDialogTitle(String ticketCode) => 'Close Rectification Ticket: $ticketCode';
  @override String get customsApprovalSupplierResponseLabel => 'Supplier Response & Correction *';
  @override String get customsApprovalResolverNameLabel => 'Closing Reviewer Name *';
  @override String get customsApprovalFinalStatusLabel => 'Final Status *';
  @override String get customsApprovalSelectStatusHint => 'Select status...';
  @override String get customsApprovalStatusResolved => 'Resolved (Draft Corrected)';
  @override String get customsApprovalStatusWaived => 'Waived with Undertaking';
  @override String get customsApprovalStatusClosed => 'Closed';
  @override String get customsApprovalConfirmResolveTicketButton => 'Confirm Resolution';

  // Screen 20 Additional: Document Types & Status Resolvers
  @override String get customsApprovalDocCommercialInvoice => 'Commercial Invoice';
  @override String get customsApprovalDocPackingList => 'Packing List';
  @override String get customsApprovalDocBillOfLading => 'Bill of Lading';
  @override String get customsApprovalDocCertificateOfOrigin => 'Certificate of Origin';
  @override String get customsApprovalDocEur1 => 'EUR.1 Movement Certificate';
  @override String get customsApprovalDocInspectionCertificate => 'Inspection Certificate';
  @override String get customsApprovalDocBankForm4 => 'Bank Form 4';
  @override String get customsApprovalDocProformaInvoice => 'Proforma Invoice';

  @override String get customsApprovalStatusApprovedForClearance => 'Approved for Clearance';
  @override String get customsApprovalStatusRectificationRequired => 'Rectification Required';
  @override String get customsApprovalStatusConditionallyApproved => 'Conditionally Approved';
  @override String get customsApprovalStatusUnderReview => 'Under Review';
  @override String get customsApprovalStatusPendingReview => 'Pending Review';
  @override String get customsApprovalStatusDraft => 'Draft';
  @override String get customsApprovalStatusRejected => 'Rejected';
  @override String get customsApprovalStatusApproved => 'Approved';
  @override String get customsApprovalStatusPending => 'Pending';

  @override String get customsApprovalComplianceFullyCompliant => 'Fully Compliant';
  @override String get customsApprovalComplianceNonCompliant => 'Non-Compliant';
  @override String get customsApprovalComplianceDiscrepancies => 'Discrepancies Found';
  @override String get customsApprovalComplianceCriticalBlocker => 'Critical Blocker';

  @override String get customsApprovalSevCriticalBadge => 'Critical';
  @override String get customsApprovalSevMajorBadge => 'Major';
  @override String get customsApprovalSevMinorBadge => 'Minor';

  @override String get customsApprovalTicketStatusOpen => 'Open';

  @override String get customsApprovalDefaultCommercialReviewer => 'Commercial Specialist';
  @override String get customsApprovalDefaultBrokerOffice => 'Licensed Customs Broker';
  @override String get customsApprovalDefaultLegalOfficer => 'Legal Officer';
  @override String get customsApprovalDefaultComplianceOfficer => 'Compliance Specialist';

  // Screen 20: Search & Clone Customs Document Approvals
  @override String get searchAndCloneCustomsApprovalBtn => 'Search & Clone Previous Customs Approval';
  @override String get searchAndCloneCustomsApprovalDialogTitle => 'Search & Clone Customs Document Approval';
  @override String get searchCustomsApprovalHint => 'Search by file code, doc type, company, or status...';
  @override String get noCustomsApprovalsFound => 'No matching customs document approvals found';
  @override String get cloneCustomsApprovalSuccess => 'Document approval checklist cloned and reset successfully';
  @override String get customsApprovalClonedResetNotice => 'Notice: All commercial and customs approvals were reset to Pending Review with notes cleared.';
  @override String get cloneApprovalRecordTooltip => 'Clone this document requirement';
  @override String get cloneTicketRecordTooltip => 'Clone this discrepancy ticket';

  // ── Screen 21: PO & Packing Reconciliation ───────────────────────────────
  @override String get poRecSampleLoadedSuccess => 'Sample demo data loaded successfully';
  @override String poRecFileSelected(String name, String sizeKb) => 'File selected: $name ($sizeKb KB)';
  @override String poRecFilePickFailed(String error) => 'Failed to pick file: $error';
  @override String poRecExtractedDigitalFileNotice(String filename) => '[Digital file uploaded: $filename — items will be extracted and processed automatically upon clicking extract & match]';
  @override String get poRecInputValidationTitle => 'Warning: Check Extraction & Reconciliation Inputs';
  @override String get poRecInputValidationDesc => 'The following issues were detected in the inputs that prevent accurate extraction:';
  @override String get poRecInputValidationRecHeader => 'Input Correction Guidelines & Proposed Solution:';
  @override String get poRecInputValidationGotIt => 'Understood, I will correct';
  @override String get poRecIssueNoFileSelected => 'No reference import file selected.';
  @override String get poRecRecSelectFileFromList => 'Please select an import file from the dropdown at the top.';
  @override String get poRecIssueEmptyInputs => 'No documents provided (both invoice and packing list are empty).';
  @override String get poRecRecProvideInputs => 'Upload a PDF/Excel file, paste text, or click "Load Sample Data".';
  @override String get poRecServerSuccessNotice => 'Smart extraction and matching completed successfully from server! Review results below';
  @override String get poRecFallbackSuccessNotice => 'Analysis and reconciliation performed locally via built-in fallback engine';
  @override String get poRecApplyExtractedSuccess => 'Extracted data applied to invoice and packing tables successfully!';
  @override String get poRecSaveSessionSelectFileWarning => 'Please select an import file first to save session';
  @override String get poRecExistingSessionWarningTitle => 'Warning: Import file already has a saved session';
  @override String poRecExistingSessionWarningContent(String sessionCode) => 'A reconciliation session already exists for this import file (Session: $sessionCode).\n\nPer system policies, duplicate sessions are prevented.\n\nDo you want to update the existing session with new data?';
  @override String get poRecUpdateExistingSessionButton => 'Update Current Session';
  @override String poRecSaveSessionError(String error) => 'Error while saving session: $error';
  @override String get poRecVarianceAlertTitle => 'Warning: Variances Detected in Reconciliation';
  @override String get poRecVarianceAlertContent => 'Variances detected between original PO, final invoice, and packing list:\n• Final values and quantities will become the official reference.\n• Goods In Transit (GIT) ledger will be updated.\nDo you wish to proceed and confirm certification?';
  @override String get poRecCancelAndReview => 'Cancel & Review';
  @override String get poRecConfirmCertifyButton => 'Confirm Certification & Match';
  @override String get poRecCertificationSuccess => 'Document reconciliation certified and import file updated successfully!';
  @override String poRecCertificationError(String error) => 'Error during certification: $error';
  @override String poRecSessionLoadedInEditor(String sessionCode) => 'Reconciliation session ($sessionCode) loaded into editor!';

  @override String poRecEditSessionTitle(String code) => 'Edit Reconciliation Session: $code';
  @override String get poRecNewSessionTitle => 'Final Commercial Invoice & Packing List Reconciliation';
  @override String poRecOpenSessionBadge(String code) => 'Active Session: $code';
  @override String get poRecHeaderDescription => 'Certified data, quantities, prices, and weights serve as the authoritative baseline for draft B/L, Goods In Transit, customs clearance, and warehouse receiving.';
  @override String get poRecSearchFileHint => 'Search import file by number or code...';
  @override String get poRecImportFileLabel => 'Reference Import File *';
  @override String get poRecSelectFileRequired => 'Please select an import file';
  @override String get poRecFinalInvoiceNoLabel => 'Final Commercial Invoice No. *';
  @override String get poRecFinalInvoiceNoHint => 'e.g. V1/2562';
  @override String get poRecFinalPackingListNoLabel => 'Final Packing List No. (Optional)';
  @override String get poRecFinalPackingListNoHint => 'e.g. M26 413 / PL-2562';
  @override String get poRecRequired => 'Required';
  @override String get poRecTotalSummaryRow => 'Totals';

  @override String get poRecKpiTotalInvoice => 'Total Final Invoice';
  @override String get poRecKpiTotalPackages => 'Total Actual Packages';
  @override String get poRecKpiTotalGrossWeight => 'Total Gross Weight';
  @override String get poRecKpiTotalNetWeight => 'Total Net Weight';
  @override String get poRecKpiTotalCbm => 'Total Volume (CBM)';
  @override String get poRecPackagesUnit => 'pkgs';
  @override String get poRecKgUnit => 'kg';
  @override String get poRecCbmUnit => 'm³';

  @override String get poRecInvoiceSectionTitle => '1. Final Commercial Invoice Items & Price Review';
  @override String get poRecResetToOriginalValuesButton => 'Reset to Original Values';
  @override String get poRecUpdateSessionButton => 'Update Reconciliation Session';
  @override String get poRecSaveSessionButton => 'Save Reconciliation Session';
  @override String get poRecCertifyFinalDataButton => 'Certify & Approve Final Data';
  @override String get poRecSelectFileToViewPoItems => 'Please select an import file to view PO line items for reconciliation';
  @override String get poRecColItemCode => 'Item Code';
  @override String get poRecColDescription => 'Description';
  @override String get poRecColPoQty => 'PO Quantity';
  @override String get poRecColFinalQty => 'Final Quantity *';
  @override String get poRecColQtyVariance => 'Qty Variance';
  @override String get poRecColPoUnitPrice => 'PO Unit Price';
  @override String get poRecColFinalUnitPrice => 'Final Unit Price *';
  @override String get poRecColPriceVariance => 'Price Variance';
  @override String get poRecColFinalTotal => 'Final Total';
  @override String get poRecColHsCode => 'HS Code';

  @override String get poRecPackingSectionTitle => '2. Packing List & Physical Cargo Measurements Review';
  @override String get poRecSelectFileToViewPackingItems => 'Please select an import file to view packing list items';
  @override String get poRecColPackageType => 'Package Type';
  @override String get poRecColPoPackagesCount => 'PO Packages (PO PKG)';
  @override String get poRecColFinalPackagesCount => 'Final Packages Count *';
  @override String get poRecColPkgVariance => 'Packages Variance';
  @override String get poRecColGrossWeight => 'Gross Weight (kg) *';
  @override String get poRecColNetWeight => 'Net Weight (kg) *';
  @override String get poRecColCbm => 'Volume (CBM m³) *';

  @override String get poRecExtractorTitle => 'Smart 3-Way Extractor & Matcher';
  @override String get poRecExtractorSubtitle => 'Extract final invoice and packing list items, match against system PO, and detect variances automatically';
  @override String get poRecLoadSampleDemoButton => 'Load Real Sample Data (G.I. INDUSTRIAL)';
  @override String get poRecHideTool => 'Hide Tool';
  @override String get poRecShowTool => 'Show Tool';
  @override String get poRecExtractorTabInvoice => '1. Final Commercial Invoice';
  @override String get poRecExtractorTabPacking => '2. Packing & Weight List';
  @override String get poRecChangeFile => 'Change File';
  @override String get poRecUploadFile => 'Upload File (PDF/Word/Excel)';
  @override String get poRecPasteInvoiceHint => 'Paste commercial invoice text here or upload digital file...';
  @override String get poRecPastePackingHint => 'Paste packing list text here or upload digital file...';
  @override String get poRecExtractingProgress => 'Running smart extraction and matching...';
  @override String get poRecExecuteSmartExtractionButton => 'Execute Smart Extraction & System 3-Way Reconciliation';
  @override String get poRecStatusFullyMatchedTitle => '100% Full Match — Zero Discrepancies or Conflicts';
  @override String poRecStatusWarningsTitle(int count) => 'Non-critical warnings detected ($count warnings) — review and certify';
  @override String poRecStatusCriticalTitle(int count) => 'Critical discrepancies detected ($count critical) — must be audited before certification!';
  @override String get poRecApplyExtractedToTablesButton => 'Apply Extracted Data to Reconciliation Tables Below';
  @override String get poRecHeaderComplianceChecksTitle => 'Header & Regulatory Compliance Checks:';
  @override String get poRecColCheckItem => 'Check Item';
  @override String get poRecColSystemValue => 'System Value';
  @override String get poRecColExtractedValue => 'Uploaded Document Value';
  @override String get poRecColMatchStatus => 'Match Status';
  @override String get poRecColDetails => 'Details';
  @override String get poRecMatchStatusMatched => 'Match';
  @override String get poRecMatchStatusWarning => 'Warning';
  @override String get poRecMatchStatusCritical => 'Critical Discrepancy';
  @override String get poRecExtractedDocMetadataTitle => 'Extracted Document Metadata:';
  @override String get poRecExtractedInvNo => 'Extracted Invoice No.';
  @override String get poRecExtractedInvAmount => 'Extracted Invoice Total';
  @override String get poRecExtractedAcid => 'Extracted ACID No.';
  @override String get poRecExtractedPackagesWeight => 'Extracted Packages & Weight';

  @override String get poRecHistorySectionTitle => 'Saved Reconciliation Sessions Registry';
  @override String get poRecHistorySectionSubtitle => 'Archive of certified shipping document, invoice, and packing list reconciliation sessions';
  @override String poRecHistoryTotalSessionsBadge(int count) => '$count Saved Sessions';
  @override String get poRecHistoryKpiTotalSessions => 'Total Saved Sessions';
  @override String get poRecHistoryKpiFullMatch => '100% Full Match';
  @override String get poRecHistoryKpiWithVariances => 'Sessions with Variances / Alerts';
  @override String get poRecHistoryKpiTotalCertifiedValue => 'Total Certified Value';
  @override String get poRecHistoryNewSessionButton => 'New Reconciliation Session';
  @override String get poRecHistorySearchHint => 'Search by session code, file number, company name, invoice number, or ACID...';
  @override String poRecHistoryFilterAll(int count) => 'All ($count)';
  @override String get poRecHistoryFilterMatched => 'Fully Matched';
  @override String get poRecHistoryFilterWarnings => 'Accepted with Warnings';
  @override String get poRecHistoryFilterCritical => 'Critical Discrepancies';
  @override String get poRecHistoryRefreshTooltip => 'Refresh Records';
  @override String get poRecHistoryEmptyTitle => 'No saved reconciliation sessions yet.';
  @override String get poRecHistoryNoMatchFilter => 'No reconciliation sessions match the search and filter criteria.';
  @override String get poRecHistoryCreateFirstSessionButton => 'Create First Reconciliation Session';
  @override String get poRecHistoryColIndex => '#';
  @override String get poRecHistoryColSessionCode => 'Session Code';
  @override String get poRecHistoryColImportFileImporter => 'Import File / Importer';
  @override String get poRecHistoryColInvoicePacking => 'Invoice & Packing List';
  @override String get poRecHistoryColTotalValue => 'Total Value';
  @override String get poRecHistoryColPackagesWeight => 'Packages & Weights';
  @override String get poRecHistoryColCbm => 'Volume CBM';
  @override String get poRecHistoryColStatus => 'Reconciliation Status';
  @override String get poRecHistoryColSavedDate => 'Saved Date';
  @override String get poRecHistoryColActions => 'Actions';
  @override String get poRecHistoryCopyCodeTooltip => 'Copy Session Code';
  @override String get poRecHistoryCodeCopiedNotice => 'Session code copied';
  @override String get poRecHistoryViewDetailsTooltip => 'View Session Details & Report';
  @override String get poRecHistoryLoadIntoEditorTooltip => 'Load Session into Reconciliation Editor';
  @override String get poRecHistoryPrintTooltip => 'Copy Reconciliation Report for Printing (Ctrl+P)';
  @override String get poRecHistoryDeleteTooltip => 'Delete Session';
  @override String get poRecHistoryDeleteConfirmTitle => 'Confirm Delete Reconciliation Session';
  @override String poRecHistoryDeleteConfirmContent(String code, String file) => 'Are you sure you want to delete reconciliation session ($code) for import file ($file)?';
  @override String get poRecHistoryDeletePermanent => 'Delete Permanently';
  @override String poRecHistoryDeletedSuccess(String code) => 'Reconciliation session ($code) deleted successfully';
  @override String get poRecHistoryPrintCopiedSuccess => 'Reconciliation session report copied to clipboard! Ready to print and share';
  @override String poRecHistorySavedDialogTitle(String code) => 'Reconciliation Session Saved Successfully ($code)';
  @override String get poRecHistorySavedUniqueNotice => 'Session recorded as an exclusive authoritative reference for this import file to prevent duplicates.';
  @override String get poRecHistoryCopyReportButton => 'Copy Session Report for Printing';
  @override String poRecHistoryDetailsModalTitle(String code) => 'Reconciliation Session Report: $code';
  @override String get poRecHistoryDetailsCertifiedItemsTitle => 'Certified Invoice Line Items in Session:';
  @override String get poRecHistoryDetailsCertifiedPackingTitle => 'Certified Packing List & Physical Measurements in Session:';
  @override String get poRecHistoryLoadInEditorButton => 'Load in Editor';
  @override String get poRecDiff => 'Diff';
  @override String get poRecMissingInPacking => 'Missing in Packing';
  @override String get poRecMissingInInvoice => 'Missing in Invoice';
  @override String get poRecQtyDiff => 'Qty Diff';
  @override String get poRecOk => 'Match';
  @override String get poRecUnassignedHsCode => 'Unassigned HS';
  @override String get poRecInvoicePrefix => 'Invoice:';
  @override String get poRecPackingPrefix => 'Packing List:';
  @override String get poRecGrossPrefix => 'Gross Wt:';
  @override String get poRecCheckFieldInvoiceNumber => 'Final Commercial Invoice Number';
  @override String get poRecCheckFieldAcidNumber => 'Customs ACID Number';
  @override String get poRecCheckFieldTotalAmount => 'Total Commercial Invoice Amount';
  @override String get poRecCheckFieldTotalPackages => 'Total Packages Count';
  @override String get poRecCheckFieldGrossWeight => 'Total Gross Weight';
  @override String get poRecCheckFieldSupplierName => 'Foreign Supplier Name';
  @override String get poRecCheckFieldImporterName => 'Importing Company Name';
  @override String get poRecCheckFieldHsCode => 'HS Code (Customs Tariff)';
  @override String get poRecCheckFieldTaxId => 'Importer Tax ID';
  @override String get poRecCheckMsgInvoiceMatched => 'Commercial invoice number extracted and matched successfully';
  @override String get poRecCheckMsgAcidMatched => 'ACID number fully matches across invoice, packing list, and system';
  @override String get poRecCheckMsgTotalAmountMatched => 'Total invoice amount matches perfectly at 100%';
  @override String get poRecCheckNotSpecified => 'Not specified in system';
  @override String get poRecReportTitle => 'Sorour Logistics ERP - PO & Packing Final Reconciliation Report';
  @override String get poRecReportSessionCode => 'Session Code';
  @override String get poRecReportImportFile => 'Import File';
  @override String get poRecReportImporter => 'Importer';
  @override String get poRecReportShipper => 'Shipper';
  @override String get poRecReportAcid => 'ACID Number';
  @override String get poRecReportInvoiceNo => 'Final Commercial Invoice';
  @override String get poRecReportPackingNo => 'Final Packing List';
  @override String get poRecReportTotalValue => 'Total Value';
  @override String get poRecReportPackages => 'Total Packages';
  @override String get poRecReportGrossWeight => 'Gross Weight';
  @override String get poRecReportNetWeight => 'Net Weight';
  @override String get poRecReportTotalCbm => 'Total Volume';
  @override String get poRecReportOverallStatus => 'Overall Status';
  @override String get poRecReportCertifiedBy => 'Certified By';
  @override String get poRecReportCsvHeader => 'Item Code,Description,HS Code,Quantity,Unit Price,Total Amount,Packages,Gross Wt,Net Wt,CBM';
  @override String get poRecReportPreviewTitle => 'Reconciliation Report Preview';

  // Screen 21: Search & Clone PO Reconciliation Sessions
  @override String get searchAndClonePoReconBtn => 'Search & Clone Previous Session';
  @override String get searchAndClonePoReconDialogTitle => 'Search & Clone PO & Packing Reconciliation Session';
  @override String get searchPoReconHint => 'Search by session code, invoice number, import file, or importer...';
  @override String get noPoReconFound => 'No reconciliation sessions matched your search query';
  @override String get clonePoReconSuccess => 'Reconciliation session cloned successfully and loaded into editor';
  @override String get poReconClonedResetNotice => 'Notice: New draft session code generated and certification data reset for independent review';
  @override String get clonePoReconRecordTooltip => 'Clone this reconciliation session as a new draft';
  @override String get copyPoReconBtn => 'Copy Reconciliation Table (TSV)';
  @override String get exportPoReconExcelBtn => 'Export Reconciliation Table to Excel';
  @override String get exportPoReconPdfBtn => 'Export Reconciliation Report to PDF';

  // ── Screen 23: Customs Declaration 46 ──────────────────────────────────────
  @override String get customsDeclStageTitle => 'Initial Customs Declaration 46 Registration';
  @override String get customsDeclTabInitialForm => 'Initial Declaration 46 Form';
  @override String get customsDeclTabRegistry => 'Declaration 46 Registry';
  @override String get customsDeclRefreshTooltip => 'Refresh Data';
  @override String get customsDeclInfoBanner => 'Draft Customs Declaration 46 ready for Nafeza integration. Automatically fetches approved ACID, verified Bank Form 4, and B/L data to calculate the tax base and estimated customs duties according to the tariff schedule and preferential agreements.';
  @override String get customsDeclSelectFileLabel => 'Import File for Declaration 46 *';
  @override String get customsDeclSearchFileHint => 'Search by file number or supplier name...';
  @override String get customsDeclAttributesHeader => 'Customs Declaration 46 Attributes & Reference Numbers:';
  @override String get customsDeclDeclarationNoLabel => 'Declaration 46 Reference Number *';
  @override String get customsDeclSubmissionDateLabel => 'Initial Registration Date *';
  @override String get customsDeclAcidNumberLabel => 'Advance Cargo Info (ACID) No.';
  @override String get customsDeclForm4NumberLabel => 'Bank Form 4 Number';
  @override String get customsDeclBlNumberLabel => 'Bill of Lading (B/L) No.';
  @override String get customsDeclDutiesHeader => 'Customs Tax Base & Estimated Duties (EGP):';
  @override String get customsDeclCifValueLabel => 'CIF Customs Value (EGP)';
  @override String get customsDeclImportDutyLabel => 'Estimated Import Duty (EGP)';
  @override String get customsDeclVatLabel => 'VAT Amount (EGP)';
  @override String get customsDeclTotalDutiesLabel => 'Total Estimated Duties & Taxes';
  @override String get customsDeclExemptionHeader => 'Customs Position & Preferential Tariff Exemption:';
  @override String get customsDeclExemptionConditionsHeader => '📌 Mandatory Regulatory Conditions for Tariff Exemption:';
  @override String get customsDeclEur1ExemptionTitle => 'EU-Egypt Association Agreement (EUR.1) — 0% Import Duty Exemption';
  @override String get customsDeclEur1Condition1 => 'Submit certified original EUR.1 / COO certificate with official authority stamps.';
  @override String get customsDeclEur1Condition2 => 'Proof of Direct Transport from the EU country of origin to Egyptian ports.';
  @override String get customsDeclEur1Condition3 => 'Include ACID number and registered manufacturer code on the commercial invoice and B/L.';
  @override String customsDeclMfnExemptionTitle(String rate) => 'Subject to Standard MFN Customs Tariff — Import Duty $rate%';
  @override String get customsDeclMfnCondition1 => 'Submit official certificate of origin authenticated by the exporter country chamber of commerce.';
  @override String get customsDeclMfnCondition2 => 'Pay scheduled customs duties and taxes through Nafeza payment voucher.';
  @override String get customsDeclRegulatoryHeader => 'Required Regulatory Approvals & Inspections:';
  @override String get customsDeclColHsCode => 'HS Code';
  @override String get customsDeclColAuthority => 'Regulatory Authority';
  @override String get customsDeclColInspection => 'Prior Inspection';
  @override String get customsDeclColCoo => 'COO Certificate';
  @override String get customsDeclColRequirements => 'Regulatory Conditions & Notes';
  @override String get customsDeclColApprovalStatus => 'Approval Status';
  @override String get customsDeclStatusFulfilled => 'Fulfilled & Approved';
  @override String get customsDeclDefaultAuthority => 'General Organization for Export & Import Control (GOEIC)';
  @override String get customsDeclDefaultNote => 'Technical presentation and inspection sampling required per Egyptian standards';
  @override String get customsDeclDefaultItemDesc => 'Imported Cargo & Merchandise Item';
  @override String get customsDeclVisualInspectionNote => 'Visual inspection and documentary compliance prior to customs release';
  @override String get customsDeclSaveButton => 'Save & Register Declaration 46';
  @override String get customsDeclSavingProgress => 'Saving...';
  @override String get customsDeclSelectFileWarning => 'Please select an import file first';
  @override String get customsDeclSaveSuccess => 'Customs Declaration 46 registered and saved successfully';
  @override String get customsDeclRegistrySearchHint => 'Search Declaration 46 registry...';
  @override String get customsDeclRegisterNewButton => 'Register New Declaration';
  @override String get customsDeclColDeclarationNo => 'Declaration 46 No.';
  @override String get customsDeclColFileNumber => 'File No.';
  @override String get customsDeclColSupplier => 'Foreign Supplier';
  @override String get customsDeclColRegistrationDate => 'Registration Date';
  @override String get customsDeclColDeclarationStatus => 'Declaration Status';
  @override String get customsDeclStatusRegisteredNafeza => 'Initially Registered on Nafeza';
  @override String get customsDeclRequiredField => 'This field is required';
  @override String get customsDeclCopyValueTooltip => 'Copy value to clipboard';
  @override String get customsDeclPrintPreviewButton => 'Preview & Copy Declaration Summary';
  @override String get customsDeclPreviewTitle => 'Initial Customs Declaration 46 Certificate';
  @override String get customsDeclCopySummarySuccess => 'Declaration 46 summary copied successfully';
  @override String get customsDeclExportTsvButton => 'Copy as Table (TSV)';
  @override String get customsDeclExportSuccess => 'Declaration data copied in Excel-compatible TSV format';
  @override String get customsDeclExportRegistryTsv => 'Export Registry (TSV)';
  @override String get customsDeclCopyAllSuccess => 'All Declaration 46 registry rows copied in TSV format';
  @override String get customsDeclCloseDialog => 'Close';
  @override String get customsDeclAssessmentTitle => 'Customs Valuation & Tariff Assessment — Declaration 46';
  @override String get customsDeclViewAssessmentTooltip => 'View Customs Valuation & Tariff Assessment';
  @override String get customsDeclAssessmentSubtitle => 'Detailed CIF base, import duty rates, VAT, and applicable customs fees';
  @override String get customsDeclShipmentParticularsHeader => 'Shipment & Customs Declaration Particulars';
  @override String get customsDeclValuationBreakdownHeader => 'Customs Valuation Breakdown (CIF Base)';
  @override String get customsDeclFobForeignLabel => 'Commercial Invoice Value (FOB)';
  @override String get customsDeclFreightEgpLabel => 'Freight Charges (EGP)';
  @override String get customsDeclInsuranceEgpLabel => 'Estimated Marine Insurance (EGP)';
  @override String get customsDeclCifTotalEgpLabel => 'Total Customs Value (CIF - EGP)';
  @override String get customsDeclTariffTaxesHeader => 'Applicable Customs Duties & Taxes Schedule';
  @override String get customsDeclImportDutyRateLabel => 'Applicable Import Duty';
  @override String get customsDeclVatRateLabel => 'Value Added Tax (VAT)';
  @override String get customsDeclDevFeeLabel => 'Development Fee';
  @override String get customsDeclCustomsServicesFeeLabel => 'Customs Service Fees';
  @override String get customsDeclColActions => 'Actions';
  @override String get customsDeclAssessmentCopySuccess => 'Customs valuation and tariff assessment copied to clipboard successfully';
  @override String get customsDeclMetricTotalDeclarations => 'Total Declarations';
  @override String get customsDeclMetricTotalCif => 'Total Customs CIF Base';
  @override String get customsDeclMetricTotalDuties => 'Total Duties & Taxes';
  @override String get customsDeclMetricExemptions => 'Preferential Exemptions';
  @override String get customsDeclFxRateLabel => 'Customs USD Exchange Rate';
  @override String get customsDeclVatBaseLabel => 'VAT Taxable Base';
  @override String get searchAndCloneCustomsDeclBtn => 'Clone Customs Declaration 46';
  @override String get cloneCustomsDeclDialogTitle => 'Search & Clone Previous Customs Declaration (Form 46)';
  @override String get cloneCustomsDeclDialogSubtitle => 'Select a customs declaration or shipment file to clone customs valuation & tariff assessment into an editable draft';
  @override String get cloneCustomsDeclSuccess => 'Customs Declaration 46 data successfully cloned into an editable draft';
  @override String get cloneCustomsDeclRowTooltip => 'Clone this declaration into a new draft';
  @override String get copyApprovalRowSuccess => 'Regulatory approval row copied as TSV successfully';
  @override String get copyApprovalTableSuccess => 'Regulatory approvals table copied as TSV successfully';
  @override String get exportExcelApprovalsTooltip => 'Export Approvals to Excel';
  @override String get exportPdfApprovalsTooltip => 'Print / Export PDF';
  @override String get exportRegistryExcelTooltip => 'Export Declarations Registry to Excel';
  @override String get exportRegistryPdfTooltip => 'Print / Export Declarations Registry PDF';
  @override String get copyRegistryRowSuccess => 'Declaration row copied as TSV successfully';
  @override String get copyRegistryTableSuccess => 'Customs declarations registry copied as TSV successfully';
  @override String get cloneFromAssessmentBtn => 'Clone as New Draft';

  // ── Screen 24/27: Customs Clearance Management ────────────────────────────────
  @override String get searchAndCloneCustomsClearanceBtn => 'Search & Clone Clearance';
  @override String get cloneCustomsClearanceDialogTitle => 'Clone Customs Clearance Record';
  @override String get cloneCustomsClearanceDialogSubtitle => 'Select a previous record to clone clearance details into a new draft';
  @override String get cloneCustomsClearanceTooltip => 'Clone this clearance record';
  @override String get copyCustomsClearanceRowSuccess => 'Clearance row copied as TSV successfully';
  @override String get copyCustomsClearanceTableSuccess => 'Customs clearance registry copied as TSV successfully';
  @override String get exportCustomsClearanceExcelTooltip => 'Export Clearance Registry to Excel';
  @override String get exportCustomsClearancePdfTooltip => 'Export Clearance Registry to PDF';
  @override String get customsClearanceStageTitle => 'Port Operations & Customs Clearance Hub';
  @override String get customsClearanceTabFollowUp => 'Customs Clearance Follow-up';
  @override String get customsClearanceTabSamples => 'Drawing Samples & Shortage Tracking';
  @override String get customsClearanceTabDiscrepancy => 'Discrepancy & Damage Registry';
  @override String get customsClearanceTabDutyPayment => 'Final Customs Duty Payment & Release';
  @override String customsClearanceErrorFetch(String error) => 'Error fetching customs clearance data: $error';
  @override String get customsClearanceSearchHint => 'Search by clearance code, Declaration 46, D/O number...';
  @override String get customsClearanceFilterAll => 'All Statuses';
  @override String get customsClearanceFilterInspection => 'Inspection In Progress';
  @override String get customsClearanceFilterDutyRequested => 'Duty Requested';
  @override String get customsClearanceFilterDutyPaid => 'Duty Paid';
  @override String get customsClearanceFilterFinalRelease => 'Final Release Granted';
  @override String get customsClearanceNewRecordButton => 'New Clearance Record';
  @override String get customsClearanceEmptyRecords => 'No matching customs clearance records found.';
  @override String get customsClearanceDeclaration46Label => 'Decl. 46';
  @override String get customsClearanceDeliveryOrderLabel => 'D/O No.';
  @override String get customsClearanceOfficeLabel => 'Customs Office';
  @override String get customsClearanceFileRefLabel => 'Import File Ref';
  @override String customsClearanceFreeDaysLabel(int days) => 'Port Free Days: $days days';
  @override String get customsClearanceTotalDutiesCard => 'Total Duties';
  @override String customsClearanceEstimatedDutiesCard(String est, String diff, String percent) => 'Estimated: $est EGP (Diff: $diff EGP [$percent%])';
  @override String get customsClearancePaymentStatusLabel => 'Payment Status';
  @override String get customsClearanceStatusPaid => 'Paid & Verified';
  @override String get customsClearanceStatusPendingPayment => 'Payment Required';
  @override String get customsClearanceEditTooltip => 'Edit Clearance Record';
  @override String get customsClearancePayTooltip => 'Duty Payment & Nafeza Reconciliation';
  @override String get customsClearanceReleaseTooltip => 'Issue Final Release';
  @override String get customsClearanceSamplesBannerTitle => 'Drawing Samples & Laboratory Inspection Tracking';
  @override String get customsClearanceSamplesBannerDesc => 'Document regulatory lab receipts (GOEIC, NFSA, Chemistry, Radiation), track statutory deadlines for analysis results, and reconcile physical weights.';
  @override String get customsClearanceAddSampleButton => 'Record Sample Drawing';
  @override String get customsClearanceSamplesTableTitle => 'Laboratory Drawn Samples Registry';
  @override String get customsClearanceColSampleCode => 'Sample ID';
  @override String get customsClearanceColAuthority => 'Regulatory Authority / Lab';
  @override String get customsClearanceColDrawingDate => 'Drawing Date';
  @override String get customsClearanceColReceiptNo => 'Receipt No.';
  @override String get customsClearanceColTestType => 'Test / Analysis Type';
  @override String get customsClearanceColTestResult => 'Inspection Result';
  @override String get customsClearanceColNotes => 'Notes';
  @override String get customsClearanceSamplePassed => 'Compliant & Passed';
  @override String get customsClearanceSamplePending => 'Under Laboratory Analysis';
  @override String get customsClearanceAddSampleDialogTitle => 'Record New Lab Sample Drawing';
  @override String get customsClearanceSampleAuthLabel => 'Regulatory Authority / Lab *';
  @override String get customsClearanceSampleReceiptLabel => 'Drawing Receipt Number *';
  @override String get customsClearanceSampleTestTypeLabel => 'Required Analysis Type *';
  @override String get customsClearanceSampleNotesLabel => 'Inspector & Lab Notes';
  @override String get customsClearanceSampleSaveButton => 'Save Sample';
  @override String get customsClearanceSampleSaveSuccess => 'Sample drawing recorded successfully';
  @override String get customsClearanceDamageBannerTitle => 'Discrepancy, Shortage & Damage Protocols Registry';
  @override String get customsClearanceDamageBannerDesc => 'Document container damage, wet cargo, and shortages with shipping agent, customs officers, and marine insurance for compensation claims.';
  @override String get customsClearanceAddDamageButton => 'Create Joint Protocol';
  @override String get customsClearanceDamageTableTitle => 'Joint Inspection Protocols & Insurance Claims';
  @override String get customsClearanceColProtocolNo => 'Protocol No.';
  @override String get customsClearanceColDeclarationNo => 'Customs Declaration (46)';
  @override String get customsClearanceColContainerNo => 'Container No.';
  @override String get customsClearanceColDamageType => 'Damage Nature & Type';
  @override String get customsClearanceColDamagedQty => 'Damaged Quantity';
  @override String get customsClearanceColEstimatedLoss => 'Estimated Loss (EGP)';
  @override String get customsClearanceColResponsibleParty => 'Responsible Party';
  @override String get customsClearanceColClaimStatus => 'Claim Status';
  @override String get customsClearanceColDate => 'Date';
  @override String get customsClearanceClaimApproved => 'Approved for Claim';
  @override String get customsClearanceClaimSubmitted => 'Submitted to Insurance';
  @override String get customsClearanceAddDamageDialogTitle => 'Create Joint Cargo Damage & Shortage Protocol';
  @override String get customsClearanceDamageDeclLabel => 'Declaration 46 Number *';
  @override String get customsClearanceDamageContainerLabel => 'Container Number *';
  @override String get customsClearanceDamageTypeLabel => 'Damage Type & Description *';
  @override String get customsClearanceDamagedQtyLabel => 'Damaged Quantity *';
  @override String get customsClearanceDamageLossLabel => 'Estimated Loss Amount (EGP) *';
  @override String get customsClearanceDamagePartyLabel => 'Party Responsible for Damage *';
  @override String get customsClearanceDamageNotesLabel => 'Joint Inspection Details & Survey Notes';
  @override String get customsClearanceDamageSaveButton => 'Save Protocol';
  @override String get customsClearanceDamageSaveSuccess => 'Joint inspection protocol saved successfully';
  @override String get customsClearancePaymentBannerTitle => 'Final Duty Payment & Customs Gate Pass System';
  @override String get customsClearancePaymentBannerDesc => 'Reconcile Nafeza payment voucher, document bank receipts, record variances, and grant final release and gate pass.';
  @override String get customsClearanceDutyLedgerTableTitle => 'Nafeza Duty Assessment & Ledger Registry';
  @override String get customsClearanceEmptyDutyLedger => 'No duty payment assessments recorded.';
  @override String get customsClearanceColClearanceCode => 'Clearance Code';
  @override String get customsClearanceColDecl46 => 'Decl. (46)';
  @override String get customsClearanceColCustomsOffice => 'Customs Office';
  @override String get customsClearanceColActualDuty => 'Actual Duty (Nafeza)';
  @override String get customsClearanceColEstimatedDuty => 'Estimated Duty';
  @override String get customsClearanceColDutyVariance => 'Duty Variance';
  @override String get customsClearanceColPaymentStatus => 'Payment Status';
  @override String get customsClearanceColActions => 'Payment & Release Actions';
  @override String get customsClearanceBtnPaymentDetails => 'Payment Details';
  @override String get customsClearanceBtnPayReconcile => 'Pay & Reconcile';
  @override String get customsClearanceBtnFinalRelease => 'Final Release';
  @override String get customsClearanceNewDialogTitle => 'Register New Customs Clearance Record';
  @override String customsClearanceEditDialogTitle(String code) => 'Edit Customs Clearance Record ($code)';
  @override String get customsClearanceExtractNafezaBtn => 'Extract from Nafeza';
  @override String get customsClearanceExtractNafezaSuccess => 'Nafeza declaration and duty data extracted successfully!';
  @override String get customsClearanceImportFileLabel => 'Target Import File *';
  @override String get customsClearanceImportFileSearchHint => 'Search by file number or shipment code...';
  @override String get customsClearanceSelectFileValidator => 'Please select an import file';
  @override String get customsClearanceDecl46Label => 'Customs Declaration No. (46)';
  @override String get customsClearanceDoNumberLabel => 'Delivery Order (D/O) No.';
  @override String get customsClearanceFreeDaysInputLabel => 'Port Free Days';
  @override String get customsClearanceOfficeInputLabel => 'Customs Office & Zone *';
  @override String get customsClearanceOfficeValidator => 'Please enter customs office name';
  @override String get customsClearanceChannelLabel => 'Customs Channel *';
  @override String get customsClearanceChannelRed => 'Red Channel (Inspection & Sampling)';
  @override String get customsClearanceChannelGreen => 'Green Channel (Documentary Release)';
  @override String get customsClearanceChannelYellow => 'Yellow Channel (Documentary Review)';
  @override String get customsClearanceDutyBreakdownHeader => 'Customs Duties & Taxes Breakdown (EGP):';
  @override String get customsClearanceImportDutyInput => 'Import Duty';
  @override String get customsClearanceVatInput => 'Value Added Tax (VAT)';
  @override String get customsClearanceScheduleTaxInput => 'Schedule Tax';
  @override String get customsClearanceWhtInput => 'Withholding Tax (1%)';
  @override String get customsClearanceLabFeesInput => 'Lab & Service Fees';
  @override String get customsClearanceEstimatedDutyInput => 'System Estimated Duty';
  @override String get customsClearanceSaveRecordBtn => 'Save Record';
  @override String get customsClearanceSaveRecordSuccess => 'Customs clearance record saved successfully';
  @override String customsClearanceSaveRecordError(String err) => 'Error saving record: $err';
  @override String customsClearanceDutyPaymentDialogTitle(String code) => 'Customs Duty Payment & Reconciliation ($code)';
  @override String get customsClearanceExtractReceiptBtn => 'Extract Payment Receipt';
  @override String customsClearanceEstimatorDutyBoxLabel(String amount) => 'Estimated Duty: $amount EGP';
  @override String customsClearanceNafezaDutyBoxLabel(String amount) => 'Required in Nafeza Voucher: $amount EGP';
  @override String get customsClearanceVarianceBoxLabel => 'Tax Base Variance:';
  @override String get customsClearanceActualPaidInput => 'Actual Paid Amount (EGP) *';
  @override String get customsClearanceBankReceiptInput => 'Bank Payment Receipt No. *';
  @override String get customsClearanceVarianceReasonInput => 'Variance reasons if any (lab adjustments, extra items...)';
  @override String get customsClearanceConfirmPaymentBtn => 'Confirm Payment & Post';
  @override String get customsClearancePaymentSuccess => 'Customs duty payment documented and reconciled successfully';
  @override String customsClearancePaymentError(String err) => 'Error documenting payment: $err';
  @override String get customsClearanceFinalReleaseDialogTitle => 'Issue Final Customs Release Permit';
  @override String get customsClearanceFinalReleaseDialogDesc => 'Clearance status will be updated to Final Release Granted and containers ready for gate exit.';
  @override String get customsClearanceReleasePermitInput => 'Customs Release Permit & Gate Pass No. *';
  @override String get customsClearanceConfirmReleaseBtn => 'Approve Final Release';
  @override String get customsClearanceReleaseSuccess => 'Final customs release granted successfully!';
  @override String customsClearanceReleaseError(String err) => 'Error granting release: $err';
  @override String get customsClearanceAiBrokerExtractorBtn => 'AI Customs Broker Coder ✨';
  @override String get customsClearanceUnderBondTooltip => 'Under-Bond Release & Lab Clearance Pathway';
  @override String get underBondReleaseDialogTitle => 'Under-Bond Release & Lab Testing Quarantine Lock';
  @override String underBondReleaseDeclSubtitle(String declNo) => 'Customs Declaration 46: $declNo';
  @override String get underBondModeUnderBond => 'Under-Bond Release (Quarantined)';
  @override String get underBondModeLabVerdict => 'Record Lab Result & Lift Lock';
  @override String get underBondInfoBanner => 'This pathway allows transferring cargo to the factory warehouse under customs quarantine pending inspection results, with automatic dispatch blocking in warehouse records.';
  @override String get underBondGuaranteeRefLabel => 'Bank Guarantee Letter / Customs Undertaking No.';
  @override String get underBondQuarantineLocLabel => 'Lab Quarantine Warehouse Location (Factory Facility)';
  @override String get underBondDefaultQuarantineLoc => 'Main Company Warehouse - 6th of October';
  @override String get underBondConfirmReleaseBtn => 'Confirm Under-Bond Release & Activate Lock';
  @override String get underBondRequiredFieldsError => 'Please enter guarantee letter reference and quarantine location';
  @override String get underBondReleaseSuccess => 'Cargo released under-bond successfully, and warehouse lock activated';
  @override String underBondActionError(String error) => 'Action failed: $error';
  @override String get underBondLabInfoBanner => 'Record inspection certificates issued by central testing laboratories (GOEIC, NFSA, Atomic Energy). A passing verdict lifts the quarantine lock immediately.';
  @override String get underBondLabCertLabel => 'Testing Certificate Reference Number';
  @override String get underBondLabVerdictLabel => 'Lab Inspection Verdict';
  @override String get underBondLabVerdictPassed => 'Standard Specifications Compliant (PASSED) ✅';
  @override String get underBondLabVerdictRejected => 'Non-Compliant & Rejected (REJECTED) ⛔';
  @override String get underBondLabRemarksLabel => 'Laboratory Notes or Final Release Decision Number';
  @override String get underBondApproveReleaseBtn => 'Approve Compliance & Lift Warehouse Lock';
  @override String get underBondRejectReleaseBtn => 'Confirm Rejection & Ban Operation';
  @override String get underBondLabCertRequiredError => 'Please enter lab inspection certificate number';
  @override String get underBondLabApprovedSuccess => 'Quarantine lock lifted and lab compliance approved successfully ✅';
  @override String get underBondLabRejectedAlert => 'Sample rejected by laboratory; re-export mandate initiated ⛔';
  @override String underBondLabResultError(String error) => 'Failed to record lab result: $error';
  @override String get customsClearanceExportTsvBtn => 'Copy Registry as Table (TSV)';
  @override String get customsClearanceExportTsvSuccess => 'Customs clearance data copied to clipboard successfully';
  @override String get customsClearanceCopyFieldTooltip => 'Copy value';

  // ── Screen 60: Customs Clearance - Drawing Samples & Shortage Tracking ───────
  @override String get drawingSamplesScreenTitle => 'Drawing Samples & Shortage Tracking';
  @override String get drawingSamplesScreenSubtitle => 'Document regulatory lab inspections, track statutory testing deadlines, and reconcile cargo shortages';
  @override String get drawingSamplesTabDrawnSamples => 'Laboratory Drawn Samples';
  @override String get drawingSamplesTabShortageReconciliation => 'Cargo Examination & Shortage Tracking';
  @override String get drawingSamplesKpiTotalSamples => 'Total Drawn Samples';
  @override String get drawingSamplesKpiPassedSamples => 'Compliant & Passed';
  @override String get drawingSamplesKpiPendingSamples => 'Pending Laboratory Analysis';
  @override String get drawingSamplesKpiShortageCount => 'Documented Shortage Cases';
  @override String get drawingSamplesExportTsvBtn => 'Export TSV';
  @override String get drawingSamplesExportExcelBtn => 'Export Excel';
  @override String get drawingSamplesPrintPdfBtn => 'Print PDF Dossier';
  @override String get drawingSamplesCopyDossierBtn => 'Copy Complete Dossier';
  @override String get drawingSamplesCopiedDossierSuccess => 'Drawing samples and shortage dossier copied to clipboard';
  @override String get drawingSamplesCopiedTsvSuccess => 'Table data copied to clipboard in TSV format';
  @override String get drawingSamplesCopiedExcelSuccess => 'Excel file exported successfully';
  @override String get drawingSamplesCopyRowSummaryBtn => 'Copy Row Summary';
  @override String get drawingSamplesCopyRowSummarySuccess => 'Row summary copied to clipboard';
  @override String get drawingSamplesCopyFieldTooltip => 'Copy Value';
  @override String get drawingSamplesSearchHint => 'Search by sample ID, receipt no, authority, or declaration...';
  @override String get drawingSamplesFilterAll => 'All Samples';
  @override String get drawingSamplesFilterPassed => 'Passed & Compliant';
  @override String get drawingSamplesFilterPending => 'Pending Analysis';
  @override String get drawingSamplesEmptySamples => 'No drawn sample records found';
  @override String get drawingSamplesEmptyShortage => 'No shortage reconciliation records found';
  @override String get drawingSamplesShortageSectionTitle => 'Cargo Examination & Shortage Protocols';
  @override String get drawingSamplesShortageSectionDesc => 'Compare manifest weights and packages against landed physical cargo to document shortages and apply customs duty deductions or carrier claims';
  @override String get drawingSamplesAddShortageBtn => 'Record Shortage Protocol';
  @override String get drawingSamplesAddShortageDialogTitle => 'Record Cargo Examination Shortage Protocol';
  @override String get drawingSamplesSummaryHeader => 'System Summary & KPIs';
  @override String get drawingSamplesColSampleCode => 'Sample ID';
  @override String get drawingSamplesColShortageCode => 'Protocol ID';
  @override String get drawingSamplesColContainerPkg => 'Container / Package No.';
  @override String get drawingSamplesColItemDesc => 'Cargo / Item Description';
  @override String get drawingSamplesColManifestQty => 'Manifest Qty';
  @override String get drawingSamplesColLandedQty => 'Landed Qty';
  @override String get drawingSamplesColShortageQty => 'Shortage Qty';
  @override String get drawingSamplesColShortagePct => 'Shortage %';
  @override String get drawingSamplesColShortageAction => 'Customs Action';
  @override String get drawingSamplesColShortageNotes => 'Endorsement Notes';
  @override String get drawingSamplesShortageActionDeductDuty => 'Customs Duty & Tax Deduction';
  @override String get drawingSamplesShortageActionCarrierClaim => 'Carrier Shortlanded Claim';
  @override String get drawingSamplesShortageActionSurveyEndorsement => 'Joint Survey Protocol Endorsed';
  @override String get drawingSamplesShortageSaveSuccess => 'Cargo shortage protocol recorded successfully';
  @override String get drawingSamplesFieldSampleId => 'Sample ID';
  @override String get drawingSamplesFieldAuthority => 'Regulatory Authority / Laboratory';
  @override String get drawingSamplesFieldReceiptNo => 'Drawing Receipt Number';
  @override String get drawingSamplesFieldDrawingDate => 'Drawing Date';
  @override String get drawingSamplesFieldTestType => 'Required Test / Analysis Type';
  @override String get drawingSamplesFieldDeclarationNo => 'Customs Declaration 46';
  @override String get drawingSamplesFieldStatus => 'Inspection Verdict';
  @override String get drawingSamplesFieldNotes => 'Inspector & Laboratory Notes';
  @override String get drawingSamplesFieldContainerNo => 'Container / Package Number';
  @override String get drawingSamplesFieldItemDesc => 'Cargo Description';
  @override String get drawingSamplesFieldManifestQty => 'Manifest Quantity (Packages/Kg)';
  @override String get drawingSamplesFieldLandedQty => 'Landed Quantity (Packages/Kg)';
  @override String get drawingSamplesValidationRequired => 'This field is required';
  @override String get drawingSamplesValidationPositiveNumber => 'Please enter a valid positive number';
  @override String get drawingSamplesValidationLandedExceeds => 'Landed quantity cannot exceed manifest quantity';

  // ── Screen 61: Customs Clearance - Discrepancy & Damage Registry ───────────────
  @override String get discrepancyDamageScreenTitle => 'Discrepancy & Damage Protocols Registry';
  @override String get discrepancyDamageScreenSubtitle => 'Document container breach, water damage, shortage protocols with carrier agent, customs, and marine insurance for claim recovery.';
  @override String get discrepancyDamageKpiTotalProtocols => 'Total Protocols';
  @override String get discrepancyDamageKpiTotalLoss => 'Total Estimated Loss';
  @override String get discrepancyDamageKpiClaimsSubmitted => 'Claims Under Review';
  @override String get discrepancyDamageKpiClaimsApproved => 'Claims Approved';
  @override String get discrepancyDamageExportTsvBtn => 'Export TSV';
  @override String get discrepancyDamageExportExcelBtn => 'Export Excel';
  @override String get discrepancyDamagePrintPdfBtn => 'Print PDF Report';
  @override String get discrepancyDamageCopyDossierBtn => 'Copy Protocols Dossier';
  @override String get discrepancyDamageCopiedDossierSuccess => 'Discrepancy and damage dossier copied to clipboard successfully.';
  @override String get discrepancyDamageCopiedTsvSuccess => 'Protocols TSV exported and saved successfully.';
  @override String get discrepancyDamageCopiedExcelSuccess => 'Protocols Excel table exported and saved successfully.';
  @override String get discrepancyDamageCopyRowSummaryBtn => 'Copy Protocol Summary';
  @override String get discrepancyDamageCopyRowSummarySuccess => 'Joint inspection protocol summary copied successfully.';
  @override String get discrepancyDamageCopyFieldTooltip => 'Copy Value';
  @override String get discrepancyDamageSearchHint => 'Search by protocol no, declaration, container, damage type, or responsible party...';
  @override String get discrepancyDamageFilterAll => 'All Statuses';
  @override String get discrepancyDamageFilterSubmitted => 'Submitted to Insurance';
  @override String get discrepancyDamageFilterApproved => 'Approved for Compensation';
  @override String get discrepancyDamageFilterUnderReview => 'Under Investigation';
  @override String get discrepancyDamageEmptyRecords => 'No joint inspection protocols or damage records found.';
  @override String get discrepancyDamageAddProtocolBtn => 'New Joint Protocol';
  @override String get discrepancyDamageAddDialogTitle => 'Record Joint Inspection & Damage Protocol';
  @override String get discrepancyDamageSummaryHeader => 'Customs Protocol Summary';
  @override String get discrepancyDamageColProtocolNo => 'Protocol No';
  @override String get discrepancyDamageColDeclarationNo => 'Customs Declaration No';
  @override String get discrepancyDamageColContainerNo => 'Container No';
  @override String get discrepancyDamageColDamageType => 'Damage Nature';
  @override String get discrepancyDamageColDamagedQty => 'Damaged Qty';
  @override String get discrepancyDamageColEstimatedLoss => 'Estimated Loss';
  @override String get discrepancyDamageColResponsibleParty => 'Responsible Party';
  @override String get discrepancyDamageColClaimStatus => 'Claim Status';
  @override String get discrepancyDamageColDate => 'Inspection Date';
  @override String get discrepancyDamageColCommittee => 'Inspection Committee';
  @override String get discrepancyDamageColNotes => 'Notes & Findings';
  @override String get discrepancyDamageColActions => 'Actions';
  @override String get discrepancyDamageClaimApproved => 'Approved for Compensation';
  @override String get discrepancyDamageClaimSubmitted => 'Submitted to Insurance';
  @override String get discrepancyDamageClaimUnderReview => 'Under Investigation';
  @override String get discrepancyDamageFieldProtocolNo => 'Protocol Code';
  @override String get discrepancyDamageFieldDeclarationNo => 'Customs Declaration No (46 C.M.)';
  @override String get discrepancyDamageFieldContainerNo => 'Container or Package No';
  @override String get discrepancyDamageFieldDamageType => 'Nature of Damage & Defect';
  @override String get discrepancyDamageFieldDamagedQty => 'Damaged Qty or Packages';
  @override String get discrepancyDamageFieldEstimatedLoss => 'Estimated Loss (EGP)';
  @override String get discrepancyDamageFieldResponsibleParty => 'Responsible Party for Damage';
  @override String get discrepancyDamageFieldCommittee => 'Joint Inspection Committee Members';
  @override String get discrepancyDamageFieldNotes => 'Joint Committee Notes & Decisions';
  @override String get discrepancyDamageValidationRequired => 'This field is required for legal documentation';
  @override String get discrepancyDamageValidationPositiveNumber => 'Please enter a valid positive number';
  @override String get discrepancyDamageSaveSuccess => 'Joint inspection protocol and damage record saved successfully.';
  @override String get discrepancyDamageCurrencyEgp => 'EGP';

  // ── Screen 62: Customs Clearance - Final Duty Payment & Release ────────────
  @override String get finalDutyScreenTitle => 'Final Customs Duty Payment & Release Hub';
  @override String get finalDutyScreenSubtitle => 'Nafeza duty assessment reconciliation, bank receipt verification, variance tracking, and final release permit issuance';
  @override String get finalDutySummaryHeader => 'Customs Duty Payment & Release Summary';
  @override String get finalDutyKpiTotalPayable => 'Total Duties Payable';
  @override String get finalDutyKpiTotalPaid => 'Total Duties Paid';
  @override String get finalDutyKpiPendingPayment => 'Pending Settlements';
  @override String get finalDutyKpiNetVariance => 'Net Duty Variance';
  @override String get finalDutyExportTsvBtn => 'Export TSV';
  @override String get finalDutyExportExcelBtn => 'Export Excel';
  @override String get finalDutyPrintPdfBtn => 'Print PDF';
  @override String get finalDutyCopyDossierBtn => 'Copy Dossier';
  @override String get finalDutyCopiedDossierSuccess => 'Duty payment & release dossier copied to clipboard';
  @override String get finalDutyCopiedTsvSuccess => 'Duty payment table copied to clipboard as TSV';
  @override String get finalDutyCopiedExcelSuccess => 'Duty payment table exported as Excel CSV';
  @override String get finalDutyCopyRowSummaryBtn => 'Copy Row Summary';
  @override String get finalDutyCopyRowSummarySuccess => 'Clearance payment summary copied to clipboard';
  @override String get finalDutyCopyFieldTooltip => 'Copy Value';
  @override String get finalDutySearchHint => 'Search by clearance code, declaration 46, or customs office...';
  @override String get finalDutyFilterAll => 'All Records';
  @override String get finalDutyFilterPaid => 'Paid';
  @override String get finalDutyFilterPending => 'Pending Payment';
  @override String get finalDutyFilterReleased => 'Final Release';
  @override String get finalDutyEmptyRecords => 'No customs duty payment or release records found.';
  @override String get finalDutyColBankReceipt => 'Bank Receipt No';
  @override String get finalDutyColReleasePermit => 'Release Permit No';
  @override String get finalDutyCurrencyEgp => 'EGP';
  @override String get finalDutyStatusPaidVerified => 'Paid & Verified';
  @override String get finalDutyStatusPendingPayment => 'Pending Payment';
  @override String get finalDutyStatusReleased => 'Final Release Granted';
  @override String get finalDutyDossierHeader => 'Customs Duty Payment & Release Dossier — ImportFlow ERP';
  @override String get finalDutyDossierKpiSummary => 'Financial & Operational KPIs:';
  @override String get finalDutyDossierRecordsDetails => 'Customs Duty Settlement & Release Registry:';
  @override String get finalDutyPdfTitle => 'Customs Duty Payment & Release Audit Report';
  @override String get finalDutyPdfSubtitle => 'Nafeza Payment Reconciliations, Bank Receipts, and Port Gate Out Authorizations';

  // ── Screen 25: Freight Booking ─────────────────────────────────────────────
  @override String get freightBookingStageTitle => 'Freight Booking & Carrier Allocation';
  @override String get freightBookingTabRegistry => 'Freight Bookings Registry';
  @override String get freightBookingTabNewRequest => 'New Booking Request';
  @override String get freightBookingCreateButton => 'Create Freight Booking';
  @override String get freightBookingSearchHint => 'Search by booking code or confirmation number...';
  @override String get freightBookingFilterStatusLabel => 'Filter by Status';
  @override String get freightBookingFilterStatusHint => 'Search status...';
  @override String get freightBookingStatusAll => 'All Statuses';
  @override String get freightBookingStatusDraft => 'Draft';
  @override String get freightBookingStatusRequested => 'Booking Requested';
  @override String get freightBookingStatusConfirmed => 'Confirmed';
  @override String get freightBookingStatusSailed => 'Sailed';
  @override String get freightBookingEmptyRecords => 'No freight bookings recorded. Click create new booking.';
  @override String get freightBookingColActions => 'Actions';
  @override String get freightBookingColBookingCode => 'Booking Code';
  @override String get freightBookingColImportFile => 'Import File';
  @override String get freightBookingColConfirmationNo => 'Confirmation No.';
  @override String get freightBookingColCarrierForwarder => 'Carrier & Forwarder';
  @override String get freightBookingColRoute => 'Route (POL ➔ POD)';
  @override String get freightBookingColVesselVoyage => 'Vessel & Voyage';
  @override String get freightBookingColDeparture => 'Departure Date';
  @override String get freightBookingColArrival => 'Arrival Date';
  @override String get freightBookingColContainers => 'Allocated Containers';
  @override String get freightBookingColTotalFreight => 'Total Freight USD';
  @override String get freightBookingColStatus => 'Status';
  @override String freightBookingApprovedQuoteLabel(String provider) => 'Approved Quote: $provider';
  @override String freightBookingWhArrivalLabel(String date) => 'WH: $date';
  @override String get freightBookingPendingDate => 'Pending';
  @override String get freightBookingViewTooltip => 'View Booking Details';
  @override String get freightBookingEditTooltip => 'Edit Freight Booking';
  @override String get freightBookingPrintTooltip => 'Print Booking Card';
  @override String get freightBookingDeleteTooltip => 'Delete Freight Booking';
  @override String get freightBookingDeleteConfirmTitle => 'Confirm Deletion';
  @override String freightBookingDeleteConfirmMessage(String code) => 'Are you sure you want to delete freight booking $code?';
  @override String get freightBookingNewDialogTitle => 'Create Carrier Freight Booking';
  @override String freightBookingEditDialogTitle(String code) => 'Edit Freight Booking: $code';
  @override String get freightBookingCloseTooltip => 'Close';
  @override String get freightBookingTabBookingDetails => '1. Booking Details & Route';
  @override String get freightBookingTabCostBreakdown => '2. Cost Breakdown & Freight';
  @override String get freightBookingImportFileLabel => 'Import File *';
  @override String get freightBookingImportFileHint => 'Search import file...';
  @override String get freightBookingConfirmNoInputLabel => 'Booking Confirmation No. *';
  @override String get freightBookingConfirmNoValidator => 'Please enter booking confirmation number';
  @override String get freightBookingEvaluatedQuotesHeader => 'Evaluated Shipping Scenarios & Quotes:';
  @override String freightBookingAvailableQuotesBadge(int count) => '$count Available Quotes';
  @override String get freightBookingNoEvaluatedQuotes => 'No evaluated freight studies found for this file. You can enter carrier data manually below.';
  @override String get freightBookingApplyQuoteInstruction => 'Click "Apply This Quote" to auto-populate carrier, ports, vessel, schedule, costs, and containers:';
  @override String get freightBookingBestQuoteBadge => 'Best Evaluated Option';
  @override String freightBookingQuoteVesselDetails(String vessel, String voyage, String pol, String pod) => 'Vessel: $vessel | Voyage: $voyage | Route: $pol ➔ $pod';
  @override String freightBookingQuoteScheduleDetails(String sailing, String eta, int days) => 'Sailing: $sailing ➔ ETA: $eta | Free Time: $days days';
  @override String freightBookingQuoteStudyRef(String code, String date) => 'Study: $code ($date)';
  @override String get freightBookingSelectedQuoteBtn => 'Selected Quote ⭐';
  @override String get freightBookingApplyQuoteBtn => 'Apply This Quote';
  @override String freightBookingQuoteAppliedSuccess(String provider, String vessel) => 'Evaluated quote applied successfully ($provider - $vessel)!';
  @override String get freightBookingShippingLineLabel => 'Shipping Line *';
  @override String get freightBookingShippingLineHint => 'Search shipping line...';
  @override String get freightBookingForwarderLabel => 'Freight Forwarder';
  @override String get freightBookingForwarderHint => 'Search freight forwarder...';
  @override String get freightBookingPolLabel => 'Port of Loading (POL) *';
  @override String get freightBookingPolHint => 'Search loading port...';
  @override String get freightBookingPodLabel => 'Port of Discharge (POD) *';
  @override String get freightBookingPodHint => 'Search discharge port...';
  @override String get freightBookingEtdLabel => 'Estimated Departure (ETD) *';
  @override String get freightBookingEtaLabel => 'Estimated Arrival (ETA) *';
  @override String get freightBookingAtdLabel => 'Actual Departure (ATD)';
  @override String freightBookingDelayBannerDelayed(int days) => '⚠️ Departure Delay: $days days behind schedule';
  @override String get freightBookingDelayBannerOnTime => '✅ Departed on schedule (No delays)';
  @override String freightBookingExpectedWhArrival(String date) => 'Expected Warehouse Arrival: $date';
  @override String get freightBookingFreeDaysInput => 'Port Demurrage Free Days *';
  @override String get freightBookingWarehouseDaysInput => 'Warehouse Transit Days';
  @override String get freightBookingStatusInputLabel => 'Booking Status *';
  @override String get freightBookingVesselNameInput => 'Vessel Name';
  @override String get freightBookingVoyageNoInput => 'Voyage Number';
  @override String get freightBookingReleaseOrderInput => 'Container Release Order No.';
  @override String get freightBookingContainerTypeInput => 'Required Container Type';
  @override String get freightBookingContainersQtyInput => 'Booked Containers Count';
  @override String get freightBookingEquipmentNote => 'ℹ️ Note: Detailed container allocation, seal numbers, VGM weights, and inspection are handled in cargo preparation stage.';
  @override String get freightBookingCostBreakdownTitle => 'Comprehensive Freight Quotation Breakdown:';
  @override String freightBookingBaseCurrencyLabel(String cur) => 'Base Currency: $cur';
  @override String get freightBookingItemRateLabel => 'Item Rate';
  @override String get freightBookingCurrencyLabel => 'Currency';
  @override String get freightBookingQuantityLabel => 'Quantity';
  @override String get freightBookingCbmVolumeLabel => 'Volume CBM';
  @override String get freightBookingItemActive => 'Active';
  @override String get freightBookingItemInactive => 'Inactive';
  @override String get freightBookingItem40ft => '1. Container 40ft Freight';
  @override String get freightBookingItem20ft => '2. Container 20ft Freight';
  @override String get freightBookingItemLcl => '3. LCL CBM Freight';
  @override String get freightBookingItemCourier => '4. Express Courier';
  @override String get freightBookingItemEur1 => '5. EUR.1 / ATR Certificate';
  @override String get freightBookingItemVgm => '6. SOLAS / VGM Fees';
  @override String get freightBookingItemVgmNotif => '7. VGM Notification Fee';
  @override String get freightBookingItemTelex => '8. Telex Release';
  @override String get freightBookingItemInsurance => '9. Marine Insurance';
  @override String get freightBookingItemCancellation => '10. Booking Cancellation';
  @override String get freightBookingItemIcs2 => '11. ICS2 Filing Fee';
  @override String get freightBookingItemOther => '12. Other Freight Fees';
  @override String get freightBookingItemDocFees => '13. Document Fees';
  @override String get freightBookingItemWaiver => '14. Waiver Letter Fee';
  @override String get freightBookingItemDthc => '15. Destination THC (DTHC)';
  @override String get freightBookingItemStorageWeek => '16. First Week Port Storage';
  @override String get freightBookingItemStorageExtra => '17. Extra Days Port Storage';
  @override String get freightBookingMismatchTitle => 'Container Allocation Mismatch Warning';
  @override String freightBookingMismatchWarning(String assigned, String suggested) => 'Assigned containers count and type ($assigned) differs from recommendation ($suggested).';
  @override String get freightBookingMismatchPrompt => 'Do you wish to proceed with this allocation?';
  @override String get freightBookingMismatchNote => 'If "Yes" is selected, system requires entering justification reason to document decision.';
  @override String get freightBookingMismatchBtnNo => 'No (Go Back)';
  @override String get freightBookingMismatchBtnYes => 'Yes (Continue & Enter Reason)';
  @override String get freightBookingMismatchReasonTitle => 'Reason for Container Allocation Change *';
  @override String get freightBookingMismatchReasonHint => 'Enter justification for this different allocation...';
  @override String get freightBookingMismatchReasonValidator => 'Reason is required to proceed';
  @override String get freightBookingMismatchReasonConfirm => 'Confirm & Save';
  @override String get freightBookingDuplicateTitle => 'Warning: Shipment Booking Already Exists!';
  @override String get freightBookingDuplicateMessage => 'Selected import file already has an active freight booking:';
  @override String get freightBookingDuplicateRowFile => 'Import File:';
  @override String get freightBookingDuplicateRowCode => 'Booking Code:';
  @override String get freightBookingDuplicateRowConfirmNo => 'Confirmation No.:';
  @override String get freightBookingDuplicateRowLine => 'Shipping Line:';
  @override String get freightBookingDuplicateRowStatus => 'Current Status:';
  @override String get freightBookingDuplicateNotice => 'System rules prohibit multiple bookings for the same import file. You can switch to edit existing booking immediately.';
  @override String get freightBookingDuplicateBtnCancel => 'Cancel & Go Back';
  @override String get freightBookingDuplicateBtnSwitch => 'Switch to Edit';
  @override String get freightBookingBtnCloseDiscard => 'Close & Discard';
  @override String get freightBookingBtnLiveReload => 'Live Reload';
  @override String get freightBookingBtnClearNew => 'Clear & New';
  @override String get freightBookingBtnSaveDraft => 'Save Draft';
  @override String get freightBookingBtnSaveConfirm => 'Save & Confirm Booking';
  @override String get freightBookingBtnUpdate => 'Update Booking';
  @override String get freightBookingSaveSuccess => 'Freight booking saved and confirmed successfully!';
  @override String freightBookingViewTitle(String code) => 'Freight Booking Details: $code';
  @override String get freightBookingViewShippingLine => 'Shipping Line:';
  @override String get freightBookingViewConfirmNo => 'Confirmation No.:';
  @override String get freightBookingViewRouteSection => 'Route & Schedule:';
  @override String get freightBookingViewPol => 'Port of Loading:';
  @override String get freightBookingViewPod => 'Port of Discharge:';
  @override String freightBookingViewVesselVoyage(String vessel, String voyage) => 'Vessel: $vessel (Voyage: $voyage)';
  @override String freightBookingViewTransitTime(int days) => 'Transit Time: $days days';
  @override String freightBookingViewEtd(String date) => 'Estimated Departure (ETD): $date';
  @override String freightBookingViewEta(String date) => 'Estimated Arrival (ETA): $date';
  @override String freightBookingViewAtd(String date, String delay) => 'Actual Departure (ATD): $date ($delay)';
  @override String freightBookingViewExpectedWh(String date) => 'Expected Warehouse Arrival: $date';
  @override String get freightBookingViewContainersSection => 'Allocated Containers & Seals:';
  @override String get freightBookingViewChargesSection => 'Approved Freight Charges & Fees:';
  @override String get freightBookingViewTotalFreight => 'Total Estimated Freight (USD):';
  @override String freightBookingPrintTitle(String code) => 'Print Carrier Booking Manifest: $code';
  @override String freightBookingPrintManifestHeader(String code) => 'Carrier Booking Confirmation Manifest ($code)';
  @override String freightBookingPrintDate(String date) => 'Print Date: $date';
  @override String get freightBookingPrintContainersHeader => 'Containers & Seals Manifest:';
  @override String get freightBookingPrintChargesHeader => 'Approved Freight Costs & Charges:';
  @override String freightBookingPrintGrandTotal(String amount) => 'Grand Total: \$ $amount USD';
  @override String get freightBookingPrintNowBtn => 'Print Now';
  @override String get freightBookingPrintSuccess => 'Booking manifest sent to printer successfully!';
  // ── Screen 25 extra keys (hardcoded strings fixed) ────────────────────────
  @override String get freightBookingAiShippingLineBtn => 'AI Encode Shipping Line ✨';
  @override String get freightBookingAiForwarderBtn => 'AI Encode Freight Forwarder ✨';
  @override String get freightBookingDraftPendingLabel => 'Draft Pending';
  @override String freightBookingForwarderPrefixLabel(String name) => 'FWD: $name';
  @override String freightBookingEtdPrefixLabel(String date) => 'ETD: $date';
  @override String freightBookingAtdPrefixLabel(String date) => 'ATD: $date';
  @override String freightBookingEtaPrefixLabel(String date) => 'ETA: $date';
  @override String freightBookingBasedOnQuote(String name) => 'Based on quote: $name';
  @override String freightBookingCostSavingsBadgeAmount(String diff, String pct) => 'Saving: \$ $diff ($pct%)';
  @override String freightBookingCostIncreaseBadgeAmount(String diff) => 'Increase: \$ $diff';
  @override String get freightBookingCostMatchBadge => 'Match: \$ 0.00';
  @override String get freightBookingNetDifference => 'Net Diff.';
  @override String get freightBookingBreakdownHeader => '📊 Savings breakdown (unit price diff × quantity):';
  @override String freightBookingBreakdownSavingsUnit(String name, String orig, String exec, String unitDiff, String qty, String unitType, String savings) => '• $name: (\$$orig - \$$exec = \$$unitDiff) × $qty $unitType = \$$savings USD saved';
  @override String get freightBookingPrintSystemHeader => 'SOROUR LOGISTICS ERP - CARRIER BOOKING CONFIRMATION';
  @override String get searchAndCloneFreightBookingBtn => 'Search & Clone Booking';
  @override String get cloneFreightBookingDialogTitle => 'Clone Freight Booking';
  @override String get cloneFreightBookingDialogSubtitle => 'Select a previous freight booking and clone into a new draft with confirmation and B/L numbers reset';
  @override String get cloneBookingRowTooltip => 'Clone freight booking as new draft';
  @override String get copyBookingRowSuccess => 'Freight booking row copied to clipboard as TSV';
  @override String get copyBookingsTableSuccess => 'Freight bookings table copied to clipboard as TSV';
  @override String get exportBookingsExcelTooltip => 'Export freight bookings to Excel';
  @override String get exportBookingsPdfTooltip => 'Export freight bookings to PDF';

  // ── Screen 26 & 52: Cargo Shipping Tracking & Freight Allocations (VGM) ───
  @override String get searchAndCloneCargoShippingBtn => 'Search & Clone Shipping';
  @override String get cloneCargoShippingDialogTitle => 'Clone Cargo Shipping Record';
  @override String get cloneCargoShippingDialogSubtitle => 'Select a previous shipping record and duplicate container allocation into a new editable draft';
  @override String get cloneCargoShippingTooltip => 'Clone shipping and container allocation as new draft';
  @override String get cargoShippingDuplicateContainerTooltip => 'Duplicate Container (Ctrl + D)';
  @override String get copyCargoShippingRowSuccess => 'Cargo shipping row copied to clipboard as TSV';
  @override String get copyCargoShippingTableSuccess => 'Cargo shipping registry table copied to clipboard as TSV';
  @override String get exportCargoShippingExcelTooltip => 'Export cargo shipping registry to Excel';
  @override String get exportCargoShippingPdfTooltip => 'Export cargo shipping registry to PDF';
  @override String get cargoShippingAllocationsTitle => 'Freight Allocations & Cargo Shipping (VGM)';
  @override String get cargoShippingTrackingTitle => 'Cargo Shipping Tracking (48h SLA)';
  @override String get cargoShippingFormTab => 'Loading & Tracking Form';
  @override String get cargoShippingRegistryTab => 'Saved Cargo Registry';
  @override String get cargoShippingUploadBlLabel => 'Upload & Extract Bill of Lading';
  @override String cargoShippingUploadBlSuccess(String blNo) => 'Bill of lading cargo data extracted successfully ($blNo)';
  @override String get cargoShippingLinkedFileBannerPrefix => 'Linked Import File:';
  @override String get cargoShippingSupplierLabel => 'Supplier:';
  @override String get cargoShippingCodeLabel => 'Shipping Code:';
  @override String get cargoShippingCancelStartNew => 'Cancel & Start New';
  @override String get cargoShippingStep1Title => '1. Containers & VGM Assignment';
  @override String get cargoShippingStep2Title => '2. Container Loading & Supply Tracking (48h SLA)';
  @override String get cargoShippingImportFileLabel => 'Linked Import File *';
  @override String get cargoShippingImportFileHint => 'Select import file...';
  @override String get cargoShippingImportFileDefault => '-- Select Import File --';
  @override String get cargoShippingPreviouslyRegistered => '(Previously Registered)';
  @override String get cargoShippingSelectFileValidator => 'Please select an import file';
  @override String get cargoShippingShipmentTypeLabel => 'Shipment Type *';
  @override String get cargoShippingFclLabel => 'Full Container Load (FCL)';
  @override String get cargoShippingLclLabel => 'LCL (Less than Container Load - CFS)';
  @override String cargoShippingAggregatedCargoMetrics(String cbm, String weight) => 'Aggregated Cargo from Packing Lists: $cbm m³ | $weight kg';
  @override String get cargoShippingCargoStackingLabel => 'Cargo Stacking & Storage:';
  @override String get cargoShippingStackable => 'Stackable';
  @override String get cargoShippingNonStackable => 'Non-Stackable';
  @override String cargoShippingAutoRecommendation(int count, String code, String spaceUtil, String weightUtil) => 'Auto Container Recommendation: $count x $code (Space Util: $spaceUtil% | Payload Util: $weightUtil%)';
  @override String get cargoShippingContainersHeader => 'Allocated Containers, Seal Numbers & VGM:';
  @override String get cargoShippingAddContainerType => 'Add Container Type';
  @override String get cargoShippingContainerType => 'Container Type';
  @override String get cargoShippingQty => 'Qty';
  @override String get cargoShippingVgmWeight => 'Total VGM (Kg)';
  @override String get cargoShippingUnitDetailsHeader => 'Container No. and Seal No. per Unit:';
  @override String cargoShippingUnitPrefix(int number) => 'Container #$number: ';
  @override String get cargoShippingContainerNo => 'Container No.';
  @override String get cargoShippingSealNo => 'Seal No.';
  @override String get cargoShippingCfsHeader => 'CFS Consolidation Warehouse Info:';
  @override String get cargoShippingCfsWarehouseLabel => 'CFS Warehouse Name & Location';
  @override String get cargoShippingImportFileTrackingLabel => 'Linked Import File for Tracking *';
  @override String get cargoShippingImportFileTrackingHint => 'Select import file for loading tracking...';
  @override String cargoShippingActiveFileTrackingBanner(String fileCode, String company, String supplier, String acid) => 'Import File: [$fileCode] $company | Supplier: $supplier | ACID: $acid';
  @override String get cargoShippingMetricTotalContainers => 'Total Containers';
  @override String get cargoShippingMetricInProgress => 'Loading In Progress';
  @override String get cargoShippingMetricGatedIn => 'Gated-In at Port';
  @override String get cargoShippingMetricSlaBreached => '48h SLA Breached';
  @override String cargoShippingContainerCardHeader(int index, String containerNo, String containerType, String sealNo) => 'Container #$index: $containerNo ($containerType) | Seal: $sealNo';
  @override String get cargoShippingSlaBreachedBadge => '48h SLA Breached';
  @override String get cargoShippingQuickSaveContainer => 'Save Container Update 💾';
  @override String get cargoShippingMilestone1 => '1. Assignment';
  @override String get cargoShippingMilestone2 => '2. At Supplier';
  @override String get cargoShippingMilestone3 => '3. Loading Start';
  @override String get cargoShippingMilestone4 => '4. Loading End';
  @override String get cargoShippingMilestone5 => '5. Port Gate-In';
  @override String get cargoShippingMilestone1Title => 'Assignment Date & Time';
  @override String get cargoShippingMilestone2Title => 'Arrival at Supplier';
  @override String get cargoShippingMilestone3Title => 'Loading Start';
  @override String get cargoShippingMilestone4Title => 'Loading End';
  @override String get cargoShippingMilestone5Title => 'Port Gate-In';
  @override String get cargoShippingPickMilestone1 => 'Record Container Assignment Date & Time';
  @override String get cargoShippingPickMilestone2 => 'Record Arrival at Supplier Date & Time';
  @override String get cargoShippingPickMilestone3 => 'Record Loading Start Date & Time';
  @override String get cargoShippingPickMilestone4 => 'Record Loading End & Seal Date & Time';
  @override String get cargoShippingPickMilestone5 => 'Record Port Gate-In Date & Time';
  @override String get cargoShippingPickBtn => 'Pick 📅';
  @override String get cargoShippingSetNowBtn => 'Now ⚡';
  @override String get cargoShippingClickToSetDateTime => 'Click to set date and time 📅';
  @override String cargoShippingNotesHeader(String containerName) => 'Milestone Notes & Timeline for ($containerName):';
  @override String get cargoShippingSelectMilestoneTarget => 'Select Target Milestone: ';
  @override String get cargoShippingTagDriverDelayed => '⚠️ Driver Pickup Delayed';
  @override String get cargoShippingTagPermitPending => '⏳ Loading Permit Pending';
  @override String get cargoShippingTagContainerInspection => '🔍 Container & Seal Inspection';
  @override String get cargoShippingTagPortCongestion => '🛑 Port Gate Congestion';
  @override String get cargoShippingTagPalletizedCargo => '📦 Palletized Wooden Cargo';
  @override String get cargoShippingTagVisualCheck => '📝 Visual Inspection & Packing List Match';
  @override String cargoShippingNoteHint(String stepTitle) => 'Write a detailed note for ($stepTitle)...';
  @override String get cargoShippingSaveNote => 'Save Note 💾';
  @override String get cargoShippingClearNote => 'Clear Note';
  @override String cargoShippingLclTrackingHeader(String warehouse) => 'LCL Cargo Consolidation Tracking at: $warehouse';
  @override String get cargoShippingQuickSaveLcl => 'Save LCL Milestone 💾';
  @override String get cargoShippingLclMilestone1 => '1. Consolidation Sched';
  @override String get cargoShippingLclMilestone2 => '2. CFS Arrival';
  @override String get cargoShippingLclMilestone3 => '3. Stuffing Start';
  @override String get cargoShippingLclMilestone4 => '4. Stuffing End';
  @override String get cargoShippingLclMilestone5 => '5. Port Gate-In';
  @override String get cargoShippingLclPickMilestone1 => 'Record CFS Consolidation Scheduled Date';
  @override String get cargoShippingLclPickMilestone2 => 'Record CFS Warehouse Arrival Date';
  @override String get cargoShippingLclPickMilestone3 => 'Record Stuffing Start Date';
  @override String get cargoShippingLclPickMilestone4 => 'Record Stuffing Completion Date';
  @override String get cargoShippingLclPickMilestone5 => 'Record Consolidated Port Gate-In Date';
  @override String get cargoShippingAutoCompleteCycle => 'Auto-Complete Loading & Gate-In Cycle ⚡';
  @override String get cargoShippingClearStartNew => 'Clear & Start New 🔄';
  @override String get cargoShippingSaveDraft => 'Save Draft & Continue Later 💾';
  @override String get cargoShippingUpdateStudy => 'Update & Save Import Study';
  @override String get cargoShippingSaveStudy => 'Save Import Study & Confirm Tracking';
  @override String get cargoShippingRegistrySearchHint => 'Search by file code, company, shipping code, container no...';
  @override String get cargoShippingStatusFilterLabel => 'Shipping Status';
  @override String get cargoShippingStatusAll => 'All Statuses';
  @override String get cargoShippingStatusCargoReady => 'Cargo Ready';
  @override String get cargoShippingStatusCompleted => 'Completed';
  @override String get cargoShippingSlaFilterLabel => '48h SLA Status';
  @override String get cargoShippingSlaAll => 'All SLAs';
  @override String get cargoShippingSlaOnTimeFilter => 'On Time';
  @override String get cargoShippingSlaBreachedFilter => 'SLA Breached';
  @override String get cargoShippingActiveFilterLabel => 'Active / Deleted Records';
  @override String get cargoShippingActiveAll => 'All Records (Active & Deleted)';
  @override String get cargoShippingActiveOnly => 'Active Only';
  @override String get cargoShippingDeletedOnly => 'Deleted Only';
  @override String get cargoShippingNoMatchingRecords => 'No tracking records matching current search.';
  @override String get cargoShippingCreateNewRecord => 'Create New Cargo Tracking Record';
  @override String get cargoShippingSoftDeletedBadge => 'Soft Deleted';
  @override String cargoShippingGatedCountBadge(int count, int total) => 'Gated-In: $count / $total';
  @override String get cargoShippingSlaBreached => '⚠️ SLA Breached';
  @override String get cargoShippingSlaOnTime => '✅ Within 48h SLA';
  @override String get cargoShippingEditTooltip => 'Edit, Track Containers & Reactivate';
  @override String get cargoShippingRestoreTooltip => 'Restore & Reactivate Record';
  @override String cargoShippingLoadSuccessSnack(String identifier) => '📂 Saved data and milestone updates loaded for ($identifier) successfully!';
  @override String cargoShippingSaveContainerMilestoneSuccess(String containerNo, String status) => '💾 Container ($containerNo) updated successfully! Status: $status';
  @override String cargoShippingSaveLclMilestoneSuccess(String status) => '💾 LCL consolidation stage updated successfully! Status: $status';
  @override String get cargoShippingAutoCompleteSuccess => '⚡ Loading cycle and port gate-in completed for all containers successfully!';
  @override String cargoShippingStudySaveSuccess(String code) => '✅ Import study and tracking ($code) saved successfully!';
  @override String get cargoShippingDraftSaveSuccess => '💾 Draft saved successfully! Data is preserved and can be resumed anytime.';
  @override String cargoShippingRestoreSuccess(String code) => '♻️ Shipping tracking record ($code) restored successfully!';
  @override String cargoShippingDeleteSuccess(String code) => '🗑️ Shipping tracking record ($code) soft deleted.';
  @override String get cargoShippingDeleteConfirmTitle => 'Confirm Soft Delete of Shipping Record';
  @override String cargoShippingDeleteConfirmMessage(String code, String fileCode) => 'Are you sure you want to delete shipping record ($code) for file ($fileCode)?\n\nYou can restore or reactivate it anytime.';
  @override String get cargoShippingConfirmDeleteBtn => 'Confirm Delete';
  @override String get cargoShippingDuplicateWarningTitle => 'Duplicate / Container Conflict Warning';
  @override String get cargoShippingGoToSavedRegistry => 'Go to Saved Registry';
  @override String get cargoShippingDateSequenceError => '⚠️ Cannot select a date and time prior to the preceding milestone!';
  @override String get cargoShippingSelectFileFirstForContainer => '⚠️ Please select linked import file in Step 1 first before saving container updates.';
  @override String get cargoShippingSelectFileFirstForLcl => '⚠️ Please select linked import file in Step 1 first before saving LCL updates.';
  @override String cargoShippingQuickSaveError(String msg) => '❌ Could not save milestone: $msg';
  @override String cargoShippingLclSaveError(String msg) => '❌ Could not save LCL milestone: $msg';
  @override String get cargoShippingFillRequiredFields => 'Please ensure all required fields are filled.';
  @override String get cargoShippingSelectLinkedFilePrompt => 'Please select the linked import file first.';
  @override String get cargoShippingStatusGatedIn => 'Gated-in at Port';
  @override String get cargoShippingStatusLoadingCompleted => 'Loading Completed';
  @override String get cargoShippingStatusLoadingInProgress => 'Loading in Progress';
  @override String get cargoShippingStatusArrivedAtSupplier => 'Arrived at Supplier';
  @override String get cargoShippingStatusArrivedAtCfs => 'Arrived at CFS';
  @override String get cargoShippingStatusAssigned => 'Assigned';
  @override String get cargoShippingStatusPendingAssignment => 'Pending Assignment';
  @override String get cargoShippingAiExtractorBtn => 'Smart Invoice & B/L Analyzer';
  @override String get cargoShippingExportManifestBtn => 'Copy Container Manifest (TSV)';
  @override String get cargoShippingManifestCopySuccess => 'Container allocations and VGM manifest copied to clipboard successfully!';
  @override String get cargoShippingCopyFieldTooltip => 'Copy value to clipboard';
  @override String get cargoShippingAcidPrefix => 'Customs ACID';
  @override String get cargoShippingManifestHeader => 'Container Allocations & Verified Gross Mass (VGM) Manifest';
  @override String get cargoShippingColUnitNumber => '#';
  @override String get cargoShippingColContainerNo => 'Container No';
  @override String get cargoShippingColContainerType => 'Container Type';
  @override String get cargoShippingColSealNo => 'Carrier Seal No';
  @override String get cargoShippingColGrossWeight => 'Gross Weight (kg)';
  @override String get cargoShippingColVgmStatus => 'VGM Status';
  @override String get cargoShippingColVgmRef => 'VGM Ref No';
  @override String get cargoShippingColTrackingStatus => 'Tracking Status';

  // Screen 52: Cargo Shipping 48h SLA Tracking & Export Toolbar
  @override String get cargoShippingSlaStageTitle => 'Cargo Shipping Tracking (48h SLA)';
  @override String get cargoShippingSlaExportTsvBtn => 'Export TSV';
  @override String get cargoShippingSlaExportExcelBtn => 'Export Excel';
  @override String get cargoShippingSlaPrintPdfBtn => 'Print & Save Document';
  @override String get cargoShippingSlaCopyDossierBtn => 'Copy SLA Dossier';
  @override String get cargoShippingSlaCopyDossierSuccess => 'Cargo shipping SLA dossier copied to clipboard';
  @override String get cargoShippingSlaDossierHeader => 'Cargo Shipping & 48h SLA Milestone Tracking Dossier';
  @override String get cargoShippingSlaExportTsvDialogTitle => 'Save Cargo Shipping SLA (TSV)';
  @override String get cargoShippingSlaExportExcelDialogTitle => 'Save Cargo Shipping SLA (Excel)';
  @override String get cargoShippingSlaTsvHeaderUnit => '#';
  @override String get cargoShippingSlaTsvHeaderContainerNo => 'Container Number';
  @override String get cargoShippingSlaTsvHeaderContainerType => 'Container Type';
  @override String get cargoShippingSlaTsvHeaderSealNo => 'Seal Number';
  @override String get cargoShippingSlaTsvHeaderAssignmentDate => 'Assignment Date';
  @override String get cargoShippingSlaTsvHeaderArrivalDate => 'Arrival at Supplier';
  @override String get cargoShippingSlaTsvHeaderLoadingStartDate => 'Loading Started';
  @override String get cargoShippingSlaTsvHeaderLoadingEndDate => 'Loading Completed';
  @override String get cargoShippingSlaTsvHeaderPortGateInDate => 'Port Gate-In';
  @override String get cargoShippingSlaTsvHeaderSlaStatus => '48h SLA Status';
  @override String get cargoShippingSlaTsvHeaderTrackingStatus => 'Tracking Status';
  @override String get cargoShippingSlaTsvHeaderNotes => 'Milestone Notes';
  @override String get cargoShippingSlaSummaryHeader => 'Cargo Shipping SLA Tracking Metrics';
  @override String get cargoShippingSlaCopyContainerSuccess => 'Container number copied to clipboard';
  @override String get cargoShippingSlaCopySealSuccess => 'Seal number copied to clipboard';
  @override String get cargoShippingSlaCopyMilestoneSuccess => 'Milestone timestamp copied to clipboard';

  // Screen 28: Warehouse Receiving & Inspection (GRN)
  @override String get searchAndCloneWarehouseReceivingBtn => 'Search & Clone GRN';
  @override String get cloneWarehouseReceivingDialogTitle => 'Clone Goods Receiving Note (GRN)';
  @override String get cloneWarehouseReceivingDialogSubtitle => 'Select a previous receiving note to clone line items and inspection counts into a new draft';
  @override String get cloneWarehouseReceivingTooltip => 'Clone this GRN record into editable draft';
  @override String get copyWarehouseReceivingRowSuccess => 'Goods Receiving Note data copied to clipboard (TSV)';
  @override String get copyWarehouseReceivingTableSuccess => 'Warehouse receiving registry table copied to clipboard (TSV)';
  @override String get exportWarehouseReceivingExcelTooltip => 'Export GRN registry to Excel';
  @override String get exportWarehouseReceivingPdfTooltip => 'Export GRN registry to PDF';
  @override String get warehouseReceivingStageTitle => 'Warehouse Receiving & Inspection (GRN)';
  @override String get warehouseReceivingTabRegistry => 'Goods Receiving Notes (GRN)';
  @override String get warehouseReceivingTabNewEntry => 'New GRN Entry';
  @override String get warehouseReceivingRefreshTooltip => 'Refresh Data';
  @override String get warehouseReceivingNewGrnBtn => 'Record Truck Arrival & New GRN';
  @override String get warehouseReceivingSearchHint => 'Search by GRN, truck plate, driver...';
  @override String get warehouseReceivingStatusAll => 'All Statuses';
  @override String get warehouseReceivingStatusDraft => 'Temporary Draft (Pending Count)';
  @override String get warehouseReceivingStatusGoodsReceived => 'Goods Fully Received';
  @override String get warehouseReceivingStatusDiscrepancy => 'Shortage / Damage Recorded';
  @override String get warehouseReceivingEmptyRecords => 'No warehouse receiving records found.';
  @override String get warehouseReceivingTruckAndDriver => 'Truck & Driver';
  @override String get warehouseReceivingArrivalDatetime => 'Arrival Date & Time';
  @override String get warehouseReceivingInspector => 'Inspector & QA Officer';
  @override String get warehouseReceivingDiscrepancyStatus => 'Discrepancy Status';
  @override String get warehouseReceivingMetricInvoiced => 'Invoiced';
  @override String get warehouseReceivingMetricAccepted => 'Accepted';
  @override String get warehouseReceivingMetricShortage => 'Shortage';
  @override String get warehouseReceivingMetricDamaged => 'Damaged';
  @override String get warehouseReceivingConfirmFinalReceiptBtn => 'Confirm Final Warehouse Receipt';
  @override String get warehouseReceivingRecordDiscrepancyBtn => 'Record Shortage / Damage';
  @override String warehouseReceivingPrintGrnSnack(String grn, String wh) => 'Printing GRN document: $grn ($wh)';
  @override String get warehouseReceivingDeleteTitle => 'Delete Receiving Note';
  @override String get warehouseReceivingDeleteConfirmMessage => 'Are you sure you want to move this receiving note to trash?';
  @override String get warehouseReceivingViewTooltip => 'View Receiving Note';
  @override String get warehouseReceivingEditTooltip => 'Edit Receiving Note';
  @override String get warehouseReceivingPrintTooltip => 'Print GRN Note';
  @override String get warehouseReceivingDeleteTooltip => 'Delete Receiving Note (Soft Delete)';
  @override String get warehouseReceivingSealIntact => 'Seal Intact';
  @override String get warehouseReceivingSealBroken => 'Seal Broken';
  @override String get warehouseReceivingConfirmReceiptTitle => 'Confirm Final Warehouse Receipt';
  @override String warehouseReceivingConfirmReceiptMessage(String grn) => 'Do you want to confirm final receipt for shipment [$grn] in warehouse?\n\n⚠️ This action will finalize actual quantities, close the note, and deduct the shipment balance from Goods in Transit (GIT) report.';
  @override String get warehouseReceivingConfirmReceiptBtn => 'Yes, Confirm Final Receipt';
  @override String warehouseReceivingConfirmReceiptSuccess(String grn) => 'Final receipt confirmed for $grn and deducted from GIT successfully';
  @override String warehouseReceivingConfirmReceiptError(String error) => 'Error confirming receipt: $error';
  @override String get warehouseReceivingNewDialogTitle => 'New Warehouse Receiving Note Entry';
  @override String get warehouseReceivingEditDialogTitle => 'Edit Receiving Note & Confirm Receipt';
  @override String get warehouseReceivingDispatchAlertTitle => 'Document Dispatch Alert:';
  @override String get warehouseReceivingDispatchAlertDesc => 'Approved shipment documents (Packing List & Commercial Invoice) must be dispatched immediately to warehouse staff for cargo verification upon truck arrival.';
  @override String get warehouseReceivingDispatchSentBtn => 'Dispatched to Warehouse';
  @override String get warehouseReceivingDispatchSendBtn => 'Send Alert to Warehouse & Create Task';
  @override String get warehouseReceivingDispatchSuccessSnack => 'Documents alert sent and smart task generated on dashboard for warehouse staff successfully';
  @override String get warehouseReceivingImportFileLabel => 'Import Shipment File *';
  @override String get warehouseReceivingSelectFileValidator => 'Please select an import file';
  @override String get warehouseReceivingWarehouseNameLabel => 'Warehouse Name & Branch *';
  @override String get warehouseReceivingWarehouseNameValidator => 'Please enter warehouse name';
  @override String get warehouseReceivingTruckPlateLabel => 'Truck / Vehicle Plate Number';
  @override String get warehouseReceivingDriverNameLabel => 'Driver Name';
  @override String get warehouseReceivingSealNumberLabel => 'Seal / Security Lock Number';
  @override String get warehouseReceivingSealIntactSwitch => 'Seal Intact';
  @override String get warehouseReceivingMultiPoHeader => 'Itemized Inventory & Inspection Breakdown per Purchase Order:';
  @override String get warehouseReceivingAddItemBtn => 'Add Item';
  @override String warehouseReceivingPoLabel(String po) => 'PO: $po';
  @override String get warehouseReceivingItemNameLabel => 'Item Name & Description';
  @override String get warehouseReceivingInvoicedQtyLabel => 'Invoiced Qty';
  @override String get warehouseReceivingAcceptedQtyLabel => 'Accepted Qty';
  @override String get warehouseReceivingShortageQtyLabel => 'Shortage Qty';
  @override String get warehouseReceivingDamagedQtyLabel => 'Damaged Qty';
  @override String get warehouseReceivingSamplesQtyLabel => 'Drawn Samples';
  @override String get warehouseReceivingSaveDraftBtn => 'Save Draft (Pending Count)';
  @override String get warehouseReceivingSaveFinalBtn => 'Confirm Final Receipt';
  @override String get warehouseReceivingDraftSuccessSnack => 'Receiving note saved as draft pending warehouse physical count';
  @override String get warehouseReceivingFinalSuccessSnack => 'Final warehouse receipt confirmed and GIT balance updated successfully';
  @override String warehouseReceivingDiscrepancyDialogTitle(String grn) => 'Official Discrepancy / Damage Protocol for: $grn';
  @override String get warehouseReceivingDiscrepancyTypeLabel => 'Discrepancy & Variance Type *';
  @override String get warehouseReceivingDiscrepancyTypeShortageAndDamage => 'Total Shortage and Damage';
  @override String get warehouseReceivingDiscrepancyTypeShortageOnly => 'Shortage Only';
  @override String get warehouseReceivingDiscrepancyTypeDamageOnly => 'Damage & Breakage Only';
  @override String get warehouseReceivingDiscrepancyTypeBrokenSeal => 'Broken Seal Discrepancy';
  @override String get warehouseReceivingDiscrepancyNotesLabel => 'Inspection Notes & Details *';
  @override String get warehouseReceivingDiscrepancyNotesValidator => 'Please enter inspection notes';
  @override String get warehouseReceivingQuarantineSwitch => 'Quarantine Cargo in Holding Area';
  @override String get warehouseReceivingInsuranceClaimSwitch => 'File Marine Insurance Claim';
  @override String get warehouseReceivingClaimRefLabel => 'Insurance Claim Reference Number';
  @override String get warehouseReceivingCertifyDiscrepancyBtn => 'Certify Discrepancy Protocol';
  @override String get warehouseReceivingDiscrepancySuccessSnack => 'Discrepancy and damage protocol certified successfully';
  @override String get warehouseReceivingQuarantineLockBadge => 'Quarantine Lock: Under Customs Custody';
  @override String get warehouseReceivingQuarantineStatusBlocked => 'Release Blocked (Quarantine)';
  @override String get warehouseReceivingQuarantineStatusCheck => 'Check Release Validity';
  @override String get warehouseReceivingQuarantineAlertBlocked => 'Release blocked: Cargo is under customs laboratory quarantine pending positive inspection results.';
  @override String get warehouseReceivingQuarantineAlertCleared => 'Cargo has been permanently released and approved for factory dispatch and operations.';
  @override String get warehouseReceivingExportTsvBtn => 'Export GRN Table (TSV / Excel)';
  @override String get warehouseReceivingExportTsvSuccess => 'GRN records exported and copied to clipboard (TSV format) successfully';
  @override String get warehouseReceivingCopyFieldTooltip => 'Copy field value';
  @override String warehouseReceivingPrintReceiptSuccess(String grn) => 'Warehouse receiving receipt for $grn copied to clipboard successfully';
  @override String get warehouseReceivingColGrnCode => 'GRN Code';
  @override String get warehouseReceivingColWarehouse => 'Warehouse';
  @override String get warehouseReceivingColStatus => 'Status';
  @override String get warehouseReceivingColQuarantine => 'Quarantine Status';
  @override String get warehouseReceivingColTruckDriver => 'Driver & Plate';
  @override String get warehouseReceivingColArrivalDate => 'Arrival Date';
  @override String get warehouseReceivingColInspector => 'Inspector';
  @override String get warehouseReceivingColDiscrepancy => 'Discrepancy';
  @override String get warehouseReceivingColInvoicedQty => 'Invoiced Qty';
  @override String get warehouseReceivingColAcceptedQty => 'Accepted Qty';
  @override String get warehouseReceivingColShortageQty => 'Shortage Qty';
  @override String get warehouseReceivingColDamagedQty => 'Damaged Qty';

  // ==========================================
  // Screen 29: Landed Cost Settlement (FinancialSettlementScreen & OdooJournalEntryDialog)
  // ==========================================
  @override String get searchAndCloneFinancialSettlementBtn => 'Search & Clone Cost Settlement';
  @override String get cloneFinancialSettlementDialogTitle => 'Clone Landed Cost Settlement';
  @override String get cloneFinancialSettlementDialogSubtitle => 'Create a new cloned settlement draft with cleared IDs and reset parameters';
  @override String get cloneFinancialSettlementTooltip => 'Clone this settlement as a new draft';
  @override String get copyFinancialSettlementRowSuccess => 'Selected settlement row copied to clipboard (TSV)';
  @override String get copyFinancialSettlementTableSuccess => 'Cost settlements table copied to clipboard (TSV)';
  @override String get exportFinancialSettlementExcelTooltip => 'Export settlements registry to Excel';
  @override String get exportFinancialSettlementPdfTooltip => 'Export settlements registry to PDF';
  @override String get financialSettlementStageTitle => 'Financial Settlement & Unit Landed Cost Engine';
  @override String get financialSettlementTabRegistry => 'Landed Cost Registry';
  @override String get financialSettlementTabNewEntry => 'New Landed Cost Calculation';
  @override String get financialSettlementRefreshTooltip => 'Refresh Data';
  @override String get financialSettlementNewSettlementBtn => 'Record Expenses & Calculate Landed Cost';
  @override String get financialSettlementSearchHint => 'Search by settlement code, accountant...';
  @override String get financialSettlementFetchError => 'Error fetching financial settlement records:';
  @override String get financialSettlementEmptyRecords => 'No landed cost settlements recorded currently.';
  @override String financialSettlementAccountantLabel(String accountant) => 'Accountant: $accountant';
  @override String get financialSettlementStatusDraft => 'Draft';
  @override String get financialSettlementStatusCalculated => 'Calculated';
  @override String get financialSettlementStatusApproved => 'Approved';
  @override String get financialSettlementMetricFobTotal => 'Total Invoice (FOB)';
  @override String get financialSettlementMetricExpensesTotal => 'Total Expenses & Freight';
  @override String get financialSettlementMetricLandedCostTotal => 'Total Landed Cost';
  @override String get financialSettlementMetricMarkupFactor => 'Average Markup Factor';
  @override String get financialSettlementExpensesSectionHeader => '1️⃣ Recorded Logistics & Customs Expense Invoices:';
  @override String get financialSettlementColInvoiceNo => 'Invoice No';
  @override String get financialSettlementColCategory => 'Category';
  @override String get financialSettlementColProvider => 'Service Provider';
  @override String get financialSettlementColAmountFx => 'Amount (FX)';
  @override String get financialSettlementColExchangeRate => 'Exchange Rate';
  @override String get financialSettlementColAmountEgp => 'Amount (EGP)';
  @override String get financialSettlementColAllocationRule => 'Allocation Rule';
  @override String get financialSettlementCategoryFreight => 'Freight';
  @override String get financialSettlementCategoryCustomsDuty => 'Customs Duty';
  @override String get financialSettlementCategoryBrokerage => 'Brokerage';
  @override String get financialSettlementCategoryLocalTransport => 'Local Transport';
  @override String get financialSettlementCategoryStorage => 'Storage';
  @override String get financialSettlementRuleVolumeBased => 'Volume-Based (CBM)';
  @override String get financialSettlementRuleValueBased => 'Value-Based (FOB)';
  @override String get financialSettlementRuleWeightBased => 'Weight-Based (Gross Wt)';
  @override String get financialSettlementRuleEqual => 'Equal';
  @override String get financialSettlementItemsSectionHeader => '2️⃣ Unit Landed Cost & Expense Allocation Breakdown:';
  @override String get financialSettlementColItemCode => 'Item Code';
  @override String get financialSettlementColItemName => 'Item Name';
  @override String get financialSettlementColQty => 'Qty';
  @override String get financialSettlementColFobUnit => 'Unit FOB (EGP)';
  @override String get financialSettlementColAllocatedFreight => 'Allocated Freight';
  @override String get financialSettlementColAllocatedCustoms => 'Allocated Customs';
  @override String get financialSettlementColAllocatedClearance => 'Allocated Clearance';
  @override String get financialSettlementColAllocatedTransport => 'Allocated Transport';
  @override String get financialSettlementColUnitLandedCost => 'Unit Landed Cost';
  @override String get financialSettlementColMarkupFactor => 'Markup Factor';
  @override String get financialSettlementExportOdooBtn => '📒 Export Journal Entry to Odoo / ERP';
  @override String get financialSettlementRecalculateBtn => 'Recalculate Landed Cost';
  @override String financialSettlementRecalculateSuccessSnack(String code) => 'Landed cost recalculation completed for settlement: $code';
  @override String financialSettlementPrintSnack(String code, String total) => 'Printing Landed Cost breakdown: $code (Total: $total EGP)';
  @override String get financialSettlementViewTooltip => 'View Settlement Details';
  @override String get financialSettlementEditTooltip => 'Edit & Recalculate';
  @override String get financialSettlementPrintTooltip => 'Print Landed Cost Sheet';
  @override String get financialSettlementDeleteTooltip => 'Soft Delete Settlement';
  @override String get financialSettlementDeleteTitle => 'Delete Settlement Record';
  @override String get financialSettlementDeleteMessage => 'Are you sure you want to soft delete this settlement record?';
  @override String get financialSettlementDialogTitle => 'Record Expenses & Shipment Items to Calculate Landed Cost';
  @override String get financialSettlementImportFileLabel => 'Import Shipment File *';
  @override String get financialSettlementImportFileSearchHint => 'Search import file by number or company...';
  @override String get financialSettlementImportFileValidator => 'Please select an import file';
  @override String get financialSettlementExpenseSectionHeader => 'Logistics & Service Expense Invoice Details:';
  @override String get financialSettlementInvoiceNoLabel => 'Invoice No *';
  @override String get financialSettlementCategoryLabel => 'Expense Category *';
  @override String get financialSettlementCategorySearchHint => 'Search expense category...';
  @override String get financialSettlementProviderNameLabel => 'Service Provider Name *';
  @override String get financialSettlementAmountFxLabel => 'Amount (FX Currency)';
  @override String get financialSettlementExchangeRateLabel => 'Exchange Rate';
  @override String get financialSettlementAllocationRuleLabel => 'Expense Allocation Rule *';
  @override String get financialSettlementAllocationRuleSearchHint => 'Search allocation rule...';
  @override String get financialSettlementItemSectionHeader => 'Shipment Item Line Details:';
  @override String get financialSettlementItemCodeLabel => 'Item Code';
  @override String get financialSettlementItemNameLabel => 'Item Name';
  @override String get financialSettlementQtyReceivedLabel => 'Received Quantity';
  @override String get financialSettlementFobUnitPriceLabel => 'Unit FOB Price (EGP)';
  @override String get financialSettlementLiveReloadBtn => 'Live Reload';
  @override String get financialSettlementResetFormBtn => 'Reset Form';
  @override String get financialSettlementSaveAndAllocateBtn => 'Save & Allocate Expenses';
  @override String financialSettlementSaveError(String error) => 'Error saving and calculating settlement: $error';
  @override String get odooJournalLoading => 'Generating balanced double-entry journal for Odoo / ERP...';
  @override String odooJournalFetchError(String error) => 'Error fetching journal entry: $error';
  @override String odooJournalTitle(String code) => 'Double-Entry Journal & Odoo ERP Export ($code)';
  @override String odooJournalSubtitle(String fileCode, String ref) => 'Import File: $fileCode | Ref: $ref';
  @override String get odooJournalBalanced => '🟢 100% Balanced (Debit = Credit)';
  @override String odooJournalUnbalanced(String diff) => '🔴 Unbalanced (Variance: $diff EGP)';
  @override String get odooJournalMetaImporter => 'Importing Company';
  @override String get odooJournalMetaSupplier => 'Foreign Supplier';
  @override String get odooJournalMetaProject => 'Project / Analytic Account';
  @override String get odooJournalMetaDate => 'Entry Date';
  @override String get odooJournalMetaTotalDebitCredit => 'Total Debit / Credit';
  @override String get odooJournalLinesSectionHeader => 'Double-Entry General Ledger Lines Details:';
  @override String get odooJournalColAccountCode => 'Account Code';
  @override String get odooJournalColAccountName => 'Ledger Account Name';
  @override String get odooJournalColPartner => 'Partner';
  @override String get odooJournalColLabel => 'Label / Description';
  @override String get odooJournalColDebit => 'Debit (EGP)';
  @override String get odooJournalColCredit => 'Credit (EGP)';
  @override String get odooJournalColForeignCurrency => 'Foreign Currency';
  @override String get odooJournalColCostCategory => 'Cost Category';
  @override String get odooJournalExportCsvBtn => '📥 Download Odoo CSV Ready for Direct Import';
  @override String get odooJournalExportExcelBtn => '📊 Download Accounting Excel Workbook';
  @override String odooJournalExportingSnack(String filename, String directUrl) => 'Exporting: $filename\nDirect link: $directUrl';
  @override String get financialSettlementCopyFieldTooltip => 'Copy value to clipboard';
  @override String get financialSettlementExportTsvBtn => 'Export Settlements (TSV)';
  @override String get financialSettlementExportTsvSuccess => 'Financial settlements copied successfully as TSV';
  @override String get financialSettlementCopyBreakdownTsvBtn => 'Copy Cost Breakdown (TSV)';
  @override String get financialSettlementCopyBreakdownSuccess => 'Landed cost and expense breakdown copied successfully';
  @override String get financialSettlementPrintSummarySuccess => 'Landed cost summary report copied to clipboard';
  @override String get financialSettlementCurrencyEgp => 'EGP';
  @override String get odooJournalCopyTsvBtn => 'Copy Journal Entry (TSV)';
  @override String get odooJournalCopyTsvSuccess => 'Journal entry lines copied successfully as TSV';
  @override String get odooJournalSaveCsvDialogTitle => 'Save Odoo Journal Entries as CSV';
  @override String get odooJournalSaveExcelDialogTitle => 'Save Journal Voucher and Landed Cost as Excel';
  @override String get odooJournalCatGoods => 'Goods';
  @override String get odooJournalCatFreight => 'Freight';
  @override String get odooJournalCatCustoms => 'Customs';
  @override String get odooJournalCatClearance => 'Clearance';
  @override String get odooJournalCatTransport => 'Transport';
  @override String get odooJournalCatDemurrage => 'Demurrage';
  @override String get odooJournalCatPriceAdjustment => 'Price Adjustment';

  // ---------------------------------------------------------------------------
  // Screen 30: File Closure & Archival
  // ---------------------------------------------------------------------------
  @override String get searchAndCloneFileClosureBtn => 'Search & Clone Archival Record';
  @override String get cloneFileClosureDialogTitle => 'Clone Archival & File Closure (Draft)';
  @override String get cloneFileClosureDialogSubtitle => 'Duplicate previous file closure record into a new editable draft with reset invariants.';
  @override String get cloneFileClosureTooltip => 'Clone this closure certificate into a new draft';
  @override String get copyFileClosureRowSuccess => 'File closure certificate copied to clipboard as TSV';
  @override String get copyFileClosureTableSuccess => 'Archived shipments registry copied to clipboard as TSV';
  @override String get exportFileClosureExcelTooltip => 'Export archived shipments registry to Excel';
  @override String get exportFileClosurePdfTooltip => 'Export archived shipments registry to PDF';
  @override String get fileClosureStageTitle => 'Import File Final Closure & Archival';
  @override String get fileClosureTabArchivedRegistry => 'Archived Files Registry';
  @override String get fileClosureTabCloseFile => 'Close Import File';
  @override String get fileClosureRefreshTooltip => 'Refresh Data';
  @override String get fileClosureNewCertificateBtn => 'Issue Final Closure & Archival Certificate';
  @override String get fileClosureSearchHint => 'Search by CLR code, auditor...';
  @override String get fileClosureFetchError => 'Error fetching shipment archive data:';
  @override String get fileClosureEmptyRecords => 'No finalized and archived shipments found currently.';
  @override String fileClosureClosedFilesBannerTitle(int count) => 'Previously Closed Shipments Registry ($count archived):';
  @override String get fileClosureClosedBadge => 'Closed';
  @override String fileClosureStopReason(String reason) => 'Closure Reason: $reason';
  @override String get fileClosureReopenBtn => 'Reopen & Activate Shipment';
  @override String fileClosureFileRefLabel(int id) => 'Import File Reference: #$id';
  @override String fileClosureVaultLabel(String location) => 'Archive Location: $location';
  @override String get fileClosureStatusBadgeClosed => 'Closed & Archived (100%)';
  @override String get fileClosureChecklistHeader => 'Completed Closure Verification Conditions:';
  @override String get fileClosureChecklistDocsOriginals => 'Original Documents & Electronic Transfer';
  @override String get fileClosureChecklistCustomsCleared => 'Customs Clearance & Form 46';
  @override String get fileClosureChecklistWarehouseGrn => 'Warehouse Inspection & GRN';
  @override String get fileClosureChecklistLandedCost => 'Financial Settlement & Landed Cost';
  @override String get fileClosureChecklistTasksClosed => 'Operational Tasks Closure';
  @override String fileClosureArchivalNotes(String notes) => 'Archive Notes: $notes';
  @override String fileClosureAuditorLabel(String auditor) => 'Auditor in Charge: $auditor';
  @override String fileClosureCertificateDialogTitle(String code) => 'Closure & Archival Certificate: $code';
  @override String fileClosureCertFileNo(int id) => 'Shipment File No: #$id';
  @override String fileClosureCertLocation(String loc) => 'Archive Location: $loc';
  @override String fileClosureCertAuditor(String name) => 'Auditor: $name';
  @override String fileClosureCertClosedDate(String date) => 'Closure Date: $date';
  @override String fileClosureCertNotes(String notes) => 'Notes: $notes';
  @override String fileClosureEditSnack(String code) => 'Editing file closure & archive data: $code';
  @override String fileClosurePrintSnack(String code, int fileId) => 'Printing official closure and archival certificate: $code (File #$fileId)';
  @override String get fileClosureDeleteTitle => 'Delete Archive Record';
  @override String get fileClosureDeleteMessage => 'Are you sure you want to move this closure record to trash?';
  @override String get fileClosureViewTooltip => 'View Closure Certificate';
  @override String get fileClosureEditTooltip => 'Edit Archival Record';
  @override String get fileClosurePrintTooltip => 'Print Closure Certificate';
  @override String get fileClosureDeleteTooltip => 'Delete Closure Record (Soft Delete)';
  @override String get fileClosureDialogTitle => 'Issue Final Shipment Closure & Archival Certificate';
  @override String get fileClosureSelectImportFile => 'Select Import File for Final Closure *';
  @override String get fileClosureSelectImportFileHint => 'Search import file by code or company name...';
  @override String get fileClosureSelectImportFileValidator => 'Please select an import file';
  @override String get fileClosureMandatoryChecklistHeader => 'Mandatory Closure Checklist:';
  @override String get fileClosureCheck1Docs => '1️⃣ Receipt of Original Documents & Electronic Transfer (CargoX)';
  @override String get fileClosureCheck2Customs => '2️⃣ Customs Clearance Completion, Duty Payment & Form 46';
  @override String get fileClosureCheck3Warehouse => '3️⃣ Goods Receipt in Warehouses & GRN Issuance';
  @override String get fileClosureCheck4LandedCost => '4️⃣ Financial Settlement, Expense Allocation & Landed Cost';
  @override String get fileClosureCheck5Tasks => '5️⃣ Closure of All Shipment Operational Tasks & Alerts';
  @override String get fileClosureAuditorNameLabel => 'Auditor in Charge Name *';
  @override String get fileClosureAuditorNameValidator => 'Auditor name is required';
  @override String get fileClosureVaultLocationLabel => 'Digital Archive Vault Location *';
  @override String get fileClosureArchivalNotesLabel => 'Archival & Audit Notes';
  @override String get fileClosureLiveReloadBtn => 'Live Reload 🔄';
  @override String get fileClosureResetFormBtn => 'Reset & Start New 🔄';
  @override String get fileClosureCertifySubmitBtn => 'Certify Final Closure & Archival ✅';
  @override String get fileClosureChecklistIncompleteWarning => 'Warning: All 5 checklist items must be verified to finalize file closure.';
  @override String fileClosureSaveError(String error) => 'Error during file closure and archival: $error';
  @override String get fileClosureCopyFieldTooltip => 'Copy field value';
  @override String get fileClosureExportTsvBtn => 'Export Archived Files (TSV)';
  @override String get fileClosureExportTsvSuccess => 'Archived files registry copied to clipboard as TSV table successfully';
  @override String get fileClosureCopyCertTsvBtn => 'Copy Certificate Data';
  @override String get fileClosureCopyCertSuccess => 'Closure and archival certificate data copied to clipboard successfully';
  @override String fileClosurePrintSuccess(String code) => 'Official closure and archival certificate for $code copied to clipboard successfully';
  @override String fileClosureDraftSavedSuccess(String pct, int completed) => 'Draft progress saved successfully ($pct% - $completed/5 tasks)';
  @override String get fileClosureCertifiedSuccess => 'Final Closure & Archival Certified Successfully!';
  @override String get fileClosureChecklistCompletionLabel => 'Overall Checklist Completion:';
  @override String get fileClosureSaveDraftTip => '💡 You can use "Save Draft" to save intermediate progress and complete later.';
  @override String get fileClosureSaveDraftBtn => 'Save Draft 💾';
  @override String get fileClosureColClosureCode => 'Closure Code';
  @override String get fileClosureColImportFile => 'Import File';
  @override String get fileClosureColArchiveVault => 'Archive Vault';
  @override String get fileClosureColAuditor => 'Auditor';
  @override String get fileClosureColClosedDate => 'Closure Date';
  @override String get fileClosureColDocsVerified => 'Original Documents';
  @override String get fileClosureColCustomsCleared => 'Customs Cleared';
  @override String get fileClosureColWarehouseReceived => 'Warehouse Received';
  @override String get fileClosureColLandedCostSettled => 'Landed Cost Settled';
  @override String get fileClosureColTasksClosed => 'Tasks Closed';
  @override String get fileClosureColNotes => 'Archival Notes';

  // Reopen Shipment Dialog
  @override String reopenShipmentDialogTitle(String code) => 'Reopen & Reactivate Shipment ($code)';
  @override String reopenShipmentRestoredPhase(String phase) => 'Target Phase for Reactivation: $phase';
  @override String get reopenShipmentNotice => 'Note: Closure status will be cancelled and shipment status will be set to Active, restoring it with identical data to its previous operational phase.';
  @override String get reopenShipmentReasonLabel => '* Reactivation Reason & Detailed Notes';
  @override String get reopenShipmentReasonHint => 'Write the reason for resuming and reopening this closed shipment...';
  @override String get reopenShipmentReasonValidatorEmpty => 'Please enter the reason for reopening the shipment.';
  @override String get reopenShipmentReasonValidatorMin => 'Reopening reason must be at least 3 characters.';
  @override String reopenShipmentSuccessSnack(String code, String phase) => 'Successfully reopened shipment ($code) and restored to ($phase)!';
  @override String reopenShipmentErrorSnack(String err) => 'Error while reopening shipment: $err';
  @override String get reopenShipmentConfirmBtn => 'Confirm Reopening & Activation';

  // ---------------------------------------------------------------------------
  // Screen 31: Projects & Cost Centers
  // ---------------------------------------------------------------------------
  @override String get projectsScreenTitle => 'Import Projects & Cost Centers';
  @override String get projectsScreenSubtitle => 'Starting reference for multi-shipment and multi-company import operations';
  @override String get createNewProjectBtn => 'Create New Project';
  @override String get projectsSearchHint => 'Search project code, name, owner...';
  @override String projectsFetchError(String error) => 'Server connection error fetching projects:\n$error';
  @override String get noProjectsFound => 'No import projects found.';
  @override String get projectCodeCol => 'Project Code';
  @override String get projectNameAndOwnerCol => 'Project Name & Owner';
  @override String get companyAndSupplierCol => 'Import Company & Supplier';
  @override String get typeAndCategoryCol => 'Type & Category';
  @override String get budgetUsdCol => 'Budget (USD)';
  @override String get capabilitiesCol => 'Capabilities';
  @override String projectOwnerLabel(String owner) => 'Owner: $owner';
  @override String projectCompanyFallback(int id) => 'Company #$id';
  @override String projectSupplierFallback(int id) => 'Supplier #$id';
  @override String projectSupplierLabel(String supplier) => 'Supplier: $supplier';
  @override String get capMultiShipment => 'Multi-Shipment';
  @override String get capMultiCompany => 'Multi-Company';
  @override String projectPrintSnack(String name, String code) => 'Printing project & cost center details: $name ($code)';
  @override String get confirmActionTitle => 'Confirm Action';
  @override String confirmDeactivateProject(String name) => 'Are you sure you want to deactivate project ($name)?';
  @override String confirmActivateProject(String name) => 'Are you sure you want to reactivate project ($name)?';
  @override String get deactivateBtn => 'Deactivate';
  @override String get activateBtn => 'Activate';
  @override String get deactivateProjectTooltip => 'Deactivate Project';
  @override String get activateProjectTooltip => 'Reactivate Project';
  @override String get createProjectDialogTitle => 'Create New Import Project';
  @override String editProjectDialogTitle(String code) => 'Edit Project ($code)';
  @override String get projectPrerequisitesMissing => 'Please ensure Import Companies, Suppliers, and Incoterms are seeded first.';
  @override String get projectNameLabel => 'Project Name *';
  @override String get projectNameHint => 'e.g. Sokhna Solar Power Expansion Phase 1';
  @override String get projectOwnerLabelField => 'Project Owner / Manager *';
  @override String get projectOwnerHint => 'e.g. Eng. Hassan Mahmoud';
  @override String get importingCompaniesFieldLabel => 'Importing Companies *';
  @override String get primarySupplierLabel => 'Primary Supplier *';
  @override String get defaultIncotermLabel => 'Default Incoterm *';
  @override String get importTypeLabel => 'Import Type *';
  @override String get priorityLabel => 'Priority *';
  @override String get projectStatusLabel => 'Project Status *';
  @override String get allowedShipmentCategoriesLabel => 'Allowed Shipment Categories *';
  @override String get estTotalBudgetUsdLabel => 'Est. Total Budget (USD)';
  @override String get estTotalBudgetUsdHint => 'e.g. 500000';
  @override String get targetEndDateLabel => 'Target End Date';
  @override String get targetEndDateHint => 'YYYY-MM-DD';
  @override String get targetEndDateCol => 'Target End Date';
  @override String get allowMultiShipmentTitle => 'Allow Multi-Shipment';
  @override String get allowMultiShipmentSubtitle => 'Allows project procurement across multiple shipments and customs declarations';
  @override String get allowMultiCompanyTitle => 'Allow Multi-Company';
  @override String get allowMultiCompanySubtitle => 'Allows working with multiple brokers, shipping lines, and secondary suppliers';
  @override String get projectNotesLabel => 'Project Notes & Description';
  @override String get selectAtLeastOneCompanyError => 'Please select at least one importing company.';
  @override String get selectAtLeastOneCategoryError => 'Please select at least one shipment category.';
  @override String get createProjectSubmitBtn => 'Create Project';
  @override String get saveChangesSubmitBtn => 'Save Changes';
  @override String get statusOnHold => 'On Hold';
  @override String get priorityUrgent => 'Urgent / Critical';
  @override String get importTypeDirectCommercial => 'Direct Commercial';
  @override String get importTypeFreeZone => 'Free Zone';
  @override String get importTypeTemporaryRelease => 'Temporary Release';
  @override String get importTypeDrawback => 'Drawback';
  @override String get importTypeProjectEquipment => 'Project Equipment';
  @override String get categoryFclContainer => 'FCL Container';
  @override String get categoryLclBreakbulk => 'LCL Breakbulk';
  @override String get categoryAirFreight => 'Air Freight';
  @override String get categoryBulkCargo => 'Bulk Cargo';
  @override String get categoryMultimodal => 'Multimodal';
  @override String get projectsCopyFieldTooltip => 'Copy data';
  @override String get projectsExportTsvBtn => 'Export Projects (TSV)';
  @override String get projectsExportTsvSuccess => 'Projects table copied to clipboard successfully';
  @override String get projectCopySummaryBtn => 'Copy Project Summary';
  @override String get projectCopySummarySuccess => 'Project summary copied to clipboard successfully';
  @override String get projectBudgetNotSet => 'Not set';
  @override String get projectIncotermFallback => 'Incoterm';
  @override String get projectColActive => 'Active Status';
  @override String get projectColShipmentCategories => 'Shipment Categories';
  @override String get projectActiveYes => 'Active';
  @override String get projectActiveNo => 'Inactive';
  @override String get projectMultiShipmentYes => 'Yes';
  @override String get projectMultiShipmentNo => 'No';
  @override String get projectMultiCompanyYes => 'Yes';
  @override String get projectMultiCompanyNo => 'No';
  @override String get projectNotesFallback => 'No notes';
  @override String get projectsToolbarTitle => 'Projects & Cost Centers';

  // ── Screen 32: Egyptian Import Companies ──────────────────────────────────
  @override String get importCompaniesScreenTitle => 'Egyptian Import Companies';
  @override String get importCompaniesScreenSubtitle => 'Manage Egyptian Importers, Registration IDs, Active Status & Expiry Rules';
  @override String get includeDeactivatedLabel => 'Include Deactivated:';
  @override String get addImporterCompanyBtn => 'Add Importer Company';
  @override String get searchImporterHint => 'Search by importer name, registration number, or VAT ID...';
  @override String importersFetchError(String error) => 'Server connection error fetching import companies:\n$error';
  @override String get retryConnectionBtn => 'Retry Connection';
  @override String get noImportCompaniesFound => 'No import companies found.';
  @override String get statusActive => 'Active';
  @override String get statusInactive => 'Inactive';
  @override String importerRowMeta(String importerId, String vatId, String regNumber) => 'Importer ID: $importerId | VAT: $vatId | Reg #: $regNumber';
  @override String get badgeImportId => 'Import ID';
  @override String get badgeVatExpiry => 'VAT Expiry';
  @override String get badgeComReg => 'Com. Reg';
  @override String get expiryExpired => 'Expired';
  @override String expiryDaysLeft(int days) => '$days days left';
  @override String expiryValidDays(int days) => 'Valid ($days d)';
  @override String confirmDeactivateCompany(String name) => 'Are you sure you want to deactivate company ($name)?';
  @override String confirmActivateCompany(String name) => 'Are you sure you want to reactivate company ($name)?';
  @override String get deactivateCompanyTooltip => 'Deactivate Company';
  @override String get activateCompanyTooltip => 'Reactivate Company';
  @override String get editImporterCompanyTitle => 'Edit Egyptian Import Company';
  @override String get addImporterCompanyTitle => 'Add Egyptian Import Company';
  @override String get closeDialogTooltip => 'Close Dialog';
  @override String get companyNameLabel => 'Company Name *';
  @override String get companyNameHint => 'e.g. Pharaohs Import & Export LLC';
  @override String get addressLabel => 'Address *';
  @override String get addressHint => 'e.g. 12 Ramses St, Cairo';
  @override String get countryLabel => 'Country *';
  @override String get importerCardIdLabel => 'Importer Card ID (9 digits) *';
  @override String get importerCardIdHint => 'e.g. 528153439';
  @override String get importerCardExpiryLabel => 'Importer Card Expiry Date *';
  @override String get vatRegIdLabel => 'VAT Registration ID (9 digits) *';
  @override String get vatRegIdHint => 'e.g. 528153439';
  @override String get vatRegExpiryLabel => 'VAT Registration Expiry Date *';
  @override String get commercialRegNumLabel => 'Commercial Reg # (15 digits) *';
  @override String get commercialRegNumHint => 'e.g. 100200000070828';
  @override String get commercialRegExpiryLabel => 'Commercial Reg Expiry Date *';
  @override String get phoneNumberLabel => 'Phone Number';
  @override String get phoneNumberHint => 'e.g. +20 100 000 0000';
  @override String get cancelAndCloseBtn => 'Cancel & Close ✕';
  @override String get updateCompanyBtn => 'Update Company';
  @override String get saveCompanyBtn => 'Save Importer Company';
  @override String get diffCompanyName => 'Importer Company Name';
  @override String get diffImporterCardId => 'Importer Card ID';
  @override String get diffImporterCardExpiry => 'Importer Card Expiry Date';
  @override String get diffVatId => 'VAT Registration ID';
  @override String get diffCommercialReg => 'Commercial Registration #';
  @override String get diffAddress => 'Address';
  @override String get diffPhone => 'Phone Number';
  @override String get diffConfirmCompanyTitle => 'Review and Confirm Importer Company Changes';
  @override String get importerProfileSubtitle => 'Egyptian Importer Profile & Regulatory Licences';
  @override String get officialRegistrationsHeader => 'Official Registrations & Licences';
  @override String get importerCardIdRowLabel => 'Importer Card ID';
  @override String get vatTaxIdRowLabel => 'VAT / Tax Registration ID';
  @override String get commercialRegRowLabel => 'Commercial Registration Number';
  @override String expiryEndingSoon(int days) => 'Expiring Soon ($days days)';
  @override String expiryValidDaysRemaining(int days) => 'Valid ($days days remaining)';
  @override String expiryDateLabel(String date) => 'Expiry: $date';
  @override String copiedToClipboard(String value) => 'Copied $value to clipboard';
  @override String get locationAndContactHeader => 'Location & Contact Information';
  @override String get countryRowLabel => 'Country';
  @override String get egyptCountryFallback => 'Egypt';
  @override String get addressRowLabel => 'Address';
  @override String get phoneRowLabel => 'Phone';
  @override String get emailRowLabel => 'Email';
  @override String get administrativeNotesHeader => 'Administrative Notes';
  @override String get printSavePdfBtn => 'Print / Save PDF 🖨️';
  @override String get downloadExcelBtn => 'Download EXCEL 📊';
  @override String excelSavedSuccess(String path) => 'Excel file saved successfully: $path';
  @override String get whatsappShareBtn => 'WhatsApp Share 💬';
  @override String get emailShareBtn => 'Email Share ✉️';
  @override String get whatsappPreviewTitle => 'WhatsApp Summary Preview';
  @override String get copyWhatsappTextBtn => 'Copy WhatsApp Text 📋';
  @override String get whatsappCopiedSuccess => 'WhatsApp text copied to clipboard successfully!';
  @override String get emailPreviewTitle => 'Email Template Preview';
  @override String emailSubjectPrefix(String subject) => 'Subject: $subject';
  @override String get copyEmailTextBtn => 'Copy Email Text & Subject 📋';
  @override String get emailCopiedSuccess => 'Email text and subject copied to clipboard successfully!';
  @override String get importCompaniesCopyFieldTooltip => 'Copy data to clipboard';
  @override String get importCompaniesExportTsvBtn => 'Export Importers (TSV)';
  @override String get importCompaniesExportTsvSuccess => 'Import companies table copied to clipboard successfully';
  @override String get importCompanyCopySummaryBtn => 'Copy Importer Summary';
  @override String get importCompanyCopySummarySuccess => 'Importer summary copied to clipboard successfully';
  @override String get importCompaniesTsvHeaderCode => 'Company ID';
  @override String get importCompaniesTsvHeaderName => 'Company Name';
  @override String get importCompaniesTsvHeaderImporterCard => 'Importer Card ID';
  @override String get importCompaniesTsvHeaderImporterCardExpiry => 'Importer Card Expiry Date';
  @override String get importCompaniesTsvHeaderVatId => 'VAT Registration ID';
  @override String get importCompaniesTsvHeaderVatExpiry => 'VAT Registration Expiry Date';
  @override String get importCompaniesTsvHeaderComReg => 'Commercial Reg #';
  @override String get importCompaniesTsvHeaderComRegExpiry => 'Commercial Reg Expiry Date';
  @override String get importCompaniesTsvHeaderCountry => 'Country';
  @override String get importCompaniesTsvHeaderAddress => 'Address';
  @override String get importCompaniesTsvHeaderPhone => 'Phone';
  @override String get importCompaniesTsvHeaderStatus => 'Status';
  @override String get importCompaniesTsvHeaderNotes => 'Notes';
  @override String get importerCardIdLabelShort => 'Importer Card';
  @override String get vatTaxIdLabelShort => 'VAT Reg ID';
  @override String get commercialRegLabelShort => 'Com. Reg #';

  // ── Screen 33: Foreign Suppliers ──
  @override String get suppliersScreenTitle => 'Foreign Suppliers Directory';
  @override String get suppliersScreenSubtitle => 'Manage Exporter Profile, Foreign Registration ID, CargoX / Nafeza ID & Origin Country';
  @override String get aiExtractorAndCodingBtn => '⚡ AI Extractor & Coding';
  @override String get addForeignSupplierBtn => 'Add Foreign Supplier';
  @override String get searchSuppliersHint => 'Search by Supplier Name, Code, CargoX ID, Registration #, or Country...';
  @override String get showInactiveSuppliersLabel => 'Show Inactive:';
  @override String suppliersFetchError(String error) => 'Server connection error fetching foreign suppliers:\n$error';
  @override String get noSuppliersFound => 'No foreign suppliers found.';
  @override String supplierRowMeta(String exporterId, String? cargoxId, String address, String? brands) {
    final cx = cargoxId != null && cargoxId.isNotEmpty ? ' | CargoX ID: $cargoxId' : '';
    final br = brands != null && brands.isNotEmpty ? ' | Brands: $brands' : '';
    return 'Exporter ID: $exporterId$cx | Address: $address$br';
  }
  @override String supplierTypeAndReg(String type, String regType) => 'Type: $type ($regType)';
  @override String confirmDeactivateSupplier(String name) => 'Are you sure you want to deactivate supplier ($name)?';
  @override String confirmActivateSupplier(String name) => 'Are you sure you want to reactivate supplier ($name)?';
  @override String get deactivateSupplierTooltip => 'Deactivate Supplier';
  @override String get activateSupplierTooltip => 'Reactivate Supplier';
  @override String get editSupplierDialogTitle => 'Edit Foreign Exporter & Supplier';
  @override String get addSupplierDialogTitle => 'Add Foreign Exporter & Supplier';
  @override String get supplierCompanyNameLabel => 'Company Name *';
  @override String get supplierCompanyNameHint => 'e.g. G.I. Industrial Holding S.p.A.';
  @override String get supplierTypeLabel => 'Supplier Type *';
  @override String get supplierTypeManufacturer => 'Manufacturer';
  @override String get supplierTypeTrader => 'Foreign Supplier / Trader';
  @override String get supplierTypeAgent => 'Authorized Agent / Distributor';
  @override String get supplierTypeExporter => 'Exporter';
  @override String get supplierRegTypeLabel => 'Registration Type *';
  @override String get regTypeFactory => 'Factory Registration';
  @override String get regTypeNafezaExporter => 'Foreign Exporter Number (Nafeza)';
  @override String get regTypeCompanyReg => 'Company Registration Number';
  @override String get regTypeVat => 'VAT Number';
  @override String get regTypeTax => 'Tax Number';
  @override String get regTypeCommercial => 'Commercial Register';
  @override String get supplierForeignExporterIdLabel => 'Foreign Exporter ID (Nafeza) *';
  @override String get foreignExporterIdHint => 'e.g. EXP-CN-998877';
  @override String get cargoxIdLabel => 'CargoX Platform Registered ID';
  @override String get cargoxIdHint => 'e.g. CX-9988776655';
  @override String get supplierCountryLabel => 'Country *';
  @override String get supplierCountryHint => 'Italy, China, Germany, etc.';
  @override String get supplierCountryCodeLabel => 'Country Code (ISO 2-letter) *';
  @override String get supplierCountryCodeHint => 'IT, CN, DE, US, etc.';
  @override String get supplierAddressLabel => 'Full Address *';
  @override String get supplierAddressHint => 'e.g. Via G. Agnelli, 7 - 33053 Latisana (UD) - Italy';
  @override String get supplierEmailLabel => 'Primary Email';
  @override String get supplierEmailHint => 'export@supplier.com';
  @override String get supplierSecondaryEmailLabel => 'Secondary / Additional Email';
  @override String get supplierSecondaryEmailHint => 'sales@supplier.com';
  @override String get supplierPhoneLabel => 'Telephone Number';
  @override String get supplierPhoneHint => '+39 0432 823011';
  @override String get supplierMobileLabel => 'Mobile Number';
  @override String get supplierMobileHint => '+39 335 1234567';
  @override String get supplierFaxLabel => 'Fax Number';
  @override String get supplierFaxHint => '+39 0432 773855';
  @override String get supplierWebsiteLabel => 'Website URL';
  @override String get supplierWebsiteHint => 'www.gind.it';
  @override String get beneficiaryBankDetailsHeader => 'Beneficiary Bank & SWIFT Details:';
  @override String get beneficiaryBankNameLabel => 'Bank Name';
  @override String get beneficiaryBankNameHint => 'e.g. Bank of China, Deutsche Bank';
  @override String get beneficiarySwiftCodeLabel => 'SWIFT Code';
  @override String get beneficiarySwiftCodeHint => 'e.g. BKCHCN2SXXX';
  @override String get beneficiaryAccountNumberLabel => 'Account No.';
  @override String get beneficiaryAccountNumberHint => 'e.g. 1234567890';
  @override String get beneficiaryIbanLabel => 'IBAN';
  @override String get beneficiaryIbanHint => 'e.g. CN980100987654321 / IT28W...';
  @override String get complianceAndCertsHeader => 'Compliance & Certifications:';
  @override String get isoCertifiedCheck => 'ISO Certified';
  @override String get decree43Check => 'Registered under Decree 43 / GOEIC';
  @override String get whiteListCheck => 'White List Registered Exporter';
  @override String get brandsProductLinesLabel => 'Brands / Product Lines';
  @override String get brandsProductLinesHint => 'e.g. Clint, Novair, ProPower';
  @override String get supplierNotesLabel => 'Notes';
  @override String get supplierNotesHint => 'Any additional supplier details...';
  @override String get updateSupplierBtn => 'Update Supplier';
  @override String get saveSupplierBtn => 'Save Foreign Supplier';
  @override String get diffSupplierCompanyName => 'Supplier Company Name';
  @override String get diffSupplierType => 'Supplier Type';
  @override String get diffSupplierRegType => 'Registration Type';
  @override String get diffForeignExporterId => 'Foreign Exporter ID (Nafeza)';
  @override String get diffCargoXId => 'CargoX Platform ID';
  @override String get diffSupplierCountry => 'Supplier Country';
  @override String get diffSupplierEmail => 'Email Address';
  @override String get diffSupplierPhone => 'Phone Number';
  @override String get diffConfirmSupplierTitle => 'Review and Confirm Supplier Changes';
  @override String get supplierProfileSubtitle => 'Foreign Exporter Profile & Regulatory Registration';
  @override String get nafezaCargoXComplianceHeader => 'Nafeza, CargoX & Exporter Identifiers';
  @override String get foreignExporterIdFieldLabel => 'Foreign Exporter ID (Nafeza)';
  @override String get cargoxPlatformIdFieldLabel => 'CargoX Platform ID';
  @override String get notRegisteredCargoX => 'Not Registered';
  @override String get supplierTypeFieldLabel => 'Supplier Type';
  @override String get supplierOriginCountryFieldLabel => 'Country & Origin';
  @override String get complianceCertificatesLabel => 'Compliance Certifications:';
  @override String get isoCertifiedTag => 'ISO Certified';
  @override String get decree43Tag => 'Decree 43';
  @override String get whiteListTag => 'White List';
  @override String get bankingSwiftSectionHeader => 'Beneficiary Banking & SWIFT Details';
  @override String get beneficiaryBankFieldLabel => 'Beneficiary Bank Name';
  @override String get swiftCodeFieldLabel => 'SWIFT Code';
  @override String get accountNumberFieldLabel => 'Account Number';
  @override String get ibanFieldLabel => 'IBAN';
  @override String get contactAddressBrandsHeader => 'Contact, Address & Product Brands';
  @override String get fullAddressFieldLabel => 'Full Address';
  @override String get phoneFieldLabel => 'Phone';
  @override String get emailFieldLabel => 'Email';
  @override String get websiteFieldLabel => 'Website';
  @override String get brandsFieldLabel => 'Brands & Products';
  @override String get additionalNotesHeader => 'Additional Administrative Notes';
  @override String get suppliersCopyFieldTooltip => 'Copy data';
  @override String get suppliersExportTsvBtn => 'Export Suppliers (TSV)';
  @override String get suppliersExportTsvSuccess => 'Suppliers TSV data copied successfully';
  @override String get supplierCopySummaryBtn => 'Copy Supplier Summary';
  @override String get supplierCopySummarySuccess => 'Supplier summary copied to clipboard successfully';
  @override String get supplierCodeBadgeLabel => 'Supplier Code';
  @override String get routeIntelligenceBtnTooltip => 'Route Intelligence & Negotiating History Card';
  @override String get goeicVerificationBtnTooltip => 'GOEIC Compliance & Decree 43 Verification';
  @override String get supplierTsvHeaderCode => 'Supplier Code';
  @override String get supplierTsvHeaderName => 'Company Name';
  @override String get supplierTsvHeaderType => 'Supplier Type';
  @override String get supplierTsvHeaderRegType => 'Registration Type';
  @override String get supplierTsvHeaderForeignExporterId => 'Foreign Exporter ID';
  @override String get supplierTsvHeaderCargoxId => 'CargoX ID';
  @override String get supplierTsvHeaderCountry => 'Country';
  @override String get supplierTsvHeaderCountryCode => 'Country Code';
  @override String get supplierTsvHeaderAddress => 'Address';
  @override String get supplierTsvHeaderPhone => 'Phone';
  @override String get supplierTsvHeaderEmail => 'Email';
  @override String get supplierTsvHeaderBankName => 'Beneficiary Bank';
  @override String get supplierTsvHeaderSwiftCode => 'SWIFT Code';
  @override String get supplierTsvHeaderIban => 'IBAN';
  @override String get supplierTsvHeaderStatus => 'Status';
  @override String get supplierTsvHeaderBrands => 'Brands & Products';
  @override String get supplierTsvHeaderNotes => 'Notes';
  @override String get routeIntelligenceDialogTitle => 'Route Intelligence & Negotiating History Card';
  @override String get routeIntelligenceAiRecommendationTitle => 'AI Recommendation for Approval & Negotiation:';
  @override String get routeIntelligenceAvgCycleDays => 'Average Import Cycle';
  @override String get routeIntelligenceRecentFreight => 'Recent Freight Cost';
  @override String get routeIntelligenceRecentClearance => 'Recent Clearance Fee';
  @override String get routeIntelligenceNotRecorded => 'Not Recorded';
  @override String get routeIntelligenceItemPricesTitle => 'Price History for Items from this Supplier:';
  @override String get routeIntelligenceNoPurchasesYet => 'No past purchases recorded for this supplier yet.';
  @override String get routeIntelligenceItemCodeCol => 'Item Code';
  @override String get routeIntelligenceItemDescCol => 'Description';
  @override String get routeIntelligenceLastUnitPriceCol => 'Last Unit Price';
  @override String get routeIntelligenceOrderCodeCol => 'Purchase Order';
  @override String get routeIntelligenceNotesTitle => 'Operational Notes & Historical Warnings:';
  @override String get routeIntelligenceDaysSuffix => 'days';
  @override String get routeIntelligenceCurrencyEgp => 'EGP';
  @override String get routeIntelligencePriceChangeCol => 'Price Change %';
  @override String get routeIntelligenceDossierCopied => 'Intelligence dossier copied to clipboard';
  @override String get routeIntelligenceCopyDossierBtn => 'Copy Dossier';
  @override String get routeIntelligenceAverageTransitDays => 'Avg Transit Time';
  @override String get smartEmailListenerBtnTooltip => 'Smart Email Listener & Arrival Notice Parser';
  @override String get smartEmailListenerDialogTitle => 'Smart Email Listener & Arrival Notice Parser';
  @override String get smartEmailListenerSenderLabel => 'Sender Email';
  @override String get smartEmailListenerSubjectLabel => 'Email Subject';
  @override String get smartEmailListenerBodyLabel => 'Raw Email Content (Paste Arrival Notice)';
  @override String get smartEmailListenerPreviewBtn => 'Analyze Email Content';
  @override String get smartEmailListenerProcessBtn => 'Process & Update ETA / Create Task';
  @override String get smartEmailListenerParsedCardTitle => 'Extracted Shipment Details';
  @override String get smartEmailListenerLogsTabTitle => 'Inbound Email Logs';
  @override String get smartEmailListenerLoadSampleBtn => 'Load Sample Notice';
  @override String get smartEmailListenerBlNumberLabel => 'Bill of Lading (B/L)';
  @override String get smartEmailListenerEtaLabel => 'Estimated Arrival (ETA)';
  @override String get smartEmailListenerVesselLabel => 'Vessel Name';
  @override String get smartEmailListenerVoyageLabel => 'Voyage';
  @override String get smartEmailListenerContainersLabel => 'Containers';
  @override String get smartEmailListenerMatchedFileLabel => 'Matched Import File';
  @override String get smartEmailListenerTaskCreatedLabel => 'Delivery Order Task Created';
  @override String get formalLetterDialogTitle => 'AI Formal Corporate Letter Drafting';
  @override String get formalLetterTemplateLabel => 'Select Letter Template';
  @override String get formalLetterRecipientLabel => 'Recipient Entity';
  @override String get formalLetterBankNameLabel => 'Bank Name';
  @override String get formalLetterBankBranchLabel => 'Bank Branch';
  @override String get formalLetterBrokerNameLabel => 'Customs Broker Name';
  @override String get formalLetterBrokerLicenseLabel => 'Broker License Number';
  @override String get formalLetterExtensionDaysLabel => 'Requested Extension (Days)';
  @override String get formalLetterCustomNotesLabel => 'Special Notes & Undertakings';
  @override String get formalLetterGenerateBtn => 'Draft Formal Letter';
  @override String get formalLetterCopyBtn => 'Copy Full Letter';
  @override String get formalLetterExportTxtBtn => 'Export as Text File';
  @override String get formalLetterLetterheadHint => 'Note: Print on official company letterhead signed and stamped.';
  @override String get formalLetterSelectShipmentPrompt => 'Please select the target shipment file for the letter:';
  @override String get goeicHubDialogTitle => 'GOEIC Compliance & Verification Hub';
  @override String get goeicHsCodeFieldLabel => 'HS Tariff Code';
  @override String get goeicCoiCertificateCheckbox => 'Certified Pre-Shipment Inspection Certificate';
  @override String get goeicCheckComplianceBtn => 'Check Regulatory Compliance';
  @override String get goeicInspectionAgencyFieldLabel => 'International Inspection Agency';
  @override String get goeicCoiNumberFieldLabel => 'Inspection Certificate Number';
  @override String get goeicDecree43MandatoryYes => 'Yes (Mandatory)';
  @override String get goeicDecree43MandatoryNo => 'No';
  @override String get goeicFactoryRegisteredYes => 'Registered & Approved';
  @override String get goeicFactoryRegisteredNo => 'Not Registered';
  @override String get goeicFactoryNotAvailable => 'N/A';
  @override String get goeicVerdictBlocked => 'Blocked: Decree 43 Violation (Factory not registered on whitelist)';
  @override String get goeicVerdictPending => 'Pending: Factory is registered, but Certificate of Inspection (COI) required';
  @override String get goeicVerdictApproved => 'Cleared for Shipping: Shipment and factory satisfy all regulatory requirements';
  @override String get goeicRecommendedActionLabel => 'Recommended Action:';
  @override String get goeicSubjectToDecree43 => 'Subject to Decree 43:';
  @override String get goeicFactoryRegistrationStatus => 'Factory GOEIC Status:';

  // ── Screen 34: External Partners & Service Providers (Partners & Banks) ──
  @override String get partnersScreenTitle => 'External Partners & Service Providers';
  @override String get partnersScreenSubtitle => 'Manage Commercial Banks, Shipping Lines, Customs Brokers, Freight Forwarders & Logistics Partners';
  @override String get addExternalPartnerBtn => 'Add External Partner';
  @override String get partnerCatAll => 'All';
  @override String get partnerCatBank => 'Bank';
  @override String get partnerCatShippingLine => 'Shipping Line';
  @override String get partnerCatCustomsBroker => 'Customs Broker';
  @override String get partnerCatFreightForwarder => 'Freight Forwarder';
  @override String get partnerCatInlandTransport => 'Inland Transport';
  @override String get partnerCatInspectionAgency => 'Inspection Agency';
  @override String get partnerCatInsuranceCompany => 'Insurance Company';
  @override String get partnersCopyFieldTooltip => 'Copy data';
  @override String get partnersExportTsvBtn => 'Export Partners (TSV) 📊';
  @override String get partnersExportTsvSuccess => 'Partners data exported to clipboard (TSV)';
  @override String get partnerCopySummaryBtn => 'Copy Partner Summary';
  @override String get partnerCopySummarySuccess => 'Partner summary copied to clipboard';
  @override String get partnerCodeBadgeLabel => 'Partner Code: ';
  @override String get partnerScorecardBtn => 'Performance Scorecard';
  @override String get partnerScorecardTooltip => 'Partner SLA Performance Scorecard';
  @override String get scorecardDialogTitle => 'Logistics Partner Performance Scorecard';
  @override String scorecardPartnerSubtitle(String name, String type) => 'Partner: $name  •  Service Type: $type';
  @override String scorecardTierLabel(String tier) => 'Certified Tier: $tier';
  @override String scorecardTotalJobs(int count) => 'Total Evaluated Operations: $count historical jobs';
  @override String get scorecardKpiHeader => 'Operational KPI Metrics:';
  @override String get scorecardAvgClearanceDays => 'Avg Clearance Turnaround (Days)';
  @override String get scorecardGreenChannelRate => 'Green Channel Rate (%)';
  @override String get scorecardSlaAdherenceRate => 'SLA Adherence Rate (%)';
  @override String get scorecardAvgArrivalDelayDays => 'Avg Arrival Delay (Days)';
  @override String get scorecardScheduleReliability => 'Schedule Reliability (%)';
  @override String get scorecardStrengthsHeader => 'Strengths & Excellence:';
  @override String get scorecardImprovementsHeader => 'Improvement Areas & Audit Notes:';
  @override String get supplierScorecardBtnTooltip => 'Supplier Performance Scorecard & Quality KPIs';
  @override String get supplierScorecardTitle => 'Foreign Supplier Performance & Reliability Scorecard';
  @override String supplierScorecardSubtitle(String name, String country) => 'Supplier: $name • Country: $country';
  @override String get supplierScorecardCrdRate => 'Cargo Readiness Date (CRD) Adherence';
  @override String get supplierScorecardDocAccuracy => 'Shipping Documents Accuracy Rate';
  @override String get supplierScorecardFulfillmentRate => 'Purchase Order Fulfillment Rate';
  @override String supplierScorecardTotalOrders(int count) => 'Total Completed Purchase Orders: $count';
  @override String get supplierScorecardCopySuccess => 'Supplier scorecard summary copied to clipboard';
  @override String get partnersTsvHeaderCode => 'Partner Code';
  @override String get partnersTsvHeaderName => 'Partner Name';
  @override String get partnersTsvHeaderCategories => 'Categories';
  @override String get partnersTsvHeaderCountry => 'Country';
  @override String get partnersTsvHeaderAddress => 'Address';
  @override String get partnersTsvHeaderPhone => 'Phone';
  @override String get partnersTsvHeaderMobile => 'Mobile';
  @override String get partnersTsvHeaderFax => 'Fax';
  @override String get partnersTsvHeaderEmail => 'Email';
  @override String get partnersTsvHeaderSecondaryEmail => 'Secondary Email';
  @override String get partnersTsvHeaderWebsite => 'Website';
  @override String get partnersTsvHeaderSwift => 'SWIFT Code';
  @override String get partnersTsvHeaderScac => 'SCAC Code';
  @override String get partnersTsvHeaderLicense => 'Clearance License';
  @override String get partnersTsvHeaderCommercialReg => 'Commercial Register';
  @override String get partnersTsvHeaderTaxId => 'Tax ID';
  @override String get partnersTsvHeaderStatus => 'Status';
  @override String get partnersTsvHeaderNotes => 'Notes';
  @override String get soaExportTsvBtn => 'Export Statement (TSV) 📊';
  @override String get soaExportTsvSuccess => 'Statement of account exported to clipboard (TSV)';
  @override String get soaCurrencyEgp => 'EGP';
  @override String get searchPartnersHint => 'Search by partner name, code, SWIFT, license #, tax ID, or country...';
  @override String get showInactivePartnersLabel => 'Show Inactive:';
  @override String get partnersFetchError => 'Server connection error fetching partners:\n\$error';
  @override String get noPartnersFound => 'No partners found for selected filters.';
  @override String get partnerCodeCol => 'Code';
  @override String get partnerNameAndCategoryCol => 'Partner Name & Category';
  @override String get registrationAndLicenseCol => 'Registration & License';
  @override String get contactDetailsCol => 'Contact Details';
  @override String get partnerStatusCol => 'Status';
  @override String get partnerActionsCol => 'Actions';
  @override String partnerSwiftLabel(String code) => 'SWIFT: $code';
  @override String partnerScacLabel(String code) => 'SCAC: $code';
  @override String partnerLicenseLabel(String num) => 'License: $num';
  @override String partnerRegLabel(String num) => 'Reg: $num';
  @override String partnerCountryLabel(String country) => 'Country: $country';
  @override String get noEmailLabel => 'No email';
  @override String get noPhoneLabel => 'No phone';
  @override String get partnerStatementOfAccountBtn => 'Statement of Account';
  @override String get partnerStatementOfAccountTooltip => 'Partner Statement of Account & Currency Balances';
  @override String confirmDeactivatePartner(String name) => 'Are you sure you want to deactivate partner ($name)?';
  @override String confirmActivatePartner(String name) => 'Are you sure you want to reactivate partner ($name)?';
  @override String get deactivatePartnerTooltip => 'Deactivate Partner';
  @override String get activatePartnerTooltip => 'Reactivate Partner';
  @override String get editPartnerDialogTitle => 'Edit External Partner & Bank';
  @override String get addPartnerDialogTitle => 'Add External Partner & Bank';
  @override String get partnerCategoriesLabel => 'Partner Categories (Select one or multiple) *';
  @override String get partnerNameLabel => 'Partner / Company Name *';
  @override String get partnerNameHint => 'e.g. National Bank of Egypt / Maersk Line / Cargo Logistics LLC';
  @override String get bankingDetailsHeader => 'Banking Details';
  @override String get bankSwiftCodeLabel => 'SWIFT Code *';
  @override String get bankSwiftCodeHint => 'NBEGEGXCAXXX';
  @override String get bankCodeLabel => 'Bank Code';
  @override String get bankCodeHint => 'NBE';
  @override String get branchNameLabel => 'Branch Name';
  @override String get branchNameHint => 'Main Branch, Cairo';
  @override String get shippingLineDetailsHeader => 'Shipping Line Details';
  @override String get scacCarrierCodeLabel => 'SCAC / Carrier Code *';
  @override String get scacCarrierCodeHint => 'MAEU / MSKU';
  @override String get defaultFreeDaysLabel => 'Default Free Days (Days) *';
  @override String get defaultFreeDaysHint => 'e.g. 14 or 21 days';
  @override String partnerFreeDaysBadge(int days) => '$days Free Days';
  @override String get trackingWebUrlLabel => 'Tracking Web URL';
  @override String get trackingWebUrlHint => 'https://www.maersk.com/tracking/';
  @override String get freightForwarderDetailsHeader => 'Freight Forwarder & Quotations Details';
  @override String get fiataLicenseLabel => 'FIATA License / Forwarder ID';
  @override String get fiataLicenseHint => 'e.g. FIATA-EG-7721';
  @override String get shippingModesLabel => 'Supported Shipping Modes';
  @override String get shippingModesHint => 'e.g. Sea FCL, Sea LCL, Air Freight, Land';
  @override String get supportedCurrenciesLabel => 'Supported Quotation Currencies';
  @override String get supportedCurrenciesHint => 'e.g. USD, EUR, EGP';
  @override String partnerFiataBadge(String fiata) => 'FIATA: $fiata';
  @override String get inspectionAgencyDetailsHeader => 'Inspection Agency & Accreditation Details';
  @override String get inspectionAccreditationNumLabel => 'GOIEC / ISO Accreditation Number *';
  @override String get inspectionAccreditationNumHint => 'e.g. GOIEC-EG-9001 or ISO-17020';
  @override String get inspectionScopeLabel => 'Inspection Scope & CoC/VOC Tests';
  @override String get inspectionScopeHint => 'e.g. Pre-shipment Inspection, CoC/VOC, Food, Machinery';
  @override String partnerAccreditationBadge(String num) => 'Accredited: $num';
  @override String get customsBrokerLicenseHeader => 'Customs Broker License & Authorized Ports';
  @override String get customsClearanceLicenseNumLabel => 'Customs Clearance License # *';
  @override String get customsClearanceLicenseNumHint => 'LIC-CAI-9988';
  @override String get authorizedPortsLabel => 'Authorized Clearance Ports & Terminals';
  @override String get authorizedPortsHint => 'e.g. Alexandria Port, Sokhna, Port Said, Damietta, Cairo Cargo';
  @override String partnerPortsBadge(String ports) => 'Ports: $ports';
  @override String get inlandTransportDetailsHeader => 'Inland Transport Fleet & License Details';
  @override String get transportLicenseNumLabel => 'Inland Transport License # *';
  @override String get transportLicenseNumHint => 'e.g. MOT-EG-8844 / Ministry of Transport';
  @override String get fleetTypesLabel => 'Fleet & Truck Types *';
  @override String get fleetTypesHint => 'e.g. 20/40ft Container Chassis, Lowbed, Reefer, Flatbed Jumbo';
  @override String get coverageAreasLabel => 'Coverage Scope & Operating Areas';
  @override String get coverageAreasHint => 'e.g. Alexandria, Sokhna, Port Said, Damietta, Greater Cairo';
  @override String partnerFleetBadge(String fleet) => 'Fleet: $fleet';
  @override String partnerCoverageBadge(String areas) => 'Coverage: $areas';
  @override String get insuranceDetailsHeader => 'Marine Cargo Insurance & License Details';
  @override String get insuranceLicenseNumLabel => 'FRA Insurance License # *';
  @override String get insuranceLicenseNumHint => 'e.g. FRA-INS-302 / Financial Regulatory Authority';
  @override String get insuranceCoverageTypesLabel => 'Approved Insurance Coverage Types *';
  @override String get insuranceCoverageTypesHint => 'e.g. Institute Cargo Clauses (A/B/C), All Risks, War & Strikes';
  @override String partnerInsuranceCoverageBadge(String cov) => 'Coverage: $cov';
  @override String get partnerTaxIdLabel => 'Tax Registration ID';
  @override String get partnerTaxIdHint => 'TAX-100200';
  @override String get partnerCommercialRegLabel => 'Commercial Reg #';
  @override String get partnerCommercialRegHint => 'REG-554433';
  @override String get partnerPrimaryEmailLabel => 'Primary Email';
  @override String get partnerPrimaryEmailHint => 'contact@partner.com';
  @override String get partnerSecondaryEmailLabel => 'Secondary / Additional Email';
  @override String get partnerSecondaryEmailHint => 'trade@partner.com';
  @override String get partnerPhoneLabel => 'Phone Number';
  @override String get partnerPhoneHint => '+20 2 2555 5555';
  @override String get partnerMobileLabel => 'Mobile Number';
  @override String get partnerMobileHint => '+20 100 1234567';
  @override String get partnerFaxLabel => 'Fax Number';
  @override String get partnerFaxHint => '+20 2 2577 0000';
  @override String get partnerWebsiteUrlLabel => 'Website URL';
  @override String get partnerWebsiteUrlHint => 'www.partner.com';
  @override String get partnerAddressLabel => 'Address';
  @override String get partnerAddressHint => 'Downtown, Cairo';
  @override String get partnerCountryLabelField => 'Country *';
  @override String get updatePartnerBtn => 'Update Partner';
  @override String get savePartnerBtn => 'Save External Partner';
  @override String get savingChanges => 'Saving Changes...';
  @override String get diffPartnerName => 'Partner / Provider Name';
  @override String get diffPartnerType => 'Partner Type';
  @override String get diffPartnerEmail => 'Email Address';
  @override String get diffPartnerPhone => 'Phone Number';
  @override String get diffPartnerAddress => 'Address';
  @override String get diffPartnerCountry => 'Country';
  @override String get diffConfirmPartnerTitle => 'Review and Confirm Partner Changes';
  @override String get partnerProfileTitle => 'Partner Profile & Identifiers';
  @override String get professionalLicensesSection => 'Professional Identifiers & Licenses';
  @override String get partnerSwiftCodeDetailLabel => 'SWIFT Code';
  @override String get partnerScacCodeDetailLabel => 'SCAC Code';
  @override String get clearanceLicenseDetailLabel => 'Customs Clearance License #';
  @override String get commercialRegDetailLabel => 'Commercial Register';
  @override String get taxIdDetailLabel => 'Tax ID';
  @override String get creditTermsSection => 'Credit Terms & Financial Conditions';
  @override String get paymentTermsDetailLabel => 'Payment Terms';
  @override String get creditLimitDetailLabel => 'Credit Limit';
  @override String get ratingDetailLabel => 'Rating';
  @override String get bankCodeDetailLabel => 'Bank Code';
  @override String get branchNameDetailLabel => 'Branch Name';
  @override String get contactAndAddressSection => 'Contact & Official Address';
  @override String get contactPersonDetailLabel => 'Contact Person';
  @override String get countryDetailLabel => 'Country';
  @override String get phoneMobileDetailLabel => 'Phone / Mobile';
  @override String get emailDetailLabel => 'Email';
  @override String get fullAddressDetailLabel => 'Full Address';
  @override String get websiteDetailLabel => 'Website';
  @override String get additionalNotesSection => 'Additional Notes';
  @override String get partnerStatementShortcutBtn => 'Statement of Account 📑';
  @override String get editPartnerBtn => 'Edit';
  @override String partnerSoaTitle(String name) => 'Partner Statement of Account — $name';
  @override String partnerSoaSubtitle(String type, String taxId) => 'Category: $type | Tax ID: $taxId | Multi-Currency Transactions';
  @override String get calculatingSoaMsg => 'Calculating statement of account and aggregating balances...';
  @override String soaFetchError(String error) => 'Error fetching statement of account: $error';
  @override String get noSoaDataAvailable => 'No financial data available for this partner';
  @override String get multiCurrencyBalancesHeader => 'Multi-Currency Balances Summary:';
  @override String get totalInvoicedLabel => 'Total Invoiced:';
  @override String get totalPaidLabel => 'Total Paid:';
  @override String get balanceDueLabel => 'Balance Due:';
  @override String transactionsLedgerHeader(int count) => 'Transactions & Ledger Entries ($count entries):';
  @override String invoicesCountLabel(int invoices, int payments) => 'Invoices: $invoices | Payments: $payments';
  @override String get noLedgerEntriesFound => 'No invoices or payments registered for this partner yet';
  @override String get ledgerDateCol => 'Date';
  @override String get ledgerTypeCol => 'Type';
  @override String get ledgerRefCol => 'Reference';
  @override String get ledgerImportFileCol => 'Import File';
  @override String get ledgerDescriptionCol => 'Description';
  @override String get ledgerCurrencyCol => 'Currency';
  @override String get ledgerDebitCol => 'Debit (Invoice)';
  @override String get ledgerCreditCol => 'Credit (Payment)';
  @override String get ledgerStatusCol => 'Status';
  @override String get ledgerInvoiceBadge => 'Invoice';
  @override String get ledgerPaymentBadge => 'Payment';
  @override String get soaFooterText => 'Sorour Logistics ERP — Multi-Currency Partner & Provider Accounting Module';
  @override String get closeBtn => 'Close';

  // Screen 35: Incoterms Rules (Incoterms 2020 · Cost Items · Responsibility Matrix)
  @override String get incotermsScreenTitle => 'Incoterms Rules';
  @override String get incotermsScreenSubtitle => 'Incoterms 2020 · Cost Items · Responsibility Matrix';
  @override String get incotermsTabRules => 'Incoterms';
  @override String get incotermsTabCostItems => 'Cost Items';
  @override String get incotermsTabMatrix => 'Responsibility Matrix';
  @override String get searchIncotermsHint => 'Search by code, name, or category...';
  @override String get showInactiveIncotermsLabel => 'Show Inactive:';
  @override String get addIncotermBtn => 'Add Incoterm';
  @override String get noIncotermsFound => 'No incoterms found.';
  @override String get incotermCodeCol => 'Code';
  @override String get incotermNameCol => 'Name & Details';
  @override String get incotermVersionCol => 'Version';
  @override String get incotermStatusCol => 'Status';
  @override String get incotermActionsCol => 'Actions';
  @override String printIncotermSnack(String code, String name) => 'Printing Incoterm details: $code ($name)';
  @override String confirmDeactivateIncoterm(String code) => 'Are you sure you want to deactivate Incoterm ($code)?';
  @override String confirmActivateIncoterm(String code) => 'Are you sure you want to reactivate Incoterm ($code)?';
  @override String get deactivateIncotermTooltip => 'Deactivate Incoterm';
  @override String get activateIncotermTooltip => 'Reactivate Incoterm';
  @override String get editIncotermDialogTitle => 'Edit Incoterm Rule';
  @override String get addIncotermDialogTitle => 'Add New Incoterm Rule';
  @override String get incotermCodeLabel => 'Incoterm Code (e.g. FOB, CIF, EXW) *';
  @override String get incotermFullNameLabel => 'Full Name *';
  @override String get incotermVersionLabel => 'ICC Version (e.g. Incoterms 2020)';
  @override String get incotermDescriptionLabel => 'Description & Risk Transfer Point';
  @override String get addCostItemBtn => 'Add Cost Item';
  @override String get showInactiveCostItemsLabel => 'Show Inactive:';
  @override String get noCostItemsFound => 'No cost items found.';
  @override String get costItemCodeCol => 'Code';
  @override String get costItemNameCol => 'Cost Item Name';
  @override String get costItemCategoryCol => 'Category';
  @override String get costItemStatusCol => 'Status';
  @override String get costItemActionsCol => 'Actions';
  @override String get costCategoryFreight => 'Freight & Logistics';
  @override String get costCategoryCustoms => 'Customs & Duties';
  @override String get costCategoryPort => 'Port & Terminal';
  @override String get costCategoryBank => 'Banking & Finance';
  @override String get costCategoryOther => 'Other Costs';
  @override String printCostItemSnack(String code, String name) => 'Printing cost item details: $code ($name)';
  @override String confirmDeactivateCostItem(String code) => 'Are you sure you want to deactivate cost item ($code)?';
  @override String confirmActivateCostItem(String code) => 'Are you sure you want to reactivate cost item ($code)?';
  @override String get deactivateCostItemTooltip => 'Deactivate Cost Item';
  @override String get activateCostItemTooltip => 'Reactivate Cost Item';
  @override String get editCostItemDialogTitle => 'Edit Cost Item';
  @override String get addCostItemDialogTitle => 'Add New Cost Item';
  @override String get costItemCodeLabel => 'Cost Item Code *';
  @override String get costItemNameLabel => 'Cost Item Name *';
  @override String get costCategoryLabel => 'Cost Category *';
  @override String get costItemDescriptionLabel => 'Description & Allocation Notes';
  @override String get filterByIncotermLabel => 'Filter by Incoterm:';
  @override String get allIncotermsOption => 'All Incoterms (11 Terms)';
  @override String get showingAllMatrixResponsibilities => 'Showing All Matrix Responsibilities';
  @override String get filteringResponsibilitiesForSelectedTerm => 'Filtering responsibilities for selected term';
  @override String get noMatrixDataFound => 'No responsibility data found.';
  @override String get matrixIncotermCol => 'Incoterm';
  @override String get matrixCostItemCol => 'Cost Item';
  @override String get matrixCategoryCol => 'Category';
  @override String get matrixResponsibleCol => 'Responsible Party';
  @override String get matrixIncludedCol => 'Included in Price';
  @override String get matrixNotesCol => 'Notes & Conditions';
  @override String get matrixActionsCol => 'Actions';
  @override String get partyBuyerImporter => 'Buyer / Importer';
  @override String get partySellerExporter => 'Seller / Exporter';
  @override String get partyShared => 'Shared between Parties';
  @override String get editResponsibilityTooltip => 'Edit Responsibility';
  @override String editResponsibilityDialogTitle(String code) => 'Edit Responsibility · $code';
  @override String incotermPrefix(String code) => 'Incoterm: $code';
  @override String costItemPrefix(String name, String category) => 'Cost Item: $name ($category)';
  @override String get matrixResponsiblePartyFieldLabel => 'Responsible Party *';
  @override String get includedInSellerPriceTitle => 'Included in Seller Price';
  @override String get includedInSellerPriceSubtitle => 'Does the seller cover this cost in the invoice price?';
  @override String get commentNotesLabel => 'Comment / Notes';
  @override String get commentNotesHint => 'Add specific conditions or details...';
  @override String get updatedSuccessfully => 'Updated successfully';
  @override String get incotermsCopyFieldTooltip => 'Copy field to clipboard';
  @override String get incotermsExportTsvBtn => 'Export Incoterms (TSV)';
  @override String get incotermsExportTsvSuccess => 'Incoterms data copied to clipboard (TSV)';
  @override String get incotermCopySummaryBtn => 'Copy Incoterm Summary';
  @override String get incotermCopySummarySuccess => 'Incoterm summary copied to clipboard';
  @override String get incotermCodeBadgeLabel => 'Incoterm Code: ';
  @override String get costItemsExportTsvBtn => 'Export Cost Items (TSV)';
  @override String get costItemsExportTsvSuccess => 'Cost items copied to clipboard (TSV)';
  @override String get costItemCopySummaryBtn => 'Copy Cost Item Summary';
  @override String get costItemCopySummarySuccess => 'Cost item summary copied to clipboard';
  @override String get costItemCodeBadgeLabel => 'Cost Item Code: ';
  @override String get matrixExportTsvBtn => 'Export Responsibility Matrix (TSV)';
  @override String get matrixExportTsvSuccess => 'Responsibility matrix copied to clipboard (TSV)';
  @override String get matrixCopySummaryBtn => 'Copy Responsibility Summary';
  @override String get matrixCopySummarySuccess => 'Responsibility details copied to clipboard';
  @override String get incotermsTsvHeaderCode => 'Incoterm Code';
  @override String get incotermsTsvHeaderName => 'Incoterm Name';
  @override String get incotermsTsvHeaderVersion => 'ICC Version';
  @override String get incotermsTsvHeaderDescription => 'Description & Risk Transfer';
  @override String get incotermsTsvHeaderStatus => 'Status';
  @override String get costItemsTsvHeaderCode => 'Cost Item Code';
  @override String get costItemsTsvHeaderName => 'Cost Item Name';
  @override String get costItemsTsvHeaderCategory => 'Cost Category';
  @override String get costItemsTsvHeaderDescription => 'Description & Allocation Notes';
  @override String get costItemsTsvHeaderStatus => 'Status';
  @override String get matrixTsvHeaderIncoterm => 'Incoterm';
  @override String get matrixTsvHeaderCostItem => 'Cost Item';
  @override String get matrixTsvHeaderCategory => 'Category';
  @override String get matrixTsvHeaderResponsible => 'Responsible Party';
  @override String get matrixTsvHeaderIncluded => 'Included in Price';
  @override String get matrixTsvHeaderNotes => 'Notes & Conditions';
  @override String get exportIncotermsPdfBtn => 'Print / Save Incoterm PDF';
  @override String get exportIncotermsExcelBtn => 'Export Incoterm to Excel';
  @override String get incotermResponsibilitiesSectionTitle => 'Cost Responsibility Matrix:';
  @override String get includedInPriceYes => 'Yes (Included in Price)';
  @override String get includedInPriceNo => 'No (Excluded)';

  // Screen 36: Customs Tariff Schedule & HS Codes
  @override String get customsTariffScreenTitle => 'Customs Tariff & HS Codes';
  @override String get customsTariffScreenSubtitle => 'Egyptian Customs Duty Rates, VAT, Schedule Taxes, Development Fees & Import Regulations';
  @override String get importExcelCsvBtn => 'Import Excel/CSV';
  @override String get hsExplorerBtn => '🔍 HS Code Explorer';
  @override String get smartNafezaDiffEngineBtn => '✨ Smart Nafeza';
  @override String get dutyCalculatorBtn => 'Duty Calculator';
  @override String get addTariffManualBtn => '+ Add Manual HS Code';
  @override String get searchTariffsHint => 'Search by HS Code, Description, or Category...';
  @override String get showInactiveTariffsLabel => 'Show Inactive:';
  @override String noTariffsMatchingQuery(String query) => 'No HS Code found matching "$query"';
  @override String get noTariffsFound => 'No customs tariffs registered.';
  @override String get tariffHsCodeCol => 'HS Code';
  @override String get tariffDescAndAuthorityCol => 'Description & Authority';
  @override String get tariffCategoryCol => 'Category';
  @override String get tariffTaxRatesBreakdownCol => 'Tax Rates Breakdown';
  @override String get tariffRequirementsCol => 'Requirements';
  @override String get tariffStatusCol => 'Status';
  @override String get tariffActionsCol => 'Actions';
  @override String rateDutyBadge(String rate) => 'Duty: $rate';
  @override String rateVatBadge(String rate) => 'VAT: $rate';
  @override String rateSchedBadge(String rate) => 'Sched: $rate';
  @override String rateDevBadge(String rate) => 'Dev: $rate';
  @override String govAuthorityPrefix(String auth) => 'Gov: $auth';
  @override String printTariffSnack(String code, String desc) => 'Printing customs tariff details: $code ($desc)';
  @override String confirmDeactivateTariff(String code) => 'Are you sure you want to deactivate HS Code ($code)?';
  @override String confirmActivateTariff(String code) => 'Are you sure you want to reactivate HS Code ($code)?';
  @override String get deactivateTariffTooltip => 'Deactivate HS Code';
  @override String get activateTariffTooltip => 'Reactivate HS Code';
  @override String get importingTariffDataset => 'Importing Customs Tariff Dataset...';
  @override String get importCompletedTitle => 'Import Completed';
  @override String importSummaryContent(int total, int imported, int updated) => 'Successfully processed $total HS Codes!\n• New Tariffs Created: $imported\n• Existing Tariffs Updated: $updated';
  @override String importFailedSnack(String error) => 'Import failed: $error';
  @override String get nafezaDetailsModalTitle => 'HS Code Item Details';
  @override String get itemNumberLabel => 'HS Code: ';
  @override String get itemDescriptionLabel => 'Item Description: ';
  @override String get taxesSectionHeader => 'Taxes & Duties:';
  @override String get importDutyLabel => 'Import Duty';
  @override String get vatLabel => 'Value Added Tax (VAT)';
  @override String get scheduleTaxLabel => 'Schedule Tax';
  @override String get developmentFeeLabel => 'Development Fee';
  @override String get importFeeLabel => 'Import Fee';
  @override String get customsServiceFeeLabel => 'Customs Service Fees';
  @override String get basicFeesLabel => 'Basic Fees';
  @override String get documentsAndProceduresHeader => 'Documents & Regulatory Procedures:';
  @override String get preferentialAgreementsSubheader => 'Preferential Trade Agreements & Duty Exemptions';
  @override String get addPreferentialAgreementBtn => 'Add Agreement';
  @override String get noPreferentialAgreements => 'No preferential agreements registered for this HS Code.';
  @override String get fullExemptionBadge => 'Full Exemption (0% Duty)';
  @override String reductionPercentageBadge(String pct) => 'Duty Reduction: $pct%';
  @override String applicableCountriesLabel(String countries) => 'Target Origins: $countries';
  @override String conditionsLabel(String conditions) => 'Conditions: $conditions';
  @override String get regulatoryApprovalsSubheader => 'Prior Regulatory Approvals & Inspection Rules';
  @override String get requiresCooRule => 'Requires Certified Certificate of Origin (COO / EUR.1)';
  @override String get requiresInspectionRule => 'Subject to GOEIC / Regulatory Quality Inspection';
  @override String get requiresAcidRule => 'Mandatory ACI Advance Cargo Information Number (ACID)';
  @override String addAgreementDialogTitle(String code) => 'Add Preferential Agreement for HS Code $code';
  @override String get agreementNameLabel => 'Agreement Name *';
  @override String get agreementNameHint => 'e.g. Egypt-EU Association Agreement, Agadir, COMESA';
  @override String get agreementCountriesLabel => 'Target Origin Countries *';
  @override String get agreementCountriesHint => 'Comma-separated country codes, e.g. JO,TN,MA,EU';
  @override String get dutyReductionPctLabel => 'Customs Duty Reduction % *';
  @override String get dutyReductionPctHint => '100 for full exemption, 10 for 10% reduction';
  @override String get agreementConditionsLabel => 'Conditions & Required Proof Notes';
  @override String get agreementConditionsHint => 'e.g. Accompanied by EUR.1, Form 1, or COO';
  @override String get saveAgreementBtn => 'Save Agreement';
  @override String verifyTariffDialogTitle(String code) => 'Verify HS Code & Audit Metadata ($code)';
  @override String get verificationProtocolHeader => 'Addendum 3 Manual Verification Protocol:';
  @override String get verificationProtocolText => '• Live external web queries forbidden. All data stored internally.\n• Modifying tax rates archives the current version and creates a new active version.\n• Historical estimates preserve their exact snapshot rate.';
  @override String get verifiedByAuditorLabel => 'Verified By (Auditor Name) *';
  @override String get sourceUrlLabel => 'Nafeza Source URL Reference';
  @override String get confidenceLevelLabel => 'Confidence Level *';
  @override String get confirmVerificationBtn => 'Confirm & Certify Verification';
  @override String get verifyTariffBtn => 'Verify & Audit Item';
  @override String get editTariffBtn => 'Edit Item';
  @override String get agreementNameRequired => 'Agreement name is required';
  @override String get agreementCountriesRequired => 'Target origin countries are required';
  @override String get invalidNumberError => 'Invalid number';
  @override String get agreementAddedSuccess => 'Preferential agreement added successfully';
  @override String agreementAddFailed(String error) => 'Failed to add agreement: $error';
  @override String get auditorNameRequired => 'Auditor name is required';
  @override String get verificationSuccessSnack => 'Customs tariff verified and audited successfully';
  @override String verificationFailedSnack(String error) => 'Verification failed: $error';
  @override String get confidenceManualAudit => 'Manual Audit (Verified)';
  @override String get confidenceOfficialGazette => 'Official Gazette Decree';
  @override String get confidenceDraft => 'Draft / Unverified';
  @override String get priorApprovalSpecialConditionsLabel => 'Prior Approval / Special Conditions Note';
  @override String get taxRatesVerificationHeader => 'Tax Rates Verification:';
  @override String get dutyRateLabel => 'Duty Rate %';
  @override String get vatRateLabel => 'VAT Rate %';
  @override String get scheduleTaxRateLabel => 'Schedule Tax %';
  @override String tariffVerifiedSuccess(String code) => 'HS Code $code successfully verified!';

  // Screen 36: Customs Tariff TSV Export & Actions
  @override String get customsTariffExportTsvBtn => 'Export Tariffs (TSV)';
  @override String get customsTariffExportTsvSuccess => 'Customs tariffs copied to clipboard successfully';
  @override String get tariffCopySummaryBtn => 'Copy HS Tariff Summary';
  @override String get tariffCopySummarySuccess => 'Customs tariff summary copied to clipboard successfully';
  @override String get tariffCodeBadgeLabel => 'HS Code: ';
  @override String get tariffCopyFieldTooltip => 'Copy value';
  @override String get exportTariffPdfBtn => 'Print & Save Tariff PDF';
  @override String get exportTariffExcelBtn => 'Export Tariff Excel';

  // Screen 36: TSV Column Headers
  @override String get tariffTsvHeaderHsCode => 'HS Code';
  @override String get tariffTsvHeaderDescription => 'Description';
  @override String get tariffTsvHeaderCategory => 'Category';
  @override String get tariffTsvHeaderDutyRate => 'Import Duty %';
  @override String get tariffTsvHeaderVatRate => 'VAT %';
  @override String get tariffTsvHeaderScheduleTax => 'Schedule Tax %';
  @override String get tariffTsvHeaderDevFee => 'Development Fee %';
  @override String get tariffTsvHeaderImportFee => 'Import Fee %';
  @override String get tariffTsvHeaderAuthority => 'Authority';
  @override String get tariffTsvHeaderRequirements => 'Requirements';
  @override String get tariffTsvHeaderStatus => 'Status';

  // Screen 36: Smart Form & Manual Dialog
  @override String get tariffDialogTitleAdd => 'Add HS Code & Regulations';
  @override String tariffDialogTitleEdit(String code) => 'Edit Customs Tariff - $code';
  @override String get tariffModeSmartText => 'Smart Text Input';
  @override String get tariffModeManualForm => 'Manual Form Input';
  @override String get quickExamplesLabel => 'Quick Test Examples:';
  @override String get exampleAirConditioners => 'Air Conditioners';
  @override String get examplePlasticsBuilding => 'Plastics & Building';
  @override String get clearTextBtn => 'Clear Text';
  @override String get pasteTariffBlockLabel => 'Paste Nafeza Tariff Block Here *';
  @override String get pasteTariffBlockHint => 'Item Number:\n8415820010\nItem Description:\nAir conditioners...\nTaxes:\nImport Duty: 60%\nSchedule Tax: 8%\nVAT: 14%';
  @override String get parseNowTooltip => 'Parse Text Immediately';
  @override String parsedPreviewHeader(String code) => 'Extracted Tariff Preview ($code)';
  @override String get editFieldsManuallyBtn => 'Edit Fields Manually';
  @override String get diffHistoryTitle => 'Tariff History & Version Diff';
  @override String get newHsVersionTitle => 'New HS Code Version';
  @override String get diffDetailsHeader => 'Detected Differences Details:';
  @override String get hsCodeLabelReq => 'HS Code *';
  @override String get hsCodeHint => 'e.g. 8415820010';
  @override String get customsCategoryLabel => 'Customs Category';
  @override String get customsCategoryHint => 'e.g. Air Conditioners, Electronics';
  @override String get hsDescriptionLabelReq => 'HS Item Description *';
  @override String get hsDescriptionRequiredError => 'Item description is required';
  @override String get taxRatesBreakdownSection => 'Tax & Fee Rates (%) :';
  @override String get dutyRateInputLabel => 'Import Duty % *';
  @override String get vatRateInputLabel => 'VAT % *';
  @override String get scheduleTaxInputLabel => 'Schedule Tax %';
  @override String get devFeeInputLabel => 'Development Fee %';
  @override String get importFeeInputLabel => 'Import Fee %';
  @override String get docsAndClearanceSection => 'Document & Clearance Requirements :';
  @override String get requiresAcidCheckbox => 'Requires ACID Registration';
  @override String get requiresCooCheckbox => 'Requires Certificate of Origin';
  @override String get requiresInspectionCheckbox => 'Requires Compliance Inspection';
  @override String get govAuthorityLabel => 'Competent Regulatory Authority';
  @override String get govAuthorityHint => 'e.g. General Organization for Export & Import Control';
  @override String get priorApprovalsLabel => 'Prior Approvals & Regulatory Procedures';
  @override String get priorApprovalsHint => 'e.g. Prior approval required, Factory Decree 43';
  @override String get tariffNotesLabel => 'Additional Notes & Customs Restrictions';
  @override String get saveAllTariffAndAgreementsBtn => 'Save Tariff & All Extracted Agreements';
  @override String get addTariffBtnShort => 'Add Tariff';
  @override String get saveTariffChangesBtn => 'Save Changes';
  @override String get savingProgress => 'Saving...';
  @override String get pasteTextFirstError => 'Please paste the tariff block text first';
  @override String get cannotExtractHsCodeError => 'Could not extract HS code from entered text';
  @override String get saveFailureTitle => 'Save Failure Details';
  @override String get saveFailureIntro => 'The following errors occurred while processing and saving:';
  @override String get adjustInputsBtn => 'OK & Adjust Inputs';
  @override String get tariffAddedSuccess => 'Customs tariff and all agreements added successfully';
  @override String get tariffUpdatedSuccess => 'Customs tariff updated successfully';

  // Screen 36: Nafeza Details Dialog
  @override String get nafezaDetailsCopyTooltip => 'Copy Tariff Details';
  @override String get nafezaDetailsCopySuccess => 'Tariff details copied to clipboard';

  // Screen 37: Ports & Transport Locations
  @override String get transportLocationsScreenTitle => 'Ports & Transport Locations';
  @override String get transportLocationsScreenSubtitle => 'Master reference for Sea Ports, Airports, Dry Ports & Land Borders (UN/LOCODE)';
  @override String get addTransportLocationBtn => 'Add Transport Location';
  @override String get locationTypeAll => 'All';
  @override String get locationTypeSeaPort => 'Sea Port';
  @override String get locationTypeAirport => 'Airport';
  @override String get locationTypeDryPort => 'Dry Port';
  @override String get locationTypeLandBorder => 'Land Border';
  @override String get locationTypeIcd => 'ICD';
  @override String get locationTypeRailTerminal => 'Rail Terminal';
  @override String get searchTransportLocationsHint => 'Search by UN/LOCODE, name, city...';
  @override String locationsFetchError(String error) => 'Server connection error fetching transport locations:\n$error';
  @override String get noTransportLocationsFound => 'No transport locations found.';
  @override String get unLocodeCol => 'UN/LOCODE';
  @override String get locationNameCol => 'Location Name';
  @override String get locationTypeCol => 'Type';
  @override String get countryCol => 'Country';
  @override String get cityCol => 'City';
  @override String printLocationSnack(String name, String code) => 'Printing transport location details: $name ($code)';
  @override String confirmDeactivateLocation(String name) => 'Are you sure you want to deactivate location ($name)?';
  @override String confirmActivateLocation(String name) => 'Are you sure you want to reactivate location ($name)?';
  @override String get deactivateLocationTooltip => 'Deactivate Location';
  @override String get activateLocationTooltip => 'Reactivate Location';
  @override String showingLocationsCount(int start, int end, int total, String type) => 'Showing $start–$end of $total locations ($type)';
  @override String get addLocationDialogTitle => 'Add Transport Location';
  @override String editLocationDialogTitle(String locode) => 'Edit Location ($locode)';
  @override String get unLocodeLabel => 'UN/LOCODE *';
  @override String get unLocodeHint => 'e.g. EGALY, EGCAI';
  @override String get locationTypeLabel => 'Location Type *';
  @override String get locationNameLabel => 'Location Name *';
  @override String get locationNameHint => 'e.g. Alexandria Port';
  @override String get countryLabelRequired => 'Country *';
  @override String get countryHint => 'e.g. Egypt';
  @override String get cityLabelRequired => 'City *';
  @override String get cityHint => 'e.g. Alexandria';
  @override String get locationNotesLabel => 'Notes / Details';
  @override String get createLocationSubmitBtn => 'Create Location';
  @override String get importingLocationsDataset => 'Importing transport locations from Excel/CSV...';
  @override String get importWarningsTitle => 'Import Warnings';
  @override String get locationsImportSuccess => 'Successfully imported transport locations!';
  @override String get locationsExportTsvBtn => 'Export Locations (TSV)';
  @override String get locationsExportTsvSuccess => 'Transport locations table copied to clipboard';
  @override String get locationCopySummaryBtn => 'Copy Location Summary';
  @override String get locationCopySummarySuccess => 'Location details copied to clipboard';
  @override String get locationLocodeBadgeLabel => 'UN/LOCODE';
  @override String get locationCopyFieldTooltip => 'Copy field value';
  @override String get exportLocationPdfBtn => 'Print / Save PDF';
  @override String get exportLocationExcelBtn => 'Download EXCEL';
  @override String get locationsTsvHeaderUnLocode => 'UN/LOCODE';
  @override String get locationsTsvHeaderName => 'Location Name';
  @override String get locationsTsvHeaderType => 'Location Type';
  @override String get locationsTsvHeaderCountry => 'Country';
  @override String get locationsTsvHeaderCity => 'City';
  @override String get locationsTsvHeaderStatus => 'Status';
  @override String get locationsTsvHeaderNotes => 'Notes';

  // Screen 38: Currencies & Exchange Rates
  @override String get currenciesScreenTitle => 'Currencies & Exchange Rates';
  @override String get currenciesScreenSubtitle => 'Manage Currency ISO Codes, Commercial Bank Rates & Official Customs Exchange Rates';
  @override String get liveCurrencyConverterBtn => 'Live Currency Converter';
  @override String get currencyGainLossBtn => 'FX Gain / Loss Engine';
  @override String get updateExchangeRatesBtn => 'Update Exchange Rates';
  @override String get addCurrencyBtn => 'Add Currency';
  @override String get searchCurrenciesHint => 'Search by ISO code (USD, EUR...) or name...';
  @override String currenciesFetchError(String error) => 'Server connection error fetching currencies:\n$error';
  @override String get noCurrenciesFound => 'No currencies found.';
  @override String get isoCodeCol => 'ISO Code';
  @override String get currencyNameCol => 'Currency Name';
  @override String get currencySymbolCol => 'Symbol';
  @override String get commercialRateBankCol => 'Commercial Rate (Bank)';
  @override String get customsRateOfficialCol => 'Customs Rate (Official)';
  @override String get baseCurrencyTooltip => 'Base Currency (EGP)';
  @override String get viewRateHistoryTooltip => 'View exchange rates historical timeline';
  @override String get baseCurrencyRateLabel => '1.0000 (Base)';
  @override String rateToEgpFormatted(String code, String rate) => '1 $code = $rate EGP';
  @override String get rateNotSet => 'Not Set';
  @override String printCurrencyDetailsSnack(String code, String name) => 'Printing currency details and rate history: $code ($name)';
  @override String confirmDeactivateCurrency(String code, String name) => 'Are you sure you want to deactivate currency ($code - $name)?';
  @override String confirmActivateCurrency(String code, String name) => 'Are you sure you want to reactivate currency ($code - $name)?';
  @override String get cannotDeactivateBaseCurrencyTooltip => 'Cannot deactivate base currency (EGP)';
  @override String get deactivateCurrencyTooltip => 'Deactivate Currency';
  @override String get activateCurrencyTooltip => 'Reactivate Currency';
  @override String showingCurrenciesCount(int start, int end, int total) => 'Showing $start–$end of $total currencies';
  @override String get addCurrencyDialogTitle => 'Add Currency';
  @override String editCurrencyDialogTitle(String code) => 'Edit Currency ($code)';
  @override String get isoCodeLabel => 'ISO Currency Code (3 Letters) *';
  @override String get isoCodeHint => 'e.g. USD, EUR, GBP, CNY';
  @override String get isoCodeLengthError => 'Must be 3 uppercase letters';
  @override String get currencyNameLabel => 'Currency Name *';
  @override String get currencyNameHint => 'e.g. US Dollar, Euro';
  @override String get currencySymbolLabel => 'Currency Symbol *';
  @override String get currencySymbolHint => r'e.g. $, €, £, ¥';
  @override String get createCurrencySubmitBtn => 'Create Currency';
  @override String exchangeRateHistoryTitle(String name) => 'Exchange Rate History — $name';
  @override String get baseCurrencySystemDesc => 'System Base Currency (Egyptian Pound EGP)';
  @override String get rateHistorySubtitle => 'Timeline of commercial bank rates and official customs rates updates';
  @override String get currentCommercialRateStat => 'Current Commercial Bank Rate';
  @override String get currentCustomsRateStat => 'Current Official Customs Rate';
  @override String get rateSpreadStat => 'Rate Spread';
  @override String get historicalUpdatesCountStat => 'Historical Updates';
  @override String recordsCountBadge(int count) => '$count records';
  @override String get notSetLabel => 'Not Set';
  @override String get exchangeRateTimelineHeader => 'Exchange Rate Timeline:';
  @override String get recordNewExchangeRateBtn => 'Update New Exchange Rate';
  @override String get baseCurrencyNoticeTitle => 'Egyptian Pound (EGP) is the system base currency';
  @override String get baseCurrencyNoticeSubtitle => 'Exchange rate is always 1.0000 and requires no historical rates against itself.';
  @override String noRateHistoryForCurrency(String code) => 'No historical exchange rates recorded for currency ($code) yet.';
  @override String get recordFirstExchangeRateBtn => 'Record First Rate';
  @override String get currentActiveRateBadge => 'Current Active Rate';
  @override String get commercialBankRateLabel => 'Commercial Rate:';
  @override String get customsExchangeRateLabel => 'Customs Rate:';
  @override String get spreadVarianceLabel => 'Spread:';
  @override String rateSourcePrefix(String source) => 'By: $source';
  @override String get updateExchangeRatesDialogTitle => 'Update Exchange Rates (Commercial & Customs)';
  @override String get selectForeignCurrencyLabel => 'Select Foreign Currency *';
  @override String get commercialRateInputLabel => 'Commercial Bank Rate to EGP *';
  @override String get customsRateInputLabel => 'Official Customs Exchange Rate to EGP *';
  @override String get rateInputHint => 'e.g. 50.25';
  @override String get enterValidRateError => 'Enter valid rate > 0';
  @override String effectiveDateLabel(String date) => 'Effective Date: $date';
  @override String get saveRateSubmitBtn => 'Save Rate';
  @override String get liveCurrencyConverterDialogTitle => 'Live Currency Converter';
  @override String get liveCurrencyConverterDialogSubtitle => 'Enter amount and select currencies for instant conversion:';
  @override String get amountToConvertLabel => 'Amount to Convert *';
  @override String get amountToConvertHint => '10000';
  @override String get enterValidAmountError => 'Enter valid amount > 0';
  @override String get fromCurrencyLabel => 'From Currency';
  @override String get toCurrencyLabel => 'To Currency';
  @override String get appliedRateTypeLabel => 'Applied Exchange Rate Type';
  @override String get rateTypeCommercialOption => 'Commercial Bank Rate';
  @override String get rateTypeCustomsOption => 'Official Customs Rate';
  @override String get convertCurrencyNowBtn => 'Convert Currency Now';
  @override String get convertedAmountLabel => 'Converted Amount:';
  @override String appliedRatePrefix(dynamic rate) => 'Applied Rate: $rate';
  @override String baseEgpEquivalentPrefix(dynamic amount) => 'Base EGP Equivalent: $amount EGP';
  @override String get fxGainLossDialogTitle => 'FX Gain / Loss Calculator';
  @override String get fxGainLossDialogSubtitle => 'Calculate variance between initial booking rate and final settlement rate:';
  @override String get foreignAmountLabel => 'Foreign Currency Amount *';
  @override String get currencyLabel => 'Currency *';
  @override String get initialRateLabel => 'Initial Booking Rate (R1) *';
  @override String get initialRateHint => '49.00';
  @override String get settlementRateLabel => 'Settlement Rate (R2) *';
  @override String get settlementRateHint => '47.50';
  @override String get calculateGainLossBtn => 'Calculate FX Gain/Loss Now';
  @override String initialCostAtBooking(dynamic amount, dynamic rate) => 'Initial Cost at Booking: $amount EGP (Rate: $rate)';
  @override String actualCostAtSettlement(dynamic amount, dynamic rate) => 'Actual Cost at Settlement: $amount EGP (Rate: $rate)';
  @override String get currenciesExportTsvBtn => 'Export Currencies (TSV)';
  @override String get currenciesExportTsvSuccess => 'Currencies table copied to clipboard successfully';
  @override String get currencyCopySummaryBtn => 'Copy Currency & Rates Summary';
  @override String get currencyCopySummarySuccess => 'Currency and rates summary copied to clipboard';
  @override String get currencyCodeBadgeLabel => 'Currency Code';
  @override String get currencyCopyFieldTooltip => 'Copy field value';
  @override String get exportCurrencyPdfBtn => 'Print / Save Currency Card (PDF)';
  @override String get exportCurrencyExcelBtn => 'Export Currencies Table (Excel)';
  @override String get currenciesTsvHeaderIsoCode => 'ISO Code';
  @override String get currenciesTsvHeaderName => 'Currency Name';
  @override String get currenciesTsvHeaderSymbol => 'Symbol';
  @override String get currenciesTsvHeaderIsBase => 'Base Currency';
  @override String get currenciesTsvHeaderCommercialRate => 'Commercial Rate (EGP)';
  @override String get currenciesTsvHeaderCustomsRate => 'Customs Rate (EGP)';
  @override String get currenciesTsvHeaderStatus => 'Status';
  @override String get currenciesTsvHeaderDecimals => 'Decimal Places';

  // Generic Pagination
  @override String get rowsPerPageLabel => 'Rows per page:';
  @override String get firstPageTooltip => 'First page';
  @override String get previousPageTooltip => 'Previous page';
  @override String pageOfTotal(dynamic page, dynamic totalPages) => '$page of $totalPages';
  @override String get nextPageTooltip => 'Next page';
  @override String get lastPageTooltip => 'Last page';

  // Screen 43: Regulatory Requirements & Pre-Shipment Compliance
  @override String get importRequirementsScreenTitle => 'Regulatory Requirements & Pre-Shipment Compliance Assessment';
  @override String get importRequirementsFormTab => '📋 Regulatory Requirements Assessment';
  @override String get importRequirementsRegistryTab => '📑 Saved Requirements Registry';
  @override String editingRequirementBanner(dynamic code) => 'You are in editing mode for assessment: ($code) — changes will update and reactivate upon saving.';
  @override String get cancelEditingAndStartNewBtn => 'Cancel Edit & Start New';
  @override String get requirementsLifecycleCardTitle => 'Requirements & Compliance Scope (From ACID Issuance to Actual Sailing):';
  @override String sailingStatusBadge(dynamic status) => 'Sailing Status: $status';
  @override String get acidIssuanceStep => 'ACID Issuance';
  @override String get preShipmentInspectionStep => 'Pre-Shipment Inspection';
  @override String get approvalsAndCertsStep => 'Approvals & Certificates';
  @override String get sailingClearanceStep => 'Sailing & Release Clearance';
  @override String get pendingInspectionCoordination => 'Pending Inspection';
  @override String get completedAndPassedInspection => 'Inspection Passed';
  @override String get allCertsFulfilled100 => '100% Fulfilled';
  @override String get pendingApprovals => 'Pending Approvals';
  @override String get linkImportFileAndConsultationHeader => 'Link Import Shipment File & Customs Consultation:';
  @override String consultationStudyBadge(dynamic code, dynamic readiness) => 'Consultation: $code (Readiness $readiness%)';
  @override String get linkedImportFileFieldLabel => 'Linked Import File *';
  @override String get selectImportFileHint => 'Select import shipment file...';
  @override String get selectImportFileOption => '-- Select Import File --';
  @override String get acidNotIssued => 'Not Issued';
  @override String get pleaseSelectImportFileError => 'Please select an import file';
  @override String get acidNumberFieldLabel => 'Advanced Customs ACID Number (Optional)';
  @override String get acidNumberRequiredError => 'ACID number is required';
  @override String get acidNumberOptionalHint => 'Auto-fetched from Import File upon issuance';
  @override String get foreignSupplierFieldLabel => 'Foreign Supplier / Factory';
  @override String get foreignSupplierHint => 'Foreign supplier...';
  @override String get notSpecifiedOption => '-- Not Specified --';
  @override String prefillImportRequirementSuccess(dynamic count, dynamic code) => '⚡ Auto-fetched $count tariff items and requirements for file $code';
  @override String hsCodesSelectorCardTitle(dynamic count) => 'Shipment Tariff HS Codes & Values — $count items recorded:';
  @override String totalHsValueBadge(dynamic value, dynamic currency) => 'Total Value: $value $currency';
  @override String hsItemCodeLabel(dynamic hs, dynamic item) => '$hs ($item)';
  @override String hsItemDescLabel(dynamic desc, dynamic value, dynamic currency) => '$desc | $value $currency';
  @override String get hsCodeFieldLabel => 'Tariff HS Code *';
  @override String get hsCodeRequiredError => 'HS Code is required';
  @override String get commodityDescFieldLabel => 'Commodity / Item Description *';
  @override String get commodityDescRequiredError => 'Commodity description is required';
  @override String get countryOfOriginFieldLabel => 'Country of Origin *';
  @override String get countryOfOriginRequiredError => 'Country of origin is required';
  @override String get currencyFieldLabel => 'Currency *';
  @override String get valueInCurrencyFieldLabel => 'Value in Currency *';
  @override String get pillar1Decree43Tab => '1. Decree 43 & Factory Reg';
  @override String get pillar2CooTab => '2. COO & Agreements';
  @override String get pillar3InspectionTab => '3. Pre-Shipment Inspection';
  @override String get pillar4PermitsTab => '4. Regulatory Permits';
  @override String get pillar5TechCertsTab => '5. Technical Certs & Sailing';
  @override String get pillar1Header => 'Pillar 1: Decree 43/2016 & Qualified Factory Registration (GOEIC)';
  @override String get decree43ApplicableCheck => 'Item subject to Decree 43/2016 (Factory Registration)';
  @override String get decree43ApplicableSub => 'Finished consumer goods requiring qualified factory registration';
  @override String get whiteListVerifiedCheck => 'Factory Verified on GOEIC White List';
  @override String get whiteListVerifiedSub => 'Factory registration verified with GOEIC authority';
  @override String get factoryRegNumFieldLabel => 'GOEIC Factory Registration No. / Foreign Exporter ID';
  @override String get factoryRegNumHint => 'e.g. GOEIC-REG-77821';
  @override String get pillar2Header => 'Pillar 2: Certificate of Origin & Preferential Trade Agreements';
  @override String get cooRequiredCheck => 'Certificate of Origin Required (COO)';
  @override String get cooTypeFieldLabel => 'Certificate of Origin Type (COO Type)';
  @override String get cooTypeEur1Option => 'EUR.1 (EU Partnership, EFTA, Turkey)';
  @override String get cooTypeFormAOption => 'Form A (Generalized System of Preferences GSP)';
  @override String get cooTypeGaftaOption => 'Arab League COO (GAFTA Trade Agreement)';
  @override String get cooTypeComesaOption => 'COMESA (Common Market for Eastern & Southern Africa)';
  @override String get cooTypeStandardChamberOption => 'Standard Chamber of Commerce Certified COO';
  @override String get cooStatusFieldLabel => 'Fulfillment Status (COO Status)';
  @override String get cooStatusPendingOption => 'Pending from Supplier';
  @override String get cooStatusObtainedOption => 'Obtained & Verified';
  @override String get cooStatusWaivedOption => 'Waived or Exempted';
  @override String get cooNotesFieldLabel => 'Origin Notes & Tariff Exemption Conditions';
  @override String get cooNotesHint => 'e.g. 100% customs exemption under EU Partnership Agreement';
  @override String get pillar3Header => 'Pillar 3: Pre-Shipment Inspection & Accredited Lab Testing (ILAC)';
  @override String get inspectionRequiredCheck => 'Pre-Shipment Inspection Certificate Required';
  @override String get inspectionBodyFieldLabel => 'Accredited Inspection Agency (Inspection Body)';
  @override String get inspectionBodySgsOption => 'SGS Inspection Services';
  @override String get inspectionBodyBvOption => 'Bureau Veritas';
  @override String get inspectionBodyTuvOption => 'TÜV Rheinland / TÜV SÜD';
  @override String get inspectionBodyIntertekOption => 'Intertek International';
  @override String get inspectionBodyQimaOption => 'QIMA Inspection Services';
  @override String get inspectionBodyIlacOption => 'ILAC / ISO 17025 Accredited International Lab';
  @override String get inspectionStatusFieldLabel => 'Inspection Status';
  @override String get inspectionStatusPendingOption => 'Pending Coordination';
  @override String get inspectionStatusScheduledOption => 'Inspection Scheduled';
  @override String get inspectionStatusCompletedOption => 'Completed & Passed';
  @override String get inspectionStatusRejectedOption => 'Rejected / Non-Compliant';
  @override String get inspectionReportNumFieldLabel => 'Inspection Report / Certificate Number';
  @override String get inspectionNotesFieldLabel => 'Inspection Notes & Lab Test Results';
  @override String get pillar4Header => 'Pillar 4: Prior Regulatory Approvals & Specialized Permits';
  @override String get importPermitRequiredCheck => 'Prior Import Permit Required';
  @override String get issuingAuthorityFieldLabel => 'Regulatory Issuing Authority';
  @override String get authorityEeaaOption => 'Egyptian Environmental Affairs Agency (EEAA)';
  @override String get authorityNfsaOption => 'National Food Safety Authority (NFSA)';
  @override String get authorityEdaOption => 'Egyptian Drug Authority (EDA)';
  @override String get authorityNtraOption => 'National Telecom Regulatory Authority (NTRA)';
  @override String get authorityPublicSecurityOption => 'Public Security & Control Authority';
  @override String get authorityChemistryOption => 'Chemistry Administration / Atomic Energy';
  @override String get authorityGoeicOption => 'General Organization for Export & Import Control (GOEIC)';
  @override String get permitStatusFieldLabel => 'Permit Status';
  @override String get permitStatusAppliedOption => 'Application Submitted';
  @override String get permitStatusApprovedOption => 'Approved & Certified';
  @override String get permitStatusRejectedOption => 'Rejected';
  @override String get permitNumberFieldLabel => 'Permit / Regulatory Approval Number';
  @override String get permitNotesFieldLabel => 'Permit Conditions & Special Requirements';
  @override String get pillar5Header => 'Pillar 5: Technical Certificates & Sailing Clearance';
  @override String get msdsRequiredCheck => 'Material Safety Data Sheet (MSDS)';
  @override String get halalCertRequiredCheck => 'Halal Certificate';
  @override String get coaRequiredCheck => 'Certificate of Analysis (COA)';
  @override String get sailingStatusFieldLabel => 'Sailing & Physical Dispatch Status';
  @override String get sailingStatusPreSailingOption => 'Pre-Sailing';
  @override String get sailingStatusClearedOption => 'Cleared for Sailing';
  @override String get sailingStatusSailedOption => 'Sailed / On Vessel';
  @override String get sailingDateFieldLabel => 'Actual / Expected Sailing Date';
  @override String get riskLevelFieldLabel => 'Compliance Risk Level';
  @override String get riskLevelLowOption => 'Low';
  @override String get riskLevelMediumOption => 'Medium';
  @override String get riskLevelHighOption => 'High';
  @override String get overallStatusDraftOption => 'Draft';
  @override String get overallStatusInProgressOption => 'In Progress';
  @override String get overallStatusCompleteOption => 'Complete';
  @override String get overallStatusConfirmedOption => 'Confirmed & Cleared';
  @override String get completeAllPillarsBtn => 'Complete & Authorize All Pillars ⚡';
  @override String get completeAllPillarsSuccessSnack => '⚡ All compliance pillars fulfilled and shipment cleared for sailing!';
  @override String get saveRequirementDraftBtn => 'Save Draft 💾';
  @override String get updateRequirementSubmitBtn => 'Update Assessment';
  @override String get saveRequirementSubmitBtn => 'Save & Authorize Assessment';
  @override String get fillRequiredFieldsError => 'Please ensure all required fields are filled.';
  @override String updateRequirementSuccessSnack(dynamic code) => '✅ Requirements assessment ($code) updated successfully!';
  @override String get createRequirementSuccessSnack => '✅ Regulatory compliance assessment created and saved successfully!';
  @override String get saveRequirementErrorTitle => 'Duplicate Warning / Save Error';
  @override String get goToSavedRequirementsBtn => 'Go to Saved Records to Edit';
  @override String get searchRequirementsHint => 'Search by assessment code, HS code, ACID, supplier, or description...';
  @override String get complianceStatusFilterLabel => 'Compliance Status';
  @override String get riskLevelFilterLabel => 'Risk Level';
  @override String get activeDeletedFilterLabel => 'Active / Deleted Records';
  @override String get allRecordsActiveAndDeleted => 'All Records (Active & Deleted)';
  @override String get activeOnlyOption => 'Active Only';
  @override String get deletedOnlyOption => 'Deleted Only';
  @override String get noRequirementsFound => 'No assessments found matching the current search.';
  @override String get createNewRequirementBtn => 'Create New Assessment';
  @override String requirementsFetchError(dynamic error) => 'Error loading requirements assessments:\n$error';
  @override String get fallbackImportingCompany => 'Importing Company';
  @override String requirementRowSubtitle(dynamic hs, dynamic desc, dynamic val, dynamic curr, dynamic supp, dynamic origin) => 'HS Code: $hs — $desc | Value: $val $curr | Supplier: $supp ($origin)';
  @override String sailingStatusBadgeRow(dynamic status) => 'Sailing: $status';
  @override String requirementStatusBadgeRow(dynamic status) => 'Status: $status';
  @override String riskLevelBadgeRow(dynamic risk) => 'Risk: $risk';
  @override String hsItemsCountBadge(dynamic count) => '$count HS Items';
  @override String get decree43VerifiedBadge => 'Decree 43 Verified';
  @override String get cooObtainedBadge => 'COO Obtained';
  @override String get inspectionPassedBadge => 'Inspection Passed';
  @override String get editRequirementTooltip => 'Edit, complete and reactivate assessment';
  @override String loadedRequirementForEditingSnack(dynamic code) => '📂 Assessment ($code) loaded for editing!';
  @override String get restoreRequirementTooltip => 'Restore and activate assessment';
  @override String restoredRequirementSuccessSnack(dynamic code) => '♻️ Assessment ($code) restored successfully!';
  @override String get deleteRequirementTooltip => 'Soft Delete';
  @override String get confirmDeleteRequirementTitle => 'Confirm Soft Delete Assessment';
  @override String confirmDeleteRequirementContent(dynamic code, dynamic file) => 'Are you sure you want to soft delete assessment ($code) for file ($file)?\n\nYou can restore or reactivate it at any time.';
  @override String deletedRequirementSuccessSnack(dynamic code) => '🗑️ Assessment ($code) soft deleted.';

  // Screen 43: Additional Export, Copy, and Detail Getters
  @override String get requirementsExportTsvBtn => 'Export TSV';
  @override String get requirementsExportTsvSuccess => 'Requirements table copied to clipboard as TSV';
  @override String get requirementsExportExcelBtn => 'Export Excel';
  @override String get requirementsExportPdfBtn => 'Print PDF Report';
  @override String get requirementCopySummaryBtn => 'Copy Assessment Summary';
  @override String get requirementCopySummarySuccess => 'Regulatory assessment summary copied to clipboard';
  @override String get requirementCodeBadgeLabel => 'Assessment Code: ';
  @override String get requirementAcidBadgeLabel => 'ACID Number: ';
  @override String get requirementHsBadgeLabel => 'HS Code: ';
  @override String get requirementCopyFieldTooltip => 'Click to copy field to clipboard';
  @override String get printRequirementSlipBtn => 'Print Compliance Slip (PDF)';
  @override String get requirementDetailsDialogTitle => 'Regulatory Requirements & Pre-Shipment Compliance Details';
  @override String get requirementSelectHsInstruction => 'Select an HS item to review and fulfill its 5 pillars individually:';
  @override String requirementPillarsProgressBadge(dynamic count) => '$count/5 Fulfilled';
  @override String get decree43NotRegisteredBadge => 'Decree 43: Not Registered';
  @override String get decree43ExemptionChangeBtn => 'Change to Legal Exemption';
  @override String get decree43SampleReasonGoeicReview => 'Factory registration submitted to GOEIC with incoming reference number and under active review';
  @override String get decree43CommonExemptionsTitle => 'Common and legally authorized exemption grounds (click to select):';
  @override String get decree43JustificationHint => 'Enter legal justification or exemption basis...';
  @override String get decree43TaskExplanation => 'A high-priority operational task has been scheduled for the team to follow up GOEIC factory registration and notify the dashboard.';
  @override String complianceBannerTitle(dynamic hs, dynamic desc) => 'Regulatory Compliance & Alerts for HS Item: $hs ($desc)';
  @override String get compliancePillar1Mandatory => 'Ministerial Decree 43/2016: Release of finished consumer goods requires production in factories registered on the GOEIC whitelist.';
  @override String get compliancePillar1Warning => 'Unregistered factories are prohibited from customs release and preliminary ACID issuance unless official exemption is documented.';
  @override String get compliancePillar1Exemption => 'Exempted: Production inputs, raw materials, spare parts for manufacturing and services (Article 2), personal use imports, and non-commercial samples.';
  @override String get compliancePillar2Mandatory => 'Submission of original Certificate of Origin certified by the chamber of commerce in the exporting country, fully matching invoice, packing list, and bill of lading.';
  @override String get compliancePillar2Warning => 'Country of origin mismatch with shipping port without movement certificate, or exporter discrepancy causes loss of preferential tariff benefits.';
  @override String get compliancePillar2Exemption => 'Preferential agreements (EUR.1, GAFTA, COMESA, Egypt-Turkey, Agadir) provide customs duty reductions and full customs exemptions.';
  @override String get compliancePillar3Mandatory => 'Pre-shipment inspection and certificate of conformity (ILAC / ISO 17020) by an accredited international inspection agency prior to shipment sailing.';
  @override String get compliancePillar3Warning => 'Shipping without an accredited certificate requires mandatory laboratory sampling by GOEIC with risk of rejection and re-export at importer expense.';
  @override String get compliancePillar3Exemption => 'Authorized Economic Operator (AEO) certified companies benefit from accelerated green channel visual verification.';
  @override String get compliancePillar4Mandatory => 'Prior regulatory approvals and permits from Egyptian authorities (EDA, EEAA, NTRA, NFSA) prior to LC opening and shipping.';
  @override String get compliancePillar4Warning => 'Shipping controlled goods without prior permits blocks entry on the Nafeza platform and triggers customs detention or confiscation.';
  @override String get compliancePillar4Exemption => 'Authorized industrial importers may request temporary bonded custody storage at factory warehouse pending final conformity tests.';
  @override String get compliancePillar5Mandatory => 'Submission of Material Safety Data Sheet (MSDS) with UN/CAS codes for chemicals, Halal certificate for food/meat, and Certificate of Analysis (COA).';
  @override String get compliancePillar5Warning => 'Unclear expiration date or production batch in Arabic on outer packaging causes rejection by the National Food Safety Authority.';
  @override String get compliancePillar5Exemption => 'Dry goods, equipment, and industrial spare parts are fully exempt from MSDS and Halal requirements, requiring only technical catalogue inspection.';
  @override String reqAcidNumberBadge(dynamic acid) => 'ACID: $acid';
  @override String get acidIssuedInPhaseText => 'Issued in ACID Phase';

  // TSV Column Headers for Export
  @override String get requirementsTsvHeaderCode => 'Assessment Code';
  @override String get requirementsTsvHeaderFileCode => 'Import File Code';
  @override String get requirementsTsvHeaderHsCode => 'HS Code';
  @override String get requirementsTsvHeaderCommodity => 'Commodity';
  @override String get requirementsTsvHeaderValue => 'Shipment Value';
  @override String get requirementsTsvHeaderCurrency => 'Currency';
  @override String get requirementsTsvHeaderOrigin => 'Origin';
  @override String get requirementsTsvHeaderSupplier => 'Supplier';
  @override String get requirementsTsvHeaderDecree43 => 'Decree 43 Registration';
  @override String get requirementsTsvHeaderCoo => 'Certificate of Origin';
  @override String get requirementsTsvHeaderInspection => 'Pre-Shipment Inspection';
  @override String get requirementsTsvHeaderPermit => 'Regulatory Permits';
  @override String get requirementsTsvHeaderTechCerts => 'Technical Certificates';
  @override String get requirementsTsvHeaderSailingStatus => 'Sailing Status';
  @override String get requirementsTsvHeaderOverallStatus => 'Overall Status';
  @override String get requirementsTsvHeaderRiskLevel => 'Risk Level';
  @override String get requirementsTsvHeaderAssessedBy => 'Assessed By';
  @override String get requirementsTsvHeaderNotes => 'Notes';

  // ── Screen 44: Demurrage & Detention ───────────────────────────────────────
  @override String get demurrageScreenTitle => 'Demurrage, Detention & Port Storage Monitor';
  @override String get containerTrackingsTab => 'Active Container Trackings';
  @override String get simulatorAndTierCalcTab => 'Tiered Simulator & Calculator';
  @override String get carrierTariffPoliciesTab => 'Carrier Tariff Policies';
  @override String get totalActiveTrackingsMetric => 'Total Active Sessions';
  @override String activeShipmentsCount(dynamic count) => '$count shipments';
  @override String get incurredDemurrageShipmentsMetric => 'Shipments with Incurred Fees';
  @override String get totalCalculatedDemurrageMetric => 'Total Calculated Demurrage';
  @override String get searchDemurrageHint => 'Search by B/L #, tracking code, or carrier...';
  @override String get allStatusesOption => 'All Statuses';
  @override String get statusFreeTimeActive => 'Free Time Active';
  @override String get statusDemurrageIncurred => 'Demurrage Incurred';
  @override String get statusDetentionIncurred => 'Detention Incurred';
  @override String get statusPushedToSettlement => 'Pushed to Settlement';
  @override String get startNewTrackingBtn => 'Start New Shipment Tracking';
  @override String get noTrackingsFound => 'No container tracking sessions match your search';
  @override String billOfLadingLabel(dynamic blNo) => 'B/L: $blNo';
  @override String get dischargeDateLabel => 'Discharge Date';
  @override String get gateOutDateLabel => 'Port Gate-Out';
  @override String get notGatedOutYet => 'Not gated out yet';
  @override String get emptyReturnDateLabel => 'Empty Return';
  @override String get notReturnedYet => 'Not returned yet';
  @override String get containersCountLabel => 'Containers Count';
  @override String containersCountValue(dynamic count) => '$count containers';
  @override String get totalEstimatedCostLabel => 'Total Estimated Cost';
  @override String get updateGateOutAndReturnDatesBtn => 'Update Gate-Out & Return Dates';
  @override String get pushToFinancialSettlementBtn => 'Push to Landed Cost Settlement';
  @override String get alreadyPushedToSettlementBtn => 'Expense Pushed to Settlement';
  @override String get calculationSettingsTitle => 'Calculation Parameters & Settings';
  @override String get shippingLineFieldLabel => 'Shipping Line';
  @override String get containerTypeFieldLabel => 'Container Type';
  @override String get containersCountFieldLabel => 'Number of Containers';
  @override String get exchangeRateFieldLabel => 'Exchange Rate (EGP/USD)';
  @override String get grantedFreeDaysHeader => 'Granted Free Days';
  @override String get portDemurrageFreeDaysLabel => 'Port Demurrage Free Days';
  @override String get emptyReturnFreeDaysLabel => 'Empty Return Free Days';
  @override String get operationalMilestonesHeader => 'Operational Milestones';
  @override String get vesselDischargeDateMilestone => 'Vessel Discharge Date';
  @override String get portGateOutDateMilestone => 'Port Gate-Out Date';
  @override String get notGatedOutCalculatedToday => 'Not gated out (calculated through today)';
  @override String get emptyReturnToDepotMilestone => 'Empty Return to Depot';
  @override String get recalculateDemurrageNowBtn => 'Recalculate Fees Now';
  @override String get initializingSimulationResults => 'Initializing simulation results...';
  @override String get totalDemurrageCostSummaryTitle => 'Total Demurrage & Storage Cost Summary';
  @override String get demurrageFeeMetric => 'Demurrage Fee';
  @override String get detentionFeeMetric => 'Detention Fee';
  @override String get portStorageFeeMetric => 'Port Storage Fee';
  @override String daysOverdueFormatted(dynamic days) => '$days days overdue';
  @override String get totalDueComprehensiveCost => 'Total Comprehensive Cost Due:';
  @override String egpCurrencyAmount(dynamic amount) => '$amount EGP';
  @override String get tieredBreakdownTitle => 'Tiered Breakdown Details';
  @override String get colCategory => 'Category';
  @override String get colConsumedDays => 'Consumed Days';
  @override String get colFreeDays => 'Free Days';
  @override String get colOverdueDays => 'Overdue Days';
  @override String get colFeeAmount => 'Fee Amount';
  @override String daysCountFormatted(dynamic days) => '$days days';
  @override String demurrageCategoryLabel(dynamic category) {
    switch (category?.toString()) {
      case 'Demurrage':
        return 'Demurrage';
      case 'Detention':
        return 'Detention';
      case 'Port Storage':
        return 'Port Storage';
      default:
        return category?.toString() ?? '';
    }
  }
  @override String get carrierTariffPoliciesTitle => 'Approved Carrier Tariff Policies';
  @override String get carrierTariffPoliciesSubtitle => 'Agreed free day schedules and progressive daily tiers per carrier and container type';
  @override String get addCarrierPolicyBtn => 'Add New Carrier Policy';
  @override String get noCarrierPoliciesFound => 'No carrier policies added yet. You can click "Add New Policy" or use system default policies.';
  @override String currencyLabelFormatted(dynamic curr) => 'Currency: $curr';
  @override String get demurrageFreeLabel => 'Demurrage Free';
  @override String get detentionFreeLabel => 'Detention Free';
  @override String get portStorageFreeLabel => 'Port Storage Free';
  @override String get dailyStorageRateLabel => 'Daily Storage Rate';
  @override String egpPerDayFormatted(dynamic rate) => '$rate EGP/day';
  @override String get addTrackingDialogTitle => 'Start New Shipment Tracking';
  @override String get arrivalPortFieldLabel => 'Port of Arrival';
  @override String get blNumberFieldLabel => 'Bill of Lading # (B/L)';
  @override String get containerNumberFieldLabel => 'Container # (e.g. MSCU1234567)';
  @override String get portDischargeDateTile => 'Port Container Discharge Date';
  @override String get saveAndStartTrackingBtn => 'Save & Start Tracking';
  @override String get trackingCreatedSuccessSnack => 'Shipment tracking started successfully';
  @override String get saveTrackingErrorSnack => 'An error occurred while saving tracking';
  @override String updateTrackingDatesDialogTitle(dynamic code) => 'Update Shipment Dates ($code)';
  @override String get gateOutDateTile => 'Port Container Gate-Out Date';
  @override String get emptyReturnDateTile => 'Empty Container Return Date';
  @override String get notRecordedOption => 'Not recorded';
  @override String get saveAndRecalculateBtn => 'Save & Recalculate';
  @override String get datesUpdatedAndRecalculatedSuccessSnack => 'Dates updated and fees recalculated successfully';
  @override String get datesUpdateErrorSnack => 'An error occurred while updating dates';
  @override String get pushedToSettlementSuccessSnack => 'Expense successfully pushed to financial settlement';
  @override String get pushToSettlementErrorSnack => 'An error occurred while pushing to settlement';
  @override String get addPolicyDialogTitle => 'Add New Carrier Policy';
  @override String get demurrageFreeDaysFieldLabel => 'Demurrage Free Days';
  @override String get detentionFreeDaysFieldLabel => 'Detention Free Days';
  @override String get portStorageFreeDaysFieldLabel => 'Port Storage Free Days';
  @override String get dailyStorageRateEgpFieldLabel => 'Daily Storage Rate (EGP)';
  @override String get savePolicyBtn => 'Save Policy';
  @override String get policyCreatedSuccessSnack => 'Carrier policy added successfully';
  @override String get genericErrorSnack => 'An error occurred';
  @override String get requiredFieldValidation => 'Required field';
  @override String localizedDemurrageStatus(dynamic status) {
    switch (status?.toString()) {
      case 'Free Time Active':
        return 'Free Time Active';
      case 'Demurrage Incurred':
        return 'Demurrage Incurred';
      case 'Detention Incurred':
        return 'Detention Incurred';
      case 'Pushed to Settlement':
        return 'Pushed to Settlement';
      default:
        return status?.toString() ?? '';
    }
  }
  // Screen 44 Additions: TSV Headers, Export, Copy & Dual Clock
  @override String get demurrageTsvHeaderTrackingCode => 'Tracking Code';
  @override String get demurrageTsvHeaderBlNumber => 'Bill of Lading No';
  @override String get demurrageTsvHeaderCarrier => 'Shipping Line';
  @override String get demurrageTsvHeaderPort => 'Arrival Port';
  @override String get demurrageTsvHeaderDischargeDate => 'Discharge Date';
  @override String get demurrageTsvHeaderGateOutDate => 'Gate-Out Date';
  @override String get demurrageTsvHeaderEmptyReturnDate => 'Empty Return Date';
  @override String get demurrageTsvHeaderContainersCount => 'Containers Count';
  @override String get demurrageTsvHeaderTotalDemurrageFx => 'Demurrage Fee (FX)';
  @override String get demurrageTsvHeaderTotalDetentionFx => 'Detention Fee (FX)';
  @override String get demurrageTsvHeaderTotalStorageEgp => 'Port Storage (EGP)';
  @override String get demurrageTsvHeaderCurrency => 'Currency';
  @override String get demurrageTsvHeaderExchangeRate => 'Exchange Rate';
  @override String get demurrageTsvHeaderTotalCostEgp => 'Total Estimated Cost (EGP)';
  @override String get demurrageTsvHeaderStatus => 'Status';
  @override String get demurrageTsvHeaderPushedSettlement => 'Pushed to Settlement';
  @override String get demurrageExportTsvBtn => 'Export TSV';
  @override String get demurrageExportTsvSuccess => 'Container trackings copied as TSV';
  @override String get demurrageExportExcelBtn => 'Export Excel';
  @override String get demurrageExportPdfBtn => 'Print Tracking PDF';
  @override String get demurragePrintSlipTooltip => 'Print Demurrage Calculation Slip';
  @override String get demurrageCopySummaryBtn => 'Copy Tracking Summary';
  @override String get demurrageCopySummarySuccess => 'Tracking summary copied successfully';
  @override String get demurrageCodeBadgeLabel => 'Tracking Code';
  @override String get demurrageBlBadgeLabel => 'Bill of Lading';
  @override String get demurrageCopyFieldTooltip => 'Click to copy to clipboard';
  @override String get dualClockRadarBtn => 'Dual-Clock Radar';
  @override String get dualClockRadarDialogTitle => 'Dual-Clock Radar: Demurrage & Port Storage';
  @override String get dualClockCarrierClockTitle => 'Carrier Demurrage';
  @override String get dualClockPortClockTitle => 'Port Storage';
  @override String get dualClockWarning72hTitle => 'Critical Warning: Less than 72 hours remaining before port storage tier doubles!';
  @override String get dualClockGateOutSectionTitle => 'Container Gate-Out & EIR Tracking';
  @override String get dualClockContainerNoLabel => 'Container Number';
  @override String get dualClockContainerNoHint => 'e.g. MSKU1234567';
  @override String get dualClockEirReceiptLabel => 'EIR Receipt Number';
  @override String get dualClockRecordGateOutBtn => 'Record Gate-Out';
  @override String get dualClockEnterContainerValidation => 'Please enter container number first';
  @override String get dualClockGateOutSuccessSnack => 'Container gate-out recorded successfully';
  @override String get dualClockGateOutErrorSnack => 'Failed to record container gate-out';
  @override String get dualClockRetryBtn => 'Retry';
  @override String get dualClockCopyMetricsBtn => 'Copy Radar Metrics';
  @override String get dualClockCopyMetricsSuccess => 'Dual-clock radar metrics copied successfully';
  @override String get dualClockFreeDaysRemaining => 'Within Free Time';
  @override String get dualClockOverdueDaysNote => 'Overdue';
  @override String get dualClockCurrentTierPrefix => 'Current Tier';
  @override String get dualClockStandardTierLabel => 'Standard Tier';
  @override String get simBreakdownCopyTsvBtn => 'Copy Breakdown';
  @override String get simBreakdownCopyTsvSuccess => 'Calculation breakdown copied successfully';
  @override String get policyCopySummaryBtn => 'Copy Policy Summary';
  @override String get policyCopySummarySuccess => 'Policy summary copied successfully';
  @override String get policiesExportTsvBtn => 'Export Carrier Policies';
  @override String get policiesExportTsvSuccess => 'Carrier policies copied as TSV';
  @override String get policiesTsvHeaderCarrier => 'Shipping Line';
  @override String get policiesTsvHeaderContainerType => 'Container Type';
  @override String get policiesTsvHeaderDemurrageFreeDays => 'Demurrage Free Days';
  @override String get policiesTsvHeaderDetentionFreeDays => 'Detention Free Days';
  @override String get policiesTsvHeaderPortStorageFreeDays => 'Port Storage Free Days';
  @override String get policiesTsvHeaderDailyStorageRateEgp => 'Daily Storage Rate (EGP)';
  @override String get policiesTsvHeaderCurrency => 'Currency';

  // ── Screen 47: Audit Logs ──────────────────────────────────────────────────
  @override String get auditLogsScreenTitle => 'System Audit Trail & History Logs';
  @override String get auditLogsScreenSubtitle => 'Complete System-Wide Activity Trail, Field Diffs & User Change Tracking';
  @override String get liveRefreshBtn => 'Live Refresh';
  @override String get filterEntityLabel => 'Entity:';
  @override String get filterActionLabel => 'Action:';
  @override String get filterAllOption => 'All';
  @override String get auditEntityImportCompany => 'Importer';
  @override String get auditEntitySupplier => 'Supplier';
  @override String get auditEntityExternalServiceProvider => 'Partner/Bank';
  @override String get auditEntityUser => 'User';
  @override String auditEntityLabel(dynamic type) {
    switch (type?.toString()) {
      case 'ImportCompany':
        return 'Importer';
      case 'Supplier':
        return 'Supplier';
      case 'ExternalServiceProvider':
        return 'Partner/Bank';
      case 'User':
        return 'User';
      case 'All':
        return 'All';
      default:
        return type?.toString() ?? '';
    }
  }
  @override String get auditActionCreate => 'CREATE';
  @override String get auditActionUpdate => 'UPDATE';
  @override String get auditActionDelete => 'DELETE';
  @override String get auditActionRestore => 'RESTORE';
  @override String auditActionLabel(dynamic action) {
    switch (action?.toString().toUpperCase()) {
      case 'CREATE':
        return 'CREATE';
      case 'UPDATE':
        return 'UPDATE';
      case 'DELETE':
        return 'DELETE';
      case 'RESTORE':
        return 'RESTORE';
      case 'ALL':
        return 'ALL';
      default:
        return action?.toString() ?? '';
    }
  }
  @override String get searchAuditLogsHint => 'Search logs by entity code, user, or change summary...';
  @override String auditLogsFetchError(dynamic error) => 'Error loading audit logs: $error';
  @override String get noAuditLogsFound => 'No system audit logs match your search filters.';
  @override String auditEntityWithCode(dynamic type, dynamic code) => '$type #$code';
  @override String get systemMutationFallback => 'System mutation recorded';
  @override String performedByUser(dynamic user) => 'Performed by: $user';
  @override String get auditLogsExportTsvBtn => 'Export Logs (TSV)';
  @override String get auditLogsExportTsvSuccess => 'Audit logs table copied to clipboard';
  @override String get auditLogCopySummaryBtn => 'Copy Log Details';
  @override String get auditLogCopySummarySuccess => 'Log details copied to clipboard';
  @override String get auditLogEntityCodeBadgeLabel => 'Entity Code';
  @override String get auditLogCopyFieldTooltip => 'Copy Value';
  @override String get exportAuditLogPdfBtn => 'Export Audit Log (PDF)';
  @override String get exportAuditLogExcelBtn => 'Export Logs (Excel)';
  @override String get viewEntityHistoryBtn => 'View Full Entity History';
  @override String get auditLogsTsvHeaderLogId => 'Log ID';
  @override String get auditLogsTsvHeaderAction => 'Action';
  @override String get auditLogsTsvHeaderEntityType => 'Entity Type';
  @override String get auditLogsTsvHeaderEntityCode => 'Entity Code';
  @override String get auditLogsTsvHeaderSummary => 'Change Summary';
  @override String get auditLogsTsvHeaderPerformedBy => 'Performed By';
  @override String get auditLogsTsvHeaderTimestamp => 'Timestamp';
  @override String get rowHistoryDialogTitle => 'Change History & Audit Trail';
  @override String rowHistoryDialogSubtitle(dynamic entityType, dynamic entityTitle) => '$entityType: $entityTitle';
  @override String get rowHistoryRefreshTooltip => 'Refresh Live History';
  @override String get rowHistoryLoading => 'Fetching live audit logs from API...';
  @override String get rowHistoryEmpty => 'No change history recorded yet.';
  @override String get rowHistoryCloseBtn => 'Close';
  @override String get rowHistoryExportTsvBtn => 'Export History (TSV)';
  @override String get rowHistoryExportTsvSuccess => 'Entity history copied to clipboard';
  @override String get rowHistoryExportPdfBtn => 'Export History (PDF)';
  @override String get rowHistoryCopySummaryBtn => 'Copy Change Summary';
  @override String get rowHistoryCopySummarySuccess => 'Change summary copied to clipboard';

  // ── Screen 48: Lifecycle Kanban Board ───────────────────────────────────────
  @override String get lifecycleBoardTitle => 'Shipment Lifecycle Operations Board (6 Phases / 25 Steps)';
  @override String get lifecycleBoardSubtitle => 'Live Interactive Shipment Stage Tracker — Select a stage to view and update file registry';
  @override String get refreshLiveBoardTooltip => 'Refresh Live Data';
  @override String lifecycleBoardError(dynamic error) => 'An error occurred while loading board data:\n$error';
  @override String get majorPhasesHeader => 'The 6 Major Phases — Select any stage to view and update its shipments in the table below:';
  @override String totalActiveShipmentsCount(dynamic files, dynamic stages) => 'Total Active Shipments: $files Files ($stages Stages)';
  @override String get showAllPhasesBtn => 'Show All Phases';
  @override String get allShipmentsAllPhases => 'All Shipments Across All Phases';
  @override String get searchLifecycleTableHint => 'Search by file code, supplier, PO, or notes...';
  @override String shipmentsCountFormatted(dynamic count) => '$count Shipments';
  @override String get colShipmentCode => 'File Code';
  @override String get colPreviousStep => 'Previous Step';
  @override String get colCurrentStep => 'Current Step';
  @override String get colNextStep => 'Next Step';
  @override String get colImportCompany => 'Importer';
  @override String get colForeignSupplier => 'Foreign Supplier';
  @override String get colPurchaseOrder => 'PO Number';
  @override String get colModeAndIncoterm => 'Mode & Incoterm';
  @override String get colEstimatedValue => 'Estimated Value';
  @override String get colNotesAndActivities => 'Notes & Activities';
  @override String get colActionsAndAdvance => 'Actions & Advance';
  @override String get notesUnderFollowupFallback => 'Under operational follow-up';
  @override String get executeAndAdvanceStepBtn => 'Execute & Advance Step';
  @override String get noShipmentsInStage => 'No shipments registered in this selected stage';
  @override String get noShipmentsInStageDesc => 'You can select another stage from above or clear filters to view all shipments.';
  @override String lifecycleStepName(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'Freight Studies';
      case 'STEP_02':
        return 'Customs Studies';
      case 'STEP_03':
        return 'Regulatory Reqs';
      case 'STEP_04':
        return 'Finance Approvals';
      case 'STEP_05':
        return 'ACID Operations';
      case 'STEP_06':
        return 'Freight Booking';
      case 'STEP_07':
        return 'Freight Allocations';
      case 'STEP_08':
        return 'Draft Docs Review';
      case 'STEP_08_PO':
        return 'PO & Packing Reconciliation';
      case 'STEP_08_BL':
        return 'Draft B/L Review';
      case 'STEP_08_MATCH':
        return 'Smart Invoice vs B/L Match';
      case 'STEP_08_COO':
        return 'Draft COO & EUR.1';
      case 'STEP_08_COC':
        return 'Inspection Review COC';
      case 'STEP_09':
        return 'Docs Customs Approval';
      case 'STEP_10':
        return 'CargoX Upload';
      case 'STEP_11':
        return 'Originals Collection';
      case 'STEP_12':
        return 'Bank Form 4';
      case 'STEP_13':
        return 'Declaration 46';
      case 'STEP_14':
        return 'Clearance Follow-up';
      case 'STEP_15':
        return 'Drawing Samples';
      case 'STEP_16':
        return 'Discrepancy / Damage';
      case 'STEP_17':
        return 'Final Calculation';
      case 'STEP_18':
        return 'Demurrage & Detention';
      case 'STEP_19':
        return 'Warehouse GRN';
      case 'STEP_20':
        return 'Landed Cost';
      case 'STEP_21':
        return 'Final Closure';
      default:
        return stepCode;
    }
  }
  @override String lifecyclePhaseName(int phaseId, String fallbackAr, String fallbackEn) {
    switch (phaseId) {
      case 1:
        return 'Shipping & Customs Planning';
      case 2:
        return 'Budgeting & ACID Operations';
      case 3:
        return 'Booking & Draft Docs';
      case 4:
        return 'Digital Transfer & Banking';
      case 5:
        return 'Customs Clearance & Valuation';
      case 6:
        return 'Inbound Logistics & Landed Cost';
      default:
        return fallbackEn.isNotEmpty ? fallbackEn : fallbackAr;
    }
  }

  // Dialog & Advance / Skip / Hold Actions
  @override String stepActionCardTitle(String stepName) => 'Step Execution Card: $stepName';
  @override String get onHoldStatusTag => 'On-Hold';
  @override String get importFileLabel => 'Import File';
  @override String get importingCompanyLabel => 'Importer';
  @override String get foreignSupplierLabel => 'Foreign Supplier';
  @override String get purchaseOrderLabel => 'Purchase Order';
  @override String get estimatedValueLabel => 'Estimated Value';
  @override String get currentStepRequirementsHeader => 'Current Operational Step Data & Requirements:';
  @override String get targetNextPhasesHeader => 'Target Next Stages upon Completion (Multiple stages can be selected concurrently):';
  @override String get stepNotesHeader => 'Notes and Updates Log for this Step:';
  @override String get stepNotesHint => 'Enter operational notes, guidelines, or reference codes...';
  @override String get skipStepBtn => 'Skip Step';
  @override String get resumeShipmentBtn => 'Resume Shipment';
  @override String get holdShipmentBtn => 'Put on Hold';
  @override String get savingAndAdvancing => 'Saving & advancing...';
  @override String get completeAndAdvanceBtn => 'Complete Step & Advance Shipment';
  @override String stepAdvanceSuccessSnack(dynamic nextSteps, dynamic fileCode) => 'Step saved and next stages ($nextSteps) activated successfully for shipment $fileCode.';
  @override String get stepAdvanceErrorSnack => 'An error occurred while saving the step. Please check server.';
  @override String get skipStepDialogTitle => 'Skip this Stage';
  @override String skipStepConfirmText(dynamic stepName, dynamic fileCode) => 'Are you sure you want to skip the step ($stepName) for shipment $fileCode?';
  @override String get skipReasonLabel => 'Skip Reason *';
  @override String get skipReasonHint => 'e.g. CIF shipment (freight prepaid), or regulatory exemption...';
  @override String get skipReasonRequired => 'Skip reason is required';
  @override String get confirmSkipAndAdvanceBtn => 'Confirm Skip & Advance';
  @override String stepSkippedSuccessSnack(dynamic nextSteps, dynamic fileCode) => 'Step skipped successfully and next stages ($nextSteps) activated for shipment $fileCode.';
  @override String get shipmentResumedSuccessSnack => 'Shipment resumed and workflow continued successfully.';
  @override String get holdDialogTitle => 'Put Shipment on Hold';
  @override String holdConfirmText(dynamic fileCode, dynamic stepName) => 'Shipment $fileCode will be put on hold at this step ($stepName).';
  @override String get holdReasonLabel => 'Hold Reason *';
  @override String get holdReasonHint => 'e.g. Waiting for bank endorsement, or supplier revision...';
  @override String get holdReasonRequired => 'Hold reason is required';
  @override String get confirmHoldBtn => 'Confirm Put on Hold';
  @override String get shipmentHeldSuccessSnack => 'Shipment successfully put on hold.';
  @override String stepParam1Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'Shipping Line / Approved Carrier Name';
      case 'STEP_02':
        return 'Customs Tariff (HS Code)';
      case 'STEP_03':
        return 'Regulatory Authority / Inspection Body';
      case 'STEP_04':
        return 'Approved Supplier Advance Amount';
      case 'STEP_05':
        return 'Preliminary Shipment ID (ACID Number)';
      case 'STEP_06':
        return 'Booking Confirmation Reference #';
      case 'STEP_12':
        return 'Approved Bank Form 4 #';
      case 'STEP_13':
        return 'Customs Declaration 46 #';
      case 'STEP_19':
        return 'Goods Receipt Note # (GRN)';
      default:
        return 'Primary Step Reference';
    }
  }
  @override String stepParam2Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'Ocean Freight Rate per Container (\$)';
      case 'STEP_02':
        return 'Import Duty / Customs Rate %';
      case 'STEP_04':
        return 'Approved Remittance Bank';
      case 'STEP_05':
        return 'ACID Validity Period (Days)';
      case 'STEP_06':
        return 'Carrying Vessel Name';
      case 'STEP_12':
        return 'Issuing Bank';
      case 'STEP_13':
        return 'Port of Customs Release';
      case 'STEP_19':
        return 'Receiving Warehouse';
      default:
        return 'Secondary Operational Note';
    }
  }
  @override String stepParam3Label(String stepCode) {
    switch (stepCode) {
      case 'STEP_01':
        return 'Estimated Transit Time (Days)';
      case 'STEP_02':
        return 'VAT Rate %';
      case 'STEP_04':
        return 'SWIFT Reference Number';
      case 'STEP_05':
        return 'Foreign Factory Reg Number';
      case 'STEP_06':
        return 'Container Distribution & Package Count';
      case 'STEP_12':
        return 'Approved Amount on Form 4 (\$)';
      case 'STEP_13':
        return 'Approved Customs Broker';
      case 'STEP_19':
        return 'Inspection & Receiving Status';
      default:
        return 'Additional Information';
    }
  }

  // CL-003 Live Logistics Tracking Radar
  @override String get viewModeKanbanPhases => '6-Phase Stage Board';
  @override String get viewModeLiveRadar => 'Live Logistics Radar';
  @override String get kpiInTransit => 'In Transit / Sailing';
  @override String get kpiInPort => 'In Port / Clearing';
  @override String get kpiHighDemurrageRisk => 'Demurrage Risk';
  @override String get kpiUnderTesting => 'Under Lab Testing';
  @override String get kpiIncompleteDocs => 'Incomplete Docs';
  @override String get riskFilterAll => 'All Risk Levels';
  @override String get riskFilterCritical => 'Critical Risk';
  @override String get riskFilterWarning => 'Warning / Medium';
  @override String get riskFilterSafe => 'Safe';
  @override String get sampleFilterAll => 'All Sample Statuses';
  @override String get sampleFilterUnderTesting => 'Under Testing';
  @override String get sampleFilterApproved => 'Approved';
  @override String get sampleFilterRejected => 'Rejected';
  @override String get colVesselAndBl => 'Vessel, Line & B/L';
  @override String get colEtaCountdown => 'ETA & Port Dwell Time';
  @override String get colDemurrageRisk => 'Demurrage & Free Time Radar';
  @override String get colSampleTesting => 'Regulatory Samples';
  @override String get colDocReadiness => 'Document Readiness';
  @override String get colQuickActions => 'Quick Actions';
  @override String get btnDemurrageSimulator => 'Demurrage Tracker';
  @override String get btnRegulatorySamples => 'Requirements & Samples';
  @override String get btnCustoms46 => 'Customs 46';
  @override String get btnCentralArchive => 'Docs Archive';
  @override String get missingDocsTooltip => 'Missing Documents: ';
  @override String get allDocsCompleted => 'All required documents verified';
  @override String daysRemainingToEta(dynamic days) => '$days days to arrival';
  @override String daysInPort(dynamic days) => '$days days in port';
  @override String freeDaysRemainingBadge(dynamic days) => '$days free days remaining';
  @override String get demurrageIncurredBadge => 'Demurrage Incurred';

  // Screen 48: Lifecycle Board Exports & Helpers
  @override String get lifecycleExportTsvBtn => 'Export TSV';
  @override String get lifecycleExportExcelBtn => 'Export Unmerged Excel';
  @override String get lifecyclePrintPdfBtn => 'Print Landscape PDF';
  @override String get lifecycleCopySummaryBtn => 'Copy Operational Summary';
  @override String get lifecycleCopySummarySuccess => 'Operational summary copied to clipboard';
  @override String get lifecycleCopyDossierBtn => 'Copy Tracking Dossier';
  @override String get lifecycleCopyDossierSuccess => 'Tracking dossier copied to clipboard';
  @override String get lifecycleExportTsvDialogTitle => 'Save Lifecycle Board as TSV';
  @override String get lifecycleExportExcelDialogTitle => 'Save Lifecycle Board as Excel';
  @override String get lifecyclePrintPdfDialogTitle => 'Logistics Lifecycle & Stages Report';
  @override String get lifecycleDossierHeader => 'Shipment Lifecycle & Stage Board Report';
  @override String get radarDossierHeader => 'Live Logistics Tracking Radar Report';
  @override String get radarExportTsvDialogTitle => 'Save Logistics Radar as TSV';
  @override String get radarExportExcelDialogTitle => 'Save Logistics Radar as Excel';
  @override String get radarPrintPdfDialogTitle => 'Live Logistics Tracking Radar';
  @override String liveRadarError(dynamic error) => 'An error occurred while loading logistics radar:\n$error';
  @override String get searchLiveRadarHint => 'Search by file, B/L, supplier, or line...';
  @override String get colBillOfLadingPrefix => 'B/L';
  @override String get colEtaPrefix => 'ETA';
  @override String demurrageFeesFormatted(dynamic fx, dynamic egp) => 'Demurrage: \$$fx ($egp EGP)';
  @override String freeDaysConsumed(dynamic used, dynamic total) => 'Used $used of $total free days';
  @override String get colCarrierUnderPrep => 'Under Preparation';

  // Kanban TSV Headers
  @override String get lifecycleTsvHeaderFileCode => 'File Code';
  @override String get lifecycleTsvHeaderPreviousStep => 'Previous Step';
  @override String get lifecycleTsvHeaderCurrentStep => 'Current Step';
  @override String get lifecycleTsvHeaderNextStep => 'Next Step';
  @override String get lifecycleTsvHeaderCompany => 'Importer';
  @override String get lifecycleTsvHeaderSupplier => 'Foreign Supplier';
  @override String get lifecycleTsvHeaderPoNumber => 'PO Number';
  @override String get lifecycleTsvHeaderShipmentMode => 'Mode & Incoterm';
  @override String get lifecycleTsvHeaderEstimatedCost => 'Estimated Cost';
  @override String get lifecycleTsvHeaderStatus => 'Status';
  @override String get lifecycleTsvHeaderNotes => 'Notes & Activity';

  // Radar TSV Headers
  @override String get radarTsvHeaderFileCode => 'Shipment & Incoterm';
  @override String get radarTsvHeaderCarrierVessel => 'Carrier & Vessel';
  @override String get radarTsvHeaderBlRoute => 'B/L & Route';
  @override String get radarTsvHeaderArrivalStatus => 'Arrival & Dwell Time';
  @override String get radarTsvHeaderDemurrageRisk => 'Demurrage Risk';
  @override String get radarTsvHeaderTestingStatus => 'Regulatory Testing';
  @override String get radarTsvHeaderDocReadiness => 'Doc Readiness %';

  // ==========================================
  // Screen 49: Freight Quotations Comparison (FreightQuotationsComparisonScreen)
  // ==========================================
  @override
  String get freightQuotationsComparisonTitle => 'Freight Quotations Comparison';
  @override
  String get selectImportFileDropdownLabel => 'Select Import File to Compare Quotations';
  @override
  String get selectImportFileDropdownHint => 'Search by file code, supplier name, or importing company...';
  @override
  String get unknownSupplierFallback => 'Unknown Supplier';
  @override
  String freightQuotesLoadError(String error) => 'Error loading freight quotations: $error';
  @override
  String get selectImportFilePrompt => 'Please select an import file to view and compare quotations';
  @override
  String get noFreightQuotesForFile => 'No freight quotations registered for this file';
  @override
  String get notSelectedYet => 'Not Selected Yet';
  @override
  String get metricCheapestQuote => 'Cheapest';
  @override
  String get metricFastestQuote => 'Fastest';
  @override
  String transitDaysCount(dynamic days) => '$days Days';
  @override
  String get metricCurrentlySelected => 'Currently Awarded';
  @override
  String get badgeBestPrice => 'Best Price';
  @override
  String get unknownCarrierFallback => 'Unknown';
  @override
  String get totalFreightCostLabel => 'Total Cost';
  @override
  String get oceanFreightLabel => 'Ocean Freight';
  @override
  String get localChargesLabel => 'Local Charges';
  @override
  String get transitDurationLabel => 'Transit Duration';
  @override
  String get sailingDateLabel => 'Sailing Date';
  @override
  String get estimatedArrivalDateLabel => 'Estimated Arrival Date';
  @override
  String get remarksLabel => 'Remarks:';
  @override
  String get quoteAwardedBtn => 'Awarded';
  @override
  String get awardQuoteBtn => 'Award Quotation';
  @override
  String get freightQuoteSelectedSuccess => 'Freight quotation selected successfully';
  @override
  String get freightQuoteAwardedSuccess => 'Freight quotation awarded and approved successfully';
  @override
  String freightQuoteAwardError(String error) => 'Error awarding quotation: $error';
  @override
  String get freightQuotationsExportTsvBtn => 'Export TSV';
  @override
  String get freightQuotationsExportExcelBtn => 'Export Excel';
  @override
  String get freightQuotationsPrintPdfBtn => 'Print / PDF';
  @override
  String get freightQuotationsCopyDossierBtn => 'Copy Dossier';
  @override
  String get freightQuotationsCopyDossierSuccess => 'Comparison dossier copied to clipboard';
  @override
  String get freightQuotationsDossierHeader => 'Freight Quotations Comparison Dossier';
  @override
  String get freightQuotationsExportTsvDialogTitle => 'Export Quotations as TSV';
  @override
  String get freightQuotationsExportExcelDialogTitle => 'Export Quotations as Excel / CSV';
  @override
  String get freightQuotesTsvHeaderCarrier => 'Carrier / Shipping Line';
  @override
  String get freightQuotesTsvHeaderTotalCost => 'Total Cost';
  @override
  String get freightQuotesTsvHeaderOceanFreight => 'Ocean Freight';
  @override
  String get freightQuotesTsvHeaderLocalCharges => 'Local Charges';
  @override
  String get freightQuotesTsvHeaderInlandCharges => 'Inland Charges';
  @override
  String get freightQuotesTsvHeaderTransitDays => 'Transit Days';
  @override
  String get freightQuotesTsvHeaderSailingDate => 'Sailing Date';
  @override
  String get freightQuotesTsvHeaderArrivalDate => 'Estimated Arrival Date';
  @override
  String get freightQuotesTsvHeaderFreeDays => 'Free Days';
  @override
  String get freightQuotesTsvHeaderStatus => 'Award Status';
  @override
  String get freightQuotesTsvHeaderRemarks => 'Remarks';
  @override
  String get vesselNameLabel => 'Vessel Name';
  @override
  String get voyageNumberLabel => 'Voyage Number';
  @override
  String get oceanFreightCostLabel => 'Ocean Freight (USD)';
  @override
  String get localChargesCostLabel => 'Local Charges (USD)';
  @override
  String get inlandCostLabel => 'Inland Transport (USD)';
  @override
  String get sailingDateFormLabel => 'Sailing Date';
  @override
  String get arrivalDateFormLabel => 'Estimated Arrival Date';
  @override
  String get freeDaysPodFormLabel => 'Free Days at Port';
  @override
  String get remarksFormLabel => 'Quotation Remarks';

  // ==========================================
  // Screen 50: Landed Cost Comparison (LandedCostComparisonScreen)
  // ==========================================
  @override
  String landedCostComparisonTitle(dynamic fileCode) => 'Landed Cost Comparison — Estimated vs Actual [$fileCode]';
  @override
  String landedCostLoadError(dynamic error) => 'Error loading landed cost data: $error';
  @override
  String get noLandedCostDataRegistered => 'No Landed Cost data registered yet for this file';
  @override
  String get expenseBreakdownHeader => 'Actual Expense Breakdown';
  @override
  String get itemLandedCostHeader => 'Item Landed Cost Allocation';
  @override
  String get estimatedCostHeader => 'Estimated Cost';
  @override
  String get actualCostHeader => 'Actual Cost';
  @override
  String get fobValueCardTitle => 'FOB Value';
  @override
  String get totalExpensesCardTitle => 'Total Expenses';
  @override
  String get totalLandedCostCardTitle => 'Total Landed Cost';
  @override
  String get estAbbreviation => 'Est.';
  @override
  String get actAbbreviation => 'Act.';
  @override
  String get colExpenseCategory => 'Category';
  @override
  String get colExpenseProvider => 'Provider / Supplier';
  @override
  String get colExpenseCurrency => 'Currency';
  @override
  String get colExpenseAmountFx => 'Foreign Amount (FX)';
  @override
  String get colExpenseExchangeRate => 'Exchange Rate';
  @override
  String get colExpenseAmountEgp => 'Amount (EGP)';
  @override
  String get colItemCode => 'Item Code';
  @override
  String get colItemName => 'Item Name';
  @override
  String get colItemQty => 'Quantity';
  @override
  String get colFobUnitPrice => 'FOB Unit Price';
  @override
  String get colLandedUnitPrice => 'Unit Landed Cost';
  @override
  String get colCostMarkupFactor => 'Markup Factor';
  @override
  String landedCostOverBudgetBanner(dynamic percent) => 'Actual cost exceeded estimated budget by $percent%';
  @override
  String landedCostUnderBudgetBanner(dynamic percent) => 'Project saved $percent% under the approved budget';
  @override
  String expenseCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'freight':
        return 'Freight & Logistics';
      case 'customs':
        return 'Customs & Duties';
      case 'clearance':
        return 'Clearance Fees';
      case 'transport':
        return 'Inland Transport';
      case 'storage':
        return 'Storage & Demurrage';
      default:
        return 'Other Expenses';
    }
  }

  // Screen 50 Export & Incoterms Additions
  @override
  String get landedCostExportTsvBtn => 'Export TSV';
  @override
  String get landedCostExportExcelBtn => 'Export Excel';
  @override
  String get landedCostPrintPdfBtn => 'Print Vector PDF';
  @override
  String get landedCostCopyDossierBtn => 'Copy Cost Summary';
  @override
  String get landedCostCopyDossierSuccess => 'Landed cost summary copied to clipboard successfully';
  @override
  String get landedCostDossierHeader => 'Shipment Landed Cost Comparison Summary';
  @override
  String get landedCostExportTsvDialogTitle => 'Export Landed Cost Comparison as TSV';
  @override
  String get landedCostExportExcelDialogTitle => 'Export Landed Cost Comparison to Excel';
  @override
  String get incoRuleExporterCoversLabel => 'Included in Invoice (Exporter):';
  @override
  String get incoRuleImporterCoversLabel => 'Added Landed Cost Expenses (Importer):';
  @override
  String get incoCifRuleTitle => 'CIF / CIP Delivery Rule (Cost, Insurance & Freight)';
  @override
  String get incoCifRuleDesc => 'Purchase invoice includes international freight and marine insurance. Importer Landed Cost = (CIF Invoice + Customs Duties & Taxes + Port & Clearance Fees + Local Transport).';
  @override
  String get incoCifExporterCovers => 'Ocean Freight • Marine Insurance • Export Clearance';
  @override
  String get incoCifImporterCovers => 'Customs & Taxes • Clearance Fees • Port Terminal Fees • Local Inland Transport';
  @override
  String get incoCfrRuleTitle => 'CFR / CPT Delivery Rule (Cost & Freight)';
  @override
  String get incoCfrRuleDesc => 'Purchase invoice covers international freight. Importer Landed Cost = (CFR Invoice + Marine Insurance + Customs Duties & Taxes + Clearance + Local Transport).';
  @override
  String get incoCfrExporterCovers => 'Ocean Freight • Export Clearance';
  @override
  String get incoCfrImporterCovers => 'Marine Insurance • Customs & Taxes • Clearance • Local Transport';
  @override
  String get incoExwRuleTitle => 'EXW Delivery Rule (Ex Works - Factory Gate)';
  @override
  String get incoExwRuleDesc => 'Invoice covers factory goods only. Importer bears all origin-to-destination costs: (EXW Invoice + Origin Trucking + Export Clearance + Freight + Insurance + Customs + Clearance + Local Transport).';
  @override
  String get incoExwExporterCovers => 'Goods Packaging at Factory';
  @override
  String get incoExwImporterCovers => 'Origin Trucking & Export • Freight & Insurance • Customs & Taxes • Clearance & Transport';
  @override
  String get incoDdpRuleTitle => 'DDP Delivery Rule (Delivered Duty Paid)';
  @override
  String get incoDdpRuleDesc => 'Invoice covers freight, insurance, customs duties, and local delivery. Importer only bears extraordinary storage/handling fees if incurred.';
  @override
  String get incoDdpExporterCovers => 'Freight & Insurance • Customs Duties & Taxes • Delivery to Warehouse';
  @override
  String get incoDdpImporterCovers => 'Unloading / Extraordinary Storage';
  @override
  String get incoFobRuleTitle => 'FOB / FCA Delivery Rule (Free On Board)';
  @override
  String get incoFobRuleDesc => 'Invoice covers goods loaded on vessel at origin port. Importer Landed Cost = (FOB Invoice + Ocean Freight + Marine Insurance + Customs Duties & Taxes + Clearance + Local Transport).';
  @override
  String get incoFobExporterCovers => 'Origin Transport & Export • Loading on Vessel';
  @override
  String get incoFobImporterCovers => 'Ocean Freight • Marine Insurance • Customs & Taxes • Clearance & Local Transport';
  @override
  String get landedCostTsvHeaderSection => 'Section';
  @override
  String get landedCostTsvHeaderCodeOrCategory => 'Code / Category';
  @override
  String get landedCostTsvHeaderNameOrProvider => 'Name / Provider';
  @override
  String get landedCostTsvHeaderQtyOrCurrency => 'Qty / Currency';
  @override
  String get landedCostTsvHeaderUnitPriceOrFx => 'Unit Price / Foreign FX';
  @override
  String get landedCostTsvHeaderExchangeRate => 'Exchange Rate';
  @override
  String get landedCostTsvHeaderTotalCostEgp => 'Total Cost (EGP)';
  @override
  String get landedCostTsvHeaderMarkupOrVariance => 'Markup / Variance';

  // ==========================================
  // Screen 51: Central Docs Hub (CentralDocsArchiveScreen)
  // ==========================================
  @override
  String get centralDocsArchiveTitle => 'Central Documents & Rectifications Archive';
  @override
  String get closeAndReturn => 'Close & Return';
  @override
  String get selectCentralArchiveFileLabel => 'Select Shipment File for Central Archive';
  @override
  String get selectCentralArchiveFileHint => 'Search by file code, importer, or supplier...';
  @override
  String get refreshArchiveBtn => 'Refresh Archive';
  @override
  String get selectShipmentFilePrompt => 'Please select a shipment file from the dropdown above';
  @override
  String get centralArchivePlaceholderDesc => 'Final commercial invoice, packing list, draft B/L, draft COO, inspection certificate, and rectification summaries will be displayed immediately.';
  @override
  String get centralArchiveLoadingPrompt => 'Fetching and consolidating central archive and reconciling documents...';
  @override
  String centralArchiveLoadError(dynamic error) => 'Error fetching central archive data: $error';
  @override
  String get readinessReadyForRelease => '100% Ready for Customs Release & CargoX Upload';
  @override
  String get readinessActionRequired => 'Critical Rectifications Required Before Original Issuance';
  @override
  String get readinessInReview => 'Document Drafts Under Review & Completion';
  @override
  String fileCodeLabel(dynamic code) => 'File Code: $code';
  @override
  String customsFileNumberLabel(dynamic num) => 'Customs File No: $num';
  @override
  String get importerCompanyLabel => 'Importer Company:';
  @override
  String get exporterSupplierLabel => 'Foreign Supplier / Exporter:';
  @override
  String get acidNumberLabel => 'ACID Registration No:';
  @override
  String get shippingRouteLabel => 'Shipping Route (POL ➔ POD):';
  @override
  String get totalPackagesAndWeightLabel => 'Total Packages & Weight:';
  @override
  String get totalInvoiceValueLabel => 'Total Invoice Value:';
  @override
  String packagesCountText(dynamic pkgs, dynamic weight) => '$pkgs packages | $weight KG';
  @override
  String get complianceReportHeader => 'Import Requirements & Regulatory Compliance Report';
  @override
  String complianceSummaryTag(dynamic origin, dynamic hsCode, dynamic commodity) => 'Origin: $origin | HS Code: $hsCode | $commodity';
  @override
  String get chipCooLabel => 'Certificate of Origin';
  @override
  String cooRequiredText(dynamic type) => 'Required ($type)';
  @override
  String get cooNotRequiredText => 'Waived or Not Required';
  @override
  String get chipVocLabel => 'Pre-Shipment Inspection (VoC)';
  @override
  String inspRequiredText(dynamic agency) => 'Required ($agency)';
  @override
  String get inspNotRequiredText => 'Exempt from Inspection';
  @override
  String get chipDecree43Label => 'Decree 43 Factory Registration';
  @override
  String get decree43WhiteListed => 'White-Listed';
  @override
  String get decree43RegistrationRequired => 'Registration Required';
  @override
  String get decree43NotApplicable => 'Not Applicable';
  @override
  String get masterRectificationsHeader => 'Summary of Required Rectifications & Discrepancies:';
  @override
  String get copySupplierEmailBtn => 'Copy Supplier Email';
  @override
  String get copySupplierEmailSuccess => 'Supplier rectification email copied successfully';
  @override
  String get copyWhatsAppBtn => 'Copy WhatsApp Message';
  @override
  String get copyWhatsAppSuccess => 'WhatsApp message copied successfully';
  @override
  String get noDiscrepanciesSuccessMessage => 'No discrepancies or modifications required. All drafts are perfectly matched and ready for CargoX upload.';
  @override
  String get severityCritical => 'Critical Blocker';
  @override
  String get severityWarning => 'Warning Alert';
  @override
  String discrepancyIssueLabel(dynamic issue) => 'Issue: $issue';
  @override
  String discrepancyRectificationLabel(dynamic rect) => 'Required Action: $rect';
  @override
  String get fiveCoreDocsSectionTitle => 'Consolidated 5 Core Documents Archive & Modification Details:';
  @override
  String get docTitleCommercialInvoice => '1. Final Commercial Invoice';
  @override
  String get docTitlePackingList => '2. Final Packing List';
  @override
  String get docTitleBillOfLading => '3. Draft Bill of Lading';
  @override
  String get docTitleCertificateOfOrigin => '4. Draft Certificate of Origin / EUR.1';
  @override
  String get docTitleInspectionCertificate => '5. Draft Inspection & Quality Certificate (VoC / COC)';
  @override
  String get docMandatoryCore => 'Mandatory Core';
  @override
  String get docConditional => 'Conditional / As Applicable';
  @override
  String docReferenceLabel(dynamic ref) => 'Ref: $ref';
  @override
  String get docStatusWaived => 'Waived / Not Required';
  @override
  String get docStatusApproved => 'Approved Successfully';
  @override
  String get docStatusModificationsRequested => 'Modifications Requested';
  @override
  String get docStatusReviewPending => 'Review Pending';
  @override
  String get docStatusNotStarted => 'Not Uploaded Yet';
  @override
  String get docModificationsRequestedTitle => 'Modifications Required for This Document:';
  @override
  String get docWaivedDefaultDesc => 'This document is waived or legally exempt and does not impact customs release readiness.';
  @override
  String get docNoDiscrepanciesDesc => 'This document contains no discrepancies or issues.';

  // Screen 51 Export & Toolbar Getters
  @override
  String get centralDocsExportTsvBtn => 'Export TSV Table';
  @override
  String get centralDocsExportExcelBtn => 'Export to Excel';
  @override
  String get centralDocsPrintPdfBtn => 'Print & Save PDF';
  @override
  String get centralDocsCopyDossierBtn => 'Copy Central Dossier';
  @override
  String get centralDocsCopyDossierSuccess => 'Central documents archive dossier copied successfully';
  @override
  String get centralDocsDossierHeader => 'Central Documents & Rectifications Archive Dossier';
  @override
  String get centralDocsExportTsvDialogTitle => 'Save Central Archive TSV Table';
  @override
  String get centralDocsExportExcelDialogTitle => 'Save Central Archive Excel Spreadsheet';
  @override
  String get centralDocsTsvHeaderDocName => 'Document Name';
  @override
  String get centralDocsTsvHeaderDocType => 'Requirement Type';
  @override
  String get centralDocsTsvHeaderRefNo => 'Reference Number';
  @override
  String get centralDocsTsvHeaderStatus => 'Status';
  @override
  String get centralDocsTsvHeaderDiscrepanciesCount => 'Discrepancies Count';
  @override
  String get centralDocsTsvHeaderIssues => 'Issues & Discrepancies';
  @override
  String get centralDocsTsvHeaderRectifications => 'Rectification Instructions';
  @override
  String get centralDocsTsvHeaderLegalNote => 'Legal Note / Exemption Reason';
  @override
  String get centralDocsDossierComplianceTitle => 'Import Requirements & Regulatory Compliance';
  @override
  String get centralDocsDossierCoreDocsTitle => 'Core & Conditional Documents';
  @override
  String get centralDocsDossierDiscrepanciesTitle => 'Discrepancies & Rectifications Log';
  @override
  String get centralDocsCopyDetailSuccess => 'Document detail copied successfully';
  @override
  String get centralDocsCopyDiscrepancySuccess => 'Rectification details copied successfully';

  // Screen 53: Draft Inspection COC (ShipmentDraftDocsScreen & InspectionReviewTab)
  @override
  String get inspStepRequirements => 'Inspection & Conformity Requirements';
  @override
  String get inspStepDraftInput => 'Draft Input & Extraction';
  @override
  String get inspStepDiscrepancyMatrix => 'Discrepancy & Matching Matrix';
  @override
  String get inspStepRegistry => 'Inspection Certificates Registry';
  @override
  String existingInspectionReviewBanner(dynamic code, dynamic status) =>
      'An inspection review is already registered for this file [Session Code: $code - Status: $status]. Updating this existing record to prevent duplicate entries.';
  @override
  String get inspectionRegistryBtn => 'Certificates Registry';
  @override
  String get inspRequirementsHeader => 'Generate Pre-Shipment Inspection & COC Requirements';
  @override
  String get selectInspectionFileLabel => 'Select Import File *';
  @override
  String get selectInspectionFileHint => 'Search by file code...';
  @override
  String get inspectionCertTypeLabel => 'Inspection Certificate Type *';
  @override
  String get inspectionCertTypeHint => 'Select certificate type...';
  @override
  String get optInspectionCoc => 'Certificate of Conformity (COC)';
  @override
  String get optInspectionCoa => 'Certificate of Analysis (COA)';
  @override
  String get optInspectionVoc => 'Verification of Conformity (VOC)';
  @override
  String get optInspectionPsi => 'Pre-Shipment Inspection (PSI)';
  @override
  String get inspectionAgencyLabel => 'International Inspection Agency *';
  @override
  String get inspectionAgencyHint => 'Select inspection agency...';
  @override
  String get openInspectionPreviewBtn => 'Open Preview & Export';
  @override
  String get nextInspectionInputBtn => 'Next: Draft Input';
  @override
  String inspectionVisualPreviewDialogTitle(dynamic agency, dynamic certType) =>
      'Visual Draft Inspection Preview: $agency ($certType)';
  @override
  String get applyInspectionDraftDataBtn => 'Apply & Auto-fill Fields';
  @override
  String get inspectionDraftDataAppliedSuccess => 'Inspection draft data applied successfully';
  @override
  String get inspDraftInputHeader => 'Inspection Certificate Draft Data Input & Extraction';
  @override
  String get runInspectionComparisonBtn => 'Run Matching & Verification';
  @override
  String get linkedInspectionFileLabel => 'Select Linked Import File *';
  @override
  String get linkedInspectionFileHint => 'Search by file code or company...';
  @override
  String get pleaseSelectInspectionFileWarning =>
      'Please select an import file first to extract data and match against system records.';
  @override
  String get certNumberFieldLabel => 'Draft Certificate Number *';
  @override
  String get regulatoryAuthorityFieldLabel => 'Competent Egyptian Regulatory Authority *';
  @override
  String get inspectedInvoiceNumberFieldLabel => 'Inspected Invoice Number *';
  @override
  String get exporterShipperFieldLabel => 'Exporter / Shipper Name *';
  @override
  String get importerApplicantFieldLabel => 'Importer / Applicant Name *';
  @override
  String get standardSpecFieldLabel => 'Adopted Standard Specification *';
  @override
  String get smartUploadInspectionBtn => 'Smart Upload & Extract Inspection Certificate';
  @override
  String get rawTextInspectionHeader => 'Inspection Certificate Raw Text / OCR Dump';
  @override
  String get smartExtractFromTextBtn => 'Smart Extract & Match from Text';
  @override
  String get rawTextInspectionHint => 'Paste full inspection certificate text here (e.g. Cotecna, TÜV, or SGS)...';
  @override
  String get pleaseSelectFileFirstPrompt => 'Please select an import file first';
  @override
  String inspectionComparisonError(dynamic err) => 'Error during inspection comparison: $err';
  @override
  String get overrideReasonMandatoryWarning =>
      'Approval justification reason is required before saving discrepancies, or click Return to Edit to contact supplier.';
  @override
  String get saveInspectionReviewSuccess => 'Inspection review session saved to registry successfully';
  @override
  String saveInspectionReviewError(dynamic err) => 'Error saving inspection review: $err';
  @override
  String get generateDraftSelectFileFirstPrompt => 'Please select an import file first to generate inspection draft';
  @override
  String get cancelAndClose => 'Cancel & Close ✕';
  @override
  String get exportPdfBtn => 'Export PDF';
  @override
  String get exportExcelBtn => 'Export Excel';
  @override
  String generateDraftError(dynamic err) => 'Error generating draft: $err';
  @override
  String get pasteRawTextFirstPrompt => 'Please paste inspection certificate text or upload a file first';
  @override
  String inspectionOcrWarningsAlert(dynamic warnings) => 'Extraction warnings: $warnings';
  @override
  String get inspectionDraft48hWarningAlert =>
      'Draft certificate detected — please confirm inspection within 48h to prevent release rejection.';
  @override
  String get inspectionExtractionSuccess => 'Inspection certificate data extracted and matched successfully';
  @override
  String get mustSelectFileForMatrixWarning => 'An import file must be selected to display comparison matrix';
  @override
  String get returnToSelectFileBtn => 'Return to Select File';
  @override
  String get pleaseRunComparisonPrompt => 'Please run matching in the previous step to review discrepancy matrix';
  @override
  String get returnToRunComparisonBtn => 'Return to Run Matching';
  @override
  String get hasCriticalMismatchStatus => 'Critical discrepancies found in inspection certificate data';
  @override
  String get hasMinorDiscrepanciesStatus => 'Minor discrepancies found in inspection certificate data';
  @override
  String get inspectionConforms100Status => 'Inspection certificate is 100% conforming';
  @override
  String get exportingInspectionPdfPrompt => 'Exporting inspection conformity report...';
  @override
  String get copiedInspectionExcelSuccess => 'Conformity data copied and exported to spreadsheet successfully';
  @override
  String get saveToInspectionRegistryBtn => 'Save to Registry';
  @override
  String get colInspField => 'Field';
  @override
  String get colInspSystemValue => 'System Value';
  @override
  String get colInspDraftValue => 'Draft Value';
  @override
  String get colInspMatchStatus => 'Match Status';
  @override
  String get colInspDetails => 'Details';
  @override
  String get inspOverrideReasonBoxTitle => 'Justification for Accepting Discrepancies (Mandatory for Approval):';
  @override
  String get inspOverrideReasonBoxDesc =>
      'When discrepancies exist in the inspection certificate, record the justification reason or return to edit and contact supplier.';
  @override
  String get inspOverrideReasonFieldLabel => 'Approval Justification Reason *';
  @override
  String get inspOverrideReasonFieldHint => 'Enter discrepancy approval reasons here before saving...';
  @override
  String get approveAndSaveWithReasonBtn => 'Approve & Save with Stated Reason';
  @override
  String get returnToEditAndContactSupplierBtn => 'Return to Edit Draft & Contact Supplier';
  @override
  String inspReviewsRegistryTitle(dynamic count) => 'Inspection & Conformity Reviews Registry ($count sessions)';
  @override
  String get startNewInspReviewBtn => 'Start New Review';
  @override
  String get noInspReviewsYet => 'No inspection review sessions recorded yet.';
  @override
  String get colInspSessionCode => 'Session Code';
  @override
  String get colInspCertType => 'Inspection Type';
  @override
  String get colInspAgency => 'Inspection Agency';
  @override
  String get colInspCertNo => 'Certificate No.';
  @override
  String get colInspStatus => 'Status';
  @override
  String get colInspCreatedAt => 'Created At';
  @override
  String get colInspActions => 'Actions';
  @override
  String get editInspSessionTooltip => 'Edit Session';
  @override
  String get viewInspDetailsTooltip => 'View Details';
  @override
  String get downloadInspPdfTooltip => 'Download Report';
  @override
  String get deleteInspSessionTooltip => 'Delete Session';
  @override
  String loadedInspSessionForEdit(dynamic code) => 'Session ($code) loaded for editing';
  @override
  String inspDetailsDialogTitle(dynamic code) => 'Inspection Review Session Details: $code';
  @override
  String get tileInspTypeAndAgency => 'Inspection Type & Issuing Agency';
  @override
  String get tileInspCertNoAndStatus => 'Certificate Number & Status';
  @override
  String get tileInspOverrideReason => 'Discrepancy Approval Justification';
  @override
  String get sectionInspDiscrepancyMatrix => 'Discrepancies & Conformity Matrix:';
  @override
  String get confirmDeleteInspSessionTitle => 'Confirm Delete Inspection Review Session';
  @override
  String confirmDeleteInspSessionContent(dynamic code, dynamic cert) =>
      'Are you sure you want to delete review session ($code) for certificate ($cert)?';
  @override
  String get inspSessionDeletedSuccess => 'Inspection review session deleted successfully';
  @override
  String deleteInspSessionError(dynamic err) => 'Error deleting session: $err';
  @override
  String visualDraftInspectionToolbarTitle(dynamic agency, dynamic certType) =>
      'Draft Inspection & Conformity Certificate: $agency ($certType)';
  @override
  String get liveRefreshTooltip => 'Live refresh imported data';
  @override
  String get copyInspectionDataBtn => 'Copy Data';
  @override
  String get copiedInspectionDataSuccess => 'Inspection certificate data copied to clipboard';
  @override
  String get saveExcelCsvBtn => 'Save Spreadsheet (CSV)';
  @override
  String get excelReadySuccess => 'Inspection spreadsheet data prepared successfully';
  @override
  String get savePrintPdfBtn => 'Save & Print PDF';
  @override
  String get egyptVerificationOfConformityHeader => 'EGYPT MANDATORY VERIFICATION OF CONFORMITY (GOEIC / NFSA)';
  @override
  String get countryOfOriginHeader => 'Country / Countries of Origin:';
  @override
  String get hsCodesHeader => 'H.S. Codes:';
  @override
  String get commercialInvoicesHeader => 'Commercial Invoices Subject to Inspection:';
  @override
  String get colInvoiceAmountCurrency => 'Invoice Amount / Currency';
  @override
  String get colInvoiceNo => 'Invoice No.';
  @override
  String get colInvoiceDate => 'Invoice Date';
  @override
  String get colIncoterm => 'Incoterm';
  @override
  String methodOfShipmentLabel(dynamic val) => 'Method of Shipment: $val';
  @override
  String countryOfShipmentLabel(dynamic val) => 'Country of Shipment: $val';
  @override
  String pointOfEntryLabel(dynamic val) => 'Point of Entry: $val';
  @override
  String totalDeclaredValueLabel(dynamic val) => 'Total Declared Value: $val';
  @override
  String get inspectedItemsHeader => 'Goods Description, Quantities & Adopted Standards:';
  @override
  String get colItemNo => '#';
  @override
  String get colQuantity => 'Quantity';
  @override
  String get colOrigin => 'Origin';
  @override
  String get colProductType => 'Product Type';
  @override
  String get colDescriptionBrandModel => 'Description (Brand/Model)';
  @override
  String get colAdoptedStandard => 'Adopted Standard';
  @override
  String placeOfInspectionLabel(dynamic val) => 'Place of Inspection: $val';
  @override
  String dateOfInspectionLabel(dynamic val) => 'Date of Inspection: $val';
  @override
  String issuingOfficeLabel(dynamic val) => 'Issuing Office: $val';
  @override
  String get egyptianMandatoryStandardsHeader => 'Egyptian Mandatory Standards & Test Protocols (ES Standards Tested):';
  @override
  String get conformityAssessmentResultConforming => 'CONFORMITY ASSESSMENT RESULT: CONFORMING & SAFE FOR RELEASE';
  @override
  String authorizedAgencyLabel(dynamic val) => 'Authorized Agency: $val';
  @override
  String get egyptianCustomsComplianceHeader => 'Egyptian Customs & Regulatory Compliance (GOEIC / NFSA)';
  @override
  String get importerCellLabel => 'Importer (Name, Address & Tax ID):';
  @override
  String get exporterCellLabel => 'Exporter & Producer (Name & Address):';
  @override
  String get exportTsvBtn => 'Export TSV';
  @override
  String get copyDossierBtn => 'Copy Full Dossier';
  @override
  String get copiedDossierSuccess => 'Inspection review dossier copied to clipboard successfully';
  @override
  String get copiedInspectionTsvSuccess => 'Inspection TSV data exported successfully';
  @override
  String get exportTsvDialogTitle => 'Save Inspection TSV File';
  @override
  String get exportExcelDialogTitle => 'Save Inspection Spreadsheet File';
  @override
  String get exportPdfDialogTitle => 'Save Inspection Certificate PDF';
  @override
  String cocNoPrefix(dynamic val) => 'COC NO: $val';
  @override
  String acidNoPrefix(dynamic val) => 'ACID NO: $val';
  @override
  String get certHeaderCocVoc => 'CERTIFICATE OF CONFORMITY (COC / VOC)';
  @override
  String get noticeBannerDraftConfirm => 'DRAFT VERIFICATION — PLEASE CONFIRM WITHIN 48 HOURS AFTER WHICH WE SHALL PROCEED TO ISSUE';
  @override
  String get importerTaxIdHeader => 'Importer (Name, Address & Tax ID)';
  @override
  String get exporterProducerHeader => 'Exporter & Producer (Name & Address)';
  @override
  String get inspectionDossierHeader => 'INSPECTION & CONFORMITY REVIEW DOSSIER';
  @override
  String get inspectionDossierBasicInfo => 'Basic Inspection Information & Parties';
  @override
  String get inspectionDossierInvoices => 'Commercial Invoices Subject to Inspection';
  @override
  String get inspectionDossierItems => 'Inspected Goods & Adopted Standards';
  @override
  String get inspectionDossierStandards => 'Egyptian Mandatory Standards & Protocols';
  @override
  String get inspectionDossierDiscrepancies => 'Discrepancy Matrix & Verification Results';
  @override
  String get colTsvItemNo => '#';
  @override
  String get colTsvProductType => 'Product Type';
  @override
  String get colTsvOrigin => 'Country of Origin';
  @override
  String get colTsvDescription => 'Description (Brand/Model)';
  @override
  String get colTsvQuantity => 'Quantity';
  @override
  String get colTsvStandard => 'Adopted Standard';

  // ── Screen 54: CargoX Blockchain Hub & Standard Commercial Invoice ──────────
  @override
  String get cargoxHubTitle => 'CargoX & ACI Blockchain Dispatch Hub';
  @override
  String get cargoxLiveRefreshTooltip => 'Live Refresh';
  @override
  String get cargoxEmbeddedTitle => 'CargoX & ACI Dispatch Hub:';
  @override
  String get cargoxTabStandardInvoice => 'Standard Commercial Invoice';
  @override
  String get cargoxTabCreateEnvelope => 'Create CargoX Envelope';
  @override
  String get cargoxTabTrackingHub => 'Blockchain Envelopes Hub';
  @override
  String get cargoxTabManifestViewer => 'ACI Digital Manifest Viewer';
  @override
  String get cargoxSegStandardInvoice => 'Standard Invoice 📊';
  @override
  String get cargoxSegCreateEnvelope => 'Prepare Envelope 📦';
  @override
  String get cargoxSegTrackingHub => 'Blockchain Tracking 🔗';
  @override
  String get cargoxSegManifestViewer => 'Digital Manifest 📜';

  // Tab 1: Envelope Creation
  @override
  String get cargoxEnvelopeGenTitle => 'CargoX Blockchain Envelope Generator';
  @override
  String get cargoxEnvelopeGenDesc => 'Digital envelope created, cryptographically signed (PKI), and linked to ACID & approved docs before Egyptian Customs transfer.';
  @override
  String get cargoxSection1ShipmentAcid => '1. Shipment Data & ACID Linkage:';
  @override
  String get cargoxImportFileField => 'Import File *';
  @override
  String get cargoxSearchFileHint => 'Search import file...';
  @override
  String get cargoxUnlinkedOption => '-- None / Unlinked --';
  @override
  String get cargoxAcidNumberField => 'ACID Number (19 Digits) *';
  @override
  String get cargoxAcidValidationDigits => 'Must be 19 digits';
  @override
  String get cargoxBlNumberField => 'B/L Number';
  @override
  String get cargoxImporterCompanyField => 'Importer Company *';
  @override
  String get cargoxForeignSupplierField => 'Foreign Exporter *';
  @override
  String get cargoxSupplierCargoxIdField => 'Supplier CargoX ID *';
  @override
  String get cargoxSection2AttachedDocs => '2. Attached Documents Checklist:';
  @override
  String get cargoxRestoreDefaultDocsBtn => 'Restore Standard Checklist 📄';
  @override
  String get cargoxColDocType => 'Document Type';
  @override
  String get cargoxColDocNumber => 'Reference Number';
  @override
  String get cargoxColFileName => 'File Name';
  @override
  String get cargoxColFileSize => 'Size (KB)';
  @override
  String get cargoxColAcidMatch => 'ACID Match';
  @override
  String get cargoxColActions => 'Delete';
  @override
  String get cargoxDocMatchedBadge => '🟢 100% Matched';
  @override
  String get cargoxAddDocToEnvelopeBtn => 'Add Document to Envelope';
  @override
  String get cargoxAddDocDialogTitle => 'Add New Document to Envelope';
  @override
  String get cargoxDocTypeField => 'Document Type *';
  @override
  String get cargoxDocNumberField => 'Document Number';
  @override
  String get cargoxDocFileNameField => 'File Name *';
  @override
  String get cargoxAddDocSubmitBtn => 'Add to Envelope';
  @override
  String get cargoxGenerateAndSignEnvelopeBtn => 'Generate & Sign CargoX Envelope ⚡';
  @override
  String get cargoxAtLeastOneDocError => 'Please attach at least one document in the envelope.';
  @override
  String cargoxEnvelopeCreatedSuccess(dynamic code) => 'CargoX envelope generated and signed successfully ($code) ⚡';
  @override
  String get cargoxEnvelopeCreateError => 'Error creating envelope';

  // Tab 2: Tracking Hub
  @override
  String get cargoxMetricTotalEnvelopes => 'Total Envelopes';
  @override
  String get cargoxMetricAcceptedCustoms => 'Accepted by Customs';
  @override
  String get cargoxMetricInProgress => 'In Progress / Uploaded';
  @override
  String get cargoxMetricAcidVerified => '100% ACID Verified';
  @override
  String get cargoxSearchEnvelopesHint => 'Search envelope code, ACID, supplier, or B/L...';
  @override
  String get cargoxFilterAllStatuses => 'All Statuses';
  @override
  String get cargoxFilterDraft => 'Draft';
  @override
  String get cargoxFilterUploaded => 'Uploaded';
  @override
  String get cargoxFilterAccepted => 'Accepted';
  @override
  String get cargoxPrepareNewEnvelopeBtn => 'Prepare New Envelope ➕';
  @override
  String get cargoxNoEnvelopesFound => 'No envelopes matching search criteria';
  @override
  String get cargoxMetaAcidNumber => 'ACID Number:';
  @override
  String get cargoxMetaSupplier => 'Foreign Supplier:';
  @override
  String get cargoxMetaSupplierCargoxId => 'Supplier CargoX ID:';
  @override
  String get cargoxMetaBlNumber => 'B/L Number:';
  @override
  String get cargoxMetaPendingIssuance => 'Pending Issuance';
  @override
  String get cargoxMetaBlockchainTxHash => 'Blockchain TX Hash:';
  @override
  String get cargoxMetaCustomsReceipt => 'Customs Receipt:';
  @override
  String get cargoxCopiedToClipboard => '📋 Copied to clipboard';
  @override
  String get cargoxCheckAcidBtn => 'Verify ACID 🛡️';
  @override
  String get cargoxDigitalManifestBtn => 'Digital Manifest 📜';
  @override
  String get cargoxSealAndTransferBtn => 'Seal & Transfer to Customs ⚡';
  @override
  String get cargoxDeliveredAndAcceptedBadge => '🟢 Delivered & Accepted by Customs';
  @override
  String cargoxAcidReportDialogTitle(dynamic code) => 'ACID Consistency Report ($code)';
  @override
  String cargoxTargetAcidLabel(dynamic acid) => 'Target ACID Number: $acid';
  @override
  String cargoxMatchRatioLabel(dynamic match, dynamic total) => 'Consistency: $match of $total documents';
  @override
  String get cargoxConfirmSealTransferTitle => 'Confirm Seal & Transfer to Customs';
  @override
  String cargoxConfirmSealTransferContent(dynamic code) => 'Are you sure you want to seal envelope ($code), cryptographically sign, and transfer to Egyptian Customs (Nafeza)?';
  @override
  String get cargoxConfirmTransferBtn => 'Confirm Customs Transfer';
  @override
  String cargoxSealSuccessSnackbar(dynamic msg, dynamic receipt) => '✅ $msg (Receipt: $receipt)';
  @override
  String get cargoxAcidCheckError => 'Error checking ACID consistency';
  @override
  String get cargoxTransferError => 'Error transferring envelope to customs';
  @override
  String get cargoxFetchManifestError => 'Error fetching digital manifest';

  // Tab 3: Manifest Viewer
  @override
  String cargoxManifestTitle(dynamic code, dynamic acid) => 'Official Digital Manifest: $code (ACID: $acid)';
  @override
  String get cargoxCopyJsonBtn => 'Copy JSON 📋';
  @override
  String get cargoxManifestCopiedToast => '📋 Digital manifest JSON copied to clipboard successfully';
  @override
  String get cargoxSelectEnvelopeForManifestPrompt => 'Please select an envelope from the tracking hub to view its digital manifest';

  // Standard Commercial Invoice Hub SubTab
  @override
  String get standardInvoiceHubTitle => 'Standard Commercial Invoice Hub';
  @override
  String get standardInvoiceHubDesc => 'Generate standardized Excel template with named ranges, auto-match supplier invoice data, and detect customs discrepancies before dispatch.';
  @override
  String get standardInvoiceFileSelectorLabel => 'Select Import File *';
  @override
  String get standardInvoiceFileSelectorHint => 'Search import file, ACID, supplier or company...';
  @override
  String get standardInvoiceFetchError => 'Error loading import files:';
  @override
  String standardInvoiceExistingSessionTitle(dynamic code) => 'Found existing saved study & comparison for this file: [$code]';
  @override
  String standardInvoiceExistingSessionSubtitle(dynamic date, dynamic status, dynamic total, dynamic curr, dynamic count) => 'Saved Date: $date | Status: $status | Total Invoice: $total $curr ($count items)';
  @override
  String get standardInvoiceViewSessionBtn => 'View Details';
  @override
  String get standardInvoiceTool1Title => '1. Generate Standard Excel Template';
  @override
  String get standardInvoiceTool1Subtitle => 'Prepare standardized .xlsx template with named ranges for supplier';
  @override
  String get standardInvoiceTool1Btn => 'Download Standard Excel Template';
  @override
  String get standardInvoiceTool2Title => '2. Parse & Extract Supplier Invoice';
  @override
  String get standardInvoiceTool2Subtitle => 'Upload completed Excel file and auto-extract items';
  @override
  String get standardInvoiceTool2Btn => 'Upload & Parse Supplier Invoice (.xlsx)';
  @override
  String get standardInvoiceTabExtracted => 'Extracted Invoice Data';
  @override
  String get standardInvoiceTabComparison => 'Comparison & Discrepancy Matrix';
  @override
  String get standardInvoiceTabGovernance => 'Approval & Customs Governance';
  @override
  String get standardInvoiceTabRegistry => 'Standard Invoices Registry';
  @override
  String get standardInvoiceTabCustomsTracks => 'Customs Tracks';
  @override
  String get standardInvoiceNoExtractedData => 'No supplier invoice uploaded or parsed yet.';
  @override
  String get standardInvoiceNoExtractedDataSub => 'Download template first, then upload it once filled by supplier.';
  @override
  String standardInvoiceDetailsHeader(dynamic invNum, dynamic date) => 'Invoice Details: $invNum ($date)';
  @override
  String get standardInvoiceSellerCardTitle => 'Exporter / Seller Details';
  @override
  String get standardInvoiceBuyerCardTitle => 'Importer / Buyer Details';
  @override
  String sellerCompanyLabel(dynamic company) => 'Company: $company';
  @override
  String sellerTaxIdLabel(dynamic taxId) => 'Tax ID: $taxId';
  @override
  String sellerCountryLabel(dynamic country) => 'Country: $country';
  @override
  String sellerAddressLabel(dynamic address) => 'Address: $address';
  @override
  String buyerCompanyLabel(dynamic company) => 'Company: $company';
  @override
  String buyerTaxIdLabel(dynamic taxId) => 'Tax ID: $taxId';
  @override
  String buyerAcidNumberLabel(dynamic acid) => 'ACID #: $acid';
  @override
  String buyerIncotermAndCurrencyLabel(dynamic incoterm, dynamic curr) => 'Incoterm: $incoterm | Currency: $curr';
  @override
  String get standardInvoiceExtractedItemsHeader => 'Extracted Line Items';
  @override
  String get standardInvoiceNoComparisonData => 'No comparison conducted yet.';
  @override
  String get standardInvoiceNoComparisonDataSub => 'Upload supplier invoice to run discrepancy comparison engine automatically.';
  @override
  String get standardInvoiceMatch100Banner => '100% Complete Match — No customs or financial discrepancies';
  @override
  String standardInvoiceCriticalMismatchBanner(dynamic count) => 'Critical Customs Warning: $count critical mismatches found (ACID / Tax ID / HS Code)';
  @override
  String standardInvoiceDiscrepanciesBanner(dynamic count) => 'Alert: $count minor discrepancies need review before approval';
  @override
  String get standardInvoiceCompHeadersSection => '1. Headers & Basic Compliance Reconciliation';
  @override
  String get standardInvoiceCompFinancialsSection => '2. Financials Reconciliation';
  @override
  String get standardInvoiceCompItemsSection => '3. Line Items Discrepancy Matrix';
  @override
  String get standardInvoiceColComparedField => 'Compared Field';
  @override
  String get standardInvoiceColSystemValue => 'System Approved Value';
  @override
  String get standardInvoiceColSupplierValue => 'Supplier Invoice Value';
  @override
  String get standardInvoiceColMatchStatus => 'Match Status';
  @override
  String get standardInvoiceColDiffAndNotes => 'Differences & Notes';
  @override
  String get standardInvoiceColHsSystem => 'HS Code (System)';
  @override
  String get standardInvoiceColHsSupplier => 'HS Code (Supplier)';
  @override
  String get standardInvoiceColQtySystem => 'Qty (System)';
  @override
  String get standardInvoiceColQtySupplier => 'Qty (Supplier)';
  @override
  String get standardInvoiceColPriceSystem => 'Price (System)';
  @override
  String get standardInvoiceColPriceSupplier => 'Price (Supplier)';
  @override
  String get standardInvoiceRectificationSectionTitle => 'Ready-to-Send Rectification Notices';
  @override
  String get standardInvoiceRectificationEnTitle => 'English Email Rectification Notice';
  @override
  String get standardInvoiceRectificationArTitle => 'Arabic Rectification Notice (WhatsApp / Email)';
  @override
  String get standardInvoiceGovernanceTitle => 'Invoice Governance & Approval Status';
  @override
  String get standardInvoiceStatusDraft => 'Draft';
  @override
  String get standardInvoiceStatusUnderReview => 'Under Review';
  @override
  String get standardInvoiceStatusApproved => 'Approved';
  @override
  String get standardInvoiceStatusRejected => 'Rejected / Needs Revision';
  @override
  String get standardInvoiceOverrideWarningBanner => 'Mandatory Governance Warning: Discrepancies detected. Override justification is strictly required before approval.';
  @override
  String get standardInvoiceOverrideReasonLabel => 'Discrepancy Override Justification *';
  @override
  String get standardInvoiceOverrideReasonHint => 'Enter administrative or financial rationale for approving discrepancies...';
  @override
  String get standardInvoiceOverrideRequiredError => 'Required: Cannot approve invoice with discrepancies without explicit justification.';
  @override
  String get standardInvoiceInternalNotesLabel => 'Internal Audit Notes';
  @override
  String get standardInvoiceSaveSessionBtn => 'Save & Submit Standard Invoice Review Session';
  @override
  String standardInvoiceSessionSavedSuccess(dynamic code) => 'Standard invoice review session saved successfully [$code]';
  @override
  String get standardInvoiceRegistrySearchHint => 'Search invoice registry by session code, ACID, supplier...';
  @override
  String get standardInvoiceFilterAll => 'All Statuses';
  @override
  String get standardInvoiceColSessionCode => 'Session Code';
  @override
  String get standardInvoiceColFileCode => 'Import File';
  @override
  String get standardInvoiceColAcid => 'ACID #';
  @override
  String get standardInvoiceColInvoiceNum => 'Invoice #';
  @override
  String get standardInvoiceColSupplier => 'Foreign Exporter';
  @override
  String get standardInvoiceColTotal => 'Total';
  @override
  String get standardInvoiceColItemsCount => 'Line Items';
  @override
  String get standardInvoiceColStatus => 'Status';
  @override
  String get standardInvoiceColUpdatedAt => 'Updated At';
  @override
  String get standardInvoiceNoSessionsFound => 'No invoice review sessions registered.';
  @override
  String get standardInvoiceSelectFileFirstError => 'Please select an import file first.';
  @override
  String standardInvoiceGeneratedSuccess(dynamic fileCode, dynamic bytesLength) => 'Invoice template generated successfully: $fileCode ($bytesLength bytes)';
  @override
  String standardInvoiceExtractedSuccess(dynamic num, dynamic itemsCount) => 'Invoice extracted successfully: $num ($itemsCount items)';
  @override
  String standardInvoiceSessionLoadedToast(dynamic code) => 'Loaded session data for $code';
  @override
  String standardInvoiceCopiedToClipboard(dynamic label) => '$label copied to clipboard successfully';
  @override
  String get standardInvoiceMustProvideOverrideJustification => 'Discrepancy override justification is required when approving with differences.';
  @override
  String get required => 'Required';
  @override
  String get errorPrefix => 'Error';
  @override
  String get copy => 'Copy';
  @override
  String get colProductCode => 'Product Code';
  @override
  String get colHsCode => 'HS Code';
  @override
  String get colDescription => 'Commercial Description';
  @override
  String get colUnit => 'Unit';
  @override
  String get colUnitPrice => 'Unit Price';
  @override
  String get colTotalAmount => 'Total Amount';
  @override
  String get colGrossWeight => 'Gross Weight';

  // Screen 54 Extensions: CargoX Toolbar, TSV/Excel Headers, Extraction Modes, Dossier
  @override
  String get cargoxExportTsvBtn => 'Export Envelopes (TSV)';
  @override
  String get cargoxExportExcelBtn => 'Export Envelopes (Excel)';
  @override
  String get cargoxPrintPdfBtn => 'Print Vector Envelopes Report';
  @override
  String get cargoxCopyDossierBtn => 'Copy CargoX Hub Dossier';
  @override
  String get cargoxCopiedDossierSuccess => 'CargoX envelopes dossier copied to clipboard';
  @override
  String get cargoxCopiedTsvSuccess => 'CargoX envelopes table copied to clipboard';
  @override
  String get cargoxCopiedExcelSuccess => 'CargoX envelopes Excel exported successfully';
  @override
  String get cargoxExportTsvDialogTitle => 'Save CargoX Envelopes (TSV)';
  @override
  String get cargoxExportExcelDialogTitle => 'Save CargoX Envelopes (Excel)';
  @override
  String get cargoxExportPdfDialogTitle => 'Save CargoX Envelopes (PDF)';
  @override
  String get cargoxAiDocumentExtractionBtn => 'Smart Document Extraction & Audit';
  @override
  String get cargoxTsvHeaderEnvelopeCode => 'Envelope Code';
  @override
  String get cargoxTsvHeaderImportFile => 'Import File';
  @override
  String get cargoxTsvHeaderAcid => 'ACID Number';
  @override
  String get cargoxTsvHeaderSupplier => 'Foreign Supplier';
  @override
  String get cargoxTsvHeaderSupplierCargoxId => 'CargoX Platform ID';
  @override
  String get cargoxTsvHeaderBlNumber => 'B/L Number';
  @override
  String get cargoxTsvHeaderStatus => 'Customs Status';
  @override
  String get cargoxTsvHeaderDocsCount => 'Docs Count';
  @override
  String get cargoxTsvHeaderTxHash => 'Blockchain TX Hash';
  @override
  String get cargoxTsvHeaderCustomsReceipt => 'Customs Receipt';
  @override
  String get cargoxTsvHeaderTransferredAt => 'Transferred At';
  @override
  String get cargoxDossierHeader => 'CARGOX BLOCKCHAIN & ACI DISPATCH DOSSIER';
  @override
  String get cargoxDossierMetricsTitle => 'DISPATCH & BLOCKCHAIN METRICS';
  @override
  String get cargoxDossierEnvelopesTitle => 'DIGITAL ENVELOPES REGISTER';
  @override
  String cargoxCopiedEnvelopeSuccess(dynamic code) => 'Envelope code copied: $code';
  @override
  String cargoxCopiedAcidSuccess(dynamic acid) => 'ACID number copied: $acid';
  @override
  String get cargoxCopiedTxHashSuccess => 'Blockchain TX hash copied to clipboard';
  @override
  String get cargoxCopiedReceiptSuccess => 'Customs confirmation receipt copied to clipboard';
  @override
  String get cargoxExtractEngineTitle => 'Multi-Track CargoX Extraction Engine';
  @override
  String cargoxExtractFileSubtitle(dynamic file, dynamic supplier, dynamic acid) => 'File: $file — Supplier: $supplier (ACID: $acid)';
  @override
  String get cargoxChooseExtractionPathPrompt => 'Select desired extraction route for Excel export:';
  @override
  String get cargoxModeConsolidatedTitle => '1. Single Consolidated File';
  @override
  String get cargoxModeConsolidatedSubtitle => 'Merge same HS Code line items with weighted unit price';
  @override
  String get cargoxModeDetailedTitle => '2. Single Detailed File';
  @override
  String get cargoxModeDetailedSubtitle => 'Extract every line item separately matching purchase order details';
  @override
  String get cargoxModePerInvoiceConsolidatedTitle => '3. Per-Invoice Consolidated File (ZIP Archive)';
  @override
  String get cargoxModePerInvoiceConsolidatedSubtitle => 'Generate separate consolidated Excel file per invoice in ZIP archive';
  @override
  String get cargoxModePerInvoiceDetailedTitle => '4. Per-Invoice Detailed File (ZIP Archive)';
  @override
  String get cargoxModePerInvoiceDetailedSubtitle => 'Generate separate detailed Excel file per invoice in ZIP archive';
  @override
  String get cargoxLiveItemsPreviewBtn => 'Live Preview Extracted Items';
  @override
  String get cargoxLiveItemsPreviewHeader => 'Extracted Items & Weight Breakdown (Live Preview):';
  @override
  String cargoxInvoicesCountAndLines(dynamic invCount, dynamic linesCount) => 'Invoices Count: $invCount | Line Items: $linesCount';
  @override
  String get cargoxAdoptAsCustomsTrackBtn => 'Adopt as Independent Customs Track';
  @override
  String cargoxAdoptCustomsTrackSuccess(dynamic code) => 'Customs track adopted and saved: $code';
  @override
  String cargoxExtractionError(dynamic err) => 'Extraction error: $err';
  @override
  String cargoxSaveTrackError(dynamic err) => 'Save customs track error: $err';
  @override
  String cargoxLivePreviewGrossNet(dynamic gross, dynamic net, dynamic unit) => 'Gross: $gross $unit | Net: $net $unit';
  @override
  String cargoxLivePreviewTotalValue(dynamic total, dynamic curr) => 'Total Value: $total $curr';
  @override
  String cargoxLivePreviewInvoiceBadge(dynamic inv) => 'Invoice: $inv';
  @override
  String get cargoxDocTypeCommercialInvoice => 'Commercial Invoice';
  @override
  String get cargoxDocTypePackingList => 'Packing List';
  @override
  String get cargoxDocTypeDraftBl => 'Draft Bill of Lading';
  @override
  String get cargoxDocTypeCooEur1 => 'Certificate of Origin / EUR.1';
  @override
  String get cargoxDocTypeCoa => 'Certificate of Analysis';
  @override
  String cargoxCopiedAttachedDocSuccess(dynamic docName) => 'Attached document copied: $docName';
  @override
  String get standardInvoiceSessionsExportTsvBtn => 'Export Sessions (TSV)';
  @override
  String get standardInvoiceSessionsExportExcelBtn => 'Export Sessions (Excel)';
  @override
  String get standardInvoiceSessionsPrintPdfBtn => 'Print Vector Sessions Report';
  @override
  String get standardInvoiceSessionsCopyDossierBtn => 'Copy Sessions Dossier';
  @override
  String get standardInvoiceSessionsDossierHeader => 'STANDARD COMMERCIAL INVOICE SESSIONS REGISTRY';
  @override
  String standardInvoiceCopiedSessionSuccess(dynamic code) => 'Session code copied: $code';
  @override
  String get standardInvoiceManufacturer => 'Manufacturer';
  @override
  String get standardInvoiceWeightNet => 'Net Weight';
  @override
  String get standardInvoiceTabTitle => 'Standard Commercial Invoice';
  @override
  String get standardInvoicePackingListTitle => 'Packing List';
  @override
  String get cargoxDownloadZipBtn => 'Download ZIP Archive';
  @override
  String customsTrackEditDialogTitle(dynamic code) => 'Edit Customs Track ($code)';
  @override
  String get customsTrackCustomsStatus => 'Customs Status:';
  @override
  String get customsTrackStatusSealed => 'Sealed & Documented';
  @override
  String get customsTrackNotesAndDeclaration => 'Notes & Customs Declaration:';
  @override
  String get customsTrackNotesHint => 'Enter any notes specific to this customs track...';
  @override
  String get customsTrackSaveBtn => 'Save Changes';
  @override
  String get customsTrackUpdateSuccessToast => 'Customs track updated successfully';
  @override
  String get customsTrackDeleteDialogTitle => 'Confirm Customs Track Deletion';
  @override
  String customsTrackDeleteDialogMessage(dynamic code) => 'Are you sure you want to delete customs track "$code"? It will not be permanently deleted, but archived.';
  @override
  String customsTrackDeleteSuccessToast(dynamic code) => 'Customs track $code deleted successfully';

  // Screen 55: Customs Clearance Quotations & RFQ Evaluator
  @override
  String get clearanceQuotesScreenTitle => 'Customs Clearance Quotations & Master Price Lists';
  @override
  String get clearanceQuotesScreenSubtitle => 'Clearance RFQ Requests, Comparative Cost Evaluation & Master Tariff Rates';
  @override
  String get clearanceQuotesEmbeddedTitle => 'Customs Clearance Quotations & Smart AI Extractor';
  @override
  String get clearanceQuotesTabRfqs => 'Clearance RFQs & Quotations Evaluator';
  @override
  String get clearanceQuotesTabPriceLists => 'Master Clearance Price Lists';
  @override
  String get clearanceQuotesSmartExtractorBtn => 'Smart AI Rate Extractor';
  @override
  String get clearanceQuotesCreateRfqBtn => 'Create New Clearance RFQ';
  @override
  String get clearanceQuotesSearchHint => 'Search by RFQ code, title, port...';
  @override
  String get clearanceQuotesStatusAll => 'All Statuses';
  @override
  String get clearanceQuotesStatusDraft => 'Draft';
  @override
  String get clearanceQuotesStatusReceived => 'Quotations Received';
  @override
  String get clearanceQuotesStatusAwarded => 'Awarded';
  @override
  String get clearanceQuotesNoRfqsFound => 'No clearance RFQs found.';
  @override
  String get clearanceQuotesAwardedBannerPrefix => 'Customs clearance awarded to:';
  @override
  String clearanceQuotesReceivedQuotesHeader(dynamic count) => 'Received Broker Quotations ($count)';
  @override
  String get clearanceQuotesSmartExtractQuoteBtn => 'Smart AI Extract';
  @override
  String get clearanceQuotesAddManualQuoteBtn => 'Add Manual Quote';
  @override
  String get clearanceQuotesNoQuotesYet => 'No quotations received for this request yet.';
  @override
  String get clearanceQuotesColBroker => 'Customs Broker';
  @override
  String get clearanceQuotesColClearanceFee => 'Clearance Fee';
  @override
  String get clearanceQuotesColInlandTransport => 'Inland Transport';
  @override
  String get clearanceQuotesColInspectionFee => 'Inspection Fee';
  @override
  String get clearanceQuotesColPortExpenses => 'Port Expenses';
  @override
  String get clearanceQuotesColMiscellaneous => 'Miscellaneous';
  @override
  String get clearanceQuotesColEstimatedTotal => 'Estimated Total';
  @override
  String get clearanceQuotesColDuration => 'Duration';
  @override
  String get clearanceQuotesColStatusActions => 'Status & Actions';
  @override
  String get clearanceQuotesStatusAwardedBadge => 'Awarded';
  @override
  String get clearanceQuotesAwardAndApproveBtn => 'Award & Approve';
  @override
  String clearanceQuotesDaysCount(dynamic days) => '$days Days';
  @override
  String get clearanceQuotesBadgePort => 'Port:';
  @override
  String get clearanceQuotesBadgeShipmentType => 'Shipment Type:';
  @override
  String get clearanceQuotesBadgeHsCode => 'HS Code:';
  @override
  String get clearanceQuotesBadgeWeight => 'Weight:';
  @override
  String get clearanceQuotesBadgeVolume => 'Volume:';
  @override
  String get clearanceQuotesBadgeLowestCost => 'Lowest Quote:';
  @override
  String get clearanceQuotesBadgeFastestDuration => 'Fastest Duration:';
  @override
  String get clearanceQuotesPriceListTitle => 'Approved Customs Clearance & Transport Price Lists';
  @override
  String get clearanceQuotesPriceListSubtitle => 'Manage Standard Baseline Tariffs per Broker and Port of Entry';
  @override
  String get clearanceQuotesAddPriceItemBtn => 'Add Price List Item';
  @override
  String get clearanceQuotesNoPriceItemsFound => 'No price list items registered yet.';
  @override
  String get clearanceQuotesColPricePort => 'Port';
  @override
  String get clearanceQuotesColPriceServiceType => 'Service Category';
  @override
  String get clearanceQuotesColPriceContainerType => 'Container Type';
  @override
  String get clearanceQuotesColPriceStandardRate => 'Standard Rate';
  @override
  String get clearanceQuotesColPriceNotes => 'Notes';
  @override
  String get clearanceQuotesColPriceDelete => 'Delete';
  @override
  String get clearanceQuotesDialogCreateRfqTitle => 'Create Clearance Quotation Request (RFQ)';
  @override
  String get clearanceQuotesFieldRfqTitle => 'RFQ Title *';
  @override
  String get clearanceQuotesFieldRfqTitleRequired => 'Title is required';
  @override
  String get clearanceQuotesFieldLinkImportFile => 'Link Import File (Optional)';
  @override
  String get clearanceQuotesFieldClearancePort => 'Customs Clearance Port *';
  @override
  String get clearanceQuotesFieldShipmentType => 'Shipment & Container Type *';
  @override
  String get clearanceQuotesFieldContainersCount => 'Containers Count *';
  @override
  String get clearanceQuotesFieldGrossWeightKg => 'Gross Weight (KG)';
  @override
  String get clearanceQuotesFieldCbm => 'Volume (CBM)';
  @override
  String get clearanceQuotesSubmitCreateRfqBtn => 'Create RFQ';
  @override
  String get clearanceQuotesDialogAddQuoteTitle => 'Add Customs Broker Quotation';
  @override
  String get clearanceQuotesFieldCustomsBroker => 'Customs Broker *';
  @override
  String get clearanceQuotesFieldClearanceFeeEgp => 'Clearance Agency Fee (EGP) *';
  @override
  String get clearanceQuotesFieldInlandFeeEgp => 'Inland Transport to Plant (EGP) *';
  @override
  String get clearanceQuotesFieldInspectionFeeEgp => 'Inspection & Physical Verification (EGP)';
  @override
  String get clearanceQuotesFieldPortExpEgp => 'Port Charges & Ground Rent (EGP)';
  @override
  String get clearanceQuotesFieldMiscFeeEgp => 'Administrative & Sundry (EGP)';
  @override
  String get clearanceQuotesFieldEstimatedDays => 'Estimated Turnaround (Days) *';
  @override
  String get clearanceQuotesTotalEstimatedQuoteLabel => 'Estimated Quotation Total:';
  @override
  String get clearanceQuotesSubmitSaveQuoteBtn => 'Save Quotation';
  @override
  String get clearanceQuotesSmartExtractorDialogTitle => 'Smart AI Clearance Quotation & Estimate Extractor';
  @override
  String get clearanceQuotesSmartExtractorPrompt => 'Paste quotation text, email, or upload document to extract items automatically:';
  @override
  String get clearanceQuotesSmartExtractorInputHint => 'Example:\nClearance quotation from Eagle Logistics...\nClearance agency fee: 3500 EGP\nInland trucking: 7000 EGP\nInspection fees: 1500 EGP...';
  @override
  String get clearanceQuotesExtractingState => 'Extracting...';
  @override
  String get clearanceQuotesExtractFromTextBtn => 'Extract from Text';
  @override
  String get clearanceQuotesUploadDocBtn => 'Upload PDF / Excel / Word Document';
  @override
  String get clearanceQuotesExtractedBrokerPrefix => 'Extracted Broker:';
  @override
  String get clearanceQuotesExtractedPortPrefix => 'Port:';
  @override
  String get clearanceQuotesExtractedContainerPrefix => 'Container:';
  @override
  String get clearanceQuotesExtractedTotalPrefix => 'Estimated Total Cost:';
  @override
  String get clearanceQuotesApplyExtractedQuoteBtn => 'Apply & Add Quotation';
  @override
  String get clearanceQuotesUseExtractedQuoteBtn => 'Apply & Use Quotation';
  @override
  String clearanceQuotesExtractedSuccessToast(dynamic broker, dynamic total) => 'Extracted broker quote successfully: $broker - Total: $total EGP';
  @override
  String get clearanceQuotesDialogAddPriceItemTitle => 'Add Baseline Price List Item';
  @override
  String get clearanceQuotesFieldServiceCategory => 'Service Category *';
  @override
  String get clearanceQuotesFieldStandardPriceEgp => 'Standard Unit Price (EGP) *';
  @override
  String get clearanceQuotesFieldStandardPriceRequired => 'Price is required';
  @override
  String get clearanceQuotesSubmitSavePriceItemBtn => 'Save Price Item';
  @override
  String get clearanceQuotesCatClearanceFee => 'Clearance Agency Fee';
  @override
  String get clearanceQuotesCatInlandTransport => 'Inland Transport';
  @override
  String get clearanceQuotesCatInspectionFee => 'Inspection & Examination Fee';
  @override
  String get clearanceQuotesCatPortCharges => 'Port & Demurrage Charges';
  @override
  String get clearanceQuotesConfirmAwardTitle => 'Confirm Clearance Award & Approval';
  @override
  String get clearanceQuotesConfirmAwardContent => 'Are you sure you want to award this quotation and lock it in the shipment cost breakdown?';
  @override
  String get clearanceQuotesConfirmAwardBtn => 'Confirm Award';
  @override
  String get clearanceQuotesAwardSuccessSnackbar => 'Customs clearance quotation awarded and approved successfully';
  @override
  String get clearanceQuotesConfirmDeleteQuoteTitle => 'Confirm Deletion';
  @override
  String get clearanceQuotesConfirmDeleteQuoteContent => 'Are you sure you want to delete this quotation from the comparison?';
  @override
  String get clearanceQuotesErrorLoadingRfqs => 'Error loading clearance RFQs:';
  @override
  String get clearanceQuotesErrorLoadingPriceList => 'Error loading price lists:';
  @override
  String get kgUnit => 'KG';
  @override
  String get cbmUnit => 'CBM';
  @override
  String get egpCurrency => 'EGP';
  @override
  String get searchPlaceholder => 'Search here...';

  // ── Screen 55: Clearance Quotations Export Toolbar & i18n ───────────────
  @override
  String get clearanceQuotesExportTsvBtn => 'Export TSV';
  @override
  String get clearanceQuotesExportExcelBtn => 'Export Excel';
  @override
  String get clearanceQuotesPrintPdfBtn => 'Print PDF Report';
  @override
  String get clearanceQuotesCopyDossierBtn => 'Copy Quotations Dossier';
  @override
  String get clearanceQuotesCopiedDossierSuccess => 'Clearance quotations dossier copied to clipboard successfully';
  @override
  String get clearanceQuotesCopiedTsvSuccess => 'Clearance quotations copied as TSV table to clipboard';
  @override
  String get clearanceQuotesCopiedExcelSuccess => 'Clearance quotations exported to Excel successfully';
  @override
  String get clearanceQuotesExportTsvDialogTitle => 'Export Clearance Quotations TSV';
  @override
  String get clearanceQuotesExportExcelDialogTitle => 'Export Clearance Quotations Excel';
  @override
  String get clearanceQuotesExportPdfDialogTitle => 'Print Clearance Quotations Report';
  @override
  String get clearanceQuotesDossierTitle => 'Customs Clearance Quotations Evaluation Summary';
  @override
  String get clearanceQuotesCopyRowSuccess => 'Row data copied to clipboard successfully';
  @override
  String get clearanceQuotesCopySummarySuccess => 'Quotation summary copied to clipboard successfully';
  @override
  String get clearanceQuotesTsvHeaderRfqCode => 'RFQ Code';
  @override
  String get clearanceQuotesTsvHeaderTitle => 'RFQ Title';
  @override
  String get clearanceQuotesTsvHeaderPort => 'Clearance Port';
  @override
  String get clearanceQuotesTsvHeaderShipmentType => 'Shipment Type';
  @override
  String get clearanceQuotesTsvHeaderContainers => 'Containers Count';
  @override
  String get clearanceQuotesTsvHeaderWeight => 'Gross Weight';
  @override
  String get clearanceQuotesTsvHeaderCbm => 'Volume CBM';
  @override
  String get clearanceQuotesTsvHeaderBroker => 'Customs Broker';
  @override
  String get clearanceQuotesTsvHeaderClearanceFee => 'Clearance Fee';
  @override
  String get clearanceQuotesTsvHeaderInlandTransport => 'Inland Transport';
  @override
  String get clearanceQuotesTsvHeaderInspectionFee => 'Inspection Fee';
  @override
  String get clearanceQuotesTsvHeaderPortExpenses => 'Port Expenses';
  @override
  String get clearanceQuotesTsvHeaderMiscFee => 'Miscellaneous Fee';
  @override
  String get clearanceQuotesTsvHeaderTotal => 'Estimated Total';
  @override
  String get clearanceQuotesTsvHeaderDays => 'Turnaround Days';
  @override
  String get clearanceQuotesTsvHeaderStatus => 'Status';
  @override
  String get clearanceQuotesTsvHeaderPriceServiceType => 'Service Category';
  @override
  String get clearanceQuotesTsvHeaderPriceContainerType => 'Container Type';
  @override
  String get clearanceQuotesTsvHeaderPriceStandardRate => 'Standard Rate';
  @override
  String get clearanceQuotesTsvHeaderPriceNotes => 'Notes';
  @override
  String get clearanceQuotesManagePriceListBtn => 'Manage Master Dated Broker Price Lists';
  @override
  String get clearanceQuotesPasteClipboardBtn => 'Paste from Clipboard';
  @override
  String get clearanceQuotesSampleAccBtn => 'Test Alexandria ACC Quotation (30,900 EGP)';
  @override
  String get clearanceQuotesSampleStandardBtn => 'Test Standard Sample Quotation';
  @override
  String get clearanceQuotesClearInputTooltip => 'Clear Input';
  @override
  String get clearanceQuotesOcrUploadingState => 'Uploading file and optical scanning (OCR)...';
  @override
  String get clearanceQuotesOcrStep1 => 'Phase 1 of 4: Uploading File';
  @override
  String get clearanceQuotesOcrDialogTitle => 'Extract Clearance Quotation';
  @override
  String clearanceQuotesOcrProgressState(dynamic percent) => 'Uploading and processing file ($percent%)...';
  @override
  String get clearanceQuotesOcrStep2 => 'Phase 2 of 4: Processing File';
  @override
  String get clearanceQuotesOcrStep4State => 'Extracting clearance fees and inland transport expenses...';
  @override
  String get clearanceQuotesSelectedContainerLabel => 'Selected Container:';
  @override
  String get clearanceQuotesSaveAsPriceListBtn => 'Code & Save as Master Broker Price List';
  @override
  String get clearanceQuotesRateOptionsTitle => 'Pricing options by container and weight (select required option):';
  @override
  String get clearanceQuotesBreakdownClearanceFee => 'Clearance Fee';
  @override
  String get clearanceQuotesBreakdownInlandFee => 'Inland Transport';
  @override
  String get clearanceQuotesBreakdownInspectionFee => 'Inspection Fee';
  @override
  String get clearanceQuotesBreakdownPortExpenses => 'Port Expenses';
  @override
  String get clearanceQuotesBreakdownEstimatedTotal => 'Estimated Total';
  @override
  String clearanceQuotesExpensesCatalogCount(dynamic count) => 'View itemized expenses catalog ($count items)';

  // ── Authentication & Login Screen ──────────────────────────────────────────
  @override
  String get loginScreenTitle => 'System Login';
  @override
  String get loginScreenSubtitle => 'Sorour Logistics — Supply Chain, Import & Customs Clearance ERP';
  @override
  String get loginUsernameLabel => 'Username or Email';
  @override
  String get loginUsernameHint => 'Username...';
  @override
  String get loginUsernameRequired => 'Please enter username or email';
  @override
  String get loginPasswordLabel => 'Password';
  @override
  String get loginPasswordRequired => 'Please enter password';
  @override
  String get loginButtonLabel => 'Sign In to System';
  @override
  String get loginAuthenticating => 'Authenticating & Signing in...';
  @override
  String get loginQuickDemoAccess => 'Quick Demo Account Access:';
  @override
  String get loginInvalidCredentials => 'Invalid username or password';
  @override
  String get loginRoleAdmin => 'Administrator';
  @override
  String get loginRoleManager => 'Operations Manager';
  @override
  String get loginRoleSpecialist => 'Logistics Specialist';
  @override
  String get loginCopyUsernameTooltip => 'Copy Username';
  @override
  String get loginUsernameCopied => 'Username copied successfully';
  @override
  String get loginCopyPasswordTooltip => 'Copy Password';
  @override
  String get loginPasswordCopied => 'Password copied successfully';
  @override
  String get loginDemoCredentialsCopied => 'Demo credentials copied successfully';
  @override
  String get loginDemoCredentialsTooltip => 'Copy Demo Credentials';

  // ── Shipping Scenarios & Cargo Stacking ────────────────────────────────────
  @override
  String get multiLayerStacking => 'Multi-layer Stacking';
  @override
  String get floorPlacementZ0 => 'Floor Placement z=0';
  @override
  String mixedStackingCargoDesc(int nonStack, int stack) =>
      '$nonStack Non-Stackable + $stack Stackable';
  @override
  String get containerCountPill => 'Container Count';
  @override
  String get spaceAndVolumeUtilPill => 'Space & Volume Utilization';
  @override
  String get weightUtilPill => 'Weight Utilization';
  @override
  String containerCountUnit(int count) => '$count Container(s)';

  // ── Smart Invoice & Packing Extractor ──────────────────────────────────────
  @override
  String get smartInvoiceExtractProgressTitle => 'Smart Invoice & Packing Extractor';
  @override
  String ocrStepProgressLabel(int step, int total, String desc) => 'Step $step of $total: $desc';
  @override
  String get ocrStep1Reading => 'Read';
  @override
  String get ocrStep2Upload => 'Upload';
  @override
  String get ocrStep3Ocr => 'Smart OCR';
  @override
  String get ocrStep4Fields => 'Extract Fields';
  @override
  String get cancelAndCloseExtractor => 'Cancel & Close Extractor';
  @override
  String get ocrAnalyzingText => 'Analyzing text, line item codes, and prices...';
  @override
  String get ocrSendingDoc => 'Sending document and processing pages...';
  @override
  String get ocrExtractingFields => 'Extracting invoice items, packing details, and formatting...';
  @override
  String get ocrCompleteSuccess => 'Processing Completed Successfully 100%';
  @override
  String get ocrCompleteSuccessDesc => 'All fields extracted successfully. Displaying preview!';
  @override
  String get closeAndCancelExtractionTooltip => 'Close & Cancel Extraction';
  @override
  String get addManualFieldBtn => '➕ Add Manual Field';
  @override
  String get populateFormBtn => 'Populate Form';
  @override
  String get verifyPartiesInDb => 'Verify Parties in Database';
  @override
  String get partyUnconfirmed => 'Unconfirmed';
  @override
  String get partyConfirmed => 'Confirmed';
  @override
  String get registerPartyAction => 'Register +';
  @override
  String get missingFieldsWarning => 'The following fields were not extracted:';
  @override
  String get editFieldValueTitle => 'Edit Field Value';
  @override
  String get updatedValueLabel => 'Updated Value';
  @override
  String get enterCorrectValueHint => 'Enter correct value...';
  @override
  String get saveEditBtn => 'Save Edit';
  @override
  String get callSmartNafezaDiffBtn => 'Invoke Smart Nafeza to Register Tariff';
  @override
  String get fullExtraction => 'Full Extraction';
  @override
  String get partialExtraction => 'Partial Extraction';
  @override
  String get extractionFailedStatus => 'Extraction Failed';
  @override
  String get extractionResultHeader => 'Extraction Results';
  @override
  String get extractionConfidenceLabel => 'Confidence Rate';
  @override
  String get extractedFieldsTitle => 'Extracted Fields';
  @override
  String get supplier => 'Supplier';

  // ── Extracted Field Labels Dictionary ───────────────────────────────────────
  @override
  String get fieldSupplierAddress => 'Supplier Address';
  @override
  String get fieldSupplierPhone => 'Supplier Phone';
  @override
  String get fieldSupplierTaxId => 'Supplier Tax ID';
  @override
  String get fieldSupplierCountry => 'Supplier Country';
  @override
  String get fieldSupplierCity => 'Supplier City';
  @override
  String get fieldSupplierEmail => 'Supplier Email';
  @override
  String get fieldCustomerName => 'Importing Company';
  @override
  String get fieldCustomerAddress => 'Importer Address';
  @override
  String get fieldCustomerTaxId => 'Importer Tax ID';
  @override
  String get fieldInvoiceNumber => 'Invoice Number';
  @override
  String get fieldInvoiceDate => 'Invoice Date';
  @override
  String get fieldInvoiceValue => 'Invoice Value';
  @override
  String get fieldPoNumber => 'PO Number';
  @override
  String get fieldIncoterm => 'Incoterm';
  @override
  String get fieldCurrency => 'Currency';
  @override
  String get fieldExchangeRate => 'Exchange Rate';
  @override
  String get fieldTotalAmount => 'Total Amount';
  @override
  String get fieldPaymentTerms => 'Payment Terms';
  @override
  String get fieldPolPort => 'Port of Loading';
  @override
  String get fieldPodPort => 'Port of Discharge';
  @override
  String get fieldAcidNumber => 'ACID Number';
  @override
  String get fieldBlNumber => 'B/L Number';
  @override
  String get fieldContainerNumbers => 'Container Numbers';
  @override
  String get fieldGrossWeight => 'Gross Weight';
  @override
  String get fieldNetWeight => 'Net Weight';
  @override
  String get fieldTotalCbm => 'Total CBM Volume';
  @override
  String get fieldPackagesCount => 'Packages Count';
  @override
  String get fieldCommodityDescription => 'Commodity Description';
  @override
  String get fieldOriginCountry => 'Country of Origin';
  @override
  String get fieldCustomsValueEgp => 'Customs Value (EGP)';
  @override
  String get fieldImportDuty => 'Import Duty';
  @override
  String get fieldVatAmount => 'VAT Amount';
  @override
  String get fieldTotalTaxes => 'Total Taxes';
  @override
  String get fieldCertificateNumber => 'Certificate Number';
  @override
  String get fieldIssueDate => 'Issue Date';
  @override
  String get fieldCarrierName => 'Carrier / Vessel Name';
  @override
  String get fieldFreightRate => 'Freight Rate';
  @override
  String get fieldTransitDays => 'Transit Days';
  @override
  String get fieldValidityDate => 'Validity Date';
  @override
  String get fieldBookingNumber => 'Booking Number';
  @override
  String get fieldSiCutoff => 'SI Cut-off';
  @override
  String get fieldAmount => 'Amount';
  @override
  String get fieldBankName => 'Bank Name';
  @override
  String get fieldSwiftCode => 'SWIFT Code';
  @override
  String get fieldInspectionResult => 'Inspection Result';

  // ── Purchase Order Details & View Modal ────────────────────────────────────
  @override
  String poViewDialogTitle(String poNumber, String? version) =>
      version != null && version.isNotEmpty
          ? 'Purchase Orders & Proforma Invoices: $poNumber ($version)'
          : 'Purchase Orders & Proforma Invoices: $poNumber';
  @override
  String get poLineItemsBreakdown => 'PO Line Items Breakdown & HS Codes';
  @override
  String get descriptionAndHsCode => 'Description & HS Code';
  @override
  String get qtyUom => 'Qty / UOM';
  @override
  String get volumeCbmPackingList => 'Volume CBM (Packing List)';
  @override
  String itemOriginLabel(String origin) => 'Origin: $origin';
  @override
  String hsMismatchWarning(String duty, String vat) =>
      'HS Mismatch (Duty: $duty / VAT: $vat)';
  @override
  String get exchangeRateLabel => 'Exchange Rate';
  @override
  String get itemCode => 'Item Code';
  @override
  String get mainDescription => 'Main Description';
  @override
  String get unitPrice => 'Unit Price';
  @override
  String get lineTotal => 'Line Total';

  // ── Edit Purchase Order & Packing List & 3D Simulator ──────────────────────
  @override
  String editPurchaseOrderTitle(String poNumber) => 'Edit Purchase Order ($poNumber)';
  @override
  String poLineItemsTabCount(int count) => 'PO Line Items ($count)';
  @override
  String poPackingListTabCount(int count) => 'Review Packing List ($count)';
  @override
  String get packingListReaderBanner => 'Packing List & Weight Extraction Tool';
  @override
  String get packingListReaderBannerDesc =>
      'Upload a packing list document to extract package quantities, gross/net weights, and volumes automatically';
  @override
  String get explicitDimensionsPath => 'Explicit Dimensions Path (L × W × H)';
  @override
  String get cbmDirectPathAndPalletLayout => 'Direct CBM & Pallet Layout Path';
  @override
  String get packingListEntriesSection => 'Packing List Entries (Dimensions & Packages) *';
  @override
  String get autoFillFromInvoice => 'Auto-fill from Invoice';
  @override
  String get simulateAndPack3d => '3D Container Simulation & Packing';
  @override
  String get addPackingEntryBtn => 'Add Packing Entry';
  @override
  String get noPackingEntriesYet => 'No packing entries added yet';
  @override
  String get noPackingEntriesYetDesc =>
      'Click "Auto-fill from Invoice" to generate entries automatically or "Add Packing Entry"';
  @override
  String pkgCardNumber(int num) => 'Pkg #$num';
  @override
  String get hsCodeSearchFieldLabel => 'HS Code (Search 🔍) *';
  @override
  String get selectTariffItemHint => 'Select Tariff Item';
  @override
  String get itemNameOrDescHint => 'Item name or description';
  @override
  String get packageTypeFieldLabel => 'Package Type';
  @override
  String get unitFieldLabel => 'Unit';
  @override
  String get qtyPcsFieldLabel => 'Qty PCS';
  @override
  String get qtyPkgFieldLabel => 'Qty PKG';
  @override
  String lengthFieldLabel(String unit) => 'Length ($unit)';
  @override
  String widthFieldLabel(String unit) => 'Width ($unit)';
  @override
  String heightFieldLabel(String unit) => 'Height ($unit)';
  @override
  String get weightUnitFieldLabel => 'Weight Unit';
  @override
  String netWeightFieldLabel(String unit) => 'Net Wt ($unit)';
  @override
  String grossWeightFieldLabel(String unit) => 'Gross Wt ($unit)';
  @override
  String get stackingInstructionsLabel => 'Stacking Instructions *';
  @override
  String get totalVolumePill => 'Total Volume';
  @override
  String get totalGrossWeightPill => 'Total Gross Wt';
  @override
  String get airChargeablePill => 'Air Chargeable Wt';
  @override
  String autoFillSuccessNotice(int count) =>
      'Successfully auto-filled $count packing items from proforma invoice lines!';
  @override
  String get enterPackingOrPalletsNotice =>
      'Please enter packing items or pallets first to run simulation';
  @override
  String get containerLoadPlan3dTitle => '3D Container Load Planner & Simulation';
  @override
  String get containerLoadPlan3dSubtitle =>
      '3D container packing simulation based on packing list and package dimensions';
  @override
  String get stackingSimulationModeLabel => 'Simulation Stacking Mode:';
  @override
  String get projectionLabel => 'Projection:';
  @override
  String get simulationModeActualMixed => '⚖️ Actual (Mixed)';
  @override
  String get simulationModeStackable => '📦 Stackable';
  @override
  String get simulationModeFloorOnly => '🚫 Floor Only';
  @override
  String get topViewProjection => '🔝 Top View';
  @override
  String get sideViewProjection => '🔲 Side View';
  @override
  String requiredContainersSummary(String fleet) => 'Required Containers: $fleet';
  @override
  String totalPackagesSummary(int total, int stackable, int floor) =>
      'Total Packages: $total pkgs ($stackable Stackable | $floor Floor)';
  @override
  String totalWeightSummary(String wt) => 'Total Weight: $wt kg';
  @override
  String totalVolumeSummary(String vol) => 'Total Volume: $vol m³';
  @override
  String get packingFailureTitle =>
      'Packing Failed: Package dimensions or payload exceed container limits';
  @override
  String get itemCodeLabel => 'Item Code *';
  @override
  String get fieldRequired => 'Required field';
  @override
  String get fieldCurrentStage => 'Current Stage';
  @override
  String get searchFieldHint => 'Search by file number, code, or company name...';

  // ── Master Palletization Plan Localizations ─────────────────────────────────
  @override
  String get masterPalletizationPlanTitle => 'Master Palletization Plan';
  @override
  String totalPalletsPill(int count) => 'Total Pallets: $count Pallets';
  @override
  String palletsVolumePill(String vol) => 'Pallets Volume: $vol m³';
  @override
  String get addPalletRowBtn => 'Add Pallet Row';
  @override
  String simulateAndPackPallets3dBtn(int count) =>
      '3D Container Simulation & Packing ($count Pallets)';
  @override
  String get clickToAddPalletsPrompt =>
      'Click here to add pallet rows and distribute cargo';
  @override
  String palletRowHeader(int index) => 'Pallet Row #$index';
  @override
  String get palletStackableBadge => 'Stackable 📦';
  @override
  String get palletFloorOnlyBadge => 'Non-Stackable (Floor Only) 🚫';
  @override
  String palletRowSummary(String vol, String wt) =>
      'Row Volume: $vol m³ | Total Weight: $wt kg';
  @override
  String get palletTypeAndSizeLabel => 'Pallet Type & Size';
  @override
  String get palletCountFieldLabel => 'Pallet Count (Qty) *';
  @override
  String get palletStackingInstructionsLabel => 'Pallet Stacking Instructions *';
  @override
  String get palletGrossWeightLabel => 'Pallet Gross Weight (kg)';
  @override
  String get deletePalletRowTooltip => 'Delete Pallet Row';
  @override
  String get customPalletOption => 'Custom Pallet (Custom Dimensions)';

  // ── 3D Container Cards & Items Table ──────────────────────────────────────
  @override
  String containerCardHeader(int index, String code, int pkgsCount, String spacePct, String payloadPct) =>
      'Container #$index: $code — ($pkgsCount pkgs) — Space: $spacePct% | Payload: $payloadPct%';
  @override
  String internalDimensionsLabel(String l, String w, String h) =>
      'Internal Dims: $l × $w × $h cm';
  @override
  String placedPackagesTableTitle(int count) =>
      '📋 Placed Packages & Position Details ($count pkgs)';
  @override
  String get thPackageCode => 'Package / Item Code';
  @override
  String get thDimensions => 'Dimensions (L×W×H cm)';
  @override
  String get thWeight => 'Weight (kg)';
  @override
  String get thCoordinates => 'Position Coords (X, Y, Z cm)';
  @override
  String get thStacking => 'Stacking';
  @override
  String get noSuitableContainersFound => 'No suitable containers found';

  // ── Standardized Stage Stop & Resume Buttons ────────────────────────────────
  @override
  String get stopShipmentAtThisStageBtn => 'Stop Shipment at this Stage';
  @override
  String get shipmentOnHoldPrefix => 'On Hold:';
  @override
  String get shipmentClosedArchived => 'Shipment Closed in Archive';
  @override
  String get selectFileToHoldTitle => 'Select Import File to Hold at this Stage';
  @override
  String get selectFileToHoldLabel => 'Select Import File to Hold *';
  @override
  String get selectFileToHoldHint => 'Search by file number, code, or company name...';
  @override
  String get continueToHoldReasonBtn => 'Proceed & Enter Hold Reason';
  @override
  String holdShipmentStageBannerTitle(String code, String stage) =>
      '⚠️ Warning: Shipment ($code) is on hold at stage: [$stage]';
  @override
  String get holdDialogReasonLabel => 'Hold & Pause Reason';
  @override
  String get holdDialogReasonHint => 'Type hold reason or select from above...';
  @override
  String get confirmHoldActionBtn => 'Confirm Hold & Freeze Shipment at this Stage';
  @override
  String holdSuccessNotification(String code, String stage) =>
      '⚠️ Shipment ($code) held successfully at stage: $stage';

  // ── Purchase Order Comprehensive Report Preview ───────────────────────────
  @override
  String get poReportPreviewTitle =>
      'Purchase Order & Packing List Preview';
  @override
  String get poReportPreviewSubtitle =>
      'Comprehensive Detailed Review & Final Reconciliation — Sorour Logistics ERP';
  @override
  String get poReport3dSimulation => '3D Load Simulation';
  @override
  String get poReportCopyText => 'Copy Report Text';
  @override
  String get poReportClosePreview => 'Close Preview';
  @override
  String get poReportHeaderDocumentTitle =>
      'PURCHASE ORDER & PACKING SPECIFICATION';
  @override
  String get poReportPoNumber => 'PO Number';
  @override
  String get poReportPiNumber => 'Proforma Invoice (PI)';
  @override
  String get poReportAcidNumber => 'ACID Number';
  @override
  String get poReportOrderDate => 'Order Date';
  @override
  String get poReportExchangeRate => 'Exchange Rate';
  @override
  String get poReportIncoterms => 'Incoterms';
  @override
  String get poReportOrigin => 'Country of Origin';
  @override
  String get poReportBuyer => 'Buyer (Importer)';
  @override
  String get poReportTaxId => 'Tax ID';
  @override
  String get poReportImportFile => 'Import File';
  @override
  String get poReportSeller => 'Seller (Foreign Exporter)';
  @override
  String get poReportSupplierCountry => 'Supplier Country';
  @override
  String get poReportPaymentTerms => 'Payment Terms';
  @override
  String get poReportTotalInvoice => 'Total Invoice';
  @override
  String get poReportTotalPkgsAndPcs => 'Packages & Pieces';
  @override
  String get poReportGrossWeight => 'Gross Weight';
  @override
  String get poReportNetWeight => 'Net Weight';
  @override
  String get poReportVolumeCbm => 'Volume CBM';
  @override
  String get poReportPalletPlan => 'Pallet Plan';
  @override
  String get poReportRecommendedContainer => 'Recommended Container';
  @override
  String get poReportSec1InvoiceItems =>
      '1. Commercial Invoice Line Items Table';
  @override
  String get poReportSec2PackingList =>
      '2. Detailed Packing List & Dimensions';
  @override
  String get poReportSec3PalletPlan =>
      '3. Master Palletization Plan';
  @override
  String get poReportSec4Notes =>
      '4. Additional Notes & Terms';
  @override
  String get poReportColItemCode => 'Item Code';
  @override
  String get poReportColDescription => 'Description';
  @override
  String get poReportColHsCode => 'HS Code';
  @override
  String get poReportColQtyUnit => 'Qty / Unit';
  @override
  String get poReportColUnitPrice => 'Unit Price';
  @override
  String get poReportColTotalAmount => 'Total Amount';
  @override
  String get poReportColPkgType => 'Package Type';
  @override
  String get poReportColDimensions => 'Dimensions (cm)';
  @override
  String get poReportColStackable => 'Stacking';
  @override
  String get poReportStackableYes => '📦 Yes';
  @override
  String get poReportStackableNo => '🚫 Floor Only';
  @override
  String get poReportGrandTotal => 'Grand Total';
  @override
  String get poReportTotalPacking => 'Total Packing';
  @override
  String get poReportTotalPallets => 'Total Pallets';
  @override
  String get poReportReadyForApproval => 'Ready for Approval';
  @override
  String get poReportCloseAndEdit => 'Close & Return to Edit';
  @override
  String get poReportSaveAndApprove => 'Save & Approve Purchase Order';
  @override
  String get poReportCopiedToClipboard =>
      '📋 Full report text copied to clipboard successfully!';
  @override
  String poReportItemsCountUnit(int count) => '$count items';
  @override
  String poReportPackagesCountUnit(int count) => '$count pkgs';
  @override
  String poReportPiecesCountUnit(int count) => '$count pcs';
  @override
  String poReportPalletsCountUnit(int count) => '$count pallets';
  @override
  String poReportRowsCountUnit(int count) => '$count rows';
  @override
  String get poReportDirectVolume => 'Direct Volume';
  @override
  String get poReportLanguageToggleTooltip =>
      'Switch report language (العربية / English)';
  @override
  String get poReportSwitchLanguageBtn => 'العربية';
  @override
  String get savePurchaseOrderBtn => 'Save Purchase Order';
  @override
  String get savePoEditsBtn => 'Save PO Changes';
  @override
  String get previewPoReportBtn => 'Preview PO Report';

  // ── Marine & Cargo Insurance (CargoInsuranceScreen) ───────────────────────
  @override
  String get insuranceScreenTitle => 'Marine & Cargo Insurance Engine';
  @override
  String get insuranceTabCertificatesRegistry => 'Certificates Registry';
  @override
  String get insuranceTabNewCertificate => 'New Certificate';
  @override
  String get insuranceAiExtractorBtn => 'AI Insurance Co Extractor ✨';
  @override
  String get insuranceSmartUploadBtn => 'Smart Insurance Document Extractor';
  @override
  String insuranceExtractedSnackbar(String ref) => '✅ Extracted Cargo Insurance Document: $ref';
  @override
  String get insuranceExtractedDone => 'Completed';
  @override
  String get insuranceRefreshTooltip => 'Refresh Data';

  @override
  String insuranceFetchError(String err) => 'Error loading certificates: $err';
  @override
  String get insuranceRetryBtn => 'Retry';

  @override
  String get insuranceKpiTotalPolicies => 'Total Policies';
  @override
  String get insuranceKpiIssuedValid => 'Issued & Valid';
  @override
  String get insuranceKpiTotalInsured => 'Total Insured';
  @override
  String get insuranceKpiTotalPremiums => 'Total Premiums';
  @override
  String get insuranceRefreshRegistryBtn => 'Refresh Registry';
  @override
  String get insuranceNewCertificateBtn => 'New Certificate';

  @override
  String get insuranceSearchHint => 'Search certificate code, policy, insured, insurance company, port...';
  @override
  String get insuranceFilterAll => 'All';
  @override
  String get insuranceFilterIssued => 'Issued';
  @override
  String get insuranceFilterDraft => 'Draft';
  @override
  String get insuranceFilterCancelled => 'Cancelled';
  @override
  String get insuranceShowDeleted => 'Show Deleted';
  @override
  String get insuranceHideDeleted => 'Hide Deleted';

  @override
  String get insuranceNoMatchingFound => 'No certificates matching search found';
  @override
  String get insuranceNoDataFound => 'No insurance certificates recorded yet';
  @override
  String get insuranceEmptyHint => 'Click "New Certificate" to calculate and issue marine or air cargo insurance.';

  @override
  String get insuranceColCertCode => 'Cert Code';
  @override
  String get insuranceColIssueDate => 'Issue Date';
  @override
  String get insuranceColPolicyFile => 'Policy & File';
  @override
  String get insuranceColInsuredEntity => 'Insured Entity (Consignee)';
  @override
  String get insuranceColInsuranceCo => 'Insurance Company';
  @override
  String get insuranceColTransportRoute => 'Transport & Route';
  @override
  String get insuranceColInsuredValue => 'Insured Value (110%)';
  @override
  String get insuranceColCoverageClause => 'Coverage Clause';
  @override
  String get insuranceColGrossPremium => 'Gross Premium';
  @override
  String get insuranceColStatus => 'Status';
  @override
  String get insuranceColActions => 'Actions';

  @override
  String get insuranceStatusIssuedBadge => 'Issued';
  @override
  String get insuranceStatusCancelledBadge => 'Cancelled';
  @override
  String get insuranceStatusDraftBadge => 'Draft';

  @override
  String get insuranceViewTooltip => 'View Official Certificate';
  @override
  String get insuranceEditTooltip => 'Edit Certificate';
  @override
  String get insurancePrintTooltip => 'Print Certificate';
  @override
  String get insuranceDeleteTooltip => 'Delete Certificate';
  @override
  String get insuranceIssueCertificateTooltip => 'Issue Certificate';
  @override
  String get insuranceConfirmIssueTitle => 'Issue Certificate';
  @override
  String insuranceConfirmIssueMsg(String code) => 'Are you sure you want to officially issue certificate $code?';
  @override
  String get insuranceConfirmIssueBtn => 'Confirm Issue';
  @override
  String get insuranceIssueSuccessMsg => '✅ Certificate issued successfully!';
  @override
  String get insuranceConfirmDeleteTitle => 'Delete Certificate';
  @override
  String get insuranceConfirmDeleteMsg => 'Are you sure you want to delete this record?';
  @override
  String get insuranceDeleteBtn => 'Delete';

  @override
  String get insuranceDialogNewTitle => 'New Cargo Insurance Certificate';
  @override
  String insuranceDialogEditTitle(String code) => 'Edit Insurance Certificate $code';
  @override
  String get insuranceDialogSubtitle => '110% CIF Insured Value & Gross Premium Engine (London Institute Cargo Clauses)';
  @override
  String get insuranceFieldLinkImportFile => 'Link Import File *';
  @override
  String get insuranceFieldLinkImportFileHint => 'Select Import File to auto-fill...';
  @override
  String get insuranceFieldInsuredEntity => 'Insured Entity (Consignee) *';
  @override
  String get insuranceFieldInsuredEntityRequired => 'Insured entity is required';
  @override
  String get insuranceFieldPolicyType => 'Policy Type *';
  @override
  String get insuranceFieldPolicyTypeHint => 'Select policy type...';
  @override
  String get insurancePolicyTypeSpecific => 'Specific Shipment Policy';
  @override
  String get insurancePolicyTypeOpen => 'Open Floating Policy';
  @override
  String get insuranceFieldInsuranceCompany => 'Insurance Company';
  @override
  String get insuranceFieldPolicyNumber => 'Policy / Certificate Number';
  @override
  String get insuranceSecVoyageDetails => 'Voyage & Transport Details';
  @override
  String get insuranceFieldTransportMode => 'Transport Mode *';
  @override
  String get insuranceFieldTransportModeHint => 'Select mode...';
  @override
  String get insuranceTransportModeOcean => 'Ocean Freight';
  @override
  String get insuranceTransportModeAir => 'Air Freight';
  @override
  String get insuranceTransportModeRoad => 'Road Transport';
  @override
  String get insuranceFieldCarrier => 'Carrier';
  @override
  String get insuranceFieldVesselFlight => 'Vessel / Flight No';
  @override
  String get insuranceFieldPol => 'Port of Loading (POL) *';
  @override
  String get insuranceFieldPod => 'Port of Discharge (POD) *';
  @override
  String get insuranceFieldBlTracking => 'B/L or AWB Tracking Ref';
  @override
  String get insuranceFieldInvoiceValue => 'Invoice Value (FOB) *';
  @override
  String get insuranceFieldFreightCost => 'Freight Cost';
  @override
  String get insuranceFieldCurrency => 'Currency *';
  @override
  String get insuranceFieldCurrencyHint => 'Select currency...';
  @override
  String get insuranceCurrUsd => 'USD - US Dollar';
  @override
  String get insuranceCurrEur => 'EUR - Euro';
  @override
  String get insuranceCurrEgp => 'EGP - Egyptian Pound';
  @override
  String get insuranceCurrCny => 'CNY - Chinese Yuan';
  @override
  String get insuranceCurrGbp => 'GBP - British Pound';
  @override
  String get insuranceSecCoverageClauses => 'Coverage Clauses & Risk Extensions';
  @override
  String get insuranceFieldCoverageClause => 'Coverage Clause (ICC) *';
  @override
  String get insuranceFieldCoverageClauseHint => 'Select coverage clause...';
  @override
  String get insuranceClauseIccA => 'ICC (A) — All Risks (0.25%)';
  @override
  String get insuranceClauseAirAllRisks => 'Air Cargo All Risks (0.20%)';
  @override
  String get insuranceClauseIccB => 'ICC (B) — Intermediate Risks (0.15%)';
  @override
  String get insuranceClauseIccC => 'ICC (C) — Minimum Cargo Risks (0.10%)';
  @override
  String get insuranceWarAndStrikesTitle => 'Include War & Strikes Clauses (+0.05%)';
  @override
  String get insuranceWarAndStrikesSubtitle => 'Mandatory add-on for Letter of Credit (L/C) compliance';
  @override
  String get insuranceSecBreakdownTitle => 'Real-Time Premium Breakdown';
  @override
  String get insuranceBreakdownCifBase => 'CIF Base Value:';
  @override
  String get insuranceBreakdownInsuredValue => 'Insured Value (110% CIF):';
  @override
  String insuranceBreakdownBasePremium(String rate) => 'Base Premium ($rate%):';
  @override
  String get insuranceBreakdownWarStrikes => 'War & Strikes Add-on (0.05%):';
  @override
  String get insuranceBreakdownNetPremium => 'Net Premium (Min Floor):';
  @override
  String get insuranceBreakdownIssuanceFee => 'Issuance Fee & Stamp Duty:';
  @override
  String get insuranceBreakdownTaxes => 'Taxes & Levies (5%):';
  @override
  String get insuranceBreakdownTotalPayable => 'Total Payable Gross Premium:';
  @override
  String get insuranceSecCargoSpecs => 'Cargo Description & Packages';
  @override
  String get insuranceFieldGoodsDesc => 'Goods Description';
  @override
  String get insuranceFieldGoodsDescHint => 'e.g. Industrial machinery & spare parts';
  @override
  String get insuranceFieldPackagesCount => 'Packages Count';
  @override
  String get insuranceFieldGrossWeight => 'Gross Weight (KG)';
  @override
  String get insuranceSavingState => 'Saving certificate...';
  @override
  String get insuranceSaveDraftBtn => 'Save Certificate Draft';
  @override
  String get insuranceCreatedSuccessMsg => '✅ Insurance Certificate created successfully!';
  @override
  String get insuranceUpdatedSuccessMsg => '✅ Insurance Certificate updated successfully!';
  @override
  String insuranceSaveErrorMsg(String err) => '❌ Failed to save certificate: $err';

  @override
  String get insurancePreviewCertificateHeader => 'CERTIFICATE OF CARGO INSURANCE';
  @override
  String get insurancePreviewOfficialIssuedBadge => 'OFFICIALLY ISSUED';
  @override
  String get insurancePreviewDraftBadge => 'DRAFT CERTIFICATE';
  @override
  String get insurancePreviewSecInsuredDetails => '1. Insured & Policy Details';
  @override
  String get insurancePreviewInsuredLabel => 'Insured (Consignee):';
  @override
  String get insurancePreviewCompanyLabel => 'Insurance Company:';
  @override
  String get insurancePreviewPolicyNoLabel => 'Policy Number:';
  @override
  String get insurancePreviewPolicyTypeLabel => 'Policy Type:';
  @override
  String get insurancePreviewSecRouteDetails => '2. Voyage & Transport Route';
  @override
  String get insurancePreviewTransportModeLabel => 'Transport Mode:';
  @override
  String get insurancePreviewVesselFlightLabel => 'Vessel / Flight:';
  @override
  String get insurancePreviewPolLabel => 'Port of Loading (POL):';
  @override
  String get insurancePreviewPodLabel => 'Port of Discharge (POD):';
  @override
  String get insurancePreviewTrackingLabel => 'Tracking / B/L Ref:';
  @override
  String get insurancePreviewSecValuation => '3. Valuation & Insured Sum';
  @override
  String get insurancePreviewInvoiceFobLabel => 'Commercial Invoice (FOB):';
  @override
  String get insurancePreviewFreightLabel => 'Freight & Logistics:';
  @override
  String get insurancePreviewCifBaseLabel => 'CIF Base Value:';
  @override
  String get insurancePreviewInsuredSumLabel => 'Insured Sum (110% CIF):';
  @override
  String get insurancePreviewSecPremium => '4. Premium Breakdown';
  @override
  String get insurancePreviewCoverageClauseLabel => 'Coverage Clause:';
  @override
  String get insurancePreviewBasePremiumLabel => 'Base Premium:';
  @override
  String get insurancePreviewWarStrikesLabel => 'War & Strikes Add-on:';
  @override
  String get insurancePreviewFeesTaxesLabel => 'Fees, Stamp Duty & Taxes:';
  @override
  String get insurancePreviewTotalGrossPremiumLabel => 'Total Payable Gross Premium:';
  @override
  String get insurancePreviewSecCargoSpecs => '5. Cargo Specifications & Clauses';
  @override
  String get insurancePreviewDescPrefix => 'Description:';
  @override
  String get insurancePreviewPackagesPrefix => 'Packages & Weight:';
  @override
  String get insurancePreviewGrossWtPrefix => 'Gross Wt:';
  @override
  String get insurancePreviewSurveyAgentPrefix => 'Survey / Claims Settling Agent:';
  @override
  String get insurancePreviewClaimsPayablePrefix => 'Claims Payable At:';
  @override
  String get insurancePreviewLegalDisclaimer => 'Official Document for Customs Clearance & Bank Form 4';
  @override
  String get insurancePreviewPrintBtn => 'Print / Export PDF';
  @override
  String get insurancePreviewPrintReadySnack => '🖨️ Ready for printing / PDF generation';

  // Export & Copy Data (Cargo Insurance)
  @override
  String get insuranceExportTsvBtn => 'Export TSV';
  @override
  String get insuranceExportExcelBtn => 'Export Excel';
  @override
  String get insurancePrintPdfBtn => 'Print PDF Report';
  @override
  String get insuranceCopyDossierBtn => 'Copy Full Dossier';
  @override
  String get insuranceCopiedTsvSuccess => 'Insurance data copied as TSV to clipboard.';
  @override
  String get insuranceCopiedExcelSuccess => 'Insurance data exported to Excel CSV.';
  @override
  String get insuranceCopiedDossierSuccess => 'Cargo insurance dossier copied to clipboard.';
  @override
  String get insuranceCopyRowSummaryBtn => 'Copy Policy Summary';
  @override
  String get insuranceCopyRowSummarySuccess => 'Insurance certificate summary copied to clipboard.';
  @override
  String get insuranceCopyFieldTooltip => 'Copy Value';
  @override
  String get insuranceSearchCopied => 'Search query copied to clipboard.';
  @override
  String insuranceCopyBadgeSuccess(String label, String value) => 'Copied $label ($value) to clipboard.';
  @override
  String get insurancePdfTitle => 'Cargo & Marine Insurance Certificates Registry';
  @override
  String get insurancePdfSubtitle => 'Official Registry of Issued Cargo Insurance Policies & Coverage Clauses';
  @override
  String get insuranceDossierHeader => 'Cargo & Marine Insurance Policies Dossier';
  @override
  String get insuranceDossierKpiSummary => 'KPIs & Insured Valuation Summary';
  @override
  String get insuranceDossierRecordsDetails => 'Insurance Certificates Registry Details';
  @override
  String get insuranceDossierFooter => 'ImportFlow ERP — Official Marine & Cargo Insurance Hub';

  // ─── HS Code Search & Customs Explorer Screen ──────────────────────────────
  @override
  String get hsExplorerTitle => 'HS Code Explorer & Tariff History';
  @override
  String get hsExplorerSubtitle => 'Real-time inquiries on Egyptian customs tariff codes, taxes, preferential agreements, regulatory requirements, and change history.';
  @override
  String get hsSearchPlaceholder => 'Search by HS Code, description, category, or decree code...';
  @override
  String get hsQuickSearchExamples => 'Quick Search Examples:';
  @override
  String get hsMatchingResultsHeader => 'Matching Tariff Items';
  @override
  String hsItemsCount(int count) => '$count items';
  @override
  String hsNoMatchingItemFound(String query) => 'No items matching "$query"';
  @override
  String hsDutyRateTag(dynamic rate) => 'Duty: $rate%';
  @override
  String get hsSelectFromListPrompt => 'Select a tariff item from the list to preview its comprehensive details and update history';
  @override
  String hsCategoryPrefix(String cat) => 'Category: $cat';
  @override
  String hsEffectiveFromPrefix(String from) => 'Effective from: $from';
  @override
  String hsEffectiveToPrefix(String to) => 'to $to';
  @override
  String get hsEffectiveActiveRecord => '(Approved Live Record)';
  @override
  String get hsDiffHistoryAction => 'Evolution & Diffs Analysis ➔';
  @override
  String get hsTabTaxRates => 'Taxes & Duties';
  @override
  String get hsTabAgreements => 'Trade Agreements';
  @override
  String get hsTabRegulatory => 'Regulatory Requirements';
  @override
  String get hsTabHistory => 'Update History & Timeline';
  @override
  String get hsTabQuickCalculator => 'Instant Duty Calculator';
  @override
  String get hsTaxRatesSectionHeader => 'Statutory Tax & Customs Duty Rates Breakdown:';
  @override
  String get hsTaxImportDutyTitle => 'Customs Import Duty';
  @override
  String get hsTaxImportDutySub => 'Percentage of CIF customs value';
  @override
  String get hsTaxVatTitle => 'Value Added Tax (VAT)';
  @override
  String get hsTaxVatSub => 'Percentage of comprehensive tax base';
  @override
  String get hsTaxScheduleTitle => 'Schedule Tax';
  @override
  String get hsTaxScheduleSub => 'Additional tax per tariff line';
  @override
  String get hsTaxDevFeeTitle => 'Development Fee';
  @override
  String get hsTaxDevFeeSub => 'Financial resources development fee';
  @override
  String get hsTaxImportFeeTitle => 'Import Surcharge Fee';
  @override
  String get hsTaxImportFeeSub => 'Specific/fixed import fee if applicable';
  @override
  String get hsTaxServiceFeeTitle => 'Customs Service Fees';
  @override
  String get hsTaxServiceFeeSub => 'Customs inspection & services';
  @override
  String get hsEgyptianCalculationRule => 'Egyptian Customs Calculation Rule: Import duty is applied first on total CIF value (FOB + Freight + Insurance), then VAT base is calculated as (CIF + Import Duty + Applicable Specific Fees).';
  @override
  String get hsNoAgreementsFound => 'No preferential trade agreements recorded for this item (Standard general tariff applies).';
  @override
  String get hsDefaultAgreementName => 'Preferential Agreement';
  @override
  String hsRequiredDocPrefix(String doc) => 'Required Document: $doc';
  @override
  String hsConditionsPrefix(String note) => 'Conditions: $note';
  @override
  String get hsFullExemptionBadge => 'Full Exemption (0%)';
  @override
  String hsReducedRateBadge(dynamic rate) => 'Reduced Rate ($rate%)';
  @override
  String get hsRegulatorySectionHeader => 'Prior Regulatory Approvals & Clearance Conditions:';
  @override
  String get hsReqAcidSystem => 'ACID Pre-Registration System';
  @override
  String get hsReqCertificateOfOrigin => 'Certificate of Origin (COO)';
  @override
  String get hsReqQualityInspection => 'Quality Conformity Inspection (COC)';
  @override
  String hsRegulatoryAuthorityPrefix(String auth) => 'Competent Regulatory Authority: $auth';
  @override
  String get hsDecreesAndNotesHeader => 'Restricting Regulatory Decrees & Circulars:';
  @override
  String hsHistorySummaryTitle(String code) => 'Historical Revision & Version Timeline for HS Code ($code)';
  @override
  String hsHistoryMultipleVersionsDesc(int count) => 'This item has ($count) recorded historical versions with different validity periods.';
  @override
  String get hsHistorySingleVersionDesc => 'The item is approved in its active live version and registered under audit protection.';
  @override
  String hsVersionsCountTag(int count) => '$count versions';
  @override
  String get hsTimelineSectionTitle => 'Tariff Versions Timeline:';
  @override
  String get hsNoHistoricalVersions => 'No previous version records registered.';
  @override
  String get hsActiveLiveVersionBadge => 'Active Live Version';
  @override
  String get hsArchivedSnapshotBadge => 'Archived Historical Snapshot';
  @override
  String hsRegistrationDatePrefix(String date) => 'Registered on: $date';
  @override
  String hsValidityPeriodPrefix(String from, String to) => 'Validity Period: From $from to $to';
  @override
  String hsApprovedDescPrefix(String desc) => 'Approved Description: $desc';
  @override
  String hsLinkedAgreementsTag(dynamic count) => 'Linked Agreements: $count';
  @override
  String get hsVersionDiffsSummaryHeader => 'Summary of Changes Between Historical Versions:';
  @override
  String hsDiffTitle(String older, String newer) => 'Historical Change: From version ($older) ➔ to version ($newer)';
  @override
  String hsDiffDutyChanged(dynamic oldRate, dynamic newRate) => 'Import Duty: changed from $oldRate% to $newRate%';
  @override
  String hsDiffVatChanged(dynamic oldRate, dynamic newRate) => 'VAT: changed from $oldRate% to $newRate%';
  @override
  String hsDiffScheduleChanged(dynamic oldRate, dynamic newRate) => 'Schedule Tax: changed from $oldRate% to $newRate%';
  @override
  String hsDiffAgreementsChanged(dynamic oldAg, dynamic newAg) => 'Trade Agreements: count changed from $oldAg to $newAg agreements';
  @override
  String get hsDiffMetadataChanged => 'Updated metadata, regulatory authorities, and document conditions';
  @override
  String get hsAuditTrailSectionTitle => 'System Audit Trail & Log History:';
  @override
  String get hsNoAuditLogsFound => 'No direct audit logs recorded yet (Generated by system).';
  @override
  String hsAuditPerformedBy(String by, String date) => 'By: $by • Date: $date';
  @override
  String get hsCalculatorSectionHeader => 'Instant Customs Duty & Tax Calculation for this Item:';
  @override
  String get hsCifValueLabel => 'Shipment CIF Value (in USD \$)';
  @override
  String get hsFreightValueLabel => 'Freight Cost (\$)';
  @override
  String get hsOriginCountryLabel => 'Country of Origin / Trade Agreement';
  @override
  String get hsOriginItalyEur1 => 'Italy (EU Partnership EUR.1)';
  @override
  String get hsOriginGermanyEur1 => 'Germany (EU Partnership EUR.1)';
  @override
  String get hsOriginChinaGeneral => 'China (Standard General Tariff)';
  @override
  String get hsOriginTurkeyFta => 'Turkey (FTA Trade Agreement)';
  @override
  String get hsOriginBrazilMercosur => 'Brazil (Mercosur Trade Agreement)';
  @override
  String get hsOriginSerbiaFta => 'Serbia (FTA Trade Agreement)';
  @override
  String get hsOriginUkPartnership => 'United Kingdom (Partnership Agreement)';
  @override
  String get hsCalculateDutyBtn => 'Calculate Duties';
  @override
  String hsTotalTaxesAndFeesDue(String amount) => 'Total Due Taxes & Customs Fees: $amount EGP';
  @override
  String hsNotePrefix(String note) => 'Note: $note';
  @override
  String hsImportDutyBreakdown(dynamic rate, String amount) => 'Import Duty ($rate%): $amount EGP';
  @override
  String hsVatBreakdown(dynamic rate, String amount) => 'VAT ($rate%): $amount EGP';
  @override
  String hsScheduleBreakdown(String amount) => 'Schedule Tax: $amount EGP';
  @override
  String hsServiceFeeBreakdown(String amount) => 'Service Fees: $amount EGP';
  @override
  String get hsDatePresentOngoing => 'Present (Ongoing)';
  @override
  String get hsDateToday => 'Today';
  @override
  String get hsDateInitial => 'Initial';
  @override
  String get hsActionExecuted => 'Action executed';

  // Screen 45 Additions: Quick queries, Copy & Exports
  @override
  String get hsQuickQueryAc => 'Air Conditioning';
  @override
  String get hsQuickQueryPlastics => 'Plastics';
  @override
  String get hsQuickQueryMeat => 'Meat';
  @override
  String get hsQuickQueryWheat => 'Wheat';

  @override
  String get hsExplorerExportTsvBtn => 'Export TSV';
  @override
  String get hsExplorerExportTsvSuccess => 'HS Code table copied to clipboard as TSV';
  @override
  String get hsExplorerExportExcelBtn => 'Export Excel';
  @override
  String get hsExplorerExportPdfBtn => 'Print / Save PDF';

  @override
  String get hsExplorerCopyHsCodeTooltip => 'Copy HS Code';
  @override
  String get hsExplorerCopySummaryBtn => 'Copy HS Code Dossier';
  @override
  String get hsExplorerCopySummarySuccess => 'HS Code details and duty matrix copied to clipboard';
  @override
  String get hsExplorerCopyDutyBreakdownBtn => 'Copy Duty Calculation';
  @override
  String get hsExplorerCopyDutyBreakdownSuccess => 'Duty calculation matrix copied to clipboard';
  @override
  String get hsExplorerCopyCardRateTooltip => 'Click to copy rate';

  @override
  String get hsExplorerTsvHeaderHsCode => 'HS Code';
  @override
  String get hsExplorerTsvHeaderDescription => 'Description';
  @override
  String get hsExplorerTsvHeaderCategory => 'Category';
  @override
  String get hsExplorerTsvHeaderDutyRate => 'Import Duty %';
  @override
  String get hsExplorerTsvHeaderVatRate => 'VAT Rate %';
  @override
  String get hsExplorerTsvHeaderScheduleRate => 'Schedule Tax %';
  @override
  String get hsExplorerTsvHeaderDevFeeRate => 'Development Fee %';
  @override
  String get hsExplorerTsvHeaderImportFeeRate => 'Import Fee %';
  @override
  String get hsExplorerTsvHeaderServiceFeeRate => 'Service Fees %';
  @override
  String get hsExplorerTsvHeaderRegulatoryAuthority => 'Regulatory Authority';
  @override
  String get hsExplorerTsvHeaderAcidRequired => 'ACID Required';
  @override
  String get hsExplorerTsvHeaderCooRequired => 'COO Required';
  @override
  String get hsExplorerTsvHeaderInspectionRequired => 'Inspection Required';
  @override
  String get hsExplorerTsvHeaderStatus => 'Status';

  // ─── Screen 46: SWIFT Message Reconciliation ──────────────────────────────
  @override
  String get swiftScreenTitle => 'SWIFT Message Reconciliation Center';
  @override
  String get swiftScreenSubtitle => 'Automated parser & real-time matching for bank SWIFT messages and transfer advices';
  @override
  String get swiftLiveSyncActiveBadge => 'Live shipment sync active';
  @override
  String get swiftTotalRequestsMetric => 'Total Payment Requests';
  @override
  String get swiftPendingSwiftMetric => 'Awaiting SWIFT';
  @override
  String get swiftMatchedSwiftMetric => 'Fully Matched';
  @override
  String get swiftVariancesMetric => 'Variances (Deficit/Surplus)';
  @override
  String get swiftAvgProcessingTimeMetric => 'Avg Processing Time';
  @override
  String swiftDaysCount(dynamic days) => '$days days';

  @override
  String get swiftExtractorHeader => 'Smart SWIFT Message Extractor & Real-Time Parser';
  @override
  String get swiftLoadSampleBtn => 'Load Sample MT103';
  @override
  String get swiftCollapseToolTooltip => 'Collapse tool';
  @override
  String get swiftExpandToolTooltip => 'Expand tool';
  @override
  String get swiftExtractedDocLabel => 'Extracted Document:';
  @override
  String get swiftDocTypePrefix => 'Type:';
  @override
  String get swiftDocSizePrefix => 'Size:';
  @override
  String get swiftDocumentDefaultType => 'Document';
  @override
  String get swiftRawTextPlaceholder => 'Paste raw SWIFT MT103 message or bank payment advice here...';
  @override
  String get swiftExtractFromTextBtn => 'Extract from Text';
  @override
  String get swiftUploadFileBtn => 'Upload SWIFT Document';
  @override
  String get swiftExtractingState => 'Extracting...';
  @override
  String get swiftMatchingMatrixTitle => 'Matching Candidate with Target Payment Request';
  @override
  String swiftConfidenceScoreTag(dynamic score) => 'Match Confidence: $score%';
  @override
  String get swiftExecuteReconcileBtn => 'Confirm Match & Reconcile Payment';
  @override
  String get swiftTargetPaymentLabel => 'Target Payment for Reconciliation:';
  @override
  String get swiftExtractedRefPrefix => 'SWIFT Ref:';
  @override
  String get swiftExtractedAmountPrefix => 'Extracted Amount:';
  @override
  String get swiftExtractedDatePrefix => 'Receipt Date:';
  @override
  String get swiftExtractedSenderPrefix => 'Sender:';
  @override
  String get swiftExtractedReceiverPrefix => 'Beneficiary:';

  @override
  String swiftFilterAll(int count) => 'All ($count)';
  @override
  String swiftFilterPending(int count) => 'Awaiting SWIFT ($count)';
  @override
  String swiftFilterMatched(int count) => 'Matched ($count)';
  @override
  String swiftFilterVariances(int count) => 'Variances ($count)';
  @override
  String swiftTableTitle(int count) => 'Payment Requests & SWIFT Reconciliation Ledger ($count)';
  @override
  String get swiftSearchPlaceholder => 'Search by payment code, shipment, supplier, SWIFT ref...';
  @override
  String get swiftNoMatchingRecords => 'No payment requests match the current filter criteria.';
  @override
  String get swiftColPaymentCode => 'Payment Code / Shipment';
  @override
  String get swiftColBeneficiaryBank => 'Beneficiary & Bank';
  @override
  String get swiftColRequestDate => 'Request Date';
  @override
  String get swiftColSwiftDate => 'SWIFT Date';
  @override
  String get swiftColProcessingTime => 'Processing Time';
  @override
  String get swiftColRequestedAmount => 'Requested Amount';
  @override
  String get swiftColTransferredAmount => 'Transferred Amount';
  @override
  String get swiftColVarianceStatus => 'Variance & Match Status';
  @override
  String get swiftChargesLabel => 'Bank Charges (71A)';
  @override
  String get swiftColSwiftRef => 'SWIFT Reference No';
  @override
  String get swiftColActions => 'Actions';

  @override
  String get swiftBadgeMatchedFull => 'Fully Matched';
  @override
  String swiftBadgeDeficit(String amount, String ccy) => 'Deficit ($amount $ccy)';
  @override
  String swiftBadgeSurplus(String amount, String ccy) => 'Surplus (+$amount $ccy)';
  @override
  String get swiftBadgePending => 'Awaiting SWIFT';
  @override
  String get swiftStatusUnregistered => 'Unregistered';
  @override
  String get swiftStatusPendingWait => 'Pending';
  @override
  String get swiftWaitingAmountEntry => 'Awaiting amount entry';
  @override
  String swiftExecutionDaysTag(dynamic days) => '$days days';
  @override
  String swiftExecutionInstantTag(dynamic days) => 'Instant Execution ($days d)';
  @override
  String swiftExecutionReasonableTag(dynamic days) => 'Normal Execution ($days d)';
  @override
  String swiftExecutionDelayedTag(dynamic days) => 'Delayed ($days d)';

  @override
  String get swiftRegisterBtn => 'Register SWIFT';
  @override
  String get swiftEditBtn => 'Edit SWIFT';
  @override
  String get swiftDetailsBtn => 'View Details';
  @override
  String get swiftCloseBtn => 'Close';
  @override
  String get swiftCancelBtn => 'Cancel';
  @override
  String get swiftRefreshBtn => 'Refresh Data';
  @override
  String swiftReconcileDialogTitle(String code) => 'Register & Reconcile SWIFT: $code';
  @override
  String swiftDetailsDialogTitle(String code) => 'SWIFT Details: $code';
  @override
  String get swiftRequestTitleLabel => 'Payment Title:';
  @override
  String get swiftBeneficiaryLabel => 'Beneficiary:';
  @override
  String get swiftBankLabel => 'Bank:';
  @override
  String get swiftAccountLabel => 'Account:';
  @override
  String get swiftRequestDateLabel => 'Request Date';
  @override
  String get swiftRequestedAmountLabel => 'Requested Amount';
  @override
  String get swiftTransferredAmountLabel => 'Transferred Amount';
  @override
  String get swiftVarianceLabel => 'Variance';
  @override
  String get swiftReceiptDateLabel => 'SWIFT Receipt Date *';
  @override
  String get swiftCurrencyLabel => 'Currency *';
  @override
  String get swiftReconciliationNotesLabel => 'Reconciliation Notes & Bank Discrepancies (if any)';
  @override
  String get swiftSyncShipmentNotice => 'The linked import file will be automatically updated with the SWIFT reference once saved.';
  @override
  String get swiftSaveAndSyncBtn => 'Save & Reconcile SWIFT (Sync Shipment)';
  @override
  String get swiftProcessingTimeLabel => 'Processing Time';
  @override
  String swiftDaysBetweenDates(dynamic days) => 'Processing time: $days days between request date and SWIFT receipt';
  @override
  String get swiftSampleMT103Chip => 'Sample MT103';
  @override
  String get swiftPasteAndExtractChip => 'Paste & Extract';
  @override
  String get swiftUploadDocChip => 'Upload Document';
  @override
  String get swiftEnterSwiftRefError => 'Please enter SWIFT reference number';
  @override
  String get swiftEnterAmountError => 'Please enter transferred amount';
  @override
  String get swiftAmountGreaterThanZeroError => 'Transferred amount must be greater than zero';

  @override
  String get swiftFileReadErrorSnack => 'Failed to read the selected file';
  @override
  String swiftExtractSuccessSnack(String filename, String type) => 'Successfully extracted SWIFT data from "$filename" ($type)';
  @override
  String swiftExtractErrorSnack(String error) => 'Failed to extract SWIFT from file: $error';
  @override
  String get swiftEmptyInputErrorSnack => 'Please paste or enter raw SWIFT message / bank advice first';
  @override
  String get swiftParseSuccessSnack => 'SWIFT message parsed and matched to payment request successfully';
  @override
  String swiftParseErrorSnack(String error) => 'Failed to parse SWIFT message: $error';
  @override
  String swiftConnectionErrorSnack(String error) => 'Connection error: $error';
  @override
  String swiftReconcileSuccessSnack(String swiftRef, String paymentCode) => 'SWIFT ($swiftRef) successfully reconciled with payment request ($paymentCode) and import file updated!';
  @override
  String swiftReconcileErrorSnack(String error) => 'Error during reconciliation: $error';

  @override
  String get swiftExportTsvBtn => 'Export TSV';
  @override
  String get swiftExportTsvSuccess => 'Reconciliation data copied to clipboard as TSV successfully';
  @override
  String get swiftExportExcelBtn => 'Export Excel';
  @override
  String get swiftExportPdfBtn => 'Print / Save PDF Report';
  @override
  String get swiftCopySummaryBtn => 'Copy Summary';
  @override
  String get swiftCopySummarySuccess => 'SWIFT reconciliation summary copied to clipboard';
  @override
  String get swiftCopyFieldTooltip => 'Click to copy';
  @override
  String get swiftPrintSlipBtn => 'Print SWIFT Slip';

  @override
  String get swiftTsvHeaderPaymentCode => 'Payment Code';
  @override
  String get swiftTsvHeaderImportFile => 'Import File';
  @override
  String get swiftTsvHeaderBeneficiary => 'Beneficiary';
  @override
  String get swiftTsvHeaderBank => 'Bank';
  @override
  String get swiftTsvHeaderRequestDate => 'Request Date';
  @override
  String get swiftTsvHeaderSwiftReceiptDate => 'SWIFT Date';
  @override
  String get swiftTsvHeaderProcessingDays => 'Processing Days';
  @override
  String get swiftTsvHeaderRequestedAmount => 'Requested Amount';
  @override
  String get swiftTsvHeaderTransferredAmount => 'Transferred Amount';
  @override
  String get swiftTsvHeaderVariance => 'Variance';
  @override
  String get swiftTsvHeaderSwiftRef => 'SWIFT Ref';
  @override
  String get swiftTsvHeaderStatus => 'Status';

  @override
  String get swiftCopyBtn => 'Copy';
  @override
  String get swiftAutoSyncNotice => 'Shipment files live sync active';
  @override
  String get swiftNoMatchingPayments => 'No payment requests match current search criteria.';
  @override
  String get swiftPendingSwiftBadge => 'Pending SWIFT Notification';
  @override
  String get swiftUnspecifiedBank => 'Unspecified Bank';
  @override
  String get swiftProcessingPending => 'Pending';
  @override
  String get swiftUnregistered => 'Unregistered';
  @override
  String get swiftCopyDossierBtn => 'Copy Payment & SWIFT Dossier';

  // Dynamic Report Builder
  @override
  String get dynReportBuilderTitle => 'Dynamic Custom Report Builder';
  @override
  String get dynReportBuilderSubtitle => 'Customize & generate shipment reports with Excel & PDF export';
  @override
  String dynCustomizeColumnsBtn(int visible, int total) => 'Customize Columns ($visible/$total)';
  @override
  String dynExportExcelBtn(int count) => 'Export Excel [$count]';
  @override
  String dynExportPdfBtn(int count) => 'Export PDF [$count]';
  @override
  String get dynFilterModeLabel => 'Shipping Mode';
  @override
  String get dynFilterPriorityLabel => 'Priority';
  @override
  String get dynSearchPlaceholder => 'Dynamic search by file code, company, or supplier...';
  @override
  String get dynModeAll => 'All';
  @override
  String get dynModeSeaFcl => 'Ocean FCL';
  @override
  String get dynModeSeaLcl => 'Ocean LCL';
  @override
  String get dynModeAir => 'Air Freight';
  @override
  String get dynModeCourier => 'Courier';
  @override
  String get dynModeLand => 'Land Freight';
  @override
  String get dynModeMultimodal => 'Multimodal';
  @override
  String get dynPriorityAll => 'All';
  @override
  String get dynPriorityHigh => 'High';
  @override
  String get dynPriorityCritical => 'Critical';
  @override
  String get dynPriorityMedium => 'Medium';
  @override
  String get dynColumnPickerTitle => 'Dynamic Column Picker';
  @override
  String get dynApplyColumnsBtn => 'Apply Selected Columns';
  @override
  String get dynExportCsvTitle => 'Dynamic Report Export (Excel CSV)';
  @override
  String get dynExportCsvGeneratedMsg => 'Custom report generated successfully. You can copy it to use in Excel:';
  @override
  String dynFetchReportError(String err) => 'Error fetching report data: $err';
  @override
  String get dynNoMatchingShipments => 'No shipments match the selected dynamic report filters.';
  @override
  String get dynPdfReportTitle => 'Sorour Logistics ERP — Dynamic Shipment Report';
  @override
  String get dynPdfConfidential => 'Sorour Logistics ERP — Confidential & Internal Use';
  @override
  String dynPdfGenerated(String date, int count) => 'Generated: $date | Total Records: $count';
  @override
  String get dynColImportFileCode => 'File Code';
  @override
  String get dynColCompanyName => 'Importing Company';
  @override
  String get dynColSupplierName => 'Foreign Supplier';
  @override
  String get dynColBrokerName => 'Customs Broker';
  @override
  String get dynColAcidNumber => 'ACID Number';
  @override
  String get dynColForm4No => 'Form 4 Number';
  @override
  String get dynColForm46No => 'Customs Declaration 46';
  @override
  String get dynColShipmentMode => 'Shipping Mode';
  @override
  String get dynColIncotermCode => 'Incoterm Rule';
  @override
  String get dynColPriority => 'Priority';
  @override
  String get dynColEstimatedCost => 'Estimated Value (PI)';
  @override
  String get dynColRequiredEta => 'Estimated Arrival (ETA)';
  @override
  String get dynColCurrentStage => 'Current Stage';
  @override
  String get dynColProgressPercent => 'Progress %';
  @override
  String get dynColOwner => 'Owner / Assignee';
  @override
  String get dynColStatus => 'File Status';
  @override
  String get dynTemplatePresetLabel => 'Report Template';
  @override
  String get dynTemplateCustom => 'Custom Dynamic Builder';
  @override
  String get dynTemplateEco => 'ECO Associates Template (Radar)';
  @override
  String get dynTemplateScas => 'SCAS Construction Template (Tracker)';
  @override
  String dynLastUpdatedLabel(String timestamp) => 'Last Updated: $timestamp';
  @override
  String get dynSearchColumnsPlaceholder => 'Search columns...';
  @override
  String get dynSelectAll => 'Select All';
  @override
  String get dynDeselectAll => 'Deselect All';
  @override
  String get dynCatFileAndProject => 'File, Company & Project Data';
  @override
  String get dynCatCommercialAndPo => 'PO & Commercial Invoices';
  @override
  String get dynCatShippingAndLogistics => 'Shipping, Logistics & Ports';
  @override
  String get dynCatPackagesAndCbm => 'Packages, Weights & CBM';
  @override
  String get dynCatCustomsAndNafeza => 'Customs, Nafeza & CargoX';
  @override
  String get dynCatBankingAndSwift => 'Banking, Form 4 & Swift';
  @override
  String get dynCatScasTracking => 'SCAS Construction & Operations Tracker (16 Cols)';
  @override
  String get dynCatEcoTracking => 'ECO Associates Radar & Original Docs (15 Cols)';
  @override
  String get dynColCustomFileNumber => 'Customer File No';
  @override
  String get dynColProjectNames => 'Project Name';
  @override
  String get dynColNextAction => 'Next Action';
  @override
  String get dynColNotes => 'Operational Notes';
  @override
  String get dynColFileOpeningDate => 'File Opening Date / ETD';
  @override
  String get dynColPoNumber => 'Purchase Order (PO)';
  @override
  String get dynColPiNumber => 'Proforma Invoice (PI)';
  @override
  String get dynColPiValue => 'PI Value';
  @override
  String get dynColShippingLine => 'Shipping Line / Forwarder';
  @override
  String get dynColPortOfLoading => 'Port of Loading (POL)';
  @override
  String get dynColPortOfDischarge => 'Port of Discharge (POD)';
  @override
  String get dynColCargoReadyDate => 'Cargo Ready Date (Pick Up)';
  @override
  String get dynColTargetFreeDays => 'Free Days';
  @override
  String get dynColTotalPackages => 'Total Packages';
  @override
  String get dynColGrossWeightKg => 'Gross Weight (kg)';
  @override
  String get dynColTotalCbm => 'Total CBM';
  @override
  String get dynColAcidIssueDate => 'ACID Issue Date';
  @override
  String get dynColAcidExpiryDate => 'ACID Expiry Date';
  @override
  String get dynColCustomsReleaseStatus => 'Customs Release Status';
  @override
  String get dynColCustomsReleasedAt => 'Customs Release Date';
  @override
  String get dynColForm4ReceivedDate => 'Form 4 Received Date';
  @override
  String get dynColSwiftNo => 'Swift Number';
  @override
  String get dynColSwiftDate => 'Swift Date';
  @override
  String get dynColSwiftAmount => 'Swift Amount';
  @override
  String get dynColUpdatedAt => 'Last Updated Date';
  @override
  String get dynColEcoBroker => 'Custom Broker Name';
  @override
  String get dynColEcoShipmentNo => 'Shipment No';
  @override
  String get dynColEcoSupplier => 'Supp. Name';
  @override
  String get dynColEcoProject => 'Project Name';
  @override
  String get dynColEcoPiValue => 'PI Value';
  @override
  String get dynColEcoShippingDate => 'Shipping Date';
  @override
  String get dynColEcoArrivalPort => 'Arrival Port';
  @override
  String get dynColEcoArrivalWarehouse => 'Arrival Warehouse';
  @override
  String get dynColEcoSara => 'المسئول عن المشروع';
  @override
  String get dynColEcoMaro => 'مالك المشروع';
  @override
  String get dynColEcoReadyToPickUp => 'Ready to Pick Up Date';
  @override
  String get dynColEcoLatestUpdate => 'Latest Update for Pending Shipment';
  @override
  String get dynColEcoSwiftDate => 'تاريخ السويفت (Swift Date)';
  @override
  String get dynColEcoSwiftAmount => 'قيمة السويفت (Swift Amount)';
  @override
  String get dynColEcoShippingCompany => 'شركة الشحن (Shipping Co)';
  @override
  String get dynColEcoAcid => 'ACID';
  @override
  String get dynColScasProjectFileAcid => 'Project';
  @override
  String get dynColScasExFactory => 'EX Factory';
  @override
  String get dynColScasOrderToOrigin => 'Order to Origin for Pick Up';
  @override
  String get dynColScasPickUpDate => 'Pick Up Date from Gind';
  @override
  String get dynColScasDeparturePort => 'Departure Date from Port (ETD)';
  @override
  String get dynColScasArrivalAlexPort => 'Arrival Date to Alex Port (ETA)';
  @override
  String get dynColScasOrigInvoice => 'Original Commercial Invoice';
  @override
  String get dynColScasOrigPackingList => 'Original Packing List';
  @override
  String get dynColScasOrigCoo => 'Original Certificate of Origin';
  @override
  String get dynColScasOrigBl => 'Original Bill of Lading';
  @override
  String get dynColScasOrigInsurance => 'Original Insurance Certificate';
  @override
  String get dynColScasInsertNafeza => 'Insert on Nafeza';
  @override
  String get dynColScasBankForm4 => 'Bank Name (Form 4)';
  @override
  String get dynColScasDeclare3A => 'Declare to 3A';
  @override
  String get dynColScasMaterialReceived => 'Material Received';
  @override
  String get dynRefreshTooltip => 'Refresh Data & Timestamp';
  @override
  String get dynCustomizeColumnsGenericBtn => 'Customize Report Columns';
  @override
  String get dynCopyTsvBtn => 'Copy as TSV';
  @override
  String dynTsvCopiedMsg(int count) => 'Copied data of $count shipments to clipboard successfully';
  @override
  String get dynCopyRowTooltip => 'Copy complete shipment summary';
  @override
  String get dynExportExcelDialogTitle => 'Export Report as Spreadsheet';
  @override
  String get dynExportPdfDialogTitle => 'Export Report as PDF';
  @override
  String dynActiveColumnsCount(int count) => 'Columns: $count';
  @override
  String get dynColumnPickerSubtitle => 'Select fields to include in the report, or use ready presets';
  @override
  String get dynCustomsReleased => 'Released';
  @override
  String get dynCustomsUnderClearance => 'Under Clearance';
  @override
  String dynDaysCount(int count) => '$count Days';
  @override
  String dynGrossWeightKg(String weight) => '$weight kg';
  @override
  String dynTotalCbm(String cbm) => '$cbm CBM';
  @override
  String get dynStatusPending => 'Pending';
  @override
  String get dynStatusDone => 'Done';
  @override
  String get dynStatusReceived => 'Received';
  @override
  String get dynCellOriginOk => 'Origin OK';
  @override
  String get dynCellExpressBl => 'Express BL';
  @override
  String get dynCellOriginCovered => 'Covered (Origin)';
  @override
  String get dynCellIssuedReceived => 'Received / Issued';
  @override
  String get dynCellPendingAcid => 'Pending ACID';
  @override
  String get dynCellPendingBank => 'Pending Bank';
  @override
  String get dynCellPending46 => 'Pending 46';
  @override
  String get dynCellDeliveredWarehouse => 'Delivered to Warehouse';
  @override
  String get dynCellInClearancePort => 'In Clearance (Port)';
  @override
  String dynRecordsCount(int count) => '$count records';

  // ── Screen 68: Comprehensive Import File Report ───────────────────────────
  @override
  String get compReportScreenTitle => 'Comprehensive Import File Report';
  @override
  String get compReportAddUpdateBtn => 'Add Update';
  @override
  String get compReportSelectFileLabel => 'Select Import File to view comprehensive report';
  @override
  String get compReportEmptyStatePrompt => 'Select an import file from the list above\nto view the comprehensive report';
  @override
  String compReportPercentCompleted(String percent) => '$percent% completed';
  @override
  String get compReportCompletedPhases => 'Completed Phases';
  @override
  String get compReportRemainingPhases => 'Remaining Phases';
  @override
  String get compReportPipelineTitle => 'Shipment Operational Lifecycle Pipeline (10 Phases)';
  @override
  String compReportStoppedAtPhase(String phase) => 'Shipment stopped at: $phase';
  @override
  String get compReportSecBasicInfo => 'Basic Import File Details';
  @override
  String get compReportColFileCode => 'File Code';
  @override
  String get compReportColCustomsFileNo => 'Customs File #';
  @override
  String get compReportColImportCompany => 'Importing Company';
  @override
  String get compReportColSupplier => 'Foreign Supplier';
  @override
  String get compReportColBroker => 'Customs Broker';
  @override
  String get compReportColPoNumber => 'PO Number';
  @override
  String get compReportColPiNumber => 'PI Number';
  @override
  String get compReportColShipmentMode => 'Shipment Mode';
  @override
  String get compReportColIncoterm => 'Incoterm Rule';
  @override
  String get compReportColCategory => 'Shipment Category';
  @override
  String get compReportColScenario => 'Selected Scenario';
  @override
  String get compReportColRequiredEta => 'Required ETA';
  @override
  String get compReportColOwner => 'Operational Owner';
  @override
  String get compReportColCreatedAt => 'Creation Date';
  @override
  String get compReportColUpdatedAt => 'Last Updated';
  @override
  String get compReportSecDocs => 'Official Documents & Customs Papers';
  @override
  String get compReportAcidNumber => 'ACID Number (Nafeza)';
  @override
  String get compReportBankForm4 => 'Bank Form 4 Number';
  @override
  String get compReportSwiftNumber => 'SWIFT Wire Reference';
  @override
  String get compReportForm46Number => 'Customs Declaration 46 #';
  @override
  String compReportSecInvoices(int count) => 'Commercial Invoices ($count Invoices)';
  @override
  String get compReportNoInvoices => 'No invoices recorded';
  @override
  String compReportSecPackingLists(int count) => 'Packing Lists & Cargo Specs ($count Lists)';
  @override
  String get compReportNoPackingLists => 'No packing list data recorded';
  @override
  String get compReportTotalPackages => 'Total Packages';
  @override
  String get compReportTotalWeight => 'Total Weight';
  @override
  String get compReportTotalCbm => 'Total Volume CBM';
  @override
  String compReportPackagesUnit(dynamic count) => '$count pkgs';
  @override
  String compReportPiecesUnit(dynamic count) => '$count pcs';
  @override
  String get compReportSecStatus => 'Operational Status & Current Stage';
  @override
  String compReportPriorityPrefix(String priority) => 'Priority: $priority';
  @override
  String get compReportStatusLabel => 'Status';
  @override
  String get compReportCurrentStageLabel => 'Current Stage';
  @override
  String get compReportCurrentModuleLabel => 'Current Module';
  @override
  String get compReportNextActionLabel => 'Next Required Action';
  @override
  String get compReportTotalProgressLabel => 'Overall Progress Rate:';
  @override
  String get compReportSecFinancial => 'Financial Summary';
  @override
  String get compReportTotalInvoicesVal => 'Total Invoices Value';
  @override
  String get compReportEstimatedCostVal => 'Estimated Total Cost';
  @override
  String get compReportEstimatedVariance => 'Estimated Cost Variance';
  @override
  String get compReportSecNotes => 'General Notes';
  @override
  String get compReportNoNotes => 'No general notes recorded.';
  @override
  String compReportSecTimeline(int count) => 'Daily Updates & Operational Log ($count Updates)';
  @override
  String get compReportNoTimelineLogs => 'No operational updates recorded for this shipment yet.';
  @override
  String compReportByPrefix(String user) => 'By: $user';
  @override
  String compReportAlertPriorityPrefix(String priority) => 'Priority: $priority';
  @override
  String get compReportSecClearance => 'Customs Clearance Data (Phase 7)';
  @override
  String get compReportNoClearanceData => 'No customs clearance data recorded';
  @override
  String compReportDeclarationChip(String no) => 'Declaration: $no';
  @override
  String compReportReleasePermitChip(String no) => 'Release Permit: $no';
  @override
  String get compReportDutyImport => 'Import Duty';
  @override
  String get compReportDutyVat => 'VAT';
  @override
  String get compReportDutySchedule => 'Schedule Tax';
  @override
  String get compReportDutyInspection => 'Inspection Fee';
  @override
  String get compReportDutyTotal => 'Total';
  @override
  String compReportPaymentDate(String date) => 'Payment Date: $date';
  @override
  String compReportReleaseDate(String date) => 'Release Date: $date';
  @override
  String get compReportSecWarehouse => 'Warehouse Receiving & GRN Voucher (Phase 8)';
  @override
  String get compReportNoWarehouseData => 'No warehouse receiving data recorded';
  @override
  String compReportGrnChip(String code) => 'GRN: $code';
  @override
  String compReportArrivalDatetime(String date) => 'Arrival: $date';
  @override
  String compReportInspectorPrefix(String name) => 'Inspector: $name';
  @override
  String get compReportQtyInvoiced => 'Invoiced Qty';
  @override
  String get compReportQtyAccepted => 'Accepted';
  @override
  String get compReportQtyShortage => 'Shortage';
  @override
  String get compReportQtyDamaged => 'Damaged';
  @override
  String get compReportTableColCode => 'Code';
  @override
  String get compReportTableColItem => 'Item';
  @override
  String get compReportTableColInvoiced => 'Invoiced';
  @override
  String get compReportTableColAccepted => 'Accepted';
  @override
  String get compReportTableColShortage => 'Shortage';
  @override
  String get compReportTableColDamaged => 'Damaged';
  @override
  String get compReportPhase1Name => 'Planning, Feasibility & Freight';
  @override
  String get compReportPhase2Name => 'Financial Approval & Budget';
  @override
  String get compReportPhase3Name => 'Documents, ACID & Form 4';
  @override
  String get compReportPhase4Name => 'Freight Booking & Carrier';
  @override
  String get compReportPhase5Name => 'Actual Shipping & CargoX';
  @override
  String get compReportPhase6Name => 'Declaration 46 & Customs Tariff';
  @override
  String get compReportPhase7Name => 'Customs Clearance & Duty Payment';
  @override
  String get compReportPhase8Name => 'Warehouse Receiving & GRN';
  @override
  String get compReportPhase9Name => 'Landed Cost Settlement';
  @override
  String get compReportPhase10Name => 'File Closure & Archiving';
  @override
  String get compReportCategoryCostAdjustment => 'Phase Cost Adjustment';
  @override
  String get compReportCategoryFutureAlert => 'Future Phase Alert';
  @override
  String get compReportCategoryDailyCheckIn => 'Daily Check-in';
  @override
  String get compReportCategoryGeneralUpdate => 'General Operational Update';
  @override
  String get compReportExportTsvBtn => 'Export TSV';
  @override
  String get compReportExportExcelBtn => 'Export Excel';
  @override
  String get compReportPrintPdfBtn => 'Print / Save PDF';
  @override
  String get compReportCopyDossierBtn => 'Copy Full Dossier';
  @override
  String get compReportCopyDossierSuccess => 'Comprehensive shipment dossier copied to clipboard';
  @override
  String get compReportExportTsvDialogTitle => 'Export Comprehensive Report as TSV';
  @override
  String get compReportExportExcelDialogTitle => 'Export Comprehensive Report to Excel';
  @override
  String get compReportPrintPdfDialogTitle => 'Print or Save Comprehensive Shipment Report';
  @override
  String get compReportDossierHeader => 'Sorour Logistics ERP — Comprehensive Import File Dossier';
  @override
  String compReportPhaseLabel(int index) => 'Phase $index';
  @override
  String compReportCopyValueTooltip(String field) => 'Copy $field to clipboard';
  @override
  String get compReportCurrencyUsd => 'USD';
  @override
  String get compReportTsvColSection => 'Section';
  @override
  String get compReportTsvColField => 'Field';
  @override
  String get compReportTsvColValue => 'Value';
  @override
  String get compReportTsvColDetails => 'Details / Notes';

  // ── Users Management & RBAC Screen ──────────────────────────────────────────
  @override
  String get usersMgmtTitle => 'Users & Access Control (RBAC)';
  @override
  String usersMgmtSubtitle(int count) => 'User Access Control — $count registered users';
  @override
  String get usersMgmtRefreshTooltip => 'Refresh users list';
  @override
  String get usersMgmtNewUserBtn => 'New User';
  @override
  String get usersMgmtReadOnlyNotice => 'View Only — Admin permission required to edit';
  @override
  String get usersMgmtStatAll => 'All';
  @override
  String get usersMgmtStatActive => 'Active';
  @override
  String get usersMgmtStatAdmin => 'Admin';
  @override
  String get usersMgmtStatManager => 'Manager';
  @override
  String get usersMgmtStatOperator => 'Operator';
  @override
  String get usersMgmtSearchHint => 'Search by name, username, or email...';
  @override
  String get usersMgmtColFullName => 'Full Name';
  @override
  String get usersMgmtColUsername => 'Username';
  @override
  String get usersMgmtColEmail => 'Email Address';
  @override
  String get usersMgmtColRole => 'Role & Access';
  @override
  String get usersMgmtColStatus => 'Status';
  @override
  String get usersMgmtColCreatedAt => 'Created At';
  @override
  String get usersMgmtColActions => 'Actions';
  @override
  String get usersMgmtSelfBadge => '(You)';
  @override
  String get usersMgmtStatusActive => 'Active';
  @override
  String get usersMgmtStatusInactive => 'Disabled';
  @override
  String get usersMgmtRoleAdminLabel => 'Admin';
  @override
  String get usersMgmtRoleManagerLabel => 'Manager';
  @override
  String get usersMgmtRoleOperatorLabel => 'Operator';
  @override
  String get usersMgmtActionEditTooltip => 'Edit user details';
  @override
  String get usersMgmtActionDeactivateTooltip => 'Disable user account';
  @override
  String get usersMgmtActionActivateTooltip => 'Enable user account';
  @override
  String get usersMgmtNoResults => 'No matching users found';
  @override
  String get usersMgmtNoResultsHint => 'Try changing filters or clearing your search';
  @override
  String get usersMgmtRetryBtn => 'Retry';
  @override
  String get usersMgmtDialogEditTitle => 'Edit User Details';
  @override
  String get usersMgmtDialogNewTitle => 'Add New User';
  @override
  String get usersMgmtFieldFullName => 'Full Name *';
  @override
  String get usersMgmtFieldFullNameHint => 'e.g. Ahmed Mohamed Sorour';
  @override
  String get usersMgmtFieldFullNameRequired => 'Full name is required';
  @override
  String get usersMgmtFieldUsername => 'Username *';
  @override
  String get usersMgmtFieldUsernameHint => 'e.g. ahmed_sorour';
  @override
  String get usersMgmtFieldUsernameHelper => 'Username cannot be changed after creation';
  @override
  String get usersMgmtFieldUsernameRequired => 'Username is required';
  @override
  String get usersMgmtFieldUsernameMinLength => 'Username must be at least 3 characters';
  @override
  String get usersMgmtFieldUsernameNoSpaces => 'Username cannot contain spaces';
  @override
  String get usersMgmtFieldEmail => 'Email Address *';
  @override
  String get usersMgmtFieldEmailHint => 'e.g. ahmed@company.com';
  @override
  String get usersMgmtFieldEmailRequired => 'Email is required';
  @override
  String get usersMgmtFieldEmailInvalid => 'Please enter a valid email address';
  @override
  String get usersMgmtFieldRole => 'Role & Permissions *';
  @override
  String get usersMgmtRoleAdminOption => 'Admin — Full system access & user management';
  @override
  String get usersMgmtRoleManagerOption => 'Manager — Operational approvals & advanced reporting';
  @override
  String get usersMgmtRoleOperatorOption => 'Operator — Data entry & shipment execution';
  @override
  String get usersMgmtFieldRoleRequired => 'Please select a role';
  @override
  String get usersMgmtFieldPasswordNew => 'New Password (leave empty to keep unchanged)';
  @override
  String get usersMgmtFieldPassword => 'Password *';
  @override
  String get usersMgmtFieldPasswordRequired => 'Password is required';
  @override
  String get usersMgmtFieldPasswordMinLength => 'Password must be at least 6 characters';
  @override
  String get usersMgmtBtnCancel => 'Cancel';
  @override
  String get usersMgmtBtnSave => 'Save Changes';
  @override
  String get usersMgmtBtnCreate => 'Create User';
  @override
  String get usersMgmtSuccessUpdated => 'User updated successfully';
  @override
  String get usersMgmtSuccessCreated => 'User created successfully';
  @override
  String get usersMgmtConfirmActivateTitle => 'Enable User Account';
  @override
  String get usersMgmtConfirmDeactivateTitle => 'Disable User Account';
  @override
  String get usersMgmtConfirmActivatePrompt => 'Do you want to enable this user account and restore access?';
  @override
  String get usersMgmtConfirmDeactivatePrompt => 'Do you want to disable this user account? The user will not be able to log in.';
  @override
  String get usersMgmtBtnActivate => 'Enable';
  @override
  String get usersMgmtBtnDeactivate => 'Disable';
  @override
  String get usersMgmtSuccessActivated => 'User account enabled successfully';
  @override
  String get usersMgmtSuccessDeactivated => 'User account disabled successfully';
  @override
  String get usersMgmtRoleAdminDescTitle => 'System Administrator — Full Control';
  @override
  String get usersMgmtRoleAdminPerm1 => 'Manage users, permissions, and roles';
  @override
  String get usersMgmtRoleAdminPerm2 => 'Unrestricted access to all screens and tools';
  @override
  String get usersMgmtRoleAdminPerm3 => 'Manage master data and reference tables';
  @override
  String get usersMgmtRoleAdminPerm4 => 'Production database synchronization & backup';
  @override
  String get usersMgmtRoleAdminPerm5 => 'Audit logs review and compliance oversight';
  @override
  String get usersMgmtRoleManagerDescTitle => 'Operations Manager — Advanced Access';
  @override
  String get usersMgmtRoleManagerPerm1 => 'Access to all import files, purchase orders, and shipments';
  @override
  String get usersMgmtRoleManagerPerm2 => 'Approval of budgets, awardings, and operational decisions';
  @override
  String get usersMgmtRoleManagerPerm3 => 'Access and export of all analytics and financial reports';
  @override
  String get usersMgmtRoleManagerPerm4 => 'View reference tables and master data';
  @override
  String get usersMgmtRoleManagerPerm5 => 'Cannot manage user accounts or modify system architecture';
  @override
  String get usersMgmtRoleOperatorDescTitle => 'Logistics Specialist — Operational Access';
  @override
  String get usersMgmtRoleOperatorPerm1 => 'Create and update import files and shipments';
  @override
  String get usersMgmtRoleOperatorPerm2 => 'Enter and match invoices, packing lists, and draft docs';
  @override
  String get usersMgmtRoleOperatorPerm3 => 'Track clearance, customs inspection, and warehouse receiving';
  @override
  String get usersMgmtRoleOperatorPerm4 => 'View operational reports for assigned tasks';
  @override
  String get usersMgmtRoleOperatorPerm5 => 'Cannot modify master data or user accounts';

  // ── Users Management: Permissions Assignment Dialog (Phase 4 RBAC) ──────────
  @override
  String get usersMgmtPermDialogTitle => 'Manage User Permissions';
  @override
  String get usersMgmtPermRoleLabel => 'Assigned Role:';
  @override
  String get usersMgmtPermNoRole => '— No Role Assigned —';
  @override
  String usersMgmtPermRolePermCount(int count) => '$count permissions from role';
  @override
  String get usersMgmtPermLegendGranted => 'Explicitly Granted';
  @override
  String get usersMgmtPermLegendRevoked => 'Explicitly Revoked';
  @override
  String get usersMgmtPermLegendInherited => 'Inherited from Role';
  @override
  String usersMgmtPermOverrideSummary(int grants, int revocations) =>
      '$grants explicit grants · $revocations explicit revocations';
  @override
  String get usersMgmtPermSaveBtn => 'Save Permissions';
  @override
  String get usersMgmtPermSavedSuccess => 'User permissions saved successfully.';
  @override
  String get usersMgmtPermLoadError => 'Failed to load user permissions. Please try again.';
  @override
  String get usersMgmtActionPermissionsTooltip => 'Manage Permissions';

  // ── Screen 66: Export Toolbar, Copy Feedback & Permissions Detail ───────────
  @override
  String get usersMgmtPermBadgeGrant => '+ Grant';
  @override
  String get usersMgmtPermBadgeRevoke => '− Revoke';
  @override
  String get usersMgmtPermBadgeRole => 'Role Default';
  @override
  String get usersMgmtPermTooltipGrant => 'Explicitly grant this permission';
  @override
  String get usersMgmtPermTooltipRevoke => 'Explicitly revoke this permission';
  @override
  String get usersMgmtPermTooltipRevertGrant => 'Remove explicit grant (revert to role)';
  @override
  String get usersMgmtPermTooltipRevertRevoke => 'Remove explicit revocation (revert to role)';
  @override
  String get usersMgmtExportTsvBtn => 'Export TSV';
  @override
  String get usersMgmtExportExcelBtn => 'Export Excel';
  @override
  String get usersMgmtPrintPdfBtn => 'Print PDF';
  @override
  String get usersMgmtCopyDossierBtn => 'Copy Dossier';
  @override
  String get usersMgmtCopiedTsvSuccess => 'Users table copied to clipboard as TSV successfully.';
  @override
  String get usersMgmtCopiedExcelSuccess => 'Users Excel file exported successfully.';
  @override
  String get usersMgmtCopiedDossierSuccess => 'Users dossier summary copied to clipboard successfully.';
  @override
  String get usersMgmtCopyRowSummaryBtn => 'Copy Row Summary';
  @override
  String get usersMgmtCopyRowSummarySuccess => 'User row summary copied to clipboard.';
  @override
  String usersMgmtCopyBadgeSuccess(String label, String value) => 'Copied $label: $value successfully.';
  @override
  String get usersMgmtSearchCopied => 'Search query copied to clipboard.';
  @override
  String usersMgmtCopyFieldTooltip(String field) => 'Copy $field';
  @override
  String get usersMgmtPdfTitle => 'Users Management & RBAC Security Report';
  @override
  String get usersMgmtPdfSubtitle => 'Official Accounts Directory, Role Assignments & Access Control';
  @override
  String get usersMgmtDossierHeader => '=== USERS MANAGEMENT & RBAC DOSSIER (IMPORTFLOW ERP) ===';
  @override
  String get usersMgmtDossierKpiSummary => '--- ACCOUNTS & ROLES METRICS SUMMARY ---';
  @override
  String get usersMgmtDossierRecordsDetails => '--- USER ACCOUNTS DIRECTORY DETAILS ---';
  @override
  String get usersMgmtDossierFooter => '=== END OF USERS MANAGEMENT REPORT — IMPORTFLOW ERP ===';

  // ── Screen: Smart Tasks & Reminder Engine ──────────────────────────────────
  @override
  String get smartTasksTitle => 'Smart Tasks & Reminder Engine';
  @override
  String get smartTasksNewTaskBtn => 'Add New Task';
  @override
  String get smartTasksFilterType => 'Task Type';
  @override
  String get smartTasksTypeAll => 'All Types';
  @override
  String get smartTasksTypeSystem => 'Automated';
  @override
  String get smartTasksTypeManual => 'Manual';
  @override
  String get smartTasksFilterPriority => 'Priority';
  @override
  String get smartTasksPriorityAll => 'All Priorities';
  @override
  String get smartTasksPriorityLow => 'Low';
  @override
  String get smartTasksPriorityMedium => 'Medium';
  @override
  String get smartTasksPriorityHigh => 'High';
  @override
  String get smartTasksPriorityCritical => 'Critical';
  @override
  String get smartTasksFilterStatus => 'Status';
  @override
  String get smartTasksStatusAll => 'All Statuses';
  @override
  String get smartTasksStatusPending => 'Pending';
  @override
  String get smartTasksStatusInProgress => 'In Progress';
  @override
  String get smartTasksStatusCompleted => 'Completed';
  @override
  String get smartTasksStatusCancelled => 'Cancelled';
  @override
  String get smartTasksResetFiltersTooltip => 'Reset Filters';
  @override
  String get smartTasksTableTitle => 'Smart Tasks & Operational Reminders Table';
  @override
  String get smartTasksColCode => 'Task Code';
  @override
  String get smartTasksColType => 'Task Type';
  @override
  String get smartTasksColTitle => 'Task Title & Details';
  @override
  String get smartTasksColShipment => 'Linked Shipment';
  @override
  String get smartTasksColPriority => 'Priority';
  @override
  String get smartTasksColReminder => 'Reminder Engine';
  @override
  String get smartTasksColDueDate => 'Due Date';
  @override
  String get smartTasksColStatus => 'Status';
  @override
  String get smartTasksColActions => 'Actions';
  @override
  String get smartTasksGeneralBadge => 'General';
  @override
  String get smartTasksActionCompleteTooltip => 'Complete Task';
  @override
  String get smartTasksActionEditTooltip => 'Edit Task';
  @override
  String get smartTasksActionDeleteTooltip => 'Delete Task';
  @override
  String smartTasksBulkCompleteBtn(int count) => 'Complete $count Tasks';
  @override
  String smartTasksBulkCompleteSuccess(int count) => 'Successfully completed $count tasks';
  @override
  String smartTasksFetchError(String err) => 'Error fetching tasks: $err';
  @override
  String get smartTasksEmptyMessage => 'No tasks or reminders match current filters';
  @override
  String get smartTaskDialogEditTitle => 'Edit Task & Reminder';
  @override
  String get smartTaskDialogNewTitle => 'Add New Task & Reminder';
  @override
  String get smartTaskFieldTitle => 'Task / Reminder Title *';
  @override
  String get smartTaskFieldTitleRequired => 'Task title is required';
  @override
  String get smartTaskFieldLinkShipment => 'Link to Import File / Shipment (Optional)';
  @override
  String get smartTaskFieldPriority => 'Priority Level';
  @override
  String get smartTaskFieldReminderType => 'Reminder Engine Type';
  @override
  String get smartTaskFieldDueDate => 'Required Due Date';
  @override
  String get smartTaskFieldReminderDate => 'Alert & Reminder Date';
  @override
  String get smartTaskFieldDescription => 'Task Description & Requirements';
  @override
  String get smartTaskFieldNotes => 'Additional Operational Notes';
  @override
  String get smartTaskBtnCancel => 'Cancel';
  @override
  String get smartTaskBtnUpdate => 'Update Task';
  @override
  String get smartTaskBtnSave => 'Save Task & Reminder';
  @override
  String get smartTaskSuccessUpdated => 'Task updated successfully';
  @override
  String get smartTaskSuccessCreated => 'Task & reminder added successfully';
  @override
  String smartTaskSubmitError(String err) => 'Error saving task: $err';
  @override
  String smartTaskPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }
  @override
  String smartTaskStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  @override
  String smartTaskReminderTypeLabel(String type) {
    switch (type) {
      case 'General Reminder':
        return 'General Reminder';
      case 'Supplier Follow-up':
        return 'Supplier Follow-up';
      case 'Bank Form 4':
        return 'Bank Form 4';
      case 'Shipping Line':
        return 'Shipping Line';
      case 'Customs Broker':
        return 'Customs Broker';
      case 'Document Review':
        return 'Document Review';
      case 'ETA Arrival':
        return 'Shipment ETA Arrival';
      default:
        return type;
    }
  }
  @override
  String get smartTasksExportTsvBtn => 'Copy TSV Table';
  @override
  String get smartTasksExportTsvSuccess => 'Smart tasks copied to clipboard as TSV table';
  @override
  String get smartTasksExportPdfBtn => 'Print Tasks Report';
  @override
  String get smartTasksExportExcelBtn => 'Export Excel';
  @override
  String get smartTaskCopySummaryBtn => 'Copy Task Summary';
  @override
  String get smartTaskCopySummarySuccess => 'Task summary copied to clipboard';
  @override
  String get smartTaskPrintPdfTooltip => 'Print Task Slip';
  @override
  String get smartTaskShareWhatsappTooltip => 'Share via WhatsApp';
  @override
  String get smartTaskCodeBadgeLabel => 'Task Code: Click to copy';
  @override
  String get smartTaskImportFileBadgeLabel => 'Shipment Code: Click to copy';
  @override
  String get smartTaskCopyFieldTooltip => 'Copy field to clipboard';
  @override
  String get smartTasksTsvHeaderCode => 'Task Code';
  @override
  String get smartTasksTsvHeaderType => 'Task Type';
  @override
  String get smartTasksTsvHeaderTitle => 'Task Title';
  @override
  String get smartTasksTsvHeaderShipment => 'Linked Shipment';
  @override
  String get smartTasksTsvHeaderPriority => 'Priority';
  @override
  String get smartTasksTsvHeaderReminder => 'Reminder Type';
  @override
  String get smartTasksTsvHeaderDueDate => 'Due Date';
  @override
  String get smartTasksTsvHeaderStatus => 'Status';
  @override
  String get smartTasksTsvHeaderAssignedUser => 'Assigned User';
  @override
  String get smartTasksTsvHeaderDescription => 'Description';

  // ── Screen 42: Operational & Daily Shipment Updates Engine ─────────────────
  @override
  String get shipmentUpdateEngineTitle => 'Operational & Daily Shipment Updates Engine';
  @override
  String get shipmentUpdateRefreshTooltip => 'Refresh Data';
  @override
  String shipmentUpdateErrorLoadingShipments(String err) => 'Error loading shipments: $err';
  @override
  String get shipmentUpdateNoShipmentsRegistered => 'No shipments registered in the system yet.';
  @override
  String get shipmentUpdateSelectShipmentPrompt => 'Select shipment to inspect phases & record operational updates';
  @override
  String shipmentUpdateDropdownLabel(String fileCode, String supplier, String stage) =>
      '$fileCode | Supplier: $supplier | Current Stage: $stage';
  @override
  String get shipmentUpdateComprehensiveDailyCheckinBtn => 'Comprehensive Daily Check-in';
  @override
  String shipmentUpdatePipelineTitle(String fileCode) =>
      'Interactive Shipment Phase Roadmap ($fileCode) — Click any phase to update:';
  @override
  String shipmentUpdateCurrentStage(String stage) => 'Current Stage: $stage';
  @override
  String get shipmentUpdatePhase1Name => 'P1: Planning & Feasibility';
  @override
  String get shipmentUpdatePhase2Name => 'P2: Financial Approval';
  @override
  String get shipmentUpdatePhase3Name => 'P3: Docs & ACID Issue';
  @override
  String get shipmentUpdatePhase4Name => 'P4: Freight Booking';
  @override
  String get shipmentUpdatePhase5Name => 'P5: Shipping & CargoX';
  @override
  String get shipmentUpdatePhase6Name => 'P6: Form 46 & Tariff';
  @override
  String get shipmentUpdatePhase7Name => 'P7: Clearance & Duties';
  @override
  String get shipmentUpdatePhase8Name => 'P8: Warehouse GRN';
  @override
  String get shipmentUpdatePhase9Name => 'P9: Landed Cost Settlement';
  @override
  String get shipmentUpdatePhase10Name => 'P10: File Closure & Archive';
  @override
  String get shipmentUpdateStatusCompleted => 'Completed';
  @override
  String get shipmentUpdateStatusCurrent => 'Current';
  @override
  String get shipmentUpdateStatusFuture => 'Upcoming';
  @override
  String shipmentUpdateCountBadge(int count) => 'Updates: $count entries';
  @override
  String get shipmentUpdateCustomsSecTitle => 'Customs Consultation & Inspection Checklist Records';
  @override
  String shipmentUpdateCustomsStudiesCount(int count) => '$count studies recorded & saved';
  @override
  String get shipmentUpdateCustomsNoStudies => 'No recorded studies';
  @override
  String get shipmentUpdateCustomsEmptyPrompt =>
      'No customs consultation study has been saved for this shipment yet. You can open "Customs Consultation Center" to seed tariff items and checklist.';
  @override
  String shipmentUpdateBrokerPrefix(String broker) => 'Customs Broker: $broker';
  @override
  String get shipmentUpdateMetricEstDuties => '💰 Est. Duties & Taxes';
  @override
  String get shipmentUpdateMetricApprovedDocs => '📄 Approved Documents';
  @override
  String shipmentUpdateMetricDocsRatio(int approved, int total) => '$approved of $total docs';
  @override
  String get shipmentUpdateMetricBlockingIssues => '🚫 Active Blocking Issues';
  @override
  String shipmentUpdateMetricBlockingCount(int count) => '$count blocking issues';
  @override
  String get shipmentUpdateMetricZeroBlocking => '0 issues (Ready)';
  @override
  String get shipmentUpdateMetricReadinessRate => 'Readiness Rate:';
  @override
  String get shipmentUpdateBtnPrintPdf => 'Print Report (PDF)';
  @override
  String get shipmentUpdateBtnViewChecklist => 'View Inspection Checklist';
  @override
  String get shipmentUpdateBtnEditDocs => 'Edit & Review Documents';
  @override
  String get shipmentUpdateBtnRecordDailyUpdate => 'Record Daily Update';
  @override
  String shipmentUpdateConsultDialogEditTitle(String code) => '✏️ Edit & Review Consultation Study: $code';
  @override
  String shipmentUpdateConsultDialogViewTitle(String code) => 'Customs Consultation Details: $code';
  @override
  String get shipmentUpdateConsultPrintTooltip => 'Print Customs Consultation Report (PDF)';
  @override
  String get shipmentUpdateConsultSwitchViewTooltip => 'Switch to View Mode';
  @override
  String get shipmentUpdateConsultSwitchEditTooltip => 'Switch to Edit Mode';
  @override
  String shipmentUpdateConsultBrokerPrefix(String broker) => 'Customs Broker: $broker';
  @override
  String shipmentUpdateConsultEstDuties(String amount) => 'Estimated Duties: $amount EGP';
  @override
  String get shipmentUpdateConsultOverallStatusLabel => 'Overall Status: ';
  @override
  String shipmentUpdateConsultStatus(String status) => 'Status: $status';
  @override
  String get shipmentUpdateConsultReadinessRateLabel => 'Readiness Rate';
  @override
  String get shipmentUpdateConsultTotalDocsLabel => 'Total Documents';
  @override
  String get shipmentUpdateConsultApprovedLabel => 'Approved';
  @override
  String get shipmentUpdateConsultBlockingLabel => 'Blocking Issues';
  @override
  String get shipmentUpdateConsultChecklistSectionTitle => 'Customs Inspection Checklist & Regulatory Requirements:';
  @override
  String get shipmentUpdateConsultEditModeBanner => '⚡ Interactive edit mode active — click to update any document status';
  @override
  String get shipmentUpdateConsultColDocType => 'Document Type & Items';
  @override
  String get shipmentUpdateConsultColResponsibleParty => 'Responsible Party';
  @override
  String get shipmentUpdateConsultColStatus => 'Status';
  @override
  String get shipmentUpdateConsultColRemarks => 'Remarks & Conditions';
  @override
  String get shipmentUpdateConsultBlockingTooltip => 'Critical blocking issue for clearance / shipment';
  @override
  String shipmentUpdateConsultHsCodesPrefix(String hs) => 'HS Codes: $hs';
  @override
  String get shipmentUpdateConsultSaveBtn => '💾 Save Changes';
  @override
  String get shipmentUpdateConsultSavingBtn => 'Saving...';
  @override
  String get shipmentUpdateConsultCloseBtn => 'Close';
  @override
  String shipmentUpdateConsultSaveSuccess(String code) => '✅ Customs consultation $code updated successfully!';
  @override
  String shipmentUpdateConsultSaveError(String err) => 'Error saving changes: $err';
  @override
  String shipmentUpdateLogsFetchError(String err) => 'Error fetching update logs: $err';
  @override
  String get shipmentUpdateLogsEmptyMessage => 'No operational updates recorded for this shipment yet.';
  @override
  String get shipmentUpdateColActions => '⚡ Actions';
  @override
  String get shipmentUpdateColCode => 'Update Code';
  @override
  String get shipmentUpdateColDate => 'Date';
  @override
  String get shipmentUpdateColType => 'Category';
  @override
  String get shipmentUpdateColTargetStage => 'Target Stage';
  @override
  String get shipmentUpdateColNotes => 'Operational Update Notes & Details';
  @override
  String get shipmentUpdateColCostAdjustment => 'Cost Adjustment';
  @override
  String get shipmentUpdateColAssignedUser => 'Assigned User';
  @override
  String get shipmentUpdateBadgeDaily => 'Daily Check-in';
  @override
  String get shipmentUpdateBadgeCostAdj => 'Cost Adjustment';
  @override
  String get shipmentUpdateBadgeFollowUp => 'Stage Follow-up';
  @override
  String get shipmentUpdateBadgeFutureAlert => 'Stage Alert';
  @override
  String get shipmentUpdateActionViewTooltip => 'View Update Details';
  @override
  String get shipmentUpdateActionEditTooltip => 'Edit Update';
  @override
  String get shipmentUpdateActionPrintTooltip => 'Print Update Log';
  @override
  String get shipmentUpdateActionDeleteTooltip => 'Delete Update Log';
  @override
  String shipmentUpdateViewDialogTitle(String code) => 'Update Details: $code';
  @override
  String shipmentUpdateViewStage(String stage) => 'Stage: $stage';
  @override
  String shipmentUpdateViewDate(String date) => 'Date: $date';
  @override
  String shipmentUpdateViewUser(String user) => 'User: $user';
  @override
  String get shipmentUpdateViewNotes => 'Notes:';
  @override
  String get shipmentUpdateViewCloseBtn => 'Close';
  @override
  String shipmentUpdatePrintSnackBar(String code, String stage) => 'Printing update log: $code ($stage)';
  @override
  String get shipmentUpdateDeleteConfirmTitle => 'Confirm Deletion';
  @override
  String shipmentUpdateDeleteConfirmMsg(String code) => 'Are you sure you want to delete update log $code?';
  @override
  String get shipmentUpdateDeleteCancelBtn => 'Cancel';
  @override
  String get shipmentUpdateDeleteConfirmBtn => 'Confirm Delete';
  @override
  String get shipmentUpdateDialogTitle => 'Shipment Operational & Daily Update Engine';
  @override
  String get shipmentUpdateFieldShipmentLabel => 'Select Shipment to Update *';
  @override
  String get shipmentUpdateFieldShipmentRequired => 'Please select the shipment to record update for';
  @override
  String get shipmentUpdateFieldCategoryLabel => 'Update Category *';
  @override
  String get shipmentUpdateCatOptFollowUp => '1. Stage Follow-up & Notes';
  @override
  String get shipmentUpdateCatOptCostAdjustment => '2. Stage Data / Cost Adjustment';
  @override
  String get shipmentUpdateCatOptFutureAlert => '3. Future Stage Alert / Unlock';
  @override
  String get shipmentUpdateCatOptDailyCheckin => '4. Daily Shipment Check-in';
  @override
  String get shipmentUpdateFieldTargetStageLabel => 'Target Stage *';
  @override
  String get shipmentUpdateFieldCostItemLabel => 'Adjusted Cost Item / Line';
  @override
  String get shipmentUpdateFieldPrevCostLabel => 'Previous Cost';
  @override
  String get shipmentUpdateFieldNewCostLabel => 'New Cost';
  @override
  String get shipmentUpdateFieldAlertPriorityLabel => 'Alert Priority Level *';
  @override
  String get shipmentUpdatePriorityLow => 'Low';
  @override
  String get shipmentUpdatePriorityNormal => 'Normal';
  @override
  String get shipmentUpdatePriorityHigh => 'High';
  @override
  String get shipmentUpdatePriorityCritical => 'Critical';
  @override
  String get shipmentUpdateFieldDateLabel => 'Update Date *';
  @override
  String get shipmentUpdateFieldNotesLabel => 'Update Details & Operational Notes *';
  @override
  String get shipmentUpdateFieldNotesHint => 'Enter daily update notes or operational details...';
  @override
  String get shipmentUpdateFieldNotesRequired => 'Please enter update notes or details';
  @override
  String get shipmentUpdateBtnCancel => 'Cancel';
  @override
  String get shipmentUpdateBtnSaveUpdate => 'Save & Record Update';
  @override
  String get shipmentUpdateSuccessSaved => 'Operational update / daily check-in recorded successfully';
  @override
  String shipmentUpdateErrorSaving(String err) => 'Error saving update: $err';
  @override
  String get shipmentUpdatesExportTsvBtn => 'Export TSV';
  @override
  String get shipmentUpdatesExportTsvSuccess => 'Shipment updates copied to clipboard as TSV successfully';
  @override
  String get shipmentUpdatesExportExcelBtn => 'Export Excel';
  @override
  String get shipmentUpdatesExportPdfBtn => 'Export PDF';
  @override
  String get shipmentUpdateCopySummaryBtn => 'Copy Update Summary';
  @override
  String get shipmentUpdateCopySummarySuccess => 'Shipment update summary copied to clipboard successfully';
  @override
  String get shipmentUpdateCodeBadgeLabel => 'Update code copied to clipboard';
  @override
  String get shipmentUpdateConsultCodeBadgeLabel => 'Customs consultation code copied to clipboard';
  @override
  String get shipmentUpdateCopyFieldTooltip => 'Copy value to clipboard';
  @override
  String get shipmentUpdatesTsvHeaderCode => 'Update Code';
  @override
  String get shipmentUpdatesTsvHeaderDate => 'Date';
  @override
  String get shipmentUpdatesTsvHeaderCategory => 'Category';
  @override
  String get shipmentUpdatesTsvHeaderPhase => 'Target Phase';
  @override
  String get shipmentUpdatesTsvHeaderNotes => 'Notes & Details';
  @override
  String get shipmentUpdatesTsvHeaderCostItem => 'Adjusted Cost Item';
  @override
  String get shipmentUpdatesTsvHeaderPrevCost => 'Previous Cost';
  @override
  String get shipmentUpdatesTsvHeaderNewCost => 'New Cost';
  @override
  String get shipmentUpdatesTsvHeaderPriority => 'Priority';
  @override
  String get shipmentUpdatesTsvHeaderAssignedUser => 'Assigned User';
  @override
  String get shipmentUpdatesTsvHeaderStatus => 'Phase Status';
  @override
  String get shipmentUpdateConsultStatusInProgress => 'In Progress';
  @override
  String get shipmentUpdateConsultStatusClearanceReady => 'Clearance Ready';
  @override
  String get shipmentUpdateConsultStatusBlocked => 'Blocked';
  @override
  String get shipmentUpdateConsultStatusActionRequired => 'Action Required';
  @override
  String get shipmentUpdateConsultStatusCompleted => 'Completed';
  @override
  String get shipmentUpdateDocStatusApproved => 'Approved';
  @override
  String get shipmentUpdateDocStatusPending => 'Pending';
  @override
  String get shipmentUpdateDocStatusReceived => 'Received';
  @override
  String get shipmentUpdateDocStatusVerified => 'Verified';
  @override
  String get shipmentUpdateDocStatusRejected => 'Rejected';
  @override
  String get shipmentUpdateCostLabel => 'Cost';
  @override
  String get shipmentUpdateCostCurrencyUsd => 'USD';

  // Error Details Dialog & Diagnostic Formatter
  @override
  String get errorDefaultSummary => 'An error occurred while processing the request';
  @override
  String get errorDialogDefaultSubtitle => 'Please review and correct the errors to proceed successfully:';
  @override
  String get errorServerResponseField => 'Server Response';
  @override
  String get errorServerResponseRecommendation => 'Please review and correct data according to server instructions.';
  @override
  String get errorValidationSummary => 'Validation errors occurred in the submitted data:';
  @override
  String get errorUnspecifiedField => 'Unspecified Field';
  @override
  String get errorInvalidValue => 'Invalid value';
  @override
  String get errorStandardRecommendation => 'Please enter a valid value matching requirements.';
  @override
  String get errorFieldRequiredMsg => 'This field is required and cannot be left empty.';
  @override
  String get errorFieldRequiredRec => 'Fill in this field before saving data.';
  @override
  String get errorValidDateMsg => 'Invalid date format.';
  @override
  String get errorValidDateRec => 'Ensure the date format is YYYY-MM-DD.';
  @override
  String get errorMinLengthMsg => 'The entered value is too short.';
  @override
  String get errorMinLengthRec => 'Enter a clear and complete text.';
  @override
  String get errorConnectionSummary => 'Unable to connect to the backend server';
  @override
  String get errorConnectionPointUnavailable => 'Backend server is currently unavailable or stopped.';
  @override
  String errorConnectionPointTarget(String targetUri) => 'Target endpoint: $targetUri';
  @override
  String get errorConnectionPointCors => 'If using a web browser, make sure the server is running and requests are not blocked.';
  @override
  String get errorConnectionFieldName => 'Server Connection';
  @override
  String errorConnectionIssueDesc(String targetUri, String errorDetail) => 'Failed to reach $targetUri ($errorDetail)';
  @override
  String get errorConnectionRecommendation => 'Make sure the backend server is running and refresh the page.';
  @override
  String get errorTimeoutSummary => 'Server response timed out.';
  @override
  String get errorTimeoutPoint => 'The server took longer than usual. Please retry.';
  @override
  String get errorTimeoutFieldName => 'Connection Timeout';
  @override
  String get errorTimeoutIssueDesc => 'The request timed out without receiving a response from the server.';
  @override
  String get errorTimeoutRecommendation => 'Check your network connection speed and retry.';
  @override
  String get errorConnectionBannerHint => '💡 Backend server is currently unavailable. Please ensure the local server is running and retry.';
  @override
  String errorTableSectionTitle(int count) => '📋 Validation errors and blocking issues to resolve ($count):';
  @override
  String get errorColFieldCondition => 'Field / Condition';
  @override
  String get errorColDescription => 'Issue Description';
  @override
  String get errorColAction => 'Recommended Action';
  @override
  String get errorBtnHideTechnicalLog => 'Hide Technical Diagnostic Log';
  @override
  String get errorBtnShowTechnicalLog => 'Show Diagnostic Log for Developers';
  @override
  String get errorBtnCopyReport => 'Copy Diagnostic Report';
  @override
  String get errorReportHeader => '=== Sorour Logistics ERP Diagnostic Report ===';
  @override
  String get errorReportDateTime => 'Date & Time:';
  @override
  String get errorReportTitle => 'Title:';
  @override
  String get errorReportSummary => 'Summary:';
  @override
  String get errorReportType => 'Error Type:';
  @override
  String get errorReportTypeConnection => 'Connection / CORS Error';
  @override
  String get errorReportTypeValidation => 'Validation / Server Error';
  @override
  String errorReportIssues(int count) => 'Issues & Missing Data ($count):';
  @override
  String get errorReportRawLog => 'Full Technical Log:';
  @override
  String get errorReportCopiedSnackBar => '📋 Diagnostic report copied to clipboard!';
  @override
  String get errorBtnRetrying => 'Retrying...';
  @override
  String get errorBtnRetryNow => 'Retry Now';
  @override
  String errorRetryFailedSnackBar(String err) => '❌ Retry failed: $err';
  @override
  String get errorBtnFixAndClose => 'Understood, I will fix the issues';
  @override
  String errorFieldName(String key) {
    switch (key) {
      case 'importer_name':
        return 'Importer Company Name';
      case 'importer_tax_id':
        return 'Importer Tax ID';
      case 'importer_address':
        return 'Importer Address';
      case 'exporter_name':
        return 'Supplier / Exporter Name';
      case 'exporter_reg_type':
        return 'Exporter Registration Type';
      case 'exporter_reg_id':
        return 'Exporter Tax / Reg ID';
      case 'exporter_country':
        return 'Supplier Country';
      case 'exporter_country_code':
        return 'Country Code';
      case 'exporter_address':
        return 'Exporter Address';
      case 'exporter_phone':
        return 'Exporter Phone';
      case 'cargox_id':
        return 'Exporter CargoX ID';
      case 'proforma_invoice_no':
        return 'Proforma Invoice No.';
      case 'proforma_invoice_date':
        return 'Proforma Invoice Date';
      case 'invoice_date':
        return 'Invoice Date';
      case 'invoice_type':
        return 'Invoice Type';
      case 'po_number':
        return 'Purchase Order Number';
      case 'po_date':
        return 'Purchase Order Date';
      case 'pol_name':
        return 'Port of Loading';
      case 'pod_name':
        return 'Port of Discharge';
      case 'customs_broker_name':
        return 'Customs Broker Name';
      case 'customs_broker_id':
        return 'Customs Broker ID';
      case 'customs_broker_phone':
        return 'Customs Broker Phone';
      case 'requested_date':
        return 'Requested Date';
      case 'acid_number':
        return 'ACID Number';
      case 'generated_date':
        return 'ACID Issue Date';
      case 'expiry_date':
        return 'Expiry Date';
      case 'items':
        return 'Shipment Items & Quotes';
      case 'cargo_ready_date':
        return 'Cargo Ready Date';
      case 'title':
        return 'Title / Subject';
      case 'consultation_title':
        return 'Customs Consultation Title';
      case 'amount':
        return 'Amount / Financial Value';
      case 'currency':
        return 'Currency';
      default:
        return key;
    }
  }

  // Regulatory Requirements - Per-HS-Code & Adaptive Banners
  @override String get decree43WarningNotRegistered => 'Decree 43 Warning: Foreign factory is not verified on GOEIC White List';
  @override String get decree43WarningNotRegisteredDesc => 'Item is subject to Decree 43/2016. Shipping without factory registration may lead to release blockage or re-exportation upon arrival.';
  @override String get decree43OptionRequestJustification => 'Request Approval / Exemption Justification';
  @override String get decree43OptionCreateDashboardTask => 'Keep Note & Create Dashboard Task';
  @override String get decree43JustificationDialogTitle => 'Record Approval & Exemption Justification (Decree 43)';
  @override String get decree43JustificationDialogDesc => 'Please specify or enter the legal basis for approving the import of this item without factory registration:';
  @override String get decree43JustificationReasonProductionInput => 'Production input for a licensed factory under industrial registry (Exempt from Decree 43)';
  @override String get decree43JustificationReasonPrivateUse => 'Import for private company use (not intended for commercial trade)';
  @override String get decree43JustificationReasonSpareParts => 'Spare parts and maintenance components for an existing production line';
  @override String get decree43JustificationReasonMinisterialExemption => 'Approved ministerial exception from the Minister of Trade and Industry';
  @override String get decree43JustificationReasonCustom => 'Other custom legal exemption reason...';
  @override String get decree43JustificationSavedBadge => 'Approved by Justified Exemption';
  @override String get decree43TaskCreatedBadge => 'Dashboard Task Created [Critical]';
  @override String get decree43TaskCreatedSuccessSnack => 'Urgent factory registration task created successfully in Dashboard';
  @override String get adaptivePillarMandatoryRequirements => 'Mandatory Requirements:';
  @override String get adaptivePillarComplianceAlert => 'Compliance Status & Alerts:';
  @override String get adaptivePillarLegalExemptions => 'Legal Exemptions & Exceptions:';
  @override String get hsCodeSequenceNavTitle => 'Shipment Tariff HS Codes Compliance Sequence';
  @override String get hsCodeFulfillmentStatus => 'Item Compliance:';
  @override String get hsCodeFullyCompliantChip => '5/5 Complete';
  @override String get hsCodePendingPillarsChip => 'Pending Pillars';

  // ── Freight Booking Cost Savings & Comparison ──────────────────────────────
  @override String get freightBookingOriginalQuotedPrice => 'Original Quoted Price';
  @override String get freightBookingExecutedPrice => 'Executed Booking Price';
  @override String get freightBookingCostSavingsTitle => 'Achieved Freight Cost Savings';
  @override String get freightBookingCostIncreaseTitle => 'Additional Freight Cost';
  @override String get freightBookingCostSavingsBadge => 'Cost Savings';
  @override String get freightBookingCostIncreaseBadge => 'Cost Increase';
  @override String get freightBookingPriceDiffLabel => 'Unit Price Difference';
  @override String freightBookingSavingsFormulaDetails(String diff, String qty, String unit, String total) =>
      'Price Difference ($diff) × $qty $unit = $total';
  @override String get freightBookingNoPriceVariance => 'Price matches quotation exactly';

  // ── Universal Copy & Clipboard Helpers ─────────────────────────────────────
  @override String get copyValue => 'Copy Value';
  @override String get copyRow => 'Copy Row Data';
  @override String get copyTable => 'Copy Entire Table';
  @override String get copiedToClipboardGeneric => 'Copied to clipboard successfully';
  @override String get copyTooltip => 'Click to copy to clipboard';

  // ── Screen 0: Operational Dashboard Enhancements ───────────────────────────
  @override String get badgeNew => 'NEW';
  @override String pendingRegRequirementsCount(int count) => '$count Pending Reg Requirements';

  // ── Freight Studies — Extended Keys (English) ────────────────────────────────
  // AI Extractor
  @override String get freightExtractorTitle => 'Extract & Read Freight Quotations (Freight Quotation AI) ⚡';
  @override String get collapseExtractor => 'Collapse Tool';
  @override String get expandExtractor => 'Expand Tool';
  @override String get pasteQuoteText => 'Paste Quote Text';
  @override String get clearField => 'Clear';
  @override String get sampleQuoteBtn => 'Sample Quote';
  @override String get uploadQuoteDocument => 'Upload Quote Document 📄';
  @override String get extractQuotesBtn => 'Extract & Analyze Quotes ⚡';
  // Extracted results
  @override String extractedQuotesBanner(int count) => '$count quote(s) extracted successfully! Review below and add to your comparison study:';
  @override String addAllQuotes(int count) => '🚀 Add All Quotes ($count)';
  @override String get attachedFileChip => 'File:';
  @override String get originPortChip => 'POL:';
  @override String get destinationPortChip => 'POD:';
  @override String get localExpensesChip => 'Local Charges:';
  @override String get directRoute => 'Direct';
  @override String get transitRoute => 'Transit';
  @override String get totalLabel => 'Total:';
  @override String get transitDaysLabel => 'Transit';
  @override String get freeTimeDaysLabel => 'Free Time';
  @override String get addThisQuoteBtn => '+ Add This Quote to Scenario';
  // Snackbars
  @override String sessionLoadedMsg(String code) => '📂 Session ($code) loaded successfully for editing!';
  @override String freightQuotesAddedMsg(int count) => '✨ $count quote(s) added successfully to the comparison study!';
  @override String get noValidQuotesError => 'No valid freight quotes found in the provided text/document.';
  @override String extractedAndAddedMsg(int count) => '🚀 $count quotes extracted and added to the scenario successfully!';
  @override String get cancelEditModeMsg => '🔄 Edit mode cancelled — form reset for a new study.';
  // Metric cards
  @override String avgDaysFromReadiness(int days) => 'Within $days days of readiness';
  // Container count chip
  @override String totalContainersCount(int total, int ft40, int ft20) =>
      'Total Applied Containers = $total (40ft: $ft40 | 20ft: $ft20)';
  // Comparison table
  @override String get excludedFromAvg => 'Excluded 🚫';
  @override String get includedInAvg => 'Included ✅';
  // Filter strip
  @override String polToPodLeadTimeStrip(String pol, String pod, int lead, int wh) =>
      '📍 POL: $pol ➔ POD: $pod | Lead Time: ${lead}d | WH Days: ${wh}d';
  // Search hints
  @override String get forwarderSearchHint => 'Search freight forwarder / agent...';
  @override String get shippingLineSearchHint => 'Search shipping line...';
  @override String get addNewLineTooltip => 'Register new shipping line with AI';
  // Clearance fee summary label
  @override String get clearanceFeeSummaryLabel => 'Clearance:';
  // Validation snackbars
  @override String get completeRequiredDataMsg => '⚠️ Please ensure all required fields are filled, including the study title!';
  @override String shippingLineRequiredMsg(int index) => '⚠️ Shipping option #$index: Please select a shipping line!';
  @override String datesRequiredMsg(int index, String provider) => '⚠️ Shipping option #$index ($provider): Please set valid dates!';
  @override String sailingBeforeCrdError(int index, String provider, String sailing, String crd) =>
      '⚠️ Shipping option #$index ($provider): Sailing date ($sailing) cannot be before cargo ready date (CRD: $crd)!';
  @override String etaAfterSailingError(int index, String provider, String eta, String sailing) =>
      '⚠️ Shipping option #$index ($provider): ETA ($eta) must be after sailing date ($sailing)!';
  @override String negativeDaysError(int index, String provider) =>
      '⚠️ Shipping option #$index ($provider): Expected delay days cannot be negative!';
  @override String duplicateQuoteError(int index, String provider) =>
      '⚠️ Shipping option #$index ($provider): Duplicate! Another quote exists with the same forwarder, vessel, and sailing date.';
  @override String get saveFailed => 'Failed to save the study and results';
  @override String get saveFailedTitle => '❌ Failed to Save Freight Study';
  // Save success dialog
  @override String get saveSuccessReportTitle => '🏆 Freight Study & Saved Quotes Results Report';
  @override String get studyCodeLabel => 'Study Code:';
  @override String get studyTitleDetailLabel => 'Study Title:';
  @override String get crdAndPickupLabel => 'CRD | Pickup Location:';
  @override String get comparativeReportLabel => '📊 Comparative Report for Evaluated Lines & Voyages:';
  @override String get carrierLineCol => 'Carrier / Shipping Line';
  @override String get portArrivalCol => 'Port Arrival';
  @override String get totalDaysCol => 'Total Days';
  @override String get whDateCol => 'Expected WH Date';
  @override String get totalQuoteCol => 'Total Quote Value';
  @override String recommendedBadge(String provider) => '🟢 Recommended';
  @override String get excludedBadge => '🚫 Excluded';
  @override String get normalBadge => 'Normal';
  @override String get recommendedLineContractLabel => 'Officially recommended shipping line for booking:';
  @override String get copySummaryBtn => 'Copy Results Summary';
  @override String get saveDoneBtn => 'OK (Saved)';
  @override String get summaryNotCopied => '📋 Summary copied to clipboard!';
  // Container comparison dialog
  @override String get containerDualMatrixTitle => '🚚 Stackable vs Non-Stackable Container Comparison';
  @override String totalCbmAndWeight(String cbm, String weight) =>
      'Total Shipment CBM: $cbm m³ | Total Weight: $weight kg';
  @override String get containerTypeCol => 'Recommended Container Type';
  @override String get containersRequiredCol => 'Required Containers';
  @override String get spaceUtilizationLabel => 'Space Utilization %';
  // Visual load plan dialog
  @override String get visualLoadPlanTitle => 'Interactive Container Load Planner & Simulation';
  @override String requiredFleetLabel(String fleet, int count) => 'Required Fleet: $fleet ($count Container(s))';
  @override String get selectStackingScenarioLabel => '🔄 Select Stacking Scenario for Preview:';
  @override String get totalPackagesMetricLabel => '📦 Total Packages';
  @override String get totalWeightMetricLabel => '⚖️ Total Weight';
  @override String get totalVolumeMetricLabel => '📐 Total Volume';
  @override String get stackableMetricLabel => '✅ Stackable';
  @override String get nonStackableMetricLabel => '🚫 Non-Stackable';
  @override String get containerCol => 'Container';
  @override String get itemsAndPackagesCol => 'Items & Packages';
  @override String get loadedWeightCol => 'Loaded Weight';
  @override String get safetyDistributionCol => 'Safety & Distribution';
  @override String loadingFailedStatus(String ids) => 'Loading Failed (Oversized/Overweight)';
  @override String nonStackableFloorCount(int count) => 'Contains $count floor-placed non-stackable package(s)';
  @override String multiLayerCompliant(String percent) => 'Multi-layer stacking compliant ($percent%)';
  @override String get failedStackLabel => 'Failed';
  @override String itemsExceedCapacity(String ids) => 'The following items exceed container capacity: $ids';
  @override String containerLayoutTitle(int index, String name, String code) => 'Container #$index Layout: $name ($code)';
  @override String get woodenFloorPalletsLabel => '🪵 Wooden Floor Pallets';
  @override String internalDimsLabel(String l, String w, String h) => 'Internal Dims: $l x $w x $h cm';
  @override String get closePlanBtn => 'Close Plan';
  // Default study title
  @override String defaultStudyTitle(String date) => 'Shipping Options Evaluation Study ($date)';
  // Independent study
  @override String get independentStudy => 'Standalone';
  // Options count chip
  @override String optionsCount(int count) => '$count Option(s)';
  // Avg transit days in registry table
  @override String avgTransitDays(String days) => '$days days';
  // Clearance cost compact line
  @override String clearanceCostSummary(String amount, String currency) => 'Clearance: $amount $currency';

  // ── Customs Consultation & Calculator Workspace (Screens 6 & 7) ─────────
  @override String get invoiceCurrencyLabel => 'Invoice / Goods Currency';
  @override String get customsFxRateLabel => 'Customs Exchange Rate (EGP)';
  @override String get freightDataHeader => 'Ocean / Air Freight Details';
  @override String get fetchHighestFreightFromStudy => 'Fetch Highest Freight from Shipping Study';
  @override String get foreignFreightAmountLabel => 'Freight in Foreign Currency';
  @override String get freightCurrencyLabel => 'Freight Currency';
  @override String get freightFxRateLabel => 'Freight Exchange Rate (EGP)';
  @override String get estimatedCustomsInsuranceRateLabel => 'Estimated Customs Insurance Rate:';
  @override String get standardCustomsInsuranceRate => '0.5% (Customs Standard)';
  @override String get customInsuranceRate => 'Custom';
  @override String autoCalculatedCandFInsuranceHelper(String option) => 'Auto-calculated from (C&F × $option)';
  @override String get declaredCifBaseLabel => 'Total Declared CIF Base Value:';
  @override String cifFormulaBreakdown(String fob, String cur, String freight, String cAndF, String insurance) =>
      'FOB Value ($fob $cur) + Freight ($freight EGP) = C&F ($cAndF EGP) + Insurance ($insurance EGP)';
  @override String tariffDetailsTableTitle(int count, String type) => 'Customs Tariff Details ($count $type)';
  @override String get groupedHsCodeItems => 'Grouped HS Items';
  @override String get detailedItems => 'Detailed Items';
  @override String get groupByHsCodeOption => '✓ Grouped by HS Code';
  @override String get detailedItemViewOption => 'Detailed Item View';
  @override String valueInCurrencyCol(String cur) => 'Value in Currency ($cur)';
  @override String linkedPurchaseOrdersSummary(int count, String total) => 'Linked Purchase Orders: $count orders$total';
  @override String approvedInvoicesSummary(int count, String total) => 'Approved Invoices: $count invoices$total';
  @override String projectNamedSummary(String name) => 'Project: $name';
  @override String freightAutoFetchedDetailsToast(String amount, String currency, String rate, String freightEgp) =>
      '🚢 Freight auto-fetched from shipping scenarios: $amount $currency × $rate = $freightEgp EGP';
  @override String get noPoItemsFoundForFileToast => '⚠️ No purchase order items found for this file to calculate terms';
  @override String recalculatedTaxesAppliedToast(String amount) =>
      '💾 Recalculated customs duties and taxes applied ($amount EGP). You can now save or update the study.';

  // Regulatory Documents & Authorities
  @override String get acidShipmentDoc => 'Advance ACID Filing for Entire Shipment (Nafeza / CargoX)';
  @override String acidShipmentDocRemarks(String hsCodes) => 'Includes HS items: $hsCodes — Preliminary customs filing number mandatory for bill of lading.';
  @override String get cooShipmentDoc => 'Legalized Certificate of Origin for Entire Shipment (COO)';
  @override String cooShipmentDocRemarks(String hsCodes) => 'Includes HS items: $hsCodes — Single origin certificate for entire shipment, issued by Chamber of Commerce and legalized by Egyptian Embassy.';
  @override String get goeicShipmentDoc => 'GOEIC Inspection and Clearance for Entire Shipment';
  @override String get goeicAgencyName => 'General Organization for Export & Import Control (GOEIC)';
  @override String goeicShipmentDocRemarks(String hsCodes) => 'Includes HS items: $hsCodes — Visual inspection and lab sampling for entire shipment.';
  @override String priorAuthorityApprovalDoc(String authority) => 'Prior Technical Approval from $authority';
  @override String priorAuthorityApprovalRemarks(String hsCodes, String note) => 'Includes HS items: $hsCodes — $note';
  @override String get defaultPriorApprovalNote => 'Requires prior technical approval and customs release permit issuance.';

  // Standard Checklist Items & Remarks
  @override String get proformaInvoiceDoc => 'Proforma Invoice';
  @override String get packingListDoc => 'Packing List';
  @override String get certificateOfOriginDoc => 'Certificate of Origin';
  @override String get goeicInspectionDoc => 'GOEIC Inspection';
  @override String get ntraApprovalDoc => 'NTRA Regulatory Approval';
  @override String get proformaInvoiceApprovedRemark => 'Proforma invoice approved and matches customs tariff HS code.';
  @override String get packingListUpdatedRemark => 'Updated with total weights, volumes, and package quantities.';
  @override String get embassyLegalizationRemark => 'Embassy and chamber of commerce authentication required.';
  @override String get visualLabInspectionRemark => 'Visual inspection and laboratory sampling required upon arrival.';
  @override String get wirelessModuleRemark => 'Applies in case wireless remote control modules exist.';

  // Checklist Parties & Statuses
  @override String get partySupplierExporter => 'Authorized Supplier';
  @override String get partyImporterTeam => 'Importer Team';

  // Screen 22: Smart Invoice vs B/L Matcher (invoice_bl_matcher_tab.dart)
  @override String get invoiceBlMatcherTitle => 'Smart Extraction & Real-Time Reconciliation';
  @override String get invoiceBlMatcherSubtitle => 'Extract target fields, cross-check final invoice against bill of lading, and prevent customs or banking discrepancies.';
  @override String get invoiceBlMatcherLinkImportFile => 'Link to Import File';
  @override String get invoiceBlMatcherSelectFileHint => 'Select shipment file to synchronize...';
  @override String get invoiceBlMatcherAddPackingListButton => '+ Add Packing List as Additional Document';
  @override String get invoiceBlMatcherRemovePackingList => 'Remove and hide packing list';
  @override String get invoiceBlMatcherInvoiceBoxTitle => '1. Final Commercial Invoice';
  @override String get invoiceBlMatcherPackingBoxTitle => '2. Final Packing List';
  @override String get invoiceBlMatcherBlBoxTitle => '3. Draft Bill of Lading';
  @override String get invoiceBlMatcherChangeFile => 'Change File';
  @override String get invoiceBlMatcherUploadFile => 'Upload File';
  @override String invoiceBlMatcherUploadedFile(String fileName) => 'Uploaded File: $fileName';
  @override String get invoiceBlMatcherInvoicePlaceholder => 'Paste invoice raw text here or click upload document...';
  @override String get invoiceBlMatcherPackingPlaceholder => 'Paste packing list text here or click upload document...';
  @override String get invoiceBlMatcherBlPlaceholder => 'Paste draft B/L text here or click upload carrier document...';
  @override String invoiceBlMatcherInvoiceFilesLoaded(int count, String names) => '[$count invoice files loaded: $names — all line items will be matched automatically]';
  @override String invoiceBlMatcherPackingFilesLoaded(int count, String names) => '[$count packing list files loaded: $names — weights, volumes, and packages will be extracted automatically]';
  @override String invoiceBlMatcherBlFilesLoaded(int count, String names) => '[$count B/L files loaded: $names — contents will be extracted and verified automatically]';
  @override String invoiceBlMatcherFilesSelectedSuccess(int count, String names) => '$count files successfully selected ($names)';
  @override String invoiceBlMatcherFileReadError(dynamic error) => 'Failed to read file: $error';
  @override String get invoiceBlMatcherExecuteMatchButton => 'Execute Smart Extraction & Match';
  @override String get invoiceBlMatcherLoadSampleButton => 'Load Real Sample Data';
  @override String get invoiceBlMatcherResetButton => 'Reset Form';
  @override String get invoiceBlMatcherSampleLoadedSuccess => 'Real sample data loaded successfully';
  @override String get invoiceBlMatcherValidationRequired => 'Please provide or upload invoice, packing list, or bill of lading documents for matching';
  @override String get invoiceBlMatcherAnalyzingProgress => 'Analyzing and extracting matching fields via AI...';
  @override String invoiceBlMatcherMatchCompletedSuccess(dynamic score) => 'Smart match completed successfully! Match score: $score%';
  @override String get invoiceBlMatcherMatchErrorTitle => 'Smart Matching Error';
  @override String get invoiceBlMatcherStatusSafeTitle => 'Documents Matched & Safe for Certification';
  @override String get invoiceBlMatcherStatusCriticalTitle => 'Critical Discrepancies Detected';
  @override String invoiceBlMatcherMatchScore(dynamic score) => 'Match Score: $score%';
  @override String get invoiceBlMatcherStatusSafeDesc => 'All customs and banking fields matched safely. You can synchronize data directly with the import file.';
  @override String invoiceBlMatcherStatusCriticalDesc(int count) => 'There are $count critical discrepancies blocking clearance or Form 4. B/L or invoice must be amended before certification.';
  @override String invoiceBlMatcherCriticalCount(int count) => 'Critical: $count';
  @override String invoiceBlMatcherWarningCount(int count) => 'Warnings: $count';
  @override String get invoiceBlMatcherMatrixTitle => 'Detailed Reconciliation Matrix (10 Customs & Banking Checks)';
  @override String get invoiceBlMatcherColCheckItem => 'Audit & Reconciliation Item';
  @override String get invoiceBlMatcherColInvoiceValue => 'Final Invoice Value';
  @override String get invoiceBlMatcherColBlValue => 'Draft B/L Value';
  @override String get invoiceBlMatcherColMatchStatus => 'Status';
  @override String get invoiceBlMatcherColActionRequired => 'Result & Required Action';
  @override String get invoiceBlMatcherStatusMatch => 'Matched';
  @override String get invoiceBlMatcherStatusMinor => 'Minor Variance';
  @override String get invoiceBlMatcherStatusMismatch => 'Mismatch';
  @override String get invoiceBlMatcherExtractedInvoiceTitle => 'Extracted Invoice Data';
  @override String get invoiceBlMatcherExtractedBlTitle => 'Extracted Bill of Lading Data';
  @override String get invoiceBlMatcherCorrectionLetterTitle => 'Automated Carrier Correction Request Letter';
  @override String get invoiceBlMatcherCopyLetterButton => 'Copy Letter';
  @override String get invoiceBlMatcherLetterCopiedSuccess => 'Correction letter copied to clipboard successfully';
  @override String get invoiceBlMatcherSyncFooterTitle => 'Certify Results & Synchronize with Import File';
  @override String get invoiceBlMatcherSyncFooterDesc => 'B/L number, invoice number, total value, and containers will be updated in the selected shipment file.';
  @override String get invoiceBlMatcherSyncFooterNoFile => 'Please select an import file from the top bar to synchronize.';
  @override String get invoiceBlMatcherExportReportButton => 'Export Reconciliation Report';
  @override String get invoiceBlMatcherCertifySyncButton => 'Certify & Sync with File';
  @override String get invoiceBlMatcherSelectFileFirstWarning => 'Please select a shipment file and execute matching before synchronization';
  @override String get invoiceBlMatcherSyncSuccess => 'Synchronized and certified successfully';
  @override String get invoiceBlMatcherSyncFailedTitle => 'Data Synchronization Failed';
  @override String get invoiceBlMatcherReportDialogTitle => 'Smart Reconciliation Report';
  @override String invoiceBlMatcherReportMatchRatio(dynamic score) => 'Match Ratio: $score%';
  @override String get invoiceBlMatcherReportSafeStatus => 'Safe for Certification';
  @override String get invoiceBlMatcherReportUnsafeStatus => 'Critical Variances Found';
  @override String get invoiceBlMatcherCopyReportButton => 'Copy Report';
  @override String get invoiceBlMatcherReportCopiedSuccess => 'Report copied to clipboard successfully';
  @override String get invoiceBlMatcherCloseButton => 'Close';

  // Screen 22: Smart Invoice & B/L Extractor Dialog (smart_invoice_bl_extractor_dialog.dart)
  @override String get smartExtractorDialogTitle => 'AI Invoice & Bill of Lading Extractor';
  @override String get smartExtractorDialogSubtitle => 'Intelligent data extraction for commercial invoices, ocean bills of lading, and air waybills with customs pre-clearance auditing';
  @override String get smartExtractorTabInvoice => 'Commercial Invoice';
  @override String get smartExtractorTabBl => 'Bill of Lading';
  @override String get smartExtractorTabAudit => 'Customs Audit Radar';
  @override String get smartExtractorInvoiceCardTitle => '1. Enter or Upload Commercial Invoice';
  @override String get smartExtractorInvoiceCardHint => 'Paste invoice raw text here, or select invoice file...';
  @override String get smartExtractorPickFileButton => 'Select File';
  @override String get smartExtractorExtractInvoiceButton => 'Extract Invoice with AI';
  @override String get smartExtractorExtractedInvoiceTitle => 'Extracted Invoice Fields:';
  @override String smartExtractorCurrency(String currency) => 'Currency: $currency';
  @override String get smartExtractorFieldInvoiceNo => 'Invoice Number';
  @override String get smartExtractorFieldInvoiceDate => 'Invoice Date';
  @override String get smartExtractorFieldAcidNo => 'ACID Number';
  @override String get smartExtractorFieldImporterTaxId => 'Importer Tax ID';
  @override String get smartExtractorFieldSupplier => 'Supplier / Shipper';
  @override String get smartExtractorFieldImporter => 'Egyptian Importer';
  @override String get smartExtractorFieldIncoterms => 'Incoterms';
  @override String get smartExtractorFieldTotalAmount => 'Total Amount';
  @override String get smartExtractorFieldTotalGrossWeight => 'Total Gross Weight';
  @override String get smartExtractorFieldPorts => 'Loading & Discharge Ports';
  @override String smartExtractorItemsTableTitle(int count) => 'Extracted Line Items ($count items):';
  @override String get smartExtractorNoItemsFound => 'No detailed items table found in document';
  @override String get smartExtractorColItemDescription => 'Item Description';
  @override String get smartExtractorColQuantity => 'Quantity';
  @override String get smartExtractorColUnit => 'Unit';
  @override String get smartExtractorColUnitPrice => 'Unit Price';
  @override String get smartExtractorColTotalPrice => 'Total Price';
  @override String get smartExtractorApplySectionTitle => 'Link and Apply to Import File:';
  @override String get smartExtractorSelectFileLabel => 'Select Import File';
  @override String get smartExtractorSearchFileHint => 'Search by file code or company...';
  @override String get smartExtractorApplyInvoiceButton => 'Apply to Import File';
  @override String smartExtractorFetchFilesError(dynamic error) => 'Error fetching files: $error';
  @override String get smartExtractorBlCardTitle => '2. Enter or Upload Bill of Lading';
  @override String get smartExtractorBlCardHint => 'Paste B/L text here, or select file...';
  @override String get smartExtractorExtractBlButton => 'Extract B/L & Containers';
  @override String get smartExtractorOceanBlTitle => 'Ocean Bill of Lading';
  @override String get smartExtractorAirWaybillTitle => 'Air Waybill';
  @override String get smartExtractorPaymentPrepaid => 'Freight Prepaid';
  @override String get smartExtractorPaymentCollect => 'Freight Collect';
  @override String get smartExtractorFieldBlNo => 'B/L Number';
  @override String get smartExtractorFieldCarrier => 'Carrier / Shipping Line';
  @override String get smartExtractorFieldFlightNo => 'Flight Number';
  @override String get smartExtractorFieldVesselVoyage => 'Vessel & Voyage';
  @override String get smartExtractorFieldPol => 'Port of Loading';
  @override String get smartExtractorFieldPod => 'Port of Discharge';
  @override String get smartExtractorFieldTotalCbm => 'Total CBM Volume';
  @override String get smartExtractorFieldPackagesCount => 'Total Packages';
  @override String get smartExtractorFieldShipper => 'Shipper';
  @override String get smartExtractorFieldConsignee => 'Consignee';
  @override String smartExtractorContainersTableTitle(int count) => 'Extracted Containers & Seals ($count containers):';
  @override String get smartExtractorNoContainersFound => 'No containers specified or shipment is Air / LCL';
  @override String get smartExtractorColContainerNo => 'Container Number';
  @override String get smartExtractorColSealNo => 'Seal Number';
  @override String get smartExtractorColContainerType => 'Type & Size';
  @override String get smartExtractorColGrossWeightKg => 'Gross Weight (KG)';
  @override String get smartExtractorApplyBlSectionTitle => 'Apply B/L to Shipment & Container Tracking:';
  @override String get smartExtractorApplyBlButton => 'Apply to Current Shipment';
  @override String get smartExtractorAuditCardTitle => 'Cross-Check Customs Audit Radar';
  @override String get smartExtractorAuditCardSubtitle => 'Cross-audits invoice against bill of lading to verify ACID number, weight variances, freight terms, and ports to prevent customs fines.';
  @override String get smartExtractorRunAuditButton => 'Run Audit Now';
  @override String smartExtractorMatchRatio(dynamic score) => 'Compliance Score: $score%';
  @override String get smartExtractorAuditMatrixTitle => 'Cross-Check Audit Matrix (10 Points):';
  @override String get smartExtractorColCheckItem => 'Audit Item';
  @override String get smartExtractorColInvoiceValue => 'Invoice Value';
  @override String get smartExtractorColBlValue => 'B/L Value';
  @override String get smartExtractorColStatus => 'Status';
  @override String get smartExtractorColDetailsGuidance => 'Details & Guidance';
  @override String get smartExtractorNoticeCardTitle => 'Official Carrier & Supplier Amendment Notice';
  @override String get smartExtractorNoticeCardSubtitle => 'Ready-to-dispatch template requesting the carrier to rectify draft B/L discrepancies immediately.';
  @override String get smartExtractorCopyEnglishNoticeButton => 'Copy English Notice';
  @override String get smartExtractorCopyArabicNoticeButton => 'Copy Arabic Notice';
  @override String smartExtractorPickFileError(dynamic error) => 'Failed to pick file: $error';
  @override String get smartExtractorRequireInvoiceInput => 'Please select invoice file or paste text first';
  @override String get smartExtractorInvoiceExtractedSuccess => 'Invoice data extracted successfully with high accuracy';
  @override String smartExtractorExtractInvoiceError(dynamic error) => 'Error extracting invoice: $error';
  @override String get smartExtractorRequireBlInput => 'Please select B/L file or paste text first';
  @override String get smartExtractorBlExtractedSuccess => 'Bill of lading and containers extracted successfully';
  @override String smartExtractorExtractBlError(dynamic error) => 'Error extracting B/L: $error';
  @override String get smartExtractorRequireBothDocsForAudit => 'Please extract both invoice and B/L first to run audit';
  @override String get smartExtractorAuditSuccess => 'Customs audit verification completed successfully';
  @override String smartExtractorAuditError(dynamic error) => 'Error during audit verification: $error';
  @override String get smartExtractorSelectFileWarning => 'Please select target import file first';
  @override String get smartExtractorInvoiceAppliedSuccess => 'Invoice data applied to import file successfully';
  @override String smartExtractorApplyInvoiceError(dynamic error) => 'Failed to apply invoice data: $error';
  @override String get smartExtractorBlAppliedSuccess => 'B/L data applied successfully';
  @override String smartExtractorApplyBlError(dynamic error) => 'Failed to apply B/L data: $error';
  @override String get smartExtractorNoticeEnCopied => 'English amendment notice copied to clipboard successfully';
  @override String get smartExtractorNoticeArCopied => 'Arabic amendment notice copied to clipboard successfully';
  @override String get smartExtractorAuditPass => 'Pass';
  @override String get smartExtractorAuditWarning => 'Warning';
  @override String get smartExtractorAuditCritical => 'Critical';
  @override String get smartExtractorAuditCompliant => 'Documents Compliant & Verified';
  @override String get smartExtractorAuditWarningsDetected => 'Minor Warnings Detected — Review Advised';
  @override String get smartExtractorAuditCriticalMismatch => 'Critical Mismatch Detected — Release Blocked';

  // ── What-If & FX Crisis Simulator ─────────────────────────────────────────
  @override String get whatIfDialogTitle => 'Shipping Risks & FX Crisis Simulator';
  @override String get whatIfDialogSubtitle => 'Analyze emergency scenarios for customs exchange rates, African rerouting, and port demurrage';
  @override String get whatIfSimulatorTab => 'Live What-If Simulator';
  @override String get whatIfExposureTab => 'FX Exposure Radar';
  @override String get whatIfShipmentAndCurrencyInputs => '1. Shipment & Currency Inputs:';
  @override String get whatIfInvoiceValue => 'Invoice Value (FOB)';
  @override String get whatIfFreightCost => 'Freight Cost (Ocean / Air)';
  @override String get whatIfFxShockSimulation => '2. FX Rate Shock Simulation:';
  @override String get whatIfBaseRate => 'Base Rate:';
  @override String get whatIfSimulatedRate => 'Simulated:';
  @override String get whatIfShippingRouteRisk => '3. Shipping Route & Transit Risks:';
  @override String get whatIfRouteRedSea => 'Red Sea & Suez Canal Route (Normal)';
  @override String get whatIfRouteCape => 'Cape of Good Hope Reroute (+18 Days / +25% Freight)';
  @override String get whatIfPortDelay => 'Port Delay:';
  @override String get whatIfDaysUnit => 'days';
  @override String get whatIfContainersCount => 'Containers';
  @override String get whatIfContainerUnit => 'Container(s)';
  @override String get whatIfRunSimulationNow => 'Run Simulation Now';
  @override String get whatIfSelectShipmentPlaceholder => 'Select Shipment for Simulation (Optional)';
  @override String get whatIfSearchShipmentHint => 'Search by file code or company...';
  @override String get whatIfPlaceholderTitle => 'Ready to simulate FX shocks and logistical crises';
  @override String get whatIfPlaceholderDescription => 'Adjust parameters on the left and click "Run Simulation" to see the immediate impact on tax base, Landed Cost, port demurrage, and ACID regulatory expiration risks.';
  @override String get whatIfRiskLevel => 'Financial & Operational Risk Level:';
  @override String get whatIfSaveScenario => 'Save Scenario to Decision Log';
  @override String get whatIfCopyScenarioSummary => 'Copy Scenario Summary';
  @override String get whatIfScenarioCopied => 'Simulation scenario summary copied to clipboard';
  @override String get whatIfBaselineLandedCost => 'Baseline Landed Cost:';
  @override String get whatIfSimulatedLandedCost => 'Simulated Landed Cost:';
  @override String get whatIfCustomsTaxVariance => 'Customs & Tax Variance (EGP):';
  @override String get whatIfShippingDemurrage => 'Shipping Line Demurrage (USD):';
  @override String get whatIfPortStorage => 'Port Storage Fees (EGP):';
  @override String get whatIfAcidExpiryCheck => 'ACID Advance Cargo Expiry Check (180 Days):';
  @override String get whatIfStrategicRecommendations => 'Strategic Recommendations & Financial Hedging:';
  @override String get whatIfRefreshExposure => 'Refresh FX Exposure Data';
  @override String get whatIfTotalUsdObligations => 'Total USD Obligations';
  @override String get whatIfTotalEurObligations => 'Total EUR Obligations';
  @override String get whatIfCurrentEgpValue => 'Current Value in EGP';
  @override String get whatIfValueAtRisk10 => 'Value at Risk 10% (VaR)';
  @override String get whatIfTreasuryGuidance => 'Treasury Management & Hedging Guidance:';
  @override String get whatIfOpenShipmentsExposed => 'Open Shipments Exposed to FX Fluctuations:';
  @override String get whatIfColShipmentCode => 'Shipment Code';
  @override String get whatIfColSupplier => 'Foreign Supplier';
  @override String get whatIfColCurrency => 'Currency';
  @override String get whatIfColPendingAmount => 'Pending Amount';
  @override String get whatIfColCurrentEgp => 'Current Equivalent (EGP)';
  @override String get whatIfColScenarioPlus10 => 'In Scenario +10%';
  @override String get whatIfColScenarioPlus25 => 'In Scenario +25%';

  // ── Freight RFQ Dialog ───────────────────────────────────────────────────
  @override String get freightRfqRecipient => 'Recipient:';
  @override String get freightRfqSelectLineHint => 'Select Shipping Line / Agent...';
  @override String get freightRfqTypePersonHint => 'Or type person / agent name (e.g. Marian, Raafat)...';
  @override String get freightRfqUpdateTextTooltip => 'Update Text';
  @override String get freightRfqUpdateBtn => 'Refresh';
  @override String get freightRfqCopySubjectTooltip => 'Copy Email Subject';
  @override String get freightRfqWhatsappFeatures => 'WhatsApp Template Features:';
  @override String get freightRfqWhatsappFeature1 => 'Cleanly formatted with symbols and clear alignment.';
  @override String get freightRfqWhatsappFeature2 => 'Includes total volume, weights, and pickup address.';
  @override String get freightRfqWhatsappFeature3 => 'Specifies required demurrage free time (21 Days FT).';
  @override String get freightRfqWhatsappFeature4 => 'Ready for instant sharing with shipping representatives and agents.';
  @override String get freightRfqCopyWhatsappBtn => 'Copy Full WhatsApp Message';
  @override String get freightRfqPickupLocation => 'Pickup Location (EXW):';
  @override String get freightRfqSupplierLabel => 'Supplier:';
  @override String get freightRfqPackagesBreakdownTitle => 'Packages Breakdown & Pallet Dimensions:';
  @override String get freightRfqPrintPdfBtn => 'Print / Save Official PDF Document';
  @override String get freightRfqCopyEmailBtn => 'Copy Full Email Body';
  @override String get freightRfqCloseDismissBtn => 'Close & Dismiss ✕';

  // ── Master Screens AI Extraction & Tools ─────────────────────────────────
  @override String get aiCodeCompanyBtn => 'AI Extract Company ✨';
  @override String get aiCodePartnerBtn => 'AI Extract Partner ✨';
  @override String aiCodeCategoryPartner(String category) => 'AI Extract $category ✨';
  @override String get syncOfficialCustomsRatesBtn => 'Sync Official Customs FX Rates';
  @override String get whatIfSimulatorBtn => 'What-If & FX Crisis Simulator';
  @override String get syncRatesSuccess => 'Official customs exchange rates synchronized successfully ✅';
  @override String syncRatesFailed(String error) => 'Failed to synchronize customs exchange rates: $error';

  // ── Screen 56: Customs Tax & Declaration 46 Review Workspace ───────────────
  @override String get customsTaxExportTsvBtn => 'Export Calculation as TSV';
  @override String get customsTaxExportExcelBtn => 'Export Calculation as Excel';
  @override String get customsTaxPrintPdfBtn => 'Print / Save Customs Assessment PDF';
  @override String get customsTaxCopyDossierBtn => 'Copy Customs Dossier to Clipboard';
  @override String get customsTaxCopiedDossierSuccess => 'Full customs assessment & duty dossier copied to clipboard';
  @override String get customsTaxCopiedTsvSuccess => 'Customs tax calculation copied in TSV format';
  @override String get customsTaxCopiedExcelSuccess => 'Customs tax calculation copied in Excel CSV format';
  @override String get customsTaxExportTsvDialogTitle => 'Export Customs Tax Calculation (TSV)';
  @override String get customsTaxExportExcelDialogTitle => 'Export Customs Tax Calculation (Excel)';
  @override String get customsTaxExportPdfDialogTitle => 'Customs Tax & Tariff Assessment Report (PDF)';
  @override String get customsTaxDossierTitle => 'Comprehensive Customs & Tariff Review Dossier';
  @override String get customsTaxCopyRowSuccess => 'Customs line details copied to clipboard';
  @override String get customsTaxCopySummarySuccess => 'Customs duties & taxes summary copied to clipboard';
  @override String get customsTaxTsvHeaderHsCode => 'HS Code';
  @override String get customsTaxTsvHeaderDescription => 'Item Description';
  @override String get customsTaxTsvHeaderOrigin => 'Origin Country';
  @override String get customsTaxTsvHeaderQty => 'Quantity';
  @override String get customsTaxTsvHeaderUnit => 'Unit';
  @override String get customsTaxTsvHeaderForeignPrice => 'Foreign Unit Price';
  @override String get customsTaxTsvHeaderFobEgp => 'FOB Value (EGP)';
  @override String get customsTaxTsvHeaderFreightEgp => 'Freight (EGP)';
  @override String get customsTaxTsvHeaderInsuranceEgp => 'Insurance (EGP)';
  @override String get customsTaxTsvHeaderCifEgp => 'CIF Customs Value (EGP)';
  @override String get customsTaxTsvHeaderDutyRate => 'Customs Duty Rate';
  @override String get customsTaxTsvHeaderDutyAmount => 'Customs Duty (EGP)';
  @override String get customsTaxTsvHeaderVatRate => 'VAT Rate';
  @override String get customsTaxTsvHeaderVatAmount => 'VAT Amount (EGP)';
  @override String get customsTaxTsvHeaderScheduleTax => 'Schedule & Development Tax (EGP)';
  @override String get customsTaxTsvHeaderCustomsFees => 'Customs Service & Base Fees (EGP)';
  @override String get customsTaxTsvHeaderTotalTaxes => 'Total Customs Duties & Taxes (EGP)';
  @override String get customsTaxTsvHeaderRegulatoryConditions => 'Prior Regulatory Conditions & Approvals';
  @override String get customsTaxLogTsvHeaderCode => 'Session Code';
  @override String get customsTaxLogTsvHeaderFile => 'Import File';
  @override String get customsTaxLogTsvHeaderTitle => 'Study Title';
  @override String get customsTaxLogTsvHeaderBroker => 'Customs Broker';
  @override String get customsTaxLogTsvHeaderEstimatedDuties => 'Estimated Duties';
  @override String get customsTaxLogTsvHeaderReadiness => 'Readiness Rate';
  @override String get customsTaxLogTsvHeaderStatus => 'Status';
  @override String get customsTaxLogTsvHeaderCreatedDate => 'Created Date';

  // ── Standalone Extraction Tools & Dual Extraction ───────────────────────
  @override String get dualExtractionEngineTitle => 'Dual Document Extraction Engine';
  @override String get dualExtractionCommercialInvoice => 'Commercial Customs Invoice';
  @override String get dualExtractionPackingList => 'Customs Packing List';
  @override String get dualExtractionInvoiceModeTitle => 'Invoice Extraction Mode';
  @override String get dualExtractionGroupingTitle => 'Invoice Line Grouping';
  @override String get dualExtractionPlModeTitle => 'Packing List Mode';
  @override String get dualExtractionStructureTitle => 'Package & Carton Structure';
  @override String get dualExtractionIncludePallets => 'Include Pallet & Package Details';
  @override String get dualExtractionPalletDataTitle => 'Pallets & Packages Details';
  @override String get dualExtractionAddPalletBtn => 'Add Pallet';
  @override String get dualExtractionNoPallets => 'No pallets added yet';
  @override String get dualExtractionPreviewResults => 'Preview Dual Extraction Results';
  @override String get dualExtractionDownloadZip => 'Download ZIP Archive';
  @override String get dualExtractionAdoptCustomsTrack => 'Adopt as Customs Track';
  @override String get dualExtractionTrackCreatedSuccess => 'Dual customs track created successfully';
  @override String get dualExtractionCopySummaryTooltip => 'Copy Dual Extraction Summary';
  @override String get dualExtractionSummaryCopied => 'Dual extraction summary copied successfully';
  @override String get smartUploadCopyAllTooltip => 'Copy All Extracted Data';
  @override String get smartUploadCopyAllSuccess => 'All extracted data copied successfully';

  // ── Screen 67: Lifecycle Steps Risk Classification & Skip Policy Governance ──
  @override String get stepConfigTitle => 'Lifecycle Steps Risk Classification & Skip Governance';
  @override String get stepConfigSubtitle => 'Central dynamic management for step skip policies and pending references without code changes';
  @override String get stepConfigAccessDeniedTitle => 'Insufficient Permissions — Manager Role Required';
  @override String get stepConfigAccessDeniedDesc => 'According to operational governance standards, operational users are restricted from viewing or modifying step skip policies. This screen is reserved exclusively for managers.';
  @override String get adminOnlyFeatureMessage => 'This feature is available to system administrators only.';
  @override String get stepConfigDemoSwitchBtn => 'Switch to Manager Role (Demo)';
  @override String get stepConfigRefreshTooltip => 'Refresh Data';
  @override String get stepConfigSearchHint => 'Search by step code, name, or policy...';
  @override String get stepConfigPhaseAll => 'All (25 Steps)';
  @override String stepConfigPhaseLabel(int phase) => 'Phase $phase';
  @override String get stepConfigEmptySearch => 'No steps match the current search criteria.';
  @override String get stepConfigColPhaseCode => 'Phase & Code';
  @override String get stepConfigColStepName => 'Step Name';
  @override String get stepConfigColSkipPolicy => 'Skip Policy';
  @override String get stepConfigColApproverRoles => 'Authorized Roles';
  @override String get stepConfigColPendingRef => 'Pending Ref';
  @override String get stepConfigColReasonCategories => 'Skip Reasons';
  @override String get stepConfigColLastModified => 'Last Modified';
  @override String get stepConfigColActions => 'Actions';
  @override String get stepConfigPolicyBlocked => 'Strictly Blocked';
  @override String get stepConfigPolicySingleApproval => 'Single Approval';
  @override String get stepConfigPolicyDualApproval => 'Dual Approval';
  @override String get stepConfigPendingRefAllowed => 'Allowed';
  @override String get stepConfigPendingRefBlocked => 'Not Allowed';
  @override String stepConfigReasonCategoriesCount(int count) => '$count Categories';
  @override String get stepConfigEditTooltip => 'Edit Policy & Classification';
  @override String get stepConfigAuditTooltip => 'Audit History Log';
  @override String get stepConfigCopyRowTooltip => 'Copy Step Summary';
  @override String get stepConfigCopyRowSuccess => 'Step configuration summary copied to clipboard successfully';
  @override String stepConfigCopyBadgeSuccess(String label, String value) => 'Copied $label: $value';
  @override String get stepConfigSearchCopied => 'Search query copied to clipboard';
  @override String get stepConfigExportTsvBtn => 'Export TSV';
  @override String get stepConfigExportExcelBtn => 'Export Excel';
  @override String get stepConfigPrintPdfBtn => 'Vector PDF';
  @override String get stepConfigCopyDossierBtn => 'Copy Dossier';
  @override String get stepConfigCopiedTsvSuccess => 'Step configurations exported and copied as TSV successfully';
  @override String get stepConfigCopiedExcelSuccess => 'Excel file exported successfully';
  @override String get stepConfigCopiedDossierSuccess => 'Step governance dossier copied to clipboard successfully';
  @override String get stepConfigPdfTitle => 'Lifecycle Steps Skip Policies & Risk Governance Report';
  @override String get stepConfigPdfSubtitle => 'Risk criteria and preliminary approval registry for import workflow';
  @override String get stepConfigDossierHeader => '=== Lifecycle Steps Governance & Skip Policies Dossier ===';
  @override String get stepConfigDossierKpiSummary => '--- Governance KPI Summary ---';
  @override String get stepConfigDossierRecordsDetails => '--- 25 Steps Detailed Configuration ---';
  @override String get stepConfigDossierFooter => '=== End of Approved Governance Report ===';
  @override String stepConfigEditDialogTitle(String code) => 'Edit Step Policy: $code';
  @override String get stepConfigSkipPolicyLabel => 'Skip Policy:';
  @override String get stepConfigPolicyItemBlocked => 'Strictly Blocked from Skipping (Non-Skippable)';
  @override String get stepConfigPolicyItemSingleApproval => 'Single Approval (Manager or Designee)';
  @override String get stepConfigPolicyItemDualApproval => 'Dual Approval (Manager & Compliance Head)';
  @override String get stepConfigPendingRefToggleTitle => 'Early Pending Reference Registration';
  @override String get stepConfigPendingRefToggleSubtitle => 'Allow recording an early reference number while step remains compliant in-progress';
  @override String get stepConfigApproverRolesTitle => 'Authorized Approver Roles:';
  @override String get stepConfigApproverRolesSubtitle => 'Manager role is the always-authorized default fallback';
  @override String get stepConfigJustificationTitle => 'Modification Justification (Mandatory for Audit):';
  @override String get stepConfigJustificationHint => 'Example: Skip permitted for direct supply shipments under general management approval...';
  @override String get stepConfigJustificationValidator => 'Justification must be at least 5 characters long';
  @override String get stepConfigCancelBtn => 'Cancel';
  @override String get stepConfigSaveBtn => 'Save & Document Record';
  @override String stepConfigSaveSuccess(String code) => 'Step policy for $code updated successfully';
  @override String stepConfigAuditDialogTitle(String code) => 'Policy Audit History: $code';
  @override String get stepConfigAuditEmpty => 'No previous modifications recorded for this step';
  @override String stepConfigAuditBy(String user) => 'By: $user';
  @override String get stepConfigAuditPolicyChange => 'Policy Change:';
  @override String get stepConfigAuditJustification => 'Justification:';
  @override String get stepConfigAuditCloseBtn => 'Close';

  // ─── AI Assistant Overlay & Lifecycle Navigator ─────────────────────────────
  @override String get aiAssistantTitle => 'Smart Import Assistant';
  @override String get aiAssistantGreetingTitle => 'Hello';
  @override String get aiAssistantGreetingBody => 'Here to help with operations and chat inquiries.';
  @override String get aiAssistantOnlineStatus => 'Import Assistant Online';
  @override String get aiAssistantCloseTooltip => 'Close AI Assistant';
  @override String get aiAssistantOpenTooltip => 'Smart Import Assistant';
  @override String get aiAssistantMyShipmentsTooltip => 'My Shipments (Lifecycle Navigator)';
  @override String get aiAssistantClearChatTooltip => 'Clear Chat';
  @override String get aiAssistantApiKeySettingsTooltip => 'API Key Settings';
  @override String get aiAssistantExpandTooltip => 'Expand Chat Window';
  @override String get aiAssistantRestoreTooltip => 'Restore Size';
  @override String get aiAssistantCopyTranscriptTooltip => 'Copy Entire Chat Transcript';
  @override String get aiAssistantTranscriptCopied => 'Entire chat transcript copied to clipboard successfully';
  @override String get aiAssistantNoMessagesToCopy => 'No messages in chat to copy';
  @override String get aiAssistantInputHint => 'Ask about imports, customs, freight, tasks...';
  @override String get aiAssistantSendTooltip => 'Send';
  @override String get aiAssistantPasteTooltip => 'Paste from clipboard';
  @override String get aiAssistantCopyMessageSuccess => 'Copied successfully';
  @override String get aiAssistantUserMessageCopied => 'Your message copied successfully';
  @override String get aiAssistantAssistantMessageCopied => 'Assistant response copied successfully';
  @override String get aiAssistantCopyNotificationTooltip => 'Copy notification';
  @override String get aiAssistantNotificationCopied => 'Notification copied successfully';
  @override String get aiAssistantRetry => 'Retry';
  @override String get aiAssistantQuickSuggestionsTitle => 'Categorized Quick Suggestions';
  @override String get aiAssistantActivateTitle => 'Activate AI Assistant';
  @override String get aiAssistantActivateDesc => 'Enter your Gemini API Key to start chatting with the smart import assistant.';
  @override String get aiAssistantEnterApiKey => 'Enter API Key';
  @override String get aiAssistantGetApiKeyLabel => 'Get API Key from Google AI Studio (Click to open)';
  @override String get aiAssistantApiKeyDialogTitle => 'Gemini API Key';
  @override String get aiAssistantApiKeyFieldLabel => 'API Key';
  @override String get aiAssistantApiKeyActiveStatus => 'Active and configured API key';
  @override String get aiAssistantDisableKey => 'Disable Key';
  @override String get aiAssistantSaveAndActivate => 'Save & Activate';
  @override String get aiAssistantClearContextTooltip => 'Clear active shipment context';
  @override String get aiAssistantViewDataShortcut => 'View Data';
  @override String get aiAssistantUpdateDataShortcut => 'Update Data';
  @override String get aiAssistantAskAboutStepShortcut => 'Ask about Step';
  @override String get aiAssistantCopiedUrlSuccess => 'Copied link to clipboard and opened browser';
  @override String get aiAssistantOpenLink => 'Open Link';
  @override String get aiAssistantCancel => 'Cancel';
  @override String get aiLifecycleTitle => 'Lifecycle:';
  @override String get aiLifecycleCloseTooltip => 'Close Navigator';
  @override String get aiLifecycleCopySummaryTooltip => 'Copy lifecycle summary';
  @override String get aiLifecycleSummaryCopied => 'Lifecycle summary copied to clipboard';
  @override String get aiLifecycleNoShipments => 'No shipments registered yet';
  @override String get aiLifecycleStartNewShipment => 'Start New Shipment';
  @override String get aiLifecycleAllCompleted => 'All shipment stages successfully completed (100%).';
  @override String aiLifecycleCompletionRate(String icon, int percent, int completed, int total) =>
      'Completion Rate: $icon $percent% ($completed of $total steps)';
  @override String get aiLifecycleStatusOverdue => 'Overdue';
  @override String get aiLifecycleStatusCompleted => 'Completed';
  @override String get aiLifecycleStatusActive => 'Active';
  @override String get aiLifecycleStatusUpcoming => 'Upcoming';
  @override String get aiLifecycleHideStages => 'Hide other stages';
  @override String aiLifecycleShowAllStages(int count) => 'Show all stages (+$count)';
  @override String aiLifecycleActionsFor(String stepName) => 'Actions for: $stepName';
  @override String get aiLifecycleActionView => 'View Data';
  @override String get aiLifecycleActionUpdate => 'Update';
  @override String get aiLifecycleActionAsk => 'Ask';
  @override String get aiLifecycleActionSkip => 'Skip';
  @override String get aiLifecycleCopyFileCodeTooltip => 'Copy file code';
  @override String get aiLifecycleFileCodeCopied => 'File code copied to clipboard';

  // ── INT-DATA-015: Free Freight & Demurrage Connector ────────────────
  @override String get freightDataConnectorDialogTitle => 'Free Freight & Demurrage External Data Connector';
  @override String get freightDataConnectorDialogSubtitle => 'External SFX Freight Index, Shipping Line Demurrage Rules, and Egyptian Port Storage Decrees';
  @override String get freightDataTabOverview => 'Overview & Quota Monitor';
  @override String get freightDataTabSimulator => 'Dual Demurrage Simulator';
  @override String get freightDataTabPortTariffs => 'Egyptian Port Storage Tariffs';
  @override String get freightDataShaqFreightSection => 'Shaq-Freight Weekly Index (SFX)';
  @override String get freightDataShaqFreightDesc => '100% Free Python library aggregating weekly container freight spot rates across global and Mediterranean trade lanes.';
  @override String get freightDataShippingRatesSection => 'ShippingRates.org Demurrage Rules Connector';
  @override String get freightDataShippingRatesDesc => 'Aggregates free time slabs and detention demurrage tiers for major carriers under quota guard protection.';
  @override String get freightDataPortDecreesSection => 'Egyptian Port Authorities Storage Tariffs Registry';
  @override String get freightDataPortDecreesDesc => 'Historical and active ministerial decrees governing container yard storage in Egyptian pounds.';
  @override String get freightDataStatusActive => 'Active & Connected';
  @override String get freightDataMonthlyQuota => 'Monthly API Quota';
  @override String get freightDataQuotaUsed => 'Calls Used';
  @override String get freightDataQuotaRemaining => 'Calls Remaining';
  @override String get freightDataSyncSfxNow => 'Sync SFX Index Now';
  @override String get freightDataSyncSfxSuccess => 'Freight index snapshots updated successfully';
  @override String get freightDataRefreshStatus => 'Refresh Connector Status';
  @override String get freightDataTrackedRoutesCount => 'Tracked Trade Routes';
  @override String get freightDataTrackedLinesCount => 'Tracked Shipping Lines';
  @override String get freightDataActiveDecreesCount => 'Registered Storage Decrees';
  @override String get freightDataLastSyncDate => 'Last Sync Date';
  @override String get freightDataNeverSynced => 'Never Synced';
  @override String get freightDataSimShippingLine => 'Shipping Line';
  @override String get freightDataSimPortAuthority => 'Port Authority';
  @override String get freightDataSimContainerType => 'Container Type';
  @override String get freightDataSimDischargeDate => 'Discharge Date';
  @override String get freightDataSimClearanceDate => 'Calculation / Clearance Date';
  @override String get freightDataSimDaysInPort => 'Total Days in Port';
  @override String get freightDataSimFxRate => 'Exchange Rate (USD to EGP)';
  @override String get freightDataSimCalculateBtn => 'Calculate Dual Demurrage Instantly';
  @override String get freightDataCarrierDetentionTitle => 'Carrier Detention (USD)';
  @override String get freightDataPortStorageTitle => 'Port Yard Storage (EGP)';
  @override String get freightDataAppliedDecree => 'Applied Decree Version';
  @override String get freightDataFreeDaysLabel => 'Free Days Allowance';
  @override String get freightDataChargeableDaysLabel => 'Chargeable Incurred Days';
  @override String get freightDataConsolidatedSummary => 'Consolidated Dual Financial Summary';
  @override String get freightDataTotalDetentionUsd => 'Total Detention (USD)';
  @override String get freightDataTotalStorageEgp => 'Total Port Storage (EGP)';
  @override String get freightDataConsolidatedEgp => 'Total Equivalent (EGP)';
  @override String get freightDataConsolidatedUsd => 'Total Equivalent (USD)';
  @override String get freightDataCopySimulationDossier => 'Copy Full Calculation Dossier';
  @override String get freightDataSimulationDossierCopied => 'Dual demurrage dossier copied to clipboard';
  @override String get freightDataAddTariffDecreeBtn => 'Add New Port Tariff Decree';
  @override String get freightDataTariffVersionCol => 'Decree / Version Code';
  @override String get freightDataEffectiveFromCol => 'Effective From';
  @override String get freightDataEffectiveToCol => 'Effective To';
  @override String get freightDataActiveOngoing => 'Active (Current)';
  @override String get freightDataSourceDocCol => 'Official Source Document';
  @override String get freightDataRateSlabsSummary => 'Rate Slabs Breakdown';
  @override String get freightDataCopySlabRateTooltip => 'Copy Rate Value';
  @override String get freightDataLaunchConnectorTooltip => 'Free Freight & Demurrage External Data Connector';
  @override String get freightDataQuotaGuardAlert => 'Quota Guard: Maximum 10 monthly calls to preserve API buffer';
  @override String get freightDataDayUnit => 'Days';
  @override String get freightDataPerDayUnit => 'Day';
  @override String get freightDataCopyStatusSummary => 'Copy Full Status Summary';
  @override String get freightDataTotalLabel => 'Total';
  @override String get freightDataNoDecreesFound => 'No registered tariffs found';

  // ── AI Quotation & Completeness Validation Layer (AI-EXTRACT-VALIDATE-001) ──
  @override String get quotationValidationBannerSafeTitle => 'Reliable & Complete Extraction';
  @override String get quotationValidationBannerWarningTitle => 'Notice: Likely Unextracted Items';
  @override String get quotationValidationBannerCriticalTitle => 'Critical Warning: Quotation Completeness Gap';
  @override String quotationValidationExpectedCount(dynamic count) => 'Expected Items: $count';
  @override String quotationValidationExtractedCount(dynamic count) => 'Extracted Items: $count';
  @override String quotationValidationGapPercentage(dynamic percent) => 'Extraction Gap: $percent%';
  @override String get quotationValidationMultiValueBadge => 'Multi-Value Split';
  @override String get quotationValidationMultiValueTooltip => 'Extracted from multi-value cell, verify splitting accuracy';
  @override String get quotationValidationRangeBadge => 'Price Range';
  @override String quotationValidationRangeTooltip(dynamic min, dynamic max) => 'Estimated price range: from $min to $max EGP';
  @override String get quotationValidationOutsideTableBadge => 'Outside Table';
  @override String get quotationValidationOutsideTableTooltip => 'Conditional item extracted from text conditions outside table';
  @override String get quotationValidationConfirmTitle => 'Confirm Quote Adoption Despite Extraction Gap';
  @override String quotationValidationConfirmMessage(dynamic expected, dynamic extracted, dynamic gap) => 'Detected $expected price patterns but only $extracted items were extracted (gap: $gap%). Do you want to proceed and adopt current items under your responsibility?';
  @override String get quotationValidationProceedBtn => 'Proceed Under My Responsibility';
  @override String get quotationValidationReviewBtn => 'Return to Review';
  @override String get quotationValidationCopyReportBtn => 'Copy Extraction Audit Report';
  @override String get quotationValidationReportCopiedToast => 'Extraction audit report copied to clipboard successfully';

  // ── Clearance Expense Types Catalog Exports ──
  @override String get expenseCatalogExportPdfBtn => 'Export PDF Report';
  @override String get expenseCatalogExportExcelBtn => 'Export Excel';
  @override String get expenseCatalogExportTsvBtn => 'Export TSV Table';
  @override String get expenseCatalogCopyDossierBtn => 'Copy Catalog Dossier';
  @override String get expenseCatalogDossierCopiedToast => 'Expense catalog dossier copied to clipboard successfully';
  @override String get expenseCatalogPdfReportTitle => 'Master Clearance Expense Types Catalog';
  @override String get expenseCatalogPdfReportSubtitle => 'Official Directory of Expense Codes, Categories and Calculation Units';
  @override String expenseCatalogTotalCountLabel(dynamic count) => 'Total Expense Types: $count';
  @override String expenseCatalogActiveCountLabel(dynamic count) => 'Active Expenses: $count';
  @override String get editExpenseTypeDialogTitle => 'Edit Expense Type';
  @override String get confirmDeleteExpenseTypeTitle => 'Confirm Delete Expense';
  @override String confirmDeleteExpenseTypeMsg(dynamic name, dynamic code) => 'Are you sure you want to delete and deactivate expense item ($name) with code ($code)?';
  @override String get expenseTypeUpdatedToast => 'Expense type updated successfully';
  @override String get expenseTypeDeletedToast => 'Expense type deleted successfully';
  @override String get copyExpenseRowSummaryTooltip => 'Copy expense row summary';
  @override String get editExpenseTooltip => 'Edit expense type';
  @override String get deleteExpenseTooltip => 'Delete expense type';

  // ── Universal Clone Engine (UX-CLONE-011) ──
  @override String get cloneRowTooltip => 'Clone Row (Ctrl+D)';
  @override String cloneEntityDialogTitle(dynamic entityType) => 'Clone $entityType — Review & Confirm Data';
  @override String get cloneEntityDialogSubtitle => 'Review copied and mandatorily reset fields prior to creating new record';
  @override String cloneSourceReferenceLabel(dynamic code) => 'Source Entity: $code';
  @override String get cloneNewCodeLabel => 'Target New Reference Code:';
  @override String get cloneNewCodeRequiredError => 'Please enter a unique reference code for the cloned entity';
  @override String get cloneCopiedFieldsHeader => 'Automatically Copied Data (Direct Duplicate)';
  @override String get cloneResetFieldsHeader => 'Mandatorily Reset Fields (Never Copied)';
  @override String get cloneFieldStatusDraftBadge => 'Status: Automatically resets to Draft';
  @override String get cloneFieldCustomsClearedReset => 'Customs Released Status: Reset to False';
  @override String get cloneFieldFinancialReset => 'Payment & Form 4 numbers: Cleared/Reset';
  @override String get cloneCopyInvoicesCheckbox => 'Copy invoice line items and packing list items';
  @override String get cloneCopyAttachmentsCheckbox => 'Copy uploaded attachments & documents (unchecked by default)';
  @override String get cloneConfirmAndCreateBtn => 'Confirm Clone & Create Record';
  @override String clonedFromBadge(dynamic code) => 'Cloned from: $code';
  @override String clonedSuccessfullyToast(dynamic code) => 'Entity cloned successfully with new code ($code)';
  @override String get clonePriceListDialogTitle => 'Clone Broker Price List';
  @override String get cloneImportFileDialogTitle => 'Clone Import File';
  @override String get cloneConsultationDialogTitle => 'Clone Customs Consultation Study';
  @override String get clonePriceListActionTooltip => 'Clone Entire Price List';
  @override String get cloneRowActionTooltip => 'Clone Current Row';
  @override String get clonePurchaseOrderDialogTitle => 'Clone Purchase Order';
  @override String get searchAndClonePoBtn => 'Search & Clone PO';
  @override String get searchAndClonePoDialogTitle => 'Search & Clone Purchase Order';
  @override String get searchAndClonePoSubtitle => 'Select a purchase order to duplicate with reset of shipments and allocations';
  @override String get searchByPoOrSupplierOrItemHint => 'Search by PO number, title, PI, supplier, company, project...';
  @override String get noMatchingPosFound => 'No matching purchase orders found';
  @override String clonePoSuccess(dynamic code) => 'Purchase Order $code cloned successfully';
  @override String clonePoError(dynamic error) => 'Failed to clone Purchase Order: $error';
  @override String get cloneRowItemTooltip => 'Duplicate Line Item (Ctrl + D)';
  @override String get clonePackingItemTooltip => 'Duplicate Package / Carton Item';
  @override String get lineItemClonedSuccess => 'Line item duplicated successfully';
  @override String get packingItemClonedSuccess => 'Package item duplicated successfully';
  @override String get cloneFieldAllocationsReset => 'Reset partial shipment allocations';
  @override String get cloneFieldShipmentUnlinked => 'Unlink from previous import file';
  @override String get searchAndCloneCbmBtn => 'Search & Clone Study';
  @override String get cloneCbmDialogTitle => 'Clone CBM Calculation Study';
  @override String get searchAndCloneCbmDialogTitle => 'Search & Clone Calculation Session';
  @override String get searchAndCloneCbmSubtitle => 'Find an existing calculation study and clone its cargo specifications as a new template';
  @override String get searchByCalcCodeOrTitleHint => 'Search by calculation code, title, or notes...';
  @override String get noMatchingCalcsFound => 'No matching calculation studies found';
  @override String cloneCbmSuccess(dynamic code) => 'CBM Study [$code] cloned successfully';
  @override String cloneCbmError(dynamic error) => 'Failed to clone CBM Study: $error';
  @override String get cloneQuickItemTooltip => 'Duplicate Cargo Package (Ctrl + D)';
  @override String get cargoItemClonedSuccess => 'Cargo package duplicated with live recalculation';
  @override String get cloneFieldCalcCodeGenerated => 'Generate new unique calculation code';
  @override String get cloneFieldImportFileReset => 'Unlink from previous import file';
  @override String get cloneFieldPoReset => 'Unlink from previous purchase order';

  // ── Screen 4 Shipping Scenarios Clone & Responsive Keys ─────────────────────
  @override String get searchAndCloneStudyBtn => 'Search & Clone Study';
  @override String get cloneStudyDialogTitle => 'Clone Shipping Evaluation Study';
  @override String get searchAndCloneStudyDialogTitle => 'Search & Clone Freight Evaluation';
  @override String get searchAndCloneStudySubtitle => 'Find an existing study and clone carrier quotations as a new draft';
  @override String get searchByStudyCodeOrTitleHint => 'Search by study code, title, carrier, or project...';
  @override String get noMatchingStudiesFound => 'No matching freight studies found';
  @override String cloneStudySuccess(dynamic code) => 'Freight Study [$code] cloned successfully';
  @override String cloneStudyError(dynamic error) => 'Failed to clone Freight Study: $error';
  @override String get cloneCarrierOptionTooltip => 'Duplicate Carrier Option (Ctrl + D)';
  @override String get carrierOptionClonedSuccess => 'Carrier option duplicated with live recalculation';
  @override String get cloneFieldStudyCodeGenerated => 'Generate new unique study code';
  @override String get cloneFieldSelectionReset => 'Reset carrier selection to evaluate anew';
  @override String get carrierOptionHeader => 'Carrier Option';

  // ── Screen 6 Customs Consultation Clone & Responsive Keys ─────────────────────
  @override String get searchAndCloneConsultationBtn => 'Search & Clone Consultation';
  @override String get searchAndCloneConsultationDialogTitle => 'Search & Clone Previous Customs Consultation';
  @override String get searchAndCloneConsultationSubtitle => 'Select an existing consultation to clone tariff lines and documents into a new draft';
  @override String get searchByConsultationCodeOrTitleHint => 'Search by consultation code, title, or broker...';
  @override String get noMatchingConsultationsFound => 'No matching customs consultations found';
  @override String cloneConsultationSuccess(dynamic code) => 'Customs Consultation [$code] cloned successfully';
  @override String cloneConsultationError(dynamic error) => 'Failed to clone customs consultation: $error';
  @override String get cloneChecklistItemTooltip => 'Duplicate Checklist Document Item (Ctrl + D)';
  @override String get checklistItemClonedSuccess => 'Checklist document item cloned successfully';
  @override String get cloneFieldConsultationCodeGenerated => 'Generate new unique consultation code';
  @override String get cloneFieldChecklistReset => 'Reset regulatory documents status to Pending';
  @override String get cloneConsultationTooltip => 'Clone this customs consultation as a new draft';
  @override String get searchAndCloneConsultationTooltip => 'Search previous consultations and clone as a new draft';

  // ── Screen 8 Financial Approval (Payment Requests) Clone & Responsive Keys ───
  @override String get searchAndClonePaymentRequestBtn => 'Search & Clone Payment Request';
  @override String get searchAndClonePaymentRequestDialogTitle => 'Search & Clone from Past Payment Requests';
  @override String get searchAndClonePaymentRequestSubtitle => 'Select an existing payment request to clone beneficiary and banking data';
  @override String get searchByPaymentCodeOrSupplierHint => 'Search by payment code, supplier, or import file...';
  @override String get noMatchingPaymentRequestsFound => 'No matching payment requests found';
  @override String clonePaymentRequestSuccess(dynamic code) => 'Payment request cloned successfully ($code) as a new draft';
  @override String clonePaymentRequestError(dynamic error) => 'Failed to clone payment request: $error';
  @override String get clonePaymentRequestTooltip => 'Clone this payment request as a new draft';
  @override String get searchAndClonePaymentTooltip => 'Search and clone from past payment requests';
  @override String get clonePaymentRequestDialogTitle => 'Clone Payment Request';
  @override String get cloneFieldPaymentCodeGenerated => 'Generate new unique payment code';
  @override String get cloneFieldBankingDetailsCopied => 'Copy supplier banking and SWIFT details';
  @override String get cloneFieldPaymentStatusReset => 'Reset status automatically to Draft';
  @override String get cloneFieldSwiftReceiptReset => 'Clear payment receipts and executed transfer data';
  @override String get clonePoAllocationTooltip => 'Clone PO Allocation';
  @override String get poAllocationClonedSuccess => 'PO allocation cloned successfully';

  // ── Screen 9 Financial Approval (Import Budget) Clone & Responsive Keys ───
  @override String get searchAndCloneBudgetBtn => 'Search & Clone Import Budget';
  @override String get searchAndCloneBudgetDialogTitle => 'Search & Clone from Past Import Budgets';
  @override String get searchAndCloneBudgetSubtitle => 'Select an existing approved budget to clone cost breakdown and exchange rates';
  @override String get searchByBudgetCodeOrTitleHint => 'Search by budget code, title, or import file...';
  @override String get noMatchingBudgetsFound => 'No matching budgets found';
  @override String cloneBudgetSuccess(dynamic code) => 'Import budget cloned successfully ($code) as a new draft';
  @override String cloneBudgetError(dynamic error) => 'Failed to clone import budget: $error';
  @override String get cloneBudgetTooltip => 'Clone Import Budget';
  @override String get searchAndCloneBudgetTooltip => 'Search and clone import budget';
  @override String get cloneBudgetDialogTitle => 'Clone Import Budget';
  @override String get cloneFieldBudgetCodeGenerated => 'Generate new unique budget code';
  @override String get cloneFieldBudgetStatusReset => 'Reset status automatically to Pending Review / Draft';
  @override String get cloneFieldCertificationsReset => 'Clear approval and certification records';
  @override String get cloneFieldExchangeRatesCopied => 'Copy cost breakdown structure and exchange rates';

  // ── Import Files Search, Clone & Dialogs Hardening ─────────────────────────
  @override String get searchAndCloneImportFileBtn => 'Search & Clone Shipment';
  @override String get searchAndCloneImportFileDialogTitle => 'Search & Clone Import File';
  @override String get searchAndCloneImportFileSubtitle => 'Select a shipment to duplicate with automatic reset of ACID & clearance';
  @override String get searchAndCloneImportFileHint => 'Search by file code, company, supplier, or PO...';
  @override String resultsWithCount(dynamic count) => 'Results ($count)';
  @override String get noMatchingShipmentsFound => 'No matching shipments found';
  @override String get cloneFieldAcidReset => 'Reset ACID number and filing date';
  @override String get portsOfLoadingAndDischarge => 'Ports (POL → POD)';
  @override String get smartChecklistTooltip => 'Smart Shipment Operational Checklist';
  @override String get moreToolsTooltip => 'More Tools';
  @override String confirmDeleteImportFilePrompt(dynamic code) => 'Are you sure you want to delete import file $code?';
  @override String get cloneBtn => 'Clone';
  @override String get selectCompanyValidation => 'Please select the Egyptian importing company';
  @override String get selectSupplierValidation => 'Please select the foreign supplier';
  @override String get ownerFieldRequired => 'Project in-charge / Owner is required';
  @override String get ownerFieldHint => 'Person in charge or project coordinator name';
  @override String get containerStackableTab => '📦 1. Stackable';
  @override String get containerNonStackableTab => '🚫 2. Non-Stackable';
  @override String get containerMixedTab => '🔀 3. Mixed';
  @override String get woodenFloorPallets => '🪵 Wooden Floor Pallets';
  @override String get internalDimensionsPrefix => 'Internal Dimensions:';
  @override String get containerOptionsAnalysisTitle => 'Container Options Analysis & Load Scenarios';
  @override String get closeDiagramBtn => 'Close Diagram';
  @override String get approvedRecommendationPrefix => 'Approved Recommendation:';
  @override String get oversizedItemsWarning => 'The following items exceed container capacity:';
  @override String get failedToFetchRfqData => 'Failed to fetch freight RFQ data from server.';
  @override String get generatingRfqTemplatesLoading => 'Aggregating shipment details and generating freight RFQ templates...';

  // ── KB-GUIDE-012 Smart Shipment Experience Guide & Reference Card ───────────
  @override String get experienceGuideTitle => 'Smart Shipment Experience Guide';
  @override String get smartReferenceCardTitle => 'Shipment Smart Reference Card';
  @override String get addGuideEntryBtn => 'Add Experience Guide Note';
  @override String get manageGuideEntriesBtn => 'Manage Experience Guide';
  @override String get guideCriticalAlertTitle => 'Critical Experience Alert';
  @override String get guideWarningAlertTitle => 'Procedural Warning Alert';
  @override String get guideMandatoryPortAlert => 'Mandatory Destination Port:';
  @override String get guideRequiredDocsAlert => 'Mandatory Prerequisite Documents:';
  @override String get guideAutoApplyPortBtn => 'Auto-Apply Mandatory Port';
  @override String get guideAddSuggestedNoteBtn => 'Insert Guidance into File Notes';
  @override String get guideAppliedPortSuccess => 'Mandatory destination port applied successfully';
  @override String get guideNoteInsertedSuccess => 'Experience guidance inserted into notes successfully';
  @override String get refCardProductSection => 'Product & Quantity Summary';
  @override String get refCardRouteSection => 'Route & Carrier Summary';
  @override String get refCardDatesSection => 'Critical Dates & Free Time';
  @override String get refCardDocsSection => 'Customs Documents Readiness';
  @override String get refCardCostSection => 'Estimated vs Actual Cost Comparison';
  @override String get refCardMatchedGuideSection => 'Matched Experience Guidelines';
  @override String get refCardHsCodeLabel => 'Customs Tariff HS Code:';
  @override String get refCardCategoryLabel => 'Product Category:';
  @override String get refCardTotalCbmLabel => 'Total Volume (CBM):';
  @override String get refCardGrossWeightLabel => 'Gross Weight (KG):';
  @override String get refCardPackagesCountLabel => 'Total Packages:';
  @override String get refCardPolLabel => 'Port of Loading:';
  @override String get refCardPodLabel => 'Port of Discharge:';
  @override String get refCardCarrierLabel => 'Carrier & Shipping Line:';
  @override String get refCardFreeDaysLabel => 'Demurrage Free Days:';
  @override String get refCardEstCostLabel => 'Estimated Cost:';
  @override String get refCardActualCostLabel => 'Actual Invoiced Cost:';
  @override String get refCardVarianceLabel => 'Cost Variance:';
  @override String get refCardDocsCompleteBadge => 'Documents Complete';
  @override String get refCardDocsPendingBadge => 'Documents Pending';
  @override String get refCardCooAttachedBadge => 'Certificate of Origin Attached';
  @override String get refCardCooMissingBadge => 'Certificate of Origin Missing (Mandatory)';
  @override String get guideEntryTitleLabel => 'Guidance Title';
  @override String get guideEntryContentLabel => 'Experience Details & Requirements';
  @override String get guideEntryTypeLabel => 'Guidance Type';
  @override String get guideSeverityLabel => 'Severity Level';
  @override String get guideScopesHeader => 'Application Scopes';
  @override String get guideAddScopeBtn => 'Add Matching Scope';
  @override String get guideEntrySavedSuccess => 'Experience guideline saved successfully';
  @override String get guideEntryDeleteConfirm => 'Are you sure you want to delete this guideline?';
  @override String get copyReferenceCardTooltip => 'Copy Reference Card Data to Clipboard';
  @override String get referenceCardCopiedSuccess => 'Reference card data copied successfully';
  @override String get guideHsCode => 'Customs HS Code';
  @override String get guideMatchButton => 'Check Experience Guidelines';
  @override String get guideProductCategory => 'Product Category';
  @override String get guideMatchResultLabel => 'Matched Experience Guidelines';

  // ── KB-INQ-013 Smart Shipment Inquiry, History & Cloning Screen ────────────
  @override String get inqScreenTitle => 'Shipment History & Smart Inquiry';
  @override String get inqFilterPanelTitle => 'Filters & Advanced Search Panel';
  @override String get inqSupplier => 'Foreign Supplier';
  @override String get inqAllSuppliers => 'All Foreign Suppliers';
  @override String get inqImporter => 'Importing Company';
  @override String get inqAllImporters => 'All Importing Companies';
  @override String get inqHsCodeOrProduct => 'HS Code / Item Code / Description';
  @override String get inqHsCodeHint => 'Search by HS Code, item name, or SKU';
  @override String get inqIncoterm => 'Delivery Term (Incoterm)';
  @override String get inqAllIncoterms => 'All Incoterms';
  @override String get inqPortOfLoading => 'Port of Loading (POL)';
  @override String get inqPortOfDischarge => 'Port of Discharge (POD)';
  @override String get inqShippingMode => 'Shipping Mode & Container';
  @override String get inqAllShippingModes => 'All Shipping Modes';
  @override String get inqCarrier => 'Carrier / Forwarder';
  @override String get inqDateRange => 'Date Range';
  @override String get inqAllDates => 'All Dates';
  @override String get inqSearchBtn => 'Search';
  @override String get inqResetBtn => 'Reset';
  @override String get inqAdvancedFilters => 'Advanced Logistics Filters';
  @override String get inqHideAdvancedFilters => 'Hide Advanced Filters';
  @override String get inqExportPrintBtn => 'Export / Print Report';
  @override String get inqExportExcelBtn => 'Export to Excel';
  @override String get inqExportPdfBtn => 'Print Official PDF';
  @override String get inqSaveFilterPreset => 'Save Filter Preset';
  @override String get inqPresetSaved => 'Filter preset saved successfully';
  @override String get inqColShipmentName => 'Shipment Name';
  @override String get inqColSupplier => 'Foreign Supplier';
  @override String get inqColImporter => 'Importing Company';
  @override String get inqColItemAndHs => 'Item & HS Code';
  @override String get inqColRoute => 'Shipping Route';
  @override String get inqColShippingMode => 'Shipping Mode & Container';
  @override String get inqColIncoterm => 'Incoterm';
  @override String get inqColFreightCost => 'Freight Cost';
  @override String get inqColActions => 'Actions';
  @override String get inqActionClone => 'Smart Clone';
  @override String get inqActionDetails => 'View Details';
  @override String get inqTotalMatchingShipments => 'Total Matching Shipments';
  @override String get inqAverageFreightCost => 'Average Freight Cost';
  @override String get inqTotalIncurredCost => 'Total Recorded Cost';
  @override String get inqCloneDialogTitle => 'Smart Shipment Cloning';
  @override String get inqCloneSuccessHeader => 'Shipment data cloned as template. Please review new dates and prices before saving.';
  @override String get inqCloneCopiedDataTitle => 'Automatically Copied Data';
  @override String get inqCloneClearedDataTitle => 'Fields Requiring New Input';
  @override String get inqCloneLastRecordedCost => 'Last Recorded Cost';
  @override String get inqCloneNewShipmentName => 'New Shipment Name';
  @override String get inqCloneNewFileCode => 'New Import File Code';
  @override String get inqCloneNewInvoiceNumber => 'PI / Commercial Invoice Number';
  @override String get inqCloneNewFreightCost => 'New Freight Cost';
  @override String get inqCloneConfirmBtn => 'Confirm & Clone Shipment';
  @override String get inqCloneOpenFormBtn => 'Open Form for Full Editing';
  @override String get inqReportTitle => 'Shipment Historical Movement & Cost Ledger';
  @override String get inqReportGeneratedAt => 'Report Generated At';
  @override String get inqReportGeneratedBy => 'User';

  // ── Screen 68: Smart Shipment Inquiry Additions ────────────────────────────
  @override String get inqSubtitle => 'Comprehensive detailed inquiry, historical freight cost ledger, and smart cloning for recurring shipments';
  @override String get inqLiveRefreshTooltip => 'Refresh data live from server';
  @override String get inqLoadError => 'Error loading shipments: ';
  @override String get inqAllRegisteredShipments => 'All registered shipments';
  @override String get inqSearchPrefix => 'Search: ';
  @override String get inqOperatorManagerDefault => 'Operations Manager';
  @override String get inqExportTsvBtn => 'Export TSV';
  @override String get inqCopyDossierTooltip => 'Copy entire text dossier summary';
  @override String get inqResultsTableTitle => '1. Shipments History & Inquiry Results';
  @override String inqShowingMatchingCount(int count) => 'Showing $count matching shipments';
  @override String get inqEmptyShipmentsTitle => 'No shipments match the current search criteria';
  @override String get inqCopyCodeTooltip => 'Copy file code';
  @override String get inqCopyRowTooltip => 'Copy row summary';
  @override String get inqCopiedCodeSuccess => 'File code copied to clipboard';
  @override String get inqCopiedRowSuccess => 'Row summary copied to clipboard';
  @override String get inqCopiedDossierSuccess => 'Shipment inquiry dossier copied to clipboard';
  @override String get inqCopiedTsvSuccess => 'TSV data exported successfully';
  @override String get inqCopiedExcelSuccess => 'Excel/CSV exported successfully';
  @override String get inqCurrencyUsd => 'USD';
  @override String get inqCurrencyEur => 'EUR';
  @override String get inqCurrencyEgp => 'EGP';
  @override String get inqIncotermExw => 'EXW - Ex Works';
  @override String get inqIncotermFob => 'FOB - Free on Board';
  @override String get inqIncotermCfr => 'CFR - Cost and Freight';
  @override String get inqIncotermCif => 'CIF - Cost, Insurance and Freight';
  @override String get inqIncotermCip => 'CIP - Carriage and Insurance Paid';
  @override String get inqIncotermDpu => 'DPU - Delivered at Place Unloaded';
  @override String get inqIncotermDap => 'DAP - Delivered at Place';
  @override String get inqIncotermDdp => 'DDP - Delivered Duty Paid';
  @override String get inqModeSeaFcl => 'Sea - Full Container (FCL)';
  @override String get inqModeSeaLcl => 'Sea - Less Container (LCL)';
  @override String get inqModeAir => 'Air Cargo';
  @override String get inqModeLand => 'Land Transport';
  @override String get inqAllModes => 'All Shipping Modes';
  @override String inqCloneDialogSubtitle(String code) => 'Cloning shipment $code as an operational template';
  @override String inqCloneSuccessBanner(String code) => 'Shipment data for $code cloned successfully. Please review dates and costs before saving.';
  @override String get inqCloneCopyInvoicesLabel => 'Copy invoice line items as preliminary items';
  @override String get inqCloneCopyPackingListsLabel => 'Copy packing list weights and measurements';
  @override String get inqCloneValidationName => 'Please enter a name for the new shipment';
  @override String get inqCloneValidationCode => 'Please enter a new import file code';
  @override String get inqCloneInvoiceHint => 'New invoice number (optional now)';
  @override String get inqCloneNotesLabel => 'Shipment Notes & Directives';
  @override String inqCloneSuccessToast(String code) => 'Shipment cloned successfully with code: $code';
  @override String inqCloneTemplateDefaultNote(String code) => 'Cloned as a template from shipment: $code';
  @override String get inqCloneNewShipmentSuffix => '(New Version)';
  @override String get inqExportTsvDialogTitle => 'Export Shipment Inquiry Data (TSV)';
  @override String get inqExportExcelDialogTitle => 'Export Shipment Inquiry Data (CSV / Excel)';
  @override String get inqExportPdfDialogTitle => 'Official Shipment History & Inquiry Dossier';
  @override String get inqPdfSystemBranding => 'Advanced Import & Logistics Management System — Sorour Logistics';
  @override String get inqPdfOfficialBadge => 'Official Historical Record';
  @override String get inqPdfFilterCriteria => 'Search Criteria Applied: ';
  @override String inqPdfPageOf(int page, int total) => 'Page $page of $total';
  @override String get inqTsvHeaderFileCode => 'File Code';
  @override String get inqTsvHeaderCurrency => 'Currency';
  @override String get inqTsvHeaderDate => 'Date';
  @override String get inqDossierCriteria => 'Search Criteria: ';
  @override String inqDossierKpiSummary(int count, String total, String avg) => '$count Matching Shipments | Total Incurred: $total | Average Freight: $avg';
  @override String get inqDossierRowSupplier => 'Supplier';
  @override String get inqDossierRowImporter => 'Importer';
  @override String get inqDossierRowItemAndHs => 'Item & HS Code';
  @override String get inqDossierRowRoute => 'Route';
  @override String get inqDossierRowShippingMode => 'Shipping Mode';
  @override String get inqDossierRowIncoterm => 'Incoterm';
  @override String get inqDossierRowFreight => 'Freight Cost';
  @override String get themeToggleTooltip => 'Toggle Dark / Light Mode';
  @override String get darkMode => 'Dark Mode';
  @override String get lightMode => 'Light Mode';
  @override String get systemMode => 'System Default';

  // ── Desktop Command Palette (Ctrl + K) ──
  @override String get commandPaletteTitle => 'Command Palette & Global Search';
  @override String get commandPaletteSearchHint => 'Search screens, quick actions, shipments, suppliers...';
  @override String get commandPaletteCategoryScreens => 'Screens & Workflow Stages';
  @override String get commandPaletteCategoryActions => 'Quick Actions & Utilities';
  @override String get commandPaletteCategoryRecords => 'Records & Master Data';
  @override String get commandPaletteNoResults => 'No results found matching your query';
  @override String get commandPaletteKeyboardNavHint => 'Use ↑ ↓ arrows to navigate, Enter to select, Esc to close';
  @override String get commandPaletteShortcutTooltip => 'Command Palette & Global Search (Ctrl + K)';
  @override String get commandPaletteOpenScreenAction => 'Open screen in workspace';
  @override String get commandPaletteQuickAction => 'Execute Quick Action';

  // ── Desktop Shortcuts & Power-User Suite ──
  @override String get keyboardShortcutsTitle => 'Keyboard Shortcuts Guide';
  @override String get keyboardShortcutsSubtitle => 'Power-user keyboard cheat-sheet for rapid operations';
  @override String get shortcutsCategoryNavigation => 'Navigation & Workspace';
  @override String get shortcutsCategoryOperations => 'Operations & Data';
  @override String get shortcutsCategoryProductivity => 'Productivity & Help';
  @override String get shortcutCommandPalette => 'Open Command Palette & Global Search';
  @override String get shortcutNextTab => 'Switch to Next Workspace Tab';
  @override String get shortcutPreviousTab => 'Switch to Previous Workspace Tab';
  @override String get shortcutCloseTab => 'Close Active Workspace Tab';
  @override String get shortcutToggleFullscreen => 'Toggle Fullscreen Mode';
  @override String get shortcutEscape => 'Dismiss Modals and Popups';
  @override String get shortcutSave => 'Quick Save Active Form / Session';
  @override String get shortcutNewRecord => 'Open Add New Record Modal';
  @override String get shortcutCloneRow => 'Clone Selected Row or Item';
  @override String get shortcutSearchTable => 'Focus Table Search Field';
  @override String get shortcutShowHelp => 'Display Keyboard Shortcuts Guide';
  @override String get fullscreenEnabledToast => 'Entered Fullscreen Mode';
  @override String get fullscreenDisabledToast => 'Exited Fullscreen Mode';

  // ── Unsaved Changes Guard ──
  @override String get unsavedChangesTitle => 'Unsaved Changes Warning';
  @override String get unsavedChangesMessage => 'You have unsaved changes on this screen. Do you want to discard your edits or stay to save?';
  @override String get unsavedChangesDiscardBtn => 'Discard Changes';
  @override String get unsavedChangesSaveBtn => 'Save Changes';
  @override String get unsavedChangesCancelBtn => 'Stay on Screen';
  @override String get unsavedChangesBadgeTooltip => 'This tab contains unsaved changes';

  // ── Enterprise Multi-Pane Layout ──
  @override String get multiPaneSelectPrompt => 'Select an item from the sidebar to inspect full details and related documents';
  @override String get multiPaneCollapseSidebar => 'Collapse Sidebar';
  @override String get multiPaneExpandSidebar => 'Expand Sidebar';
  @override String get multiPaneBackToList => 'Back to List';
  @override String get multiPaneSidebarTitle => 'Item List';
  @override String get multiPaneDetailsTitle => 'Detail View';

  // ── PO Balance & Partial Shipments Ledger ──
  @override String get poBalanceLedgerTitle => 'PO Balance & Partial Shipments Ledger';
  @override String poBalanceSubTitle(String poCode, String fulfillment) => 'Purchase Order: $poCode  •  Fulfillment Rate: $fulfillment%';
  @override String get poBalanceFullyShipped => '✅ Full PO shipment completed (100%)';
  @override String get poBalancePartialInProgress => '⏳ Partial shipments in progress';
  @override String get poBalanceTotalOrderedQty => 'Total Ordered Quantity';
  @override String get poBalanceActuallyShippedQty => 'Actually Shipped Quantity';
  @override String get poBalanceRemainingQty => 'Remaining Balance for Delivery';
  @override String get poBalanceUnit => 'units';
  @override String poBalanceValue(String val) => 'Value: $val';
  @override String get poBalanceLineItemsTitle => '📋 Line Items Balance Breakdown:';
  @override String get poBalanceColItemCode => 'Item Code';
  @override String get poBalanceColDescription => 'Description';
  @override String get poBalanceColOrderedQty => 'Ordered Qty';
  @override String get poBalanceColShippedQty => 'Shipped';
  @override String get poBalanceColRemaining => 'Remaining';
  @override String get poBalanceColStatus => 'Status';
  @override String get poBalanceStatusCompleted => 'Completed ✅';
  @override String get poBalanceStatusPartial => 'Partial Remaining ⏳';
  @override String get poBalanceLoading => 'Calculating shipment balance...';
  @override String poBalanceLoadError(String err) => 'Failed to load PO balance: $err';

  // ── Container Demurrage Radar (TR-02) ──
  @override String get demurrageRadarCardTitle => 'Container Demurrage & Free Days Radar (TR-02)';
  @override String get demurrageRadarCardSubtitle => 'Live tracking of free days for shipping lines and port storage to prevent detention fines';
  @override String get demurrageRadarRefreshTooltip => 'Refresh Radar';
  @override String get demurrageRadarOpenScreenBtn => 'Open Demurrage Screen';
  @override String get demurrageRadarSafeBadge => 'Safe in Free Time';
  @override String get demurrageRadarWarningBadge => '72-Hour Warning';
  @override String get demurrageRadarActiveFinesBadge => 'Active Fines';
  @override String get demurrageRadarReturnedBadge => 'Returned';
  @override String demurrageRadarExposureBanner(String usd, String egp, String total) =>
      'Total Accrued Fees: \$$usd Line Demurrage + $egp EGP Port Storage (Estimated Exposure: $total EGP)';
  @override String get demurrageRadarEmptyState =>
      'No containers currently tracked — all shipments are stable within free days.';
  @override String get demurrageRadarCarrierFreeDays => 'Line Free Days:';
  @override String demurrageRadarDaysCount(int consumed, int total) => '$consumed / $total days';
  @override String get demurrageRadarStatusSafe => 'Safe';
  @override String get demurrageRadarStatusWarning => 'Warning';
  @override String get demurrageRadarStatusCritical => 'Overdue';
  @override String get demurrageRadarStatusReturned => 'Returned';
  @override String get demurrageRadarButtonLabel => 'Demurrage Radar (TR-02)';

  // Screen Photos Localization Fixes
  @override String get smartEmailCheckInboxBtn => 'Check Inbox Now';
  @override String get smartEmailSettingsBtn => 'Email Settings';
  @override String get invoiceBlMatchTabInspect => '⚡ Inspect & Match Invoice and B/L';
  @override String get invoiceBlMatchTabHistory => '📋 Match Sessions History';
  @override String get invoiceBlMatchNewSessionBtn => 'Start New Match Session';
  @override String get cooSaveDraftSessionBtn => 'Save Session Draft';
  @override String get cooChinaRecommendationAlert => 'Country of origin is PR China — China Certificate of Origin (CCPIT) selected automatically.';
  @override String get cooChinaGeneralExemptionNote => 'Origin: China - Subject to standard Egyptian customs tariff import duty and 14% VAT.';
  @override String get cooEuRecommendationAlert => 'Country of origin is within EU-27 — EUR.1 Movement Certificate selected automatically for full preferential customs exemption.';
  @override String get cooAgadirGaftaRecommendationAlert => 'Country of origin is a member of both Agadir & GAFTA — Please select certificate type manually.';

  // ── In-app updates (app_update) ──
  @override String updateAvailableBanner(String version) => 'A new system update is available: v$version';
  @override String updateMandatoryBanner(String version) => 'Mandatory update required: v$version. Install it to continue working.';
  @override String get updateWhatsNew => "What's new in this version";
  @override String updateSize(String mb) => '$mb MB';
  @override String get updateInstallNow => 'Install now';
  @override String get updateRemindLater => 'Remind me later';
  @override String updateDownloading(String done, String total) => 'Downloading… $done of $total MB';
  @override String get updateVerifying => "Verifying the update's digital fingerprint…";
  @override String get updateBackingUp => 'Backing up the database…';
  @override String get updateInstalling => 'Installing the update. The app will restart automatically';
  @override String get updateCancel => 'Cancel download';
  @override String updateSucceeded(String version) => 'The system was updated to v$version successfully';
  @override String get updateFailed => 'The update failed';
  @override String get updateRollback => 'Roll back to the previous version';
  @override String updateRollbackWarning(String backupTime) => 'The database will be restored from the backup taken at $backupTime. All data entered after that time will be permanently lost.';
  @override String get updateFromFile => 'Update from file (USB)';
  @override String updateCheckOffline(String lastChecked) => 'Could not reach the update server. Last successful check: $lastChecked';
  @override String get updateDevModeDisabled => 'Automatic updates are not available in development mode';
  @override String updateDialogTitle(String version) => 'Update the system to v$version';
  @override String get updateDownloadNow => 'Download update';
  @override String get updateReadyToInstall => 'The update is downloaded, verified and ready to install. The database is backed up before installing.';
  @override String get updateMandatoryNotice => "This update is mandatory (a security fix or a database change) and can't be postponed.";
  @override String get updateAdminOnlyNotice => 'Only a system administrator can install updates. Please contact your administrator.';
  @override String get updateSignOut => 'Sign out';
  @override String get updateViewDetails => 'View details';
  @override String get updateRestartingHint => "Don't turn off the computer while installing.";
  @override String get updateRollbackTitle => 'Confirm update rollback';
  @override String get updateRollbackConfirmCheck => 'I understand that data entered after the backup will be lost';
  @override String get updateRollbackConfirmBtn => 'Confirm rollback';
  @override String get updateRollbackNoBackup => 'No pre-update backup is available to roll back to';
  @override String get updatePickManifest => 'Choose the release file (manifest.json)';
  @override String get updatePickInstaller => 'Choose the installer file (.exe)';
  @override String get updateStagedFromFile => 'The update files were verified and are ready to install';
  @override String get updateSectionTitle => 'Application updates';
  @override String get updateCheckNow => 'Check for updates';
  @override String updateUpToDate(String version) => 'The system is up to date (v$version)';
  @override String get updateInvalidSignature => 'The release file on the server was rejected: invalid signature';
  @override String get updateNeverChecked => 'Not checked yet';
  @override String get updateRetry => 'Retry';
  @override String get updateClose => 'Close';
  @override String get updateFailedRollbackHint => 'The post-update check did not pass. An administrator can roll back to the previous version.';
  @override String updateCurrentVersion(String version) => 'Current version: $version';
  @override String get updateNoPermission => 'You do not have permission to install system updates (administrator required)';
  @override String updateRollbackSucceeded(String version) => 'Rolled back to v$version and restored the database from the backup';
  @override String get updateRollbackFailed => 'The rollback failed';
}





















