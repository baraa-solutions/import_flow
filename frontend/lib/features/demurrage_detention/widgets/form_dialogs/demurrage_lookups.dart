/// Static lookup lists shared by the demurrage forms and the simulator.
class DemurrageLookups {
  DemurrageLookups._();

  static const List<String> carriers = [
    'MSC',
    'Maersk',
    'CMA CGM',
    'COSCO',
    'Hapag-Lloyd',
    'ONE',
    'Evergreen',
    'Yang Ming',
  ];

  static const List<String> containerTypes = [
    '20ft Standard',
    '40ft Standard',
    '40ft High Cube',
    '20ft Reefer',
    '40ft Reefer',
    '45ft High Cube',
  ];

  static const List<String> ports = [
    'Alexandria Port',
    'Dekheila Port',
    'Damietta Port',
    'Port Said East',
    'Port Said West',
    'Sokhna Port',
    'Adabiya Port',
    'Cairo Dry Port (6th of October)',
  ];

  static const Map<String, List<String>> terminalsByPort = {
    'Alexandria Port': [
      'Alexandria Container Terminal (ACCHCO)',
      'Alexandria Old Terminal',
      'Tahya Misr Multipurpose Terminal',
    ],
    'Dekheila Port': [
      'Dekheila Container Terminal (ACCHCO)',
      'Dekheila Berth 96 Terminal',
    ],
    'Damietta Port': [
      'Damietta Container Handling (DCHC)',
      'Damietta Alliance Terminal',
    ],
    'Port Said East': [
      'Suez Canal Container Terminal (SCCT - APMT)',
    ],
    'Port Said West': [
      'Port Said Container Handling (PSCCHC)',
    ],
    'Sokhna Port': [
      'DP World Sokhna Terminal',
      'Basin 2 Container Terminal',
    ],
    'Adabiya Port': [
      'Adabiya Port Terminal',
    ],
    'Cairo Dry Port (6th of October)': [
      'October Dry Port (ODP)',
    ],
  };

  static const List<String> ancillaryFeeTypes = [
    'كشف وفحص بالأشعة',
    'وزن ميزان بسكول',
    'سيل جمركي ملاحي',
    'حراسة ومراقبة ساحة',
    'تطهير وتبخير',
    'أذونات ونولون إضافي',
  ];
}

String fmtDemurrageDate(DateTime dt) => dt.toIso8601String().split('T').first;
