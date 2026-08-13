/// Seed catalogue (JSON maps). Wire shape matches `b2c/lib/models` — keep in sync.
library;

/// Static residence photo served at `/v1/static/residences/<file>`.
String staticResidencePhoto(String filename) =>
    '/v1/static/residences/$filename';

String _placeholderImage(String seed, int w, int h) =>
    'https://picsum.photos/seed/$seed/$w/$h';

Map<String, dynamic> _media({
  required String id,
  required String type,
  required String url,
  int sortOrder = 0,
  bool isCover = false,
}) => {
  'id': id,
  'type': type,
  'url': url,
  'sortOrder': sortOrder,
  'isCover': isCover,
};

class _LayoutSpec {
  const _LayoutSpec({this.rooms, required this.area, required this.label});

  final int? rooms;
  final double area;
  final String label;
}

const _apartmentLayouts = [
  _LayoutSpec(rooms: 1, area: 44, label: '1-room'),
  _LayoutSpec(rooms: 2, area: 63, label: '2-room'),
  _LayoutSpec(rooms: 3, area: 86, label: '3-room'),
  _LayoutSpec(rooms: 4, area: 108, label: '4-room'),
];

const _officeLayouts = [
  _LayoutSpec(area: 42, label: 'open-plan'),
  _LayoutSpec(area: 68, label: 'cabinet'),
  _LayoutSpec(area: 95, label: 'corner-suite'),
];

Map<String, dynamic> _unit({
  required String id,
  required String buildingId,
  required String number,
  required String kind,
  required String dealType,
  required String status,
  required int floor,
  required bool isOffplan,
  required double areaTotal,
  int? rooms,
  String? layout,
  double? price,
  double? rentMonthly,
  required int planColumn,
  required int planRow,
  String? photo,
}) {
  final isRent = dealType == 'rent';
  return {
    'id': id,
    'buildingId': buildingId,
    'number': number,
    'kind': kind,
    'dealType': dealType,
    'status': status,
    'floor': floor,
    'isOffplan': isOffplan,
    'areaTotal': areaTotal,
    'areaLiving': areaTotal * 0.86,
    'rooms': rooms,
    'layout': layout,
    'price': price,
    'priceM2': price == null ? null : price / areaTotal,
    'rentMonthly': rentMonthly,
    'rentM2': rentMonthly == null ? null : rentMonthly / areaTotal,
    'minLeaseMonths': isRent ? 12 : null,
    'finishing': isOffplan ? 'Pre-finish' : 'Turnkey',
    'view': const ['City', 'Courtyard', 'Park', 'Street'][planColumn % 4],
    'planColumn': planColumn,
    'planRow': planRow,
    'version': 1,
    'media': [
      _media(
        id: 'med-$id-cover',
        type: 'photo',
        url: photo ?? staticResidencePhoto('nestone.png'),
        isCover: true,
      ),
    ],
  };
}

List<Map<String, dynamic>> _apartmentUnits({
  required String buildingId,
  required int floors,
  required int perFloor,
  required bool offplan,
  required double basePrice,
  required double baseRent,
  bool mixedRent = true,
  String? unitPhoto,
}) {
  final units = <Map<String, dynamic>>[];
  var i = 0;
  const statuses = ['available', 'reserved', 'sold', 'available'];
  for (var floor = 1; floor <= floors; floor++) {
    for (var col = 0; col < perFloor; col++) {
      final layout = _apartmentLayouts[i % _apartmentLayouts.length];
      final isRent = mixedRent && col == perFloor - 1;
      final rooms = layout.rooms!;
      units.add(
        _unit(
          id: '$buildingId-u$floor$col',
          buildingId: buildingId,
          number: '$floor${(col + 1).toString().padLeft(2, '0')}',
          kind: 'apartment',
          dealType: isRent ? 'rent' : 'sale',
          status: statuses[i % statuses.length],
          floor: floor,
          isOffplan: offplan,
          areaTotal: layout.area,
          rooms: rooms,
          layout: layout.label,
          price: isRent ? null : basePrice + (rooms * 12000),
          rentMonthly: isRent ? baseRent + (rooms * 85) : null,
          planColumn: col,
          planRow: floor - 1,
          photo: unitPhoto,
        ),
      );
      i++;
    }
  }
  return units;
}

List<Map<String, dynamic>> _officeUnits({
  required String buildingId,
  required int floors,
  required int perFloor,
  required double baseRent,
}) {
  final units = <Map<String, dynamic>>[];
  var i = 0;
  const statuses = ['available', 'available', 'reserved', 'rented'];
  for (var floor = 1; floor <= floors; floor++) {
    for (var col = 0; col < perFloor; col++) {
      final layout = _officeLayouts[i % _officeLayouts.length];
      units.add(
        _unit(
          id: '$buildingId-u$floor$col',
          buildingId: buildingId,
          number: 'O$floor${(col + 1).toString().padLeft(2, '0')}',
          kind: 'office',
          dealType: 'rent',
          status: statuses[i % statuses.length],
          floor: floor,
          isOffplan: false,
          areaTotal: layout.area,
          layout: layout.label,
          rentMonthly: baseRent + (layout.area * 4.2),
          planColumn: col,
          planRow: floor - 1,
        ),
      );
      i++;
    }
  }
  return units;
}

Map<String, dynamic> _summarizeProject(Map<String, dynamic> project) {
  final buildings = (project['buildings'] as List).cast<Map<String, dynamic>>();
  final allUnits = [
    for (final b in buildings)
      ...(b['units'] as List).cast<Map<String, dynamic>>(),
  ];
  final saleUnits = allUnits.where((u) => u['dealType'] == 'sale').toList();
  final rentUnits = allUnits.where((u) => u['dealType'] == 'rent').toList();

  double? minOf(Iterable<Map<String, dynamic>> units, String key) {
    final vals = units.map((u) => u[key] as double?).whereType<double>();
    return vals.isEmpty ? null : vals.reduce((a, b) => a < b ? a : b);
  }

  double? maxOf(Iterable<Map<String, dynamic>> units, String key) {
    final vals = units.map((u) => u[key] as double?).whereType<double>();
    return vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b);
  }

  project['priceMin'] = minOf(saleUnits, 'price');
  project['priceMax'] = maxOf(saleUnits, 'price');
  project['rentMin'] = minOf(rentUnits, 'rentMonthly');
  project['rentMax'] = maxOf(rentUnits, 'rentMonthly');
  project['availableUnits'] = allUnits
      .where((u) => u['status'] == 'available')
      .length;
  project['totalUnits'] = allUnits.length;
  return project;
}

/// NestOne + Hills Blue — real catalogue entries with bundled photos.
List<Map<String, dynamic>> buildProjectsSeed() => [
  _buildNestOne(),
  _buildHillsBlue(),
];

Map<String, dynamic> _buildNestOne() {
  final developer = {
    'id': 'dev-nestone',
    'name': 'NestOne Development',
    'logoUrl': null,
    'rating': 4.8,
    'projectsCount': 1,
    'phone': '+998 78 150 10 10',
    'agentName': 'Madina Rakhimova',
    'agentPhone': '+998 90 150 10 10',
    'agentAvatarUrl': _placeholderImage('agent-nestone', 200, 200),
  };

  const livingId = 'bld-nestone-living';
  const officeId = 'bld-nestone-office';

  final livingUnits = _apartmentUnits(
    buildingId: livingId,
    floors: 10,
    perFloor: 4,
    offplan: false,
    basePrice: 52000,
    baseRent: 480,
    mixedRent: true,
    unitPhoto: staticResidencePhoto('nestone.png'),
  );
  final officeUnits = _officeUnits(
    buildingId: officeId,
    floors: 8,
    perFloor: 3,
    baseRent: 950,
  );

  return _summarizeProject({
    'id': 'prj-nestone',
    'name': 'NestOne',
    'type': 'residential_complex',
    'status': 'ready',
    'district': 'Shayxontohur',
    'address': 'Amir Temur shoh ko\'chasi, Shayxontohur, Tashkent',
    'lat': 41.31215655652716,
    'lng': 69.25275117116448,
    'developer': developer,
    'description':
        'NestOne is a completed mixed-use complex in Shayxontohur: sale and rent '
        'apartments in a 10-storey living tower plus Class-A offices with live '
        'availability on an interactive floor grid. Underground parking, gym, and concierge.',
    'amenities': const [
      'Underground parking',
      'Gym',
      'Concierge',
      'Coworking lounge',
      'Landscaped courtyard',
      '24/7 security',
      'High-speed elevators',
    ],
    'tags': const [
      'Premium',
      'Ready to move',
      'Apartments',
      'Offices',
      'Rent',
      'Installments',
    ],
    'constructionProgress': 100,
    'plannedProgress': 100,
    'completionDate': '2024-12-01T00:00:00.000Z',
    'rating': 4.8,
    'isFeatured': true,
    'isPublished': true,
    'moderationStatus': 'approved',
    'moderationNote': null,
    'gallery': [
      _media(
        id: 'med-nestone-cover',
        type: 'photo',
        url: staticResidencePhoto('nestone.png'),
        isCover: true,
      ),
    ],
    'offers': [
      {
        'id': 'off-nestone-installment',
        'projectId': 'prj-nestone',
        'type': 'installment',
        'title': 'Flexible installment plan',
        'description': '25% down payment, balance in equal monthly payments.',
        'startsAt': null,
        'endsAt': null,
        'downPaymentPercent': 0.25,
        'termMonths': 36,
        'interestRate': 0.0,
      },
    ],
    'buildings': [
      {
        'id': livingId,
        'projectId': 'prj-nestone',
        'name': 'Living Tower',
        'floors': 10,
        'constructionProgress': 100,
        'completionDate': '2024-12-01T00:00:00.000Z',
        'units': livingUnits,
      },
      {
        'id': officeId,
        'projectId': 'prj-nestone',
        'name': 'Office Wing',
        'floors': 8,
        'constructionProgress': 100,
        'completionDate': '2024-12-01T00:00:00.000Z',
        'units': officeUnits,
      },
    ],
  });
}

Map<String, dynamic> _buildHillsBlue() {
  final developer = {
    'id': 'dev-hills-group',
    'name': 'Hills Group',
    'logoUrl': null,
    'rating': 4.9,
    'projectsCount': 1,
    'phone': '+998 78 120 64 64',
    'agentName': 'Dilshod Karimov',
    'agentPhone': '+998 90 120 64 64',
    'agentAvatarUrl': _placeholderImage('agent-hills', 200, 200),
  };

  const tower1Id = 'bld-hills-t1';
  const tower2Id = 'bld-hills-t2';
  final hillsPhoto = staticResidencePhoto('hillsblue.png');

  final tower1Units = _apartmentUnits(
    buildingId: tower1Id,
    floors: 12,
    perFloor: 4,
    offplan: true,
    basePrice: 46000,
    baseRent: 520,
    mixedRent: false,
    unitPhoto: hillsPhoto,
  );
  final tower2Units = _apartmentUnits(
    buildingId: tower2Id,
    floors: 12,
    perFloor: 4,
    offplan: true,
    basePrice: 48000,
    baseRent: 540,
    mixedRent: false,
    unitPhoto: hillsPhoto,
  );

  return _summarizeProject({
    'id': 'prj-hills-blue',
    'name': 'Hills Blue',
    'type': 'residential_complex',
    'status': 'under_construction',
    'district': 'Yunusabad',
    'address': 'Chingiz Aitmatov ko\'chasi 37B, Badamzar, Tashkent',
    'lat': 41.3528,
    'lng': 69.3012,
    'developer': developer,
    'description':
        'Premium residential complex by Hills Group in Yunusabad\'s Badamzar '
        'district: twin 22-storey towers with asymmetric facades, 3.5 m ceiling '
        'heights, underground parking and white-box handover. Completion Q1 2027.',
    'amenities': const [
      'Underground parking',
      'Landscaped courtyard',
      'Gym',
      '24/7 security',
      'High-speed elevators',
      'Concierge',
      'Smart home systems',
    ],
    'tags': const ['Premium', 'New build', 'Installments'],
    'constructionProgress': 38,
    'plannedProgress': 42,
    'completionDate': '2027-03-01T00:00:00.000Z',
    'rating': 4.9,
    'isFeatured': true,
    'isPublished': true,
    'moderationStatus': 'approved',
    'moderationNote': null,
    'gallery': [
      _media(
        id: 'med-hills-cover',
        type: 'photo',
        url: staticResidencePhoto('hillsblue.png'),
        isCover: true,
      ),
      _media(
        id: 'med-hills-banner',
        type: 'photo',
        url: staticResidencePhoto('hills-blue-banner.webp'),
        sortOrder: 1,
      ),
    ],
    'offers': [
      {
        'id': 'off-hills-installment',
        'projectId': 'prj-hills-blue',
        'type': 'installment',
        'title': 'Flexible installment until handover',
        'description': '30% down payment, balance split monthly until Q1 2027.',
        'startsAt': null,
        'endsAt': '2027-01-01T00:00:00.000Z',
        'downPaymentPercent': 0.3,
        'termMonths': 24,
        'interestRate': 0.0,
      },
    ],
    'buildings': [
      {
        'id': tower1Id,
        'projectId': 'prj-hills-blue',
        'name': 'Tower 1',
        'floors': 22,
        'constructionProgress': 42,
        'completionDate': '2027-03-01T00:00:00.000Z',
        'units': tower1Units,
      },
      {
        'id': tower2Id,
        'projectId': 'prj-hills-blue',
        'name': 'Tower 2',
        'floors': 22,
        'constructionProgress': 35,
        'completionDate': '2027-03-01T00:00:00.000Z',
        'units': tower2Units,
      },
    ],
  });
}
