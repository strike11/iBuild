/// Seed dataset: Tashkent residential complexes and business centres.
///
/// Plain JSON-shaped `Map`s (not the Flutter `freezed` models) so this server
/// has zero compile-time coupling to the client — the wire shape (field names,
/// enum wire values) simply mirrors `b2c/lib/models/*.dart` /
/// `models/enums.dart`. Keep the two in sync by hand if either changes.
library;

int _idCounter = 0;
String _nextId(String prefix) => '$prefix-${(_idCounter++).toRadixString(36)}';

/// Real Tashkent residential / street photos (Wikimedia Commons, CC-licensed).
const _photoPool = [
  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/20230606_Tashkent019.jpg/1280px-20230606_Tashkent019.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Apartment_building_in_Tashkent_(Uzbekistan).jpg/1280px-Apartment_building_in_Tashkent_(Uzbekistan).jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Sky_builds.jpg/1280px-Sky_builds.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Immeubles_r%C3%A9sidentiels_%C3%A0_Tchilanzar.JPG/1280px-Immeubles_r%C3%A9sidentiels_%C3%A0_Tchilanzar.JPG',
  'https://upload.wikimedia.org/wikipedia/commons/2/22/Residential_Towers_%283926792798%29.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Furkat_street_in_Tashkent.jpg/1280px-Furkat_street_in_Tashkent.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Nukus_street_in_Tashkent_%284%29.jpg/1280px-Nukus_street_in_Tashkent_%284%29.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Tashkent_city_3.JPG/1280px-Tashkent_city_3.JPG',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Tashkent_city_5.JPG/1280px-Tashkent_city_5.JPG',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Modern_Tashkent._Skyline.jpg/1280px-Modern_Tashkent._Skyline.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/Skyline_of_Tashkent.jpg/1280px-Skyline_of_Tashkent.jpg',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Winter_in_Tashkent_3.JPG/1280px-Winter_in_Tashkent_3.JPG',
];

String _photo(int seed) => _photoPool[seed % _photoPool.length];

/// Path served by [residencesStaticHandler] — resolved to a full URL on the
/// client via [Env.apiBaseUrl] (see `AppNetworkImage`).
String _staticResidence(String filename) => '/v1/static/residences/$filename';

/// Deterministic gray placeholder used for floor plans (we don't have real
/// architectural drawings for this seed data) and agent headshots.
String _placeholderImage(String seed, int w, int h) =>
    'https://picsum.photos/seed/$seed/$w/$h';

Map<String, dynamic> _developer({
  required String id,
  required String name,
  required double rating,
  required int projectsCount,
  required String phone,
  required String agentName,
  required String agentPhone,
}) => {
  'id': id,
  'name': name,
  'logoUrl': null,
  'rating': rating,
  'projectsCount': projectsCount,
  'phone': phone,
  'agentName': agentName,
  'agentPhone': agentPhone,
  'agentAvatarUrl': _placeholderImage('agent-$id', 200, 200),
};

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

/// One distinct apartment/office layout inside a building: how many rooms
/// (null for offices), typical area, and a shared floor-plan placeholder so
/// "look inside" browsing can group units by layout.
class _LayoutSpec {
  const _LayoutSpec({
    this.rooms,
    required this.area,
    required this.label,
    this.layoutName,
  });

  final int? rooms;
  final double area;
  final String label;
  final String? layoutName;
}

const _apartmentLayouts = [
  _LayoutSpec(rooms: 1, area: 42, label: '1-room'),
  _LayoutSpec(rooms: 2, area: 61, label: '2-room'),
  _LayoutSpec(rooms: 3, area: 84, label: '3-room'),
  _LayoutSpec(rooms: 4, area: 112, label: '4-room'),
];

const _officeLayouts = [
  _LayoutSpec(area: 45, label: 'Open plan', layoutName: 'Open plan'),
  _LayoutSpec(area: 70, label: 'Cabinet layout', layoutName: 'Cabinet layout'),
  _LayoutSpec(area: 120, label: 'Corner suite', layoutName: 'Corner suite'),
];

/// Street-retail / ground-floor commercial units (Konseptsiya §4.3):
/// distinct from offices — street-facing shopfronts sized for cafes,
/// pharmacies, small shops, sold or rented by the same developer alongside
/// the residential units above them.
const _retailLayouts = [
  _LayoutSpec(area: 32, label: 'Kiosk unit', layoutName: 'Kiosk unit'),
  _LayoutSpec(area: 68, label: 'Shopfront', layoutName: 'Shopfront'),
  _LayoutSpec(
    area: 140,
    label: 'Corner storefront',
    layoutName: 'Corner storefront',
  ),
];

/// Builds one building with `floors` levels and `perFloor` units per level,
/// cycling through [layouts]. `soldRatio`/`reservedRatio` roughly control how
/// "mature" the sales stage looks (ready projects skew sold/rented).
Map<String, dynamic> buildBuilding({
  required String projectId,
  required String name,
  required int floors,
  required int perFloor,
  required String kind, // apartment | office
  required String dealType, // sale | rent
  required bool offplan,
  required double basePrice,
  required double priceStep,
  double? baseRent,
  double? rentStep,
  double soldRatio = 0.2,
  double reservedRatio = 0.15,
  double blockedRatio = 0.05,
  int? constructionProgress,
  DateTime? completionDate,
  bool mixedRent = false,
}) {
  final buildingId = _nextId('bld');
  final layouts = kind == 'office'
      ? _officeLayouts
      : kind == 'retail'
      ? _retailLayouts
      : _apartmentLayouts;
  final floorplanByLayout = <String, String>{
    for (final l in layouts)
      l.label: _placeholderImage('$buildingId-${l.label}', 640, 440),
  };

  final units = <Map<String, dynamic>>[];
  var i = 0;
  for (var floor = 1; floor <= floors; floor++) {
    for (var col = 0; col < perFloor; col++) {
      final layout = layouts[i % layouts.length];
      final roll = (i * 37 + floor * 11) % 100;
      final status = roll < (blockedRatio * 100)
          ? 'blocked'
          : roll < ((blockedRatio + soldRatio) * 100)
          ? (dealType == 'rent' ? 'rented' : 'sold')
          : roll < ((blockedRatio + soldRatio + reservedRatio) * 100)
          ? 'reserved'
          : 'available';

      final isRentUnit = mixedRent ? (i % 3 == 0) : dealType == 'rent';
      final price = !isRentUnit
          ? basePrice + priceStep * (layout.rooms ?? 1)
          : null;
      final priceM2 = !isRentUnit ? (price! / layout.area) : null;
      final rent = isRentUnit
          ? (baseRent ?? basePrice * 0.007) +
                (rentStep ?? priceStep * 0.006) * (layout.rooms ?? 1)
          : null;
      final rentM2 = isRentUnit ? (rent! / layout.area) : null;

      units.add({
        'id': _nextId('unit'),
        'buildingId': buildingId,
        'number': '$floor${(col + 1).toString().padLeft(2, '0')}',
        'kind': kind,
        'dealType': isRentUnit ? 'rent' : 'sale',
        'status': status,
        'floor': floor,
        'isOffplan': offplan,
        'areaTotal': layout.area,
        'areaLiving': layout.area * 0.86,
        'rooms': layout.rooms,
        'layout': layout.layoutName,
        'price': price,
        'priceM2': priceM2,
        'rentMonthly': rent,
        'rentM2': rentM2,
        'minLeaseMonths': isRentUnit ? 12 : null,
        'finishing': const ['Turnkey', 'Pre-finish', 'None'][i % 3],
        'view': const ['City', 'Courtyard', 'Park', 'Street'][i % 4],
        'planColumn': col,
        'planRow': floor - 1,
        'version': 1,
        'media': [
          _media(
            id: _nextId('med'),
            type: 'photo',
            url: _photo(i + floor),
            isCover: true,
          ),
          _media(
            id: _nextId('med'),
            type: 'floorplan',
            url: floorplanByLayout[layout.label]!,
            sortOrder: 1,
          ),
        ],
      });
      i++;
    }
  }

  return {
    'id': buildingId,
    'projectId': projectId,
    'name': name,
    'floors': floors,
    'constructionProgress': constructionProgress,
    'completionDate': completionDate?.toIso8601String(),
    'units': units,
  };
}

Map<String, dynamic> _offer({
  required String projectId,
  required String type,
  required String title,
  String? description,
  DateTime? startsAt,
  DateTime? endsAt,
  // Only meaningful for `type: 'installment'` offers — left `null` for
  // discount/rentPromo offers, matching how other optional fields (e.g.
  // `constructionProgress` on projects) are represented in this seed data.
  double? downPaymentPercent,
  int? termMonths,
  double? interestRate,
}) => {
  'id': _nextId('off'),
  'projectId': projectId,
  'type': type,
  'title': title,
  'description': description,
  'startsAt': startsAt?.toIso8601String(),
  'endsAt': endsAt?.toIso8601String(),
  'downPaymentPercent': downPaymentPercent,
  'termMonths': termMonths,
  'interestRate': interestRate,
};

Map<String, dynamic> _project({
  required String name,
  required String type,
  required String status,
  required String district,
  required String address,
  required double lat,
  required double lng,
  required Map<String, dynamic> developer,
  required String description,
  required List<String> amenities,
  required List<String> tags,
  required double rating,
  required bool isFeatured,
  required List<int> photoSeeds,
  List<String>? galleryUrls,
  required List<Map<String, dynamic>> buildings,
  int? constructionProgress,
  DateTime? completionDate,
  List<Map<String, dynamic>> offers = const [],
}) {
  final id = _nextId('prj');
  final allUnits = [
    for (final b in buildings) ...(b['units'] as List).cast<Map>(),
  ];
  final saleUnits = allUnits.where((u) => u['dealType'] == 'sale').toList();
  final rentUnits = allUnits.where((u) => u['dealType'] == 'rent').toList();
  final available = allUnits.where((u) => u['status'] == 'available').length;

  double? _minOf(Iterable<Map> units, String key) {
    final vals = units.map((u) => u[key] as double?).whereType<double>();
    return vals.isEmpty ? null : vals.reduce((a, b) => a < b ? a : b);
  }

  double? _maxOf(Iterable<Map> units, String key) {
    final vals = units.map((u) => u[key] as double?).whereType<double>();
    return vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b);
  }

  for (final b in buildings) {
    b['projectId'] = id;
    for (final u in (b['units'] as List).cast<Map>()) {
      u['buildingId'] = b['id'];
    }
  }
  for (final o in offers) {
    o['projectId'] = id;
  }

  return {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'district': district,
    'address': address,
    'lat': lat,
    'lng': lng,
    'developer': developer,
    'description': description,
    'amenities': amenities,
    'tags': tags,
    'priceMin': _minOf(saleUnits, 'price'),
    'priceMax': _maxOf(saleUnits, 'price'),
    'rentMin': _minOf(rentUnits, 'rentMonthly'),
    'rentMax': _maxOf(rentUnits, 'rentMonthly'),
    'constructionProgress': constructionProgress,
    'completionDate': completionDate?.toIso8601String(),
    'rating': rating,
    'availableUnits': available,
    'totalUnits': allUnits.length,
    'isFeatured': isFeatured,
    'gallery': galleryUrls != null
        ? [
            for (var i = 0; i < galleryUrls.length; i++)
              _media(
                id: _nextId('med'),
                type: i == galleryUrls.length - 1 ? 'render' : 'photo',
                url: galleryUrls[i],
                sortOrder: i,
                isCover: i == 0,
              ),
          ]
        : [
            for (var i = 0; i < photoSeeds.length; i++)
              _media(
                id: _nextId('med'),
                type: i == photoSeeds.length - 1 ? 'render' : 'photo',
                url: _photo(photoSeeds[i]),
                sortOrder: i,
                isCover: i == 0,
              ),
          ],
    'buildings': buildings,
    'offers': offers,
  };
}

/// Builds the full seed catalogue: 12 residential complexes + 3 business
/// centres across real Tashkent districts, each with a developer + assigned
/// realtor (name & phone), amenities (pool/sauna/gym/...), sale and/or rent
/// pricing, multi-floor buildings with varied apartment/office layouts, photo
/// + floor-plan placeholders, and a couple of active offers.
List<Map<String, dynamic>> buildProjectsSeed() {
  final projects = <Map<String, dynamic>>[];

  // 1. Tashkent City Residence — Yashnobod — ready, sale + rent, luxury.
  projects.add(
    _project(
      name: 'Tashkent City Residence',
      type: 'residential_complex',
      status: 'ready',
      district: 'Yashnobod',
      address: 'Tashkent City blvd 8, Tashkent',
      lat: 41.2864,
      lng: 69.3286,
      developer: _developer(
        id: 'dev-tcg',
        name: 'Tashkent Development Group',
        rating: 4.9,
        projectsCount: 5,
        phone: '+998 71 200 11 11',
        agentName: 'Sardor Aliyev',
        agentPhone: '+998 90 111 22 33',
      ),
      description:
          'A flagship luxury complex in the new Tashkent City business '
          'district: panoramic towers, a resident-only pool and spa deck, '
          'and full concierge service.',
      amenities: const [
        'Swimming pool',
        'Sauna',
        'Spa & wellness center',
        'Gym',
        'Concierge',
        '24/7 security',
        'Underground parking',
        'Smart home systems',
      ],
      tags: const ['Premium', 'Ready', 'City view'],
      rating: 4.9,
      isFeatured: true,
      photoSeeds: const [0, 4, 6, 9],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Tower A',
          floors: 18,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 78000,
          priceStep: 26000,
          soldRatio: 0.35,
          reservedRatio: 0.1,
          mixedRent: true,
          baseRent: 700,
          rentStep: 220,
        ),
        buildBuilding(
          projectId: '',
          name: 'Tower B',
          floors: 16,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 82000,
          priceStep: 27000,
          soldRatio: 0.3,
          reservedRatio: 0.12,
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'discount',
          title: '5% off for full upfront payment',
          description: 'Applies to any available unit in Tower A or B.',
          endsAt: DateTime(2026, 12, 31),
        ),
      ],
    ),
  );

  // 2. Nur Residence — Mirzo Ulugbek — under construction, installments.
  projects.add(
    _project(
      name: 'Nur Residence',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Mirzo Ulugbek',
      address: 'Buyuk Ipak Yuli 45, Tashkent',
      lat: 41.3251,
      lng: 69.3436,
      developer: _developer(
        id: 'dev-nur',
        name: 'Nur Qurilish',
        rating: 4.6,
        projectsCount: 3,
        phone: '+998 71 200 22 22',
        agentName: 'Malika Yusupova',
        agentPhone: '+998 90 222 33 44',
      ),
      description:
          'A family-oriented new build with a landscaped inner courtyard, '
          'kindergarten, and flexible installment plans during construction.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Kindergarten',
        'Underground parking',
        '24/7 security',
        'High-speed elevators',
      ],
      tags: const ['New build', 'Installments', 'Family friendly'],
      rating: 4.6,
      isFeatured: true,
      photoSeeds: const [1, 3, 7],
      constructionProgress: 48,
      completionDate: DateTime(2027, 9),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block 1',
          floors: 9,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 30000,
          priceStep: 9500,
          soldRatio: 0.15,
          reservedRatio: 0.2,
          constructionProgress: 48,
          completionDate: DateTime(2027, 9),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: '0% installment for 24 months',
          description: '30% down payment, the rest split monthly.',
          endsAt: DateTime(2027, 3, 1),
          downPaymentPercent: 0.3,
          termMonths: 24,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 3. Yunusabad Garden — Yunusabad — ready, sale + rent, family friendly.
  projects.add(
    _project(
      name: 'Yunusabad Garden',
      type: 'residential_complex',
      status: 'ready',
      district: 'Yunusabad',
      address: 'Amir Temur Ave 12, Tashkent',
      lat: 41.3379,
      lng: 69.3348,
      developer: _developer(
        id: 'dev-garden',
        name: 'Garden City Invest',
        rating: 4.7,
        projectsCount: 6,
        phone: '+998 71 200 33 33',
        agentName: 'Bekzod Rahimov',
        agentPhone: '+998 90 333 44 55',
      ),
      description:
          'Move-in-ready apartments around a green, car-free courtyard with '
          'a playground and a resident gym.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Gym',
        'Parking',
        '24/7 security',
        'Bicycle storage',
      ],
      tags: const ['Ready', 'Family friendly', 'Near metro'],
      rating: 4.7,
      isFeatured: false,
      photoSeeds: const [2, 5, 8],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block A',
          floors: 10,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 34000,
          priceStep: 11000,
          soldRatio: 0.4,
          reservedRatio: 0.1,
          mixedRent: true,
          baseRent: 320,
          rentStep: 110,
        ),
      ],
    ),
  );

  // 4. Chilanzar Plaza — Chilanzar — ready, sale.
  projects.add(
    _project(
      name: 'Chilanzar Plaza',
      type: 'residential_complex',
      status: 'ready',
      district: 'Chilanzar',
      address: 'Bunyodkor shokh kochasi 21, Tashkent',
      lat: 41.2856,
      lng: 69.2034,
      developer: _developer(
        id: 'dev-chilanzar',
        name: 'Chilanzar Qurilish Servis',
        rating: 4.3,
        projectsCount: 8,
        phone: '+998 71 200 44 44',
        agentName: 'Nodira Tashkentova',
        agentPhone: '+998 90 444 55 66',
      ),
      description:
          'A well-established residential plaza close to Chilanzar metro, '
          'with a commercial ground floor and secure parking.',
      amenities: const [
        'Commercial ground floor',
        'Underground parking',
        '24/7 security',
        'High-speed elevators',
      ],
      tags: const ['Ready', 'Near metro'],
      rating: 4.3,
      isFeatured: false,
      photoSeeds: const [3, 6, 10],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block 3',
          floors: 9,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 28000,
          priceStep: 8500,
          soldRatio: 0.5,
          reservedRatio: 0.08,
        ),
      ],
    ),
  );

  // 5. Mirabad Towers — Mirabad — under construction, featured.
  projects.add(
    _project(
      name: 'Mirabad Towers',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Mirabad',
      address: 'Mirabad kochasi 5, Tashkent',
      lat: 41.3033,
      lng: 69.2879,
      developer: _developer(
        id: 'dev-towers',
        name: 'Towers Group Uzbekistan',
        rating: 4.8,
        projectsCount: 4,
        phone: '+998 71 200 55 55',
        agentName: 'Jasur Ergashev',
        agentPhone: '+998 90 555 66 77',
      ),
      description:
          'Twin high-rise towers with a panoramic rooftop terrace, private '
          'spa floor, and smart-home fittings in every unit.',
      amenities: const [
        'Rooftop terrace',
        'Sauna',
        'Spa & wellness center',
        'Gym',
        'Smart home systems',
        'Underground parking',
        'Concierge',
      ],
      tags: const ['New build', 'Premium', 'Installments'],
      rating: 4.8,
      isFeatured: true,
      photoSeeds: const [4, 0, 9],
      constructionProgress: 71,
      completionDate: DateTime(2027, 2),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Tower North',
          floors: 22,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 65000,
          priceStep: 21000,
          soldRatio: 0.25,
          reservedRatio: 0.15,
          constructionProgress: 71,
          completionDate: DateTime(2027, 2),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: 'Installments up to 36 months',
          description: '20% down payment, flexible schedule.',
          downPaymentPercent: 0.2,
          termMonths: 36,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 6. Sergeli Park Residence — Sergeli — planned, early-bird pricing.
  projects.add(
    _project(
      name: 'Sergeli Park Residence',
      type: 'residential_complex',
      status: 'planned',
      district: 'Sergeli',
      address: 'Sergeli 12-berlik, Tashkent',
      lat: 41.2167,
      lng: 69.1978,
      developer: _developer(
        id: 'dev-sergeli',
        name: 'Sergeli Invest Qurilish',
        rating: 4.1,
        projectsCount: 2,
        phone: '+998 71 200 66 66',
        agentName: 'Kamola Nazarova',
        agentPhone: '+998 90 666 77 88',
      ),
      description:
          'Early-stage new build next to a planned public park; the lowest '
          'entry price in the portfolio for early reservations.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Parking',
        '24/7 security',
      ],
      tags: const ['New build', 'Installments', 'Eco-friendly'],
      rating: 4.1,
      isFeatured: false,
      photoSeeds: const [5, 1, 11],
      constructionProgress: 8,
      completionDate: DateTime(2028, 6),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block 1',
          floors: 7,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 21000,
          priceStep: 7000,
          soldRatio: 0.05,
          reservedRatio: 0.1,
          blockedRatio: 0.1,
          constructionProgress: 8,
          completionDate: DateTime(2028, 6),
        ),
      ],
    ),
  );

  // 7. Olmazor Family Complex — Olmazor — ready, sale + rent.
  projects.add(
    _project(
      name: 'Olmazor Family Complex',
      type: 'residential_complex',
      status: 'ready',
      district: 'Olmazor',
      address: 'Olmazor kochasi 44, Tashkent',
      lat: 41.3556,
      lng: 69.2264,
      developer: _developer(
        id: 'dev-olmazor',
        name: 'Olmazor Uy-Joy',
        rating: 4.4,
        projectsCount: 5,
        phone: '+998 71 200 77 77',
        agentName: 'Farrukh Tursunov',
        agentPhone: '+998 90 777 88 99',
      ),
      description:
          'A quiet family complex with a large courtyard, dedicated '
          'kindergarten, and both sale and long-term rental units available.',
      amenities: const [
        'Landscaped courtyard',
        'Kindergarten',
        'Kids playground',
        'Parking',
        'Video surveillance',
      ],
      tags: const ['Ready', 'Family friendly'],
      rating: 4.4,
      isFeatured: false,
      photoSeeds: const [6, 2, 8],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block A',
          floors: 8,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 26000,
          priceStep: 8200,
          soldRatio: 0.3,
          reservedRatio: 0.1,
          mixedRent: true,
          baseRent: 260,
          rentStep: 90,
        ),
      ],
    ),
  );

  // 8. Bektemir River View — Bektemir — under construction.
  projects.add(
    _project(
      name: 'Bektemir River View',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Bektemir',
      address: 'Bektemir daryo boyi 3, Tashkent',
      lat: 41.2306,
      lng: 69.3489,
      developer: _developer(
        id: 'dev-riverview',
        name: 'River View Development',
        rating: 4.5,
        projectsCount: 2,
        phone: '+998 71 200 88 88',
        agentName: 'Gulnora Sattorova',
        agentPhone: '+998 90 888 99 00',
      ),
      description:
          'Riverside new build with waterfront-facing units, a jogging path, '
          'and phased handover by block.',
      amenities: const [
        'Landscaped courtyard',
        'Underground parking',
        '24/7 security',
        'Gym',
      ],
      tags: const ['New build', 'City view'],
      rating: 4.5,
      isFeatured: false,
      photoSeeds: const [7, 3, 0],
      constructionProgress: 34,
      completionDate: DateTime(2027, 11),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block Riverside',
          floors: 12,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 38000,
          priceStep: 12500,
          soldRatio: 0.12,
          reservedRatio: 0.18,
          constructionProgress: 34,
          completionDate: DateTime(2027, 11),
        ),
      ],
    ),
  );

  // 9. Uchtepa Green City — Uchtepa — ready.
  projects.add(
    _project(
      name: 'Uchtepa Green City',
      type: 'residential_complex',
      status: 'ready',
      district: 'Uchtepa',
      address: 'Uchtepa bogʻi 9, Tashkent',
      lat: 41.2953,
      lng: 69.1866,
      developer: _developer(
        id: 'dev-greencity',
        name: 'Green City Invest',
        rating: 4.2,
        projectsCount: 3,
        phone: '+998 71 200 99 99',
        agentName: 'Otabek Yoldashev',
        agentPhone: '+998 90 999 00 11',
      ),
      description:
          'An eco-focused complex with solar-assisted common areas and a '
          'car-free central garden.',
      amenities: const [
        'Landscaped courtyard',
        'Bicycle storage',
        'Parking',
        'Video surveillance',
      ],
      tags: const ['Ready', 'Eco-friendly'],
      rating: 4.2,
      isFeatured: false,
      photoSeeds: const [8, 4, 1],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block Green',
          floors: 8,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 24000,
          priceStep: 7600,
          soldRatio: 0.45,
          reservedRatio: 0.1,
        ),
      ],
    ),
  );

  // 10. Sebzor Residence — Shayxontohur — handed over, mostly rent now.
  projects.add(
    _project(
      name: 'Sebzor Residence',
      type: 'residential_complex',
      status: 'handed_over',
      district: 'Shayxontohur',
      address: 'Sebzor koʻchasi 2, Tashkent',
      lat: 41.3225,
      lng: 69.2401,
      developer: _developer(
        id: 'dev-sebzor',
        name: 'Sebzor Emlak',
        rating: 4.3,
        projectsCount: 7,
        phone: '+998 71 201 10 10',
        agentName: 'Zarina Karimova',
        agentPhone: '+998 90 111 33 55',
      ),
      description:
          'A fully handed-over complex in the historic city core; most units '
          'are now investor-owned and available for long-term rent.',
      amenities: const [
        'Parking',
        '24/7 security',
        'Commercial ground floor',
        'High-speed elevators',
      ],
      tags: const ['Handed over', 'Near metro'],
      rating: 4.3,
      isFeatured: false,
      photoSeeds: const [9, 5, 2],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block 2',
          floors: 9,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 30000,
          priceStep: 9000,
          soldRatio: 0.55,
          reservedRatio: 0.05,
          mixedRent: true,
          baseRent: 300,
          rentStep: 95,
        ),
      ],
    ),
  );

  // 11. Malika Residence — Yakkasaray — ready, premium, featured.
  projects.add(
    _project(
      name: 'Malika Residence',
      type: 'residential_complex',
      status: 'ready',
      district: 'Yakkasaray',
      address: 'Yakkasaray koʻchasi 18, Tashkent',
      lat: 41.2953,
      lng: 69.2698,
      developer: _developer(
        id: 'dev-malika',
        name: 'Malika Estate Group',
        rating: 4.85,
        projectsCount: 4,
        phone: '+998 71 201 20 20',
        agentName: 'Shokhrukh Nabiyev',
        agentPhone: '+998 90 222 44 66',
      ),
      description:
          'Boutique premium residence with a private spa, sauna and gym floor, '
          'and a dedicated concierge desk for residents.',
      amenities: const [
        'Swimming pool',
        'Sauna',
        'Gym',
        'Spa & wellness center',
        'Concierge',
        'Smart home systems',
        'Underground parking',
      ],
      tags: const ['Premium', 'Ready', 'City view'],
      rating: 4.85,
      isFeatured: true,
      photoSeeds: const [10, 6, 3],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Residence Tower',
          floors: 14,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 95000,
          priceStep: 32000,
          soldRatio: 0.4,
          reservedRatio: 0.1,
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'discount',
          title: '3% loyalty discount for repeat buyers',
        ),
      ],
    ),
  );

  // 12. Diyor Residence — Yangihayot — under construction, installments.
  projects.add(
    _project(
      name: 'Diyor Residence',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Yangihayot',
      address: 'Yangihayot MFY 6, Tashkent',
      lat: 41.2483,
      lng: 69.1494,
      developer: _developer(
        id: 'dev-diyor',
        name: 'Diyor Qurilish Invest',
        rating: 4.35,
        projectsCount: 3,
        phone: '+998 71 201 30 30',
        agentName: 'Madina Alimova',
        agentPhone: '+998 90 333 55 77',
      ),
      description:
          'Affordable new build on the western edge of the city, targeting '
          'young families with generous installment terms.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Parking',
        '24/7 security',
      ],
      tags: const ['New build', 'Installments', 'Family friendly'],
      rating: 4.35,
      isFeatured: false,
      photoSeeds: const [11, 7, 4],
      constructionProgress: 22,
      completionDate: DateTime(2028, 1),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block 1',
          floors: 9,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 19000,
          priceStep: 6200,
          soldRatio: 0.08,
          reservedRatio: 0.12,
          blockedRatio: 0.08,
          constructionProgress: 22,
          completionDate: DateTime(2028, 1),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: '0% installment for 36 months',
          description:
              '15% down payment, the rest split monthly until handover.',
          downPaymentPercent: 0.15,
          termMonths: 36,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 13. Poytaht Business Center — Mirabad — ready, Class A offices.
  projects.add(
    _project(
      name: 'Poytaht Business Center',
      type: 'business_centre',
      status: 'ready',
      district: 'Mirabad',
      address: 'Navoi koʻchasi 2, Tashkent',
      lat: 41.3111,
      lng: 69.2401,
      developer: _developer(
        id: 'dev-poytaht',
        name: 'Poytaht Property Management',
        rating: 4.4,
        projectsCount: 2,
        phone: '+998 71 201 40 40',
        agentName: 'Ravshan Yusupov',
        agentPhone: '+998 90 444 66 88',
      ),
      description:
          'Class-A offices for rent in the city core, with fiber connectivity '
          'and 24/7 access control.',
      amenities: const [
        'Underground parking',
        '24/7 security',
        'Fiber internet',
        'Backup power generator',
        'Conference rooms',
      ],
      tags: const ['Class A', 'Ready'],
      rating: 4.4,
      isFeatured: false,
      photoSeeds: const [0, 8, 5],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Section A',
          floors: 10,
          perFloor: 4,
          kind: 'office',
          dealType: 'rent',
          offplan: false,
          basePrice: 0,
          priceStep: 0,
          baseRent: 900,
          rentStep: 260,
          soldRatio: 0.3,
          reservedRatio: 0.1,
        ),
      ],
    ),
  );

  // 14. Alfa Business Tower — Yunusabad — ready, featured.
  projects.add(
    _project(
      name: 'Alfa Business Tower',
      type: 'business_centre',
      status: 'ready',
      district: 'Yunusabad',
      address: 'Amir Temur shoh koʻchasi 108, Tashkent',
      lat: 41.3444,
      lng: 69.2856,
      developer: _developer(
        id: 'dev-alfa',
        name: 'Alfa Group Uzbekistan',
        rating: 4.7,
        projectsCount: 3,
        phone: '+998 71 201 50 50',
        agentName: 'Iroda Bekova',
        agentPhone: '+998 90 555 77 99',
      ),
      description:
          'A premium business tower with a coworking lounge, conference '
          'floor, and panoramic corner suites.',
      amenities: const [
        'Coworking lounge',
        'Conference rooms',
        'Underground parking',
        '24/7 security',
        'High-speed elevators',
        'Fiber internet',
      ],
      tags: const ['Class A', 'Premium'],
      rating: 4.7,
      isFeatured: true,
      photoSeeds: const [1, 9, 6],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Main Tower',
          floors: 16,
          perFloor: 4,
          kind: 'office',
          dealType: 'rent',
          offplan: false,
          basePrice: 0,
          priceStep: 0,
          baseRent: 1400,
          rentStep: 420,
          soldRatio: 0.35,
          reservedRatio: 0.1,
        ),
      ],
    ),
  );

  // 15. Grand Plaza Offices — Shayxontohur — ready.
  projects.add(
    _project(
      name: 'Grand Plaza Offices',
      type: 'business_centre',
      status: 'ready',
      district: 'Shayxontohur',
      address: 'Navoi shoh koʻchasi 2, Tashkent',
      lat: 41.3111,
      lng: 69.2401,
      developer: _developer(
        id: 'dev-grandplaza',
        name: 'Grand Plaza Holding',
        rating: 4.5,
        projectsCount: 2,
        phone: '+998 71 201 60 60',
        agentName: 'Sanjar Mirzayev',
        agentPhone: '+998 90 666 88 00',
      ),
      description:
          'Flexible open-plan and cabinet-layout offices in the city centre, '
          'popular with growing local businesses.',
      amenities: const [
        'Underground parking',
        '24/7 security',
        'Fiber internet',
        'Commercial ground floor',
      ],
      tags: const ['Class A', 'Near metro'],
      rating: 4.5,
      isFeatured: false,
      photoSeeds: const [2, 10, 7],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Section B',
          floors: 8,
          perFloor: 4,
          kind: 'office',
          dealType: 'rent',
          offplan: false,
          basePrice: 0,
          priceStep: 0,
          baseRent: 780,
          rentStep: 200,
          soldRatio: 0.25,
          reservedRatio: 0.12,
        ),
      ],
    ),
  );

  // 16. Zarafshon Residence — Uchtepa — ready, rent-only, mid-market.
  projects.add(
    _project(
      name: 'Zarafshon Residence',
      type: 'residential_complex',
      status: 'ready',
      district: 'Uchtepa',
      address: 'Zarafshon koʻchasi 14, Tashkent',
      lat: 41.2820,
      lng: 69.1750,
      developer: _developer(
        id: 'dev-zarafshon',
        name: 'Zarafshon Property',
        rating: 4.15,
        projectsCount: 3,
        phone: '+998 71 201 70 70',
        agentName: 'Umid Rashidov',
        agentPhone: '+998 90 777 11 22',
      ),
      description:
          'A fully tenanted mid-market complex popular with long-term renters, '
          'minutes from Uchtepa market with a quiet inner courtyard.',
      amenities: const [
        'Landscaped courtyard',
        'Parking',
        '24/7 security',
        'Video surveillance',
      ],
      tags: const ['Ready', 'Near metro'],
      rating: 4.15,
      isFeatured: false,
      photoSeeds: const [3, 9, 1],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block Zarafshon',
          floors: 9,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'rent',
          offplan: false,
          basePrice: 0,
          priceStep: 0,
          baseRent: 280,
          rentStep: 95,
          soldRatio: 0.5,
          reservedRatio: 0.1,
        ),
      ],
    ),
  );

  // 17. Bostonlik Hills — Mirzo Ulugbek — planned, low-rise, premium plots.
  projects.add(
    _project(
      name: 'Bostonlik Hills',
      type: 'residential_complex',
      status: 'planned',
      district: 'Mirzo Ulugbek',
      address: 'Bostonlik yoʻli 3, Tashkent',
      lat: 41.3690,
      lng: 69.3902,
      developer: _developer(
        id: 'dev-bostonlik',
        name: 'Hills Development',
        rating: 4.6,
        projectsCount: 2,
        phone: '+998 71 201 80 80',
        agentName: 'Aziza Nematova',
        agentPhone: '+998 90 888 22 33',
      ),
      description:
          'Low-rise premium living on the green northern edge of the city, '
          'with private terraces and panoramic mountain views.',
      amenities: const [
        'Swimming pool',
        'Landscaped courtyard',
        'Gym',
        '24/7 security',
        'Underground parking',
        'Smart home systems',
      ],
      tags: const ['New build', 'Premium', 'Eco-friendly'],
      rating: 4.6,
      isFeatured: true,
      photoSeeds: const [6, 11, 2],
      constructionProgress: 3,
      completionDate: DateTime(2028, 10),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Residence 1',
          floors: 6,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 72000,
          priceStep: 24000,
          soldRatio: 0.03,
          reservedRatio: 0.07,
          blockedRatio: 0.05,
          constructionProgress: 3,
          completionDate: DateTime(2028, 10),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'discount',
          title: 'Early-bird 8% discount before groundbreaking',
          endsAt: DateTime(2027, 1, 15),
        ),
      ],
    ),
  );

  // 18. Chorsu Old Town Flats — Shayxontohur — handed over, budget, sale+rent.
  projects.add(
    _project(
      name: 'Chorsu Old Town Flats',
      type: 'residential_complex',
      status: 'handed_over',
      district: 'Shayxontohur',
      address: 'Chorsu maydoni 6, Tashkent',
      lat: 41.3269,
      lng: 69.2350,
      developer: _developer(
        id: 'dev-chorsu',
        name: 'Chorsu Uy-Joy Servis',
        rating: 4.0,
        projectsCount: 9,
        phone: '+998 71 201 90 90',
        agentName: 'Tohir Ismoilov',
        agentPhone: '+998 90 999 22 44',
      ),
      description:
          'Budget-friendly flats steps from Chorsu bazaar, popular with both '
          'first-time buyers and renters thanks to the unbeatable location.',
      amenities: const ['Parking', '24/7 security', 'Commercial ground floor'],
      tags: const ['Handed over', 'Near metro'],
      rating: 4.0,
      isFeatured: false,
      photoSeeds: const [10, 0, 4],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block Old Town',
          floors: 5,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: false,
          basePrice: 16000,
          priceStep: 5200,
          soldRatio: 0.6,
          reservedRatio: 0.05,
          mixedRent: true,
          baseRent: 190,
          rentStep: 70,
        ),
      ],
    ),
  );

  // 19. Hills Blue — Yunusabad — premium new build (Hills Group / AYSEL).
  // Real marketing photo from `residences-images/hills-blue-banner.webp`.
  // Source: hillsblue.uz, salomuy.uz — 5×22-floor towers, Badamzar, Q1 2027.
  projects.add(
    _project(
      name: 'Hills Blue',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Yunusabad',
      address: 'Chingiz Aitmatov ko\'chasi 37B, Badamzar, Tashkent',
      lat: 41.3528,
      lng: 69.3012,
      developer: _developer(
        id: 'dev-hills-group',
        name: 'Hills Group',
        rating: 4.9,
        projectsCount: 4,
        phone: '+998 78 120 64 64',
        agentName: 'Dilshod Karimov',
        agentPhone: '+998 90 120 64 64',
      ),
      description:
          'Premium residential complex by Hills Group in Yunusabad\'s Badamzar '
          'district: five 22-storey towers with asymmetric facades, 3.5 m '
          'ceiling heights, underground parking and white-box handover. '
          'Award-winning architecture; completion planned for Q1 2027.',
      amenities: const [
        'Underground parking',
        'Landscaped courtyard',
        'Gym',
        '24/7 security',
        'High-speed elevators',
        'Concierge',
        'Smart home systems',
      ],
      tags: const ['Premium', 'New build', 'Installments'],
      rating: 4.9,
      isFeatured: true,
      photoSeeds: const [0, 9, 5],
      galleryUrls: [
        _staticResidence('hills-blue-banner.webp'),
        _photo(9),
        _photo(5),
        _photo(0),
      ],
      constructionProgress: 38,
      completionDate: DateTime(2027, 3),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Tower 1',
          floors: 22,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 46000,
          priceStep: 14000,
          soldRatio: 0.12,
          reservedRatio: 0.18,
          constructionProgress: 42,
          completionDate: DateTime(2027, 3),
        ),
        buildBuilding(
          projectId: '',
          name: 'Tower 2',
          floors: 22,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 48000,
          priceStep: 14500,
          soldRatio: 0.1,
          reservedRatio: 0.15,
          constructionProgress: 35,
          completionDate: DateTime(2027, 3),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: 'Flexible installment until handover',
          description: '30% down payment, balance split monthly until Q1 2027.',
          endsAt: DateTime(2027, 1, 1),
          downPaymentPercent: 0.3,
          termMonths: 24,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 20. Regnum Plaza — Mirzo Ulugbek — business class (Murad Buildings).
  projects.add(
    _project(
      name: 'Regnum Plaza',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Mirzo Ulugbek',
      address: 'Sayram ko\'chasi, Mirzo Ulugbek tumani, Tashkent',
      lat: 41.3388,
      lng: 69.3588,
      developer: _developer(
        id: 'dev-murad',
        name: 'Murad Buildings',
        rating: 4.8,
        projectsCount: 12,
        phone: '+998 71 205 55 55',
        agentName: 'Aziza Nazarova',
        agentPhone: '+998 90 205 55 55',
      ),
      description:
          'Business-class residential complex by Murad Buildings on Sayram '
          'Street in Mirzo Ulugbek — one of the developer\'s flagship launches '
          'with smart-home infrastructure and a landscaped podium deck.',
      amenities: const [
        'Landscaped courtyard',
        'Underground parking',
        'Gym',
        '24/7 security',
        'Kids playground',
        'High-speed elevators',
      ],
      tags: const ['New build', 'Business class', 'Installments'],
      rating: 4.8,
      isFeatured: true,
      photoSeeds: const [4, 1, 8],
      constructionProgress: 55,
      completionDate: DateTime(2025, 3),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Phase 1',
          floors: 16,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 42000,
          priceStep: 12000,
          soldRatio: 0.2,
          reservedRatio: 0.22,
          constructionProgress: 55,
          completionDate: DateTime(2025, 3),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: '0% installment for 18 months',
          description: '25% down payment during construction phase.',
          downPaymentPercent: 0.25,
          termMonths: 18,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 21. Saadiyat — Mirzo Ulugbek — business class (Murad Buildings).
  projects.add(
    _project(
      name: 'Saadiyat',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Mirzo Ulugbek',
      address: 'Katta Darkhan va Akkurgan ko\'chalari chorrahasi, Tashkent',
      lat: 41.3295,
      lng: 69.3712,
      developer: _developer(
        id: 'dev-murad',
        name: 'Murad Buildings',
        rating: 4.8,
        projectsCount: 12,
        phone: '+998 71 205 55 55',
        agentName: 'Javohir Mirzayev',
        agentPhone: '+998 90 305 55 55',
      ),
      description:
          'A business-class neighbourhood by Murad Buildings at the '
          'intersection of Katta Darkhan and Akkurgan streets — designed for '
          'families who want modern layouts close to universities and transit.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Underground parking',
        'Gym',
        '24/7 security',
      ],
      tags: const ['New build', 'Business class', 'Family friendly'],
      rating: 4.7,
      isFeatured: false,
      photoSeeds: const [3, 7, 2],
      constructionProgress: 28,
      completionDate: DateTime(2027, 12),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Block A',
          floors: 14,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 36000,
          priceStep: 10500,
          soldRatio: 0.1,
          reservedRatio: 0.16,
          constructionProgress: 28,
          completionDate: DateTime(2027, 12),
        ),
      ],
    ),
  );

  // 22. Soy Bo\'yi — Uchtepa — riverside business class (Murad Buildings).
  projects.add(
    _project(
      name: 'Soy Bo\'yi',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Uchtepa',
      address: 'Yusuf Sakkaki ko\'chasi 3A, Uchtepa tumani, Tashkent',
      lat: 41.2788,
      lng: 69.1688,
      developer: _developer(
        id: 'dev-murad',
        name: 'Murad Buildings',
        rating: 4.8,
        projectsCount: 12,
        phone: '+998 71 205 55 55',
        agentName: 'Kamola Rakhimova',
        agentPhone: '+998 90 405 55 55',
      ),
      description:
          'Life by the riverbank — Murad Buildings\' business-class complex '
          'along the Chirchiq canal in Uchtepa with walking paths, a resident '
          'gym and underground parking.',
      amenities: const [
        'Riverside promenade',
        'Gym',
        'Underground parking',
        'Landscaped courtyard',
        '24/7 security',
        'Kids playground',
      ],
      tags: const ['New build', 'Business class'],
      rating: 4.75,
      isFeatured: false,
      photoSeeds: const [6, 10, 1],
      constructionProgress: 44,
      completionDate: DateTime(2026, 3),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Riverside Block',
          floors: 12,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 34000,
          priceStep: 9800,
          soldRatio: 0.14,
          reservedRatio: 0.18,
          constructionProgress: 44,
          completionDate: DateTime(2026, 3),
        ),
      ],
    ),
  );

  // 23. Tuzel Park — Yashnabad — comfort class (Imarat Development).
  projects.add(
    _project(
      name: 'Tuzel Park',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Yashnobod',
      address: 'Rohat aylanma yo\'li yonida, Yashnobod tumani, Tashkent',
      lat: 41.2688,
      lng: 69.3588,
      developer: _developer(
        id: 'dev-imarat',
        name: 'Imarat Development',
        rating: 4.5,
        projectsCount: 8,
        phone: '+998 71 291 00 00',
        agentName: 'Feruza Toshmatova',
        agentPhone: '+998 90 291 00 00',
      ),
      description:
          'A comfort-class quarter by Imarat Development near the Tuzel metro '
          'hub in Yashnabad: seven 16-storey buildings with landscaped grounds '
          'and installment plans up to 30 months.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Parking',
        '24/7 security',
        'Commercial ground floor',
      ],
      tags: const ['New build', 'Installments', 'Near metro'],
      rating: 4.5,
      isFeatured: true,
      photoSeeds: const [2, 8, 4],
      constructionProgress: 32,
      completionDate: DateTime(2026, 12),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Building 1',
          floors: 16,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 20600,
          priceStep: 6500,
          soldRatio: 0.11,
          reservedRatio: 0.14,
          constructionProgress: 32,
          completionDate: DateTime(2026, 12),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: 'Installment up to 30 months',
          description: '20% down payment, 0% interest during construction.',
          downPaymentPercent: 0.2,
          termMonths: 30,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 24. Bristol — Tashkent region — comfort class (Imarat Development).
  projects.add(
    _project(
      name: 'Bristol',
      type: 'residential_complex',
      status: 'under_construction',
      district: 'Yangihayot',
      address: 'Parkent yo\'li, Yuqorichirchiq tumani, Toshkent viloyati',
      lat: 41.3122,
      lng: 69.4522,
      developer: _developer(
        id: 'dev-imarat',
        name: 'Imarat Development',
        rating: 4.5,
        projectsCount: 8,
        phone: '+998 71 291 00 00',
        agentName: 'Rustam Qodirov',
        agentPhone: '+998 90 391 00 00',
      ),
      description:
          'A low-rise comfort-class neighbourhood by Imarat Development on '
          'the Parkent highway — 34 seven-storey buildings in a green suburban '
          'setting, with phased handover from Q4 2025.',
      amenities: const [
        'Landscaped courtyard',
        'Kids playground',
        'Parking',
        '24/7 security',
        'Kindergarten',
      ],
      tags: const ['New build', 'Family friendly', 'Installments'],
      rating: 4.4,
      isFeatured: false,
      photoSeeds: const [11, 3, 6],
      constructionProgress: 48,
      completionDate: DateTime(2027, 3),
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Cluster A',
          floors: 7,
          perFloor: 4,
          kind: 'apartment',
          dealType: 'sale',
          offplan: true,
          basePrice: 18500,
          priceStep: 5800,
          soldRatio: 0.15,
          reservedRatio: 0.12,
          constructionProgress: 48,
          completionDate: DateTime(2027, 3),
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'installment',
          title: 'Installment up to 30 months',
          downPaymentPercent: 0.2,
          termMonths: 30,
          interestRate: 0.0,
        ),
      ],
    ),
  );

  // 25. Chilanzar Retail Row — street retail (Konseptsiya §4.3): ground-floor
  // commercial units sold and rented directly by the developer, distinct
  // from both residential complexes and business-centre office floors.
  projects.add(
    _project(
      name: 'Chilanzar Retail Row',
      type: 'street_retail',
      status: 'ready',
      district: 'Chilanzar',
      address: 'Bunyodkor shokh kochasi 21, Tashkent',
      lat: 41.2851,
      lng: 69.2040,
      developer: _developer(
        id: 'dev-chilanzar',
        name: 'Chilanzar Qurilish Servis',
        rating: 4.3,
        projectsCount: 8,
        phone: '+998 71 200 44 44',
        agentName: 'Nodira Tashkentova',
        agentPhone: '+998 90 444 55 66',
      ),
      description:
          'Street-facing commercial units on the ground floor of Chilanzar '
          'Plaza — shopfronts and corner storefronts for cafes, pharmacies '
          'and small retail, available for purchase or long-term rent '
          'directly from the developer.',
      amenities: const [
        'Street frontage',
        'Separate utility metering',
        '24/7 security',
        'Loading access',
      ],
      tags: const ['Street retail', 'Ready', 'Near metro'],
      rating: 4.3,
      isFeatured: false,
      photoSeeds: const [3, 6, 10],
      buildings: [
        buildBuilding(
          projectId: '',
          name: 'Ground Floor Row',
          floors: 1,
          perFloor: 6,
          kind: 'retail',
          dealType: 'sale',
          offplan: false,
          basePrice: 42000,
          priceStep: 18000,
          soldRatio: 0.3,
          reservedRatio: 0.15,
          mixedRent: true,
          baseRent: 950,
          rentStep: 380,
        ),
      ],
      offers: [
        _offer(
          projectId: '',
          type: 'rent_promo',
          title: 'First month free on a 24-month lease',
          description: 'Applies to any available shopfront in the row.',
        ),
      ],
    ),
  );

  return projects;
}
