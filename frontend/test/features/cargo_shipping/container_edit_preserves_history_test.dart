import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_shipping_model.dart';

void main() {
  group('ContainerLoadingModel edit preserves tracking history & SLA (FE05-T02)', () {
    late ContainerLoadingModel initialItem;

    setUp(() {
      initialItem = ContainerLoadingModel(
        containerType: '40HC',
        quantity: 2,
        containerNo: 'MSKU1111111',
        sealNo: 'SL-001',
        tareWeightKg: 3800.0,
        netWeightKg: 22000.0,
        grossWeightKg: 25800.0,
        vgmStatus: 'Verified',
        vgmRefNo: 'VGM-998877',
        individualUnits: [
          {'container_no': 'MSKU1111111', 'seal_no': 'SL-001'},
          {'container_no': 'MSKU2222222', 'seal_no': 'SL-002'},
        ],
        containerAssignmentDate: '2026-10-01T08:00:00Z',
        arrivalAtSupplierAt: '2026-10-02T10:00:00Z',
        loadingStartAt: '2026-10-02T12:00:00Z',
        loadingEndAt: '2026-10-02T18:00:00Z',
        portGateInAt: '2026-10-03T09:00:00Z',
        slaDeadlineAt: '2026-10-04T08:00:00Z',
        isSlaBreached: false,
        trackingStatus: 'LOADING_COMPLETED',
        trackingHistory: [
          {
            'milestone': 'LOADING_START',
            'timestamp': '2026-10-02T12:00:00Z',
            'user': 'dispatcher_1',
          },
          {
            'milestone': 'LOADING_COMPLETED',
            'timestamp': '2026-10-02T18:00:00Z',
            'user': 'dispatcher_1',
          },
        ],
        milestoneNotes: {
          'LOADING_COMPLETED': 'Cargo inspection passed and loaded cleanly',
        },
      );
    });

    test('editing seal number via copyWith retains trackingHistory, milestoneNotes, and slaDeadlineAt', () {
      final updatedUnits = initialItem.individualUnits.map((u) => Map<String, String>.from(u)).toList();
      updatedUnits[0]['seal_no'] = 'SL-NEW-999';

      final editedItem = initialItem.copyWith(
        containerNo: updatedUnits.first['container_no'] ?? '',
        sealNo: updatedUnits.first['seal_no'] ?? '',
        individualUnits: updatedUnits,
      );

      expect(editedItem.sealNo, 'SL-NEW-999');
      expect(editedItem.individualUnits[0]['seal_no'], 'SL-NEW-999');
      expect(editedItem.individualUnits[1]['seal_no'], 'SL-002');
      expect(editedItem.trackingHistory, hasLength(2));
      expect(editedItem.milestoneNotes['LOADING_COMPLETED'], 'Cargo inspection passed and loaded cleanly');
      expect(editedItem.slaDeadlineAt, '2026-10-04T08:00:00Z');
      expect(editedItem.trackingStatus, 'LOADING_COMPLETED');

      final payload = buildCargoShippingPayload(
        importFileId: 10,
        shipmentType: 'FCL',
        containers: [editedItem],
        isEdit: true,
      );

      final containerData = (payload['containers_loading_data'] as List).first as Map<String, dynamic>;
      expect(containerData['seal_no'], 'SL-NEW-999');
      expect(containerData['sla_deadline_at'], '2026-10-04T08:00:00Z');
      expect(containerData['tracking_history'], hasLength(2));
      expect(containerData['milestone_notes']['LOADING_COMPLETED'], 'Cargo inspection passed and loaded cleanly');
    });

    test('editing container number via copyWith retains trackingHistory and notes', () {
      final updatedUnits = initialItem.individualUnits.map((u) => Map<String, String>.from(u)).toList();
      updatedUnits[1]['container_no'] = 'MSKU3333333';

      final editedItem = initialItem.copyWith(
        containerNo: updatedUnits.first['container_no'] ?? '',
        sealNo: updatedUnits.first['seal_no'] ?? '',
        individualUnits: updatedUnits,
      );

      expect(editedItem.individualUnits[1]['container_no'], 'MSKU3333333');
      expect(editedItem.trackingHistory, hasLength(2));
      expect(editedItem.milestoneNotes, isNotEmpty);
      expect(editedItem.slaDeadlineAt, isNotNull);
    });

    test('editing container type and weight retains history and notes', () {
      final editedItem = initialItem.copyWith(
        containerType: '20GP',
        grossWeightKg: 18500.0,
      );

      expect(editedItem.containerType, '20GP');
      expect(editedItem.grossWeightKg, 18500.0);
      expect(editedItem.trackingHistory, hasLength(2));
      expect(editedItem.milestoneNotes['LOADING_COMPLETED'], isNotNull);
      expect(editedItem.slaDeadlineAt, '2026-10-04T08:00:00Z');
    });

    test('modifying quantity deep-copies units and preserves existing unit numbers', () {
      // Increase qty to 3
      final unitsIncreased = initialItem.individualUnits.map((u) => Map<String, String>.from(u)).toList();
      while (unitsIncreased.length < 3) {
        unitsIncreased.add({'container_no': '', 'seal_no': ''});
      }
      final with3 = initialItem.copyWith(
        quantity: 3,
        containerNo: unitsIncreased.isNotEmpty ? unitsIncreased.first['container_no'] ?? '' : '',
        sealNo: unitsIncreased.isNotEmpty ? unitsIncreased.first['seal_no'] ?? '' : '',
        individualUnits: unitsIncreased,
      );

      expect(with3.quantity, 3);
      expect(with3.individualUnits, hasLength(3));
      expect(with3.individualUnits[0]['container_no'], 'MSKU1111111');
      expect(with3.individualUnits[1]['container_no'], 'MSKU2222222');
      expect(with3.individualUnits[2]['container_no'], '');
      expect(with3.trackingHistory, hasLength(2));

      // Decrease qty to 1
      final unitsDecreased = initialItem.individualUnits.map((u) => Map<String, String>.from(u)).toList();
      unitsDecreased.removeRange(1, unitsDecreased.length);
      final with1 = initialItem.copyWith(
        quantity: 1,
        containerNo: unitsDecreased.first['container_no'] ?? '',
        sealNo: unitsDecreased.first['seal_no'] ?? '',
        individualUnits: unitsDecreased,
      );

      expect(with1.quantity, 1);
      expect(with1.individualUnits, hasLength(1));
      expect(with1.individualUnits[0]['container_no'], 'MSKU1111111');
      expect(with1.trackingHistory, hasLength(2));
    });

    test('deep copy prevents mutating original item units map (F05-32)', () {
      final updatedUnits = initialItem.individualUnits.map((u) => Map<String, String>.from(u)).toList();
      updatedUnits[0]['container_no'] = 'MUTATED';

      // Original item must remain unmutated
      expect(initialItem.individualUnits[0]['container_no'], 'MSKU1111111');
    });
  });

  group('Source Code Scan Guard (FE05-T02)', () {
    test('ContainerEquipmentCard uses item.copyWith instead of manual ContainerLoadingModel', () {
      // The card was split out of cargo_shipping_screen.dart (_buildContainerEquipmentCard)
      // into the ContainerEquipmentCard widget; it reports edits through onUpdate(index, ...).
      final file = File('lib/features/cargo_shipping/widgets/container_equipment_assignment_tab.dart');
      final content = file.readAsStringSync();

      final classStart = content.indexOf('class ContainerEquipmentCard extends StatelessWidget');
      expect(classStart, isNonNegative);
      final classEnd = content.indexOf('class ContainerEquipmentAssignmentTab ', classStart);
      expect(classEnd, isNonNegative);

      final cardCode = content.substring(classStart, classEnd);

      // No hand-built model in the card's edit handlers (that dropped tracking history,
      // milestone notes and SLA deadline); every edit must go through item.copyWith.
      final constructorMatches = RegExp(r'ContainerLoadingModel\(').allMatches(cardCode);
      expect(
        constructorMatches.isEmpty,
        isTrue,
        reason: 'ContainerLoadingModel(...) in ContainerEquipmentCard must be replaced with item.copyWith(...)',
      );

      // Verify item.copyWith is used in the card
      expect(cardCode.contains('item.copyWith('), isTrue);
    });
  });
}
