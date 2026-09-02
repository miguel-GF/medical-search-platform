typedef JsonMap = Map<String, dynamic>;

double? _doubleValue(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value');
String? _stringValue(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

class SearchOffer {
  const SearchOffer({
    required this.id,
    required this.providerName,
    this.locationName,
    this.distanceMeters,
    this.amountMinor,
    this.currency,
    this.sourceUrl,
    this.lastSeenAt,
  });

  final String id;
  final String providerName;
  final String? locationName;
  final double? distanceMeters;
  final int? amountMinor;
  final String? currency;
  final String? sourceUrl;
  final String? lastSeenAt;

  factory SearchOffer.fromJson(JsonMap json) {
    final provider = (json['provider'] as JsonMap?) ?? <String, dynamic>{};
    final location = json['location'] as JsonMap?;
    final price = json['price'] as JsonMap?;
    final source = json['source'] as JsonMap?;
    return SearchOffer(
      id: _stringValue(json['id']) ?? 'offer',
      providerName: _stringValue(provider['name']) ?? 'Proveedor',
      locationName: _stringValue(location?['name']),
      distanceMeters: _doubleValue(json['distance_meters']),
      amountMinor: _intValue(price?['amount_minor']),
      currency: _stringValue(price?['currency']),
      sourceUrl: _stringValue(source?['url']),
      lastSeenAt: _stringValue(source?['last_seen_at']),
    );
  }
}

class SearchService {
  const SearchService({
    required this.id,
    required this.displayName,
    required this.confidence,
    required this.offers,
  });

  final String id;
  final String displayName;
  final double confidence;
  final List<SearchOffer> offers;

  factory SearchService.fromJson(JsonMap json) {
    final service = (json['service'] as JsonMap?) ?? <String, dynamic>{};
    final offers = (json['offers'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(SearchOffer.fromJson)
        .toList(growable: false);
    return SearchService(
      id: _stringValue(service['id']) ?? 'service',
      displayName: _stringValue(service['display_name']) ?? 'Servicio',
      confidence: _doubleValue(service['confidence']) ?? 0,
      offers: offers,
    );
  }
}

class SearchResponse {
  const SearchResponse({required this.query, required this.services});

  final String query;
  final List<SearchService> services;

  factory SearchResponse.fromJson(JsonMap json) => SearchResponse(
    query: _stringValue(json['query']) ?? '',
    services: (json['results'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(SearchService.fromJson)
        .toList(growable: false),
  );
}

enum PackageObjective { allInOne, lowestCost, nearest, balanced }

extension PackageObjectiveWire on PackageObjective {
  String get wireName => switch (this) {
    PackageObjective.allInOne => 'all_in_one',
    PackageObjective.lowestCost => 'lowest_cost',
    PackageObjective.nearest => 'nearest',
    PackageObjective.balanced => 'balanced',
  };

  String get label => switch (this) {
    PackageObjective.allInOne => 'Todo en una sucursal',
    PackageObjective.lowestCost => 'Menor costo',
    PackageObjective.nearest => 'Más cercano',
    PackageObjective.balanced => 'Balanceado',
  };
}

class PackageCandidate {
  const PackageCandidate({
    required this.displayName,
    required this.confidence,
    required this.matchMethod,
  });

  final String displayName;
  final double confidence;
  final String matchMethod;

  factory PackageCandidate.fromJson(JsonMap json) => PackageCandidate(
    displayName: _stringValue(json['display_name']) ?? 'Candidato',
    confidence: _doubleValue(json['confidence']) ?? 0,
    matchMethod: _stringValue(json['match_method']) ?? 'review',
  );
}

class PackageItem {
  const PackageItem({
    required this.index,
    required this.input,
    required this.status,
    required this.candidates,
    this.reasonCode,
  });

  final int index;
  final String input;
  final String status;
  final List<PackageCandidate> candidates;
  final String? reasonCode;

  factory PackageItem.fromJson(JsonMap json) => PackageItem(
    index: _intValue(json['index']) ?? 0,
    input: _stringValue(json['input']) ?? '',
    status: _stringValue(json['status']) ?? 'no_match',
    reasonCode: _stringValue(json['reason_code']),
    candidates: (json['candidates'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(PackageCandidate.fromJson)
        .toList(growable: false),
  );
}

class PackageLocation {
  const PackageLocation({
    required this.name,
    required this.providerName,
    this.distanceMeters,
  });

  final String name;
  final String providerName;
  final double? distanceMeters;

  factory PackageLocation.fromJson(JsonMap json) => PackageLocation(
    name: _stringValue(json['name']) ?? 'Sucursal',
    providerName: _stringValue(json['provider_name']) ?? 'Proveedor',
    distanceMeters: _doubleValue(json['distance_meters']),
  );
}

class PackageSolution {
  const PackageSolution({
    required this.coverageCount,
    required this.requestedCount,
    required this.coveragePercent,
    required this.locationCount,
    required this.locations,
    required this.missingIndexes,
    this.totalAmountMinor,
    this.currency,
    required this.requiresQuote,
  });

  final int coverageCount;
  final int requestedCount;
  final double coveragePercent;
  final int locationCount;
  final List<PackageLocation> locations;
  final List<int> missingIndexes;
  final int? totalAmountMinor;
  final String? currency;
  final bool requiresQuote;

  factory PackageSolution.fromJson(JsonMap json) => PackageSolution(
    coverageCount: _intValue(json['coverage_count']) ?? 0,
    requestedCount: _intValue(json['requested_count']) ?? 0,
    coveragePercent: _doubleValue(json['coverage_percent']) ?? 0,
    locationCount: _intValue(json['location_count']) ?? 0,
    locations: (json['locations'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(PackageLocation.fromJson)
        .toList(growable: false),
    missingIndexes: (json['missing_item_indexes'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(growable: false),
    totalAmountMinor: _intValue(json['total_amount_minor']),
    currency: _stringValue(json['currency']),
    requiresQuote: json['requires_quote'] == true,
  );
}

class OcrPreview {
  const OcrPreview({
    required this.text,
    required this.reviewRequired,
    required this.lowConfidenceLines,
  });

  final String text;
  final bool reviewRequired;
  final List<String> lowConfidenceLines;

  factory OcrPreview.fromJson(JsonMap json) => OcrPreview(
    text: _stringValue(json['text']) ?? '',
    reviewRequired: json['review_required'] == true,
    lowConfidenceLines:
        (json['low_confidence_lines'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
  );
}

class PackageResponse {
  const PackageResponse({
    required this.packageStatus,
    required this.coverageStatus,
    required this.items,
    required this.solutions,
    this.ocr,
    this.query,
  });

  final String packageStatus;
  final String coverageStatus;
  final List<PackageItem> items;
  final List<PackageSolution> solutions;
  final OcrPreview? ocr;
  final String? query;

  factory PackageResponse.fromJson(JsonMap json) => PackageResponse(
    packageStatus: _stringValue(json['package_status']) ?? 'no_match',
    coverageStatus: _stringValue(json['coverage_status']) ?? 'none',
    query: _stringValue(json['query']),
    items: (json['items'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(PackageItem.fromJson)
        .toList(growable: false),
    solutions: (json['solutions'] as List<dynamic>? ?? const [])
        .whereType<JsonMap>()
        .map(PackageSolution.fromJson)
        .toList(growable: false),
    ocr: json['ocr'] is JsonMap
        ? OcrPreview.fromJson(json['ocr'] as JsonMap)
        : null,
  );
}
