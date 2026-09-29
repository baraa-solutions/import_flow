import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/operational_dashboard/services/operational_dashboard_export_service.dart';

void main() {
  group('OperationalDashboardExportService Unit Tests (Task C)', () {
    final sampleShipments = [
      ImportFileModel(
        importFileId: 101,
        importFileCode: 'IMP-2026-0101',
        customFileNumber: 'CUST-8899',
        companyName: 'Al-Amal Trading Co',
        supplierName: 'Shenzhen Tech Ltd',
        brokerName: 'Al-Ameen Customs Office',
        poNumber: 'PO-99123',
        priority: 'High',
        // Shape written by modules/common/file_tracking.set_file_tracking (single-language
        // storage): step/phase codes + English legacy text (current_module = step,
        // current_stage = phase title).
        currentModule: 'STEP_17 Duty Payment',
        currentStage: 'Phase 5: Port Operations & Clearance',
        currentStepCode: 'STEP_17',
        currentPhaseId: 5,
        currentStageCode: 'PHASE_5',
        progressPercent: 65.0,
        nextAction: 'Customs valuation, inspection & sampling',
        nextActionCode: 'NA_VALUATION_INSPECTION_SAMPLING',
        status: 'Open',
        isActive: true,
        createdAt: '2026-08-01T10:00:00Z',
        updatedAt: '2026-08-05T12:00:00Z',
      ),
      ImportFileModel(
        importFileId: 102,
        importFileCode: 'IMP-2026-0102',
        customFileNumber: null,
        companyName: 'Nile Logistics Ltd',
        supplierName: 'Bavaria Motors AG',
        brokerName: null,
        poNumber: null,
        priority: 'Critical',
        currentModule: 'Arrival Notice',
        currentStage: 'Vessel Berthed',
        progressPercent: 40.0,
        nextAction: '',
        status: 'Closed',
        isActive: false,
        createdAt: '2026-07-15T08:00:00Z',
        updatedAt: '2026-08-02T16:00:00Z',
      ),
    ];

    test('OperationalDashboardReportRow maps correctly in Arabic mode with localized priorities and statuses', () {
      const lAr = AppLocalizationsAr();

      final row1 = OperationalDashboardReportRow.fromImportFile(sampleShipments[0], lAr, true);
      expect(row1.shipmentName, 'CUST-8899');
      expect(row1.shipmentTitle, 'CUST-8899 (IMP-2026-0101)');
      expect(row1.importFileCode, 'IMP-2026-0101');
      expect(row1.customFileNumber, 'CUST-8899');
      expect(row1.companyName, 'Al-Amal Trading Co');
      expect(row1.supplierName, 'Shenzhen Tech Ltd');
      expect(row1.priority, lAr.priorityHigh);
      // Coded rows: phase title from the backend 6-phase catalog (SystemMessageRenderer.phaseTitle).
      expect(row1.currentPhase, 'المرحلة الخامسة: عمليات الميناء والتخليص الجمركي');
      expect(row1.operationalStep, 'سداد الضرائب والرسوم الجمركية');
      expect(row1.brokerName, 'Al-Ameen Customs Office');
      expect(row1.poNumber, 'PO-99123');
      expect(row1.progressPercent, 65.0);
      // Coded next action rendered from the system-message catalog in the UI language.
      expect(row1.nextAction, 'التثمين الجمركي والكشف وسحب العينات');
      expect(row1.status, lAr.statusOpen);

      final row2 = OperationalDashboardReportRow.fromImportFile(sampleShipments[1], lAr, true);
      expect(row2.shipmentName, 'IMP-2026-0102');
      expect(row2.shipmentTitle, 'IMP-2026-0102');
      expect(row2.customFileNumber, '-');
      expect(row2.brokerName, lAr.unassigned);
      expect(row2.poNumber, '-');
      expect(row2.priority, lAr.priorityCritical);
      expect(row2.nextAction, '-');
      expect(row2.status, lAr.statusClosed);
    });

    test('OperationalDashboardReportRow maps correctly in English mode with localized priorities and statuses', () {
      const lEn = AppLocalizationsEn();

      final row1 = OperationalDashboardReportRow.fromImportFile(sampleShipments[0], lEn, false);
      expect(row1.shipmentName, 'CUST-8899');
      expect(row1.shipmentTitle, 'CUST-8899 (IMP-2026-0101)');
      expect(row1.priority, 'High');
      expect(row1.currentPhase, '5. Port Operations & Clearance');
      expect(row1.operationalStep, 'Duty Payment');
      expect(row1.nextAction, 'Customs valuation, inspection & sampling');
      expect(row1.status, 'Open');
      expect(row1.brokerName, 'Al-Ameen Customs Office');

      final row2 = OperationalDashboardReportRow.fromImportFile(sampleShipments[1], lEn, false);
      expect(row2.shipmentName, 'IMP-2026-0102');
      expect(row2.shipmentTitle, 'IMP-2026-0102');
      expect(row2.priority, 'Critical');
      expect(row2.status, 'Closed');
      expect(row2.brokerName, lEn.unassigned);
      expect(row2.poNumber, '-');
    });

    test('TSV export formatting generates tab-delimited records with UTF-8 BOM', () {
      const lAr = AppLocalizationsAr();
      final buffer = StringBuffer();
      buffer.write('\uFEFF');

      final headers = [
        lAr.operationalTsvHeaderShipmentName,
        lAr.operationalTsvHeaderFileCode,
        lAr.operationalTsvHeaderImporter,
        lAr.operationalTsvHeaderSupplier,
        lAr.operationalTsvHeaderPriority,
        lAr.operationalTsvHeaderCurrentPhase,
        lAr.operationalTsvHeaderOperationalStep,
        lAr.operationalTsvHeaderBroker,
        lAr.operationalTsvHeaderPoNumber,
        lAr.operationalTsvHeaderProgress,
        lAr.operationalTsvHeaderNextAction,
        lAr.operationalTsvHeaderStatus,
      ];
      buffer.writeln(headers.join('\t'));

      for (final s in sampleShipments) {
        final row = OperationalDashboardReportRow.fromImportFile(s, lAr, true);
        buffer.writeln([
          row.shipmentName,
          row.importFileCode,
          row.companyName,
          row.supplierName,
          row.priority,
          row.currentPhase,
          row.operationalStep,
          row.brokerName,
          row.poNumber,
          '${row.progressPercent.toStringAsFixed(0)}%',
          row.nextAction,
          row.status,
        ].join('\t'));
      }

      final content = buffer.toString();
      expect(content.startsWith('\uFEFF'), isTrue, reason: 'Must contain UTF-8 BOM');
      expect(content.contains('\t'), isTrue, reason: 'Must be tab-delimited');
      final lines = const LineSplitter().convert(content);
      expect(lines.length, 3); // 1 header + 2 rows
      expect(lines[0].split('\t').length, 12);
      expect(lines[1].split('\t').length, 12);
      expect(lines[2].split('\t').length, 12);
    });

    test('CSV export formatting properly escapes quotes and commas with UTF-8 BOM', () {
      const lAr = AppLocalizationsAr();
      final buffer = StringBuffer();
      buffer.write('\uFEFF');

      String escapeCsv(String field) {
        if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }

      final headers = [
        escapeCsv(lAr.operationalTsvHeaderShipmentName),
        escapeCsv(lAr.operationalTsvHeaderFileCode),
        escapeCsv(lAr.operationalTsvHeaderImporter),
        escapeCsv(lAr.operationalTsvHeaderSupplier),
        escapeCsv(lAr.operationalTsvHeaderPriority),
        escapeCsv(lAr.operationalTsvHeaderCurrentPhase),
        escapeCsv(lAr.operationalTsvHeaderOperationalStep),
        escapeCsv(lAr.operationalTsvHeaderBroker),
        escapeCsv(lAr.operationalTsvHeaderPoNumber),
        escapeCsv(lAr.operationalTsvHeaderProgress),
        escapeCsv(lAr.operationalTsvHeaderNextAction),
        escapeCsv(lAr.operationalTsvHeaderStatus),
      ];
      buffer.writeln(headers.join(','));

      for (final s in sampleShipments) {
        final row = OperationalDashboardReportRow.fromImportFile(s, lAr, true);
        buffer.writeln([
          escapeCsv(row.shipmentName),
          escapeCsv(row.importFileCode),
          escapeCsv(row.companyName),
          escapeCsv(row.supplierName),
          escapeCsv(row.priority),
          escapeCsv(row.currentPhase),
          escapeCsv(row.operationalStep),
          escapeCsv(row.brokerName),
          escapeCsv(row.poNumber),
          '${row.progressPercent.toStringAsFixed(0)}%',
          escapeCsv(row.nextAction),
          escapeCsv(row.status),
        ].join(','));
      }

      final content = buffer.toString();
      expect(content.startsWith('\uFEFF'), isTrue);
      final lines = const LineSplitter().convert(content);
      expect(lines.length, 3);
      expect(lines[1], contains('IMP-2026-0101'));
      expect(lines[2], contains('IMP-2026-0102'));
    });

    test('Dossier plain-text clipboard generation contains all required sections', () {
      const lAr = AppLocalizationsAr();
      final buffer = StringBuffer();

      buffer.writeln('📋 ${lAr.operationalReportTitle}');
      buffer.writeln('═══════════════════════════════════════════════');
      buffer.writeln('🔍 ${lAr.operationalDossierCriteria}All');
      buffer.writeln('📊 ${lAr.matchingShipments}: ${sampleShipments.length} ${lAr.shipmentCountUnit}');
      buffer.writeln('───────────────────────────────────────────────');

      for (int i = 0; i < sampleShipments.length; i++) {
        final r = OperationalDashboardReportRow.fromImportFile(sampleShipments[i], lAr, true);
        buffer.writeln('[${i + 1}] ${r.shipmentTitle}');
        buffer.writeln('    - ${lAr.operationalTsvHeaderImporter}: ${r.companyName} | ${lAr.operationalTsvHeaderSupplier}: ${r.supplierName}');
        buffer.writeln('    - ${lAr.operationalTsvHeaderPriority}: ${r.priority} | ${lAr.operationalTsvHeaderProgress}: ${r.progressPercent.toStringAsFixed(0)}%');
        buffer.writeln('    - ${lAr.operationalTsvHeaderCurrentPhase}: ${r.currentPhase} (${r.operationalStep})');
        buffer.writeln('    - ${lAr.operationalTsvHeaderBroker}: ${r.brokerName} | ${lAr.operationalTsvHeaderPoNumber}: ${r.poNumber}');
        buffer.writeln('    - ${lAr.operationalTsvHeaderNextAction}: ${r.nextAction}');
        buffer.writeln('');
      }

      final dossier = buffer.toString();
      expect(dossier, contains('📋'));
      expect(dossier, contains('IMP-2026-0101'));
      expect(dossier, contains('IMP-2026-0102'));
      expect(dossier, contains('Al-Amal Trading Co'));
      expect(dossier, contains('Shenzhen Tech Ltd'));
      expect(dossier, contains(lAr.priorityHigh));
      expect(dossier, contains(lAr.priorityCritical));
    });
  });
}
